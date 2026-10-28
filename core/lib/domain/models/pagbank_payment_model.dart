import '../enums/enums.dart';

class PagBankPaymentModel {
  final PagBankPaymentType type;

  /// Valor em centavos: R$ 10,00 é 1000.
  final int amount;

  final PagBankInstallmentType installmentType;

  /// Quantidade de parcelas: 1 à vista e 2 ou mais no parcelado.
  final int installments;

  /// Código da venda, de referência para o lojista: até 10 letras sem acento e números.
  final String? userReference;

  /// Imprime a via do estabelecimento ao fim do pagamento.
  final bool printReceipt;

  const PagBankPaymentModel({
    required this.type,
    required this.amount,
    this.installmentType = PagBankInstallmentType.aVista,
    this.installments = 1,
    this.userReference,
    this.printReceipt = false,
  });

  /// O SDK recebe o valor como inteiro de 32 bits.
  static const maxAmount = 2147483647;

  static final _userReference = RegExp(r'^[A-Za-z0-9]{1,10}$');

  bool get isAmountValid => amount > 0 && amount <= maxAmount;

  bool get isInstallmentsValid =>
      installmentType == PagBankInstallmentType.aVista ? installments == 1 : installments >= 2;

  /// Nulo ou vazio é válido: a venda vai sem código.
  bool get isUserReferenceValid {
    final reference = userReference;
    return reference == null || reference.isEmpty || _userReference.hasMatch(reference);
  }

  static Map<String, dynamic> toMap(PagBankPaymentModel data) {
    return {
      'type': data.type.value,
      'amount': data.amount,
      'installmentType': data.installmentType.value,
      'installments': data.installments,
      'userReference': data.userReference,
      'printReceipt': data.printReceipt,
    };
  }
}
