import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:core/infrastructure/receipt_image/bottom_margin.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/images.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('acrescenta 80 linhas brancas abaixo da imagem', () async {
    // A impressora tem 8 pontos por milímetro: 1 cm são 80 linhas abaixo da última linha da imagem.
    final result = await decodePng(await withBottomMargin(await png([0, 0, 0])));

    expect([result.width, result.height], [3, 81]);
    expect(result.tones.take(3), [0, 0, 0]);
    expect(result.tones.skip(3), everyElement(255));
  });

  test('libera o Picture usado para a margem', () async {
    final image = await png([0, 0, 0]);
    final created = <ui.Picture>[];
    final disposed = <ui.Picture>[];
    ui.Picture.onCreate = created.add;
    ui.Picture.onDispose = disposed.add;
    addTearDown(() {
      ui.Picture.onCreate = null;
      ui.Picture.onDispose = null;
    });

    await withBottomMargin(image);

    expect(created, hasLength(1));
    expect(disposed, created);
  });

  test('bytes que não formam imagem lançam Exception', () {
    expect(withBottomMargin(Uint8List.fromList([1, 2, 3])), throwsException);
  });
}
