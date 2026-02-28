import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/auth_provider.dart';
import '../providers/matches_provider.dart';
import '../models/match_model.dart';
import '../core/constants/api_constants.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMatches());
  }

  Future<void> _loadMatches() async {
    final auth = context.read<AuthProvider>();
    if (auth.teamId > 0) {
      await context.read<MatchesProvider>().loadMatches(auth.teamId);
    }
  }

  List<MatchModel> _getEventsForDay(DateTime day, List<MatchModel> matches) {
    return matches.where((m) => isSameDay(m.data, day)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return Consumer<MatchesProvider>(
      builder: (context, matchProv, _) {
        if (!matchProv.hasLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        final matches = matchProv.matches;

        final selectedEvents = _selectedDay != null
            ? _getEventsForDay(_selectedDay!, matches) : <MatchModel>[];

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final prossime = matches
            .where((m) => !m.isConclusa && !m.data.isBefore(today))
            .toList()
          ..sort((a, b) => a.data.compareTo(b.data));

        // Lista partite da mostrare sotto il calendario
        final listaPartite = (_selectedDay != null && selectedEvents.isNotEmpty)
            ? selectedEvents
            : prossime;
        final titoloLista = (_selectedDay != null && selectedEvents.isNotEmpty)
            ? 'Partite del ${DateFormat('dd MMMM', 'it_IT').format(_selectedDay!)}'
            : 'Prossime partite (${prossime.length})';

        return ListView(
          children: [
            TableCalendar<MatchModel>(
              firstDay: DateTime(2024),
              lastDay: DateTime(2028),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              locale: 'it_IT',
              startingDayOfWeek: StartingDayOfWeek.monday,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: (day) => _getEventsForDay(day, matches),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  if (_selectedDay != null && isSameDay(_selectedDay!, selectedDay)) {
                    _selectedDay = null;
                  } else {
                    _selectedDay = selectedDay;
                  }
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() => _calendarFormat = format);
              },
              calendarStyle: CalendarStyle(
                markerDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const Divider(height: 1),
            if (listaPartite.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.event_busy, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Nessuna partita in programma'),
                  ],
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  titoloLista,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold),
                ),
              ),
              ...listaPartite.map((m) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _MatchCard(
                  match: m,
                  showDate: !(_selectedDay != null && selectedEvents.isNotEmpty),
                  isAdmin: auth.isAdmin,
                  onEdit: () => _showMatchDialog(context, matchToEdit: m),
                  onDelete: () => _confirmDelete(context, m),
                ),
              )),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _exportCalendar(context),
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: const Text('Esporta Calendario'),
                    ),
                  ),
                  if (auth.isAdmin) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _showMatchDialog(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Nuova Partita'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
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
        content: const Text('Calendario esportato! Importalo nella tua app calendario.'),
        action: SnackBarAction(
          label: 'Copia URL',
          onPressed: () {
            web.window.navigator.clipboard.writeText(url);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('URL copiato! Usa per abbonarti al calendario.')),
            );
          },
        ),
      ),
    );
  }

  void _showMatchDialog(BuildContext context, {MatchModel? matchToEdit}) {
    final isEdit = matchToEdit != null;
    final dataCtrl = TextEditingController(
      text: isEdit ? DateFormat('dd/MM/yyyy').format(matchToEdit.data) : '');
    final oraCtrl = TextEditingController(
      text: isEdit ? matchToEdit.ora : '21:00');
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
                  hintText: 'es. Real Madrid',
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
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
              bool success;
              if (isEdit) {
                success = await context.read<MatchesProvider>().updateMatch(
                  auth.teamId, matchToEdit.id, matchData);
              } else {
                success = await context.read<MatchesProvider>().createMatch(
                  auth.teamId, matchData);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isEdit ? 'Partita aggiornata!' : 'Partita creata!')));
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vuoi eliminare "${match.displayTitle}"?'),
            if (!match.isProgrammata) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Partita in stato "${match.stato}". '
                        'Convocazioni, presenze e statistiche verranno eliminati. '
                        'I gettoni consumati verranno restituiti.',
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              final success = await context.read<MatchesProvider>().deleteMatch(
                auth.teamId, match.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Partita eliminata')));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final MatchModel match;
  final bool showDate;
  final bool isAdmin;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const _MatchCard({
    required this.match, this.showDate = false,
    this.isAdmin = false, this.onEdit, this.onDelete,
  });

  Color _statusColor(BuildContext context) {
    switch (match.stato) {
      case 'Conclusa': return Colors.grey;
      case 'InCorso': return Colors.green;
      case 'ConvocazioniInviate': return Colors.orange;
      default: return Theme.of(context).colorScheme.primary;
    }
  }

  String _statusLabel() {
    switch (match.stato) {
      case 'Conclusa': return 'Conclusa';
      case 'InCorso': return 'In Corso';
      case 'ConvocazioniInviate': return 'Convocati';
      default: return 'Programmata';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: () => context.push('/match/${match.id}'),
        onLongPress: isAdmin ? () => _showActions(context) : null,
        leading: CircleAvatar(
          backgroundColor: _statusColor(context),
          foregroundColor: Colors.white,
          child: Text('G${match.numeroGiornata}'),
        ),
        title: Text(match.displayTitle),
        subtitle: Text(
          showDate
              ? '${DateFormat('EEE dd/MM', 'it_IT').format(match.data)} - ${match.ora}${match.luogo != null ? ' - ${match.luogo}' : ''}'
              : '${match.ora}${match.luogo != null ? ' - ${match.luogo}' : ''}',
        ),
        trailing: Chip(
          label: Text(_statusLabel(), style: const TextStyle(fontSize: 11)),
          backgroundColor: _statusColor(context).withOpacity(0.15),
          side: BorderSide.none,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Modifica'),
              onTap: () { Navigator.pop(ctx); onEdit?.call(); },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Elimina', style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(ctx); onDelete?.call(); },
            ),
          ],
        ),
      ),
    );
  }
}
