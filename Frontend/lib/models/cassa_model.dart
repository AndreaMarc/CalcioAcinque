/// Uscite di cassa e cruscotto del cassiere (vedi Backend/DTOs/Cassa).
class ExpenseModel {
  final int id;
  final int teamId;
  final int? seasonId;
  final int? matchId;
  final String categoria;
  final String categoriaLabel;
  final String descrizione;
  final double importo;
  final DateTime data;
  final String? note;
  final String? adminNome;

  ExpenseModel({
    required this.id,
    required this.teamId,
    this.seasonId,
    this.matchId,
    required this.categoria,
    required this.categoriaLabel,
    required this.descrizione,
    required this.importo,
    required this.data,
    this.note,
    this.adminNome,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) => ExpenseModel(
        id: json['id'] as int,
        teamId: json['teamId'] as int,
        seasonId: json['seasonId'] as int?,
        matchId: json['matchId'] as int?,
        categoria: json['categoria'] as String? ?? 'Altro',
        categoriaLabel: json['categoriaLabel'] as String? ?? 'Altro',
        descrizione: json['descrizione'] as String? ?? '',
        importo: (json['importo'] as num?)?.toDouble() ?? 0,
        data: DateTime.tryParse(json['data'] as String? ?? '') ?? DateTime.now(),
        note: json['note'] as String?,
        adminNome: json['adminNome'] as String?,
      );
}

/// Le categorie ammesse dal server, con etichetta.
const categorieSpesa = <String, String>{
  'Campo': 'Affitto campo',
  'Arbitro': 'Arbitro',
  'Materiale': 'Materiale',
  'Trasferta': 'Trasferta',
  'Altro': 'Altro',
};

class CassaSummary {
  final int? seasonId;
  final String? seasonNome;
  final double entrateAttese;
  final double entrateIncassate;
  final double inVerifica;
  final double uscite;
  final double saldo;
  final List<PartitaNonIncassata> partiteNonIncassate;
  final List<Arretrato> arretrati;
  final List<UscitaCategoria> uscitePerCategoria;

  CassaSummary({
    this.seasonId,
    this.seasonNome,
    required this.entrateAttese,
    required this.entrateIncassate,
    required this.inVerifica,
    required this.uscite,
    required this.saldo,
    required this.partiteNonIncassate,
    required this.arretrati,
    required this.uscitePerCategoria,
  });

  double get daIncassare => (entrateAttese - entrateIncassate).clamp(0, double.infinity);

  factory CassaSummary.fromJson(Map<String, dynamic> json) => CassaSummary(
        seasonId: json['seasonId'] as int?,
        seasonNome: json['seasonNome'] as String?,
        entrateAttese: (json['entrateAttese'] as num?)?.toDouble() ?? 0,
        entrateIncassate: (json['entrateIncassate'] as num?)?.toDouble() ?? 0,
        inVerifica: (json['inVerifica'] as num?)?.toDouble() ?? 0,
        uscite: (json['uscite'] as num?)?.toDouble() ?? 0,
        saldo: (json['saldo'] as num?)?.toDouble() ?? 0,
        partiteNonIncassate: ((json['partiteNonIncassate'] as List?) ?? const [])
            .map((e) => PartitaNonIncassata.fromJson(e as Map<String, dynamic>))
            .toList(),
        arretrati: ((json['arretrati'] as List?) ?? const [])
            .map((e) => Arretrato.fromJson(e as Map<String, dynamic>))
            .toList(),
        uscitePerCategoria: ((json['uscitePerCategoria'] as List?) ?? const [])
            .map((e) => UscitaCategoria.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class PartitaNonIncassata {
  final int matchId;
  final int numeroGiornata;
  final DateTime data;
  final String? titolo;
  final int presenti;
  final int presentiAPartita;

  PartitaNonIncassata({
    required this.matchId,
    required this.numeroGiornata,
    required this.data,
    this.titolo,
    required this.presenti,
    required this.presentiAPartita,
  });

  factory PartitaNonIncassata.fromJson(Map<String, dynamic> json) => PartitaNonIncassata(
        matchId: json['matchId'] as int,
        numeroGiornata: (json['numeroGiornata'] as num?)?.toInt() ?? 0,
        data: DateTime.tryParse(json['data'] as String? ?? '') ?? DateTime.now(),
        titolo: json['titolo'] as String?,
        presenti: (json['presenti'] as num?)?.toInt() ?? 0,
        presentiAPartita: (json['presentiAPartita'] as num?)?.toInt() ?? 0,
      );
}

class Arretrato {
  final int playerId;
  final String nome;
  final String? soprannome;
  final double importo;
  final int voci;

  Arretrato({
    required this.playerId,
    required this.nome,
    this.soprannome,
    required this.importo,
    required this.voci,
  });

  String get displayName => (soprannome ?? '').isNotEmpty ? soprannome! : nome;

  factory Arretrato.fromJson(Map<String, dynamic> json) => Arretrato(
        playerId: json['playerId'] as int,
        nome: json['nome'] as String? ?? '',
        soprannome: json['soprannome'] as String?,
        importo: (json['importo'] as num?)?.toDouble() ?? 0,
        voci: (json['voci'] as num?)?.toInt() ?? 0,
      );
}

class UscitaCategoria {
  final String categoria;
  final String label;
  final double importo;

  UscitaCategoria({required this.categoria, required this.label, required this.importo});

  factory UscitaCategoria.fromJson(Map<String, dynamic> json) => UscitaCategoria(
        categoria: json['categoria'] as String? ?? 'Altro',
        label: json['label'] as String? ?? 'Altro',
        importo: (json['importo'] as num?)?.toDouble() ?? 0,
      );
}
