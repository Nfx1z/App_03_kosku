enum StatusKiriman { menunggu, masuk }

/// Jadwal kiriman (transfer masuk) berikutnya.
class Kiriman {
  final int? id;
  final int nominal;
  final DateTime tanggalDatang; // tanggal saja (tanpa jam)
  final String? catatan;
  final StatusKiriman status;
  final DateTime dibuatPada;

  // ---- kolom sinkronisasi cloud (fase 2) ----
  final String? cloudId;
  final bool dihapus;
  final int diubahPada;

  Kiriman({
    this.id,
    required this.nominal,
    required this.tanggalDatang,
    this.catatan,
    this.status = StatusKiriman.menunggu,
    DateTime? dibuatPada,
    this.cloudId,
    this.dihapus = false,
    this.diubahPada = 0,
  }) : dibuatPada = dibuatPada ?? DateTime.now();

  bool get sudahMasuk => status == StatusKiriman.masuk;

  Map<String, Object?> keMap() => {
        'id': id,
        'nominal': nominal,
        'tanggal_datang': tanggalDatang.toIso8601String().substring(0, 10),
        'catatan': catatan,
        'status': status.name,
        'dibuat_pada': dibuatPada.toIso8601String(),
        'cloud_id': cloudId,
        'dihapus': dihapus ? 1 : 0,
        'diubah_pada': diubahPada,
      };

  factory Kiriman.dariMap(Map<String, Object?> m) {
    final t = DateTime.parse(m['tanggal_datang'] as String);
    return Kiriman(
      id: m['id'] as int?,
      nominal: m['nominal'] as int,
      tanggalDatang: DateTime(t.year, t.month, t.day),
      catatan: m['catatan'] as String?,
      status: (m['status'] as String) == 'masuk'
          ? StatusKiriman.masuk
          : StatusKiriman.menunggu,
      dibuatPada: DateTime.parse(m['dibuat_pada'] as String),
      cloudId: m['cloud_id'] as String?,
      dihapus: (m['dihapus'] as int? ?? 0) == 1,
      diubahPada: (m['diubah_pada'] as int?) ?? 0,
    );
  }

  Kiriman salinan({
    int? id,
    String? cloudId,
    bool? dihapus,
    int? diubahPada,
    StatusKiriman? status,
  }) =>
      Kiriman(
        id: id ?? this.id,
        nominal: nominal,
        tanggalDatang: tanggalDatang,
        catatan: catatan,
        status: status ?? this.status,
        dibuatPada: dibuatPada,
        cloudId: cloudId ?? this.cloudId,
        dihapus: dihapus ?? this.dihapus,
        diubahPada: diubahPada ?? this.diubahPada,
      );
}
