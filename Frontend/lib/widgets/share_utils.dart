import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web/web.dart' as web;
import '../providers/theme_provider.dart';
import 'app_widgets.dart';

/// Condivisione di testi pronti (convocati, risultato, solleciti): il gruppo
/// WhatsApp esiste comunque, meglio alimentarlo senza riscrivere a mano.
bool get nativeShareSupported => web.window.navigator.has('share');

/// Foglio di condivisione nativo del telefono. `false` se non c'e' o l'utente annulla.
Future<bool> shareNative(String text, {String? title}) async {
  if (!nativeShareSupported) return false;
  try {
    await web.window.navigator.share(web.ShareData(title: title ?? 'InCampo', text: text)).toDart;
    return true;
  } catch (_) {
    return false;
  }
}

/// Apre WhatsApp (app o web) con il testo gia' scritto.
void openWhatsApp(String text) {
  web.window.open('https://wa.me/?text=${Uri.encodeComponent(text)}', '_blank');
}

/// Anteprima del testo e tre modi per mandarlo: condivisione nativa, WhatsApp, copia.
Future<void> showShareSheet(BuildContext context, {required String title, required String text}) {
  return showAppSheet<void>(
    context,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final textColor = isDark ? AppTokens.darkText : AppTokens.text;
      final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DisplayText(title.toUpperCase(), size: 22, color: textColor),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.35),
            child: AppCard(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: Text(
                  text,
                  style: GoogleFonts.spaceGrotesk(fontSize: 13, color: muteColor, height: 1.4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (nativeShareSupported)
            AppSheetAction(
              icon: Icons.ios_share,
              label: 'Condividi',
              subtitle: 'WhatsApp, Telegram, messaggi, altro',
              onTap: () async {
                Navigator.of(ctx).pop();
                await shareNative(text, title: title);
              },
            ),
          AppSheetAction(
            icon: Icons.chat_outlined,
            label: 'Apri WhatsApp',
            subtitle: 'Con il testo gia\' pronto',
            onTap: () {
              Navigator.of(ctx).pop();
              openWhatsApp(text);
            },
          ),
          AppSheetAction(
            icon: Icons.copy_outlined,
            label: 'Copia il testo',
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Testo copiato')),
                );
              }
            },
          ),
        ],
      );
    },
  );
}

/// Indirizzo pubblico dell'app, per i link nei messaggi (hash routing).
String appLink(String route) => '${Uri.base.origin}/#$route';
