import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:kosku/models/target.dart';
import 'package:kosku/models/transaksi.dart';
import 'package:kosku/utils/format.dart';
import 'package:kosku/utils/hitung.dart';
import 'package:kosku/utils/teks.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  group('parseRupiah', () {
    test('baca angka bebas format', () {
      expect(parseRupiah('15000'), 15000);
      expect(parseRupiah('15.000'), 15000);
      expect(parseRupiah('Rp 15.000'), 15000);
      expect(parseRupiah('1.500.000'), 1500000);
      expect(parseRupiah(''), 0);
      expect(parseRupiah('abc'), 0);
    });
  });

  group('rp', () {
    // Format angka mengikuti bahasa UI - kunci bahasanya eksplisit
    // supaya test tidak tergantung default (default app kini 'en').
    test('format Indonesia pakai titik ribuan', () {
      T.bahasa = 'id';
      expect(rp(15000), 'Rp 15.000');
      expect(rp(1500000), 'Rp 1.500.000');
      expect(rp(0), 'Rp 0');
    });

    test('English format uses comma separators', () {
      T.bahasa = 'en';
      expect(rp(15000), 'Rp 15,000');
      expect(rp(1500000), 'Rp 1,500,000');
      expect(rp(0), 'Rp 0');
    });
  });

  group('tebakKategori', () {
    test('menebak dari kata kunci', () {
      expect(tebakKategori('esteh'), KategoriPengeluaran.makanMinum);
      expect(tebakKategori('gojek ke kampus'), KategoriPengeluaran.transport);
      expect(tebakKategori('token listrik'), KategoriPengeluaran.tagihanRumah);
      expect(tebakKategori('netflix'), KategoriPengeluaran.hiburan);
      expect(tebakKategori('obat flu'), KategoriPengeluaran.kesehatan);
      expect(tebakKategori('habis no clue'), KategoriPengeluaran.lainLain);
    });
  });

  group('sisaHariMenuju', () {
    final kini = DateTime(2026, 11, 16);

    test('ke kiriman besok = 1', () {
      expect(
        sisaHariMenuju(kini: kini, tanggalKiriman: DateTime(2026, 11, 17)),
        1,
      );
    });

    test('ke kiriman 4 hari lagi', () {
      expect(
        sisaHariMenuju(kini: kini, tanggalKiriman: DateTime(2026, 11, 20)),
        4,
      );
    });

    test('tanggal lewat → minimal 1', () {
      expect(
        sisaHariMenuju(kini: kini, tanggalKiriman: DateTime(2026, 11, 10)),
        1,
      );
    });

    test('tanpa kiriman → sisa hari bulan ini', () {
      // 16 Nov → akhir bulan 30 Nov = 15 hari (16..30)
      expect(sisaHariMenuju(kini: kini), 15);
    });
  });

  group('budgetHarian', () {
    test('dibagi rata', () {
      expect(budgetHarian(saldo: 300000, sisaHari: 10), 30000);
      expect(budgetHarian(saldo: 100000, sisaHari: 3), 33333);
    });

    test('saldo nol / minus → 0', () {
      expect(budgetHarian(saldo: 0, sisaHari: 5), 0);
      expect(budgetHarian(saldo: -5000, sisaHari: 5), 0);
    });
  });

  group('hitungSaranTarget', () {
    final kini = DateTime(2026, 11, 16);

    TargetBeli target(
      String nama,
      int nominal, {
      DateTime? tanggal,
    }) =>
        TargetBeli(nama: nama, nominal: nominal, tanggal: tanggal);

    test('saldo cukup → siap beli', () {
      final s = hitungSaranTarget(
        target: target('lipstik', 100000),
        saldoPegangan: 150000,
        batasHarianAktif: 30000,
        rataPengeluaran7Hari: 20000,
        kini: kini,
      );
      expect(s.status, StatusSaran.siapBeli);
    });

    test('ada tanggal & ringan → aman, saran nabung per hari', () {
      final s = hitungSaranTarget(
        target: target('gunung', 5000000, tanggal: DateTime(2027, 1, 16)),
        saldoPegangan: 4000000,
        batasHarianAktif: 40000,
        rataPengeluaran7Hari: 20000,
        kini: kini,
      );
      // kurang 1jt / 61 hari = 16.394/hari ≤ kemampuan 20rb → aman
      expect(s.status, StatusSaran.aman);
      expect(s.nabungPerHari, 16394);
    });

    test('ada tanggal & berat → peringatan', () {
      final s = hitungSaranTarget(
        target: target('laptop', 10000000, tanggal: DateTime(2026, 11, 23)),
        saldoPegangan: 1000000,
        batasHarianAktif: 30000,
        rataPengeluaran7Hari: 25000,
        kini: kini,
      );
      // kurang 9jt / 7 hari = 1.285.714/hari, jauh di atas kemampuan
      expect(s.status, StatusSaran.berat);
    });

    test('tanpa tanggal → saran kapan bisa beli', () {
      final s = hitungSaranTarget(
        target: target('lipstik', 100000),
        saldoPegangan: 40000,
        batasHarianAktif: 30000,
        rataPengeluaran7Hari: 20000,
        kini: kini,
      );
      // kurang 60rb, kemampuan 10rb/hari → 6 hari
      expect(s.status, StatusSaran.perluWaktu);
      expect(s.tanggalSaran, DateTime(2026, 11, 22));
    });
  });

  group('hematBulan (tabungan bulanan + bawaan)', () {
    final nov = DateTime(2026, 11, 1);

    test('jumlah sisa jatah tanggal 1 sampai hari terakhir', () {
      // batas 50rb; tgl 1 kepakai 30rb, tgl 2 boros 80rb (hitung 0),
      // tgl 3 tidak belanja, tgl 4 pas 50rb (0), tgl 5 kepakai 40rb.
      final perHari = {
        kunciHari(DateTime(2026, 11, 1)): 30000,
        kunciHari(DateTime(2026, 11, 2)): 80000,
        kunciHari(DateTime(2026, 11, 4)): 50000,
        kunciHari(DateTime(2026, 11, 5)): 40000,
      };
      expect(
        hematBulan(
          batas: 50000,
          awalBulan: nov,
          mulaiPantau: nov,
          hariTerakhir: DateTime(2026, 11, 5),
          pengeluaranPerHari: perHari,
        ),
        // (50-30) + 0 + 50 + 0 + (50-40) = 80rb
        80000,
      );
    });

    test('mulaiPantau di tengah bulan → hari sebelumnya tidak dihitung', () {
      final perHari = {
        kunciHari(DateTime(2026, 11, 1)): 10000, // sebelum pantau, abaikan
        kunciHari(DateTime(2026, 11, 10)): 20000,
        kunciHari(DateTime(2026, 11, 11)): 30000,
      };
      expect(
        hematBulan(
          batas: 50000,
          awalBulan: nov,
          mulaiPantau: DateTime(2026, 11, 10),
          hariTerakhir: DateTime(2026, 11, 11),
          pengeluaranPerHari: perHari,
        ),
        // (50-20) + (50-30) = 50rb
        50000,
      );
    });

    test('hari boros tidak mencuri tabungan hari lain', () {
      final perHari = {
        kunciHari(DateTime(2026, 11, 1)): 150000,
        kunciHari(DateTime(2026, 11, 2)): 0,
      };
      expect(
        hematBulan(
          batas: 50000,
          awalBulan: nov,
          mulaiPantau: nov,
          hariTerakhir: DateTime(2026, 11, 2),
          pengeluaranPerHari: perHari,
        ),
        // 0 + 50 = 50rb (bukan 50 - 100 = minus)
        50000,
      );
    });

    test('batas nol / hariTerakhir sebelum mulai → 0', () {
      expect(
        hematBulan(
          batas: 0,
          awalBulan: nov,
          mulaiPantau: nov,
          hariTerakhir: DateTime(2026, 11, 5),
          pengeluaranPerHari: {},
        ),
        0,
      );
      expect(
        hematBulan(
          batas: 50000,
          awalBulan: nov,
          mulaiPantau: DateTime(2026, 11, 10),
          hariTerakhir: DateTime(2026, 11, 5),
          pengeluaranPerHari: {},
        ),
        0,
      );
    });

    test('bulan penuh terpantau (tanggal 1-30)', () {
      expect(
        hematBulan(
          batas: 50000,
          awalBulan: nov,
          mulaiPantau: nov,
          hariTerakhir: DateTime(2026, 11, 30),
          pengeluaranPerHari: {},
        ),
        50000 * 30,
      );
    });
  });

  group('proyeksiBatas', () {
    test('batas nol / belum diatur → null', () {
      expect(proyeksiBatas(saldo: 100000, batas: 0, sisaHari: 5), isNull);
    });

    test('aman: saldo pas sampai patokan', () {
      final p = proyeksiBatas(saldo: 300000, batas: 30000, sisaHari: 10)!;
      expect(p.hariBertahan, 10);
      expect(p.aman, isTrue);
      expect(p.sisaAkhir, 0);
      expect(p.saranBatas, 30000);
    });

    test('kurang: habis sebelum patokan + saran batas', () {
      final p = proyeksiBatas(saldo: 150000, batas: 30000, sisaHari: 10)!;
      expect(p.hariBertahan, 5);
      expect(p.aman, isFalse);
      expect(p.sisaAkhir, -150000);
      expect(p.saranBatas, 15000);
    });

    test('lebih: sisa uang di patokan', () {
      final p = proyeksiBatas(saldo: 400000, batas: 30000, sisaHari: 10)!;
      expect(p.aman, isTrue);
      expect(p.sisaAkhir, 100000);
    });

    test('saldo nol → bertahan 0 hari, saran 0', () {
      final p = proyeksiBatas(saldo: 0, batas: 20000, sisaHari: 5)!;
      expect(p.hariBertahan, 0);
      expect(p.aman, isFalse);
      expect(p.saranBatas, 0);
    });

    test('pengeluaran hari ini DI DALAM batas tidak mengurangi proyeksi', () {
      // Sudah belanja 30rb dari batas 50rb hari ini: jatah hari ini
      // dihitung penuh lewat batas x sisa hari, jadi 30rb itu tidak
      // boleh dihitung dua kali.
      final p = proyeksiBatas(
        saldo: 320000,
        batas: 50000,
        sisaHari: 7,
        terpakaiHariIni: 30000,
      )!;
      // Efektif = 320rb + 30rb = 350rb = pas 50rb x 7 hari.
      expect(p.aman, isTrue);
      expect(p.sisaAkhir, 0);
      expect(p.saranBatas, 50000);
    });

    test('kelebihan DI ATAS batas tetap memotong proyeksi', () {
      // Terpakai 70rb, batas 50rb: hanya 50rb yang "dikembalikan",
      // 20rb kelebihannya benar-benar mengurangi daya tahan.
      final p = proyeksiBatas(
        saldo: 320000,
        batas: 50000,
        sisaHari: 7,
        terpakaiHariIni: 70000,
      )!;
      // Efektif = 320rb + 50rb = 370rb; butuh 350rb → aman, sisa 20rb.
      expect(p.aman, isTrue);
      expect(p.sisaAkhir, 20000);
    });

    test('contoh kurang dengan belanja hari ini', () {
      final p = proyeksiBatas(
        saldo: 280000,
        batas: 50000,
        sisaHari: 7,
        terpakaiHariIni: 30000,
      )!;
      // Efektif 310rb → 6 hari (butuh 350rb, kurang 40rb).
      expect(p.hariBertahan, 6);
      expect(p.aman, isFalse);
      expect(p.sisaAkhir, -40000);
      expect(p.saranBatas, 44285); // 310rb ~/ 7
    });

    test('hari lewat batas: saran tidak menghitung jatah hari ini lagi', () {
      // Kasus nyata dari user: saldo 313.811, sudah belanja 300.000,
      // batas 40.000, sisa 13 hari. Jatah hari ini sudah abis, jadi
      // saran = saldo ÷ (sisa - 1) = 313.811 ~/ 12 = 26.150.
      // (Dulu salah: (saldo + batas) / sisa = 27.216 - jatah lama
      // "dikembalikan" padahal hari ini sudah boros.)
      final p = proyeksiBatas(
        saldo: 313811,
        batas: 40000,
        sisaHari: 13,
        terpakaiHariIni: 300000,
      )!;
      expect(p.saranBatas, 26150);
    });

    test('hari lewat batas (terpakai di antara): pakai sisa hari - 1', () {
      // saranPenuh = 130rb ~/ 5 = 26.000 < terpakai 30.000 → hari ini
      // pasti lewat saran mana pun → saldo 100rb dibagi 4 hari = 25.000.
      final p = proyeksiBatas(
        saldo: 100000,
        batas: 50000,
        sisaHari: 5,
        terpakaiHariIni: 30000,
      )!;
      expect(p.saranBatas, 25000);
    });

    test('batas saran pas dengan terpakai: tetap rumus penuh', () {
      // saranPenuh = 156rb ~/ 5 = 31.200 ≥ terpakai 26.000 → belanja
      // hari ini masih muat di batas saran → rumus (saldo+terpakai)/sisa.
      final p = proyeksiBatas(
        saldo: 130000,
        batas: 50000,
        sisaHari: 5,
        terpakaiHariIni: 26000,
      )!;
      expect(p.saranBatas, 31200);
    });
  });
}
