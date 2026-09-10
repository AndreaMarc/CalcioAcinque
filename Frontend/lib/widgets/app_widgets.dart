import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/team_format.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'team_utils.dart';

/// Safe initials extractor: returns 1-2 uppercase chars, falls back to [fallback].
String teamInitials(String name, {String fallback = 'IC'}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return fallback;
  if (trimmed.length >= 2) return trimmed.substring(0, 2).toUpperCase();
  return trimmed[0].toUpperCase();
}

TextStyle _display(double size, {double height = 1, Color? color, double letter = 0.02}) {
  return GoogleFonts.bebasNeue(
    fontSize: size,
    height: height,
    letterSpacing: letter,
    color: color,
  );
}

class AppTopBar extends StatelessWidget {
  final String teamInitials;
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Color? crestColor;

  /// Widget a destra del titolo (es. [FormatBadge]).
  final Widget? titleTrailing;

  /// Logo esplicito nel crest. Se `null` e [showTeamLogo] e' vero, si usa il
  /// logo della squadra attiva salvato in [ThemeProvider].
  final Uint8List? logo;
  final bool showTeamLogo;

  /// Tap sul crest. Se `null` e non c'e' [onBack], con piu' squadre si apre lo
  /// sheet di cambio squadra.
  final VoidCallback? onCrestTap;

  /// Sostituisce del tutto titolo/sottotitolo (es. pill LIVE, selettore draft).
  final Widget? titleWidget;

  /// Forza la resa "su fondo ink" anche in tema chiaro: per le schermate che
  /// dipingono scuro (scelta squadra, live, draft).
  final bool onInk;

  const AppTopBar({
    super.key,
    this.teamInitials = 'IC',
    this.title = '',
    this.subtitle,
    this.onBack,
    this.actions = const [],
    this.crestColor,
    this.titleTrailing,
    this.logo,
    this.showTeamLogo = true,
    this.onCrestTap,
    this.titleWidget,
    this.onInk = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = onInk || Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final cardColor = isDark ? AppTokens.darkCard : AppTokens.card;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Row(
        children: [
          if (onBack != null)
            _iconBtn(
              Icons.arrow_back,
              onBack!,
              bg: cardColor,
              border: lineColor,
              fg: textColor,
            )
          else
            _crest(context, isDark),
          const SizedBox(width: 10),
          if (titleWidget != null)
            Expanded(child: titleWidget!)
          else
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          letterSpacing: -0.01,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (titleTrailing != null) ...[
                      const SizedBox(width: 8),
                      titleTrailing!,
                    ],
                  ],
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      color: muteColor,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          ...actions.map((w) => Padding(padding: const EdgeInsets.only(left: 8), child: w)),
        ],
      ),
    );
  }

  Widget _crest(BuildContext context, bool isDark) {
    final logoBytes = logo ?? (showTeamLogo ? teamLogoOf(context) : null);
    final onTap = onCrestTap ?? _teamSwitcherIfMany(context);
    final crest = TeamCrest(
      initials: teamInitials,
      logo: logoBytes,
      size: 32,
      radius: 9,
      fontSize: 18,
      bg: crestColor ?? (isDark ? Colors.white : AppTokens.ink),
      fg: isDark ? AppTokens.ink : AppTokens.brand,
    );
    if (onTap == null) return crest;
    return Semantics(
      button: true,
      label: 'Cambia squadra',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: crest,
      ),
    );
  }

  /// Con piu' squadre il crest apre lo sheet di cambio squadra.
  static VoidCallback? _teamSwitcherIfMany(BuildContext context) {
    int count;
    try {
      count = context.select<AuthProvider, int>((a) => a.teams?.length ?? 0);
    } on ProviderNotFoundException {
      return null;
    }
    if (count < 2) return null;
    return () => showTeamSwitcher(context);
  }

  static Widget iconAction(
    BuildContext context,
    IconData icon,
    VoidCallback onTap, {
    Widget? badge,
    bool onInk = false,
  }) {
    final isDark = onInk || Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final lineColor = isDark ? AppTokens.darkLine : AppTokens.line;
    final cardColor = isDark ? AppTokens.darkCard : AppTokens.card;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _iconBtn(icon, onTap, bg: cardColor, border: lineColor, fg: textColor),
        if (badge != null) Positioned(top: 6, right: 6, child: badge),
      ],
    );
  }
}

Widget _iconBtn(
  IconData icon,
  VoidCallback onTap, {
  required Color bg,
  required Color border,
  required Color fg,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 18, color: fg),
    ),
  );
}

class Eyebrow extends StatelessWidget {
  final String text;
  final Color? color;
  final bool onInk;
  const Eyebrow(this.text, {super.key, this.color, this.onInk = false});

  @override
  Widget build(BuildContext context) {
    final isDark = onInk || Theme.of(context).brightness == Brightness.dark;
    final c = color ??
        (onInk
            ? AppTokens.textOnInkMute
            : (isDark ? AppTokens.darkTextMute : AppTokens.textMute));
    return Text(
      text,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.14 * 11,
        color: c,
      ).copyWith(letterSpacing: 1.54),
    );
  }
}

class DisplayText extends StatelessWidget {
  final String text;
  final double size;
  final Color? color;
  final double height;
  const DisplayText(
    this.text, {
    super.key,
    this.size = 26,
    this.color,
    this.height = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: _display(size, height: height, color: color, letter: 0.02),
    );
  }
}

class SectionHead extends StatelessWidget {
  final String title;
  final String? more;
  final VoidCallback? onMore;
  final EdgeInsets padding;
  final double size;
  final bool onInk;
  const SectionHead({
    super.key,
    required this.title,
    this.more,
    this.onMore,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 10),
    this.size = 22,
    this.onInk = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = onInk || Theme.of(context).brightness == Brightness.dark;
    final textColor = onInk ? Colors.white : (isDark ? AppTokens.darkText : AppTokens.text);
    final muteColor = onInk ? AppTokens.textOnInkMute : (isDark ? AppTokens.darkTextMute : AppTokens.textMute);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title, style: _display(size, color: textColor, letter: 0.02)),
          const Spacer(),
          if (more != null)
            InkWell(
              onTap: onMore,
              child: Text(
                more!,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: muteColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum AppChipVariant { neutral, ok, warn, bad, brand, dark }

class AppChip extends StatelessWidget {
  final String text;
  final AppChipVariant variant;
  final IconData? leadingIcon;
  final Widget? leading;
  final EdgeInsets padding;
  final double fontSize;
  final bool onInk;

  const AppChip({
    super.key,
    required this.text,
    this.variant = AppChipVariant.neutral,
    this.leadingIcon,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    this.fontSize = 11,
    this.onInk = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = onInk || Theme.of(context).brightness == Brightness.dark;
    late Color bg;
    late Color fg;
    switch (variant) {
      case AppChipVariant.ok:
        bg = AppTokens.softOf(AppTokens.ok, isDark: isDark);
        fg = isDark ? AppTokens.ok : AppTokens.okInk;
        break;
      case AppChipVariant.warn:
        bg = AppTokens.softOf(AppTokens.warn, isDark: isDark);
        fg = isDark ? AppTokens.warn : AppTokens.warnInk;
        break;
      case AppChipVariant.bad:
        bg = AppTokens.softOf(AppTokens.bad, isDark: isDark);
        fg = isDark ? AppTokens.bad : AppTokens.badInk;
        break;
      case AppChipVariant.brand:
        bg = isDark ? AppTokens.brand.withOpacity(0.15) : AppTokens.brandSoft;
        fg = isDark ? AppTokens.darkBrand : AppTokens.brandInk;
        break;
      case AppChipVariant.dark:
        bg = isDark ? AppTokens.ink3 : AppTokens.ink3;
        fg = Colors.white;
        break;
      case AppChipVariant.neutral:
        bg = isDark ? AppTokens.ink3 : AppTokens.card;
        fg = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
        break;
    }

    final borderColor = variant == AppChipVariant.neutral
        ? (isDark ? AppTokens.darkLine : AppTokens.line)
        : Colors.transparent;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: fontSize + 2, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: GoogleFonts.spaceGrotesk(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.02,
            ),
          ),
        ],
      ),
    );
  }
}

class JerseyNumber extends StatelessWidget {
  final int? number;
  final double size;
  final Color? bg;
  final Color? fg;
  final double fontSize;
  final double radius;

  const JerseyNumber({
    super.key,
    this.number,
    this.size = 40,
    this.bg,
    this.fg,
    this.fontSize = 20,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg ?? AppTokens.ink,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text(
        number?.toString() ?? '?',
        style: _display(fontSize, color: fg ?? AppTokens.brand),
      ),
    );
  }
}

class CardInk extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool withPitch;
  final double radius;

  const CardInk({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.withPitch = true,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: AppTokens.ink,
        borderRadius: BorderRadius.circular(radius),
        border: isDark
            ? Border.all(color: AppTokens.brand.withOpacity(0.12))
            : null,
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: AppTokens.brand.withOpacity(0.06),
              blurRadius: 60,
              offset: const Offset(0, 20),
            )
          else
            const BoxShadow(
              color: AppTokens.inkShadow,
              blurRadius: 40,
              offset: Offset(0, 20),
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (withPitch)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _PitchPainter()),
              ),
            ),
          Padding(padding: padding, child: DefaultTextStyle(
            style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 14),
            child: child,
          )),
        ],
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTokens.brand.withOpacity(0.22),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 1.1),
        width: size.width * 1.2,
        height: size.height,
      ));
    canvas.drawRect(Offset.zero & size, glow);

    final line = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1;
    final midY = size.height * 0.58;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), line);

    final circlePaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(
      Offset(size.width / 2, size.height + 10),
      80,
      circlePaint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class AppProgressBar extends StatelessWidget {
  final double value; // 0..1
  final double height;
  final Color? fillColor;

  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 6,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTokens.darkLine : AppTokens.line;
    final fill = fillColor ?? (isDark ? AppTokens.darkBrand : AppTokens.brand);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Stack(
        children: [
          Container(height: height, color: bg),
          FractionallySizedBox(
            widthFactor: value.clamp(0, 1),
            child: Container(height: height, color: fill),
          ),
        ],
      ),
    );
  }
}

class GettoniBar extends StatelessWidget {
  final int filled;
  final int total;
  final Color? filledColor;
  final double cellHeight;
  const GettoniBar({
    super.key,
    required this.filled,
    required this.total,
    this.filledColor,
    this.cellHeight = 6,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white.withOpacity(0.12) : AppTokens.line;
    final fill = filledColor ?? (isDark ? AppTokens.darkBrand : AppTokens.brand);
    return Row(
      children: List.generate(total, (i) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
            height: cellHeight,
            decoration: BoxDecoration(
              color: i < filled ? fill : bg,
              borderRadius: BorderRadius.circular(cellHeight / 2),
            ),
          ),
        );
      }),
    );
  }
}

class VsLayout extends StatelessWidget {
  final Widget homeCrest;
  final String homeName;
  final String homeLabel;
  final Widget awayCrest;
  final String awayName;
  final String awayLabel;

  const VsLayout({
    super.key,
    required this.homeCrest,
    required this.homeName,
    this.homeLabel = 'CASA',
    required this.awayCrest,
    required this.awayName,
    this.awayLabel = 'OSPITE',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              homeCrest,
              const SizedBox(height: 8),
              Text(
                homeName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                homeLabel,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  color: AppTokens.textOnInkMute,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'VS',
            style: _display(30, color: Colors.white.withOpacity(0.4), letter: 0.06),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              awayCrest,
              const SizedBox(height: 8),
              Text(
                awayName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                awayLabel,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  color: AppTokens.textOnInkMute,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CrestBox extends StatelessWidget {
  final String initials;
  final bool filled;
  final double size;
  final double radius;
  final double fontSize;
  final Color? bg;
  final Color? fg;

  /// Logo esplicito; se `null` e [showTeamLogo] e' vero si usa quello della
  /// squadra attiva. Di default spento: CrestBox serve anche per avversari e
  /// persone.
  final Uint8List? logo;
  final bool showTeamLogo;

  const CrestBox({
    super.key,
    required this.initials,
    this.filled = true,
    this.size = 54,
    this.radius = 14,
    this.fontSize = 22,
    this.bg,
    this.fg,
    this.logo,
    this.showTeamLogo = false,
  });

  @override
  Widget build(BuildContext context) {
    return TeamCrest(
      initials: initials,
      logo: logo ?? (showTeamLogo ? teamLogoOf(context) : null),
      size: size,
      radius: radius,
      fontSize: fontSize,
      bg: filled ? (bg ?? AppTokens.brand) : Colors.white.withOpacity(0.08),
      fg: filled ? (fg ?? AppTokens.brandInk) : Colors.white.withOpacity(0.7),
      border: filled ? null : Border.all(color: Colors.white.withOpacity(0.2)),
    );
  }
}

/// Logo della squadra attiva (gia' decodificato e cachato dal provider),
/// `null` se non c'e' o se non siamo sotto un [ThemeProvider].
Uint8List? teamLogoOf(BuildContext context) {
  try {
    return context.select<ThemeProvider, Uint8List?>((t) => t.logoBytes);
  } on ProviderNotFoundException {
    return null;
  }
}

/// Stemma squadra: il logo caricato se c'e', altrimenti le iniziali.
/// Unifica i quadratini fotocopia di top bar, VsLayout, liste squadre.
class TeamCrest extends StatelessWidget {
  final String initials;
  final Uint8List? logo;
  final double size;
  final double radius;
  final double fontSize;
  final Color bg;
  final Color fg;
  final BoxBorder? border;

  const TeamCrest({
    super.key,
    required this.initials,
    this.logo,
    this.size = 40,
    this.radius = 10,
    this.fontSize = 18,
    this.bg = AppTokens.ink,
    this.fg = AppTokens.brand,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = logo;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: border,
      ),
      alignment: Alignment.center,
      child: bytes == null
          ? _initialsText()
          : Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              // Decodifica alla dimensione mostrata, non a quella del file.
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
              errorBuilder: (_, __, ___) => _initialsText(),
            ),
    );
  }

  Widget _initialsText() => Text(
        initials,
        style: _display(fontSize, color: fg, letter: 0.04),
      );
}

/// Tono del [FormatBadge].
enum FormatBadgeTone {
  /// Pill ink con testo brand (bianca con testo ink in tema scuro): top bar su paper.
  ink,

  /// Pill brand con testo brandInk: elemento selezionato / in evidenza.
  brand,

  /// Pill traslucida bianca: su superfici ink.
  onInk,

  /// Pill brandSoft con testo brandInk: liste neutre.
  soft,
}

/// Badge del formato di gioco (A5, A7, A8, A11).
class FormatBadge extends StatelessWidget {
  final TeamFormat format;
  final FormatBadgeTone tone;
  final double fontSize;

  const FormatBadge(
    this.format, {
    super.key,
    this.tone = FormatBadgeTone.ink,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bg;
    Color fg;
    BoxBorder? border;
    switch (tone) {
      case FormatBadgeTone.ink:
        bg = isDark ? Colors.white : AppTokens.ink;
        fg = isDark ? AppTokens.ink : AppTokens.brand;
        break;
      case FormatBadgeTone.brand:
        bg = AppTokens.brand;
        fg = AppTokens.brandInk;
        break;
      case FormatBadgeTone.onInk:
        bg = Colors.white.withOpacity(0.10);
        fg = Colors.white;
        border = Border.all(color: Colors.white.withOpacity(0.18));
        break;
      case FormatBadgeTone.soft:
        bg = isDark ? AppTokens.brand.withOpacity(0.15) : AppTokens.brandSoft;
        fg = isDark ? AppTokens.darkBrand : AppTokens.brandInk;
        break;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.7, vertical: fontSize * 0.2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTokens.rChip),
        border: border,
      ),
      child: Text(
        format.shortLabel,
        style: _display(fontSize, color: fg, letter: 0.06 * fontSize, height: 1.1),
      ),
    );
  }
}

class StatusDotBadge extends StatelessWidget {
  final Color color;
  final Widget child;
  const StatusDotBadge({super.key, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? AppTokens.darkPaper : AppTokens.paper,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class StoryAvatar extends StatelessWidget {
  final String name;
  final int? number;
  final String status; // 'me' | 'ok' | 'warn' | 'no'
  final double size;

  const StoryAvatar({
    super.key,
    required this.name,
    this.number,
    this.status = 'ok',
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muteText = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    final faintText = isDark ? AppTokens.darkTextMute.withOpacity(0.5) : AppTokens.textFaint;

    final hue = name.codeUnits.fold<int>(0, (a, c) => a + c) % 360;
    final ringBrand = status == 'me';
    final grayed = status == 'no';

    Color dotColor;
    Widget dotChild;
    switch (status) {
      case 'ok':
      case 'me':
        dotColor = AppTokens.ok;
        dotChild = const Icon(Icons.check, size: 10, color: Colors.white);
        break;
      case 'warn':
        dotColor = AppTokens.warn;
        dotChild = Text(
          '?',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        );
        break;
      default:
        dotColor = AppTokens.bad;
        dotChild = const Icon(Icons.close, size: 10, color: Colors.white);
    }

    return SizedBox(
      width: size + 4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: ringBrand ? const EdgeInsets.all(2) : null,
            decoration: ringBrand
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const SweepGradient(
                      colors: [
                        AppTokens.brand,
                        AppTokens.brandGlow,
                        AppTokens.brand,
                      ],
                    ),
                  )
                : null,
            child: ColorFiltered(
              colorFilter: grayed
                  ? const ColorFilter.matrix([
                      0.33, 0.33, 0.33, 0, 0,
                      0.33, 0.33, 0.33, 0, 0,
                      0.33, 0.33, 0.33, 0, 0,
                      0, 0, 0, 0.4, 0,
                    ])
                  : const ColorFilter.matrix([
                      1, 0, 0, 0, 0,
                      0, 1, 0, 0, 0,
                      0, 0, 1, 0, 0,
                      0, 0, 0, 1, 0,
                    ]),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: HSLColor.fromAHSL(1, hue.toDouble(), 0.18, 0.22).toColor(),
                      shape: BoxShape.circle,
                      border: ringBrand
                          ? Border.all(
                              color: isDark ? AppTokens.darkPaper : AppTokens.paper,
                              width: 2,
                            )
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      number?.toString() ?? _initials(name),
                      style: _display(size * 0.45, color: Colors.white),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: StatusDotBadge(color: dotColor, child: dotChild),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: grayed ? faintText : muteText,
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p.isEmpty ? '' : p[0]).join().toUpperCase();
  }
}

class AppShell extends StatelessWidget {
  final Widget? topBar;
  final Widget body;
  final Widget? tabbar;
  final bool dark;
  final Widget? floating;

  const AppShell({
    super.key,
    this.topBar,
    required this.body,
    this.tabbar,
    this.dark = false,
    this.floating,
  });

  @override
  Widget build(BuildContext context) {
    final paper = dark ? AppTokens.darkPaper : AppTokens.paper;
    return Container(
      color: paper,
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                if (topBar != null) topBar!,
                Expanded(child: body),
                if (tabbar != null) const SizedBox(height: 78),
              ],
            ),
            if (tabbar != null)
              Positioned(left: 12, right: 12, bottom: 14, child: tabbar!),
            if (floating != null) floating!,
          ],
        ),
      ),
    );
  }
}

class AppTabBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;
  final List<AppTab> tabs;

  const AppTabBar({
    super.key,
    required this.activeIndex,
    required this.onTap,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : AppTokens.ink;
    final active = isDark ? AppTokens.darkBrand : AppTokens.brand;
    const inactive = AppTokens.textOnInkMute;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: isDark ? Border.all(color: AppTokens.darkLine) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.6 : 0.25),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final t = tabs[i];
          final sel = i == activeIndex;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onTap(i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(t.icon, size: 22, color: sel ? active : inactive),
                      if (t.badge != null)
                        Positioned(top: -4, right: -6, child: t.badge!),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    t.label,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: sel ? active : inactive,
                      letterSpacing: 0.02,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class AppTab {
  final IconData icon;
  final String label;
  final Widget? badge;
  const AppTab(this.icon, this.label, {this.badge});
}

class PitchGlow extends StatelessWidget {
  final Widget child;
  final Alignment alignment;
  const PitchGlow({
    super.key,
    required this.child,
    this.alignment = Alignment.bottomCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: alignment,
                  radius: 0.8,
                  colors: [
                    AppTokens.brand.withOpacity(0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Alone radiale brand posizionato in un angolo: sostituisce i cerchi
/// `Positioned` copiati a mano in login, scelta squadra e live.
class GlowSpot extends StatelessWidget {
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double size;
  final double opacity;
  const GlowSpot({
    super.key,
    this.top,
    this.left,
    this.right,
    this.bottom,
    this.size = 480,
    this.opacity = 0.22,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [AppTokens.brand.withOpacity(opacity), Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card standard: fondo card, bordo line, raggio rCard. Con [onInk] diventa
/// una lastra traslucida per le schermate scure. [onTap] la rende cliccabile.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final bool onInk;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin,
    this.radius = AppTokens.rCard,
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.onInk = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = color ??
        (onInk
            ? Colors.white.withOpacity(0.04)
            : (isDark ? AppTokens.darkCard : AppTokens.card));
    final line = borderColor ??
        (onInk
            ? Colors.white.withOpacity(0.08)
            : (isDark ? AppTokens.darkLine : AppTokens.line));
    Widget box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: line, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
    if (onTap != null) {
      box = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: box,
        ),
      );
    }
    if (margin != null) box = Padding(padding: margin!, child: box);
    return box;
  }
}

/// Stato vuoto: icona in un riquadro brand tenue, titolo Bebas, messaggio
/// smorzato e un'azione opzionale.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool onInk;
  final EdgeInsets padding;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.onInk = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = onInk || Theme.of(context).brightness == Brightness.dark;
    final textColor = onInk ? Colors.white : (isDark ? AppTokens.darkText : AppTokens.text);
    final muteColor = onInk
        ? Colors.white.withOpacity(0.6)
        : (isDark ? AppTokens.darkTextMute : AppTokens.textMute);
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTokens.brand.withOpacity(0.15),
                borderRadius: BorderRadius.circular(22),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: isDark ? AppTokens.darkBrand : AppTokens.brand, size: 34),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: _display(28, color: textColor, letter: 0.02, height: 1.05),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(fontSize: 13, color: muteColor, height: 1.4),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 22), action!],
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet dell'app: fondo card (o ink), angoli 24 in alto, maniglia.
/// Il [builder] riceve il context del sheet; per gli sheet scrollabili passare
/// `scrollControlled: true` e gestire l'altezza dentro.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool onInk = false,
  bool scrollControlled = false,
  bool handle = true,
  EdgeInsets padding = const EdgeInsets.fromLTRB(20, 8, 20, 20),
}) {
  final isDark = onInk || Theme.of(context).brightness == Brightness.dark;
  final bg = onInk ? AppTokens.ink2 : (isDark ? AppTokens.darkCard : AppTokens.card);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: scrollControlled,
    backgroundColor: bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.rCardLg)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (handle) AppSheetHandle(onInk: onInk),
              builder(ctx),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Maniglia dei bottom sheet (40x4, centrata).
class AppSheetHandle extends StatelessWidget {
  final bool onInk;
  const AppSheetHandle({super.key, this.onInk = false});

  @override
  Widget build(BuildContext context) {
    final isDark = onInk || Theme.of(context).brightness == Brightness.dark;
    final c = onInk
        ? Colors.white.withOpacity(0.25)
        : (isDark ? AppTokens.darkTextMute : AppTokens.textMute).withOpacity(0.3);
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 4, bottom: 16),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}

/// Riga d'azione dentro un [showAppSheet]: icona in riquadro, etichetta,
/// sottotitolo opzionale. [destructive] la colora di rosso.
class AppSheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool destructive;
  final bool selected;
  final Widget? trailing;
  final bool onInk;
  final VoidCallback? onTap;

  const AppSheetAction({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.destructive = false,
    this.selected = false,
    this.trailing,
    this.onInk = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = onInk || Theme.of(context).brightness == Brightness.dark;
    final textColor = onInk ? Colors.white : (isDark ? AppTokens.darkText : AppTokens.text);
    final muteColor = onInk ? AppTokens.textOnInkMute : (isDark ? AppTokens.darkTextMute : AppTokens.textMute);
    final lineColor = onInk ? Colors.white.withOpacity(0.1) : (isDark ? AppTokens.darkLine : AppTokens.line);
    final fg = destructive ? AppTokens.bad : textColor;
    final iconBg = destructive
        ? AppTokens.softOf(AppTokens.bad, isDark: isDark)
        : (onInk ? Colors.white.withOpacity(0.06) : (isDark ? AppTokens.ink3 : AppTokens.paperLow));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.rButton),
      child: Opacity(
        opacity: onTap == null && !selected ? 0.5 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: destructive ? Colors.transparent : lineColor),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: destructive ? AppTokens.bad : muteColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: GoogleFonts.spaceGrotesk(fontSize: 12, color: muteColor, height: 1.2),
                      ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (selected)
                Icon(Icons.check_circle, color: isDark ? AppTokens.darkBrand : AppTokens.brand, size: 20)
              else if (onTap != null)
                Icon(Icons.chevron_right, color: muteColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila di chip di scelta singola nello stile dei filtri della rosa:
/// attivo = ink con testo bianco, inattivo = card con bordo line.
/// Con [allowNull] si puo' deselezionare toccando di nuovo il chip attivo.
class AppChoiceChips<T> extends StatelessWidget {
  final List<T> values;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T?> onChanged;
  final bool allowNull;
  final bool onInk;
  final double spacing;

  const AppChoiceChips({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
    this.allowNull = false,
    this.onInk = false,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = onInk || Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: values.map((v) {
        final active = v == selected;
        final bg = active
            ? (onInk ? AppTokens.brand : (isDark ? Colors.white : AppTokens.ink))
            : (onInk ? Colors.white.withOpacity(0.06) : (isDark ? AppTokens.darkCard : AppTokens.card));
        final fg = active
            ? (onInk ? AppTokens.brandInk : (isDark ? AppTokens.ink : Colors.white))
            : (onInk ? Colors.white.withOpacity(0.75) : (isDark ? AppTokens.darkTextMute : AppTokens.textMute));
        final border = active
            ? Colors.transparent
            : (onInk ? Colors.white.withOpacity(0.12) : (isDark ? AppTokens.darkLine : AppTokens.line));
        return InkWell(
          onTap: () {
            if (active) {
              if (allowNull) onChanged(null);
              return;
            }
            onChanged(v);
          },
          borderRadius: BorderRadius.circular(AppTokens.rChip),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppTokens.rChip),
              border: Border.all(color: border),
            ),
            child: Text(
              label(v),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Riquadro di avviso: tinta e bordo del colore semantico, testo, azione
/// opzionale.
class NoticeBox extends StatelessWidget {
  final String text;
  final AppChipVariant variant;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool onInk;
  final EdgeInsets margin;

  const NoticeBox({
    super.key,
    required this.text,
    this.variant = AppChipVariant.warn,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.onInk = false,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = onInk || Theme.of(context).brightness == Brightness.dark;
    late Color sem;
    late Color ink;
    switch (variant) {
      case AppChipVariant.ok:
        sem = AppTokens.ok;
        ink = isDark ? AppTokens.ok : AppTokens.okInk;
        break;
      case AppChipVariant.bad:
        sem = AppTokens.bad;
        ink = isDark ? AppTokens.bad : AppTokens.badInk;
        break;
      case AppChipVariant.brand:
        sem = AppTokens.brand;
        ink = isDark ? AppTokens.darkBrand : AppTokens.brandInk;
        break;
      case AppChipVariant.warn:
      case AppChipVariant.neutral:
      case AppChipVariant.dark:
        sem = AppTokens.warn;
        ink = isDark ? AppTokens.warn : AppTokens.warnInk;
        break;
    }
    return Padding(
      padding: margin,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: sem.withOpacity(isDark ? 0.12 : 0.10),
          borderRadius: BorderRadius.circular(AppTokens.rButton),
          border: Border.all(color: sem.withOpacity(0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon ?? Icons.info_outline, size: 18, color: sem),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.spaceGrotesk(fontSize: 13, color: ink, height: 1.35),
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: ink,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dialog di conferma coerente: titolo, messaggio, Annulla + azione.
/// Con [destructive] il bottone e' rosso. Ritorna `true` se confermato.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Conferma',
  String cancelLabel = 'Annulla',
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: AppTokens.bad,
                  foregroundColor: Colors.white,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}
