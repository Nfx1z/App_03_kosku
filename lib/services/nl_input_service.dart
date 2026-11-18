import '../models/transaksi.dart';
import '../utils/parser_lokal.dart';
import 'gemini_service.dart';

/// Hasil parsing input bebas, dibungkus jadi satu bentuk untuk UI.
class HasilParseInput {
  final String? nama;
  final int? jumlah;
  final KategoriPengeluaran? kategori;
  final int offsetHari;

  /// 'gemini' kalau dibaca AI, 'lokal' kalau parser offline.
  final String sumber;

  const HasilParseInput({
    this.nama,
    this.jumlah,
    this.kategori,
    this.offsetHari = 0,
    this.sumber = 'lokal',
  });
}

/// Orkestrator input bahasa alami:
/// 1. Coba Gemini (kalau ada API key) - paling paham konteks & slang.
///    Pakai [GeminiKeyPool]: 2 key bergantian otomatis biar kuota lega.
/// 2. Kalau gagal / offline / tanpa key → parser lokal (regex) tetap jalan.
/// UI selalu menampilkan hasil di form untuk dicek user sebelum disimpan.
Future<HasilParseInput> parseInput(
  String teks, {
  GeminiKeyPool? pool,
}) async {
  if (teks.trim().isEmpty) return const HasilParseInput();

  if (pool != null) {
    try {
      final r = await pool.jalankan((svc) => svc.bacaTeksBebas(teks.trim()));
      if (r.jumlah > 0 || (r.nama != null && r.nama!.isNotEmpty)) {
        final kategori = r.kategori == null
            ? null
            : KategoriPengeluaran.dariNilai(r.kategori!);
        return HasilParseInput(
          nama: (r.nama == null || r.nama!.isEmpty) ? null : r.nama,
          jumlah: r.jumlah > 0 ? r.jumlah : null,
          kategori: kategori == KategoriPengeluaran.lainLain
              ? null
              : kategori,
          offsetHari: r.offsetHari,
          sumber: 'gemini',
        );
      }
    } on GeminiException {
      // Offline / key bermasalah → fallback lokal, bukan error untuk user.
    } catch (_) {
      // Bentuk balasan aneh → fallback lokal.
    }
  }

  final l = parseTeksLokal(teks);
  return HasilParseInput(
    nama: l.nama,
    jumlah: l.jumlah,
    kategori: l.kategori,
    offsetHari: l.offsetHari,
    sumber: 'lokal',
  );
}
