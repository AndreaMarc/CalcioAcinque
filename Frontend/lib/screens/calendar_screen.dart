import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/matches_provider.dart';
import '../providers/theme_provider.dart';
import '../models/match_model.dart';
import '../core/constants/api_constants.dart';
import '../widgets/app_widgets.dart';
import '../widgets/season_picker.dart';
import '../providers/club_provider.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMatches());
  }

  Future<void> _loadMatches() async {
    final auth = context.read<AuthProvider>();
    if (auth.teamId > 0) {
      await context.read<MatchesProvider>().loadMatches(auth.teamId);
      if (mounted) await context.read<ClubProvider>().loadSeasons(auth.teamId);
    }
  }

  Future<void> _pickSeason() async {
    final auth = context.read<AuthProvider>();
    final matchProv = context.read<MatchesProvider>();
    final scelta = await showSeasonPicker(
      context,
      teamId: auth.teamId,
      selected: matchProv.seasonId,
    );
    if (scelta == null || !mounted) return;
    await matchProv.selectSeason(auth.teamId, scelta.seasonId);
    if (!mounted) return;

    // Il calendario e' fermo sul mese di oggi: su una stagione archiviata
    // mostrerebbe una griglia vuota, quindi si va sulla sua ultima partita.
    final partite = matchProv.matches;
    if (partite.isEmpty) return;
    final ultima = partite
        .map((m) => m.data)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final haPartiteNelMese = partite.any((m) =>
        m.data.year == _focusedMonth.year && m.data.month == _focusedMonth.month);
    if (!haPartiteNelMese) {
      setState(() => _focusedMonth = DateTime(ultima.year, ultima.month));
    }
  }

  void _shiftMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final initials = teamInitials(theme.teamName);

    return Consumer<MatchesProvider>(
      builder: (context, matchProv, _) {
        if (!matchProv.hasLoaded) {
          return Column(
            children: [
              AppTopBar(
                teamInitials: initials,
                title: 'Partite',
                subtitle: 'Caricamento',
              ),
              const Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          );
        }
        final matches = matchProv.matches;
        final seasons = context.watch<ClubProvider>().seasons;
        // Stagione chiusa: si guarda e non si tocca
        final archivio = matchProv.seasonId != null &&
            seasons.any((s) => s.id == matchProv.seasonId && s.chiusa);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final prossime = matches
            .where((m) => !m.isConclusa && !m.data.isBefore(today))
            .toList()
          ..sort((a, b) => a.data.compareTo(b.data));
        final passate = matches
            .where((m) => m.data.isBefore(today) || m.isConclusa)
            .toList()
          ..sort((a, b) => b.data.compareTo(a.data));

        return Column(
          children: [
            AppTopBar(
              teamInitials: initials,
              title: 'Partite',
              subtitle: '${seasonLabel(seasons, matchProv.seasonId)} · ${matches.length}',
              actions: [
                if (auth.puoGestireCampo && !archivio)
                  AppTopBar.iconAction(
                    context,
                    Icons.add,
                    () => _showMatchDialog(context),
                  ),
                if (seasons.length > 1)
                  AppTopBar.iconAction(context, Icons.event_repeat, _pickSeason),
                AppTopBar.iconAction(
                  context,
                  Icons.download_outlined,
                  () => _exportCalendar(context),
                ),
              ],
            ),
            if (archivio)
              SeasonArchiveBanner(
                label: seasonLabel(seasons, matchProv.seasonId),
                onTorna: () => matchProv.selectSeason(auth.teamId, null),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  _MonthHeader(
                    month: _focusedMonth,
                    matchCount: matches.where((m) =>
                            m.data.year == _focusedMonth.year &&
                            m.data.month == _focusedMonth.month).length,
                    onPrev: () => _shiftMonth(-1),
                    onNext: () => _shiftMonth(1),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _MonthGrid(
                      focusedMonth: _focusedMonth,
                      matches: matches,
                      today: today,
                    ),
                  ),
                  if (prossime.isNotEmpty) ...[
                    SectionHead(title: 'PROSSIME', more: '${prossime.length} partite'),
                    ...prossime.asMap().entries.map((e) {
                      final idx = e.key;
                      final m = e.value;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: _FixtureCard(
                          match: m,
                          isNext: idx == 0,
                          isAdmin: auth.puoGestireCampo,
                          onTap: () => context.push('/match/${m.id}'),
                          onEdit: () => _showMatchDialog(context, matchToEdit: m),
                          onDelete: () => _confirmDelete(context, m),
                        ),
                      );
                    }),
                  ],
                  if (passate.isNotEmpty) ...[
                    const SectionHead(title: 'PASSATE'),
                    ...passate.take(10).map((m) => Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: _PastCard(
                            match: m,
                            onTap: () => context.push('/match/${m.id}'),
                          ),
                        )),
                  ],
                  if (prossime.isEmpty && passate.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: Text('Nessuna partita in programma')),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _exportCalendar(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final url = '${ApiConstants.baseUrl}${ApiConstants.calendarIcs(auth.teamId)}';
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = 'partite.ics';
    anchor.click();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Calendario esportato!'),
        action: SnackBarAction(
          label: 'Copia URL',
          onPressed: () {
            web.window.navigator.clipboard.writeText(url);
          },
        ),
      ),
    );
  }

  void _showMatchDialog(BuildContext context, {MatchModel? matchToEdit}) {
    final isEdit = matchToEdit != null;
    final dataCtrl = TextEditingController(
        text: isEdit ? DateFormat('dd/MM/yyyy').format(matchToEdit.data) : '');
    final oraCtrl = TextEditingController(text: isEdit ? matchToEdit.ora : '21:00');
    final luogoCtrl = TextEditingController(text: matchToEdit?.luogo ?? '');
    final titoloCtrl = TextEditingController(text: matchToEdit?.titolo ?? '');
    final giornatCtrl = TextEditingController(
        text: isEdit ? matchToEdit.numeroGiornata.toString() : '');
    final noteCtrl = TextEditingController(text: matchToEdit?.note ?? '');
    DateTime? selectedDate = matchToEdit?.data;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Modifica Partita' : 'Nuova Partita'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: giornatCtrl,
                decoration: const InputDecoration(labelText: 'Numero Giornata'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titoloCtrl,
                decoration: const InputDecoration(
                  labelText: 'Avversario (opzionale)',
                  prefixIcon: Icon(Icons.shield_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dataCtrl,
                decoration: const InputDecoration(
                    labelText: 'Data', suffixIcon: Icon(Icons.calendar_today)),
                readOnly: true,
                onTap: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    selectedDate = date;
                    dataCtrl.text = DateFormat('dd/MM/yyyy').format(date);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: oraCtrl,
                decoration: const InputDecoration(labelText: 'Ora'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: luogoCtrl,
                decoration: const InputDecoration(labelText: 'Luogo'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Note (opzionale)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(
            onPressed: () async {
              if (selectedDate == null || giornatCtrl.text.isEmpty) return;
              final auth = context.read<AuthProvider>();
              final matchData = {
                'data': selectedDate!.toIso8601String(),
                'ora': oraCtrl.text,
                'luogo': luogoCtrl.text.isEmpty ? null : luogoCtrl.text,
                'titolo': titoloCtrl.text.isEmpty ? null : titoloCtrl.text,
                'numeroGiornata': int.tryParse(giornatCtrl.text) ?? 1,
                'note': noteCtrl.text.isEmpty ? null : noteCtrl.text,
              };
              final success = isEdit
                  ? await context.read<MatchesProvider>().updateMatch(
                      auth.teamId, matchToEdit.id, matchData)
                  : await context.read<MatchesProvider>().createMatch(
                      auth.teamId, matchData);
              if (ctx.mounted) Navigator.pop(ctx);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        isEdit ? 'Partita aggiornata!' : 'Partita creata!')));
              }
            },
            child: Text(isEdit ? 'Salva' : 'Crea'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, MatchModel match) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina Partita'),
        content: Text('Vuoi eliminare "${match.displayTitle}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              final success = await context
                  .read<MatchesProvider>()
                  .deleteMatch(auth.teamId, match.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Partita eliminata')));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppTokens.bad),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final int matchCount;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthHeader({
    required this.month,
    required this.matchCount,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    final cardColor = isDark ? AppTokens.darkCard : AppTokens.card;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMMM', 'it_IT').format(month).toUpperCase(),
                  style: GoogleFonts.bebasNeue(
                    fontSize: 40,
                    height: 1,
                    color: textColor,
                    letterSpacing: 0.02 * 40,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${month.year} · $matchCount partite',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    color: muteColor,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _nav(Icons.chevron_left, onPrev, cardColor, lineColor, textColor),
              const SizedBox(width: 6),
              _nav(Icons.chevron_right, onNext, cardColor, lineColor, textColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nav(IconData i, VoidCallback tap, Color bg, Color border, Color fg) {
    return InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(i, size: 18, color: fg),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final List<MatchModel> matches;
  final DateTime today;

  const _MonthGrid({
    required this.focusedMonth,
    required this.matches,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTokens.darkCard : AppTokens.card;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final faintColor = isDark
        ? AppTokens.darkTextMute.withOpacity(0.5)
        : AppTokens.textFaint;

    final first = DateTime(focusedMonth.year, focusedMonth.month, 1);
    // dayOfWeek: Mon=1..Sun=7 → we want Mon=0 offset
    final offset = first.weekday - 1;
    final daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final totalCells = 42;

    // Group matches by day in this month
    final byDay = <int, MatchModel>{};
    for (final m in matches) {
      if (m.data.year == focusedMonth.year &&
          m.data.month == focusedMonth.month) {
        byDay[m.data.day] = m;
      }
    }

    final now = DateTime.now();
    MatchModel? nextMatch;
    for (final m in matches
        .where((m) => !m.isConclusa && !m.data.isBefore(now))
        .toList()
      ..sort((a, b) => a.data.compareTo(b.data))) {
      if (m.data.year == focusedMonth.year &&
          m.data.month == focusedMonth.month) {
        nextMatch = m;
        break;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lineColor),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: ['L', 'M', 'M', 'G', 'V', 'S', 'D']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: faintColor,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            children: List.generate(totalCells, (i) {
              final d = i - offset + 1;
              final inMonth = d >= 1 && d <= daysInMonth;
              final dayMatch = inMonth ? byDay[d] : null;
              final isToday = inMonth &&
                  today.year == focusedMonth.year &&
                  today.month == focusedMonth.month &&
                  today.day == d;
              final isNext = dayMatch != null &&
                  nextMatch != null &&
                  nextMatch.id == dayMatch.id;
              final isPast = dayMatch != null &&
                  (dayMatch.isConclusa ||
                      DateTime(focusedMonth.year, focusedMonth.month, d)
                          .isBefore(today));

              Color bg;
              Color fg;
              if (isNext) {
                bg = AppTokens.ink;
                fg = Colors.white;
              } else if (isToday) {
                bg = isDark
                    ? AppTokens.brand.withOpacity(0.2)
                    : AppTokens.brandSoft;
                fg = isDark ? AppTokens.darkBrand : AppTokens.brandInk;
              } else {
                bg = Colors.transparent;
                fg = inMonth ? textColor : faintColor;
              }

              return AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (inMonth)
                        Text(
                          '$d',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            color: fg,
                            fontWeight: isNext || isToday
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      if (dayMatch != null && !isNext)
                        Positioned(
                          bottom: 4,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isPast
                                  ? faintColor
                                  : (isDark
                                      ? AppTokens.darkBrand
                                      : AppTokens.brand),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _FixtureCard extends StatelessWidget {
  final MatchModel match;
  final bool isNext;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _FixtureCard({
    required this.match,
    required this.isNext,
    required this.isAdmin,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTokens.darkCard : AppTokens.card;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    final stripBg = isNext
        ? AppTokens.ink
        : (isDark ? AppTokens.ink2 : AppTokens.paper);
    final stripFg = isNext ? Colors.white : textColor;

    final dayLabel =
        DateFormat('EEE', 'it_IT').format(match.data).toUpperCase();
    final dayNum = match.data.day;
    final monthLabel =
        DateFormat('MMM', 'it_IT').format(match.data).toUpperCase();

    final opponent = (match.titolo ?? '').isNotEmpty
        ? match.titolo!.toUpperCase()
        : 'PARTITA';

    return GestureDetector(
      onTap: onTap,
      onLongPress: isAdmin
          ? () {
              showModalBottomSheet(
                context: context,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text('Modifica'),
                        onTap: () {
                          Navigator.pop(ctx);
                          onEdit?.call();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete, color: AppTokens.bad),
                        title: const Text('Elimina',
                            style: TextStyle(color: AppTokens.bad)),
                        onTap: () {
                          Navigator.pop(ctx);
                          onDelete?.call();
                        },
                      ),
                    ],
                  ),
                ),
              );
            }
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: lineColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 78,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                color: stripBg,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dayLabel,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isNext ? AppTokens.brand : muteColor,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dayNum',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 34,
                        height: 0.9,
                        color: stripFg,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$monthLabel · ${match.ora}',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        color: isNext ? AppTokens.textOnInkMute : muteColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'GIORNATA ${match.numeroGiornata}',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: muteColor,
                              letterSpacing: 1,
                            ),
                          ),
                          if (isNext) ...[
                            const SizedBox(width: 6),
                            const AppChip(
                              text: 'NEXT',
                              variant: AppChipVariant.brand,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 1),
                              fontSize: 9,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'VS $opponent',
                        style: GoogleFonts.bebasNeue(
                          fontSize: 22,
                          letterSpacing: 0.02 * 22,
                          height: 1.05,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.place_outlined,
                              size: 12, color: muteColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              match.luogo?.isNotEmpty == true
                                  ? match.luogo!
                                  : 'Luogo da definire',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 12,
                                color: muteColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PastCard extends StatelessWidget {
  final MatchModel match;
  final VoidCallback onTap;
  const _PastCard({required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTokens.darkCard : AppTokens.card;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    return Opacity(
      opacity: 0.75,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: lineColor),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 54,
                child: Text(
                  DateFormat('dd/MM').format(match.data),
                  style: GoogleFonts.bebasNeue(fontSize: 22, color: muteColor),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.displayTitle,
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${match.luogo?.isNotEmpty == true ? '${match.luogo} · ' : ''}${match.ora}',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        color: muteColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (match.isConclusa)
                const AppChip(
                  text: 'Conclusa',
                  variant: AppChipVariant.neutral,
                  fontSize: 10,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
