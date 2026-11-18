import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../utils/teks.dart';
import 'verifikasi_email_screen.dart';

/// Login / daftar akun (email & sandi) + lupa sandi.
/// Bisa dilewati ("pakai offline dulu") - aplikasi tetap berfungsi penuh.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  final _emailCtl = TextEditingController();
  final _sandiCtl = TextEditingController();
  bool _sandiKelihatan = false;
  bool _memproses = false;
  String? _error;

  @override
  void dispose() {
    _tab.dispose();
    _emailCtl.dispose();
    _sandiCtl.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    final app = context.read<AppState>();
    final email = _emailCtl.text.trim();
    final sandi = _sandiCtl.text;

    if (email.isEmpty || sandi.isEmpty) {
      setState(() => _error = T.t('auth_err_isi_dulu'));
      return;
    }

    setState(() {
      _memproses = true;
      _error = null;
    });

    final modeDaftar = _tab.index == 1;
    final error = modeDaftar
        ? await app.daftarAkun(email, sandi)
        : await app.masukAkun(email, sandi);

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _memproses = false;
        _error = error;
      });
      return;
    }

    // Sukses: listener AppState otomatis menyiapkan sinkronisasi.
    // Email belum diverifikasi → layar verifikasi dulu (bisa dilewati).
    setState(() => _memproses = false);
    if (!mounted) return;
    if (!app.emailTerverifikasi) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const VerifikasiEmailScreen()),
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _lupaSandi() async {
    final app = context.read<AppState>();
    final email = _emailCtl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = T.t('auth_err_invalid_email'));
      return;
    }
    setState(() {
      _memproses = true;
      _error = null;
    });
    final error = await app.kirimResetSandi(email);
    if (!mounted) return;
    setState(() => _memproses = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? T.t('snack_reset_terkirim'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(T.t('akun_judul')),
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(text: T.t('masuk_judul'), icon: const Icon(Icons.login_rounded)),
            Tab(text: T.t('daftar_judul'), icon: const Icon(Icons.person_add_rounded)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: cs.secondaryContainer,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.cloud_sync_outlined,
                      color: cs.onSecondaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      T.t('akun_sub'),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailCtl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: T.t('email'),
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sandiCtl,
            obscureText: !_sandiKelihatan,
            onSubmitted: (_) => _kirim(),
            decoration: InputDecoration(
              labelText: T.t('sandi'),
              helperText: _tab.index == 1 ? T.t('sandi_hint') : null,
              prefixIcon: const Icon(Icons.password_rounded),
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                icon: Icon(_sandiKelihatan
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded),
                onPressed: () =>
                    setState(() => _sandiKelihatan = !_sandiKelihatan),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _error!,
                style: TextStyle(fontSize: 12.5, color: cs.onErrorContainer),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _memproses ? null : _kirim,
              child: _memproses
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_tab.index == 1
                      ? T.t('tombol_daftar')
                      : T.t('tombol_masuk')),
            ),
          ),
          TextButton(
            onPressed: _memproses ? null : _lupaSandi,
            child: Text(T.t('lupa_sandi')),
          ),
          const Divider(height: 24),
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.wifi_off_rounded, size: 18),
            label: Text(T.t('pakai_offline')),
          ),
        ],
      ),
    );
  }
}
