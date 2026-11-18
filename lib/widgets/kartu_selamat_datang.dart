import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../utils/format.dart';
import '../utils/teks.dart';

/// Kartu onboarding: isi saldo pegangan pertama kali.
class KartuSelamatDatang extends StatefulWidget {
  const KartuSelamatDatang({super.key});

  @override
  State<KartuSelamatDatang> createState() => _KartuSelamatDatangState();
}

class _KartuSelamatDatangState extends State<KartuSelamatDatang> {
  final _ctl = TextEditingController();
  bool _menyimpan = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _mulai() async {
    final nominal = parseRupiah(_ctl.text);
    if (nominal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.t('snack_isi_pegangan'))),
      );
      return;
    }
    setState(() => _menyimpan = true);
    await context.read<AppState>().aturSaldoAwal(nominal);
    if (!mounted) return;
    setState(() => _menyimpan = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.secondaryContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.waving_hand_rounded, color: cs.onSecondaryContainer),
                const SizedBox(width: 8),
                Text(
                  T.t('selamat_datang'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: cs.onSecondaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              T.t('selamat_datang_sub'),
              style: TextStyle(
                fontSize: 13,
                color: cs.onSecondaryContainer.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctl,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [RibuanFormatter()],
                    onSubmitted: (_) => _mulai(),
                    decoration: InputDecoration(
                      labelText: T.t('pegangan_label'),
                      prefixText: 'Rp ',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _menyimpan ? null : _mulai,
                  child: _menyimpan
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(T.t('mulai')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
