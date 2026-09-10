import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

/// Scorciatoie per pagare: PayPal si apre in una nuova scheda, l'IBAN si copia.
///
/// Niente `url_launcher`: l'app e' solo web e il resto del codice usa gia'
/// `package:web` per il DOM (vedi il download dell'ICS in calendar_screen)
/// e `Clipboard.setData` per copiare.
class PaymentLinks extends StatelessWidget {
  final String? paypalLink;
  final String? iban;
  final String? intestatario;

  /// Importo da precompilare nel link PayPal, se il link lo supporta.
  final double? importo;

  /// Layout compatto per le righe di elenco.
  final bool compatto;

  const PaymentLinks({
    super.key,
    this.paypalLink,
    this.iban,
    this.intestatario,
    this.importo,
    this.compatto = false,
  });

  bool get _haQualcosa =>
      (paypalLink != null && paypalLink!.isNotEmpty) || (iban != null && iban!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    if (!_haQualcosa) return const SizedBox.shrink();

    final bottoni = <Widget>[
      if (paypalLink != null && paypalLink!.isNotEmpty)
        _Bottone(
          icona: Icons.open_in_new,
          testo: 'PayPal',
          compatto: compatto,
          onTap: () => apriPaypal(paypalLink!, importo),
        ),
      if (iban != null && iban!.isNotEmpty)
        _Bottone(
          icona: Icons.content_copy,
          testo: compatto ? 'IBAN' : 'Copia IBAN',
          compatto: compatto,
          onTap: () => copiaIban(context, iban!, intestatario),
        ),
    ];

    return Wrap(spacing: 8, runSpacing: 8, children: bottoni);
  }

  /// Apre il link in una nuova scheda. `window.open` da un gesto dell'utente
  /// non viene bloccato dai popup blocker.
  static void apriPaypal(String link, double? importo) {
    var url = link.trim();
    if (!url.startsWith('http')) url = 'https://$url';

    // paypal.me accetta l'importo come ultimo segmento del percorso
    if (importo != null && importo > 0 && url.contains('paypal.me')) {
      final pulito = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      final valore = importo == importo.roundToDouble()
          ? importo.toStringAsFixed(0)
          : importo.toStringAsFixed(2);
      url = '$pulito/$valore';
    }

    web.window.open(url, '_blank');
  }

  static Future<void> copiaIban(BuildContext context, String iban, String? intestatario) async {
    await Clipboard.setData(ClipboardData(text: iban));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(intestatario != null && intestatario.isNotEmpty
          ? 'IBAN copiato ($intestatario)'
          : 'IBAN copiato'),
    ));
  }
}

class _Bottone extends StatelessWidget {
  final IconData icona;
  final String testo;
  final bool compatto;
  final VoidCallback onTap;

  const _Bottone({
    required this.icona,
    required this.testo,
    required this.compatto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (compatto) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icona, size: 14),
        label: Text(testo, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: const Size(0, 32),
          visualDensity: VisualDensity.compact,
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icona, size: 18),
      label: Text(testo),
    );
  }
}

/// Riquadro con i dati per pagare, da mettere in testa a una schermata.
class PaymentInfoCard extends StatelessWidget {
  final String? paypalLink;
  final String? iban;
  final String? intestatario;
  final double? totaleDaPagare;

  const PaymentInfoCard({
    super.key,
    this.paypalLink,
    this.iban,
    this.intestatario,
    this.totaleDaPagare,
  });

  @override
  Widget build(BuildContext context) {
    final haDati = (paypalLink != null && paypalLink!.isNotEmpty) ||
        (iban != null && iban!.isNotEmpty);
    if (!haDati) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text('Come pagare',
                  style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
            ],
          ),
          if (iban != null && iban!.isNotEmpty) ...[
            const SizedBox(height: 10),
            SelectableText(
              iban!,
              style: const TextStyle(fontSize: 13, letterSpacing: 0.5, fontFamily: 'monospace'),
            ),
            if (intestatario != null && intestatario!.isNotEmpty)
              Text(intestatario!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
          const SizedBox(height: 12),
          PaymentLinks(
            paypalLink: paypalLink,
            iban: iban,
            intestatario: intestatario,
            importo: totaleDaPagare,
          ),
        ],
      ),
    );
  }
}
