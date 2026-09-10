import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../core/constants/api_constants.dart';
import '../widgets/app_widgets.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic>? _teamStats;
  bool _isLoading = true;
  bool _meTab = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final resp = await auth.apiClient.dio
          .get(ApiConstants.teamStats(auth.teamId));
      if (resp.data['success'] == true) {
        setState(() => _teamStats = resp.data['data']);
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final initials = teamInitials(theme.teamName, fallback: 'CA');

    if (_isLoading) {
      return Column(
        children: [
          AppTopBar(teamInitials: initials, title: 'Statistiche'),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }

    final classifica = (_teamStats?['classifica'] as List?) ?? [];
    final totPartite = _teamStats?['totalePartite'] as int? ?? 0;
    final totGoal = _teamStats?['totaleGoal'] as int? ?? 0;
    final totGoalSubiti = _teamStats?['totaleGoalSubiti'] as int? ?? 0;
    final diff = totGoal - totGoalSubiti;
    final vittorie = _teamStats?['vittorie'] as int? ?? 0;
    final pareggi = _teamStats?['pareggi'] as int? ?? 0;
    final sconfitte = _teamStats?['sconfitte'] as int? ?? 0;

    final topScorers = List<Map<String, dynamic>>.from(classifica)
      ..sort((a, b) => (b['totaleGoal'] ?? 0).compareTo(a['totaleGoal'] ?? 0));
    final top5 = topScorers.take(5).toList();
    final maxGoals = top5.isEmpty
        ? 1
        : (top5.first['totaleGoal'] as int).clamp(1, 99999);

    return Column(
      children: [
        AppTopBar(
          teamInitials: initials,
          title: 'Statistiche',
          subtitle: 'Stagione in corso',
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadStats,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: _TabSwitcher(
                    isMe: _meTab,
                    onChange: (v) => setState(() => _meTab = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: _SeasonHero(
                    vittorie: vittorie,
                    pareggi: pareggi,
                    sconfitte: sconfitte,
                    diff: diff,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: _GoalsSummaryCard(
                    totGoal: totGoal,
                    totGoalSubiti: totGoalSubiti,
                    totPartite: totPartite,
                  ),
                ),
                const SectionHead(title: 'CAPOCANNONIERI'),
                if (top5.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: Center(child: Text('Nessun dato ancora')),
                  )
                else
                  ...top5.asMap().entries.map((e) {
                    final i = e.key;
                    final p = e.value;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: _ScorerRow(
                        rank: i + 1,
                        nome: p['soprannome'] ?? p['nomeGiocatore'] ?? '',
                        goals: p['totaleGoal'] ?? 0,
                        maxGoals: maxGoals,
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TabSwitcher extends StatelessWidget {
  final bool isMe;
  final ValueChanged<bool> onChange;
  const _TabSwitcher({required this.isMe, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final activeBg = isDark ? AppTokens.darkCard : Colors.white;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _opt('Squadra', !isMe, () => onChange(false),
              activeBg, textColor, muteColor),
          _opt('Io', isMe, () => onChange(true),
              activeBg, textColor, muteColor),
        ],
      ),
    );
  }

  Widget _opt(String label, bool active, VoidCallback tap, Color bg,
      Color fg, Color muted) {
    return Expanded(
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: active
              ? BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                )
              : null,
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? fg : muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _SeasonHero extends StatelessWidget {
  final int vittorie;
  final int pareggi;
  final int sconfitte;
  final int diff;
  const _SeasonHero({
    required this.vittorie,
    required this.pareggi,
    required this.sconfitte,
    required this.diff,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTokens.darkCard : AppTokens.card;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow('Stagione in corso', color: muteColor),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$vittorie',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 56,
                      height: 0.9,
                      color: textColor,
                    ),
                  ),
                  Text(
                    'VITTORIE',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.ok,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$pareggi',
                        style: GoogleFonts.bebasNeue(
                            fontSize: 28, color: textColor),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'PAREGGI',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: muteColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$sconfitte',
                        style: GoogleFonts.bebasNeue(
                          fontSize: 28,
                          color: AppTokens.bad,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'SCONFITTE',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: muteColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: lineColor, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Differenza reti',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: muteColor,
                ),
              ),
              Text(
                diff >= 0 ? '+$diff' : '$diff',
                style: GoogleFonts.bebasNeue(
                  fontSize: 24,
                  color: diff >= 0 ? AppTokens.ok : AppTokens.bad,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalsSummaryCard extends StatelessWidget {
  final int totGoal;
  final int totGoalSubiti;
  final int totPartite;
  const _GoalsSummaryCard({
    required this.totGoal,
    required this.totGoalSubiti,
    required this.totPartite,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTokens.darkCard : AppTokens.card;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lineColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow('Reti segnate', color: muteColor),
                const SizedBox(height: 4),
                Text(
                  '$totGoal GOL',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 30,
                    color: textColor,
                    letterSpacing: 0.02 * 30,
                  ),
                ),
                Text(
                  totPartite > 0
                      ? '${(totGoal / totPartite).toStringAsFixed(1)} per partita'
                      : 'Nessuna partita',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    color: muteColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'GOL SUBITI',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: muteColor,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totGoalSubiti',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 30,
                    color: AppTokens.bad,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScorerRow extends StatelessWidget {
  final int rank;
  final String nome;
  final int goals;
  final int maxGoals;

  const _ScorerRow({
    required this.rank,
    required this.nome,
    required this.goals,
    required this.maxGoals,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTokens.darkCard : AppTokens.card;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;

    final rankBg = rank == 1
        ? AppTokens.brand
        : rank < 4
            ? AppTokens.ink
            : (isDark ? AppTokens.darkLine : AppTokens.line);
    final rankFg = rank == 1
        ? AppTokens.brandInk
        : rank < 4
            ? Colors.white
            : muteColor;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lineColor),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: rankBg,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: GoogleFonts.bebasNeue(fontSize: 14, color: rankFg),
            ),
          ),
          const SizedBox(width: 10),
          JerseyNumber(number: rank, size: 40, fontSize: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nome,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 5),
                AppProgressBar(
                  value: maxGoals > 0 ? goals / maxGoals : 0,
                  height: 3,
                  fillColor: isDark ? Colors.white : AppTokens.ink,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$goals',
                style: GoogleFonts.bebasNeue(fontSize: 26, color: textColor),
              ),
              const SizedBox(width: 4),
              Text(
                'GOL',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: muteColor,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
