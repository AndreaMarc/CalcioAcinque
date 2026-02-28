import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/matches_provider.dart';
import '../providers/convocations_provider.dart';
import '../models/match_model.dart';
import '../core/constants/api_constants.dart';

class MatchDetailScreen extends StatefulWidget {
  final int matchId;
  const MatchDetailScreen({super.key, required this.matchId});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  MatchModel? _match;
  Map<String, dynamic>? _availabilityData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    await context.read<MatchesProvider>().loadMatches(auth.teamId);
    await context.read<ConvocationsProvider>().loadByMatch(widget.matchId);
    // Carica disponibilita
    try {
      final response = await auth.apiClient.dio.get(
        ApiConstants.matchAvailability(widget.matchId),
      );
      if (response.data['success'] == true) {
        setState(() => _availabilityData = response.data['data']);
      }
    } catch (_) {}

    if (mounted) {
      final matches = context.read<MatchesProvider>().matches;
      setState(() {
        _match = matches.where((m) => m.id == widget.matchId).firstOrNull;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (_match == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final match = _match!;
    return Scaffold(
      appBar: AppBar(
        title: Text(match.displayTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/calendar'),
        ),
        actions: [
          if (auth.isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Modifica',
              onPressed: () => _showEditDialog(context, match),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Elimina',
              onPressed: () => _confirmDelete(context, match),
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildInfoCard(context, match),
            const SizedBox(height: 16),
            if (_availabilityData != null) ...[
              _buildAvailabilitySection(context),
              const SizedBox(height: 16),
            ],
            _buildConvocationsSummary(context, match),
            const SizedBox(height: 16),
            if (auth.isAdmin) ...[
              _buildAdminActions(context, match),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, MatchModel match) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sports_soccer,
                  color: Theme.of(context).colorScheme.primary, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(match.displayTitle,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold)),
                      Text(_statusLabel(match.stato),
                        style: TextStyle(color: _statusColor(context, match.stato))),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _infoRow(Icons.calendar_today,
              DateFormat('EEEE dd MMMM yyyy', 'it_IT').format(match.data)),
            const SizedBox(height: 8),
            _infoRow(Icons.access_time, match.ora),
            if (match.luogo != null) ...[
              const SizedBox(height: 8),
              _infoRow(Icons.location_on, match.luogo!),
            ],
            if (match.note != null) ...[
              const SizedBox(height: 8),
              _infoRow(Icons.notes, match.note!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }

  Widget _buildAvailabilitySection(BuildContext context) {
    final data = _availabilityData!;
    final disponibili = data['disponibili'] as int? ?? 0;
    final nonDisponibili = data['nonDisponibili'] as int? ?? 0;
    final dettaglio = data['dettaglio'] as List? ?? [];

    final listDisponibili = dettaglio.where((d) => d['disponibile'] == true).toList();
    final listNonDisponibili = dettaglio.where((d) => d['disponibile'] != true).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.how_to_reg, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Disponibilita\'', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold)),
                const Spacer(),
                Chip(
                  label: Text('$disponibili si / $nonDisponibili no'),
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                ),
              ],
            ),
            if (listDisponibili.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Disponibili', style: TextStyle(
                fontWeight: FontWeight.w600, color: Colors.green.shade700, fontSize: 13)),
              const SizedBox(height: 4),
              ...listDisponibili.map((d) => _buildAvailabilityTile(d, true)),
            ],
            if (listNonDisponibili.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Non disponibili', style: TextStyle(
                fontWeight: FontWeight.w600, color: Colors.red.shade700, fontSize: 13)),
              const SizedBox(height: 4),
              ...listNonDisponibili.map((d) => _buildAvailabilityTile(d, false)),
            ],
            if (dettaglio.isEmpty) ...[
              const SizedBox(height: 12),
              const Text('Nessuno ha ancora dichiarato la propria disponibilita\'.',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityTile(dynamic d, bool disponibile) {
    final nome = d['soprannome'] ?? d['nomeGiocatore'] ?? '';
    final note = d['note'] as String?;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: disponibile ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
        child: Icon(
          disponibile ? Icons.check : Icons.close,
          size: 18,
          color: disponibile ? Colors.green : Colors.red,
        ),
      ),
      title: Text(nome, style: const TextStyle(fontSize: 14)),
      subtitle: note != null && note.isNotEmpty
        ? Text(note, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic))
        : null,
    );
  }

  Widget _buildConvocationsSummary(BuildContext context, MatchModel match) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Riepilogo', style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statCol('Convocati', '${match.totaleConvocati}', Colors.blue),
                _statCol('Confermati', '${match.totaleConfermati}', Colors.green),
                _statCol('Presenti', '${match.totalePresenti}', Colors.teal),
                _statCol('Giocato', '${match.totaleHannoGiocato}', Colors.purple),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/match/${match.id}/convocations'),
                    icon: const Icon(Icons.list),
                    label: const Text('Convocazioni'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => context.push('/match/${match.id}/day'),
                    icon: const Icon(Icons.sports),
                    label: const Text('Match Day'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildAdminActions(BuildContext context, MatchModel match) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Azioni Admin', style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (match.isProgrammata)
              FilledButton.icon(
                onPressed: () => _updateStato(context, match, 'ConvocazioniInviate'),
                icon: const Icon(Icons.send),
                label: const Text('Invia Convocazioni'),
              ),
            if (match.stato == 'ConvocazioniInviate') ...[
              FilledButton.icon(
                onPressed: () => _startMatch(context, match),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Inizia Partita'),
              ),
            ],
            if (match.stato == 'InCorso') ...[
              FilledButton.icon(
                onPressed: () => context.push('/match/${match.id}/live'),
                icon: const Icon(Icons.timer),
                label: const Text('Vai alla Partita Live'),
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _updateStato(context, match, 'Conclusa'),
                icon: const Icon(Icons.stop),
                label: const Text('Concludi Partita'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
            if (match.isConclusa) ...[
              FilledButton.icon(
                onPressed: () => context.push('/match/${match.id}/live'),
                icon: const Icon(Icons.edit),
                label: const Text('Modifica Statistiche'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startMatch(BuildContext context, MatchModel match) async {
    final auth = context.read<AuthProvider>();
    final success = await context.read<MatchesProvider>().updateStato(
      auth.teamId, match.id, 'InCorso');
    if (success && mounted) {
      context.push('/match/${match.id}/live');
    }
  }

  Future<void> _updateStato(BuildContext context, MatchModel match, String stato) async {
    final auth = context.read<AuthProvider>();
    final success = await context.read<MatchesProvider>().updateStato(
      auth.teamId, match.id, stato);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stato aggiornato a $stato')));
      _loadData();
    }
  }

  Color _statusColor(BuildContext context, String stato) {
    switch (stato) {
      case 'Conclusa': return Colors.grey;
      case 'InCorso': return Colors.green;
      case 'ConvocazioniInviate': return Colors.orange;
      default: return Theme.of(context).colorScheme.primary;
    }
  }

  String _statusLabel(String stato) {
    switch (stato) {
      case 'Conclusa': return 'Conclusa';
      case 'InCorso': return 'In Corso';
      case 'ConvocazioniInviate': return 'Convocazioni Inviate';
      default: return 'Programmata';
    }
  }

  void _showEditDialog(BuildContext context, MatchModel match) {
    final dataCtrl = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(match.data));
    final oraCtrl = TextEditingController(text: match.ora);
    final luogoCtrl = TextEditingController(text: match.luogo ?? '');
    final titoloCtrl = TextEditingController(text: match.titolo ?? '');
    final giornatCtrl = TextEditingController(text: match.numeroGiornata.toString());
    final noteCtrl = TextEditingController(text: match.note ?? '');
    DateTime? selectedDate = match.data;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifica Partita'),
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
              final success = await context.read<MatchesProvider>().updateMatch(
                auth.teamId, match.id, {
                  'data': selectedDate!.toIso8601String(),
                  'ora': oraCtrl.text,
                  'luogo': luogoCtrl.text.isEmpty ? null : luogoCtrl.text,
                  'titolo': titoloCtrl.text.isEmpty ? null : titoloCtrl.text,
                  'numeroGiornata': int.tryParse(giornatCtrl.text) ?? 1,
                  'note': noteCtrl.text.isEmpty ? null : noteCtrl.text,
                },
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Partita aggiornata!')));
                _loadData();
              }
            },
            child: const Text('Salva'),
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
                context.go('/calendar');
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
