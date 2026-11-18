import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../utils/format.dart';
import '../utils/teks.dart';

/// Kartu budget harian: terpakai vs batas harian POLOS (tanpa tambahan
/// rollover - sesuai keinginan user, budget harian tetap seperti
/// sebelumnya). Sisa jatah yang tidak terpakai mengendap jadi tabungan
/// hemat (menu Tabungan), dan kelebihan hari ini bisa ditutup tabungan
/// lewat konfirmasi saat mencatat - kalau sudah ditutup, kartu tidak
/// merah.
class KartuBudget extends StatelessWidget {
  const KartuBudget({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    final jatah = app.batasAktif;
    final terpakai = app.terpakaiHariIni;
    final kelebihan = app.kelebihanHariIni;
    final ditutup = app.ditutupTabunganHariIni;
    final sisa = jatah - terpakai;

    // Merah hanya kalau lewat batas DAN kelebihannya belum tertutup
    // tabungan. Kalau sudah ditutup: hari ini dianggap aman.
    final lewatBelumTertutup = app.lewatBatasBelumTertutup;
    final progres = jatah <= 0 ? 0.0 : (terpakai / jatah).clamp(0.0, 1.0);

    String sumberInfo;
    if (app.batasHarian != null) {
      sumberInfo = T.t('budget_manual_info');
    } else if (app.kirimanAktif != null && !app.kirimanTelat) {
      sumberInfo = T.f('budget_oto_kiriman', {
        'd': tanggalSangatPendek(app.kirimanAktif!.tanggalDatang),
      });
    } else if (app.kirimanTelat) {
      // Kiriman lewat tanggal belum dikonfirmasi: patokan sementara
      // akhir bulan (bukan "sisa 1 hari" yang buka batas jadi semua
      // saldo) + ajakan konfirmasi.
      sumberInfo = T.t('budget_oto_telat');
    } else {
      sumberInfo = T.t('budget_oto_bulan');
    }

    // Proyeksi batas manual (hanya kalau user mengatur sendiri).
    // Saat lewat batas BELUM TERTUTUP: baris ini DILEWATI - saran
    // budget cukup satu saja (kotak "jatah baru" di bawah), tidak
    // menumpuk dua saran dengan dua rumus.
    final proyeksi = app.proyeksiBatasAktif;
    final kini = DateTime.now();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  T.t('budget_harian'),
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withValues(alpha: 0.75),
                  ),
                ),
                Text(
                  T.f('sisa_hari_info', {'n': '${app.sisaHari}'}),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${rp(terpakai)} / ${rp(jatah)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: lewatBelumTertutup ? cs.error : cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              lewatBelumTertutup
                  ? T.f('lewat_batas_info', {'n': rp(kelebihan - ditutup)})
                  : T.f('sisa_hari_ini', {'n': rp(sisa)}),
              style: TextStyle(
                fontSize: 12,
                color:
                    lewatBelumTertutup ? cs.error : cs.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progres,
                minHeight: 8,
                color: lewatBelumTertutup ? cs.error : cs.primary,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              sumberInfo,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.75),
              ),
            ),
            // Proyeksi batas manual (hanya kalau user mengatur sendiri
            // dan TIDAK sedang lewat batas - saat lewat batas, satu-
            // satunya saran ada di kotak "jatah baru" di bawah).
            if (proyeksi != null && !lewatBelumTertutup) ...[
              const SizedBox(height: 6),
              Text(
                proyeksi.aman
                    ? T.f('batas_proyeksi_aman', {
                        'd': tanggalSangatPendek(app.tanggalPatokan),
                        'n': rp(proyeksi.sisaAkhir),
                      })
                    : T.f('batas_proyeksi_kurang', {
                        'd': tanggalSangatPendek(
                            kini.add(Duration(days: proyeksi.hariBertahan))),
                        'k': '${proyeksi.sisaHari - proyeksi.hariBertahan}',
                        'n': rp(proyeksi.saranBatas),
                      }),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: proyeksi.aman
                      ? cs.onSurface.withValues(alpha: 0.75)
                      : cs.error,
                ),
              ),
            ],
            // Kelebihan jatah hari ini yang ditutup tabungan hemat:
            // bukan kondisi buruk, jadi pakai warna positif (bukan merah).
            if (ditutup > 0) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.savings_rounded,
                        size: 16, color: cs.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        T.f('budget_ditutup', {'n': rp(ditutup)}),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              T.t('budget_abaikan_lain'),
              style: TextStyle(
                fontSize: 10.5,
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
            ),
            if (lewatBelumTertutup) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  // SATU-SATUNYA saran budget saat lewat batas. Angkanya
                  // = sisa saldo ÷ sisa hari SETELAH hari ini (jatah
                  // hari ini sudah abis) - konsisten dengan saran batas
                  // di proyeksiBatas (hitung.dart).
                  T.f('budget_recal', {
                    'd': tanggalSangatPendek(app.tanggalPatokan),
                    'n': rp(app.budgetBaruSetelahLewat),
                  }),
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onErrorContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
