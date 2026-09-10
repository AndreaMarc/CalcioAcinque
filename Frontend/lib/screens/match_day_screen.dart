import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/theme_provider.dart';
import '../models/attendance_model.dart';
import '../widgets/app_widgets.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paper = isDark ? AppTokens.darkPaper : AppTokens.paper;
    final auth = context.watch<AuthProvider>();
    final useGettoni = context.watch<DashboardProvider>().useGettoni;
    final theme = context.watch<ThemeProvider>();
    final initials = teamInitials(theme.teamName, fallback: 'CA');

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              teamInitials: initials,
              title: 'Match Day',
              subtitle: 'Presenze e statistiche',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: Consumer<AttendanceProvider>(
                  builder: (context, attProv, _) {
                    if (!attProv.hasLoaded) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final attendances = attProv.attendances;
                    if (attendances.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          Center(
                            child: Text(
                              'Nessun giocatore convocato',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 14,
                                color: isDark
                                    ? AppTokens.darkTextMute
                                    : AppTokens.textMute,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    final presenti =
                        attendances.where((a) => a.presente).length;
                    final giocato =
                        attendances.where((a) => a.haGiocato).length;
                    final totalGoal = attendances.fold<int>(
                        0, (s, a) => s + (a.goal ?? 0));
                    final totalAssist = attendances.fold<int>(
                        0, (s, a) => s + (a.assist ?? 0));

                    return ListView(
                      padding: const EdgeInsets.only(bottom: 20),
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 4, 16, 14),
                          child: _MatchDayHero(
                            convocati: attendances.length,
                            presenti: presenti,
                            giocato: giocato,
                            goal: totalGoal,
                            assist: totalAssist,
                          ),
                        ),
                        SectionHead(
                          title: 'GIOCATORI',
                          more: auth.puoGestireCampo ? 'Tocca per stats' : null,
                        ),
                        ...attendances.map((att) => Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: _AttRow(
                                attendance: att,
                                isAdmin: auth.puoGestireCampo,
                                matchId: widget.matchId,
                                useGettoni: useGettoni,
                                onUpdate: _loadData,
                              ),
                            )),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchDayHero extends StatelessWidget {
  final int convocati;
  final int presenti;
  final int giocato;
  final int goal;
  final int assist;

  const _MatchDayHero({
    required this.convocati,
    required this.presenti,
    required this.giocato,
    required this.goal,
    required this.assist,
  });

  @override
  Widget build(BuildContext context) {
    return CardInk(
      padding: const EdgeInsets.all(22),
      withPitch: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MATCH DAY',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.54,
              color: AppTokens.brand,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$giocato',
                style: GoogleFonts.bebasNeue(
                  fontSize: 64,
                  height: 0.85,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '/ $convocati convocati',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _mini('$presenti', 'PRESENTI', AppTokens.brand),
                ),
                _divider(),
                Expanded(
                  child: _mini('$goal', 'GOL', Colors.white),
                ),
                _divider(),
                Expanded(
                  child: _mini('$assist', 'ASSIST', Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 32, color: Colors.white.withOpacity(0.08));

  Widget _mini(String v, String l, Color c) {
    return Column(
      children: [
        Text(v, style: GoogleFonts.bebasNeue(fontSize: 26, color: c)),
        Text(
          l,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTokens.textOnInkMute,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _AttRow extends StatelessWidget {
  final AttendanceModel attendance;
  final bool isAdmin;
  final int matchId;
  final bool useGettoni;
  final VoidCallback onUpdate;

  const _AttRow({
    required this.attendance,
    required this.isAdmin,
    required this.matchId,
    required this.useGettoni,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTokens.darkCard : AppTokens.card;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    final name = attendance.soprannome ?? attendance.nomeGiocatore;

    return InkWell(
      onTap: isAdmin && attendance.haGiocato
          ? () => _showStatsDialog(context)
          : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: attendance.haGiocato
                ? (isDark ? AppTokens.darkBrand : AppTokens.brand)
                    .withOpacity(0.3)
                : lineColor,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                JerseyNumber(
                  size: 44,
                  fontSize: 20,
                  bg: attendance.haGiocato
                      ? (isDark ? AppTokens.darkBrand : AppTokens.brand)
                      : AppTokens.ink,
                  fg: attendance.haGiocato
                      ? AppTokens.brandInk
                      : (isDark ? AppTokens.darkBrand : AppTokens.brand),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      if (useGettoni)
                        Text(
                          attendance.gettoneConsumato
                              ? 'Gettone consumato · ${attendance.gettoniRimanenti} rim.'
                              : '${attendance.gettoniRimanenti} gettoni',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            color: muteColor,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isAdmin) ...[
                  _toggle(
                    context,
                    'PRES',
                    attendance.presente,
                    AppTokens.ok,
                    onTap: () async {
                      await context
                          .read<AttendanceProvider>()
                          .updateAttendance(matchId, attendance.playerId,
                              presente: !attendance.presente);
                      onUpdate();
                    },
                  ),
                  const SizedBox(width: 6),
                  _toggle(
                    context,
                    'CAMPO',
                    attendance.haGiocato,
                    isDark ? AppTokens.darkBrand : AppTokens.brand,
                    onTap: attendance.presente
                        ? () async {
                            await context
                                .read<AttendanceProvider>()
                                .updateAttendance(
                                    matchId, attendance.playerId,
                                    haGiocato: !attendance.haGiocato);
                            onUpdate();
                          }
                        : null,
                  ),
                ] else ...[
                  if (attendance.presente)
                    const AppChip(
                      text: 'PRESENTE',
                      variant: AppChipVariant.ok,
                      fontSize: 9,
                    ),
                  if (attendance.haGiocato) ...[
                    const SizedBox(width: 4),
                    const AppChip(
                      text: 'CAMPO',
                      variant: AppChipVariant.brand,
                      fontSize: 9,
                    ),
                  ],
                ],
              ],
            ),
            if (attendance.hasStats) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if ((attendance.minutiGiocati ?? 0) > 0)
                      _stat(
                          Icons.timer_outlined,
                          '${attendance.minutiGiocati}\'',
                          isDark ? Colors.white : AppTokens.ink),
                    if ((attendance.goal ?? 0) > 0)
                      _stat(Icons.sports_soccer, '${attendance.goal}',
                          AppTokens.ok),
                    if ((attendance.assist ?? 0) > 0)
                      _stat(Icons.handshake_outlined, '${attendance.assist}',
                          AppTokens.info),
                    if ((attendance.ammonizioni ?? 0) > 0)
                      _stat(Icons.square, '${attendance.ammonizioni}',
                          AppTokens.warn),
                    if ((attendance.espulsioni ?? 0) > 0)
                      _stat(Icons.square_outlined,
                          '${attendance.espulsioni}', AppTokens.bad),
                    if ((attendance.goalSubiti ?? 0) > 0)
                      _stat(Icons.shield_outlined,
                          '${attendance.goalSubiti} GS', AppTokens.bad),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _toggle(BuildContext context, String label, bool active, Color color,
      {VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: onTap == null
                ? lineColor.withOpacity(0.5)
                : active
                    ? color
                    : lineColor,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: onTap == null
                ? lineColor
                : active
                    ? color
                    : (isDark ? AppTokens.darkTextMute : AppTokens.textMute),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showStatsDialog(BuildContext context) {
    final minutiCtrl =
        TextEditingController(text: '${attendance.minutiGiocati ?? ''}');
    final goalCtrl = TextEditingController(text: '${attendance.goal ?? ''}');
    final assistCtrl =
        TextEditingController(text: '${attendance.assist ?? ''}');
    final autogoalCtrl =
        TextEditingController(text: '${attendance.autogoal ?? ''}');
    final ammonizioniCtrl =
        TextEditingController(text: '${attendance.ammonizioni ?? ''}');
    final espulsioniCtrl =
        TextEditingController(text: '${attendance.espulsioni ?? ''}');
    final goalSubitiCtrl =
        TextEditingController(text: '${attendance.goalSubiti ?? ''}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(attendance.soprannome ?? attendance.nomeGiocatore),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _f(minutiCtrl, 'Minuti', Icons.timer_outlined),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _f(goalCtrl, 'Gol', Icons.sports_soccer)),
                const SizedBox(width: 10),
                Expanded(
                    child: _f(assistCtrl, 'Assist', Icons.handshake_outlined)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _f(autogoalCtrl, 'Autogol', Icons.sports_soccer)),
                const SizedBox(width: 10),
                Expanded(
                    child: _f(
                        goalSubitiCtrl, 'Gol subiti', Icons.shield_outlined)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _f(ammonizioniCtrl, 'Amm.', Icons.square)),
                const SizedBox(width: 10),
                Expanded(
                    child: _f(espulsioniCtrl, 'Esp.', Icons.square_outlined)),
              ]),
            ],
          ),
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
                  .updateAttendance(matchId, attendance.playerId,
                      minutiGiocati: int.tryParse(minutiCtrl.text) ?? 0,
                      goal: int.tryParse(goalCtrl.text) ?? 0,
                      assist: int.tryParse(assistCtrl.text) ?? 0,
                      autogoal: int.tryParse(autogoalCtrl.text) ?? 0,
                      ammonizioni: int.tryParse(ammonizioniCtrl.text) ?? 0,
                      espulsioni: int.tryParse(espulsioniCtrl.text) ?? 0,
                      goalSubiti: int.tryParse(goalSubitiCtrl.text) ?? 0);
              onUpdate();
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  Widget _f(TextEditingController c, String label, IconData icon) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        isDense: true,
      ),
    );
  }
}
