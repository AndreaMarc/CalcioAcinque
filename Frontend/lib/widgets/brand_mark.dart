import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/theme_provider.dart';

/// Marchio InCampo: il centrocampo visto dall'alto (linea di meta' campo
/// spezzata dal cerchio, dischetto centrale) su un quadrato arrotondato.
///
/// La geometria e' in "viewBox 100" ed e' la stessa di `web/icons/brand.svg`
/// e dello script che genera le icone PWA: se cambia una, cambiano tutte.
class BrandMark extends StatelessWidget {
  final double size;

  /// `true` = quadrato ink con tracce brand (per superfici chiare);
  /// `false` = quadrato brand con tracce ink (default, per fondo ink).
  final bool onPaper;

  const BrandMark({super.key, this.size = 36, this.onPaper = false});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _BrandMarkPainter(onPaper),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  final bool onPaper;
  const _BrandMarkPainter(this.onPaper);

  @override
  void paint(Canvas c, Size s) {
    final u = s.width / 100;
    final bg = onPaper ? AppTokens.ink : AppTokens.brand;
    final fg = onPaper ? AppTokens.brand : AppTokens.ink;

    c.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(26 * u)),
      Paint()..color = bg,
    );

    final stroke = Paint()
      ..color = fg
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7 * u
      ..strokeCap = StrokeCap.round;

    // Linea di meta' campo, interrotta dal cerchio di centrocampo
    c.drawLine(Offset(14 * u, 50 * u), Offset(27 * u, 50 * u), stroke);
    c.drawLine(Offset(73 * u, 50 * u), Offset(86 * u, 50 * u), stroke);
    // Cerchio di centrocampo
    c.drawCircle(Offset(50 * u, 50 * u), 19 * u, stroke);
    // Dischetto
    c.drawCircle(Offset(50 * u, 50 * u), 4.5 * u, Paint()..color = fg);
  }

  @override
  bool shouldRepaint(_BrandMarkPainter old) => old.onPaper != onPaper;
}

/// Marchio + wordmark "INCAMPO" in Bebas Neue, allineati in riga.
class BrandWordmark extends StatelessWidget {
  final double markSize;
  final Color color;
  final bool onPaper;

  const BrandWordmark({
    super.key,
    this.markSize = 36,
    this.color = Colors.white,
    this.onPaper = false,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = markSize * 0.61;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: markSize, onPaper: onPaper),
        SizedBox(width: markSize * 0.28),
        Text(
          'INCAMPO',
          style: GoogleFonts.bebasNeue(
            fontSize: fontSize,
            color: color,
            letterSpacing: 0.04 * fontSize,
            height: 1,
          ),
        ),
      ],
    );
  }
}

/// Etichetta della stagione sportiva corrente, es. "25/26".
/// La stagione parte a luglio: da gennaio a giugno si e' ancora in quella
/// iniziata l'anno prima.
String currentSeasonLabel([DateTime? now]) {
  final d = now ?? DateTime.now();
  final start = d.month >= 7 ? d.year : d.year - 1;
  String yy(int y) => (y % 100).toString().padLeft(2, '0');
  return '${yy(start)}/${yy(start + 1)}';
}
