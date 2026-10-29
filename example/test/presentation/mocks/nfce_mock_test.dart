import 'dart:convert';

import 'package:example/presentation/mocks/mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('o PDF da NFC-e de teste mostra o cupom padrão, linha a linha e na ordem', () {
    final pdf = latin1.decode(base64Decode(NfceMock.pdf));

    var from = 0;
    for (final line in NfceMock.text.split('\n').where((line) => line.isNotEmpty)) {
      // Nas strings do PDF, `\`, `(` e `)` vêm escapados.
      final shown = '(${line.replaceAllMapped(RegExp(r'[\\()]'), (m) => '\\${m[0]}')})';
      from = pdf.indexOf(shown, from);
      expect(from, isNonNegative, reason: 'linha ausente ou fora de ordem: "$line"');
      from += shown.length;
    }
  });
}
