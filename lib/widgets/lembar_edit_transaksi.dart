import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaksi.dart';
import '../providers/app_state.dart';
import '../utils/dialog.dart';
import '../utils/format.dart';
import '../utils/teks.dart';

/// Buka lembar "ubah / hapus transaksi" untuk satu baris buku kas
/// (dipanggil dari Riwayat dan daftar "Hari ini" di Home).
///
/// Aturan keamanan data:
/// - jumlah & tanggal boleh diubah untuk semua jenis (saldo dihitung
///   ulang otomatis dari seluruh buku kas);
/// - nama/catatan hanya untuk transaksi TANPA catatan terkait
///   (pengeluaran, pemasukan, uang lain, kantong) supaya tidak beda
///   cerita dengan data kiriman/utang yang ditautkannya;
/// - kategori hanya untuk pengeluaran;
/// - catatan penyetelan saldo (koreksi) tidak bisa diedit - hanya
///   dihapus, lalu saldo diatur ulang.
Future<void> bukaLembarTransaksi(BuildContext context, Transaksi t) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _LembarTransaksi(t: t),
  );
}

class _LembarTransaksi extends StatefulWidget {
  final Transaksi t;
  const _LembarTransaksi({required this.t});

  @override
  State<_LembarTransaksi> createState() => _LembarTransaksiState();
}

class _LembarTransaksiState extends State<_LembarTransaksi> {
  late final TextEditingController _jumlahCtl;
  late final TextEditingController _catatanCtl;
  late KategoriPengeluaran _kategori;
  late DateTime _tanggal;

  /// Tanggal asli transaksi - batas paling mundur saat mengedit
  /// (tanggal boleh dibenahi, tapi tidak boleh ditarik lebih tua
  /// dari aslinya supaya "mulai pantau" tabungan hemat tidak ikut
  /// mundur).
  late final DateTime _tanggalAwal;

  bool _menyimpan = false;

  Transaksi get t => widget.t;

  bool get _koreksi => t.jenis == JenisTransaksi.koreksi;

  /// Catatan boleh diedit kalau transaksinya tidak menautkan
  /// kiriman/utang lain (terkaitId) dan bukan penyetelan saldo.
  bool get _bolehCatatan => t.terkaitId == null && !_koreksi;

  bool get _bolehKategori => t.jenis == JenisTransaksi.pengeluaran;

  @override
  void initState() {
    super.initState();
    _jumlahCtl = TextEditingController(
      text: t.jumlah == 0 ? '' : ribuan(t.jumlah),
    );
    _catatanCtl = TextEditingController(text: t.catatan ?? '');
    _kategori = t.kategori ?? KategoriPengeluaran.lainLain;
    _tanggal = tanggalSaja(t.dibuatPada);
    _tanggalAwal = tanggalSaja(t.dibuatPada);
  }

  @override
  void dispose() {
    _jumlahCtl.dispose();
    _catatanCtl.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final app = context.read<AppState>();
    final jumlah = parseRupiah(_jumlahCtl.text);
    if (jumlah <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.t('snack_isi_nominal'))),
      );
      return;
    }

    setState(() => _menyimpan = true);
    final catatanBaru = _catatanCtl.text.trim();
    await app.perbaruiTransaksi(
      t,
      jumlah: jumlah,
      catatan: _bolehCatatan
          ? (catatanBaru.isEmpty ? null : catatanBaru)
          : null,
      hapusCatatan: _bolehCatatan && catatanBaru.isEmpty,
      kategori: _bolehKategori ? _kategori : null,
      // Tanggal hanya ditulis kalau benar-benar diganti; jam asli
      // transaksi dipertahankan (tidak di-reset ke tengah malam).
      dibuatPada: tanggalSaja(_tanggal) == tanggalSaja(t.dibuatPada)
          ? null
          : DateTime(
              _tanggal.year,
              _tanggal.month,
              _tanggal.day,
              t.dibuatPada.hour,
              t.dibuatPada.minute,
            ),
    );
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(T.t('trans_diedit'))),
    );
  }

  Future<void> _hapus() async {
    final app = context.read<AppState>();
    final ya = await konfirmasi(
      context,
      judul: T.t('hapus_trans_judul'),
      pesan: T.t('hapus_trans_pesan'),
      bahaya: true,
      teksYa: T.t('hapus'),
    );
    if (!ya || !mounted) return;
    // Kalau transaksi ini yang bikin lewat batas + ditutup tabungan,
    // tabungannya otomatis dikembalikan (info di snackbar).
    final kembali = await app.hapusTransaksi(t);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(kembali > 0
            ? T.f('trans_dihapus_tabungan', {'n': rp(kembali)})
            : T.t('trans_dihapus')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            T.t('edit_judul'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            '${labelJenis(t.jenis)} \u2022 ${tanggalPendek(t.dibuatPada)} '
                '\u2022 ${jamPendek(t.dibuatPada)}',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 14),

          if (_koreksi) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                T.t('edit_koreksi_info'),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: cs.onSecondaryContainer,
                ),
              ),
            ),
          ] else ...[
            TextField(
              controller: _jumlahCtl,
              keyboardType: TextInputType.number,
              inputFormatters: const [RibuanFormatter()],
              decoration: InputDecoration(
                labelText: T.t('edit_field_jumlah'),
                prefixText: 'Rp ',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            if (_bolehCatatan) ...[
              TextField(
                controller: _catatanCtl,
                decoration: InputDecoration(
                  labelText: T.t('edit_field_catatan'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                if (_bolehKategori) ...[
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<KategoriPengeluaran>(
                      key: ValueKey(_kategori),
                      initialValue: _kategori,
                      isExpanded: true,
                      items: KategoriPengeluaran.values
                          .map((k) => DropdownMenuItem(
                                value: k,
                                child: Text(labelKategori(k),
                                    style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _kategori = v!),
                      decoration: InputDecoration(
                        labelText: T.t('kategori'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      // Rentang edit: [paling mundur antara tanggal
                      // asli & 1 bulan lalu .. hari ini]. Transaksi
                      // adalah catatan kejadian yang sudah lewat -
                      // tidak boleh dipindah ke masa depan, dan tidak
                      // boleh ditarik lebih tua dari tanggal aslinya
                      // (pelindung tabungan hemat, lihat _tanggalAwal).
                      final kini = DateTime.now();
                      final sebulanLalu =
                          DateTime(kini.year, kini.month - 1, kini.day);
                      final p = await pilihTanggal(
                        context,
                        awal: _tanggal,
                        batasAwal: _tanggalAwal.isBefore(sebulanLalu)
                            ? _tanggalAwal
                            : sebulanLalu,
                        batasAkhir: kini,
                      );
                      if (p != null) setState(() => _tanggal = p);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: T.t('tanggal'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Text(tanggalPendek(_tanggal)),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_menyimpan || _koreksi) ? null : _simpan,
              icon: _menyimpan
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(T.t('simpan_perubahan')),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.error,
                side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
              ),
              onPressed: _menyimpan ? null : _hapus,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(T.t('hapus')),
            ),
          ),
        ],
      ),
    );
  }
}
