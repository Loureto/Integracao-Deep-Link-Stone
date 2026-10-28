import '../enums/enums.dart';
import 'pagbank_transaction_entity.dart';

class PagBankVoidModel {
  final String transactionCode;
  final String transactionId;
  final PagBankVoidType voidType;

  /// Imprime a via do cliente do estorno.
  final bool printReceipt;

  const PagBankVoidModel({
    required this.transactionCode,
    required this.transactionId,
    this.voidType = PagBankVoidType.payment,
    this.printReceipt = false,
  });

  /// Estorno de uma transação aprovada, com o tipo calculado para ela.
  static PagBankVoidModel fromTransaction(PagBankTransaction transaction, {bool printReceipt = false}) {
    return PagBankVoidModel(
      transactionCode: transaction.transactionCode ?? '',
      transactionId: transaction.transactionId ?? '',
      voidType: transaction.voidType,
      printReceipt: printReceipt,
    );
  }

  bool get isValid => transactionCode.isNotEmpty && transactionId.isNotEmpty;

  static Map<String, dynamic> toMap(PagBankVoidModel data) {
    return {
      'transactionCode': data.transactionCode,
      'transactionId': data.transactionId,
      'voidType': data.voidType.value,
      'printReceipt': data.printReceipt,
    };
  }
}
