import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/transaksi.dart';
import '../providers/app_state.dart';
import '../utils/agregat.dart';
import '../utils/format.dart';
import '../utils/laporan_pdf.dart';
import '../utils/teks.dart';
import '../utils/tema.dart';
import '../widgets/bagian.dart';
import '../widgets/memuat.dart';

/// Laporan bulanan: total, rata-rata harian, tren (line chart),
/// per kategori, pengeluaran terbesar, dan perbandingan vs bulan lalu.
class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  DateTime _bulan = DateTime(DateTime.now().year, DateTime.now().month);
  bool _memuat = true;
  bool _membuatPdf = false;
  RingkasanBulan? _ini;
  RingkasanBulan? _lalu;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final app = context.read<AppState>();
    final kini = DateTime.now();

    final listBulanIni =
        await app.transaksiBulan(_bulan.year, _bulan.month);
    final bulanLalu = DateTime(_bulan.year, _bulan.month - 1);
    final listBulanLalu =
        await app.transaksiBulan(bulanLalu.year, bulanLalu.month);

    if (!mounted) return;
    setState(() {
      _ini = ringkasBulan(listBulanIni,
          tahun: _bulan.year, bulan: _bulan.month, kini: kini);
      _lalu = ringkasBulan(listBulanLalu,
          tahun: bulanLalu.year, bulan: bulanLalu.month, kini: kini);
      _memuat = false;
    });
  }

  void _geser(int bulan) {
    final kini = DateTime.now();
    final target = DateTime(_bulan.year, _bulan.month + bulan);
    final batas = DateTime(kini.year, kini.month);
    if (target.isAfter(batas)) return;
    setState(() {
      _bulan = target;
      _memuat = true;
    });
    _muat();
  }

  /// Ekspor laporan bulan aktif ke PDF, lalu buka lembar bagikan
  /// Android (bisa disimpan, dikirim ke WhatsApp, email, dsb).
  Future<void> _eksporPdf() async {
    final ini = _ini;
    if (ini == null || ini.kosong) return;
    setState(() => _membuatPdf = true);
    try {
      final bytes = await buatPdfLaporan(ini: ini, lalu: _lalu);
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'laporan-kosku-${ini.tahun}-${ini.bulan.toString().padLeft(2, '0')}.pdf',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(T.t('pdf_gagal'))),
        );
      }
    } finally {
      if (mounted) setState(() => _membuatPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ini = _ini;

    return Scaffold(
      appBar: AppBar(
        title: Text(T.t('laporan_judul')),
        actions: [
          if (ini != null && !ini.kosong && !_memuat)
            IconButton(
              tooltip: T.t('ekspor_pdf'),
              onPressed: _membuatPdf ? null : _eksporPdf,
              icon: _membuatPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded),
            ),
        ],
      ),
      body: _memuat || ini == null
          ? const Center(child: PemuatKosku())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // ----- navigasi bulan -----
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => _geser(-1),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Text(
                      namaBulanTahun(_bulan.year, _bulan.month),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    IconButton(
                      onPressed: () => _geser(1),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                if (ini.kosong)
                  kartuKosong(T.t('laporan_kosong'), ikon: Icons.bar_chart_rounded)
                else ...[
                  _kartuRingkasan(context, ini),
                  const SizedBox(height: 8),
                  _kartuTren(context, ini),
                  const SizedBox(height: 8),
                  _kartuKalender(context, ini),
                  const SizedBox(height: 8),
                  _kartuKategori(context, ini),
                  // Uang keluar lain (kos, wifi, dll) punya bagian sendiri:
                  // wajib tampil di laporan bulanan, tapi tidak dicampur
                  // dengan total pengeluaran harian.
                  if (ini.keluarLainList.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _kartuKeluarLain(context, ini),
                  ],
                  if (ini.terbesar != null) ...[
                    const SizedBox(height: 8),
                    _kartuTerbesar(context, ini.terbesar!),
                  ],
                  if (_lalu != null) ...[
                    const SizedBox(height: 8),
                    _kartuVsBulanLalu(context, ini, _lalu!),
                  ],
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _kartuRingkasan(BuildContext context, RingkasanBulan r) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primaryContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              T.t('total_pengeluaran'),
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
                color: cs.onPrimaryContainer.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 2),
            // Nominal utama pakai warna tinta gelap (onSurface), BUKAN
            // onPrimaryContainer - hijau tua di atas hijau muda susah dibaca.
            Text(
              rp(r.totalPengeluaran),
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _statChip(
                  Icons.calculate_outlined,
                  '${T.t('rata_harian')}: ${rp(r.rataHarian)}',
                ),
                _statChip(
                  Icons.receipt_long_outlined,
                  T.f('jumlah_transaksi', {'n': '${r.jumlahTransaksi}'}),
                ),
                _statChip(
                  Icons.event_available_outlined,
                  T.f('hari_tanpa_belanja', {'n': '${r.hariTanpaBelanja}'}),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData ikon, String teks) {
    final cs = Theme.of(context).colorScheme;
    // Chip putih + teks gelap: kontras maksimum, tidak sekamu dengan kartu.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            teks,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kartuTren(BuildContext context, RingkasanBulan r) {
    final cs = Theme.of(context).colorScheme;
    final spots = <FlSpot>[
      for (var i = 0; i < r.perHari.length; i++)
        FlSpot((i + 1).toDouble(), r.perHari[i].toDouble()),
    ];
    final maks = r.perHari.fold<int>(0, (a, b) => a > b ? a : b);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(T.t('tren_harian'),
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              T.t('tren_harian_sub'),
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maks <= 0 ? 1 : maks.toDouble() * 1.15,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      barWidth: 2,
                      color: cs.primary,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: cs.primary.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  // Tekan titik data → tooltip kontras tinggi: latar cream
                  // terang + teks tinta gelap + bingkai pink (sebelumnya
                  // teks susah dibaca saat menekan grafik).
                  lineTouchData: LineTouchData(
                    touchSpotThreshold: 24,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => WarnaKosku.permukaan,
                      tooltipBorderRadius: BorderRadius.circular(12),
                      tooltipMargin: 12,
                      tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      tooltipBorder: BorderSide(
                        color: cs.primary.withValues(alpha: 0.55),
                        width: 1,
                      ),
                      getTooltipItems: (titik) => titik
                          .map(
                            (s) => LineTooltipItem(
                              '${tanggalSangatPendek(DateTime(_bulan.year,
                                      _bulan.month, s.x.toInt()))}\n'
                              '${rp(s.y.toInt())}',
                              const TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                fontWeight: FontWeight.w800,
                                color: WarnaKosku.tinta,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: 5,
                        getTitlesWidget: (v, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(
                            '${v.toInt()}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kalender pengeluaran: peta warna per tanggal (pink muda = hemat,
  /// merah pekat + angka putih = lewat jatah, abu = tidak belanja).
  /// Ketuk tanggal untuk melihat nominalnya. Patokan warna = jatah
  /// harian SAAT INI.
  Widget _kartuKalender(BuildContext context, RingkasanBulan r) {
    final app = Provider.of<AppState>(context);
    final cs = Theme.of(context).colorScheme;
    final batas = app.batasAktif;

    final kini = tanggalSaja(DateTime.now());
    final bulanIni = kini.year == r.tahun && kini.month == r.bulan;

    // Nama hari pendek sesuai bahasa (Senin..Minggu).
    final locale = T.bahasa == 'en' ? 'en_US' : 'id_ID';
    final namaHari = [
      for (var i = 0; i < 7; i++)
        DateFormat.E(locale).format(DateTime(2024, 1, 1 + i)),
    ];
    // 1 Jan 2024 = Senin, jadi kolom 0 = Senin.
    final kosongDepan = DateTime(r.tahun, r.bulan, 1).weekday - 1;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(T.t('kalender_judul'),
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              T.f('kalender_sub', {'j': rp(batas)}),
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, kotak) {
                final lebar =
                    (kotak.maxWidth - 6 * 4) / 7; // 7 kolom, jarak 4
                Widget sel(VoidCallback? onTap, Widget anak,
                    {Color? warna, Border? bingkai}) {
                  return Padding(
                    padding: const EdgeInsets.all(2),
                    child: GestureDetector(
                      onTap: onTap,
                      child: Container(
                        width: lebar,
                        height: lebar,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: warna ?? cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                          border: bingkai,
                        ),
                        child: anak,
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    Row(
                      children: [
                        for (final h in namaHari)
                          Expanded(
                            child: Center(
                              child: Text(
                                h,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      children: [
                        // Sel kosong sebelum tanggal 1.
                        for (var i = 0; i < kosongDepan; i++)
                          sel(null, const SizedBox.shrink()),
                        for (var tgl = 1; tgl <= r.perHari.length; tgl++)
                          _selKalender(
                            context,
                            sel,
                            tanggal: DateTime(r.tahun, r.bulan, tgl),
                            belanja: r.perHari[tgl - 1],
                            batas: batas,
                            hariIni: bulanIni &&
                                DateTime(r.tahun, r.bulan, tgl) == kini,
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _legenda(context, cs.tertiaryContainer, T.t('kalender_hemat')),
                _legenda(context, cs.error, T.t('kalender_lewat')),
                _legenda(
                    context, cs.surfaceContainerLow, T.t('kalender_kosong')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _selKalender(
    BuildContext context,
    Widget Function(VoidCallback?, Widget, {Color? warna, Border? bingkai})
        sel, {
    required DateTime tanggal,
    required int belanja,
    required int batas,
    required bool hariIni,
  }) {
    final cs = Theme.of(context).colorScheme;
    final masaDepan = tanggal.isAfter(tanggalSaja(DateTime.now()));

    Color? warna;
    Color? warnaTeks;
    if (!masaDepan) {
      if (belanja <= 0) {
        warna = null; // abu permukaan bawaan
      } else if (batas > 0 && belanja > batas) {
        // Merah pekat + teks putih. errorContainer (salmon muda) nyaris
        // tak bisa dibedakan dari tertiaryContainer (pink muda) di tema
        // ini - hari boros harus langsung kelihatan bedanya.
        warna = cs.error;
        warnaTeks = cs.onError;
      } else {
        warna = cs.tertiaryContainer;
      }
    }

    return sel(
      masaDepan
          ? null
          : () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(T.f('kalender_nominal', {
                    'd': tanggalPendek(tanggal),
                    'n': rp(belanja),
                  })),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
      Text(
        '${tanggal.day}',
        style: TextStyle(
          fontSize: 12,
          fontWeight:
              hariIni ? FontWeight.w800 : FontWeight.w600,
          color: masaDepan
              ? cs.onSurface.withValues(alpha: 0.35)
              : warnaTeks ?? cs.onSurface.withValues(alpha: 0.8),
        ),
      ),
      warna: warna,
      bingkai: hariIni
          ? Border.all(color: cs.primary, width: 1.5)
          : null,
    );
  }

  Widget _legenda(BuildContext context, Color warna, String teks) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: warna,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          teks,
          style: TextStyle(
            fontSize: 11,
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _kartuKategori(BuildContext context, RingkasanBulan r) {
    final cs = Theme.of(context).colorScheme;
    final urut = r.kategoriUrut;
    final maks = urut.isEmpty ? 1 : urut.first.value;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(T.t('per_kategori'),
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            for (final e in urut)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(labelKategori(e.key),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(rp(e.value),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: maks <= 0 ? 0 : e.value / maks,
                        minHeight: 6,
                        color: cs.primary,
                        backgroundColor: cs.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _kartuKeluarLain(BuildContext context, RingkasanBulan r) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.home_work_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Text(T.t('pengeluaran_lainnya'),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              T.t('pengeluaran_lainnya_sub'),
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 10),
            for (final t in r.keluarLainList)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.catatan ?? T.t('uang_keluar_lain'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tanggalSangatPendek(t.dibuatPada),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: cs.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      rp(t.jumlah),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            const Divider(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(T.t('total_keluar_lain'),
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
                Text(
                  rp(r.totalKeluarLain),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kartuTerbesar(BuildContext context, Transaksi t) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(T.t('pengeluaran_terbesar'),
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: cs.secondaryContainer,
                  child: Icon(Icons.shopping_basket_outlined,
                      size: 18, color: cs.onSecondaryContainer),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.catatan ?? T.t('judul_pengeluaran'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        t.kategori == null
                            ? tanggalPendek(t.dibuatPada)
                            : '${tanggalPendek(t.dibuatPada)} • '
                                '${labelKategori(t.kategori!)}',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
                Text(
                  rp(t.jumlah),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kartuVsBulanLalu(
    BuildContext context,
    RingkasanBulan ini,
    RingkasanBulan lalu,
  ) {
    final cs = Theme.of(context).colorScheme;
    final naik = ini.totalPengeluaran > lalu.totalPengeluaran;
    final tetap = ini.totalPengeluaran == lalu.totalPengeluaran;

    String perubahan;
    Color warna;
    IconData ikon;
    if (lalu.totalPengeluaran <= 0) {
      perubahan = T.t('bulan_pertama');
      warna = cs.onSurface.withValues(alpha: 0.8);
      ikon = Icons.remove_rounded;
    } else if (tetap) {
      perubahan = T.t('tetap_sama');
      warna = cs.onSurface.withValues(alpha: 0.8);
      ikon = Icons.trending_flat_rounded;
    } else {
      final persen =
          ((ini.totalPengeluaran - lalu.totalPengeluaran) / lalu.totalPengeluaran * 100).round();
      perubahan = T.f(
          naik ? 'naik_persen' : 'turun_persen', {'p': '$persen'});
      warna = naik ? cs.error : cs.tertiary;
      ikon = naik
          ? Icons.trending_up_rounded
          : Icons.trending_down_rounded;
    }

    final movers = deltaKategori(lalu, ini).entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ikon, size: 18, color: warna),
                const SizedBox(width: 6),
                Text(
                  '${T.t('vs_bulan_lalu')} - $perubahan',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: warna),
                ),
              ],
            ),
            if (movers.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(T.t('top_bergerak'),
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withValues(alpha: 0.85))),
              const SizedBox(height: 6),
              for (final m in movers.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(labelKategori(m.key),
                          style: const TextStyle(fontSize: 12.5)),
                      Text(
                        rpTanda(m.value),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: m.value > 0 ? cs.error : cs.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
