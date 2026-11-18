import 'package:flutter/material.dart';

import '../providers/app_state.dart';
import '../utils/dialog.dart';
import '../utils/format.dart';
import '../utils/teks.dart';

/// Dialog CATAT UANG LAIN: masuk & keluar dalam SATU tempat.
///
/// Dibuka lewat satu menu Home ("Uang masuk / keluar lain"). Arah
/// (masuk/keluar) dipilih langsung di dalam dialog dengan tombol
/// segmented - dulu dua menu terpisah. Isinya TIDAK dihitung di budget
/// harian.
///
/// Mode keluar menampilkan pratinjau "imbas": pegangan jadi berapa dan
/// dengan batas harian yang diatur, uang bertahan sampai kapan.
class DialogUangLain extends StatefulWidget {
  /// Arah awal saat dialog dibuka (bisa diganti di dalam dialog).
  final bool masuk;
  final AppState app;
  const DialogUangLain({super.key, required this.masuk, required this.app});

  @override
  State<DialogUangLain> createState() => _DialogUangLainState();
}

class _DialogUangLainState extends State<DialogUangLain> {
  final _nominalCtl = TextEditingController();
  final _catatanCtl = TextEditingController();
  bool _menyimpan = false;
  late bool _masuk = widget.masuk;

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

    if (!_masuk) {
      // Uang keluar mengurangi saldo: gerbang jaga saldo (tidak boleh
      // minus + peringatan bila menghabiskan hampir semua saldo).
      final lanjut = await gerbangJagaSaldo(context, widget.app, nominal);
      if (!lanjut || !mounted) return;
    }

    setState(() => _menyimpan = true);
    final catatan =
        _catatanCtl.text.trim().isEmpty ? null : _catatanCtl.text.trim();
    if (_masuk) {
      await widget.app.tambahMasukLain(nominal, catatan);
    } else {
      await widget.app.tambahKeluarLain(nominal, catatan);
    }
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          T.f(
            _masuk ? 'snack_masuk_lain' : 'snack_keluar_lain',
            {'n': rp(widget.app.saldoPegangan)},
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(T.t('uang_lain_judul')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Satu pintu dua arah: pilih masuk / keluar di sini.
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.south_west_rounded, size: 16),
                label: Text(T.t('uang_masuk_lain')),
              ),
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.north_east_rounded, size: 16),
                label: Text(T.t('uang_keluar_lain')),
              ),
            ],
            selected: {_masuk},
            onSelectionChanged: (s) => setState(() => _masuk = s.first),
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(
                TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            T.t(_masuk ? 'uang_masuk_lain_sub' : 'uang_keluar_lain_sub'),
            style: TextStyle(
              fontSize: 12.5,
              color: cs.onSurface.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nominalCtl,
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
          const SizedBox(height: 6),
          Text(
            T.t('budget_abaikan_lain'),
            style: TextStyle(
              fontSize: 10.5,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
          // Pratinjau imbas khusus uang KELUAR: langsung ke-update tiap
          // ketikan nominal.
          if (!_masuk)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _nominalCtl,
              builder: (context, nilai, _) {
                final nominal = parseRupiah(nilai.text);
                if (nominal <= 0) return const SizedBox.shrink();
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
                            widget.app.teksImbas(nominal),
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
