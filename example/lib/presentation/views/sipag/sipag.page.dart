import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart' hide State;
import 'package:flutter/material.dart';

import '../../mocks/mocks.dart';
import '../../widgets/widgets.dart';

import 'sipag.state.dart';
import 'sipag.viewmodel.dart';

class SipagPage extends StatefulWidget {
  const SipagPage({super.key});

  @override
  State<SipagPage> createState() => _SipagPageState();
}

class _SipagPageState extends ViewState<SipagPage, SipagViewModel> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CustomText.medium('Sipag Integration'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade500,
      ),
      body: BlocBuilder<SipagViewModel, SipagState>(
        bloc: viewModel,
        builder: (context, state) {
          final isLoading = state.status.isLoading;

          // O app da adquirente fica na frente durante a operação, e as ações só voltam quando ela termina.
          Widget action(String label, VoidCallback? onPressed) {
            return FilledButton(
              onPressed: isLoading ? null : onPressed,
              child: CustomText.small(label),
            );
          }

          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            physics: BouncingScrollPhysics(),
            children: [
              SipagStatusCard(
                status: state.status,
                message: state.message,
                transaction: state.transaction,
              ),
              _Section('Pagamentos de teste (dados fake)'),
              for (final payment in SipagPaymentsMock.all)
                action(payment.label, () => viewModel.pay(payment.type, payment.amount)),
              _Section('Última venda'),
              action(
                'Estornar o último pagamento',
                state.lastPayment == null ? null : viewModel.refundLastPayment,
              ),
              action('Buscar a última operação', viewModel.getLastOperation),
              _Section('Impressão pelo driver genérico'),
              action('Imprimir a NFC-e de teste', () => viewModel.printNfc(NfceMock.pdf)),
              action('Imprimir a NFC-e de homologação', () => viewModel.printNfc(NfceHomologacaoMock.pdf)),
              action('Imprimir o texto de teste', () => viewModel.printTxt(NfceMock.text)),
              action('Impressão de teste', viewModel.testPrint),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;

  const _Section(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: CustomText.medium(title, color: Colors.black),
    );
  }
}
