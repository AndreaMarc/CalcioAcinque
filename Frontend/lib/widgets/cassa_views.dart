import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/constants/api_constants.dart';
import '../models/cassa_model.dart';
import '../models/payment_model.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'app_widgets.dart';

/// Le due viste del cassiere oltre alle entrate: le uscite e il cruscotto.
/// Vivono qui per non gonfiare payments_screen, che le ospita in un segmented.

enum SezioneCassa { entrate, uscite, cassa }

class CassaSwitcher extends StatelessWidget {
  final SezioneCassa value;
  final ValueChanged<SezioneCassa> onChange;
  const CassaSwitcher({super.key, required this.value, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final activeBg = isDark ? AppTokens.darkCard : Colors.white;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;

    Widget opt(String label, SezioneCassa v) {
      final active = value == v;
      return Expanded(
        child: InkWell(
          onTap: () => onChange(v),
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: active
                ? BoxDecoration(
                    color: activeBg,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  )
                : null,
            alignment: Alignment.center,
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? textColor : muteColor,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: trackColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          opt('Entrate', SezioneCassa.entrate),
          opt('Uscite', SezioneCassa.uscite),
          opt('Cassa', SezioneCassa.cassa),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// USCITE
// ---------------------------------------------------------------------------

class UsciteView extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final bool archivio;
  final VoidCallback onAdd;
  final ValueChanged<ExpenseModel> onEdit;
  const UsciteView({
    super.key,
    required this.expenses,
    required this.archivio,
    required this.onAdd,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    final totale = expenses.fold(0.0, (s, e) => s + e.importo);
    final perCategoria = <String, double>{};
    for (final e in expenses) {
      perCategoria[e.categoriaLabel] = (perCategoria[e.categoriaLabel] ?? 0) + e.importo;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: CardInk(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('USCITE', color: AppTokens.bad),
                const SizedBox(height: 6),
                Text(
                  formatEuro(totale),
                  style: GoogleFonts.bebasNeue(fontSize: 56, height: 0.85, color: Colors.white),
                ),
                const SizedBox(height: 10),
                if (perCategoria.isEmpty)
                  Text(
                    'Campo, arbitro, materiale: qui si segna cosa esce dalla cassa.',
                    style: GoogleFonts.spaceGrotesk(fontSize: 12, color: AppTokens.textOnInkMute),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: perCategoria.entries
                        .map((e) => AppChip(
                              text: '${e.key} ${formatEuro(e.value)}',
                              variant: AppChipVariant.dark,
                              onInk: true,
                            ))
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
        if (expenses.isEmpty)
          EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'NESSUNA USCITA',
            message: archivio
                ? 'In questa stagione non risultano spese.'
                : 'Il costo del campo si registra da solo con l\'incasso partita. Il resto lo aggiungi qui.',
            action: archivio
                ? null
                : FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nuova uscita'),
                  ),
          )
        else ...[
          ...expenses.map((e) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _ExpenseRow(e: e, onTap: archivio ? null : () => onEdit(e)),
              )),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              'Le uscite "Affitto campo" legate a una partita si aggiornano dall\'incasso partita.',
              style: GoogleFonts.spaceGrotesk(fontSize: 11, color: muteColor),
            ),
          ),
        ],
      ],
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  final ExpenseModel e;
  final VoidCallback? onTap;
  const _ExpenseRow({required this.e, this.onTap});

  static IconData _icona(String categoria) => switch (categoria) {
        'Campo' => Icons.stadium_outlined,
        'Arbitro' => Icons.sports,
        'Materiale' => Icons.sports_soccer,
        'Trasferta' => Icons.directions_bus_outlined,
        _ => Icons.receipt_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTokens.bad.withOpacity(isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(_icona(e.categoria), color: AppTokens.bad, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.descrizione,
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, fontSize: 14, color: textColor),
                ),
                Text(
                  [e.categoriaLabel, if (e.adminNome != null) e.adminNome!].join(' · '),
                  style: GoogleFonts.spaceGrotesk(fontSize: 11, color: muteColor),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('-${formatEuro(e.importo)}', style: GoogleFonts.bebasNeue(fontSize: 22, color: AppTokens.bad)),
              Text(DateFormat('dd/MM/yy').format(e.data), style: GoogleFonts.spaceGrotesk(fontSize: 10, color: muteColor)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Crea o modifica un'uscita. Ritorna true se qualcosa e' cambiato.
Future<bool> showExpenseDialog(
  BuildContext context, {
  required int teamId,
  ExpenseModel? existing,
}) async {
  final descrizioneCtrl = TextEditingController(text: existing?.descrizione ?? '');
  final importoCtrl = TextEditingController(
    text: existing == null ? '' : _formatImporto(existing.importo),
  );
  final noteCtrl = TextEditingController(text: existing?.note ?? '');
  var categoria = existing?.categoria ?? 'Campo';
  var data = existing?.data ?? DateTime.now();
  var busy = false;
  String? errore;

  String messaggio(Object e) {
    if (e is DioException && e.response?.data is Map && (e.response!.data as Map)['message'] != null) {
      return (e.response!.data as Map)['message'] as String;
    }
    return 'Errore di connessione';
  }

  final esito = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final cs = Theme.of(ctx).colorScheme;

        Future<void> salva() async {
          final descrizione = descrizioneCtrl.text.trim();
          final importo = double.tryParse(importoCtrl.text.replaceAll(',', '.'));
          if (descrizione.isEmpty || importo == null || importo <= 0) {
            setDialogState(() => errore = 'Servono una descrizione e un importo.');
            return;
          }
          setDialogState(() {
            busy = true;
            errore = null;
          });
          try {
            final dio = context.read<AuthProvider>().apiClient.dio;
            final payload = {
              'categoria': categoria,
              'descrizione': descrizione,
              'importo': importo,
              'data': DateTime(data.year, data.month, data.day, 12).toUtc().toIso8601String(),
              'note': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
            };
            if (existing == null) {
              await dio.post(ApiConstants.expenses(teamId), data: payload);
            } else {
              await dio.put(ApiConstants.expense(existing.id), data: payload);
            }
            if (ctx.mounted) Navigator.of(ctx).pop(true);
          } catch (e) {
            if (ctx.mounted) {
              setDialogState(() {
                busy = false;
                errore = messaggio(e);
              });
            }
          }
        }

        Future<void> elimina() async {
          final ok = await showConfirmDialog(
            ctx,
            title: 'Eliminare l\'uscita?',
            message: '"${existing!.descrizione}" da ${formatEuro(existing.importo)} sparisce dalla cassa.',
            confirmLabel: 'Elimina',
            destructive: true,
          );
          if (!ok || !ctx.mounted) return;
          setDialogState(() => busy = true);
          try {
            await context.read<AuthProvider>().apiClient.dio.delete(ApiConstants.expense(existing.id));
            if (ctx.mounted) Navigator.of(ctx).pop(true);
          } catch (e) {
            if (ctx.mounted) {
              setDialogState(() {
                busy = false;
                errore = messaggio(e);
              });
            }
          }
        }

        return AlertDialog(
          title: Text(existing == null ? 'Nuova uscita' : 'Modifica uscita'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('CATEGORIA'),
                const SizedBox(height: 8),
                AppChoiceChips<String>(
                  values: categorieSpesa.keys.toList(),
                  selected: categoria,
                  label: (k) => categorieSpesa[k]!,
                  onChanged: (v) => setDialogState(() => categoria = v ?? 'Altro'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descrizioneCtrl,
                  decoration: const InputDecoration(labelText: 'Descrizione *'),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: importoCtrl,
                        decoration: const InputDecoration(labelText: 'Importo *', prefixText: '€ '),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: data,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setDialogState(() => data = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Data'),
                          child: Text(DateFormat('dd/MM/yyyy').format(data)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: 'Note'),
                  maxLines: 2,
                ),
                if (errore != null) ...[
                  const SizedBox(height: 10),
                  Text(errore!, style: TextStyle(fontSize: 12, color: cs.error)),
                ],
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: busy ? null : elimina,
                style: TextButton.styleFrom(foregroundColor: AppTokens.bad),
                child: const Text('Elimina'),
              ),
            TextButton(onPressed: busy ? null : () => Navigator.of(ctx).pop(false), child: const Text('Annulla')),
            FilledButton(
              onPressed: busy ? null : salva,
              child: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(existing == null ? 'Aggiungi' : 'Salva'),
            ),
          ],
        );
      },
    ),
  );
  return esito ?? false;
}

String _formatImporto(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

// ---------------------------------------------------------------------------
// CASSA (cruscotto)
// ---------------------------------------------------------------------------

class CassaView extends StatelessWidget {
  final CassaSummary? cassa;
  final bool archivio;
  final ValueChanged<PartitaNonIncassata> onIncassa;
  final VoidCallback onSollecitaTutti;
  final ValueChanged<Arretrato> onSollecitaUno;
  final VoidCallback onEsporta;
  final VoidCallback onCondividi;

  const CassaView({
    super.key,
    required this.cassa,
    required this.archivio,
    required this.onIncassa,
    required this.onSollecitaTutti,
    required this.onSollecitaUno,
    required this.onEsporta,
    required this.onCondividi,
  });

  @override
  Widget build(BuildContext context) {
    final c = cassa;
    if (c == null) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    final totArretrati = c.arretrati.fold(0.0, (s, a) => s + a.importo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: _CassaHero(c: c),
        ),

        // Partite concluse senza addebiti: il lavoro che manca al cassiere
        if (c.partiteNonIncassate.isNotEmpty) ...[
          SectionHead(
            title: 'PARTITE DA INCASSARE',
            more: '${c.partiteNonIncassate.length}',
          ),
          ...c.partiteNonIncassate.map((p) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: AppCard(
                  padding: const EdgeInsets.all(12),
                  onTap: archivio ? null : () => onIncassa(p),
                  child: Row(
                    children: [
                      JerseyNumber(number: p.numeroGiornata, size: 40, fontSize: 17),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.titolo != null && p.titolo!.isNotEmpty
                                  ? 'G${p.numeroGiornata} vs ${p.titolo}'
                                  : 'Giornata ${p.numeroGiornata}',
                              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, fontSize: 14, color: textColor),
                            ),
                            Text(
                              '${DateFormat('EEE d MMM', 'it_IT').format(p.data)} · ${p.presenti} presenti'
                              '${p.presentiAPartita > 0 ? ', ${p.presentiAPartita} pagano a partita' : ''}',
                              style: GoogleFonts.spaceGrotesk(fontSize: 11, color: muteColor),
                            ),
                          ],
                        ),
                      ),
                      if (!archivio) const Icon(Icons.euro, color: AppTokens.brand, size: 20),
                    ],
                  ),
                ),
              )),
        ],

        // Arretrati per giocatore
        SectionHead(
          title: 'ARRETRATI',
          more: c.arretrati.isEmpty ? null : formatEuro(totArretrati),
        ),
        if (c.arretrati.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Nessuno deve niente. Cassa in ordine.', style: GoogleFonts.spaceGrotesk(fontSize: 13, color: muteColor)),
          )
        else ...[
          ...c.arretrati.map((a) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: AppCard(
                  padding: const EdgeInsets.all(12),
                  onTap: archivio ? null : () => onSollecitaUno(a),
                  child: Row(
                    children: [
                      const JerseyNumber(size: 40, fontSize: 17),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.displayName, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                            Text(
                              a.voci == 1 ? '1 voce da saldare' : '${a.voci} voci da saldare',
                              style: GoogleFonts.spaceGrotesk(fontSize: 11, color: muteColor),
                            ),
                          ],
                        ),
                      ),
                      Text(formatEuro(a.importo), style: GoogleFonts.bebasNeue(fontSize: 22, color: AppTokens.warn)),
                      if (!archivio) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.chat_outlined, size: 18, color: muteColor),
                      ],
                    ],
                  ),
                ),
              )),
          if (!archivio)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onSollecitaTutti,
                      icon: const Icon(Icons.notifications_active_outlined, size: 18),
                      label: const Text('Sollecita con notifica'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCondividi,
                      icon: const Icon(Icons.ios_share, size: 18),
                      label: const Text('Condividi elenco'),
                    ),
                  ),
                ],
              ),
            ),
        ],

        // Uscite per categoria
        if (c.uscitePerCategoria.isNotEmpty) ...[
          const SectionHead(title: 'USCITE PER CATEGORIA'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: c.uscitePerCategoria.map((u) {
                  final ratio = c.uscite > 0 ? u.importo / c.uscite : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(u.label, style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w600, color: textColor))),
                            Text(formatEuro(u.importo), style: GoogleFonts.bebasNeue(fontSize: 20, color: textColor)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        AppProgressBar(value: ratio, height: 3, fillColor: AppTokens.bad),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextButton.icon(
            onPressed: onEsporta,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Esporta movimenti (CSV)'),
          ),
        ),
      ],
    );
  }
}

class _CassaHero extends StatelessWidget {
  final CassaSummary c;
  const _CassaHero({required this.c});

  @override
  Widget build(BuildContext context) {
    final negativo = c.saldo < 0;
    return CardInk(
      withPitch: true,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(
            c.seasonNome != null ? 'SALDO CASSA · ${c.seasonNome!.toUpperCase()}' : 'SALDO CASSA',
            color: AppTokens.brand,
          ),
          const SizedBox(height: 6),
          Text(
            formatEuro(c.saldo),
            style: GoogleFonts.bebasNeue(
              fontSize: 56,
              height: 0.85,
              color: negativo ? AppTokens.bad : Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Incassato meno uscite: quello che c\'e\' davvero.',
            style: GoogleFonts.spaceGrotesk(fontSize: 12, color: AppTokens.textOnInkMute),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Expanded(child: _mini(formatEuro(c.entrateIncassate), 'INCASSATO', AppTokens.brand)),
                _sep(),
                Expanded(child: _mini(formatEuro(c.uscite), 'USCITE', AppTokens.bad)),
                _sep(),
                Expanded(child: _mini(formatEuro(c.daIncassare), 'DA INCASSARE', AppTokens.warn)),
                if (c.inVerifica > 0) ...[
                  _sep(),
                  Expanded(child: _mini(formatEuro(c.inVerifica), 'IN VERIFICA', Colors.white)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sep() => Container(width: 1, height: 32, color: Colors.white.withOpacity(0.08));

  Widget _mini(String v, String l, Color c) => Column(
        children: [
          Text(v, style: GoogleFonts.bebasNeue(fontSize: 22, color: c)),
          Text(
            l,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppTokens.textOnInkMute,
              letterSpacing: 0.6,
            ),
          ),
        ],
      );
}

/// Movimenti in CSV (separatore `;`, decimali con la virgola: apre bene in Excel italiano).
String buildCassaCsv(List<PaymentModel> payments, List<ExpenseModel> expenses) {
  String q(String? s) => '"${(s ?? '').replaceAll('"', '""')}"';
  String n(double v) => v.toStringAsFixed(2).replaceAll('.', ',');
  final df = DateFormat('dd/MM/yyyy');
  final rows = <String>['Tipo;Data;Descrizione;Giocatore;Categoria;Importo;Stato'];
  for (final p in payments) {
    rows.add([
      'Entrata',
      df.format(p.dataPagamento),
      q(p.descrizione),
      q(p.nomeGiocatore),
      q(p.tipo.label),
      n(p.importo),
      p.pagato ? 'Pagato' : (p.inVerifica ? 'In verifica' : 'Da pagare'),
    ].join(';'));
  }
  for (final e in expenses) {
    rows.add([
      'Uscita',
      df.format(e.data),
      q(e.descrizione),
      '',
      q(e.categoriaLabel),
      '-${n(e.importo)}',
      'Registrata',
    ].join(';'));
  }
  return rows.join('\r\n');
}
