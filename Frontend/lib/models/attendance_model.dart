class AttendanceModel {
  final int id;
  final int matchId;
  final int playerId;
  final String nomeGiocatore;
  final String? soprannome;
  final bool convocato;
  final bool presente;
  final bool haGiocato;
  final bool gettoneConsumato;
  final int gettoniRimanenti;

  // Statistiche facoltative
  final int? minutiGiocati;
  final int? goal;
  final int? assist;
  final int? autogoal;
  final int? ammonizioni;
  final int? espulsioni;
  final int? goalSubiti;

  AttendanceModel({
    required this.id, required this.matchId, required this.playerId,
    required this.nomeGiocatore, this.soprannome,
    required this.convocato, required this.presente,
    required this.haGiocato, required this.gettoneConsumato,
    required this.gettoniRimanenti,
    this.minutiGiocati, this.goal, this.assist, this.autogoal,
    this.ammonizioni, this.espulsioni, this.goalSubiti,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) => AttendanceModel(
    id: json['id'], matchId: json['matchId'], playerId: json['playerId'],
    nomeGiocatore: json['nomeGiocatore'] ?? '', soprannome: json['soprannome'],
    convocato: json['convocato'] ?? false, presente: json['presente'] ?? false,
    haGiocato: json['haGiocato'] ?? false,
    gettoneConsumato: json['gettoneConsumato'] ?? false,
    gettoniRimanenti: json['gettoniRimanenti'] ?? 0,
    minutiGiocati: json['minutiGiocati'],
    goal: json['goal'],
    assist: json['assist'],
    autogoal: json['autogoal'],
    ammonizioni: json['ammonizioni'],
    espulsioni: json['espulsioni'],
    goalSubiti: json['goalSubiti'],
  );

  bool get hasStats =>
    (goal ?? 0) > 0 || (assist ?? 0) > 0 || (autogoal ?? 0) > 0 ||
    (ammonizioni ?? 0) > 0 || (espulsioni ?? 0) > 0 ||
    (goalSubiti ?? 0) > 0 || (minutiGiocati ?? 0) > 0;
}
