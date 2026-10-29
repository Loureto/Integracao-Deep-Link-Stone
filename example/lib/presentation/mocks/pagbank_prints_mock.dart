import 'dart:convert';

/// Impressão livre de teste no terminal do PagBank. A imagem foi gerada só para o teste. A NFC-e de teste, a
/// mesma em todas as adquirentes, fica no `NfceMock`.
abstract final class PagBankPrintsMock {
  /// PNG de 384 x 160 pixels com "TESTE PAGBANK" e "IMPRESSAO LIVRE" numa moldura.
  static final image = base64Decode(_image);

  static const _image =
      'iVBORw0KGgoAAAANSUhEUgAAAYAAAACgAQAAAAAtZ4aQAAAA/UlEQVR42u2XTQrEIAyFAx5gLiTk6oIX6gGEjEm0lpFZzC7t'
      'PBEbf76Ffa15Ej2gvOSncgAAAAAAgP8BGlEm4qKtBjqSpGj1oHHL3DgyIE17OtB8WHzFqqm3Ve4JzEALhwdcKQ9MOFUzdx0t'
      '4JKThAd4POamN+32t3Q/YP/4wgH6+7twdggYYMdCOkkODSADAQAAAACADXAfqyZEfUhPIlbNq1hmuSwgDgr0Xip5ucKV1T07'
      'er73WYkLqI19ADCEO+9K9An4bFzAt5unVZTlqBbg/egA12+A1DpmgwLjfm0CEg0F1eX67ckOhKHd9dQIBSADAQAAAACAHXhA'
      'eQN+udpaaEeRiwAAAABJRU5ErkJggg==';
}
