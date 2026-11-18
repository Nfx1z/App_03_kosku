import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../utils/teks.dart';
import 'auth_screen.dart';

/// Layar kunci: sesi kedaluwarsa karena offline terlalu lama.
/// Data lokal tetap ada (kecuali auto-wipe aktif) dan kembali setelah
/// login online + sinkronisasi.
class LayarKunci extends StatelessWidget {
  const LayarKunci({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                app.dataTerhapusLokal
                    ? Icons.lock_clock_rounded
                    : Icons.lock_outline_rounded,
                size: 72,
                color: cs.primary,
              ),
              const SizedBox(height: 20),
              Text(
                T.t('kunci_judul'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: cs.primary),
              ),
              const SizedBox(height: 10),
              Text(
                app.dataTerhapusLokal
                    ? T.f('kunci_pesan_wipe', {'n': '${app.graceHari}'})
                    : T.f('kunci_pesan', {'n': '${app.graceHari}'}),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: cs.onSurface.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                ),
                icon: const Icon(Icons.login_rounded),
                label: Text(T.t('tombol_masuk')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
