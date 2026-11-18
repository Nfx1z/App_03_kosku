import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../db/database_helper.dart';

/// Status sinkronisasi untuk chip di Home & baris di Pengaturan.
enum StatusSinkron {
  /// Tidak ada akun / Firebase belum dikonfigurasi → murni lokal.
  lokalSaja,

  /// Ada akun, sedang offline → antrian disimpan lokal.
  offline,

  /// Online, ada perubahan yang belum terkirim.
  antri,

  /// Online dan antrian kosong.
  sinkron,

  /// Online tapi gagal kirim (mis. aturan Firestore salah).
  error,
}

/// Mesin sinkronisasi local-first → Firestore.
///
/// Alur:
/// 1. Setiap tulis lokal (cepat, tanpa internet) masuk tabel `antrian`.
/// 2. [flush] mengirim antrian ke Firestore berkelompok (batch) saat online.
/// 3. Listener real-time menerapkan perubahan dari perangkat lain ke SQLite.
/// 4. Konflik diselesaikan last-write-wins per dokumen via `diubah_pada`.
///
/// Penghapusan: baris lokal jadi tombstone (dihapus=1, disimpan 30 hari
/// supaya penghapusan tidak tertimpa merge), tapi di cloud dokumennya
/// dihapus BETULAN (batch.delete) - bukan ditandai - jadi data user tidak
/// tertinggal selamanya di console Firebase. Perangkat lain diberi tahu
/// lewat event `removed` dari listener.
///
/// Skema Firestore (semua di bawah `users/{uid}/`):
/// - `transaksi/{cloud_id}`, `kiriman/{cloud_id}`, `target/{cloud_id}`,
///   `utang/{cloud_id}` - isi = kolom SQLite tanpa `id`; baris yang
///   dihapus lokal dikirim sebagai DELETE dokumen.
/// - `pengaturan/{kunci}` - {kunci, nilai, dihapus, diubah_pada}; untuk
///   kunci ini tombstone kecil (nilai null) tetap dipakai sebagai sinyal
///   LWW ke perangkat lain.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _db = DatabaseHelper.instance;

  FirebaseFirestore? _fs;
  String? _uid;
  bool _aktif = false;
  bool _flushing = false;
  bool _menyapu = false;
  Timer? _kickTimer;
  Timer? _reloadDebounce;
  StreamSubscription? _subKonektivitas;
  final _subs = <StreamSubscription>[];

  /// Dipasang AppState: status berubah / data remote baru diterapkan.
  void Function(StatusSinkron status, int antrian, DateTime? terakhir)?
      onPerubahan;

  StatusSinkron status = StatusSinkron.lokalSaja;
  int jumlahAntrian = 0;
  DateTime? sinkronTerakhir;

  bool get aktif => _aktif;
  String? get uid => _uid;

  static int _intDari(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  // ================= SIKLUS HIDUP =================

  /// Mulai sinkron untuk [uid]: merge pertama (sekali per uid) →
  /// listener real-time → flush antrian.
  Future<void> mulai(String uid) async {
    if (_aktif && _uid == uid) return;
    await berhenti();

    _uid = uid;
    _fs = FirebaseFirestore.instance;
    _aktif = true;

    // Muat stempel waktu sinkron terakhir dari penyimpanan lokal.
    final lastSyncTersimpan = await _db.getNilai('last_sync');
    final ms = int.tryParse(lastSyncTersimpan ?? '');
    sinkronTerakhir =
        ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);

    // Merge penuh sekali per akun (perangkat baru / login pertama).
    final sudahMerge = await _db.getNilai('sync_uid');
    if (sudahMerge != uid) {
      await gabungPertama();
      await _db.setNilai('sync_uid', uid);
    }

    _mulaiListener();
    _subKonektivitas = Connectivity().onConnectivityChanged.listen((hasil) {
      final online =
          hasil.isNotEmpty && !hasil.contains(ConnectivityResult.none);
      if (online) {
        kick(cepat: true);
      } else if (_aktif) {
        _lapor(StatusSinkron.offline);
      }
    });

    kick(cepat: true);

    // Bersih-bersih sekali per nyala sync (aman diulang, error diabaikan):
    // - sweep "hapus semua data" yang tertunda (reset saat offline).
    // - dokumen tombstone peninggalan versi lama (dihapus=1) di cloud.
    unawaited(_cobaSweepTertunda());
    unawaited(_bersihkanTombstoneCloud());
  }

  /// Berhenti total (logout / app ditutup).
  Future<void> berhenti() async {
    _aktif = false;
    _uid = null;
    _kickTimer?.cancel();
    _reloadDebounce?.cancel();
    await _subKonektivitas?.cancel();
    _subKonektivitas = null;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _lapor(StatusSinkron.lokalSaja);
  }

  // ================= MERGE PERTAMA =================

  /// Gabungkan data cloud ↔ lokal berdasarkan last-write-wins,
  /// lalu antri semua yang lokal lebih baru. Sesuai keputusan desain:
  /// data yang sudah ada di HP menjadi master (diunggah), data cloud
  /// yang lebih baru diterapkan.
  Future<void> gabungPertama() async {
    final fs = _fs;
    final uid = _uid;
    if (fs == null || uid == null) return;

    final root = fs.collection('users').doc(uid);

    for (final tabel in DatabaseHelper.tabelData) {
      await _gabungKoleksi(tabel, root.collection(tabel));
    }
    await _gabungPengaturan(root.collection('pengaturan'));

    await _db.hitungUlangSaldo();
    await _db.bersihkanTombstoneLama();
    await _catatSinkronBerhasil();
  }

  Future<void> _gabungKoleksi(
    String tabel,
    CollectionReference<Map<String, dynamic>> col,
  ) async {
    final snapshot = await col.get();
    final remoteDocs = <String, Map<String, Object?>>{};
    for (final doc in snapshot.docs) {
      remoteDocs[doc.id] = Map<String, Object?>.from(doc.data());
    }

    final lokal = await _db.semuaBaris(tabel, termasukTerhapus: true);
    final lokalByCloud = <String, Map<String, Object?>>{};
    for (final r in lokal) {
      final cid = r['cloud_id'] as String?;
      if (cid != null) lokalByCloud[cid] = r;
    }

    // 1. Terapkan dokumen cloud yang lebih baru / belum ada di lokal.
    for (final e in remoteDocs.entries) {
      final data = e.value;
      final barisLokal = lokalByCloud[e.key];
      final diubahLokal = (barisLokal?['diubah_pada'] as int?) ?? -1;
      final diubahRemote = _intDari(data['diubah_pada']);
      if (diubahRemote > diubahLokal) {
        data['cloud_id'] = e.key;
        await _db.upsertDariCloud(tabel, data);
      }
    }

    // 2. Antri baris lokal yang lebih baru / belum ada di cloud.
    for (final r in lokal) {
      final cid = r['cloud_id'] as String?;
      if (cid == null) continue;
      final remote = remoteDocs[cid];
      final diubahLokal = (r['diubah_pada'] as int?) ?? 0;
      final diubahRemote =
          remote == null ? -1 : _intDari(remote['diubah_pada']);
      if (diubahLokal > diubahRemote) {
        final payload = Map<String, Object?>.from(r)..remove('id');
        await _db.enqueueManual(tabel, cid, payload);
      }
    }
  }

  Future<void> _gabungPengaturan(
    CollectionReference<Map<String, dynamic>> col,
  ) async {
    final snapshot = await col.get();
    final remoteDocs = <String, Map<String, Object?>>{};
    for (final doc in snapshot.docs) {
      remoteDocs[doc.id] = Map<String, Object?>.from(doc.data());
    }

    for (final kunci in DatabaseHelper.kunciPengaturanTersinkron) {
      final remote = remoteDocs[kunci];
      final lokal = await _db.barisPengaturan(kunci);
      final diubahLokal = lokal?.$2 ?? -1;

      if (remote != null) {
        final diubahRemote = _intDari(remote['diubah_pada']);
        if (diubahRemote > diubahLokal) {
          final dihapus = _intDari(remote['dihapus']) == 1;
          if (dihapus) {
            await _db.hapusNilai(kunci, dariCloud: true);
          } else {
            await _db.setNilai(
              kunci,
              remote['nilai']?.toString(),
              dariCloud: true,
              diubahPadaCloud: diubahRemote,
            );
          }
        }
      }

      // Dorong nilai lokal yang lebih baru (atau cloud belum punya).
      if (lokal != null && lokal.$1 != null) {
        final diubahRemote =
            remote == null ? -1 : _intDari(remote['diubah_pada']);
        if (lokal.$2 > diubahRemote) {
          await _db.enqueueManual('pengaturan', kunci, {
            'kunci': kunci,
            'nilai': lokal.$1,
            'dihapus': 0,
            'diubah_pada': lokal.$2,
          });
        }
      } else if (lokal == null && remote != null) {
        // Hapus lokal yang belum sampai ke cloud → dorong tombstone.
        await _db.enqueueManual('pengaturan', kunci, {
          'kunci': kunci,
          'nilai': null,
          'dihapus': 1,
          'diubah_pada': DateTime.now().millisecondsSinceEpoch,
        });
      }
    }
  }

  // ================= LISTENER REAL-TIME =================

  void _mulaiListener() {
    final fs = _fs;
    final uid = _uid;
    if (fs == null || uid == null) return;
    final root = fs.collection('users').doc(uid);

    for (final tabel in DatabaseHelper.tabelData) {
      _subs.add(
        root.collection(tabel).snapshots().listen((snap) async {
          var berubah = false;
          for (final change in snap.docChanges) {
            // hasPendingWrites = tulisan kita sendiri yang ke-echo → skip.
            if (change.doc.metadata.hasPendingWrites) continue;
            if (change.type == DocumentChangeType.removed) {
              // Dokumen dihapus betulan di cloud (perangkat lain /
              // sweep reset) → hapus baris lokal. KECUALI masih ada op
              // antrian untuk dokumen ini: edit lokal yang belum
              // terkirim menang (LWW), flush akan membuat ulang
              // dokumennya.
              if (!await _db.adaOpAntrian(tabel, change.doc.id)) {
                await _db.hapusBarisDariCloud(tabel, change.doc.id);
                berubah = true;
              }
              continue;
            }
            final dataRemote = change.doc.data();
            if (dataRemote == null) continue;
            final ok = await _terapkanDocRemote(
              tabel,
              change.doc.id,
              dataRemote,
            );
            berubah = berubah || ok;
          }
          if (berubah) {
            await _db.hitungUlangSaldo();
            _jadwalkanReloadUi();
          }
        }, onError: (_) {}),
      );
    }

    _subs.add(
      root.collection('pengaturan').snapshots().listen((snap) async {
        var berubah = false;
        for (final change in snap.docChanges) {
          if (change.doc.metadata.hasPendingWrites) continue;
          final data = change.doc.data();
          if (data == null) continue;
          final kunci = change.doc.id;
          if (!DatabaseHelper.kunciPengaturanTersinkron.contains(kunci)) {
            continue;
          }
          final lokal = await _db.barisPengaturan(kunci);
          final diubahLokal = lokal?.$2 ?? -1;
          final diubahRemote = _intDari(data['diubah_pada']);
          if (diubahRemote > diubahLokal) {
            if (_intDari(data['dihapus']) == 1) {
              await _db.hapusNilai(kunci, dariCloud: true);
            } else {
              await _db.setNilai(
                kunci,
                data['nilai']?.toString(),
                dariCloud: true,
                diubahPadaCloud: diubahRemote,
              );
            }
            berubah = true;
          }
        }
        if (berubah) _jadwalkanReloadUi();
      }, onError: (_) {}),
    );
  }

  /// Terapkan satu dokumen remote ke SQLite. Return true kalau ada perubahan.
  /// Satu dokumen rusak/tak sesuai skema TIDAK boleh menggagalkan
  /// sinkronisasi lain - dilewati saja (defense in depth; hanya pemilik
  /// akun yang bisa menulis ke dokumen ini sesuai firestore.rules).
  Future<bool> _terapkanDocRemote(
    String tabel,
    String docId,
    Map<String, Object?> data,
  ) async {
    try {
      final baris = await _db.barisDariCloudId(tabel, docId);
      final diubahLokal = (baris?['diubah_pada'] as int?) ?? -1;
      final diubahRemote = _intDari(data['diubah_pada']);
      if (diubahRemote <= diubahLokal) return false;
      data['cloud_id'] = docId;
      await _db.upsertDariCloud(tabel, data);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Debounce reload UI: perubahan remote bisa datang beruntun.
  void _jadwalkanReloadUi() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 400), () async {
      jumlahAntrian = await _db.jumlahAntrian();
      onPerubahan?.call(status, jumlahAntrian, sinkronTerakhir);
    });
  }

  // ================= FLUSH (LOKAL → CLOUD) =================

  /// Jadwalkan flush (dipanggil setiap selesai aksi tulis lokal).
  void kick({bool cepat = false}) {
    if (!_aktif) return;
    _kickTimer?.cancel();
    _kickTimer =
        Timer(Duration(milliseconds: cepat ? 200 : 1500), () => flush());
  }

  /// Kirim seluruh antrian ke Firestore (berkelompok 400 dokumen).
  /// Return true kalau antrian habis terkirim.
  Future<bool> flush() async {
    final fs = _fs;
    final uid = _uid;
    if (!_aktif || fs == null || uid == null) return false;
    if (_flushing) return false;
    _flushing = true;

    var sukses = true;
    try {
      final root = fs.collection('users').doc(uid);
      while (true) {
        final ops = await _db.ambilAntrian(batas: 400);
        if (ops.isEmpty) break;

        final batch = fs.batch();
        for (final op in ops) {
          final koleksi = op['koleksi'] as String;
          final docId = op['doc_id'] as String;
          final payload =
              jsonDecode(op['payload'] as String) as Map<String, dynamic>;
          final ref = root.collection(koleksi).doc(docId);
          if (koleksi != 'pengaturan' &&
              DatabaseHelper.tabelData.contains(koleksi) &&
              _intDari(payload['dihapus']) == 1) {
            // Baris lokal sudah dihapus (tombstone) → dokumen cloud
            // dihapus BETULAN, bukan ditandai. Data user tidak boleh
            // tertinggal di console Firebase. (Pengaturan tetap pakai
            // dokumen tombstone kecil - lihat catatan skema di atas.)
            batch.delete(ref);
          } else {
            batch.set(ref, payload);
          }
        }
        await batch.commit();

        await _db.hapusAntrian(
          ops.map((o) => o['id'] as int).toList(),
        );
        await _catatSinkronBerhasil();
      }
    } catch (_) {
      sukses = false;
    }

    _flushing = false;
    jumlahAntrian = await _db.jumlahAntrian();
    if (sukses && jumlahAntrian == 0) {
      // Antrian tuntas → coba jalankan sweep reset yang tertunda
      // ("hapus semua data" yang dilakukan saat offline).
      unawaited(_cobaSweepTertunda());
    }
    if (!sukses) {
      // Bedakan "offline" vs "error server": coba ping ringan.
      final online = await adaInternet();
      status = online ? StatusSinkron.error : StatusSinkron.offline;
    } else {
      status = jumlahAntrian > 0 ? StatusSinkron.antri : StatusSinkron.sinkron;
    }
    _lapor(status);
    return sukses;
  }

  /// Deteksi koneksi internet secara ringan.
  Future<bool> adaInternet() async {
    try {
      final hasil = await Connectivity().checkConnectivity();
      return hasil.isNotEmpty && !hasil.contains(ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  // ================= SWEEP & BERSIH-BERSIH CLOUD =================

  /// Hapus SELURUH dokumen user di cloud (semua koleksi data +
  /// pengaturan). Dipakai "Hapus semua data" supaya janji "termasuk
  /// salinan di cloud" beneran ditepati - termasuk dokumen yang tidak
  /// punya baris lokal lagi (tombstone lama, data dari perangkat lain).
  ///
  /// Return true kalau tuntas. Kalau gagal / sync belum aktif (belum
  /// login-verifikasi, offline), flag lokal `reset_cloud_pending`
  /// dipasang dan sweep diulang otomatis saat [mulai] / setelah flush
  /// sukses. Antrian tombstone dari [DatabaseHelper.hapusSemua] tetap
  /// dikirim flush sebagai DELETE - jadi dobel jaring pengaman.
  Future<bool> bersihkanCloudPenuh() async {
    final fs = _fs;
    final uid = _uid;
    if (!_aktif || fs == null || uid == null) {
      await _db.setNilai('reset_cloud_pending', '1');
      return false;
    }
    try {
      final root = fs.collection('users').doc(uid);
      for (final k in [...DatabaseHelper.tabelData, 'pengaturan']) {
        // Sapu bertahap 400 dokumen per batch (batas Firestore 500).
        while (true) {
          final snap = await root.collection(k).limit(400).get();
          if (snap.docs.isEmpty) break;
          final batch = fs.batch();
          for (final d in snap.docs) {
            batch.delete(d.reference);
          }
          await batch.commit();
        }
      }
      await _db.hapusNilai('reset_cloud_pending');
      return true;
    } catch (_) {
      await _db.setNilai('reset_cloud_pending', '1');
      return false;
    }
  }

  /// Jalankan sweep reset yang tertunda (kalau ada). Aman dipanggil
  /// berkali-kali; tidak jalan ganda (guard [_menyapu]).
  Future<void> _cobaSweepTertunda() async {
    if (!_aktif || _menyapu) return;
    if ((await _db.getNilai('reset_cloud_pending')) != '1') return;
    _menyapu = true;
    try {
      await bersihkanCloudPenuh();
    } finally {
      _menyapu = false;
    }
  }

  /// Bersihkan dokumen tombstone peninggalan versi lama di cloud.
  ///
  /// Versi sebelumnya menset dokumen `dihapus: 1` alih-alih menghapus -
  /// akibatnya data yang "sudah dihapus" tetap terlihat (dan tetap
  /// berisi datanya) di console Firebase. Ini menyapunya:
  /// - Koleksi data: SEMUA dokumen dihapus=1 dihapus (peninggalan lama;
  ///   versi baru tidak pernah menulis dokumen seperti ini lagi).
  /// - Pengaturan: hanya yang sudah lewat 30 hari (tombstone pengaturan
  ///   masih jadi sinyal LWW untuk perangkat lain selama itu).
  Future<void> _bersihkanTombstoneCloud() async {
    final fs = _fs;
    final uid = _uid;
    if (!_aktif || fs == null || uid == null) return;
    final root = fs.collection('users').doc(uid);
    final batas30Hari = DateTime.now()
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;

    // Filter `dihapus == 1` di server (index satu field, otomatis);
    // sisa syarat (mis. usia) disaring di klien.
    Future<void> sapu(CollectionReference<Map<String, dynamic>> col,
        bool Function(Map<String, dynamic>) layak) async {
      final snap = await col.where('dihapus', isEqualTo: 1).limit(450).get();
      final sasaran = snap.docs.where((d) => layak(d.data())).toList();
      if (sasaran.isEmpty) return;
      final batch = fs.batch();
      for (final d in sasaran) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }

    try {
      for (final tabel in DatabaseHelper.tabelData) {
        await sapu(
          root.collection(tabel),
          (data) => _intDari(data['dihapus']) == 1,
        );
      }
      await sapu(
        root.collection('pengaturan'),
        (data) =>
            _intDari(data['dihapus']) == 1 &&
            _intDari(data['diubah_pada']) < batas30Hari,
      );
    } catch (_) {
      // Gagal (offline / aturan) → coba lagi lain kali app menyala.
    }
  }

  Future<void> _catatSinkronBerhasil() async {
    final now = DateTime.now();
    sinkronTerakhir = now;
    await _db.setNilai('last_sync', now.millisecondsSinceEpoch.toString());
    // Login dianggap "terverifikasi online" tiap berhasil kirim.
    await _db.setNilai('last_auth_ok', now.millisecondsSinceEpoch.toString());
  }

  void _lapor(StatusSinkron s) {
    status = s;
    onPerubahan?.call(s, jumlahAntrian, sinkronTerakhir);
  }
}
