import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/matches_provider.dart';
import '../providers/convocations_provider.dart';
import '../providers/club_provider.dart';
import '../models/team_format.dart';
import '../providers/theme_provider.dart';
import '../models/match_model.dart';
import '../core/constants/api_constants.dart';
import '../widgets/app_widgets.dart';
import '../widgets/match_incasso_sheet.dart';
import '../widgets/mvp_card.dart';
import '../widgets/share_utils.dart';
import '../widgets/turni_card.dart';

class MatchDetailScreen extends StatefulWidget {
  final int matchId;
  const MatchDetailScreen({super.key, required this.matchId});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  MatchModel? _match;
  Map<String, dynamic>? _availabilityData;
  bool _notFound = false;

  /// Cresce a ogni ricarica: le card MVP e Turni lo usano per ricaricarsi.
  int _refreshTick = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    await context.read<MatchesProvider>().loadMatches(auth.teamId);
    await context.read<ConvocationsProvider>().loadByMatch(widget.matchId);
    // Formato e regole della squadra (per il biglietto): non blocca il resto
    if (context.read<ClubProvider>().teamConfig == null) {
      context.read<ClubProvider>().loadTeamConfig(auth.teamId);
    }
    if (mounted) setState(() => _refreshTick++);
    try {
      final response = await auth.apiClient.dio.get(
        ApiConstants.matchAvailability(widget.matchId),
      );
      if (response.data['success'] == true) {
        setState(() => _availabilityData = response.data['data']);
      }
    } catch (_) {}
    if (!mounted) return;
    final matchesProv = context.read<MatchesProvider>();
    var match = matchesProv.matches.where((m) => m.id == widget.matchId).firstOrNull;
    // Dalla notifica si arriva qui prima che la lista sia caricata, o per una
    // partita di un'altra stagione: si chiede al server invece di girare a vuoto
    match ??= await matchesProv.fetchMatch(auth.teamId, widget.matchId);
    if (!mounted) return;
    setState(() {
      _match = match;
      _notFound = match == null;
    });
  }

  Future<void> _rispondiConvocazione(int convocationId, String risposta) async {
    final ok = await context.read<ConvocationsProvider>().respond(convocationId, risposta);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (risposta == 'Confermato' ? 'Confermato: sei in lista per la partita.' : 'Forfait registrato: il mister cerca un sostituto.')
          : 'Non riesco a salvare la risposta, riprova'),
    ));
    if (ok) _loadData();
  }

  Future<void> _setDisponibilita(bool disponibile) async {
    try {
      await context.read<AuthProvider>().apiClient.dio.post(
        ApiConstants.matchAvailability(widget.matchId),
        data: {'disponibile': disponibile},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(disponibile
            ? 'Hai detto: ci sono. Il mister lo vede quando sceglie i convocati.'
            : 'Hai detto: salto. Puoi cambiare idea fino alle convocazioni.'),
      ));
      _loadData();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore nel salvare la disponibilita')),
      );
    }
  }

  /// La risposta di chi guarda: e' il motivo per cui la notifica porta qui.
  Widget _buildMyResponse(BuildContext context, MatchModel match) {
    final me = context.read<AuthProvider>().currentPlayer;
    if (me == null || match.stato == 'Conclusa' || match.stato == 'InCorso') {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;

    final convs = context.watch<ConvocationsProvider>().convocations;
    final mia = convs.where((c) => c.playerId == me.id).firstOrNull;

    String eyebrow;
    String stato;
    AppChipVariant variant;
    bool? attuale;
    void Function(bool) onRisposta;

    final dettaglio = (_availabilityData?['dettaglio'] as List?) ?? const [];
    final miaDisp = dettaglio.cast<Map>().where((d) => d['playerId'] == me.id).firstOrNull;
    final convocazioniInviate = match.stato != 'Programmata';
    if (mia != null) {
      eyebrow = 'LA TUA CONVOCAZIONE';
      if (mia.isConfermato) {
        stato = 'Hai confermato';
        variant = AppChipVariant.ok;
        attuale = true;
      } else if (mia.isNonDisponibile) {
        stato = 'Hai dato forfait';
        variant = AppChipVariant.bad;
        attuale = false;
      } else {
        stato = 'In attesa di risposta';
        variant = AppChipVariant.warn;
      }
      onRisposta = (si) => _rispondiConvocazione(mia.id, si ? 'Confermato' : 'NonDisponibile');
    } else {
      eyebrow = 'LA TUA DISPONIBILITÀ';
      if (miaDisp == null) {
        stato = 'Non hai ancora risposto';
        variant = AppChipVariant.warn;
      } else if (miaDisp['disponibile'] == true) {
        stato = 'Disponibile';
        variant = AppChipVariant.ok;
        attuale = true;
      } else {
        stato = 'Non disponibile';
        variant = AppChipVariant.bad;
        attuale = false;
      }
      onRisposta = _setDisponibilita;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Eyebrow(eyebrow)),
                AppChip(text: stato, variant: variant),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: attuale == true ? null : () => onRisposta(true),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Ci sono'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: attuale == false ? null : () => onRisposta(false),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Non ci sono'),
                    style: OutlinedButton.styleFrom(foregroundColor: textColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              mia != null
                  ? (miaDisp == null
                      ? 'Sei tra i convocati. Questa risposta è quella che conta per la distinta.'
                      : 'Sei tra i convocati (avevi detto: ${miaDisp['disponibile'] == true ? 'ci sono' : 'salto'}). Questa risposta è quella che conta.')
                  : convocazioniInviate
                      ? 'Le convocazioni sono uscite e non sei in lista. La disponibilità resta utile: se serve un sostituto il mister ti vede.'
                      : 'Il mister convoca guardando chi ha detto di esserci. La convocazione arriva con una notifica.',
              style: GoogleFonts.spaceGrotesk(fontSize: 11, color: muteColor, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paper = isDark ? AppTokens.darkPaper : AppTokens.paper;

    if (_match == null) {
      return Scaffold(
        backgroundColor: paper,
        body: SafeArea(
          child: _notFound
              ? Column(
                  children: [
                    AppTopBar(title: 'Partita', onBack: () => context.go('/calendar')),
                    Expanded(
                      child: EmptyState(
                        icon: Icons.event_busy_outlined,
                        title: 'PARTITA NON TROVATA',
                        message: 'Forse è stata eliminata, o appartiene a un\'altra squadra.',
                        action: FilledButton(
                          onPressed: () => context.go('/calendar'),
                          child: const Text('Vai al calendario'),
                        ),
                      ),
                    ),
                  ],
                )
              : const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final match = _match!;
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
              title: 'Giornata ${match.numeroGiornata}',
              subtitle: '${DateFormat('EEE d MMM', 'it_IT').format(match.data)} · ${match.ora}',
              onBack: () => context.go('/calendar'),
              actions: [
                if (!match.isConclusa)
                  AppTopBar.iconAction(context, Icons.event_available_outlined, () => _aggiungiAlCalendario(match)),
                AppTopBar.iconAction(context, Icons.ios_share, () => _condividi(match)),
                // Anche il cassiere: dentro il menu c'e' l'incasso, che e' suo
                if (auth.puoGestireCampo || auth.puoGestireSoldi)
                  AppTopBar.iconAction(
                    context,
                    Icons.more_vert,
                    () => _showAdminMenu(context, match),
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
                      child: _TicketCard(
                        match: match,
                        teamInitials: initials,
                        bgColor: paper,
                        formato: () {
                          // Il numero vero della squadra (configurabile), non il preset del formato
                          final n = context.watch<ClubProvider>().teamConfig?.giocatoriInCampo ??
                              auth.currentMembership?.formato.giocatoriInCampo ??
                              5;
                          return '${n}V$n';
                        }(),
                      ),
                    ),
                    _buildMyResponse(context, match),
                    if (match.isConclusa) MvpCard(key: ValueKey('mvp-${match.id}'), matchId: match.id, refreshTick: _refreshTick),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _AvailabilitySummary(
                        availability: _availabilityData,
                        match: match,
                      ),
                    ),
                    if (_availabilityData != null) _buildDettaglio(_availabilityData!),
                    if (context.watch<ConvocationsProvider>().convocations.isNotEmpty) ...[
                      _buildConvocations(context),
                      TurniCard(
                        key: ValueKey('turni-${match.id}'),
                        matchId: match.id,
                        canEdit: auth.puoGestireCampo,
                        convocati: context.watch<ConvocationsProvider>().convocations,
                        refreshTick: _refreshTick,
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: _ActionButtons(
                        match: match,
                        isAdmin: auth.puoGestireCampo,
                        onMatchDay: () => context.push('/match/${match.id}/day'),
                        onLive: () => context.push('/match/${match.id}/live'),
                        onConvocations: () =>
                            context.push('/match/${match.id}/convocations'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// La singola partita nel calendario del telefono: file .ics dal server (iPhone lo
  /// apre in Calendario, Android nell'app calendario) oppure Google Calendar via link.
  Future<void> _aggiungiAlCalendario(MatchModel match) async {
    final auth = context.read<AuthProvider>();
    String feed;
    try {
      final resp = await auth.apiClient.dio.get(ApiConstants.calendarLink(auth.teamId));
      feed = resp.data['data']['url'] as String;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Non riesco a preparare il calendario, riprova')),
      );
      return;
    }
    if (!mounted) return;
    final eventoIcs = feed.replaceFirst('/calendar.ics?', '/${match.id}/event.ics?');
    final cfg = context.read<ClubProvider>().teamConfig;
    final durata = cfg != null ? cfg.minutiPerTempo * cfg.numeroTempi + 15 : 90;
    final parti = match.ora.split(':');
    final inizio = DateTime(match.data.year, match.data.month, match.data.day,
        int.tryParse(parti.first) ?? 21, parti.length > 1 ? int.tryParse(parti[1]) ?? 0 : 0);
    final fine = inizio.add(Duration(minutes: durata));
    String g(DateTime d) => DateFormat('yyyyMMdd\'T\'HHmmss').format(d);
    final teamName = context.read<ThemeProvider>().teamName;
    final titolo = (match.titolo ?? '').isNotEmpty ? '$teamName - G${match.numeroGiornata} vs ${match.titolo}' : '$teamName - Giornata ${match.numeroGiornata}';
    final google = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': titolo,
      'dates': '${g(inizio)}/${g(fine)}',
      if ((match.luogo ?? '').isNotEmpty) 'location': match.luogo!,
      'details': 'Partita su InCampo: ${appLink('/match/${match.id}')}',
    }).toString();

    await showAppSheet<void>(
      context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DisplayText('AGGIUNGI AL CALENDARIO', size: 22, color: isDark ? AppTokens.darkText : AppTokens.text),
            const SizedBox(height: 10),
            AppSheetAction(
              icon: Icons.phone_iphone,
              label: 'iPhone, Mac e altri calendari',
              subtitle: 'Scarica l\'evento (.ics): si apre in Calendario',
              onTap: () {
                Navigator.of(ctx).pop();
                web.window.open(eventoIcs, '_blank');
              },
            ),
            AppSheetAction(
              icon: Icons.android,
              label: 'Google Calendar',
              subtitle: 'Android, o chi usa Google Calendar',
              onTap: () {
                Navigator.of(ctx).pop();
                web.window.open(google, '_blank');
              },
            ),
            AppSheetAction(
              icon: Icons.calendar_month_outlined,
              label: 'Tutte le partite, sempre aggiornate',
              subtitle: 'Iscrizione al calendario della squadra, dalla scheda Partite',
              onTap: () {
                Navigator.of(ctx).pop();
                context.go('/calendar');
              },
            ),
          ],
        );
      },
    );
  }

  /// Testo pronto per il gruppo: risultato e marcatori se conclusa, altrimenti
  /// i convocati con i turni.
  Future<void> _condividi(MatchModel match) async {
    final auth = context.read<AuthProvider>();
    final teamName = context.read<ThemeProvider>().teamName;
    final quando = DateFormat('EEEE d MMMM', 'it_IT').format(match.data);
    final b = StringBuffer();
    final testata = [
      quando[0].toUpperCase() + quando.substring(1),
      'ore ${match.ora}',
      if (match.luogo != null && match.luogo!.isNotEmpty) match.luogo!,
    ].join(' · ');

    if (match.isConclusa) {
      var fatti = 0, subiti = 0;
      final marcatori = <String>[];
      try {
        final resp = await auth.apiClient.dio.get(ApiConstants.matchAttendance(match.id));
        for (final a in (resp.data['data'] as List? ?? const [])) {
          final goal = (a['goal'] as num?)?.toInt() ?? 0;
          fatti += goal;
          subiti += (a['goalSubiti'] as num?)?.toInt() ?? 0;
          if (goal > 0) {
            final nome = (a['soprannome'] as String?) ?? (a['nomeGiocatore'] as String? ?? '');
            marcatori.add(goal == 1 ? nome : '$nome ($goal)');
          }
        }
      } catch (_) {}
      if (!mounted) return;
      final avversario = (match.titolo ?? '').isNotEmpty ? match.titolo! : 'Avversari';
      b.writeln('🏁 RISULTATO · Giornata ${match.numeroGiornata}');
      b.writeln(testata);
      b.writeln();
      b.writeln('$teamName $fatti - $subiti $avversario');
      if (marcatori.isNotEmpty) b.writeln('⚽ ${marcatori.join(', ')}');
      b.writeln();
      b.write('Vota il migliore in campo: ${appLink('/match/${match.id}')}');
      showShareSheet(context, title: 'Risultato', text: b.toString());
      return;
    }

    final convs = context.read<ConvocationsProvider>().convocations;
    String nome(dynamic c) => (c.soprannome as String?) ?? (c.nomeGiocatore as String);
    final conf = convs.where((c) => c.isConfermato).map(nome).toList();
    final att = convs.where((c) => c.isInAttesa).map(nome).toList();
    final no = convs.where((c) => c.isNonDisponibile).map(nome).toList();
    b.writeln('⚽ ${match.displayTitle.toUpperCase()}');
    b.writeln(testata);
    if (convs.isNotEmpty) {
      b.writeln();
      if (conf.isNotEmpty) b.writeln('✅ Confermati (${conf.length}): ${conf.join(', ')}');
      if (att.isNotEmpty) b.writeln('⏳ In attesa (${att.length}): ${att.join(', ')}');
      if (no.isNotEmpty) b.writeln('❌ Forfait (${no.length}): ${no.join(', ')}');
      try {
        final resp = await auth.apiClient.dio.get(ApiConstants.matchChores(match.id));
        final turni = (resp.data['data'] as List? ?? const [])
            .where((t) => t['playerId'] != null)
            .map((t) => '${t['nome']}: ${t['soprannome'] ?? t['nomeGiocatore']}')
            .toList();
        if (turni.isNotEmpty) b.writeln('🎽 Turni · ${turni.join(' · ')}');
      } catch (_) {}
    }
    b.writeln();
    b.write('Rispondi su InCampo: ${appLink('/match/${match.id}')}');
    if (!mounted) return;
    showShareSheet(context, title: 'Partita', text: b.toString());
  }

  Widget _buildDettaglio(Map<String, dynamic> data) {
    final dettaglio = (data['dettaglio'] as List? ?? []).cast<Map>();
    if (dettaglio.isEmpty) return const SizedBox.shrink();
    // Chi gioca e chi sta in panchina si leggono a parte
    final giocatori = dettaglio.where((d) => d['gioca'] != false).toList();
    final staff = dettaglio.where((d) => d['gioca'] == false).toList();

    Widget righe(List<Map> lista, {bool conRuolo = false}) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Column(
            children: lista.map((d) {
              var nome = (d['soprannome'] ?? d['nomeGiocatore'] ?? '') as String;
              if (conRuolo) {
                final ruolo = d['ruolo'] as String?;
                nome = '$nome · ${ruolo == 'Mister' ? 'mister' : ruolo == 'Admin' ? 'admin' : ruolo == 'Cassiere' ? 'cassiere' : 'staff'}';
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AvailabilityRow(
                  nome: nome,
                  disponibile: d['disponibile'] == true,
                  note: d['note'] as String?,
                ),
              );
            }).toList(),
          ),
        );

    return Column(
      children: [
        if (giocatori.isNotEmpty) ...[
          SectionHead(title: 'DISPONIBILITÀ', more: '${giocatori.length} ${giocatori.length == 1 ? 'giocatore' : 'giocatori'}'),
          righe(giocatori),
        ],
        if (staff.isNotEmpty) ...[
          const SectionHead(title: 'IN PANCHINA', more: 'staff'),
          righe(staff, conRuolo: true),
        ],
      ],
    );
  }

  Widget _buildConvocations(BuildContext context) {
    final convs = context.watch<ConvocationsProvider>().convocations;
    return Column(
      children: [
        SectionHead(title: 'CONVOCATI', more: convs.length == 1 ? '1 giocatore' : '${convs.length} giocatori'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            children: convs.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ConvocationRow(conv: c),
                )).toList(),
          ),
        ),
      ],
    );
  }

  void _showAdminMenu(BuildContext context, MatchModel match) {
    // Le voci di campo al mister, l'incasso al cassiere: l'API applica gli
    // stessi limiti, mostrarle a chi non puo' usarle produce solo un 403
    final auth = context.read<AuthProvider>();
    final campo = auth.puoGestireCampo;
    final soldi = auth.puoGestireSoldi;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (campo)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Modifica'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditDialog(context, match);
                },
              ),
            if (campo && match.isProgrammata)
              ListTile(
                leading: const Icon(Icons.send),
                title: const Text('Invia Convocazioni'),
                onTap: () {
                  Navigator.pop(ctx);
                  _updateStato(context, match, 'ConvocazioniInviate');
                },
              ),
            if (campo && match.stato == 'ConvocazioniInviate')
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('Inizia Partita'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final auth = context.read<AuthProvider>();
                  final success = await context
                      .read<MatchesProvider>()
                      .updateStato(auth.teamId, match.id, 'InCorso');
                  if (success && mounted) context.push('/match/${match.id}/live');
                },
              ),
            if (campo && match.stato == 'InCorso')
              ListTile(
                leading: const Icon(Icons.stop, color: AppTokens.bad),
                title: const Text('Concludi Partita'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _updateStato(context, match, 'Conclusa');
                  if (mounted) _proponiIncasso(match.id);
                },
              ),
            // Presenze e statistiche si bloccano alla conclusione: per correggerle
            // si riapre (il server ammette solo Conclusa -> InCorso)
            if (campo && match.stato == 'Conclusa')
              ListTile(
                leading: const Icon(Icons.replay, color: AppTokens.warn),
                title: const Text('Riapri partita'),
                subtitle: const Text('Per correggere presenze e statistiche'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await showConfirmDialog(
                    context,
                    title: 'Riaprire la partita?',
                    message: 'Torna "in corso": potrai correggere presenze e statistiche, '
                        'poi andra\' conclusa di nuovo. I gettoni si riallineano da soli.',
                    confirmLabel: 'Riapri',
                  );
                  if (ok && mounted) await _updateStato(context, match, 'InCorso');
                },
              ),
            // Riapribile in qualsiasi momento: l incasso spesso si registra
            // dopo, quando le presenze sono state sistemate
            if (soldi && match.stato == 'Conclusa')
              ListTile(
                leading: const Icon(Icons.euro, color: AppTokens.brand),
                title: const Text('Incasso partita'),
                subtitle: const Text('Chi deve pagare questa partita'),
                onTap: () {
                  Navigator.pop(ctx);
                  MatchIncassoSheet.show(context, match.id);
                },
              ),
            if (campo)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTokens.bad),
                title: const Text('Elimina',
                    style: TextStyle(color: AppTokens.bad)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(context, match);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Invito non bloccante: le presenze si bloccano alla conclusione e possono
  /// essere incomplete, quindi non si apre nulla d autorita.
  void _proponiIncasso(int matchId) {
    if (!context.read<AuthProvider>().puoGestireSoldi) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Partita conclusa. Vuoi registrare l\'incasso?'),
      duration: const Duration(seconds: 8),
      action: SnackBarAction(
        label: 'Registra incasso',
        onPressed: () => MatchIncassoSheet.show(context, matchId),
      ),
    ));
  }

  Future<void> _updateStato(
      BuildContext context, MatchModel match, String stato) async {
    final auth = context.read<AuthProvider>();
    final success = await context
        .read<MatchesProvider>()
        .updateStato(auth.teamId, match.id, stato);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stato aggiornato a $stato')));
      _loadData();
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
                decoration: const InputDecoration(labelText: 'Avversario'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dataCtrl,
                decoration: const InputDecoration(
                    labelText: 'Data',
                    suffixIcon: Icon(Icons.calendar_today)),
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
                decoration: const InputDecoration(labelText: 'Note'),
                maxLines: 2,
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
              if (selectedDate == null || giornatCtrl.text.isEmpty) return;
              final auth = context.read<AuthProvider>();
              final success = await context
                  .read<MatchesProvider>()
                  .updateMatch(auth.teamId, match.id, {
                'data': selectedDate!.toIso8601String(),
                'ora': oraCtrl.text,
                'luogo': luogoCtrl.text.isEmpty ? null : luogoCtrl.text,
                'titolo': titoloCtrl.text.isEmpty ? null : titoloCtrl.text,
                'numeroGiornata': int.tryParse(giornatCtrl.text) ?? 1,
                'note': noteCtrl.text.isEmpty ? null : noteCtrl.text,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (success && mounted) _loadData();
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
        content: Text('Vuoi eliminare "${match.displayTitle}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla')),
          FilledButton(
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              final success = await context
                  .read<MatchesProvider>()
                  .deleteMatch(auth.teamId, match.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (success && mounted) context.go('/calendar');
            },
            style: FilledButton.styleFrom(backgroundColor: AppTokens.bad),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final MatchModel match;
  final String teamInitials;
  final Color bgColor;
  final String formato;
  const _TicketCard({
    required this.match,
    required this.teamInitials,
    required this.bgColor,
    required this.formato,
  });

  @override
  Widget build(BuildContext context) {
    final opponent = (match.titolo ?? '').isNotEmpty
        ? match.titolo!.toUpperCase()
        : 'AVVERSARIO';
    final awayInitials = opponent.length >= 2
        ? opponent.substring(0, 2).toUpperCase()
        : opponent.toUpperCase();
    final dayName =
        DateFormat('EEEE', 'it_IT').format(match.data).toUpperCase();
    final day = DateFormat('d').format(match.data);
    final month =
        DateFormat('MMM y', 'it_IT').format(match.data).toUpperCase();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Dark top
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Container(
              color: AppTokens.ink,
              padding: const EdgeInsets.all(20),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.bottomCenter,
                            radius: 1.2,
                            colors: [
                              AppTokens.brand.withOpacity(0.18),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MATCH TICKET · #${match.numeroGiornata}',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.54,
                                    color: AppTokens.brand,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dayName,
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 30,
                                    height: 1,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                day,
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 38,
                                  height: 0.9,
                                  color: AppTokens.brand,
                                ),
                              ),
                              Text(
                                month,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 10,
                                  letterSpacing: 1.2,
                                  color: AppTokens.textOnInkMute,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      VsLayout(
                        homeCrest:
                            CrestBox(initials: teamInitials, size: 48, fontSize: 20, showTeamLogo: true),
                        homeName: context.watch<ThemeProvider>().teamName,
                        awayCrest: CrestBox(
                          initials: awayInitials,
                          filled: false,
                          size: 48,
                          fontSize: 18,
                        ),
                        awayName: opponent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Perforation
          _Perforation(bgColor: bgColor, topColor: AppTokens.ink),
          // White bottom
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: Container(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTokens.darkCard
                  : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: _ticketStat(context, 'ORA', match.ora)),
                      Expanded(
                          child: _ticketStat(
                              context, 'CAMPO', match.luogo ?? '—',
                              small: (match.luogo?.length ?? 0) > 4)),
                      Expanded(
                          child: _ticketStat(context, 'FORMATO', formato)),
                    ],
                  ),
                  if (match.luogo != null || match.note != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppTokens.darkLine
                                : AppTokens.line2,
                            style: BorderStyle.solid,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 14,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppTokens.darkTextMute
                                : AppTokens.textMute,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              match.luogo?.isNotEmpty == true
                                  ? match.luogo!
                                  : (match.note ?? ''),
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 12,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? AppTokens.darkTextMute
                                    : AppTokens.textMute,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ticketStat(BuildContext context, String label, String value,
      {bool small = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.3,
            color: muteColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.bebasNeue(
            fontSize: small ? 16 : 22,
            color: textColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _Perforation extends StatelessWidget {
  final Color bgColor;
  final Color topColor;
  const _Perforation({required this.bgColor, required this.topColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Stack(
        children: [
          // half circle cutouts on sides (match bg)
          Positioned(
            left: -11,
            top: 0,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: -11,
            top: 0,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          // dashed divider line between two colors
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 11,
              color: topColor,
            ),
          ),
          Positioned(
            top: 11,
            left: 0,
            right: 0,
            child: Container(
              height: 11,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTokens.darkCard
                  : Colors.white,
            ),
          ),
          Positioned(
            top: 10,
            left: 20,
            right: 20,
            child: _DashedLine(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.2)
                  : AppTokens.line2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  final Color color;
  const _DashedLine({required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final dashWidth = 4.0;
        final dashGap = 4.0;
        final count = (c.maxWidth / (dashWidth + dashGap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(count, (_) {
            return SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(decoration: BoxDecoration(color: color)),
            );
          }),
        );
      },
    );
  }
}

class _AvailabilitySummary extends StatelessWidget {
  final Map<String, dynamic>? availability;
  final MatchModel match;
  const _AvailabilitySummary({required this.availability, required this.match});

  @override
  Widget build(BuildContext context) {
    // Tre numeri della stessa natura: la disponibilita' dichiarata dalla rosa.
    // Le convocazioni hanno la loro sezione sotto, mischiarle qui confondeva.
    final int disp = availability?['disponibili'] as int? ?? 0;
    final int nonDisp = availability?['nonDisponibili'] as int? ?? 0;
    final int totale = availability?['totale'] as int? ?? (disp + nonDisp);
    final int inAttesa = (totale - disp - nonDisp).clamp(0, 999);

    return Row(
      children: [
        Expanded(
          child: _statCard(
            context,
            '$disp',
            'DISPONIBILI',
            AppTokens.ok,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            context,
            '$inAttesa',
            'SENZA RISPOSTA',
            AppTokens.warn,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            context,
            '$nonDisp',
            'NON DISPONIBILI',
            AppTokens.bad,
          ),
        ),
      ],
    );
  }

  Widget _statCard(BuildContext context, String value, String label, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTokens.darkCard : AppTokens.card;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lineColor),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.bebasNeue(fontSize: 32, color: color, height: 1),
          ),
          const SizedBox(height: 2),
          // Etichette lunghe ("NON DISPONIBILI") su tile stretti: si riducono, non sbordano
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: muteColor,
                letterSpacing: 0.9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityRow extends StatelessWidget {
  final String nome;
  final bool disponibile;
  final String? note;
  const _AvailabilityRow({
    required this.nome,
    required this.disponibile,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTokens.darkCard : AppTokens.card;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: lineColor),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTokens.softOf(disponibile ? AppTokens.ok : AppTokens.bad, isDark: isDark),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              disponibile ? Icons.check : Icons.close,
              size: 18,
              color: disponibile ? AppTokens.ok : AppTokens.bad,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nome,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                if (note != null && note!.isNotEmpty)
                  Text(
                    note!,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: muteColor,
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

class _ConvocationRow extends StatelessWidget {
  final dynamic conv;
  const _ConvocationRow({required this.conv});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTokens.darkCard : AppTokens.card;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;

    final name = conv.soprannome ?? conv.nomeGiocatore;
    final fullName = conv.nomeGiocatore;
    final stato = conv.statoRisposta as String;

    Color bg;
    Color fg;
    IconData icon;
    switch (stato) {
      case 'Confermato':
        bg = AppTokens.softOf(AppTokens.ok, isDark: isDark);
        fg = AppTokens.ok;
        icon = Icons.check;
        break;
      case 'NonDisponibile':
        bg = AppTokens.softOf(AppTokens.bad, isDark: isDark);
        fg = AppTokens.bad;
        icon = Icons.close;
        break;
      default:
        bg = AppTokens.softOf(AppTokens.warn, isDark: isDark);
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
          JerseyNumber(number: conv.numeroMaglia, bg: AppTokens.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                Text(
                  fullName,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    color: muteColor,
                  ),
                ),
              ],
            ),
          ),
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
}

class _ActionButtons extends StatelessWidget {
  final MatchModel match;
  final bool isAdmin;
  final VoidCallback onMatchDay;
  final VoidCallback onLive;
  final VoidCallback onConvocations;
  const _ActionButtons({
    required this.match,
    required this.isAdmin,
    required this.onMatchDay,
    required this.onLive,
    required this.onConvocations,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onConvocations,
            icon: const Icon(Icons.list, size: 18),
            label: const Text('Convocazioni'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 50),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: match.stato == 'InCorso' ? onLive : onMatchDay,
            icon: Icon(
              match.stato == 'InCorso' ? Icons.live_tv : Icons.sports,
              size: 18,
            ),
            label: Text(match.stato == 'InCorso' ? 'Live' : 'Match Day'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 50),
            ),
          ),
        ),
      ],
    );
  }
}
