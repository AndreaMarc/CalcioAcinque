import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/convocations_provider.dart';
import '../providers/club_provider.dart';
import '../models/team_draft.dart' show PlayerPosition, PlayerPositionX;
import '../providers/players_provider.dart';
import '../providers/theme_provider.dart';
import '../models/convocation_model.dart';
import '../core/constants/api_constants.dart';
import '../widgets/app_widgets.dart';

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
      // Serve il limite di convocati e il formato della squadra
      context.read<ClubProvider>().loadTeamConfig(auth.teamId),
      _loadAvailability(),
    ]);
  }

  Future<void> _loadAvailability() async {
    try {
      final auth = context.read<AuthProvider>();
      final resp = await auth.apiClient.dio
          .get(ApiConstants.matchAvailability(widget.matchId));
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        final List list = resp.data['data'] ?? [];
        final map = <int, bool?>{};
        for (final item in list) {
          map[item['playerId'] as int] = item['disponibile'] as bool?;
        }
        if (mounted) setState(() => _availabilityMap = map);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paper = isDark ? AppTokens.darkPaper : AppTokens.paper;
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final initials = teamInitials(theme.teamName);

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              teamInitials: initials,
              title: 'Convocazioni',
              subtitle: () {
                final cfg = context.watch<ClubProvider>().teamConfig;
                if (cfg == null) return 'Chi gioca, chi salta';
                final limite = cfg.maxConvocati;
                return limite == null
                    ? '${cfg.formatoShortLabel} · ${cfg.giocatoriInCampo} in campo'
                    : '${cfg.formatoShortLabel} · max $limite convocati';
              }(),
              onBack: () => context.pop(),
              actions: [
                if (auth.puoGestireCampo)
                  AppTopBar.iconAction(
                    context,
                    Icons.person_add,
                    () => _showSendConvocationsDialog(context),
                  ),
              ],
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: Consumer<ConvocationsProvider>(
                  builder: (context, convProv, _) {
                    if (!convProv.hasLoaded) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final convocations = convProv.convocations;
                    if (convocations.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 100),
                          Center(
                            child: Text(
                              'Nessuna convocazione',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 14,
                                color: isDark
                                    ? AppTokens.darkTextMute
                                    : AppTokens.textMute,
                              ),
                            ),
                          ),
                          if (auth.puoGestireCampo) ...[
                            const SizedBox(height: 20),
                            Center(
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _showSendConvocationsDialog(context),
                                icon: const Icon(Icons.send, size: 18),
                                label: const Text('Invia Convocazioni'),
                              ),
                            ),
                          ],
                        ],
                      );
                    }

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

                    final totConf =
                        convocations.where((c) => c.isConfermato).length;
                    final totAtt =
                        convocations.where((c) => c.isInAttesa).length;
                    final totNon =
                        convocations.where((c) => c.isNonDisponibile).length;

                    return ListView(
                      padding: const EdgeInsets.only(bottom: 20),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                          child: _SummaryStrip(
                            confermati: totConf,
                            inAttesa: totAtt,
                            nonDisp: totNon,
                          ),
                        ),
                        if (disponibili.isNotEmpty) ...[
                          _Head(
                              label: 'DISPONIBILI',
                              count: disponibili.length,
                              color: AppTokens.ok),
                          ...disponibili.map((c) => Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                child: _ConvTile(
                                  conv: c,
                                  isAdmin: auth.puoGestireCampo,
                                  onRespond: _loadData,
                                  availability: true,
                                ),
                              )),
                        ],
                        if (nonVotato.isNotEmpty) ...[
                          _Head(
                              label: 'NON HANNO VOTATO',
                              count: nonVotato.length,
                              color: AppTokens.warn),
                          ...nonVotato.map((c) => Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                child: _ConvTile(
                                  conv: c,
                                  isAdmin: auth.puoGestireCampo,
                                  onRespond: _loadData,
                                  availability: null,
                                ),
                              )),
                        ],
                        if (nonDisponibili.isNotEmpty) ...[
                          _Head(
                              label: 'NON DISPONIBILI',
                              count: nonDisponibili.length,
                              color: AppTokens.bad),
                          ...nonDisponibili.map((c) => Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                child: _ConvTile(
                                  conv: c,
                                  isAdmin: auth.puoGestireCampo,
                                  onRespond: _loadData,
                                  availability: false,
                                ),
                              )),
                        ],
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

  void _showSendConvocationsDialog(BuildContext context) {
    final players = context.read<PlayersProvider>().players;
    final config = context.read<ClubProvider>().teamConfig;
    final existing = context
        .read<ConvocationsProvider>()
        .convocations
        .map((c) => c.playerId)
        .toSet();
    final available = players.where((p) => !existing.contains(p.id)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tutti i giocatori sono gia convocati')));
      return;
    }

    // Il backend rifiuta l'invio oltre il limite della squadra: qui lo si mostra prima
    final maxConvocati = config?.maxConvocati;
    final restanti = maxConvocati == null ? null : maxConvocati - existing.length;
    if (restanti != null && restanti <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Limite raggiunto: $maxConvocati convocati per partita'),
      ));
      return;
    }

    available.sort((a, b) {
      final aAvail = _availabilityMap[a.id];
      final bAvail = _availabilityMap[b.id];
      int order(bool? v) => v == true ? 0 : v == null ? 1 : 2;
      return order(aAvail).compareTo(order(bAvail));
    });
    final selected = <int>{};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final pieno = restanti != null && selected.length >= restanti;
          return AlertDialog(
            title: const Text('Convoca Giocatori'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (restanti != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${config!.formatoLabel}: ancora $restanti convocabili '
                        'su $maxConvocati (${config.giocatoriInCampo} in campo)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: available.map((p) {
                        final isSelected = selected.contains(p.id);
                        return CheckboxListTile(
                          title: Text(p.displayName),
                          subtitle: Text([
                            'Gettoni: ${p.gettoniRimanenti}',
                            if (p.posizione != null) p.posizione!.label,
                          ].join(' · ')),
                          value: isSelected,
                          // Oltre il limite si possono solo deselezionare
                          onChanged: (!isSelected && pieno)
                              ? null
                              : (val) {
                                  setDialogState(() {
                                    if (val == true) {
                                      selected.add(p.id);
                                    } else {
                                      selected.remove(p.id);
                                    }
                                  });
                                },
                        );
                      }).toList(),
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
                onPressed: selected.isEmpty
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await context
                            .read<ConvocationsProvider>()
                            .sendConvocations(widget.matchId, selected.toList());
                        if (mounted) _loadData();
                      },
                child: Text('Convoca (${selected.length})'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final int confermati;
  final int inAttesa;
  final int nonDisp;
  const _SummaryStrip({
    required this.confermati,
    required this.inAttesa,
    required this.nonDisp,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _card(context, '$confermati', 'CONFERMATI', AppTokens.ok)),
        const SizedBox(width: 10),
        Expanded(
            child: _card(context, '$inAttesa', 'ATTESA', AppTokens.warn)),
        const SizedBox(width: 10),
        Expanded(child: _card(context, '$nonDisp', 'NO', AppTokens.bad)),
      ],
    );
  }

  Widget _card(BuildContext context, String v, String l, Color c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? AppTokens.darkCard : AppTokens.card;
    final line = isDark ? AppTokens.darkLine : AppTokens.line;
    final mute = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: line),
      ),
      child: Column(
        children: [
          Text(v, style: GoogleFonts.bebasNeue(fontSize: 30, color: c)),
          Text(
            l,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: mute,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _Head extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _Head({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$label · $count',
            style: GoogleFonts.bebasNeue(
              fontSize: 20,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTokens.darkText
                  : AppTokens.text,
              letterSpacing: 0.02 * 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConvTile extends StatelessWidget {
  final ConvocationModel conv;
  final bool isAdmin;
  final VoidCallback onRespond;
  final bool? availability;

  const _ConvTile({
    required this.conv,
    required this.isAdmin,
    required this.onRespond,
    required this.availability,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTokens.darkCard : AppTokens.card;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;

    Color bg;
    Color fg;
    IconData icon;
    if (conv.isConfermato) {
      bg = isDark
          ? AppTokens.ok.withOpacity(0.15)
          : const Color(0xFFDCF6E8);
      fg = AppTokens.ok;
      icon = Icons.check;
    } else if (conv.isNonDisponibile) {
      bg = isDark
          ? AppTokens.bad.withOpacity(0.15)
          : const Color(0xFFFCE0E0);
      fg = AppTokens.bad;
      icon = Icons.close;
    } else {
      bg = isDark
          ? AppTokens.warn.withOpacity(0.15)
          : const Color(0xFFFCEDD2);
      fg = AppTokens.warn;
      icon = Icons.access_time;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: lineColor),
      ),
      child: Row(
        children: [
          const JerseyNumber(size: 40, fontSize: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  conv.soprannome ?? conv.nomeGiocatore,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                Text(
                  _statusLabel(),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    color: muteColor,
                  ),
                ),
              ],
            ),
          ),
          if (conv.isInAttesa) ...[
            IconButton(
              icon: const Icon(Icons.check_circle, size: 26, color: AppTokens.ok),
              onPressed: () async {
                await context
                    .read<ConvocationsProvider>()
                    .respond(conv.id, 'Confermato');
                onRespond();
              },
            ),
            IconButton(
              icon: const Icon(Icons.cancel, size: 26, color: AppTokens.bad),
              onPressed: () async {
                await context
                    .read<ConvocationsProvider>()
                    .respond(conv.id, 'NonDisponibile');
                onRespond();
              },
            ),
          ] else
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: fg),
            ),
        ],
      ),
    );
  }

  String _statusLabel() {
    if (conv.isConfermato) return 'Confermato';
    if (conv.isNonDisponibile) return 'Non disponibile';
    return 'In attesa';
  }
}
