import 'package:dependencies/dependencies.dart';

/// Transação aprovada pelo app da Vero. Classe e campos têm os nomes do `VeroTransactionResult` do plugin
/// `vero_flutter`, para o `AcquirerTransactionResult.fromVeroTransaction` do flutter_acquirers_sdk lê-la sem
/// mudança.
class VeroTransactionResult extends Equatable {
  final String serial, acquiringCnpj, flag, establishmentName, transaction, receipt, establishmentCnpj;
  final String nsu, value, cardNumber, authorization, merchantReceipt, customerReceiptTxt, customerReceipt;
  final String installments, acquirerName;

  const VeroTransactionResult({
    required this.serial,
    required this.acquiringCnpj,
    required this.flag,
    required this.establishmentName,
    required this.transaction,
    required this.receipt,
    required this.establishmentCnpj,
    required this.nsu,
    required this.value,
    required this.cardNumber,
    required this.authorization,
    required this.merchantReceipt,
    required this.customerReceiptTxt,
    required this.customerReceipt,
    required this.installments,
    required this.acquirerName,
  });

  /// Lê os extras devolvidos pelo app da Vero. Os comprovantes chegam como caminhos de arquivo no cache.
  ///
  /// No plugin todos os campos eram obrigatórios e um ausente derrubava o app; aqui ele vira texto vazio.
  factory VeroTransactionResult.fromMap(Map<dynamic, dynamic> map) {
    String read(String key) => map[key]?.toString() ?? '';

    return VeroTransactionResult(
      serial: read('SERIAL'),
      acquiringCnpj: read('CNPJ_ADQUIRENTE'),
      flag: read('BANDEIRA'),
      establishmentName: read('NOME_ESTABELECIMENTO'),
      transaction: read('TRANSACAO'),
      receipt: read('COMPROVANTE'),
      establishmentCnpj: read('CNPJ_ESTABELECIMENTO'),
      nsu: read('NSU'),
      value: read('VALOR'),
      cardNumber: read('NUMCARTAO'),
      authorization: read('AUTORIZACAO'),
      merchantReceipt: read('COMPROVANTE_LOJISTA'),
      customerReceiptTxt: read('COMPROVANTE_CLIENTE_TXT'),
      customerReceipt: read('COMPROVANTE_CLIENTE'),
      installments: read('PARCELAS'),
      acquirerName: read('NOME_ADQUIRENTE'),
    );
  }

  @override
  List<Object?> get props => [
    serial,
    acquiringCnpj,
    flag,
    establishmentName,
    transaction,
    receipt,
    establishmentCnpj,
    nsu,
    value,
    cardNumber,
    authorization,
    merchantReceipt,
    customerReceiptTxt,
    customerReceipt,
    installments,
    acquirerName,
  ];
}
