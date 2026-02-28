import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/players_provider.dart';
import '../models/player_model.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPlayers());
  }

  Future<void> _loadPlayers() async {
    final auth = context.read<AuthProvider>();
    if (auth.teamId > 0) {
      await context.read<PlayersProvider>().loadPlayers(auth.teamId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadPlayers,
        child: Consumer<PlayersProvider>(
          builder: (context, playersProv, _) {
            if (!playersProv.hasLoaded) {
              return const Center(child: CircularProgressIndicator());
            }
            final players = playersProv.players;
            if (players.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 200),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.groups_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Nessun giocatore nella rosa'),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              itemCount: players.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final player = players[index];
                return Card(
                  child: ListTile(
                    onTap: () => context.push('/player/${player.id}'),
                    onLongPress: auth.isAdmin
                        ? () => _showPlayerActions(context, player)
                        : null,
                    leading: CircleAvatar(
                      backgroundColor: player.gettoniEsauriti
                          ? Theme.of(context).colorScheme.errorContainer
                          : Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        player.displayName.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: player.gettoniEsauriti
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    title: Text(player.displayName),
                    subtitle: Text(player.nome != player.displayName
                        ? player.nome : (player.telefono ?? '')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${player.gettoniRimanenti}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: player.gettoniEsauriti
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const Text('gettoni', style: TextStyle(fontSize: 10)),
                          ],
                        ),
                        if (auth.isAdmin) ...[
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            padding: EdgeInsets.zero,
                            onSelected: (value) {
                              switch (value) {
                                case 'edit':
                                  _showEditPlayerDialog(context, player);
                                case 'reset':
                                  _showResetPasswordDialog(context, player);
                                case 'delete':
                                  _showDeleteConfirmDialog(context, player);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(Icons.edit),
                                  title: Text('Modifica'),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'reset',
                                child: ListTile(
                                  leading: Icon(Icons.lock_reset),
                                  title: Text('Reset Password'),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  leading: Icon(Icons.delete, color: Colors.red.shade600),
                                  title: Text('Elimina',
                                    style: TextStyle(color: Colors.red.shade600)),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (!auth.isAdmin) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: auth.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showAddPlayerDialog(context),
              icon: const Icon(Icons.person_add),
              label: const Text('Aggiungi'),
            )
          : null,
    );
  }

  void _showPlayerActions(BuildContext context, PlayerModel player) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(player.displayName,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Modifica Nome / Soprannome'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditPlayerDialog(context, player);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_reset),
              title: const Text('Reset Password'),
              onTap: () {
                Navigator.pop(ctx);
                _showResetPasswordDialog(context, player);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red.shade600),
              title: Text('Elimina Giocatore',
                style: TextStyle(color: Colors.red.shade600)),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirmDialog(context, player);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEditPlayerDialog(BuildContext context, PlayerModel player) {
    final nomeCtrl = TextEditingController(text: player.nome);
    final soprannomeCtrl = TextEditingController(text: player.soprannome ?? '');
    final telefonoCtrl = TextEditingController(text: player.telefono ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifica Giocatore'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome e Cognome *',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: soprannomeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Soprannome',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telefonoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Telefono',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
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
              if (nomeCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final auth = context.read<AuthProvider>();
              final data = <String, dynamic>{
                'nome': nomeCtrl.text.trim(),
              };
              if (soprannomeCtrl.text.trim().isNotEmpty) {
                data['soprannome'] = soprannomeCtrl.text.trim();
              }
              if (telefonoCtrl.text.trim().isNotEmpty) {
                data['telefono'] = telefonoCtrl.text.trim();
              }
              final success = await context.read<PlayersProvider>()
                  .updatePlayer(auth.teamId, player.id, data);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Giocatore aggiornato')));
              }
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog(BuildContext context, PlayerModel player) {
    final passwordCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resetta la password di ${player.displayName}',
              style: Theme.of(ctx).textTheme.bodyMedium),
            const SizedBox(height: 16),
            TextField(
              controller: passwordCtrl,
              decoration: const InputDecoration(
                labelText: 'Nuova Password *',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              if (passwordCtrl.text.isEmpty || passwordCtrl.text.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('La password deve avere almeno 4 caratteri')));
                return;
              }
              Navigator.pop(ctx);
              final auth = context.read<AuthProvider>();
              final success = await context.read<PlayersProvider>()
                  .resetPassword(auth.teamId, player.id, passwordCtrl.text);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success
                      ? 'Password resettata per ${player.displayName}'
                      : 'Errore nel reset della password')),
                );
              }
            },
            child: const Text('Resetta'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, PlayerModel player) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, size: 48, color: Colors.red.shade600),
        title: const Text('Elimina Giocatore'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sei sicuro di voler eliminare ${player.displayName}?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Questa azione eliminera\' definitivamente il giocatore e il suo account. '
                'Tutte le statistiche, convocazioni e presenze verranno rimosse.',
                style: TextStyle(fontSize: 13, color: Colors.red.shade700),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final auth = context.read<AuthProvider>();
              final success = await context.read<PlayersProvider>()
                  .deletePlayer(auth.teamId, player.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success
                      ? '${player.displayName} eliminato'
                      : 'Errore nell\'eliminazione')),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  void _showAddPlayerDialog(BuildContext context) {
    final nomeCtrl = TextEditingController();
    final soprannomeCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuovo Giocatore'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome e Cognome *'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: soprannomeCtrl,
                decoration: const InputDecoration(labelText: 'Soprannome'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email *'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                decoration: const InputDecoration(labelText: 'Password *'),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telefonoCtrl,
                decoration: const InputDecoration(labelText: 'Telefono'),
                keyboardType: TextInputType.phone,
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
              if (nomeCtrl.text.trim().isEmpty ||
                  emailCtrl.text.trim().isEmpty ||
                  passwordCtrl.text.isEmpty) {
                return;
              }
              Navigator.pop(ctx);
              final auth = context.read<AuthProvider>();
              final success = await context.read<PlayersProvider>().createPlayer(
                auth.teamId,
                {
                  'nome': nomeCtrl.text.trim(),
                  'soprannome': soprannomeCtrl.text.trim().isEmpty
                      ? null : soprannomeCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'password': passwordCtrl.text,
                  'telefono': telefonoCtrl.text.trim().isEmpty
                      ? null : telefonoCtrl.text.trim(),
                },
              );
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Giocatore aggiunto!')));
              }
            },
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );
  }
}
