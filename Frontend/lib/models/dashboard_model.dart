class DashboardModel {
  final MatchSummary? prossimaPartita;
  final bool useGettoni;
  final int gettoniRimanenti;
  final int gettoniTotali;
  final int convocazioniInAttesa;
  final int partiteGiocate;
  final int partiteTotali;
  final List<PlayerTokenSummary> classificaGettoni;

  DashboardModel({
    this.prossimaPartita, this.useGettoni = true,
    required this.gettoniRimanenti, required this.gettoniTotali,
    required this.convocazioniInAttesa, required this.partiteGiocate,
    required this.partiteTotali, required this.classificaGettoni,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) => DashboardModel(
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
  );
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

  MatchSummary({
    required this.id, required this.data, required this.ora, this.luogo,
    this.titolo, required this.numeroGiornata, required this.stato,
    required this.confermati, required this.inAttesa, required this.nonDisponibili,
    this.miaConvocazione,
  });

  factory MatchSummary.fromJson(Map<String, dynamic> json) => MatchSummary(
    id: json['id'], data: DateTime.parse(json['data']), ora: json['ora'] ?? '',
    luogo: json['luogo'], titolo: json['titolo'],
    numeroGiornata: json['numeroGiornata'] ?? 0,
    stato: json['stato'] ?? '', confermati: json['confermati'] ?? 0,
    inAttesa: json['inAttesa'] ?? 0, nonDisponibili: json['nonDisponibili'] ?? 0,
    miaConvocazione: json['miaConvocazione'],
  );

  String get displayTitle => titolo != null && titolo!.isNotEmpty
      ? 'G$numeroGiornata vs $titolo'
      : 'Giornata $numeroGiornata';
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
