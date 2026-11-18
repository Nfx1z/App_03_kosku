/// arah = ngutang  : AKU yang berutang (dapet duit, saldo nambah).
/// arah = ngutangin : AKU yang ngasih pinjam (saldo kepotong).
enum ArahUtang { ngutang, ngutangin }

enum StatusUtang { aktif, lunas }

class Utang {
  final int? id;
  final ArahUtang arah;
  final String pihak; // nama orang / siapa
  final int nominal;
  final DateTime? jatuhTempo; // opsional
  final String? catatan;
  final StatusUtang status;
  final DateTime dibuatPada;

  // ---- kolom sinkronisasi cloud (fase 2) ----
  final String? cloudId;
  final bool dihapus;
  final int diubahPada;

  Utang({
    this.id,
    required this.arah,
    required this.pihak,
    required this.nominal,
    this.jatuhTempo,
    this.catatan,
    this.status = StatusUtang.aktif,
    DateTime? dibuatPada,
    this.cloudId,
    this.dihapus = false,
    this.diubahPada = 0,
  }) : dibuatPada = dibuatPada ?? DateTime.now();

  bool get lunas => status == StatusUtang.lunas;

  Map<String, Object?> keMap() => {
        'id': id,
        'arah': arah.name,
        'pihak': pihak,
        'nominal': nominal,
        'jatuh_tempo': jatuhTempo?.toIso8601String().substring(0, 10),
        'catatan': catatan,
        'status': status.name,
        'dibuat_pada': dibuatPada.toIso8601String(),
        'cloud_id': cloudId,
        'dihapus': dihapus ? 1 : 0,
        'diubah_pada': diubahPada,
      };

  factory Utang.dariMap(Map<String, Object?> m) {
    final t = m['jatuh_tempo'] == null
        ? null
        : DateTime.parse(m['jatuh_tempo'] as String);
    return Utang(
      id: m['id'] as int?,
      arah: (m['arah'] as String) == 'ngutangin'
          ? ArahUtang.ngutangin
          : ArahUtang.ngutang,
      pihak: m['pihak'] as String,
      nominal: m['nominal'] as int,
      jatuhTempo: t == null ? null : DateTime(t.year, t.month, t.day),
      catatan: m['catatan'] as String?,
      status: (m['status'] as String) == 'lunas' ? StatusUtang.lunas : StatusUtang.aktif,
      dibuatPada: DateTime.parse(m['dibuat_pada'] as String),
      cloudId: m['cloud_id'] as String?,
      dihapus: (m['dihapus'] as int? ?? 0) == 1,
      diubahPada: (m['diubah_pada'] as int?) ?? 0,
    );
  }

  Utang salinan({
    int? id,
    String? cloudId,
    bool? dihapus,
    int? diubahPada,
    StatusUtang? status,
  }) =>
      Utang(
        id: id ?? this.id,
        arah: arah,
        pihak: pihak,
        nominal: nominal,
        jatuhTempo: jatuhTempo,
        catatan: catatan,
        status: status ?? this.status,
        dibuatPada: dibuatPada,
        cloudId: cloudId ?? this.cloudId,
        dihapus: dihapus ?? this.dihapus,
        diubahPada: diubahPada ?? this.diubahPada,
      );
}
