/// Voti al migliore in campo di una partita.
class MatchMvp {
  final int matchId;
  final bool aperto;
  final int? mioVotoPlayerId;
  final int totaleVoti;
  final List<MvpVoteCount> classifica;
  final List<MvpCandidate> candidati;

  MatchMvp({
    required this.matchId,
    required this.aperto,
    this.mioVotoPlayerId,
    required this.totaleVoti,
    required this.classifica,
    required this.candidati,
  });

  /// Chi e' in testa (piu' di uno a pari merito).
  List<MvpVoteCount> get leader {
    if (classifica.isEmpty) return const [];
    final max = classifica.first.voti;
    return classifica.where((c) => c.voti == max).toList();
  }

  factory MatchMvp.fromJson(Map<String, dynamic> json) => MatchMvp(
        matchId: json['matchId'] as int,
        aperto: json['aperto'] as bool? ?? false,
        mioVotoPlayerId: json['mioVotoPlayerId'] as int?,
        totaleVoti: (json['totaleVoti'] as num?)?.toInt() ?? 0,
        classifica: ((json['classifica'] as List?) ?? const [])
            .map((e) => MvpVoteCount.fromJson(e as Map<String, dynamic>))
            .toList(),
        candidati: ((json['candidati'] as List?) ?? const [])
            .map((e) => MvpCandidate.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class MvpVoteCount {
  final int playerId;
  final String nome;
  final String? soprannome;
  final int voti;
  MvpVoteCount({required this.playerId, required this.nome, this.soprannome, required this.voti});
  String get displayName => (soprannome ?? '').isNotEmpty ? soprannome! : nome;
  factory MvpVoteCount.fromJson(Map<String, dynamic> json) => MvpVoteCount(
        playerId: json['playerId'] as int,
        nome: json['nome'] as String? ?? '',
        soprannome: json['soprannome'] as String?,
        voti: (json['voti'] as num?)?.toInt() ?? 0,
      );
}

class MvpCandidate {
  final int playerId;
  final String nome;
  final String? soprannome;
  final int? numeroMaglia;
  MvpCandidate({required this.playerId, required this.nome, this.soprannome, this.numeroMaglia});
  String get displayName => (soprannome ?? '').isNotEmpty ? soprannome! : nome;
  factory MvpCandidate.fromJson(Map<String, dynamic> json) => MvpCandidate(
        playerId: json['playerId'] as int,
        nome: json['nome'] as String? ?? '',
        soprannome: json['soprannome'] as String?,
        numeroMaglia: json['numeroMaglia'] as int?,
      );
}
