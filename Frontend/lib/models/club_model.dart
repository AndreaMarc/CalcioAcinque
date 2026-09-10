import 'ruoli.dart';
import 'team_draft.dart' show PlayerPosition, PlayerPositionX;
import 'team_format.dart';

/// Societa' sportiva: contenitore di piu' squadre con anagrafica condivisa.
class ClubModel {
  final int id;
  final String nome;
  final String? inviteCode;
  final int totaleMembri;
  final bool isAdmin;
  final String? paypalLink;
  final String? iban;
  final String? intestatarioIban;
  final List<ClubTeam> squadre;

  ClubModel({
    required this.id,
    required this.nome,
    this.inviteCode,
    required this.totaleMembri,
    required this.isAdmin,
    this.paypalLink,
    this.iban,
    this.intestatarioIban,
    required this.squadre,
  });

  factory ClubModel.fromJson(Map<String, dynamic> json) => ClubModel(
        id: json['id'] as int,
        nome: json['nome'] as String? ?? '',
        inviteCode: json['inviteCode'] as String?,
        totaleMembri: (json['totaleMembri'] as num?)?.toInt() ?? 0,
        isAdmin: json['isAdmin'] as bool? ?? false,
        paypalLink: json['paypalLink'] as String?,
        iban: json['iban'] as String?,
        intestatarioIban: json['intestatarioIban'] as String?,
        squadre: ((json['squadre'] as List?) ?? const [])
            .map((e) => ClubTeam.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Squadre di cui l'utente corrente non fa parte: sono quelle a cui puo' aggiungersi.
  List<ClubTeam> get squadreNonMie => squadre.where((t) => t.mioPlayerId == null).toList();
}

class ClubTeam {
  final int id;
  final String nome;
  final TeamFormat formato;
  final String formatoLabel;
  final int giocatoriInCampo;
  final int totaleGiocatori;
  final int? mioPlayerId;
  final String? mioRuolo;

  ClubTeam({
    required this.id,
    required this.nome,
    required this.formato,
    required this.formatoLabel,
    required this.giocatoriInCampo,
    required this.totaleGiocatori,
    this.mioPlayerId,
    this.mioRuolo,
  });

  factory ClubTeam.fromJson(Map<String, dynamic> json) {
    final formato = TeamFormatX.fromApi(json['formato'] as String?);
    return ClubTeam(
      id: json['id'] as int,
      nome: json['nome'] as String? ?? '',
      formato: formato,
      formatoLabel: json['formatoLabel'] as String? ?? formato.label,
      giocatoriInCampo: (json['giocatoriInCampo'] as num?)?.toInt() ?? formato.giocatoriInCampo,
      totaleGiocatori: (json['totaleGiocatori'] as num?)?.toInt() ?? 0,
      mioPlayerId: json['mioPlayerId'] as int?,
      mioRuolo: json['mioRuolo'] as String?,
    );
  }

  bool get sonoAdmin => mioRuolo == 'Admin';
}

/// Anagrafica unica di societa': una persona, N iscrizioni alle squadre.
class ClubMember {
  final int id;
  final int clubId;
  final int? userId;
  final String nome;
  final String? soprannome;
  final String? telefono;
  final DateTime? dataNascita;
  final String? note;
  final String? email;
  final List<ClubMemberTeam> squadre;

  ClubMember({
    required this.id,
    required this.clubId,
    this.userId,
    required this.nome,
    this.soprannome,
    this.telefono,
    this.dataNascita,
    this.note,
    this.email,
    required this.squadre,
  });

  factory ClubMember.fromJson(Map<String, dynamic> json) => ClubMember(
        id: json['id'] as int,
        clubId: json['clubId'] as int,
        userId: json['userId'] as int?,
        nome: json['nome'] as String? ?? '',
        soprannome: json['soprannome'] as String?,
        telefono: json['telefono'] as String?,
        dataNascita: json['dataNascita'] != null
            ? DateTime.tryParse(json['dataNascita'] as String)
            : null,
        note: json['note'] as String?,
        email: json['email'] as String?,
        squadre: ((json['squadre'] as List?) ?? const [])
            .map((e) => ClubMemberTeam.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String get displayName => soprannome != null && soprannome!.isNotEmpty ? soprannome! : nome;

  /// Senza account non puo' essere iscritto a una squadra (serve un login).
  bool get haAccount => userId != null;

  bool giocaIn(int teamId) => squadre.any((s) => s.teamId == teamId);

  /// Chi gioca in piu' di una squadra della societa'.
  bool get condiviso => squadre.length > 1;
}

class ClubMemberTeam {
  final int teamId;
  final String teamNome;
  final TeamFormat formato;
  final String formatoLabel;
  final int playerId;
  final String ruolo;
  final PlayerPosition? posizione;
  final int? numeroMaglia;
  final int gettoniRimanenti;
  final bool iscrizionePagata;
  final bool tesseramentoPagato;

  ClubMemberTeam({
    required this.teamId,
    required this.teamNome,
    required this.formato,
    required this.formatoLabel,
    required this.playerId,
    required this.ruolo,
    this.posizione,
    this.numeroMaglia,
    required this.gettoniRimanenti,
    required this.iscrizionePagata,
    required this.tesseramentoPagato,
  });

  factory ClubMemberTeam.fromJson(Map<String, dynamic> json) {
    final formato = TeamFormatX.fromApi(json['formato'] as String?);
    return ClubMemberTeam(
      teamId: json['teamId'] as int,
      teamNome: json['teamNome'] as String? ?? '',
      formato: formato,
      formatoLabel: json['formatoLabel'] as String? ?? formato.label,
      playerId: json['playerId'] as int,
      ruolo: json['ruolo'] as String? ?? 'User',
      posizione: PlayerPositionX.fromApi(json['posizione'] as String?),
      numeroMaglia: json['numeroMaglia'] as int?,
      gettoniRimanenti: (json['gettoniRimanenti'] as num?)?.toInt() ?? 0,
      iscrizionePagata: json['iscrizionePagata'] as bool? ?? false,
      tesseramentoPagato: json['tesseramentoPagato'] as bool? ?? false,
    );
  }

  bool get isAdmin => ruolo == 'Admin';
  String get ruoloLabel => labelRuolo(ruolo);
}
