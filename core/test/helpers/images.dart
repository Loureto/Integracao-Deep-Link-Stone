import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// PNG com [tones] de cinza em linhas de [width] pontos.
Future<Uint8List> png(List<int> tones, {int? width}) async {
  final columns = width ?? tones.length;
  final pixels = Uint8List(tones.length * 4);
  for (final (i, tone) in tones.indexed) {
    pixels.setAll(i * 4, [tone, tone, tone, 255]);
  }
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    columns,
    tones.length ~/ columns,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  final image = await completer.future;
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

/// Largura e altura do PNG [bytes] e o tom de cinza de cada pixel, linha a linha.
Future<({int width, int height, List<int> tones})> decodePng(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final image = (await codec.getNextFrame()).image;
  final pixels = (await image.toByteData())!.buffer.asUint8List();
  return (
    width: image.width,
    height: image.height,
    tones: [for (var i = 0; i < pixels.length; i += 4) pixels[i]],
  );
}
