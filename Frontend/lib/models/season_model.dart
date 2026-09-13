/// Una stagione della squadra. Ogni squadra apre e chiude le sue, quindi la
/// C5 e la C7 della stessa società' possono trovarsi in stagioni diverse.
class SeasonModel {
  final int id;
  final int teamId;
  final String nome;
  final DateTime dataInizio;
  final DateTime? dataFine;
  final bool chiusa;
  final String? note;

  final int partite;
  final double incassato;
  final double daIncassare;

  SeasonModel({
    required this.id,
    required this.teamId,
    required this.nome,
    required this.dataInizio,
    this.dataFine,
    required this.chiusa,
    this.note,
    required this.partite,
    required this.incassato,
    required this.daIncassare,
  });

  factory SeasonModel.fromJson(Map<String, dynamic> json) => SeasonModel(
        id: json['id'] as int,
        teamId: json['teamId'] as int? ?? 0,
        nome: json['nome'] as String? ?? '',
        dataInizio: DateTime.parse(json['dataInizio'] as String),
        dataFine: json['dataFine'] == null
            ? null
            : DateTime.parse(json['dataFine'] as String),
        chiusa: json['chiusa'] as bool? ?? false,
        note: json['note'] as String?,
        partite: (json['partite'] as num?)?.toInt() ?? 0,
        incassato: (json['incassato'] as num?)?.toDouble() ?? 0,
        daIncassare: (json['daIncassare'] as num?)?.toDouble() ?? 0,
      );

  bool get inCorso => !chiusa;
}

/// Esito della chiusura, cosi' la UI puo' dire cosa e' stato azzerato.
class CloseSeasonResult {
  final String stagioneChiusa;
  final String stagioneNuova;
  final int giocatoriAzzerati;
  final double arretratiLasciatiAperti;

  CloseSeasonResult({
    required this.stagioneChiusa,
    required this.stagioneNuova,
    required this.giocatoriAzzerati,
    required this.arretratiLasciatiAperti,
  });

  factory CloseSeasonResult.fromJson(Map<String, dynamic> json) => CloseSeasonResult(
        stagioneChiusa: json['stagioneChiusa'] as String? ?? '',
        stagioneNuova: json['stagioneNuova'] as String? ?? '',
        giocatoriAzzerati: (json['giocatoriAzzerati'] as num?)?.toInt() ?? 0,
        arretratiLasciatiAperti:
            (json['arretratiLasciatiAperti'] as num?)?.toDouble() ?? 0,
      );
}
