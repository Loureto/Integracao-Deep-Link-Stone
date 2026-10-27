import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mantém o code e o reason do erro da Cielo', () {
    final failure = CieloFailure.fromResponse(
      const CieloResponse(action: CieloAction.payment, data: {'code': 4, 'reason': 'Erro de autenticação'}),
    );

    expect(failure.code, '4');
    expect(failure.message, 'Erro de autenticação');
  });

  test('usa a mensagem padrão quando o erro não traz motivo', () {
    final failure = CieloFailure.fromResponse(
      const CieloResponse(action: CieloAction.orders, data: {'code': 2}),
    );

    expect(failure.message, 'A Cielo não concluiu a operação.');
  });

  test('retorno sem dados vira INVALID_RESPONSE', () {
    final failure = CieloFailure.fromResponse(const CieloResponse(action: CieloAction.payment));

    expect(failure.code, 'INVALID_RESPONSE');
    expect(failure.message, 'O app da Cielo respondeu sem dados válidos.');
  });
}
