import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/app_state.dart';
import 'screens/home_screen.dart';
import 'screens/layar_kunci.dart';
import 'screens/layar_sambutan.dart';
import 'screens/layar_splash.dart';
import 'services/bagikan_service.dart';
import 'services/notifikasi_service.dart';
import 'utils/tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  await initializeDateFormatting('en_US');

  // Firebase opsional: kalau belum di-flutterfire-configure, aplikasi tetap
  // jalan penuh dalam mode "lokal saja" (tanpa login & sync).
  var cloudSiap = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    cloudSiap = true;
  } catch (_) {
    cloudSiap = false;
  }

  final app = AppState(cloudSiap: cloudSiap)..muatSemua();

  // Terima foto/teks yang di-share dari app lain (WhatsApp, galeri, dll).
  // Hanya di Android; di platform lain BagikanService tidak dibuat.
  if (Platform.isAndroid) {
    BagikanService(
      onGambar: (bytes) => app.terimaBagikan(gambar: bytes),
      onTeks: (teks) => app.terimaBagikan(teks: teks),
    ).mulai(); // service memegang dirinya sendiri (static _aktif)
  }

  runApp(
    ChangeNotifierProvider.value(
      value: app,
      child: KoskuApp(cloudSiap: cloudSiap),
    ),
  );

  // Pengingat Android (kiriman / utang / catat harian): disiapkan
  // SETELAH UI jalan supaya startup tidak tertunda. Izin notifikasi
  // (Android 13+) diminta sekali oleh plugin; kalau ditolak, fitur
  // pengingat mati sendirian tanpa mengganggu aplikasi.
  NotifikasiService.instance.siapkan();
}

/// Tema dipasang lewat [buildTemaKosku] di utils/tema.dart.

class KoskuApp extends StatelessWidget {
  final bool cloudSiap;
  const KoskuApp({super.key, required this.cloudSiap});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'kosku',
      debugShowCheckedModeBanner: false,
      theme: buildTemaKosku(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      home: Consumer<AppState>(
        builder: (context, app, _) {
          // Splash brand tampil SETIAP sesi pembukaan aplikasi (gaya
          // Gojek), sekaligus berfungsi sebagai layar memuat data.
          if (!app.siap || !app.splashSelesai) return const LayarSplash();
          if (app.terkunci) return const LayarKunci();
          // Sekali di awal: sambutan brand dulu, baru isi aplikasi.
          if (!app.sudahSambutan) return const LayarSambutan();
          return const HomeScreen();
        },
      ),
    );
  }
}
