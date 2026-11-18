import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/kiriman.dart';
import '../models/target.dart';
import '../models/transaksi.dart';
import '../models/utang.dart';
import '../services/auth_service.dart';
import '../services/gemini_service.dart';
import '../services/notifikasi_service.dart';
import '../services/sync_service.dart';
import '../utils/format.dart';
import '../utils/hitung.dart';
import '../utils/kunci_env.dart';
import '../utils/teks.dart';

/// Satu baris pengingat di kartu "Perlu perhatian" (home).
class Perhatian {
  final IconData ikon;
  final String teks;
  const Perhatian(this.ikon, this.teks);
}

/// Satu catatan "tabungan hemat dipakai untuk menutup kelebihan jatah
/// harian". Disimpan sebagai JSON di tabel pengaturan (kunci
/// `tabungan_terpakai`) dan ikut disinkronkan. Catatan TIDAK pernah
/// dipangkas: pemakaian mengurangi saldo tabungan selamanya.
class PemakaianTabungan {
  final DateTime waktu;
  final int jumlah;
  final String? catatan;
  const PemakaianTabungan(this.waktu, this.jumlah, this.catatan);

  Map<String, Object?> keMap() => {
        't': waktu.millisecondsSinceEpoch,
        'n': jumlah,
        'c': catatan,
      };

  static PemakaianTabungan dariMap(Map<String, Object?> m) =>
      PemakaianTabungan(
        DateTime.fromMillisecondsSinceEpoch((m['t'] as num).toInt()),
        (m['n'] as num).toInt(),
        m['c'] as String?,
      );
}

/// Hasil pemeriksaan [AppState.jagaSaldo] untuk transaksi yang
/// mengurangi saldo pegangan.
enum HasilJagaSaldo {
  /// Boleh langsung dicatat.
  aman,

  /// Masih cukup, tapi sisanya di bawah perkiraan kebutuhan hidup -
  /// UI menampilkan konfirmasi "tetap lanjut?".
  kritis,

  /// Saldo akan minus - WAJIB ditolak (saldo tidak boleh minus).
  kurang,
}

/// State terpusat seluruh aplikasi.
/// Semua perubahan saldo WAJIB lewat sini supaya konsisten.
///
/// Fase 2 menambahkan: akun Firebase (email/sandi), status sinkronisasi,
/// kunci offline (masa tenggang), dan bahasa UI (id/en).
class AppState extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  // ----- state dasar -----
  bool siap = false;
  bool sudahSetup = false;

  /// Sudah lihat layar sambutan (sekali di awal, perangkat lokal,
  /// tidak ikut sync). Layar sambutan tidak muncul lagi setelahnya.
  bool sudahSambutan = false;
  int saldoPegangan = 0;
  int kantongDarurat = 0;
  List<Transaksi> transaksiHariIni = [];
  List<Kiriman> kirimanList = [];
  List<TargetBeli> targetList = [];
  List<Utang> utangList = [];

  /// Batas pengeluaran per hari. Null = otomatis (saldo / sisa hari).
  int? batasHarian;

  /// Kunci Gemini dibundel saat build lewat --dart-define
  /// (lihat utils/kunci_env.dart) dan dipakai bergantian kalau ada dua.
  String modelGemini = 'gemini-3.5-flash-lite';

  int _rataPengeluaran7Hari = 0;
  int get rataPengeluaran7Hari => _rataPengeluaran7Hari;

  /// Rincian pengeluaran per hari untuk BULAN berjalan (tanggal 1
  /// sampai kemarin - hari ini belum dihitung karena masih berjalan).
  /// Awal rincian dibatasi hari pertama app memantau uang. Dasar
  /// hitung tabungan hemat bulan ini (rollover sisa jatah harian).
  List<(DateTime, int)> _rincianBulanIni = [];

  /// Hemat bulan-bulan TERTUTUP yang sudah dibekukan (kunci
  /// `tabungan_riwayat`, JSON {"yyyy-MM": nominal}). Tabungan dari
  /// bulan-bulan sebelumnya TERBAWA terus sampai dipakai - tidak
  /// hangus saat ganti bulan.
  Map<String, int> _tabunganRiwayat = {};

  /// Catatan pemakaian tabungan hemat (menutup kelebihan jatah
  /// harian). Semua catatan dipertahankan dan mengurangi saldo
  /// tabungan selamanya.
  List<PemakaianTabungan> _pemakaianTabungan = [];

  /// Splash pembuka SETIAP sesi (runtime saja, tidak dipersist).
  /// Digerakkan LayarSplash setelah animasi brand + data siap.
  bool splashSelesai = false;

  // ----- fase 2: cloud -----
  /// True kalau Firebase berhasil diinisialisasi (flutterfire configure).
  final bool cloudSiap;

  AuthService? _auth;
  bool masukAkunState = false;
  String? emailAkun;

  /// True kalau email akun sudah diverifikasi lewat link di email.
  /// Sinkronisasi cloud baru AKTIF setelah email terverifikasi;
  /// aplikasi sendiri tetap jalan penuh secara lokal tanpa menunggu.
  bool emailTerverifikasi = false;

  /// True = sesi kedaluwarsa (offline terlalu lama) → app terkunci.
  bool terkunci = false;

  /// True kalau auto-wipe sudah menghapus data lokal saat terkunci
  /// (untuk pesan yang tepat di layar kunci).
  bool dataTerhapusLokal = false;

  /// Berapa hari login tetap aktif tanpa internet.
  int graceHari = 7;

  /// Hapus data lokal saat sesi kedaluwarsa (default: mati).
  bool autoWipe = false;

  /// Pengingat "catat pengeluaran" tiap malam (default: nyala).
  /// Preferensi perangkat - tidak ikut sync.
  bool notifHarian = true;

  /// Jam pengingat ("HH:MM", ikut jam HP): pagi = kiriman / utang /
  /// target (default 08.00), malam = catat pengeluaran (default 20.00).
  /// Bisa diubah user di Pengaturan (time picker).
  String jamNotifPagi = '08:00';
  String jamNotifMalam = '20:00';

  StatusSinkron statusSinkron = StatusSinkron.lokalSaja;
  int antrianSinkron = 0;
  DateTime? sinkronTerakhir;

  // ----- bagikan dari app lain (T16) -----
  /// Foto yang di-share dari WhatsApp/galeri: diarahkan ke ScanScreen.
  /// Null = tidak ada. Di-nol-kan setelah diambil HomeScreen.
  Uint8List? gambarBagikan;

  /// Teks yang di-share dari app lain: diarahkan ke input NL di Home.
  String? teksBagikan;

  bool _sudahCekKunci = false;

  AppState({required this.cloudSiap}) {
    if (cloudSiap) {
      _auth = AuthService();
      _auth!.perubahanUser.listen(_saatUserBerubah);
    }
    SyncService.instance.onPerubahan = (status, antrian, terakhir) {
      statusSinkron = status;
      antrianSinkron = antrian;
      sinkronTerakhir = terakhir;
      notifyListeners();
    };
  }

  /// Dipanggil saat bootstrap dan setelah setiap perubahan data.
  Future<void> muatSemua() async {
    if (!_sudahCekKunci) {
      await cekKunciOffline();
      _sudahCekKunci = true;
    }

    final saldo = await _db.ambilSaldo();
    saldoPegangan = saldo.pegangan;
    kantongDarurat = saldo.kantong;

    final kini = DateTime.now();
    final awalHari = DateTime(kini.year, kini.month, kini.day);
    transaksiHariIni = await _db.transaksiAntara(
      awalHari,
      awalHari.add(const Duration(days: 1)),
    );
    kirimanList = await _db.semuaKiriman();
    targetList = await _db.semuaTarget();
    utangList = await _db.semuaUtang();

    final batasTersimpan = await _db.getNilai('batas_harian');
    batasHarian =
        batasTersimpan == null ? null : int.tryParse(batasTersimpan);

    final modelTersimpan = await _db.getNilai('model_gemini');
    modelGemini = modelTersimpan ?? 'gemini-3.5-flash-lite';

    final bahasaTersimpan = await _db.getNilai('bahasa');
    // Default bahasa = Indonesia; pilihan 'en' yang pernah disimpan tetap
    // dihormati (pengguna yang sengaja pilih English tidak mendapati UI
    // berubah sendiri).
    T.bahasa = bahasaTersimpan == 'en' ? 'en' : 'id';

    final graceTersimpan = await _db.getNilai('grace_offline_hari');
    graceHari = int.tryParse(graceTersimpan ?? '') ?? 7;

    autoWipe = (await _db.getNilai('auto_wipe')) == '1';
    notifHarian = (await _db.getNilai('notif_harian')) != '0';
    jamNotifPagi = await _db.getNilai('jam_notif_pagi') ?? '08:00';
    jamNotifMalam = await _db.getNilai('jam_notif_malam') ?? '20:00';

    final setup = await _db.getNilai('sudah_setup');
    sudahSetup = setup == '1';

    final sambutan = await _db.getNilai('sudah_sambutan');
    sudahSambutan = sambutan == '1';

    // Pemakaian tabungan hemat (JSON di tabel pengaturan, ikut sync).
    // Semua catatan dipertahankan - pemakaian mengurangi saldo
    // tabungan selamanya (tidak ada pangkasan 7 hari lagi).
    _pemakaianTabungan = await _muatPemakaianTabungan();

    final total7Hari = await _db.jumlahPengeluaranAntara(
      awalHari.subtract(const Duration(days: 7)),
      awalHari.add(const Duration(days: 1)),
    );
    _rataPengeluaran7Hari = total7Hari ~/ 7;

    // ---- Tabungan hemat: jendela BULAN (bukan 7 hari) ----
    // Hemat bulan berjalan dihitung dari tanggal 1 sampai kemarin;
    // hemat bulan-bulan sebelumnya sudah dibekukan di riwayat dan
    // terbawa terus. Mulai pantau = aktivitas pertama user, supaya
    // hari-hari sebelum app dipakai tidak jadi tabungan palsu.
    _tabunganRiwayat = await _muatRiwayatTabungan();
    final transaksiAwal = await _db.transaksiPertama();
    final mulaiPantau = _cariMulaiPantau(transaksiAwal);
    if (mulaiPantau == null) {
      _rincianBulanIni = [];
    } else {
      final awalBulan = DateTime(kini.year, kini.month, 1);
      await _kunciBulanTertutup(mulaiPantau, awalBulan);
      final mulaiRincian =
          mulaiPantau.isAfter(awalBulan) ? mulaiPantau : awalBulan;
      final daftarBulanIni = await _db.transaksiAntara(
        mulaiRincian,
        awalHari,
      );
      final perHari = <String, int>{};
      for (final t in daftarBulanIni) {
        if (t.jenis != JenisTransaksi.pengeluaran) continue;
        final k = kunciHari(t.dibuatPada);
        perHari[k] = (perHari[k] ?? 0) + t.jumlah;
      }
      final kemarin = awalHari.subtract(const Duration(days: 1));
      _rincianBulanIni = [
        for (var d = mulaiRincian;
            !d.isAfter(kemarin);
            d = d.add(const Duration(days: 1)))
          (d, perHari[kunciHari(d)] ?? 0),
      ];
    }

    // Kunci Gemini adalah konstanta build (--dart-define), bukan data
    // user: tidak ada yang perlu dimuat dari storage.
    _bangunPoolGemini();

    antrianSinkron = await _db.jumlahAntrian();
    if (SyncService.instance.aktif) {
      SyncService.instance.kick();
    }

    siap = true;
    notifyListeners();

    // Pengingat sistem (kiriman / utang / catat harian) dijadwalkan
    // ulang kalau datanya berubah - murah, ada penjaga tanda tangan di
    // dalam servicenya.
    NotifikasiService.instance.sinkronJadwal(
      harianAktif: notifHarian,
      kiriman: kirimanList,
      utang: utangList,
      target: targetList,
      saldoPegangan: saldoPegangan,
      jamPagi: jamNotifPagi,
      jamMalam: jamNotifMalam,
    );
  }

  // ================= AKUN & KUNCI OFFLINE =================

  /// Cek masa tenggang offline: kalau terakhir kali "terverifikasi online"
  /// sudah lewat [graceHari] hari → kunci app + (opsional) wipe lokal.
  Future<void> cekKunciOffline() async {
    if ((await _db.getNilai('terkunci')) == '1') {
      terkunci = true;
      autoWipe = (await _db.getNilai('auto_wipe')) == '1';
      dataTerhapusLokal = autoWipe;
    }

    if (!cloudSiap || _auth == null) return;
    final user = _auth!.userSekarang;
    if (user == null) return;

    final graceTersimpan = await _db.getNilai('grace_offline_hari');
    graceHari = int.tryParse(graceTersimpan ?? '') ?? 7;
    autoWipe = (await _db.getNilai('auto_wipe')) == '1';

    var lastOk = int.tryParse((await _db.getNilai('last_auth_ok')) ?? '');
    if (lastOk == null) {
      // Belum pernah tercatat (upgrade dari v1) → mulai hitung dari sekarang.
      lastOk = DateTime.now().millisecondsSinceEpoch;
      await _db.setNilai('last_auth_ok', lastOk.toString());
      return;
    }

    final batas = lastOk + graceHari * 86400000;
    if (DateTime.now().millisecondsSinceEpoch > batas) {
      if (autoWipe) {
        // Keamanan HP hilang: data lokal dihapus, data cloud tetap aman
        // dan bisa dipulihkan setelah login online.
        await _db.hapusSemua(kirimTombstone: false);
        dataTerhapusLokal = true;
      }
      await _db.setNilai('terkunci', '1');
      terkunci = true;
      await _auth!.keluar(); // memicu listener → sync berhenti
    }
  }

  Future<void> _saatUserBerubah(User? user) async {
    masukAkunState = user != null;
    emailAkun = user?.email;
    emailTerverifikasi = user?.emailVerified ?? false;
    if (user != null) {
      // Login / re-login sukses → buka kunci + reset masa tenggang.
      terkunci = false;
      await _db.setNilai('terkunci', '0');
      await _db.setNilai(
          'last_auth_ok', DateTime.now().millisecondsSinceEpoch.toString());
      if (emailTerverifikasi) {
        await SyncService.instance.mulai(user.uid);
      } else {
        // Email belum diverifikasi → data tetap lokal sampai verifikasi.
        await SyncService.instance.berhenti();
      }
      await muatSemua();
    } else {
      await SyncService.instance.berhenti();
      notifyListeners();
    }
  }

  /// Return null kalau sukses, atau pesan error kalau gagal.
  Future<String?> masukAkun(String email, String sandi) async {
    if (_auth == null) return T.t('cloud_belum');
    try {
      await _auth!.masuk(email: email, sandi: sandi);
      return null;
    } catch (e) {
      return _auth!.pesanError(e);
    }
  }

  Future<String?> daftarAkun(String email, String sandi) async {
    if (_auth == null) return T.t('cloud_belum');
    try {
      await _auth!.daftar(email: email, sandi: sandi);
      // Langsung kirim email verifikasi (kalau gagal, masih bisa kirim
      // ulang dari layar verifikasi / Pengaturan).
      try {
        await _auth!.kirimVerifikasiEmail();
      } catch (_) {}
      return null;
    } catch (e) {
      return _auth!.pesanError(e);
    }
  }

  /// Kirim (ulang) email verifikasi ke akun yang sedang login.
  /// Return null kalau terkirim, atau pesan error.
  Future<String?> kirimVerifikasiEmail() async {
    if (_auth == null) return T.t('cloud_belum');
    try {
      await _auth!.kirimVerifikasiEmail();
      return null;
    } catch (e) {
      return _auth!.pesanError(e);
    }
  }

  /// Muat ulang profil dari Firebase dan cek status verifikasi email.
  /// Kalau ternyata sudah diverifikasi, sinkronisasi langsung dimulai.
  /// Return status verifikasi terbaru (offline → status lama, tanpa error).
  Future<bool> cekVerifikasiEmail() async {
    final auth = _auth;
    if (auth == null) return false;
    try {
      await auth.muatUlang();
    } catch (_) {
      // Gagal network saat reload → pakai status yang sudah diketahui.
      return emailTerverifikasi;
    }
    final user = auth.userSekarang;
    emailTerverifikasi = user?.emailVerified ?? false;
    if (emailTerverifikasi && user != null) {
      await _db.setNilai(
          'last_auth_ok', DateTime.now().millisecondsSinceEpoch.toString());
      await SyncService.instance.mulai(user.uid);
    }
    notifyListeners();
    return emailTerverifikasi;
  }

  Future<String?> kirimResetSandi(String email) async {
    if (_auth == null) return T.t('cloud_belum');
    try {
      await _auth!.kirimReset(email);
      return null;
    } catch (e) {
      return _auth!.pesanError(e);
    }
  }

  Future<void> keluarAkun() async {
    await SyncService.instance.berhenti();
    await _auth?.keluar();
    await muatSemua();
  }

  Future<void> sinkronSekarang() async {
    final ok = await SyncService.instance.flush();
    if (!ok) {
      statusSinkron = StatusSinkron.error;
      notifyListeners();
    }
    await muatSemua();
  }

  // ================= PENGATURAN FASE 2 =================

  Future<void> aturBahasa(String kode) async {
    T.bahasa = kode == 'en' ? 'en' : 'id';
    await _db.setNilai('bahasa', T.bahasa);
    notifyListeners();
  }

  Future<void> simpanGraceHari(int hari) async {
    graceHari = hari;
    await _db.setNilai('grace_offline_hari', hari.toString());
    notifyListeners();
  }

  Future<void> simpanAutoWipe(bool nilai) async {
    autoWipe = nilai;
    await _db.setNilai('auto_wipe', nilai ? '1' : '0');
    notifyListeners();
  }

  /// Nyalakan / matikan pengingat malam "catat pengeluaran".
  Future<void> simpanNotifHarian(bool nilai) async {
    notifHarian = nilai;
    await _db.setNilai('notif_harian', nilai ? '1' : '0');
    await NotifikasiService.instance.aturHarian(nilai, jam: jamNotifMalam);
    notifyListeners();
  }

  /// Ubah jam pengingat (pagi & malam, format "HH:MM") lalu jadwalkan
  /// ulang seluruh pengingat - kiriman, utang, target, dan pengingat
  /// malam - sesuai jam baru.
  Future<void> simpanJamNotif({required String pagi, required String malam}) async {
    jamNotifPagi = pagi;
    jamNotifMalam = malam;
    await _db.setNilai('jam_notif_pagi', pagi);
    await _db.setNilai('jam_notif_malam', malam);
    await NotifikasiService.instance.sinkronJadwal(
      harianAktif: notifHarian,
      kiriman: kirimanList,
      utang: utangList,
      target: targetList,
      saldoPegangan: saldoPegangan,
      jamPagi: pagi,
      jamMalam: malam,
    );
    notifyListeners();
  }

  /// Tutup layar sambutan dan catat biar tidak muncul lagi.
  Future<void> selesaikanSambutan() async {
    sudahSambutan = true;
    await _db.setNilai('sudah_sambutan', '1');
    notifyListeners();
  }

  /// Tutup splash pembuka (dipanggil LayarSplash tiap sesi, runtime saja).
  void selesaikanSplash() {
    if (splashSelesai) return;
    splashSelesai = true;
    notifyListeners();
  }

  // ================= BAGIKAN DARI APP LAIN =================

  /// Titik masuk data share (dipanggil BagikanService dari main()).
  void terimaBagikan({Uint8List? gambar, String? teks}) {
    if (gambar != null) gambarBagikan = gambar;
    if (teks != null && teks.trim().isNotEmpty) teksBagikan = teks.trim();
    notifyListeners();
  }

  /// Ambil foto share (sekali ambil, langsung dinolkan).
  Uint8List? ambilGambarBagikan() {
    final g = gambarBagikan;
    gambarBagikan = null;
    return g;
  }

  /// Ambil teks share (sekali ambil, langsung dinolkan).
  String? ambilTeksBagikan() {
    final t = teksBagikan;
    teksBagikan = null;
    return t;
  }

  // ================= GETTER HITUNGAN =================

  /// Kiriman menunggu terdekat (yang belum lewat tanggal).
  Kiriman? get kirimanAktif {
    final menunggu = kirimanList
        .where((k) => k.status == StatusKiriman.menunggu)
        .toList()
      ..sort((a, b) => a.tanggalDatang.compareTo(b.tanggalDatang));
    if (menunggu.isEmpty) return null;
    final kini = tanggalSaja(DateTime.now());
    final belumLewat =
        menunggu.where((k) => !k.tanggalDatang.isBefore(kini)).toList();
    return belumLewat.isNotEmpty ? belumLewat.first : menunggu.last;
  }

  /// True kalau kiriman aktif sudah lewat tanggal tapi belum
  /// dikonfirmasi. Selama telat, jatah harian sementara kembali memakai
  /// patokan akhir bulan - bukan "sisa 1 hari" yang bikin batas
  /// harian membuka jadi seluruh saldo.
  bool get kirimanTelat {
    final k = kirimanAktif;
    if (k == null) return false;
    return k.tanggalDatang.isBefore(tanggalSaja(DateTime.now()));
  }

  int get sisaHari => sisaHariMenuju(
        kini: DateTime.now(),
        // Kiriman telat belum tentu datang: pakai akhir bulan dulu
        // sampai kiriman dikonfirmasi / diedit (lihat [kirimanTelat]).
        tanggalKiriman: kirimanTelat ? null : kirimanAktif?.tanggalDatang,
      );

  int get budgetHarianOtomatis =>
      budgetHarian(saldo: saldoPegangan, sisaHari: sisaHari);

  /// Batas yang dipakai app: manual kalau diisi, kalau tidak pakai otomatis.
  int get batasAktif => batasHarian ?? budgetHarianOtomatis;

  /// Tanggal patokan proyeksi: kiriman berikutnya (kalau ada dan tidak
  /// telat) atau akhir bulan ini - sumber sama dengan [sisaHari].
  DateTime get tanggalPatokan => kirimanAktif != null && !kirimanTelat
      ? kirimanAktif!.tanggalDatang
      : DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

  /// Proyeksi batas manual yang lagi aktif (null kalau batasnya
  /// otomatis - by definition selalu pas sampai patokan).
  ProyeksiBatas? get proyeksiBatasAktif => proyeksiBatas(
        saldo: saldoPegangan,
        batas: batasHarian ?? 0,
        sisaHari: sisaHari,
        terpakaiHariIni: terpakaiHariIni,
      );

  // ============ TABUNGAN HEMAT (BULANAN + BAWAAN, BUKAN DI HOME) ============

  /// Tabungan hemat bulan berjalan: sisa jatah harian tanggal 1
  /// sampai kemarin yang tidak kepakai. Per hari dibatasi minimal 0,
  /// jadi hari boros tidak "mencuri" tabungan hari lain.
  ///
  /// Contoh: batas 50rb/hari, dari tanggal 1 baru 3 hari terpantau
  /// dan cuma kepakai 30rb/hari → hemat bulan ini (50-30) × 3 = 60rb.
  int get tabunganHematBulanIni {
    final batas = batasAktif;
    if (batas <= 0) return 0;
    var total = 0;
    for (final (_, terpakai) in _rincianBulanIni) {
      final sisaHariItu = batas - terpakai;
      if (sisaHariItu > 0) total += sisaHariItu;
    }
    return total;
  }

  /// Hemat bulan-bulan SEBELUM bulan berjalan yang sudah dibekukan
  /// di `tabungan_riwayat`. Angka ini TIDAK berubah lagi, jadi ganti
  /// batas harian tidak menulis-ulang tabungan bulan yang sudah lalu.
  int get tabunganBulanLalu =>
      _tabunganRiwayat.values.fold(0, (a, b) => a + b);

  /// Tabungan yang DIBAWA dari bulan-bulan sebelumnya ke bulan ini:
  /// hemat bulan lalu dikurangi pemakaian sebelum bulan ini.
  int get tabunganBawaan {
    final kini = DateTime.now();
    final awalBulan = DateTime(kini.year, kini.month);
    final terpakai = _pemakaianTabungan
        .where((p) => p.waktu.isBefore(awalBulan))
        .fold(0, (a, p) => a + p.jumlah);
    final sisa = tabunganBulanLalu - terpakai;
    return sisa < 0 ? 0 : sisa;
  }

  /// Total pot hemat = bawaan bulan-bulan lalu + bulan berjalan.
  int get tabunganHemat => tabunganBulanLalu + tabunganHematBulanIni;

  /// Saldo tabungan hemat yang boleh dipakai hari ini. SEMUA catatan
  /// pemakaian (kapan pun dibuat) mengurangi saldo - tidak hangus.
  ///
  /// Beda dengan versi lama (jendela 7 hari): hemat mengendap sepanjang
  /// bulan dan sisanya terbawa ke bulan-bulan berikutnya, jadi tabungan
  /// tetap ada buat minggu-minggu depan. Tabungan TIDAK menambah jatah
  /// harian (budget harian tetap polos). Tabungan hanya dipakai kalau
  /// user KONFIRMASI saat pengeluaran lewat batas harian - lihat
  /// [gerbangLewatBatas] di utils/dialog.dart dan layar Tabungan.
  int get tabunganSaldo {
    final terpakai =
        _pemakaianTabungan.fold(0, (a, p) => a + p.jumlah);
    final sisa = tabunganHemat - terpakai;
    return sisa < 0 ? 0 : sisa;
  }

  /// Daftar pemakaian tabungan (terbaru duluan) untuk layar Tabungan.
  List<PemakaianTabungan> get daftarPemakaianTabungan =>
      List.unmodifiable([..._pemakaianTabungan]
          ..sort((a, b) => b.waktu.compareTo(a.waktu)));

  /// Rincian pengeluaran per hari untuk bulan berjalan + tanggalnya
  /// (tanggal 1 sampai kemarin). Untuk layar Tabungan.
  List<(DateTime, int)> get rincianBulanIni =>
      List.unmodifiable(_rincianBulanIni);

  /// Berapa hari terpantau bulan ini yang jatahnya tidak habis
  /// (dipakai untuk info "hemat X dari Y hari" di layar Tabungan).
  int get hariHematBulanIni {
    final batas = batasAktif;
    if (batas <= 0) return 0;
    var n = 0;
    for (final (_, terpakai) in _rincianBulanIni) {
      if (terpakai < batas) n++;
    }
    return n;
  }

  int get terpakaiHariIni => transaksiHariIni
      .where((t) => t.jenis == JenisTransaksi.pengeluaran)
      .fold(0, (a, t) => a + t.jumlah);

  /// Catatan: [masukLain]/[keluarLain] (uang masuk/keluar lain, mis. bayar
  /// kos/wifi) TIDAK dihitung di sini - kewajiban itu sudah disediakan
  /// terpisah dari jatah harian.

  /// Kelebihan pengeluaran hari ini terhadap batas harian (0 kalau tidak
  /// lewat). Budget harian TIDAK ditambah rollover - sesuai keinginan
  /// user, batasnya tetap polos.
  int get kelebihanHariIni {
    final lebih = terpakaiHariIni - batasAktif;
    return lebih < 0 ? 0 : lebih;
  }

  /// Berapa kelebihan hari ini yang sudah ditutup tabungan hemat.
  int get ditutupTabunganHariIni {
    final kini = DateTime.now();
    return _pemakaianTabungan
        .where((p) =>
            p.waktu.year == kini.year &&
            p.waktu.month == kini.month &&
            p.waktu.day == kini.day)
        .fold(0, (a, p) => a + p.jumlah);
  }

  /// True kalau pengeluaran hari ini lewat batas DAN kelebihannya belum
  /// (seluruhnya) ditutup tabungan → layar perlu tetap memberi peringatan.
  bool get lewatBatasBelumTertutup =>
      batasAktif > 0 && kelebihanHariIni > ditutupTabunganHariIni;

  bool get lewatBatasHariIni => cekLewatBatas(0);

  /// True kalau setelah nambah [jumlahBaru] pengeluaran hari ini lewat
  /// batas harian polos (tanpa tambahan rollover).
  bool cekLewatBatas(int jumlahBaru) =>
      batasAktif > 0 && (terpakaiHariIni + jumlahBaru) > batasAktif;

  /// Recalculate setelah lewat batas. Jatah hari ini SUDAH ABIS
  /// (itulah kenapa lewat batas), jadi sisa saldo dibagi rata sisa
  /// hari SETELAH hari ini (sisaHari - 1) - bukan saldo ÷ sisaHari
  /// yang seolah jatah hari ini masih ada. Angka ini SATU-SATUNYA
  /// saran budget yang tampil saat lewat batas (kartu Perhatian
  /// hanya memberi peringatan, kartu Budget menampilkan angkanya).
  int get budgetBaruSetelahLewat => budgetHarian(
        saldo: saldoPegangan,
        sisaHari: sisaHari > 1 ? sisaHari - 1 : 1,
      );

  int get totalUang => saldoPegangan + kantongDarurat;

  /// Muat catatan pemakaian tabungan dari tabel pengaturan. Semua
  /// catatan dipertahankan: pemakaian mengurangi saldo tabungan
  /// selamanya (saldo = hemat semua bulan - semua pemakaian).
  Future<List<PemakaianTabungan>> _muatPemakaianTabungan() async {
    final mentah = await _db.getNilai('tabungan_terpakai');
    if (mentah == null || mentah.isEmpty) return [];
    try {
      return (jsonDecode(mentah) as List)
          .map((e) =>
              PemakaianTabungan.dariMap(Map<String, Object?>.from(e)))
          .toList();
    } catch (_) {
      return []; // JSON rusak → mulai bersih, jangan crash app
    }
  }

  Future<void> _simpanPemakaianTabungan() async {
    await _db.setNilai(
      'tabungan_terpakai',
      jsonEncode(_pemakaianTabungan.map((p) => p.keMap()).toList()),
    );
  }

  /// Muat riwayat hemat bulan-bulan tertutup (kunci `tabungan_riwayat`,
  /// JSON {"yyyy-MM": nominal}). Aman terhadap JSON rusak.
  Future<Map<String, int>> _muatRiwayatTabungan() async {
    final mentah = await _db.getNilai('tabungan_riwayat');
    if (mentah == null || mentah.isEmpty) return {};
    try {
      final obj = jsonDecode(mentah);
      if (obj is! Map) return {};
      final hasil = <String, int>{};
      obj.forEach((kunci, nilai) {
        final n = nilai is num ? nilai.toInt() : int.tryParse('$nilai');
        if (kunci is String && n != null) hasil[kunci] = n;
      });
      return hasil;
    } catch (_) {
      return {}; // JSON rusak → mulai bersih, jangan crash app
    }
  }

  /// Hari pertama app mulai memantau uang: catatan paling awal
  /// (transaksi, kiriman, atau pemakaian tabungan). Hari-hari sebelum
  /// ini tidak dihitung hemat supaya tidak muncul tabungan palsu
  /// (misal hari-hari sebelum app dipasang).
  DateTime? _cariMulaiPantau(DateTime? transaksiAwal) {
    DateTime? mulai;
    void pertimbangkan(DateTime? d) {
      if (d == null) return;
      final tgl = tanggalSaja(d);
      if (mulai == null || tgl.isBefore(mulai!)) mulai = tgl;
    }

    pertimbangkan(transaksiAwal);
    for (final k in kirimanList) {
      pertimbangkan(k.dibuatPada);
    }
    for (final p in _pemakaianTabungan) {
      pertimbangkan(p.waktu);
    }
    return mulai;
  }

  /// Bekukan hemat bulan-bulan TERTUTUP (sebelum bulan ini) ke
  /// `tabungan_riwayat`. Dipanggil dari [muatSemua]; cuma jalan kalau
  /// ada bulan yang belum dibekukan (mis. pertama kali jalan setelah
  /// ganti bulan), sisanya langsung balik (murah).
  ///
  /// Untuk bulan tertutup, hemat dihitung hanya sampai hari AKTIVITAS
  /// TERAKHIR bulan itu (transaksi/pemakaian terakhir). Kalau user
  /// berhenti mencatat di tengah bulan, hari-hari kosong setelahnya
  /// tidak dihitung hemat. Bulan tanpa aktivitas sama sekali = 0.
  /// Bulan yang sudah dibekukan tidak dihitung ulang, jadi mengganti
  /// batas harian tidak menulis-ulang tabungan bulan-bulan lama.
  Future<void> _kunciBulanTertutup(
    DateTime mulaiPantau,
    DateTime awalBulanIni,
  ) async {
    final belum = <DateTime>[];
    for (var m = DateTime(mulaiPantau.year, mulaiPantau.month);
        m.isBefore(awalBulanIni);
        m = DateTime(m.year, m.month + 1)) {
      if (!_tabunganRiwayat.containsKey(kunciBulan(m))) belum.add(m);
    }
    if (belum.isEmpty) return;

    // Satu query untuk semua transaksi sebelum bulan ini.
    final daftar = await _db.transaksiAntara(mulaiPantau, awalBulanIni);
    final perHari = <String, int>{};
    final hariAktif = <String>{};
    for (final t in daftar) {
      final k = kunciHari(t.dibuatPada);
      hariAktif.add(k);
      if (t.jenis != JenisTransaksi.pengeluaran) continue;
      perHari[k] = (perHari[k] ?? 0) + t.jumlah;
    }
    for (final p in _pemakaianTabungan) {
      hariAktif.add(kunciHari(p.waktu));
    }

    final batas = batasAktif;
    for (final m in belum) {
      // Hari terakhir yang benar-benar dipantau di bulan itu.
      DateTime? terakhir;
      final akhirBulan = DateTime(m.year, m.month + 1, 1);
      for (var d = m; d.isBefore(akhirBulan); d = d.add(const Duration(days: 1))) {
        if (hariAktif.contains(kunciHari(d))) terakhir = d;
      }
      _tabunganRiwayat[kunciBulan(m)] = terakhir == null
          ? 0
          : hematBulan(
              batas: batas,
              awalBulan: m,
              mulaiPantau: mulaiPantau,
              hariTerakhir: terakhir,
              pengeluaranPerHari: perHari,
            );
    }
    await _db.setNilai(
      'tabungan_riwayat',
      jsonEncode(_tabunganRiwayat),
    );
  }

  /// Buka kunci hemat bulan-bulan TERTUTUP yang terkena hapus/ubah
  /// transaksi, supaya nilainya dihitung ulang dari data yang benar
  /// di [muatSemua] berikutnya. Tanpa ini, hemat bulan lama yang sudah
  /// dibekukan dari data yang salah (mis. sisa kasus struk nyasar ke
  /// 2023) tetap nempel selamanya padahal transaksinya sudah dihapus.
  /// Bulan berjalan tidak pernah dikunci, jadi otomatis diabaikan.
  Future<void> _bukaKunciBulanTerkena(List<DateTime> tanggalTerkena) async {
    final kini = DateTime.now();
    final bulanIni = DateTime(kini.year, kini.month);
    var berubah = false;
    for (final d in tanggalTerkena) {
      final m = DateTime(d.year, d.month);
      if (!m.isBefore(bulanIni)) continue; // bukan bulan tertutup
      final k = kunciBulan(m);
      if (_tabunganRiwayat.containsKey(k)) {
        _tabunganRiwayat.remove(k);
        berubah = true;
      }
    }
    if (berubah) {
      await _db.setNilai(
        'tabungan_riwayat',
        jsonEncode(_tabunganRiwayat),
      );
    }
  }

  /// Catat pemakaian tabungan hemat (dipanggil setelah pengeluaran yang
  /// lewat batas disetujui user untuk ditutup tabungan).
  Future<void> pakaiTabungan(int jumlah, String? catatan) async {
    if (jumlah <= 0) return;
    _pemakaianTabungan
        .add(PemakaianTabungan(DateTime.now(), jumlah, catatan));
    await _simpanPemakaianTabungan();
    await muatSemua();
  }

  /// Kembalikan pemakaian tabungan yang sudah tidak diperlukan di hari
  /// [hari]. Dipanggil setelah transaksi pengeluaran DIHAPUS atau
  /// DIUBAH: kalau kelebihan jatah hari itu sekarang lebih kecil dari
  /// pemakaian tabungannya (atau malah sudah tidak lewat batas),
  /// selisihnya dikembalikan ke saldo tabungan - dipangkas dari
  /// catatan pemakaian terbaru hari itu (sebagian bila perlu).
  ///
  /// Return berapa rupiah yang dikembalikan (0 kalau tidak ada).
  Future<int> _kembalikanTabunganBerlebih(DateTime hari) async {
    final tglHari = tanggalSaja(hari);
    final hariItu = _pemakaianTabungan
        .where((p) => tanggalSaja(p.waktu) == tglHari)
        .toList();
    if (hariItu.isEmpty) return 0;

    // Kelebihan jatah hari itu SETELAH perubahan (baca ulang dari DB).
    final awal = DateTime(tglHari.year, tglHari.month, tglHari.day);
    final daftar = await _db.transaksiAntara(
      awal,
      awal.add(const Duration(days: 1)),
    );
    final pengeluaran = daftar
        .where((t) => t.jenis == JenisTransaksi.pengeluaran)
        .fold(0, (a, t) => a + t.jumlah);
    final batas = batasAktif;
    final kelebihan = pengeluaran - batas;
    final perluTutup = kelebihan > 0 ? kelebihan : 0;

    var kembali =
        hariItu.fold(0, (a, p) => a + p.jumlah) - perluTutup;
    if (kembali <= 0) return 0;

    // Pangkas dari catatan terbaru hari itu (sebagian bila perlu).
    final urut = [...hariItu]..sort((a, b) => b.waktu.compareTo(a.waktu));
    var sisa = kembali;
    for (final p in urut) {
      if (sisa <= 0) break;
      if (p.jumlah <= sisa) {
        _pemakaianTabungan.remove(p);
        sisa -= p.jumlah;
      } else {
        final i = _pemakaianTabungan.indexOf(p);
        _pemakaianTabungan[i] =
            PemakaianTabungan(p.waktu, p.jumlah - sisa, p.catatan);
        sisa = 0;
      }
    }
    await _simpanPemakaianTabungan();
    return kembali;
  }

  // ================= JAGA SALDO (TIDAK BOLEH MINUS) =================

  /// Perkiraan kebutuhan hidup untuk sisa periode: rata-rata belanja
  /// × sisa hari, minimal 10% saldo (buat user baru yang belum punya
  /// riwayat belanja).
  int get ambangAmanSaldo {
    final butuh = rataPengeluaran7Hari * sisaHari;
    final sepuluhPersen = saldoPegangan ~/ 10;
    return butuh > sepuluhPersen ? butuh : sepuluhPersen;
  }

  /// Periksa transaksi yang mengurangi saldo sebanyak [jumlah]:
  /// - [HasilJagaSaldo.kurang]  → saldo jadi minus, wajib DITOLAK;
  /// - [HasilJagaSaldo.kritis]  → pembelian besar (≥ 50% saldo) yang
  ///   menyisakan uang di bawah perkiraan kebutuhan → minta konfirmasi
  ///   (contoh: beli motor 3jt dengan saldo persis 3jt);
  /// - [HasilJagaSaldo.aman]    → lanjut.
  ///
  /// Sebelum saldo pertama diatur (onboarding) tidak ada penjagaan
  /// supaya pengguna baru tetap bisa mencatat.
  HasilJagaSaldo jagaSaldo(int jumlah) {
    if (!sudahSetup) return HasilJagaSaldo.aman;
    final sisa = saldoPegangan - jumlah;
    if (sisa < 0) return HasilJagaSaldo.kurang;
    if (sisa < ambangAmanSaldo && jumlah >= saldoPegangan ~/ 2) {
      return HasilJagaSaldo.kritis;
    }
    return HasilJagaSaldo.aman;
  }

  // ================= GEMINI (DUA KEY + ROTASI) =================

  GeminiKeyPool? _poolGemini;

  /// Pool key aktif - null kalau belum ada satu pun API key.
  GeminiKeyPool? get poolGemini => _poolGemini;

  bool get punyaKunciGemini => _poolGemini != null;

  /// Panggil Gemini dengan rotasi key otomatis:
  /// key 1 → habis kuota / invalid → key 2 → dst, transparan untuk pemanggil.
  Future<R> panggilGemini<R>(Future<R> Function(GeminiService) aksi) async {
    final pool = _poolGemini;
    if (pool == null) throw const GeminiException('scan_err_key');
    return pool.jalankan(aksi);
  }

  void _bangunPoolGemini() {
    final daftar = KunciEnv.daftar; // dari --dart-define saat build
    _poolGemini = daftar.isEmpty
        ? null
        : GeminiKeyPool(kunci: daftar, model: modelGemini);
  }

  SaranTarget saranUntuk(TargetBeli t) => hitungSaranTarget(
        target: t,
        saldoPegangan: saldoPegangan,
        batasHarianAktif: batasAktif,
        rataPengeluaran7Hari: rataPengeluaran7Hari,
        kini: DateTime.now(),
      );

  /// Teks pratinjau "imbas" transaksi keluar sebesar [jumlah] (beli
  /// target, ngutangin, isi kantong darurat, uang keluar lain):
  /// pegangan jadi berapa + dengan batas yang diatur, uang bertahan
  /// sampai kapan. Untuk batas otomatis cukup kabari batas barunya.
  ///
  /// [masukBudgetHariIni] = true kalau nominalnya bakal tercatat sebagai
  /// pengeluaran hari ini (beli target): nominal itu ikut "memakan"
  /// jatah hari ini, jadi sisa jatah hari ini tidak boleh dikembalikan
  /// dua kali (dulu: beli target 200rb dengan jatah 50rb membuat
  /// pratinjau terlihat lebih pendek dari kenyataan).
  String teksImbas(int jumlah, {bool masukBudgetHariIni = false}) {
    final sisaSaldo = saldoPegangan - jumlah;
    if (batasHarian == null) {
      final baru = budgetHarian(saldo: sisaSaldo, sisaHari: sisaHari);
      return T.f('imbas_oto', {'s': rp(sisaSaldo), 'b': rp(baru)});
    }
    final p = proyeksiBatas(
      saldo: sisaSaldo,
      batas: batasHarian!,
      sisaHari: sisaHari,
      terpakaiHariIni: masukBudgetHariIni
          ? terpakaiHariIni + jumlah
          : terpakaiHariIni,
    );
    if (p == null) return '';
    if (p.aman) {
      return T.f('imbas_aman', {
        's': rp(sisaSaldo),
        'b': rp(batasHarian!),
        'd': tanggalSangatPendek(tanggalPatokan),
        'n': rp(p.sisaAkhir),
      });
    }
    return T.f('imbas_kurang', {
      's': rp(sisaSaldo),
      'b': rp(batasHarian!),
      'd': tanggalSangatPendek(
          DateTime.now().add(Duration(days: p.hariBertahan))),
      'k': '${p.sisaHari - p.hariBertahan}',
      'r': rp(p.saranBatas),
    });
  }

  /// Teks saran target dalam bahasa aktif (data murni dari [saranUntuk]).
  String teksSaranTarget(TargetBeli t) {
    final s = saranUntuk(t);
    switch (s.status) {
      case StatusSaran.siapBeli:
        return T.t('saran_siap');
      case StatusSaran.aman:
        return T.f('saran_aman', {
          'n': rp(s.nabungPerHari ?? 0),
          'd': '${s.sisaHari ?? 0}',
          't': tanggalPendek(s.tanggalSaran ?? DateTime.now()),
        });
      case StatusSaran.berat:
        return T.f('saran_berat', {
          'n': rp(s.nabungPerHari ?? 0),
          'k': rp(s.kemampuan),
        });
      case StatusSaran.perluWaktu:
        return T.f('saran_waktu', {
          'n': rp(s.kurang),
          'k': rp(s.kemampuan),
          't': tanggalPendek(s.tanggalSaran ?? DateTime.now()),
          'd': '${s.sisaHari ?? 0}',
        });
    }
  }

  List<Perhatian> get daftarPerhatian {
    final items = <Perhatian>[];
    final kini = tanggalSaja(DateTime.now());

    for (final k in kirimanList.where((k) =>
        k.status == StatusKiriman.menunggu &&
        k.tanggalDatang.isBefore(kini))) {
      items.add(Perhatian(
        Icons.schedule_rounded,
        T.f('perhatian_kiriman', {
          'n': rp(k.nominal),
          'd': tanggalPendek(k.tanggalDatang),
        }),
      ));
    }

    for (final u in utangList.where(
        (u) => u.status == StatusUtang.aktif && u.jatuhTempo != null)) {
      final beda = u.jatuhTempo!.difference(kini).inDays;
      final pihak =
          u.arah == ArahUtang.ngutang ? T.t('utang_ke') : T.t('piutang_ke');
      if (beda < 0) {
        items.add(Perhatian(
          Icons.warning_amber_rounded,
          T.f('perhatian_lewat_tempo', {
            'p': pihak,
            'x': u.pihak,
            'd': tanggalPendek(u.jatuhTempo!),
          }),
        ));
      } else if (beda <= 3) {
        items.add(Perhatian(
          Icons.alarm_rounded,
          T.f('perhatian_tempo_dekat', {
            'p': pihak,
            'x': u.pihak,
            'd': tanggalPendek(u.jatuhTempo!),
          }),
        ));
      }
    }

    for (final t in targetList.where((t) =>
        t.status == StatusTarget.aktif && t.tanggal != null)) {
      final beda = t.tanggal!.difference(kini).inDays;
      if (beda >= 0 && beda <= 7 && saldoPegangan < t.nominal) {
        items.add(Perhatian(
          Icons.flag_rounded,
          T.f('perhatian_target', {
            'x': t.nama,
            'h': beda == 0
                ? T.t('perhatian_target_hari_ini')
                : T.f('sisa_hari_info', {'n': '$beda'}),
            'n': rp(t.nominal - saldoPegangan),
          }),
        ));
      }
    }

    // Peringatan lewat batas hanya kalau kelebihannya belum ditutup
    // tabungan hemat (kalau sudah ditutup, hari itu dianggap aman).
    // Tanpa angka saran - saran budget barunya ada di kartu Budget
    // (satu saran saja, tidak mendem di tiga tempat).
    if (lewatBatasBelumTertutup) {
      items.add(Perhatian(
        Icons.speed_rounded,
        T.t('perhatian_batas'),
      ));
    }

    return items;
  }

  // ================= AKSI: SALDO & PENGELUARAN =================

  /// Set saldo pegangan (dipakai onboarding & pengaturan).
  Future<void> aturSaldoAwal(int nominal) async {
    final delta = nominal - saldoPegangan;
    if (delta != 0) {
      await _db.catatTransaksi(Transaksi(
        jenis: JenisTransaksi.koreksi,
        jumlah: delta,
        catatan: T.t('judul_koreksi'),
      ));
    }
    await _db.setNilai('sudah_setup', '1');
    await muatSemua();
  }

  /// Return true kalau tersimpan; false kalau ditolak penjaga saldo.
  /// (UI memeriksa lewat gerbangJagaSaldo dulu, tapi saldo bisa berubah
  /// di antara konfirmasi dan penyimpanan - panggil WAJIB cek hasilnya
  /// sebelum mencatat pemakaian tabungan.)
  Future<bool> tambahPengeluaran({
    required String nama,
    required int jumlah,
    required KategoriPengeluaran kategori,
    String sumber = 'manual',
    DateTime? dibuatPada,
  }) async {
    // Prinsip "saldo tidak boleh minus": baris pertahanan terakhir.
    if (jagaSaldo(jumlah) == HasilJagaSaldo.kurang) return false;
    await _db.catatTransaksi(Transaksi(
      jenis: JenisTransaksi.pengeluaran,
      jumlah: jumlah,
      kategori: kategori,
      catatan: nama,
      sumber: sumber,
      dibuatPada: _dibuatPadaAman(dibuatPada),
    ));
    await muatSemua();
    return true;
  }

  Future<void> tambahPemasukan({
    required int jumlah,
    String? catatan,
    String sumber = 'manual',
    int? terkaitId,
    DateTime? dibuatPada,
  }) async {
    await _db.catatTransaksi(Transaksi(
      jenis: JenisTransaksi.pemasukan,
      jumlah: jumlah,
      catatan: catatan,
      sumber: sumber,
      terkaitId: terkaitId,
      dibuatPada: _dibuatPadaAman(dibuatPada),
    ));
    await muatSemua();
  }

  /// Pelindung terakhir tanggal transaksi yang dibawa scan/input:
  /// hanya terima jendela [kini - 1 bulan .. kini]. Tanggal di luar
  /// jendela (mis. hasil scan salah baca "18/11/2023") dipotong ke
  /// batas jendela - satu struk aneh tidak boleh menarik "mulai
  /// pantau" tabungan hemat bertahun-tahun ke belakang, yang dulu
  /// bikin riwayat tabungan tiba-tiba berisi hemat palsu 1-16 tiap
  /// hari. (Layar scan sudah menyaring lebih dulu; ini penjaga
  /// kalau ada jalur lain yang lupa menyaring.)
  DateTime _dibuatPadaAman(DateTime? d) {
    final kini = DateTime.now();
    if (d == null) return kini;
    final awal = DateTime(kini.year, kini.month - 1, kini.day);
    if (d.isBefore(awal)) return awal;
    if (d.isAfter(kini)) return kini;
    return d;
  }

  /// Uang masuk yang bukan kiriman (hadiah, jualan, cashback).
  Future<void> tambahMasukLain(int jumlah, String? catatan) async {
    await _db.catatTransaksi(Transaksi(
      jenis: JenisTransaksi.masukLain,
      jumlah: jumlah,
      catatan: catatan,
    ));
    await muatSemua();
  }

  /// Uang keluar yang bukan pengeluaran (bayar kos, wifi, setor
  /// tabungan, kas ke keluarga). Tidak dihitung sebagai pengeluaran
  /// di laporan maupun di budget harian.
  Future<void> tambahKeluarLain(int jumlah, String? catatan) async {
    // Uang keluar tetap tidak boleh bikin saldo minus.
    if (jagaSaldo(jumlah) == HasilJagaSaldo.kurang) return;
    await _db.catatTransaksi(Transaksi(
      jenis: JenisTransaksi.keluarLain,
      jumlah: jumlah,
      catatan: catatan,
    ));
    await muatSemua();
  }

  // ================= AKSI: UBAH / HAPUS TRANSAKSI =================

  /// Ubah transaksi lama (salah catat) - hanya field yang diberikan.
  /// Jenis transaksinya tidak pernah diubah. Saldo pegangan & kantong
  /// dihitung ulang otomatis dari seluruh buku kas. Kalau perubahan ini
  /// menghilangkan kelebihan jatah di tanggal lama/baru, pemakaian
  /// tabungan hari itu dikembalikan otomatis (lihat
  /// [_kembalikanTabunganBerlebih]).
  Future<void> perbaruiTransaksi(
    Transaksi t, {
    int? jumlah,
    String? catatan,
    bool hapusCatatan = false,
    KategoriPengeluaran? kategori,
    DateTime? dibuatPada,
  }) async {
    await _db.perbaruiTransaksi(
      t.id!,
      jumlah: jumlah,
      catatan: catatan,
      hapusCatatan: hapusCatatan,
      kategoriNilai: kategori?.nilai,
      dibuatPada: dibuatPada,
    );
    // Bulan tertutup yang tanggalnya terkena (lama & baru) dibuka
    // kuncinya dulu supaya hemat bulan itu dihitung ulang dari data
    // yang sekarang benar.
    await _bukaKunciBulanTerkena([
      t.dibuatPada,
      if (dibuatPada != null) dibuatPada,
    ]);
    // Segarkan state dulu supaya batas aktif (otomatis) dihitung dari
    // saldo terbaru, baru cek pemakaian tabungan berlebih.
    await muatSemua();
    // Tanggal transaksi bisa pindah hari: cek pemakaian tabungan di
    // tanggal LAMA maupun BARU (kalau sama, ceknya cuma sekali).
    var kembali = await _kembalikanTabunganBerlebih(t.dibuatPada);
    if (dibuatPada != null &&
        tanggalSaja(dibuatPada) != tanggalSaja(t.dibuatPada)) {
      kembali += await _kembalikanTabunganBerlebih(dibuatPada);
    }
    if (kembali > 0) await muatSemua(); // refresh saldo tabungan dsb.
  }

  /// Hapus transaksi - saldo pegangan & kantong dihitung ulang
  /// otomatis. Penghapusan ikut tersinkron (tombstone). Kalau
  /// transaksi ini yang bikin lewat batas (dan ditutup tabungan),
  /// tabungannya DIKEMBALIKAN otomatis. Return berapa tabungan yang
  /// dikembalikan (0 kalau tidak ada).
  Future<int> hapusTransaksi(Transaksi t) async {
    await _db.hapusTransaksi(t.id!);
    // Bulan tertutup dari transaksi ini dibuka kuncinya supaya
    // hematnya dihitung ulang (kasus: struk nyasar ke tahun lalu
    // dibekukan membawa nilai salah - menghapusnya harus benar-benar
    // membersihkan jejaknya di tabungan).
    await _bukaKunciBulanTerkena([t.dibuatPada]);
    // Segarkan state dulu supaya batas aktif (otomatis) dihitung dari
    // saldo terbaru, baru kembalikan tabungan berlebihnya.
    await muatSemua();
    final kembali = await _kembalikanTabunganBerlebih(t.dibuatPada);
    if (kembali > 0) await muatSemua(); // refresh saldo tabungan dsb.
    return kembali;
  }

  // ================= AKSI: KANTONG DARURAT =================

  /// Pindah uang dari pegangan ke kantong darurat.
  Future<void> isiKantong(int jumlah) async {
    // Pindahan keluar dari pegangan: jangan sampai pegangan minus.
    if (jagaSaldo(jumlah) == HasilJagaSaldo.kurang) return;
    await _db.catatTransaksi(
        Transaksi(jenis: JenisTransaksi.isiDarurat, jumlah: jumlah));
    await muatSemua();
  }

  /// Pakai uang dari kantong darurat (saldo pegangan tidak berubah).
  Future<void> pakaiKantong(int jumlah, String? catatan) async {
    await _db.catatTransaksi(Transaksi(
      jenis: JenisTransaksi.pakaiDarurat,
      jumlah: jumlah,
      catatan: catatan,
    ));
    await muatSemua();
  }

  /// Tarik uang kantong darurat kembali ke pegangan.
  Future<void> tarikKantong(int jumlah) async {
    await _db.catatTransaksi(
        Transaksi(jenis: JenisTransaksi.tarikDarurat, jumlah: jumlah));
    await muatSemua();
  }

  Future<List<Transaksi>> riwayatKantong() => _db.transaksiJenis(const [
        JenisTransaksi.isiDarurat,
        JenisTransaksi.pakaiDarurat,
        JenisTransaksi.tarikDarurat,
      ]);

  // ================= AKSI: KIRIMAN =================

  Future<void> tambahKiriman({
    required int nominal,
    required DateTime tanggalDatang,
    String? catatan,
  }) async {
    await _db.simpanKiriman(Kiriman(
      nominal: nominal,
      tanggalDatang: tanggalDatang,
      catatan: catatan,
    ));
    await muatSemua();
  }

  /// Konfirmasi kiriman sudah masuk → saldo bertambah.
  Future<void> konfirmasiKiriman(Kiriman k) async {
    await _db.catatTransaksi(Transaksi(
      jenis: JenisTransaksi.pemasukan,
      jumlah: k.nominal,
      catatan: k.catatan ?? T.t('nav_kiriman'),
      terkaitId: k.id,
    ));
    await _db.perbaruiStatusKiriman(k.id!, StatusKiriman.masuk);
    await muatSemua();
  }

  Future<void> hapusKiriman(Kiriman k) async {
    await _db.hapusKiriman(k.id!);
    await muatSemua();
  }

  // ================= AKSI: TARGET =================

  Future<void> tambahTarget({
    required String nama,
    required int nominal,
    DateTime? tanggal,
  }) async {
    await _db.simpanTarget(TargetBeli(
      nama: nama,
      nominal: nominal,
      tanggal: tanggal,
    ));
    await muatSemua();
  }

  Future<void> tandaiTargetTercapai(TargetBeli t,
      {required bool catatPengeluaran}) async {
    // Beli target = pengeluaran besar: jangan sampai saldo minus.
    if (catatPengeluaran &&
        jagaSaldo(t.nominal) == HasilJagaSaldo.kurang) {
      return;
    }
    await _db.perbaruiStatusTarget(t.id!, StatusTarget.tercapai);
    if (catatPengeluaran) {
      await _db.catatTransaksi(Transaksi(
        jenis: JenisTransaksi.pengeluaran,
        jumlah: t.nominal,
        kategori: KategoriPengeluaran.lainLain,
        catatan: '${T.t('nav_target')}: ${t.nama}',
      ));
    }
    await muatSemua();
  }

  Future<void> hapusTarget(TargetBeli t) async {
    await _db.hapusTarget(t.id!);
    await muatSemua();
  }

  // ================= AKSI: UTANG & PIUTANG =================

  /// ngutang  → saldo nambah (kita dapet duit).
  /// ngutangin → saldo kepotong (kita ngasih pinjam).
  Future<void> tambahUtang({
    required ArahUtang arah,
    required String pihak,
    required int nominal,
    DateTime? jatuhTempo,
    String? catatan,
  }) async {
    // Ngasih pinjam mengurangi saldo: tidak boleh sampai minus.
    if (arah == ArahUtang.ngutangin &&
        jagaSaldo(nominal) == HasilJagaSaldo.kurang) {
      return;
    }
    final id = await _db.simpanUtang(Utang(
      arah: arah,
      pihak: pihak,
      nominal: nominal,
      jatuhTempo: jatuhTempo,
      catatan: catatan,
    ));
    await _db.catatTransaksi(Transaksi(
      jenis: arah == ArahUtang.ngutang
          ? JenisTransaksi.utangMasuk
          : JenisTransaksi.piutangKeluar,
      jumlah: nominal,
      catatan: pihak,
      terkaitId: id,
    ));
    await muatSemua();
  }

  /// Lunasi: bayar utang (saldo -) atau piutang balik (saldo +).
  Future<void> lunasiUtang(Utang u, {required bool catatTransaksi}) async {
    // Bayar utang mengurangi saldo: jangan sampai minus.
    if (catatTransaksi &&
        u.arah == ArahUtang.ngutang &&
        jagaSaldo(u.nominal) == HasilJagaSaldo.kurang) {
      return;
    }
    await _db.perbaruiStatusUtang(u.id!, StatusUtang.lunas);
    if (catatTransaksi) {
      await _db.catatTransaksi(Transaksi(
        jenis: u.arah == ArahUtang.ngutang
            ? JenisTransaksi.utangBayar
            : JenisTransaksi.piutangTerima,
        jumlah: u.nominal,
        catatan: u.pihak,
        terkaitId: u.id,
      ));
    }
    await muatSemua();
  }

  Future<void> hapusUtang(Utang u) async {
    await _db.hapusUtang(u.id!);
    await muatSemua();
  }

  // ================= PENGATURAN =================

  Future<void> simpanBatasHarian(int? nilai) async {
    batasHarian = nilai;
    if (nilai == null) {
      await _db.hapusNilai('batas_harian');
    } else {
      await _db.setNilai('batas_harian', nilai.toString());
    }
    await muatSemua();
  }

  Future<void> simpanModelGemini(String model) async {
    await _db.setNilai('model_gemini', model);
    _bangunPoolGemini(); // pool membawa model aktif
    await muatSemua();
  }

  // ================= LAIN-LAIN =================

  Future<List<Transaksi>> ambilSemuaTransaksi() => _db.semuaTransaksi();

  Future<List<Transaksi>> transaksiBulan(int tahun, int bulan) =>
      _db.transaksiAntara(
        DateTime(tahun, bulan, 1),
        DateTime(tahun, bulan + 1, 1),
      );

  /// Reset total: lokal + cloud. Kalau sedang login, SELURUH dokumen di
  /// cloud ikut dihapus betulan (sweep - bukan sekadar ditandai), sesuai
  /// janji dialog "permanen (termasuk salinan di cloud)". Kalau sweep
  /// belum bisa jalan (offline / belum verifikasi email), ia diulang
  /// otomatis begitu sync online.
  ///
  /// Return true kalau cloud sudah tuntas dibersihkan (atau tidak ada
  /// akun - tidak ada yang perlu dibersihkan); false kalau masih
  /// tertunda.
  Future<bool> resetSemuaData() async {
    await _db.hapusSemua(kirimTombstone: masukAkunState);
    var cloudTuntas = true;
    if (masukAkunState) {
      // Sweep langsung. Kalau belum bisa (offline / belum verifikasi),
      // flag `reset_cloud_pending` dipasang + antrian tombstone tetap
      // dikirim flush sebagai DELETE begitu online - dobel jaring
      // pengaman.
      cloudTuntas = await SyncService.instance.bersihkanCloudPenuh();
    }
    await muatSemua();
    return cloudTuntas;
  }
}
