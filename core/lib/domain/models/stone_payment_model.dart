import '../enums/enums.dart';

class StonePaymentModel {
  /// Valor do pagamento, em centavos. Aceita valores entre 0 e 999999999.
  final int? amount;

  /// Permite que o valor do pagamento seja editado diretamente no aplicativo de Pagamento.
  /// Valor 1 para true e 0 para false.
  final bool? editableAmount;

  /// Modalidade do pagamento: DEBIT, CREDIT, VOUCHER, INSTANT_PAYMENT e PIX.
  /// Esse campo aceita valor nulo.
  final StoneTransactionType? transactionType;

  /// Tipo de parcelamento: MERCHANT (parcelado sem juros)
  /// ISSUER (parcelado com juros) e NONE (à vista). Esse campo aceita valor nulo.
  final StoneInstallmentType? installmentType;

  /// Quantidade de parcelas. Aceita valores entre 2 e 99.
  final int? installmentCount;

  /// Identificador do pedido. Caso queira utilizá-lo
  /// habilitar a funcionalidade no aplicativo de Ajustes do POS.
  final int? orderId;

  const StonePaymentModel({
    this.amount,
    this.editableAmount,
    this.transactionType,
    this.installmentType,
    this.installmentCount,
    this.orderId,
  });

  static const minAmount = 0;
  static const maxAmount = 999999999;
  static const minInstallmentCount = 2;
  static const maxInstallmentCount = 99;

  static Map<String, dynamic> toMap(StonePaymentModel data) {
    return {
      'amount': data.amount,
      'editableAmount': data.editableAmount,
      'transactionType': data.transactionType?.value,
      'installmentType': data.installmentType?.value,
      'installmentCount': data.installmentCount,
      'orderId': data.orderId,
    };
  }

  /// Campos ausentes ficam nulos para serem pedidos no app de Pagamento.
  static StonePaymentModel fromMap(Map<String, dynamic> map) {
    return StonePaymentModel(
      amount: map['amount'],
      editableAmount: map['editableAmount'],
      transactionType: StoneTransactionType.fromValue(map['transactionType']),
      installmentType: StoneInstallmentType.fromValue(map['installmentType']),
      installmentCount: map['installmentCount'],
      orderId: map['orderId'],
    );
  }

  static bool _isInRange(int? value, int min, int max) => value == null || (value >= min && value <= max);

  /// Nulo é válido: o valor passa a ser pedido no app de Pagamento.
  bool get isAmountValid => _isInRange(amount, minAmount, maxAmount);

  /// Nulo é válido: a quantidade passa a ser pedida no app de Pagamento.
  bool get isInstallmentCountValid => _isInRange(installmentCount, minInstallmentCount, maxInstallmentCount);
}
