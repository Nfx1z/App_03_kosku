import 'package:flutter_test/flutter_test.dart';

import 'package:kosku/models/transaksi.dart';
import 'package:kosku/utils/parser_lokal.dart';

void main() {
  group('parseTeksLokal - jumlah', () {
    test('satuan rb / k / ribu', () {
      expect(parseTeksLokal('ngopi 15rb').jumlah, 15000);
      expect(parseTeksLokal('ngopi 15 rb').jumlah, 15000);
      expect(parseTeksLokal('kopi 15k').jumlah, 15000);
      expect(parseTeksLokal('kopi 15 ribu').jumlah, 15000);
    });

    test('satuan jt / juta (desimal)', () {
      expect(parseTeksLokal('laptop 1,5jt').jumlah, 1500000);
      expect(parseTeksLokal('laptop 1.5 juta').jumlah, 1500000);
      expect(parseTeksLokal('motor 20juta').jumlah, 20000000);
    });

    test('pemisah ribuan', () {
      expect(parseTeksLokal('gojek 12.500').jumlah, 12500);
      expect(parseTeksLokal('gojek 12,500').jumlah, 12500);
      expect(parseTeksLokal('tagihan 1.500.000').jumlah, 1500000);
    });

    test('angka telanjang kecil dianggap ribuan', () {
      expect(parseTeksLokal('ngopi 15').jumlah, 15000);
      expect(parseTeksLokal('parkir 2').jumlah, 2000);
    });

    test('angka telanjang besar apa adanya', () {
      expect(parseTeksLokal('nasgor 15000').jumlah, 15000);
    });

    test('tanpa angka → jumlah null', () {
      expect(parseTeksLokal('jajan aja').jumlah, null);
    });

    test('angka bersatuan menang atas angka telanjang', () {
      final h = parseTeksLokal('makan 3 kali 25rb');
      expect(h.jumlah, 25000);
      expect(h.nama, 'makan 3 kali');
    });
  });

  group('parseTeksLokal - nama & kategori', () {
    test('nama bersih tanpa angka', () {
      expect(parseTeksLokal('ngopi 15rb').nama, 'ngopi');
      expect(parseTeksLokal('belanja pokok 250rb').nama, 'belanja pokok');
      expect(parseTeksLokal('gojek ke kampus 12.500').nama, 'gojek ke kampus');
    });

    test('kata pengisi gaya ngomong dibuang dari nama', () {
      // Input suara panjang → nama tetap ringkas.
      expect(parseTeksLokal('tadi aku abis beli nasi padang 25rb').nama,
          'nasi padang');
      expect(parseTeksLokal('gua bayar gojek ke kampus 12rb').nama,
          'gojek ke kampus');
      expect(parseTeksLokal('bayarin wifi buat kos 100rb').nama, 'wifi kos');
    });

    test('kata kategori TIDAK ikut dibuang', () {
      // "belanja" / "makan" bagian dari nama kategori, harus utuh.
      expect(parseTeksLokal('belanja pokok 250rb').nama, 'belanja pokok');
      expect(parseTeksLokal('makan siang 20rb').nama, 'makan siang');
      expect(parseTeksLokal('jajan cireng 10rb').nama, 'jajan cireng');
    });

    test('kategori ditebak dari nama', () {
      expect(parseTeksLokal('ngopi 15rb').kategori,
          KategoriPengeluaran.makanMinum);
      expect(parseTeksLokal('gojek 12.500').kategori,
          KategoriPengeluaran.transport);
      expect(parseTeksLokal('belanja pokok 250rb').kategori,
          KategoriPengeluaran.belanjaPokok);
      expect(parseTeksLokal('netflix 50rb').kategori,
          KategoriPengeluaran.hiburan);
    });

    test('kategori tidak diketahui → null', () {
      expect(parseTeksLokal('xyz asal 10rb').kategori, null);
    });
  });

  group('parseTeksLokal - waktu', () {
    test('kemarin → offset -1 dan kata dibuang dari nama', () {
      final h = parseTeksLokal('ngopi kemarin 15rb');
      expect(h.offsetHari, -1);
      expect(h.nama, 'ngopi');
    });

    test('default hari ini', () {
      expect(parseTeksLokal('ngopi 15rb').offsetHari, 0);
    });
  });

  test('teks kosong', () {
    final h = parseTeksLokal('   ');
    expect(h.nama, null);
    expect(h.jumlah, null);
  });
}
