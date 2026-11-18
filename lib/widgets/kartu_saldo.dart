import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../utils/format.dart';
import '../utils/teks.dart';

/// Kartu utama di Home: saldo pegangan, kantong darurat, info kiriman.
class KartuSaldo extends StatelessWidget {
  const KartuSaldo({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    return Card(
      color: cs.primaryContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              T.t('pegangan_sekarang'),
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                color: cs.onPrimaryContainer.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              rp(app.saldoPegangan),
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: app.saldoPegangan < 0 ? cs.error : cs.onPrimaryContainer,
              ),
            ),
            if (app.saldoPegangan < 0)
              Text(
                T.t('saldo_minus'),
                style: TextStyle(fontSize: 12, color: cs.error),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Pill(
                  ikon: Icons.savings_outlined,
                  teks: T.f('pill_kantong', {'n': rp(app.kantongDarurat)}),
                ),
                _Pill(
                  ikon: Icons.account_balance_wallet_outlined,
                  teks: T.f('pill_total', {'n': rp(app.totalUang)}),
                ),
              ],
            ),
            // Info kiriman hanya kalau belum lewat tanggal; kiriman
            // telat sudah cukup diberitakan kartu "Perlu perhatian"
            // supaya kartu saldo tetap tenang.
            if (app.kirimanAktif != null && !app.kirimanTelat) ...[
              const SizedBox(height: 10),
              Text(
                T.f('kiriman_info', {
                  'n': rp(app.kirimanAktif!.nominal),
                  'd': tanggalPendek(app.kirimanAktif!.tanggalDatang),
                  'h': '${app.sisaHari}',
                }),
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onPrimaryContainer.withValues(alpha: 0.85),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData ikon;
  final String teks;
  const _Pill({required this.ikon, required this.teks});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.onPrimaryContainer.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 14, color: cs.onPrimaryContainer),
          const SizedBox(width: 6),
          Text(
            teks,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
