class StonePaymentResponse {
  final Map<String, String?> data;

  const StonePaymentResponse(this.data);

  String? get code => data['code'];

  /// A tabela de erros da documentação Stone chama a chave de `mensagem`, mas
  /// os exemplos de retorno usam `message`.
  String? get message => data['message'] ?? data['mensagem'];

  /// Action code do autorizador, enviado quando a transação é negada.
  String? get reason => data['reason'];

  /// Pela documentação Stone, somente `code == "0"` indica sucesso.
  bool get isApproved => code == '0';
}
