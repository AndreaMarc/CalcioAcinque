class PlayerModel {
  final int id;
  final int teamId;
  final int userId;
  final String nome;
  final String? soprannome;
  final String? telefono;
  final String ruolo;
  final int gettoniTotali;
  final int gettoniConsumati;
  final int gettoniRimanenti;
  final bool iscrizionePagata;
  final bool tesseramentoPagato;

  PlayerModel({
    required this.id, required this.teamId, required this.userId,
    required this.nome, this.soprannome, this.telefono, required this.ruolo,
    required this.gettoniTotali, required this.gettoniConsumati,
    required this.gettoniRimanenti, required this.iscrizionePagata,
    required this.tesseramentoPagato,
  });

  factory PlayerModel.fromJson(Map<String, dynamic> json) => PlayerModel(
    id: json['id'], teamId: json['teamId'], userId: json['userId'],
    nome: json['nome'] ?? '', soprannome: json['soprannome'],
    telefono: json['telefono'], ruolo: json['ruolo'] ?? 'User',
    gettoniTotali: json['gettoniTotali'] ?? 0,
    gettoniConsumati: json['gettoniConsumati'] ?? 0,
    gettoniRimanenti: json['gettoniRimanenti'] ?? 0,
    iscrizionePagata: json['iscrizionePagata'] ?? false,
    tesseramentoPagato: json['tesseramentoPagato'] ?? false,
  );

  String get displayName => soprannome ?? nome;
  bool get isAdmin => ruolo == 'Admin';
  bool get gettoniEsauriti => gettoniRimanenti <= 0;
}
