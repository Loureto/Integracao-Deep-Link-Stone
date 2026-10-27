/// Item do pedido enviado no pagamento Cielo. A Cielo trabalha com pedidos (orders), então todo
/// pagamento leva ao menos um item.
class CieloItemModel {
  final String sku;
  final String name;

  /// Preço unitário, em centavos.
  final int unitPrice;

  final int quantity;
  final String unitOfMeasure;

  const CieloItemModel({
    required this.sku,
    required this.name,
    required this.unitPrice,
    this.quantity = 1,
    this.unitOfMeasure = 'unidade',
  });

  /// Total do item, em centavos.
  int get total => unitPrice * quantity;

  bool get isValid => sku.isNotEmpty && name.isNotEmpty && unitPrice >= 0 && quantity > 0;

  static Map<String, dynamic> toMap(CieloItemModel data) {
    return {
      'sku': data.sku,
      'name': data.name,
      'unitPrice': data.unitPrice,
      'quantity': data.quantity,
      'unitOfMeasure': data.unitOfMeasure,
    };
  }
}
