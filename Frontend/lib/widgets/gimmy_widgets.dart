import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/theme_provider.dart';

/// Safe initials extractor: returns 1-2 uppercase chars, falls back to [fallback].
String teamInitials(String name, {String fallback = 'CA'}) {
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

class GimmyTopBar extends StatelessWidget {
  final String teamInitials;
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Color? crestColor;

  const GimmyTopBar({
    super.key,
    this.teamInitials = 'CA',
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
    this.crestColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? GimmyTokens.darkText : GimmyTokens.text;
    final muteColor = isDark ? GimmyTokens.darkTextMute : GimmyTokens.textMute;
    final lineColor = isDark ? GimmyTokens.darkLine : GimmyTokens.line;
    final cardColor = isDark ? GimmyTokens.darkCard : GimmyTokens.card;

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
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: crestColor ?? (isDark ? Colors.white : GimmyTokens.ink),
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Text(
                teamInitials,
                style: _display(
                  18,
                  color: isDark ? GimmyTokens.ink : GimmyTokens.brand,
                  letter: 0.04,
                ),
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
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

  static Widget iconAction(
    BuildContext context,
    IconData icon,
    VoidCallback onTap, {
    Widget? badge,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? GimmyTokens.darkText : GimmyTokens.text;
    final lineColor = isDark ? GimmyTokens.darkLine : GimmyTokens.line;
    final cardColor = isDark ? GimmyTokens.darkCard : GimmyTokens.card;
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
  const Eyebrow(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = color ?? (isDark ? GimmyTokens.darkTextMute : GimmyTokens.textMute);
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
  const SectionHead({
    super.key,
    required this.title,
    this.more,
    this.onMore,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 10),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? GimmyTokens.darkText : GimmyTokens.text;
    final muteColor = isDark ? GimmyTokens.darkTextMute : GimmyTokens.textMute;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title, style: _display(22, color: textColor, letter: 0.02)),
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

enum GimmyChipVariant { neutral, ok, warn, bad, brand, dark }

class GimmyChip extends StatelessWidget {
  final String text;
  final GimmyChipVariant variant;
  final IconData? leadingIcon;
  final Widget? leading;
  final EdgeInsets padding;
  final double fontSize;

  const GimmyChip({
    super.key,
    required this.text,
    this.variant = GimmyChipVariant.neutral,
    this.leadingIcon,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    late Color bg;
    late Color fg;
    switch (variant) {
      case GimmyChipVariant.ok:
        bg = isDark ? GimmyTokens.ok.withOpacity(0.15) : const Color(0xFFDCF6E8);
        fg = isDark ? GimmyTokens.ok : const Color(0xFF096B3A);
        break;
      case GimmyChipVariant.warn:
        bg = isDark ? GimmyTokens.warn.withOpacity(0.15) : const Color(0xFFFCEDD2);
        fg = isDark ? GimmyTokens.warn : const Color(0xFF8A5510);
        break;
      case GimmyChipVariant.bad:
        bg = isDark ? GimmyTokens.bad.withOpacity(0.15) : const Color(0xFFFCE0E0);
        fg = isDark ? GimmyTokens.bad : const Color(0xFF9E2323);
        break;
      case GimmyChipVariant.brand:
        bg = isDark ? GimmyTokens.brand.withOpacity(0.15) : GimmyTokens.brandSoft;
        fg = isDark ? GimmyTokens.darkBrand : GimmyTokens.brandInk;
        break;
      case GimmyChipVariant.dark:
        bg = isDark ? GimmyTokens.ink3 : GimmyTokens.ink3;
        fg = Colors.white;
        break;
      case GimmyChipVariant.neutral:
        bg = isDark ? GimmyTokens.ink3 : GimmyTokens.card;
        fg = isDark ? GimmyTokens.darkTextMute : GimmyTokens.textMute;
        break;
    }

    final borderColor = variant == GimmyChipVariant.neutral
        ? (isDark ? GimmyTokens.darkLine : GimmyTokens.line)
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
        color: bg ?? GimmyTokens.ink,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text(
        number?.toString() ?? '?',
        style: _display(fontSize, color: fg ?? GimmyTokens.brand),
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
        color: GimmyTokens.ink,
        borderRadius: BorderRadius.circular(radius),
        border: isDark
            ? Border.all(color: GimmyTokens.brand.withOpacity(0.12))
            : null,
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: GimmyTokens.brand.withOpacity(0.06),
              blurRadius: 60,
              offset: const Offset(0, 20),
            )
          else
            const BoxShadow(
              color: Color(0x1A0A0E0F),
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
          GimmyTokens.brand.withOpacity(0.22),
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

class GimmyBar extends StatelessWidget {
  final double value; // 0..1
  final double height;
  final Color? fillColor;

  const GimmyBar({
    super.key,
    required this.value,
    this.height = 6,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? GimmyTokens.darkLine : GimmyTokens.line;
    final fill = fillColor ?? (isDark ? GimmyTokens.darkBrand : GimmyTokens.brand);
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

class GimmyTokensBar extends StatelessWidget {
  final int filled;
  final int total;
  final Color? filledColor;
  final double cellHeight;
  const GimmyTokensBar({
    super.key,
    required this.filled,
    required this.total,
    this.filledColor,
    this.cellHeight = 6,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white.withOpacity(0.12) : GimmyTokens.line;
    final fill = filledColor ?? (isDark ? GimmyTokens.darkBrand : GimmyTokens.brand);
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
                  color: const Color(0xFF9FA7A9),
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
                  color: const Color(0xFF9FA7A9),
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

  const CrestBox({
    super.key,
    required this.initials,
    this.filled = true,
    this.size = 54,
    this.radius = 14,
    this.fontSize = 22,
    this.bg,
    this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? (bg ?? GimmyTokens.brand) : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(radius),
        border: filled
            ? null
            : Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
                style: BorderStyle.solid,
              ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: _display(
          fontSize,
          color: filled
              ? (fg ?? GimmyTokens.brandInk)
              : Colors.white.withOpacity(0.7),
        ),
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
          color: isDark ? GimmyTokens.darkPaper : GimmyTokens.paper,
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
    final muteText = isDark ? GimmyTokens.darkTextMute : GimmyTokens.textMute;
    final faintText = isDark ? GimmyTokens.darkTextMute.withOpacity(0.5) : GimmyTokens.textFaint;

    final hue = name.codeUnits.fold<int>(0, (a, c) => a + c) % 360;
    final ringBrand = status == 'me';
    final grayed = status == 'no';

    Color dotColor;
    Widget dotChild;
    switch (status) {
      case 'ok':
      case 'me':
        dotColor = GimmyTokens.ok;
        dotChild = const Icon(Icons.check, size: 10, color: Colors.white);
        break;
      case 'warn':
        dotColor = GimmyTokens.warn;
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
        dotColor = GimmyTokens.bad;
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
                        GimmyTokens.brand,
                        Color(0xFF00FFA6),
                        GimmyTokens.brand,
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
                              color: isDark ? GimmyTokens.darkPaper : GimmyTokens.paper,
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

class GimmyScaffold extends StatelessWidget {
  final Widget? topBar;
  final Widget body;
  final Widget? tabbar;
  final bool dark;
  final Widget? floating;

  const GimmyScaffold({
    super.key,
    this.topBar,
    required this.body,
    this.tabbar,
    this.dark = false,
    this.floating,
  });

  @override
  Widget build(BuildContext context) {
    final paper = dark ? GimmyTokens.darkPaper : GimmyTokens.paper;
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

class GimmyTabBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;
  final List<GimmyTab> tabs;

  const GimmyTabBar({
    super.key,
    required this.activeIndex,
    required this.onTap,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : GimmyTokens.ink;
    final active = isDark ? GimmyTokens.darkBrand : GimmyTokens.brand;
    const inactive = GimmyTokens.textOnInkMute;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: isDark ? Border.all(color: GimmyTokens.darkLine) : null,
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

class GimmyTab {
  final IconData icon;
  final String label;
  final Widget? badge;
  const GimmyTab(this.icon, this.label, {this.badge});
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
                    GimmyTokens.brand.withOpacity(0.22),
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
