import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/convocations_provider.dart';
import '../providers/players_provider.dart';
import '../models/convocation_model.dart';
import '../core/constants/api_constants.dart';

class ConvocationsScreen extends StatefulWidget {
  final int matchId;
  const ConvocationsScreen({super.key, required this.matchId});

  @override
  State<ConvocationsScreen> createState() => _ConvocationsScreenState();
}

class _ConvocationsScreenState extends State<ConvocationsScreen> {
  Map<int, bool?> _availabilityMap = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    await Future.wait([
      context.read<ConvocationsProvider>().loadByMatch(widget.matchId),
      context.read<PlayersProvider>().loadPlayers(auth.teamId),
      _loadAvailability(),
    ]);
  }

  Future<void> _loadAvailability() async {
    try {
      final auth = context.read<AuthProvider>();
      final resp = await auth.apiClient.dio.get(
        ApiConstants.matchAvailability(widget.matchId),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        final List list = resp.data['data'] ?? [];
        final map = <int, bool?>{};
        for (final item in list) {
          map[item['playerId'] as int] = item['disponibile'] as bool?;
        }
        if (mounted) {
          setState(() => _availabilityMap = map);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Convocazioni'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Consumer<ConvocationsProvider>(
          builder: (context, convProv, _) {
            if (!convProv.hasLoaded) {
              return const Center(child: CircularProgressIndicator());
            }
            final convocations = convProv.convocations;
            if (convocations.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 64,
                      color: cs.onSurfaceVariant.withOpacity(0.4)),
                    const SizedBox(height: 16),
                    Text('Nessuna convocazione',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                    if (auth.isAdmin) ...[
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => _showSendConvocationsDialog(context),
                        icon: const Icon(Icons.send),
                        label: const Text('Invia Convocazioni'),
                      ),
                    ],
                  ],
                ),
              );
            }

            // Raggruppa per disponibilità
            final disponibili = <ConvocationModel>[];
            final nonVotato = <ConvocationModel>[];
            final nonDisponibili = <ConvocationModel>[];

            for (final c in convocations) {
              final avail = _availabilityMap[c.playerId];
              if (avail == true) {
                disponibili.add(c);
              } else if (avail == false) {
                nonDisponibili.add(c);
              } else {
                nonVotato.add(c);
              }
            }

            // Ordina all'interno di ogni gruppo per stato convocazione
            int statusOrder(ConvocationModel c) {
              if (c.isConfermato) return 0;
              if (c.isInAttesa) return 1;
              return 2;
            }
            disponibili.sort((a, b) => statusOrder(a).compareTo(statusOrder(b)));
            nonVotato.sort((a, b) => statusOrder(a).compareTo(statusOrder(b)));
            nonDisponibili.sort((a, b) => statusOrder(a).compareTo(statusOrder(b)));

            final totConf = convocations.where((c) => c.isConfermato).length;
            final totAtt = convocations.where((c) => c.isInAttesa).length;
            final totNon = convocations.where((c) => c.isNonDisponibile).length;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Riepilogo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildCounter(context, totConf.toString(), 'Confermati',
                        Colors.green),
                      _buildCounter(context, totAtt.toString(), 'In attesa',
                        Colors.orange),
                      _buildCounter(context, totNon.toString(), 'Non disp.',
                        Colors.red),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (auth.isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: FilledButton.icon(
                      onPressed: () => _showSendConvocationsDialog(context),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Aggiungi Convocati'),
                    ),
                  ),

                // Sezione Disponibili
                if (disponibili.isNotEmpty) ...[
                  _sectionHeader(context, 'Disponibili (${disponibili.length})',
                    Icons.thumb_up_outlined, Colors.green),
                  ...disponibili.map((c) => _ConvocationTile(
                    convocation: c,
                    isAdmin: auth.isAdmin,
                    onRespond: _loadData,
                    availabilityStatus: true,
                  )),
                  const SizedBox(height: 12),
                ],

                // Sezione Non hanno votato
                if (nonVotato.isNotEmpty) ...[
                  _sectionHeader(context, 'Non hanno votato (${nonVotato.length})',
                    Icons.help_outline, Colors.orange),
                  ...nonVotato.map((c) => _ConvocationTile(
                    convocation: c,
                    isAdmin: auth.isAdmin,
                    onRespond: _loadData,
                    availabilityStatus: null,
                  )),
                  const SizedBox(height: 12),
                ],

                // Sezione Non disponibili
                if (nonDisponibili.isNotEmpty) ...[
                  _sectionHeader(context, 'Non disponibili (${nonDisponibili.length})',
                    Icons.thumb_down_outlined, Colors.red),
                  ...nonDisponibili.map((c) => _ConvocationTile(
                    convocation: c,
                    isAdmin: auth.isAdmin,
                    onRespond: _loadData,
                    availabilityStatus: false,
                  )),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCounter(BuildContext context, String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(
          fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(
          fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String title, IconData icon, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold, color: cs.onSurface)),
        ],
      ),
    );
  }

  void _showSendConvocationsDialog(BuildContext context) {
    final players = context.read<PlayersProvider>().players;
    final existing = context.read<ConvocationsProvider>().convocations
        .map((c) => c.playerId).toSet();
    final available = players.where((p) => !existing.contains(p.id)).toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tutti i giocatori sono gia\' convocati')));
      return;
    }

    // Ordina per disponibilità: disponibili prima, poi non votato, poi non disponibili
    available.sort((a, b) {
      final aAvail = _availabilityMap[a.id];
      final bAvail = _availabilityMap[b.id];
      int order(bool? v) => v == true ? 0 : v == null ? 1 : 2;
      return order(aAvail).compareTo(order(bAvail));
    });

    final selected = <int>{};
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Convoca Giocatori'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: available.map((p) {
                final avail = _availabilityMap[p.id];
                final availIcon = avail == true
                    ? Icon(Icons.thumb_up, size: 16, color: Colors.green.shade600)
                    : avail == false
                        ? Icon(Icons.thumb_down, size: 16, color: Colors.red.shade600)
                        : Icon(Icons.help_outline, size: 16,
                            color: Colors.orange.shade600);
                final availLabel = avail == true
                    ? 'Disponibile'
                    : avail == false
                        ? 'Non disponibile'
                        : 'Non votato';
                return CheckboxListTile(
                  title: Row(
                    children: [
                      Expanded(child: Text(p.displayName)),
                      availIcon,
                    ],
                  ),
                  subtitle: Row(
                    children: [
                      Text('Gettoni: ${p.gettoniRimanenti}'),
                      const SizedBox(width: 8),
                      Text('· $availLabel',
                        style: TextStyle(fontSize: 12,
                          color: cs.onSurfaceVariant)),
                    ],
                  ),
                  value: selected.contains(p.id),
                  onChanged: (val) {
                    setDialogState(() {
                      if (val == true) selected.add(p.id);
                      else selected.remove(p.id);
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: selected.isEmpty ? null : () async {
                Navigator.pop(ctx);
                await context.read<ConvocationsProvider>()
                    .sendConvocations(widget.matchId, selected.toList());
                if (mounted) _loadData();
              },
              child: Text('Convoca (${selected.length})'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConvocationTile extends StatelessWidget {
  final ConvocationModel convocation;
  final bool isAdmin;
  final VoidCallback onRespond;
  final bool? availabilityStatus;

  const _ConvocationTile({
    required this.convocation,
    required this.isAdmin,
    required this.onRespond,
    required this.availabilityStatus,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              backgroundColor: _statusColor().withOpacity(0.15),
              child: Icon(_statusIcon(), color: _statusColor(), size: 20),
            ),
            // Badge disponibilità
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                  color: cs.surface,
                  shape: BoxShape.circle,
                ),
                child: Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    color: availabilityStatus == true
                        ? Colors.green.shade100
                        : availabilityStatus == false
                            ? Colors.red.shade100
                            : Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    availabilityStatus == true
                        ? Icons.thumb_up
                        : availabilityStatus == false
                            ? Icons.thumb_down
                            : Icons.help_outline,
                    size: 10,
                    color: availabilityStatus == true
                        ? Colors.green.shade700
                        : availabilityStatus == false
                            ? Colors.red.shade700
                            : Colors.orange.shade700,
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          convocation.soprannome ?? convocation.nomeGiocatore,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(_statusLabel(),
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        trailing: convocation.isInAttesa
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.check_circle,
                      color: Colors.green.shade600, size: 28),
                    tooltip: 'Conferma',
                    onPressed: () async {
                      await context.read<ConvocationsProvider>()
                          .respond(convocation.id, 'Confermato');
                      onRespond();
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.cancel,
                      color: Colors.red.shade600, size: 28),
                    tooltip: 'Non disponibile',
                    onPressed: () async {
                      await context.read<ConvocationsProvider>()
                          .respond(convocation.id, 'NonDisponibile');
                      onRespond();
                    },
                  ),
                ],
              )
            : Icon(_statusIcon(), color: _statusColor().withOpacity(0.5), size: 22),
      ),
    );
  }

  Color _statusColor() {
    if (convocation.isConfermato) return Colors.green;
    if (convocation.isNonDisponibile) return Colors.red;
    return Colors.orange;
  }

  IconData _statusIcon() {
    if (convocation.isConfermato) return Icons.check_circle_outline;
    if (convocation.isNonDisponibile) return Icons.cancel_outlined;
    return Icons.hourglass_empty;
  }

  String _statusLabel() {
    if (convocation.isConfermato) return 'Confermato';
    if (convocation.isNonDisponibile) return 'Non disponibile';
    return 'In attesa di risposta';
  }
}
