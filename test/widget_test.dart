// Smoke test pengganti file bawaan `flutter create`.
//
// Catatan: file widget_test.dart lama (hasil `flutter create` dengan nama
// project lama `kosku`) menunjuk ke `package:kosku/main.dart` dan class
// `MyApp` yang tidak ada di project ini - sehingga `flutter analyze` gagal.
// File ini menggantikannya.
//
// Sengaja tidak mem-pump `KoskuApp` (butuh SQLite & Firebase runtime) -
// cukup uji kamus dwibahasa yang menjadi fondasi semua label UI.
import 'package:flutter_test/flutter_test.dart';
import 'package:kosku/utils/teks.dart';

void main() {
  test('Kamus dwibahasa: default bahasa Indonesia', () {
    T.bahasa = 'id';
    expect(T.t('simpan'), 'Simpan');
    expect(T.t('batal'), 'Batal');
  });

  test('Kamus dwibahasa: ganti bahasa ke Inggris', () {
    T.bahasa = 'en';
    expect(T.t('simpan'), 'Save');
    expect(T.t('batal'), 'Cancel');
    // Placeholder {n} terganti dengan nilai parameter.
    expect(T.f('jumlah_transaksi', {'n': '12'}), contains('12'));
    // Kembalikan ke default agar tidak mempengaruhi test lain.
    T.bahasa = 'id';
  });

  test('Kunci tidak dikenal dikembalikan apa adanya', () {
    T.bahasa = 'id';
    expect(T.t('kunci_tidak_ada_xyz'), 'kunci_tidak_ada_xyz');
  });
}
