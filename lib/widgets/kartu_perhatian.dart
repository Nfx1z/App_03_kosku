import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../utils/teks.dart';

/// Kartu "Perlu perhatian": kiriman lewat tanggal, utang jatuh tempo,
/// target dekat, pengeluaran lewat batas.
class KartuPerhatian extends StatelessWidget {
  const KartuPerhatian({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final items = app.daftarPerhatian;
    if (items.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    return Card(
      color: cs.tertiaryContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active_rounded,
                    size: 16, color: cs.onTertiaryContainer),
                const SizedBox(width: 6),
                Text(
                  T.t('perlu_perhatian'),
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: cs.onTertiaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...items.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(p.ikon, size: 18, color: cs.onTertiaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.teks,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
