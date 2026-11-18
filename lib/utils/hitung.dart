import '../models/target.dart';
import 'format.dart';

/// Sisa hari sampai tanggal kiriman berikutnya.
int sisaHariMenuju({required DateTime kini, DateTime? tanggalKiriman}) {
  final hariIni = tanggalSaja(kini);
  if (tanggalKiriman != null) {
    final beda = tanggalSaja(tanggalKiriman).difference(hariIni).inDays;
    return beda < 1 ? 1 : beda;
  }
  final akhirBulan = DateTime(hariIni.year, hariIni.month + 1, 0);
  final beda = akhirBulan.difference(hariIni).inDays + 1;
  return beda < 1 ? 1 : beda;
}

/// Budget harian otomatis: saldo dibagi rata sisa hari.
int budgetHarian({required int saldo, required int sisaHari}) =>
    saldo <= 0 ? 0 : saldo ~/ sisaHari;

/// Proyeksi batas harian manual: berapa hari saldo bertahan kalau
/// konsisten belanja di [batas] per hari, dibanding sisa hari menuju
/// patokan (kiriman berikutnya / akhir bulan). Murni data - teksnya
/// dibangun di lapisan UI (dua bahasa).
class ProyeksiBatas {
  /// Hari bertahan di batas terpilih (efektif ~/ batas).
  final int hariBertahan;

  /// Sisa hari menuju patokan (kiriman berikutnya / akhir bulan).
  final int sisaHari;

  /// True kalau batas cukup: uang bertahan sampai patokan.
  final bool aman;

  /// Selisih di akhir patokan: positif = sisa uang, negatif = kurang.
  final int sisaAkhir;

  /// Batas yang pas: batas rata-rata yang bikin uang PAS sampai
  /// patokan. Kalau pengeluaran hari ini masih di bawah batas saran
  /// itu, uang jendela = saldo + terpakai (belanja hari ini masuk
  /// jatah hari ini). Kalau hari ini SUDAH lewat saran (jatah hari
  /// ini pasti abis), sisa saldo tinggal dibagi rata sisa hari
  /// SETELAH hari ini (sisaHari - 1).
  final int saranBatas;

  const ProyeksiBatas({
    required this.hariBertahan,
    required this.sisaHari,
    required this.aman,
    required this.sisaAkhir,
    required this.saranBatas,
  });
}

/// Hitung [ProyeksiBatas]. Batas <= 0 berarti belum diatur → null.
///
/// [terpakaiHariIni] = pengeluaran hari ini yang SUDAH keluar dari
/// saldo. Sisa jatah hari ini yang masih di dalam batas TIDAK boleh
/// mengurangi proyeksi - jatah hari ini sudah dihitung penuh lewat
/// `batas x sisa hari` (sisa hari mencakup hari ini). Hanya kelebihan
/// DI ATAS batas yang benar-benar memotong daya tahan uang.
/// Contoh: saldo 280rb, batas 50rb, sisa 7 hari, sudah belanja 30rb
/// hari ini → efektif 310rb → bertahan 6 hari... cek: butuh 350rb
/// sampai patokan, kurang 40rb.
ProyeksiBatas? proyeksiBatas({
  required int saldo,
  required int batas,
  required int sisaHari,
  int terpakaiHariIni = 0,
}) {
  if (batas <= 0) return null;
  final kembali = terpakaiHariIni < batas ? terpakaiHariIni : batas;
  final efektif = saldo + kembali;
  final hari = efektif <= 0 ? 0 : efektif ~/ batas;

  // Saran batas rata yang bikin uang pas sampai patokan. Dulu selalu
  // (saldo + min(terpakai, batas)) / sisaHari - itu MENYALAH di hari
  // yang lewat batas: jatah lama "dikembalikan" ke hitungan padahal
  // hari itu sudah keburu boros. Sekarang: kalau pengeluaran hari ini
  // masih muat di batas saran, saran = (saldo + terpakai) / sisaHari
  // (jatah hari ini dihitung penuh, sisa jatah hari ini masih bisa
  // dipakai). Kalau tidak muat (hari ini pasti lewat), hari ini sudah
  // selesai - saldo dibagi rata sisaHari - 1 hari berikutnya.
  // Contoh: saldo 313.811, terpakai 300.000, sisa 13 hari → saran
  // 26.150/hari (bukan 27.216 yang menghitung jatah hari ini lagi).
  final saranPenuh =
      budgetHarian(saldo: saldo + terpakaiHariIni, sisaHari: sisaHari);
  final saranBatas = terpakaiHariIni <= saranPenuh
      ? saranPenuh
      : budgetHarian(
          saldo: saldo,
          sisaHari: sisaHari > 1 ? sisaHari - 1 : 1,
        );

  return ProyeksiBatas(
    hariBertahan: hari,
    sisaHari: sisaHari,
    aman: hari >= sisaHari,
    sisaAkhir: efektif - batas * sisaHari,
    saranBatas: saranBatas,
  );
}

/// Hemat (sisa jatah) SATU BULAN untuk tabungan: jumlah dari
/// `batas - pengeluaran` setiap hari dari max([awalBulan],
/// [mulaiPantau]) sampai [hariTerakhir] (inklusif). Per hari dibatasi
/// minimal 0 supaya hari boros tidak "mencuri" tabungan hari lain.
/// Hari tanpa catatan dianggap tidak belanja (hemat penuh).
///
/// - [mulaiPantau] = hari pertama app memantau uang (aktivitas pertama);
///   hari sebelum itu tidak dihitung supaya tidak muncul tabungan palsu.
/// - [hariTerakhir] = batas hitung: kemarin untuk bulan berjalan, atau
///   hari aktivitas terakhir untuk bulan yang sudah tertutup (setelah
///   itu user berhenti mencatat → hari-hari berikutnya tidak dihitung).
int hematBulan({
  required int batas,
  required DateTime awalBulan,
  required DateTime mulaiPantau,
  required DateTime hariTerakhir,
  required Map<String, int> pengeluaranPerHari,
}) {
  if (batas <= 0) return 0;
  final awalHitung =
      mulaiPantau.isAfter(awalBulan) ? mulaiPantau : awalBulan;
  var total = 0;
  for (var d = tanggalSaja(awalHitung);
      !d.isAfter(hariTerakhir);
      d = d.add(const Duration(days: 1))) {
    final sisa = batas - (pengeluaranPerHari[kunciHari(d)] ?? 0);
    if (sisa > 0) total += sisa;
  }
  return total;
}

enum StatusSaran { siapBeli, aman, berat, perluWaktu }

/// Hasil hitungan saran untuk satu target beli.
/// Murni data - teksnya dibangun di lapisan UI (dua bahasa), lihat
/// [teksSaranTarget] di app_state / teks.dart.
class SaranTarget {
  final StatusSaran status;
  final int? nabungPerHari;
  final DateTime? tanggalSaran;

  /// Berapa kekurangan saldo (0 kalau sudah cukup).
  final int kurang;

  /// Kemampuan nabung per hari (batas harian − rata-rata belanja, min Rp 1.000).
  final int kemampuan;

  /// Sisa hari menuju deadline (null kalau target tanpa tanggal).
  final int? sisaHari;

  const SaranTarget(
    this.status, {
    this.nabungPerHari,
    this.tanggalSaran,
    this.kurang = 0,
    this.kemampuan = 0,
    this.sisaHari,
  });
}

/// Saran untuk satu target beli:
/// - saldo cukup        → siap beli
/// - ada tanggal, ringan → nabung Rp X/hari
/// - ada tanggal, berat  → peringatan proyeksi tidak cukup
/// - tanpa tanggal       → saran kapan realistis bisa beli
SaranTarget hitungSaranTarget({
  required TargetBeli target,
  required int saldoPegangan,
  required int batasHarianAktif,
  required int rataPengeluaran7Hari,
  required DateTime kini,
}) {
  final kurang = target.nominal - saldoPegangan;
  if (kurang <= 0) {
    return const SaranTarget(StatusSaran.siapBeli, kurang: 0);
  }

  // Kemampuan nabung per hari = sisa "napas" harian dibanding kebiasaan belanja.
  final mentah = batasHarianAktif - rataPengeluaran7Hari;
  final kemampuan = mentah < 1000 ? 1000 : mentah;

  if (target.tanggal != null) {
    final sisa = sisaHariMenuju(kini: kini, tanggalKiriman: target.tanggal);
    final perHari = (kurang / sisa).ceil();
    if (perHari <= kemampuan) {
      return SaranTarget(
        StatusSaran.aman,
        nabungPerHari: perHari,
        kurang: kurang,
        kemampuan: kemampuan,
        sisaHari: sisa,
        tanggalSaran: target.tanggal,
      );
    }
    return SaranTarget(
      StatusSaran.berat,
      nabungPerHari: perHari,
      kurang: kurang,
      kemampuan: kemampuan,
      sisaHari: sisa,
    );
  }

  final hari = (kurang / kemampuan).ceil();
  final saran = tanggalSaja(kini).add(Duration(days: hari));
  return SaranTarget(
    StatusSaran.perluWaktu,
    nabungPerHari: kemampuan,
    kurang: kurang,
    kemampuan: kemampuan,
    sisaHari: hari,
    tanggalSaran: saran,
  );
}
