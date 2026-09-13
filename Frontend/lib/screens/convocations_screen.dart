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
import 'package:intl/intl.dart';
import '../models/player_model.dart';
import '../widgets/app_widgets.dart';
import '../widgets/share_utils.dart';

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
                if (context.watch<ConvocationsProvider>().convocations.isNotEmpty)
                  AppTopBar.iconAction(context, Icons.ios_share, _condividiConvocati),
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
                          const SizedBox(height: 40),
                          EmptyState(
                            icon: Icons.campaign_outlined,
                            title: 'NESSUNA CONVOCAZIONE',
                            message: auth.puoGestireCampo
                                ? 'Scegli i convocati e invia: partono le notifiche.'
                                : 'Quando il mister convoca, lo vedi qui.',
                            action: auth.puoGestireCampo
                                ? FilledButton.icon(
                                    onPressed: () =>
                                        _showSendConvocationsDialog(context),
                                    icon: const Icon(Icons.send, size: 18),
                                    label: const Text('Invia Convocazioni'),
                                  )
                                : null,
                          ),
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
                                  onRevoke: () => _revoca(c),
                                ),
                              )),
                        ],
                        if (nonVotato.isNotEmpty) ...[
                          _Head(
                              label: 'DISPONIBILITÀ NON DATA',
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
                                  onRevoke: () => _revoca(c),
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
                                  onRevoke: () => _revoca(c),
                                ),
                              )),
                        ],
                        if (auth.puoGestireCampo) ..._sostitutiSection(context, convocations, totNon),
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

  /// Chi ha detto "ci sono" ma non e' convocato: il sostituto e' a un tocco.
  List<Widget> _sostitutiSection(
      BuildContext context, List<ConvocationModel> convocations, int forfait) {
    final players = context.read<PlayersProvider>().players;
    final convocati = convocations.map((c) => c.playerId).toSet();
    final sostituti = players
        .where((p) => !convocati.contains(p.id) && _availabilityMap[p.id] == true)
        .toList()
      ..sort((a, b) => (b.affidabilita ?? -1).compareTo(a.affidabilita ?? -1));
    if (sostituti.isEmpty) return const [];

    final cfg = context.read<ClubProvider>().teamConfig;
    final maxConvocati = cfg?.maxConvocati;
    // Chi ha dato forfait non occupa piu' un posto
    final attivi = convocations.where((c) => !c.isNonDisponibile).length;
    final pieno = maxConvocati != null && attivi >= maxConvocati;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;

    return [
      _Head(label: 'DISPONIBILI NON CONVOCATI', count: sostituti.length, color: AppTokens.brand),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Text(
          pieno
              ? 'Rosa al completo ($maxConvocati): per convocarne uno revoca prima una convocazione.'
              : forfait > 0
                  ? 'Qualcuno ha dato forfait: convoca il sostituto con un tocco.'
                  : 'Hanno votato disponibile ma non sono in lista.',
          style: GoogleFonts.spaceGrotesk(fontSize: 11, color: muteColor),
        ),
      ),
      ...sostituti.map((p) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _SubTile(
              player: p,
              enabled: !pieno,
              onConvoca: () => _convocaSostituto(p),
            ),
          )),
    ];
  }

  Future<void> _convocaSostituto(PlayerModel p) async {
    final ok = await context
        .read<ConvocationsProvider>()
        .sendConvocations(widget.matchId, [p.id]);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '${p.displayName} convocato: gli arriva la notifica' : 'Non riesco a convocare, riprova'),
    ));
    if (ok) _loadData();
  }

  Future<void> _revoca(ConvocationModel c) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Revocare la convocazione?',
      message: '${c.soprannome ?? c.nomeGiocatore} esce dalla lista di questa partita. '
          'Nessuna notifica: avvisalo tu se serve.',
      confirmLabel: 'Revoca',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final errore = await context.read<ConvocationsProvider>().revoke(c.id, widget.matchId);
    if (!mounted) return;
    if (errore != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errore)));
    } else {
      _loadData();
    }
  }

  /// Il messaggio per il gruppo: chi c'e', chi manca, chi non ha risposto.
  void _condividiConvocati() {
    final convs = context.read<ConvocationsProvider>().convocations;
    if (convs.isEmpty) return;
    final first = convs.first;
    String nome(ConvocationModel c) => c.soprannome ?? c.nomeGiocatore;
    final conf = convs.where((c) => c.isConfermato).map(nome).toList();
    final att = convs.where((c) => c.isInAttesa).map(nome).toList();
    final no = convs.where((c) => c.isNonDisponibile).map(nome).toList();
    final quando = first.dataPartita != null
        ? DateFormat('EEEE d MMMM', 'it_IT').format(first.dataPartita!)
        : null;
    final b = StringBuffer();
    b.writeln('⚽ CONVOCATI · Giornata ${first.numeroGiornata ?? ''}'.trim());
    b.writeln([
      if (quando != null) quando[0].toUpperCase() + quando.substring(1),
      if (first.oraPartita != null) 'ore ${first.oraPartita}',
      if (first.luogoPartita != null) first.luogoPartita!,
    ].join(' · '));
    b.writeln();
    if (conf.isNotEmpty) b.writeln('✅ Confermati (${conf.length}): ${conf.join(', ')}');
    if (att.isNotEmpty) b.writeln('⏳ In attesa (${att.length}): ${att.join(', ')}');
    if (no.isNotEmpty) b.writeln('❌ Forfait (${no.length}): ${no.join(', ')}');
    b.writeln();
    b.write('Rispondi su InCampo: ${appLink('/match/${widget.matchId}')}');
    showShareSheet(context, title: 'Convocati', text: b.toString());
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
          content: Text('Tutti i giocatori sono già convocati')));
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
      final byAvail = order(aAvail).compareTo(order(bAvail));
      if (byAvail != 0) return byAvail;
      // A pari disponibilita' prima chi di solito risponde e viene
      return (b.affidabilita ?? -1).compareTo(a.affidabilita ?? -1);
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
                            if (p.affidabilita != null) 'affidabilità ${p.affidabilita}%',
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
    final mute = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14),
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
  final VoidCallback? onRevoke;

  const _ConvTile({
    required this.conv,
    required this.isAdmin,
    required this.onRespond,
    required this.availability,
    this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;

    AppChipVariant variant;
    IconData icon;
    if (conv.isConfermato) {
      variant = AppChipVariant.ok;
      icon = Icons.check;
    } else if (conv.isNonDisponibile) {
      variant = AppChipVariant.bad;
      icon = Icons.close;
    } else {
      variant = AppChipVariant.warn;
      icon = Icons.access_time;
    }

    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          JerseyNumber(number: conv.numeroMaglia, size: 40, fontSize: 19),
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
            AppChip(text: _statusLabel(), variant: variant, leadingIcon: icon),
          if (isAdmin && onRevoke != null)
            IconButton(
              tooltip: 'Revoca convocazione',
              icon: Icon(Icons.person_remove_outlined, size: 20, color: muteColor),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              onPressed: onRevoke,
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

/// Un disponibile non convocato, con il bottone per convocarlo al volo.
class _SubTile extends StatelessWidget {
  final PlayerModel player;
  final bool enabled;
  final VoidCallback onConvoca;
  const _SubTile({required this.player, required this.enabled, required this.onConvoca});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    final dettagli = <String>[
      if (player.posizione != null) player.posizione!.label,
      if (player.affidabilita != null) 'affidabilità ${player.affidabilita}%',
      'gettoni ${player.gettoniRimanenti}',
    ];
    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          JerseyNumber(number: player.numeroMaglia, size: 40, fontSize: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  player.displayName,
                  style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                ),
                Text(dettagli.join(' · '), style: GoogleFonts.spaceGrotesk(fontSize: 11, color: muteColor)),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: enabled ? onConvoca : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 34),
            ),
            child: const Text('Convoca'),
          ),
        ],
      ),
    );
  }
}
