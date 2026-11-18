import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Menerima foto / teks yang di-share dari aplikasi lain (WhatsApp,
/// galeri, dsb) lewat Android share target (intent-filter SEND).
/// Pemakaian:
///   BagikanService(onGambar: ..., onTeks: ...).mulai();
/// Callback dipanggil di main() sebelum runApp; mereka memasukkan data
/// ke AppState, Home yang mengarahkan (scan foto / isi input NL).
class BagikanService {
  final void Function(Uint8List bytes)? onGambar;
  final void Function(String teks)? onTeks;

  /// Referensi instance aktif: menjaga objek + langganan stream tetap
  /// hidup tanpa perlu menyimpan variabel global di main().
  static BagikanService? _aktif;

  StreamSubscription<List<SharedMediaFile>>? _langganan;
  bool _selesaiAwal = false;

  BagikanService({this.onGambar, this.onTeks});

  void mulai() {
    _aktif = this;
    try {
      _langganan = ReceiveSharingIntent.instance.getMediaStream().listen(
            _terima,
            onError: (_) {},
          );
      // App dibuka langsung dari share (cold start).
      ReceiveSharingIntent.instance
          .getInitialMedia()
          .then(_terimaSekali)
          .catchError((_) {});
    } catch (_) {
      // Plugin tidak tersedia / platform bukan Android: diam saja.
    }
  }

  void _terimaSekali(List<SharedMediaFile> daftar) {
    _terima(daftar);
    _selesaiAwal = true;
  }

  void _terima(List<SharedMediaFile> daftar) {
    if (daftar.isEmpty) return;
    for (final media in daftar) {
      // Prioritas foto: langsung diarahkan ke scan struk.
      if (media.type == SharedMediaType.image &&
          media.path.isNotEmpty &&
          onGambar != null) {
        File(media.path).readAsBytes().then((bytes) {
          onGambar?.call(bytes);
        }).catchError((_) {});
        ReceiveSharingIntent.instance.reset();
        return;
      }
      // Teks: masuk ke input cepat di Home.
      // (Sejak receive_sharing_intent 1.6, teks juga datang lewat stream
      //  media: isinya ada di .path dengan type == text.)
      final teks = media.path;
      if (media.type == SharedMediaType.text &&
          teks.trim().isNotEmpty &&
          onTeks != null) {
        onTeks?.call(teks);
        ReceiveSharingIntent.instance.reset();
        return;
      }
    }
    if (_selesaiAwal) ReceiveSharingIntent.instance.reset();
  }

  void berhenti() {
    _langganan?.cancel();
    _langganan = null;
    if (_aktif == this) _aktif = null;
  }
}
