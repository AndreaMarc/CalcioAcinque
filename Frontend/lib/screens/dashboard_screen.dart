import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/convocations_provider.dart';
import '../providers/announcements_provider.dart';
import '../providers/players_provider.dart';
import '../providers/theme_provider.dart';
import '../models/dashboard_model.dart';
import '../models/player_model.dart';
import '../core/constants/api_constants.dart';
import '../widgets/app_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _availabilityData;

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
      context.read<PlayersProvider>().loadPlayers(auth.teamId);
      _loadAvailability();
    }
  }

  Future<void> _loadAvailability() async {
    try {
      final auth = context.read<AuthProvider>();
      final response = await auth.apiClient.dio.get(
        ApiConstants.nextAvailability(auth.teamId),
      );
      if (response.data['success'] == true && response.data['data'] != null) {
        if (mounted) setState(() => _availabilityData = response.data['data']);
      } else if (mounted) {
        setState(() => _availabilityData = null);
      }
    } catch (_) {
      if (mounted) setState(() => _availabilityData = null);
    }
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
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(disponibile
                ? 'Hai detto: ci sono. Il mister lo vede quando sceglie i convocati.'
                : 'Hai detto: salto. Puoi cambiare idea fino alle convocazioni.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nel salvare la disponibilita')),
        );
      }
    }
  }

  Future<void> _rispondiConvocazione(int convocationId, bool ciSono) async {
    final ok = await context
        .read<ConvocationsProvider>()
        .respond(convocationId, ciSono ? 'Confermato' : 'NonDisponibile');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(!ok
          ? 'Non riesco a salvare la risposta, riprova'
          : ciSono
              ? 'Confermato: sei in lista per la partita.'
              : 'Forfait registrato: il mister cerca un sostituto.'),
    ));
    if (ok) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();

    final player = auth.currentPlayer;
    final greeting = player != null
        ? 'Ciao, ${player.soprannome?.isNotEmpty == true ? player.soprannome : player.nome.split(' ').first}'
        : 'Benvenuto';
    final initials = teamInitials(theme.teamName);

    return Column(
      children: [
        AppTopBar(
          teamInitials: initials,
          title: theme.teamName,
          titleTrailing: auth.currentMembership != null
              ? FormatBadge(auth.currentMembership!.formato, fontSize: 11)
              : null,
          subtitle: greeting,
          actions: [
            AppTopBar.iconAction(
              context,
              Icons.notifications_none,
              () => context.go('/bacheca'),
              badge: Consumer<AnnouncementsProvider>(
                builder: (context, prov, _) {
                  if (prov.unreadCount <= 0) return const SizedBox.shrink();
                  return Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppTokens.bad,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppTokens.darkPaper : Colors.white,
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
            ),
            // I pagamenti non hanno una scheda in fondo: senza questa icona
            // ci si arriva solo dalla notifica push
            AppTopBar.iconAction(
              context,
              Icons.account_balance_wallet_outlined,
              () => context.go('/payments'),
            ),
            AppTopBar.iconAction(
              context,
              Icons.settings_outlined,
              () => context.push('/settings'),
            ),
          ],
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: Consumer2<DashboardProvider, ConvocationsProvider>(
              builder: (context, dash, conv, _) {
                if (dash.isLoading && dash.dashboard == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final d = dash.dashboard;
                if (d == null) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 160),
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              dash.hasError
                                  ? Icons.cloud_off
                                  : Icons.hourglass_empty,
                              size: 40,
                              color: AppTokens.textMute,
                            ),
                            const SizedBox(height: 12),
                            Text(dash.hasError
                                ? 'Impossibile caricare la dashboard'
                                : 'Caricamento...'),
                            if (dash.hasError) ...[
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _loadData,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Riprova'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: 4, bottom: 100),
                  children: [
                    if (d.prossimaPartita != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: _HeroMatchCard(
                          match: d.prossimaPartita!,
                          teamInitials: initials,
                          // Se sono convocato i due tasti rispondono alla convocazione,
                          // che e' la risposta che conta; altrimenti danno la disponibilita'
                          onYes: () {
                            final p = d.prossimaPartita!;
                            if (p.sonoConvocato && p.miaConvocazioneId != null) {
                              _rispondiConvocazione(p.miaConvocazioneId!, true);
                            } else {
                              _setAvailability(p.id, true);
                            }
                          },
                          onNo: () {
                            final p = d.prossimaPartita!;
                            if (p.sonoConvocato && p.miaConvocazioneId != null) {
                              _rispondiConvocazione(p.miaConvocazioneId!, false);
                            } else {
                              _setAvailability(p.id, false);
                            }
                          },
                          onTap: () => context.push('/match/${d.prossimaPartita!.id}'),
                        ),
                      ),
                    if (d.miePartite.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: _MyMatchesCard(
                          partite: d.miePartite,
                          onOpen: (id) => context.push('/match/$id'),
                        ),
                      ),
                    if (conv.pending.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: _PendingConvocationsCard(provider: conv, onDone: _loadData),
                      ),
                    if (_availabilityData != null && d.prossimaPartita == null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: _AvailabilityCompactCard(
                          data: _availabilityData!,
                          onYes: (id) => _setAvailability(id, true),
                          onNo: (id) => _setAvailability(id, false),
                        ),
                      ),
                    Consumer<PlayersProvider>(
                      builder: (context, players, _) {
                        if (players.players.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final present = (_availabilityData?['dettaglio']
                                as List?)
                            ?.where((d) => d['disponibile'] == true)
                            .length ?? 0;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHead(
                              title: 'CHI C\'È STASERA',
                              more: '$present su ${players.players.length} →',
                            ),
                            _StoriesRow(
                              players: players.players,
                              availabilityDetails:
                                  _availabilityData?['dettaglio'] as List?,
                              currentPlayerId:
                                  context.read<AuthProvider>().playerId,
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _StatsTokensRow(
                        partiteGiocate: d.partiteGiocate,
                        partiteTotali: d.partiteTotali,
                        useGettoni: d.useGettoni,
                        gettoniRimanenti: d.gettoniRimanenti,
                        gettoniTotali: d.gettoniTotali,
                      ),
                    ),
                    Consumer<AnnouncementsProvider>(
                      builder: (context, ann, _) {
                        final items = ann.announcements.take(1).toList();
                        if (items.isEmpty) return const SizedBox.shrink();
                        final a = items.first;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHead(
                              title: 'BACHECA',
                              more: 'Vedi tutto →',
                              onMore: () => context.go('/bacheca'),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: _BachecaPreview(title: a.titolo, body: a.contenuto),
                            ),
                          ],
                        );
                      },
                    ),
                    if (d.useGettoni && d.classificaGettoni.isNotEmpty) ...[
                      SectionHead(
                        title: 'CLASSIFICA GETTONI',
                        more: 'Vedi →',
                        onMore: () => context.go('/tokens'),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _RankingMini(list: d.classificaGettoni),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroMatchCard extends StatelessWidget {
  final MatchSummary match;
  final String teamInitials;
  final VoidCallback onYes;
  final VoidCallback onNo;
  final VoidCallback onTap;

  const _HeroMatchCard({
    required this.match,
    required this.teamInitials,
    required this.onYes,
    required this.onNo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEE d MMM', 'it_IT');
    final dateLabel = dateFmt.format(match.data).toUpperCase();
    final oraLabel = match.ora.isNotEmpty ? match.ora : '--:--';
    final fieldLabel = (match.luogo ?? '').isNotEmpty ? match.luogo! : '—';
    final opponent = (match.titolo ?? '').isNotEmpty ? match.titolo! : 'Avversario';
    final awayInitials = opponent.length >= 2
        ? opponent.substring(0, 2).toUpperCase()
        : opponent.toUpperCase();

    // In alto: dove sono con la convocazione. Sotto i tasti: cosa sto rispondendo.
    final Widget statusChip;
    if (match.hoConfermato) {
      statusChip = AppChip(text: 'Convocato · confermato', variant: AppChipVariant.brand, leading: _dot(AppTokens.brand));
    } else if (match.hoDatoForfait) {
      statusChip = const AppChip(text: 'Convocato · forfait', variant: AppChipVariant.bad);
    } else if (match.devoRispondere) {
      statusChip = const AppChip(text: 'Convocato · rispondi', variant: AppChipVariant.warn);
    } else if (match.convocazioniInviate) {
      statusChip = const AppChip(text: 'Non convocato', variant: AppChipVariant.neutral);
    } else {
      statusChip = const AppChip(text: 'Convocazioni in arrivo', variant: AppChipVariant.neutral);
    }

    // La domanda a cui rispondono i due tasti, e la risposta gia' data
    final bool? scelta = match.sonoConvocato
        ? (match.hoConfermato ? true : match.hoDatoForfait ? false : null)
        : match.miaDisponibilita;
    final String domanda;
    final String? esito;
    if (match.sonoConvocato) {
      domanda = scelta == null ? 'SEI CONVOCATO: CI SEI?' : 'LA TUA RISPOSTA ALLA CONVOCAZIONE';
      esito = scelta == null
          ? 'Il mister aspetta la tua conferma.'
          : scelta
              ? 'Hai confermato: sei in lista. Se cambia qualcosa, tocca Salto.'
              : 'Hai dato forfait. Se torni disponibile, tocca Ci sono.';
    } else {
      domanda = scelta == null ? 'DISPONIBILITÀ: CI SEI?' : 'LA TUA DISPONIBILITÀ';
      if (match.convocazioniInviate) {
        esito = scelta == null
            ? 'Le convocazioni sono uscite e non sei in lista. Di\' comunque se ci sei: serve per i sostituti.'
            : scelta
                ? 'Hai detto: ci sono. Non sei tra i convocati, ma se serve un sostituto il mister ti vede.'
                : 'Hai detto: salto. Non sei tra i convocati.';
      } else {
        esito = scelta == null
            ? 'Il mister convoca guardando chi ha detto di esserci.'
            : scelta
                ? 'Hai detto: ci sono. La convocazione arriva con una notifica.'
                : 'Hai detto: salto. Puoi cambiare idea fino alle convocazioni.';
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: CardInk(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROSSIMA PARTITA',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.54,
                          color: AppTokens.brand,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'GIORNATA ${match.numeroGiornata}',
                        style: GoogleFonts.bebasNeue(
                          fontSize: 36,
                          height: 1,
                          letterSpacing: 0.02 * 36,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                statusChip,
              ],
            ),
            const SizedBox(height: 20),
            VsLayout(
              homeCrest: CrestBox(initials: teamInitials, filled: true, showTeamLogo: true),
              homeName: context.watch<ThemeProvider>().teamName,
              awayCrest: CrestBox(initials: awayInitials, filled: false),
              awayName: opponent,
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(
                children: [
                  Expanded(child: _heroStat('DATA', dateLabel)),
                  Container(
                    width: 1,
                    height: 32,
                    color: Colors.white.withOpacity(0.08),
                  ),
                  Expanded(child: _heroStat('ORA', oraLabel)),
                  Container(
                    width: 1,
                    height: 32,
                    color: Colors.white.withOpacity(0.08),
                  ),
                  Expanded(child: _heroStat('CAMPO', fieldLabel)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              domanda,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: scelta == null ? AppTokens.warn : AppTokens.textOnInkMute,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _actionBtn(
                    label: 'Ci sono',
                    icon: scelta == true ? Icons.check_circle : Icons.check,
                    fill: AppTokens.brand,
                    fg: AppTokens.brandInk,
                    onTap: onYes,
                    active: scelta == true,
                    dimmed: scelta == false,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionBtn(
                    label: 'Salto',
                    icon: scelta == false ? Icons.cancel : Icons.close,
                    fill: scelta == false ? AppTokens.bad.withOpacity(0.25) : Colors.white.withOpacity(0.08),
                    fg: Colors.white,
                    border: scelta == false ? AppTokens.bad : Colors.white.withOpacity(0.12),
                    onTap: onNo,
                    active: scelta == false,
                    dimmed: scelta == true,
                  ),
                ),
              ],
            ),
            if (esito != null) ...[
              const SizedBox(height: 10),
              Text(
                esito,
                style: GoogleFonts.spaceGrotesk(fontSize: 12, color: AppTokens.textOnInkMute, height: 1.3),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            color: AppTokens.textOnInkMute,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.bebasNeue(
            fontSize: value.length > 6 ? 18 : 22,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color fill,
    required Color fg,
    Color? border,
    required VoidCallback onTap,
    bool active = false,
    bool dimmed = false,
  }) {
    // La scelta fatta resta piena e bordata, l'altra si spegne: si vede cosa si e' risposto
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(14),
          border: active ? Border.all(color: Colors.white, width: 2) : (border != null ? Border.all(color: border) : null),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _dot(Color c) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );
}

class _StoriesRow extends StatelessWidget {
  final List<PlayerModel> players;
  final List? availabilityDetails;
  final int currentPlayerId;

  const _StoriesRow({
    required this.players,
    required this.availabilityDetails,
    required this.currentPlayerId,
  });

  String _statusFor(int playerId) {
    if (playerId == currentPlayerId) return 'me';
    if (availabilityDetails == null) return 'pending';
    final entry = availabilityDetails!
        .cast<dynamic>()
        .firstWhere((e) => e['playerId'] == playerId, orElse: () => null);
    if (entry == null) return 'pending';
    if (entry['disponibile'] == true) return 'ok';
    if (entry['disponibile'] == false) return 'no';
    return 'pending';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: players.length,
        itemBuilder: (context, i) {
          final p = players[i];
          final myStatus = _statusFor(p.id);
          // Map 'pending' → 'warn' for visual consistency with mockup
          final status = myStatus == 'pending' ? 'warn' : myStatus;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: StoryAvatar(
              name: p.soprannome?.isNotEmpty == true ? p.soprannome! : p.nome.split(' ').first,
              number: i + 1,
              status: status,
              size: 60,
            ),
          );
        },
      ),
    );
  }
}

class _StatsTokensRow extends StatelessWidget {
  final int partiteGiocate;
  final int partiteTotali;
  final bool useGettoni;
  final int gettoniRimanenti;
  final int gettoniTotali;

  const _StatsTokensRow({
    required this.partiteGiocate,
    required this.partiteTotali,
    required this.useGettoni,
    required this.gettoniRimanenti,
    required this.gettoniTotali,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    final cardColor = isDark ? AppTokens.darkCard : AppTokens.card;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;

    final ratio = partiteTotali > 0 ? partiteGiocate / partiteTotali : 0.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 13,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: lineColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow('Le tue presenze', color: muteColor),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$partiteGiocate',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 44,
                        color: textColor,
                        height: 0.9,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '/ $partiteTotali',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          color: muteColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AppProgressBar(
                  value: ratio,
                  fillColor: isDark ? Colors.white : AppTokens.ink,
                  height: 6,
                ),
              ],
            ),
          ),
        ),
        if (useGettoni) ...[
          const SizedBox(width: 10),
          Expanded(
            flex: 10,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppTokens.darkBrand : AppTokens.brand,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTokens.brandInk.withOpacity(0.2),
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GETTONI',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.54,
                          color: AppTokens.brandInk.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$gettoniRimanenti',
                            style: GoogleFonts.bebasNeue(
                              fontSize: 56,
                              color: AppTokens.brandInk,
                              height: 0.85,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '/ $gettoniTotali',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 14,
                                color: AppTokens.brandInk.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BachecaPreview extends StatelessWidget {
  final String title;
  final String body;
  const _BachecaPreview({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTokens.darkCard : AppTokens.card;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lineColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark
                  ? AppTokens.brand.withOpacity(0.15)
                  : AppTokens.brandSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.push_pin_outlined,
              size: 18,
              color: isDark ? AppTokens.darkBrand : AppTokens.brandInk,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AppChip(
                      text: 'BACHECA',
                      variant: AppChipVariant.brand,
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      fontSize: 10,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    color: muteColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingMini extends StatelessWidget {
  final List<PlayerTokenSummary> list;
  const _RankingMini({required this.list});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTokens.darkCard : AppTokens.card;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lineColor),
      ),
      child: Column(
        children: list.take(5).toList().asMap().entries.map((e) {
          final i = e.key;
          final p = e.value;
          final ratio = p.gettoniTotali > 0
              ? p.gettoniRimanenti / p.gettoniTotali
              : 0.0;
          final low = p.gettoniRimanenti <= 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: i < list.take(5).length - 1
                  ? Border(bottom: BorderSide(color: lineColor))
                  : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    '${i + 1}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: muteColor,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.soprannome?.isNotEmpty == true ? p.soprannome! : p.nome,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AppProgressBar(
                        value: ratio,
                        height: 4,
                        fillColor: low
                            ? AppTokens.bad
                            : (isDark ? Colors.white : AppTokens.ink),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${p.gettoniRimanenti}',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 22,
                    color: low ? AppTokens.bad : textColor,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  '/${p.gettoniTotali}',
                  style: GoogleFonts.spaceGrotesk(fontSize: 11, color: muteColor),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PendingConvocationsCard extends StatelessWidget {
  final ConvocationsProvider provider;
  final VoidCallback onDone;
  const _PendingConvocationsCard({required this.provider, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTokens.darkCard : AppTokens.card;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTokens.warn, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active, size: 18, color: AppTokens.warn),
              const SizedBox(width: 8),
              Text(
                'CONVOCAZIONI IN ATTESA',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.54,
                  color: AppTokens.warn,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...provider.pending.map((c) {
            final dateStr = c.dataPartita != null
                ? DateFormat('d MMM', 'it_IT').format(c.dataPartita!)
                : '—';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Giornata ${c.numeroGiornata ?? '—'}',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                        Text(
                          '$dateStr · ${c.oraPartita ?? ''}',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            color: muteColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      await provider.respond(c.id, 'Confermato');
                      onDone();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? AppTokens.darkBrand : AppTokens.brand,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 14, color: AppTokens.brandInk),
                          const SizedBox(width: 4),
                          Text(
                            'Ci sono',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTokens.brandInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () async {
                      await provider.respond(c.id, 'NonDisponibile');
                      onDone();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: lineColor),
                      ),
                      child: Text(
                        'No',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AvailabilityCompactCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final void Function(int) onYes;
  final void Function(int) onNo;
  const _AvailabilityCompactCard({
    required this.data,
    required this.onYes,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) {
    final matchId = data['matchId'] as int;
    final giornata = data['numeroGiornata'] as int? ?? 0;
    final dataPartita = data['dataPartita'] != null
        ? DateTime.tryParse(data['dataPartita'])
        : null;
    final ora = data['oraPartita'] ?? '';
    final disponibili = data['disponibili'] as int? ?? 0;
    final nonDisp = data['nonDisponibili'] as int? ?? 0;
    final totale = data['totale'] as int? ?? 0;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTokens.darkCard : AppTokens.card;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;

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
          Text(
            'GIORNATA $giornata',
            style: GoogleFonts.bebasNeue(
              fontSize: 24,
              color: textColor,
              letterSpacing: 0.02 * 24,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dataPartita != null
                ? '${DateFormat('EEEE d MMMM', 'it_IT').format(dataPartita)} · $ora'
                : ora,
            style: GoogleFonts.spaceGrotesk(fontSize: 12, color: muteColor),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statMini('$disponibili', 'OK', AppTokens.ok),
              const SizedBox(width: 16),
              _statMini('$nonDisp', 'NO', AppTokens.bad),
              const SizedBox(width: 16),
              _statMini('$totale', 'TOT', textColor),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => onYes(matchId),
                  icon: const Icon(Icons.thumb_up_outlined, size: 16),
                  label: const Text('Ci sono'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onNo(matchId),
                  icon: const Icon(Icons.thumb_down_outlined, size: 16),
                  label: const Text('Non ci sono'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statMini(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.bebasNeue(fontSize: 26, color: color),
        ),
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color.withOpacity(0.9),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

/// Il riepilogo personale: per ogni partita in arrivo, cosa ho detto e se sono
/// stato convocato. Risponde alla domanda "e adesso?" dopo aver toccato Ci sono.
class _MyMatchesCard extends StatelessWidget {
  final List<MatchSummary> partite;
  final ValueChanged<int> onOpen;
  const _MyMatchesCard({required this.partite, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final df = DateFormat('EEE d MMM', 'it_IT');

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Eyebrow('LE MIE PARTITE')),
              Text('disponibilità · convocazione',
                  style: GoogleFonts.spaceGrotesk(fontSize: 10, color: muteColor)),
            ],
          ),
          const SizedBox(height: 6),
          ...partite.asMap().entries.map((e) {
            final p = e.value;
            final quando = df.format(p.data);
            return InkWell(
              onTap: () => onOpen(p.id),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: e.key == partite.length - 1 ? Colors.transparent : lineColor)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.displayTitle,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                          Text('${quando[0].toUpperCase()}${quando.substring(1)} · ${p.ora}',
                              style: GoogleFonts.spaceGrotesk(fontSize: 11, color: muteColor)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _dispChip(p),
                    const SizedBox(width: 6),
                    _convChip(p),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _dispChip(MatchSummary p) {
    if (p.miaDisponibilita == true) return const AppChip(text: 'Ci sono', variant: AppChipVariant.ok, leadingIcon: Icons.check);
    if (p.miaDisponibilita == false) return const AppChip(text: 'Salto', variant: AppChipVariant.bad, leadingIcon: Icons.close);
    return const AppChip(text: 'Non risposto', variant: AppChipVariant.warn);
  }

  Widget _convChip(MatchSummary p) {
    if (p.hoConfermato) return const AppChip(text: 'Convocato', variant: AppChipVariant.brand, leadingIcon: Icons.check);
    if (p.hoDatoForfait) return const AppChip(text: 'Forfait', variant: AppChipVariant.bad);
    if (p.devoRispondere) return const AppChip(text: 'Conferma!', variant: AppChipVariant.warn);
    if (p.convocazioniInviate) return const AppChip(text: 'Non convocato', variant: AppChipVariant.neutral);
    return const AppChip(text: 'In arrivo', variant: AppChipVariant.neutral);
  }
}
