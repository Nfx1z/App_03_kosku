import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../utils/teks.dart';
import '../widgets/bagian.dart';
import '../widgets/dialog_uang_lain.dart';
import '../widgets/kartu_budget.dart';
import '../widgets/kartu_input_cepat.dart';
import '../widgets/kartu_perhatian.dart';
import '../widgets/kartu_saldo.dart';
import '../widgets/kartu_selamat_datang.dart';
import '../widgets/lembar_edit_transaksi.dart';
import '../widgets/memuat.dart';
import '../widgets/tile_transaksi.dart';
import 'dana_darurat_screen.dart';
import 'kiriman_screen.dart';
import 'laporan_screen.dart';
import 'pengaturan_screen.dart';
import 'riwayat_screen.dart';
import 'scan_screen.dart';
import 'tabungan_screen.dart';
import 'target_screen.dart';
import 'utang_screen.dart';

/// Home = layar input harian. Semua halaman lain lewat menu pojok kanan.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _bukaMenu(BuildContext context, String nilai) {
    // Satu pintu untuk akun + sinkronisasi + pengaturan: semuanya ada
    // di dalam PengaturanScreen (kartu "Akun & Sinkronisasi" muncul
    // sendiri kalau cloud aktif). Tidak ada lagi menu terpisah.
    final Widget? tujuan = switch (nilai) {
      'kiriman' => const KirimanScreen(),
      'darurat' => const DanaDaruratScreen(),
      'tabungan' => const TabunganScreen(),
      'target' => const TargetScreen(),
      'utang' => const UtangScreen(),
      'riwayat' => const RiwayatScreen(),
      'laporan' => const LaporanScreen(),
      'pengaturan' => const PengaturanScreen(),
      _ => null,
    };
    if (tujuan != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => tujuan),
      );
    }
  }

  /// Menu "Pemasukan lainnya" / "Pengeluaran lainnya" (uang bukan
  /// kiriman & bukan pengeluaran harian: bayar kos, wifi, hadiah...).
  /// Sejajar dengan menu Kiriman/Utang/Dana Darurat - tidak lagi
  /// berupa kartu di Home.
  void _bukaUangLain(BuildContext context, {required bool masuk}) {
    final app = context.read<AppState>();
    showDialog<void>(
      context: context,
      builder: (_) => DialogUangLain(masuk: masuk, app: app),
    );
  }

  void _bukaScan(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.receipt_long_rounded),
              title: Text(T.t('scan_struk')),
              subtitle: Text(T.t('scan_struk_sub')),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ScanScreen(jenis: ScanJenis.struk),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_rounded),
              title: Text(T.t('scan_tf')),
              subtitle: Text(T.t('scan_tf_sub')),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ScanScreen(jenis: ScanJenis.buktiTf),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Foto yang di-share dari app lain langsung dibuka di scan struk.
  /// (Teks ditangani KartuInputCepat sendiri.) Bisa berkali-kali: setelah
  /// diambil, slot di AppState dinolkan, share berikutnya masuk lagi.
  void _konsumsiBagikan() {
    final app = context.read<AppState>();
    final gambar = app.gambarBagikan;
    if (gambar == null) return;
    app.ambilGambarBagikan(); // kosongkan biar tidak dibuka dua kali
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScanScreen(jenis: ScanJenis.struk, gambarAwal: gambar),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    _konsumsiBagikan();
    final app = context.watch<AppState>();

    if (!app.siap) {
      return const Scaffold(
        body: Center(child: PemuatKosku()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'kosku',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu_rounded),
            onSelected: (v) {
              if (v == 'uangLain') {
                _bukaUangLain(context, masuk: true);
              } else {
                _bukaMenu(context, v);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'kiriman',
                child: Text(T.t('nav_kiriman')),
              ),
              PopupMenuItem(value: 'darurat', child: Text(T.t('nav_darurat'))),
              PopupMenuItem(
                  value: 'tabungan', child: Text(T.t('nav_tabungan'))),
              PopupMenuItem(value: 'target', child: Text(T.t('nav_target'))),
              PopupMenuItem(value: 'utang', child: Text(T.t('nav_utang'))),
              PopupMenuItem(
                  value: 'uangLain', child: Text(T.t('nav_uang_lain'))),
              PopupMenuItem(value: 'riwayat', child: Text(T.t('nav_riwayat'))),
              PopupMenuItem(value: 'laporan', child: Text(T.t('nav_laporan'))),
              // Akun + sinkronisasi + pengaturan = SATU menu (semua ada
              // di dalam PengaturanScreen, termasuk kartu akun bila
              // cloud aktif). Sebelumnya terpisah 3 titik: ikon status
              // sync di AppBar + menu "Akun" + menu "Pengaturan".
              PopupMenuItem(
                  value: 'pengaturan', child: Text(T.t('nav_pengaturan'))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _bukaScan(context),
        icon: const Icon(Icons.document_scanner_rounded),
        label: Text(T.t('scan')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
        children: [
          if (!app.sudahSetup) const KartuSelamatDatang(),
          const KartuSaldo(),
          const KartuPerhatian(),
          if (app.sudahSetup) const KartuBudget(),
          if (app.sudahSetup)  KartuInputCepat(),
          judulSection(T.t('bagian_hari_ini')),
          if (app.transaksiHariIni.isEmpty)
            kartuKosong(T.t('home_kosong'),
                ikon: Icons.coffee_rounded)
          else
            ...app.transaksiHariIni.map(
              (t) => TileTransaksi(
                t: t,
                onTap: () => bukaLembarTransaksi(context, t),
              ),
            ),
        ],
      ),
    );
  }
}
