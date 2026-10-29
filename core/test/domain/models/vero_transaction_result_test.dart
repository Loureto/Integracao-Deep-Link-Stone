import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromMap lê as 16 chaves do retorno da Vero', () {
    final result = VeroTransactionResult.fromMap({
      'SERIAL': 'S1',
      'CNPJ_ADQUIRENTE': '92702067000196',
      'BANDEIRA': 'VISA',
      'NOME_ESTABELECIMENTO': 'LOJA',
      'TRANSACAO': 'CREDITO',
      'COMPROVANTE': 'C',
      'CNPJ_ESTABELECIMENTO': '07056528000121',
      'NSU': '123',
      'VALOR': '1000',
      'NUMCARTAO': '************1234',
      'AUTORIZACAO': 'A1',
      'COMPROVANTE_LOJISTA': '/cache/l.png',
      'COMPROVANTE_CLIENTE_TXT': 'TXT',
      'COMPROVANTE_CLIENTE': '/cache/c.png',
      'PARCELAS': '1',
      'NOME_ADQUIRENTE': 'VERO',
    });

    expect(
      result,
      const VeroTransactionResult(
        serial: 'S1',
        acquiringCnpj: '92702067000196',
        flag: 'VISA',
        establishmentName: 'LOJA',
        transaction: 'CREDITO',
        receipt: 'C',
        establishmentCnpj: '07056528000121',
        nsu: '123',
        value: '1000',
        cardNumber: '************1234',
        authorization: 'A1',
        merchantReceipt: '/cache/l.png',
        customerReceiptTxt: 'TXT',
        customerReceipt: '/cache/c.png',
        installments: '1',
        acquirerName: 'VERO',
      ),
    );
  });

  test('campo ausente ou nulo vira texto vazio', () {
    // O nativo manda nulo quando não consegue copiar o comprovante para o cache.
    final result = VeroTransactionResult.fromMap({'NSU': '123', 'COMPROVANTE_CLIENTE': null});

    expect(result.nsu, '123');
    expect([result.serial, result.customerReceipt, result.customerReceiptTxt], ['', '', '']);
  });

  test('valor que não é texto vira texto', () {
    final result = VeroTransactionResult.fromMap({'PARCELAS': 3, 'VALOR': 1000});

    expect([result.installments, result.value], ['3', '1000']);
  });
}
