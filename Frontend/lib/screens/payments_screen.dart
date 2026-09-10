import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/club_provider.dart';
import '../providers/players_provider.dart';
import '../providers/theme_provider.dart';
import '../core/constants/api_constants.dart';
import '../models/payment_model.dart';
import '../models/team_format.dart';
import '../widgets/app_widgets.dart';
import '../widgets/payment_links.dart';
import '../widgets/season_picker.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<PaymentModel> _payments = [];
  TeamConfig? _config;
  bool _isLoading = true;
  String _filter = 'daPagare';
  TipoPagamento? _tipo;

  /// null = stagione in corso, la scelta la fa il server.
  int? _seasonId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      await context.read<PlayersProvider>().loadPlayers(auth.teamId);
      // Serve per i dati di pagamento (PayPal/IBAN) risolti su societa e squadra
      _config = await context.read<ClubProvider>().loadTeamConfig(auth.teamId);

      await context.read<ClubProvider>().loadSeasons(auth.teamId);

      final response = await auth.apiClient.dio.get(
        ApiConstants.teamPayments(auth.teamId),
        queryParameters: {if (_seasonId != null) 'seasonId': _seasonId},
      );
      if (response.data['success'] == true) {
        final lista = (response.data['data'] as List)
            .map((e) => PaymentModel.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) setState(() => _payments = lista);
      }
    } catch (_) {
      // La schermata resta usabile: il RefreshIndicator permette di riprovare
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickSeason() async {
    final auth = context.read<AuthProvider>();
    final scelta = await showSeasonPicker(
      context,
      teamId: auth.teamId,
      selected: _seasonId,
    );
    if (scelta == null || !mounted) return;
    setState(() => _seasonId = scelta.seasonId);
    await _loadData();
  }

  List<PaymentModel> get _filteredPayments {
    var lista = _payments;
    if (_tipo != null) lista = lista.where((p) => p.tipo == _tipo).toList();

    switch (_filter) {
      case 'pagati':
        return lista.where((p) => p.pagato).toList();
      case 'daPagare':
        return lista.where((p) => p.daPagare).toList();
      case 'inVerifica':
        return lista.where((p) => p.inVerifica).toList();
      default:
        return lista;
    }
  }

  double get _totaleDovuto => _payments.fold(0.0, (s, p) => s + p.importo);
  double get _totalePagato =>
      _payments.where((p) => p.pagato).fold(0.0, (s, p) => s + p.importo);

  /// Quanto deve l'utente che sta guardando, per precompilare il link PayPal.
  double get _mioArretrato {
    final playerId = context.read<AuthProvider>().playerId;
    return _payments
        .where((p) => p.playerId == playerId && p.daPagare)
        .fold(0.0, (s, p) => s + p.importo);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final initials = teamInitials(theme.teamName, fallback: 'CA');
    final filtered = _filteredPayments;
    final inVerifica = _payments.where((p) => p.inVerifica).length;
    final seasons = context.watch<ClubProvider>().seasons;
    // Stagione chiusa: i conti sono storia, non si aggiungono voci
    final archivio =
        _seasonId != null && seasons.any((s) => s.id == _seasonId && s.chiusa);

    return Column(
      children: [
        AppTopBar(
          teamInitials: initials,
          title: 'Pagamenti',
          subtitle: seasons.length > 1
              ? seasonLabel(seasons, _seasonId)
              : (auth.puoGestireSoldi ? 'Quote e partite' : 'I tuoi pagamenti'),
          actions: [
            if (auth.puoGestireSoldi && !archivio)
              AppTopBar.iconAction(
                context,
                Icons.notifications_active_outlined,
                _confermaSollecito,
              ),
            if (auth.puoGestireSoldi && !archivio)
              AppTopBar.iconAction(
                context,
                Icons.add,
                () => _showCreatePaymentDialog(context),
              ),
            if (seasons.length > 1)
              AppTopBar.iconAction(context, Icons.event_repeat, _pickSeason),
          ],
        ),
        if (archivio)
          SeasonArchiveBanner(
            label: seasonLabel(seasons, _seasonId),
            onTorna: () {
              setState(() => _seasonId = null);
              _loadData();
            },
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.only(bottom: 100),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                        child: _PaymentsHero(
                          dovuto: _totaleDovuto,
                          pagato: _totalePagato,
                        ),
                      ),

                      // Come pagare: mostrato a chi ha qualcosa da saldare
                      if (_mioArretrato > 0 && (_config?.haDatiPagamento ?? false))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: PaymentInfoCard(
                            paypalLink: _config!.paypalLinkEffettivo,
                            iban: _config!.ibanEffettivo,
                            intestatario: _config!.intestatarioIbanEffettivo,
                            totaleDaPagare: _mioArretrato,
                          ),
                        ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: SizedBox(
                          height: 32,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _fc('Da pagare',
                                  _payments.where((p) => p.daPagare).length, 'daPagare'),
                              const SizedBox(width: 8),
                              if (inVerifica > 0) ...[
                                _fc('In verifica', inVerifica, 'inVerifica'),
                                const SizedBox(width: 8),
                              ],
                              _fc('Pagati',
                                  _payments.where((p) => p.pagato).length, 'pagati'),
                              const SizedBox(width: 8),
                              _fc('Tutti', _payments.length, 'tutti'),
                            ],
                          ),
                        ),
                      ),

                      // Secondo filtro per natura della voce: con gli addebiti
                      // partita la lista si allunga in fretta
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: SizedBox(
                          height: 32,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _tc(null, 'Ogni tipo'),
                              for (final t in TipoPagamento.values)
                                if (_payments.any((p) => p.tipo == t)) ...[
                                  const SizedBox(width: 8),
                                  _tc(t, t.label),
                                ],
                            ],
                          ),
                        ),
                      ),

                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Center(
                            child: Text(
                              _filter == 'daPagare'
                                  ? 'Niente da pagare'
                                  : 'Nessun pagamento',
                            ),
                          ),
                        )
                      else
                        ...filtered.map((p) => Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: _PaymentRow(
                                p: p,
                                config: _config,
                                // Il proprietario della voce puo dichiarare di aver
                                // pagato, ma su una stagione chiusa non si tocca nulla
                                mia: p.playerId == auth.playerId && !archivio,
                                onTap: auth.puoGestireSoldi && !archivio
                                    ? () => _showEditPaymentDialog(context, p)
                                    : null,
                                onDichiara: () => _dichiaraPagato(p),
                              ),
                            )),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _fc(String label, int count, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = _filter == value;
    final bg = active
        ? (isDark ? AppTokens.ink3 : AppTokens.ink)
        : (isDark ? AppTokens.darkCard : AppTokens.card);
    final fg = active
        ? Colors.white
        : (isDark ? AppTokens.darkTextMute : AppTokens.textMute);
    final line = isDark ? AppTokens.darkLine : AppTokens.line;
    return InkWell(
      onTap: () => setState(() => _filter = value),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? Colors.transparent : line),
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

  Widget _tc(TipoPagamento? tipo, String label) {
    final active = _tipo == tipo;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: active,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => _tipo = tipo),
    );
  }

  Future<void> _dichiaraPagato(PaymentModel p) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hai pagato?'),
        content: Text(
          'Segnalo che hai versato ${formatEuro(p.importo)} per "${p.descrizione}". '
          'L amministratore lo confermera quando vede i soldi.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ho pagato')),
        ],
      ),
    );
    if (conferma != true) return;

    try {
      final auth = context.read<AuthProvider>();
      final response = await auth.apiClient.dio.post(ApiConstants.declarePayment(p.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(response.data['message'] as String? ?? 'Segnalato'),
      ));
      _loadData();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_messaggio(e))));
    }
  }

  Future<void> _confermaSollecito() async {
    final inArretrato = _payments.where((p) => p.daPagare).map((p) => p.playerId).toSet();
    if (inArretrato.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Non c e nessun arretrato da sollecitare')),
      );
      return;
    }

    final conferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sollecita i pagamenti'),
        content: Text(
          'Manda una notifica a ${inArretrato.length} '
          '${inArretrato.length == 1 ? "giocatore" : "giocatori"} con voci non saldate, '
          'col totale che deve ciascuno. Arriva solo a chi ha attivato le notifiche.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sollecita')),
        ],
      ),
    );
    if (conferma != true) return;

    try {
      final auth = context.read<AuthProvider>();
      final response = await auth.apiClient.dio.post(
        ApiConstants.remindPayments(auth.teamId),
        // Lista vuota = il server sollecita tutti quelli che hanno arretrati
        data: {'playerIds': <int>[]},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(response.data['message'] as String? ?? 'Solleciti inviati'),
      ));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_messaggio(e))));
    }
  }

  static String _messaggio(DioException e) =>
      e.response?.data is Map && (e.response!.data as Map)['message'] != null
          ? (e.response!.data as Map)['message'] as String
          : 'Errore di connessione';

  void _showCreatePaymentDialog(BuildContext context) {
    final descrizioneCtrl = TextEditingController();
    final importoCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    int? selectedPlayerId;
    bool pagato = false;
    TipoPagamento tipo = TipoPagamento.altro;
    final players = context.read<PlayersProvider>().players;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nuovo Pagamento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Giocatore *'),
                  items: players
                      .map((p) => DropdownMenuItem(
                          value: p.id, child: Text(p.displayName)))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedPlayerId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TipoPagamento>(
                  value: tipo,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: TipoPagamento.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => tipo = v ?? TipoPagamento.altro),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descrizioneCtrl,
                  decoration: const InputDecoration(labelText: 'Descrizione *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: importoCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Importo *', prefixText: '€ '),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: 'Note'),
                  maxLines: 2,
                ),
                SwitchListTile(
                  title: const Text('Gia pagato'),
                  value: pagato,
                  onChanged: (v) => setDialogState(() => pagato = v),
                  contentPadding: EdgeInsets.zero,
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
                if (selectedPlayerId == null ||
                    descrizioneCtrl.text.trim().isEmpty ||
                    importoCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final auth = context.read<AuthProvider>();
                  await auth.apiClient.dio
                      .post(ApiConstants.playerPayments(selectedPlayerId!),
                          data: {
                        'descrizione': descrizioneCtrl.text.trim(),
                        'tipo': tipo.label,
                        'importo': double.tryParse(
                                importoCtrl.text.replaceAll(',', '.')) ??
                            0,
                        'dataPagamento': DateTime.now().toIso8601String(),
                        'pagato': pagato,
                        'note': noteCtrl.text.trim().isEmpty
                            ? null
                            : noteCtrl.text.trim(),
                      });
                  if (mounted) _loadData();
                } catch (_) {}
              },
              child: const Text('Crea'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPaymentDialog(BuildContext context, PaymentModel payment) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (payment.inVerifica)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Text(
                  '${payment.nomeGiocatore} dice di aver pagato il '
                  '${DateFormat('dd/MM alle HH:mm').format(payment.dichiaratoPagatoAt!.toLocal())}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ListTile(
              leading: Icon(
                payment.pagato ? Icons.cancel : Icons.check_circle,
                color: payment.pagato ? AppTokens.warn : AppTokens.ok,
              ),
              title: Text(payment.pagato
                  ? 'Segna come NON pagato'
                  : payment.inVerifica
                      ? 'Confermo: ho ricevuto i soldi'
                      : 'Segna come PAGATO'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final auth = context.read<AuthProvider>();
                  await auth.apiClient.dio.put(ApiConstants.payment(payment.id),
                      data: {'pagato': !payment.pagato});
                  if (mounted) _loadData();
                } catch (_) {}
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentsHero extends StatelessWidget {
  final double dovuto;
  final double pagato;
  const _PaymentsHero({required this.dovuto, required this.pagato});

  @override
  Widget build(BuildContext context) {
    final mancante = (dovuto - pagato).clamp(0, double.infinity).toDouble();
    final ratio = dovuto > 0 ? pagato / dovuto : 0.0;

    return CardInk(
      withPitch: true,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INCASSI',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.54,
              color: AppTokens.brand,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '€${pagato.toStringAsFixed(0)}',
                style: GoogleFonts.bebasNeue(
                  fontSize: 56,
                  height: 0.85,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '/ €${dovuto.toStringAsFixed(0)}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppProgressBar(value: ratio, height: 6),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                    child: _mini('€${pagato.toStringAsFixed(0)}', 'PAGATI',
                        AppTokens.brand)),
                Container(
                    width: 1,
                    height: 32,
                    color: Colors.white.withOpacity(0.08)),
                Expanded(
                    child: _mini('€${mancante.toStringAsFixed(0)}',
                        'MANCANTI', AppTokens.bad)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mini(String v, String l, Color c) {
    return Column(
      children: [
        Text(v, style: GoogleFonts.bebasNeue(fontSize: 26, color: c)),
        Text(
          l,
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

class _PaymentRow extends StatelessWidget {
  final PaymentModel p;
  final TeamConfig? config;

  /// Vero se la voce e' di chi sta guardando: solo lui puo' dichiarare di aver pagato.
  final bool mia;
  final VoidCallback? onTap;
  final VoidCallback onDichiara;

  const _PaymentRow({
    required this.p,
    required this.config,
    required this.mia,
    required this.onDichiara,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTokens.darkCard : AppTokens.card;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;

    // Tre stati e non due: in verifica sta fra "da pagare" e "pagato"
    final statusColor = p.pagato
        ? AppTokens.ok
        : p.inVerifica
            ? AppTokens.brand
            : AppTokens.warn;
    final statusBg = statusColor.withOpacity(isDark ? 0.15 : 0.12);
    final statusIcon = p.pagato
        ? Icons.check
        : p.inVerifica
            ? Icons.hourglass_top
            : Icons.schedule;

    final mostraLink = mia && p.daPagare && (config?.haDatiPagamento ?? false);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: lineColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p.descrizione,
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: textColor,
                        ),
                      ),
                      Text(
                        [
                          p.nomeGiocatore,
                          if (p.inVerifica) 'in verifica',
                        ].join(' · '),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          color: p.inVerifica ? AppTokens.brand : muteColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatEuro(p.importo),
                      style: GoogleFonts.bebasNeue(fontSize: 22, color: statusColor),
                    ),
                    Text(
                      DateFormat('dd/MM/yy').format(p.dataPagamento),
                      style: GoogleFonts.spaceGrotesk(fontSize: 10, color: muteColor),
                    ),
                  ],
                ),
              ],
            ),
            if (mostraLink || (mia && p.daPagare && !p.inVerifica)) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (mostraLink)
                    PaymentLinks(
                      paypalLink: config!.paypalLinkEffettivo,
                      iban: config!.ibanEffettivo,
                      intestatario: config!.intestatarioIbanEffettivo,
                      importo: p.importo,
                      compatto: true,
                    ),
                  const Spacer(),
                  if (!p.inVerifica)
                    TextButton.icon(
                      onPressed: onDichiara,
                      icon: const Icon(Icons.done_all, size: 16),
                      label: const Text('Ho pagato', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
