import 'dart:typed_data';
import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/dashboard_provider.dart';
import '../core/constants/api_constants.dart';
import '../providers/matches_provider.dart';
import '../providers/players_provider.dart';
import '../providers/announcements_provider.dart';
import '../providers/club_provider.dart';
import '../providers/notifications_provider.dart';
import '../models/payment_model.dart';
import '../models/ruoli.dart';
import '../models/season_model.dart';
import '../models/team_format.dart';
import '../widgets/gimmy_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    final theme = context.read<ThemeProvider>();
    _nameCtrl = TextEditingController(text: theme.teamName);
    final auth = context.read<AuthProvider>();
    if (auth.teams == null) {
      auth.loadMyTeams();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTeamConfig();
      context.read<NotificationsProvider>().load();
    });
  }

  Future<void> _loadTeamConfig() async {
    final auth = context.read<AuthProvider>();
    if (auth.teamId == 0) return;
    final club = context.read<ClubProvider>();
    await club.loadFormats();
    await club.loadTeamConfig(auth.teamId);
    await club.loadSeasons(auth.teamId);
    await club.loadClubs(preferClubId: auth.currentClubId);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final completer = Completer<Uint8List?>();
    final input = web.document.createElement('input') as web.HTMLInputElement;
    input.type = 'file';
    input.accept = 'image/*';
    input.click();
    input.addEventListener('change', (web.Event event) {
      final files = input.files;
      if (files == null || files.length == 0) {
        completer.complete(null);
        return;
      }
      final file = files.item(0)!;
      final reader = web.FileReader();
      reader.readAsArrayBuffer(file);
      reader.addEventListener('loadend', (web.Event e) {
        final arrayBuffer = reader.result as JSArrayBuffer;
        final bytes = arrayBuffer.toDart.asUint8List();
        completer.complete(bytes);
      }.toJS);
    }.toJS);

    final bytes = await completer.future;
    if (bytes != null && mounted) {
      await context.read<ThemeProvider>().setLogo(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo caricato!')),
        );
      }
    }
  }

  void _resetAllProviders() {
    context.read<DashboardProvider>().reset();
    context.read<MatchesProvider>().reset();
    context.read<PlayersProvider>().reset();
    context.read<AnnouncementsProvider>().reset();
  }

  Future<void> _switchToTeam(int teamId) async {
    final auth = context.read<AuthProvider>();
    final success = await auth.switchTeam(teamId);
    if (success && mounted) {
      context.read<ThemeProvider>().setCurrentTeamId(auth.teamId);
      _resetAllProviders();
      context.go('/dashboard');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Errore nel cambio team')),
      );
    }
  }

  void _showEditProfileDialog() {
    final auth = context.read<AuthProvider>();
    final player = auth.currentPlayer;
    if (player == null) return;

    final nomeCtrl = TextEditingController(text: player.nome);
    final soprannomeCtrl = TextEditingController(text: player.soprannome ?? '');
    final telefonoCtrl = TextEditingController(text: player.telefono ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifica Profilo'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nomeCtrl,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Obbligatorio' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: soprannomeCtrl,
                  decoration: const InputDecoration(labelText: 'Soprannome'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: telefonoCtrl,
                  decoration: const InputDecoration(labelText: 'Telefono'),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annulla')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final success = await auth.updateMyProfile(
                nome: nomeCtrl.text.trim(),
                soprannome: soprannomeCtrl.text.trim(),
                telefono: telefonoCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success
                      ? 'Profilo aggiornato!'
                      : 'Errore aggiornamento'),
                ));
              }
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleUseGettoni(bool value) async {
    final auth = context.read<AuthProvider>();
    final club = context.read<ClubProvider>();
    final ok = await club.updateTeamConfig(teamId: auth.teamId, useGettoni: value);
    if (!mounted) return;
    if (ok) {
      context.read<DashboardProvider>().loadDashboard(auth.teamId);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(value ? 'Sistema gettoni attivato' : 'Sistema gettoni disattivato'),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(club.error ?? 'Errore nell aggiornamento')),
      );
    }
  }

  Future<void> _enableNotifications() async {
    final notifications = context.read<NotificationsProvider>();
    final ok = await notifications.enable();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Notifiche attivate su questo dispositivo'
          : notifications.error ?? 'Non e stato possibile attivare le notifiche'),
    ));
  }

  Future<void> _disableNotifications() async {
    final notifications = context.read<NotificationsProvider>();
    final ok = await notifications.disable();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Notifiche disattivate su questo dispositivo'
          : notifications.error ?? 'Errore nella disattivazione'),
    ));
  }

  Future<void> _toggleNotificationKind(String kind, bool enabled) async {
    final notifications = context.read<NotificationsProvider>();
    final ok = await notifications.setPreference(kind, enabled);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(notifications.error ?? 'Errore nel salvataggio')),
    );
  }

  Future<void> _sendTestNotification() async {
    final notifications = context.read<NotificationsProvider>();
    final message = await notifications.sendTest();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message ?? notifications.error ?? 'Errore nell invio'),
    ));
  }

  /// Regole e costi della squadra attiva. Il formato in cima: cambiarlo riallinea
  /// giocatori in campo, convocati e durata ai default della nuova disciplina.
  /// Chiusura stagione: azzera i contatori di tutti, quindi si chiede conferma
  /// una volta e, se il server segnala arretrati, una seconda volta esplicita.
  Future<void> _showCloseSeasonDialog() async {
    final auth = context.read<AuthProvider>();
    final club = context.read<ClubProvider>();
    final corrente = club.stagioneCorrente;
    if (corrente == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessuna stagione aperta')),
      );
      return;
    }

    final nomeCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    var busy = false;

    final conferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final cs = Theme.of(ctx).colorScheme;
          return AlertDialog(
            title: Text('Chiudi ${corrente.nome}'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Partite e pagamenti della stagione restano consultabili '
                    'nell archivio. Per tutti i giocatori vengono azzerati '
                    'gettoni, iscrizione e tesseramento.',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nomeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome nuova stagione',
                      hintText: 'Lascia vuoto per calcolarlo (es. 2026/27)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Note sulla stagione che chiudi',
                    ),
                  ),
                  if (corrente.daIncassare > 0) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 18, color: cs.error),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Ci sono ancora ${formatEuro(corrente.daIncassare)} da incassare.',
                            style: TextStyle(fontSize: 12, color: cs.error),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.of(ctx).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () {
                        setDialogState(() => busy = true);
                        Navigator.of(ctx).pop(true);
                      },
                child: const Text('Chiudi stagione'),
              ),
            ],
          );
        },
      ),
    );

    if (conferma != true || !mounted) return;

    var result = await club.closeSeason(
      teamId: auth.teamId,
      nomeNuovaStagione: nomeCtrl.text.trim(),
      note: noteCtrl.text.trim(),
    );

    // Il rifiuto per arretrati e' l unico che vale la pena ritentare: si mostra
    // il motivo del server e si chiede il condono in modo esplicito.
    if (result == null && mounted && club.error != null) {
      final forza = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Chiudere comunque?'),
          content: Text('${club.error}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('No, torna indietro'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Chiudi e condona'),
            ),
          ],
        ),
      );

      if (forza == true && mounted) {
        result = await club.closeSeason(
          teamId: auth.teamId,
          nomeNuovaStagione: nomeCtrl.text.trim(),
          note: noteCtrl.text.trim(),
          ignoraArretrati: true,
        );
      }
    }

    if (!mounted) return;

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(club.error ?? 'Stagione non chiusa')),
      );
      return;
    }

    // I gettoni e i flag quota sono cambiati per tutta la rosa
    context.read<PlayersProvider>().reset();
    context.read<MatchesProvider>().reset();
    context.read<DashboardProvider>().loadDashboard(auth.teamId);
    await club.loadTeamConfig(auth.teamId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Stagione ${result.stagioneChiusa} chiusa, aperta ${result.stagioneNuova}. '
          '${result.giocatoriAzzerati} giocatori azzerati.',
        ),
      ),
    );
  }

  Future<void> _showTeamRulesDialog() async {
    final auth = context.read<AuthProvider>();
    final club = context.read<ClubProvider>();
    final config = club.teamConfig ?? await club.loadTeamConfig(auth.teamId);
    if (!mounted || config == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(club.error ?? 'Configurazione non disponibile')),
        );
      }
      return;
    }

    final nomeCtrl = TextEditingController(text: config.nome);
    final partiteCtrl = TextEditingController(text: '${config.partitePerStagione}');
    final gettoniCtrl = TextEditingController(text: '${config.gettoniPerGiocatore}');
    final inCampoCtrl = TextEditingController(text: '${config.giocatoriInCampo}');
    final convocatiCtrl = TextEditingController(text: '${config.maxConvocati ?? 0}');
    final minutiCtrl = TextEditingController(text: '${config.minutiPerTempo}');
    final tempiCtrl = TextEditingController(text: '${config.numeroTempi}');
    final iscrizioneCtrl = TextEditingController(text: _euro(config.quotaIscrizione));
    final tesseramentoCtrl = TextEditingController(text: _euro(config.quotaTesseramento));
    final costoPartitaCtrl = TextEditingController(text: _euro(config.costoPartita));

    final minutiMinimiCtrl =
        TextEditingController(text: '${config.minutiMinimiPerAddebito}');
    final promemoriaCtrl =
        TextEditingController(text: '${config.orePromemoriaPartita}');

    var formato = config.formato;
    var useGettoni = config.useGettoni;
    var regimeDefault = config.regimePagamentoDefault;
    var applicaIscrizione = config.applicaIscrizioneA;
    var applicaTesseramento = config.applicaTesseramentoA;
    var busy = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final info = club.formatInfo(formato);
          final cs = Theme.of(ctx).colorScheme;
          return AlertDialog(
            title: const Text('Regole e costi'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nomeCtrl,
                    decoration: const InputDecoration(labelText: 'Nome squadra'),
                  ),
                  const SizedBox(height: 16),
                  const Text('Formato', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: TeamFormat.values
                        .map((f) => ChoiceChip(
                              label: Text(f.shortLabel),
                              selected: formato == f,
                              onSelected: (_) => setDialogState(() {
                                formato = f;
                                final preset = club.formatInfo(f);
                                inCampoCtrl.text = '${preset.giocatoriInCampo}';
                                convocatiCtrl.text = '${preset.maxConvocati}';
                                minutiCtrl.text = '${preset.minutiPerTempo}';
                                tempiCtrl.text = '${preset.numeroTempi}';
                              }),
                            ))
                        .toList(),
                  ),
                  if (formato != config.formato) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Passando a ${info.label} i ruoli non previsti (per esempio Pivot) '
                      'vengono azzerati sui giocatori.',
                      style: TextStyle(fontSize: 12, color: cs.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text('Regole di gioco', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    controller: inCampoCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Giocatori in campo'),
                  ),
                  TextField(
                    controller: convocatiCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max convocati per partita',
                      helperText: '0 = nessun limite',
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: tempiCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Tempi'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: minutiCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Minuti per tempo'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: partiteCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Partite per stagione'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sistema gettoni'),
                    value: useGettoni,
                    onChanged: (v) => setDialogState(() => useGettoni = v),
                  ),
                  if (useGettoni)
                    TextField(
                      controller: gettoniCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Gettoni per giocatore'),
                    ),
                  const SizedBox(height: 16),
                  const Text('Costi (EUR)', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    controller: iscrizioneCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quota iscrizione'),
                  ),
                  TextField(
                    controller: tesseramentoCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quota tesseramento'),
                  ),
                  TextField(
                    controller: costoPartitaCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Costo a partita',
                      helperText: 'Addebitato a chi paga a partita',
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('Come pagano', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Vale per chi non ha una scelta personale. Il singolo si cambia dalla Rosa.',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: RegimePagamento.values
                        .map((r) => ChoiceChip(
                              label: Text(r.label),
                              selected: regimeDefault == r,
                              onSelected: (_) => setDialogState(() => regimeDefault = r),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: minutiMinimiCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Minuti minimi per l addebito',
                      helperText: '0 = basta essere scesi in campo',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Chi deve le quote fisse',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  _DestinatariRow(
                    label: 'Iscrizione',
                    valore: applicaIscrizione,
                    onChanged: (v) => setDialogState(() => applicaIscrizione = v),
                  ),
                  _DestinatariRow(
                    label: 'Tesseramento',
                    valore: applicaTesseramento,
                    onChanged: (v) => setDialogState(() => applicaTesseramento = v),
                  ),
                  const SizedBox(height: 18),
                  const Text('Promemoria partita',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Arriva ai convocati: un sollecito a chi non ha risposto, '
                    'un promemoria a chi ha confermato.',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: promemoriaCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Ore prima della partita',
                      helperText: '0 = nessun promemoria',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.of(ctx).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        setDialogState(() => busy = true);
                        final ok = await club.updateTeamConfig(
                          teamId: auth.teamId,
                          nome: nomeCtrl.text.trim().isEmpty ? null : nomeCtrl.text.trim(),
                          formato: formato,
                          partitePerStagione: int.tryParse(partiteCtrl.text),
                          useGettoni: useGettoni,
                          gettoniPerGiocatore: int.tryParse(gettoniCtrl.text),
                          giocatoriInCampo: int.tryParse(inCampoCtrl.text),
                          maxConvocati: int.tryParse(convocatiCtrl.text),
                          minutiPerTempo: int.tryParse(minutiCtrl.text),
                          numeroTempi: int.tryParse(tempiCtrl.text),
                          quotaIscrizione: _parseEuro(iscrizioneCtrl.text),
                          quotaTesseramento: _parseEuro(tesseramentoCtrl.text),
                          costoPartita: _parseEuro(costoPartitaCtrl.text),
                          regimePagamentoDefault: regimeDefault,
                          applicaIscrizioneA: applicaIscrizione,
                          applicaTesseramentoA: applicaTesseramento,
                          minutiMinimiPerAddebito:
                              int.tryParse(minutiMinimiCtrl.text) ?? 0,
                          orePromemoriaPartita:
                              int.tryParse(promemoriaCtrl.text) ?? 0,
                        );
                        if (!ctx.mounted) return;
                        setDialogState(() => busy = false);
                        if (ok) {
                          Navigator.of(ctx).pop(true);
                        } else {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(club.error ?? 'Errore nel salvataggio')),
                          );
                        }
                      },
                child: busy
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Salva'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true && mounted) {
      await context.read<AuthProvider>().loadMyTeams();
      if (mounted) {
        context.read<DashboardProvider>().loadDashboard(auth.teamId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurazione aggiornata')),
        );
      }
    }
  }

  /// PayPal e IBAN della squadra. Sono un override: lasciando i campi vuoti
  /// valgono quelli della societa, che e il caso normale.
  Future<void> _showPaymentInfoDialog() async {
    final auth = context.read<AuthProvider>();
    final club = context.read<ClubProvider>();
    final config = club.teamConfig;
    if (config == null) return;

    final paypalCtrl = TextEditingController(text: config.paypalLink ?? '');
    final ibanCtrl = TextEditingController(text: config.iban ?? '');
    final intestatarioCtrl = TextEditingController(text: config.intestatarioIban ?? '');
    var busy = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final cs = Theme.of(ctx).colorScheme;
          return AlertDialog(
            title: const Text('Dati di pagamento'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Se lasci vuoto vale quello della societa. Compila solo se questa '
                    'squadra ha un conto suo.',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: paypalCtrl,
                    decoration: InputDecoration(
                      labelText: 'Link PayPal',
                      hintText: config.paypalLinkEffettivo ?? 'https://paypal.me/...',
                    ),
                  ),
                  TextField(
                    controller: ibanCtrl,
                    decoration: InputDecoration(
                      labelText: 'IBAN',
                      hintText: config.ibanEffettivo ?? 'IT...',
                    ),
                  ),
                  TextField(
                    controller: intestatarioCtrl,
                    decoration: InputDecoration(
                      labelText: 'Intestatario',
                      hintText: config.intestatarioIbanEffettivo ?? 'Nome sul conto',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.of(ctx).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        setDialogState(() => busy = true);
                        final ok = await club.updateTeamConfig(
                          teamId: auth.teamId,
                          // Stringa vuota = azzera l override
                          paypalLink: paypalCtrl.text.trim(),
                          iban: ibanCtrl.text.trim(),
                          intestatarioIban: intestatarioCtrl.text.trim(),
                        );
                        if (!ctx.mounted) return;
                        setDialogState(() => busy = false);
                        if (ok) {
                          Navigator.of(ctx).pop(true);
                        } else {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(club.error ?? 'Errore nel salvataggio')),
                          );
                        }
                      },
                child: busy
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Salva'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dati di pagamento aggiornati')),
      );
    }
  }

  /// Crea le voci in Pagamenti per le quote configurate sulla squadra.
  Future<void> _generateFees() async {
    final auth = context.read<AuthProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Genera quote'),
        content: const Text(
          'Crea in Pagamenti una voce di iscrizione e una di tesseramento per ogni '
          'giocatore, con gli importi configurati su questa squadra. '
          'Rilanciarla non crea duplicati.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Genera')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final response = await auth.apiClient.dio.post(
        ApiConstants.generatePayments(auth.teamId),
        data: {'iscrizione': true, 'tesseramento': true, 'aggiornaEsistenti': true},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(response.data['message'] as String? ?? 'Quote generate'),
      ));
    } on DioException catch (e) {
      if (!mounted) return;
      final message =
          e.response?.data is Map ? (e.response!.data as Map)['message'] as String? : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message ?? 'Errore nella generazione delle quote')),
      );
    }
  }

  static String _euro(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

  static double _parseEuro(String raw) => double.tryParse(raw.replaceAll(',', '.')) ?? 0;

  /// Crea una squadra. Se l'utente amministra gia' una societa' puo' agganciarla
  /// a quella (e' il caso "la mia societa' ha anche la squadra a 7"), altrimenti
  /// nasce una societa' nuova insieme alla squadra.
  void _showCreateTeamDialog() {
    final club = context.read<ClubProvider>();
    final nomeTeamCtrl = TextEditingController();
    final nomeSocietaCtrl = TextEditingController();
    final nomeGiocatoreCtrl = TextEditingController();
    final soprannomeCtrl = TextEditingController();
    final partiteCtrl = TextEditingController(text: '8');
    final gettoniCtrl = TextEditingController(text: '4');
    final iscrizioneCtrl = TextEditingController(text: '0');
    final tesseramentoCtrl = TextEditingController(text: '0');
    final costoPartitaCtrl = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();

    final societaAmministrate = club.clubs.where((c) => c.isAdmin).toList();
    int? clubId = societaAmministrate.isNotEmpty ? societaAmministrate.first.id : null;
    var formato = TeamFormat.calcioA5;
    var useGettoniValue = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final info = club.formatInfo(formato);
          final cs = Theme.of(ctx).colorScheme;
          return AlertDialog(
            title: const Text('Crea nuova squadra'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (societaAmministrate.isNotEmpty) ...[
                      const Text('Societa', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int?>(
                        // `value` e non `initialValue`: l'SDK pinnato e Flutter 3.27
                        value: clubId,
                        isExpanded: true,
                        items: [
                          ...societaAmministrate.map((c) => DropdownMenuItem<int?>(
                                value: c.id,
                                child: Text('${c.nome} (${c.squadre.length} squadre)'),
                              )),
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Nuova societa'),
                          ),
                        ],
                        onChanged: (v) => setDialogState(() => clubId = v),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        clubId == null
                            ? 'La squadra avra una societa tutta sua.'
                            : 'La squadra condividera l anagrafica con le altre della societa.',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (clubId == null)
                      TextFormField(
                        controller: nomeSocietaCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome societa (opzionale)',
                          helperText: 'Se vuoto viene usato il nome della squadra',
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nomeTeamCtrl,
                      decoration: const InputDecoration(labelText: 'Nome squadra'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Obbligatorio' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('Formato', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: TeamFormat.values
                          .map((f) => ChoiceChip(
                                label: Text(f.shortLabel),
                                selected: formato == f,
                                onSelected: (_) => setDialogState(() => formato = f),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${info.label}: ${info.giocatoriInCampo} in campo, '
                      'max ${info.maxConvocati} convocati, '
                      '${info.numeroTempi}x${info.minutiPerTempo} minuti.',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nomeGiocatoreCtrl,
                      decoration: const InputDecoration(labelText: 'Il tuo nome'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Obbligatorio' : null,
                    ),
                    TextFormField(
                      controller: soprannomeCtrl,
                      decoration: const InputDecoration(labelText: 'Soprannome'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: partiteCtrl,
                      decoration: const InputDecoration(labelText: 'Partite per stagione'),
                      keyboardType: TextInputType.number,
                    ),
                    SwitchListTile(
                      title: const Text('Sistema gettoni'),
                      value: useGettoniValue,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => setDialogState(() => useGettoniValue = v),
                    ),
                    if (useGettoniValue)
                      TextFormField(
                        controller: gettoniCtrl,
                        decoration: const InputDecoration(labelText: 'Gettoni per giocatore'),
                        keyboardType: TextInputType.number,
                      ),
                    const SizedBox(height: 16),
                    const Text('Costi (EUR)', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextFormField(
                      controller: iscrizioneCtrl,
                      decoration: const InputDecoration(labelText: 'Quota iscrizione'),
                      keyboardType: TextInputType.number,
                    ),
                    TextFormField(
                      controller: tesseramentoCtrl,
                      decoration: const InputDecoration(labelText: 'Quota tesseramento'),
                      keyboardType: TextInputType.number,
                    ),
                    TextFormField(
                      controller: costoPartitaCtrl,
                      decoration: const InputDecoration(labelText: 'Costo a partita'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Annulla')),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final auth = context.read<AuthProvider>();
                  final success = await auth.createTeam(
                    nomeTeam: nomeTeamCtrl.text.trim(),
                    nomeGiocatore: nomeGiocatoreCtrl.text.trim(),
                    soprannome: soprannomeCtrl.text.trim(),
                    formato: formato,
                    clubId: clubId,
                    nomeSocieta: nomeSocietaCtrl.text.trim(),
                    partitePerStagione: int.tryParse(partiteCtrl.text) ?? 8,
                    gettoniPerGiocatore:
                        useGettoniValue ? (int.tryParse(gettoniCtrl.text) ?? 4) : 0,
                    useGettoni: useGettoniValue,
                    quotaIscrizione: _parseEuro(iscrizioneCtrl.text),
                    quotaTesseramento: _parseEuro(tesseramentoCtrl.text),
                    costoPartita: _parseEuro(costoPartitaCtrl.text),
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (success && mounted) {
                    context.read<ThemeProvider>().setCurrentTeamId(auth.teamId);
                    _resetAllProviders();
                    context.go('/dashboard');
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(auth.error ?? 'Errore nella creazione')),
                    );
                  }
                },
                child: const Text('Crea'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Un codice puo' essere di una squadra o di una societa': nel secondo caso
  /// si sceglie a quale squadra unirsi.
  void _showJoinTeamDialog() {
    final codeCtrl = TextEditingController();
    final nomeCtrl = TextEditingController();
    final soprannomeCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    List<Map<String, dynamic>> squadre = const [];
    String? nomeSocieta;
    int? teamId;
    var verificando = false;
    var verificato = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final cs = Theme.of(ctx).colorScheme;

          Future<void> verifica() async {
            final code = codeCtrl.text.trim();
            if (code.isEmpty) return;
            setDialogState(() => verificando = true);

            final info = await context.read<AuthProvider>().getJoinInfo(code);
            if (!ctx.mounted) return;

            setDialogState(() {
              verificando = false;
              verificato = info != null;
              nomeSocieta = info?['clubName'] as String?;
              squadre = ((info?['teams'] as List?) ?? const [])
                  .cast<Map<String, dynamic>>()
                  .toList();
              teamId = squadre.length == 1 ? squadre.first['teamId'] as int? : null;
            });

            if (info == null) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Codice non valido')),
              );
            }
          }

          return AlertDialog(
            title: const Text('Unisciti con codice'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: codeCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Codice invito',
                              helperText: 'Di una squadra o della societa',
                            ),
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Obbligatorio' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        verificando
                            ? const SizedBox(
                                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : TextButton(onPressed: verifica, child: const Text('Verifica')),
                      ],
                    ),
                    if (verificato && squadre.length > 1) ...[
                      const SizedBox(height: 12),
                      Text(
                        nomeSocieta != null
                            ? 'Squadre di $nomeSocieta'
                            : 'Scegli la squadra',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      ...squadre.map((t) => RadioListTile<int>(
                            contentPadding: EdgeInsets.zero,
                            value: t['teamId'] as int,
                            groupValue: teamId,
                            title: Text(t['nome'] as String? ?? ''),
                            subtitle: Text(
                              '${t['formatoLabel'] ?? ''} · ${t['totaleGiocatori'] ?? 0} in rosa',
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                            ),
                            onChanged: (v) => setDialogState(() => teamId = v),
                          )),
                    ] else if (verificato && squadre.length == 1) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Ti unisci a ${squadre.first['nome']} (${squadre.first['formatoLabel'] ?? ''})',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nomeCtrl,
                      decoration: const InputDecoration(labelText: 'Nome'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Obbligatorio' : null,
                    ),
                    TextFormField(
                      controller: soprannomeCtrl,
                      decoration: const InputDecoration(labelText: 'Soprannome'),
                    ),
                    TextFormField(
                      controller: telefonoCtrl,
                      decoration: const InputDecoration(labelText: 'Telefono'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Annulla')),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  if (squadre.length > 1 && teamId == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Scegli a quale squadra unirti')),
                    );
                    return;
                  }
                  final auth = context.read<AuthProvider>();
                  final success = await auth.joinTeam(
                    inviteCode: codeCtrl.text.trim(),
                    nome: nomeCtrl.text.trim(),
                    soprannome: soprannomeCtrl.text.trim(),
                    telefono: telefonoCtrl.text.trim(),
                    teamId: teamId,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (success && mounted) {
                    context.read<ThemeProvider>().setCurrentTeamId(auth.teamId);
                    _resetAllProviders();
                    context.go('/dashboard');
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(auth.error ?? 'Errore')),
                    );
                  }
                },
                child: const Text('Unisciti'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showInviteCode() async {
    final auth = context.read<AuthProvider>();
    final code = await auth.getInviteCode();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Codice Invito'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Condividi questo codice:',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: GimmyTokens.brandSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    code ?? 'N/A',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 28,
                      letterSpacing: 4,
                      color: GimmyTokens.brandInk,
                    ),
                  ),
                  if (code != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Codice copiato!')),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paper = isDark ? GimmyTokens.darkPaper : GimmyTokens.paper;
    final theme = context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();
    final teams = auth.teams ?? [];
    final currentTeamId = auth.teamId;
    final initials = teamInitials(theme.teamName, fallback: 'CA');
    final clubConfig = context.watch<ClubProvider>().teamConfig;

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
            GimmyTopBar(
              teamInitials: initials,
              title: 'Impostazioni',
              subtitle: 'Team + account',
              onBack: () => context.go('/dashboard'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 20),
                children: [
                  // PROFILO
                  const _Head(text: 'PROFILO'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: _ProfileCard(
                      onEdit: _showEditProfileDialog,
                    ),
                  ),

                  // NOTIFICHE
                  const _Head(text: 'NOTIFICHE'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: _NotificationsCard(
                      provider: context.watch<NotificationsProvider>(),
                      onEnable: _enableNotifications,
                      onDisable: _disableNotifications,
                      onTogglePreference: _toggleNotificationKind,
                      onTest: _sendTestNotification,
                    ),
                  ),

                  // I MIEI TEAM
                  const _Head(text: 'I MIEI TEAM'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: _TeamsCard(
                      teams: teams,
                      currentTeamId: currentTeamId,
                      isAdmin: auth.puoGestireSquadra,
                      onSwitch: _switchToTeam,
                      onCreate: _showCreateTeamDialog,
                      onJoin: _showJoinTeamDialog,
                      onInvite: _showInviteCode,
                      onDraft: () => context.go('/draft'),
                    ),
                  ),

                  // SOCIETA
                  if (clubConfig?.clubId != null) ...[
                    const _Head(text: 'SOCIETA'),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: _CardShell(
                        child: ListTile(
                          leading: const Icon(Icons.shield_outlined, color: GimmyTokens.brand),
                          title: Text(
                            clubConfig!.clubNome ?? 'Societa',
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            'Squadre, anagrafica condivisa, codice invito',
                            style: GoogleFonts.spaceGrotesk(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.go('/club'),
                        ),
                      ),
                    ),
                  ],

                  // CONFIG TEAM (admin)
                  if (auth.puoGestireSquadra) ...[
                    const _Head(text: 'CONFIGURAZIONE TEAM'),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: _ConfigCard(
                        config: context.watch<ClubProvider>().teamConfig,
                        useGettoni: context.watch<DashboardProvider>().useGettoni,
                        onToggleGettoni: _toggleUseGettoni,
                        onEditRules: _showTeamRulesDialog,
                        onGenerateFees: _generateFees,
                      ),
                    ),
                  ],

                  // STAGIONE
                  const _Head(text: 'STAGIONE'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: _SeasonCard(
                      seasons: context.watch<ClubProvider>().seasons,
                      vedeIConti: auth.puoGestireSoldi,
                      puoChiudere: auth.puoGestireSquadra,
                      onClose: _showCloseSeasonDialog,
                    ),
                  ),

                  // PAGAMENTI: l'elenco lo vedono tutti (ognuno il suo),
                  // i dati per incassare solo cassiere e admin
                  const _Head(text: 'PAGAMENTI'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: _CardShell(
                      child: ListTile(
                        leading: const Icon(Icons.account_balance_wallet_outlined,
                            color: GimmyTokens.brand),
                        title: Text(
                          auth.puoGestireSoldi ? 'Cassa' : 'I miei pagamenti',
                          style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text(
                          auth.puoGestireSoldi
                              ? 'Quote, addebiti partita e solleciti'
                              : 'Quote e partite da saldare',
                          style: GoogleFonts.spaceGrotesk(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go('/payments'),
                      ),
                    ),
                  ),
                  if (auth.puoGestireSoldi)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: _PaymentInfoSettingsCard(
                        config: clubConfig,
                        onEdit: _showPaymentInfoDialog,
                        onOpenClub: () => context.go('/club'),
                      ),
                    ),

                  // PERSONALIZZAZIONE
                  const _Head(text: 'BRAND'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: _BrandCard(
                      isDark: theme.isDark,
                      onToggleDark: theme.setDarkMode,
                      hasLogo: theme.hasLogo,
                      logoBytes: theme.logoBytes,
                      teamName: theme.teamName,
                      teamNameCtrl: _nameCtrl,
                      primaryColor: theme.primaryColor,
                      onPickLogo: _pickLogo,
                      onRemoveLogo: () async {
                        await theme.removeLogo();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Logo rimosso')),
                          );
                        }
                      },
                      onSaveName: () {
                        if (_nameCtrl.text.trim().isNotEmpty) {
                          theme.setTeamName(_nameCtrl.text.trim());
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nome aggiornato!')),
                          );
                        }
                      },
                      onColorPick: theme.setPrimaryColor,
                    ),
                  ),

                  // ACCOUNT
                  const _Head(text: 'ACCOUNT'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: _AccountCard(
                      onLogout: () async {
                        await auth.logout();
                        if (context.mounted) context.go('/login');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  final String text;
  const _Head({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? GimmyTokens.darkText : GimmyTokens.text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        text,
        style: GoogleFonts.bebasNeue(
          fontSize: 18,
          color: color,
          letterSpacing: 0.04 * 18,
        ),
      ),
    );
  }
}

/// Notifiche push. Su iPhone il passaggio obbligato e' l'installazione in
/// schermata Home: senza quella Safari rifiuta la subscription, quindi la card
/// mostra le istruzioni invece di un interruttore che fallirebbe.
class _NotificationsCard extends StatelessWidget {
  final NotificationsProvider provider;
  final VoidCallback onEnable;
  final VoidCallback onDisable;
  final void Function(String kind, bool enabled) onTogglePreference;
  final VoidCallback onTest;

  const _NotificationsCard({
    required this.provider,
    required this.onEnable,
    required this.onDisable,
    required this.onTogglePreference,
    required this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? GimmyTokens.darkText : GimmyTokens.text;
    final muteColor = isDark ? GimmyTokens.darkTextMute : GimmyTokens.textMute;
    final lineColor = isDark ? GimmyTokens.darkLine : GimmyTokens.line;
    final env = provider.environment;

    if (provider.isLoading) {
      return const _CardShell(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (!env.supported) {
      return _CardShell(
        child: _info(
          context,
          Icons.notifications_off_outlined,
          'Non disponibili',
          'Questo browser non supporta le notifiche web.',
        ),
      );
    }

    if (!provider.serverEnabled) {
      return _CardShell(
        child: _info(
          context,
          Icons.notifications_paused_outlined,
          'Non configurate',
          'Il server non ha ancora le chiavi per inviare le notifiche.',
        ),
      );
    }

    if (env.needsHomeScreenInstall) {
      return _CardShell(child: _IosInstallHint(muteColor: muteColor, textColor: textColor));
    }

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            secondary: Icon(
              provider.attiveQui ? Icons.notifications_active : Icons.notifications_none,
              color: GimmyTokens.brand,
            ),
            title: Text(
              'Notifiche su questo dispositivo',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: textColor,
              ),
            ),
            subtitle: Text(
              provider.attiveQui
                  ? (provider.dispositiviRegistrati > 1
                      ? 'Attive · ${provider.dispositiviRegistrati} dispositivi collegati'
                      : 'Attive')
                  : env.isDenied
                      ? 'Bloccate dal browser: riattivale dalle sue impostazioni'
                      : 'Disattivate',
              style: GoogleFonts.spaceGrotesk(fontSize: 12, color: muteColor),
            ),
            value: provider.attiveQui,
            onChanged: provider.isBusy || (env.isDenied && !provider.attiveQui)
                ? null
                : (v) {
                    if (v) {
                      onEnable();
                    } else {
                      onDisable();
                    }
                  },
          ),
          if (provider.isBusy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (provider.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                provider.error!,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          if (provider.attiveQui) ...[
            Divider(height: 1, color: lineColor),
            ...provider.tipi.map((tipo) => SwitchListTile(
                  dense: true,
                  title: Text(
                    tipo.label,
                    style: GoogleFonts.spaceGrotesk(fontSize: 13, color: textColor),
                  ),
                  subtitle: tipo.descrizione.isEmpty
                      ? null
                      : Text(
                          tipo.descrizione,
                          style: GoogleFonts.spaceGrotesk(fontSize: 11, color: muteColor),
                        ),
                  value: tipo.attiva,
                  onChanged: (v) => onTogglePreference(tipo.valore, v),
                )),
            Divider(height: 1, color: lineColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: provider.isBusy ? null : onTest,
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Invia notifica di prova'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _info(BuildContext context, IconData icon, String titolo, String testo) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(icon, color: isDark ? GimmyTokens.darkTextMute : GimmyTokens.textMute),
      title: Text(
        titolo,
        style: GoogleFonts.spaceGrotesk(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: isDark ? GimmyTokens.darkText : GimmyTokens.text,
        ),
      ),
      subtitle: Text(
        testo,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 12,
          color: isDark ? GimmyTokens.darkTextMute : GimmyTokens.textMute,
        ),
      ),
    );
  }
}

/// Istruzioni per iOS: e' l'unico modo di ricevere notifiche su iPhone.
class _IosInstallHint extends StatelessWidget {
  final Color muteColor;
  final Color textColor;

  const _IosInstallHint({required this.muteColor, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.ios_share, color: GimmyTokens.brand),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Aggiungi l app alla Home',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Su iPhone le notifiche arrivano solo se apri l app dall icona in schermata Home. '
            'Serve iOS 16.4 o piu recente.',
            style: GoogleFonts.spaceGrotesk(fontSize: 12, color: muteColor),
          ),
          const SizedBox(height: 12),
          _step(1, 'In Safari tocca il tasto Condividi (il quadrato con la freccia in su)'),
          _step(2, 'Scorri e scegli "Aggiungi a schermata Home"'),
          _step(3, 'Apri l app dalla nuova icona e torna qui: troverai l interruttore'),
        ],
      ),
    );
  }

  Widget _step(int numero, String testo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: GimmyTokens.brand,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              '$numero',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: GimmyTokens.brandInk,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              testo,
              style: GoogleFonts.spaceGrotesk(fontSize: 12, color: muteColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinatariRow extends StatelessWidget {
  final String label;
  final DestinatariQuota valore;
  final ValueChanged<DestinatariQuota> onChanged;

  const _DestinatariRow({
    required this.label,
    required this.valore,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: Wrap(
              spacing: 6,
              children: DestinatariQuota.values
                  .map((d) => ChoiceChip(
                        label: Text(d.label, style: const TextStyle(fontSize: 11)),
                        selected: valore == d,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => onChanged(d),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Riquadro coi dati per pagare, con l'indicazione di dove arrivano.
class _PaymentInfoSettingsCard extends StatelessWidget {
  final TeamConfig? config;
  final VoidCallback onEdit;
  final VoidCallback onOpenClub;

  const _PaymentInfoSettingsCard({
    required this.config,
    required this.onEdit,
    required this.onOpenClub,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? GimmyTokens.darkText : GimmyTokens.text;
    final muteColor = isDark ? GimmyTokens.darkTextMute : GimmyTokens.textMute;
    final lineColor = isDark ? GimmyTokens.darkLine : GimmyTokens.line;
    final cfg = config;

    // Dire da dove arriva il dato evita la domanda "perche non riesco a cambiarlo qui"
    String provenienza(String? proprio, String? effettivo) {
      if (effettivo == null || effettivo.isEmpty) return 'da impostare';
      return (proprio != null && proprio.isNotEmpty) ? 'squadra' : 'societa';
    }

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.account_balance_outlined, color: GimmyTokens.brand),
            title: Text(
              'Come farsi pagare',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              cfg == null
                  ? '-'
                  : 'PayPal: ${cfg.paypalLinkEffettivo ?? "non impostato"}'
                      ' (${provenienza(cfg.paypalLink, cfg.paypalLinkEffettivo)})'
                      '\nIBAN: ${cfg.ibanEffettivo ?? "non impostato"}'
                      ' (${provenienza(cfg.iban, cfg.ibanEffettivo)})',
              style: GoogleFonts.spaceGrotesk(fontSize: 12, color: muteColor),
            ),
            isThreeLine: cfg != null,
            trailing: TextButton(onPressed: onEdit, child: const Text('Modifica')),
          ),
          Divider(height: 1, color: lineColor),
          ListTile(
            dense: true,
            leading: Icon(Icons.shield_outlined, color: muteColor, size: 20),
            title: Text(
              'Imposta i dati per tutta la societa',
              style: GoogleFonts.spaceGrotesk(fontSize: 13, color: textColor),
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: onOpenClub,
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _CardShell({
    required this.child,
    this.padding = const EdgeInsets.all(0),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? GimmyTokens.darkCard : GimmyTokens.card;
    final lineColor = isDark ? GimmyTokens.darkLine : GimmyTokens.line;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lineColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final VoidCallback onEdit;
  const _ProfileCard({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? GimmyTokens.darkText : GimmyTokens.text;
    final muteColor = isDark ? GimmyTokens.darkTextMute : GimmyTokens.textMute;
    final auth = context.watch<AuthProvider>();
    final player = auth.currentPlayer;

    return _CardShell(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              JerseyNumber(
                size: 56,
                fontSize: 24,
                radius: 14,
                bg: GimmyTokens.ink,
                fg: GimmyTokens.brand,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      player?.nome ?? 'Utente',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                    if ((player?.soprannome ?? '').isNotEmpty)
                      Text(
                        '"${player!.soprannome}"',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: muteColor,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        GimmyChip(
                          text: (player?.ruolo ?? 'User') == 'User'
                              ? 'GIOCATORE'
                              : labelRuolo(player?.ruolo).toUpperCase(),
                          variant: auth.isAdmin
                              ? GimmyChipVariant.brand
                              : (auth.puoGestireCampo || auth.puoGestireSoldi)
                                  ? GimmyChipVariant.ok
                                  : GimmyChipVariant.dark,
                          fontSize: 9,
                        ),
                        if ((player?.telefono ?? '').isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            player!.telefono!,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              color: muteColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined, size: 18, color: muteColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamsCard extends StatelessWidget {
  final List teams;
  final int currentTeamId;
  final bool isAdmin;
  final void Function(int) onSwitch;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final VoidCallback onInvite;
  final VoidCallback onDraft;

  const _TeamsCard({
    required this.teams,
    required this.currentTeamId,
    required this.isAdmin,
    required this.onSwitch,
    required this.onCreate,
    required this.onJoin,
    required this.onInvite,
    required this.onDraft,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lineColor = isDark ? GimmyTokens.darkLine : GimmyTokens.line;
    final textColor = isDark ? GimmyTokens.darkText : GimmyTokens.text;
    final muteColor = isDark ? GimmyTokens.darkTextMute : GimmyTokens.textMute;
    final faintColor = isDark
        ? GimmyTokens.darkTextMute.withOpacity(0.5)
        : GimmyTokens.textFaint;

    return _CardShell(
      child: Column(
        children: [
          if (teams.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Nessun team caricato',
                style: GoogleFonts.spaceGrotesk(color: muteColor),
              ),
            )
          else
            ...teams.asMap().entries.map((e) {
              final i = e.key;
              final team = e.value;
              final isActive = team.teamId == currentTeamId;
              final teamInitial = teamInitials(team.teamName, fallback: '?');
              return Container(
                decoration: BoxDecoration(
                  border: i > 0
                      ? Border(top: BorderSide(color: lineColor))
                      : null,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 4),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isActive ? GimmyTokens.brand : GimmyTokens.ink,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      teamInitial,
                      style: GoogleFonts.bebasNeue(
                        fontSize: 18,
                        color: isActive
                            ? GimmyTokens.brandInk
                            : GimmyTokens.brand,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          team.teamName,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Con due squadre nella stessa societa il nome non basta a distinguerle
                      GimmyChip(
                        text: team.formatoShortLabel,
                        variant: GimmyChipVariant.neutral,
                        fontSize: 9,
                      ),
                    ],
                  ),
                  subtitle: Text(
                    [
                      if (team.clubName != null) team.clubName,
                      team.formatoLabel,
                      team.isAdmin ? 'Amministratore' : 'Giocatore',
                    ].join(' · '),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      color: muteColor,
                    ),
                  ),
                  trailing: isActive
                      ? const GimmyChip(
                          text: 'ATTIVO',
                          variant: GimmyChipVariant.brand,
                          fontSize: 9,
                        )
                      : InkWell(
                          onTap: () => onSwitch(team.teamId),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: GimmyTokens.ink,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Cambia',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: GimmyTokens.brand,
                              ),
                            ),
                          ),
                        ),
                ),
              );
            }),
          if (isAdmin)
            Container(
              decoration:
                  BoxDecoration(border: Border(top: BorderSide(color: lineColor))),
              child: ListTile(
                leading: Icon(Icons.vpn_key_outlined,
                    color: GimmyTokens.brand),
                title: Text('Codice invito',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor)),
                trailing: Icon(Icons.chevron_right, color: faintColor),
                onTap: onInvite,
              ),
            ),
          Container(
            decoration:
                BoxDecoration(border: Border(top: BorderSide(color: lineColor))),
            child: ListTile(
              leading:
                  const Icon(Icons.add_circle_outline, color: GimmyTokens.brand),
              title: Text('Crea nuovo team',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor)),
              trailing: Icon(Icons.chevron_right, color: faintColor),
              onTap: onCreate,
            ),
          ),
          Container(
            decoration:
                BoxDecoration(border: Border(top: BorderSide(color: lineColor))),
            child: ListTile(
              leading: const Icon(Icons.link, color: GimmyTokens.brand),
              title: Text('Unisciti con codice',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor)),
              trailing: Icon(Icons.chevron_right, color: faintColor),
              onTap: onJoin,
            ),
          ),
          Container(
            decoration:
                BoxDecoration(border: Border(top: BorderSide(color: lineColor))),
            child: ListTile(
              leading: const Icon(Icons.tune, color: GimmyTokens.brand),
              title: Text('Configuratore squadra',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor)),
              subtitle: Text('Pianifica una nuova rosa (draft)',
                  style: GoogleFonts.spaceGrotesk(fontSize: 11, color: muteColor)),
              trailing: Icon(Icons.chevron_right, color: faintColor),
              onTap: onDraft,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeasonCard extends StatelessWidget {
  final List<SeasonModel> seasons;
  final bool vedeIConti;
  final bool puoChiudere;
  final VoidCallback onClose;

  const _SeasonCard({
    required this.seasons,
    required this.vedeIConti,
    required this.puoChiudere,
    required this.onClose,
  });

  static String _data(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _sottotitoloCorrente(SeasonModel s) {
    final righe = ['Dal ${_data(s.dataInizio)} · ${s.partite} partite'];
    if (vedeIConti) {
      righe.add('Incassato ${formatEuro(s.incassato)} · '
          'da incassare ${formatEuro(s.daIncassare)}');
    }
    return righe.join('\n');
  }

  String _sottotitoloArchivio(SeasonModel s) {
    final periodo = s.dataFine == null
        ? _data(s.dataInizio)
        : '${_data(s.dataInizio)} - ${_data(s.dataFine!)}';
    var riga = '$periodo · ${s.partite} partite';
    if (vedeIConti) riga = '$riga · ${formatEuro(s.incassato)} incassati';
    final note = s.note;
    return note == null || note.isEmpty ? riga : '$riga\n$note';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? GimmyTokens.darkText : GimmyTokens.text;
    final muteColor = isDark ? GimmyTokens.darkTextMute : GimmyTokens.textMute;
    final lineColor = isDark ? GimmyTokens.darkLine : GimmyTokens.line;

    if (seasons.isEmpty) {
      return _CardShell(
        child: ListTile(
          leading: const Icon(Icons.event_repeat, color: GimmyTokens.brand),
          title: Text('Stagione',
              style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
          subtitle: Text('Caricamento...',
              style: GoogleFonts.spaceGrotesk(fontSize: 12, color: muteColor)),
        ),
      );
    }

    final corrente = seasons.firstWhere((s) => !s.chiusa, orElse: () => seasons.first);
    final archivio = seasons.where((s) => s.id != corrente.id).toList();

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.event_repeat, color: GimmyTokens.brand),
            title: Text(
              corrente.chiusa ? '${corrente.nome} (chiusa)' : corrente.nome,
              style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w600, fontSize: 14, color: textColor),
            ),
            subtitle: Text(
              _sottotitoloCorrente(corrente),
              style: GoogleFonts.spaceGrotesk(fontSize: 12, color: muteColor),
            ),
            isThreeLine: vedeIConti,
          ),
          if (puoChiudere) ...[
            Divider(height: 1, color: lineColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chiudere la stagione archivia partite e pagamenti e riporta '
                    'a zero gettoni e quote di tutta la rosa.',
                    style: GoogleFonts.spaceGrotesk(fontSize: 11, color: muteColor),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onClose,
                      icon: const Icon(Icons.flag_outlined, size: 18),
                      label: const Text('Chiudi stagione e riparti'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (archivio.isNotEmpty) ...[
            Divider(height: 1, color: lineColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text('ARCHIVIO',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: muteColor)),
            ),
            ...archivio.map((s) => ListTile(
                  dense: true,
                  leading: Icon(Icons.inventory_2_outlined, size: 18, color: muteColor),
                  title: Text(s.nome,
                      style: GoogleFonts.spaceGrotesk(fontSize: 13, color: textColor)),
                  subtitle: Text(
                    _sottotitoloArchivio(s),
                    style: GoogleFonts.spaceGrotesk(fontSize: 11, color: muteColor),
                  ),
                  trailing: vedeIConti && s.daIncassare > 0
                      ? Text('-${formatEuro(s.daIncassare)}',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.error))
                      : null,
                )),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ConfigCard extends StatelessWidget {
  final TeamConfig? config;
  final bool useGettoni;
  final void Function(bool) onToggleGettoni;
  final VoidCallback onEditRules;
  final VoidCallback onGenerateFees;

  const _ConfigCard({
    required this.config,
    required this.useGettoni,
    required this.onToggleGettoni,
    required this.onEditRules,
    required this.onGenerateFees,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? GimmyTokens.darkText : GimmyTokens.text;
    final muteColor = isDark ? GimmyTokens.darkTextMute : GimmyTokens.textMute;
    final lineColor = isDark ? GimmyTokens.darkLine : GimmyTokens.line;
    final cfg = config;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.sports_soccer, color: GimmyTokens.brand),
            title: Text(
              cfg?.formatoLabel ?? 'Formato squadra',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: textColor,
              ),
            ),
            subtitle: Text(
              cfg == null
                  ? 'Caricamento...'
                  : '${cfg.giocatoriInCampo} in campo · '
                      '${cfg.maxConvocati == null ? 'convocati liberi' : 'max ${cfg.maxConvocati} convocati'} · '
                      '${cfg.numeroTempi}x${cfg.minutiPerTempo} min',
              style: GoogleFonts.spaceGrotesk(fontSize: 12, color: muteColor),
            ),
            trailing: TextButton(onPressed: onEditRules, child: const Text('Modifica')),
          ),
          Divider(height: 1, color: lineColor),
          SwitchListTile(
            secondary: const Icon(Icons.toll, color: GimmyTokens.brand),
            title: Text(
              'Sistema gettoni',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: textColor,
              ),
            ),
            subtitle: Text(
              useGettoni ? 'Attivo' : 'Disattivato',
              style: GoogleFonts.spaceGrotesk(fontSize: 12, color: muteColor),
            ),
            value: useGettoni,
            onChanged: onToggleGettoni,
          ),
          Divider(height: 1, color: lineColor),
          ListTile(
            leading: const Icon(Icons.euro, color: GimmyTokens.brand),
            title: Text(
              'Costi',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: textColor,
              ),
            ),
            subtitle: Text(
              cfg == null
                  ? '-'
                  : 'Iscrizione ${_fmt(cfg.quotaIscrizione)} · '
                      'Tesseramento ${_fmt(cfg.quotaTesseramento)} · '
                      'Partita ${_fmt(cfg.costoPartita)}'
                      '\nStagione stimata ${_fmt(cfg.costoStagioneStimato)} a giocatore',
              style: GoogleFonts.spaceGrotesk(fontSize: 12, color: muteColor),
            ),
            isThreeLine: cfg != null,
          ),
          if (cfg != null && (cfg.quotaIscrizione > 0 || cfg.quotaTesseramento > 0))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onGenerateFees,
                  icon: const Icon(Icons.playlist_add_check, size: 18),
                  label: const Text('Genera quote in Pagamenti'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _fmt(double value) =>
      value == 0 ? '-' : '${value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2)} EUR';
}

class _BrandCard extends StatelessWidget {
  final bool isDark;
  final void Function(bool) onToggleDark;
  final bool hasLogo;
  final Uint8List? logoBytes;
  final String teamName;
  final TextEditingController teamNameCtrl;
  final Color primaryColor;
  final VoidCallback onPickLogo;
  final VoidCallback onRemoveLogo;
  final VoidCallback onSaveName;
  final void Function(Color) onColorPick;

  const _BrandCard({
    required this.isDark,
    required this.onToggleDark,
    required this.hasLogo,
    required this.logoBytes,
    required this.teamName,
    required this.teamNameCtrl,
    required this.primaryColor,
    required this.onPickLogo,
    required this.onRemoveLogo,
    required this.onSaveName,
    required this.onColorPick,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final lineColor = dark ? GimmyTokens.darkLine : GimmyTokens.line;
    final textColor = dark ? GimmyTokens.darkText : GimmyTokens.text;
    final muteColor = dark ? GimmyTokens.darkTextMute : GimmyTokens.textMute;

    return _CardShell(
      child: Column(
        children: [
          // Tema scuro
          SwitchListTile(
            secondary: Icon(
              isDark ? Icons.dark_mode : Icons.light_mode,
              color: GimmyTokens.brand,
            ),
            title: Text(
              'Tema scuro',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: textColor,
              ),
            ),
            subtitle: Text(
              isDark ? 'Attivo' : 'Disattivato',
              style: GoogleFonts.spaceGrotesk(fontSize: 12, color: muteColor),
            ),
            value: isDark,
            onChanged: onToggleDark,
          ),
          Divider(color: lineColor, height: 1),
          // Logo
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LOGO SQUADRA',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.54,
                    color: muteColor,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: dark
                            ? GimmyTokens.darkPaper
                            : const Color(0xFFF2F0EA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: lineColor),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: hasLogo && logoBytes != null
                          ? Image.memory(logoBytes!, fit: BoxFit.cover)
                          : Icon(
                              Icons.sports_soccer,
                              size: 32,
                              color: muteColor.withOpacity(0.5),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OutlinedButton.icon(
                            onPressed: onPickLogo,
                            icon: const Icon(Icons.upload, size: 16),
                            label: Text(hasLogo ? 'Cambia' : 'Carica'),
                          ),
                          if (hasLogo) ...[
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: onRemoveLogo,
                              child: const Text(
                                'Rimuovi',
                                style: TextStyle(
                                  color: GimmyTokens.bad,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(color: lineColor, height: 1),
          // Nome team
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NOME SQUADRA',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.54,
                    color: muteColor,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: teamNameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Es. I Campioni',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: onSaveName,
                      child: const Text('Salva'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(color: lineColor, height: 1),
          // Colore primario
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'COLORE BRAND',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.54,
                        color: muteColor,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: lineColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: ThemeProvider.availableColors.map((color) {
                    final selected = primaryColor.value == color.value;
                    return GestureDetector(
                      onTap: () => onColorPick(color),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                          border: selected
                              ? Border.all(color: textColor, width: 3)
                              : Border.all(color: lineColor),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: color.withOpacity(0.4),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: selected
                            ? const Icon(Icons.check,
                                size: 18, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final VoidCallback onLogout;
  const _AccountCard({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lineColor = isDark ? GimmyTokens.darkLine : GimmyTokens.line;
    final textColor = isDark ? GimmyTokens.darkText : GimmyTokens.text;
    final muteColor = isDark ? GimmyTokens.darkTextMute : GimmyTokens.textMute;
    return _CardShell(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.info_outline, color: muteColor),
            title: Text(
              'Versione',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: textColor,
              ),
            ),
            trailing: Text(
              '1.0.0',
              style: GoogleFonts.spaceGrotesk(color: muteColor, fontSize: 13),
            ),
          ),
          Divider(color: lineColor, height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: GimmyTokens.bad),
            title: Text(
              'Esci',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: GimmyTokens.bad,
              ),
            ),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}
