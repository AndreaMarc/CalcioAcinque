import 'payment_model.dart';
import 'team_draft.dart' show PlayerPosition, PlayerPositionX;

/// Disciplina della squadra. I valori `api` corrispondono all'enum `TeamFormat`
/// del backend (`Backend/Models/Enums/TeamFormat.cs`).
enum TeamFormat { calcioA5, calcioA7, calcioA8, calcioA11 }

extension TeamFormatX on TeamFormat {
  String get apiValue {
    switch (this) {
      case TeamFormat.calcioA5:
        return 'CalcioA5';
      case TeamFormat.calcioA7:
        return 'CalcioA7';
      case TeamFormat.calcioA8:
        return 'CalcioA8';
      case TeamFormat.calcioA11:
        return 'CalcioA11';
    }
  }

  String get label {
    switch (this) {
      case TeamFormat.calcioA5:
        return 'Calcio a 5';
      case TeamFormat.calcioA7:
        return 'Calcio a 7';
      case TeamFormat.calcioA8:
        return 'Calcio a 8';
      case TeamFormat.calcioA11:
        return 'Calcio a 11';
    }
  }

  String get shortLabel {
    switch (this) {
      case TeamFormat.calcioA5:
        return 'A5';
      case TeamFormat.calcioA7:
        return 'A7';
      case TeamFormat.calcioA8:
        return 'A8';
      case TeamFormat.calcioA11:
        return 'A11';
    }
  }

  int get giocatoriInCampo {
    switch (this) {
      case TeamFormat.calcioA5:
        return 5;
      case TeamFormat.calcioA7:
        return 7;
      case TeamFormat.calcioA8:
        return 8;
      case TeamFormat.calcioA11:
        return 11;
    }
  }

  /// Ruoli proponibili nel formato. Rispecchia i preset di `TeamFormats` lato backend:
  /// il server scarta comunque i ruoli non previsti, questa lista serve solo alla UI.
  List<PlayerPosition> get posizioni {
    switch (this) {
      case TeamFormat.calcioA5:
        return const [
          PlayerPosition.portiere,
          PlayerPosition.difensore,
          PlayerPosition.laterale,
          PlayerPosition.centrale,
          PlayerPosition.pivot,
          PlayerPosition.universale,
          PlayerPosition.jolly,
        ];
      case TeamFormat.calcioA7:
      case TeamFormat.calcioA8:
        return const [
          PlayerPosition.portiere,
          PlayerPosition.difensore,
          PlayerPosition.terzino,
          PlayerPosition.mediano,
          PlayerPosition.centrocampista,
          PlayerPosition.esterno,
          PlayerPosition.ala,
          PlayerPosition.attaccante,
          PlayerPosition.jolly,
        ];
      case TeamFormat.calcioA11:
        return const [
          PlayerPosition.portiere,
          PlayerPosition.terzino,
          PlayerPosition.difensore,
          PlayerPosition.libero,
          PlayerPosition.mediano,
          PlayerPosition.centrocampista,
          PlayerPosition.trequartista,
          PlayerPosition.esterno,
          PlayerPosition.ala,
          PlayerPosition.attaccante,
          PlayerPosition.punta,
          PlayerPosition.jolly,
        ];
    }
  }

  static TeamFormat fromApi(String? value) {
    switch (value) {
      case 'CalcioA7':
        return TeamFormat.calcioA7;
      case 'CalcioA8':
        return TeamFormat.calcioA8;
      case 'CalcioA11':
        return TeamFormat.calcioA11;
      case 'CalcioA5':
      default:
        return TeamFormat.calcioA5;
    }
  }
}

/// Preset restituito da `GET /api/clubs/formats`: usato per mostrare i default
/// di regole e ruoli quando si scegle il formato di una nuova squadra.
class TeamFormatInfo {
  final TeamFormat formato;
  final String label;
  final String shortLabel;
  final int giocatoriInCampo;
  final int maxConvocati;
  final int minutiPerTempo;
  final int numeroTempi;
  final List<PlayerPosition> posizioni;

  TeamFormatInfo({
    required this.formato,
    required this.label,
    required this.shortLabel,
    required this.giocatoriInCampo,
    required this.maxConvocati,
    required this.minutiPerTempo,
    required this.numeroTempi,
    required this.posizioni,
  });

  factory TeamFormatInfo.fromJson(Map<String, dynamic> json) {
    final formato = TeamFormatX.fromApi(json['valore'] as String?);
    return TeamFormatInfo(
      formato: formato,
      label: json['label'] as String? ?? formato.label,
      shortLabel: json['shortLabel'] as String? ?? formato.shortLabel,
      giocatoriInCampo: (json['giocatoriInCampo'] as num?)?.toInt() ?? formato.giocatoriInCampo,
      maxConvocati: (json['maxConvocati'] as num?)?.toInt() ?? 0,
      minutiPerTempo: (json['minutiPerTempo'] as num?)?.toInt() ?? 25,
      numeroTempi: (json['numeroTempi'] as num?)?.toInt() ?? 2,
      posizioni: (json['posizioni'] as List? ?? const [])
          .map((e) => PlayerPositionX.fromApi(e as String?))
          .whereType<PlayerPosition>()
          .toList(),
    );
  }

  /// Preset locale, usato quando il catalogo non e' ancora stato scaricato.
  factory TeamFormatInfo.local(TeamFormat formato) => TeamFormatInfo(
        formato: formato,
        label: formato.label,
        shortLabel: formato.shortLabel,
        giocatoriInCampo: formato.giocatoriInCampo,
        maxConvocati: formato.giocatoriInCampo * 2 + 2,
        minutiPerTempo: formato == TeamFormat.calcioA11
            ? 45
            : formato == TeamFormat.calcioA5
                ? 25
                : 30,
        numeroTempi: 2,
        posizioni: formato.posizioni,
      );
}

/// Configurazione completa di una squadra (`GET /api/teams/{teamId}`).
class TeamConfig {
  final int id;
  final int? clubId;
  final String? clubNome;
  final String nome;
  final TeamFormat formato;
  final String formatoLabel;
  final String formatoShortLabel;
  final int partitePerStagione;
  final int gettoniPerGiocatore;
  final bool useGettoni;
  final int giocatoriInCampo;
  final int? maxConvocati;
  final int minutiPerTempo;
  final int numeroTempi;
  final double quotaIscrizione;
  final double quotaTesseramento;
  final double costoPartita;

  final RegimePagamento regimePagamentoDefault;
  final DestinatariQuota applicaIscrizioneA;
  final DestinatariQuota applicaTesseramentoA;
  final int minutiMinimiPerAddebito;

  /// Ore prima della partita per il promemoria. 0 = spento.
  final int orePromemoriaPartita;

  /// Override della squadra: null = valgono quelli della società.
  final String? paypalLink;
  final String? iban;
  final String? intestatarioIban;

  /// Valori efficaci risolti dal server (squadra ?? societa).
  final String? paypalLinkEffettivo;
  final String? ibanEffettivo;
  final String? intestatarioIbanEffettivo;

  final int totaleGiocatori;

  /// Logo condiviso della squadra (base64), null se non caricato.
  final String? logoBase64;

  TeamConfig({
    required this.id,
    this.clubId,
    this.clubNome,
    required this.nome,
    required this.formato,
    required this.formatoLabel,
    required this.formatoShortLabel,
    required this.partitePerStagione,
    required this.gettoniPerGiocatore,
    required this.useGettoni,
    required this.giocatoriInCampo,
    this.maxConvocati,
    required this.minutiPerTempo,
    required this.numeroTempi,
    required this.quotaIscrizione,
    required this.quotaTesseramento,
    required this.costoPartita,
    this.regimePagamentoDefault = RegimePagamento.stagionale,
    this.applicaIscrizioneA = DestinatariQuota.soloStagionali,
    this.applicaTesseramentoA = DestinatariQuota.tutti,
    this.minutiMinimiPerAddebito = 0,
    this.orePromemoriaPartita = 24,
    this.paypalLink,
    this.iban,
    this.intestatarioIban,
    this.paypalLinkEffettivo,
    this.ibanEffettivo,
    this.intestatarioIbanEffettivo,
    required this.totaleGiocatori,
    this.logoBase64,
  });

  factory TeamConfig.fromJson(Map<String, dynamic> json) {
    final formato = TeamFormatX.fromApi(json['formato'] as String?);
    return TeamConfig(
      id: json['id'] as int,
      clubId: json['clubId'] as int?,
      clubNome: json['clubNome'] as String?,
      nome: json['nome'] as String? ?? '',
      formato: formato,
      formatoLabel: json['formatoLabel'] as String? ?? formato.label,
      formatoShortLabel: json['formatoShortLabel'] as String? ?? formato.shortLabel,
      partitePerStagione: (json['partitePerStagione'] as num?)?.toInt() ?? 8,
      gettoniPerGiocatore: (json['gettoniPerGiocatore'] as num?)?.toInt() ?? 4,
      useGettoni: json['useGettoni'] as bool? ?? true,
      giocatoriInCampo: (json['giocatoriInCampo'] as num?)?.toInt() ?? formato.giocatoriInCampo,
      maxConvocati: (json['maxConvocati'] as num?)?.toInt(),
      minutiPerTempo: (json['minutiPerTempo'] as num?)?.toInt() ?? 25,
      numeroTempi: (json['numeroTempi'] as num?)?.toInt() ?? 2,
      quotaIscrizione: (json['quotaIscrizione'] as num?)?.toDouble() ?? 0,
      quotaTesseramento: (json['quotaTesseramento'] as num?)?.toDouble() ?? 0,
      costoPartita: (json['costoPartita'] as num?)?.toDouble() ?? 0,
      regimePagamentoDefault:
          RegimePagamentoX.fromApi(json['regimePagamentoDefault'] as String?) ??
              RegimePagamento.stagionale,
      applicaIscrizioneA: DestinatariQuotaX.fromApi(json['applicaIscrizioneA'] as String?),
      applicaTesseramentoA: DestinatariQuotaX.fromApi(json['applicaTesseramentoA'] as String?),
      minutiMinimiPerAddebito: (json['minutiMinimiPerAddebito'] as num?)?.toInt() ?? 0,
      orePromemoriaPartita: (json['orePromemoriaPartita'] as num?)?.toInt() ?? 24,
      paypalLink: json['paypalLink'] as String?,
      iban: json['iban'] as String?,
      intestatarioIban: json['intestatarioIban'] as String?,
      paypalLinkEffettivo: json['paypalLinkEffettivo'] as String?,
      ibanEffettivo: json['ibanEffettivo'] as String?,
      intestatarioIbanEffettivo: json['intestatarioIbanEffettivo'] as String?,
      totaleGiocatori: (json['totaleGiocatori'] as num?)?.toInt() ?? 0,
      logoBase64: json['logoBase64'] as String?,
    );
  }

  /// Ci sono dati sufficienti per proporre un pagamento rapido.
  bool get haDatiPagamento =>
      (paypalLinkEffettivo != null && paypalLinkEffettivo!.isNotEmpty) ||
      (ibanEffettivo != null && ibanEffettivo!.isNotEmpty);

  /// Costo stagionale atteso per giocatore: quote fisse piu' i gettoni/partite previsti.
  double get costoStagioneStimato {
    final partite = useGettoni ? gettoniPerGiocatore : partitePerStagione;
    return quotaIscrizione + quotaTesseramento + costoPartita * partite;
  }
}
