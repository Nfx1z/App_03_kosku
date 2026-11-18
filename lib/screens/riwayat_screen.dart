import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaksi.dart';
import '../providers/app_state.dart';
import '../utils/format.dart';
import '../utils/teks.dart';
import '../widgets/bagian.dart';
import '../widgets/lembar_edit_transaksi.dart';
import '../widgets/memuat.dart';
import '../widgets/tile_transaksi.dart';

enum _FilterRiwayat { semua, pengeluaran, pemasukan, kantong, utang, lainnya }

/// Riwayat lengkap semua transaksi, dikelompokkan per tanggal.
class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  List<Transaksi> _semua = [];
  bool _memuat = true;
  _FilterRiwayat _filter = _FilterRiwayat.semua;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final data = await context.read<AppState>().ambilSemuaTransaksi();
    if (!mounted) return;
    setState(() {
      _semua = data;
      _memuat = false;
    });
  }

  bool _cocok(Transaksi t) => switch (_filter) {
        _FilterRiwayat.semua => true,
        _FilterRiwayat.pengeluaran => t.jenis == JenisTransaksi.pengeluaran,
        _FilterRiwayat.pemasukan => t.jenis == JenisTransaksi.pemasukan,
        _FilterRiwayat.kantong =>
          t.jenis == JenisTransaksi.isiDarurat ||
              t.jenis == JenisTransaksi.pakaiDarurat ||
              t.jenis == JenisTransaksi.tarikDarurat,
        _FilterRiwayat.utang =>
          t.jenis == JenisTransaksi.utangMasuk ||
              t.jenis == JenisTransaksi.utangBayar ||
              t.jenis == JenisTransaksi.piutangKeluar ||
              t.jenis == JenisTransaksi.piutangTerima,
        _FilterRiwayat.lainnya =>
          t.jenis == JenisTransaksi.masukLain ||
              t.jenis == JenisTransaksi.keluarLain,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final terfilter = _semua.where(_cocok).toList();

    // ringkasan bulan ini
    final kini = DateTime.now();
    int masukBulanIni = 0;
    int keluarBulanIni = 0;
    for (final t in _semua) {
      final d = t.dibuatPada;
      if (d.year != kini.year || d.month != kini.month) continue;
      if (t.jenis == JenisTransaksi.pemasukan ||
          t.jenis == JenisTransaksi.utangMasuk ||
          t.jenis == JenisTransaksi.piutangTerima ||
          t.jenis == JenisTransaksi.masukLain) {
        masukBulanIni += t.jumlah;
      } else if (t.jenis == JenisTransaksi.pengeluaran ||
          t.jenis == JenisTransaksi.utangBayar ||
          t.jenis == JenisTransaksi.piutangKeluar ||
          t.jenis == JenisTransaksi.keluarLain) {
        keluarBulanIni += t.jumlah;
      }
    }

    // kelompokkan per tanggal (list sudah DESC)
    final perTanggal = <String, List<Transaksi>>{};
    for (final t in terfilter) {
      final kunci = t.dibuatPada.toIso8601String().substring(0, 10);
      perTanggal.putIfAbsent(kunci, () => []).add(t);
    }

    return Scaffold(
      appBar: AppBar(title: Text(T.t('riwayat_judul'))),
      body: _memuat
          ? const Center(child: PemuatKosku())
          : RefreshIndicator(
              onRefresh: _muat,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    color: cs.secondaryContainer,
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(T.t('masuk_bulan_ini'),
                                    style: TextStyle(
                                        fontSize: 10,
                                        letterSpacing: 1,
                                        fontWeight: FontWeight.w700,
                                        color: cs.onSecondaryContainer
                                            .withValues(alpha: 0.7))),
                                Text(
                                  rp(masukBulanIni),
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: cs.onSecondaryContainer),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(T.t('keluar_bulan_ini'),
                                    style: TextStyle(
                                        fontSize: 10,
                                        letterSpacing: 1,
                                        fontWeight: FontWeight.w700,
                                        color: cs.onSecondaryContainer
                                            .withValues(alpha: 0.7))),
                                Text(
                                  rp(keluarBulanIni),
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: cs.onSecondaryContainer),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final f in _FilterRiwayat.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(_labelFilter(f)),
                              selected: _filter == f,
                              onSelected: (_) =>
                                  setState(() => _filter = f),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      T.t('tekan_untuk_ubah'),
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  if (perTanggal.isEmpty)
                    kartuKosong(T.t('riwayat_kosong'))
                  else
                    ...perTanggal.entries.map((e) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            judulSection(_labelTanggal(e.key)),
                            ...e.value.map(
                              (t) => TileTransaksi(
                                t: t,
                                onTap: () => bukaLembarTransaksi(context, t),
                              ),
                            ),
                          ],
                        )),
                ],
              ),
            ),
    );
  }

  String _labelFilter(_FilterRiwayat f) => switch (f) {
        _FilterRiwayat.semua => T.t('filter_semua'),
        _FilterRiwayat.pengeluaran => T.t('filter_pengeluaran'),
        _FilterRiwayat.pemasukan => T.t('filter_pemasukan'),
        _FilterRiwayat.kantong => T.t('filter_kantong'),
        _FilterRiwayat.utang => T.t('filter_utang'),
        _FilterRiwayat.lainnya => T.t('filter_lainnya'),
      };

  String _labelTanggal(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final kini = tanggalSaja(DateTime.now());
    final kemarin = kini.subtract(const Duration(days: 1));
    final t = DateTime(d.year, d.month, d.day);
    if (t == kini) return T.t('hari_ini_label');
    if (t == kemarin) return T.t('kemarin_label');
    return tanggalLengkap(t);
  }
}
