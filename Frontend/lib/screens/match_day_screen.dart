import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/dashboard_provider.dart';
import '../models/attendance_model.dart';

class MatchDayScreen extends StatefulWidget {
  final int matchId;
  const MatchDayScreen({super.key, required this.matchId});

  @override
  State<MatchDayScreen> createState() => _MatchDayScreenState();
}

class _MatchDayScreenState extends State<MatchDayScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    await context.read<AttendanceProvider>().loadByMatch(widget.matchId);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final useGettoni = context.watch<DashboardProvider>().useGettoni;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Day'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Consumer<AttendanceProvider>(
          builder: (context, attProv, _) {
            if (!attProv.hasLoaded) {
              return const Center(child: CircularProgressIndicator());
            }
            final attendances = attProv.attendances;
            if (attendances.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sports, size: 64,
                      color: cs.onSurfaceVariant.withOpacity(0.4)),
                    const SizedBox(height: 16),
                    Text('Nessun giocatore convocato',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text('Invia prima le convocazioni',
                      style: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.7),
                        fontSize: 13)),
                  ],
                ),
              );
            }

            final presenti = attendances.where((a) => a.presente).length;
            final giocato = attendances.where((a) => a.haGiocato).length;
            final totalGoal = attendances.fold<int>(0, (s, a) => s + (a.goal ?? 0));
            final totalAssist = attendances.fold<int>(0, (s, a) => s + (a.assist ?? 0));

            return Column(
              children: [
                // Header stats
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.3),
                    border: Border(bottom: BorderSide(
                      color: cs.outlineVariant.withOpacity(0.5))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _headerStat('Convocati', '${attendances.length}', cs.primary),
                      _headerStat('Presenti', '$presenti', Colors.green),
                      _headerStat('Giocato', '$giocato', Colors.blue),
                      _headerStat('Goal', '$totalGoal', Colors.orange),
                      _headerStat('Assist', '$totalAssist', Colors.purple),
                    ],
                  ),
                ),
                if (auth.isAdmin)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Tocca un giocatore per inserire le statistiche',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic, color: cs.onSurfaceVariant),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: attendances.length,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemBuilder: (context, index) {
                      final att = attendances[index];
                      return _AttendanceTile(
                        attendance: att,
                        isAdmin: auth.isAdmin,
                        matchId: widget.matchId,
                        onUpdate: _loadData,
                        useGettoni: useGettoni,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _headerStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10,
          color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _AttendanceTile extends StatelessWidget {
  final AttendanceModel attendance;
  final bool isAdmin;
  final int matchId;
  final VoidCallback onUpdate;
  final bool useGettoni;

  const _AttendanceTile({
    required this.attendance, required this.isAdmin,
    required this.matchId, required this.onUpdate,
    this.useGettoni = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isAdmin && attendance.haGiocato
            ? () => _showStatsDialog(context)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _avatarColor(),
                    radius: 20,
                    child: Text(
                      (attendance.soprannome ?? attendance.nomeGiocatore)
                          .substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attendance.soprannome ?? attendance.nomeGiocatore,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (useGettoni) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.toll, size: 13,
                                color: attendance.gettoniRimanenti > 0
                                  ? Colors.green.shade600 : Colors.red.shade600),
                              const SizedBox(width: 3),
                              Text('${attendance.gettoniRimanenti} gettoni',
                                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                              if (attendance.gettoneConsumato) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.check_circle, size: 13,
                                  color: Colors.green.shade600),
                                Text(' consumato',
                                  style: TextStyle(fontSize: 10, color: Colors.green.shade600)),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isAdmin) ...[
                    _toggleChip(context, 'Presente', attendance.presente,
                      Colors.green, () async {
                        await context.read<AttendanceProvider>().updateAttendance(
                          matchId, attendance.playerId,
                          presente: !attendance.presente);
                        onUpdate();
                      }),
                    const SizedBox(width: 6),
                    _toggleChip(context, 'Giocato', attendance.haGiocato,
                      Colors.blue, attendance.presente ? () async {
                        await context.read<AttendanceProvider>().updateAttendance(
                          matchId, attendance.playerId,
                          haGiocato: !attendance.haGiocato);
                        onUpdate();
                      } : null),
                  ] else ...[
                    if (attendance.presente)
                      _statusChip('Presente', Colors.green),
                    if (attendance.haGiocato) ...[
                      const SizedBox(width: 4),
                      _statusChip('Giocato', Colors.blue),
                    ],
                  ],
                ],
              ),
              // Stats row - mostra se ha statistiche
              if (attendance.hasStats) ...[
                const SizedBox(height: 8),
                _buildStatsRow(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleChip(BuildContext context, String label, bool active,
      Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: onTap == null
            ? Colors.grey.shade400
            : active ? color : Colors.grey.shade600,
        )),
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stats = <Widget>[];

    if ((attendance.minutiGiocati ?? 0) > 0) {
      stats.add(_statBadge(Icons.timer_outlined, '${attendance.minutiGiocati}\'',
        cs.primary));
    }
    if ((attendance.goal ?? 0) > 0) {
      stats.add(_statBadge(Icons.sports_soccer, '${attendance.goal}',
        Colors.green.shade700));
    }
    if ((attendance.assist ?? 0) > 0) {
      stats.add(_statBadge(Icons.handshake_outlined, '${attendance.assist}',
        Colors.purple.shade600));
    }
    if ((attendance.autogoal ?? 0) > 0) {
      stats.add(_statBadge(Icons.sports_soccer, '${attendance.autogoal} AG',
        Colors.red.shade600));
    }
    if ((attendance.ammonizioni ?? 0) > 0) {
      stats.add(_statBadge(Icons.square, '${attendance.ammonizioni}',
        Colors.amber.shade700));
    }
    if ((attendance.espulsioni ?? 0) > 0) {
      stats.add(_statBadge(Icons.square, '${attendance.espulsioni}',
        Colors.red.shade700));
    }
    if ((attendance.goalSubiti ?? 0) > 0) {
      stats.add(_statBadge(Icons.shield_outlined, '${attendance.goalSubiti} GS',
        Colors.orange.shade700));
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: stats,
    );
  }

  Widget _statBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: color)),
        ],
      ),
    );
  }

  Color _avatarColor() {
    if (attendance.haGiocato) return Colors.blue;
    if (attendance.presente) return Colors.green;
    return Colors.grey;
  }

  void _showStatsDialog(BuildContext context) {
    final minutiCtrl = TextEditingController(
      text: '${attendance.minutiGiocati ?? ''}');
    final goalCtrl = TextEditingController(
      text: '${attendance.goal ?? ''}');
    final assistCtrl = TextEditingController(
      text: '${attendance.assist ?? ''}');
    final autogoalCtrl = TextEditingController(
      text: '${attendance.autogoal ?? ''}');
    final ammonizioniCtrl = TextEditingController(
      text: '${attendance.ammonizioni ?? ''}');
    final espulsioniCtrl = TextEditingController(
      text: '${attendance.espulsioni ?? ''}');
    final goalSubitiCtrl = TextEditingController(
      text: '${attendance.goalSubiti ?? ''}');

    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.bar_chart, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                attendance.soprannome ?? attendance.nomeGiocatore,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _statsField(minutiCtrl, 'Minuti giocati', Icons.timer_outlined,
                cs.primary),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _statsField(goalCtrl, 'Goal',
                    Icons.sports_soccer, Colors.green.shade700)),
                  const SizedBox(width: 10),
                  Expanded(child: _statsField(assistCtrl, 'Assist',
                    Icons.handshake_outlined, Colors.purple.shade600)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _statsField(autogoalCtrl, 'Autogoal',
                    Icons.sports_soccer, Colors.red.shade600)),
                  const SizedBox(width: 10),
                  Expanded(child: _statsField(goalSubitiCtrl, 'Goal subiti',
                    Icons.shield_outlined, Colors.orange.shade700)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _statsField(ammonizioniCtrl, 'Ammonizioni',
                    Icons.square, Colors.amber.shade700)),
                  const SizedBox(width: 10),
                  Expanded(child: _statsField(espulsioniCtrl, 'Espulsioni',
                    Icons.square, Colors.red.shade700)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Salva'),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AttendanceProvider>().updateAttendance(
                matchId, attendance.playerId,
                minutiGiocati: int.tryParse(minutiCtrl.text) ?? 0,
                goal: int.tryParse(goalCtrl.text) ?? 0,
                assist: int.tryParse(assistCtrl.text) ?? 0,
                autogoal: int.tryParse(autogoalCtrl.text) ?? 0,
                ammonizioni: int.tryParse(ammonizioniCtrl.text) ?? 0,
                espulsioni: int.tryParse(espulsioniCtrl.text) ?? 0,
                goalSubiti: int.tryParse(goalSubitiCtrl.text) ?? 0,
              );
              onUpdate();
            },
          ),
        ],
      ),
    );
  }

  Widget _statsField(TextEditingController ctrl, String label,
      IconData icon, Color color) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13),
        prefixIcon: Icon(icon, color: color, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 15),
    );
  }
}
