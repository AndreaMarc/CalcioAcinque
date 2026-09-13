import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/api_constants.dart';
import '../providers/auth_provider.dart';
import '../providers/players_provider.dart';
import '../providers/tokens_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/theme_provider.dart';
import '../models/player_model.dart';
import '../widgets/app_widgets.dart';

class PlayerDetailScreen extends StatefulWidget {
  final int playerId;
  const PlayerDetailScreen({super.key, required this.playerId});

  @override
  State<PlayerDetailScreen> createState() => _PlayerDetailScreenState();
}

class _PlayerDetailScreenState extends State<PlayerDetailScreen> {
  PlayerModel? _player;

  /// Altre squadre della società in cui gioca la stessa persona,
  /// dal dettaglio giocatore (`altreSquadre`).
  List<Map<String, dynamic>> _altreSquadre = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    await context.read<PlayersProvider>().loadPlayers(auth.teamId);
    await context.read<TokensProvider>().loadPlayerTokens(widget.playerId);
    await _loadDetail(auth);
    if (mounted) {
      final players = context.read<PlayersProvider>().players;
      setState(() {
        _player = players.where((p) => p.id == widget.playerId).firstOrNull;
      });
    }
  }

  Future<void> _loadDetail(AuthProvider auth) async {
    try {
      final response = await auth.apiClient.dio.get(
        ApiConstants.player(auth.teamId, widget.playerId),
      );
      if (response.data['success'] == true) {
        _altreSquadre = ((response.data['data']['altreSquadre'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .toList();
      }
    } catch (_) {
      // Il dettaglio e un extra: se non arriva la scheda resta comunque completa
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paper = isDark ? AppTokens.darkPaper : AppTokens.paper;

    if (_player == null) {
      return Scaffold(
        backgroundColor: paper,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final player = _player!;
    final auth = context.watch<AuthProvider>();
    final useGettoni = context.watch<DashboardProvider>().useGettoni;
    final theme = context.watch<ThemeProvider>();
    final initials = teamInitials(theme.teamName);
    final playerIndex = context.read<PlayersProvider>().players.indexWhere((p) => p.id == player.id);
    final jerseyNum = playerIndex >= 0 ? playerIndex + 1 : 1;

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              teamInitials: initials,
              title: 'Giocatore',
              subtitle: 'Scheda atleta',
              onBack: () => context.go('/players'),
              actions: [
                if (auth.puoGestireSquadra)
                  AppTopBar.iconAction(
                    context,
                    Icons.edit,
                    () {},
                  ),
              ],
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 20),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: _PlayerHero(
                        player: player,
                        jerseyNum: jerseyNum,
                      ),
                    ),
                    if (_altreSquadre.isNotEmpty) ...[
                      const SectionHead(title: 'GIOCA ANCHE IN'),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _altreSquadre.map((t) {
                            final ruolo = t['posizione'] as String?;
                            return AppChip(
                              text: [
                                t['teamNome'] as String? ?? '',
                                t['formatoShortLabel'] as String? ?? '',
                                if (ruolo != null) ruolo,
                              ].where((e) => e.isNotEmpty).join(' · '),
                              variant: AppChipVariant.neutral,
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    if (useGettoni) ...[
                      const SectionHead(title: 'GETTONI'),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: _TokenBreakdown(player: player),
                      ),
                    ],
                    if (useGettoni && auth.puoGestireGettoni)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _showTokenDialog(context, player, true),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Aggiungi'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _showTokenDialog(context, player, false),
                                icon: const Icon(Icons.remove, size: 18),
                                label: const Text('Rimuovi'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (player.telefono != null || player.nome.isNotEmpty) ...[
                      const SectionHead(title: 'CONTATTI'),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: _ContactCard(player: player),
                      ),
                    ],
                    if (useGettoni) ...[
                      const SectionHead(title: 'STORICO GETTONI'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _Transactions(),
                      ),
                    ],
                  ],
                ),
              ),
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
              decoration: const InputDecoration(labelText: 'Quantita'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motivazioneCtrl,
              decoration: const InputDecoration(labelText: 'Motivazione'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla')),
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
}

class _PlayerHero extends StatelessWidget {
  final PlayerModel player;
  final int jerseyNum;
  const _PlayerHero({required this.player, required this.jerseyNum});

  @override
  Widget build(BuildContext context) {
    final parts = player.nome.split(RegExp(r'\s+'));
    final firstName = parts.isNotEmpty ? parts.first : player.nome;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    return CardInk(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#$jerseyNum${player.isAdmin ? " · CAPITANO" : ""}',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.54,
                        color: AppTokens.brand,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      firstName.toUpperCase(),
                      style: GoogleFonts.bebasNeue(
                        fontSize: 40,
                        height: 0.95,
                        color: Colors.white,
                      ),
                    ),
                    if (lastName.isNotEmpty)
                      Text(
                        lastName.toUpperCase(),
                        style: GoogleFonts.bebasNeue(
                          fontSize: 40,
                          height: 0.95,
                          color: Colors.white,
                        ),
                      ),
                    if ((player.soprannome ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '"${player.soprannome}"',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          color: AppTokens.textOnInkMute,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '$jerseyNum',
                style: GoogleFonts.bebasNeue(
                  fontSize: 120,
                  height: 0.8,
                  color: AppTokens.brand.withOpacity(0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _heroStat(
                    label: 'GETTONI',
                    value: '${player.gettoniRimanenti}/${player.gettoniTotali}',
                  ),
                ),
                Expanded(
                  child: _heroStat(
                    label: 'CONSUMATI',
                    value: '${player.gettoniConsumati}',
                    brand: true,
                  ),
                ),
                Expanded(
                  child: _heroStat(
                    label: 'RUOLO',
                    value: player.isAdmin ? 'ADMIN' : 'PLAYER',
                    small: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat({
    required String label,
    required String value,
    bool brand = false,
    bool small = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.bebasNeue(
            fontSize: small ? 18 : 26,
            color: brand ? AppTokens.brand : Colors.white,
          ),
        ),
        Text(
          label,
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

class _TokenBreakdown extends StatelessWidget {
  final PlayerModel player;
  const _TokenBreakdown({required this.player});

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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _stat(
                  '${player.gettoniTotali}',
                  'TOTALI',
                  textColor,
                  muteColor,
                ),
              ),
              Expanded(
                child: _stat(
                  '${player.gettoniConsumati}',
                  'CONSUMATI',
                  AppTokens.warn,
                  muteColor,
                ),
              ),
              Expanded(
                child: _stat(
                  '${player.gettoniRimanenti}',
                  'RIMANENTI',
                  warn
                      ? AppTokens.bad
                      : (isDark ? AppTokens.darkBrand : AppTokens.brand),
                  muteColor,
                ),
              ),
            ],
          ),
          if (player.gettoniTotali > 0) ...[
            const SizedBox(height: 14),
            AppProgressBar(
              value: pct,
              height: 6,
              fillColor: warn
                  ? AppTokens.bad
                  : (isDark ? Colors.white : AppTokens.ink),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String value, String label, Color fg, Color muteColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: GoogleFonts.bebasNeue(fontSize: 28, color: fg)),
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: muteColor,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {
  final PlayerModel player;
  const _ContactCard({required this.player});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTokens.darkCard : AppTokens.card;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;

    final rows = <_ContactRowData>[
      _ContactRowData(Icons.person_outline, player.nome),
      if (player.telefono?.isNotEmpty == true)
        _ContactRowData(Icons.phone_outlined, player.telefono!),
      _ContactRowData(
        Icons.toll,
        '${player.gettoniConsumati} gettoni consumati',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lineColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: rows.asMap().entries.map((e) {
          final i = e.key;
          final r = e.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: i < rows.length - 1
                  ? Border(bottom: BorderSide(color: lineColor))
                  : null,
            ),
            child: Row(
              children: [
                Icon(r.icon, size: 16, color: muteColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    r.label,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ContactRowData {
  final IconData icon;
  final String label;
  _ContactRowData(this.icon, this.label);
}

class _Transactions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTokens.darkCard : AppTokens.card;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;

    return Consumer<TokensProvider>(
      builder: (context, prov, _) {
        final txs = prov.transactions;
        if (txs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: lineColor),
            ),
            alignment: Alignment.center,
            child: Text(
              'Nessuna transazione',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: muteColor,
              ),
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: lineColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: txs.take(15).toList().asMap().entries.map((e) {
              final i = e.key;
              final t = e.value;
              final positive = t.quantita > 0;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: i < txs.take(15).length - 1
                      ? Border(bottom: BorderSide(color: lineColor))
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTokens.softOf(
                          positive ? AppTokens.ok : AppTokens.bad,
                          isDark: isDark,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        positive ? '+${t.quantita}' : '${t.quantita}',
                        style: GoogleFonts.bebasNeue(
                          fontSize: 16,
                          color:
                              positive ? AppTokens.ok : AppTokens.bad,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t.motivazione,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${DateFormat('dd/MM/yy HH:mm').format(t.timestamp)} · ${t.tipo}',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              color: muteColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
