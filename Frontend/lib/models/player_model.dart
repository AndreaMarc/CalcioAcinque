import 'ruoli.dart';
import 'payment_model.dart';
import 'team_draft.dart' show PlayerPosition, PlayerPositionX;

class PlayerModel {
  final int id;
  final int teamId;
  final int userId;
  final String nome;
  final String? soprannome;
  final String? telefono;
  final String ruolo;
  final int? clubMemberId;
  final PlayerPosition? posizione;
  final int? numeroMaglia;

  /// Falso per chi è solo staff (allenatore, dirigente) e non gioca.
  final bool gioca;
  final int gettoniTotali;
  final int gettoniConsumati;
  final int gettoniRimanenti;
  final bool iscrizionePagata;
  final bool tesseramentoPagato;

  /// Scelta personale; null = eredita il default della squadra.
  final RegimePagamento? regimePagamento;

  /// Regime che vale davvero, risolto dal server.
  final RegimePagamento regimePagamentoEffettivo;

  /// Convocazioni ricevute su partite concluse e % confermate (null senza storia).
  final int convocazioniRicevute;
  final int? affidabilita;

  PlayerModel({
    required this.id, required this.teamId, required this.userId,
    required this.nome, this.soprannome, this.telefono, required this.ruolo,
    this.clubMemberId, this.posizione, this.numeroMaglia, this.gioca = true,
    required this.gettoniTotali, required this.gettoniConsumati,
    required this.gettoniRimanenti, required this.iscrizionePagata,
    required this.tesseramentoPagato,
    this.regimePagamento,
    this.regimePagamentoEffettivo = RegimePagamento.stagionale,
    this.convocazioniRicevute = 0,
    this.affidabilita,
  });

  factory PlayerModel.fromJson(Map<String, dynamic> json) => PlayerModel(
    id: json['id'], teamId: json['teamId'], userId: json['userId'],
    nome: json['nome'] ?? '', soprannome: json['soprannome'],
    telefono: json['telefono'], ruolo: json['ruolo'] ?? 'User',
    clubMemberId: json['clubMemberId'] as int?,
    posizione: PlayerPositionX.fromApi(json['posizione'] as String?),
    numeroMaglia: json['numeroMaglia'] as int?,
    gioca: json['gioca'] as bool? ?? true,
    gettoniTotali: json['gettoniTotali'] ?? 0,
    gettoniConsumati: json['gettoniConsumati'] ?? 0,
    gettoniRimanenti: json['gettoniRimanenti'] ?? 0,
    iscrizionePagata: json['iscrizionePagata'] ?? false,
    tesseramentoPagato: json['tesseramentoPagato'] ?? false,
    regimePagamento: RegimePagamentoX.fromApi(json['regimePagamento'] as String?),
    regimePagamentoEffettivo:
        RegimePagamentoX.fromApi(json['regimePagamentoEffettivo'] as String?) ??
            RegimePagamento.stagionale,
    convocazioniRicevute: (json['convocazioniRicevute'] as num?)?.toInt() ?? 0,
    affidabilita: (json['affidabilita'] as num?)?.toInt(),
  );

  String get displayName => soprannome ?? nome;
  bool get isAdmin => ruolo == 'Admin';
  String get ruoloLabel => labelRuolo(ruolo);

  /// Sigla dell incarico, null per chi e' solo giocatore.
  String? get ruoloBadge => badgeRuolo(ruolo);
  bool get gettoniEsauriti => gettoniRimanenti <= 0;
  bool get pagaAPartita => regimePagamentoEffettivo == RegimePagamento.aPartita;
}
