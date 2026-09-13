import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/constants/api_constants.dart';
import '../models/payment_model.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_widgets.dart';

/// Incasso di una partita: propone chi deve pagare e lascia decidere all'admin.
///
/// Non e' un passaggio automatico alla conclusione della partita di proposito:
/// le presenze si bloccano quando la partita passa a Conclusa, e solo il mister
/// sa se sono complete. Da qui si apre su richiesta, anche a distanza di giorni.
class MatchIncassoSheet extends StatefulWidget {
  final int matchId;

  const MatchIncassoSheet({super.key, required this.matchId});

  /// Apre il foglio. Ritorna true se sono stati creati degli addebiti.
  static Future<bool> show(BuildContext context, int matchId) async {
    final esito = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MatchIncassoSheet(matchId: matchId),
    );
    return esito ?? false;
  }

  @override
  State<MatchIncassoSheet> createState() => _MatchIncassoSheetState();
}

class _MatchIncassoSheetState extends State<MatchIncassoSheet> {
  MatchPaymentPreview? _preview;
  final Set<int> _selezionati = {};
  final _importoCtrl = TextEditingController();
  final _spesaCampoCtrl = TextEditingController();
  bool _dividi = false;

  bool _caricamento = true;
  bool _invio = false;
  bool _inviaNotifica = true;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  @override
  void dispose() {
    _importoCtrl.dispose();
    _spesaCampoCtrl.dispose();
    super.dispose();
  }

  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final response = await auth.apiClient.dio.get(
        ApiConstants.matchPaymentsPreview(widget.matchId),
      );

      if (response.data['success'] == true) {
        final preview = MatchPaymentPreview.fromJson(
          response.data['data'] as Map<String, dynamic>,
        );
        setState(() {
          _preview = preview;
          _selezionati
            ..clear()
            ..addAll(preview.candidati.where((c) => c.preselezionato).map((c) => c.playerId));
          _importoCtrl.text = _formatImporto(preview.costoPartita);
          if (preview.spesaCampoRegistrata != null) {
            _spesaCampoCtrl.text = _formatImporto(preview.spesaCampoRegistrata!);
          }
          _caricamento = false;
        });
      } else {
        setState(() {
          _errore = response.data['message'] as String?;
          _caricamento = false;
        });
      }
    } on DioException catch (e) {
      setState(() {
        _errore = _messaggio(e);
        _caricamento = false;
      });
    } catch (e) {
      setState(() {
        _errore = 'Errore imprevisto: $e';
        _caricamento = false;
      });
    }
  }

  Future<void> _conferma() async {
    if (_selezionati.isEmpty) return;

    setState(() {
      _invio = true;
      _errore = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final importo = double.tryParse(_importoCtrl.text.replaceAll(',', '.'));

      final response = await auth.apiClient.dio.post(
        ApiConstants.matchPayments(widget.matchId),
        data: {
          'playerIds': _selezionati.toList(),
          // Con la divisione l'importo a testa lo calcola il server dalla spesa
          if (!_dividiAttivo && importo != null && importo > 0) 'importo': importo,
          if (_spesaCampo > 0) 'spesaCampo': _spesaCampo,
          'dividiSpesaCampo': _dividiAttivo,
          'inviaNotifica': _inviaNotifica,
        },
      );

      if (!mounted) return;

      if (response.data['success'] == true) {
        final messaggio = response.data['message'] as String? ?? 'Incasso registrato';
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messaggio)));
      } else {
        setState(() {
          _errore = response.data['message'] as String?;
          _invio = false;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _errore = _messaggio(e);
        _invio = false;
      });
    }
  }

  double get _spesaCampo => double.tryParse(_spesaCampoCtrl.text.replaceAll(',', '.')) ?? 0;
  bool get _dividiAttivo => _dividi && _spesaCampo > 0 && _selezionati.isNotEmpty;

  /// A testa: la spesa divisa tra i selezionati (arrotondata a 50 cent, come il
  /// server) oppure l'importo scritto a mano.
  double get _importoATesta {
    if (_dividiAttivo) return (_spesaCampo / _selezionati.length * 2).ceilToDouble() / 2;
    return double.tryParse(_importoCtrl.text.replaceAll(',', '.')) ?? _preview?.costoPartita ?? 0;
  }

  double get _totale => _importoATesta * _selezionati.length;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: _caricamento
              ? const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _preview == null
                  ? _erroreIniziale(cs)
                  : _contenuto(cs, _preview!),
        ),
      ),
    );
  }

  Widget _erroreIniziale(ColorScheme cs) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 40, color: AppTokens.bad),
          const SizedBox(height: 12),
          Text(_errore ?? 'Non riesco a caricare l incasso', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Chiudi'),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _carica, child: const Text('Riprova')),
            ],
          ),
        ],
      );

  Widget _contenuto(ColorScheme cs, MatchPaymentPreview preview) {
    final addebitabili = preview.addebitabili;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSheetHandle(),
        DisplayText('INCASSO PARTITA', size: 26, color: cs.onSurface),
        const SizedBox(height: 2),
        Text(preview.partita, style: GoogleFonts.spaceGrotesk(fontSize: 12, color: cs.onSurfaceVariant)),
        const SizedBox(height: 12),

        if (preview.giaGestita)
          const NoticeBox(
            variant: AppChipVariant.brand,
            icon: Icons.check_circle_outline,
            text: 'Per questa partita hai gia registrato degli addebiti. Chi e gia stato addebitato non ricompare.',
            margin: EdgeInsets.only(bottom: 10),
          ),

        if (preview.presenzeDaRegistrare)
          NoticeBox(
            variant: AppChipVariant.bad,
            icon: Icons.info_outline,
            text: preview.presenzeBloccate
                ? 'Nessuna presenza registrata. La partita e conclusa, quindi per correggerle va prima riaperta.'
                : 'Nessuna presenza registrata: senza quelle non so chi ha giocato.',
            actionLabel: 'Presenze',
            onAction: () {
              Navigator.of(context).pop(false);
              context.push('/match/${widget.matchId}/day');
            },
            margin: const EdgeInsets.only(bottom: 10),
          ),

        if (addebitabili.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              preview.candidati.isEmpty
                  ? 'Nessun convocato per questa partita.'
                  : 'Nessuno da addebitare: sono tutti gia a posto.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          )
        else ...[
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: addebitabili.length,
              itemBuilder: (_, i) => _riga(cs, addebitabili[i]),
            ),
          ),
          const Divider(height: 20),
          // Costo del campo: diventa un'uscita di cassa e, se si vuole, si divide
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _spesaCampoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Costo campo (totale)',
                    prefixText: '€ ',
                    isDense: true,
                    helperText: 'Registrato come uscita di cassa',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Dividi', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  Switch(
                    value: _dividi && _spesaCampo > 0,
                    onChanged: _spesaCampo > 0 ? (v) => setState(() => _dividi = v) : null,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _dividiAttivo
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Importo a testa', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                          Text(formatEuro(_importoATesta),
                              style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
                          Text('${formatEuro(_spesaCampo)} / ${_selezionati.length}, arrotondato a 50 cent',
                              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                        ],
                      )
                    : TextField(
                        controller: _importoCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Importo a testa',
                          prefixText: '€ ',
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${_selezionati.length} selezionati',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  DisplayText(formatEuro(_totale), size: 26, color: cs.onSurface),
                ],
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Avvisa con una notifica'),
            subtitle: Text('Arriva solo a chi ha attivato le notifiche',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            value: _inviaNotifica,
            onChanged: (v) => setState(() => _inviaNotifica = v),
          ),
        ],

        if (_errore != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_errore!, style: TextStyle(fontSize: 12, color: AppTokens.bad)),
          ),

        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _invio ? null : () => Navigator.of(context).pop(false),
                child: const Text('Annulla'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: (_invio || _selezionati.isEmpty) ? null : _conferma,
                child: _invio
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('Addebita ${formatEuro(_totale)}'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _riga(ColorScheme cs, MatchPaymentCandidate c) {
    final dettagli = <String>[
      if (c.regime == RegimePagamento.stagionale) 'quota stagionale',
      if (c.presente && c.haGiocato) 'ha giocato',
      if (c.presente && !c.haGiocato) 'presente, non ha giocato',
      if (!c.presente) 'non presente',
      if (c.minutiGiocati != null) '${c.minutiGiocati} min',
      if (c.arretratoAttuale > 0) 'deve gia ${formatEuro(c.arretratoAttuale)}',
    ];

    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      value: _selezionati.contains(c.playerId),
      title: Text(c.displayName),
      subtitle: Text(
        dettagli.join(' · '),
        style: TextStyle(
          fontSize: 11,
          // Il motivo per cui non e' preselezionato va notato, non nascosto
          color: c.motivo != null ? AppTokens.bad : cs.onSurfaceVariant,
        ),
      ),
      onChanged: (v) => setState(() {
        if (v == true) {
          _selezionati.add(c.playerId);
        } else {
          _selezionati.remove(c.playerId);
        }
      }),
    );
  }

  static String _formatImporto(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

  static String _messaggio(DioException e) =>
      e.response?.data is Map && (e.response!.data as Map)['message'] != null
          ? (e.response!.data as Map)['message'] as String
          : 'Errore di connessione';
}
