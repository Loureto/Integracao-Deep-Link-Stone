/// Página da listagem de pedidos abertos na Cielo Smart.
class CieloOrderListModel {
  /// Página, a partir de 0.
  final int page;

  /// Pedidos por página. Por causa do tamanho do retorno, a Cielo aceita no máximo [maxPageSize].
  final int pageSize;

  const CieloOrderListModel({this.page = 0, this.pageSize = maxPageSize});

  static const maxPageSize = 5;

  bool get isValid => page >= 0 && pageSize >= 1 && pageSize <= maxPageSize;

  static Map<String, dynamic> toMap(CieloOrderListModel data) {
    return {
      'page': data.page,
      'pageSize': data.pageSize,
    };
  }
}
