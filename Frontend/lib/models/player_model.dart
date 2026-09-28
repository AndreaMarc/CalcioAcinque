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

  /// Accordi personali: null = come la squadra. Gli *Effettivo/Effettiva sono
  /// i valori che valgono davvero, risolti dal server.
  final bool? usaGettoni;
  final bool usaGettoniEffettivo;
  final int? gettoniPerStagione;
  final int gettoniPerStagioneEffettivi;
  final double? quotaIscrizionePersonale;
  final double? quotaTesseramentoPersonale;
  final double? costoPartitaPersonale;
  final double quotaIscrizioneEffettiva;
  final double quotaTesseramentoEffettiva;
  final double costoPartitaEffettivo;

  /// Partite in cui è stato presente (tutte le stagioni).
  final int presenze;

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
    this.usaGettoni,
    this.usaGettoniEffettivo = true,
    this.gettoniPerStagione,
    this.gettoniPerStagioneEffettivi = 0,
    this.quotaIscrizionePersonale,
    this.quotaTesseramentoPersonale,
    this.costoPartitaPersonale,
    this.quotaIscrizioneEffettiva = 0,
    this.quotaTesseramentoEffettiva = 0,
    this.costoPartitaEffettivo = 0,
    this.presenze = 0,
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
    usaGettoni: json['usaGettoni'] as bool?,
    usaGettoniEffettivo: json['usaGettoniEffettivo'] as bool? ?? true,
    gettoniPerStagione: (json['gettoniPerStagione'] as num?)?.toInt(),
    gettoniPerStagioneEffettivi: (json['gettoniPerStagioneEffettivi'] as num?)?.toInt() ?? 0,
    quotaIscrizionePersonale: (json['quotaIscrizionePersonale'] as num?)?.toDouble(),
    quotaTesseramentoPersonale: (json['quotaTesseramentoPersonale'] as num?)?.toDouble(),
    costoPartitaPersonale: (json['costoPartitaPersonale'] as num?)?.toDouble(),
    quotaIscrizioneEffettiva: (json['quotaIscrizioneEffettiva'] as num?)?.toDouble() ?? 0,
    quotaTesseramentoEffettiva: (json['quotaTesseramentoEffettiva'] as num?)?.toDouble() ?? 0,
    costoPartitaEffettivo: (json['costoPartitaEffettivo'] as num?)?.toDouble() ?? 0,
    presenze: (json['presenze'] as num?)?.toInt() ?? 0,
    convocazioniRicevute: (json['convocazioniRicevute'] as num?)?.toInt() ?? 0,
    affidabilita: (json['affidabilita'] as num?)?.toInt(),
  );

  String get displayName => soprannome ?? nome;
  bool get isAdmin => ruolo == 'Admin';
  String get ruoloLabel => labelRuolo(ruolo);

  /// Sigla dell incarico, null per chi e' solo giocatore.
  String? get ruoloBadge => badgeRuolo(ruolo);
  /// Esaurito conta solo per chi i gettoni li usa davvero.
  bool get gettoniEsauriti => usaGettoniEffettivo && gettoniRimanenti <= 0;
  bool get gettoniBassi => usaGettoniEffettivo && gettoniRimanenti <= 2;

  /// Accordi diversi da quelli della squadra, in breve (per la rosa).
  /// Vuota se segue in tutto la squadra.
  List<String> get accordiPersonali => [
        if (regimePagamento != null) regimePagamento!.shortLabel,
        if (regimePagamento != RegimePagamento.esente &&
            (quotaIscrizionePersonale != null ||
                quotaTesseramentoPersonale != null ||
                costoPartitaPersonale != null))
          'Importi personali',
        if (usaGettoni == true) 'Gettoni solo per lui',
        if (usaGettoni == false) 'Senza gettoni',
        if (usaGettoniEffettivo && gettoniPerStagione != null) '$gettoniPerStagione gettoni',
      ];
  bool get pagaAPartita => regimePagamentoEffettivo == RegimePagamento.aPartita;
}
