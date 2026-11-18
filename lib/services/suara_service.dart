import 'package:speech_to_text/speech_to_text.dart';

/// Input suara: speech-to-text perangkat (bahasa Indonesia),
/// hasilnya dilempar ke pipeline parsing input bebas (NL).
///
/// SINGLETON: engine cukup di-initialize SEKALI per sesi aplikasi.
/// Inisialisasi speech recognizer itu yang paling lambat (1-2 detik);
/// setelah aktif, menahan tombol mic langsung mendengar tanpa jeda.
///
/// Mode TAHAN-UNTUK-BICARA (ala voice note WhatsApp):
/// - [dengar] dipanggil saat jari mulai menekan tombol mic;
/// - [berhenti] saat jari dilepas -> mengembalikan teks final;
/// - [batal] untuk membuang perekaman (geser batal / interupsi sistem);
/// - [saatSelesai] tetap dipanggil kalau engine berhenti SENDIRI
///   (cap waktu) supaya UI tidak nyangkut di status "merekam".
class SuaraService {
  SuaraService._();
  static final SuaraService instance = SuaraService._();

  final SpeechToText _stt = SpeechToText();
  bool _siap = false;
  bool _sedangDengar = false;
  String _teksTerakhir = '';

  bool get tersedia => _siap;
  bool get sedangDengar => _sedangDengar || _stt.isListening;

  /// Minta izin mikrofon + siapkan engine. Return false kalau ditolak /
  /// tidak ada speech recognizer di perangkat. Panggilan berikutnya
  /// (setelah sukses) langsung true tanpa menunggu apa pun.
  Future<bool> siapkan() async {
    if (_siap) return true;
    try {
      _siap = await _stt.initialize();
    } catch (_) {
      _siap = false;
    }
    return _siap;
  }

  /// Mulai mendengar.
  /// [saatHasil] menerima teks sementara; final=true saat kalimat selesai.
  /// [saatLevel] menerima level suara 0..1 (untuk animasi bar suara).
  /// [saatSelesai] dipanggil SETELAH listening berhenti sendiri (cap
  /// [batasDengar] / deteksi diam) - bukan saat [berhenti]/[batal].
  /// [berhentiSaatDiam]=true: 2 detik diam dianggap selesai (mode lama).
  /// false (mode tahan): rekam terus selama jari menahan, sampai cap waktu.
  Future<void> dengar({
    required void Function(String teks, bool final_) saatHasil,
    void Function(double level)? saatLevel,
    void Function()? saatSelesai,
    bool berhentiSaatDiam = false,
    Duration batasDengar = const Duration(seconds: 30),
  }) async {
    if (!_siap) {
      saatSelesai?.call();
      return;
    }
    _teksTerakhir = '';
    _sedangDengar = true;
    try {
      await _stt.listen(
        onResult: (hasil) {
          _teksTerakhir = hasil.recognizedWords;
          saatHasil(hasil.recognizedWords, hasil.finalResult);
        },
        localeId: 'id_ID',
        listenFor: batasDengar,
        pauseFor: berhentiSaatDiam ? const Duration(seconds: 2) : null,
        onSoundLevelChange: saatLevel == null
            ? null
            : (db) => saatLevel(_normalisasiLevel(db)),
        listenOptions: SpeechListenOptions(
          // Hasil parsial LANGSUNG mengalir ke layar saat masih bicara -
          // terasa instan, seperti voice note.
          partialResults: true,
        ),
      );
    } catch (_) {
      // Engine gagal mulai (mis. izin dicabut saat berjalan): akhiri rapi.
      _sedangDengar = false;
      saatSelesai?.call();
      return;
    }
    // listen() berhenti secara asinkron; pantau status via timer sederhana.
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      _pantauSelesai(saatSelesai);
    });
  }


  /// dB (kisaran -45..0) -> 0..1 untuk animasi bar level suara.
  double _normalisasiLevel(double db) {
    if (db >= 0) return 1;
    return ((db + 45) / 45).clamp(0.0, 1.0).toDouble();
  }

  void _pantauSelesai(void Function()? saatSelesai) async {
    for (var i = 0; i < 120; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!_stt.isListening) {
        _sedangDengar = false;
        saatSelesai?.call();
        return;
      }
    }
    _sedangDengar = false;
  }

  /// Berhenti & kembalikan teks final - dipanggil saat jari dilepas.
  /// Tunggu sebentar supaya hasil pengucapan terakhir sempat mendarat
  /// sebelum teks dibaca (stop() asinkron di sisi native).
  Future<String> berhenti() async {
    try {
      await _stt.stop();
    } catch (_) {}
    _sedangDengar = false;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final teks = _teksTerakhir.trim();
    _teksTerakhir = '';
    return teks;
  }

  /// Buang perekaman tanpa memproses hasil (geser batal, interupsi
  /// sistem seperti telepon masuk): pakai cancel() supaya engine dan
  /// hasil sementara dibersihkan total.
  Future<void> batal() async {
    try {
      await _stt.cancel();
    } catch (_) {}
    _sedangDengar = false;
    _teksTerakhir = '';
  }
}
