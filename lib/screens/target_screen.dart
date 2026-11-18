import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/target.dart';
import '../providers/app_state.dart';
import '../utils/dialog.dart';
import '../utils/format.dart';
import '../utils/hitung.dart';
import '../utils/teks.dart';
import '../widgets/bagian.dart';

/// Target beli: nama + budget + tanggal (opsional).
/// Ada tanggal  → saran nabung/hari + peringatan kalau proyeksi kurang.
/// Tanpa tanggal → saran kapan realistis bisa beli.
class TargetScreen extends StatelessWidget {
  const TargetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: Text(T.t('target_judul'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const KartuFormTarget(),
          judulSection(T.t('target_kamu')),
          if (app.targetList.isEmpty)
            kartuKosong(T.t('target_kosong'), ikon: Icons.flag_rounded)
          else
            ...app.targetList.map((t) => _KartuTarget(t: t)),
        ],
      ),
    );
  }
}

class KartuFormTarget extends StatefulWidget {
  const KartuFormTarget({super.key});

  @override
  State<KartuFormTarget> createState() => _KartuFormTargetState();
}

class _KartuFormTargetState extends State<KartuFormTarget> {
  final _namaCtl = TextEditingController();
  final _nominalCtl = TextEditingController();
  bool _pakaiDeadline = false;
  DateTime _deadline = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _namaCtl.dispose();
    _nominalCtl.dispose();
    super.dispose();
  }

  Future<void> _tambah() async {
    final nama = _namaCtl.text.trim();
    final nominal = parseRupiah(_nominalCtl.text);
    if (nama.isEmpty || nominal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.t('snack_target_isi'))),
      );
      return;
    }
    await context.read<AppState>().tambahTarget(
          nama: nama,
          nominal: nominal,
          tanggal: _pakaiDeadline ? _deadline : null,
        );
    if (!mounted) return;
    _namaCtl.clear();
    _nominalCtl.clear();
    setState(() => _pakaiDeadline = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(T.t('snack_target_tambah'))),
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
            Text(T.t('tambah_target'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            TextField(
              controller: _namaCtl,
              decoration: InputDecoration(
                labelText: T.t('mau_beli_apa'),
                hintText: T.t('hint_target'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nominalCtl,
              keyboardType: TextInputType.number,
              inputFormatters: const [RibuanFormatter()],
              decoration: InputDecoration(
                labelText: T.t('budget'),
                prefixText: 'Rp ',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _pakaiDeadline,
              onChanged: (v) => setState(() => _pakaiDeadline = v),
              title: Text(T.t('punya_deadline'),
                  style: const TextStyle(fontSize: 14)),
            ),
            if (_pakaiDeadline)
              InkWell(
                onTap: () async {
                  final p = await pilihTanggal(context, awal: _deadline);
                  if (p != null) setState(() => _deadline = p);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: T.t('deadline'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  child: Text(tanggalPendek(_deadline)),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _tambah,
                icon: const Icon(Icons.add_rounded),
                label: Text(T.t('tambah_target')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KartuTarget extends StatelessWidget {
  final TargetBeli t;
  const _KartuTarget({required this.t});

  Color _warnaStatus(StatusSaran s, ColorScheme cs) => switch (s) {
        StatusSaran.siapBeli => cs.tertiary,
        StatusSaran.aman => cs.primary,
        StatusSaran.berat => cs.error,
        StatusSaran.perluWaktu => cs.secondary,
      };

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;
    final saran = app.saranUntuk(t);
    final progres =
        t.nominal <= 0 ? 0.0 : (app.saldoPegangan / t.nominal).clamp(0.0, 1.0);
    final siap = app.saldoPegangan < 0
        ? 0
        : (app.saldoPegangan > t.nominal ? t.nominal : app.saldoPegangan);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.nama,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                if (t.tercapai)
                  Chip(
                    label: Text(T.t('tercapai'),
                        style: const TextStyle(fontSize: 11)),
                    backgroundColor: cs.primaryContainer,
                    visualDensity: VisualDensity.compact,
                  )
                else
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'capai') {
                        final catat = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => _DialogTercapai(
                            nama: t.nama,
                            nominal: t.nominal,
                            app: app,
                          ),
                        );
                        if (catat != null && context.mounted) {
                          // Beli target = pengeluaran besar. Gerbang jaga
                          // saldo: ditolak bila saldo kurang (tidak boleh
                          // minus), konfirmasi bila menghabiskan hampir
                          // semua saldo (mis. beli 3jt dengan saldo 3jt).
                          if (catat &&
                              !await gerbangJagaSaldo(
                                  context, app, t.nominal)) {
                            return;
                          }
                          if (!context.mounted) return;
                          await app.tandaiTargetTercapai(
                            t,
                            catatPengeluaran: catat,
                          );
                        }
                      } else if (v == 'hapus') {
                        final ya = await konfirmasi(
                          context,
                          judul: T.t('hapus_target_judul'),
                          pesan: T.f('hapus_target_pesan', {
                            'x': t.nama,
                            'n': rp(t.nominal),
                          }),
                          bahaya: true,
                          teksYa: T.t('hapus'),
                        );
                        if (ya && context.mounted) await app.hapusTarget(t);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                          value: 'capai', child: Text(T.t('tandai_tercapai'))),
                      PopupMenuItem(
                          value: 'hapus', child: Text(T.t('hapus'))),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              t.tanggal != null
                  ? T.f('budget_deadline_info', {
                      'n': rp(t.nominal),
                      'd': tanggalPendek(t.tanggal!),
                    })
                  : T.f('budget_tanpa_tanggal', {'n': rp(t.nominal)}),
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
            // Sudah tercapai: berhenti tampilkan progres/saran - dulu
            // kartu tetap bilang "kurang Rp X" karena saldo sudah
            // terpakai buat beli targetnya (terlihat seperti belum
            // tercapai padahal sudah).
            if (t.tercapai)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 16, color: cs.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        T.t('target_selesai'),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              const SizedBox(height: 10),
              Text(
                T.f('siap_info', {'a': rp(siap), 'b': rp(t.nominal)}),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progres,
                  minHeight: 8,
                  color: _warnaStatus(saran.status, cs),
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.tips_and_updates_outlined,
                      size: 16, color: _warnaStatus(saran.status, cs)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      app.teksSaranTarget(t),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: cs.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DialogTercapai extends StatefulWidget {
  final String nama;
  final int nominal;
  final AppState app;
  const _DialogTercapai({
    required this.nama,
    required this.nominal,
    required this.app,
  });

  @override
  State<_DialogTercapai> createState() => _DialogTercapaiState();
}

class _DialogTercapaiState extends State<_DialogTercapai> {
  bool _catat = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(T.t('tandai_tercapai_judul')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${widget.nama} (${rp(widget.nominal)})'),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _catat,
            onChanged: (v) => setState(() => _catat = v),
            title: Text(T.t('catat_sekarang'),
                style: const TextStyle(fontSize: 14)),
            subtitle: Text(T.t('catat_sekarang_sub'),
                style: const TextStyle(fontSize: 12)),
          ),
          // Imbas ke saldo: kalau beli sekarang, pegangan jadi berapa
          // dan dengan batas yang diatur uang bertahan sampai kapan.
          if (_catat) ...[
            const SizedBox(height: 4),
            Container(
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
                      size: 16, color: cs.onSurface.withValues(alpha: 0.7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      // masukBudgetHariIni: beli target tercatat sebagai
                      // pengeluaran hari ini, jadi nominalnya ikut memakan
                      // jatah hari ini di proyeksi.
                      widget.app.teksImbas(widget.nominal,
                          masukBudgetHariIni: true),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: cs.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(T.t('batal')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _catat),
          child: Text(T.t('tandai')),
        ),
      ],
    );
  }
}
