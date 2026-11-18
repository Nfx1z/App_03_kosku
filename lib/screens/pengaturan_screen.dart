import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/notifikasi_service.dart';
import '../services/sync_service.dart';
import '../utils/dialog.dart';
import '../utils/ekspor_csv.dart';
import '../utils/format.dart';
import '../utils/hitung.dart';
import '../utils/teks.dart';
import 'auth_screen.dart';

class PengaturanScreen extends StatefulWidget {
  const PengaturanScreen({super.key});

  @override
  State<PengaturanScreen> createState() => _PengaturanScreenState();
}

class _PengaturanScreenState extends State<PengaturanScreen> {
  final _batasCtl = TextEditingController();
  bool _sedangSinkron = false;

  static const _pilihanGrace = [3, 7, 14, 30];

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _batasCtl.text = app.batasHarian != null ? ribuan(app.batasHarian!) : '';
  }

  @override
  void dispose() {
    _batasCtl.dispose();
    super.dispose();
  }

  Future<void> _aturSaldo() async {
    final app = context.read<AppState>();
    final ctl = TextEditingController(
      text: app.saldoPegangan > 0 ? ribuan(app.saldoPegangan) : '',
    );
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(T.t('atur_saldo')),
        content: TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          inputFormatters: const [RibuanFormatter()],
          decoration: InputDecoration(
            labelText: T.t('atur_saldo_label'),
            prefixText: 'Rp ',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(T.t('batal'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(T.t('simpan'))),
        ],
      ),
    );
    if (ya != true) return;
    final nominal = parseRupiah(ctl.text);
    if (nominal < 0) return;
    await app.aturSaldoAwal(nominal);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(T.f('snack_saldo_atur', {'n': rp(nominal)}))),
    );
  }

  Future<void> _kirimUlangVerifikasi() async {
    final app = context.read<AppState>();
    final error = await app.kirimVerifikasiEmail();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? T.t('verif_terkirim'))),
    );
  }

  Future<void> _cekVerifikasi() async {
    final app = context.read<AppState>();
    final ok = await app.cekVerifikasiEmail();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? T.t('verif_sukses') : T.t('verif_belum')),
      ),
    );
  }

  Future<void> _keluarAkun() async {
    final app = context.read<AppState>();
    final ya = await konfirmasi(
      context,
      judul: T.t('keluar_konfirmasi_judul'),
      pesan: T.t('keluar_konfirmasi_pesan'),
      teksYa: T.t('keluar_akun'),
    );
    if (ya && mounted) await app.keluarAkun();
  }

  Future<void> _sinkronSekarang() async {
    setState(() => _sedangSinkron = true);
    final app = context.read<AppState>();
    await app.sinkronSekarang();
    if (!mounted) return;
    setState(() => _sedangSinkron = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(app.statusSinkron == StatusSinkron.sinkron
            ? T.t('snack_sinkron_ok')
            : T.t('snack_sinkron_gagal')),
      ),
    );
  }

  Future<void> _aktifkanAutoWipe(bool nilai) async {
    final app = context.read<AppState>();
    if (nilai) {
      final ya = await konfirmasi(
        context,
        judul: T.t('auto_wipe_label'),
        pesan: T.t('auto_wipe_warning'),
        bahaya: true,
        teksYa: T.t('aktifkan'),
      );
      if (!ya) return;
    }
    await app.simpanAutoWipe(nilai);
  }

  Future<void> _aktifkanNotifHarian(bool nilai) async {
    final app = context.read<AppState>();
    await app.simpanNotifHarian(nilai);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(T.t(nilai ? 'notif_aktif' : 'notif_mati')),
      ),
    );
  }

  /// Ubah jam pengingat (pagi & malam) lewat time picker, lalu
  /// jadwalkan ulang semua pengingat sesuai jam baru.
  Future<void> _simpanJamNotif({required String pagi, required String malam}) async {
    await context.read<AppState>().simpanJamNotif(pagi: pagi, malam: malam);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(T.t('notif_jam_tersimpan'))),
    );
  }

  /// Kirim notifikasi uji: satu langsung muncul + satu terjadwal 1
  /// menit lagi. Menguji dua jalur sekaligus (izin/channel + alarm
  /// terjadwal, jalur yang sama dengan pengingat harian) langsung
  /// dari HP, tanpa perlu nunggu besok.
  Future<void> _ujiNotifikasi() async {
    final ok = await NotifikasiService.instance.ujiNotifikasi();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(T.t(ok ? 'notif_uji_ok' : 'notif_uji_gagal')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(T.t('pengaturan_judul'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ---------- AKUN & SINKRONISASI ----------
          // Disembunyikan kalau cloud tidak aktif - end user tidak perlu
          // melihat catatan setup apa pun; aplikasi tetap jalan lokal.
          if (app.cloudSiap)
            Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(T.t('akun_judul'),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    T.t('akun_desc'),
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurface.withValues(alpha: 0.75)),
                  ),
                  const SizedBox(height: 12),

                  if (!app.masukAkunState)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AuthScreen()),
                        ),
                        icon: const Icon(Icons.login_rounded, size: 18),
                        label: Text(T.t('masuk_daftar')),
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Icon(
                          app.emailTerverifikasi
                              ? Icons.verified_rounded
                              : Icons.mark_email_unread_rounded,
                          size: 18,
                          color: app.emailTerverifikasi
                              ? cs.tertiary
                              : cs.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            app.emailAkun ?? '-',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton(
                          onPressed: _keluarAkun,
                          child: Text(T.t('keluar_akun')),
                        ),
                      ],
                    ),

                    // Email belum diverifikasi → banner + aksi langsung.
                    if (!app.emailTerverifikasi) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.tertiaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              T.t('verif_banner_judul'),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: cs.onTertiaryContainer,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              T.t('verif_banner_desc'),
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: cs.onTertiaryContainer,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.tonal(
                                    onPressed: _kirimUlangVerifikasi,
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      backgroundColor:
                                          cs.onTertiaryContainer,
                                      foregroundColor: cs.tertiaryContainer,
                                    ),
                                    child: Text(T.t('verif_kirim_ulang'),
                                        style: const TextStyle(fontSize: 12.5)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _cekVerifikasi,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      foregroundColor: cs.onTertiaryContainer,
                                      side: BorderSide(
                                          color: cs.onTertiaryContainer
                                              .withValues(alpha: 0.7)),
                                    ),
                                    child: Text(T.t('verif_ceklagi'),
                                        style: const TextStyle(fontSize: 12.5)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Divider(height: 20),
                    _barisStatusSync(context, app),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _sedangSinkron ? null : _sinkronSekarang,
                            icon: _sedangSinkron
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.sync_rounded, size: 18),
                            label: Text(_sedangSinkron
                                ? T.t('sedang_sinkron')
                                : T.t('sinkron_sekarang')),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    DropdownButtonFormField<int>(
                      key: ValueKey(app.graceHari),
                      initialValue: _pilihanGrace.contains(app.graceHari)
                          ? app.graceHari
                          : 7,
                      items: _pilihanGrace
                          .map((n) => DropdownMenuItem(
                                value: n,
                                child: Text(T.f('grace_n_hari', {'n': '$n'})),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) app.simpanGraceHari(v);
                      },
                      decoration: InputDecoration(
                        labelText: T.t('grace_label'),
                        helperText:
                            T.f('grace_sub', {'n': '${app.graceHari}'}),
                        helperMaxLines: 3,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: app.autoWipe,
                      onChanged: _aktifkanAutoWipe,
                      title: Text(T.t('auto_wipe_label'),
                          style: const TextStyle(fontSize: 14)),
                      subtitle: Text(T.t('auto_wipe_sub'),
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ---------- BAHASA ----------
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(T.t('bahasa_judul'),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    T.t('bahasa_sub'),
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurface.withValues(alpha: 0.75)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Text(T.t('bahasa_id')),
                          selected: T.bahasa == 'id',
                          onSelected: (_) => app.aturBahasa('id'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Text(T.t('bahasa_en')),
                          selected: T.bahasa == 'en',
                          onSelected: (_) => app.aturBahasa('en'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ---------- PENGINGAT ----------
          // Notifikasi sistem Android: kiriman semestinya datang, utang
          // menjelang jatuh tempo, dan ingatan catat pengeluaran.
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(T.t('notif_judul'),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    T.t('notif_desc'),
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurface.withValues(alpha: 0.75)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: app.notifHarian,
                    onChanged: _aktifkanNotifHarian,
                    title: Text(T.t('notif_harian'),
                        style: const TextStyle(fontSize: 14)),
                    subtitle: Text(T.t('notif_harian_sub'),
                        style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(height: 4),
                  // Jam pengingat bisa diubah sendiri (default 08.00 pagi
                  // & 20.00 malam) - dulu hardcode sekarang time picker.
                  _ListTileJam(
                    judul: T.t('notif_jam_pagi'),
                    sub: T.t('notif_jam_pagi_sub'),
                    nilai: app.jamNotifPagi,
                    onChanged: (v) => _simpanJamNotif(
                      pagi: v,
                      malam: app.jamNotifMalam,
                    ),
                  ),
                  _ListTileJam(
                    judul: T.t('notif_jam_malam'),
                    sub: T.t('notif_jam_malam_sub'),
                    nilai: app.jamNotifMalam,
                    onChanged: (v) => _simpanJamNotif(
                      pagi: app.jamNotifPagi,
                      malam: v,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _ujiNotifikasi,
                      icon: const Icon(Icons.notification_important_rounded,
                          size: 18),
                      label: Text(T.t('notif_uji_tombol'),
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    T.t('notif_uji_sub'),
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.65)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ---------- UANG ----------
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(T.t('uang_judul'),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    T.t('batas_desc'),
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurface.withValues(alpha: 0.75)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _batasCtl,
                          keyboardType: TextInputType.number,
                          inputFormatters: const [RibuanFormatter()],
                          decoration: InputDecoration(
                            labelText: T.t('batas_harian_label'),
                            prefixText: 'Rp ',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            helperText: T.t('kosongkan_oto'),
                            helperMaxLines: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: () async {
                          final teks = _batasCtl.text.trim();
                          await app.simpanBatasHarian(
                              teks.isEmpty ? null : parseRupiah(teks));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(T.t('snack_batas_simpan'))),
                          );
                        },
                        child: Text(T.t('simpan')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Pratinjau langsung: dengan batas yang sedang diketik,
                  // uang cukup sampai kiriman / akhir bulan? Pengeluaran
                  // hari ini yang masih di dalam batas tidak mengurangi
                  // proyeksi (lihat proyeksiBatas).
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _batasCtl,
                    builder: (context, nilai, _) {
                      final teks = nilai.text.trim();
                      final proyeksi = teks.isEmpty
                          ? null
                          : proyeksiBatas(
                              saldo: app.saldoPegangan,
                              batas: parseRupiah(teks),
                              sisaHari: app.sisaHari,
                              terpakaiHariIni: app.terpakaiHariIni,
                            );
                      if (proyeksi == null) return const SizedBox.shrink();
                      return Text(
                        proyeksi.aman
                            ? T.f('batas_proyeksi_aman', {
                                'd': tanggalSangatPendek(app.tanggalPatokan),
                                'n': rp(proyeksi.sisaAkhir),
                              })
                            : T.f('batas_proyeksi_kurang', {
                                'd': tanggalSangatPendek(DateTime.now()
                                    .add(Duration(days: proyeksi.hariBertahan))),
                                'k':
                                    '${proyeksi.sisaHari - proyeksi.hariBertahan}',
                                'n': rp(proyeksi.saranBatas),
                              }),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: proyeksi.aman
                              ? cs.onSurface.withValues(alpha: 0.75)
                              : cs.error,
                        ),
                      );
                    },
                  ),
                  const Divider(height: 24),
                  // Cadangan data: ekspor seluruh buku kas ke CSV yang
                  // bisa dibuka Excel / dikirim via WhatsApp / email.
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => eksporDanBagikanCsv(context, app),
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: Text(T.t('ekspor_csv')),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    T.t('ekspor_csv_sub'),
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurface.withValues(alpha: 0.65)),
                  ),
                  const Divider(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.account_balance_wallet_rounded),
                    title: Text(T.t('atur_saldo'),
                        style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      T.f('sekarang', {'n': rp(app.saldoPegangan)}),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.edit_rounded, size: 18),
                    onTap: _aturSaldo,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ---------- PINDAI (hanya kalau nonaktif) ----------
          // Tidak ada pengaturan teknis (model, key, dsb.) buat user:
          // kalau pindai aktif, tidak ada yang perlu diatur dan kartu ini
          // tidak muncul sama sekali. Kalau build ini tanpa pindai, cukup
          // satu penjelasan singkat kenapa fiturnya tidak ada.
          if (!app.punyaKunciGemini)
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(T.t('gemini_judul'),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      T.t('gemini_status_kosong'),
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.75)),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),

          // ---------- DATA ----------
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(T.t('data_judul'),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    T.t('data_desc'),
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurface.withValues(alpha: 0.75)),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.error,
                        side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                      ),
                      onPressed: () async {
                        final ya = await konfirmasi(
                          context,
                          judul: T.t('hapus_semua_judul'),
                          pesan: T.t('hapus_semua_pesan'),
                          bahaya: true,
                          teksYa: T.t('hapus_semua'),
                        );
                        if (ya && context.mounted) {
                          final cloudTuntas = await app.resetSemuaData();
                          if (!context.mounted) return;
                          _batasCtl.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(cloudTuntas
                                  ? T.t('snack_semua_hapus')
                                  : T.t('snack_semua_hapus_tunda')),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.delete_forever_rounded, size: 18),
                      label: Text(T.t('hapus_semua')),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(T.t('tentang_judul'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    T.t('tentang_desc'),
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: cs.onSurface.withValues(alpha: 0.75)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barisStatusSync(BuildContext context, AppState app) {
    final cs = Theme.of(context).colorScheme;
    IconData ikon;
    String teks;
    Color warna;

    switch (app.statusSinkron) {
      case StatusSinkron.sinkron:
        ikon = Icons.cloud_done_rounded;
        warna = cs.tertiary;
        teks = app.sinkronTerakhir == null
            ? T.t('belum_pernah_sinkron')
            : T.f('sinkron_terakhir', {
                't': jamPendek(app.sinkronTerakhir!),
              });
        break;
      case StatusSinkron.antri:
        ikon = Icons.cloud_upload_rounded;
        warna = cs.primary;
        teks = T.f('antrian_info', {'n': '${app.antrianSinkron}'});
        break;
      case StatusSinkron.offline:
        ikon = Icons.signal_wifi_off_rounded;
        warna = cs.onSurface.withValues(alpha: 0.75);
        teks = T.t('offline_info');
        break;
      case StatusSinkron.error:
        ikon = Icons.cloud_off_rounded;
        warna = cs.error;
        teks = T.t('sync_error');
        break;
      case StatusSinkron.lokalSaja:
        ikon = Icons.smartphone_rounded;
        warna = cs.onSurface.withValues(alpha: 0.75);
        teks = T.t('sync_lokal');
        break;
    }

    return Row(
      children: [
        Icon(ikon, size: 18, color: warna),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            teks,
            style: TextStyle(fontSize: 12.5, color: warna),
          ),
        ),
      ],
    );
  }
}

/// Baris pilihan jam pengingat: nilai "HH:MM" ditampilkan sebagai
/// chip "HH.MM"; tap membuka time picker dan hasilnya dikirim balik
/// lewat [onChanged].
class _ListTileJam extends StatelessWidget {
  final String judul;
  final String sub;
  final String nilai; // format "HH:MM"
  final ValueChanged<String> onChanged;
  const _ListTileJam({
    required this.judul,
    required this.sub,
    required this.nilai,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bagian = nilai.split(':');
    final awal = TimeOfDay(
      hour: int.tryParse(bagian.first) ?? 8,
      minute: bagian.length == 2 ? (int.tryParse(bagian.last) ?? 0) : 0,
    );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(judul, style: const TextStyle(fontSize: 14)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
      trailing: OutlinedButton(
        onPressed: () async {
          final p = await showTimePicker(context: context, initialTime: awal);
          if (p == null) return;
          final j = p.hour.toString().padLeft(2, '0');
          final m = p.minute.toString().padLeft(2, '0');
          onChanged('$j:$m');
        },
        child: Text(
          nilai.replaceFirst(':', '.'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
