import 'team_format.dart';

class DashboardModel {
  final MatchSummary? prossimaPartita;
  final bool useGettoni;
  final int gettoniRimanenti;
  final int gettoniTotali;
  final int convocazioniInAttesa;
  final int partiteGiocate;
  final int partiteTotali;
  final List<PlayerTokenSummary> classificaGettoni;
  final String teamNome;
  final TeamFormat formato;
  final String formatoLabel;
  final String formatoShortLabel;
  final int giocatoriInCampo;
  final int? maxConvocati;
  final int? clubId;
  final String? clubNome;

  /// Le prossime partite con la mia disponibilità e la mia convocazione.
  final List<MatchSummary> miePartite;

  DashboardModel({
    this.prossimaPartita, this.useGettoni = true,
    required this.gettoniRimanenti, required this.gettoniTotali,
    required this.convocazioniInAttesa, required this.partiteGiocate,
    required this.partiteTotali, required this.classificaGettoni,
    this.teamNome = '',
    this.formato = TeamFormat.calcioA5,
    this.formatoLabel = 'Calcio a 5',
    this.formatoShortLabel = 'A5',
    this.giocatoriInCampo = 5,
    this.maxConvocati,
    this.clubId,
    this.clubNome,
    this.miePartite = const [],
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    final formato = TeamFormatX.fromApi(json['formato'] as String?);
    return DashboardModel(
    prossimaPartita: json['prossimaPartita'] != null
        ? MatchSummary.fromJson(json['prossimaPartita']) : null,
    useGettoni: json['useGettoni'] ?? true,
    gettoniRimanenti: json['gettoniRimanenti'] ?? 0,
    gettoniTotali: json['gettoniTotali'] ?? 0,
    convocazioniInAttesa: json['convocazioniInAttesa'] ?? 0,
    partiteGiocate: json['partiteGiocate'] ?? 0,
    partiteTotali: json['partiteTotali'] ?? 0,
    classificaGettoni: (json['classificaGettoni'] as List? ?? [])
        .map((e) => PlayerTokenSummary.fromJson(e)).toList(),
    teamNome: json['teamNome'] as String? ?? '',
    formato: formato,
    formatoLabel: json['formatoLabel'] as String? ?? formato.label,
    formatoShortLabel: json['formatoShortLabel'] as String? ?? formato.shortLabel,
    giocatoriInCampo: (json['giocatoriInCampo'] as num?)?.toInt() ?? formato.giocatoriInCampo,
    maxConvocati: (json['maxConvocati'] as num?)?.toInt(),
    clubId: json['clubId'] as int?,
    clubNome: json['clubNome'] as String?,
    miePartite: ((json['miePartite'] as List?) ?? const [])
        .map((e) => MatchSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
  }
}

class MatchSummary {
  final int id;
  final DateTime data;
  final String ora;
  final String? luogo;
  final String? titolo;
  final int numeroGiornata;
  final String stato;
  final int confermati;
  final int inAttesa;
  final int nonDisponibili;
  final String? miaConvocazione; // null, "InAttesa", "Confermato", "NonDisponibile"
  final int? miaConvocazioneId;
  /// La disponibilità che ho dato: null = non ho ancora risposto.
  final bool? miaDisponibilita;
  /// Il mister ha già mandato le convocazioni.
  final bool convocazioniInviate;

  MatchSummary({
    required this.id, required this.data, required this.ora, this.luogo,
    this.titolo, required this.numeroGiornata, required this.stato,
    required this.confermati, required this.inAttesa, required this.nonDisponibili,
    this.miaConvocazione,
    this.miaConvocazioneId,
    this.miaDisponibilita,
    this.convocazioniInviate = false,
  });

  factory MatchSummary.fromJson(Map<String, dynamic> json) => MatchSummary(
    id: json['id'], data: DateTime.parse(json['data']), ora: json['ora'] ?? '',
    luogo: json['luogo'], titolo: json['titolo'],
    numeroGiornata: json['numeroGiornata'] ?? 0,
    stato: json['stato'] ?? '', confermati: json['confermati'] ?? 0,
    inAttesa: json['inAttesa'] ?? 0, nonDisponibili: json['nonDisponibili'] ?? 0,
    miaConvocazione: json['miaConvocazione'],
    miaConvocazioneId: json['miaConvocazioneId'] as int?,
    miaDisponibilita: json['miaDisponibilita'] as bool?,
    convocazioniInviate: json['convocazioniInviate'] as bool? ?? false,
  );

  String get displayTitle => titolo != null && titolo!.isNotEmpty
      ? 'G$numeroGiornata vs $titolo'
      : 'Giornata $numeroGiornata';

  bool get sonoConvocato => miaConvocazione != null;
  bool get hoConfermato => miaConvocazione == 'Confermato';
  bool get hoDatoForfait => miaConvocazione == 'NonDisponibile';
  bool get devoRispondere => miaConvocazione == 'InAttesa';
}

class PlayerTokenSummary {
  final int playerId;
  final String nome;
  final String? soprannome;
  final int gettoniRimanenti;
  final int gettoniTotali;

  PlayerTokenSummary({
    required this.playerId, required this.nome, this.soprannome,
    required this.gettoniRimanenti, required this.gettoniTotali,
  });

  factory PlayerTokenSummary.fromJson(Map<String, dynamic> json) => PlayerTokenSummary(
    playerId: json['playerId'], nome: json['nome'] ?? '',
    soprannome: json['soprannome'],
    gettoniRimanenti: json['gettoniRimanenti'] ?? 0,
    gettoniTotali: json['gettoniTotali'] ?? 0,
  );
}
