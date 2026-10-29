import 'dart:convert';
import 'dart:ui' as ui;

import 'package:dependencies/dependencies.dart';
import 'package:flutter/services.dart';

import '../../data/data.dart';
import '../../domain/domain.dart';

/// [IPdfImageConverter] pelo pdfx, que no Android renderiza com o `PdfRenderer` do sistema.
class PdfImageConverter implements IPdfImageConverter {
  /// Pontos por linha da impressora térmica dos terminais, de bobina de 58 mm.
  static const paperWidth = 384;

  /// A altura sai esticada na proporção 2.0 / 1.7 do `parsePdfToBitMap` do flutter_acquirers_sdk, já usada em
  /// produção nas impressoras dos terminais. Lá a escala era fixa, pensada para a NFC-e de 80 mm.
  static const _heightStretch = 2.0 / 1.7;

  /// Tom a partir do qual o pixel conta como papel em branco. O contorno suavizado das letras fica abaixo dele.
  static const _paper = 250;

  final Future<PdfDocument> Function(Uint8List data) _open;

  const PdfImageConverter({Future<PdfDocument> Function(Uint8List data) open = PdfDocument.openData})
    : _open = open;

  @override
  Future<Either<PdfImageFailure, Uint8List>> firstPageToPng(String pdfBase64) async {
    final Uint8List data;
    try {
      // A NFC-e costuma chegar da API com quebras de linha no base64.
      data = base64Decode(pdfBase64.replaceAll(RegExp(r'\s'), ''));
    } on FormatException {
      return left(PdfImageFailure.invalidBase64());
    }
    if (data.isEmpty) return left(PdfImageFailure.invalidBase64());

    try {
      final document = await _open(data);
      try {
        return await _renderFirstPage(document);
      } finally {
        await document.close();
      }
    } on Exception catch (e) {
      return left(PdfImageFailure.invalidPdf(e is PlatformException ? e.message : null));
    }
  }

  static Future<Either<PdfImageFailure, Uint8List>> _renderFirstPage(PdfDocument document) async {
    final page = await document.getPage(1);
    try {
      // A página inteira ocupa a largura da bobina: a NFC-e de 80 mm encolhe e a de 58 mm cresce.
      final scale = paperWidth / page.width;
      final image = await page.render(
        width: paperWidth.toDouble(),
        height: page.height * scale * _heightStretch,
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
        forPrint: true,
      );
      if (image == null) return left(PdfImageFailure.renderFailed());

      try {
        return right(await _trim(image.bytes));
      } on Exception {
        return left(PdfImageFailure.renderFailed());
      }
    } finally {
      await page.close();
    }
  }

  /// Corta as sobras em branco em volta do conteúdo e o centraliza na largura da imagem. A NFC-e pode vir numa
  /// página da altura do A4, que sem o corte gastaria metade do papel em branco.
  static Future<Uint8List> _trim(Uint8List png) async {
    final codec = await ui.instantiateImageCodec(png);
    final image = (await codec.getNextFrame()).image;
    try {
      final ink = await _inkBounds(image);
      if (ink == null || (ink.width == image.width && ink.height == image.height)) return png;

      final recorder = ui.PictureRecorder();
      final left = ((image.width - ink.width) / 2).floorToDouble();
      ui.Canvas(recorder)
        ..drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src)
        ..drawImageRect(image, ink, ui.Rect.fromLTWH(left, 0, ink.width, ink.height), ui.Paint());
      final trimmed = await recorder.endRecording().toImage(image.width, ink.height.toInt());
      try {
        final bytes = await trimmed.toByteData(format: ui.ImageByteFormat.png);
        return bytes!.buffer.asUint8List();
      } finally {
        trimmed.dispose();
      }
    } finally {
      image.dispose();
      codec.dispose();
    }
  }

  /// Menor retângulo com todos os pixels que não são papel em branco, ou nulo se a página estiver vazia.
  static Future<ui.Rect?> _inkBounds(ui.Image image) async {
    final pixels = (await image.toByteData())!.buffer.asUint8List();
    var top = image.height, bottom = -1, left = image.width, right = -1;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final i = (y * image.width + x) * 4;
        if (pixels[i] < _paper || pixels[i + 1] < _paper || pixels[i + 2] < _paper) {
          if (y < top) top = y;
          bottom = y;
          if (x < left) left = x;
          if (x > right) right = x;
        }
      }
    }
    if (bottom < 0) return null;
    return ui.Rect.fromLTRB(left.toDouble(), top.toDouble(), right + 1.0, bottom + 1.0);
  }
}
