import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/theme_provider.dart';
import 'app_widgets.dart';
import 'share_utils.dart';

/// Codice invito con link diretto, QR da far scansionare a bordo campo e
/// condivisione pronta. Unico per squadra e società'.
Future<void> showInviteDialog(
  BuildContext context, {
  required String code,
  required String titolo,
  required String nome,
  String? descrizione,
}) {
  final link = appLink('/join/$code');
  final testo = 'Unisciti a $nome su InCampo: $link\nCodice invito: $code';

  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
      return AlertDialog(
        title: Text(titolo),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (descrizione != null) ...[
                Text(descrizione, style: GoogleFonts.spaceGrotesk(fontSize: 13, color: muteColor)),
                const SizedBox(height: 14),
              ],
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: QrImageView(
                    data: link,
                    size: 180,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppTokens.ink),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppTokens.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTokens.brand.withOpacity(0.15) : AppTokens.brandSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    code,
                    style: GoogleFonts.bebasNeue(
                      fontSize: 30,
                      letterSpacing: 4,
                      color: isDark ? AppTokens.darkBrand : AppTokens.brandInk,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SelectableText(
                link,
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(fontSize: 11, color: muteColor),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copiato')),
                );
              }
            },
            child: const Text('Copia link'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              showShareSheet(context, title: 'Invito', text: testo);
            },
            icon: const Icon(Icons.ios_share, size: 18),
            label: const Text('Condividi'),
          ),
        ],
      );
    },
  );
}
