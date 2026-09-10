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
  final int gettoniTotali;
  final int gettoniConsumati;
  final int gettoniRimanenti;
  final bool iscrizionePagata;
  final bool tesseramentoPagato;

  /// Scelta personale; null = eredita il default della squadra.
  final RegimePagamento? regimePagamento;

  /// Regime che vale davvero, risolto dal server.
  final RegimePagamento regimePagamentoEffettivo;

  PlayerModel({
    required this.id, required this.teamId, required this.userId,
    required this.nome, this.soprannome, this.telefono, required this.ruolo,
    this.clubMemberId, this.posizione, this.numeroMaglia,
    required this.gettoniTotali, required this.gettoniConsumati,
    required this.gettoniRimanenti, required this.iscrizionePagata,
    required this.tesseramentoPagato,
    this.regimePagamento,
    this.regimePagamentoEffettivo = RegimePagamento.stagionale,
  });

  factory PlayerModel.fromJson(Map<String, dynamic> json) => PlayerModel(
    id: json['id'], teamId: json['teamId'], userId: json['userId'],
    nome: json['nome'] ?? '', soprannome: json['soprannome'],
    telefono: json['telefono'], ruolo: json['ruolo'] ?? 'User',
    clubMemberId: json['clubMemberId'] as int?,
    posizione: PlayerPositionX.fromApi(json['posizione'] as String?),
    numeroMaglia: json['numeroMaglia'] as int?,
    gettoniTotali: json['gettoniTotali'] ?? 0,
    gettoniConsumati: json['gettoniConsumati'] ?? 0,
    gettoniRimanenti: json['gettoniRimanenti'] ?? 0,
    iscrizionePagata: json['iscrizionePagata'] ?? false,
    tesseramentoPagato: json['tesseramentoPagato'] ?? false,
    regimePagamento: RegimePagamentoX.fromApi(json['regimePagamento'] as String?),
    regimePagamentoEffettivo:
        RegimePagamentoX.fromApi(json['regimePagamentoEffettivo'] as String?) ??
            RegimePagamento.stagionale,
  );

  String get displayName => soprannome ?? nome;
  bool get isAdmin => ruolo == 'Admin';
  String get ruoloLabel => labelRuolo(ruolo);

  /// Sigla dell incarico, null per chi e' solo giocatore.
  String? get ruoloBadge => badgeRuolo(ruolo);
  bool get gettoniEsauriti => gettoniRimanenti <= 0;
  bool get pagaAPartita => regimePagamentoEffettivo == RegimePagamento.aPartita;
}
