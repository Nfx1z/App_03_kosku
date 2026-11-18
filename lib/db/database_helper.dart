import 'dart:convert';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/kiriman.dart';
import '../models/target.dart';
import '../models/transaksi.dart';
import '../models/utang.dart';

class SaldoInfo {
  final int pegangan;
  final int kantong;
  const SaldoInfo(this.pegangan, this.kantong);
}

/// UUID v4 sederhana tanpa package tambahan - ID dokumen cloud.
String uuidBaru() {
  final r = Random.secure();
  const hex = '0123456789abcdef';
  String b(int n) => List.generate(n, (_) => hex[r.nextInt(16)]).join();
  return '${b(8)}-${b(4)}-4${b(3)}-a${b(3)}-${b(12)}';
}

/// Semua akses database SQLite lokal dikumpulkan di sini.
///
/// Prinsip fase 2: **lokal dulu (cepat), cloud belakangan**.
/// Setiap tulis lokal otomatis mengantri di tabel `antrian`;
/// SyncService mengirim antrian itu ke Firestore saat online.
/// Tulis dari arah cloud memakai metode `*DariCloud` (tanpa antrian).
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;
  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  /// Tabel data yang disinkronkan (nama tabel = nama koleksi Firestore).
  static const tabelData = ['transaksi', 'kiriman', 'target', 'utang'];

  /// Kunci pengaturan yang ikut disinkronkan.
  /// API key Gemini TIDAK di sini (disimpan di secure storage, perangkat-only).
  static const kunciPengaturanTersinkron = {
    'sudah_setup',
    'batas_harian',
    'model_gemini',
    'bahasa',
    // Catatan pemakaian tabungan hemat (JSON) - ikut sync supaya
    // saldo tabungan konsisten antar perangkat.
    'tabungan_terpakai',
    // Hemat bulan-bulan tertutup yang dibekukan (JSON {"yyyy-MM": n})
    // - dasar bawaan tabungan bulan berjalan, ikut sync.
    'tabungan_riwayat',
  };

  Future<Database> _init() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'saku.db'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transaksi (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            jenis TEXT NOT NULL,
            jumlah INTEGER NOT NULL,
            kategori TEXT,
            catatan TEXT,
            sumber TEXT NOT NULL DEFAULT 'manual',
            terkait_id INTEGER,
            dibuat_pada TEXT NOT NULL,
            cloud_id TEXT,
            dihapus INTEGER NOT NULL DEFAULT 0,
            diubah_pada INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_transaksi_dibuat ON transaksi(dibuat_pada)');
        await db.execute(
            'CREATE INDEX idx_transaksi_cloud ON transaksi(cloud_id)');
        await db.execute('''
          CREATE TABLE saldo (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            pegangan INTEGER NOT NULL DEFAULT 0,
            kantong INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.insert('saldo', {'id': 1, 'pegangan': 0, 'kantong': 0});
        await db.execute('''
          CREATE TABLE kiriman (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nominal INTEGER NOT NULL,
            tanggal_datang TEXT NOT NULL,
            catatan TEXT,
            status TEXT NOT NULL DEFAULT 'menunggu',
            dibuat_pada TEXT NOT NULL,
            cloud_id TEXT,
            dihapus INTEGER NOT NULL DEFAULT 0,
            diubah_pada INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE target (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nama TEXT NOT NULL,
            nominal INTEGER NOT NULL,
            tanggal TEXT,
            status TEXT NOT NULL DEFAULT 'aktif',
            dibuat_pada TEXT NOT NULL,
            cloud_id TEXT,
            dihapus INTEGER NOT NULL DEFAULT 0,
            diubah_pada INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE utang (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            arah TEXT NOT NULL,
            pihak TEXT NOT NULL,
            nominal INTEGER NOT NULL,
            jatuh_tempo TEXT,
            catatan TEXT,
            status TEXT NOT NULL DEFAULT 'aktif',
            dibuat_pada TEXT NOT NULL,
            cloud_id TEXT,
            dihapus INTEGER NOT NULL DEFAULT 0,
            diubah_pada INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE pengaturan (
            kunci TEXT PRIMARY KEY,
            nilai TEXT,
            diubah_pada INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await _buatTabelAntrian(db);
      },
      onUpgrade: (db, lama, baru) async {
        if (lama < 2) {
          for (final t in tabelData) {
            await db.execute('ALTER TABLE $t ADD COLUMN cloud_id TEXT');
            await db.execute(
                'ALTER TABLE $t ADD COLUMN dihapus INTEGER NOT NULL DEFAULT 0');
            await db.execute(
                'ALTER TABLE $t ADD COLUMN diubah_pada INTEGER NOT NULL DEFAULT 0');
            // Backfill: data lama dianggap berubah sesuai tanggal buatnya.
            await db.execute('''
              UPDATE $t SET
                cloud_id = 'm_' || $t || '_' || id,
                diubah_pada = CAST(COALESCE(
                  strftime('%s', REPLACE(dibuat_pada, 'T', ' ')), 0
                ) AS INTEGER) * 1000
            ''');
          }
          await db.execute(
              'ALTER TABLE pengaturan ADD COLUMN diubah_pada INTEGER NOT NULL DEFAULT 0');
          await db.execute('UPDATE pengaturan SET diubah_pada = ?',
              [DateTime.now().millisecondsSinceEpoch]);
          await _buatTabelAntrian(db);
        }
      },
    );
  }

  Future<void> _buatTabelAntrian(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS antrian (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        koleksi TEXT NOT NULL,
        doc_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        UNIQUE(koleksi, doc_id)
      )
    ''');
  }

  // ================= INTI ANTRIAN SYNC =================

  /// Masukkan satu operasi ke antrian (menimpa op lama untuk dokumen sama).
  Future<void> _enqueue(
    String koleksi,
    String docId,
    Map<String, Object?> payload,
  ) async {
    final db = await database;
    await db.insert(
      'antrian',
      {
        'koleksi': koleksi,
        'doc_id': docId,
        'payload': jsonEncode(payload),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Antri baris tabel data (payload = isi baris tanpa kolom id lokal).
  Future<void> _enqueueBaris(String tabel, int id) async {
    final db = await database;
    final rows = await db.query(tabel, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final payload = Map<String, Object?>.from(rows.first)..remove('id');
    final cloudId = payload['cloud_id'] as String?;
    if (cloudId == null) return;
    await _enqueue(tabel, cloudId, payload);
  }

  /// Insert lokal: pasang cloud_id + stempel waktu, lalu antri.
  Future<int> _insertLokal(String tabel, Map<String, Object?> m) async {
    final db = await database;
    m['cloud_id'] ??= uuidBaru();
    m['dihapus'] = (m['dihapus'] == null || m['dihapus'] == 0) ? 0 : 1;
    m['diubah_pada'] = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert(tabel, m);
    await _enqueueBaris(tabel, id);
    return id;
  }

  /// Update lokal: stempel waktu baru, lalu antri ulang baris penuh.
  Future<void> _updateLokal(
    String tabel,
    int id,
    Map<String, Object?> perubahan,
  ) async {
    final db = await database;
    perubahan['diubah_pada'] = DateTime.now().millisecondsSinceEpoch;
    await db.update(tabel, perubahan, where: 'id = ?', whereArgs: [id]);
    await _enqueueBaris(tabel, id);
  }

  /// Hapus = tombstone (baris ditandai, bukan dibuang) supaya penghapusan
  /// ikut tersinkron ke perangkat lain. Dibersihkan setelah 30 hari.
  Future<void> _tombstone(String tabel, int id) async {
    await _updateLokal(tabel, id, {'dihapus': 1});
  }

  // ================= SALDO =================

  Future<SaldoInfo> ambilSaldo() async {
    final db = await database;
    final rows = await db.query('saldo', where: 'id = 1');
    if (rows.isEmpty) return const SaldoInfo(0, 0);
    return SaldoInfo(
      rows.first['pegangan'] as int,
      rows.first['kantong'] as int,
    );
  }

  /// Hitung ulang saldo dari seluruh buku kas (dipakai setelah merge cloud).
  Future<void> hitungUlangSaldo() async {
    final db = await database;
    final rows = await db.query('transaksi', where: 'dihapus = 0');
    var pegangan = 0;
    var kantong = 0;
    for (final r in rows) {
      final t = Transaksi.dariMap(r);
      pegangan += t.efekPegangan;
      kantong += t.efekKantong;
    }
    await db.update(
      'saldo',
      {'pegangan': pegangan, 'kantong': kantong},
      where: 'id = 1',
    );
  }

  // ================= TRANSAKSI =================

  /// Catat transaksi + update saldo secara atomik + antri sync.
  /// Return id baris baru.
  Future<int> catatTransaksi(Transaksi t) async {
    final db = await database;
    final m = t.keMap();
    m['cloud_id'] = t.cloudId ?? uuidBaru();
    m['diubah_pada'] = DateTime.now().millisecondsSinceEpoch;
    final id = await db.transaction((txn) async {
      final idBaru = await txn.insert('transaksi', m);
      await txn.rawUpdate(
        'UPDATE saldo SET pegangan = pegangan + ?, kantong = kantong + ? '
        'WHERE id = 1',
        [t.efekPegangan, t.efekKantong],
      );
      return idBaru;
    });
    await _enqueueBaris('transaksi', id);
    return id;
  }

  Future<List<Transaksi>> transaksiAntara(
    DateTime mulai,
    DateTime akhir,
  ) async {
    final db = await database;
    final rows = await db.query(
      'transaksi',
      where: 'dihapus = 0 AND dibuat_pada >= ? AND dibuat_pada < ?',
      whereArgs: [mulai.toIso8601String(), akhir.toIso8601String()],
      orderBy: 'dibuat_pada DESC',
    );
    return rows.map(Transaksi.dariMap).toList();
  }

  Future<List<Transaksi>> transaksiJenis(List<JenisTransaksi> jenis) async {
    final db = await database;
    final nilai = jenis.map((j) => j.nilai).toList();
    final rows = await db.query(
      'transaksi',
      where:
          'dihapus = 0 AND jenis IN (${List.filled(nilai.length, '?').join(',')})',
      whereArgs: nilai,
      orderBy: 'dibuat_pada DESC',
    );
    return rows.map(Transaksi.dariMap).toList();
  }

  Future<List<Transaksi>> semuaTransaksi({int batas = 5000}) async {
    final db = await database;
    final rows = await db.query(
      'transaksi',
      where: 'dihapus = 0',
      orderBy: 'dibuat_pada DESC',
      limit: batas,
    );
    return rows.map(Transaksi.dariMap).toList();
  }

  Future<int> jumlahPengeluaranAntara(DateTime mulai, DateTime akhir) async {
    final db = await database;
    final rows = await db.rawQuery(
      "SELECT COALESCE(SUM(jumlah), 0) AS total FROM transaksi "
      "WHERE dihapus = 0 AND jenis = 'pengeluaran' "
      "AND dibuat_pada >= ? AND dibuat_pada < ?",
      [mulai.toIso8601String(), akhir.toIso8601String()],
    );
    return (rows.first['total'] as int?) ?? 0;
  }

  /// Tanggal transaksi (belum terhapus) paling awal - dipakai AppState
  /// untuk menentukan hari pertama pemantauan tabungan hemat, supaya
  /// hari-hari sebelum app dipakai tidak dihitung sebagai hemat.
  Future<DateTime?> transaksiPertama() async {
    final db = await database;
    final rows = await db.query('transaksi',
        where: 'dihapus = 0', orderBy: 'dibuat_pada ASC', limit: 1);
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['dibuat_pada'] as String);
  }

  /// Ubah transaksi lama (salah catat). Hanya field yang diberikan;
  /// id / cloud_id / jenis tidak pernah diubah. Setelah update, saldo
  /// dihitung ULANG dari seluruh buku kas supaya pegangan & kantong
  /// selalu konsisten. Baris ikut diantri ke cloud (diubah_pada baru).
  Future<void> perbaruiTransaksi(
    int id, {
    int? jumlah,
    String? catatan,
    bool hapusCatatan = false,
    String? kategoriNilai,
    DateTime? dibuatPada,
  }) async {
    final perubahan = <String, Object?>{
      if (jumlah != null) 'jumlah': jumlah,
      if (catatan != null || hapusCatatan) 'catatan': catatan,
      if (kategoriNilai != null) 'kategori': kategoriNilai,
      if (dibuatPada != null) 'dibuat_pada': dibuatPada.toIso8601String(),
    };
    if (perubahan.isEmpty) return;
    await _updateLokal('transaksi', id, perubahan);
    await hitungUlangSaldo();
  }

  /// Hapus transaksi (tombstone, ikut sync) + saldo dihitung ulang.
  Future<void> hapusTransaksi(int id) async {
    await _tombstone('transaksi', id);
    await hitungUlangSaldo();
  }

  // ================= KIRIMAN =================

  Future<int> simpanKiriman(Kiriman k) => _insertLokal('kiriman', k.keMap());

  Future<void> perbaruiStatusKiriman(int id, StatusKiriman status) =>
      _updateLokal('kiriman', id, {'status': status.name});

  Future<void> hapusKiriman(int id) => _tombstone('kiriman', id);

  Future<List<Kiriman>> semuaKiriman() async {
    final db = await database;
    // Urutan rapi: yang MENUNGGU duluan (paling dekat tanggalnya di
    // atas - termasuk yang lewat tanggal), yang sudah masuk ke bawah.
    final rows = await db.query('kiriman',
        where: 'dihapus = 0',
        orderBy: "status = 'masuk', tanggal_datang ASC, id ASC");
    return rows.map(Kiriman.dariMap).toList();
  }

  // ================= TARGET =================

  Future<int> simpanTarget(TargetBeli t) => _insertLokal('target', t.keMap());

  Future<void> perbaruiStatusTarget(int id, StatusTarget status) =>
      _updateLokal('target', id, {'status': status.name});

  Future<void> hapusTarget(int id) => _tombstone('target', id);

  Future<List<TargetBeli>> semuaTarget() async {
    final db = await database;
    // Urutan rapi: yang masih BERJALAN duluan (deadline terdekat di
    // atas, tanpa tanggal menyusul), yang sudah tercapai ke bawah.
    final rows = await db.query('target',
        where: 'dihapus = 0',
        orderBy: "status = 'tercapai', tanggal IS NULL, tanggal ASC, id DESC");
    return rows.map(TargetBeli.dariMap).toList();
  }

  // ================= UTANG =================

  Future<int> simpanUtang(Utang u) => _insertLokal('utang', u.keMap());

  Future<void> perbaruiStatusUtang(int id, StatusUtang status) =>
      _updateLokal('utang', id, {'status': status.name});

  Future<void> hapusUtang(int id) => _tombstone('utang', id);

  Future<List<Utang>> semuaUtang() async {
    final db = await database;
    // Urutan rapi: yang AKTIF duluan (jatuh tempo terdekat di atas,
    // tanpa tempo menyusul), yang lunas ke bawah.
    final rows = await db.query('utang',
        where: 'dihapus = 0',
        orderBy: "status = 'lunas', jatuh_tempo IS NULL, jatuh_tempo ASC, id DESC");
    return rows.map(Utang.dariMap).toList();
  }

  // ================= PENGATURAN (key-value) =================

  Future<String?> getNilai(String kunci) async {
    final db = await database;
    final rows = await db
        .query('pengaturan', where: 'kunci = ?', whereArgs: [kunci]);
    if (rows.isEmpty) return null;
    return rows.first['nilai'] as String?;
  }

  Future<void> setNilai(String kunci, String? nilai,
      {bool dariCloud = false, int? diubahPadaCloud}) async {
    final db = await database;
    final now = diubahPadaCloud ?? DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'pengaturan',
      {'kunci': kunci, 'nilai': nilai, 'diubah_pada': now},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (!dariCloud && kunciPengaturanTersinkron.contains(kunci)) {
      await _enqueue('pengaturan', kunci, {
        'kunci': kunci,
        'nilai': nilai,
        'dihapus': 0,
        'diubah_pada': now,
      });
    }
  }

  Future<void> hapusNilai(String kunci, {bool dariCloud = false}) async {
    final db = await database;
    await db.delete('pengaturan', where: 'kunci = ?', whereArgs: [kunci]);
    if (!dariCloud && kunciPengaturanTersinkron.contains(kunci)) {
      await _enqueue('pengaturan', kunci, {
        'kunci': kunci,
        'nilai': null,
        'dihapus': 1,
        'diubah_pada': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  /// Baris pengaturan: (nilai, diubah_pada). Null kalau kunci tidak ada.
  /// Dipakai SyncService untuk LWW pengaturan.
  Future<(String?, int)?> barisPengaturan(String kunci) async {
    final db = await database;
    final rows = await db
        .query('pengaturan', where: 'kunci = ?', whereArgs: [kunci]);
    if (rows.isEmpty) return null;
    return (
      rows.first['nilai'] as String?,
      (rows.first['diubah_pada'] as int?) ?? 0,
    );
  }

  // ================= ANTRIAN (dibaca SyncService) =================

  Future<List<Map<String, Object?>>> ambilAntrian({int batas = 400}) async {
    final db = await database;
    final rows =
        await db.query('antrian', orderBy: 'id ASC', limit: batas);
    return rows;
  }

  Future<void> hapusAntrian(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.delete(
      'antrian',
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }

  Future<int> jumlahAntrian() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM antrian');
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Antri payload manual (dipakai SyncService saat merge:
  /// baris lokal yang lebih baru dari cloud).
  Future<void> enqueueManual(
    String koleksi,
    String docId,
    Map<String, Object?> payload,
  ) =>
      _enqueue(koleksi, docId, payload);

  // ================= JEMBATAN CLOUD → LOKAL =================

  /// Semua baris satu tabel (untuk merge). Termasuk tombstone kalau
  /// [termasukTerhapus] - dipakai SyncService membandingkan LWW.
  Future<List<Map<String, Object?>>> semuaBaris(String tabel,
      {bool termasukTerhapus = false}) async {
    final db = await database;
    if (!tabelData.contains(tabel)) return [];
    return db.query(tabel,
        where: termasukTerhapus ? null : 'dihapus = 0');
  }

  /// Cari satu baris berdasarkan cloud_id (untuk LWW).
  Future<Map<String, Object?>?> barisDariCloudId(
      String tabel, String cloudId) async {
    final db = await database;
    if (!tabelData.contains(tabel)) return null;
    final rows = await db
        .query(tabel, where: 'cloud_id = ?', whereArgs: [cloudId], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Hapus permanen satu baris berdasarkan cloud_id. Dipanggil SyncService
  /// saat dokumen di cloud terhapus betulan (DELETE, bukan tombstone).
  /// TIDAK mengantri apa pun - penghapusan sudah terjadi di cloud.
  /// Return true kalau ada baris yang benar-benar terhapus.
  Future<bool> hapusBarisDariCloud(String tabel, String cloudId) async {
    final db = await database;
    if (!tabelData.contains(tabel)) return false;
    final n =
        await db.delete(tabel, where: 'cloud_id = ?', whereArgs: [cloudId]);
    return n > 0;
  }

  /// Masih ada op antrian untuk dokumen ini? (edit lokal belum terkirim).
  /// Dipakai SyncService: dokumen yang sudah dihapus di cloud tapi punya
  /// edit lokal yang belum terkirim TIDAK dihapus lokal - edit itu yang
  /// menang (LWW), flush akan membuat ulang dokumennya.
  Future<bool> adaOpAntrian(String koleksi, String docId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT 1 FROM antrian WHERE koleksi = ? AND doc_id = ? LIMIT 1',
      [koleksi, docId],
    );
    return rows.isNotEmpty;
  }

  /// Tulis data dari cloud ke tabel data (tanpa antri, tanpa ubah saldo -
  /// saldo dihitung ulang terpisah lewat [hitungUlangSaldo]).
  Future<void> upsertDariCloud(
      String tabel, Map<String, Object?> data) async {
    final db = await database;
    if (!tabelData.contains(tabel)) return;
    final cloudId = data['cloud_id'] as String?;
    if (cloudId == null) return;
    final baris = Map<String, Object?>.from(data)..remove('id');
    final ada = await db
        .query(tabel, where: 'cloud_id = ?', whereArgs: [cloudId], limit: 1);
    if (ada.isNotEmpty) {
      await db.update(tabel, baris, where: 'cloud_id = ?', whereArgs: [cloudId]);
    } else {
      await db.insert(tabel, baris);
    }
  }

  /// Bersihkan tombstone yang sudah tua (default 30 hari) dari tabel lokal.
  Future<void> bersihkanTombstoneLama({
    Duration usia = const Duration(days: 30),
  }) async {
    final db = await database;
    final batas = DateTime.now().subtract(usia).millisecondsSinceEpoch;
    for (final t in tabelData) {
      await db.delete(t,
          where: 'dihapus = 1 AND diubah_pada < ?', whereArgs: [batas]);
    }
  }

  // ================= RESET =================

  /// Hapus semua data.
  /// [kirimTombstone] = true  → "Hapus semua data" user: penghapusan juga
  ///   diantri ke cloud (flush mengirim DELETE betulan per dokumen) DAN
  ///   SyncService menyapu bersih seluruh koleksi cloud (lihat
  ///   [SyncService.bersihkanCloudPenuh]) - termasuk dokumen yang sudah
  ///   tidak punya baris lokal (tombstone lama).
  /// [kirimTombstone] = false → wipe lokal demi keamanan (HP hilang / auto-wipe):
  ///   data di cloud TETAP ADA supaya bisa dipulihkan saat login ulang.
  Future<void> hapusSemua({required bool kirimTombstone}) async {
    final db = await database;

    if (kirimTombstone) {
      // Tombstone semua baris hidup, satu per satu ke antrian.
      for (final t in tabelData) {
        final rows = await db
            .query(t, where: 'dihapus = 0', columns: ['id']);
        for (final r in rows) {
          await _tombstone(t, r['id'] as int);
        }
      }
    } else {
      for (final t in tabelData) {
        await db.delete(t);
      }
      await db.delete('antrian');
    }

    // Pengaturan tersinkron ikut di-reset (tombstone / hapus lokal).
    for (final kunci in kunciPengaturanTersinkron) {
      final ada = await getNilai(kunci);
      if (ada != null) {
        await hapusNilai(kunci, dariCloud: !kirimTombstone);
      }
    }

    await db.update('saldo', {'pegangan': 0, 'kantong': 0}, where: 'id = 1');
  }
}
