class MatchModel {
  final int id;
  final int teamId;
  final DateTime data;
  final String ora;
  final String? luogo;
  final String? titolo;
  final int numeroGiornata;
  final String stato;
  final String? note;
  final int totaleConvocati;
  final int totaleConfermati;
  final int totalePresenti;
  final int totaleHannoGiocato;

  MatchModel({
    required this.id, required this.teamId, required this.data, required this.ora,
    this.luogo, this.titolo, required this.numeroGiornata, required this.stato, this.note,
    this.totaleConvocati = 0, this.totaleConfermati = 0,
    this.totalePresenti = 0, this.totaleHannoGiocato = 0,
  });

  factory MatchModel.fromJson(Map<String, dynamic> json) => MatchModel(
    id: json['id'], teamId: json['teamId'],
    data: DateTime.parse(json['data']), ora: json['ora'] ?? '',
    luogo: json['luogo'], titolo: json['titolo'],
    numeroGiornata: json['numeroGiornata'] ?? 0,
    stato: json['stato'] ?? '', note: json['note'],
    totaleConvocati: json['totaleConvocati'] ?? 0,
    totaleConfermati: json['totaleConfermati'] ?? 0,
    totalePresenti: json['totalePresenti'] ?? 0,
    totaleHannoGiocato: json['totaleHannoGiocato'] ?? 0,
  );

  bool get isProgrammata => stato == 'Programmata';
  bool get isConclusa => stato == 'Conclusa';

  /// Titolo formattato: "G1 vs Avversario" oppure "Giornata 1"
  String get displayTitle => titolo != null && titolo!.isNotEmpty
      ? 'G$numeroGiornata vs $titolo'
      : 'Giornata $numeroGiornata';
}
