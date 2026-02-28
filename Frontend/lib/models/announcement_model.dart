class AnnouncementModel {
  final int id;
  final int teamId;
  final int authorId;
  final String autoreNome;
  final String? autoreSoprannome;
  final String titolo;
  final String contenuto;
  final bool importante;
  final DateTime createdAt;
  final int totalePresaVisione;
  final int totaleGiocatori;
  final bool hoPresaVisione;
  final List<AnnouncementReadModel> presaVisione;

  AnnouncementModel({
    required this.id,
    required this.teamId,
    required this.authorId,
    required this.autoreNome,
    this.autoreSoprannome,
    required this.titolo,
    required this.contenuto,
    this.importante = false,
    required this.createdAt,
    this.totalePresaVisione = 0,
    this.totaleGiocatori = 0,
    this.hoPresaVisione = false,
    this.presaVisione = const [],
  });

  String get autoreDisplay => autoreSoprannome ?? autoreNome;

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id'] as int,
      teamId: json['teamId'] as int,
      authorId: json['authorId'] as int,
      autoreNome: json['autoreNome'] as String? ?? '',
      autoreSoprannome: json['autoreSoprannome'] as String?,
      titolo: json['titolo'] as String? ?? '',
      contenuto: json['contenuto'] as String? ?? '',
      importante: json['importante'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      totalePresaVisione: json['totalePresaVisione'] as int? ?? 0,
      totaleGiocatori: json['totaleGiocatori'] as int? ?? 0,
      hoPresaVisione: json['hoPresaVisione'] as bool? ?? false,
      presaVisione: (json['presaVisione'] as List?)
              ?.map((e) => AnnouncementReadModel.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class AnnouncementReadModel {
  final int playerId;
  final String nomeGiocatore;
  final String? soprannome;
  final DateTime readAt;

  AnnouncementReadModel({
    required this.playerId,
    required this.nomeGiocatore,
    this.soprannome,
    required this.readAt,
  });

  String get displayName => soprannome ?? nomeGiocatore;

  factory AnnouncementReadModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementReadModel(
      playerId: json['playerId'] as int,
      nomeGiocatore: json['nomeGiocatore'] as String? ?? '',
      soprannome: json['soprannome'] as String?,
      readAt: DateTime.parse(json['readAt'] as String),
    );
  }
}
