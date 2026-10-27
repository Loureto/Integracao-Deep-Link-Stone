import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const coca = CieloItemModel(sku: '1234', name: 'cocacola', unitPrice: 250, quantity: 2);
  const pepsi = CieloItemModel(sku: '4321', name: 'pepsi', unitPrice: 280, quantity: 2);

  test('o valor do pagamento é a soma dos itens, em centavos', () {
    // Itens do exemplo de retorno de pagamento da documentação Cielo.
    expect(const CieloPaymentModel(items: [coca, pepsi]).value, 1060);
  });

  test('pagamento precisa de itens válidos e valor maior que zero', () {
    expect(const CieloPaymentModel(items: [coca]).isValueValid, isTrue);

    for (final items in [
      <CieloItemModel>[],
      [const CieloItemModel(sku: '1', name: 'Brinde', unitPrice: 0)],
      [const CieloItemModel(sku: '', name: 'Sem SKU', unitPrice: 100)],
      [const CieloItemModel(sku: '1', name: 'Sem quantidade', unitPrice: 100, quantity: 0)],
      [const CieloItemModel(sku: '1', name: 'Preço negativo', unitPrice: -100)],
    ]) {
      expect(CieloPaymentModel(items: items).isValueValid, isFalse, reason: '$items');
    }
  });

  test('installments aceita 0 (à vista) ou mais parcelas', () {
    expect(const CieloPaymentModel(items: [coca]).isInstallmentsValid, isTrue);
    expect(const CieloPaymentModel(items: [coca], installments: 12).isInstallmentsValid, isTrue);
    expect(const CieloPaymentModel(items: [coca], installments: -1).isInstallmentsValid, isFalse);
  });

  test('campos opcionais nulos ficam fora do JSON', () {
    expect(CieloPaymentModel.toMap(const CieloPaymentModel(items: [coca])), {
      'value': '500',
      'installments': 0,
      'items': [CieloItemModel.toMap(coca)],
    });
  });

  test('envia o subadquirente com todos os campos documentados', () {
    const subAcquirer = CieloSubAcquirerModel(
      softDescriptor: 'TESTE123',
      terminalId: '4AC12345',
      merchantCode: '0012397373089400',
      city: 'Sao Paulo',
      telephone: '011999999999',
      state: 'SP',
      postalCode: '08022300',
      address: 'Rua Joao Bello 29',
      identifier: '1234567898',
      merchantCategoryCode: '5441',
      countryCode: '0076',
      informationType: 'J',
      document: '01027058000191',
      businessName: 'Cielo',
      ibgeCode: '0000000',
    );

    final map = CieloPaymentModel.toMap(
      const CieloPaymentModel(
        items: [coca],
        paymentCode: CieloPaymentCode.debitoAvista,
        subAcquirer: subAcquirer,
      ),
    );

    expect(map['paymentCode'], 'DEBITO_AVISTA');
    expect(map['subAcquirer'], hasLength(15));
    expect(map['subAcquirer'], containsPair('countryCode', '0076'));
  });
}
