import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/players_provider.dart';
import '../providers/tokens_provider.dart';
import '../providers/dashboard_provider.dart';
import '../models/player_model.dart';

class PlayerDetailScreen extends StatefulWidget {
  final int playerId;
  const PlayerDetailScreen({super.key, required this.playerId});

  @override
  State<PlayerDetailScreen> createState() => _PlayerDetailScreenState();
}

class _PlayerDetailScreenState extends State<PlayerDetailScreen> {
  PlayerModel? _player;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    await context.read<PlayersProvider>().loadPlayers(auth.teamId);
    await context.read<TokensProvider>().loadPlayerTokens(widget.playerId);
    if (mounted) {
      final players = context.read<PlayersProvider>().players;
      setState(() {
        _player = players.where((p) => p.id == widget.playerId).firstOrNull;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final useGettoni = context.watch<DashboardProvider>().useGettoni;

    if (_player == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final player = _player!;

    return Scaffold(
      appBar: AppBar(
        title: Text(player.displayName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/players'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildInfoCard(context, player),
            if (useGettoni) ...[
              const SizedBox(height: 16),
              _buildTokenCard(context, player),
              const SizedBox(height: 16),
              if (auth.isAdmin) ...[
                _buildAdminActions(context, player),
                const SizedBox(height: 16),
              ],
              _buildTransactionsCard(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, PlayerModel player) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                player.displayName.substring(0, 1).toUpperCase(),
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary),
              ),
            ),
            const SizedBox(height: 12),
            Text(player.nome, style: Theme.of(context).textTheme.titleLarge),
            if (player.soprannome != null)
              Text('"${player.soprannome}"',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic)),
            if (player.telefono != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phone, size: 16),
                  const SizedBox(width: 4),
                  Text(player.telefono!),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (player.isAdmin)
                  Chip(label: const Text('Admin'),
                    avatar: const Icon(Icons.admin_panel_settings, size: 16),
                    side: BorderSide.none),
                if (player.iscrizionePagata)
                  const Chip(label: Text('Iscrizione OK'), side: BorderSide.none,
                    avatar: Icon(Icons.check_circle, size: 16, color: Colors.green)),
                if (player.tesseramentoPagato)
                  const Chip(label: Text('Tesseramento OK'), side: BorderSide.none,
                    avatar: Icon(Icons.check_circle, size: 16, color: Colors.green)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenCard(BuildContext context, PlayerModel player) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gettoni', style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _tokenStat('Totali', '${player.gettoniTotali}',
                  Theme.of(context).colorScheme.primary),
                _tokenStat('Consumati', '${player.gettoniConsumati}', Colors.orange),
                _tokenStat('Rimanenti', '${player.gettoniRimanenti}',
                  player.gettoniEsauriti ? Colors.red : Colors.green),
              ],
            ),
            if (player.gettoniTotali > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(
                  value: player.gettoniRimanenti / player.gettoniTotali,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                  color: player.gettoniEsauriti ? Colors.red : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tokenStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildAdminActions(BuildContext context, PlayerModel player) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gestione Gettoni', style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _showTokenDialog(context, player, true),
                    icon: const Icon(Icons.add),
                    label: const Text('Aggiungi'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showTokenDialog(context, player, false),
                    icon: const Icon(Icons.remove),
                    label: const Text('Rimuovi'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTokenDialog(BuildContext context, PlayerModel player, bool isAdd) {
    final quantitaCtrl = TextEditingController();
    final motivazioneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAdd ? 'Aggiungi Gettoni' : 'Rimuovi Gettoni'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantitaCtrl,
              decoration: const InputDecoration(labelText: 'Quantita\''),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motivazioneCtrl,
              decoration: const InputDecoration(labelText: 'Motivazione (obbligatoria)'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(
            onPressed: () async {
              final qty = int.tryParse(quantitaCtrl.text) ?? 0;
              if (qty <= 0 || motivazioneCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final finalQty = isAdd ? qty : -qty;
              await context.read<TokensProvider>().manualAdjust(
                player.id, finalQty, motivazioneCtrl.text.trim());
              if (mounted) _loadData();
            },
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsCard(BuildContext context) {
    return Consumer<TokensProvider>(
      builder: (context, tokensProv, _) {
        final transactions = tokensProv.transactions;
        if (transactions.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Nessuna transazione'),
            ),
          );
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Storico Transazioni',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...transactions.take(20).map((t) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: t.quantita > 0 ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                    child: Text(
                      t.quantita > 0 ? '+${t.quantita}' : '${t.quantita}',
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold,
                        color: t.quantita > 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                  title: Text(t.motivazione, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                    '${DateFormat('dd/MM/yy HH:mm').format(t.timestamp)} - ${t.tipo}',
                    style: const TextStyle(fontSize: 11)),
                )),
              ],
            ),
          ),
        );
      },
    );
  }
}
