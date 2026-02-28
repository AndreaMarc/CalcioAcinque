import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/convocations_provider.dart';
import '../providers/announcements_provider.dart';
import '../models/dashboard_model.dart';
import '../core/constants/api_constants.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _availabilityData;
  bool _availabilityLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    if (auth.teamId > 0) {
      context.read<DashboardProvider>().loadDashboard(auth.teamId);
      context.read<ConvocationsProvider>().loadPending(auth.playerId);
      context.read<AnnouncementsProvider>().loadAnnouncements(auth.teamId);
      _loadAvailability();
    }
  }

  Future<void> _loadAvailability() async {
    setState(() => _availabilityLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final response = await auth.apiClient.dio.get(
        ApiConstants.nextAvailability(auth.teamId),
      );
      if (response.data['success'] == true && response.data['data'] != null) {
        setState(() => _availabilityData = response.data['data']);
      } else {
        setState(() => _availabilityData = null);
      }
    } catch (_) {
      setState(() => _availabilityData = null);
    }
    setState(() => _availabilityLoading = false);
  }

  Future<void> _setAvailability(int matchId, bool disponibile) async {
    try {
      final auth = context.read<AuthProvider>();
      await auth.apiClient.dio.post(
        ApiConstants.matchAvailability(matchId),
        data: {'disponibile': disponibile},
      );
      if (mounted) {
        _loadAvailability();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(disponibile
            ? 'Sei disponibile!'
            : 'Non disponibile segnalato')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nel salvare la disponibilita\'')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: Consumer2<DashboardProvider, ConvocationsProvider>(
        builder: (context, dash, conv, _) {
          if (dash.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = dash.dashboard;
          if (d == null) {
            return const Center(child: Text('Caricamento...'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (conv.pending.isNotEmpty) ...[
                _buildPendingConvocations(context, conv),
                const SizedBox(height: 16),
              ],
              if (!_availabilityLoading && _availabilityData != null) ...[
                _buildAvailabilityCard(context),
                const SizedBox(height: 16),
              ],
              if (d.prossimaPartita != null) ...[
                _buildNextMatch(context, d.prossimaPartita!),
                const SizedBox(height: 16),
              ],
              if (d.useGettoni) ...[
                _buildTokenCard(context, d),
                const SizedBox(height: 16),
              ],
              _buildStatsCard(context, d),
              if (d.useGettoni) ...[
                const SizedBox(height: 16),
                _buildTokenRanking(context, d),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildAvailabilityCard(BuildContext context) {
    final data = _availabilityData!;
    final matchId = data['matchId'] as int;
    final giornata = data['numeroGiornata'] as int? ?? 0;
    final dataPartita = data['dataPartita'] != null
        ? DateTime.tryParse(data['dataPartita'])
        : null;
    final oraPartita = data['oraPartita'] ?? '';
    final mia = data['miaDisponibilita']; // "disponibile", "nonDisponibile", null
    final disponibili = data['disponibili'] as int? ?? 0;
    final nonDisponibili = data['nonDisponibili'] as int? ?? 0;
    final totale = data['totale'] as int? ?? 0;

    Color cardColor;
    IconData cardIcon;
    String cardLabel;

    if (mia == 'disponibile') {
      cardColor = Colors.green;
      cardIcon = Icons.check_circle;
      cardLabel = 'Sei DISPONIBILE';
    } else if (mia == 'nonDisponibile') {
      cardColor = Colors.red;
      cardIcon = Icons.cancel;
      cardLabel = 'NON disponibile';
    } else {
      cardColor = Colors.orange;
      cardIcon = Icons.help_outline;
      cardLabel = 'Non hai ancora risposto';
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header colorato
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: cardColor.withOpacity(0.15),
            child: Row(
              children: [
                Icon(Icons.how_to_reg, color: cardColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Disponibilita\' - Giornata $giornata',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold),
                      ),
                      if (dataPartita != null)
                        Text(
                          '${DateFormat('EEEE dd MMMM', 'it_IT').format(dataPartita)} - $oraPartita',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Stato attuale
                Row(
                  children: [
                    Icon(cardIcon, color: cardColor, size: 28),
                    const SizedBox(width: 8),
                    Text(cardLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: cardColor,
                      )),
                  ],
                ),
                const SizedBox(height: 12),
                // Contatori
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _availStat(context, '$disponibili', 'Disponibili', Colors.green),
                    _availStat(context, '$nonDisponibili', 'Non disp.', Colors.red),
                    _availStat(context, '$totale', 'Risposte', Theme.of(context).colorScheme.primary),
                  ],
                ),
                const SizedBox(height: 16),
                // Bottoni azione
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: mia == 'disponibile'
                            ? null
                            : () => _setAvailability(matchId, true),
                        icon: const Icon(Icons.thumb_up),
                        label: const Text('Ci sono!'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          disabledBackgroundColor: Colors.green.withOpacity(0.3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: mia == 'nonDisponibile'
                            ? null
                            : () => _setAvailability(matchId, false),
                        icon: const Icon(Icons.thumb_down),
                        label: const Text('Non ci sono'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _availStat(BuildContext context, String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildPendingConvocations(BuildContext context, ConvocationsProvider conv) {
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active,
                  color: Theme.of(context).colorScheme.tertiary),
                const SizedBox(width: 8),
                Text('Convocazioni in attesa',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...conv.pending.map((c) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Giornata ${c.numeroGiornata ?? '-'}'),
              subtitle: Text(c.dataPartita != null
                  ? '${DateFormat('dd/MM/yyyy').format(c.dataPartita!)} - ${c.oraPartita ?? ''}'
                  : 'Data da definire'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.tonal(
                    onPressed: () async {
                      await conv.respond(c.id, 'Confermato');
                      if (context.mounted) _loadData();
                    },
                    child: const Text('Confermo'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () async {
                      await conv.respond(c.id, 'NonDisponibile');
                      if (context.mounted) _loadData();
                    },
                    child: const Text('No'),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildNextMatch(BuildContext context, MatchSummary match) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/match/${match.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sports_soccer,
                    color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Prossima Partita',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Text(match.displayTitle,
                style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              _buildConvocazioneChip(match.miaConvocazione),
              const SizedBox(height: 4),
              Text(
                '${DateFormat('EEEE dd MMMM', 'it_IT').format(match.data)} - ${match.ora}',
                style: Theme.of(context).textTheme.bodyLarge),
              if (match.luogo != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16),
                    const SizedBox(width: 4),
                    Text(match.luogo!),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _miniStat('Confermati', '${match.confermati}', Colors.green),
                  _miniStat('In attesa', '${match.inAttesa}', Colors.orange),
                  _miniStat('Non disp.', '${match.nonDisponibili}', Colors.red),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConvocazioneChip(String? stato) {
    final IconData icon;
    final String label;
    final Color bg;
    final Color fg;
    switch (stato) {
      case 'Confermato':
        icon = Icons.check_circle;
        label = 'Convocato - Confermato';
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        break;
      case 'InAttesa':
        icon = Icons.hourglass_top;
        label = 'In attesa di risposta';
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade700;
        break;
      case 'NonDisponibile':
        icon = Icons.cancel;
        label = 'Non disponibile';
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        break;
      default:
        icon = Icons.person_off;
        label = 'Non convocato';
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade600;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(
          fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildTokenCard(BuildContext context, DashboardModel d) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.toll, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('I tuoi Gettoni',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${d.gettoniRimanenti}',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: d.gettoniRimanenti > 0
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
                Text(
                  ' / ${d.gettoniTotali}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            if (d.gettoniTotali > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(
                  value: d.gettoniRimanenti / d.gettoniTotali,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, DashboardModel d) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statColumn(context, '${d.partiteGiocate}', 'Giocate'),
            _statColumn(context, '${d.partiteTotali}', 'Totali'),
            _statColumn(context, '${d.convocazioniInAttesa}', 'In attesa'),
          ],
        ),
      ),
    );
  }

  Widget _statColumn(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildTokenRanking(BuildContext context, DashboardModel d) {
    if (d.classificaGettoni.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Classifica Gettoni',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...d.classificaGettoni.map((p) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: p.gettoniRimanenti > 0
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.errorContainer,
                child: Text('${p.gettoniRimanenti}'),
              ),
              title: Text(p.soprannome ?? p.nome),
              subtitle: Text('${p.gettoniRimanenti} / ${p.gettoniTotali} gettoni'),
            )),
          ],
        ),
      ),
    );
  }
}
