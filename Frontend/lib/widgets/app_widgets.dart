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

class AppTopBar extends StatelessWidget {
  final String teamInitials;
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Color? crestColor;

  const AppTopBar({
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
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: crestColor ?? (isDark ? Colors.white : AppTokens.ink),
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Text(
                teamInitials,
                style: _display(
                  18,
                  color: isDark ? AppTokens.ink : AppTokens.brand,
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
  const Eyebrow(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = color ?? (isDark ? AppTokens.darkTextMute : AppTokens.textMute);
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
    final textColor = isDark ? AppTokens.darkText : AppTokens.text;
    final muteColor = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
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

enum AppChipVariant { neutral, ok, warn, bad, brand, dark }

class AppChip extends StatelessWidget {
  final String text;
  final AppChipVariant variant;
  final IconData? leadingIcon;
  final Widget? leading;
  final EdgeInsets padding;
  final double fontSize;

  const AppChip({
    super.key,
    required this.text,
    this.variant = AppChipVariant.neutral,
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
      case AppChipVariant.ok:
        bg = isDark ? AppTokens.ok.withOpacity(0.15) : const Color(0xFFDCF6E8);
        fg = isDark ? AppTokens.ok : const Color(0xFF096B3A);
        break;
      case AppChipVariant.warn:
        bg = isDark ? AppTokens.warn.withOpacity(0.15) : const Color(0xFFFCEDD2);
        fg = isDark ? AppTokens.warn : const Color(0xFF8A5510);
        break;
      case AppChipVariant.bad:
        bg = isDark ? AppTokens.bad.withOpacity(0.15) : const Color(0xFFFCE0E0);
        fg = isDark ? AppTokens.bad : const Color(0xFF9E2323);
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
        color: filled ? (bg ?? AppTokens.brand) : Colors.white.withOpacity(0.08),
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
              ? (fg ?? AppTokens.brandInk)
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
                        Color(0xFF00FFA6),
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
