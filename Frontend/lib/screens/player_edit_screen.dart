import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/navigation/app_page.dart';
import '../models/payment_model.dart';
import '../models/player_model.dart';
import '../models/ruoli.dart';
import '../models/team_draft.dart' show PlayerPosition, PlayerPositionX;
import '../providers/auth_provider.dart';
import '../providers/club_provider.dart';
import '../providers/players_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/position_picker.dart';

/// Modifica di un giocatore: anagrafica, ruolo e gli accordi economici solo suoi
/// (esente, quote diverse da quelle di squadra, gettoni solo per lui).
/// Ogni accordo personale ha "come la squadra" come punto di partenza: cambiare
/// poi il default della squadra continua a valere per lui finche' non lo si fissa.
class PlayerEditScreen extends StatefulWidget {
  final int playerId;
  const PlayerEditScreen({super.key, required this.playerId});

  @override
  State<PlayerEditScreen> createState() => _PlayerEditScreenState();
}

class _PlayerEditScreenState extends State<PlayerEditScreen> {
  PlayerModel? _player;
  bool _salvataggio = false;

  final _nome = TextEditingController();
  final _soprannome = TextEditingController();
  final _telefono = TextEditingController();
  final _numero = TextEditingController();
  PlayerPosition? _posizione;
  Ruolo _ruolo = Ruolo.values.first;
  bool _gioca = true;

  RegimePagamento? _regime;
  // null = come la squadra
  bool? _usaGettoni;
  final _gettoni = _Personale();
  final _iscrizione = _Personale();
  final _tesseramento = _Personale();
  final _costoPartita = _Personale();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carica());
  }

  Future<void> _carica() async {
    final auth = context.read<AuthProvider>();
    final club = context.read<ClubProvider>();
    final players = context.read<PlayersProvider>();
    if (club.teamConfig == null) await club.loadTeamConfig(auth.teamId);
    // Sempre dal server: il form salva tutti i campi, e partire da una copia
    // vecchia (ruolo, regime cambiati da un altro admin) li riscriverebbe indietro
    await players.loadPlayers(auth.teamId);
    if (!mounted) return;
    final p = players.players.where((p) => p.id == widget.playerId).firstOrNull;
    if (p == null) return;
    setState(() {
      _player = p;
      _nome.text = p.nome;
      _soprannome.text = p.soprannome ?? '';
      _telefono.text = p.telefono ?? '';
      _numero.text = p.numeroMaglia?.toString() ?? '';
      _posizione = p.posizione;
      _ruolo = RuoloX.fromApi(p.ruolo);
      _gioca = p.gioca;
      _regime = p.regimePagamento;
      _usaGettoni = p.usaGettoni;
      _gettoni.init(p.gettoniPerStagione?.toDouble());
      _iscrizione.init(p.quotaIscrizionePersonale);
      _tesseramento.init(p.quotaTesseramentoPersonale);
      _costoPartita.init(p.costoPartitaPersonale);
    });
  }

  @override
  void dispose() {
    for (final c in [_nome, _soprannome, _telefono, _numero]) {
      c.dispose();
    }
    for (final p in [_gettoni, _iscrizione, _tesseramento, _costoPartita]) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _salva() async {
    final player = _player!;
    if (_nome.text.trim().isEmpty) {
      _avviso('Il nome è obbligatorio');
      return;
    }
    for (final p in [_gettoni, _iscrizione, _tesseramento, _costoPartita]) {
      if (p.attivo && p.valore == null) {
        _avviso('Controlla gli importi: servono numeri, anche 0');
        return;
      }
    }

    final data = <String, dynamic>{
      'nome': _nome.text.trim(),
      if (_soprannome.text.trim().isNotEmpty) 'soprannome': _soprannome.text.trim(),
      if (_telefono.text.trim().isNotEmpty) 'telefono': _telefono.text.trim(),
      // Stringa vuota = azzera il ruolo in campo
      'posizione': _posizione?.apiValue ?? '',
      'numeroMaglia': int.tryParse(_numero.text) ?? 0,
      'ruolo': _ruolo.apiValue,
      'gioca': _gioca,
      // Stringa vuota = torna al default della squadra
      'regimePagamento': _regime?.apiValue ?? '',
      if (_usaGettoni == null) 'reimpostaUsaGettoni': true else 'usaGettoni': _usaGettoni,
      ..._gettoni.json('gettoniPerStagione', 'reimpostaGettoniPerStagione', intero: true),
      ..._iscrizione.json('quotaIscrizionePersonale', 'reimpostaQuotaIscrizione'),
      ..._tesseramento.json('quotaTesseramentoPersonale', 'reimpostaQuotaTesseramento'),
      ..._costoPartita.json('costoPartitaPersonale', 'reimpostaCostoPartita'),
    };

    setState(() => _salvataggio = true);
    final auth = context.read<AuthProvider>();
    final ok = await context.read<PlayersProvider>().updatePlayer(auth.teamId, player.id, data);
    if (!mounted) return;
    setState(() => _salvataggio = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Giocatore aggiornato')));
      context.popOr('/player/${player.id}');
    } else {
      _avviso(context.read<PlayersProvider>().updateError ?? 'Non riesco a salvare, riprova');
    }
  }

  void _avviso(String testo) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo)));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paper = isDark ? AppTokens.darkPaper : AppTokens.paper;
    final cs = Theme.of(context).colorScheme;
    final theme = context.watch<ThemeProvider>();
    final cfg = context.watch<ClubProvider>().teamConfig;
    final player = _player;

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              teamInitials: teamInitials(theme.teamName),
              title: 'Modifica giocatore',
              subtitle: player?.displayName,
              onBack: () => context.popOr('/players'),
            ),
            Expanded(
              child: player == null || cfg == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        const SectionHead(title: 'ANAGRAFICA'),
                        _card(Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (player.clubMemberId != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _nota(cs, 'Nome, soprannome e telefono valgono in tutte le squadre della società.'),
                              ),
                            TextField(
                              controller: _nome,
                              decoration: const InputDecoration(labelText: 'Nome e cognome *'),
                              textCapitalization: TextCapitalization.words,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _soprannome,
                              decoration: const InputDecoration(labelText: 'Soprannome'),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _telefono,
                              decoration: const InputDecoration(labelText: 'Telefono'),
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                        )),
                        const SectionHead(title: 'IN SQUADRA'),
                        _card(Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PositionPicker(
                              formato: cfg.formato,
                              selected: _posizione,
                              onChanged: (p) => setState(() => _posizione = p),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _numero,
                              decoration: const InputDecoration(labelText: 'Numero di maglia'),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                            const SizedBox(height: 16),
                            _titolo(context, 'Ruolo nella squadra'),
                            AppChoiceChips<Ruolo>(
                              values: Ruolo.values,
                              selected: _ruolo,
                              label: (r) => r.label,
                              onChanged: (r) => setState(() => _ruolo = r ?? _ruolo),
                            ),
                            const SizedBox(height: 6),
                            _nota(cs, _ruolo.descrizione),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Solo staff, non gioca'),
                              subtitle: const Text(
                                'Allenatore o dirigente: dà la presenza ma resta fuori da convocazioni e statistiche',
                                style: TextStyle(fontSize: 12),
                              ),
                              value: !_gioca,
                              onChanged: (v) => setState(() => _gioca = !v),
                            ),
                          ],
                        )),
                        const SectionHead(title: 'COME PAGA'),
                        _card(Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppChoiceChips<RegimePagamento?>(
                              values: [null, ...RegimePagamento.values],
                              selected: _regime,
                              label: (r) => r == null
                                  ? 'Come la squadra (${cfg.regimePagamentoDefault.shortLabel})'
                                  : r.label,
                              onChanged: (r) => setState(() => _regime = r),
                            ),
                            const SizedBox(height: 6),
                            _nota(cs, (_regime ?? cfg.regimePagamentoDefault).descrizione),
                            if (_regime != RegimePagamento.esente) ...[
                              const SizedBox(height: 16),
                              _titolo(context, 'Importi solo per lui'),
                              _nota(cs, 'Spento = vale l\'importo della squadra. 0 = quella voce non la paga.'),
                              _ImportoPersonale(
                                etichetta: 'Quota iscrizione',
                                squadra: formatEuro(cfg.quotaIscrizione),
                                stato: _iscrizione,
                                onChanged: () => setState(() {}),
                              ),
                              _ImportoPersonale(
                                etichetta: 'Quota tesseramento',
                                squadra: formatEuro(cfg.quotaTesseramento),
                                stato: _tesseramento,
                                onChanged: () => setState(() {}),
                              ),
                              _ImportoPersonale(
                                etichetta: 'Costo a partita',
                                squadra: formatEuro(cfg.costoPartita),
                                stato: _costoPartita,
                                onChanged: () => setState(() {}),
                              ),
                            ],
                            const SizedBox(height: 12),
                            // Sola lettura: la verita' e' la voce in Pagamenti, questi
                            // flag ne sono il riflesso (si aggiornano segnandola pagata)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                AppChip(
                                  text: player.iscrizionePagata ? 'Iscrizione pagata' : 'Iscrizione da pagare',
                                ),
                                AppChip(
                                  text: player.tesseramentoPagato ? 'Tesseramento pagato' : 'Tesseramento da pagare',
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _nota(cs, 'Le quote pagate si segnano da Pagamenti. Gli importi nuovi valgono per le quote generate da qui in poi.'),
                          ],
                        )),
                        const SectionHead(title: 'GETTONI'),
                        _card(Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppChoiceChips<bool?>(
                              values: const [null, true, false],
                              selected: _usaGettoni,
                              label: (v) => switch (v) {
                                null => 'Come la squadra (${cfg.useGettoni ? 'sì' : 'no'})',
                                true => 'Usa i gettoni',
                                false => 'Senza gettoni',
                              },
                              onChanged: (v) => setState(() => _usaGettoni = v),
                            ),
                            const SizedBox(height: 6),
                            _nota(
                              cs,
                              (_usaGettoni ?? cfg.useGettoni)
                                  ? 'Ogni presenza consuma un gettone. Ora ne ha ${player.gettoniRimanenti} su ${player.gettoniTotali}.'
                                  : 'Le presenze non consumano gettoni.',
                            ),
                            if (_usaGettoni ?? cfg.useGettoni)
                              _ImportoPersonale(
                                etichetta: 'Gettoni a stagione',
                                squadra: '${cfg.gettoniPerGiocatore}',
                                stato: _gettoni,
                                intero: true,
                                onChanged: () => setState(() {}),
                              ),
                            if (_usaGettoni == true && !player.usaGettoniEffettivo && player.gettoniTotali == 0)
                              _nota(cs, 'Salvando riceve subito i gettoni della stagione.'),
                          ],
                        )),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                          child: FilledButton(
                            onPressed: _salvataggio ? null : _salva,
                            child: _salvataggio
                                ? const SizedBox(
                                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Salva'),
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

  Widget _card(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AppCard(padding: const EdgeInsets.all(16), child: child),
      );

  Widget _titolo(BuildContext context, String testo) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(testo, style: Theme.of(context).textTheme.labelLarge),
      );

  Widget _nota(ColorScheme cs, String testo) =>
      Text(testo, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant));
}

/// Un valore che puo' essere quello della squadra (spento) o personale.
class _Personale {
  bool attivo = false;
  final ctrl = TextEditingController();

  void init(double? valore) {
    attivo = valore != null;
    ctrl.text = valore == null ? '' : _formatta(valore);
  }

  double? get valore => double.tryParse(ctrl.text.trim().replaceAll(',', '.'));

  Map<String, dynamic> json(String campo, String reimposta, {bool intero = false}) => attivo
      ? {campo: intero ? valore!.round() : valore}
      : {reimposta: true};

  static String _formatta(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceAll('.', ',');

  void dispose() => ctrl.dispose();
}

class _ImportoPersonale extends StatelessWidget {
  final String etichetta;
  final String squadra;
  final _Personale stato;
  final bool intero;
  final VoidCallback onChanged;

  const _ImportoPersonale({
    required this.etichetta,
    required this.squadra,
    required this.stato,
    required this.onChanged,
    this.intero = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etichetta, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(
                  stato.attivo ? 'Personalizzato' : 'Come la squadra: $squadra',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (stato.attivo)
            SizedBox(
              width: 96,
              child: TextField(
                controller: stato.ctrl,
                textAlign: TextAlign.end,
                keyboardType: TextInputType.numberWithOptions(decimal: !intero),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(intero ? r'[0-9]' : r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: intero ? null : '€',
                  hintText: '0',
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
          Switch(
            value: stato.attivo,
            onChanged: (v) {
              stato.attivo = v;
              if (v && stato.ctrl.text.isEmpty) stato.ctrl.text = '0';
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}
