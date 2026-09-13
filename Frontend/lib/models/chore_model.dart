/// Turni di squadra: i compiti configurati e a chi toccano per una partita.
class TeamChoreModel {
  final int id;
  final String nome;
  final bool attivo;
  final int ordine;

  TeamChoreModel({required this.id, required this.nome, required this.attivo, required this.ordine});

  factory TeamChoreModel.fromJson(Map<String, dynamic> json) => TeamChoreModel(
        id: json['id'] as int,
        nome: json['nome'] as String? ?? '',
        attivo: json['attivo'] as bool? ?? true,
        ordine: (json['ordine'] as num?)?.toInt() ?? 0,
      );
}

class MatchChoreModel {
  final int choreId;
  final String nome;
  final int? playerId;
  final String? nomeGiocatore;
  final String? soprannome;

  MatchChoreModel({
    required this.choreId,
    required this.nome,
    this.playerId,
    this.nomeGiocatore,
    this.soprannome,
  });

  bool get assegnato => playerId != null;
  String get chi => (soprannome ?? '').isNotEmpty ? soprannome! : (nomeGiocatore ?? 'da assegnare');

  factory MatchChoreModel.fromJson(Map<String, dynamic> json) => MatchChoreModel(
        choreId: json['choreId'] as int,
        nome: json['nome'] as String? ?? '',
        playerId: json['playerId'] as int?,
        nomeGiocatore: json['nomeGiocatore'] as String?,
        soprannome: json['soprannome'] as String?,
      );
}
