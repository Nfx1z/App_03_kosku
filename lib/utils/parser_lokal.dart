import '../models/transaksi.dart';
import 'format.dart';

/// Hasil parser lokal (offline, tanpa Gemini).
/// Semua field bisa null / tidak yakin - UI tetap minta user cek.
class HasilParseLokal {
  /// Nama pengeluaran setelah angka & kata waktu dibuang.
  final String? nama;

  /// Nominal hasil baca (null kalau tidak ketemu angka).
  final int? jumlah;

  /// Tebakan kategori (null kalau tidak yakin / lain-lain).
  final KategoriPengeluaran? kategori;

  /// -1 = "kemarin", 0 = hari ini (default).
  final int offsetHari;

  const HasilParseLokal({
    this.nama,
    this.jumlah,
    this.kategori,
    this.offsetHari = 0,
  });
}

final RegExp _reAngka = RegExp(
  r'(\d+(?:[.,]\d{3})+|\d+(?:[.,]\d+)?|\d+)\s*(rb|ribu|k|jt|juta)?\b',
  caseSensitive: false,
);

double _desimal(String s) {
  final bersih = s.replaceAll(',', '.');
  return double.tryParse(bersih) ?? 0;
}

/// Kata pengisi gaya ngomong sehari-hari yang tidak menambah makna
/// nama pengeluaran - dibuang supaya nama dari input suara / teks
/// tetap ringkas ("tadi aku abis beli nasi padang 25rb" → "nasi
/// padang"). Hati-hati jangan memotong nama beneran: kata kategori
/// seperti "belanja" (belanja pokok), "makan" (makan siang), "ke"
/// (gojek ke kampus) sengaja TIDAK ada di daftar ini.
final RegExp _reKataIsi = RegExp(
  r'\b(aku|gua|gue|saya|udah|udh|dah|sudah|abis|abisnya|habis|'
  r'tuh|nah|nih|deh|dong|doang|cuma|cuman|cmn|mah|banget|kok|'
  r'terus|trs|trus|eh|emang|aja|saja|ya|yah|buat|bwt|'
  r'beli|beliin|bayar|bayarin)\b',
  caseSensitive: false,
);

/// Ubah satu token angka + satuan jadi rupiah bulat.
/// "15rb" → 15000, "1.5jt" → 1500000, "25.000" → 25000,
/// "15" → 15000 (angka kecil dianggap ribuan, gaya bicara sehari-hari).
int? _nominalDari(String angka, String? satuan) {
  final satuanKecil = satuan?.toLowerCase();
  if (satuanKecil == 'rb' || satuanKecil == 'ribu' || satuanKecil == 'k') {
    return (_desimal(angka) * 1000).round();
  }
  if (satuanKecil == 'jt' || satuanKecil == 'juta') {
    return (_desimal(angka) * 1000000).round();
  }
  // Tanpa satuan: "25.000" / "1.500.000" = pemisah ribuan.
  if (RegExp(r'^\d+(?:[.,]\d{3})+$').hasMatch(angka)) {
    return int.tryParse(angka.replaceAll(RegExp(r'[.,]'), ''));
  }
  final nilai = _desimal(angka);
  if (nilai <= 0) return null;
  // Angka telanjang: < 1000 dianggap ribuan ("ngopi 15" = 15rb).
  if (nilai < 1000) return (nilai * 1000).round();
  return nilai.round();
}

/// Parser pengeluaran bahasa alami, jalan 100% offline.
/// Contoh: "ngopi 15rb", "belanja pokok 250rb kemarin", "gojek 12.500".
/// Dipakai kalau Gemini tidak tersedia; hasilnya selalu bisa dikoreksi user.
HasilParseLokal parseTeksLokal(String teks) {
  final asli = teks.trim();
  if (asli.isEmpty) return const HasilParseLokal();

  // Pilih angka pertama yang paling "yakin": yang pakai satuan (rb/jt) menang.
  RegExpMatch? pilihan;
  String? satuanPilihan;
  for (final m in _reAngka.allMatches(asli)) {
    final satuan = m.group(2);
    if (satuan != null) {
      pilihan = m;
      satuanPilihan = satuan;
      break;
    }
    pilihan ??= m;
  }

  int? jumlah;
  if (pilihan != null) {
    jumlah = _nominalDari(pilihan.group(1)!, satuanPilihan);
  }

  // Buang token angka + kata waktu + kata pengisi dari teks → sisanya
  // jadi nama.
  var nama = asli;
  if (pilihan != null) {
    nama = nama.replaceRange(
      pilihan.start,
      pilihan.end,
      ' ',
    );
  }
  nama = nama
      .replaceAll(
          RegExp(r'\b(kemarin|kemaren|barusan|tadi)\b', caseSensitive: false),
          ' ')
      .replaceAll(_reKataIsi, ' ')
      .replaceAll(RegExp(r'[-–:|]+\s*$'), '')
      .replaceAll(RegExp(r'^\s*[-–:|]+\s*'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final offsetHari =
      RegExp(r'\b(kemarin|kemaren)\b', caseSensitive: false).hasMatch(asli)
          ? -1
          : 0;

  // Tebak kategori dari nama; kalau mentok lain-lain, anggap tidak yakin.
  final tebakan = tebakKategori(nama.isEmpty ? asli : nama);
  final kategori =
      tebakan == KategoriPengeluaran.lainLain ? null : tebakan;

  return HasilParseLokal(
    nama: nama.isEmpty ? null : nama,
    jumlah: jumlah,
    kategori: kategori,
    offsetHari: offsetHari,
  );
}
