import 'package:firebase_auth/firebase_auth.dart';

import '../utils/teks.dart';

/// Login email & password via Firebase Authentication.
/// Dibangun HANYA kalau Firebase sudah terkonfigurasi (lihat AppState).
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get userSekarang => _auth.currentUser;
  String? get emailSekarang => _auth.currentUser?.email;

  /// Stream user: null = sudah keluar / sesi hilang.
  Stream<User?> get perubahanUser => _auth.authStateChanges();

  Future<void> daftar({required String email, required String sandi}) async {
    await _auth.createUserWithEmailAndPassword(email: email, password: sandi);
  }

  Future<void> masuk({required String email, required String sandi}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: sandi);
  }

  Future<void> keluar() => _auth.signOut();

  Future<void> kirimReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  /// Kirim email verifikasi ke user yang sedang login.
  /// Firebase mengirim link; sinkronisasi dibuka setelah link diklik.
  Future<void> kirimVerifikasiEmail() async {
    final user = _auth.currentUser;
    if (user != null) await user.sendEmailVerification();
  }

  /// Muat ulang profil user terbaru dari Firebase
  /// (status verifikasi email bisa berubah di sisi server).
  Future<void> muatUlang() async {
    final user = _auth.currentUser;
    if (user != null) await user.reload();
  }

  /// Terjemahkan error Firebase ke bahasa aktif.
  String pesanError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return T.t('auth_err_invalid_email');
        case 'wrong-password':
        case 'invalid-credential':
          return T.t('auth_err_wrong_password');
        case 'user-not-found':
          return T.t('auth_err_user_not_found');
        case 'email-already-in-use':
          return T.t('auth_err_email_in_use');
        case 'weak-password':
          return T.t('auth_err_weak_password');
        case 'network-request-failed':
          return T.t('auth_err_network');
        case 'too-many-requests':
          return T.t('auth_err_too_many');
      }
      return T.f('auth_err_lain', {'x': e.code});
    }
    return T.f('auth_err_lain', {'x': e.toString()});
  }
}
