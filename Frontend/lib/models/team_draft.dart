import 'team_format.dart';

enum DraftStatus { confermato, inForse, daSentire, rifiutato }

extension DraftStatusX on DraftStatus {
  String get apiValue {
    switch (this) {
      case DraftStatus.confermato:
        return 'Confermato';
      case DraftStatus.inForse:
        return 'InForse';
      case DraftStatus.daSentire:
        return 'DaSentire';
      case DraftStatus.rifiutato:
        return 'Rifiutato';
    }
  }

  String get label {
    switch (this) {
      case DraftStatus.confermato:
        return 'Confermato';
      case DraftStatus.inForse:
        return 'In forse';
      case DraftStatus.daSentire:
        return 'Da sentire';
      case DraftStatus.rifiutato:
        return 'Rifiutato';
    }
  }

  static DraftStatus fromApi(String value) {
    switch (value) {
      case 'Confermato':
        return DraftStatus.confermato;
      case 'InForse':
        return DraftStatus.inForse;
      case 'DaSentire':
        return DraftStatus.daSentire;
      case 'Rifiutato':
        return DraftStatus.rifiutato;
      default:
        return DraftStatus.daSentire;
    }
  }
}

/// Ruoli in campo. Quali siano proponibili dipende dal formato della squadra:
/// vedi `TeamFormatX.posizioni` in `team_format.dart`.
enum PlayerPosition {
  portiere,
  difensore,
  centrocampista,
  esterno,
  attaccante,
  jolly,
  // Calcio a 5
  laterale,
  centrale,
  pivot,
  universale,
  // Calcio a 7 / 8 / 11
  terzino,
  libero,
  mediano,
  trequartista,
  ala,
  punta,
}

extension PlayerPositionX on PlayerPosition {
  String get apiValue {
    switch (this) {
      case PlayerPosition.portiere:
        return 'Portiere';
      case PlayerPosition.difensore:
        return 'Difensore';
      case PlayerPosition.centrocampista:
        return 'Centrocampista';
      case PlayerPosition.esterno:
        return 'Esterno';
      case PlayerPosition.attaccante:
        return 'Attaccante';
      case PlayerPosition.jolly:
        return 'Jolly';
      case PlayerPosition.laterale:
        return 'Laterale';
      case PlayerPosition.centrale:
        return 'Centrale';
      case PlayerPosition.pivot:
        return 'Pivot';
      case PlayerPosition.universale:
        return 'Universale';
      case PlayerPosition.terzino:
        return 'Terzino';
      case PlayerPosition.libero:
        return 'Libero';
      case PlayerPosition.mediano:
        return 'Mediano';
      case PlayerPosition.trequartista:
        return 'Trequartista';
      case PlayerPosition.ala:
        return 'Ala';
      case PlayerPosition.punta:
        return 'Punta';
    }
  }

  String get label => apiValue;

  String get shortLabel {
    switch (this) {
      case PlayerPosition.portiere:
        return 'POR';
      case PlayerPosition.difensore:
        return 'DIF';
      case PlayerPosition.centrocampista:
        return 'CEN';
      case PlayerPosition.esterno:
        return 'EST';
      case PlayerPosition.attaccante:
        return 'ATT';
      case PlayerPosition.jolly:
        return 'JOL';
      case PlayerPosition.laterale:
        return 'LAT';
      case PlayerPosition.centrale:
        return 'CNT';
      case PlayerPosition.pivot:
        return 'PIV';
      case PlayerPosition.universale:
        return 'UNI';
      case PlayerPosition.terzino:
        return 'TER';
      case PlayerPosition.libero:
        return 'LIB';
      case PlayerPosition.mediano:
        return 'MED';
      case PlayerPosition.trequartista:
        return 'TRQ';
      case PlayerPosition.ala:
        return 'ALA';
      case PlayerPosition.punta:
        return 'PUN';
    }
  }

  static PlayerPosition? fromApi(String? value) {
    if (value == null) return null;
    for (final p in PlayerPosition.values) {
      if (p.apiValue == value) return p;
    }
    return null;
  }
}

class DraftCandidate {
  final int id;
  final String nome;
  final String? soprannome;
  final PlayerPosition? posizione;
  final DraftStatus stato;
  final int bravura;
  final int affidabilita;
  final bool tesserato;
  final bool isFriend;
  final String? note;

  DraftCandidate({
    required this.id,
    required this.nome,
    this.soprannome,
    this.posizione,
    required this.stato,
    required this.bravura,
    required this.affidabilita,
    required this.tesserato,
    this.isFriend = false,
    this.note,
  });

  factory DraftCandidate.fromJson(Map<String, dynamic> json) => DraftCandidate(
        id: json['id'] as int,
        nome: json['nome'] as String,
        soprannome: json['soprannome'] as String?,
        posizione: PlayerPositionX.fromApi(json['posizione'] as String?),
        stato: DraftStatusX.fromApi(json['stato'] as String? ?? 'DaSentire'),
        bravura: (json['bravura'] as num?)?.toInt() ?? 3,
        affidabilita: (json['affidabilita'] as num?)?.toInt() ?? 3,
        tesserato: json['tesserato'] as bool? ?? false,
        isFriend: json['isFriend'] as bool? ?? false,
        note: json['note'] as String?,
      );
}

class DraftCollaborator {
  final int userId;
  final String email;
  final bool isOwner;
  final DateTime joinedAt;

  DraftCollaborator({
    required this.userId,
    required this.email,
    required this.isOwner,
    required this.joinedAt,
  });

  factory DraftCollaborator.fromJson(Map<String, dynamic> json) => DraftCollaborator(
        userId: json['userId'] as int,
        email: json['email'] as String? ?? '',
        isOwner: json['isOwner'] as bool? ?? false,
        joinedAt: DateTime.parse(json['joinedAt'] as String),
      );
}

class TeamDraft {
  final int id;
  final String nomeTeam;
  final TeamFormat formato;
  final int partitePerStagione;
  final int gettoniPerGiocatore;
  final bool useGettoni;
  final String shareCode;
  final bool isOwner;
  final int ownerUserId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<DraftCandidate> candidates;
  final List<DraftCollaborator> collaborators;

  TeamDraft({
    required this.id,
    required this.nomeTeam,
    this.formato = TeamFormat.calcioA5,
    required this.partitePerStagione,
    required this.gettoniPerGiocatore,
    required this.useGettoni,
    required this.shareCode,
    required this.isOwner,
    required this.ownerUserId,
    required this.createdAt,
    required this.updatedAt,
    required this.candidates,
    required this.collaborators,
  });

  factory TeamDraft.fromJson(Map<String, dynamic> json) => TeamDraft(
        id: json['id'] as int,
        nomeTeam: json['nomeTeam'] as String,
        formato: TeamFormatX.fromApi(json['formato'] as String?),
        partitePerStagione: (json['partitePerStagione'] as num?)?.toInt() ?? 8,
        gettoniPerGiocatore: (json['gettoniPerGiocatore'] as num?)?.toInt() ?? 4,
        useGettoni: json['useGettoni'] as bool? ?? true,
        shareCode: json['shareCode'] as String? ?? '',
        isOwner: json['isOwner'] as bool? ?? false,
        ownerUserId: (json['ownerUserId'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        candidates: ((json['candidates'] as List?) ?? [])
            .map((e) => DraftCandidate.fromJson(e as Map<String, dynamic>))
            .toList(),
        collaborators: ((json['collaborators'] as List?) ?? [])
            .map((e) => DraftCollaborator.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  int countByStatus(DraftStatus s) =>
      candidates.where((c) => c.stato == s).length;
}
