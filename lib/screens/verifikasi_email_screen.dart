import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../utils/teks.dart';

/// Layar tunggu verifikasi email.
///
/// Muncul setelah daftar / masuk dengan email yang belum diverifikasi.
/// Sinkronisasi cloud otomatis menyala begitu Firebase mencatat email
/// sudah diklik - layar ini menutup sendiri. Aplikasi sendiri tetap
/// bisa dipakai offline tanpa menunggu apa pun (tombol di bawah).
class VerifikasiEmailScreen extends StatefulWidget {
  const VerifikasiEmailScreen({super.key});

  @override
  State<VerifikasiEmailScreen> createState() => _VerifikasiEmailScreenState();
}

class _VerifikasiEmailScreenState extends State<VerifikasiEmailScreen> {
  Timer? _cekOtomatis;
  Timer? _hitungMundur;
  int _detikTunggu = 0;
  bool _mengirim = false;
  bool _memeriksa = false;

  @override
  void initState() {
    super.initState();
    // Cek status tiap 5 detik: user buka email → klik link → app langsung
    // lanjut tanpa perlu mencet apa pun.
    _cekOtomatis =
        Timer.periodic(const Duration(seconds: 5), (_) => _periksa(oto: true));
  }

  @override
  void dispose() {
    _cekOtomatis?.cancel();
    _hitungMundur?.cancel();
    super.dispose();
  }

  Future<void> _periksa({bool oto = false}) async {
    if (_memeriksa || !mounted) return;
    _memeriksa = true;
    final app = context.read<AppState>();
    final terverifikasi = await app.cekVerifikasiEmail();
    _memeriksa = false;
    if (!mounted) return;
    if (terverifikasi) {
      _cekOtomatis?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.t('verif_sukses'))),
      );
      Navigator.pop(context); // sinkronisasi sudah jalan otomatis
    } else if (!oto) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.t('verif_belum'))),
      );
    }
  }

  Future<void> _kirimUlang() async {
    final app = context.read<AppState>();
    setState(() => _mengirim = true);
    final error = await app.kirimVerifikasiEmail();
    if (!mounted) return;
    setState(() {
      _mengirim = false;
      // Cooldown supaya tidak kena "too-many-requests" dari Firebase.
      _detikTunggu = error == null ? 60 : 10;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? T.t('verif_terkirim'))),
    );
    _hitungMundur?.cancel();
    _hitungMundur = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _detikTunggu = _detikTunggu > 0 ? _detikTunggu - 1 : 0);
      if (_detikTunggu == 0) t.cancel();
    });
  }

  Future<void> _keluar() async {
    final app = context.read<AppState>();
    await app.keluarAkun();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(T.t('verif_judul'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          Icon(Icons.mark_email_unread_rounded, size: 64, color: cs.primary),
          const SizedBox(height: 16),
          Text(
            T.t('verif_kartu_judul'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            T.f('verif_desc', {'e': app.emailAkun ?? '-'}),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: cs.onSurface.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 24),

          // Kirim ulang (dengan cooldown).
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_mengirim || _detikTunggu > 0) ? null : _kirimUlang,
              icon: _mengirim
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.outgoing_mail, size: 18),
              label: Text(_detikTunggu > 0
                  ? T.f('verif_tunggu', {'n': '$_detikTunggu'})
                  : T.t('verif_kirim_ulang')),
            ),
          ),
          const SizedBox(height: 8),

          // Cek sekarang (selain auto-check tiap 5 detik).
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _periksa(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(T.t('verif_ceklagi')),
            ),
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: 16),
          Text(
            T.t('verif_offline_note'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: cs.onSurface.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _keluar,
              child: Text(T.t('verif_keluar')),
            ),
          ),
        ],
      ),
    );
  }
}
