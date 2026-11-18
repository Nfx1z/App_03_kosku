import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../utils/format.dart';
import '../utils/teks.dart';
import '../widgets/bagian.dart';
import '../widgets/memuat.dart';
import '../widgets/tile_transaksi.dart';

/// Kantong dana darurat:
/// - isi   : pegangan kepotong, kantong nambah
/// - pakai : kantong kepotong, pegangan tetap
/// - tarik : kantong kepotong, balik ke pegangan
class DanaDaruratScreen extends StatelessWidget {
  const DanaDaruratScreen({super.key});

  Future<void> _dialogNominal(
    BuildContext context, {
    required String judul,
    required String teksYa,
    bool pakai = false,

    /// Tampilkan pratinjau imbas (khusus ISI: uang pindah dari pegangan
    /// ke kantong, daya tahan jatah harian ikut berkurang).
    bool imbas = false,

    /// Batas atas nominal: isi dibatasi saldo pegangan, pakai/tarik
    /// dibatasi isi kantong. Prinsip: saldo tidak boleh minus.
    int? maks,
    required Future<void> Function(int nominal, String? catatan) aksi,
  }) async {
    final ctl = TextEditingController();
    final catatanCtl = TextEditingController();
    final app = context.read<AppState>();
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(judul),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctl,
              keyboardType: TextInputType.number,
              inputFormatters: const [RibuanFormatter()],
              decoration: InputDecoration(
                labelText: T.t('nominal'),
                prefixText: 'Rp ',
                helperText: maks == null ? null : T.f('maks_nominal', {'n': rp(maks)}),
                border: const OutlineInputBorder(),
              ),
            ),
            // Imbas isi kantong: pegangan jadi berapa + dengan batas
            // yang diatur, uang bertahan sampai kapan.
            if (imbas)
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: ctl,
                builder: (ctx, nilai, _) {
                  final nominal = parseRupiah(nilai.text);
                  if (nominal <= 0) return const SizedBox.shrink();
                  final cs = Theme.of(ctx).colorScheme;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.insights_rounded,
                              size: 16,
                              color: cs.onSurface.withValues(alpha: 0.7)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              app.teksImbas(nominal),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: cs.onSurface.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            if (pakai) ...[
              const SizedBox(height: 10),
              TextField(
                controller: catatanCtl,
                decoration: InputDecoration(
                  labelText: T.t('pakai_buat_apa'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(T.t('batal')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(teksYa),
          ),
        ],
      ),
    );
    if (ya != true) return;
    final nominal = parseRupiah(ctl.text);
    if (nominal <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(T.t('snack_isi_nominal'))),
        );
      }
      return;
    }
    if (maks != null && nominal > maks) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(T.f('snack_saldo_kurang', {'n': rp(maks)}))),
        );
      }
      return;
    }
    await aksi(nominal, catatanCtl.text.trim().isEmpty ? null : catatanCtl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(T.t('darurat_judul'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            color: cs.primaryContainer,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    T.t('kantong_darurat'),
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rp(app.kantongDarurat),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    T.f('darurat_info', {
                      'p': rp(app.saldoPegangan),
                      't': rp(app.totalUang),
                    }),
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _dialogNominal(
                    context,
                    judul: T.t('isi_kantong_judul'),
                    teksYa: T.t('isi'),
                    // Isi kantong maksimal sebanyak saldo pegangan.
                    maks: app.saldoPegangan,
                    imbas: true,
                    aksi: (n, _) => context.read<AppState>().isiKantong(n),
                  ),
                  icon: const Icon(Icons.savings_outlined),
                  label: Text(T.t('isi')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _dialogNominal(
                    context,
                    judul: T.t('pakai_darurat_judul'),
                    teksYa: T.t('pakai'),
                    pakai: true,
                    // Pakai tidak boleh melebihi isi kantong.
                    maks: app.kantongDarurat,
                    aksi: (n, c) => context.read<AppState>().pakaiKantong(n, c),
                  ),
                  icon: const Icon(Icons.health_and_safety_outlined),
                  label: Text(T.t('pakai')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _dialogNominal(
                    context,
                    judul: T.t('tarik_judul'),
                    teksYa: T.t('tarik'),
                    // Tarik balik juga dibatasi isi kantong.
                    maks: app.kantongDarurat,
                    aksi: (n, _) => context.read<AppState>().tarikKantong(n),
                  ),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: Text(T.t('tarik')),
                ),
              ),
            ],
          ),
          judulSection(T.t('cara_kerja_kantong')),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                T.t('cara_kerja_teks'),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: cs.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ),
          ),
          judulSection(T.t('riwayat_kantong')),
          FutureBuilder(
            future: app.riwayatKantong(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(16),
                  child: PemuatKosku(ukuran: 48),
                ));
              }
              final data = snap.data!;
              if (data.isEmpty) {
                return kartuKosong(T.t('kantong_kosong'),
                    ikon: Icons.savings_outlined);
              }
              return Column(
                children: data.map((t) => TileTransaksi(t: t)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
