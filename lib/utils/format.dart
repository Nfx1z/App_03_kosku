import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/transaksi.dart';
import 'teks.dart';

String get _locale => T.bahasa == 'en' ? 'en_US' : 'id_ID';

/// Format ribuan gaya Indonesia: 15000 → "15.000".
/// Selalu titik (bukan ikut bahasa) supaya kolom input konsisten.
String ribuan(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    buf.write(s[i]);
    final sisa = s.length - i - 1;
    if (sisa > 0 && sisa % 3 == 0) buf.write('.');
  }
  final hasil = buf.toString();
  return n < 0 ? '-$hasil' : hasil;
}

/// Formatter input uang: selama user mengetik, angka langsung diberi
/// titik ribuan ("15000" → "15.000") supaya kelihatan berapa rupiah.
/// Pasang di TextField: inputFormatters: [RibuanFormatter()].
class RibuanFormatter extends TextInputFormatter {
  const RibuanFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    // Buang nol di depan ("0007" → 7).
    final bersih = digits.replaceFirst(RegExp(r'^0+'), '');
    final n = int.tryParse(bersih.isEmpty ? '0' : bersih) ?? 0;
    final teks = ribuan(n);
    return TextEditingValue(
      text: teks,
      selection: TextSelection.collapsed(offset: teks.length),
    );
  }
}

/// "Rp 1.500.000" (id) / "Rp 1,500,000" (en)
String rp(int n) => 'Rp ${NumberFormat('#,###', _locale).format(n)}';

/// "+ Rp 50.000" / "- Rp 5.000" (tanpa nol: "Rp 0")
String rpTanda(int n) {
  if (n == 0) return 'Rp 0';
  return n > 0 ? '+ ${rp(n)}' : '- ${rp(-n)}';
}

String tanggalLengkap(DateTime d) =>
    DateFormat('EEEE, d MMMM yyyy', _locale).format(d);

String tanggalPendek(DateTime d) => DateFormat('d MMM yyyy', _locale).format(d);

String tanggalSangatPendek(DateTime d) => DateFormat('d MMM', _locale).format(d);

String jamPendek(DateTime d) => DateFormat('HH:mm', _locale).format(d);

/// Nama bulan + tahun untuk judul laporan ("November 2026").
String namaBulanTahun(int tahun, int bulan) =>
    DateFormat('MMMM yyyy', _locale).format(DateTime(tahun, bulan));

/// Normalisasi ke tanggal saja (tanpa jam).
DateTime tanggalSaja(DateTime d) => DateTime(d.year, d.month, d.day);

/// Kunci hari "yyyy-MM-dd" (zona waktu lokal) untuk bucket pengeluaran
/// per hari - dipakai hitungan tabungan hemat bulanan.
String kunciHari(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Kunci bulan "yyyy-MM" untuk riwayat tabungan per bulan.
String kunciBulan(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}';

/// Parse "yyyy-MM-dd" → DateTime tanggal-saja (aman dari UTC shift).
DateTime? tanggalDariIso(String? s) {
  if (s == null || s.isEmpty) return null;
  final d = DateTime.tryParse(s);
  if (d == null) return null;
  return DateTime(d.year, d.month, d.day);
}

// ================= TANGGAL & JAM DOKUMEN (SCAN) =================
// Struktur/bukti transfer Indonesia mencetak tanggal dd/MM/yyyy, tapi
// hasil bacaan Gemini bisa balas dalam format apa pun (ISO, mm/dd
// gaya Amerika, 2 digit tahun, bahkan tanpa tahun). Semua parsing
// tanggal+jam dokumen dipusatkan di sini supaya:
// - format dd/MM selalu menang (kecuali pasangannya ketara mm/dd,
//   mis. "12/28" = 28 Desember);
// - tahun yang tidak terbaca dianggap TAHUN BERJALAN (bukan tebakan
//   acak yang bikin transaksi nyasar ke tahun lalu);
// - jam dokumen ikut terbaca (bukan selalu 00:00).

/// Validasi komponen tanggal; null kalau bulan/hari tidak mungkin
/// (mis. 31/02, bulan 13) - DateTime Dart "memutar" ke bulan berikutnya,
/// jadi hasilnya dicek balik.
DateTime? _tanggalAman(int tahun, int bulan, int hari) {
  if (bulan < 1 || bulan > 12 || hari < 1 || hari > 31) return null;
  final d = DateTime(tahun, bulan, hari);
  if (d.year != tahun || d.month != bulan || d.day != hari) return null;
  return DateTime(tahun, bulan, hari);
}

/// Parse tanggal dari hasil bacaan dokumen (struk / bukti transfer).
/// Format yang dikenali:
/// 1. "yyyy-MM-dd" atau "yyyy/MM/dd" (ISO - balasan Gemini paling umum);
/// 2. "dd/MM/yyyy" dengan pemisah `/` `-` `.` (format Indonesia);
/// 3. tahun 2 digit ("18/11/25" → 2025-11-18);
/// 4. TANPA tahun ("18/11") → dianggap TAHUN BERJALAN.
///
/// Khusus angka pertama <= 12 dan angka kedua > 12 (mis. "12/28"):
/// satu-satunya bacaan yang masuk akal adalah MM/dd → 28 Desember.
/// Selain itu (ambigu atau jelas dd/MM) → selalu dd/MM (Indonesia).
/// String kosong / tak dikenal → null.
DateTime? parseTanggalDokumen(String? v) {
  if (v == null) return null;
  var s = v.trim();
  if (s.isEmpty) return null;
  // Buang bagian jam/teks lain: "18/11/2026 14:23" → "18/11/2026".
  s = s.split(RegExp(r'[\sT]+'))[0];

  final iso = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$').firstMatch(s);
  if (iso != null) {
    return _tanggalAman(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    );
  }

  final m = RegExp(r'^(\d{1,2})[./-](\d{1,2})(?:[./-](\d{2,4}))?$')
      .firstMatch(s);
  if (m == null) return null;
  final a = int.parse(m.group(1)!);
  final b = int.parse(m.group(2)!);
  final th = m.group(3);
  final kini = DateTime.now();
  final tahun = th == null
      ? kini.year // tahun tidak terbaca → tahun berjalan
      : (th.length <= 2 ? 2000 + int.parse(th) : int.parse(th));

  final int hari;
  final int bulan;
  if (a <= 12 && b > 12) {
    // "12/28" - cuma mungkin MM/dd (28 Desember).
    bulan = a;
    hari = b;
  } else {
    // Format Indonesia dd/MM - termasuk saat ambigu (18/11, 05/03).
    hari = a;
    bulan = b;
  }
  return _tanggalAman(tahun, bulan, hari);
}

/// Parse jam dari hasil bacaan dokumen: "14:35", "14.35", "09:05:22",
/// "14.35 WIB" → menit sejak tengah malam (14*60+35 = 875).
/// Tidak terbaca / tidak wajar ("25:00") → null.
int? parseJamDokumen(String? v) {
  if (v == null) return null;
  final m = RegExp(r'(\d{1,2})[:.](\d{2})').firstMatch(v.trim());
  if (m == null) return null;
  final jam = int.parse(m.group(1)!);
  final menit = int.parse(m.group(2)!);
  if (jam > 23 || menit > 59) return null;
  return jam * 60 + menit;
}

/// Gerbang tanggal dokumen hasil scan: hanya tanggal yang WAJAR untuk
/// dicatat yang diterima, yaitu:
/// - tahun tidak di bawah tahun berjalan;
/// - tidak lebih dari 1 bulan yang lalu;
/// - tidak di masa depan (salah baca).
/// Di luar jendela itu → null: pemanggil memakai HARI INI + jam scan.
/// Ini pelindungnya: satu struk salah baca (mis. "18/11/2023") tidak
/// boleh menarik catatan - dan hitungan tabungan hemat - bertahun ke
/// belakang.
DateTime? validasiTanggalDokumen(DateTime? d) {
  if (d == null) return null;
  final kini = DateTime.now();
  final tgl = tanggalSaja(d);
  if (tgl.year < kini.year) return null;
  final batas = DateTime(kini.year, kini.month - 1, kini.day);
  if (tgl.isBefore(batas)) return null;
  if (tgl.isAfter(tanggalSaja(kini))) return null;
  return tgl;
}

/// Gabungkan tanggal (tanpa jam) dengan jam-dalam-menit hasil bacaan.
/// Kalau jam dokumen tidak ada ([jamMenit] null), pakai jam dari
/// [cadangan] - mis. saat struk di-scan - supaya transaksi tidak
/// tercatat jam 00:00.
DateTime tanggalDenganJam(
  DateTime tanggal,
  int? jamMenit,
  DateTime cadangan,
) {
  final jm = jamMenit ?? cadangan.hour * 60 + cadangan.minute;
  return DateTime(tanggal.year, tanggal.month, tanggal.day, jm ~/ 60, jm % 60);
}

/// Label "HH:mm" dari jam-dalam-menit (875 → "14:35").
String jamMenitLabel(int menit) {
  final m = menit < 0 ? 0 : (menit > 1439 ? 1439 : menit);
  return '${(m ~/ 60).toString().padLeft(2, '0')}:'
      '${(m % 60).toString().padLeft(2, '0')}';
}

/// Parse input harga bebas ("15000", "15.000", "Rp 15.000") → int.
int parseRupiah(String s) {
  final bersih = s.replaceAll(RegExp(r'[^0-9]'), '');
  if (bersih.isEmpty) return 0;
  return int.tryParse(bersih) ?? 0;
}

/// Label kategori dua bahasa (dropdown, subtitle, laporan).
String labelKategori(KategoriPengeluaran k) => T.t('kategori_${k.nilai}');

/// Label jenis transaksi dua bahasa (subtitle riwayat).
String labelJenis(JenisTransaksi j) => T.t('jenis_${j.nilai}');

/// Judul satu baris transaksi (dipakai tile riwayat), dua bahasa.
String judulTransaksi(Transaksi t) {
  final orang = t.catatan ?? T.t('seseorang');
  switch (t.jenis) {
    case JenisTransaksi.pengeluaran:
      return t.catatan ?? T.t('judul_pengeluaran');
    case JenisTransaksi.pemasukan:
      return t.catatan ?? T.t('judul_pemasukan');
    case JenisTransaksi.isiDarurat:
      return T.t('jenis_isi_darurat');
    case JenisTransaksi.pakaiDarurat:
      return t.catatan ?? T.t('judul_pakai_darurat');
    case JenisTransaksi.tarikDarurat:
      return T.t('judul_tarik_darurat');
    case JenisTransaksi.utangMasuk:
      return T.f('judul_utang_masuk', {'x': orang});
    case JenisTransaksi.utangBayar:
      return T.f('judul_utang_bayar', {'x': orang});
    case JenisTransaksi.piutangKeluar:
      return T.f('judul_piutang_keluar', {'x': orang});
    case JenisTransaksi.piutangTerima:
      return T.f('judul_piutang_terima', {'x': orang});
    case JenisTransaksi.koreksi:
      return t.catatan ?? T.t('judul_koreksi');
    case JenisTransaksi.masukLain:
      return t.catatan ?? T.t('judul_masuk_lain');
    case JenisTransaksi.keluarLain:
      return t.catatan ?? T.t('judul_keluar_lain');
  }
}

/// Tebak kategori dari nama pengeluaran (untuk default dropdown yang cerdas).
KategoriPengeluaran tebakKategori(String nama) {
  final n = nama.toLowerCase();
  const kamus = <KategoriPengeluaran, List<String>>{
    KategoriPengeluaran.pendidikan: [
      'buku', 'kuliah', 'spp', 'ukt', 'print', 'fotokopi', 'fotokopian',
      'alat tulis', 'atk', 'kursus', 'les', 'seminar', 'workshop', 'skripsi',
    ],
    KategoriPengeluaran.kesehatan: [
      'obat', 'dokter', 'klinik', 'puskesmas', 'apotek', 'vitamin',
      'rumah sakit', 'periksa', 'lab', 'tensi', 'massage', 'pijat',
    ],
    KategoriPengeluaran.tagihanRumah: [
      'listrik', 'token', 'pulsa', 'paket data', 'wifi', 'internet', 'pdam',
      'air', 'gas', 'lpg', 'kos', 'kontrakan', 'cicilan', 'iuran', 'asuransi',
      'bpjs', 'langganan', ' sewa',
    ],
    KategoriPengeluaran.transport: [
      'gojek', 'goride', 'gocar', 'grab', 'ojol', 'ojek', 'bensin', 'bbm',
      'pertalite', 'pertamax', 'kereta', 'krl', 'busway', 'transjakarta',
      'mrt', 'lrt', 'angkot', 'parkir', 'tol', 'taksi', 'maxim',
    ],
    KategoriPengeluaran.belanjaPokok: [
      'belanja', 'indomaret', 'alfamart', 'supermarket', 'sembako', 'beras',
      'minyak goreng', 'telur', 'sayur', 'buah', 'sabun', 'shampoo',
      'deterjen', 'pampers', 'gula', 'garam', 'kelontong', 'sabi',
    ],
    KategoriPengeluaran.hiburan: [
      'netflix', 'spotify', 'youtube', 'disney', 'vidio', 'game', 'steam',
      'diamond', 'top up', 'bioskop', 'cgv', 'xxi', 'cinepolis', 'tiket',
      'karaoke', 'konser', 'festival', 'museum', 'wisata', 'hibur',
    ],
    KategoriPengeluaran.makanMinum: [
      'makan', 'minum', 'esteh', 'es teh', 'teh', 'kopi', 'ngopi', 'nasi',
      'ayam', 'bakso', 'mie', 'mi ', 'soto', 'warung', 'cafe', 'kafe',
      'kantin', 'seblak', 'seblac', 'burger', 'pizza', 'snack', 'jajan',
      'susu', 'roti', 'sarapan', 'brunch', 'boba', 'dimsum', 'sate',
      'sosis', 'gorengan', 'cilok', 'batagor', 'siomay', 'rujak', 'juice',
      'jus', 'air mineral', 'es ', 'pedas', 'sambal', 'dimsum',
    ],
  };
  for (final e in kamus.entries) {
    for (final kata in e.value) {
      if (n.contains(kata)) return e.key;
    }
  }
  return KategoriPengeluaran.lainLain;
}
