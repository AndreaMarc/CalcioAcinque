import 'ruoli.dart';
import 'team_format.dart';

class TeamMembershipInfo {
  final int teamId;
  final int playerId;
  final String teamName;
  final String ruolo;
  final int? clubId;
  final String? clubName;
  final TeamFormat formato;
  final String formatoLabel;
  final String formatoShortLabel;

  TeamMembershipInfo({
    required this.teamId,
    required this.playerId,
    required this.teamName,
    required this.ruolo,
    this.clubId,
    this.clubName,
    this.formato = TeamFormat.calcioA5,
    this.formatoLabel = 'Calcio a 5',
    this.formatoShortLabel = 'A5',
  });

  factory TeamMembershipInfo.fromJson(Map<String, dynamic> json) {
    final formato = TeamFormatX.fromApi(json['formato'] as String?);
    return TeamMembershipInfo(
      teamId: json['teamId'],
      playerId: json['playerId'],
      teamName: json['teamName'],
      ruolo: json['ruolo'] ?? 'User',
      clubId: json['clubId'] as int?,
      clubName: json['clubName'] as String?,
      formato: formato,
      formatoLabel: json['formatoLabel'] as String? ?? formato.label,
      formatoShortLabel: json['formatoShortLabel'] as String? ?? formato.shortLabel,
    );
  }

  bool get isAdmin => ruolo == 'Admin';
  String get ruoloLabel => labelRuolo(ruolo);

  /// Etichetta per il raggruppamento: le squadre senza società' (dati vecchi)
  /// finiscono in un gruppo a se' col nome della squadra.
  String get groupLabel => clubName ?? teamName;
}

/// Raggruppa le squadre dell'utente per società', mantenendo l'ordine di arrivo.
List<ClubGroup> groupTeamsByClub(List<TeamMembershipInfo> teams) {
  final groups = <String, ClubGroup>{};
  for (final team in teams) {
    final key = team.clubId?.toString() ?? 'team-${team.teamId}';
    groups.putIfAbsent(
      key,
      () => ClubGroup(clubId: team.clubId, nome: team.groupLabel, teams: []),
    );
    groups[key]!.teams.add(team);
  }
  return groups.values.toList();
}

class ClubGroup {
  final int? clubId;
  final String nome;
  final List<TeamMembershipInfo> teams;

  ClubGroup({required this.clubId, required this.nome, required this.teams});

  /// Una società' con una sola squadra non ha bisogno di essere mostrata come gruppo.
  bool get isSingleTeam => teams.length == 1;
}
