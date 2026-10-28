import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a falha da transação mantém o errorCode, a mensagem e a própria transação', () {
    final transaction = PagBankTransaction.fromMap({
      'result': -1,
      'errorCode': 'C13',
      'message': 'OPERACAO CANCELADA',
    })!;

    final failure = PagBankFailure.fromTransaction(transaction);

    expect(failure.code, 'C13');
    expect(failure.message, 'OPERACAO CANCELADA');
    expect(failure.transaction, same(transaction));
  });

  test('usa mensagens padrão quando o terminal não envia mensagem', () {
    expect(
      PagBankFailure.fromTransaction(const PagBankTransaction({'result': -1})).message,
      'Operação não aprovada no terminal.',
    );
    expect(
      PagBankFailure.fromPlatform(code: 'PAGBANK_ERROR').message,
      'Não foi possível concluir a operação no terminal.',
    );
    expect(PagBankFailure.fromPrint().message, 'Não foi possível reimprimir o comprovante.');
  });
}
