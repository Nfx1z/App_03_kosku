import 'package:flutter_test/flutter_test.dart';

import 'package:kosku/utils/format.dart';

/// Tes parser tanggal/jam dokumen (hasil scan) + gerbang tanggal wajar.
///
/// Kasus nyata yang memicu perbaikan ini: struk terbaca "18/11/2023"
/// padahal tahun berjalan 2026 → transaksi nyasar 3 tahun ke belakang
/// → "mulai pantau" tabungan hemat ikut mundur → layar Tabungan
/// tiba-tiba berisi hemat palsu tiap tanggal 1-16. Parser sekarang:
/// dd/MM Indonesia (mm/dd hanya kalau ketara), tahun hilang = tahun
/// berjalan, tanggal di luar jendela wajar ditolak.
///
/// Tanggal tes dihitung dinamis dari DateTime.now() supaya lolos
/// kapan pun tes dijalankan (termasuk di sekitar pergantian tahun,
/// saat aturan "tahun di bawah tahun berjalan" ikut menolak tanggal
/// Desember tahun lalu).
void main() {
  group('parseTanggalDokumen', () {
    test('ISO yyyy-MM-dd', () {
      final d = parseTanggalDokumen('2026-11-18');
      expect(d, DateTime(2026, 11, 18));
    });

    test('ISO dengan jam ikut terbuang', () {
      final d = parseTanggalDokumen('2026-11-18 14:23');
      expect(d, DateTime(2026, 11, 18));
    });

    test('dd/MM/yyyy format Indonesia', () {
      expect(parseTanggalDokumen('18/11/2026'), DateTime(2026, 11, 18));
      expect(parseTanggalDokumen('05/03/2026'), DateTime(2026, 3, 5));
      expect(parseTanggalDokumen('18-11-2026'), DateTime(2026, 11, 18));
      expect(parseTanggalDokumen('18.11.2026'), DateTime(2026, 11, 18));
    });

    test('mm/dd ketara (angka kedua > 12) dibaca MM/dd', () {
      // "12/28" cuma mungkin 28 Desember - walau posisinya di depan.
      expect(parseTanggalDokumen('12/28/2026'), DateTime(2026, 12, 28));
      expect(parseTanggalDokumen('11/18/2023'), DateTime(2023, 11, 18));
    });

    test('angka pertama > 12 tetap dd/MM', () {
      expect(parseTanggalDokumen('18/11/2026'), DateTime(2026, 11, 18));
      expect(parseTanggalDokumen('31/01/2026'), DateTime(2026, 1, 31));
    });

    test('tahun 2 digit → 20xx', () {
      expect(parseTanggalDokumen('18/11/25'), DateTime(2025, 11, 18));
      expect(parseTanggalDokumen('01/01/26'), DateTime(2026, 1, 1));
    });

    test('tanpa tahun → tahun berjalan', () {
      final kini = DateTime.now();
      final d = parseTanggalDokumen('18/11');
      expect(d, DateTime(kini.year, 11, 18));
    });

    test('tanggal mustahil → null (tidak memutar ke bulan lain)', () {
      expect(parseTanggalDokumen('31/02/2026'), isNull); // 31 Feb
      expect(parseTanggalDokumen('18/13/2026'), isNull); // bulan 13
      expect(parseTanggalDokumen('32/01/2026'), isNull); // hari 32
      expect(parseTanggalDokumen('13/13/2026'), isNull); // dua-duanya > 12
      expect(parseTanggalDokumen(''), isNull);
      expect(parseTanggalDokumen(null), isNull);
      expect(parseTanggalDokumen('not a date'), isNull);
    });
  });

  group('parseJamDokumen', () {
    test('format umum struk/bukti', () {
      expect(parseJamDokumen('14:35'), 14 * 60 + 35);
      expect(parseJamDokumen('14.35'), 14 * 60 + 35);
      expect(parseJamDokumen('09:05:22'), 9 * 60 + 5);
      expect(parseJamDokumen('14.35 WIB'), 14 * 60 + 35);
      expect(parseJamDokumen('07:55 WIB'), 7 * 60 + 55);
    });

    test('tidak wajar / kosong → null', () {
      expect(parseJamDokumen('25:00'), isNull);
      expect(parseJamDokumen('12:75'), isNull);
      expect(parseJamDokumen(''), isNull);
      expect(parseJamDokumen(null), isNull);
      expect(parseJamDokumen('tanpa jam'), isNull);
    });
  });

  group('validasiTanggalDokumen (gerbang wajar)', () {
    final kini = DateTime.now();

    test('hari ini diterima', () {
      expect(validasiTanggalDokumen(kini), tanggalSaja(kini));
    });

    test('baru beberapa hari lalu diterima (kecuali beda tahun)', () {
      final mingguLalu = kini.subtract(const Duration(days: 7));
      if (mingguLalu.year == kini.year) {
        expect(validasiTanggalDokumen(mingguLalu), isNotNull);
      } else {
        // Awal Januari: struk akhir Desember tahun lalu ditolak aturan
        // "tahun di bawah tahun berjalan" - memang disengaja.
        expect(validasiTanggalDokumen(mingguLalu), isNull);
      }
    });

    test('tahun di bawah tahun berjalan DITOLAK (kasus struk 2023)', () {
      expect(validasiTanggalDokumen(DateTime(kini.year - 1, 6, 1)), isNull);
      expect(validasiTanggalDokumen(DateTime(kini.year - 3, 11, 18)), isNull);
    });

    test('lebih dari 1 bulan lalu DITOLAK', () {
      // 2 bulan lalu: kena aturan bulan (atau aturan tahun kalau
      // kebetulan beda tahun) - dua-duanya menolak.
      final duaBulanLalu = DateTime(kini.year, kini.month - 2, kini.day);
      expect(validasiTanggalDokumen(duaBulanLalu), isNull);
    });

    test('masa depan DITOLAK (salah baca)', () {
      expect(
        validasiTanggalDokumen(kini.add(const Duration(days: 3))),
        isNull,
      );
    });

    test('null tetap null', () {
      expect(validasiTanggalDokumen(null), isNull);
    });
  });

  group('tanggalDenganJam & jamMenitLabel', () {
    test('jam dokumen dipakai kalau ada', () {
      final d = tanggalDenganJam(DateTime(2026, 11, 18), 14 * 60 + 35,
          DateTime(2026, 11, 18, 7, 10));
      expect(d, DateTime(2026, 11, 18, 14, 35));
    });

    test('jam dokumen tidak ada → jam cadangan (jam scan)', () {
      final d = tanggalDenganJam(
          DateTime(2026, 11, 18), null, DateTime(2026, 11, 18, 7, 10));
      expect(d, DateTime(2026, 11, 18, 7, 10));
    });

    test('label jam', () {
      expect(jamMenitLabel(14 * 60 + 35), '14:35');
      expect(jamMenitLabel(9 * 60 + 5), '09:05');
      expect(jamMenitLabel(0), '00:00');
    });
  });
}
