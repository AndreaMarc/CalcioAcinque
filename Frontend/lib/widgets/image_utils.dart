import 'dart:typed_data';
import 'dart:ui' as ui;

/// Riduce un'immagine a [maxSide] pixel sul lato lungo e la ricodifica in PNG.
/// Un logo da fotocamera pesa megabyte: cosi' resta sotto i limiti del server
/// e della memoria locale, e il crest da 32 px non decodifica 4000x3000.
Future<Uint8List> shrinkImage(Uint8List bytes, {int maxSide = 256}) async {
  final probe = await ui.instantiateImageCodec(bytes);
  final first = await probe.getNextFrame();
  final w = first.image.width;
  final h = first.image.height;
  first.image.dispose();
  probe.dispose();

  int tw = w, th = h;
  if (w > maxSide || h > maxSide) {
    final scale = maxSide / (w > h ? w : h);
    tw = (w * scale).round().clamp(1, maxSide);
    th = (h * scale).round().clamp(1, maxSide);
  }

  final codec = await ui.instantiateImageCodec(bytes, targetWidth: tw, targetHeight: th);
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  frame.image.dispose();
  codec.dispose();
  if (data == null) return bytes;
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}
