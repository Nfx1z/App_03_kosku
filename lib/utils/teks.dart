/// Kamus dua bahasa (id = default, en = opsional).
/// Dipakai lewat [T.t] (teks biasa) dan [T.f] (dengan placeholder {x}).
///
/// Semua label UI melewati kelas ini supaya bahasa bisa
/// diganti live dari Pengaturan tanpa restart aplikasi.
class T {
  /// 'id' atau 'en'. Diisi AppState saat load & saat diganti di Pengaturan.
  /// Default 'id': install baru mulai dari Bahasa Indonesia; pilihan 'en'
  /// yang tersimpan di DB tetap dihormati.
  static String bahasa = 'id';

  static String t(String kunci) {
    final e = _kamus[kunci];
    if (e == null) return kunci;
    return e[bahasa] ?? e['id'] ?? kunci;
  }

  /// Teks dengan placeholder: T.f('x', {'n': '5'}).
  static String f(String kunci, Map<String, String> param) {
    var s = t(kunci);
    param.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }

  static const _kamus = <String, Map<String, String>>{
    // ============ UMUM ============
    'simpan': {'id': 'Simpan', 'en': 'Save'},
    'batal': {'id': 'Batal', 'en': 'Cancel'},
    'ya': {'id': 'Ya', 'en': 'Yes'},
    'hapus': {'id': 'Hapus', 'en': 'Delete'},
    'nama': {'id': 'Nama', 'en': 'Name'},
    'nominal': {'id': 'Nominal', 'en': 'Amount'},
    'kategori': {'id': 'Kategori', 'en': 'Category'},
    'tanggal': {'id': 'Tanggal', 'en': 'Date'},
    'catatan_opsional': {
      'id': 'Catatan (opsional)',
      'en': 'Note (optional)'
    },
    'sekarang': {'id': 'Sekarang {n}', 'en': 'Now {n}'},

    // ============ KATEGORI ============
    'kategori_makan_minum': {'id': 'Makan/Minum', 'en': 'Food/Drink'},
    'kategori_transport': {'id': 'Transport', 'en': 'Transport'},
    'kategori_belanja_pokok': {'id': 'Belanja Pokok', 'en': 'Groceries'},
    'kategori_hiburan': {'id': 'Hiburan', 'en': 'Entertainment'},
    'kategori_kesehatan': {'id': 'Kesehatan', 'en': 'Health'},
    'kategori_tagihan_rumah': {'id': 'Tagihan/Rumah', 'en': 'Bills/Home'},
    'kategori_pendidikan': {'id': 'Pendidikan', 'en': 'Education'},
    'kategori_lain_lain': {'id': 'Lain-lain', 'en': 'Other'},

    // ============ JENIS TRANSAKSI (label riwayat) ============
    'jenis_pengeluaran': {'id': 'Pengeluaran', 'en': 'Expense'},
    'jenis_pemasukan': {'id': 'Pemasukan', 'en': 'Income'},
    'jenis_isi_darurat': {'id': 'Isi kantong darurat', 'en': 'Fill emergency pocket'},
    'jenis_pakai_darurat': {'id': 'Pakai dana darurat', 'en': 'Use emergency fund'},
    'jenis_tarik_darurat': {'id': 'Tarik kantong ke pegangan', 'en': 'Withdraw pocket to cash'},
    'jenis_utang_masuk': {'id': 'Utang masuk', 'en': 'Debt received'},
    'jenis_utang_bayar': {'id': 'Bayar utang', 'en': 'Debt paid'},
    'jenis_piutang_keluar': {'id': 'Piutang keluar', 'en': 'Loan given'},
    'jenis_piutang_terima': {'id': 'Piutang diterima', 'en': 'Loan returned'},
    'jenis_koreksi': {'id': 'Penyetelan saldo', 'en': 'Balance adjustment'},

    // Judul baris transaksi (tile riwayat)
    'judul_pemasukan': {'id': 'Pemasukan', 'en': 'Income'},
    'judul_pakai_darurat': {'id': 'Pakai dana darurat', 'en': 'Use emergency fund'},
    'judul_tarik_darurat': {
      'id': 'Tarik kantong ke pegangan',
      'en': 'Withdraw pocket to cash'
    },
    'judul_utang_masuk': {'id': 'Ngutang dari {x}', 'en': 'Borrowed from {x}'},
    'judul_utang_bayar': {'id': 'Bayar utang ke {x}', 'en': 'Paid debt to {x}'},
    'judul_piutang_keluar': {'id': 'Ngutangin {x}', 'en': 'Lent to {x}'},
    'judul_piutang_terima': {'id': '{x} balikin utang', 'en': '{x} returned the loan'},
    'judul_koreksi': {'id': 'Atur saldo', 'en': 'Set balance'},
    'judul_pengeluaran': {'id': 'Pengeluaran', 'en': 'Expense'},
    'seseorang': {'id': 'seseorang', 'en': 'someone'},

    // ============ MENU HOME ============
    'nav_kiriman': {'id': 'Kiriman selanjutnya', 'en': 'Next transfer'},
    'nav_darurat': {'id': 'Dana darurat', 'en': 'Emergency fund'},
    'nav_tabungan': {'id': 'Tabungan', 'en': 'Savings'},
    'nav_target': {'id': 'Target beli', 'en': 'Buy targets'},
    'nav_utang': {'id': 'Utang & ngutangin', 'en': 'Debts & loans'},
    'nav_uang_lain': {
      'id': 'Uang masuk / keluar lain',
      'en': 'Other money in / out'
    },
    'nav_riwayat': {'id': 'Riwayat lengkap', 'en': 'Full history'},
    'nav_laporan': {'id': 'Laporan bulanan', 'en': 'Monthly report'},
    // Satu pintu: akun + sinkronisasi + pengaturan menyatu di
    // PengaturanScreen (sebelumnya terpisah jadi 3 titik masuk).
    'nav_pengaturan': {'id': 'Pengaturan & Akun', 'en': 'Settings & Account'},
    'scan': {'id': 'Scan', 'en': 'Scan'},
    'scan_struk': {'id': 'Scan struk belanja', 'en': 'Scan shopping receipt'},
    'scan_struk_sub': {
      'id': 'Foto struk, form terisi otomatis',
      'en': 'Photo the receipt, the form fills itself'
    },
    'scan_tf': {'id': 'Scan bukti transfer', 'en': 'Scan transfer proof'},
    'scan_tf_sub': {
      'id': 'Catat kiriman dari bukti transfer',
      'en': 'Log a transfer from the proof'
    },
    'bagian_hari_ini': {'id': 'Hari ini', 'en': 'Today'},
    'home_kosong': {
      'id': 'Belum ada transaksi hari ini.\nCatat pengeluaran pertamamu di atas.',
      'en': 'No transactions today yet.\nLog your first expense above.'
    },

    // ============ KARTU SALDO ============
    'pegangan_sekarang': {'id': 'PEGANGAN SEKARANG', 'en': 'CASH ON HAND'},
    'saldo_minus': {
      'id': 'Saldo minus, cek lagi catatanmu',
      'en': 'Negative balance, check your records'
    },
    'pill_kantong': {'id': 'Kantong darurat {n}', 'en': 'Emergency pocket {n}'},
    'pill_total': {'id': 'Total {n}', 'en': 'Total {n}'},
    'kiriman_info': {
      'id': 'Kiriman berikutnya: {n} • {d} ({h} hari lagi)',
      'en': 'Next transfer: {n} • {d} (in {h} days)'
    },

    // ============ KARTU BUDGET ============
    'budget_harian': {'id': 'BUDGET HARIAN', 'en': 'DAILY BUDGET'},
    'sisa_hari_info': {'id': 'sisa {n} hari', 'en': '{n} days left'},
    'budget_manual_info': {
      'id': 'Batas manual, ubah di Pengaturan',
      'en': 'Manual limit, change in Settings'
    },
    'budget_oto_kiriman': {
      'id': 'Otomatis: saldo ÷ sisa hari menuju kiriman {d}',
      'en': 'Auto: balance ÷ days until transfer {d}'
    },
    'budget_oto_bulan': {
      'id': 'Otomatis: saldo ÷ sisa hari bulan ini',
      'en': 'Auto: balance ÷ days left this month'
    },
    'lewat_batas_info': {'id': 'Lewat {n} dari batas', 'en': 'Over limit by {n}'},
    'sisa_hari_ini': {'id': 'Sisa {n} buat hari ini', 'en': '{n} left for today'},
    'budget_recal': {
      'id': 'Jatah hari ini sudah lewat batas. Supaya uang cukup '
          'sampai {d}, jatah barumu sekitar {n}/hari.',
      'en': "Today's allowance is blown. To make your money last "
          'until {d}, your new daily budget is about {n}/day.'
    },
    // Kelebihan jatah hari ini yang ditutup tabungan hemat (positif,
    // bukan peringatan merah).
    'budget_ditutup': {
      'id': '{n} kelebihan jatah ditutup tabungan',
      'en': '{n} over-limit covered by savings'
    },
    'budget_abaikan_lain': {
      'id': 'Uang masuk/keluar lain (kos, wifi, dll) tidak dihitung di '
          'jatah harian.',
      'en': 'Other money in/out (rent, wifi, etc.) is not counted '
          'against your daily allowance.'
    },
    'budget_oto_telat': {
      'id': 'Kiriman telat - sementara pakai sisa hari bulan ini. '
          'Konfirmasi kiriman biar hitungan balik normal.',
      'en': 'Transfer overdue - temporarily using days left this month. '
          'Confirm the transfer to restore the count.'
    },
    // Proyeksi batas manual (kartu budget + Pengaturan).
    'batas_proyeksi_aman': {
      'id': 'Dengan batas ini uang cukup sampai {d} - sisa ±{n}.',
      'en': 'With this limit, money lasts until {d} - ±{n} left.'
    },
    'batas_proyeksi_kurang': {
      'id': 'Dengan batas ini uang habis sekitar {d} ({k} hari kurang). '
          'Saran biar cukup: {n}/hari.',
      'en': 'With this limit, money runs out around {d} ({k} days short). '
          'To make it last: {n}/day.'
    },

    // ============ TABUNGAN HEMAT (menu Tabungan) ============
    'tabungan_saldo_label': {'id': 'TABUNGAN HEMAT', 'en': 'SAVINGS POT'},
    'tabungan_info': {
      'id': 'Sisa jatah harian yang tidak terpakai mengendap di sini '
          'sepanjang bulan, dan sisanya dibawa terus ke bulan-bulan '
          'berikutnya (tidak hangus). Dipakai hanya dengan konfirmasimu '
          'saat pengeluaran lewat batas harian.',
      'en': 'Unused daily allowance pools here all month long, and '
          'whatever is left carries over to the following months (it '
          'never expires). It is only used with your confirmation '
          'when spending goes over the daily limit.'
    },
    'tabungan_asal': {
      'id': 'Asal tabungan • {b}',
      'en': 'Where it comes from • {b}'
    },
    'tabungan_bawaan': {
      'id': 'Dibawa dari bulan-bulan sebelumnya',
      'en': 'Carried over from previous months'
    },
    'tabungan_belum_terpantau': {
      'id': 'Belum ada hari terpantau di bulan ini - hemat mulai '
          'terhitung setelah hari pertama kamu mencatat.',
      'en': 'No tracked days yet this month - savings start counting '
          'after your first logged day.'
    },
    'tabungan_hari_jatah': {
      'id': 'Jatah {a} • terpakai {b}',
      'en': 'Allowance {a} • spent {b}'
    },
    'tabungan_hemat': {'id': 'Hemat {n}', 'en': 'Saved {n}'},
    'tabungan_habis': {'id': 'Jatah habis', 'en': 'Fully spent'},
    'tabungan_hemat_info': {
      'id': 'Hemat {n} dari {d} hari terpantau bulan ini.',
      'en': 'Saved on {n} of {d} tracked days this month.'
    },
    'tabungan_dipakai_judul': {
      'id': 'Pemakaian tabungan',
      'en': 'Savings used'
    },
    'tabungan_dipakai_sub': {
      'id': 'Menutup kelebihan jatah harian',
      'en': 'Covered daily-allowance excess'
    },
    'tabungan_dipakai_kosong': {
      'id': 'Belum pernah dipakai.',
      'en': 'Never used yet.'
    },
    'tabungan_dipakai_lainnya': {
      'id': 'Dan {n} catatan pemakaian lainnya.',
      'en': 'And {n} more usage entries.'
    },
    'tabungan_belum_aktif': {
      'id': 'Belum ada batas harian aktif, jadi tabungan belum bisa '
          'mengendap. Atur saldo dulu di Home.',
      'en': 'No active daily limit yet, so savings cannot pool yet. '
          'Set your balance on Home first.'
    },

    // Dialog "pakai tabungan?" saat pengeluaran lewat batas
    'tabungan_pakai_judul': {'id': 'Pakai tabungan?', 'en': 'Use savings?'},
    'tabungan_pakai_pesan': {
      'id': 'Pengeluaran ini bikin jatah harianmu lewat {a}. Tabungan '
          'hemat {b} otomatis dipakai untuk menutup kelebihannya.',
      'en': 'This expense pushes you {a} over your daily limit. {b} of '
          'savings will be used to cover the excess.'
    },
    'tabungan_pakai_sebagian_pesan': {
      'id': 'Pengeluaran ini bikin jatah harianmu lewat {a}, dan '
          'tabunganmu cuma {b} - semuanya dipakai untuk menutup '
          'kelebihan, sisanya tetap dihitung lewat batas.',
      'en': 'This expense pushes you {a} over your daily limit, and you '
          'only have {b} in savings - all of it will be used, the rest '
          'still counts as over limit.'
    },
    'pakai_tabungan': {
      'id': 'Catat & pakai tabungan',
      'en': 'Log & use savings'
    },
    'snack_tersimpan_tabungan': {
      'id': 'Tersimpan. Kelebihan {t} ditutup tabungan, sisa pegangan {n}',
      'en': 'Saved. Excess {t} covered by savings, cash left {n}'
    },

    // ============ INPUT CEPAT ============
    'catat_pengeluaran': {'id': 'CATAT PENGELUARAN', 'en': 'LOG EXPENSE'},
    'hint_nama': {
      'id': 'esteh, belanja pokok, gojek...',
      'en': 'iced tea, groceries, ride...'
    },
    'harga': {'id': 'Harga', 'en': 'Price'},
    'snack_nama_kosong': {
      'id': 'Isi nama pengeluarannya dulu',
      'en': 'Enter the expense name first'
    },
    'snack_harga_kosong': {
      'id': 'Isi harganya berapa',
      'en': 'Enter the price'
    },
    'snack_tersimpan': {
      'id': 'Tersimpan. Sisa pegangan {n}',
      'en': 'Saved. Cash left {n}'
    },
    'snack_tersimpan_lewat': {
      'id': 'Tersimpan. Sisa pegangan {n}, budget harian baru {b}/hari',
      'en': 'Saved. Cash left {n}, new daily budget {b}/day'
    },

    // Input bahasa alami + suara
    'nl_hint': {
      'id': 'Ketik / ucap: "ngopi 15rb"',
      'en': 'Type / say: "coffee 15k"'
    },
    'nl_gagal': {
      'id': 'Gagal membaca, isi nama & harga manual',
      'en': 'Could not parse, fill name & price manually'
    },
    'nl_isi': {
      'id': 'Form terisi, cek lalu Simpan',
      'en': 'Form filled, check then Save'
    },
    'nl_mendengarkan': {'id': 'Mendengarkan...', 'en': 'Listening...'},
    'nl_mik_gagal': {
      'id': 'Mikrofon tidak tersedia / izin ditolak',
      'en': 'Microphone unavailable / permission denied'
    },
    'nl_suara_kosong': {
      'id': 'Tidak kedengaran, coba lagi',
      'en': 'Nothing heard, try again'
    },
    // Suara mode tahan-untuk-bicara (ala voice note WhatsApp)
    'nl_tahan_mic': {
      'id': 'Tahan tombol mic sambil bicara, lepas untuk diproses',
      'en': 'Hold the mic button while speaking, release to process'
    },
    'nl_lepas_proses': {
      'id': 'Bicara... lepas saat selesai',
      'en': 'Speak... release when done'
    },
    'nl_geser_batal': {'id': 'geser batal', 'en': 'slide cancel'},
    'nl_lepas_batal': {'id': 'LEPAS UNTUK BATAL', 'en': 'RELEASE TO CANCEL'},
    'nl_menyiapkan_mic': {
      'id': 'Menyiapkan mikrofon...',
      'en': 'Preparing microphone...'
    },
    'nl_pratinjau': {'id': 'Dibaca', 'en': 'Read as'},
    // Penanda hasil parse "kemarin" - tetap terlihat sampai disimpan
    // supaya transaksi tidak nyasar tercatat di tanggal yang salah.
    'akan_dicatat_kemarin': {
      'id': 'Akan dicatat untuk: KEMARIN',
      'en': 'Will be recorded: YESTERDAY'
    },
    'kembalikan_hari_ini': {'id': 'Pakai hari ini', 'en': 'Use today'},

    // ============ KARTU PERHATIAN ============
    'perlu_perhatian': {'id': 'PERLU PERHATIAN', 'en': 'NEEDS ATTENTION'},
    'perhatian_kiriman': {
      'id': 'Kiriman {n} tanggal {d} belum dikonfirmasi masuk',
      'en': 'Transfer {n} dated {d} not confirmed as arrived yet'
    },
    'utang_ke': {'id': 'Utang ke', 'en': 'Debt to'},
    'piutang_ke': {'id': 'Piutang ke', 'en': 'Loan to'},
    'perhatian_lewat_tempo': {
      'id': '{p} {x} lewat jatuh tempo ({d})',
      'en': '{p} {x} past due date ({d})'
    },
    'perhatian_tempo_dekat': {
      'id': '{p} {x} jatuh tempo {d}',
      'en': '{p} {x} due on {d}'
    },
    'perhatian_target_hari_ini': {'id': 'hari ini', 'en': 'today'},
    'perhatian_target': {
      'id': 'Target "{x}" {h}, saldo belum cukup (kurang {n})',
      'en': 'Target "{x}" {h}, balance not enough yet (short {n})'
    },
    'perhatian_batas': {
      'id': 'Pengeluaran hari ini lewat batas - cek kartu budget '
          'untuk jatah barunya.',
      'en': 'Today\'s spending is over the limit - check the budget '
          'card for your new allowance.'
    },

    // ============ ONBOARDING ============
    'selamat_datang': {'id': 'Selamat datang di Kosku!', 'en': 'Welcome to Kosku!'},
    'selamat_datang_sub': {
      'id': 'Uang di tanganmu sekarang berapa? Dari situ Kosku mulai '
          'menghitung budget harianmu.',
      'en': 'How much cash do you have right now? Kosku starts counting '
          'your daily budget from there.'
    },
    'pegangan_label': {'id': 'Pegangan sekarang', 'en': 'Cash on hand'},
    'mulai': {'id': 'Mulai', 'en': 'Start'},
    'snack_isi_pegangan': {
      'id': 'Isi dulu peganganmu berapa sekarang',
      'en': 'Enter how much cash you have first'
    },

    // ============ RIWAYAT ============
    'riwayat_judul': {'id': 'Riwayat Lengkap', 'en': 'Full History'},
    'masuk_bulan_ini': {'id': 'MASUK BULAN INI', 'en': 'INCOME THIS MONTH'},
    'keluar_bulan_ini': {'id': 'KELUAR BULAN INI', 'en': 'SPENT THIS MONTH'},
    'filter_semua': {'id': 'Semua', 'en': 'All'},
    'filter_pengeluaran': {'id': 'Pengeluaran', 'en': 'Expenses'},
    'filter_pemasukan': {'id': 'Pemasukan', 'en': 'Income'},
    'filter_kantong': {'id': 'Kantong', 'en': 'Pocket'},
    'filter_utang': {'id': 'Utang', 'en': 'Debts'},
    'riwayat_kosong': {
      'id': 'Belum ada transaksi di filter ini.',
      'en': 'No transactions in this filter.'
    },
    'hari_ini_label': {'id': 'Hari ini', 'en': 'Today'},
    'kemarin_label': {'id': 'Kemarin', 'en': 'Yesterday'},
    'tekan_untuk_ubah': {
      'id': 'Ketuk transaksi untuk mengubah atau menghapus',
      'en': 'Tap a transaction to edit or delete it'
    },

    // ---- Ubah / hapus transaksi (lembar bawah Riwayat & Home) ----
    'edit_judul': {'id': 'Ubah transaksi', 'en': 'Edit transaction'},
    'edit_field_jumlah': {'id': 'Jumlah baru', 'en': 'New amount'},
    'edit_field_catatan': {'id': 'Nama / catatan', 'en': 'Name / note'},
    'edit_koreksi_info': {
      'id': 'Catatan penyetelan saldo tidak bisa diubah - hapus saja '
          'kalau salah, lalu atur ulang saldo.',
      'en': 'Balance adjustments can\u2019t be edited - just delete it '
          'if it\u2019s wrong, then set your balance again.'
    },
    'simpan_perubahan': {'id': 'Simpan perubahan', 'en': 'Save changes'},
    'hapus_trans_judul': {'id': 'Hapus transaksi ini?', 'en': 'Delete this transaction?'},
    'hapus_trans_pesan': {
      'id': 'Catatan ini dihapus dari buku kas. Saldo pegangan & '
          'kantong darurat dihitung ulang otomatis. Kalau catatan ini '
          'yang bikin lewat batas, tabungan yang terpakai otomatis '
          'dikembalikan.',
      'en': 'This entry is removed from the ledger. Cash & emergency '
          'pocket are recalculated automatically. If this entry caused '
          'an over-limit covered by savings, those savings are '
          'returned automatically.'
    },
    'trans_diedit': {'id': 'Transaksi diubah', 'en': 'Transaction updated'},
    'trans_dihapus': {'id': 'Transaksi dihapus', 'en': 'Transaction deleted'},
    'trans_dihapus_tabungan': {
      'id': 'Transaksi dihapus. Tabungan {n} dikembalikan.',
      'en': 'Transaction deleted. {n} returned to savings.'
    },
    'snack_saldo_berubah': {
      'id': 'Saldo berubah, transaksi batal - coba lagi',
      'en': 'Balance changed, transaction cancelled - try again'
    },

    // ============ KIRIMAN ============
    'kiriman_judul': {'id': 'Kiriman Selanjutnya', 'en': 'Next Transfer'},
    'kiriman_kartu': {'id': 'KIRIMAN BERIKUTNYA', 'en': 'NEXT TRANSFER'},
    'hari_lagi': {'id': '({n} hari lagi)', 'en': '(in {n} days)'},
    'kiriman_info_konfirmasi': {
      'id': 'Kalau uangnya sudah masuk, pencet "Sudah masuk" biar '
          'saldo pegangan ikut nambah.',
      'en': 'Once the money arrives, tap "Arrived" so your cash balance grows.'
    },
    'tambah_jadwal_kiriman': {
      'id': 'Tambah jadwal kiriman',
      'en': 'Add transfer schedule'
    },
    'perkiraan_datang': {'id': 'Perkiraan datang', 'en': 'Expected arrival'},
    'catatan_kiriman': {
      'id': 'Catatan (opsional, mis. "gaji ortu")',
      'en': 'Note (optional, e.g. "parents\' allowance")'
    },
    'tambah_jadwal': {'id': 'Tambah jadwal', 'en': 'Add schedule'},
    'daftar_kiriman': {'id': 'Daftar kiriman', 'en': 'Transfer list'},
    'kiriman_kosong': {
      'id': 'Belum ada jadwal kiriman.',
      'en': 'No transfer schedules yet.'
    },
    'sudah_masuk': {'id': 'Sudah masuk', 'en': 'Arrived'},
    'menunggu': {'id': 'Menunggu', 'en': 'Waiting'},
    'lewat_tanggal': {
      'id': 'Lewat tanggal, sudah masuk belum?',
      'en': 'Past its date, has it arrived?'
    },
    'konfirmasi_kiriman_judul': {
      'id': 'Kiriman sudah masuk?',
      'en': 'Has the transfer arrived?'
    },
    'konfirmasi_kiriman_pesan': {
      'id': 'Saldo pegangan akan bertambah {n}.',
      'en': 'Cash balance will increase by {n}.'
    },
    'hapus_kiriman_judul': {
      'id': 'Hapus jadwal kiriman?',
      'en': 'Delete this transfer schedule?'
    },
    'hapus_kiriman_pesan': {
      'id': 'Jadwal {n} tanggal {d} akan dihapus. Saldo tidak berubah.',
      'en': 'Schedule {n} on {d} will be deleted. Balance unchanged.'
    },
    'snack_kiriman_tambah': {
      'id': 'Jadwal kiriman ditambahkan',
      'en': 'Transfer schedule added'
    },
    'snack_kiriman_nominal': {
      'id': 'Isi nominal kiriman dulu',
      'en': 'Enter the transfer amount first'
    },

    // ============ DANA DARURAT ============
    'darurat_judul': {'id': 'Dana Darurat', 'en': 'Emergency Fund'},
    'kantong_darurat': {'id': 'KANTONG DARURAT', 'en': 'EMERGENCY POCKET'},
    'darurat_info': {
      'id': 'Pegangan {p} • Total uang {t}',
      'en': 'Cash {p} • Total money {t}'
    },
    'isi': {'id': 'Isi', 'en': 'Fill'},
    'pakai': {'id': 'Pakai', 'en': 'Use'},
    'tarik': {'id': 'Tarik', 'en': 'Withdraw'},
    'isi_kantong_judul': {'id': 'Isi kantong darurat', 'en': 'Fill emergency pocket'},
    'pakai_darurat_judul': {'id': 'Pakai dana darurat', 'en': 'Use emergency fund'},
    'tarik_judul': {'id': 'Tarik ke pegangan', 'en': 'Withdraw to cash'},
    'pakai_buat_apa': {
      'id': 'Dipakai buat apa? (opsional)',
      'en': 'Used for what? (optional)'
    },
    'snack_isi_nominal': {
      'id': 'Isi nominalnya dulu',
      'en': 'Enter the amount first'
    },
    'cara_kerja_kantong': {
      'id': 'Cara kerja kantong',
      'en': 'How the pocket works'
    },
    'cara_kerja_teks': {
      'id': 'Isi: uang pindah dari pegangan ke kantong (pegangan kepotong).\n'
          'Pakai: uang keluar dari kantong, pegangan tidak tersentuh.\n'
          'Tarik: uang balik dari kantong ke pegangan.',
      'en': 'Fill: money moves from cash to the pocket (cash decreases).\n'
          'Use: money leaves the pocket, cash untouched.\n'
          'Withdraw: money returns from the pocket to cash.'
    },
    'riwayat_kantong': {'id': 'Riwayat kantong', 'en': 'Pocket history'},
    'kantong_kosong': {
      'id': 'Kantong masih kosong.',
      'en': 'The pocket is still empty.'
    },

    // ============ TARGET ============
    'target_judul': {'id': 'Target Beli', 'en': 'Buy Targets'},
    'tambah_target': {'id': 'Tambah target', 'en': 'Add target'},
    'mau_beli_apa': {'id': 'Mau beli apa?', 'en': 'What do you want to buy?'},
    'hint_target': {
      'id': 'naik gunung, lipstik, sepatu...',
      'en': 'hiking trip, lipstick, shoes...'
    },
    'budget': {'id': 'Budget', 'en': 'Budget'},
    'punya_deadline': {
      'id': 'Punya tanggal deadline?',
      'en': 'Has a deadline?'
    },
    'deadline': {'id': 'Deadline', 'en': 'Deadline'},
    'target_kamu': {'id': 'Target kamu', 'en': 'Your targets'},
    'target_kosong': {
      'id': 'Belum ada target. Mau beli apa berikutnya?',
      'en': 'No targets yet. What do you want to buy next?'
    },
    'tercapai': {'id': 'Tercapai', 'en': 'Reached'},
    'target_selesai': {
      'id': 'Target tercapai - tidak ada yang perlu dikejar lagi.',
      'en': 'Target reached - nothing left to chase.'
    },
    'budget_deadline_info': {
      'id': 'Budget {n} • deadline {d}',
      'en': 'Budget {n} • deadline {d}'
    },
    'budget_tanpa_tanggal': {
      'id': 'Budget {n} • tanpa tanggal',
      'en': 'Budget {n} • no date'
    },
    'siap_info': {'id': 'Siap {a} / {b}', 'en': 'Ready {a} / {b}'},
    'tandai_tercapai': {'id': 'Tandai tercapai', 'en': 'Mark as reached'},
    'tandai_tercapai_judul': {
      'id': 'Tandai tercapai?',
      'en': 'Mark as reached?'
    },
    'catat_sekarang': {
      'id': 'Catat pengeluaran sekarang?',
      'en': 'Log the expense now?'
    },
    'catat_sekarang_sub': {
      'id': 'Pegangan kepotong sesuai budget',
      'en': 'Cash decreases by the budget'
    },
    'tandai': {'id': 'Tandai', 'en': 'Mark'},
    'hapus_target_judul': {'id': 'Hapus target?', 'en': 'Delete this target?'},
    'hapus_target_pesan': {
      'id': 'Target "{x}" ({n}) akan dihapus.',
      'en': 'Target "{x}" ({n}) will be deleted.'
    },
    'snack_target_isi': {
      'id': 'Isi nama target dan budgetnya',
      'en': 'Enter the target name and budget'
    },
    'snack_target_tambah': {'id': 'Target ditambahkan', 'en': 'Target added'},

    // Saran target (dihitung di hitung.dart, teksnya di sini)
    'saran_siap': {
      'id': 'Saldo sudah cukup, siap beli kapan saja.',
      'en': 'Balance is enough, ready to buy anytime.'
    },
    'saran_aman': {
      'id': 'Nabung {n}/hari selama {d} hari, siap tanggal {t}.',
      'en': 'Save {n}/day for {d} days, ready by {t}.'
    },
    'saran_berat': {
      'id': 'Butuh nabung {n}/hari, di atas kemampuanmu '
          '(~{k}/hari). Coba geser tanggal atau kecilin budget.',
      'en': 'Needs saving {n}/day, beyond your capacity '
          '(~{k}/day). Try shifting the date or lowering the budget.'
    },
    'saran_waktu': {
      'id': 'Kurang {n}. Kalau nabung {k}/hari, siap sekitar {t} ({d} hari lagi).',
      'en': 'Short by {n}. Saving {k}/day, ready around {t} (in {d} days).'
    },

    // ============ UTANG ============
    'utang_judul': {'id': 'Utang & Ngutangin', 'en': 'Debts & Loans'},
    'tab_ngutang': {'id': 'Aku ngutang', 'en': 'I owe'},
    'tab_ngutangin': {'id': 'Aku ngutangin', 'en': 'I lent'},
    'form_utang_judul': {
      'id': 'Catat utang (aku yang minjem)',
      'en': 'Log a debt (I borrowed)'
    },
    'form_ngutangin_judul': {
      'id': 'Catat pinjaman (aku yang ngasih)',
      'en': 'Log a loan (I lent)'
    },
    'form_utang_sub': {
      'id': 'Saldo pegangan nambah. Jangan lupa balikin, ya.',
      'en': 'Cash balance increases. Don\'t forget to pay it back.'
    },
    'form_ngutangin_sub': {
      'id': 'Saldo pegangan kepotong. Semoga balik, ya.',
      'en': 'Cash balance decreases. Hope it comes back.'
    },
    'siapa': {'id': 'Siapa?', 'en': 'Who?'},
    'hint_siapa': {'id': 'nama orang', 'en': 'person\'s name'},
    'punya_target_bayar': {
      'id': 'Punya target bayar?',
      'en': 'Has a payback target?'
    },
    'target_bayar': {'id': 'Target bayar', 'en': 'Payback target'},
    'catat': {'id': 'Catat', 'en': 'Log'},
    'yang_aku_pinjam': {'id': 'Yang aku pinjam', 'en': 'What I borrowed'},
    'yang_kupinjamkan': {'id': 'Yang kupinjamkan', 'en': 'What I lent out'},
    'utang_kosong': {
      'id': 'Belum ada utang. Alhamdulillah.',
      'en': 'No debts. Thank goodness.'
    },
    'ngutangin_kosong': {
      'id': 'Belum ada yang kamu utangin.',
      'en': 'You haven\'t lent anything yet.'
    },
    'lunas': {'id': 'Lunas', 'en': 'Settled'},
    'belum_lunas': {'id': 'Belum lunas', 'en': 'Not settled'},
    'lewat_tempo': {'id': 'LEWAT TEMPO {d}', 'en': 'OVERDUE {d}'},
    'bayar_sebelum': {'id': 'Bayar sebelum {d}', 'en': 'Pay before {d}'},
    'utang_lunas_judul': {
      'id': 'Utang ke {x} lunas?',
      'en': 'Debt to {x} settled?'
    },
    'piutang_lunas_judul': {
      'id': '{x} sudah balikin?',
      'en': 'Has {x} paid you back?'
    },
    'utang_lunas_pesan': {
      'id': 'Kamu bayar {n} ke {x}.',
      'en': 'You pay {n} to {x}.'
    },
    'piutang_lunas_pesan': {
      'id': '{x} balikin {n} ke kamu.',
      'en': '{x} returns {n} to you.'
    },
    'catat_pengeluaran_tanya': {
      'id': 'Catat pengeluaran?',
      'en': 'Log as expense?'
    },
    'catat_pemasukan_tanya': {
      'id': 'Catat pemasukan?',
      'en': 'Log as income?'
    },
    'pegangan_kepotong': {'id': 'Pegangan kepotong', 'en': 'Cash decreases'},
    'pegangan_nambah': {'id': 'Pegangan nambah', 'en': 'Cash increases'},
    'tandai_lunas': {'id': 'Tandai lunas', 'en': 'Mark settled'},
    'hapus_utang_judul': {
      'id': 'Hapus catatan ini?',
      'en': 'Delete this record?'
    },
    'hapus_utang_pesan': {
      'id': 'Catatan {x} ({n}) dihapus. Saldo TIDAK berubah, kalau uangnya '
          'sudah berpindah tandai lunas dulu.',
      'en': 'Record {x} ({n}) deleted. Balance does NOT change, if the money '
          'already moved mark it settled first.'
    },
    'snack_utang_isi': {
      'id': 'Isi nama orang dan nominalnya',
      'en': 'Enter the person\'s name and amount'
    },
    'snack_utang_tersimpan': {
      'id': 'Tercatat, saldo nambah {n}',
      'en': 'Logged, balance up {n}'
    },
    'snack_ngutangin_tersimpan': {
      'id': 'Tercatat, saldo kepotong {n}',
      'en': 'Logged, balance down {n}'
    },

    // ============ SCAN ============
    'scan_struk_judul': {'id': 'Scan Struk Belanja', 'en': 'Scan Shopping Receipt'},
    'scan_tf_judul': {'id': 'Scan Bukti Transfer', 'en': 'Scan Transfer Proof'},
    'scan_struk_info': {
      'id': 'Foto struknya atau pilih dari galeri, rincian belanja '
          'terisi otomatis. Tinggal cek lalu simpan.',
      'en': 'Photo the receipt or pick from gallery, the details '
          'fill in automatically. Just check and save.'
    },
    'scan_tf_info': {
      'id': 'Foto bukti transfer yang masuk ke kamu, nominal dan '
          'pengirim terbaca otomatis.',
      'en': 'Photo the transfer proof sent to you, the amount and '
          'sender are read automatically.'
    },
    'ambil_foto': {
      'id': 'Ambil / pilih foto dulu',
      'en': 'Take / pick a photo first'
    },
    'kamera': {'id': 'Kamera', 'en': 'Camera'},
    'galeri': {'id': 'Galeri', 'en': 'Gallery'},
    'ganti_foto': {'id': 'Ganti foto', 'en': 'Change photo'},
    'baca_gemini': {'id': 'Baca otomatis', 'en': 'Read automatically'},
    'sedang_dibaca': {'id': 'Sedang dibaca...', 'en': 'Reading...'},
    'hasil_scan_judul': {
      'id': 'Hasil scan, cek dulu sebelum simpan',
      'en': 'Scan result, check before saving'
    },
    'nama_toko': {
      'id': 'Nama (toko / pengeluaran)',
      'en': 'Name (store / expense)'
    },
    'pajak_biaya': {'id': 'Pajak / biaya', 'en': 'Tax / fees'},
    'total_kapotong': {
      'id': 'Total (yang kepotong)',
      'en': 'Total (deducted)'
    },
    'item_terbaca': {'id': 'Item terbaca ({n}):', 'en': 'Items read ({n}):'},
    'nominal_masuk': {'id': 'Nominal masuk', 'en': 'Incoming amount'},
    'dari_siapa': {
      'id': 'Dari siapa? (pengirim)',
      'en': 'From whom? (sender)'
    },
    'bank_ewallet': {
      'id': 'Bank / e-wallet (opsional)',
      'en': 'Bank / e-wallet (optional)'
    },
    'tf_keluar_warning': {
      'id': 'Terdeteksi transfer KELUAR (kamu yang kirim). Fitur ini '
          'untuk catatan kiriman masuk, simpan hanya kalau memang '
          'ujungnya uang masuk ke kamu.',
      'en': 'OUTGOING transfer detected (you sent it). This feature is for '
          'incoming transfers, only save if the money ends up with you.'
    },
    'simpan_pengeluaran': {'id': 'Simpan pengeluaran', 'en': 'Save expense'},
    'konfirmasi_kiriman_masuk': {
      'id': 'Konfirmasi kiriman masuk',
      'en': 'Confirm incoming transfer'
    },
    'scan_err_key': {
      'id': 'Fitur pindai belum aktif di aplikasi ini.',
      'en': 'Scanning is not enabled in this app.'
    },
    'scan_err_gagal': {
      'id': 'Gagal membaca gambar, coba foto lagi.',
      'en': 'Failed to read the image, try another photo.'
    },
    'scan_err_total': {
      'id': 'Total belum terbaca, isi manual dulu',
      'en': 'Total not read yet, fill it in manually'
    },
    'scan_err_nominal': {
      'id': 'Nominal belum terbaca, isi manual dulu',
      'en': 'Amount not read yet, fill it in manually'
    },
    'belanja_default': {'id': 'Belanja', 'en': 'Shopping'},
    'scan_item_lain': {'id': ', dll', 'en': ', etc'},
    'snack_scan_struk': {
      'id': 'Tersimpan ({x}). Sisa pegangan {n}',
      'en': 'Saved ({x}). Cash left {n}'
    },
    'snack_scan_tf': {
      'id': 'Kiriman tercatat. Pegangan jadi {n}',
      'en': 'Transfer logged. Cash now {n}'
    },
    'scan_struk_sumber': {'id': 'Scan struk', 'en': 'Receipt scan'},
    'transfer_masuk': {'id': 'Transfer masuk', 'en': 'Incoming transfer'},
    'transfer_dari': {'id': ' dari {x}', 'en': ' from {x}'},

    // Error Gemini (dilempar sebagai kunci, diterjemahkan di UI)
    'gem_err_offline': {
      'id': 'Tidak ada koneksi internet, fitur ini butuh online.',
      'en': 'No internet connection, this feature needs to be online.'
    },
    'gem_err_koneksi': {
      'id': 'Koneksi gagal, coba lagi.',
      'en': 'Connection failed, try again.'
    },
    'gem_err_key': {
      'id': 'Layanan pindai sedang bermasalah, coba lagi nanti.',
      'en': 'The scanning service has a problem, try again later.'
    },
    'gem_err_model': {
      'id': 'Model "{x}" tidak ditemukan, ganti di Pengaturan.',
      'en': 'Model "{x}" not found, change it in Settings.'
    },
    'gem_err_kuota': {
      'id': 'Kuota Gemini sementara habis, coba lagi nanti.',
      'en': 'Gemini quota temporarily exhausted, try again later.'
    },
    'gem_err_kuota_semua': {
      'id': 'Kuota pindai sementara habis, coba lagi nanti.',
      'en': 'Scanning quota is temporarily used up, try again later.'
    },
    'gem_err_status': {'id': 'Gemini error {x}.', 'en': 'Gemini error {x}.'},
    'gem_err_baca': {
      'id': 'Balasan Gemini tidak bisa dibaca.',
      'en': 'Could not read the Gemini response.'
    },
    'gem_err_data': {
      'id': 'Gemini tidak mengembalikan data yang bisa dibaca.',
      'en': 'Gemini did not return readable data.'
    },

    // ============ DIALOG BATAS ============
    'lewat_batas_judul': {
      'id': 'Lewat batas harian',
      'en': 'Daily limit exceeded'
    },
    'lewat_batas_pesan': {
      'id': 'Pengeluaran hari ini jadi {a}, lewat batas {b}. Tetap simpan?',
      'en': 'Today\'s spending becomes {a}, over the {b} limit. Save anyway?'
    },
    'tetap_simpan': {'id': 'Tetap simpan', 'en': 'Save anyway'},

    // ============ PENGATURAN ============
    'pengaturan_judul': {'id': 'Pengaturan', 'en': 'Settings'},
    'uang_judul': {'id': 'Uang', 'en': 'Money'},
    'batas_desc': {
      'id': 'Batas pengeluaran per hari. Kalau lewat, Kosku ngasih '
          'peringatan + hitung ulang budget harian.',
      'en': 'Daily spending limit. If exceeded, Kosku warns you '
          'and recalculates the daily budget.'
    },
    'batas_harian_label': {'id': 'Batas harian', 'en': 'Daily limit'},
    'kosongkan_oto': {'id': 'Kosongkan = otomatis', 'en': 'Empty = automatic'},
    'snack_batas_simpan': {
      'id': 'Batas harian disimpan',
      'en': 'Daily limit saved'
    },
    'atur_saldo': {'id': 'Atur saldo pegangan', 'en': 'Set cash balance'},
    'atur_saldo_label': {
      'id': 'Pegangan sekarang sebenarnya',
      'en': 'Actual cash on hand now'
    },
    'snack_saldo_atur': {
      'id': 'Pegangan diatur jadi {n}',
      'en': 'Cash set to {n}'
    },

    // Akun & sync
    'akun_judul': {'id': 'Akun & Sinkronisasi', 'en': 'Account & Sync'},
    'akun_desc': {
      'id': 'Login email & sandi. Data disimpan lokal dulu (cepat), lalu '
          'disalin ke cloud saat online. Ganti HP / reinstall → data balik.',
      'en': 'Email & password login. Data is saved locally first (fast), then '
          'mirrored to the cloud when online. New phone / reinstall → data restored.'
    },
    'cloud_belum': {
      'id': 'Sinkronisasi cloud belum aktif, data kamu tetap tersimpan '
          'aman di HP ini.',
      'en': 'Cloud sync is not active, your data stays safely on this phone.'
    },
    'masuk_daftar': {'id': 'Masuk / daftar akun', 'en': 'Sign in / register'},
    'keluar_akun': {'id': 'Keluar', 'en': 'Sign out'},
    'keluar_konfirmasi_judul': {
      'id': 'Keluar akun?',
      'en': 'Sign out?'
    },
    'keluar_konfirmasi_pesan': {
      'id': 'Data di HP ini tetap ada. Setelah keluar, sinkronisasi berhenti '
          'sampai kamu login lagi.',
      'en': 'Data on this phone stays. After signing out, sync stops '
          'until you sign in again.'
    },
    'sinkron_terakhir': {
      'id': 'Sinkron terakhir: {t}',
      'en': 'Last synced: {t}'
    },
    'belum_pernah_sinkron': {
      'id': 'Belum pernah sinkron',
      'en': 'Never synced'
    },
    'antrian_info': {'id': '{n} perubahan menunggu sinkron', 'en': '{n} changes waiting to sync'},
    'offline_info': {
      'id': 'Offline, perubahan disimpan lokal, otomatis dikirim saat online.',
      'en': 'Offline, changes saved locally, sent automatically when online.'
    },
    'sinkron_sekarang': {'id': 'Sinkron sekarang', 'en': 'Sync now'},
    'sedang_sinkron': {'id': 'Sinkronisasi...', 'en': 'Syncing...'},
    'snack_sinkron_ok': {'id': 'Semua perubahan terkirim', 'en': 'All changes synced'},
    'snack_sinkron_gagal': {
      'id': 'Belum bisa sinkron, cek koneksi internet',
      'en': 'Cannot sync yet, check your internet connection'
    },
    'grace_label': {
      'id': 'Masa tenggang offline',
      'en': 'Offline grace period'
    },
    'grace_sub': {
      'id': 'Login tetap aktif tanpa internet selama {n} hari. Setelah itu, '
          'wajib login online lagi.',
      'en': 'Login stays active without internet for {n} days. After that, '
          'you must sign in online again.'
    },
    'grace_n_hari': {'id': '{n} hari', 'en': '{n} days'},
    'auto_wipe_label': {
      'id': 'Hapus data lokal saat terkunci',
      'en': 'Erase local data when locked'
    },
    'auto_wipe_sub': {
      'id': 'Untuk keamanan kalau HP hilang: begitu sesi kedaluwarsa, semua '
          'data di HP ini dihapus (data di cloud aman).',
      'en': 'For security if the phone is lost: once the session expires, all '
          'data on this phone is erased (cloud data stays safe).'
    },
    'auto_wipe_warning': {
      'id': 'PERINGATAN: yang belum sempat sinkron akan HILANG PERMANEN '
          'dan tidak bisa balik. Yakin aktifkan?',
      'en': 'WARNING: anything not yet synced will be LOST FOREVER and '
          'cannot be recovered. Really enable?'
    },
    'aktifkan': {'id': 'Aktifkan', 'en': 'Enable'},

    // Bahasa
    'bahasa_judul': {'id': 'Bahasa / Language', 'en': 'Bahasa / Language'},
    'bahasa_sub': {
      'id': 'Ganti tampilan aplikasi. Default: Bahasa Indonesia.',
      'en': 'Switch the app language. Default: Indonesian.'
    },
    'bahasa_id': {'id': 'Bahasa Indonesia', 'en': 'Bahasa Indonesia'},
    'bahasa_en': {'id': 'English', 'en': 'English'},

    // Gemini
    'gemini_judul': {'id': 'Pindai struk', 'en': 'Receipt scanning'},
    'gemini_status_kosong': {
      'id': 'Pindai belum aktif di versi aplikasi ini.',
      'en': 'Scanning is not enabled in this app version.'
    },

    // Data
    // ---- Pengingat Android (notifikasi sistem) ----
    'notif_judul': {'id': 'Pengingat', 'en': 'Reminders'},
    'notif_desc': {
      'id': 'Pengingat muncul di notifikasi HP: kiriman semestinya '
          'datang, utang / piutang menjelang jatuh tempo, ingatan '
          'catat pengeluaran, dan (kalau dinyalakan) ringkasan pagi.',
      'en': 'Reminders appear in your phone\u2019s notifications: '
          'expected transfers, debts / loans nearing their due date, '
          'a nudge to log expenses, and (if enabled) a morning summary.'
    },
    'notif_harian': {
      'id': 'Pengingat catat pengeluaran tiap malam',
      'en': 'Nightly log-your-expenses reminder'
    },
    'notif_harian_sub': {
      'id': 'Sekali sehari biar buku kas selalu mutakhir',
      'en': 'Once a day to keep your ledger up to date'
    },
    'notif_pagi': {
      'id': 'Pengingat pagi harian',
      'en': 'Daily morning reminder'
    },
    'notif_pagi_sub': {
      'id': 'Tiap pagi: pegangan & jatah hari ini (default mati)',
      'en': 'Every morning: cash on hand & today\'s allowance (off by default)'
    },
    'notif_pagi_title': {
      'id': 'Selamat pagi!',
      'en': 'Good morning!'
    },
    'notif_pagi_body': {
      'id': 'Pegangan {s} • jatah hari ini {j}',
      'en': 'Cash {s} • today\'s allowance {j}'
    },
    'notif_jadwal_ada': {
      'id': '{n} pengingat terjadwal sekarang',
      'en': '{n} reminders scheduled right now'
    },
    'notif_jadwal_kosong': {
      'id': 'Belum ada jadwal pengingat - muncul otomatis saat ada kiriman '
          'menunggu, utang menjelang jatuh tempo, atau target bertanggal',
      'en': 'No reminders scheduled yet - they appear automatically when '
          'there is a pending transfer, an upcoming debt, or a dated target'
    },
    'notif_baterai': {
      'id': 'Pengingat tidak muncul? Keluarkan kosku dari optimasi baterai '
          'dan izinkan autostart (Setelan HP > Baterai / Autostart).',
      'en': 'Reminders not showing? Exclude kosku from battery optimization '
          'and allow autostart (Phone settings > Battery / Autostart).'
    },
    'notif_jam_pagi': {
      'id': 'Jam pengingat kiriman, utang & target',
      'en': 'Transfer, debt & target reminder time'
    },
    'notif_jam_pagi_sub': {
      'id': 'Default 08.00 - dipakai pengingat pagi harian & pengingat '
          'tanggal: pagi hari kiriman, H-1 / hari jatuh tempo, dan '
          'H-1 deadline target',
      'en': 'Default 8:00 AM - used by the daily morning reminder and for '
          'event days: transfer arrival day, day before / due day of '
          'debts, day before target deadlines'
    },
    'notif_jam_malam': {
      'id': 'Jam pengingat catat pengeluaran',
      'en': 'Log-your-expenses reminder time'
    },
    'notif_jam_malam_sub': {
      'id': 'Default 20.00 - pengingat malam biar buku kas mutakhir',
      'en': 'Default 8:00 PM - the evening nudge time'
    },
    'notif_jam_tersimpan': {
      'id': 'Jam pengingat tersimpan - jadwal dipasang ulang',
      'en': 'Reminder time saved - schedules re-armed'
    },
    'notif_aktif': {'id': 'Pengingat dinyalakan', 'en': 'Reminders on'},
    'notif_mati': {'id': 'Pengingat dimatikan', 'en': 'Reminders off'},
    'notif_kiriman_title': {
      'id': 'Kiriman {n} semestinya datang hari ini',
      'en': 'Transfer of {n} expected today'
    },
    'notif_kiriman_body': {
      'id': 'Kalau uangnya sudah masuk, buka kosku dan konfirmasi.',
      'en': 'If it arrived, open kosku and confirm it.'
    },
    'notif_utang_title': {
      'id': 'Besok jatuh tempo: {x}',
      'en': 'Due tomorrow: {x}'
    },
    'notif_utang_body': {
      'id': 'Buka kosku buat cek utang / piutangmu.',
      'en': 'Open kosku to check your debt / loan.'
    },
    'notif_utang_hari_ini_title': {
      'id': 'Hari ini jatuh tempo: {x}',
      'en': 'Due today: {x}'
    },
    'notif_target_title': {
      'id': 'Besok deadline target: {x}',
      'en': 'Target deadline tomorrow: {x}'
    },
    'notif_target_body': {
      'id': 'Kurang {n} lagi - cek targetmu di kosku.',
      'en': '{n} to go - check your target in kosku.'
    },
    'notif_target_body_ok': {
      'id': 'Uangmu sudah cukup - tinggal eksekusi.',
      'en': 'You can afford it already - go get it.'
    },
    'notif_catat_title': {
      'id': 'Sudah catat pengeluaran hari ini?',
      'en': 'Logged today\u2019s spending yet?'
    },
    'notif_catat_body': {
      'id': 'Sekali catat, saldo & jatah harian selalu akurat.',
      'en': 'One quick log keeps your balance & allowance accurate.'
    },
    'notif_uji_title': {
      'id': 'Pengingat kosku jalan',
      'en': 'kosku reminders work'
    },
    'notif_uji_body': {
      'id': 'Kalau pesan ini muncul, izin notifikasi sudah benar.',
      'en': 'If you can read this, notification permission is fine.'
    },
    'notif_uji_jadwal_title': {
      'id': 'Pengingat terjadwal juga jalan',
      'en': 'Scheduled reminders work too'
    },
    'notif_uji_jadwal_body': {
      'id': 'Pesan ini dijadwalkan 1 menit lalu - alarm terjadwal OK.',
      'en': 'This was scheduled 1 minute ago - scheduled alarms are OK.'
    },
    'notif_uji_tombol': {
      'id': 'Kirim notifikasi uji',
      'en': 'Send test notification'
    },
    'notif_uji_sub': {
      'id': 'Satu langsung muncul + satu terjadwal 1 menit lagi',
      'en': 'One shows instantly + one arrives in 1 minute'
    },
    'notif_uji_ok': {
      'id': 'Notifikasi uji terkirim - cek panel notifikasimu',
      'en': 'Test notifications sent - check your notification panel'
    },
    'notif_uji_gagal': {
      'id': 'Gagal menyiapkan notifikasi - cek izin notifikasi di pengaturan HP',
      'en': 'Failed to set up notifications - check the permission in phone settings'
    },

    'data_judul': {'id': 'Data', 'en': 'Data'},
    'data_desc': {
      'id': 'Semua data tersimpan lokal di HP ini (SQLite). '
          'Menghapus tidak bisa dibatalkan.',
      'en': 'All data is stored locally on this phone (SQLite). '
          'Deletion cannot be undone.'
    },
    'hapus_semua': {'id': 'Hapus semua data', 'en': 'Erase all data'},

    // ---- Ekspor buku kas ke CSV (backup yang bisa dibuka Excel) ----
    'ekspor_csv': {'id': 'Ekspor buku kas (CSV)', 'en': 'Export ledger (CSV)'},
    'ekspor_csv_sub': {
      'id': 'Semua transaksi jadi satu file - bisa dibuka di Excel '
          'atau dikirim ke WhatsApp / email sebagai cadangan.',
      'en': 'All transactions in one file - open it in Excel or send '
          'it to WhatsApp / email as a backup.'
    },
    'ekspor_csv_ok': {'id': 'Buku kas diekspor', 'en': 'Ledger exported'},
    'ekspor_csv_gagal': {
      'id': 'Gagal mengekspor buku kas',
      'en': 'Failed to export the ledger'
    },
    'ekspor_csv_kosong': {
      'id': 'Belum ada transaksi buat diekspor',
      'en': 'No transactions to export yet'
    },
    'csv_h_tanggal': {'id': 'Tanggal', 'en': 'Date'},
    'csv_h_jam': {'id': 'Jam', 'en': 'Time'},
    'csv_h_jenis': {'id': 'Jenis', 'en': 'Type'},
    'csv_h_kategori': {'id': 'Kategori', 'en': 'Category'},
    'csv_h_nama': {'id': 'Nama', 'en': 'Name'},
    'csv_h_jumlah': {'id': 'Jumlah', 'en': 'Amount'},
    'csv_h_sumber': {'id': 'Sumber', 'en': 'Source'},
    'hapus_semua_judul': {
      'id': 'Hapus SEMUA data?',
      'en': 'Erase ALL data?'
    },
    'hapus_semua_pesan': {
      'id': 'Semua transaksi, kiriman, target, dan utang akan hilang '
          'permanen (termasuk salinan di cloud).',
      'en': 'All transactions, transfers, targets, and debts will be erased '
          'permanently (including the cloud copy).'
    },
    'snack_semua_hapus': {
      'id': 'Semua data dihapus',
      'en': 'All data erased'
    },
    'snack_semua_hapus_tunda': {
      'id': 'Data di HP sudah dihapus. Salinan di cloud akan dibersihkan '
          'otomatis begitu online.',
      'en': 'Data on this phone is erased. The cloud copy will be cleaned '
          'up automatically once online.'
    },

    // Tentang
    'tentang_judul': {'id': 'Kosku v2.17.3', 'en': 'Kosku v2.17.3'},
    'tentang_desc': {
      'id': 'Pencatat uang pribadi offline-first.\n'
          'Fitur inti jalan tanpa internet; pindai struk butuh online.',
      'en': 'Offline-first personal money tracker.\n'
          'Core features work without internet; receipt scanning needs '
          'to be online.'
    },

    // ============ LOGIN / DAFTAR ============
    'masuk_judul': {'id': 'Masuk', 'en': 'Sign in'},
    'daftar_judul': {'id': 'Daftar', 'en': 'Register'},
    'email': {'id': 'Email', 'en': 'Email'},
    'sandi': {'id': 'Kata sandi', 'en': 'Password'},
    'sandi_hint': {'id': 'Minimal 6 karakter', 'en': 'At least 6 characters'},
    'tombol_masuk': {'id': 'Masuk', 'en': 'Sign in'},
    'tombol_daftar': {'id': 'Buat akun', 'en': 'Create account'},
    'lupa_sandi': {'id': 'Lupa sandi?', 'en': 'Forgot password?'},
    'snack_reset_terkirim': {
      'id': 'Email reset terkirim, cek inbox (dan folder spam).',
      'en': 'Reset email sent, check your inbox (and spam folder).'
    },
    'pakai_offline': {
      'id': 'Pakai offline dulu',
      'en': 'Use offline for now'
    },
    'akun_sub': {
      'id': 'Satu akun = backup otomatis + data nyambung antar HP.',
      'en': 'One account = automatic backup + data across phones.'
    },

    // Error auth
    'auth_err_isi_dulu': {
      'id': 'Isi email dan sandinya dulu.',
      'en': 'Enter your email and password first.'
    },
    'auth_err_invalid_email': {
      'id': 'Format email tidak valid.',
      'en': 'Invalid email format.'
    },
    'auth_err_wrong_password': {
      'id': 'Sandi salah.',
      'en': 'Wrong password.'
    },
    'auth_err_user_not_found': {
      'id': 'Akun dengan email ini belum terdaftar.',
      'en': 'No account registered with this email.'
    },
    'auth_err_email_in_use': {
      'id': 'Email sudah dipakai akun lain.',
      'en': 'Email already used by another account.'
    },
    'auth_err_weak_password': {
      'id': 'Sandi terlalu lemah (minimal 6 karakter).',
      'en': 'Password too weak (at least 6 characters).'
    },
    'auth_err_network': {
      'id': 'Tidak bisa konek, cek internet. Login butuh online.',
      'en': 'Cannot connect, check the internet. Signing in needs to be online.'
    },
    'auth_err_too_many': {
      'id': 'Terlalu banyak percobaan, tunggu beberapa menit.',
      'en': 'Too many attempts, wait a few minutes.'
    },
    'auth_err_lain': {
      'id': 'Gagal: {x}',
      'en': 'Failed: {x}'
    },

    // ============ VERIFIKASI EMAIL ============
    'verif_judul': {
      'id': 'Verifikasi Email',
      'en': 'Email Verification'
    },
    'verif_kartu_judul': {
      'id': 'Cek emailmu, tinggal klik linknya',
      'en': 'Check your email, just tap the link'
    },
    'verif_desc': {
      'id': 'Kami kirim link verifikasi ke {e}. Buka emailnya dan klik '
          'linknya, aplikasi langsung lanjut sendiri begitu verifikasi '
          'terbaca.',
      'en': 'We sent a verification link to {e}. Open the email and tap the '
          'link, the app continues automatically once it is detected.'
    },
    'verif_kirim_ulang': {
      'id': 'Kirim ulang email',
      'en': 'Resend email'
    },
    'verif_tunggu': {
      'id': 'Kirim ulang ({n} detik)',
      'en': 'Resend ({n}s)'
    },
    'verif_terkirim': {
      'id': 'Email verifikasi terkirim, cek inbox & spam.',
      'en': 'Verification email sent, check your inbox & spam.'
    },
    'verif_ceklagi': {
      'id': 'Sudah diklik, cek sekarang',
      'en': 'I already tapped it, check now'
    },
    'verif_belum': {
      'id': 'Belum terbaca terverifikasi. Klik linknya dulu di email, '
          'atau kirim ulang.',
      'en': 'Not verified yet. Tap the link in the email first, or resend.'
    },
    'verif_sukses': {
      'id': 'Email terverifikasi, sinkronisasi aktif!',
      'en': 'Email verified, sync is active!'
    },
    'verif_offline_note': {
      'id': 'Tidak mau nunggu? Aplikasi tetap bisa dipakai penuh secara '
          'lokal, data nanti tersinkron otomatis setelah verifikasi.',
      'en': 'No time to wait? The app works fully offline meanwhile, data '
          'syncs automatically once the email is verified.'
    },
    'verif_keluar': {
      'id': 'Keluar dari akun ini',
      'en': 'Sign out of this account'
    },
    'verif_banner_judul': {
      'id': 'Email belum diverifikasi',
      'en': 'Email not verified yet'
    },
    'verif_banner_desc': {
      'id': 'Sinkronisasi cloud baru aktif setelah email diverifikasi. '
          'Data kamu tetap aman di HP ini.',
      'en': 'Cloud sync activates after your email is verified. Your data '
          'stays safe on this phone.'
    },

    // ============ LAYAR KUNCI ============
    'kunci_judul': {'id': 'Sesi kedaluwarsa', 'en': 'Session expired'},
    'kunci_pesan': {
      'id': 'Kamu offline lebih lama dari masa tenggang ({n} hari), jadi Kosku '
          'mengunci data demi keamanan. Login online sekali lagi, data yang '
          'belum terkirim tetap aman di HP ini.',
      'en': 'You were offline longer than the grace period ({n} days), so Kosku '
          'locked the data for safety. Sign in online once more, unsent data '
          'is still safe on this phone.'
    },
    'kunci_pesan_wipe': {
      'id': 'Kamu offline lebih lama dari masa tenggang ({n} hari). Sesuai '
          'pengaturan keamananmu, data lokal di HP ini sudah dihapus. '
          'Login online untuk memulihkan dari cloud.',
      'en': 'You were offline longer than the grace period ({n} days). '
          'Per your security setting, the local data on this phone was erased. '
          'Sign in online to restore from the cloud.'
    },

    // ============ STATUS SYNC (chip di Home) ============
    'sync_lokal': {
      'id': 'Mode lokal, data hanya di HP ini',
      'en': 'Local mode, data only on this phone'
    },
    'sync_sinkron': {'id': 'Semua sudah sinkron', 'en': 'Everything synced'},
    'sync_antri': {
      'id': '{n} perubahan menunggu dikirim',
      'en': '{n} changes waiting to send'
    },
    'sync_offline': {
      'id': 'Offline, perubahan disimpan lokal',
      'en': 'Offline, changes saved locally'
    },
    'sync_error': {
      'id': 'Sinkronisasi gagal, coba lagi nanti',
      'en': 'Sync failed, try again later'
    },

    // ============ LAPORAN BULANAN ============
    'laporan_judul': {'id': 'Laporan Bulanan', 'en': 'Monthly Report'},
    'total_pengeluaran': {'id': 'Total pengeluaran', 'en': 'Total spent'},
    'rata_harian': {'id': 'Rata-rata / hari', 'en': 'Average / day'},
    'jumlah_transaksi': {'id': '{n} transaksi', 'en': '{n} transactions'},
    'hari_tanpa_belanja': {
      'id': '{n} hari tanpa belanja',
      'en': '{n} no-spend days'
    },
    // Label polos (tanpa placeholder) buat kotak statistik PDF -
    // angkanya ditampilkan terpisah di bawah label.
    'jumlah_transaksi_label': {
      'id': 'Jumlah transaksi',
      'en': 'Transactions'
    },
    'hari_tanpa_belanja_label': {
      'id': 'Hari tanpa belanja',
      'en': 'No-spend days'
    },
    'per_kategori': {'id': 'Per kategori', 'en': 'By category'},
    'tren_harian': {'id': 'Tren harian', 'en': 'Daily trend'},
    'tren_harian_sub': {
      'id': 'Tekan titik pada grafik untuk lihat nominal per tanggal',
      'en': 'Tap a point on the chart to see the amount per date'
    },
    'pengeluaran_terbesar': {
      'id': 'Pengeluaran terbesar',
      'en': 'Biggest expense'
    },
    'vs_bulan_lalu': {'id': 'vs bulan lalu', 'en': 'vs last month'},
    'naik_persen': {'id': 'naik {p}%', 'en': 'up {p}%'},
    'turun_persen': {'id': 'turun {p}%', 'en': 'down {p}%'},
    'tetap_sama': {'id': 'tetap sama', 'en': 'flat'},
    'bulan_pertama': {
      'id': 'Belum ada data bulan sebelumnya',
      'en': 'No previous-month data yet'
    },
    'laporan_kosong': {
      'id': 'Belum ada pengeluaran bulan ini.',
      'en': 'No expenses this month yet.'
    },
    'top_bergerak': {'id': 'Pergerakan terbesar', 'en': 'Biggest movers'},
    'pengeluaran_lainnya': {'id': 'Uang keluar lain', 'en': 'Other money out'},
    'pengeluaran_lainnya_sub': {
      'id': 'Kewajiban seperti kos, wifi, atau setor ke keluarga - tidak '
          'dihitung di total pengeluaran harian.',
      'en': 'Obligations like rent, wifi, or family savings - not counted '
          'in daily spending.'
    },
    'total_keluar_lain': {'id': 'Total uang keluar lain', 'en': 'Other money out total'},

    // ---- Kalender pengeluaran (peta warna per tanggal) ----
    'kalender_judul': {'id': 'Kalender pengeluaran', 'en': 'Spending calendar'},
    'kalender_sub': {
      'id': 'Warna tiap tanggal: total belanja hari itu vs jatah '
          'harianmu sekarang ({j}/hari). Ketuk tanggal untuk lihat nominal.',
      'en': 'Each day is colored by that day\u2019s spending vs your '
          'current allowance ({j}/day). Tap a date to see the amount.'
    },
    'kalender_hemat': {'id': 'Di bawah jatah', 'en': 'Under budget'},
    'kalender_lewat': {'id': 'Lewat jatah', 'en': 'Over budget'},
    'kalender_kosong': {'id': 'Tidak belanja', 'en': 'No spending'},
    'kalender_nominal': {
      'id': '{d}: belanja {n}',
      'en': '{d}: spent {n}'
    },

    // ============ SAMBUTAN (layar awal) ============
    'sambutan_tagline': {
      'id': 'Catat pegangan, tentukan budget harian, scan struk. Sederhana, semuanya di HPmu.',
      'en': 'Track your cash, set a daily budget, scan receipts. Simple, and it all lives on your phone.'
    },
    'sambutan_poin1': {
      'id': 'Catat pengeluaran dalam 5 detik',
      'en': 'Log an expense in 5 seconds'
    },
    'sambutan_poin2': {
      'id': 'Scan struk & bukti transfer',
      'en': 'Scan receipts & transfer proofs'
    },
    'sambutan_poin3': {
      'id': 'Budget harian yang ngitung sendiri',
      'en': 'A daily budget that counts itself'
    },
    'sambutan_poin4': {
      'id': 'Jalan penuh tanpa internet',
      'en': 'Works fully offline'
    },

    // ============ UANG MASUK/KELUAR LAIN (bukan kiriman) ============
    // Pintu masuknya sekarang lewat menu Home ("Pemasukan lainnya" /
    // "Pengeluaran lainnya"), sejajar dengan Kiriman/Utang/Dana Darurat.
    'uang_masuk_lain': {'id': 'Uang masuk lain', 'en': 'Other money in'},
    'uang_keluar_lain': {'id': 'Uang keluar lain', 'en': 'Other money out'},
    'uang_masuk_lain_sub': {
      'id': 'Bukan dari kiriman: hadiah, barang terjual, cashback...',
      'en': 'Not from your transfer: gifts, sold stuff, cashback...'
    },
    'uang_keluar_lain_sub': {
      'id': 'Bukan pengeluaran: setor tabungan, kas ke keluarga...',
      'en': 'Not spending: savings deposit, cash to family...'
    },
    'buat_apa': {
      'id': 'Buat apa? (opsional)',
      'en': 'For what? (optional)'
    },
    'snack_masuk_lain': {
      'id': 'Tercatat. Pegangan sekarang {n}',
      'en': 'Logged. Cash now {n}'
    },
    'snack_keluar_lain': {
      'id': 'Tercatat. Pegangan sekarang {n}',
      'en': 'Logged. Cash now {n}'
    },
    'uang_lain_judul': {
      'id': 'Catat uang lain',
      'en': 'Log other money'
    },
    'jenis_masuk_lain': {'id': 'Uang masuk lain', 'en': 'Other money in'},
    'jenis_keluar_lain': {'id': 'Uang keluar lain', 'en': 'Other money out'},
    'judul_masuk_lain': {'id': 'Uang masuk', 'en': 'Money in'},
    'judul_keluar_lain': {'id': 'Uang keluar', 'en': 'Money out'},
    'filter_lainnya': {'id': 'Lainnya', 'en': 'Other'},

    // ============ IMBAS TRANSAKSI (pratinjau sebelum catat) ============
    'imbas_oto': {
      'id': 'Setelah ini pegangan jadi {s}. Batas otomatismu jadi {b}/hari.',
      'en': 'After this your balance is {s}. Your auto limit becomes {b}/day.'
    },
    'imbas_aman': {
      'id': 'Setelah ini pegangan jadi {s}. Dengan batas {b}/hari, uang '
          'cukup sampai {d} (sisa ±{n}).',
      'en': 'After this your balance is {s}. With a {b}/day limit, money '
          'lasts until {d} (±{n} left).'
    },
    'imbas_kurang': {
      'id': 'Setelah ini pegangan jadi {s}. Dengan batas {b}/hari, uang '
          'habis sekitar {d} ({k} hari kurang). Saran: {r}/hari.',
      'en': 'After this your balance is {s}. With a {b}/day limit, money '
          'runs out around {d} ({k} days short). Suggested: {r}/day.'
    },

    // ============ SALDO TIDAK BOLEH MINUS ============
    'snack_saldo_kurang': {
      'id': 'Saldo pegangan cuma {n}. Catat uang masuk dulu atau kecilin nominalnya.',
      'en': 'Cash on hand is only {n}. Log incoming money first or lower the amount.'
    },
    'maks_nominal': {
      'id': 'Maksimal {n}',
      'en': 'Up to {n}'
    },
    'habis_saldo_judul': {
      'id': 'Habisin hampir semua saldo?',
      'en': 'Spend almost all your cash?'
    },
    'habis_saldo_pesan': {
      'id': 'Setelah ini pegangan sisa {a}, padahal kamu butuh sekitar '
          '{b}/hari untuk {d} hari ke depan. Tetap lanjut?',
      'en': 'After this you would have {a} left, but you typically need '
          'about {b}/day for the next {d} days. Continue anyway?'
    },
    'tetap_lanjut': {'id': 'Tetap lanjut', 'en': 'Continue anyway'},

    // ============ SCAN: POTONG & PUTAR ============
    'potong_putar': {
      'id': 'Potong / putar',
      'en': 'Crop / rotate'
    },
    'crop_gagal': {
      'id': 'Editor foto tidak bisa dibuka, coba ambil ulang fotonya.',
      'en': 'The photo editor could not open, try re-taking the photo.'
    },

    // Default tanggal scan = TANGGAL DOKUMEN (sesuai isi struk);
    // satu ketuk untuk mencatatnya sebagai hari ini (mis. struk lama
    // baru dibayar sekarang), dan sebaliknya.
    'scan_tanggal_dokumen': {
      'id': 'Tanggal dokumen: {d}',
      'en': 'Document date: {d}'
    },
    'scan_pakai_tanggal_dokumen': {
      'id': 'Pakai tanggal dokumen',
      'en': 'Use document date'
    },
    'scan_pakai_hari_ini': {
      'id': 'Kembali ke hari ini',
      'en': 'Back to today'
    },
    // Tanggal hasil bacaan ditolak gerbang (tahun lalu / lebih dari
    // sebulan / masa depan) - pencatatan otomatis pakai hari ini + jam
    // scan, user diberi tahu kenapa.
    'scan_tanggal_ditolak': {
      'id':
          'Tanggal di dokumen terbaca {d} - tidak wajar (tahun lalu / '
          'lebih dari sebulan / masa depan), jadi pencatatan memakai '
          'hari ini & jam scan.',
      'en':
          'The document date reads {d} - not plausible (last year / '
          'more than a month ago / in the future), so it is recorded '
          'as today at scan time.'
    },

    // ============ BAGIKAN DARI APP LAIN ============
    'bagikan_terisi': {
      'id': 'Teks terisi dari aplikasi lain',
      'en': 'Text filled from another app'
    },
    'bagikan_foto_terima': {
      'id': 'Foto diterima dari aplikasi lain',
      'en': 'Photo received from another app'
    },

    // ============ EKSPOR PDF ============
    'ekspor_pdf': {'id': 'Ekspor PDF', 'en': 'Export PDF'},
    'pdf_gagal': {
      'id': 'Gagal membuat PDF',
      'en': 'Could not create the PDF'
    },
    'pdf_dibuat_oleh': {
      'id': 'Dibuat oleh Kosku',
      'en': 'Generated by Kosku'
    },
    'pdf_pemasukan': {
      'id': 'Uang masuk',
      'en': 'Money in'
    },
  };
}
