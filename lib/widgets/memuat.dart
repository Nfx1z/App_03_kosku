import 'package:flutter/material.dart';

import '../utils/tema.dart';

/// Pemuat brand Kosku: lingkaran pink berdenyut dengan ikon kantong,
/// pengganti CircularProgressIndicator polos di layar penuh.
/// [teks] boleh kosong; [ukuran] mengatur lingkarannya.
class PemuatKosku extends StatefulWidget {
  final String? teks;
  final double ukuran;
  const PemuatKosku({super.key, this.teks, this.ukuran = 72});

  @override
  State<PemuatKosku> createState() => _PemuatKoskuState();
}

class _PemuatKoskuState extends State<PemuatKosku>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  // Bernapas: membesar-mengecil sedikit + memudar halus.
  late final Animation<double> _skala =
      Tween(begin: 0.92, end: 1.06).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
  );
  late final Animation<double> _pudar =
      Tween(begin: 0.55, end: 1.0).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: _pudar,
          child: ScaleTransition(
            scale: _skala,
            child: Container(
              width: widget.ukuran,
              height: widget.ukuran,
              decoration: const BoxDecoration(
                color: Color(0xFFFFD9E0),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.savings_rounded,
                size: widget.ukuran * 0.5,
                color: WarnaKosku.primary,
              ),
            ),
          ),
        ),
        if (widget.teks != null) ...[
          const SizedBox(height: 14),
          Text(
            widget.teks!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }
}
