import 'package:flutter/material.dart';

import '../providers/app_state.dart';
import 'format.dart';
import 'teks.dart';

/// Dialog konfirmasi generik.
Future<bool> konfirmasi(
  BuildContext context, {
  required String judul,
  required String pesan,
  String? teksYa,
  String? teksBatal,
  bool bahaya = false,
}) async {
  final hasil = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(judul),
      content: Text(pesan),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(teksBatal ?? T.t('batal')),
        ),
        FilledButton(
          style: bahaya
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                )
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(teksYa ?? T.t('ya')),
        ),
      ],
    ),
  );
  return hasil ?? false;
}

/// Pemilih tanggal konsisten (rentang wajar).
///
/// [batasAwal] / [batasAkhir] mempersempit rentang pilihan (dipakai
/// layar scan & ubah transaksi supaya tanggal catatan tidak bisa
/// "ngalor ngidul" ke tahun lalu / masa depan). Tanggal awal yang
/// kebetulan di luar rentang otomatis digeser ke batas terdekat -
/// showDatePicker menuntut initialDate di dalam [firstDate, lastDate].
Future<DateTime?> pilihTanggal(
  BuildContext context, {
  DateTime? awal,
  DateTime? batasAwal,
  DateTime? batasAkhir,
}) {
  final kini = DateTime.now();
  final first = batasAwal ?? DateTime(2020);
  final last = batasAkhir ?? kini.add(const Duration(days: 365 * 3));
  var initial = awal ?? kini;
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: last,
  );
}

/// Hasil gerbang lewat batas: boleh lanjut atau tidak, plus berapa
/// tabungan hemat yang dipakai menutup kelebihan jatah.
class HasilLewatBatas {
  /// False = user batal, transaksi TAK boleh disimpan.
  final bool lanjut;

  /// Berapa rupiah tabungan hemat yang dipakai menutup kelebihan
  /// (0 hanya di jalur tanpa tabungan - begitu ada tabungan,
  /// penutupan tabungan adalah satu-satunya aksi).
  final int pakaiTabungan;
  const HasilLewatBatas(this.lanjut, {this.pakaiTabungan = 0});
}

/// Gerbang sebelum mencatat pengeluaran yang bikin hari ini lewat batas
/// harian (batas polos, tanpa tambahan rollover).
///
/// - [tanggal] = tanggal transaksi yang AKAN dicatat. Untuk transaksi
///   bertanggal BUKAN hari ini (mis. hasil parse "kemarin" atau tanggal
///   struk lama), gerbang ini dilewati - pengeluaran hari lain tidak
///   dihitung ke jatah hari ini, jadi peringatannya salah konteks.
/// - Yang ditutup tabungan hanya kelebihan yang BELUM tertutup
///   pemakaian hari ini (pengeluaran lewat batas kedua tidak menutup
///   kelebihan yang sudah ditutup pengeluaran pertama).
/// - Kalau ada saldo tabungan hemat: tabungan DIPAKAI untuk menutup
///   kelebihan (penuh kalau cukup, seluruh saldo tabungan kalau
///   kurang) - satu-satunya aksi, sesuai prinsip app: kelebihan jatah
///   wajib ditutup tabungan dulu. Konfirmasinya cuma Batal vs Lanjut,
///   tidak ada lagi opsi "tetap catat tanpa tabungan".
/// - Kalau tabungan tidak ada sama sekali: konfirmasi "tetap simpan?"
///   seperti biasa (dicatat + peringatan lewat batas).
Future<HasilLewatBatas> gerbangLewatBatas(
  BuildContext context,
  AppState app,
  int jumlahBaru, {
  DateTime? tanggal,
}) async {
  // Transaksi untuk hari lain tidak menambah pengeluaran hari ini.
  final untukHariIni = tanggal == null ||
      tanggalSaja(tanggal) == tanggalSaja(DateTime.now());
  if (!untukHariIni) return const HasilLewatBatas(true);
  if (!app.cekLewatBatas(jumlahBaru)) return const HasilLewatBatas(true);

  // Kelebihan yang BELUM tertutup: total kelebihan hari ini dikurangi
  // pemakaian tabungan yang sudah dicatat hari ini. Tanpa ini, dua
  // pengeluaran lewat batas yang dicatat berurutan menutup kelebihan
  // yang sama DUA KALI (pengeluaran kedua "menutup" lagi bagian yang
  // sudah ditutup pengeluaran pertama).
  final kelebihanTotal = (app.terpakaiHariIni + jumlahBaru) - app.batasAktif;
  final kelebihan = kelebihanTotal - app.ditutupTabunganHariIni;
  if (kelebihan <= 0) return const HasilLewatBatas(true);
  final saldoTabungan = app.tabunganSaldo;

  // Ada tabungan → dipakai menutup kelebihan (penuh atau sebagian).
  // Satu aksi saja: catat & tutup pakai tabungan (batal = tidak catat).
  if (saldoTabungan > 0) {
    final cukup = saldoTabungan >= kelebihan;
    final dipakai = cukup ? kelebihan : saldoTabungan;
    // Imbas ke daya tahan uang kalau tetap dicatat (nominal ini masuk
    // pengeluaran hari ini → memakan jatah hari ini di proyeksi).
    final imbas = app.teksImbas(jumlahBaru, masukBudgetHariIni: true);
    final ya = await konfirmasi(
      context,
      judul: T.t('tabungan_pakai_judul'),
      pesan: (cukup
              ? T.f('tabungan_pakai_pesan', {
                  'a': rp(kelebihan),
                  'b': rp(saldoTabungan),
                })
              : T.f('tabungan_pakai_sebagian_pesan', {
                  'a': rp(kelebihan),
                  'b': rp(saldoTabungan),
                })) +
          (imbas.isEmpty ? '' : '\n\n$imbas'),
      teksYa: T.t('pakai_tabungan'),
    );
    if (!ya) return const HasilLewatBatas(false);
    return HasilLewatBatas(true, pakaiTabungan: dipakai);
  }

  // Tidak ada tabungan → konfirmasi "tetap simpan?" seperti biasa,
  // plus imbas ke daya tahan uang (nominal ini masuk pengeluaran
  // hari ini → memakan jatah hari ini di proyeksi).
  final terpakaiSetelah = app.terpakaiHariIni + jumlahBaru;
  final imbas = app.teksImbas(jumlahBaru, masukBudgetHariIni: true);
  final ya = await konfirmasi(
    context,
    judul: T.t('lewat_batas_judul'),
    pesan: T.f('lewat_batas_pesan', {
      'a': rp(terpakaiSetelah),
      'b': rp(app.batasAktif),
    }) + (imbas.isEmpty ? '' : '\n\n$imbas'),
    teksYa: T.t('tetap_simpan'),
  );
  return HasilLewatBatas(ya);
}

/// Gerbang terpusat sebelum mencatat transaksi yang mengurangi saldo
/// (pengeluaran, uang keluar lain, beli target, bayar utang, ngutangin).
///
/// Prinsip "saldo tidak boleh minus":
/// - [HasilJagaSaldo.kurang] → DITOLAK, tampil snackbar beserta saran
///   (catat uang masuk dulu / kecilin nominal). Tidak ada jalur
///   "tetap simpan" untuk saldo minus.
/// - [HasilJagaSaldo.kritis] → pembelian besar yang menghabiskan hampir
///   semua saldo: konfirmasi dulu ("tetap lanjut?") sesuai tujuan app
///   yaitu belanja yang aman.
///
/// Return true kalau boleh lanjut menyimpan.
Future<bool> gerbangJagaSaldo(
  BuildContext context,
  AppState app,
  int jumlah,
) async {
  switch (app.jagaSaldo(jumlah)) {
    case HasilJagaSaldo.kurang:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(T.f('snack_saldo_kurang', {
            'n': rp(app.saldoPegangan),
          })),
        ),
      );
      return false;
    case HasilJagaSaldo.kritis:
      // Imbas: setelah catat ini, pegangan jadi berapa dan dengan batas
      // yang diatur uang bertahan sampai kapan (tambahan info konkret
      // di atas peringatan lama yang berbasis rata-rata belanja).
      final imbas = app.teksImbas(jumlah);
      return konfirmasi(
        context,
        judul: T.t('habis_saldo_judul'),
        pesan: T.f('habis_saldo_pesan', {
              'a': rp(app.saldoPegangan - jumlah),
              'b': rp(app.rataPengeluaran7Hari),
              'd': '${app.sisaHari}',
            }) +
            (imbas.isEmpty ? '' : '\n\n$imbas'),
        teksYa: T.t('tetap_lanjut'),
      );
    case HasilJagaSaldo.aman:
      return true;
  }
}
