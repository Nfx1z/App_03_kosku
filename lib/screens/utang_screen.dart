import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/utang.dart';
import '../providers/app_state.dart';
import '../utils/dialog.dart';
import '../utils/format.dart';
import '../utils/teks.dart';
import '../widgets/bagian.dart';

/// Dua arah:
/// - Aku ngutang  : dapet duit, saldo nambah, nanti harus balikin
/// - Aku ngutangin: ngasih pinjam, saldo kepotong, nanti harus ditagih
class UtangScreen extends StatelessWidget {
  const UtangScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(T.t('utang_judul')),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.handshake_rounded), text: T.t('tab_ngutang')),
              Tab(icon: const Icon(Icons.outbox_rounded), text: T.t('tab_ngutangin')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TabUtang(arah: ArahUtang.ngutang),
            _TabUtang(arah: ArahUtang.ngutangin),
          ],
        ),
      ),
    );
  }
}

class _TabUtang extends StatelessWidget {
  final ArahUtang arah;
  const _TabUtang({required this.arah});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final daftar = app.utangList.where((u) => u.arah == arah).toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        KartuFormUtang(arah: arah),
        judulSection(arah == ArahUtang.ngutang
            ? T.t('yang_aku_pinjam')
            : T.t('yang_kupinjamkan')),
        if (daftar.isEmpty)
          kartuKosong(
            arah == ArahUtang.ngutang
                ? T.t('utang_kosong')
                : T.t('ngutangin_kosong'),
            ikon: Icons.handshake_outlined,
          )
        else
          ...daftar.map((u) => _TileUtang(u: u)),
      ],
    );
  }
}

class KartuFormUtang extends StatefulWidget {
  final ArahUtang arah;
  const KartuFormUtang({super.key, required this.arah});

  @override
  State<KartuFormUtang> createState() => _KartuFormUtangState();
}

class _KartuFormUtangState extends State<KartuFormUtang> {
  final _pihakCtl = TextEditingController();
  final _nominalCtl = TextEditingController();
  final _catatanCtl = TextEditingController();
  bool _pakaiTempo = false;
  DateTime _tempo = DateTime.now().add(const Duration(days: 14));

  @override
  void dispose() {
    _pihakCtl.dispose();
    _nominalCtl.dispose();
    _catatanCtl.dispose();
    super.dispose();
  }

  Future<void> _tambah() async {
    final app = context.read<AppState>();
    final pihak = _pihakCtl.text.trim();
    final nominal = parseRupiah(_nominalCtl.text);
    if (pihak.isEmpty || nominal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.t('snack_utang_isi'))),
      );
      return;
    }
    // Prinsip saldo tidak boleh minus: ngutangin (ngasih pinjam)
    // melewati gerbang jaga saldo (tolak bila saldo kurang, konfirmasi
    // bila pinjamannya menghabiskan hampir semua saldo).
    if (widget.arah == ArahUtang.ngutangin) {
      final lanjut = await gerbangJagaSaldo(context, app, nominal);
      if (!lanjut || !mounted) return;
    }
    await app.tambahUtang(
      arah: widget.arah,
      pihak: pihak,
      nominal: nominal,
      jatuhTempo: _pakaiTempo ? _tempo : null,
      catatan: _catatanCtl.text.trim().isEmpty ? null : _catatanCtl.text.trim(),
    );
    if (!mounted) return;
    _pihakCtl.clear();
    _nominalCtl.clear();
    _catatanCtl.clear();
    setState(() => _pakaiTempo = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.arah == ArahUtang.ngutang
              ? T.f('snack_utang_tersimpan', {'n': rp(nominal)})
              : T.f('snack_ngutangin_tersimpan', {'n': rp(nominal)}),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ngutang = widget.arah == ArahUtang.ngutang;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ngutang
                  ? T.t('form_utang_judul')
                  : T.t('form_ngutangin_judul'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              ngutang ? T.t('form_utang_sub') : T.t('form_ngutangin_sub'),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _pihakCtl,
                    decoration: InputDecoration(
                      labelText: T.t('siapa'),
                      hintText: T.t('hint_siapa'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
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
              ],
            ),
            // Imbas khusus NGUTANGIN (kita ngasih pinjam = uang keluar):
            // pegangan jadi berapa + dengan batas yang diatur, uang
            // bertahan sampai kapan. Langsung ke-update tiap ketikan.
            if (!ngutang)
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _nominalCtl,
                builder: (context, nilai, _) {
                  final nominal = parseRupiah(nilai.text);
                  if (nominal <= 0) return const SizedBox.shrink();
                  final app = context.read<AppState>();
                  final cs = Theme.of(context).colorScheme;
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _pakaiTempo,
              onChanged: (v) => setState(() => _pakaiTempo = v),
              title: Text(T.t('punya_target_bayar'),
                  style: const TextStyle(fontSize: 14)),
            ),
            if (_pakaiTempo)
              InkWell(
                onTap: () async {
                  final p = await pilihTanggal(context, awal: _tempo);
                  if (p != null) setState(() => _tempo = p);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: T.t('target_bayar'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  child: Text(tanggalPendek(_tempo)),
                ),
              ),
            if (_pakaiTempo) const SizedBox(height: 10),
            TextField(
              controller: _catatanCtl,
              decoration: InputDecoration(
                labelText: T.t('catatan_opsional'),
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
                label: Text(T.t('catat')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TileUtang extends StatelessWidget {
  final Utang u;
  const _TileUtang({required this.u});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;
    final kini = tanggalSaja(DateTime.now());
    final lewatTempo = !u.lunas &&
        u.jatuhTempo != null &&
        u.jatuhTempo!.isBefore(kini);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor:
              u.lunas ? cs.surfaceContainerHighest : cs.tertiaryContainer,
          child: Icon(
            u.lunas ? Icons.check_rounded : Icons.person_rounded,
            size: 18,
            color: u.lunas
                ? cs.onSurface.withValues(alpha: 0.7)
                : cs.onTertiaryContainer,
          ),
        ),
        title: Text(
          '${u.pihak} - ${rp(u.nominal)}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (u.catatan != null && u.catatan!.isNotEmpty)
              Text(u.catatan!, style: const TextStyle(fontSize: 12)),
            Text(
              u.lunas
                  ? T.t('lunas')
                  : u.jatuhTempo == null
                      ? T.t('belum_lunas')
                      : lewatTempo
                          ? T.f('lewat_tempo', {
                              'd': tanggalPendek(u.jatuhTempo!),
                            })
                          : T.f('bayar_sebelum', {
                              'd': tanggalPendek(u.jatuhTempo!),
                            }),
              style: TextStyle(
                fontSize: 12,
                fontWeight: lewatTempo ? FontWeight.w800 : FontWeight.w400,
                color: lewatTempo
                    ? cs.error
                    : cs.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!u.lunas)
              IconButton(
                tooltip: T.t('tandai_lunas'),
                onPressed: () async {
                  final catat = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => _DialogLunas(u: u),
                  );
                  if (catat != null && context.mounted) {
                    // Bayar utang mengurangi saldo: gerbang jaga saldo
                    // (ditolak bila saldo kurang + peringatan bila
                    // pembayarannya menghabiskan hampir semua saldo).
                    if (catat &&
                        u.arah == ArahUtang.ngutang &&
                        !await gerbangJagaSaldo(
                            context, app, u.nominal)) {
                      return;
                    }
                    if (!context.mounted) return;
                    await app.lunasiUtang(u, catatTransaksi: catat);
                  }
                },
                icon: Icon(Icons.task_alt_rounded, color: cs.primary),
              ),
            IconButton(
              tooltip: T.t('hapus'),
              onPressed: () async {
                final ya = await konfirmasi(
                  context,
                  judul: T.t('hapus_utang_judul'),
                  pesan: T.f('hapus_utang_pesan', {
                    'x': u.pihak,
                    'n': rp(u.nominal),
                  }),
                  bahaya: true,
                  teksYa: T.t('hapus'),
                );
                if (ya && context.mounted) await app.hapusUtang(u);
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

class _DialogLunas extends StatefulWidget {
  final Utang u;
  const _DialogLunas({required this.u});

  @override
  State<_DialogLunas> createState() => _DialogLunasState();
}

class _DialogLunasState extends State<_DialogLunas> {
  late bool _catat = true;

  @override
  Widget build(BuildContext context) {
    final u = widget.u;
    final ngutang = u.arah == ArahUtang.ngutang;
    final app = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;
    // Imbas bayar utang (bila dicatat: saldo pegangan kepotong) - sama
    // seperti fitur lain: pegangan jadi berapa + dengan batas yang
    // diatur, uang bertahan sampai kapan.
    final imbas = ngutang && _catat ? app.teksImbas(u.nominal) : '';
    return AlertDialog(
      title: Text(ngutang
          ? T.f('utang_lunas_judul', {'x': u.pihak})
          : T.f('piutang_lunas_judul', {'x': u.pihak})),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(ngutang
              ? T.f('utang_lunas_pesan', {'n': rp(u.nominal), 'x': u.pihak})
              : T.f('piutang_lunas_pesan', {'n': rp(u.nominal), 'x': u.pihak})),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _catat,
            onChanged: (v) => setState(() => _catat = v),
            title: Text(
              ngutang
                  ? T.t('catat_pengeluaran_tanya')
                  : T.t('catat_pemasukan_tanya'),
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              ngutang ? T.t('pegangan_kepotong') : T.t('pegangan_nambah'),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (imbas.isNotEmpty)
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
                      imbas,
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(T.t('batal')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _catat),
          child: Text(T.t('lunas')),
        ),
      ],
    );
  }
}
