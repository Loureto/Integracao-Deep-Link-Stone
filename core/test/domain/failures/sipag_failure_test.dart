import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('estorno sem NSU usa o código e a mensagem do FlutterAcquirersSdk.refund', () {
    expect(
      SiPagFailure.nsuNotInformed(),
      const SiPagFailure(
        code: 'nsu.not.informed',
        message: 'O campo: nsu não foi informado! Corrija-o e tente novamente!',
      ),
    );
  });

  test('tipo de estorno inválido usa o código e a mensagem do PaymentService do centralizer', () {
    expect(
      SiPagFailure.invalidRefundType(),
      const SiPagFailure(code: 'type.is.invalid', message: 'Função de estorno não encontrada!'),
    );
  });

  test('canal inexistente cita o método do canal', () {
    expect(
      SiPagFailure.notImplemented('pay_credit'),
      const SiPagFailure(
        code: 'pay_credit.not.implemented',
        message: 'pay_credit() has not been implemented.',
      ),
    );
  });

  test('resposta vazia usa o erro desconhecido da fachada', () {
    expect(
      SiPagFailure.unknown(),
      const SiPagFailure(code: 'unknown.error', message: 'Erro desconhecido, tente novamente'),
    );
  });
}
