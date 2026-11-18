import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models/transaksi.dart';
import '../providers/app_state.dart';
import '../services/gemini_service.dart';
import '../utils/dialog.dart';
import '../utils/format.dart';
import '../utils/teks.dart';

enum ScanJenis { struk, buktiTf }

/// Scan struk belanja / bukti transfer pakai Gemini.
/// Foto → Gemini baca → form terisi otomatis → kamu cek & simpan.
class ScanScreen extends StatefulWidget {
  final ScanJenis jenis;

  /// Foto yang di-share dari app lain (WhatsApp/galeri): langsung terpasang.
  final Uint8List? gambarAwal;
  const ScanScreen({super.key, required this.jenis, this.gambarAwal});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  Uint8List? _foto;

  /// Path file foto terakhir: dibutuhkan image_cropper (crop/rotate).
  String? _fotoPath;
  bool _memproses = false;
  String? _error;

  HasilScanStruk? _hasilStruk;
  HasilScanTf? _hasilTf;

  // form struk
  final _namaCtl = TextEditingController();
  final _pajakCtl = TextEditingController();
  final _totalCtl = TextEditingController();
  KategoriPengeluaran _kategori = KategoriPengeluaran.lainLain;

  // form bukti TF
  final _nominalCtl = TextEditingController();
  final _pihakCtl = TextEditingController();
  final _catatanCtl = TextEditingController();

  DateTime _tanggal = DateTime.now();

  /// Jam pencatatan (menit sejak 00:00) yang dipakai saat simpan.
  /// Default = jam struk kalau terbaca, kalau tidak jam saat scan -
  /// supaya transaksi scan tidak lagi tercatat jam 00:00.
  int _jamMenit = 0;

  /// Tanggal yang tercetak di struk/bukti (hasil bacaan Gemini) yang
  /// LOLOS gerbang wajar (tahun berjalan, maks 1 bulan lalu, bukan masa
  /// depan). Default pencatatan = TANGGAL DOKUMEN; kalau Gemini tidak
  /// menemukan tanggal ATAU tanggalnya ditolak gerbang, default tetap
  /// HARI INI + jam scan. Satu ketuk di baris "tanggal dokumen"
  /// untuk bolak-balik keduanya.
  DateTime? _tanggalDokumen;

  /// Jam yang tercetak di dokumen (menit sejak 00:00), kalau terbaca.
  int? _jamDokumen;

  /// Tanggal hasil bacaan yang DITOLAK gerbang (mis. struk terbaca
  /// "18/11/2023" padahal tahun berjalan) - ditampilkan sebagai info
  /// kecil supaya user tahu kenapa pencatatannya pakai hari ini.
  DateTime? _tanggalDitolak;
  bool _menyimpan = false;

  bool get _isStruk => widget.jenis == ScanJenis.struk;

  @override
  void initState() {
    super.initState();
    _tanggal = tanggalSaja(DateTime.now());
    _jamMenit = _jamSekarang();
    if (widget.gambarAwal != null) {
      _foto = widget.gambarAwal;
      // Foto dari share hanya berupa bytes: tulis ke file sementara
      // supaya tombol potong/putar tetap bisa dipakai (image_cropper
      // butuh path file, bukan bytes).
      _simpanKeFileSementara(widget.gambarAwal!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(T.t('bagikan_foto_terima'))),
          );
        }
      });
    }
  }

  /// Jam saat ini (menit sejak 00:00) - dipakai sebagai jam catat
  /// kalau dokumen tidak mencantumkan jam.
  int _jamSekarang() {
    final n = DateTime.now();
    return n.hour * 60 + n.minute;
  }

  /// Terapkan hasil bacaan tanggal+jam ke state form:
  /// - tanggal dokumen lolos gerbang → jadi default catat + jam dokumen
  ///   (kalau ada; kalau tidak, jam scan);
  /// - tidak terbaca / ditolak (tahun lalu, > 1 bulan, masa depan) →
  ///   HARI INI + jam scan, plus catatan kecil tanggal yang ditolak.
  void _pasangTanggalDokumen(DateTime? mentah, int? jamBacaan) {
    final dok = validasiTanggalDokumen(mentah);
    _tanggalDokumen = dok;
    _jamDokumen = dok == null ? null : jamBacaan;
    _tanggalDitolak = (mentah != null && dok == null)
        ? tanggalSaja(mentah)
        : null;
    _tanggal = dok ?? tanggalSaja(DateTime.now());
    _jamMenit = (dok != null && jamBacaan != null)
        ? jamBacaan
        : _jamSekarang();
  }

  /// Simpan bytes foto (mis. hasil share dari WhatsApp) ke file
  /// sementara supaya bisa di-crop/di-rotate.
  Future<void> _simpanKeFileSementara(Uint8List bytes) async {
    try {
      final dir = await getTemporaryDirectory();
      final f = File(p.join(
        dir.path,
        'kosku-bagikan-${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      await f.writeAsBytes(bytes);
      if (mounted) setState(() => _fotoPath = f.path);
    } catch (_) {
      // Gagal menulis file: foto tetap bisa dibaca Gemini, hanya
      // tombol potong/putar yang nonaktif.
    }
  }

  @override
  void dispose() {
    _namaCtl.dispose();
    _pajakCtl.dispose();
    _totalCtl.dispose();
    _nominalCtl.dispose();
    _pihakCtl.dispose();
    _catatanCtl.dispose();
    super.dispose();
  }

  Future<void> _pilih(bool kamera) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: kamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _foto = bytes;
      _fotoPath = file.path;
      _hasilStruk = null;
      _hasilTf = null;
      _error = null;
      _tanggalDokumen = null;
      _jamDokumen = null;
      _tanggalDitolak = null;
      // Foto baru = tanggal dokumen lama tidak berlaku lagi.
      _tanggal = tanggalSaja(DateTime.now());
      _jamMenit = _jamSekarang();
    });
  }

  /// Potong / putar foto sebelum dibaca. UI crop bawaan Android
  /// (uCrop) sudah menyediakan rotasi 90 derajat dan drag handle bebas.
  Future<void> _bukaEditor() async {
    if (_fotoPath == null) return;
    final cs = Theme.of(context).colorScheme;
    try {
      final hasil = await ImageCropper().cropImage(
        sourcePath: _fotoPath!,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: T.t('potong_putar'),
            toolbarColor: cs.primary,
            toolbarWidgetColor: cs.onPrimary,
            activeControlsWidgetColor: cs.primary,
            lockAspectRatio: false,
            hideBottomControls: false,
          ),
        ],
      );
      if (hasil == null) return;
      final bytes = await File(hasil.path).readAsBytes();
      if (!mounted) return;
      setState(() {
        _foto = bytes;
        _fotoPath = hasil.path;
        _hasilStruk = null;
        _hasilTf = null;
        _error = null;
        _tanggalDokumen = null;
        _jamDokumen = null;
        _tanggalDitolak = null;
        // Hasil baca lama tidak berlaku untuk foto hasil crop.
        _tanggal = tanggalSaja(DateTime.now());
        _jamMenit = _jamSekarang();
      });
    } catch (_) {
      // Editor gagal dibuka: beri tahu user (sebelumnya diam-diam,
      // terkesan tombolnya tidak berfungsi).
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.t('crop_gagal'))),
      );
    }
  }

  Future<void> _baca() async {
    final app = context.read<AppState>();
    if (!app.punyaKunciGemini) {
      setState(() => _error = T.t('scan_err_key'));
      return;
    }
    setState(() {
      _memproses = true;
      _error = null;
    });
    try {
      if (_isStruk) {
        // panggilGemini: key 1 → habis kuota/invalid → key 2 otomatis.
        final hasil = await app.panggilGemini((svc) => svc.bacaStruk(_foto!));
        if (!mounted) return;
        setState(() {
          _hasilStruk = hasil;
          _namaCtl.text = hasil.merchant ?? '';
          _pajakCtl.text = hasil.pajak > 0 ? ribuan(hasil.pajak) : '';
          _totalCtl.text = hasil.total > 0 ? ribuan(hasil.total) : '';
          _kategori = KategoriPengeluaran.dariNilai(hasil.kategoriSaran);
          // Default = TANGGAL STRUK + jam struk (kalau terbaca & wajar);
          // kalau tidak terbaca / ditolak gerbang, pakai hari ini +
          // jam scan.
          _pasangTanggalDokumen(hasil.tanggal, hasil.jamMenit);
        });
      } else {
        final hasil = await app.panggilGemini((svc) => svc.bacaBuktiTf(_foto!));
        if (!mounted) return;
        setState(() {
          _hasilTf = hasil;
          _nominalCtl.text = hasil.nominal > 0 ? ribuan(hasil.nominal) : '';
          _pihakCtl.text = hasil.pihak ?? '';
          _pasangTanggalDokumen(hasil.tanggal, hasil.jamMenit);
          _catatanCtl.text = hasil.bank ?? '';
        });
      }
    } on GeminiException catch (e) {
      if (mounted) setState(() => _error = e.pesan);
    } catch (_) {
      if (mounted) setState(() => _error = T.t('scan_err_gagal'));
    } finally {
      if (mounted) setState(() => _memproses = false);
    }
  }

  /// Pemilih tanggal untuk form scan: catatan hanya boleh dalam
  /// jendela [1 bulan lalu .. hari ini] - sama dengan gerbang tanggal
  /// dokumen - supaya hasil scan yang sudah disaring tidak bisa
  /// "dibebaskan" lagi lewat picker ke tanggal tahun lalu / masa depan.
  Future<void> _pilihTanggalForm() async {
    final kini = DateTime.now();
    final p = await pilihTanggal(
      context,
      awal: _tanggal,
      batasAwal: DateTime(kini.year, kini.month - 1, kini.day),
      batasAkhir: kini,
    );
    if (p != null) {
      setState(() => _tanggal = tanggalSaja(p));
    }
  }

  Future<void> _simpan() async {
    final app = context.read<AppState>();

    if (_isStruk) {
      final nama = _namaCtl.text.trim().isEmpty
          ? T.t('belanja_default')
          : _namaCtl.text.trim();
      final total = parseRupiah(_totalCtl.text);
      if (total <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(T.t('scan_err_total'))),
        );
        return;
      }
      // Gerbang lewat batas: kalau pengeluaran ini bikin lewat batas
      // harian, tabungan hemat otomatis dipakai menutup kelebihannya
      // (satu tombol konfirmasi - lihat gerbangLewatBatas).
      // Tanggal struk ikut dikirim: catatan bertanggal lain tidak
      // dihitung ke jatah HARI INI.
      final gate = await gerbangLewatBatas(context, app, total,
          tanggal: _tanggal);
      if (!gate.lanjut || !mounted) return;
      if (!await gerbangJagaSaldo(context, app, total)) return;
      if (!mounted) return;

      setState(() => _menyimpan = true);
      final items = _hasilStruk?.items ?? [];
      final ringkasan = items.isEmpty
          ? T.t('scan_struk_sumber')
          : '${items.length} item: ${items.map((i) => i.nama).take(3).join(', ')}'
              '${items.length > 3 ? T.t('scan_item_lain') : ''}';
      final tersimpan = await app.tambahPengeluaran(
        nama: nama,
        jumlah: total,
        kategori: _kategori,
        sumber: 'scan_struk',
        // Default tanggal struk + jam struk (kalau tidak ada jam
        // di struk, jam saat scan) - bukan lagi jam 00:00.
        dibuatPada: tanggalDenganJam(_tanggal, _jamMenit, DateTime.now()),
      );
      if (!mounted) return;
      if (!tersimpan) {
        // Saldo berubah di antara konfirmasi dan simpan - batal, jangan
        // catat pemakaian tabungan.
        setState(() => _menyimpan = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(T.t('snack_saldo_berubah'))),
        );
        return;
      }
      // Tabungan yang disetujui user dicatat setelah pengeluaran masuk.
      if (gate.pakaiTabungan > 0) {
        await app.pakaiTabungan(gate.pakaiTabungan, nama);
      }
      if (!mounted) return;
      setState(() => _menyimpan = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(T.f('snack_scan_struk', {
            'x': ringkasan,
            'n': rp(app.saldoPegangan),
          })),
        ),
      );
      Navigator.pop(context);
    } else {
      final nominal = parseRupiah(_nominalCtl.text);
      if (nominal <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(T.t('scan_err_nominal'))),
        );
        return;
      }
      setState(() => _menyimpan = true);
      final pihak = _pihakCtl.text.trim();
      final bank = _catatanCtl.text.trim();
      await app.tambahPemasukan(
        jumlah: nominal,
        catatan: '${T.t('transfer_masuk')}'
            '${pihak.isEmpty ? '' : T.f('transfer_dari', {'x': pihak})}'
            '${bank.isEmpty ? '' : ' ($bank)'}',
        sumber: 'scan_tf',
        // Default tanggal bukti + jam bukti (kalau tidak ada jam di
        // bukti, jam saat scan); bisa diganti user.
        dibuatPada: tanggalDenganJam(_tanggal, _jamMenit, DateTime.now()),
      );
      if (!mounted) return;
      setState(() => _menyimpan = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(T.f('snack_scan_tf', {'n': rp(app.saldoPegangan)})),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isStruk ? T.t('scan_struk_judul') : T.t('scan_tf_judul')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            color: cs.secondaryContainer,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                _isStruk ? T.t('scan_struk_info') : T.t('scan_tf_info'),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: cs.onSecondaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ----- area foto -----
          if (_foto == null)
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.outlineVariant,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_camera_rounded,
                      size: 40, color: cs.onSurface.withValues(alpha: 0.75)),
                  const SizedBox(height: 8),
                  Text(T.t('ambil_foto'),
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => _pilih(true),
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: Text(T.t('kamera')),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: () => _pilih(false),
                        icon: const Icon(Icons.photo_library_rounded, size: 18),
                        label: Text(T.t('galeri')),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                _foto!,
                height: 260,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    // Foto selalu punya path: dari kamera/galeri, maupun
                    // hasil share (bytes ditulis ke file sementara dulu).
                    onPressed: _bukaEditor,
                    icon: const Icon(Icons.crop_rounded, size: 18),
                    label: Text(T.t('potong_putar')),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _pilih(true),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(T.t('ganti_foto')),
                  ),
                ),
              ],
            ),
          ],

          // ----- tombol baca -----
          if (_foto != null) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _memproses ? null : _baca,
                icon: _memproses
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(_memproses
                    ? T.t('sedang_dibaca')
                    : T.t('baca_gemini')),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _error!,
                style: TextStyle(fontSize: 12.5, color: cs.onErrorContainer),
              ),
            ),
          ],

          // ----- form hasil struk -----
          if (_hasilStruk != null) ...[
            const SizedBox(height: 12),
            _KartuHasilStruk(
              namaCtl: _namaCtl,
              pajakCtl: _pajakCtl,
              totalCtl: _totalCtl,
              kategori: _kategori,
              onKategori: (k) => setState(() => _kategori = k),
              tanggal: _tanggal,
              jamMenit: _jamMenit,
              onTanggal: () => _pilihTanggalForm(),
              tanggalDokumen: _tanggalDokumen,
              jamDokumen: _jamDokumen,
              tanggalDitolak: _tanggalDitolak,
              onPakaiTanggalDokumen: () => setState(() {
                    _tanggal = tanggalSaja(
                        _tanggalDokumen ?? DateTime.now());
                    if (_jamDokumen != null) _jamMenit = _jamDokumen!;
                  }),
              onKembaliHariIni: () => setState(() {
                    _tanggal = tanggalSaja(DateTime.now());
                    _jamMenit = _jamSekarang();
                  }),
              hasil: _hasilStruk!,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _menyimpan ? null : _simpan,
                icon: const Icon(Icons.check_rounded),
                label: Text(T.t('simpan_pengeluaran')),
              ),
            ),
          ],

          // ----- form hasil bukti TF -----
          if (_hasilTf != null) ...[
            const SizedBox(height: 12),
            _KartuHasilTf(
              nominalCtl: _nominalCtl,
              pihakCtl: _pihakCtl,
              catatanCtl: _catatanCtl,
              tanggal: _tanggal,
              jamMenit: _jamMenit,
              onTanggal: () => _pilihTanggalForm(),
              tanggalDokumen: _tanggalDokumen,
              jamDokumen: _jamDokumen,
              tanggalDitolak: _tanggalDitolak,
              onPakaiTanggalDokumen: () => setState(() {
                    _tanggal = tanggalSaja(
                        _tanggalDokumen ?? DateTime.now());
                    if (_jamDokumen != null) _jamMenit = _jamDokumen!;
                  }),
              onKembaliHariIni: () => setState(() {
                    _tanggal = tanggalSaja(DateTime.now());
                    _jamMenit = _jamSekarang();
                  }),
              hasil: _hasilTf!,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _menyimpan ? null : _simpan,
                icon: const Icon(Icons.check_rounded),
                label: Text(T.t('konfirmasi_kiriman_masuk')),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _KartuHasilStruk extends StatelessWidget {
  final TextEditingController namaCtl;
  final TextEditingController pajakCtl;
  final TextEditingController totalCtl;
  final KategoriPengeluaran kategori;
  final ValueChanged<KategoriPengeluaran> onKategori;
  final DateTime tanggal;

  /// Jam pencatatan (menit sejak 00:00) - ditampilkan di samping
  /// tanggal supaya user tahu jam yang akan dipakai saat menyimpan.
  final int jamMenit;
  final VoidCallback onTanggal;

  /// Tanggal tercetak di struk yang lolos gerbang wajar (bisa null).
  final DateTime? tanggalDokumen;

  /// Jam yang tercetak di struk (bisa null kalau tidak ada).
  final int? jamDokumen;

  /// Tanggal hasil bacaan yang ditolak gerbang (info kenapa pakai
  /// hari ini) - null kalau tidak ada yang ditolak.
  final DateTime? tanggalDitolak;
  final VoidCallback? onPakaiTanggalDokumen;
  final VoidCallback? onKembaliHariIni;
  final HasilScanStruk hasil;

  const _KartuHasilStruk({
    required this.namaCtl,
    required this.pajakCtl,
    required this.totalCtl,
    required this.kategori,
    required this.onKategori,
    required this.tanggal,
    required this.jamMenit,
    required this.onTanggal,
    required this.tanggalDokumen,
    required this.jamDokumen,
    required this.tanggalDitolak,
    required this.onPakaiTanggalDokumen,
    required this.onKembaliHariIni,
    required this.hasil,
  });

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
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(T.t('hasil_scan_judul'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: namaCtl,
              decoration: InputDecoration(
                labelText: T.t('nama_toko'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onTanggal,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: T.t('tanggal'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Text(
                        '${tanggalPendek(tanggal)} • ${jamMenitLabel(jamMenit)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<KategoriPengeluaran>(
                    key: ValueKey(kategori),
                    initialValue: kategori,
                    isExpanded: true,
                    items: KategoriPengeluaran.values
                        .map((k) => DropdownMenuItem(
                              value: k,
                              child: Text(labelKategori(k),
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) => onKategori(v!),
                    decoration: InputDecoration(
                      labelText: T.t('kategori'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: pajakCtl,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [RibuanFormatter()],
                    decoration: InputDecoration(
                      labelText: T.t('pajak_biaya'),
                      prefixText: 'Rp ',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: totalCtl,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [RibuanFormatter()],
                    decoration: InputDecoration(
                      labelText: T.t('total_kapotong'),
                      prefixText: 'Rp ',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            _BarisTanggalDokumen(
              tanggalDokumen: tanggalDokumen,
              jamDokumen: jamDokumen,
              tanggalDitolak: tanggalDitolak,
              tanggal: tanggal,
              onPakaiTanggalDokumen: onPakaiTanggalDokumen,
              onKembaliHariIni: onKembaliHariIni,
            ),
            if (hasil.items.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(T.f('item_terbaca', {'n': '${hasil.items.length}'}),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              ...hasil.items.map(
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(i.nama,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5)),
                      ),
                      Text(rp(i.harga),
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ],
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

class _KartuHasilTf extends StatelessWidget {
  final TextEditingController nominalCtl;
  final TextEditingController pihakCtl;
  final TextEditingController catatanCtl;
  final DateTime tanggal;

  /// Jam pencatatan (menit sejak 00:00) untuk ditampilkan di form.
  final int jamMenit;
  final VoidCallback onTanggal;

  /// Tanggal tercetak di bukti transfer yang lolos gerbang (bisa null).
  final DateTime? tanggalDokumen;

  /// Jam yang tercetak di bukti transfer (bisa null).
  final int? jamDokumen;

  /// Tanggal hasil bacaan yang ditolak gerbang (info kenapa pakai
  /// hari ini) - null kalau tidak ada yang ditolak.
  final DateTime? tanggalDitolak;
  final VoidCallback? onPakaiTanggalDokumen;
  final VoidCallback? onKembaliHariIni;
  final HasilScanTf hasil;

  const _KartuHasilTf({
    required this.nominalCtl,
    required this.pihakCtl,
    required this.catatanCtl,
    required this.tanggal,
    required this.jamMenit,
    required this.onTanggal,
    required this.tanggalDokumen,
    required this.jamDokumen,
    required this.tanggalDitolak,
    required this.onPakaiTanggalDokumen,
    required this.onKembaliHariIni,
    required this.hasil,
  });

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
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(T.t('hasil_scan_judul'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
            if (hasil.arah == 'keluar')
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  T.t('tf_keluar_warning'),
                  style: TextStyle(fontSize: 12, color: cs.onErrorContainer),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: nominalCtl,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [RibuanFormatter()],
                    decoration: InputDecoration(
                      labelText: T.t('nominal_masuk'),
                      prefixText: 'Rp ',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: onTanggal,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: T.t('tanggal'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Text(
                        '${tanggalSangatPendek(tanggal)} • ${jamMenitLabel(jamMenit)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pihakCtl,
              decoration: InputDecoration(
                labelText: T.t('dari_siapa'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: catatanCtl,
              decoration: InputDecoration(
                labelText: T.t('bank_ewallet'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            _BarisTanggalDokumen(
              tanggalDokumen: tanggalDokumen,
              jamDokumen: jamDokumen,
              tanggalDitolak: tanggalDitolak,
              tanggal: tanggal,
              onPakaiTanggalDokumen: onPakaiTanggalDokumen,
              onKembaliHariIni: onKembaliHariIni,
            ),
          ],
        ),
      ),
    );
  }
}

/// Baris info "tanggal dokumen vs hari ini". Pencatatan default
/// TANGGAL DOKUMEN (sesuai isi struk, plus jam struk kalau ada);
/// kalau user lebih suka mencatatnya sebagai hari ini (mis. struk
/// lama baru dibayar sekarang), satu ketuk untuk bolak-balik kapan
/// pun. Kalau tanggal hasil bacaan DITOLAK gerbang (tahun lalu /
/// lebih dari sebulan / masa depan), baris ini jadi pemberitahuan
/// kenapa pencatatan memakai hari ini + jam scan.
class _BarisTanggalDokumen extends StatelessWidget {
  final DateTime? tanggalDokumen;

  /// Jam yang tercetak di dokumen (menit sejak 00:00), bisa null.
  final int? jamDokumen;

  /// Tanggal hasil bacaan yang ditolak gerbang (bisa null).
  final DateTime? tanggalDitolak;
  final DateTime tanggal;
  final VoidCallback? onPakaiTanggalDokumen;
  final VoidCallback? onKembaliHariIni;

  const _BarisTanggalDokumen({
    required this.tanggalDokumen,
    required this.jamDokumen,
    required this.tanggalDitolak,
    required this.tanggal,
    this.onPakaiTanggalDokumen,
    this.onKembaliHariIni,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dok = tanggalDokumen;
    final ditolak = tanggalDitolak;

    // Tanggal dokumen ditolak gerbang → info kenapa pakai hari ini.
    if (dok == null && ditolak != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.errorContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.event_busy_rounded,
                  size: 16, color: cs.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  T.f('scan_tanggal_ditolak', {'d': tanggalPendek(ditolak)}),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: cs.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (dok == null) return const SizedBox.shrink();
    final samaDenganTanggal = tanggalSaja(dok) == tanggalSaja(tanggal);
    if (samaDenganTanggal) return const SizedBox.shrink();

    final hariIni = tanggalSaja(DateTime.now());
    final pakaiHariIni = tanggalSaja(tanggal) == hariIni;
    final teksDok = jamDokumen == null
        ? tanggalPendek(dok)
        : '${tanggalPendek(dok)} • ${jamMenitLabel(jamDokumen!)}';

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
        decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.event_rounded, size: 16, color: cs.onSecondaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                T.f('scan_tanggal_dokumen', {'d': teksDok}),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: cs.onSecondaryContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: pakaiHariIni
                  ? onPakaiTanggalDokumen
                  : onKembaliHariIni,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                pakaiHariIni
                    ? T.t('scan_pakai_tanggal_dokumen')
                    : T.t('scan_pakai_hari_ini'),
                style: const TextStyle(fontSize: 11.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
