class ConvocationModel {
  final int id;
  final int matchId;
  final int playerId;
  final String nomeGiocatore;
  final String? soprannome;
  final String statoRisposta;
  final DateTime dataConvocazione;
  final DateTime? dataRisposta;
  final DateTime? dataPartita;
  final String? oraPartita;
  final String? luogoPartita;
  final int? numeroGiornata;

  ConvocationModel({
    required this.id, required this.matchId, required this.playerId,
    required this.nomeGiocatore, this.soprannome, required this.statoRisposta,
    required this.dataConvocazione, this.dataRisposta, this.dataPartita,
    this.oraPartita, this.luogoPartita, this.numeroGiornata,
  });

  factory ConvocationModel.fromJson(Map<String, dynamic> json) => ConvocationModel(
    id: json['id'], matchId: json['matchId'], playerId: json['playerId'],
    nomeGiocatore: json['nomeGiocatore'] ?? '',
    soprannome: json['soprannome'],
    statoRisposta: json['statoRisposta'] ?? 'InAttesa',
    dataConvocazione: DateTime.parse(json['dataConvocazione']),
    dataRisposta: json['dataRisposta'] != null ? DateTime.parse(json['dataRisposta']) : null,
    dataPartita: json['dataPartita'] != null ? DateTime.parse(json['dataPartita']) : null,
    oraPartita: json['oraPartita'], luogoPartita: json['luogoPartita'],
    numeroGiornata: json['numeroGiornata'],
  );

  bool get isInAttesa => statoRisposta == 'InAttesa';
  bool get isConfermato => statoRisposta == 'Confermato';
  bool get isNonDisponibile => statoRisposta == 'NonDisponibile';
}
