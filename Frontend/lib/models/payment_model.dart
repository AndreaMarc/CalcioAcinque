/// Regime con cui un giocatore contribuisce ai costi.
enum RegimePagamento { stagionale, aPartita }

extension RegimePagamentoX on RegimePagamento {
  String get apiValue => this == RegimePagamento.stagionale ? 'Stagionale' : 'APartita';

  String get label =>
      this == RegimePagamento.stagionale ? 'Quota stagionale' : 'Paga a partita';

  String get shortLabel => this == RegimePagamento.stagionale ? 'Stagione' : 'A partita';

  String get descrizione => this == RegimePagamento.stagionale
      ? 'Versa la quota all inizio, poi non paga le singole partite'
      : 'Riceve un addebito dopo ogni partita giocata';

  static RegimePagamento? fromApi(String? value) {
    switch (value) {
      case 'Stagionale':
        return RegimePagamento.stagionale;
      case 'APartita':
        return RegimePagamento.aPartita;
      default:
        return null;
    }
  }
}

/// A chi si applica una quota fissa.
enum DestinatariQuota { tutti, soloStagionali }

extension DestinatariQuotaX on DestinatariQuota {
  String get apiValue => this == DestinatariQuota.tutti ? 'Tutti' : 'SoloStagionali';

  String get label =>
      this == DestinatariQuota.tutti ? 'Tutti' : 'Solo chi paga a stagione';

  static DestinatariQuota fromApi(String? value) =>
      value == 'SoloStagionali' ? DestinatariQuota.soloStagionali : DestinatariQuota.tutti;
}

enum TipoPagamento { iscrizione, tesseramento, partita, altro }

extension TipoPagamentoX on TipoPagamento {
  String get label {
    switch (this) {
      case TipoPagamento.iscrizione:
        return 'Iscrizione';
      case TipoPagamento.tesseramento:
        return 'Tesseramento';
      case TipoPagamento.partita:
        return 'Partita';
      case TipoPagamento.altro:
        return 'Altro';
    }
  }

  static TipoPagamento fromApi(String? value) {
    switch (value) {
      case 'Iscrizione':
        return TipoPagamento.iscrizione;
      case 'Tesseramento':
        return TipoPagamento.tesseramento;
      case 'Partita':
        return TipoPagamento.partita;
      default:
        return TipoPagamento.altro;
    }
  }
}

/// Una voce di pagamento. Prima erano mappe non tipizzate dentro lo screen.
class PaymentModel {
  final int id;
  final int playerId;
  final String nomeGiocatore;
  final String descrizione;
  final double importo;
  final DateTime dataPagamento;
  final bool pagato;
  final String? note;
  final String adminNome;
  final TipoPagamento tipo;
  final int? matchId;
  final DateTime? dichiaratoPagatoAt;

  PaymentModel({
    required this.id,
    required this.playerId,
    required this.nomeGiocatore,
    required this.descrizione,
    required this.importo,
    required this.dataPagamento,
    required this.pagato,
    this.note,
    required this.adminNome,
    required this.tipo,
    this.matchId,
    this.dichiaratoPagatoAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) => PaymentModel(
        id: json['id'] as int,
        playerId: json['playerId'] as int,
        nomeGiocatore: json['nomeGiocatore'] as String? ?? '',
        descrizione: json['descrizione'] as String? ?? '',
        importo: (json['importo'] as num?)?.toDouble() ?? 0,
        dataPagamento: DateTime.tryParse(json['dataPagamento'] as String? ?? '') ?? DateTime.now(),
        pagato: json['pagato'] as bool? ?? false,
        note: json['note'] as String?,
        adminNome: json['adminNome'] as String? ?? '',
        tipo: TipoPagamentoX.fromApi(json['tipo'] as String?),
        matchId: json['matchId'] as int?,
        dichiaratoPagatoAt: json['dichiaratoPagatoAt'] != null
            ? DateTime.tryParse(json['dichiaratoPagatoAt'] as String)
            : null,
      );

  /// Il giocatore ha detto di aver pagato, l'admin non ha ancora confermato.
  bool get inVerifica => !pagato && dichiaratoPagatoAt != null;

  bool get daPagare => !pagato;
}

/// Cosa l'admin vede prima di decidere a chi addebitare la partita.
class MatchPaymentPreview {
  final int matchId;
  final String partita;
  final DateTime data;
  final String stato;
  final double costoPartita;
  final int minutiMinimiPerAddebito;
  final bool giaGestita;
  final bool presenzeDaRegistrare;
  final bool presenzeBloccate;
  final List<MatchPaymentCandidate> candidati;

  MatchPaymentPreview({
    required this.matchId,
    required this.partita,
    required this.data,
    required this.stato,
    required this.costoPartita,
    required this.minutiMinimiPerAddebito,
    required this.giaGestita,
    required this.presenzeDaRegistrare,
    required this.presenzeBloccate,
    required this.candidati,
  });

  factory MatchPaymentPreview.fromJson(Map<String, dynamic> json) => MatchPaymentPreview(
        matchId: json['matchId'] as int,
        partita: json['partita'] as String? ?? '',
        data: DateTime.tryParse(json['data'] as String? ?? '') ?? DateTime.now(),
        stato: json['stato'] as String? ?? '',
        costoPartita: (json['costoPartita'] as num?)?.toDouble() ?? 0,
        minutiMinimiPerAddebito: (json['minutiMinimiPerAddebito'] as num?)?.toInt() ?? 0,
        giaGestita: json['giaGestita'] as bool? ?? false,
        presenzeDaRegistrare: json['presenzeDaRegistrare'] as bool? ?? false,
        presenzeBloccate: json['presenzeBloccate'] as bool? ?? false,
        candidati: ((json['candidati'] as List?) ?? const [])
            .map((e) => MatchPaymentCandidate.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Chi si puo' ancora addebitare: chi lo e' gia' stato non si ripropone.
  List<MatchPaymentCandidate> get addebitabili =>
      candidati.where((c) => !c.giaAddebitato).toList();
}

class MatchPaymentCandidate {
  final int playerId;
  final String nome;
  final String? soprannome;
  final RegimePagamento? regime;
  final bool presente;
  final bool haGiocato;
  final int? minutiGiocati;
  final bool preselezionato;
  final bool giaAddebitato;
  final String? motivo;
  final double importoProposto;
  final double arretratoAttuale;

  MatchPaymentCandidate({
    required this.playerId,
    required this.nome,
    this.soprannome,
    this.regime,
    required this.presente,
    required this.haGiocato,
    this.minutiGiocati,
    required this.preselezionato,
    required this.giaAddebitato,
    this.motivo,
    required this.importoProposto,
    required this.arretratoAttuale,
  });

  factory MatchPaymentCandidate.fromJson(Map<String, dynamic> json) => MatchPaymentCandidate(
        playerId: json['playerId'] as int,
        nome: json['nome'] as String? ?? '',
        soprannome: json['soprannome'] as String?,
        regime: RegimePagamentoX.fromApi(json['regime'] as String?),
        presente: json['presente'] as bool? ?? false,
        haGiocato: json['haGiocato'] as bool? ?? false,
        minutiGiocati: json['minutiGiocati'] as int?,
        preselezionato: json['preselezionato'] as bool? ?? false,
        giaAddebitato: json['giaAddebitato'] as bool? ?? false,
        motivo: json['motivo'] as String?,
        importoProposto: (json['importoProposto'] as num?)?.toDouble() ?? 0,
        arretratoAttuale: (json['arretratoAttuale'] as num?)?.toDouble() ?? 0,
      );

  String get displayName => soprannome != null && soprannome!.isNotEmpty ? soprannome! : nome;
}

/// Formattazione unica degli importi, per non avere "8.0 EUR" in giro.
String formatEuro(double value) {
  final arrotondato = value == value.roundToDouble();
  return '${arrotondato ? value.toStringAsFixed(0) : value.toStringAsFixed(2)} €';
}
