import 'package:flutter_test/flutter_test.dart';

import 'package:kosku/models/transaksi.dart';
import 'package:kosku/utils/agregat.dart';

void main() {
  final kini = DateTime(2026, 11, 16); // November 2026, 30 hari

  Transaksi pengeluaran(
    int hari,
    int jumlah, {
    KategoriPengeluaran kategori = KategoriPengeluaran.makanMinum,
    String nama = 'tes',
    int bulan = 11,
  }) =>
      Transaksi(
        jenis: JenisTransaksi.pengeluaran,
        jumlah: jumlah,
        kategori: kategori,
        catatan: nama,
        dibuatPada: DateTime(2026, bulan, hari, 10),
      );

  final data = [
    pengeluaran(1, 10000, nama: 'esteh'),
    pengeluaran(1, 5000, kategori: KategoriPengeluaran.transport, nama: 'gojek'),
    pengeluaran(2, 20000, nama: 'nasi goreng'),
    pengeluaran(10, 50000,
        kategori: KategoriPengeluaran.hiburan, nama: 'netflix'),
    // Bulan lain & jenis lain → tidak ikut dihitung.
    Transaksi(
      jenis: JenisTransaksi.pemasukan,
      jumlah: 200000,
      dibuatPada: DateTime(2026, 11, 3),
    ),
    // Uang masuk lain (hadiah/jualan) ikut dihitung sebagai uang masuk.
    Transaksi(
      jenis: JenisTransaksi.masukLain,
      jumlah: 25000,
      catatan: 'jual buku bekas',
      dibuatPada: DateTime(2026, 11, 8),
    ),
    // Uang keluar lain BUKAN pengeluaran → tidak menggeser statistik belanja.
    Transaksi(
      jenis: JenisTransaksi.keluarLain,
      jumlah: 50000,
      catatan: 'setor tabungan',
      dibuatPada: DateTime(2026, 11, 9),
    ),
    Transaksi(
      jenis: JenisTransaksi.pengeluaran,
      jumlah: 99000,
      dibuatPada: DateTime(2026, 10, 20), // Oktober, di luar rentang
    ),
  ];

  test('ringkasBulan - total & jumlah', () {
    final r = ringkasBulan(data, tahun: 2026, bulan: 11, kini: kini);
    expect(r.totalPengeluaran, 85000);
    expect(r.jumlahTransaksi, 4);
    // pemasukan (kiriman) + uang masuk lain
    expect(r.totalPemasukan, 225000);
  });

  test('ringkasBulan - rata-rata & hari tanpa belanja', () {
    final r = ringkasBulan(data, tahun: 2026, bulan: 11, kini: kini);
    // Bulan berjalan, hari ke-16 → 85000 / 16 = 5312
    expect(r.rataHarian, 5312);
    // Belanja di hari 1, 2, 10 → 16 - 3 = 13 hari tanpa belanja
    expect(r.hariTanpaBelanja, 13);
  });

  test('ringkasBulan - per kategori & urutan', () {
    final r = ringkasBulan(data, tahun: 2026, bulan: 11, kini: kini);
    expect(r.perKategori[KategoriPengeluaran.makanMinum], 30000);
    expect(r.perKategori[KategoriPengeluaran.hiburan], 50000);
    expect(r.kategoriUrut.first.key, KategoriPengeluaran.hiburan);
  });

  test('ringkasBulan - per hari', () {
    final r = ringkasBulan(data, tahun: 2026, bulan: 11, kini: kini);
    expect(r.perHari.length, 30);
    expect(r.perHari[0], 15000); // tgl 1: esteh + gojek
    expect(r.perHari[1], 20000); // tgl 2
    expect(r.perHari[9], 50000); // tgl 10
    expect(r.perHari[29], 0); // tgl 30
  });

  test('ringkasBulan - pengeluaran terbesar', () {
    final r = ringkasBulan(data, tahun: 2026, bulan: 11, kini: kini);
    expect(r.terbesar!.jumlah, 50000);
    expect(r.terbesar!.catatan, 'netflix');
  });

  test('ringkasBulan - bulan lampau dibagi jumlah hari penuh', () {
    final r = ringkasBulan(data, tahun: 2026, bulan: 10, kini: kini);
    expect(r.totalPengeluaran, 99000);
    expect(r.rataHarian, 99000 ~/ 31); // Oktober punya 31 hari
  });

  test('ringkasBulan - uang keluar lain tampil di laporan (bagian sendiri)', () {
    final r = ringkasBulan(data, tahun: 2026, bulan: 11, kini: kini);
    // Wajib muncul di laporan bulanan sebagai bagian terpisah...
    expect(r.keluarLainList.length, 1);
    expect(r.keluarLainList.first.catatan, 'setor tabungan');
    expect(r.totalKeluarLain, 50000);
    // ...tapi TIDAK mencemur statistik belanja harian.
    expect(r.totalPengeluaran, 85000);
    expect(r.perHari[8], 0); // tgl 9 (hari setor) tidak terhitung
    expect(r.jumlahTransaksi, 4);
  });

  test('deltaKategori - naik/turun vs bulan lalu', () {
    final ini = ringkasBulan(data, tahun: 2026, bulan: 11, kini: kini);
    final kosong = ringkasBulan([], tahun: 2026, bulan: 10, kini: kini);
    final d = deltaKategori(kosong, ini);
    expect(d[KategoriPengeluaran.makanMinum], 30000);
    expect(d[KategoriPengeluaran.hiburan], 50000);

    final lalu = ringkasBulan([
      pengeluaran(5, 40000,
          kategori: KategoriPengeluaran.makanMinum, bulan: 10),
    ], tahun: 2026, bulan: 10, kini: kini);
    final d2 = deltaKategori(lalu, ini);
    expect(d2[KategoriPengeluaran.makanMinum], -10000); // turun
    expect(d2[KategoriPengeluaran.hiburan], 50000); // baru muncul
  });
}
