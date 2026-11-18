import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaksi.dart';
import '../providers/app_state.dart';
import '../services/nl_input_service.dart';
import '../services/suara_service.dart';
import '../utils/dialog.dart';
import '../utils/format.dart';
import '../utils/parser_lokal.dart';
import '../utils/teks.dart';

/// Input cepat pengeluaran harian langsung di Home.
/// Baris pertama: input bebas / suara ("ngopi 15rb") → form terisi otomatis.
/// Baris berikut: nama + harga + kategori dropdown, tanggal otomatis.
class KartuInputCepat extends StatefulWidget {
  const KartuInputCepat({super.key});

  @override
  State<KartuInputCepat> createState() => _KartuInputCepatState();
}

class _KartuInputCepatState extends State<KartuInputCepat> {
  final _namaCtl = TextEditingController();
  final _hargaCtl = TextEditingController();
  final _nlCtl = TextEditingController();
  final _suara = SuaraService.instance;
  late final AppState _app;

  late KategoriPengeluaran _kategori = KategoriPengeluaran.lainLain;
  bool _kategoriManual = false;
  bool _menyimpan = false;
  bool _memparsing = false;
  int _offsetHari = 0;

  // ----- suara: mode tahan-untuk-bicara (ala voice note WhatsApp) -----
  // Jari menekan mic = merekam; dilepas = otomatis diparse ke form;
  // digeser ke kiri / terlalu cepat / interupsi sistem = dibuang.
  bool _menahanSuara = false; // jari sedang menekan & merekam
  bool _menyiapkanMic = false; // engine mic pertama kali disiapkan
  bool _arahBatal = false; // jari digeser kiri -> lepas = buang
  int _detikRekam = 0;
  double _levelSuara = 0; // 0..1, animasi bar suara
  String _teksHidup = ''; // transkrip parsial saat merekam
  String _teksSebelumRekam = ''; // isi kolom input sebelum merekam
  Timer? _timerRekam;
  DateTime _waktuTekan = DateTime.now();
  Offset _posisiTekan = Offset.zero;
  int _sesiRekam = 0; // token anti-race antar sesi tekan

  // Pratinjau nominal langsung saat mengetik (parser lokal, offline,
  // instan): "ngopi 15rb" → chip "Rp 15.000" muncul tanpa tekan apa-apa.
  int? _pratinjauNominal;
  bool _pratinjauKemarin = false;

  @override
  void initState() {
    super.initState();
    _app = context.read<AppState>();
    _nlCtl.addListener(_perbaruiPratinjau);
    // Teks yang di-share dari app lain (cold start maupun saat app jalan)
    // langsung masuk ke sini.
    _app.addListener(_saatAppBerubah);
    WidgetsBinding.instance.addPostFrameCallback((_) => _cekBagikan());
  }

  /// AppState memberi tahu (mis. ada teks baru di-share) → cek & isi.
  void _saatAppBerubah() {
    if (_app.teksBagikan != null) _cekBagikan();
  }

  Future<void> _cekBagikan() async {
    if (!mounted) return;
    final teks = context.read<AppState>().ambilTeksBagikan();
    if (teks == null || !mounted) return;
    _nlCtl.text = teks;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(T.t('bagikan_terisi'))),
    );
    await _parseNl(teks);
  }

  @override
  void dispose() {
    _app.removeListener(_saatAppBerubah);
    _nlCtl.removeListener(_perbaruiPratinjau);
    _timerRekam?.cancel();
    _namaCtl.dispose();
    _hargaCtl.dispose();
    _nlCtl.dispose();
    _suara.berhenti();
    super.dispose();
  }

  void _perbaruiPratinjau() {
    final l = parseTeksLokal(_nlCtl.text);
    if (!mounted) return;
    final nominal = (l.jumlah != null && l.jumlah! > 0) ? l.jumlah : null;
    final kemarin = l.offsetHari != 0;
    // Skip rebuild kalau pratinjau tidak berubah (mis. ngetik nama saja).
    if (nominal == _pratinjauNominal && kemarin == _pratinjauKemarin) return;
    setState(() {
      _pratinjauNominal = nominal;
      _pratinjauKemarin = kemarin;
    });
  }

  // ---------- input bebas (NL) ----------

  Future<void> _parseNl(String teks) async {
    if (teks.trim().isEmpty || _memparsing) return;
    final app = context.read<AppState>();
    setState(() => _memparsing = true);
    final hasil = await parseInput(teks, pool: app.poolGemini);
    if (!mounted) return;
    setState(() => _memparsing = false);

    final nama = hasil.nama;
    final jumlah = hasil.jumlah;
    if (nama == null && jumlah == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.t('nl_gagal'))),
      );
      return;
    }

    if (nama != null && nama.isNotEmpty) _namaCtl.text = nama;
    if (jumlah != null && jumlah > 0) _hargaCtl.text = ribuan(jumlah);
    setState(() {
      if (hasil.kategori != null) {
        _kategori = hasil.kategori!;
        _kategoriManual = true;
      } else if (nama != null && !_kategoriManual) {
        _kategori = tebakKategori(nama);
      }
      // Offset tanggal ikut setState supaya chip "kemarin" muncul.
      _offsetHari = hasil.offsetHari;
    });
    _nlCtl.clear();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(T.t('nl_isi')),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ---------- uang masuk / keluar lain pindah ke menu (pojok kanan) ----------
  // Menu "Pemasukan lainnya" / "Pengeluaran lainnya" membuka
  // DialogUangLain (widgets/dialog_uang_lain.dart).

  // ---------- suara: tahan-untuk-bicara (ala VN WhatsApp) ----------

  /// Jari menyentuh tombol mic: langsung mulai merekam (tanpa jeda
  /// long-press). Snapshot teks lama dipulihkan kalau rekaman dibuang.
  void _saatTekan(PointerDownEvent e) {
    // Dua jari sekaligus: abaikan sentuhan kedua, jangan restart sesi.
    if (_menahanSuara) return;
    _sesiRekam++;
    _waktuTekan = DateTime.now();
    _posisiTekan = e.position;
    _teksSebelumRekam = _nlCtl.text;
    _teksHidup = '';
    _detikRekam = 0;
    _arahBatal = false;
    _levelSuara = 0;
    setState(() {
      _menahanSuara = true;
      _menyiapkanMic = true;
    });
    _mulaiRekam();
  }

  Future<void> _mulaiRekam() async {
    final sesi = _sesiRekam;
    final ok = await _suara.siapkan();
    // Jari sudah dilepas / digeser batal sebelum engine siap: batal diam.
    if (sesi != _sesiRekam || !_menahanSuara || !mounted) return;
    if (!ok) {
      _akhirRekam(reset: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(T.t('nl_mik_gagal'))),
        );
      }
      return;
    }
    setState(() => _menyiapkanMic = false);
    _timerRekam = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _menahanSuara) setState(() => _detikRekam++);
    });
    await _suara.dengar(
      saatHasil: (teks, final_) {
        if (!mounted || !_menahanSuara) return;
        setState(() => _teksHidup = teks);
      },
      saatLevel: (level) {
        if (!mounted || !_menahanSuara) return;
        setState(() => _levelSuara = level);
      },
      // Engine berhenti sendiri (cap 30 detik): anggap selesai ->
      // langsung proses walau jari masih menahan, seperti dilepas.
      saatSelesai: () {
        if (mounted && _menahanSuara) _finalisasiRekam();
      },
    );
  }

  /// Jari bergeser: geser cukup jauh ke KIRI = niat batal (seperti
  /// "slide to cancel" WhatsApp); kembali ke kanan = lanjut merekam.
  void _saatGerak(PointerMoveEvent e) {
    if (!_menahanSuara) return;
    final batal = (e.position.dx - _posisiTekan.dx) < -72;
    if (batal != _arahBatal) setState(() => _arahBatal = batal);
  }

  void _saatLepas(PointerUpEvent e) {
    if (!_menahanSuara) return; // sudah difinalisasi engine
    _finalisasiRekam();
  }

  /// Interupsi sistem (telepon masuk, dsb.): buang rekaman.
  void _saatDibatalkan(PointerCancelEvent e) {
    if (!_menahanSuara) return;
    _arahBatal = true;
    _finalisasiRekam();
  }

  /// Bersihkan state visual + timer tanpa memproses hasil.
  void _akhirRekam({bool reset = false}) {
    _timerRekam?.cancel();
    _timerRekam = null;
    _sesiRekam++; // batalkan lanjutan async yang masih menggantung
    if (!mounted) return;
    setState(() {
      _menahanSuara = false;
      _menyiapkanMic = false;
      _arahBatal = false;
      _levelSuara = 0;
      if (reset) _teksHidup = '';
    });
  }

  /// Jari dilepas (atau engine berhenti sendiri di cap 30 detik):
  /// digeser-batal / terlalu cepat = buang; selain itu OTOMATIS diparse
  /// ke form tanpa tekan tombol apa pun - persis voice note: lepas = jadi.
  Future<void> _finalisasiRekam() async {
    final digeserBatal = _arahBatal;
    final terlaluCepat = DateTime.now().difference(_waktuTekan) <
        const Duration(milliseconds: 400);
    _akhirRekam();

    if (digeserBatal) {
      await _suara.batal();
      _nlCtl.text = _teksSebelumRekam;
      return;
    }
    if (terlaluCepat) {
      // Baru disentuh sekejap: jangan rekam sampah, kasih petunjuk cara.
      await _suara.batal();
      _nlCtl.text = _teksSebelumRekam;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(T.t('nl_tahan_mic'))),
        );
      }
      return;
    }
    final teks = await _suara.berhenti();
    if (!mounted) return;
    if (teks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.t('nl_suara_kosong'))),
      );
      return;
    }
    if (_memparsing) {
      // Parse sebelumnya masih berjalan: jangan buang hasil suara,
      // taruh di kolom input untuk diproses lewat tombol petir.
      _nlCtl.text = teks;
      return;
    }
    _parseNl(teks);
  }

  /// Bar perekaman ala voice note: timer + bar level suara + transkrip
  /// hidup + petunjuk geser-kiri-untuk-batal.
  Widget _panelRekam(ColorScheme cs) {
    final batal = _arahBatal;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: batal ? cs.errorContainer : cs.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            batal
                ? Icons.delete_outline_rounded
                : Icons.fiber_manual_record_rounded,
            size: 14,
            color: batal ? cs.onErrorContainer : cs.error,
          ),
          const SizedBox(width: 6),
          Text(
            _formatDetik(_detikRekam),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: batal
                  ? cs.onErrorContainer
                  : cs.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 8),
          if (_menyiapkanMic)
            Expanded(
              child: Text(
                T.t('nl_menyiapkan_mic'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: cs.onSecondaryContainer,
                ),
              ),
            )
          else ...[
            _barLevelSuara(cs, batal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _teksHidup.isEmpty ? T.t('nl_lepas_proses') : _teksHidup,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontStyle: _teksHidup.isEmpty
                      ? FontStyle.italic
                      : FontStyle.normal,
                  color: _teksHidup.isEmpty
                      ? cs.onSecondaryContainer.withValues(alpha: 0.7)
                      : cs.onSecondaryContainer,
                ),
              ),
            ),
          ],
          const SizedBox(width: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.west_rounded,
                size: 14,
                color: batal
                    ? cs.onErrorContainer
                    : cs.onSecondaryContainer.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 2),
              Text(
                batal ? T.t('nl_lepas_batal') : T.t('nl_geser_batal'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: batal
                      ? cs.onErrorContainer
                      : cs.onSecondaryContainer.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Lima bar kecil yang mengikuti kerasnya suara.
  Widget _barLevelSuara(ColorScheme cs, bool batal) {
    const bobot = [0.45, 0.75, 1.0, 0.75, 0.45];
    return SizedBox(
      width: 24,
      height: 18,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < bobot.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              width: 3,
              height: (4 + 13 * _levelSuara * bobot[i])
                  .clamp(3.0, 18.0)
                  .toDouble(),
              decoration: BoxDecoration(
                color: batal ? cs.onErrorContainer : cs.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDetik(int d) {
    final m = d ~/ 60;
    final s = (d % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ---------- simpan ----------

  Future<void> _simpan() async {
    final app = context.read<AppState>();
    final nama = _namaCtl.text.trim();
    final harga = parseRupiah(_hargaCtl.text);

    if (nama.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.t('snack_nama_kosong'))),
      );
      return;
    }
    if (harga <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.t('snack_harga_kosong'))),
      );
      return;
    }

    // Gerbang lewat batas: kalau pengeluaran ini bikin lewat batas
    // harian, tabungan hemat otomatis dipakai menutup kelebihannya
    // (satu tombol konfirmasi; tanpa tabungan → konfirmasi "tetap
    // simpan?"). Tanggal ikut dikirim: catatan "kemarin" tidak
    // dihitung ke jatah HARI INI (gerbangnya dilewati untuk tanggal lain).
    // Offset dipagari [-7..0]: catatan harian tak pernah lebih tua
    // dari sepekan, nilai aneh dari AI tidak boleh menarik tanggal
    // transaksi jauh ke belakang.
    var offsetHari = _offsetHari;
    if (offsetHari > 0) offsetHari = 0;
    if (offsetHari < -7) offsetHari = -7;
    final tanggalCatat = offsetHari == 0
        ? null
        : DateTime.now().add(Duration(days: offsetHari));
    final gate = await gerbangLewatBatas(
      context,
      app,
      harga,
      tanggal: tanggalCatat,
    );
    if (!gate.lanjut || !mounted) return;
    // Saldo pegangan tidak boleh minus: gerbang terpusat (tolak keras +
    // konfirmasi bila pembelian besar menghabiskan hampir semua saldo).
    if (!await gerbangJagaSaldo(context, app, harga)) return;
    if (!mounted) return;
    setState(() => _menyimpan = true);
    final tersimpan = await app.tambahPengeluaran(
      nama: nama,
      jumlah: harga,
      kategori: _kategori,
      sumber: 'nl_input',
      dibuatPada: tanggalCatat,
    );
    if (!mounted) return;
    if (!tersimpan) {
      // Saldo berubah di antara konfirmasi dan simpan (mis. hasil sync)
      // - transaksi batal, jangan catat pemakaian tabungan.
      setState(() => _menyimpan = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.t('snack_saldo_berubah'))),
      );
      return;
    }
    // Setelah pengeluaran tersimpan: catat pemakaian tabungan yang
    // disetujui user (menutup kelebihan jatah hari ini).
    if (gate.pakaiTabungan > 0) {
      await app.pakaiTabungan(gate.pakaiTabungan, nama);
    }
    if (!mounted) return;
    setState(() => _menyimpan = false);

    _namaCtl.clear();
    _hargaCtl.clear();
    setState(() {
      _kategori = KategoriPengeluaran.lainLain;
      _kategoriManual = false;
      _offsetHari = 0;
    });

    if (!mounted) return;
    final sisaSaldo = app.saldoPegangan;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: gate.pakaiTabungan > 0
            ? Text(T.f('snack_tersimpan_tabungan', {
                't': rp(gate.pakaiTabungan),
                'n': rp(sisaSaldo),
              }))
            : app.lewatBatasBelumTertutup
                ? Text(T.f('snack_tersimpan_lewat', {
                    'n': rp(sisaSaldo),
                    'b': rp(app.budgetBaruSetelahLewat),
                  }))
                : Text(T.f('snack_tersimpan', {'n': rp(sisaSaldo)})),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              T.t('catat_pengeluaran'),
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 10),

            // ----- baris input bebas / suara -----
            // Saat menahan mic, kolom input + tombol petir diganti bar
            // perekaman VN; tombol mic TETAP terpasang supaya gesture
            // jari (geser/lepas) tidak terputus di tengah jalan.
            Row(
              children: [
                Expanded(
                  child: _menahanSuara
                      ? _panelRekam(cs)
                      : TextField(
                          controller: _nlCtl,
                          textInputAction: TextInputAction.done,
                          onSubmitted: _parseNl,
                          decoration: InputDecoration(
                            labelText: T.t('nl_hint'),
                            prefixIcon: const Icon(
                                Icons.auto_awesome_rounded,
                                size: 20),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                ),
                if (!_menahanSuara) ...[
                  const SizedBox(width: 8),
                  _TombolIkon(
                    onPressed:
                        _memparsing ? null : () => _parseNl(_nlCtl.text),
                    ikon: Icons.bolt_rounded,
                    memutar: _memparsing,
                  ),
                ],
                const SizedBox(width: 4),
                _TombolMicTahan(
                  onTekan: _saatTekan,
                  onGerak: _saatGerak,
                  onLepas: _saatLepas,
                  onBatalkan: _saatDibatalkan,
                  merekam: _menahanSuara,
                  menyiapkan: _menyiapkanMic,
                ),
              ],
            ),
            if (_pratinjauNominal != null && !_menahanSuara)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.calculate_rounded, size: 16, color: cs.primary),
                    const SizedBox(width: 6),
                    Text(
                      '${T.t('nl_pratinjau')}:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Nominal penuh dengan titik ribuan - user tidak perlu
                    // menebak "15rb" itu berapa angka.
                    Text(
                      'Rp ${ribuan(_pratinjauNominal!)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_pratinjauKemarin) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.history_rounded,
                          size: 14, color: cs.onSurface.withValues(alpha: 0.85)),
                      const SizedBox(width: 2),
                      Text(
                        T.t('kemarin_label'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 10),

            // Penanda tanggal hasil parse "kemarin": tetap terlihat
            // sampai disimpan / diganti, supaya transaksi tidak nyasar
            // tercatat di tanggal yang salah tanpa sadar.
            if (_offsetHari != 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded,
                          size: 16, color: cs.onSecondaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          T.t('akan_dicatat_kemarin'),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: cs.onSecondaryContainer,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _offsetHari = 0),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(
                          T.t('kembalikan_hari_ini'),
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ----- baris nama + harga -----
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _namaCtl,
                    textInputAction: TextInputAction.next,
                    onChanged: (v) {
                      // Tebak kategori otomatis selama user belum pilih manual.
                      if (!_kategoriManual) {
                        setState(() => _kategori = tebakKategori(v));
                      }
                    },
                    decoration: InputDecoration(
                      labelText: T.t('nama'),
                      hintText: T.t('hint_nama'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _hargaCtl,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [RibuanFormatter()],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _simpan(),
                    decoration: InputDecoration(
                      labelText: T.t('harga'),
                      prefixText: 'Rp ',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ----- kategori + simpan -----
            Row(
              children: [
                Expanded(
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
                        setState(() { _kategori = v!; _kategoriManual = true; }),
                    decoration: InputDecoration(
                      labelText: T.t('kategori'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _menyimpan ? null : _simpan,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    minimumSize: const Size(0, 48),
                  ),
                  child: _menyimpan
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(T.t('simpan')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tombol mic yang aktif saat DITAHAN (bukan ditekan-sekali), seperti
/// tombol voice note WhatsApp: pakai pointer event mentah supaya mulai
/// merekam seketika saat jari menyentuh (tanpa jeda long-press 500 ms)
/// dan pergeseran jari bisa dideteksi untuk geser-batal.
class _TombolMicTahan extends StatelessWidget {
  final void Function(PointerDownEvent) onTekan;
  final void Function(PointerMoveEvent) onGerak;
  final void Function(PointerUpEvent) onLepas;
  final void Function(PointerCancelEvent) onBatalkan;
  final bool merekam;
  final bool menyiapkan;

  const _TombolMicTahan({
    required this.onTekan,
    required this.onGerak,
    required this.onLepas,
    required this.onBatalkan,
    this.merekam = false,
    this.menyiapkan = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Listener(
      onPointerDown: onTekan,
      onPointerMove: onGerak,
      onPointerUp: onLepas,
      onPointerCancel: onBatalkan,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: merekam ? cs.primary : cs.outline,
            width: 2,
          ),
          color: merekam ? cs.primaryContainer : null,
        ),
        child: Center(
          child: menyiapkan
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  Icons.mic_rounded,
                  size: 22,
                  color: cs.primary,
                ),
        ),
      ),
    );
  }
}

/// Tombol ikon persegi kecil (bolt = parse).
class _TombolIkon extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData ikon;
  final Color? warna;
  final bool memutar;
  const _TombolIkon({
    required this.onPressed,
    required this.ikon,
    this.warna,
    this.memutar = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: warna,
        ),
        child: memutar
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(ikon, size: 22),
      ),
    );
  }
}
