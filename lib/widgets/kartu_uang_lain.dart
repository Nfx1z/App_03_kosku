import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../utils/dialog.dart';
import '../utils/format.dart';
import '../utils/teks.dart';

/// Kartu pintu masuk "uang masuk / keluar lain" di PALING ATAS Home
/// (pindah dari bawah kartu input cepat).
///
/// Buat apa: kewajiban bulanan seperti bayar kos/wifi dicatat lewat
/// sini. Posisinya di atas supaya gampang dijangkau, dan isinya
/// TIDAK dihitung di budget harian (lihat AppState.terpakaiHariIni).
class KartuUangLain extends StatelessWidget {
  const KartuUangLain({super.key});

  Future<void> _bukaDialog(BuildContext context, {required bool masuk}) async {
    final app = context.read<AppState>();
    await showDialog<void>(
      context: context,
      builder: (_) => _DialogUangLain(masuk: masuk, app: app),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              T.t('uang_lain_judul'),
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _bukaDialog(context, masuk: true),
                    icon: const Icon(Icons.card_giftcard_rounded, size: 18),
                    label: Text(
                      T.t('uang_masuk_lain'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _bukaDialog(context, masuk: false),
                    icon: const Icon(Icons.home_work_rounded, size: 18),
                    label: Text(
                      T.t('uang_keluar_lain'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              T.t('budget_abaikan_lain'),
              style: TextStyle(
                fontSize: 10.5,
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog input uang masuk/keluar lain (hadiah, bayar kos, wifi, dll).
class _DialogUangLain extends StatefulWidget {
  final bool masuk;
  final AppState app;
  const _DialogUangLain({required this.masuk, required this.app});

  @override
  State<_DialogUangLain> createState() => _DialogUangLainState();
}

class _DialogUangLainState extends State<_DialogUangLain> {
  final _nominalCtl = TextEditingController();
  final _catatanCtl = TextEditingController();
  bool _menyimpan = false;

  @override
  void dispose() {
    _nominalCtl.dispose();
    _catatanCtl.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final nominal = parseRupiah(_nominalCtl.text);
    if (nominal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.t('snack_isi_nominal'))),
      );
      return;
    }

    if (!widget.masuk) {
      // Uang keluar mengurangi saldo: gerbang jaga saldo (tidak boleh
      // minus + peringatan bila menghabiskan hampir semua saldo).
      final lanjut = await gerbangJagaSaldo(context, widget.app, nominal);
      if (!lanjut || !mounted) return;
    }

    setState(() => _menyimpan = true);
    final catatan =
        _catatanCtl.text.trim().isEmpty ? null : _catatanCtl.text.trim();
    if (widget.masuk) {
      await widget.app.tambahMasukLain(nominal, catatan);
    } else {
      await widget.app.tambahKeluarLain(nominal, catatan);
    }
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(T.f('snack_masuk_lain', {
          'n': rp(widget.app.saldoPegangan),
        })),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(T.t(widget.masuk ? 'uang_masuk_lain' : 'uang_keluar_lain')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            T.t(widget.masuk ? 'uang_masuk_lain_sub' : 'uang_keluar_lain_sub'),
            style: TextStyle(
              fontSize: 12.5,
              color: cs.onSurface.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nominalCtl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: const [RibuanFormatter()],
            decoration: InputDecoration(
              labelText: T.t('nominal'),
              prefixText: 'Rp ',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _catatanCtl,
            decoration: InputDecoration(
              labelText: T.t('buat_apa'),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(T.t('batal')),
        ),
        FilledButton(
          onPressed: _menyimpan ? null : _simpan,
          child: _menyimpan
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(T.t('catat')),
        ),
      ],
    );
  }
}
