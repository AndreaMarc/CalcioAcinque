import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/players_provider.dart';
import '../providers/theme_provider.dart';
import '../models/player_model.dart';
import '../models/pending_player.dart';
import '../models/team_draft.dart' show PlayerPosition, PlayerPositionX;
import '../models/payment_model.dart';
import '../models/ruoli.dart';
import '../models/team_format.dart';
import '../providers/club_provider.dart';
import '../widgets/app_widgets.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  String _query = '';
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPlayers());
  }

  Future<void> _loadPlayers() async {
    final auth = context.read<AuthProvider>();
    if (auth.teamId > 0) {
      final club = context.read<ClubProvider>();
      await club.loadFormats();
      await club.loadTeamConfig(auth.teamId);
      await context.read<PlayersProvider>().loadPlayers(auth.teamId);
    }
  }

  /// Formato della squadra attiva: decide quali ruoli proporre.
  TeamFormat get _formato =>
      context.read<ClubProvider>().teamConfig?.formato ?? TeamFormat.calcioA5;

  /// Regime di default della squadra: e quello che vale per chi non sceglie.
  RegimePagamento get _regimeSquadra =>
      context.read<ClubProvider>().teamConfig?.regimePagamentoDefault ??
          RegimePagamento.stagionale;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final initials = teamInitials(theme.teamName);

    return Consumer<PlayersProvider>(
      builder: (context, playersProv, _) {
        final players = playersProv.players;
        final q = _query.toLowerCase();
        List<PlayerModel> filtered = players.where((p) {
          if (q.isEmpty) return true;
          return p.nome.toLowerCase().contains(q) ||
              (p.soprannome ?? '').toLowerCase().contains(q);
        }).toList();
        switch (_filter) {
          case 'low':
            filtered = filtered.where((p) => p.gettoniRimanenti <= 2).toList();
            break;
          case 'full':
            filtered = filtered.where((p) => !p.gettoniEsauriti).toList();
            break;
          default:
        }
        filtered.sort((a, b) => b.gettoniRimanenti.compareTo(a.gettoniRimanenti));

        final low = players.where((p) => p.gettoniRimanenti <= 2).length;

        return Column(
          children: [
            AppTopBar(
              teamInitials: initials,
              title: 'Rosa',
              titleTrailing: context.watch<ClubProvider>().teamConfig != null
                  ? FormatBadge(
                      context.watch<ClubProvider>().teamConfig!.formato,
                      fontSize: 11,
                    )
                  : null,
              subtitle: '${players.length} giocatori',
              actions: [
                if (auth.puoGestireSquadra)
                  AppTopBar.iconAction(
                    context,
                    Icons.add,
                    () => _showAddPlayerDialog(context),
                  ),
              ],
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadPlayers,
                child: !playersProv.hasLoaded
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 100),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                            child: _SearchBar(
                              onChanged: (v) => setState(() => _query = v),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                            child: SizedBox(
                              height: 32,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _FilterChip(
                                    label: 'Tutti',
                                    count: players.length,
                                    active: _filter == 'all',
                                    onTap: () => setState(() => _filter = 'all'),
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterChip(
                                    label: 'Gettoni bassi',
                                    count: low,
                                    active: _filter == 'low',
                                    onTap: () => setState(() => _filter = 'low'),
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterChip(
                                    label: 'Attivi',
                                    count: players.where((p) => !p.gettoniEsauriti).length,
                                    active: _filter == 'full',
                                    onTap: () => setState(() => _filter = 'full'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (filtered.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 60),
                              child: Center(child: Text('Nessun giocatore')),
                            )
                          else
                            ...filtered.asMap().entries.map((e) {
                              final i = e.key;
                              final p = e.value;
                              return Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                child: _PlayerCard(
                                  player: p,
                                  // Il numero configurato vince sulla posizione in lista
                                  jerseyNumber: p.numeroMaglia ?? i + 1,
                                  isAdmin: auth.puoGestireSquadra,
                                  onTap: () =>
                                      context.push('/player/${p.id}'),
                                  onLongPress: auth.puoGestireSquadra
                                      ? () => _showPlayerActions(context, p)
                                      : null,
                                ),
                              );
                            }),
                          if (playersProv.pending.isNotEmpty && _query.isEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                              child: Text(
                                'IN ATTESA DI REGISTRARSI · ${playersProv.pending.length}',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  color: AppTokens.guest,
                                ),
                              ),
                            ),
                            ...playersProv.pending.map((pp) => Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                  child: _PendingCard(
                                    pending: pp,
                                    isAdmin: auth.puoGestireSquadra,
                                    onRemove: auth.puoGestireSquadra
                                        ? () => _confirmRemovePending(context, pp)
                                        : null,
                                  ),
                                )),
                          ],
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmRemovePending(BuildContext context, PendingPlayer pp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rimuovere dalla lista?'),
        content: Text('${pp.nome} non si è ancora registrato. Rimuoverlo dai giocatori in attesa?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTokens.bad),
            onPressed: () async {
              Navigator.pop(ctx);
              final auth = context.read<AuthProvider>();
              await context.read<PlayersProvider>().deletePending(auth.teamId, pp.id);
            },
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );
  }

  void _showPlayerActions(BuildContext context, PlayerModel player) {
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
              leading: const Icon(Icons.delete, color: AppTokens.bad),
              title: const Text('Elimina',
                  style: TextStyle(color: AppTokens.bad)),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirmDialog(context, player);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Ruolo e numero valgono solo per questa squadra: lo stesso giocatore puo'
  /// essere pivot nell'a5 e ala nell'a7.
  void _showEditPlayerDialog(BuildContext context, PlayerModel player) {
    final nomeCtrl = TextEditingController(text: player.nome);
    final soprannomeCtrl =
        TextEditingController(text: player.soprannome ?? '');
    final telefonoCtrl = TextEditingController(text: player.telefono ?? '');
    final numeroCtrl =
        TextEditingController(text: player.numeroMaglia?.toString() ?? '');
    var posizione = player.posizione;
    var regime = player.regimePagamento;
    var ruolo = RuoloX.fromApi(player.ruolo);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Modifica Giocatore'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (player.clubMemberId != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Nome, soprannome e telefono valgono in tutte le squadre della società.',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                    ),
                  ),
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
                  controller: telefonoCtrl,
                  decoration: const InputDecoration(labelText: 'Telefono'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _PositionPicker(
                  formato: _formato,
                  selected: posizione,
                  onChanged: (p) => setDialogState(() => posizione = p),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: numeroCtrl,
                  decoration: const InputDecoration(labelText: 'Numero di maglia'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Ruolo nella squadra',
                      style: Theme.of(ctx).textTheme.labelLarge),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: Ruolo.values
                      .map((r) => ChoiceChip(
                            label: Text(r.label),
                            selected: ruolo == r,
                            onSelected: (_) => setDialogState(() => ruolo = r),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    ruolo.descrizione,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Come paga',
                      style: Theme.of(ctx).textTheme.labelLarge),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // null = eredita il default della squadra
                    ChoiceChip(
                      label: Text('Come la squadra (${_regimeSquadra.shortLabel})'),
                      selected: regime == null,
                      onSelected: (_) => setDialogState(() => regime = null),
                    ),
                    ...RegimePagamento.values.map((r) => ChoiceChip(
                          label: Text(r.label),
                          selected: regime == r,
                          onSelected: (_) => setDialogState(() => regime = r),
                        )),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    (regime ?? _regimeSquadra).descrizione,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Sola lettura di proposito: la verita e la voce in Pagamenti,
                // questi flag ne sono il riflesso. Si spuntano segnando pagata
                // la voce, non da qui, altrimenti i due dati divergono.
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Quote', style: Theme.of(ctx).textTheme.labelLarge),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(
                      avatar: Icon(
                        player.iscrizionePagata ? Icons.check_circle : Icons.schedule,
                        size: 16,
                      ),
                      label: Text(player.iscrizionePagata
                          ? 'Iscrizione pagata'
                          : 'Iscrizione da pagare'),
                    ),
                    Chip(
                      avatar: Icon(
                        player.tesseramentoPagato ? Icons.check_circle : Icons.schedule,
                        size: 16,
                      ),
                      label: Text(player.tesseramentoPagato
                          ? 'Tesseramento pagato'
                          : 'Tesseramento da pagare'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Si aggiornano da Pagamenti, segnando pagata la voce.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla')),
            FilledButton(
              onPressed: () async {
                if (nomeCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final auth = context.read<AuthProvider>();
                final data = <String, dynamic>{
                  'nome': nomeCtrl.text.trim(),
                  // Stringa vuota = azzera il ruolo, null = lascia invariato
                  'posizione': posizione?.apiValue ?? '',
                  'numeroMaglia': int.tryParse(numeroCtrl.text) ?? 0,
                  // Stringa vuota = torna al default della squadra
                  'ruolo': ruolo.apiValue,
                  'regimePagamento': regime?.apiValue ?? '',
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
            Text('Resetta la password di ${player.displayName}'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordCtrl,
              decoration: const InputDecoration(labelText: 'Nuova Password *'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla')),
          FilledButton(
            onPressed: () async {
              if (passwordCtrl.text.isEmpty || passwordCtrl.text.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content:
                        Text('La password deve avere almeno 4 caratteri')));
                return;
              }
              Navigator.pop(ctx);
              final auth = context.read<AuthProvider>();
              final success = await context.read<PlayersProvider>()
                  .resetPassword(auth.teamId, player.id, passwordCtrl.text);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success
                      ? 'Password resettata'
                      : 'Errore nel reset'),
                ));
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
        title: const Text('Elimina Giocatore'),
        content: Text('Eliminare ${player.displayName}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final auth = context.read<AuthProvider>();
              final success = await context.read<PlayersProvider>()
                  .deletePlayer(auth.teamId, player.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success
                      ? '${player.displayName} eliminato'
                      : 'Errore nell\'eliminazione'),
                ));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppTokens.bad),
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
    final numeroCtrl = TextEditingController();
    PlayerPosition? posizione;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nuovo Giocatore'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    helperText: 'Se gioca già in un\'altra squadra della società, usa la sua email',
                  ),
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
                const SizedBox(height: 16),
                _PositionPicker(
                  formato: _formato,
                  selected: posizione,
                  onChanged: (p) => setDialogState(() => posizione = p),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: numeroCtrl,
                  decoration: const InputDecoration(labelText: 'Numero di maglia'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla')),
            FilledButton(
              onPressed: () async {
                if (nomeCtrl.text.trim().isEmpty ||
                    emailCtrl.text.trim().isEmpty ||
                    passwordCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                final auth = context.read<AuthProvider>();
                final success =
                    await context.read<PlayersProvider>().createPlayer(
                  auth.teamId,
                  {
                    'nome': nomeCtrl.text.trim(),
                    'soprannome': soprannomeCtrl.text.trim().isEmpty
                        ? null
                        : soprannomeCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'password': passwordCtrl.text,
                    'telefono': telefonoCtrl.text.trim().isEmpty
                        ? null
                        : telefonoCtrl.text.trim(),
                    if (posizione != null) 'posizione': posizione!.apiValue,
                    if (int.tryParse(numeroCtrl.text) != null)
                      'numeroMaglia': int.parse(numeroCtrl.text),
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
      ),
    );
  }
}

/// Chip dei ruoli ammessi dal formato della squadra.
class _PositionPicker extends StatelessWidget {
  final TeamFormat formato;
  final PlayerPosition? selected;
  final ValueChanged<PlayerPosition?> onChanged;

  const _PositionPicker({
    required this.formato,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final posizioni = context.read<ClubProvider>().positionsFor(formato);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ruolo (${formato.label})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('Nessuno'),
              selected: selected == null,
              onSelected: (_) => onChanged(null),
            ),
            ...posizioni.map((p) => ChoiceChip(
                  label: Text(p.label),
                  selected: selected == p,
                  onSelected: (_) => onChanged(p),
                )),
          ],
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTokens.darkCard : Colors.white;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: lineColor),
      ),
      child: TextField(
        onChanged: onChanged,
        style: GoogleFonts.spaceGrotesk(color: textColor, fontSize: 14),
        decoration: InputDecoration(
          filled: false,
          hintText: 'Cerca giocatore...',
          hintStyle: GoogleFonts.spaceGrotesk(
            color: muteColor,
            fontSize: 14,
          ),
          prefixIcon: Icon(Icons.search, size: 18, color: muteColor),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = active
        ? (isDark ? AppTokens.ink3 : AppTokens.ink)
        : (isDark ? AppTokens.darkCard : AppTokens.card);
    final fg = active
        ? Colors.white
        : (isDark ? AppTokens.darkTextMute : AppTokens.textMute);
    final border = active
        ? Colors.transparent
        : (isDark ? AppTokens.darkLine : AppTokens.line);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Text(
          '$label · $count',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final PendingPlayer pending;
  final bool isAdmin;
  final VoidCallback? onRemove;


  const _PendingCard({
    required this.pending,
    required this.isAdmin,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    final p = pending;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTokens.guest.withOpacity(isDark ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTokens.guest.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTokens.guest.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.hourglass_empty, color: AppTokens.guest, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  p.soprannome != null && p.soprannome!.isNotEmpty
                      ? '${p.nome} "${p.soprannome}"'
                      : p.nome,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      p.posizione != null ? '${p.posizione} · ' : '',
                      style: GoogleFonts.spaceGrotesk(fontSize: 11, color: muteColor),
                    ),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < p.bravura ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 12,
                          color: i < p.bravura ? AppTokens.guest : muteColor.withOpacity(0.4),
                        ),
                      ),
                    ),
                    if (p.tesserato) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, size: 13, color: AppTokens.guest),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTokens.guest.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'IN ATTESA',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppTokens.guest,
              ),
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: Icon(Icons.close, size: 18, color: muteColor),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final PlayerModel player;
  final int jerseyNumber;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _PlayerCard({
    required this.player,
    required this.jerseyNumber,
    required this.isAdmin,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTokens.darkCard : AppTokens.card;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    final pct = player.gettoniTotali > 0
        ? player.gettoniRimanenti / player.gettoniTotali
        : 0.0;
    final warn = player.gettoniRimanenti <= 2;

    return Opacity(
      opacity: player.gettoniEsauriti ? 0.55 : 1,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: lineColor),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  JerseyNumber(
                    number: jerseyNumber,
                    size: 50,
                    radius: 12,
                    fontSize: 24,
                    bg: AppTokens.ink,
                    fg: player.gettoniEsauriti
                        ? AppTokens.bad
                        : AppTokens.brand,
                  ),
                  if (player.ruoloBadge != null)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTokens.brand,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: cardColor, width: 2),
                        ),
                        child: Text(
                          player.ruoloBadge!,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: AppTokens.brandInk,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      player.displayName,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    if (player.displayName != player.nome ||
                        player.posizione != null)
                      Text(
                        [
                          if (player.displayName != player.nome) player.nome,
                          if (player.posizione != null) player.posizione!.label,
                        ].join(' · '),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          color: muteColor,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: AppProgressBar(
                            value: pct,
                            height: 4,
                            fillColor: warn
                                ? AppTokens.bad
                                : (isDark ? Colors.white : AppTokens.ink),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${player.gettoniRimanenti}/${player.gettoniTotali}',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: muteColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${player.gettoniConsumati}',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 22,
                      color: textColor,
                    ),
                  ),
                  Text(
                    'PRESENZE',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: muteColor,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
