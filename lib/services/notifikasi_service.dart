import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/kiriman.dart';
import '../models/target.dart';
import '../models/utang.dart';
import '../utils/format.dart';
import '../utils/teks.dart';

/// Pengingat Android (notifikasi sistem) untuk kosku:
/// - kiriman "menunggu" yang semestinya datang hari itu;
/// - utang / piutang H-1 DAN hari jatuh temponya sendiri;
/// - target beli bertanggal: H-1 deadline;
/// - pengingat malam "sudah catat pengeluaran hari ini?".
///
/// Jam pengingat BISA DIUBAH user di Pengaturan (default 08.00 pagi
/// untuk kiriman/utang/target, 20.00 malam untuk catat pengeluaran) -
/// dulu hardcode 08.00/20.00.
///
/// Prinsip: notifikasi adalah BONUS - kalau plugin gagal / izin ditolak,
/// aplikasi tetap jalan penuh tanpa crash (semua panggilan dibungkus
/// try/catch). Jadwal di-sinkronkan ulang tiap data berubah; murah
/// karena dijaga tanda tangan (signature) di sini.
///
/// PENTING (build): receiver di AndroidManifest WAJIB ada. Sejak v2.12
/// folder android/ sudah disertakan lengkap (receiver + izin + desugaring
/// sudah diterapkan), jadi tinggal `flutter build apk` - lihat README.
/// Tanpa `ScheduledNotificationReceiver`, alarm "berhasil" dijadwalkan
/// tapi TIDAK PERNAH tampil; tanpa `ScheduledNotificationBootReceiver`
/// + izin RECEIVE_BOOT_COMPLETED, semua jadwal hilang setelah HP restart.
///
/// Jam pengingat mengikuti WAKTU HP (bukan zona Indonesia tetap): semua
/// waktu dihitung dari DateTime.now() perangkat, dan zona lokal plugin
/// dipasang dari offset HP sekarang.
class NotifikasiService {
  NotifikasiService._();
  static final NotifikasiService instance = NotifikasiService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _siap = false;
  bool _menyiapkan = false;

  /// Boleh pakai alarm EXACT (Android 12+ "Alarms & reminders")?
  /// Dicek ulang tiap siapkan; kalau tidak, jatuh ke alarm inexact
  /// (masih muncul, hanya bisa telat ±15 menit).
  bool _bolehExact = false;

  /// Tanda tangan jadwal terakhir - dipakai supaya muatSemua() yang
  /// sering terpanggil tidak menjadwalkan ulang tanpa perubahan.
  String? _tandaTanganTerakhir;

  /// Slot kiriman/utang/target yang terakhir terjadwal (memori). Dipakai
  /// buat membatalkan jadwal yang tidak lagi relevan tanpa menyapu
  /// ratusan slot tiap kali (sweep penuh hanya sekali di awal sesi).
  Set<int>? _kirimanTerjadwal;
  Set<int>? _utangTerjadwal;
  Set<int>? _utangHariIniTerjadwal;
  Set<int>? _targetTerjadwal;

  // ID notifikasi stabil: 1 = harian, 2-3 = uji,
  // 100+id kiriman, 100000+id utang (H-1), 150000+id utang (hari-H),
  // 200000+id target.
  static const _idHarian = 1;
  static const _idUji = 2;
  static const _idKirimanBase = 100;
  static const _idUtangBase = 100000;
  static const _idUtangHariIniBase = 150000;
  static const _idTargetBase = 200000;

  /// Siapkan plugin + minta izin notifikasi (Android 13+). Status izin
  /// alarm exact (Android 12+) hanya DICEK di sini; mintanya lewat
  /// tombol "Kirim notifikasi uji" (lihat [_mintaIzin]). Aman dipanggil
  /// berkali-kali; gagal = notifikasi mati, app tetap jalan.
  Future<void> siapkan() async {
    if (_siap || _menyiapkan) return;
    _menyiapkan = true;
    try {
      tzdata.initializeTimeZones();
      _pasangZonaHp();
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _siap = true;
    } catch (_) {
      _siap = false;
    } finally {
      _menyiapkan = false;
    }

    // Izin dipisah dari blok di atas supaya kegagalan minta izin
    // (mis. binding belum siap) TIDAK mematikan status _siap.
    if (!_siap) return;
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _mintaIzin();
      });
    } catch (_) {
      // Binding belum ada (dipanggil terlalu awal) - coba langsung.
      await _mintaIzin();
    }
  }

  /// [mintaExactAlarm] = true hanya dari tombol "Kirim notifikasi uji"
  /// (aksi user yang jelas konteksnya). requestExactAlarmsPermission di
  /// Android 12 membuka layar setelan khusus - kalau dipanggil otomatis
  /// tiap startup, HP pengguna yang menolak akan "dibawa" ke setelan
  /// setiap kali buka app. Di startup cukup CEK statusnya.
  Future<void> _mintaIzin({bool mintaExactAlarm = false}) async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return;
      // Android 13+: sekali saja; sudah pernah dijawab = otomatis.
      await android.requestNotificationsPermission();
      if (mintaExactAlarm) {
        try {
          await android.requestExactAlarmsPermission();
        } catch (_) {}
      }
      await _cekExact(android);
    } catch (_) {}
  }

  /// Segarkan _bolehExact (tanpa membuka layar setelan apa pun).
  Future<void> _cekExact(
      AndroidFlutterLocalNotificationsPlugin? android) async {
    try {
      _bolehExact =
          await android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      _bolehExact = false;
    }
  }

  /// Pasang zona waktu lokal plugin = zona HP (ikut waktu telepon).
  /// Cari zona di database tz yang offset-nya SAMA dengan offset HP
  /// sekarang (zona Indonesia dicek duluan biar namanya rapi untuk
  /// pengguna RI). Semua jadwal dibangun dari DateTime.now() perangkat,
  /// jadi apapun hasilnya pengingat tetap ikut jam HP.
  void _pasangZonaHp() {
    try {
      final offsetHp = DateTime.now().timeZoneOffset.inMilliseconds;
      for (final nama in const [
        'Asia/Jakarta',
        'Asia/Makassar',
        'Asia/Jayapura',
      ]) {
        final lok = tz.getLocation(nama);
        if (lok.currentTimeZone.offset == offsetHp) {
          tz.setLocalLocation(lok);
          return;
        }
      }
      // Zona RI tidak cocok (HP di luar Indonesia): cari zona mana pun
      // yang offset-nya sama dengan HP.
      for (final lok in tz.timeZoneDatabase.locations.values) {
        if (lok.currentTimeZone.offset == offsetHp) {
          tz.setLocalLocation(lok);
          return;
        }
      }
      // Nyaris mustahil gagal; kalau gagal, biarkan default - jadwal
      // tetap dihitung dari jam HP (input selalu DateTime.now()).
    } catch (_) {}
  }

  Future<void> _tampil(
    int id,
    String judul,
    String isi, {
    DateTime? waktu,
    bool ulangHarian = false,
  }) async {
    if (!_siap) return;
    const detail = NotificationDetails(
      android: AndroidNotificationDetails(
        'kosku',
        'kosku',
        channelDescription: 'Pengingat keuangan kosku',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    try {
      if (waktu == null) {
        await _plugin.show(id, judul, isi, detail);
        return;
      }
      final jadwal = tz.TZDateTime.from(waktu, tz.local);
      // Lewati waktu yang sudah lewat (device restart / data lama).
      if (jadwal.isBefore(tz.TZDateTime.now(tz.local))) return;
      await _plugin.zonedSchedule(
        id,
        judul,
        isi,
        jadwal,
        detail,
        androidScheduleMode: _bolehExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        // Ulang tiap hari di jam yang sama (khusus pengingat harian).
        matchDateTimeComponents: ulangHarian ? DateTimeComponents.time : null,
      );
    } catch (_) {
      // Jadwal gagal (mis. izin SCHEDULE_EXACT ditolak) → diam saja.
    }
  }

  /// "HH:MM" → (jam, menit). Format aneh / di luar jangkauan →
  /// default ([jDefault], [mDefault]) supaya jadwal tetap dibuat.
  (int, int) _parseJam(String s, int jDefault, int mDefault) {
    final bagian = s.split(':');
    if (bagian.length != 2) return (jDefault, mDefault);
    final j = int.tryParse(bagian[0]);
    final m = int.tryParse(bagian[1]);
    if (j == null || m == null || j < 0 || j > 23 || m < 0 || m > 59) {
      return (jDefault, mDefault);
    }
    return (j, m);
  }

  /// Waktu ideal pengingat: pukul [jam]:[menit] pada tanggal [hari].
  /// Kalau slot itu sudah lewat tapi harinya HARI INI, majukan ke
  /// sekarang + 5 menit supaya event yang dicatat mendadak tetap
  /// dapat pengingat hari ini (dulu: langsung di-skip diam-diam).
  /// Malam (mulai [batasMalam], default 20.00) tidak diganggu -
  /// besok saja ingatkan kalau masih relevan.
  DateTime? _slotPengingat(DateTime hari, int jam, int menit, DateTime batasMalam) {
    final kini = DateTime.now();
    final slot = DateTime(hari.year, hari.month, hari.day, jam, menit);
    if (slot.isAfter(kini)) return slot;
    final samaHari = hari.year == kini.year &&
        hari.month == kini.month &&
        hari.day == kini.day;
    if (!samaHari) return null;
    if (!kini.isBefore(batasMalam)) return null;
    return kini.add(const Duration(minutes: 5));
  }

  // ================= PENGINGAT HARIAN =================

  /// Nyalakan / matikan pengingat malam "catat pengeluaran"
  /// (default 20.00, bisa diubah lewat [jam] "HH:MM"). Kalau slot
  /// hari ini sudah lewat, mulai besok.
  Future<void> aturHarian(bool aktif, {String jam = '20:00'}) async {
    await siapkan();
    if (!_siap) return;
    try {
      await _plugin.cancel(_idHarian);
    } catch (_) {}
    if (!aktif) return;

    final (j, m) = _parseJam(jam, 20, 0);
    final kini = DateTime.now();
    var slot = DateTime(kini.year, kini.month, kini.day, j, m);
    if (!slot.isAfter(kini)) {
      slot = slot.add(const Duration(days: 1));
    }
    await _tampil(
      _idHarian,
      T.t('notif_catat_title'),
      T.t('notif_catat_body'),
      waktu: slot,
      ulangHarian: true,
    );
  }

  // ================= NOTIFIKASI UJI (Pengaturan) =================

  /// Kirim notifikasi uji dari layar Pengaturan: satu langsung muncul
  /// (menguji izin + channel) dan satu terjadwal 1 menit lagi (menguji
  /// alarm terjadwal - jalur yang sama dengan pengingat harian).
  /// Sekalian menawarkan izin "Alarms & reminders" (Android 12+) supaya
  /// pengingat terjadwal muncul tepat waktu. Return true kalau plugin
  /// siap.
  Future<bool> ujiNotifikasi() async {
    await siapkan();
    if (!_siap) return false;
    await _mintaIzin(mintaExactAlarm: true);
    await _tampil(
      _idUji,
      T.t('notif_uji_title'),
      T.t('notif_uji_body'),
    );
    await _tampil(
      _idUji + 1,
      T.t('notif_uji_jadwal_title'),
      T.t('notif_uji_jadwal_body'),
      waktu: DateTime.now().add(const Duration(minutes: 1)),
    );
    return true;
  }

  // ================= SINKRON JADWAL (dipanggil AppState) =================

  /// Sinkronkan seluruh jadwal dengan data terkini. Idempotent: kalau
  /// tanda tangan (isi data + setting) tidak berubah, tidak melakukan
  /// apa pun. Dipanggil dari muatSemua(). [jamPagi] = jam pengingat
  /// kiriman/utang/target ("HH:MM", default 08.00), [jamMalam] = jam
  /// pengingat catat pengeluaran (default 20.00) - keduanya bisa
  /// diubah user di Pengaturan dan ikut tanda tangan supaya ganti jam
  /// = jadwal ulang otomatis.
  Future<void> sinkronJadwal({
    required bool harianAktif,
    required List<Kiriman> kiriman,
    required List<Utang> utang,
    required List<TargetBeli> target,
    required int saldoPegangan,
    String jamPagi = '08:00',
    String jamMalam = '20:00',
  }) async {
    await siapkan();
    if (!_siap) return;

    // Segarkan status alarm exact sebelum menaruh jadwal (murah: satu
    // panggilan channel; TIDAK membuka layar setelan apa pun).
    await _cekExact(
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>());

    // Hanya kiriman menunggu, utang aktif, dan target berjalan yang
    // relevan.
    final kirimanTunggu = kiriman
        .where((k) => k.status == StatusKiriman.menunggu)
        .toList()
      ..sort((a, b) => a.id!.compareTo(b.id!));
    final utangAktif = utang
        .where((u) =>
            u.status == StatusUtang.aktif && u.jatuhTempo != null)
        .toList()
      ..sort((a, b) => a.id!.compareTo(b.id!));
    final targetBertanggal = target
        .where((t) => !t.tercapai && t.tanggal != null)
        .toList()
      ..sort((a, b) => a.id!.compareTo(b.id!));

    final tanda = [
      'harian:$harianAktif',
      // Bahasa ikut tanda tangan: ganti bahasa = jadwal ulang supaya
      // teks pengingat yang terpasang ikut berganti.
      'bahasa:${T.bahasa}',
      // Jam pengingat ikut: ganti jam di Pengaturan = pasang ulang
      // seluruh jadwal di jam yang baru.
      'pagi:$jamPagi',
      'malam:$jamMalam',
      // Saldo ikut: isi "kurang Rp X" pengingat target berganti tiap
      // saldo berubah. Mode exact ikut supaya jadwal lama dipasang
      // ulang sebagai alarm exact begitu izinnya diberikan.
      'saldo:$saldoPegangan',
      'exact:$_bolehExact',
      for (final k in kirimanTunggu) 'k${k.id}:${k.tanggalDatang}',
      for (final u in utangAktif) 'u${u.id}:${u.jatuhTempo}',
      for (final t in targetBertanggal) 't${t.id}:${t.tanggal}',
    ].join('|');
    if (tanda == _tandaTanganTerakhir) return;
    _tandaTanganTerakhir = tanda;

    final (jp, mp) = _parseJam(jamPagi, 8, 0);
    final (jm, mm) = _parseJam(jamMalam, 20, 0);
    final kini = DateTime.now();
    final batasMalam = DateTime(kini.year, kini.month, kini.day, jm, mm);

    // Pengingat harian (malam, jam bisa diatur).
    await aturHarian(harianAktif, jam: jamMalam);

    final batasJadwal = DateTime.now().add(const Duration(days: 30));

    // Kiriman: ingatkan pagi hari tanggal kiriman. Kalau kiriman
    // datangnya HARI INI tapi jam pengingat sudah lewat (dicatat siang
    // bolong), ingatkan segera.
    final idKirimanAktif = <int>{};
    for (final k in kirimanTunggu) {
      final waktu = _slotPengingat(k.tanggalDatang, jp, mp, batasMalam);
      if (waktu == null || waktu.isAfter(batasJadwal)) continue;
      idKirimanAktif.add(k.id!);
      await _tampil(
        _idKirimanBase + k.id!,
        T.f('notif_kiriman_title', {'n': rp(k.nominal)}),
        T.t('notif_kiriman_body'),
        waktu: waktu,
      );
    }

    // Utang / piutang: ingatkan H-1 DAN hari jatuh tempo sendiri
    // (dulu cuma H-1 - utang yang dicatat mendadak di hari-H tidak
    // pernah diingatkan sama sekali).
    final idUtangAktif = <int>{};
    final idUtangHariIniAktif = <int>{};
    for (final u in utangAktif) {
      final tempo = u.jatuhTempo!;
      final hMin = _slotPengingat(
        tempo.subtract(const Duration(days: 1)),
        jp,
        mp,
        batasMalam,
      );
      if (hMin != null && !hMin.isAfter(batasJadwal)) {
        idUtangAktif.add(u.id!);
        await _tampil(
          _idUtangBase + u.id!,
          T.f('notif_utang_title', {'x': u.pihak}),
          T.t('notif_utang_body'),
          waktu: hMin,
        );
      }
      final hIni = _slotPengingat(tempo, jp, mp, batasMalam);
      if (hIni != null && !hIni.isAfter(batasJadwal)) {
        idUtangHariIniAktif.add(u.id!);
        await _tampil(
          _idUtangHariIniBase + u.id!,
          T.f('notif_utang_hari_ini_title', {'x': u.pihak}),
          T.t('notif_utang_body'),
          waktu: hIni,
        );
      }
    }

    // Target beli bertanggal: ingatkan H-1 deadline.
    final idTargetAktif = <int>{};
    for (final t in targetBertanggal) {
      final waktu = _slotPengingat(
          t.tanggal!.subtract(const Duration(days: 1)), jp, mp, batasMalam);
      if (waktu == null || waktu.isAfter(batasJadwal)) continue;
      idTargetAktif.add(t.id!);
      final kurang = t.nominal - saldoPegangan;
      await _tampil(
        _idTargetBase + t.id!,
        T.f('notif_target_title', {'x': t.nama}),
        kurang > 0
            ? T.f('notif_target_body', {'n': rp(kurang)})
            : T.t('notif_target_body_ok'),
        waktu: waktu,
      );
    }

    // Batalkan jadwal yang tidak lagi relevan. Sesi pertama belum tahu
    // apa yang terjadwal → sapu rentang slot sekali; setelah itu cukup
    // batalkan yang pernah kita jadwalkan sendiri.
    await _batalYgTakDipakai(
      base: _idKirimanBase,
      aktif: idKirimanAktif,
      terjadwal: _kirimanTerjadwal,
      simpan: (s) => _kirimanTerjadwal = s,
    );
    await _batalYgTakDipakai(
      base: _idUtangBase,
      aktif: idUtangAktif,
      terjadwal: _utangTerjadwal,
      simpan: (s) => _utangTerjadwal = s,
    );
    await _batalYgTakDipakai(
      base: _idUtangHariIniBase,
      aktif: idUtangHariIniAktif,
      terjadwal: _utangHariIniTerjadwal,
      simpan: (s) => _utangHariIniTerjadwal = s,
    );
    await _batalYgTakDipakai(
      base: _idTargetBase,
      aktif: idTargetAktif,
      terjadwal: _targetTerjadwal,
      simpan: (s) => _targetTerjadwal = s,
    );
  }

  Future<void> _batalYgTakDipakai({
    required int base,
    required Set<int> aktif,
    required Set<int>? terjadwal,
    required void Function(Set<int>) simpan,
  }) async {
    if (terjadwal == null) {
      for (var slot = 0; slot < 500; slot++) {
        if (aktif.contains(slot)) continue;
        try {
          await _plugin.cancel(base + slot);
        } catch (_) {}
      }
    } else {
      for (final slot in terjadwal) {
        if (aktif.contains(slot)) continue;
        try {
          await _plugin.cancel(base + slot);
        } catch (_) {}
      }
    }
    simpan(aktif);
  }
}
