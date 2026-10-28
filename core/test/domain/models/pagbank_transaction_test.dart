import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lê a transação enviada pelo Android', () {
    final transaction = PagBankTransaction.fromMap({
      'result': 0,
      'errorCode': '0000',
      'transactionCode': 'TC1',
      'transactionId': 'TID1',
      'amount': '3000',
      'installments': 3,
      'paymentType': 'CREDIT',
      'voidType': 'PAYMENT',
      'cardBrand': 'VISA',
    })!;

    expect(transaction.isApproved, isTrue);
    expect(transaction.hasTransaction, isTrue);
    expect(transaction.amount, 3000);
    expect(transaction.installments, 3);
    expect(transaction.paymentType, PagBankPaymentType.credit);
    expect(transaction.voidType, PagBankVoidType.payment);
    expect(transaction.cardBrand, 'VISA');
  });

  test('só result 0 é aprovada', () {
    expect(PagBankTransaction.fromMap({'result': -1, 'errorCode': 'C13'})!.isApproved, isFalse);
    expect(PagBankTransaction.fromMap({'errorCode': '0000'})!.isApproved, isFalse);
  });

  test('sem código ou id, a consulta não trouxe transação', () {
    expect(
      PagBankTransaction.fromMap({'result': 0, 'transactionCode': '', 'transactionId': ''})!.hasTransaction,
      isFalse,
    );
    expect(PagBankTransaction.fromMap({'result': 0, 'transactionCode': 'TC1'})!.hasTransaction, isFalse);
  });

  test('aceita campos ausentes ou de outro tipo, e estorna como pagamento quando não sabe o tipo', () {
    final transaction = PagBankTransaction.fromMap({
      'result': '0',
      'amount': 3000,
      'paymentType': 'PREAUTO',
    })!;

    expect(transaction.result, isNull);
    expect(transaction.amount, isNull);
    expect(transaction.paymentType, isNull);
    expect(transaction.voidType, PagBankVoidType.payment);
  });

  test('retorno que não é um mapa não vira transação', () {
    expect(PagBankTransaction.fromMap(null), isNull);
    expect(PagBankTransaction.fromMap('0000'), isNull);
  });

  test('o estorno usa o código, o id e o tipo de estorno da transação', () {
    final transaction = PagBankTransaction.fromMap({
      'transactionCode': 'TC1',
      'transactionId': 'TID1',
      'voidType': 'QRCODE',
    })!;

    expect(PagBankVoidModel.toMap(PagBankVoidModel.fromTransaction(transaction, printReceipt: true)), {
      'transactionCode': 'TC1',
      'transactionId': 'TID1',
      'voidType': 'QRCODE',
      'printReceipt': true,
    });
  });
}
