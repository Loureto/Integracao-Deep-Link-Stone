import '../enums/enums.dart';
import 'cielo_item_model.dart';
import 'cielo_sub_acquirer_model.dart';

class CieloPaymentModel {
  /// Itens do pedido. O valor do pagamento é a soma deles.
  final List<CieloItemModel> items;

  /// Forma de pagamento. Nulo para escolher no app da Cielo.
  final CieloPaymentCode? paymentCode;

  /// Número de parcelas: 0 para pagamento à vista.
  final int installments;

  /// Referência do pedido, para controle interno.
  final String? reference;

  /// E-mail do cliente.
  final String? email;

  /// Estabelecimento, em caso de MULTI-EC: 00 + EC (10 dígitos) + loja do EC (4 dígitos).
  final String? merchantCode;

  final CieloSubAcquirerModel? subAcquirer;

  const CieloPaymentModel({
    required this.items,
    this.paymentCode,
    this.installments = 0,
    this.reference,
    this.email,
    this.merchantCode,
    this.subAcquirer,
  });

  /// Valor do pagamento, em centavos.
  int get value => items.fold(0, (total, item) => total + item.total);

  bool get isValueValid => items.isNotEmpty && items.every((item) => item.isValid) && value > 0;

  bool get isInstallmentsValid => installments >= 0;

  /// Campos nulos ficam fora do JSON. O `value` vai como texto, como na documentação.
  static Map<String, dynamic> toMap(CieloPaymentModel data) {
    return {
      'value': data.value.toString(),
      'installments': data.installments,
      'items': data.items.map(CieloItemModel.toMap).toList(),
      if (data.paymentCode != null) 'paymentCode': data.paymentCode!.value,
      if (data.reference != null) 'reference': data.reference,
      if (data.email != null) 'email': data.email,
      if (data.merchantCode != null) 'merchantCode': data.merchantCode,
      if (data.subAcquirer != null) 'subAcquirer': CieloSubAcquirerModel.toMap(data.subAcquirer!),
    };
  }
}
