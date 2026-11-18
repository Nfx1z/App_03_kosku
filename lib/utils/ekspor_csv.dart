import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/app_state.dart';
import '../utils/format.dart';
import '../utils/teks.dart';

/// Ekspor seluruh buku kas ke file CSV, lalu buka lembar bagikan
/// Android (bisa disimpan, dikirim ke WhatsApp / email sebagai
/// cadangan). Pemisah titik-koma + BOM UTF-8 supaya langsung rapi
/// dibuka di Excel Indonesia.
///
/// Return true kalau file berhasil dibuat & lembar bagikan terbuka.
Future<bool> eksporDanBagikanCsv(
  BuildContext context,
  AppState app,
) async {
  final semua = await app.ambilSemuaTransaksi();
  if (semua.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.t('ekspor_csv_kosong'))),
      );
    }
    return false;
  }

  try {
    // Kolom di-escape: kutip ganda digandakan, selalu dibungkus "...",
    // supaya catatan yang mengandung titik-koma tidak merusak kolom.
    String sel(String? s) => '"${(s ?? '').replaceAll('"', '""')}"';

    final buf = StringBuffer()
      ..writeln([
        T.t('csv_h_tanggal'),
        T.t('csv_h_jam'),
        T.t('csv_h_jenis'),
        T.t('csv_h_kategori'),
        T.t('csv_h_nama'),
        T.t('csv_h_jumlah'),
        T.t('csv_h_sumber'),
      ].join(';'));

    // Semua transaksi, terlama dulu (kronologis enak dibaca ulang).
    for (final t in semua.reversed) {
      buf.writeln([
        kunciHari(t.dibuatPada), // yyyy-MM-dd
        jamPendek(t.dibuatPada),
        sel(labelJenis(t.jenis)),
        sel(t.kategori == null ? '' : labelKategori(t.kategori!)),
        sel(t.catatan),
        // Koreksi boleh negatif - biarkan apa adanya.
        '${t.jumlah}',
        sel(t.sumber),
      ].join(';'));
    }

    final dir = await getTemporaryDirectory();
    final kini = DateTime.now();
    final nama = 'kosku-buku-kas-'
        '${kunciHari(kini).replaceAll('-', '')}.csv';
    final f = File('${dir.path}/$nama');
    // BOM UTF-8 (\ufeff) = Excel langsung mengenali karakter non-ASCII.
    await f.writeAsString('\ufeff${buf.toString()}', encoding: utf8);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(f.path)]),
    );
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.t('ekspor_csv_gagal'))),
      );
    }
    return false;
  }
}
