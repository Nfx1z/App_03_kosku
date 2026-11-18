import 'package:flutter/material.dart';

/// Judul section kecil (mis. "HARI INI", "DAFTAR KIRIMAN").
Widget judulSection(String teks) {
  return Builder(
    builder: (context) {
      final cs = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Text(
          teks.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: cs.onSurface.withValues(alpha: 0.75),
          ),
        ),
      );
    },
  );
}

/// Placeholder kalau list kosong.
Widget kartuKosong(String teks, {IconData ikon = Icons.inbox_rounded}) {
  return Builder(
    builder: (context) {
      final cs = Theme.of(context).colorScheme;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(ikon, size: 28, color: cs.onSurface.withValues(alpha: 0.78)),
            const SizedBox(height: 6),
            Text(
              teks,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.78)),
            ),
          ],
        ),
      );
    },
  );
}
