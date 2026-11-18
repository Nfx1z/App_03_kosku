enum StatusTarget { aktif, tercapai }

/// Target beli sesuatu (mis. "naik gunung budget 5jt", "lipstik 100rb").
class TargetBeli {
  final int? id;
  final String nama;
  final int nominal;
  final DateTime? tanggal; // deadline, opsional
  final StatusTarget status;
  final DateTime dibuatPada;

  // ---- kolom sinkronisasi cloud (fase 2) ----
  final String? cloudId;
  final bool dihapus;
  final int diubahPada;

  TargetBeli({
    this.id,
    required this.nama,
    required this.nominal,
    this.tanggal,
    this.status = StatusTarget.aktif,
    DateTime? dibuatPada,
    this.cloudId,
    this.dihapus = false,
    this.diubahPada = 0,
  }) : dibuatPada = dibuatPada ?? DateTime.now();

  bool get tercapai => status == StatusTarget.tercapai;

  Map<String, Object?> keMap() => {
        'id': id,
        'nama': nama,
        'nominal': nominal,
        'tanggal': tanggal?.toIso8601String().substring(0, 10),
        'status': status.name,
        'dibuat_pada': dibuatPada.toIso8601String(),
        'cloud_id': cloudId,
        'dihapus': dihapus ? 1 : 0,
        'diubah_pada': diubahPada,
      };

  factory TargetBeli.dariMap(Map<String, Object?> m) {
    final t = m['tanggal'] == null ? null : DateTime.parse(m['tanggal'] as String);
    return TargetBeli(
      id: m['id'] as int?,
      nama: m['nama'] as String,
      nominal: m['nominal'] as int,
      tanggal: t == null ? null : DateTime(t.year, t.month, t.day),
      status: (m['status'] as String) == 'tercapai'
          ? StatusTarget.tercapai
          : StatusTarget.aktif,
      dibuatPada: DateTime.parse(m['dibuat_pada'] as String),
      cloudId: m['cloud_id'] as String?,
      dihapus: (m['dihapus'] as int? ?? 0) == 1,
      diubahPada: (m['diubah_pada'] as int?) ?? 0,
    );
  }

  TargetBeli salinan({
    int? id,
    String? cloudId,
    bool? dihapus,
    int? diubahPada,
    StatusTarget? status,
  }) =>
      TargetBeli(
        id: id ?? this.id,
        nama: nama,
        nominal: nominal,
        tanggal: tanggal,
        status: status ?? this.status,
        dibuatPada: dibuatPada,
        cloudId: cloudId ?? this.cloudId,
        dihapus: dihapus ?? this.dihapus,
        diubahPada: diubahPada ?? this.diubahPada,
      );
}
