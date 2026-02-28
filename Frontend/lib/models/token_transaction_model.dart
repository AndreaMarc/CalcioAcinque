class TokenTransactionModel {
  final int id;
  final int playerId;
  final String nomeGiocatore;
  final int? matchId;
  final int? numeroGiornata;
  final String tipo;
  final String motivazione;
  final int quantita;
  final String adminNome;
  final DateTime timestamp;

  TokenTransactionModel({
    required this.id, required this.playerId, required this.nomeGiocatore,
    this.matchId, this.numeroGiornata, required this.tipo,
    required this.motivazione, required this.quantita,
    required this.adminNome, required this.timestamp,
  });

  factory TokenTransactionModel.fromJson(Map<String, dynamic> json) => TokenTransactionModel(
    id: json['id'], playerId: json['playerId'],
    nomeGiocatore: json['nomeGiocatore'] ?? '',
    matchId: json['matchId'], numeroGiornata: json['numeroGiornata'],
    tipo: json['tipo'] ?? '', motivazione: json['motivazione'] ?? '',
    quantita: json['quantita'] ?? 0, adminNome: json['adminNome'] ?? '',
    timestamp: DateTime.parse(json['timestamp']),
  );

  bool get isConsumo => tipo == 'ConsumoAutomatico';
  bool get isAggiunta => tipo == 'AggiuntaManuale';
  bool get isRimozione => tipo == 'RimozioneManuale';
  bool get isOverride => tipo == 'Override';
}
