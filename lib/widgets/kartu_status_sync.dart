import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../screens/pengaturan_screen.dart';
import '../services/sync_service.dart';
import '../utils/teks.dart';

/// Ikon status sinkron di AppBar Home.
/// Tap → buka Pengaturan (bagian Akun & Sinkronisasi).
class TombolStatusSync extends StatelessWidget {
  const TombolStatusSync({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    IconData ikon;
    Color warna = cs.onSurface.withValues(alpha: 0.75);
    String tooltip;

    switch (app.statusSinkron) {
      case StatusSinkron.sinkron:
        ikon = Icons.cloud_done_rounded;
        warna = cs.tertiary;
        tooltip = T.t('sync_sinkron');
        break;
      case StatusSinkron.antri:
        ikon = Icons.cloud_upload_rounded;
        tooltip = T.f('sync_antri', {'n': '${app.antrianSinkron}'});
        break;
      case StatusSinkron.offline:
        ikon = Icons.signal_wifi_off_rounded;
        tooltip = T.t('sync_offline');
        break;
      case StatusSinkron.error:
        ikon = Icons.cloud_off_rounded;
        warna = cs.error;
        tooltip = T.t('sync_error');
        break;
      case StatusSinkron.lokalSaja:
        ikon = Icons.smartphone_rounded;
        tooltip = T.t('sync_lokal');
        break;
    }

    return IconButton(
      tooltip: tooltip,
      icon: ikon == Icons.cloud_upload_rounded && app.antrianSinkron > 0
          ? Badge(
              smallSize: 8,
              child: Icon(ikon, color: warna),
            )
          : Icon(ikon, color: warna),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PengaturanScreen()),
      ),
    );
  }
}
