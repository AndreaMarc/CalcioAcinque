class PlayerInfo {
  final int id;
  final int userId;
  final int teamId;
  final String email;
  final String nome;
  final String? soprannome;
  final String? telefono;
  final String ruolo;

  PlayerInfo({
    required this.id, required this.userId, required this.teamId,
    required this.email, required this.nome, this.soprannome,
    this.telefono, required this.ruolo,
  });

  factory PlayerInfo.fromJson(Map<String, dynamic> json) => PlayerInfo(
    id: json['id'], userId: json['userId'], teamId: json['teamId'],
    email: json['email'] ?? '', nome: json['nome'] ?? '',
    soprannome: json['soprannome'], telefono: json['telefono'],
    ruolo: json['ruolo'] ?? 'User',
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

  PlayerInfo copyWith({String? nome, String? soprannome, String? telefono}) => PlayerInfo(
    id: id, userId: userId, teamId: teamId, email: email,
    nome: nome ?? this.nome,
    soprannome: soprannome ?? this.soprannome,
    telefono: telefono ?? this.telefono,
    ruolo: ruolo,
  );
}
