import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/kiriman.dart';
import '../providers/app_state.dart';
import '../utils/dialog.dart';
import '../utils/format.dart';
import '../utils/teks.dart';
import '../widgets/bagian.dart';

class KirimanScreen extends StatelessWidget {
  const KirimanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final aktif = app.kirimanAktif;

    return Scaffold(
      appBar: AppBar(title: Text(T.t('kiriman_judul'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (aktif != null)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      T.t('kiriman_kartu'),
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer
                            .withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rp(aktif.nominal),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      '${tanggalLengkap(aktif.tanggalDatang)} '
                      '${T.f('hari_lagi', {'n': '${app.sisaHari}'})}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer
                            .withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      T.t('kiriman_info_konfirmasi'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer
                            .withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const KartuFormKiriman(),
          judulSection(T.t('daftar_kiriman')),
          if (app.kirimanList.isEmpty)
            kartuKosong(T.t('kiriman_kosong'), ikon: Icons.send_rounded)
          else
            ...app.kirimanList.map((k) => _TileKiriman(k: k)),
        ],
      ),
    );
  }
}

class KartuFormKiriman extends StatefulWidget {
  const KartuFormKiriman({super.key});

  @override
  State<KartuFormKiriman> createState() => _KartuFormKirimanState();
}

class _KartuFormKirimanState extends State<KartuFormKiriman> {
  final _nominalCtl = TextEditingController();
  final _catatanCtl = TextEditingController();
  DateTime _tanggal = DateTime.now();

  @override
  void dispose() {
    _nominalCtl.dispose();
    _catatanCtl.dispose();
    super.dispose();
  }

  Future<void> _tambah() async {
    final nominal = parseRupiah(_nominalCtl.text);
    if (nominal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.t('snack_kiriman_nominal'))),
      );
      return;
    }
    await context.read<AppState>().tambahKiriman(
          nominal: nominal,
          tanggalDatang: _tanggal,
          catatan: _catatanCtl.text.trim().isEmpty ? null : _catatanCtl.text.trim(),
        );
    if (!mounted) return;
    _nominalCtl.clear();
    _catatanCtl.clear();
    setState(() => _tanggal = DateTime.now());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(T.t('snack_kiriman_tambah'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              T.t('tambah_jadwal_kiriman'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nominalCtl,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [RibuanFormatter()],
                    decoration: InputDecoration(
                      labelText: T.t('nominal'),
                      prefixText: 'Rp ',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final p = await pilihTanggal(context, awal: _tanggal);
                      if (p != null) setState(() => _tanggal = p);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: T.t('perkiraan_datang'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Text(tanggalSangatPendek(_tanggal)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _catatanCtl,
              decoration: InputDecoration(
                labelText: T.t('catatan_kiriman'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _tambah,
                icon: const Icon(Icons.add_rounded),
                label: Text(T.t('tambah_jadwal')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TileKiriman extends StatelessWidget {
  final Kiriman k;
  const _TileKiriman({required this.k});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;
    final lewatTanggal = !k.sudahMasuk &&
        k.tanggalDatang.isBefore(tanggalSaja(DateTime.now()));

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor:
              k.sudahMasuk ? cs.surfaceContainerHighest : cs.primaryContainer,
          child: Icon(
            k.sudahMasuk ? Icons.check_rounded : Icons.schedule_rounded,
            size: 18,
            color: k.sudahMasuk
                ? cs.onSurface.withValues(alpha: 0.7)
                : cs.onPrimaryContainer,
          ),
        ),
        title: Text(
          '${rp(k.nominal)} - ${tanggalPendek(k.tanggalDatang)}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (k.catatan != null && k.catatan!.isNotEmpty)
              Text(k.catatan!, style: const TextStyle(fontSize: 12)),
            Text(
              k.sudahMasuk
                  ? T.t('sudah_masuk')
                  : lewatTanggal
                      ? T.t('lewat_tanggal')
                      : T.t('menunggu'),
              style: TextStyle(
                fontSize: 12,
                color: lewatTanggal ? cs.error : cs.onSurface.withValues(alpha: 0.75),
                fontWeight: lewatTanggal ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!k.sudahMasuk)
              IconButton(
                tooltip: T.t('sudah_masuk'),
                onPressed: () async {
                  final ya = await konfirmasi(
                    context,
                    judul: T.t('konfirmasi_kiriman_judul'),
                    pesan: T.f('konfirmasi_kiriman_pesan', {'n': rp(k.nominal)}),
                    teksYa: T.t('sudah_masuk'),
                  );
                  if (ya && context.mounted) await app.konfirmasiKiriman(k);
                },
                icon: Icon(Icons.task_alt_rounded, color: cs.primary),
              ),
            IconButton(
              tooltip: T.t('hapus'),
              onPressed: () async {
                final ya = await konfirmasi(
                  context,
                  judul: T.t('hapus_kiriman_judul'),
                  pesan: T.f('hapus_kiriman_pesan', {
                    'n': rp(k.nominal),
                    'd': tanggalPendek(k.tanggalDatang),
                  }),
                  bahaya: true,
                  teksYa: T.t('hapus'),
                );
                if (ya && context.mounted) await app.hapusKiriman(k);
              },
              icon: Icon(Icons.delete_outline_rounded,
                  color: cs.onSurface.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }
}
