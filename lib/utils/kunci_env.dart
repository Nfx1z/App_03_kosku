/// Kunci API Gemini yang **dibundel saat build** - user tidak perlu
/// (dan tidak bisa) memasukkan key sendiri; mereka cukup daftar/masuk.
///
/// Flutter tidak punya file `.env` bawaan. Padanannya adalah menyuntik
/// nilai lewat `--dart-define`, yang dievaluasi jadi konstanta
/// compile-time oleh `String.fromEnvironment`:
///
/// ```bash
/// flutter run \
///   --dart-define=GEMINI_API_KEY_1=AIza... \
///   --dart-define=GEMINI_API_KEY_2=AIza...
///
/// flutter build apk --release \
///   --dart-define=GEMINI_API_KEY_1=AIza... \
///   --dart-define=GEMINI_API_KEY_2=AIza...
/// ```
///
/// Keuntungan dibanding memakai user input + secure storage:
/// - tidak ada UI penyimpanan key, alur user murni login / daftar;
/// - key tidak pernah tersimpan di perangkat, tidak ikut sync, dan
///   tidak pernah ditulis ke SQLite;
/// - ganti key = build ulang, tanpa migrasi data.
///
/// Catatan jujur: nilai tetap terkompilasi di dalam APK, jadi tetap
/// bisa diekstrak secara teknis. Batasi key di Google Cloud Console
/// ke package name + SHA-1 aplikasi supaya tidak bisa dipakai pihak lain.
class KunciEnv {
  /// Slot pertama (wajib supaya scan aktif).
  static const String kunci1 = String.fromEnvironment('GEMINI_API_KEY_1');

  /// Slot kedua (opsional; kalau ada, dipakai bergantian dengan slot 1).
  static const String kunci2 = String.fromEnvironment('GEMINI_API_KEY_2');

  /// Daftar key yang benar-benar terisi (slot kosong otomatis dilewati).
  static List<String> get daftar => [
        if (kunci1.trim().isNotEmpty) kunci1.trim(),
        if (kunci2.trim().isNotEmpty) kunci2.trim(),
      ];

  /// True kalau build ini menyertakan minimal satu key.
  static bool get tersedia => daftar.isNotEmpty;
}
