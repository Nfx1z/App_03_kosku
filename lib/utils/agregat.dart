import '../models/transaksi.dart';

/// Ringkasan statistik pengeluaran satu bulan - murni data, gampang dites.
class RingkasanBulan {
  final int tahun;
  final int bulan;
  final int totalPengeluaran;
  final int totalPemasukan;
  final int jumlahTransaksi;
  final int rataHarian;
  final int hariTanpaBelanja;
  final Map<KategoriPengeluaran, int> perKategori;
  final List<int> perHari; // panjang = jumlah hari dalam bulan, index 0 = tgl 1
  final Transaksi? terbesar;

  /// Uang keluar lain bulan ini (bayar kos, wifi, setor keluarga).
  /// Tetap ditampilkan di laporan sebagai bagian terpisah, tapi TIDAK
  /// dihitung di [totalPengeluaran] / [perHari] / [perKategori] supaya
  /// tidak membebani statistik belanja harian.
  final List<Transaksi> keluarLainList;

  const RingkasanBulan({
    required this.tahun,
    required this.bulan,
    required this.totalPengeluaran,
    required this.totalPemasukan,
    required this.jumlahTransaksi,
    required this.rataHarian,
    required this.hariTanpaBelanja,
    required this.perKategori,
    required this.perHari,
    this.terbesar,
    this.keluarLainList = const [],
  });

  /// Total uang keluar lain bulan ini.
  int get totalKeluarLain =>
      keluarLainList.fold(0, (a, t) => a + t.jumlah);

  /// Kategori terurut dari nominal terbesar.
  List<MapEntry<KategoriPengeluaran, int>> get kategoriUrut {
    final e = perKategori.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return e;
  }

  bool get kosong => jumlahTransaksi == 0;
}

int _jumlahHari(int tahun, int bulan) => DateTime(tahun, bulan + 1, 0).day;

/// Ringkas daftar transaksi (satu bulan penuh) jadi statistik.
/// [kini] dipakai untuk rata-rata harian: bulan berjalan dibagi hari terpakai,
/// bulan lampau dibagi jumlah hari bulan itu.
RingkasanBulan ringkasBulan(
  List<Transaksi> transaksi, {
  required int tahun,
  required int bulan,
  required DateTime kini,
}) {
  final jumlahHari = _jumlahHari(tahun, bulan);
  final perHari = List<int>.filled(jumlahHari, 0);
  final perKategori = <KategoriPengeluaran, int>{};
  final keluarLainList = <Transaksi>[];
  var totalPengeluaran = 0;
  var totalPemasukan = 0;
  var jumlah = 0;
  Transaksi? terbesar;

  for (final t in transaksi) {
    final d = t.dibuatPada;
    if (d.year != tahun || d.month != bulan) continue;

    if (t.jenis == JenisTransaksi.pengeluaran) {
      jumlah++;
      totalPengeluaran += t.jumlah;
      final idx = d.day - 1;
      if (idx >= 0 && idx < perHari.length) perHari[idx] += t.jumlah;
      if (t.kategori != null) {
        perKategori[t.kategori!] = (perKategori[t.kategori!] ?? 0) + t.jumlah;
      }
      if (terbesar == null || t.jumlah > terbesar.jumlah) terbesar = t;
    } else if (t.jenis == JenisTransaksi.keluarLain) {
      // Kewajiban (kos, wifi, dll): direkam terpisah, tetap muncul
      // di laporan bulanan sebagai bagian tersendiri.
      keluarLainList.add(t);
    } else if (t.jenis == JenisTransaksi.pemasukan ||
        // Uang masuk lain (hadiah, jualan) ikut dihitung sebagai uang masuk,
        // konsisten dengan ringkasan di Riwayat.
        t.jenis == JenisTransaksi.masukLain) {
      totalPemasukan += t.jumlah;
    }
  }

  final bulanBerjalan = kini.year == tahun && kini.month == bulan;
  final pembagi = bulanBerjalan
      ? (kini.day < 1 ? 1 : kini.day)
      : jumlahHari;

  final hariAktif = perHari.where((n) => n > 0).length;
  final hariTanpaBelanja =
      (pembagi - hariAktif).clamp(0, pembagi).toInt();

  return RingkasanBulan(
    tahun: tahun,
    bulan: bulan,
    totalPengeluaran: totalPengeluaran,
    totalPemasukan: totalPemasukan,
    jumlahTransaksi: jumlah,
    rataHarian: totalPengeluaran ~/ pembagi,
    hariTanpaBelanja: hariTanpaBelanja,
    perKategori: perKategori,
    perHari: perHari,
    terbesar: terbesar,
    keluarLainList: keluarLainList,
  );
}

/// Selisih per kategori bulan ini vs bulan lalu (positif = naik).
Map<KategoriPengeluaran, int> deltaKategori(
  RingkasanBulan bulanLalu,
  RingkasanBulan bulanIni,
) {
  final hasil = <KategoriPengeluaran, int>{};
  for (final e in bulanIni.perKategori.entries) {
    hasil[e.key] = e.value - (bulanLalu.perKategori[e.key] ?? 0);
  }
  for (final e in bulanLalu.perKategori.entries) {
    hasil.putIfAbsent(e.key, () => -e.value);
  }
  return hasil;
}
