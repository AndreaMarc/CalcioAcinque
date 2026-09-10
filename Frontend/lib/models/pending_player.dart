class PendingPlayer {
  final int id;
  final String nome;
  final String? soprannome;
  final String? posizione;
  final int bravura;
  final int affidabilita;
  final bool tesserato;
  final String? note;

  PendingPlayer({
    required this.id,
    required this.nome,
    this.soprannome,
    this.posizione,
    required this.bravura,
    required this.affidabilita,
    required this.tesserato,
    this.note,
  });

  factory PendingPlayer.fromJson(Map<String, dynamic> json) => PendingPlayer(
        id: json['id'] as int,
        nome: json['nome'] as String,
        soprannome: json['soprannome'] as String?,
        posizione: json['posizione'] as String?,
        bravura: (json['bravura'] as num?)?.toInt() ?? 3,
        affidabilita: (json['affidabilita'] as num?)?.toInt() ?? 3,
        tesserato: json['tesserato'] as bool? ?? false,
        note: json['note'] as String?,
      );
}
