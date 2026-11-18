import 'package:flutter/material.dart';

import '../models/transaksi.dart';
import '../utils/format.dart';

/// Satu baris transaksi di riwayat / home.
class TileTransaksi extends StatelessWidget {
  final Transaksi t;

  /// Dipasang di Riwayat & Home: ketuk untuk buka lembar ubah/hapus.
  final VoidCallback? onTap;
  const TileTransaksi({super.key, required this.t, this.onTap});

  IconData get _ikon => switch (t.jenis) {
        JenisTransaksi.pengeluaran => Icons.shopping_basket_outlined,
        JenisTransaksi.pemasukan => Icons.south_west_rounded,
        JenisTransaksi.isiDarurat => Icons.savings_outlined,
        JenisTransaksi.pakaiDarurat => Icons.health_and_safety_outlined,
        JenisTransaksi.tarikDarurat => Icons.swap_horiz_rounded,
        JenisTransaksi.utangMasuk => Icons.handshake_outlined,
        JenisTransaksi.utangBayar => Icons.payments_outlined,
        JenisTransaksi.piutangKeluar => Icons.north_east_rounded,
        JenisTransaksi.piutangTerima => Icons.south_west_rounded,
        JenisTransaksi.koreksi => Icons.tune_rounded,
        JenisTransaksi.masukLain => Icons.card_giftcard_rounded,
        JenisTransaksi.keluarLain => Icons.output_rounded,
      };

  String get _subjudul {
    final jam = jamPendek(t.dibuatPada);
    if (t.jenis == JenisTransaksi.pengeluaran && t.kategori != null) {
      return '$jam • ${labelKategori(t.kategori!)}';
    }
    return '$jam • ${labelJenis(t.jenis)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nilai = t.tandaTampil;
    final warnaNilai = nilai > 0
        ? cs.tertiary
        : (nilai < 0 ? cs.error : cs.onSurface.withValues(alpha: 0.75));

    return ListTile(
      dense: true,
      onTap: onTap,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: cs.secondaryContainer,
        child: Icon(_ikon, size: 18, color: cs.onSecondaryContainer),
      ),
      title: Text(
        judulTransaksi(t),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        _subjudul,
        style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.75)),
      ),
      trailing: Text(
        rpTanda(nilai),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: warnaNilai,
        ),
      ),
    );
  }
}
