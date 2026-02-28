import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/matches_provider.dart';
import '../providers/attendance_provider.dart';
import '../models/match_model.dart';
import '../models/attendance_model.dart';

enum StatType { goal, assist, ammonizione, espulsione, autogoal, goalSubiti }

class LiveMatchScreen extends StatefulWidget {
  final int matchId;
  const LiveMatchScreen({super.key, required this.matchId});

  @override
  State<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends State<LiveMatchScreen> {
  // Timer state
  Timer? _timer;
  int _remainingSeconds = 25 * 60;
  int _currentHalf = 1;
  bool _isRunning = false;

  MatchModel? _match;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    await context.read<MatchesProvider>().loadMatches(auth.teamId);
    await context.read<AttendanceProvider>().loadByMatch(widget.matchId);
    if (mounted) {
      final matches = context.read<MatchesProvider>().matches;
      setState(() {
        _match = matches.where((m) => m.id == widget.matchId).firstOrNull;
      });
    }
  }

  // ── Timer controls ──

  void _startTimer() {
    if (_remainingSeconds <= 0) return;
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _pauseTimer();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _toggleTimer() {
    if (_isRunning) {
      _pauseTimer();
    } else {
      _startTimer();
    }
  }

  void _startSecondHalf() {
    _pauseTimer();
    setState(() {
      _currentHalf = 2;
      _remainingSeconds = 25 * 60;
    });
  }

  void _resetHalf() {
    _pauseTimer();
    setState(() {
      _remainingSeconds = 25 * 60;
    });
  }

  String get _displayTime {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Quick action ──

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PlayerSelectorSheet(
        players: eligible,
        actionType: action,
        matchId: widget.matchId,
        onComplete: () {
          _loadData();
        },
      ),
    );
  }

  // ── Conclude match ──

  Future<void> _concludeMatch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Concludi Partita'),
        content: const Text('Vuoi concludere la partita? Potrai comunque modificare le statistiche dopo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Concludi')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    final success = await context.read<MatchesProvider>().updateStato(
      auth.teamId, widget.matchId, 'Conclusa');
    if (success && mounted) {
      _pauseTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partita conclusa!')),
      );
      _loadData();
    }
  }

  // ── Stats dialog (same as MatchDayScreen) ──

  void _showStatsDialog(BuildContext context, AttendanceModel att) {
    final minutiCtrl = TextEditingController(text: '${att.minutiGiocati ?? ''}');
    final goalCtrl = TextEditingController(text: '${att.goal ?? ''}');
    final assistCtrl = TextEditingController(text: '${att.assist ?? ''}');
    final autogoalCtrl = TextEditingController(text: '${att.autogoal ?? ''}');
    final ammonizioniCtrl = TextEditingController(text: '${att.ammonizioni ?? ''}');
    final espulsioniCtrl = TextEditingController(text: '${att.espulsioni ?? ''}');
    final goalSubitiCtrl = TextEditingController(text: '${att.goalSubiti ?? ''}');

    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.bar_chart, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(att.soprannome ?? att.nomeGiocatore,
                style: const TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _statsField(minutiCtrl, 'Minuti giocati', Icons.timer_outlined, cs.primary),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _statsField(goalCtrl, 'Goal', Icons.sports_soccer, Colors.green.shade700)),
                const SizedBox(width: 10),
                Expanded(child: _statsField(assistCtrl, 'Assist', Icons.handshake_outlined, Colors.purple.shade600)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _statsField(autogoalCtrl, 'Autogoal', Icons.sports_soccer, Colors.red.shade600)),
                const SizedBox(width: 10),
                Expanded(child: _statsField(goalSubitiCtrl, 'Goal subiti', Icons.shield_outlined, Colors.orange.shade700)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _statsField(ammonizioniCtrl, 'Ammonizioni', Icons.square, Colors.amber.shade700)),
                const SizedBox(width: 10),
                Expanded(child: _statsField(espulsioniCtrl, 'Espulsioni', Icons.square, Colors.red.shade700)),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton.icon(
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Salva'),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AttendanceProvider>().updateAttendance(
                widget.matchId, att.playerId,
                minutiGiocati: int.tryParse(minutiCtrl.text) ?? 0,
                goal: int.tryParse(goalCtrl.text) ?? 0,
                assist: int.tryParse(assistCtrl.text) ?? 0,
                autogoal: int.tryParse(autogoalCtrl.text) ?? 0,
                ammonizioni: int.tryParse(ammonizioniCtrl.text) ?? 0,
                espulsioni: int.tryParse(espulsioniCtrl.text) ?? 0,
                goalSubiti: int.tryParse(goalSubitiCtrl.text) ?? 0,
              );
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  Widget _statsField(TextEditingController ctrl, String label, IconData icon, Color color) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        prefixIcon: Icon(icon, color: color, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 15),
    );
  }

  // ── BUILD ──

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer2<MatchesProvider, AttendanceProvider>(
      builder: (context, matchProv, attProv, _) {
        // Refresh match from provider
        final match = matchProv.matches.where((m) => m.id == widget.matchId).firstOrNull ?? _match;
        if (match == null || !attProv.hasLoaded) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final isLive = match.stato == 'InCorso';
        final isConclusa = match.stato == 'Conclusa';
        final attendances = attProv.attendances;
        final playing = attendances.where((a) => a.haGiocato).toList();

        // Score
        final goalsScored = attendances.fold<int>(0, (s, a) => s + (a.goal ?? 0));
        final goalsConceded = attendances.fold<int>(0, (s, a) => s + (a.goalSubiti ?? 0));

        return Scaffold(
          appBar: AppBar(
            title: Text(isConclusa
                ? 'Statistiche - ${match.displayTitle}'
                : 'Live - ${match.displayTitle}'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            actions: [
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'conclude') _concludeMatch();
                  if (val == 'matchday') context.push('/match/${match.id}/day');
                },
                itemBuilder: (_) => [
                  if (isLive)
                    const PopupMenuItem(value: 'conclude',
                      child: ListTile(
                        leading: Icon(Icons.stop, color: Colors.red),
                        title: Text('Concludi Partita'),
                        contentPadding: EdgeInsets.zero,
                      )),
                  const PopupMenuItem(value: 'matchday',
                    child: ListTile(
                      leading: Icon(Icons.people),
                      title: Text('Presenze (Match Day)'),
                      contentPadding: EdgeInsets.zero,
                    )),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // ── [1] TIMER / CONCLUSA BANNER ──
              if (isLive)
                _buildTimerCard(cs)
              else if (isConclusa)
                _buildConclusaBanner(cs),

              // ── [2] SCORE ──
              _buildScoreCard(goalsScored, goalsConceded, cs),

              // ── [3] QUICK ACTIONS ──
              _buildQuickActions(cs),

              // ── [4] PLAYER LIST ──
              if (playing.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sports, size: 48, color: cs.onSurfaceVariant.withOpacity(0.4)),
                        const SizedBox(height: 8),
                        Text('Nessun giocatore in campo',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text('Segna i giocatori come "Giocato" nella schermata Match Day',
                          style: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.6), fontSize: 12)),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/match/${match.id}/day'),
                          icon: const Icon(Icons.people, size: 18),
                          label: const Text('Vai a Match Day'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: playing.length,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemBuilder: (context, index) {
                      final att = playing[index];
                      return _buildPlayerTile(att, cs);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Timer Card ──

  Widget _buildTimerCard(ColorScheme cs) {
    final timerColor = _remainingSeconds <= 60
        ? Colors.red
        : _remainingSeconds <= 5 * 60
            ? Colors.orange
            : cs.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer.withOpacity(0.3), cs.surface],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // Half indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _halfPill('1T', _currentHalf == 1, cs),
              const SizedBox(width: 8),
              _halfPill('2T', _currentHalf == 2, cs),
            ],
          ),
          const SizedBox(height: 8),
          // Countdown display
          Text(
            _displayTime,
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              color: timerColor,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Play/Pause
              FilledButton.icon(
                onPressed: _toggleTimer,
                icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                label: Text(_isRunning ? 'Pausa' : 'Avvia'),
                style: FilledButton.styleFrom(
                  backgroundColor: _isRunning ? Colors.orange : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(width: 12),
              // Second half / Reset
              if (_currentHalf == 1)
                OutlinedButton.icon(
                  onPressed: _remainingSeconds == 0 || !_isRunning ? _startSecondHalf : null,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('2° Tempo'),
                )
              else
                OutlinedButton.icon(
                  onPressed: !_isRunning ? _resetHalf : null,
                  icon: const Icon(Icons.replay),
                  label: const Text('Reset'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _halfPill(String label, bool active, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: active ? cs.primary : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(
        fontWeight: FontWeight.bold,
        color: active ? cs.onPrimary : cs.onSurfaceVariant,
      )),
    );
  }

  // ── Conclusa Banner ──

  Widget _buildConclusaBanner(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flag, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text('Partita Conclusa',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            )),
          const SizedBox(width: 8),
          Text('(modifica statistiche)',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  // ── Score Card ──

  Widget _buildScoreCard(int goalsScored, int goalsConceded, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            children: [
              Text('$goalsScored', style: TextStyle(
                fontSize: 40, fontWeight: FontWeight.w800, color: cs.primary)),
              Text('NOI', style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('-', style: TextStyle(
              fontSize: 32, fontWeight: FontWeight.w300, color: cs.onSurfaceVariant)),
          ),
          Column(
            children: [
              Text('$goalsConceded', style: TextStyle(
                fontSize: 40, fontWeight: FontWeight.w800, color: Colors.red.shade600)),
              Text('LORO', style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Quick Actions ──

  Widget _buildQuickActions(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          _actionButton('Goal', Icons.sports_soccer, Colors.green.shade600, StatType.goal),
          _actionButton('Assist', Icons.handshake, Colors.purple.shade600, StatType.assist),
          _actionButton('Ammon.', Icons.square, Colors.amber.shade700, StatType.ammonizione),
          _actionButton('Espuls.', Icons.square, Colors.red.shade700, StatType.espulsione),
          _actionButton('Autogol', Icons.sports_soccer, Colors.orange.shade700, StatType.autogoal),
          _actionButton('G. Subiti', Icons.shield, Colors.deepOrange, StatType.goalSubiti),
        ],
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, StatType type) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _onQuickAction(type),
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Player Tile ──

  Widget _buildPlayerTile(AttendanceModel att, ColorScheme cs) {
    final stats = <Widget>[];
    if ((att.goal ?? 0) > 0) {
      stats.add(_statBadge(Icons.sports_soccer, '${att.goal}', Colors.green.shade700));
    }
    if ((att.assist ?? 0) > 0) {
      stats.add(_statBadge(Icons.handshake_outlined, '${att.assist}', Colors.purple.shade600));
    }
    if ((att.ammonizioni ?? 0) > 0) {
      stats.add(_statBadge(Icons.square, '${att.ammonizioni}', Colors.amber.shade700));
    }
    if ((att.espulsioni ?? 0) > 0) {
      stats.add(_statBadge(Icons.square, '${att.espulsioni}', Colors.red.shade700));
    }
    if ((att.autogoal ?? 0) > 0) {
      stats.add(_statBadge(Icons.sports_soccer, '${att.autogoal} AG', Colors.orange.shade700));
    }
    if ((att.goalSubiti ?? 0) > 0) {
      stats.add(_statBadge(Icons.shield_outlined, '${att.goalSubiti} GS', Colors.deepOrange));
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showStatsDialog(context, att),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue,
                radius: 20,
                child: Text(
                  (att.soprannome ?? att.nomeGiocatore).substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(att.soprannome ?? att.nomeGiocatore,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (stats.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(spacing: 4, runSpacing: 2, children: stats),
                    ],
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, size: 18, color: cs.onSurfaceVariant.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ── Player Selector Bottom Sheet ──

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
      case StatType.goal: return 'Goal';
      case StatType.assist: return 'Assist';
      case StatType.ammonizione: return 'Ammonizione';
      case StatType.espulsione: return 'Espulsione';
      case StatType.autogoal: return 'Autogoal';
      case StatType.goalSubiti: return 'Goal Subito';
    }
  }

  IconData get _actionIcon {
    switch (actionType) {
      case StatType.goal: return Icons.sports_soccer;
      case StatType.assist: return Icons.handshake;
      case StatType.ammonizione: return Icons.square;
      case StatType.espulsione: return Icons.square;
      case StatType.autogoal: return Icons.sports_soccer;
      case StatType.goalSubiti: return Icons.shield;
    }
  }

  Color get _actionColor {
    switch (actionType) {
      case StatType.goal: return Colors.green.shade600;
      case StatType.assist: return Colors.purple.shade600;
      case StatType.ammonizione: return Colors.amber.shade700;
      case StatType.espulsione: return Colors.red.shade700;
      case StatType.autogoal: return Colors.orange.shade700;
      case StatType.goalSubiti: return Colors.deepOrange;
    }
  }

  int _getCurrentValue(AttendanceModel att) {
    switch (actionType) {
      case StatType.goal: return att.goal ?? 0;
      case StatType.assist: return att.assist ?? 0;
      case StatType.ammonizione: return att.ammonizioni ?? 0;
      case StatType.espulsione: return att.espulsioni ?? 0;
      case StatType.autogoal: return att.autogoal ?? 0;
      case StatType.goalSubiti: return att.goalSubiti ?? 0;
    }
  }

  Future<void> _assign(BuildContext context, AttendanceModel att) async {
    final current = _getCurrentValue(att);
    final newVal = current + 1;

    Navigator.pop(context);

    final provider = context.read<AttendanceProvider>();
    switch (actionType) {
      case StatType.goal:
        await provider.updateAttendance(matchId, att.playerId, goal: newVal);
      case StatType.assist:
        await provider.updateAttendance(matchId, att.playerId, assist: newVal);
      case StatType.ammonizione:
        await provider.updateAttendance(matchId, att.playerId, ammonizioni: newVal);
      case StatType.espulsione:
        await provider.updateAttendance(matchId, att.playerId, espulsioni: newVal);
      case StatType.autogoal:
        await provider.updateAttendance(matchId, att.playerId, autogoal: newVal);
      case StatType.goalSubiti:
        await provider.updateAttendance(matchId, att.playerId, goalSubiti: newVal);
    }

    onComplete();

    if (context.mounted) {
      final name = att.soprannome ?? att.nomeGiocatore;
      final emoji = actionType == StatType.goal ? '\u26BD' :
                    actionType == StatType.assist ? '\ud83e\udd1d' :
                    actionType == StatType.ammonizione ? '\ud83d\udfe8' :
                    actionType == StatType.espulsione ? '\ud83d\udfe5' :
                    actionType == StatType.autogoal ? '\ud83d\ude2c' : '\ud83e\udee3';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$emoji $_actionLabel assegnato a $name ($newVal)'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_actionIcon, color: _actionColor, size: 24),
                const SizedBox(width: 8),
                Text('Assegna $_actionLabel',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _actionColor)),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            // Player list
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final att = players[index];
                  final current = _getCurrentValue(att);
                  return ListTile(
                    onTap: () => _assign(context, att),
                    leading: CircleAvatar(
                      backgroundColor: _actionColor.withOpacity(0.15),
                      child: Text(
                        (att.soprannome ?? att.nomeGiocatore).substring(0, 1).toUpperCase(),
                        style: TextStyle(fontWeight: FontWeight.bold, color: _actionColor),
                      ),
                    ),
                    title: Text(att.soprannome ?? att.nomeGiocatore,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                    trailing: current > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _actionColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('$current', style: TextStyle(
                              fontWeight: FontWeight.bold, color: _actionColor)),
                          )
                        : null,
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
