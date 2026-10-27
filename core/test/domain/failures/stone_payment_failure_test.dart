import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mantém code, message e reason do retorno de transação negada', () {
    // Exemplo "1016 - Não Autorizado" da documentação de pagamento Stone.
    final failure = StonePaymentFailure.fromResponse(
      const StonePaymentResponse({
        'success': 'false',
        'reason': '1016',
        'response_code': '-6',
        'code': '-6',
        'message': 'Não autorizada',
      }),
    );

    expect(failure.code, '-6');
    expect(failure.message, 'Não autorizada');
    expect(failure.reason, '1016');
  });

  test('aceita a chave mensagem, usada na tabela de erros da documentação', () {
    final failure = StonePaymentFailure.fromResponse(
      const StonePaymentResponse({'code': '2', 'mensagem': 'Usuário encerrou o aplicativo'}),
    );

    expect(failure.code, '2');
    expect(failure.message, 'Usuário encerrou o aplicativo');
    expect(failure.reason, isNull);
  });

  test('usa mensagem padrão quando o retorno não traz mensagem', () {
    final failure = StonePaymentFailure.fromResponse(const StonePaymentResponse({'code': '2'}));

    expect(failure.message, 'Pagamento não aprovado.');
  });
}
