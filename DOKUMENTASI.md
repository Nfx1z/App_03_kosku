# Dokumentasi Kosku

**Pencatat uang pribadi offline-first untuk Android** — dibuat dengan Flutter + Dart.
Versi aplikasi yang didokumentasikan: **2.17.1** (build 20).

Dokumen ini adalah referensi lengkap kosku dalam Bahasa Indonesia: semua fitur, konsep dan cara hitung uangnya, aturan-aturan keamanan saldonya, pengingat notifikasinya, akun & sinkronisasi cloud-nya, sampai peta struktur file dan skema database-nya — semuanya dijelaskan per bagian.

> Dokumen ini menjelaskan **implementasi aktual** di dalam kode. Kalau ada komentar lama di kode yang tidak lagi cocok (mis. soal penyimpanan API key), yang dipakai acuan adalah dokumen ini.

---

## Daftar isi

1. [Tentang kosku](#1-tentang-kosku)
2. [Konsep dasar & istilah](#2-konsep-dasar--istilah)
3. [Alur aplikasi & peta navigasi](#3-alur-aplikasi--peta-navigasi)
4. [Panduan fitur lengkap](#4-panduan-fitur-lengkap)
5. [Aturan uang: saldo tidak boleh minus](#5-aturan-uang-saldo-tidak-boleh-minus)
6. [Cara aplikasi menghitung uang](#6-cara-aplikasi-menghitung-uang)
7. [Pengingat & notifikasi](#7-pengingat--notifikasi)
8. [Akun, sinkronisasi & keamanan](#8-akun-sinkronisasi--keamanan)
9. [Struktur file lengkap](#9-struktur-file-lengkap)
10. [Skema database (SQLite)](#10-skema-database-sqlite)
11. [Struktur data di Firestore](#11-struktur-data-di-firestore)
12. [Teknologi & dependensi](#12-teknologi--dependensi)
13. [Menjalankan, membuild & merilis](#13-menjalankan-membuild--merilis)
14. [Uji otomatis](#14-uji-otomatis)
15. [Riwayat versi](#15-riwayat-versi)

---

## 1. Tentang kosku

kosku adalah pencatat keuangan pribadi yang dirancang untuk anak kos: orang yang uangnya datang rutin dari kiriman (transfer dari rumah), dipegang tunai, dan habis untuk kebutuhan harian.

**Prinsip besar desainnya:**

| Prinsip | Artinya |
| --- | --- |
| **Offline-first** | Semua data disimpan di SQLite di HP. Aplikasi jalan **penuh tanpa internet**. Cloud (Firebase) hanya cermin — nyala belakangan lewat antrian sync. |
| **Saldo tidak boleh minus** | Uang pegangan tidak pernah bisa dikurangi melebihi isinya. Ini dijaga berlapis (lihat bagian 5). |
| **Uang tunai, angka bulat** | Semua nominal disimpan sebagai `INTEGER` Rupiah bulat tanpa sen — pas untuk melacak uang tunai. |
| **Satu sumber kebenaran** | Semua perubahan saldo wajib lewat `AppState`; saldo di tabel `saldo` adalah hasil materialisasi buku kas (transaksi), bukan angka lepas. |
| **Notifikasi adalah bonus** | Pengingat dibungkus try/catch — izin ditolak atau alarm gagal tidak pernah membuat aplikasi crash. |
| **Dua bahasa, ganti tanpa restart** | UI dwibahasa Indonesia (default) / English lewat kamus `T.t()` / `T.f()`. |

**Tampilan:** tema **dusty pink + cream** (tanpa warna lain — status positif pun memakai keluarga pink), splash logo setiap kali aplikasi dibuka (gaya Gojek), layar sambutan sekali di awal, dan ikon launcher logo kosku.

**Fitur online (semuanya opsional):** scan struk, scan bukti transfer, input bahasa alami (lewat Gemini API), serta login + sinkronisasi cloud (Firebase). Tanpa kunci Gemini dan tanpa Firebase pun aplikasi tetap berfungsi penuh — fitur online-nya saja yang nonaktif.

---

## 2. Konsep dasar & istilah

Istilah-istilah ini dipakai di seluruh aplikasi dan dokumen ini.

| Istilah | Artinya |
| --- | --- |
| **Pegangan** | Uang tunai yang sedang kamu pegang. Angka utama di Home. Setiap transaksi otomatis menambah/menguranginya. |
| **Kantong darurat** | Uang yang dipisahkan dari pegangan untuk keadaan darurat. Isi kantong = pegangan berkurang; tarik kembali = pegangan bertambah. |
| **Kiriman** | Transfer rutin masuk dari rumah/orang tua. Punya jadwal (tanggal datang) dan status *menunggu* / *sudah masuk*. Konfirmasi kiriman = pemasukan. |
| **Jatah / budget harian** | Batas belanja per hari. Bisa otomatis (saldo ÷ sisa hari) atau manual (diatur sendiri di Pengaturan). |
| **Patokan** | Tanggal acuan "sampai kapan uang ini harus cukup": tanggal kiriman berikutnya, atau akhir bulan kalau tidak ada kiriman / kiriman telat. |
| **Tabungan hemat** | Sisa jatah harian yang tidak terpakai, terkumpul otomatis per hari, dibawa terus antar bulan (rollover). |
| **Utang** | Aku berutang ke orang lain (dapat duit, saldo nambah, wajib dibayar → saat bayar saldo berkurang). |
| **Ngutangin** | Aku meminjamkan uang ke orang lain (saldo berkurang saat uang keluar, kembali saat dilunasi). |
| **Target beli** | Rencana beli sesuatu: nama + budget + deadline opsional. Ada saran nabung per hari. |
| **Uang masuk / keluar lain** | Uang yang bukan kiriman dan bukan pengeluaran harian: hadiah, jualan, cashback (masuk); bayar kos, wifi, setor ke rumah (keluar). Tidak dihitung dalam statistik belanja. |
| **Imbas** | Pratinjau dampak sebelum menyimpan: "pegangan jadi berapa, dengan batas harian uang bertahan sampai kapan". Muncul di konfirmasi beli target, ngutangin, bayar lunas utang, isi kantong darurat, uang keluar lain, dan saat lewat batas. |
| **Tombstone** | Penanda "terhapus" (`dihapus = 1`) pada baris SQLite **lokal** — supaya penghapusan tidak tertimpa merge. Di cloud dokumennya justru **dihapus betulan** (DELETE, sejak v2.17.1) — bukan ditandai — jadi data "sudah dihapus" tidak menumpuk selamanya di Firestore. |

**Dua belas jenis transaksi** (`JenisTransaksi`) dan efeknya ke saldo:

| Jenis | Efek pegangan | Efek kantong | Kapan tercatat |
| --- | --- | --- | --- |
| `pengeluaran` | −n | — | Input cepat, scan struk, beli target |
| `pemasukan` | +n | — | Konfirmasi kiriman, scan bukti transfer |
| `isi_darurat` | −n | +n | Isi kantong darurat |
| `pakai_darurat` | 0 | −n | Pakai kantong darurat |
| `tarik_darurat` | +n | −n | Tarik kantong darurat ke pegangan |
| `utang_masuk` | +n | — | Catat utang (aku berutang) |
| `utang_bayar` | −n | — | Lunasi utang (opsional dicatat) |
| `piutang_keluar` | −n | — | Catat ngutangin (uang keluar) |
| `piutang_terima` | +n | — | Piutang dilunasi orang (opsional dicatat) |
| `koreksi` | ±n | — | Setel ulang saldo pegangan (atur saldo) |
| `masuk_lain` | +n | — | Uang masuk lain (hadiah, jualan, cashback) |
| `keluar_lain` | −n | — | Uang keluar lain (kos, wifi, setor) |

**Delapan kategori pengeluaran** (`KategoriPengeluaran`): `makan_minum`, `transport`, `belanja_pokok`, `hiburan`, `kesehatan`, `tagihan_rumah`, `pendidikan`, `lain_lain`. Kategori bisa ditebak otomatis dari nama (lihat 6.6).

---

## 3. Alur aplikasi & peta navigasi

Urutan gerbang saat aplikasi dibuka (`main()` → `KoskuApp`):

1. **Splash** (`LayarSplash`) — tampil setiap sesi pembukaan; animasi logo 1,5 detik; hanya lanjut kalau animasi selesai **dan** data sudah siap dimuat.
2. **Layar kunci** (`LayarKunci`) — hanya kalau sesi terkunci karena offline terlalu lama melewati masa tenggang (lihat 8.6).
3. **Sambutan** (`LayarSambutan`) — sekali di awal pemakaian (flag `sudah_sambutan` per perangkat).
4. **Home** (`HomeScreen`) — layar utama.

Bootstrap di belakangnya: format tanggal lokal disiapkan → Firebase dicoba diinisialisasi (gagal? aplikasi tetap jalan mode lokal) → `AppState` dimuat dari SQLite → service penerima share dinyalakan (Android) → notifikasi disiapkan **setelah** `runApp` supaya startup tidak tertunda.

```
HomeScreen (layar input harian)
├── Menu pojok kanan (PopupMenu):
│    ├── Kiriman selanjutnya   → KirimanScreen
│    ├── Dana darurat          → DanaDaruratScreen
│    ├── Tabungan              → TabunganScreen
│    ├── Target beli           → TargetScreen
│    ├── Utang & ngutangin     → UtangScreen (2 tab)
│    ├── Uang masuk/keluar lain→ DialogUangLain (dialog)
│    ├── Riwayat lengkap       → RiwayatScreen
│    ├── Laporan bulanan       → LaporanScreen
│    └── Pengaturan & Akun     → PengaturanScreen  ← SATU pintu untuk
│         (akun, sinkronisasi, bahasa, pengingat,      pengaturan + akun +
│          uang, data, tentang)                        sinkronisasi
├── Tombol Scan (FAB) → pilih: Scan struk / Scan bukti transfer → ScanScreen
├── Kartu-kartu: Selamat datang (sekali) · Saldo · Perhatian ·
│                Budget · Input cepat
└── Bagian "Hari ini": daftar transaksi hari ini
     └── Tap transaksi → lembar ubah/hapus

Dari Pengaturan & Akun: → AuthScreen (masuk/daftar) → VerifikasiEmailScreen
                        (saat email belum diverifikasi)
Dari layar kunci:       → AuthScreen (masuk untuk membuka)
```

> **Sejak v2.14**, akun + sinkronisasi + pengaturan menyatu jadi **satu** menu "Pengaturan & Akun". Sebelumnya ada tiga pintu masuk terpisah (ikon status sync di AppBar Home, menu "Akun & sinkronisasi", dan menu "Pengaturan"). Semua yang dulu bisa dilakukan dari titik-titik itu sekarang ada di dalam `PengaturanScreen`: kartu **Akun & Sinkronisasi** muncul sendiri di bagian atas layar itu begitu Firebase aktif.

---

## 4. Panduan fitur lengkap

### 4.1 Home — layar input harian

Home adalah pusat segalanya: semua halaman lain dibuka dari menu pojok kanan, dan pencatatan harian terjadi langsung di sini.

Susunan kartunya (atas ke bawah):

1. **Kartu selamat datang** (hanya sekali, sebelum setup) — input saldo pegangan pertama. Menekan "Mulai" mencatat transaksi `koreksi` sebesar selisihnya dan menandai setup selesai (`sudah_setup`).
2. **Kartu saldo** — angka besar **pegangan sekarang** (merah + peringatan bila minus — secara normal tidak mungkin terjadi), dua pil info: *kantong darurat* dan *total uang* (pegangan + kantong), serta info kiriman berikutnya ("nominal • tanggal • n hari lagi") bila ada kiriman aktif yang tidak telat.
3. **Kartu perlu perhatian** — muncul hanya kalau ada yang perlu diketahui: kiriman lewat tanggal belum dikonfirmasi, utang lewat/mendekati jatuh tempo (≤ 3 hari), target ≤ 7 hari ke deadline tapi uang masih kurang, dan lewat batas harian yang belum ditutup tabungan (tanpa angka — saran jatah barunya ada di kartu budget, satu saran saja).
4. **Kartu budget** — penjaga jatah harian (detail di 4.2).
5. **Kartu input cepat** — pencatatan super cepat (detail di 4.11).
6. **Bagian "Hari ini"** — daftar transaksi hari ini; tap satu transaksi untuk mengubah/menghapus. Kalau kosong, muncul kartu "belum ada catatan".

Tombol **Scan** (FAB biru muda di bawah) membuka pilihan scan struk / bukti transfer (4.10).

### 4.2 Kartu budget — jatah harian

Menampilkan **terpakai / jatah** hari ini, progress bar, dan sumber batas:

- **Batas manual** — angka yang kamu atur sendiri di Pengaturan.
- **Batas otomatis** — `saldo ÷ sisa hari` sampai patokan (kiriman berikutnya, atau akhir bulan). Manual selalu menang atas otomatis.
- **Kiriman telat** — patokan otomatis pindah ke akhir bulan (uang terakhir harus bertahan sampai benar-benar ada kiriman).

Keluar dari batas tidak dilarang — hanya dijaga: kartu jadi merah, muncul **satu-satunya** rekomendasi **jatah baru** (sisa saldo ÷ sisa hari SETELAH hari ini — jatah hari itu memang sudah abis; dulu salah memakai `saldo ÷ sisa hari` dan sempat tiga saran serentak di tiga tempat), dan saat mencatat pengeluaran yang bikin lewat, muncul gerbang konfirmasi (5.2) yang memakai tabungan hemat menutup kelebihan. Uang masuk/keluar lain dan isi kantong **tidak** dihitung sebagai pengeluaran di kartu ini.

Untuk batas manual ada pula **proyeksi**: "cukup sampai {tanggal}, sisa ±{nominal}" atau "habis sekitar {tanggal}, kurang {k} hari, saran {nominal}/hari".

### 4.3 Kiriman selanjutnya

Mengelola jadwal kiriman rutin (transfer dari rumah).

- **Form tambah**: nominal + perkiraan tanggal datang (date picker) + catatan opsional.
- **Daftar kiriman** terurut rapi: yang **menunggu** duluan (tanggal terdekat di atas, termasuk yang lewat tanggal), yang sudah masuk ke bawah.
- **Konfirmasi ✓** — mencatat pemasukan sebesar nominal (terkait ke kiriman itu) lalu status jadi *sudah masuk*. Konfirmasi manual saja — tidak ada penandaan otomatis; kiriman yang lewat tanggal tetap "menunggu" sampai kamu konfirmasi (supaya tidak ada pemasukan palsu).
- **Hapus** — dengan konfirmasi.

Info yang menyertainya: "{n} hari lagi" untuk kiriman aktif; status **"Lewat tanggal"** merah untuk yang telat.

### 4.4 Dana darurat — kantong terpisah

Uang yang dipisahkan dari pegangan supaya tidak keburu terpakai:

- **Isi** — pindahkan uang dari pegangan ke kantong (saldo pegangan berkurang; melewati gerbang jaga saldo). Dialognya menampilkan **imbas live** sambil mengetik nominal.
- **Pakai** — catat pengeluaran darurat: kantong berkurang, pegangan tidak berubah (makanya aman dari godaan).
- **Tarik** — kembalikan uang kantong ke pegangan.
- **Riwayat kantong** — tiga jenis transaksi darurat di bagian bawah.

Nominal dibatasi: isi maksimal sebesar pegangan, pakai/tarik maksimal sebesar isi kantong — konsisten dengan aturan saldo tidak minus.

### 4.5 Tabungan hemat (rollover bulanan)

Layar ini **read-only** — tabungan terkumpul sendiri dari sisa jatah harian, dan pemakaiannya hanya terjadi lewat gerbang "lewat batas" (5.2).

- **Saldo tabungan** = (hemat bulan-bulan lalu yang terbekukan + hemat bulan berjalan) − seluruh pemakaian. Pemakaian mengurangi saldo selamanya, tidak hangus, dan sisanya terus terbawa ke bulan-bulan berikutnya.
- **Asal tabungan bulan ini** — rincian per hari: "jatah {a} • terpakai {b}", chip **+hemat {n}** untuk hari yang hemat, "habis" untuk hari boros. Hari tanpa catatan dihitung hemat penuh; hari boros tidak "mencuri" tabungan hari lain (per hari minimal 0).
- **Mulai pantau** — perhitungan hemat hanya dimulai dari aktivitas pertamamu (transaksi/kiriman/pemakaian tabungan paling awal), bukan dari awal bulan kosong.
- **Bulan tertutup** — begitu bulan berlalu, hemat bulan itu dibekukan ke `tabungan_riwayat` dan tidak dihitung ulang.
- **Pemakaian** — daftar catatan "kapan, berapa, untuk apa", 30 teratas.

Batas harian ≤ 0 → kartu "belum aktif" (atur batas dulu di Pengaturan).

### 4.6 Target beli

Rencana beli barang/jasa: **nama + budget + deadline opsional**.

- **Saran cerdas** berdasarkan status (`StatusSaran`):
  - *Siap beli* — saldo sudah cukup.
  - *Aman* — berdeadline, butuh nabung ±{n}/hari dan itu masih dalam kemampuan (sisa jatah di atas rata-rata belanja 7 hari, minimal Rp 1.000).
  - *Berat* — deadline terlalu mepet untuk kemampuanmu (tetap ditampilkan angka per hari yang dibutuhkan).
  - *Perlu waktu* — tanpa deadline: perkiraan tanggal realistis bisa terbeli dengan kemampuan sekarang.
- **Progress bar** warna mengikuti status; baris "Siap {a} dari {b}".
- **Tandai tercapai** — dialog berisi switch "catat sekarang sebagai pengeluaran" (default nyala) + **imbas** beli (termasuk hitungan harga beli yang memakan jatah hari ini). Bila dicatat, melewati gerbang jaga saldo. Target yang sudah tercapai tampil "selesai" tanpa progress/saran, dan **tidak lagi** menghitung "kurang Rp X".
- **Urutan**: yang masih berjalan duluan (deadline terdekat di atas, tanpa deadline menyusul), yang tercapai ke bawah.

### 4.7 Utang & ngutangin

Dua tab: **Ngutang** (aku berutang) dan **Ngutangin** (aku meminjamkan).

- **Form per tab**: siapa, nominal, catatan opsional, switch "punya target bayar" + tanggal (default +14 hari).
  - Catat **utang** → transaksi `utang_masuk`, saldo **nambah** (kamu dapat duit).
  - Catat **ngutangin** → transaksi `piutang_keluar`, saldo **berkurang** — lewat gerbang jaga saldo, dengan **imbas live** di form.
- **Lunasi ✓** — dialog konfirmasi dengan switch "catat pengeluaran/pemasukan sekarang" + **imbas** untuk bayar utang. Bayar utang = `utang_bayar` (saldo −, lewat gerbang jaga saldo); piutang dilunasi = `piutang_terima` (saldo +).
- **Status tile**: Lunas / Belum lunas / "Bayar sebelum {tanggal}" / **"Lewat tempo {tanggal}"** (merah tebal).
- **Urutan**: yang aktif duluan (jatuh tempo terdekat di atas, tanpa tempo menyusul), yang lunas ke bawah.
- **Hapus** — dengan konfirmasi bahaya.

### 4.8 Uang masuk / keluar lain

Satu menu (sejak v2.10 satu pintu, dulu dua kartu terpisah) membuka dialog dengan **SegmentedButton** masuk/keluar yang bisa diganti-ganti di dalam dialog:

- **Masuk** — hadiah, jualan, cashback, bonus: transaksi `masuk_lain`, saldo bertambah.
- **Keluar** — bayar kos, wifi, setor ke rumah: transaksi `keluar_lain`, saldo berkurang (lewat gerbang jaga saldo, dengan imbas live).
- Keduanya **tidak dihitung** sebagai pengeluaran di budget/kartu budget/statistik belanja — murni pergerakan uang di luar belanja harian.

### 4.9 Riwayat lengkap & ubah/hapus transaksi

- **Filter** (chip horizontal): Semua / Pengeluaran / Pemasukan / Kantong / Utang / Lainnya.
- **Ringkasan bulan berjalan**: total masuk (pemasukan + utang masuk + piutang terima + uang masuk lain) dan total keluar (pengeluaran + bayar utang + piutang keluar + uang keluar lain).
- **Dikelompokkan per tanggal** ("Hari ini", "Kemarin", atau tanggal lengkap), tarik-untuk-muat-ulang.
- **Tap transaksi** → lembar ubah/hapus (`lembar_edit_transaksi.dart`) dengan aturan keamanan data:
  - Jumlah & tanggal bisa diubah untuk semua jenis — saldo otomatis dihitung ulang.
  - Nama/catatan hanya untuk transaksi polos (bukan yang terkait kiriman/utang).
  - Kategori hanya untuk pengeluaran.
  - **Koreksi (setelan saldo) tidak bisa diedit — hanya dihapus** (menghapusnya tetap aman, saldo dihitung ulang dari sisa transaksi).
  - Mengubah tanggal menjaga jam asli transaksi. Rentang pickernya dibatasi (sejak v2.16): paling mundur 1 bulan atau tanggal asli (yang lebih tua dari dua-duanya), tidak bisa ke masa depan — supaya tanggal transaksi tidak "ngalor ngidul" menarik hitungan tabungan hemat ke belakang.
  - **Tabungan otomatis kembali** — bila transaksi yang dihapus/diubah itu yang bikin lewat batas (dan kelebihannya ditutup tabungan), pemakaian tabungan hari itu dipangkas otomatis sesuai kelebihan yang tersisa; snackbar memberi tahu berapa yang dikembalikan. Sejak v2.16, bulan tertutup yang terkena hapus/ubah juga **dihitung ulang hematnya** (kunci riwayatnya dibuka dulu) — menghapus transaksi nyasar (mis. struk salah baca ke tahun lalu) benar-benar membersihkan jejaknya di tabungan.

### 4.10 Laporan bulanan

Navigasi bulan (chevron kiri/kanan, tidak bisa melewati bulan berjalan). Isinya:

1. **Ringkasan** — total pengeluaran besar, rata-rata harian, jumlah transaksi, hari tanpa belanja, pemasukan.
2. **Tren harian** — grafik garis (fl_chart) per tanggal; ketuk titik untuk tooltip tanggal + nominal.
3. **Kalender pengeluaran** — peta warna per tanggal: abu = tidak belanja, pink muda = belanja dalam jatah, **merah pekat dengan angka putih = lewat jatah** (dipertajam di v2.9 karena versi lamanya nyaris tak terbedakan). Patokan warna = batas harian aktif saat ini. Ketuk tanggal untuk melihat nominalnya.
4. **Per kategori** — nominal + bar proporsi, terbesar dulu.
5. **Uang keluar lain** — daftar kos/wifi/setor dsb. sebagai bagian terpisah, tidak mencemari statistik belanja.
6. **Pengeluaran terbesar**.
7. **Vs bulan lalu** — naik/turun {p}%, plus "top bergerak": 3 kategori dengan perubahan terbesar.
8. **Ekspor PDF** (ikon di AppBar) — laporan berformat (warna brand, A4): total, statistik, perbandingan bulan, per kategori dengan bar, uang keluar lain, tren harian, pengeluaran terbesar. Dibagikan lewat lembar share Android sebagai `laporan-kosku-YYYY-MM.pdf`.
9. **Ekspor CSV buku kas** (di Pengaturan) — seluruh transaksi kronologis (terlama dulu): kolom Tanggal, Jam, Jenis, Kategori, Nama, Jumlah, Sumber; pemisah titik-koma + BOM UTF-8 supaya Excel Indonesia langsung rapi. Nama file `kosku-buku-kas-YYYYMMDD.csv`.

### 4.11 Input cepat, input bebas & suara

Tiga cara mencatat pengeluaran harian, semua di satu kartu di Home:

1. **Ketik bebas** — "ngopi 15rb", "belanja pokok 250rb kemarin". Sambil mengetik, parser lokal (offline, instan) menampilkan chip **pratinjau "Rp 15.000"** + label "kemarin". Tekan tombol ⚡ (atau enter) untuk mengisi form: Gemini memparse kalau online (lebih paham konteks), parser regex offline sebagai fallback. Hasil **selalu tampil di form dulu** untuk dicek sebelum disimpan.
2. **Suara** 🎤 — **tahan** tombol mic sambil bicara (ala voice note WhatsApp): transkrip mengalir live di bar perekaman lengkap dengan timer & bar level suara. **Lepas jari = otomatis diparse** ke form, tanpa tekan tombol apa pun. Geser ke kiri (atau sentuhan terlalu cepat / interupsi sistem) = rekaman dibuang, teks kolom dipulihkan. Maks 30 detik per tahanan.
3. **Manual** — isi nama (kategori tertebak otomatis selama kamu belum memilih sendiri) + harga + dropdown kategori + Simpan.

Penanda **"akan dicatat kemarin"** muncul bila hasil parse bertanggal kemarin — lengkap dengan tombol "kembalikan hari ini" supaya transaksi tidak nyasar tanggal. Sejak v2.16 offset hari dipagari **maksimal 7 hari ke belakang** ("minggu lalu" paling jauh): nilai aneh dari AI (mis. -300) tidak bisa menarik tanggal transaksi berbulan-bulan ke belakang.

Yang dipahami parser offline: satuan `rb/ribu/k` (×1.000) dan `jt/juta` (×1.000.000, desimal koma/titik boleh), pemisah ribuan titik/koma (`25.000`, `12,500`), **angka telanjang < 1000 dianggap ribuan** (`ngopi 15` = 15.000), angka bersatuan menang atas angka telanjang, kata "kemarin/kemaren" (tanggal mundur sehari), dan pembersihan kata pengisi ("aku udah beli...") dari nama. Parser lokal selalu menganggap input **pengeluaran** — deteksi arah masuk/keluar hanya ada di scan bukti transfer.

### 4.12 Pengaturan & Akun (satu pintu)

Satu layar untuk semua pengaturan — kartu-kartunya atas ke bawah:

1. **Akun & Sinkronisasi** (hanya muncul kalau Firebase aktif):
   - Belum login → tombol **Masuk / Daftar** (ke `AuthScreen`: tab Masuk/Daftar, lupa sandi, boleh "pakai offline dulu").
   - Sudah login → email + ikon terverifikasi/belum, tombol **Keluar akun** (konfirmasi), banner verifikasi email (kirim ulang / cek lagi) bila belum verifikasi.
   - **Baris status sinkronisasi** — Sinkron terakhir {jam} / antrian {n} / offline / error / lokal saja.
   - **Sinkron sekarang** — flush antrian manual.
   - **Masa tenggang offline** (dropdown 3/7/14/30 hari) — berapa lama boleh offline sebelum aplikasi terkunci.
   - **Auto-wipe** (switch, aktifnya perlu konfirmasi bahaya) — bila terkunci, data lokal dihapus (cloud tetap aman).
2. **Bahasa** — chip Indonesia / English, langsung berubah tanpa restart, pilihan ikut tersinkron antar perangkat.
3. **Pengingat** — switch pengingat harian; **jam pagi & jam malam bisa diatur sendiri** lewat time picker (default 08.00 & 20.00; ganti jam = seluruh jadwal dipasang ulang otomatis); tombol **Kirim notifikasi uji** (satu langsung + satu terjadwal 1 menit lagi).
4. **Uang** — batas harian manual (+ **pratinjau proyeksi live** saat mengetik: cukup sampai kapan / kurang berapa hari / saran batas), **ekspor CSV buku kas**, **atur saldo pegangan** (dialog nominal → transaksi koreksi).
5. **Pindai** — hanya muncul bila build **tanpa** kunci Gemini: penjelasan kenapa fitur scan nonaktif.
6. **Data** — tombol merah **Hapus semua data** (konfirmasi bahaya; bila login, **seluruh dokumen di cloud ikut dihapus betulan** — koleksi disapu kosong termasuk sisa-sisa lama; kalau sedang offline, pembersihan diulang otomatis begitu online dan snackbar jujur memberi tahu).
7. **Tentang**.

### 4.13 Menerima share dari aplikasi lain

Di Android, kosku terdaftar sebagai share target:

- **Share foto** (dari WhatsApp/galeri/dll.) → langsung terbuka di **ScanScreen mode struk** dengan foto itu.
- **Share teks** → langsung terisi di **kolom input bebas** Home dan otomatis diparse.

---

## 5. Aturan uang: saldo tidak boleh minus

Aturan paling keras di kosku, dijaga berlapis:

### 5.1 Gerbang jaga saldo (`gerbangJagaSaldo`)

Semua aksi yang **mengurangi** pegangan melewatinya: pengeluaran (manual/scan/input bebas), uang keluar lain, isi kantong darurat, beli target, bayar utang, ngutangin. Keputusannya (`HasilJagaSaldo`):

- **`kurang`** — sisa saldo jadi minus → **ditolak keras**, tidak ada jalur "tetap simpan". Snackbar menyarankan catat uang masuk dulu atau kecilkan nominal.
- **`kritis`** — sisa masih positif tapi di bawah ambang aman (rata-rata belanja 7 hari × sisa hari, minimal 10% saldo) **dan** nominalnya ≥ 50% saldo → dialog peringatan ("sisanya cuma {n}, rata-rata belanjamu {x}/hari, sisa {d} hari") + imbas + tombol "Tetap lanjut" (keputusan tetap di tangan user).
- **`aman`** — langsung lanjut.

Baris terakhir pertahanan: `tambahPengeluaran` sendiri menolak (return `false`, tanpa menyimpan) bila saldo berubah di antara konfirmasi dan penyimpanan (misal karena hasil sync masuk duluan).

### 5.2 Gerbang lewat batas (`gerbangLewatBatas`)

Jalan sebelum mencatat pengeluaran yang membuat total harian **lewat batas**:

- Transaksi bertanggal bukan hari ini (hasil parse "kemarin" / tanggal struk lama) **dilewati** — peringatannya salah konteks.
- Ada saldo tabungan → **tabungan wajib dipakai duluan**: satu-satunya aksi adalah **"Catat & pakai tabungan"** (menutup penuh kelebihan bila cukup; kalau tabungan kurang, seluruhnya dipakai dan sisanya tetap dihitung lewat batas). Tidak ada lagi opsi "tetap catat tanpa tabungan" — kelebihan jatah memang wajib ditutup tabungan dulu. Pesannya menyertakan imbas.
- Tanpa tabungan sama sekali → konfirmasi "tetap simpan?" + imbas.

Pemakaian tabungan yang disetujui tercatat di daftar pemakaian (catatan, waktu, nominal) dan mengurangi saldo tabungan selamanya — **kecuali transaksinya dihapus/diubah** hingga kelebihannya hilang: selisih pemakaian yang tidak lagi diperlukan otomatis dikembalikan ke saldo tabungan (`_kembalikanTabunganBerlebih` di `app_state.dart`).

### 5.3 Konsistensi saldo

Saldo di tabel `saldo` adalah **materialisasi** buku kas: setiap catat transaksi meng-update saldo dalam satu transaksi SQLite yang atomik (bersama insert transaksinya), dan setelah edit/hapus/merge cloud saldo dihitung ulang penuh dari seluruh transaksi hidup. Tidak ada jalur untuk "saldo lepas dari buku kas".

---

## 6. Cara aplikasi menghitung uang

Semua formula ada di `lib/utils/hitung.dart` (dan diuji di `test/hitung_test.dart`).

### 6.1 Sisa hari (`sisaHariMenuju`)

- Ada kiriman aktif → `tanggal kiriman − hari ini` (minimal 1; tanggal lewat tetap dihitung 1, karena yang telat sudah diberitakan kartu perhatian).
- Tidak ada kiriman / kiriman telat → `akhir bulan − hari ini + 1` (minimal 1) — patokan pindah ke akhir bulan.

### 6.2 Budget harian otomatis (`budgetHarian`)

`saldo ≤ 0 → 0`, selain itu `saldo ÷ sisa hari` (dibulatkan ke bawah). Batas manual (Pengaturan) selalu menang atas otomatis.

### 6.3 Proyeksi batas manual (`proyeksiBatas`)

Menjawab "kalau aku jalan-jalan pakai batas ini, uangku cukup sampai kapan?":

- `kembali = min(terpakaiHariIni, batas)` — **pengeluaran hari ini yang masih di dalam batas tidak mengurangi proyeksi** (jatah hari ini sudah dihitung penuh lewat `batas × sisa hari`); hanya kelebihan di atas batas yang memotong.
- `efektif = saldo + kembali`; `hariBertahan = efektif ÷ batas`.
- `aman` bila `hariBertahan ≥ sisaHari`; kalau kurang: tanggal habis, jumlah hari kurang, dan **saran batas** dihitung dua kas: pengeluaran hari ini masih muat di batas saran → `(saldo + terpakaiHariIni) ÷ sisaHari` (jatah hari ini dihitung penuh); sudah lewat → hari itu dianggap selesai → `saldo ÷ (sisaHari − 1)`. (Sebelum v2.15 saran selalu `efektif ÷ sisaHari`, yang di hari lewat batas "mengembalikan" jatah lama padahal sudah keburu diboroskan — contoh saldo 313.811, terpakai 300.000, batas 40.000, sisa 13 hari: dulu 27.216, sekarang 26.150.)

Contoh (dari kode): saldo 280rb, batas 50rb, sisa 7 hari, terpakai 30rb → efektif 310rb → bertahan 6 hari → kurang 1 hari, saran 44.285/hari.

### 6.4 Tabungan hemat bulanan (`hematBulan`)

Per hari dari `max(awal bulan, mulai pantau)` sampai hari terakhir yang terpantau: `max(0, batas − pengeluaran hari itu)` lalu dijumlahkan. Hari tanpa catatan = hemat penuh; hari boros tidak mencuri tabungan hari lain; batas ≤ 0 → 0. Bulan yang sudah lewat dibekukan ke `tabungan_riwayat` (tidak dihitung ulang). **Saldo tabungan** = semua hemat − semua pemakaian (dipangkas di 0).

### 6.5 Saran target (`hitungSaranTarget`)

`kurang = nominal − saldo`; `kemampuan = max(batas aktif − rata-rata belanja 7 hari, 1000)`. Berdeadline: `per hari = kurang ÷ sisa hari` → *aman* bila ≤ kemampuan, else *berat*. Tanpa deadline: `hari = kurang ÷ kemampuan` → perkiraan tanggal terbeli (*perlu waktu*). `kurang ≤ 0` → *siap beli*.

### 6.6 Tebak kategori (`tebakKategori`)

Kamus kata kunci Indonesia per kategori — contoh: `gojek/ojek/bensin/parkir/krl` → transport; `ngopi/nasi/bakso/warung/boba` → makan_minum; `listrik/wifi/pulsa/kos` → tagihan_rumah; `indomaret/beras/sabun` → belanja_pokok; `netflix/steam/bioskop` → hiburan; `obat/dokter/apotek` → kesehatan; `buku/ukt/fotokopi` → pendidikan. Tidak cocok → `lain_lain`.

### 6.7 Imbas (`teksImbas`)

Pratinjau dampak pengeluaran sebesar {n}:

- Batas **otomatis** → "pegangan sisanya {x}, batas barumu {b}/hari" (batas memang ikut berubah saat saldo berubah).
- Batas **manual** → proyeksi batas dengan nominal itu dimasukkan: "cukup sampai {tanggal}, sisa ±{n}" atau "habis sekitar {tanggal}, {k} hari kurang, saran {r}/hari".

---

## 7. Pengingat & notifikasi

Semua lewat `flutter_local_notifications`, satu channel: id `'kosku'`, importance/priority high. Filosofinya: notifikasi adalah bonus — semua panggilan dibungkus try/catch, izin ditolak tidak pernah mengganggu aplikasi.

### 7.1 Matriks pengingat

| Pengingat | Kapan muncul | Jam | ID | Catatan |
| --- | --- | --- | --- | --- |
| **"Sudah catat pengeluaran hari ini?"** | Setiap hari, berulang di jam yang sama | jam malam (default **20.00**, bisa diatur) | 1 | On/off lewat switch "Pengingat harian" |
| **Kiriman semestinya datang** | Pagi di tanggal kiriman berstatus *menunggu* | jam pagi (default **08.00**, bisa diatur) | 100 + id kiriman | Judul memuat nominal; dijadwalkan maks. 30 hari ke depan |
| **Utang/piutang H-1** | Pagi sehari sebelum jatuh tempo | jam pagi | 100.000 + id utang | "Besok jatuh tempo: {pihak}" |
| **Utang/piutang hari-H** | Pagi di hari jatuh tempo sendiri | jam pagi | 150.000 + id utang | "Hari ini jatuh tempo: {pihak}" |
| **Target beli H-1** | Pagi sehari sebelum deadline | jam pagi | 200.000 + id target | Isi "Kurang Rp X" (dihitung dari saldo saat penjadwalan) atau "Uangmu sudah cukup" |
| **Uji notifikasi** | Manual dari Pengaturan: satu langsung + satu 1 menit lagi | — | 2 dan 3 | Menguji izin + channel + jalur alarm terjadwal sekaligus |

Jam pagi dipakai untuk semua event bertanggal; jam malam khusus pengingat malam harian. **Kedua jam bisa diubah sendiri** dari Pengaturan (time picker) — mengubah jam memasang ulang seluruh jadwal otomatis. Semua waktu mengikuti **zona waktu HP** (bukan zona tetap Indonesia), jadi aman saat pindah waktu/tempat.

### 7.2 Cara kerja penjadwalan

- `NotifikasiService.sinkronJadwal(...)` dipanggil di akhir setiap `muatSemua()` (yaitu setelah tiap aksi/ubah data) dan saat jam/on-off diubah. **Idempoten lewat tanda tangan**: kalau tidak ada yang berubah (harian, bahasa, jam, saldo, daftar kiriman/utang/target), tidak melakukan apa pun.
- Event mendadak (dicatat hari ini, setelah jam pagi lewat) tetap diingatkan: slot dimajukan ke **sekarang + 5 menit** (asal sebelum jam malam).
- Slot yang tidak dipakai dibatalkan (penyapuan 500 slot per rentang ID di sesi pertama; setelah itu hanya yang pernah dipasang sendiri).

### 7.3 Izin Android & syarat teknis

| Izin / syarat | Untuk apa | Kapan diminta |
| --- | --- | --- |
| `POST_NOTIFICATIONS` (Android 13+) | Menampilkan notifikasi | Sekali, otomatis saat aplikasi siap |
| `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` (Android 12+) | Alarm tepat waktu | Hanya lewat tombol **Kirim notifikasi uji** — supaya tidak membawa user ke layar setelan setiap startup |
| `RECEIVE_BOOT_COMPLETED` + receiver boot | Memasang ulang jadwal setelah HP restart / aplikasi ter-update | Tidak perlu minta — receiver di manifest |
| **Core library desugaring** (`build.gradle`) | Syarat `zonedSchedule` di Android lama | Sudah aktif di folder `android/` bawaan |

Tanpa izin alarm exact, pengingat **tetap jalan** hanya saja bisa telat ±15 menit (fallback `inexactAllowWhileIdle`). Tanpa receiver boot (mis. folder `android/` dibuat ulang tanpa manifest bawaan), semua jadwal hilang setelah restart — itulah kenapa sejak v2.12 folder `android/` lengkap ikut dalam paket.

Kalau pengingat tidak muncul: (1) cek izin notifikasi di setelan HP, (2) tekan **Kirim notifikasi uji** dan setujui izin "Alarms & reminders" yang ditawarkan, (3) pastikan folder `android/` yang dipakai adalah bawaan paket (receiver + desugaring ada).

---

## 8. Akun, sinkronisasi & keamanan

### 8.1 Akun (Firebase Auth, email + sandi)

- **Daftar** → akun dibuat + email verifikasi langsung dikirim.
- **Masuk** → bila email belum diverifikasi, diarahkan ke **layar verifikasi**: polling otomatis tiap 5 detik, tombol kirim ulang (cooldown 60 detik, anti spam), tombol cek manual. Sinkronisasi baru menyala **setelah email diverifikasi** — ini mencegah data tersinkron ke akun yang belum pasti milikmu.
- **Lupa sandi** → email reset dikirim.
- **Keluar akun** → sync berhenti; data lokal tetap ada.
- Semua pesan error Firebase (sandi salah, email terpakai, koneksi, dll.) diterjemahkan ke bahasa UI aktif.

Semua fitur akun **opsional**: "pakai offline dulu" selalu tersedia, dan tanpa Firebase terkonfigurasi pun aplikasi jalan penuh (kartu Akun & Sinkronisasi tidak muncul).

### 8.2 Model sinkronisasi: lokal dulu, cloud belakangan

1. **Tulis lokal** (instan, tanpa internet): setiap baris baru otomatis diberi `cloud_id` (UUID) + stempel `diubah_pada` (epoch ms), lalu **mengantri** di tabel `antrian` (JSON baris penuh; operasi baru menimpa operasi lama untuk dokumen yang sama).
2. **Pemicu kirim**: setelah tiap aksi (debounce), saat koneksi kembali online, saat login/verifikasi, atau manual lewat **Sinkron sekarang**.
3. **Merge pertama** (sekali per akun/perangkat): seluruh dokumen cloud diunduh dan dibandingkan per `cloud_id` dengan baris lokal — **last-write-wins** via `diubah_pada`: yang lebih baru menang, dari arah mana pun. Setelahnya saldo dihitung ulang.
4. **Listener real-time**: perubahan dari perangkat lain muncul sendiri (dokumen yang lebih baru diterapkan; **dokumen yang terhapus di cloud → baris lokal ikut dihapus** — kecuali masih ada edit lokal yang belum terkirim, edit itulah yang menang LWW; tulisan echo sendiri diabaikan; satu dokumen rusak tidak menggagalkan yang lain).
5. **Flush**: antrian dikirim per batch 400 dokumen lewat `WriteBatch` — baris hidup jadi `set`, **baris terhapus jadi `delete` betulan**. Tiap kirim berhasil juga memperbarui `last_auth_ok` (lihat 8.5).
6. **Penghapusan** (sejak v2.17.1): lokal = tombstone (`dihapus: 1`, disimpan 30 hari supaya tidak tertimpa merge); **cloud = dokumen dihapus betulan** — sebelumnya dokumen hanya ditandai `dihapus: 1` sehingga menumpuk selamanya di console dan isinya masih terbaca. Perangkat lain diberi tahu lewat event `removed`. **"Hapus semua data"** menyapu seluruh koleksi cloud (`bersihkanCloudPenuh`) termasuk dokumen yang tidak punya baris lokal lagi; kalau sweep gagal (offline), flag `reset_cloud_pending` mengulanginya otomatis begitu online. Tiap sync menyala, **penyapu kecil** juga membersihkan dokumen `dihapus: 1` peninggalan versi lama (khusus `pengaturan`: yang sudah lewat 30 hari — tombstone kecil `nilai: null` itu tetap diperlukan sebagai sinyal LWW antar perangkat selama masa itu).

### 8.3 Status sinkronisasi

`lokalSaja` (tanpa akun/Firebase) · `offline` (ada akun, sedang offline — antrian disimpan) · `antri` (online, ada {n} perubahan belum terkirim) · `sinkron` (online, antrian kosong) · `error` (online tapi gagal — mis. aturan Firestore belum diterapkan). Status + jumlah antrian + waktu sinkron terakhir tampil di kartu Akun & Sinkronisasi.

### 8.4 Yang ikut tersinkron

Empat tabel data (transaksi, kiriman, target, utang) + pengaturan pilihan: `sudah_setup`, `batas_harian`, `model_gemini`, `bahasa`, `tabungan_terpakai`, `tabungan_riwayat`. Preferensi perangkat (pengingat, jam notifikasi, masa tenggang, auto-wipe, sambutan) **tidak** ikut — memang beda kebutuhan per perangkat. **API key Gemini tidak pernah tersinkron** dan tidak tersimpan di database (lihat 8.7).

### 8.5 Masa tenggang offline (grace period) & layar kunci

`last_auth_ok` = terakhir kali kamu terverifikasi online (login sukses atau flush berhasil). Kalau HP offline lebih lama dari **masa tenggang** (default 7 hari; opsi 3/7/14/30):

- Aplikasi **terkunci** (layar kunci; data lokal tetap utuh) sampai kamu masuk online lagi — masuk sukses membuka kunci dan me-reset masa tenggang.
- **Auto-wipe aktif** (opsional, default mati): saat terkunci, data lokal **dihapus** demi keamanan — data cloud tetap utuh dan dipulihkan otomatis lewat merge saat masuk online berikutnya. Mengaktifkannya butuh konfirmasi peringatan bahaya.

### 8.6 Aturan keamanan Firestore

`firestore.rules` (siap tempel ke Console Firebase):

```
match /users/{uid}/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
}
match /{document=**} { allow read, write: if false; }
```

Hanya pemilik akun (login, uid cocok) yang bisa membaca/menulis dokumennya sendiri; semua path lain ditolak eksplisit.

### 8.7 Keamanan data & API key

- **Tidak ada rahasia di SQLite**: kunci Gemini dibundel saat build lewat `--dart-define` (`kunci_env.dart`) — tidak ada UI memasukkan key, key tidak pernah tersimpan di perangkat, tidak ikut sync. (Catatan jujur: nilai tetap terkompilasi di APK — disarankan membatasi key di Google Cloud Console ke package name + SHA-1.)
- **Pool 2 kunci dengan rotasi otomatis**: `GeminiKeyPool` memakai round-robin; kunci yang kena limit kuota (429) atau ditolak (401/403) diistirahatkan 30 menit, otomatis lanjut ke kunci berikutnya.
- **Sanitasi input AI**: teks user dibersihkan dari karakter kontrol dan dipangkas (anti prompt injection); output AI di-clamp (nominal maks Rp 999 miliar, string dipangkas).
- **Aplikasi tahan data rusak**: penerapan dokumen cloud per-dokumen dibungkus try/catch; satu data rusak tidak merusak yang lain.

### 8.8 Verifikasi & ketahanan offline lain

- Scan dan input bebas punya **fallback offline**: tanpa kunci Gemini, input bebas otomatis pakai parser lokal; layar scan menampilkan penjelasan kenapa fiturnya nonaktif.
- Model Gemini default tertulis `gemini-3.5-flash-lite` (bisa diganti lewat kunci pengaturan `model_gemini`; ikut sync).

---

## 9. Struktur file lengkap

Peta lengkap proyek beserta tanggung jawab tiap berkas. Total 51 file Dart di `lib/` (±15.500 baris), ditambah platform Android, aset, dan pengujian.

### 9.1 Root proyek

```
kosku/
├── lib/                     # seluruh kode Dart (lihat 9.2–9.7)
├── android/                 # proyek Android SIAP PAKAI (sejak v2.12; setelah
│                            # `flutterfire configure` memuat juga
│                            # `app/google-services.json` — aman di-commit)
├── assets/                  # logo.png (splash/sambutan), logo_icon.png,
│                            # logo_adaptive_fg.png (ikon launcher)
├── test/                    # 4 file uji otomatis (lihat bagian 14)
├── android_patch/           # REFERENSI saja: manifest cadangan, snippet
│                            # desugaring, ikon res/ semua density, README.
│                            # Tidak dipakai build — folder android/ yang
│                            # sebenarnya sudah lengkap.
├── pubspec.yaml             # nama, versi, dependensi, aset, konfigurasi ikon
├── pubspec.lock             # kunci versi dependensi
├── firestore.rules          # aturan keamanan Firestore (siap tempel)
├── firebase.json            # Firebase CLI — muncul setelah proyek dihubungkan;
│                            # dipakai `firebase deploy --only firestore:rules`
├── analysis_options.yaml    # linter (flutter_lints; build/** dikecualikan)
├── README.md                # ringkasan + instalasi cepat (menautkan dokumen ini)
├── DOKUMENTASI.md           # dokumen ini
└── .gitignore
```

### 9.2 `lib/` — akar

| File | Tanggung jawab |
| --- | --- |
| `main.dart` | Titik masuk: binding, format tanggal lokal, **Firebase opsional** (try/catch → mode lokal), `AppState` + `muatSemua()`, service share (Android), `runApp`, lalu menyiapkan notifikasi. Widget `KoskuApp`: tema dusty pink, dukungan lokal id/en, dan **urutan gerbang** splash → kunci → sambutan → Home. |
| `firebase_options.dart` | Di paket sumber berupa **STUB** (melempar `UnsupportedError`) supaya proyek tetap bisa dikompilasi tanpa Firebase; di proyek yang berjalan sudah ditimpa hasil `flutterfire configure` (isinya project ID + konfigurasi API — bukan rahasia, aman di-commit). |

### 9.3 `lib/models/` — model data (4 file)

| File | Isi |
| --- | --- |
| `transaksi.dart` | `Transaksi` (id, jenis, jumlah, kategori?, catatan?, sumber, terkaitId?, dibuatPada, cloudId?, dihapus, diubahPada) + `enum JenisTransaksi` (12 nilai, lihat bagian 2) + `enum KategoriPengeluaran` (8 nilai) + efek saldo (`efekPegangan`/`efekKantong`/`tandaTampil`). |
| `kiriman.dart` | `Kiriman` (nominal, tanggalDatang, catatan?, status menunggu/masuk, …) + `enum StatusKiriman`. Tanggal disimpan `yyyy-MM-dd`. |
| `target.dart` | `TargetBeli` (nama, nominal, tanggal? = deadline, status aktif/tercapai, …) + `enum StatusTarget`. |
| `utang.dart` | `Utang` (arah ngutang/ngutangin, pihak, nominal, jatuhTempo?, catatan?, status aktif/lunas, …) + `enum ArahUtang` + `enum StatusUtang`. |

Semua model punya `keMap()`/`dariMap()` (kolom SQLite) dan membawa trio sync: `cloud_id`, `dihapus`, `diubah_pada`.

### 9.4 `lib/db/` — database lokal

| File | Isi |
| --- | --- |
| `database_helper.dart` | Satu-satunya gerbang SQLite (`saku.db` v2, singleton). Membuat 7 tabel (lihat bagian 10) + migrasi v1→v2. Mekanisme inti: `_insertLokal`/`_updateLokal`/`_tombstone` (semua tulis user otomatis mengantri ke tabel `antrian`), metode `*DariCloud` untuk tulis dari cloud (tanpa antri), `catatTransaksi` (insert + update saldo atomik dalam satu transaksi SQLite), `hitungUlangSaldo` (re-materialisasi dari buku kas), kueri `semuaX` dengan **urutan rapi** (kiriman: menunggu dulu + tanggal terdekat; utang: aktif dulu + tempo terdekat, lunas bawah; target: berjalan dulu + deadline terdekat, tercapai bawah), tabel `pengaturan` key-value (kunci tersinkron diantri), `hapusBarisDariCloud` + `adaOpAntrian` (jembatan event hapus dari arah cloud), dan `hapusSemua({kirimTombstone})` — `true` untuk hapus user (antrian dikirim sebagai DELETE + SyncService menyapu seluruh cloud), `false` untuk wipe lokal keamanan (cloud tetap). |

### 9.5 `lib/providers/` — state terpusat

| File | Isi |
| --- | --- |
| `app_state.dart` (±1.500 baris) | Otak aplikasi (`ChangeNotifier`). Memegang seluruh state (saldo, daftar transaksi/kiriman/target/utang, pengaturan, status akun & sync, slot share). **Setiap aksi user** (tambah/ubah/hapus transaksi, konfirmasi kiriman, lunasi utang, isi kantong, simpan pengaturan, dst.) menulis lewat sini → database → `muatSemua()` (reload + hitung turunan + pasang ulang pengingat). Getter hitungan penting: `sisaHari`, `batasAktif`, `budgetHarianOtomatis`, `terpakaiHariIni`, `kelebihanHariIni`, `tabunganSaldo`, `jagaSaldo()`, `teksImbas()`, `saranUntuk()`, `daftarPerhatian`, serta pengembalian tabungan otomatis `_kembalikanTabunganBerlebih()`. Juga: gerbang kunci offline (`cekKunciOffline`), aksi akun (masuk/daftar/verifikasi/keluar/sinkronSekarang), dan `panggilGemini<R>()` (lewat pool kunci). |

### 9.6 `lib/services/` — layanan (7 file)

| File | Tanggung jawab |
| --- | --- |
| `notifikasi_service.dart` | Pengingat Android (lihat bagian 7): satu channel, ID stabil per kategori, jadwal idempoten bertanda tangan, slot pagi/malam bisa diatur, uji notifikasi, penyapu slot, pasang zona waktu HP, izin (notifikasi otomatis; alarm exact lewat tombol uji). |
| `sync_service.dart` | Mesin sync (lihat 8.2): `kick()` debounce, `mulai(uid)` + merge pertama LWW, listener snapshot real-time (termasuk event `removed` → hapus baris lokal), `flush()` batch 400 (baris hidup = `set`, baris terhapus = **DELETE betulan**), `bersihkanCloudPenuh()` (sweep "hapus semua data" + retry otomatis via `reset_cloud_pending`), penyapu dokumen tombstone lama tiap sync menyala, deteksi offline vs error lewat konektivitas, pembaruan `last_sync` + `last_auth_ok`. `enum StatusSinkron` ada di sini. |
| `auth_service.dart` | Pembungkus FirebaseAuth: daftar/masuk/keluar, kirim email verifikasi, reset sandi, reload profil, stream perubahan user, dan penerjemah error Firebase ke bahasa UI. |
| `gemini_service.dart` | Klien REST Gemini (`generateContent`, JSON, temperature 0.1): `bacaStruk` (struk belanja Indonesia + saran kategori), `bacaBuktiTf` (bukti transfer bank/e-wallet, arah masuk/keluar), `bacaTeksBebas` (parser catatan harian). Pemetaan error lengkap (offline, key, kuota, model, dsb.), sanitasi input user, clamping output. **`GeminiKeyPool`**: rotasi 2 kunci round-robin + masa istirahat 30 menit untuk kunci yang kena 429/401/403. |
| `nl_input_service.dart` | Orkestrator input bebas: Gemini dulu (kalau ada kunci), gagal/offline → parser lokal regex. Kategori `lain_lain` dari Gemini dianggap "tidak yakin". |
| `suara_service.dart` | Speech-to-text `id-ID`, mode tahan-untuk-bicara: partial results live, level suara, `berhenti()` balikin teks final, `batal()` buang rekaman, maks 30 detik. |
| `bagikan_service.dart` | Menerima share dari aplikasi lain (Android): foto → scan struk, teks → input bebas; menangani cold start maupun aplikasi sedang jalan. |

### 9.7 `lib/utils/` — utilitas (11 file)

| File | Isi |
| --- | --- |
| `teks.dart` | Kamus dwibahasa ±474 kunci dalam 26 seksi: `T.t('kunci')` dan `T.f('kunci', {params})`; bahasa tersimpan, default `id`; kunci tak dikenal dikembalikan apa adanya (memudahkan debug). |
| `format.dart` | `ribuan`/`rp`/`rpTanda`, formatter input ribuan, format tanggal/jam (lengkap → HH:mm), `parseRupiah`, label kategori/jenis, `judulTransaksi`, dan **`tebakKategori`** (kamus kata kunci Indonesia per kategori). |
| `hitung.dart` | Semua formula uang (lihat bagian 6): `sisaHariMenuju`, `budgetHarian`, `proyeksiBatas`, `hematBulan`, `hitungSaranTarget` + `enum StatusSaran`. |
| `agregat.dart` | `ringkasBulan` → `RingkasanBulan` (total, rata-harian, hari tanpa belanja, per kategori, per hari, terbesar, uang keluar lain terpisah) + `deltaKategori` bulan-ke-bulan. |
| `dialog.dart` | `konfirmasi` (dialog generik, varian bahaya), `pilihTanggal`, **`gerbangLewatBatas`** (tabungan wajib dipakai duluan — satu aksi), **`gerbangJagaSaldo`** (tolak minus / konfirmasi kritis). |
| `parser_lokal.dart` | Parser NL offline (lihat 4.11): satuan rb/k/jt/juta, pemisah ribuan, angka telanjang < 1000 = ribuan, "kemarin", pembersih kata pengisi, tebak kategori. |
| `laporan_pdf.dart` | Generator PDF laporan bulanan (paket `pdf`): tema brand, statistik, per kategori + bar, uang keluar lain, tren harian, terbesar. |
| `ekspor_csv.dart` | Ekspor buku kas → CSV (titik-koma, BOM UTF-8, quote) + lembar bagikan Android. |
| `tema.dart` | Tema Material 3 dusty pink + cream (`WarnaKosku`); tanpa hijau — status positif pakai keluarga pink. |
| `kunci_env.dart` | Kunci Gemini via `--dart-define` (`GEMINI_API_KEY_1` wajib, `GEMINI_API_KEY_2` opsional), `tersedia`, daftar kunci. |
| `zona.dart` | Utilitas "jam selalu WIB" — **saat ini tidak dipakai** (aplikasi mengikuti zona waktu HP; lihat 7). Disimpan sebagai cadangan. |

### 9.8 `lib/screens/` — 15 layar

| File | Layar |
| --- | --- |
| `home_screen.dart` | Layar utama: AppBar (menu pojok kanan — sejak v2.14 tanpa ikon sync terpisah), FAB Scan, dan susunan kartu Home. |
| `kiriman_screen.dart` | Jadwal kiriman: form tambah, daftar terurut, konfirmasi ✓, hapus. |
| `dana_darurat_screen.dart` | Kantong darurat: Isi/Pakai/Tarik (dialog nominal + imbas + batas maksimal), riwayat kantong. |
| `tabungan_screen.dart` | Tabungan hemat: saldo, rincian asal per hari, riwayat pemakaian. Read-only. |
| `target_screen.dart` | Target beli: form, progress + warna status, dialog tercapai (catat pengeluaran + imbas). |
| `utang_screen.dart` | Utang & ngutangin: 2 tab, form per arah (ngutangin + imbas), tile status tempo, dialog lunas (+ imbas + gerbang). |
| `riwayat_screen.dart` | Riwayat lengkap: filter chip, ringkasan bulan, kelompok per tanggal. |
| `laporan_screen.dart` | Laporan bulanan: navigasi bulan, ringkasan, grafik tren, kalender pengeluaran, per kategori, vs bulan lalu, ekspor PDF. |
| `scan_screen.dart` | Scan struk / bukti transfer (lihat 4.1): pilih/kamera foto, crop (uCrop), baca Gemini, form review (**tanggal default = tanggal yang tercetak di dokumen** — kalau tidak terbaca / di luar jendela wajar [tahun lalu, > 1 bulan, masa depan] pakai hari ini; **jam dokumen dipakai kalau ada, kalau tidak jam saat scan** — bukan lagi 00:00; satu ketuk untuk bolak-balik), simpan lewat gerbang. |
| `auth_screen.dart` | Masuk/Daftar (tab), lupa sandi, "pakai offline dulu". |
| `verifikasi_email_screen.dart` | Menunggu verifikasi email: polling 5 detik, kirim ulang ber-cooldown, cek manual, keluar akun. |
| `pengaturan_screen.dart` | **Pengaturan & Akun** (satu pintu, lihat 4.12): kartu akun & sync, bahasa, pengingat (switch + 2 time picker jam + uji notifikasi), uang (batas + proyeksi live + CSV + atur saldo), pindai (info bila tanpa kunci), data (hapus semua), tentang. |
| `layar_splash.dart` | Splash tiap sesi (animasi logo 1,5 detik) + layar tunggu data. |
| `layar_sambutan.dart` | Sambutan sekali di awal: logo, tagline, 4 poin fitur, tombol Mulai. |
| `layar_kunci.dart` | Layar kunci sesi (lihat 8.5): ikon + pesan sesuai kondisi (data terhapus lokal / tidak), tombol Masuk. |

### 9.9 `lib/widgets/` — 10 komponen

| File | Komponen |
| --- | --- |
| `kartu_selamat_datang.dart` | Kartu onboarding: input saldo pertama → `aturSaldoAwal`. |
| `kartu_saldo.dart` | Kartu saldo utama: pegangan, pil kantong & total, info kiriman berikutnya. |
| `kartu_perhatian.dart` | Kartu "Perlu perhatian" (render `daftarPerhatian`). |
| `kartu_budget.dart` | Kartu budget harian: terpakai/jatah, progress, sumber batas, proyeksi manual (disembunyikan saat lewat batas), dan satu-satunya saran jatah baru saat lewat batas. |
| `kartu_input_cepat.dart` | Input cepat: baris input bebas + ⚡ + 🎤, pratinjau nominal live, penanda "kemarin", form nama/harga/kategori, simpan lewat gerbang. |
| `dialog_uang_lain.dart` | Dialog uang masuk/keluar lain: segmented masuk/keluar, nominal + catatan, imbas live untuk keluar. |
| `tile_transaksi.dart` | Satu baris transaksi (ikon per jenis, judul, jam + kategori, nominal bertanda). |
| `lembar_edit_transaksi.dart` | Lembar ubah/hapus transaksi (aturan keamanan data lihat 4.9). |
| `bagian.dart` | Helper `judulSection` + `kartuKosong`. |
| `memuat.dart` | `PemuatKosku` — pemuat brand (lingkaran pink + ikon kantong berdenyut). |

> Catatan sejarah: `kartu_status_sync.dart` (ikon status sync di AppBar Home) **dihapus di v2.14** saat akun + sinkronisasi + pengaturan digabung jadi satu menu.

### 9.10 `android/` — proyek Android siap pakai

| File / bagian | Isi penting |
| --- | --- |
| `app/src/main/AndroidManifest.xml` | Izin: INTERNET, CAMERA, RECORD_AUDIO, READ_EXTERNAL_STORAGE (≤32) + READ_MEDIA_IMAGES, WRITE_EXTERNAL_STORAGE (≤29), POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM + USE_EXACT_ALARM, RECEIVE_BOOT_COMPLETED. MainActivity launcher + **share target** (SEND image/* & text/plain, SEND_MULTIPLE). Receiver `ScheduledNotificationReceiver` + `ScheduledNotificationBootReceiver` (BOOT_COMPLETED, MY_PACKAGE_REPLACED, QUICKBOOT). Activity uCrop. `<queries>` speech & PROCESS_TEXT. |
| `app/build.gradle.kts` | `applicationId com.kosku.kosku`; SDK mengikuti Flutter (minSdk bawaan 21); **core library desugaring aktif** + `desugar_jdk_libs:2.1.4`; Java 17. (Release masih memakai signing debug — ganti sebelum rilis publik.) |
| `settings.gradle.kts`, `gradle.properties`, root `build.gradle.kts` | AGP 9.0.1, Kotlin 2.3.20, AndroidX, memori gradle 8G. |
| `app/src/main/res/` | Ikon launcher semua density (hasil flutter_launcher_icons) + `MainActivity.kt` polos. |

### 9.11 `android_patch/` — referensi (tidak dipakai build)

`AndroidManifest.xml` cadangan siap tempel, `build.gradle.snippet` (desugaring versi Groovy), `res/` ikon semua density, dan `README.md` penjelas. Berguna hanya kalau kamu membuat ulang folder `android/` sendiri via `flutter create`.

---

## 10. Skema database (SQLite)

Database `saku.db` (versi skema 2). Semua nominal `INTEGER` Rupiah bulat.

### 10.1 `transaksi` — buku kas (satu-satunya sumber pergerakan uang)

| Kolom | Tipe | Keterangan |
| --- | --- | --- |
| `id` | INTEGER PK AI | |
| `jenis` | TEXT NOT NULL | nilai `JenisTransaksi` (12 jenis, lihat bagian 2) |
| `jumlah` | INTEGER NOT NULL | positif; negatif hanya untuk `koreksi` |
| `kategori` | TEXT NULL | nilai `KategoriPengeluaran` (khusus pengeluaran) |
| `catatan` | TEXT NULL | nama/deskripsi |
| `sumber` | TEXT NOT NULL DEFAULT 'manual' | `manual` \| `scan_struk` \| `scan_tf` \| `nl_input` |
| `terkait_id` | INTEGER NULL | id kiriman/utang terkait |
| `dibuat_pada` | TEXT NOT NULL | ISO-8601 (tanggal + jam) |
| `cloud_id` | TEXT | id dokumen Firestore (UUID) |
| `dihapus` | INTEGER NOT NULL DEFAULT 0 | tombstone |
| `diubah_pada` | INTEGER NOT NULL DEFAULT 0 | epoch ms — dasar last-write-wins |

Indeks: `dibuat_pada`, `cloud_id`.

### 10.2 `saldo` — saldo termaterialisasi

| Kolom | Tipe | Keterangan |
| --- | --- | --- |
| `id` | INTEGER PK | selalu 1 (baris tunggal, dijaga CHECK) |
| `pegangan` | INTEGER NOT NULL DEFAULT 0 | |
| `kantong` | INTEGER NOT NULL DEFAULT 0 | dana darurat |

Selalu dijaga konsisten dengan buku kas (atomik saat catat; dihitung ulang penuh setelah edit/hapus/merge).

### 10.3 `kiriman`, `target`, `utang` — data fitur

| Tabel | Kolom khusus | Kolom umum |
| --- | --- | --- |
| `kiriman` | `nominal`, `tanggal_datang` (yyyy-MM-dd), `catatan?`, `status` (`menunggu`\|`masuk`) | `id`, `dibuat_pada`, `cloud_id`, `dihapus`, `diubah_pada` |
| `target` | `nama`, `nominal`, `tanggal?` (deadline), `status` (`aktif`\|`tercapai`) | idem |
| `utang` | `arah` (`ngutang`\|`ngutangin`), `pihak`, `nominal`, `jatuh_tempo?`, `catatan?`, `status` (`aktif`\|`lunas`) | idem |

### 10.4 `pengaturan` — key-value

`kunci` (PK), `nilai`, `diubah_pada`. Kunci tersinkron: `sudah_setup`, `batas_harian`, `model_gemini`, `bahasa`, `tabungan_terpakai`, `tabungan_riwayat`. Kunci lokal perangkat: `sudah_sambutan`, `grace_offline_hari`, `auto_wipe`, `notif_harian`, `jam_notif_pagi`, `jam_notif_malam`, `terkunci`, `last_auth_ok`, `last_sync`, `sync_uid`, `reset_cloud_pending` (sweep "hapus semua data" yang belum tuntas).

### 10.5 `antrian` — antrian sync

`id` PK AI, `koleksi`, `doc_id`, `payload` (JSON baris tanpa `id`), `UNIQUE(koleksi, doc_id)` — operasi baru menimpa yang lama untuk dokumen yang sama.

### 10.6 Migrasi v1 → v2

Menambah `cloud_id`/`dihapus`/`diubah_pada` ke 4 tabel data (backfill `cloud_id = 'm_' + tabel + '_' + id`), kolom `diubah_pada` di `pengaturan`, dan membuat tabel `antrian`.

---

## 11. Struktur data di Firestore

```
users/{uid}/                       ← hanya pemilik uid yang boleh (lihat 8.6)
├── transaksi/{cloud_id}           ← isi = kolom SQLite tanpa id
├── kiriman/{cloud_id}
├── target/{cloud_id}
├── utang/{cloud_id}
└── pengaturan/{kunci}             ← {kunci, nilai, dihapus, diubah_pada}
```

Nama koleksi = nama tabel SQLite. Konflik diselesaikan last-write-wins via `diubah_pada`. **Penghapusan baris data = dokumen benar-benar dihapus (DELETE, sejak v2.17.1)** — penanda `dihapus: 1` hanya dipertahankan di koleksi `pengaturan` (tombstone kecil `nilai: null` sebagai sinyal LWW ke perangkat lain, dibersihkan setelah 30 hari). "Hapus semua data" menyapu seluruh koleksi sampai kosong.

---

## 12. Teknologi & dependensi

| Paket | Versi | Untuk |
| --- | --- | --- |
| `provider` | ^6.1.2 | State management (`ChangeNotifier`) |
| `sqflite` + `path` + `path_provider` | ^2.3.3 / ^1.9.0 / ^2.1.4 | Database SQLite lokal |
| `http` | ^1.2.2 | Klien REST Gemini |
| `image_picker` | ^1.1.2 | Kamera & galeri |
| `image_cropper` | ^8.0.0 | Potong/putar foto (uCrop Android) |
| `receive_sharing_intent` | ^1.8.1 | Terima share foto/teks |
| `pdf` + `printing` | ^3.11.1 / ^5.13.4 | Laporan PDF + lembar bagikan |
| `firebase_core` / `firebase_auth` / `cloud_firestore` | ^5.1.0 / ^7.0.1 / ^7.1.0 | Login + sync |
| `connectivity_plus` | ^7.3.1 | Deteksi online (pemicu flush; sengaja bukan ^7.3.2) |
| `speech_to_text` | ^7.5.0 | Input suara id-ID |
| `fl_chart` | ^1.3.1 | Grafik tren laporan |
| `flutter_local_notifications` + `timezone` | ^19.0.0 / ^0.10.0 | Pengingat terjadwal |
| `share_plus` | ^11.0.0 | Bagikan CSV/PDF |
| `intl` | any | Format Rupiah/tanggal (versi mengikuti flutter_localizations) |
| `flutter_localizations` | sdk | Label material dua bahasa |
| `flutter_lints` (dev) | ^4.0.0 | Linter |
| `flutter_launcher_icons` (dev) | ^0.14.4 | Generate ikon dari aset logo |

Lingkungan: Dart SDK `>=3.6.0 <4.0.0`, Material 3, satu aset terdaftar (`assets/logo.png`).

---

## 13. Menjalankan, membuild & merilis

### 13.1 Prasyarat

- Flutter SDK (stabil) + Android Studio/VS Code + Android SDK.
- (Opsional) Akun Firebase + `flutterfire_cli` untuk login & sync.
- (Opsional) API key Gemini untuk scan & input AI.

### 13.2 Jalankan pertama kali

```bash
cd kosku
flutter pub get
flutter run
```

Folder `android/` bawaan sudah lengkap (izin, receiver pengingat, desugaring, ikon) — tidak ada patch manual. Kalau kamu membuat ulang folder `android/` sendiri (mis. karena versi Flutter berbeda):

```bash
rm -rf android
flutter create . --org com.kosku --project-name kosku
# lalu salin ulang izin + receiver + share target dari android_patch/AndroidManifest.xml
# dan flag desugaring dari android_patch/build.gradle.snippet
```

### 13.3 Menyalakan fitur Gemini (opsional)

Kunci dibundel saat build, tidak dimasukkan dari dalam aplikasi:

```bash
flutter run \
  --dart-define=GEMINI_API_KEY_1=AIza... \
  --dart-define=GEMINI_API_KEY_2=AIza...   # opsional (rotasi otomatis)
```

Tanpa kunci: aplikasi jalan penuh; input bebas pakai parser offline; layar scan menjelaskan kenapa nonaktif. Praktik aman: batasi key (Google Cloud Console) ke package name + SHA-1.

### 13.4 Menyalakan Firebase (opsional)

Proyek yang sekarang dipakai **sudah melewati langkah ini**: `lib/firebase_options.dart` sudah berisi konfigurasi asli hasil `flutterfire configure`, `android/app/google-services.json` sudah ada, dan `firebase.json` hadir untuk Firebase CLI — semuanya aman di-commit (bukan rahasia; keamanan datanya ada di Firestore Rules pemilik-saja). Bagian ini hanya perlu untuk salinan baru yang masih memakai `firebase_options.dart` stub:

```bash
dart pub global activate flutterfire_cli
flutterfire configure        # memilih project; menimpa lib/firebase_options.dart
```

Aktifkan metode login **Email/Password** di Firebase Auth, lalu terapkan aturan (lihat 8.6) — cara paling cepat lewat CLI:

```bash
firebase deploy --only firestore:rules
```

(atau tempel isi `firestore.rules` manual di Console Firebase → Firestore → Rules).

### 13.5 Ikon launcher

Ikon sudah tersedia di `android/app/src/main/res/` (dan cadangan di `android_patch/res/`). Meregenerasi dari aset:

```bash
dart run flutter_launcher_icons
```

### 13.6 Build APK rilis

```bash
flutter build apk --release \
  --dart-define=GEMINI_API_KEY_1=AIza... \
  --dart-define=GEMINI_API_KEY_2=AIza...
```

Catatan: signing release masih memakai kunci debug (`build.gradle.kts`) — ganti ke keystore sendiri sebelum unggah ke Play Store.

### 13.7 Uji otomatis

```bash
flutter test
```

---

## 14. Uji otomatis

Empat file di `test/`:

| File | Cakupan |
| --- | --- |
| `hitung_test.dart` | `parseRupiah`, format `rp` dua bahasa, `tebakKategori`, `sisaHariMenuju` (besok/4 hari/lewat/tanpa kiriman), `budgetHarian`, `hitungSaranTarget` (4 status), `hematBulan` (mulai pantau tengah bulan, hari boros tidak mencuri, bulan penuh), `proyeksiBatas` (aman/kurang, terpakai dalam batas tidak memotong, kelebihan memotong). |
| `agregat_test.dart` | `ringkasBulan` (total, rata, hari tanpa belanja, per kategori, per hari, terbesar, bulan lampau dibagi hari penuh, uang keluar lain terpisah), `deltaKategori`. |
| `parser_lokal_test.dart` | Semua satuan & format angka, angka telanjang kecil = ribuan, angka bersatuan menang, kata pengisi dibuang, kata kategori utuh, "kemarin" → −1 hari, teks kosong. |
| `widget_test.dart` | Kamus `T`: default id, ganti en, placeholder `{n}`, kunci tak dikenal dikembalikan apa adanya. |

---

## 15. Riwayat versi

Ringkasan perubahan penting (detail lengkap di `README.md`):

| Versi | Perubahan utama |
| --- | --- |
| **2.17.1** | **Cloud benar-benar bersih saat menghapus**: dokumen Firestore untuk transaksi/kiriman/target/utang yang dihapus kini **di-DELETE betulan** (dulu hanya ditandai `dihapus: 1` — data "sudah dihapus" tetap menumpuk selamanya di console dan isinya masih terbaca). "Hapus semua data" menyapu **seluruh koleksi cloud** termasuk sisa lama yang tidak punya baris lokal lagi, dengan **retry otomatis** bila dilakukan offline (flag `reset_cloud_pending`) dan snackbar jujur kalau pembersihan cloud ditunda. Penyapu kecil membersihkan dokumen tombstone peninggalan versi lama tiap sync menyala; event `removed` kini menghapus baris lokal di perangkat lain. |
| **2.17** | **Input suara jadi tahan-untuk-bicara** ala voice note WhatsApp: tahan mic = merekam dengan transkrip live, timer, dan bar level suara; **lepas jari = otomatis diparse** ke form tanpa tombol apa pun; geser kiri / sentuhan terlalu cepat / interupsi sistem = rekaman dibuang dan teks kolom dipulihkan; maks 30 detik per tahanan. |
| **2.16** | **Pelindung tanggal & jam hasil scan**: tanggal struk/bukti dibaca dengan format Indonesia dd/MM (mm/dd hanya kalau ketara seperti "12/28"), tahun yang tidak tercetak dianggap tahun berjalan, dan tanggal di luar jendela wajar (tahun lalu / lebih dari sebulan / masa depan) DITOLAK — pencatatan otomatis pakai hari ini + jam scan dengan info kenapa. **Jam dokumen ikut terbaca** (dulu selalu 00:00): jam struk dipakai kalau ada, kalau tidak jam saat scan. Pelindung berlapis juga di tempat lain: picker tanggal scan & ubah transaksi dibatasi (maks mundur 1 bulan, tidak bisa masa depan, tidak bisa lebih tua dari tanggal asli), input bebas maks mundur 7 hari, dan `tambahPengeluaran`/`tambahPemasukan` memagari `dibuatPada` di jendela 1 bulan — satu struk salah baca (kasus nyata: belanja tercatat 18 November 2023) tidak lagi bisa menarik "mulai pantau" tabungan hemat bertahun ke belakang sehingga tabungan tiba-tiba berisi hemat palsu tiap tanggal 1-16. Menghapus/mengubah transaksi juga membuka kunci hemat bulan tertutup yang terkena untuk dihitung ulang, jadi jejak data nyasar di tabungan ikut bersih. |
| **2.15** | Scan memakai tanggal dokumen sebagai default (bukan hari ini). Saran budget dirapikan jadi satu. Perbaikan hitungan saran batas di hari lewat batas. Konfirmasi lewat batas jadi satu aksi ("Catat & pakai tabungan"). Tabungan otomatis kembali saat transaksi dihapus/diubah. |
| **2.14** | **Menu Pengaturan + Akun + Sinkronisasi digabung jadi satu** ("Pengaturan & Akun"; ikon status sync di AppBar Home dihapus, kartu akun & sync ada di dalam Pengaturan). Menambah dokumen lengkap ini (`DOKUMENTASI.md`). |
| **2.13** | Semua **autofocus dihapus** (keyboard tidak lagi muncul sendiri). **Imbas di konfirmasi bayar lunas utang**. **Jam pengingat bisa diatur sendiri** (pagi & malam, default 08.00/20.00). **Urutan daftar dirapikan** (kiriman/utang/target). |
| **2.12** | Folder `android/` jadi disertakan lengkap (manifest + izin alarm exact + receiver + desugaring + ikon) — perbaikan definitif pengingat yang tidak pernah muncul. Izin alarm exact (Android 12+). Tombol "Kirim notifikasi uji". Jam pengingat ikut zona waktu HP. Perbaikan imbas beli target. Imbas di konfirmasi lewat batas. Bahasa default kembali ke Bahasa Indonesia. |
| **2.10** | Perbaikan pengingat tidak pernah muncul (receiver belum dideklarasikan). Pengingat utang hari jatuh tempo, target H-1, "segera" untuk event mendadak. Pratinjau imbas di banyak fitur. Proyeksi batas manual. Menu uang lain digabung. Perbaikan kartu target tercapai & label PDF. |
| **2.9** | Kartu "bertahan berapa lama" + simulasi dihapus dari Home (asumsinya bisa menyesatkan). Kalender pengeluaran dipertajam (lewat jatah = merah pekat angka putih). |
| **2.8** | Ubah/hapus transaksi. Kalender pengeluaran. Ekspor CSV. Pengingat Android (flutter_local_notifications + timezone + share_plus). |
| **2.7** | Tabungan hemat jadi rollover bulanan (tidak hangus 7 hari). |
| **2.6 / 2.5 / 2.3** | Ikon launcher siap salin / flutter_launcher_icons / image_cropper + receive_sharing_intent + pdf & printing. |

