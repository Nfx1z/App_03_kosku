import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../utils/format.dart';
import '../utils/teks.dart';
import '../widgets/bagian.dart';

/// Batas tampilan riwayat pemakaian (sisanya diringkas satu baris).
const _batasTampilPemakaian = 30;

/// Layar Tabungan hemat (rollover sisa jatah harian).
///
/// - Hemat mengendap sepanjang BULAN berjalan (tanggal 1 sampai
///   kemarin), bukan cuma 7 hari terakhir.
/// - Sisa tabungan dari bulan-bulan sebelumnya DIBAWA terus
///   (tidak hangus saat ganti bulan) - jadi tabungan yang menumpuk
///   tetap bisa nutup pengeluaran tambahan minggu-minggu depan.
/// - Budget harian TIDAK ditambah tabungan - batas tetap polos.
/// - Tabungan hanya dipakai kalau user konfirmasi saat pengeluaran
///   lewat batas harian (dialog "pakai tabungan?" saat mencatat).
/// - Tidak ada angka tabungan di Home supaya layar utama bersih.
class TabunganScreen extends StatelessWidget {
  const TabunganScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final kini = DateTime.now();

    final saldo = app.tabunganSaldo;
    final bawaan = app.tabunganBawaan;
    final batas = app.batasAktif;
    final rincian = app.rincianBulanIni;
    final pemakaian = app.daftarPemakaianTabungan;
    final pemakaianTampil =
        pemakaian.take(_batasTampilPemakaian).toList();
    final sisaPemakaian = pemakaian.length - pemakaianTampil.length;

    return Scaffold(
      appBar: AppBar(title: Text(T.t('nav_tabungan'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          // ----- kartu saldo tabungan -----
          Card(
            color: cs.primaryContainer,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.savings_rounded,
                          size: 16, color: cs.onPrimaryContainer),
                      const SizedBox(width: 6),
                      Text(
                        T.t('tabungan_saldo_label'),
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                          color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rp(saldo),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    T.t('tabungan_info'),
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: cs.onPrimaryContainer.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ----- asal tabungan: bulan berjalan + bawaan bulan lalu -----
          judulSection(T.f('tabungan_asal', {
            'b': namaBulanTahun(kini.year, kini.month),
          })),
          if (batas <= 0)
            kartuKosong(T.t('tabungan_belum_aktif'),
                ikon: Icons.speed_rounded)
          else ...[
            if (bawaan > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_repeat_rounded,
                          size: 18, color: cs.onTertiaryContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          T.t('tabungan_bawaan'),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      Text(
                        '+${rp(bawaan)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: cs.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (rincian.isEmpty)
              kartuKosong(T.t('tabungan_belum_terpantau'),
                  ikon: Icons.calendar_month_rounded)
            else
              ...rincian.map(
                (r) {
                  final (tanggal, terpakai) = r;
                  final hemat = batas - terpakai;
                  final tersimpan = hemat > 0 ? hemat : 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 64,
                            child: Text(
                              tanggalSangatPendek(tanggal),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              T.f('tabungan_hari_jatah', {
                                'a': rp(batas),
                                'b': rp(terpakai),
                              }),
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                          if (tersimpan > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: cs.tertiaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                T.f('tabungan_hemat', {'n': rp(tersimpan)}),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onTertiaryContainer,
                                ),
                              ),
                            )
                          else
                            Text(
                              T.t('tabungan_habis'),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4),
              child: Text(
                T.f('tabungan_hemat_info', {
                  'n': '${app.hariHematBulanIni}',
                  'd': '${rincian.length}',
                }),
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
          ],

          // ----- riwayat pemakaian -----
          judulSection(T.t('tabungan_dipakai_judul')),
          if (pemakaian.isEmpty)
            kartuKosong(T.t('tabungan_dipakai_kosong'),
                ikon: Icons.verified_rounded)
          else ...[
            ...pemakaianTampil.map(
              (p) => ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4),
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: cs.secondaryContainer,
                  child: Icon(Icons.savings_rounded,
                      size: 18, color: cs.onSecondaryContainer),
                ),
                title: Text(
                  p.catatan == null || p.catatan!.isEmpty
                      ? T.t('tabungan_dipakai_sub')
                      : '${T.t('tabungan_dipakai_sub')} • ${p.catatan}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  tanggalPendek(p.waktu),
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.7)),
                ),
                trailing: Text(
                  '-${rp(p.jumlah)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.error,
                  ),
                ),
              ),
            ),
            if (sisaPemakaian > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 4),
                child: Text(
                  T.f('tabungan_dipakai_lainnya', {'n': '$sisaPemakaian'}),
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
