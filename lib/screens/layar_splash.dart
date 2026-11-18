import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../utils/tema.dart';

/// Splash brand SETIAP kali aplikasi dibuka (gaya Gojek): logo kosku
/// muncul sebentar dengan animasi halus, lalu otomatis lanjut ke isi
/// aplikasi begitu animasi selesai DAN data lokal siap.
///
/// - Tidak di-persist: muncul lagi di sesi berikutnya.
/// - Layar sambutan lengkap (dengan poin + tombol Mulai) tetap hanya
///   sekali di awal, dikendalikan flag `sudah_sambutan`.
class LayarSplash extends StatefulWidget {
  const LayarSplash({super.key});

  @override
  State<LayarSplash> createState() => _LayarSplashState();
}

class _LayarSplashState extends State<LayarSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  /// Logo: sedikit mengecil-membesar (scale-in lembut).
  late final Animation<double> _skala = Tween(begin: 0.82, end: 1.0)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

  /// Wordmark + titik-titik: muncul setelah logo.
  late final Animation<double> _muncul = Tween(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.25, 0.7, curve: Curves.easeOut),
    ),
  );

  AppState? _app;

  @override
  void initState() {
    super.initState();
    _ctrl.addStatusListener((status) => _cobaSelesai());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Dengarkan AppState: begitu data siap (dan animasi selesai), tutup.
    final app = context.read<AppState>();
    if (!identical(app, _app)) {
      _app?.removeListener(_cobaSelesai);
      _app = app;
      app.addListener(_cobaSelesai);
    }
    _cobaSelesai();
  }

  @override
  void dispose() {
    _app?.removeListener(_cobaSelesai);
    _ctrl.dispose();
    super.dispose();
  }

  /// Tutup splash hanya kalau animasi SUDAH selesai dan data SUDAH siap.
  /// Kalau data lebih cepat: tunggu animasi brand. Kalau data lambat:
  /// splash menunggu (titik-titik tetap berdenyut).
  void _cobaSelesai() {
    final app = _app;
    if (app == null || !_ctrl.isCompleted || !app.siap) return;
    if (!mounted) return;
    app.selesaikanSplash();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WarnaKosku.krem,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo kosku hasil pewarnaan dusty pink (assets/logo.png).
            // Kotak penuh TANPA potongan lingkaran - lingkaran dulunya
            // memotong pinggir logo (permintaan user: jangan dibulatkan).
            ScaleTransition(
              scale: _skala,
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: WarnaKosku.primary.withValues(alpha: 0.22),
                      blurRadius: 36,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.savings_rounded,
                    size: 64,
                    color: WarnaKosku.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            FadeTransition(
              opacity: _muncul,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'kosku',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: WarnaKosku.tinta,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _TitikMemuat(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tiga titik kecil berdenyut - indikator "sedang menyiapkan data"
/// tanpa terlihat seperti spinner teknis.
class _TitikMemuat extends StatefulWidget {
  @override
  State<_TitikMemuat> createState() => _TitikMemuatState();
}

class _TitikMemuatState extends State<_TitikMemuat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Tiap titik punya jeda fase berbeda.
            final t = (_ctrl.value * 3 - i).clamp(0.0, 2.0) % 1.0;
            final naik = t < 0.5 ? t * 2 : (1 - t) * 2;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: WarnaKosku.primary
                      .withValues(alpha: 0.35 + 0.65 * naik),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
