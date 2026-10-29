import 'package:dependencies/dependencies.dart';
import 'package:flutter/services.dart';

import '../../data/data.dart';
import '../../domain/domain.dart';
import '../receipt_image/bottom_margin.dart';

/// [IRedePaymentService] pelo canal `rede_sdk`, com os métodos e códigos do plugin `flutter_rede_sdk` do
/// flutter_acquirers_sdk. O Android abre o app da Rede para pagar e imprime pela impressora do SDK dela.
class RedePaymentService implements IRedePaymentService {
  static const _creditPayment = 'credit_payment';
  static const _debitPayment = 'debit_payment';
  static const _pixPayment = 'pix_payment';
  static const _refund = 'refund';
  static const _printReceipt = 'print_receipt';
  static const _printTxt = 'print_txt';
  static const _testPrint = 'test_print';

  /// Erro depois do qual a impressão é repetida uma vez. No plugin, a flag estática `_attempts` só voltava a
  /// `false` com sucesso, e depois de uma falha as impressões seguintes ficavam sem nova tentativa.
  static const _printerUnavailable = 'IMPRESSORA_INDISPONIVEL';

  final MethodChannel _channel;
  final IPdfImageConverter _pdfImage;

  const RedePaymentService(this._channel, this._pdfImage);

  @override
  Future<Either<RedeFailure, RedeTransactionResult>> creditCardPayment(double amount) =>
      _pay(_creditPayment, amount);

  @override
  Future<Either<RedeFailure, RedeTransactionResult>> debitCardPayment(double amount) =>
      _pay(_debitPayment, amount);

  @override
  Future<Either<RedeFailure, RedeTransactionResult>> pixPayment(double amount) => _pay(_pixPayment, amount);

  @override
  Future<Either<RedeFailure, RedeTransactionResult>> refundPayment(String nsu) async {
    if (nsu.trim().isEmpty) return left(RedeFailure.nsuNotInformed());

    return _call(_refund, {'nsu': nsu});
  }

  @override
  Future<Either<RedeFailure, Unit>> printTxt(String text) => _print(_printTxt, {'text': text});

  @override
  Future<Either<RedeFailure, Unit>> testPrint() => _print(_testPrint, {});

  @override
  Future<Either<RedeFailure, Unit>> printNfc(String nfcBase64) async {
    final image = await _pdfImage.firstPageToPng(nfcBase64);

    return image.match<Future<Either<RedeFailure, Unit>>>(
      (failure) async => left(RedeFailure(code: failure.code, message: failure.message)),
      (png) => printReceipt(bitmap: png),
    );
  }

  @override
  Future<Either<RedeFailure, Unit>> printReceipt({required Uint8List bitmap}) async {
    final Uint8List image;
    try {
      image = await withBottomMargin(bitmap);
    } on Exception {
      return left(RedeFailure.invalidImage());
    }

    return _print(_printReceipt, {'bitmap': image});
  }

  /// O app da Rede recebe o valor em centavos. O plugin truncava (`toInt`) e cobrava R$ 0,29 como 28 centavos;
  /// aqui o valor é arredondado.
  Future<Either<RedeFailure, RedeTransactionResult>> _pay(String method, double amount) {
    return _call(method, {'amount': (amount * 100).round()});
  }

  /// Chama o app da Rede. Diferente da Vero, o centralizer não imprime comprovante depois do pagamento.
  Future<Either<RedeFailure, RedeTransactionResult>> _call(
    String method,
    Map<String, Object> arguments,
  ) async {
    final Map<dynamic, dynamic>? response;
    try {
      response = await _channel.invokeMethod<Map<dynamic, dynamic>>(method, arguments);
    } on PlatformException catch (e) {
      return left(_failure(e));
    } on MissingPluginException {
      return left(RedeFailure.notImplemented(method));
    }
    if (response == null) return left(RedeFailure.unknown());

    return right(RedeTransactionResult.fromMap(response));
  }

  Future<Either<RedeFailure, Unit>> _print(
    String method,
    Map<String, Object> arguments, {
    bool isRetry = false,
  }) async {
    try {
      await _channel.invokeMethod<String>(method, arguments);
      return right(unit);
    } on PlatformException catch (e) {
      if (e.code == _printerUnavailable && !isRetry) return _print(method, arguments, isRetry: true);

      return left(_failure(e));
    } on MissingPluginException {
      return left(RedeFailure.notImplemented(method));
    }
  }

  static RedeFailure _failure(PlatformException e) {
    return RedeFailure(code: e.code, message: e.message ?? e.stacktrace ?? e.toString());
  }
}
