class PlayerInfo {
  final int id;
  final int userId;
  final int teamId;
  final String email;
  final String nome;
  final String? soprannome;
  final String? telefono;
  final String ruolo;
  /// Tema scuro salvato sull'account (vale su ogni dispositivo), null = mai scelto.
  final bool? temaScuro;
  /// Colore brand dell'account "#RRGGBB"; null = mai scelto, "" = verde di default.
  final String? coloreBrand;

  PlayerInfo({
    required this.id, required this.userId, required this.teamId,
    required this.email, required this.nome, this.soprannome,
    this.telefono, required this.ruolo, this.temaScuro, this.coloreBrand,
  });

  factory PlayerInfo.fromJson(Map<String, dynamic> json) => PlayerInfo(
    id: json['id'], userId: json['userId'], teamId: json['teamId'],
    email: json['email'] ?? '', nome: json['nome'] ?? '',
    soprannome: json['soprannome'], telefono: json['telefono'],
    ruolo: json['ruolo'] ?? 'User',
    temaScuro: json['temaScuro'] as bool?,
    coloreBrand: json['coloreBrand'] as String?,
  );

  bool get isAdmin => ruolo == 'Admin';
  bool get isMister => ruolo == 'Mister';
  bool get isCassiere => ruolo == 'Cassiere';

  /// Rosa, configurazione squadra, societa: solo l admin.
  bool get puoGestireSquadra => isAdmin;

  /// Partite, convocazioni, presenze, avvisi.
  bool get puoGestireCampo => isAdmin || isMister;

  /// Quote, incassi, solleciti.
  bool get puoGestireSoldi => isAdmin || isCassiere;

  /// La rettifica dei gettoni sta fra campo e cassa: la aprono entrambi.
  bool get puoGestireGettoni => isAdmin || isMister || isCassiere;

  PlayerInfo copyWith({String? nome, String? soprannome, String? telefono, bool? temaScuro, String? coloreBrand}) => PlayerInfo(
    id: id, userId: userId, teamId: teamId, email: email,
    nome: nome ?? this.nome,
    soprannome: soprannome ?? this.soprannome,
    telefono: telefono ?? this.telefono,
    ruolo: ruolo,
    temaScuro: temaScuro ?? this.temaScuro,
    coloreBrand: coloreBrand ?? this.coloreBrand,
  );
}
