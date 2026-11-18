import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../utils/tema.dart';
import '../utils/teks.dart';

/// Sambutan sekali di awal: brand "kosku" dulu, baru isi aplikasi.
/// Muncul sebelum HomeScreen (digerakkan flag `sudah_sambutan`),
/// bukan kartu onboarding saldo yang sudah ada di Home.
class LayarSambutan extends StatefulWidget {
  const LayarSambutan({super.key});

  @override
  State<LayarSambutan> createState() => _LayarSambutanState();
}

class _LayarSambutanState extends State<LayarSambutan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  // Masuk halus: naik + muncul, tiap bagian dengan jeda bertingkat.
  late final Animation<double> _naik =
      Tween(begin: 24.0, end: 0.0).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _muncul =
      Tween(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _poin(IconData ikon, String teks, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(ikon, size: 20, color: WarnaKosku.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              teks,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: FadeTransition(
              opacity: _muncul,
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _naik.value),
                  child: child,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo brand: gambar logo kosku (dusty pink) kotak
                    // penuh, TANPA potongan lingkaran (lingkaran memotong
                    // pinggir logo); fallback ikon kantong bila asset hilang.
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: WarnaKosku.primary.withValues(alpha: 0.18),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.savings_rounded,
                          size: 60,
                          color: WarnaKosku.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'kosku',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: WarnaKosku.tinta,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      T.t('sambutan_tagline'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.5,
                        color: cs.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _poin(Icons.bolt_rounded, T.t('sambutan_poin1'), cs),
                    _poin(Icons.document_scanner_rounded,
                        T.t('sambutan_poin2'), cs),
                    _poin(Icons.speed_rounded, T.t('sambutan_poin3'), cs),
                    _poin(Icons.wifi_off_rounded, T.t('sambutan_poin4'), cs),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onPressed: () => context
                            .read<AppState>()
                            .selesaikanSambutan(),
                        child: Text(T.t('mulai')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
