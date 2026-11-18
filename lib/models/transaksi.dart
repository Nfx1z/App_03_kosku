/// Kategori pengeluaran - dipakai sebagai enum di semua form (dropdown).
enum KategoriPengeluaran {
  makanMinum('makan_minum'),
  transport('transport'),
  belanjaPokok('belanja_pokok'),
  hiburan('hiburan'),
  kesehatan('kesehatan'),
  tagihanRumah('tagihan_rumah'),
  pendidikan('pendidikan'),
  lainLain('lain_lain');

  final String nilai;
  const KategoriPengeluaran(this.nilai);

  /// Label dua bahasa: lihat [labelKategori] di utils/format.dart.
  static KategoriPengeluaran dariNilai(String v) =>
      values.firstWhere((k) => k.nilai == v, orElse: () => KategoriPengeluaran.lainLain);
}

/// Jenis baris buku kas (ledger).
/// Efek terhadap saldo pegangan dan kantong darurat dihitung dari jenis ini.
enum JenisTransaksi {
  pengeluaran('pengeluaran'),
  pemasukan('pemasukan'),
  isiDarurat('isi_darurat'),
  pakaiDarurat('pakai_darurat'),
  tarikDarurat('tarik_darurat'),
  utangMasuk('utang_masuk'),
  utangBayar('utang_bayar'),
  piutangKeluar('piutang_keluar'),
  piutangTerima('piutang_terima'),
  koreksi('koreksi'),

  /// Uang masuk yang bukan kiriman (hadiah, jualan barang, cashback).
  masukLain('masuk_lain'),

  /// Uang keluar yang bukan pengeluaran (setor tabungan, kas ke keluarga).
  keluarLain('keluar_lain');

  final String nilai;
  const JenisTransaksi(this.nilai);

  static JenisTransaksi dariNilai(String v) =>
      values.firstWhere((j) => j.nilai == v);
}

/// Satu baris buku kas.
/// [jumlah] selalu bulat positif, KECUALI untuk [JenisTransaksi.koreksi]
/// (selisih penyetelan saldo, boleh negatif).
class Transaksi {
  final int? id;
  final JenisTransaksi jenis;
  final int jumlah;
  final KategoriPengeluaran? kategori;
  final String? catatan;
  final String sumber; // 'manual' | 'scan_struk' | 'scan_tf' | 'nl_input'
  final int? terkaitId; // id kiriman/utang terkait, jika ada
  final DateTime dibuatPada;

  // ---- kolom sinkronisasi cloud (fase 2) ----
  /// ID dokumen di Firestore (UUID). Dibuat lokal saat insert pertama.
  final String? cloudId;
  /// Tombstone: true = sudah dihapus, disimpan sementara untuk sync.
  final bool dihapus;
  /// Epoch ms perubahan terakhir - dasar last-write-wins antar perangkat.
  final int diubahPada;

  Transaksi({
    this.id,
    required this.jenis,
    required this.jumlah,
    this.kategori,
    this.catatan,
    this.sumber = 'manual',
    this.terkaitId,
    DateTime? dibuatPada,
    this.cloudId,
    this.dihapus = false,
    this.diubahPada = 0,
  }) : dibuatPada = dibuatPada ?? DateTime.now();

  /// Perubahan saldo pegangan akibat transaksi ini (bisa 0 / negatif).
  int get efekPegangan => switch (jenis) {
        JenisTransaksi.pengeluaran => -jumlah,
        JenisTransaksi.pemasukan => jumlah,
        JenisTransaksi.isiDarurat => -jumlah,
        JenisTransaksi.tarikDarurat => jumlah,
        JenisTransaksi.utangMasuk => jumlah,
        JenisTransaksi.utangBayar => -jumlah,
        JenisTransaksi.piutangKeluar => -jumlah,
        JenisTransaksi.piutangTerima => jumlah,
        JenisTransaksi.pakaiDarurat => 0,
        JenisTransaksi.koreksi => jumlah,
        JenisTransaksi.masukLain => jumlah,
        JenisTransaksi.keluarLain => -jumlah,
      };

  /// Perubahan saldo kantong darurat akibat transaksi ini.
  int get efekKantong => switch (jenis) {
        JenisTransaksi.isiDarurat => jumlah,
        JenisTransaksi.pakaiDarurat => -jumlah,
        JenisTransaksi.tarikDarurat => -jumlah,
        _ => 0,
      };

  /// Ikon ringkas untuk tampilan riwayat.
  int get tandaTampil =>
      efekPegangan != 0 ? efekPegangan : efekKantong;

  Map<String, Object?> keMap() => {
        'id': id,
        'jenis': jenis.nilai,
        'jumlah': jumlah,
        'kategori': kategori?.nilai,
        'catatan': catatan,
        'sumber': sumber,
        'terkait_id': terkaitId,
        'dibuat_pada': dibuatPada.toIso8601String(),
        'cloud_id': cloudId,
        'dihapus': dihapus ? 1 : 0,
        'diubah_pada': diubahPada,
      };

  factory Transaksi.dariMap(Map<String, Object?> m) => Transaksi(
        id: m['id'] as int?,
        jenis: JenisTransaksi.dariNilai(m['jenis'] as String),
        jumlah: m['jumlah'] as int,
        kategori: m['kategori'] == null
            ? null
            : KategoriPengeluaran.dariNilai(m['kategori'] as String),
        catatan: m['catatan'] as String?,
        sumber: (m['sumber'] as String?) ?? 'manual',
        terkaitId: m['terkait_id'] as int?,
        dibuatPada: DateTime.parse(m['dibuat_pada'] as String),
        cloudId: m['cloud_id'] as String?,
        dihapus: (m['dihapus'] as int? ?? 0) == 1,
        diubahPada: (m['diubah_pada'] as int?) ?? 0,
      );

  /// Salinan dengan field sync diatur (dipakai lapisan DB).
  Transaksi salinan({
    int? id,
    String? cloudId,
    bool? dihapus,
    int? diubahPada,
  }) =>
      Transaksi(
        id: id ?? this.id,
        jenis: jenis,
        jumlah: jumlah,
        kategori: kategori,
        catatan: catatan,
        sumber: sumber,
        terkaitId: terkaitId,
        dibuatPada: dibuatPada,
        cloudId: cloudId ?? this.cloudId,
        dihapus: dihapus ?? this.dihapus,
        diubahPada: diubahPada ?? this.diubahPada,
      );
}
