import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/transaksi.dart';
import 'agregat.dart';
import 'format.dart';
import 'teks.dart';

/// Warna brand di PDF (dusty pink Kosku, sama dengan tema aplikasi).
const _warnaUtama = PdfColor.fromInt(0xFFB26676);
const _warnaTinta = PdfColor.fromInt(0xFF38292C);
const _warnaAbu = PdfColor.fromInt(0xFF8A7074);
const _warnaGaris = PdfColor.fromInt(0xFFE8D8D6);
const _warnaKrem = PdfColor.fromInt(0xFFFFF5EF);
const _warnaKosong = PdfColor.fromInt(0xFFF2E2DC);

/// Gaya teks tebal (judul, angka penting). Sengaja TIDAK `const`:
/// sejak pdf 3.13, konstruktor TextStyle membandingkan enum
/// fontWeight di initializer-nya, dan perbandingan enum bukan
/// ekspresi konstan yang valid di Dart
/// (const_eval_type_bool_num_string).
pw.TextStyle _gayaTebal(double ukuran, PdfColor warna) => pw.TextStyle(
      fontSize: ukuran,
      fontWeight: pw.FontWeight.bold,
      color: warna,
    );

/// Bangun PDF laporan bulanan. Semua teks Latin (Helvetica bawaan), dua
/// bahasa mengikuti T.bahasa. Return bytes siap dibagikan/di-print.
Future<Uint8List> buatPdfLaporan({
  required RingkasanBulan ini,
  RingkasanBulan? lalu,
}) async {
  final pdf = pw.Document();

  final kotakStat = <pw.Widget>[
    // Label polos tanpa placeholder - angkanya ditampilkan terpisah
    // di bawah label (dulu pakai key ber-placeholder '{n} transaksi'
    // yang muncul mentah di PDF).
    _kotakStat(T.t('rata_harian'), rp(ini.rataHarian)),
    _kotakStat(T.t('jumlah_transaksi_label'), '${ini.jumlahTransaksi}'),
    _kotakStat(T.t('hari_tanpa_belanja_label'), '${ini.hariTanpaBelanja}'),
    _kotakStat(T.t('pdf_pemasukan'), rp(ini.totalPemasukan)),
  ];

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (context) => [
        // ---------- kepala ----------
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: _warnaGaris),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'kosku',
                    style: _gayaTebal(22, _warnaUtama),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${T.t('laporan_judul')} ${namaBulanTahun(ini.tahun, ini.bulan)}',
                    style: const pw.TextStyle(
                      fontSize: 13,
                      color: _warnaAbu,
                    ),
                  ),
                ],
              ),
              pw.Text(
                T.t('pdf_dibuat_oleh'),
                style: const pw.TextStyle(fontSize: 9, color: _warnaAbu),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),

        // ---------- total ----------
        pw.Text(
          T.t('total_pengeluaran').toUpperCase(),
          style: const pw.TextStyle(fontSize: 10, color: _warnaAbu),
        ),
        pw.Text(
          rp(ini.totalPengeluaran),
          style: _gayaTebal(30, _warnaTinta),
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          children: [
            for (var i = 0; i < kotakStat.length; i++) ...[
              pw.Expanded(child: kotakStat[i]),
              if (i < kotakStat.length - 1) pw.SizedBox(width: 8),
            ],
          ],
        ),
        pw.SizedBox(height: 20),

        // ---------- vs bulan lalu ----------
        if (lalu != null) ...[
          _barisVs(lalu, ini),
          pw.SizedBox(height: 20),
        ],

        // ---------- per kategori ----------
        pw.Text(
          T.t('per_kategori'),
          style: _gayaTebal(13, _warnaTinta),
        ),
        pw.SizedBox(height: 10),
        if (ini.kategoriUrut.isEmpty)
          pw.Text(
            T.t('laporan_kosong'),
            style: const pw.TextStyle(color: _warnaAbu),
          )
        else
          ...ini.kategoriUrut.map((e) => _barisKategori(e.key, e.value, ini)),

        pw.SizedBox(height: 20),

        // ---------- uang keluar lain (kos, wifi, dll) ----------
        if (ini.keluarLainList.isNotEmpty) ...[
          pw.Text(
            T.t('pengeluaran_lainnya'),
            style: _gayaTebal(13, _warnaTinta),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            T.t('pengeluaran_lainnya_sub'),
            style: const pw.TextStyle(fontSize: 9, color: _warnaAbu),
          ),
          pw.SizedBox(height: 8),
          ...ini.keluarLainList.map(_barisKeluarLain),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: const pw.BoxDecoration(color: _warnaKrem),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  T.t('total_keluar_lain'),
                  style: _gayaTebal(11, _warnaTinta),
                ),
                pw.Text(
                  rp(ini.totalKeluarLain),
                  style: _gayaTebal(11, _warnaUtama),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
        ],

        // ---------- tren harian ----------
        pw.Text(
          T.t('tren_harian'),
          style: _gayaTebal(13, _warnaTinta),
        ),
        pw.SizedBox(height: 10),
        _grafikHarian(ini),

        pw.SizedBox(height: 20),

        // ---------- pengeluaran terbesar ----------
        if (ini.terbesar != null) ...[
          pw.Text(
            T.t('pengeluaran_terbesar'),
            style: _gayaTebal(13, _warnaTinta),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: const pw.BoxDecoration(color: _warnaKrem),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    ini.terbesar!.catatan ?? T.t('judul_pengeluaran'),
                    style: _gayaTebal(12, _warnaTinta),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Text(
                  tanggalPendek(ini.terbesar!.dibuatPada),
                  style: const pw.TextStyle(fontSize: 10, color: _warnaAbu),
                ),
                pw.SizedBox(width: 10),
                pw.Text(
                  rp(ini.terbesar!.jumlah),
                  style: _gayaTebal(12, _warnaUtama),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );

  return pdf.save();
}

/// Kotak statistik kecil (rata-rata, jumlah transaksi, dsb).
pw.Widget _kotakStat(String label, String nilai) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: const pw.BoxDecoration(color: _warnaKrem),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: const pw.TextStyle(fontSize: 7, color: _warnaAbu),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          nilai,
          style: _gayaTebal(12, _warnaTinta),
        ),
      ],
    ),
  );
}

/// Baris "vs bulan lalu: naik/turun x%".
pw.Widget _barisVs(RingkasanBulan lalu, RingkasanBulan ini) {
  String perubahan;
  if (lalu.totalPengeluaran <= 0) {
    perubahan = T.t('bulan_pertama');
  } else if (ini.totalPengeluaran == lalu.totalPengeluaran) {
    perubahan = T.t('tetap_sama');
  } else {
    final naik = ini.totalPengeluaran > lalu.totalPengeluaran;
    final persen =
        ((ini.totalPengeluaran - lalu.totalPengeluaran) /
                lalu.totalPengeluaran *
                100)
            .round();
    perubahan = T.f(naik ? 'naik_persen' : 'turun_persen', {'p': '$persen'});
  }
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _warnaGaris),
    ),
    child: pw.Text(
      '${T.t('vs_bulan_lalu')} - $perubahan',
      style: const pw.TextStyle(fontSize: 12, color: _warnaTinta),
    ),
  );
}

/// Satu baris kategori: label, nominal, bar proporsi.
pw.Widget _barisKategori(
    KategoriPengeluaran k, int nilai, RingkasanBulan ini) {
  final maks = ini.kategoriUrut.isEmpty ? 1 : ini.kategoriUrut.first.value;
  final porsi = maks <= 0 ? 0.0 : (nilai / maks).clamp(0.0, 1.0);
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              labelKategori(k),
              style: const pw.TextStyle(fontSize: 10.5, color: _warnaTinta),
            ),
            pw.Text(
              rp(nilai),
              style: _gayaTebal(10.5, _warnaTinta),
            ),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Stack(
          children: [
            pw.Container(
              width: double.infinity,
              height: 6,
              decoration: const pw.BoxDecoration(color: _warnaGaris),
            ),
            pw.Container(
              width: (porsi * 500).clamp(0.0, 500.0),
              height: 6,
              decoration: const pw.BoxDecoration(color: _warnaUtama),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Satu baris uang keluar lain (kos, wifi, setor keluarga).
pw.Widget _barisKeluarLain(Transaksi t) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Text(
            t.catatan ?? T.t('uang_keluar_lain'),
            style: const pw.TextStyle(fontSize: 10.5, color: _warnaTinta),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Text(
          tanggalPendek(t.dibuatPada),
          style: const pw.TextStyle(fontSize: 9, color: _warnaAbu),
        ),
        pw.SizedBox(width: 10),
        pw.Text(
          rp(t.jumlah),
          style: _gayaTebal(10.5, _warnaTinta),
        ),
      ],
    ),
  );
}

/// Grafik batang sederhana per hari (pengganti line chart di PDF).
pw.Widget _grafikHarian(RingkasanBulan ini) {
  final maks = ini.perHari.fold<int>(0, (a, b) => a > b ? a : b);
  return pw.Container(
    height: 110,
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: _warnaGaris),
        left: pw.BorderSide(color: _warnaGaris),
      ),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < ini.perHari.length; i++)
          pw.Expanded(
            child: pw.Container(
              margin: const pw.EdgeInsets.symmetric(horizontal: 1),
              height: maks <= 0
                  ? 0
                  : (ini.perHari[i] / maks * 100).clamp(0.0, 100.0),
              color: ini.perHari[i] > 0 ? _warnaUtama : _warnaKosong,
            ),
          ),
      ],
    ),
  );
}
