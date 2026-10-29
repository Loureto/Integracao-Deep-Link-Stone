import 'dart:typed_data';
import 'dart:ui' as ui;

/// 1 cm de papel na impressora de 8 pontos por milímetro. A NFC-e chega do conversor sem a sobra do PDF, e sem
/// esta margem a última linha pode ficar antes da serrilha, como aconteceu na Stone.
const _bottomMargin = 80;

/// Devolve o PNG [png] com [_bottomMargin] linhas brancas no fim, para a impressão de comprovantes. Lança
/// [Exception] quando os bytes não formam uma imagem.
Future<Uint8List> withBottomMargin(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  try {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
      ..drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src)
      ..drawImage(image, ui.Offset.zero, ui.Paint());
    final picture = recorder.endRecording();
    final ui.Image withMargin;
    try {
      withMargin = await picture.toImage(image.width, image.height + _bottomMargin);
    } finally {
      picture.dispose();
    }
    try {
      final bytes = await withMargin.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List();
    } finally {
      withMargin.dispose();
    }
  } finally {
    image.dispose();
    codec.dispose();
  }
}
