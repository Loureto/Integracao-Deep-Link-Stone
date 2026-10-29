import 'dart:convert';
import 'dart:ui' as ui;

import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pdf = Uint8List.fromList(utf8.encode('%PDF-1.4 NFC-e'));

  /// O que o renderizador devolve por padrão: conteúdo que já ocupa a imagem toda, sem sobra para cortar.
  late Uint8List png;

  setUpAll(() async => png = await _png(384, 40, ink: const ui.Rect.fromLTWH(0, 0, 384, 40)));

  test('renderiza a página na largura da bobina, com a altura esticada como nos terminais', () async {
    final document = _FakeDocument(image: png);
    final opened = <Uint8List>[];
    final converter = PdfImageConverter(
      open: (data) async {
        opened.add(data);
        return document;
      },
    );

    final result = await converter.firstPageToPng(base64Encode(pdf));

    expect(result.getRight().toNullable(), png);
    expect(opened.single, pdf);
    expect(document.pages.single.pageNumber, 1);
    // Página de 200 x 300 pt: 384 / 200 = 1.92 na largura e 1.92 x 2.0 / 1.7 na altura.
    final render = document.pages.single.renders.single;
    expect(render['width'], 384.0);
    expect(render['height'], closeTo(677.65, 0.01));
    expect(render['format'], PdfPageImageFormat.png);
    expect(render['backgroundColor'], '#FFFFFF');
    expect(render['forPrint'], isTrue);
  });

  test('corta as sobras em branco e centraliza o conteúdo na largura da bobina', () async {
    // Conteúdo de 30 x 10 pontos no alto, à esquerda, como o DANFE numa página A4 maior que ele.
    final rendered = await _png(384, 100, ink: const ui.Rect.fromLTWH(10, 20, 30, 10));

    final result = await PdfImageConverter(
      open: (_) async => _FakeDocument(image: rendered),
    ).firstPageToPng(base64Encode(pdf));

    final image = await _decode(result.getRight().toNullable()!);
    expect([image.width, image.height], [384, 10]);
    // (384 - 30) / 2 = 177 pontos de cada lado.
    expect(await _inkColumns(image), [177, 206]);
  });

  test('página toda em branco sai como o renderizador a devolveu', () async {
    final blank = await _png(384, 50);

    final result = await PdfImageConverter(
      open: (_) async => _FakeDocument(image: blank),
    ).firstPageToPng(base64Encode(pdf));

    expect(result.getRight().toNullable(), blank);
  });

  test('fecha a página e o documento depois de converter', () async {
    final document = _FakeDocument(image: png);

    await PdfImageConverter(open: (_) async => document).firstPageToPng(base64Encode(pdf));

    expect(document.pages.single.isClosed, isTrue);
    expect(document.isClosed, isTrue);
  });

  test('aceita o base64 quebrado em linhas', () async {
    final opened = <Uint8List>[];
    final converter = PdfImageConverter(
      open: (data) async {
        opened.add(data);
        return _FakeDocument(image: png);
      },
    );
    final encoded = base64Encode(pdf);

    await converter.firstPageToPng('${encoded.substring(0, 8)}\r\n${encoded.substring(8)}\n');

    expect(opened.single, pdf);
  });

  test('base64 inválido ou vazio vira INVALID_BASE64 sem abrir o PDF', () async {
    var opens = 0;
    final converter = PdfImageConverter(
      open: (_) async {
        opens++;
        return _FakeDocument(image: png);
      },
    );

    final codes = [
      for (final value in ['não é base64', '', '  \n'])
        (await converter.firstPageToPng(value)).getLeft().toNullable()?.code,
    ];

    expect(codes, ['INVALID_BASE64', 'INVALID_BASE64', 'INVALID_BASE64']);
    expect(opens, 0);
  });

  test('PDF que o renderizador não abre vira INVALID_PDF com a mensagem dele', () async {
    final converter = PdfImageConverter(
      open: (_) async => throw PlatformException(code: 'PDF_RENDERER', message: 'Unable to open document'),
    );

    final failure = (await converter.firstPageToPng(base64Encode(pdf))).getLeft().toNullable();

    expect(failure?.code, 'INVALID_PDF');
    expect(failure?.message, 'Unable to open document');
  });

  test('página que não renderiza vira RENDER_FAILED e também fecha página e documento', () async {
    final document = _FakeDocument(image: null);

    final result = await PdfImageConverter(open: (_) async => document).firstPageToPng(base64Encode(pdf));

    expect(result.getLeft().toNullable()?.code, 'RENDER_FAILED');
    expect(document.pages.single.isClosed, isTrue);
    expect(document.isClosed, isTrue);
  });

  test('imagem renderizada que não decodifica vira RENDER_FAILED', () async {
    final document = _FakeDocument(image: Uint8List.fromList([137, 80, 78, 71]));

    final result = await PdfImageConverter(open: (_) async => document).firstPageToPng(base64Encode(pdf));

    expect(result.getLeft().toNullable()?.code, 'RENDER_FAILED');
    expect(document.pages.single.isClosed, isTrue);
    expect(document.isClosed, isTrue);
  });
}

/// PNG branco de [width] x [height] pontos, com um retângulo preto em [ink].
Future<Uint8List> _png(int width, int height, {ui.Rect? ink}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
  if (ink != null) canvas.drawRect(ink, ui.Paint()..color = const ui.Color(0xFF000000));
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

Future<ui.Image> _decode(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  return (await codec.getNextFrame()).image;
}

/// Primeira e última coluna com algum pixel escuro.
Future<List<int>> _inkColumns(ui.Image image) async {
  final pixels = (await image.toByteData())!.buffer.asUint8List();
  bool dark(int x, int y) => pixels[(y * image.width + x) * 4] < 128;
  final columns = [
    for (var x = 0; x < image.width; x++)
      if (Iterable.generate(image.height).any((y) => dark(x, y))) x,
  ];
  return [columns.first, columns.last];
}

/// Documento de uma página de 200 x 300, que renderiza [image] ou nada, como o pdfx quando falha.
class _FakeDocument extends PdfDocument {
  _FakeDocument({required this.image}) : super(sourceName: 'memory', id: 'document', pagesCount: 1);

  final Uint8List? image;
  final pages = <_FakePage>[];

  @override
  Future<PdfPage> getPage(int pageNumber, {bool autoCloseAndroid = false}) async {
    final page = _FakePage(this, pageNumber);
    pages.add(page);
    return page;
  }

  @override
  Future<void> close() async => isClosed = true;

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => id.hashCode;
}

class _FakePage extends PdfPage {
  _FakePage(_FakeDocument document, int pageNumber)
    : super(
        document: document,
        id: 'page',
        pageNumber: pageNumber,
        width: 200,
        height: 300,
        autoCloseAndroid: false,
      );

  final renders = <Map<String, Object?>>[];

  @override
  Future<PdfPageImage?> render({
    required double width,
    required double height,
    PdfPageImageFormat format = PdfPageImageFormat.jpeg,
    String? backgroundColor,
    Rect? cropRect,
    int quality = 100,
    bool forPrint = false,
    bool removeTempFile = true,
  }) async {
    renders.add({
      'width': width,
      'height': height,
      'format': format,
      'backgroundColor': backgroundColor,
      'forPrint': forPrint,
    });

    final image = (document as _FakeDocument).image;
    return image == null ? null : _FakeImage(image, format);
  }

  @override
  Future<PdfPageTexture> createTexture() => throw UnimplementedError();

  @override
  Future<void> close() async => isClosed = true;

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => pageNumber.hashCode;
}

class _FakeImage extends PdfPageImage {
  const _FakeImage(Uint8List bytes, PdfPageImageFormat format)
    : super(id: 'image', pageNumber: 1, width: 340, height: 600, bytes: bytes, format: format, quality: 100);

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => bytes.hashCode;
}
