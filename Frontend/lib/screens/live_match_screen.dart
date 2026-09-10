import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/matches_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/club_provider.dart';
import '../widgets/match_incasso_sheet.dart';
import '../providers/theme_provider.dart';
import '../models/match_model.dart';
import '../models/attendance_model.dart';
import '../widgets/app_widgets.dart';

enum StatType { goal, assist, ammonizione, espulsione, autogoal, goalSubiti }

class LiveMatchScreen extends StatefulWidget {
  final int matchId;
  const LiveMatchScreen({super.key, required this.matchId});

  @override
  State<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends State<LiveMatchScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;

  /// Durata e numero di tempi vengono dalla configurazione della squadra
  /// (a 5 sono 2x25, a 7 e a 8 2x30, a 11 2x45), con fallback sul calcio a 5.
  int _minutiPerTempo = 25;
  int _numeroTempi = 2;
  int _remainingSeconds = 25 * 60;
  int _currentHalf = 1;
  bool _isRunning = false;
  late AnimationController _pulseCtrl;

  MatchModel? _match;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    await context.read<MatchesProvider>().loadMatches(auth.teamId);
    await context.read<AttendanceProvider>().loadByMatch(widget.matchId);
    final config = await context.read<ClubProvider>().loadTeamConfig(auth.teamId);
    if (mounted) {
      final matches = context.read<MatchesProvider>().matches;
      setState(() {
        _match = matches.where((m) => m.id == widget.matchId).firstOrNull;
        if (config != null) {
          _minutiPerTempo = config.minutiPerTempo;
          _numeroTempi = config.numeroTempi;
          // Il cronometro non e ancora partito: si riallinea alla durata reale
          if (!_isRunning && _currentHalf == 1) {
            _remainingSeconds = _minutiPerTempo * 60;
          }
        }
      });
    }
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      if (_remainingSeconds <= 0) return;
      setState(() => _isRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_remainingSeconds > 0) {
          setState(() => _remainingSeconds--);
        } else {
          _timer?.cancel();
          setState(() => _isRunning = false);
        }
      });
    }
  }

  void _startNextHalf() {
    if (_currentHalf >= _numeroTempi) return;
    _timer?.cancel();
    setState(() {
      _currentHalf++;
      _remainingSeconds = _minutiPerTempo * 60;
      _isRunning = false;
    });
  }

  String get _displayTime {
    // Minuto di gioco complessivo, contando i tempi gia giocati
    final elapsed = _currentHalf * _minutiPerTempo * 60 - _remainingSeconds;
    final m = elapsed ~/ 60;
    return "$m'";
  }

  String get _clockDisplay {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _onQuickAction(StatType action) {
    final attendances = context.read<AttendanceProvider>().attendances;
    final eligible = attendances.where((a) => a.haGiocato).toList();
    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun giocatore in campo')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.ink2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PlayerSelectorSheet(
        players: eligible,
        actionType: action,
        matchId: widget.matchId,
        onComplete: _loadData,
      ),
    );
  }

  Future<void> _concludeMatch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Concludi Partita'),
        content: const Text('Vuoi concludere la partita?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Concludi')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final auth = context.read<AuthProvider>();
    await context
        .read<MatchesProvider>()
        .updateStato(auth.teamId, widget.matchId, 'Conclusa');
    _timer?.cancel();
    if (mounted) _loadData();
    if (mounted) _proponiIncasso();
  }

  /// Invito non bloccante a registrare l incasso. Non apre il foglio da solo:
  /// a fine partita le presenze possono essere incomplete, e forzare un modale
  /// qui costringerebbe a riaprire la partita per sistemarle.
  void _proponiIncasso() {
    if (!context.read<AuthProvider>().puoGestireSoldi) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Partita conclusa. Vuoi registrare l incasso?'),
      duration: const Duration(seconds: 8),
      action: SnackBarAction(
        label: 'Gestisci',
        onPressed: () => MatchIncassoSheet.show(context, widget.matchId),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final initials = teamInitials(theme.teamName);

    return Consumer2<MatchesProvider, AttendanceProvider>(
      builder: (context, matchProv, attProv, _) {
        final match =
            matchProv.matches.where((m) => m.id == widget.matchId).firstOrNull ??
                _match;
        if (match == null || !attProv.hasLoaded) {
          return const Scaffold(
            backgroundColor: AppTokens.ink,
            body: Center(
              child: CircularProgressIndicator(color: AppTokens.brand),
            ),
          );
        }

        final isLive = match.stato == 'InCorso';
        final isConclusa = match.stato == 'Conclusa';
        final attendances = attProv.attendances;
        final playing = attendances.where((a) => a.haGiocato).toList();
        final goalsScored =
            attendances.fold<int>(0, (s, a) => s + (a.goal ?? 0));
        final goalsConceded =
            attendances.fold<int>(0, (s, a) => s + (a.goalSubiti ?? 0));
        final opponent = (match.titolo ?? '').isNotEmpty
            ? match.titolo!.toUpperCase()
            : 'AVVERSARIO';
        final awayInitials = opponent.length >= 2
            ? opponent.substring(0, 2).toUpperCase()
            : opponent;

        return Scaffold(
          backgroundColor: AppTokens.ink,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: -120,
                  left: -100,
                  child: Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTokens.brand.withOpacity(0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Column(
                  children: [
                    _LiveHeader(
                      pulse: _pulseCtrl,
                      onBack: () => context.pop(),
                      onMore: () => _showMenu(context, isLive, match.id),
                      isConclusa: isConclusa,
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          const SizedBox(height: 8),
                          _Scoreboard(
                            teamInitials: initials,
                            teamName: theme.teamName,
                            awayInitials: awayInitials,
                            awayName: opponent,
                            homeGoals: goalsScored,
                            awayGoals: goalsConceded,
                            half: _currentHalf,
                            timeLabel: _displayTime,
                            pulse: _pulseCtrl,
                          ),
                          const SizedBox(height: 20),
                          if (isLive) ...[
                            _TimerControls(
                              clockDisplay: _clockDisplay,
                              isRunning: _isRunning,
                              remainingSeconds: _remainingSeconds,
                              currentHalf: _currentHalf,
                              numeroTempi: _numeroTempi,
                              onToggle: _toggleTimer,
                              onNextHalf: _startNextHalf,
                            ),
                            const SizedBox(height: 20),
                          ],
                          _QuickActions(onTap: _onQuickAction),
                          const SizedBox(height: 20),
                          Text(
                            'IN CAMPO',
                            style: GoogleFonts.bebasNeue(
                              fontSize: 20,
                              color: Colors.white,
                              letterSpacing: 0.04 * 20,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (playing.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Nessun giocatore in campo',
                                    style: GoogleFonts.spaceGrotesk(
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        context.push('/match/${match.id}/day'),
                                    icon: const Icon(Icons.people, size: 16,
                                        color: Colors.white),
                                    label: Text(
                                      'Match Day',
                                      style: GoogleFonts.spaceGrotesk(
                                          color: Colors.white),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                          color:
                                              Colors.white.withOpacity(0.2)),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: playing.asMap().entries.map((e) {
                                final i = e.key;
                                final a = e.value;
                                return _OnFieldTile(
                                  number: i + 1,
                                  attendance: a,
                                  onTap: () => _showStatsDialog(context, a),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 20),
                          if ((goalsScored + goalsConceded) > 0) ...[
                            Text(
                              'TIMELINE',
                              style: GoogleFonts.bebasNeue(
                                fontSize: 20,
                                color: Colors.white,
                                letterSpacing: 0.04 * 20,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...attendances
                                .where((a) => (a.goal ?? 0) > 0)
                                .map((a) => _TimelineEvent(
                                      name:
                                          a.soprannome ?? a.nomeGiocatore,
                                      count: a.goal ?? 0,
                                      home: true,
                                    )),
                            if (goalsConceded > 0)
                              _TimelineEvent(
                                name: opponent,
                                count: goalsConceded,
                                home: false,
                              ),
                          ],
                          const SizedBox(height: 20),
                          if (isLive)
                            FilledButton.icon(
                              onPressed: _concludeMatch,
                              icon: const Icon(Icons.stop, size: 18),
                              label: const Text('Concludi Partita'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTokens.bad,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMenu(BuildContext context, bool isLive, int matchId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTokens.ink2,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.people, color: Colors.white),
              title: const Text('Match Day',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/match/$matchId/day');
              },
            ),
            if (isLive)
              ListTile(
                leading: const Icon(Icons.stop, color: AppTokens.bad),
                title: const Text('Concludi Partita',
                    style: TextStyle(color: AppTokens.bad)),
                onTap: () {
                  Navigator.pop(ctx);
                  _concludeMatch();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showStatsDialog(BuildContext context, AttendanceModel att) {
    final goalCtrl = TextEditingController(text: '${att.goal ?? ''}');
    final assistCtrl = TextEditingController(text: '${att.assist ?? ''}');
    final ammCtrl = TextEditingController(text: '${att.ammonizioni ?? ''}');
    final espCtrl = TextEditingController(text: '${att.espulsioni ?? ''}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(att.soprannome ?? att.nomeGiocatore),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Expanded(child: _f(goalCtrl, 'Gol')),
              const SizedBox(width: 10),
              Expanded(child: _f(assistCtrl, 'Assist')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _f(ammCtrl, 'Amm.')),
              const SizedBox(width: 10),
              Expanded(child: _f(espCtrl, 'Esp.')),
            ]),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context
                  .read<AttendanceProvider>()
                  .updateAttendance(widget.matchId, att.playerId,
                      goal: int.tryParse(goalCtrl.text) ?? 0,
                      assist: int.tryParse(assistCtrl.text) ?? 0,
                      ammonizioni: int.tryParse(ammCtrl.text) ?? 0,
                      espulsioni: int.tryParse(espCtrl.text) ?? 0);
              _loadData();
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  Widget _f(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }
}

class _LiveHeader extends StatelessWidget {
  final AnimationController pulse;
  final VoidCallback onBack;
  final VoidCallback onMore;
  final bool isConclusa;
  const _LiveHeader({
    required this.pulse,
    required this.onBack,
    required this.onMore,
    required this.isConclusa,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          _darkBtn(Icons.arrow_back, onBack),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isConclusa
                  ? Colors.white.withOpacity(0.08)
                  : AppTokens.bad.withOpacity(0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isConclusa
                    ? Colors.white.withOpacity(0.2)
                    : AppTokens.bad.withOpacity(0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isConclusa)
                  AnimatedBuilder(
                    animation: pulse,
                    builder: (c, _) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: AppTokens.live,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTokens.live.withOpacity(
                              0.4 + 0.4 * pulse.value,
                            ),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                Text(
                  isConclusa ? 'FINE' : 'LIVE',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _darkBtn(Icons.more_vert, onMore),
        ],
      ),
    );
  }

  Widget _darkBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

class _Scoreboard extends StatelessWidget {
  final String teamInitials;
  final String teamName;
  final String awayInitials;
  final String awayName;
  final int homeGoals;
  final int awayGoals;
  final int half;
  final String timeLabel;
  final AnimationController pulse;

  const _Scoreboard({
    required this.teamInitials,
    required this.teamName,
    required this.awayInitials,
    required this.awayName,
    required this.homeGoals,
    required this.awayGoals,
    required this.half,
    required this.timeLabel,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppTokens.brand.withOpacity(0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppTokens.brand.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: pulse,
                builder: (c, _) => Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppTokens.brand
                        .withOpacity(0.5 + 0.5 * pulse.value),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Text(
                '${half}° TEMPO · $timeLabel',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTokens.brand,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                children: [
                  CrestBox(
                    initials: teamInitials,
                    size: 64,
                    radius: 16,
                    fontSize: 26,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    teamName,
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Text(
                    '$homeGoals',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 90,
                      height: 0.85,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '—',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 48,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$awayGoals',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 90,
                      height: 0.85,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  CrestBox(
                    initials: awayInitials,
                    filled: false,
                    size: 64,
                    radius: 16,
                    fontSize: 22,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    awayName,
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimerControls extends StatelessWidget {
  final String clockDisplay;
  final bool isRunning;
  final int remainingSeconds;
  final int currentHalf;
  final int numeroTempi;
  final VoidCallback onToggle;
  final VoidCallback onNextHalf;

  const _TimerControls({
    required this.clockDisplay,
    required this.isRunning,
    required this.remainingSeconds,
    required this.currentHalf,
    required this.numeroTempi,
    required this.onToggle,
    required this.onNextHalf,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TEMPO $currentHalf/$numeroTempi · COUNTDOWN',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.textOnInkMute,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  clockDisplay,
                  style: GoogleFonts.bebasNeue(
                    fontSize: 44,
                    height: 0.9,
                    color: remainingSeconds <= 60
                        ? AppTokens.bad
                        : remainingSeconds <= 300
                            ? AppTokens.warn
                            : Colors.white,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTokens.brand,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTokens.brand.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                isRunning ? Icons.pause : Icons.play_arrow,
                color: AppTokens.brandInk,
                size: 24,
              ),
            ),
          ),
          if (currentHalf < numeroTempi) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: (remainingSeconds == 0 || !isRunning)
                  ? onNextHalf
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Text(
                  '${currentHalf + 1}°T',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: (remainingSeconds == 0 || !isRunning)
                        ? Colors.white
                        : Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final void Function(StatType) onTap;
  const _QuickActions({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      _QA('GOL', Icons.sports_soccer, AppTokens.brand, StatType.goal,
          brand: true),
      _QA('ASSIST', Icons.handshake_outlined, Colors.white, StatType.assist),
      _QA('AMM.', Icons.square, AppTokens.warn, StatType.ammonizione),
      _QA('ESP.', Icons.square_outlined, AppTokens.bad, StatType.espulsione),
      _QA('AG', Icons.sports_soccer, AppTokens.away, StatType.autogoal),
      _QA('SUBITO', Icons.shield_outlined, AppTokens.bad, StatType.goalSubiti),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((q) {
        final brand = q.brand;
        return InkWell(
          onTap: () => onTap(q.type),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: brand
                  ? AppTokens.brand
                  : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: brand
                  ? null
                  : Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(q.icon,
                    size: 16,
                    color: brand ? AppTokens.brandInk : q.color),
                const SizedBox(width: 6),
                Text(
                  q.label,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: brand ? AppTokens.brandInk : Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _QA {
  final String label;
  final IconData icon;
  final Color color;
  final StatType type;
  final bool brand;
  _QA(this.label, this.icon, this.color, this.type, {this.brand = false});
}

class _OnFieldTile extends StatelessWidget {
  final int number;
  final AttendanceModel attendance;
  final VoidCallback onTap;

  const _OnFieldTile({
    required this.number,
    required this.attendance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = attendance.soprannome ?? attendance.nomeGiocatore;
    final goals = attendance.goal ?? 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppTokens.brand,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Text(
                  '$number',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 28,
                    color: AppTokens.brandInk,
                    height: 0.9,
                  ),
                ),
                if (goals > 0)
                  Positioned(
                    top: -4,
                    right: -12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTokens.ink,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '⚽$goals',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppTokens.brand,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppTokens.brandInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineEvent extends StatelessWidget {
  final String name;
  final int count;
  final bool home;
  const _TimelineEvent({
    required this.name,
    required this.count,
    required this.home,
  });

  @override
  Widget build(BuildContext context) {
    final color = home ? AppTokens.brand : AppTokens.away;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Text(
              '×$count',
              style: GoogleFonts.bebasNeue(fontSize: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    home ? 'GOL' : 'GOL SUBITO',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.5),
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    name,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerSelectorSheet extends StatelessWidget {
  final List<AttendanceModel> players;
  final StatType actionType;
  final int matchId;
  final VoidCallback onComplete;

  const _PlayerSelectorSheet({
    required this.players,
    required this.actionType,
    required this.matchId,
    required this.onComplete,
  });

  String get _actionLabel {
    switch (actionType) {
      case StatType.goal:
        return 'GOL';
      case StatType.assist:
        return 'ASSIST';
      case StatType.ammonizione:
        return 'AMMONIZIONE';
      case StatType.espulsione:
        return 'ESPULSIONE';
      case StatType.autogoal:
        return 'AUTOGOL';
      case StatType.goalSubiti:
        return 'GOL SUBITO';
    }
  }

  int _currentValue(AttendanceModel att) {
    switch (actionType) {
      case StatType.goal:
        return att.goal ?? 0;
      case StatType.assist:
        return att.assist ?? 0;
      case StatType.ammonizione:
        return att.ammonizioni ?? 0;
      case StatType.espulsione:
        return att.espulsioni ?? 0;
      case StatType.autogoal:
        return att.autogoal ?? 0;
      case StatType.goalSubiti:
        return att.goalSubiti ?? 0;
    }
  }

  Future<void> _assign(BuildContext context, AttendanceModel att) async {
    final current = _currentValue(att);
    final newVal = current + 1;
    Navigator.pop(context);
    final provider = context.read<AttendanceProvider>();
    switch (actionType) {
      case StatType.goal:
        await provider.updateAttendance(matchId, att.playerId, goal: newVal);
      case StatType.assist:
        await provider.updateAttendance(matchId, att.playerId,
            assist: newVal);
      case StatType.ammonizione:
        await provider.updateAttendance(matchId, att.playerId,
            ammonizioni: newVal);
      case StatType.espulsione:
        await provider.updateAttendance(matchId, att.playerId,
            espulsioni: newVal);
      case StatType.autogoal:
        await provider.updateAttendance(matchId, att.playerId,
            autogoal: newVal);
      case StatType.goalSubiti:
        await provider.updateAttendance(matchId, att.playerId,
            goalSubiti: newVal);
    }
    onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ASSEGNA $_actionLabel',
              style: GoogleFonts.bebasNeue(
                fontSize: 22,
                color: AppTokens.brand,
                letterSpacing: 0.04 * 22,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: players.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, i) {
                  final att = players[i];
                  final current = _currentValue(att);
                  final name = att.soprannome ?? att.nomeGiocatore;
                  return InkWell(
                    onTap: () => _assign(context, att),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Row(
                        children: [
                          JerseyNumber(
                            number: i + 1,
                            size: 40,
                            fontSize: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (current > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTokens.brand.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '×$current',
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 16,
                                  color: AppTokens.brand,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
