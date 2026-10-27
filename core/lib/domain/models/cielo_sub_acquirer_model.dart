/// Dados do subadquirente, enviados em `subAcquirer` quando o pagamento é feito por meio de um. Todos os
/// campos são obrigatórios: com algum ausente, a Cielo responde "Parâmetros inválidos: Json inválido".
class CieloSubAcquirerModel {
  /// Texto exibido na fatura do cliente.
  final String softDescriptor;
  final String terminalId;

  /// 00 + EC (10 dígitos) + loja do EC (4 dígitos).
  final String merchantCode;
  final String city;
  final String telephone;
  final String state;
  final String postalCode;
  final String address;
  final String identifier;
  final String merchantCategoryCode;

  /// Código do país: 0076 para o Brasil.
  final String countryCode;

  /// J para pessoa jurídica e F para pessoa física.
  final String informationType;

  /// CNPJ ou CPF.
  final String document;
  final String businessName;

  /// Código IBGE do município.
  final String ibgeCode;

  const CieloSubAcquirerModel({
    required this.softDescriptor,
    required this.terminalId,
    required this.merchantCode,
    required this.city,
    required this.telephone,
    required this.state,
    required this.postalCode,
    required this.address,
    required this.identifier,
    required this.merchantCategoryCode,
    required this.countryCode,
    required this.informationType,
    required this.document,
    required this.businessName,
    required this.ibgeCode,
  });

  static Map<String, dynamic> toMap(CieloSubAcquirerModel data) {
    return {
      'softDescriptor': data.softDescriptor,
      'terminalId': data.terminalId,
      'merchantCode': data.merchantCode,
      'city': data.city,
      'telephone': data.telephone,
      'state': data.state,
      'postalCode': data.postalCode,
      'address': data.address,
      'identifier': data.identifier,
      'merchantCategoryCode': data.merchantCategoryCode,
      'countryCode': data.countryCode,
      'informationType': data.informationType,
      'document': data.document,
      'businessName': data.businessName,
      'ibgeCode': data.ibgeCode,
    };
  }
}
