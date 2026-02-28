class TeamMembershipInfo {
  final int teamId;
  final int playerId;
  final String teamName;
  final String ruolo;

  TeamMembershipInfo({
    required this.teamId,
    required this.playerId,
    required this.teamName,
    required this.ruolo,
  });

  factory TeamMembershipInfo.fromJson(Map<String, dynamic> json) => TeamMembershipInfo(
    teamId: json['teamId'],
    playerId: json['playerId'],
    teamName: json['teamName'],
    ruolo: json['ruolo'] ?? 'User',
  );

  bool get isAdmin => ruolo == 'Admin';
}
