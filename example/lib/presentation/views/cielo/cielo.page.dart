import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart' hide State;
import 'package:flutter/material.dart';

import '../../mocks/mocks.dart';
import '../../widgets/widgets.dart';

import 'cielo.state.dart';
import 'cielo.viewmodel.dart';

class CieloPage extends StatefulWidget {
  const CieloPage({super.key});

  @override
  State<CieloPage> createState() => _CieloPageState();
}

class _CieloPageState extends ViewState<CieloPage, CieloViewModel> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CustomText.medium('Cielo Smart Integration'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade500,
      ),
      body: BlocBuilder<CieloViewModel, CieloState>(
        bloc: viewModel,
        builder: (context, state) {
          final isLoading = state.status.isLoading;

          Widget action(String label, VoidCallback? onPressed) {
            return AbsorbPointer(
              absorbing: isLoading,
              child: FilledButton(
                onPressed: onPressed,
                child: CustomText.small(label),
              ),
            );
          }

          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            physics: BouncingScrollPhysics(),
            children: [
              CieloStatusCard(
                status: state.status,
                message: state.message,
                response: state.response,
              ),
              _Section('Pagamentos de teste (dados fake)'),
              for (final payment in CieloPaymentsMock.all)
                action(payment.label, () => viewModel.sendPayment(payment.request)),
              _Section('Último pedido'),
              action(
                'Cancelar o último pagamento',
                state.cancelRequest == null ? null : viewModel.cancelLastPayment,
              ),
              action(
                'Consultar o último pedido',
                state.lastOrder == null ? null : viewModel.findLastOrder,
              ),
              action('Listar pedidos', viewModel.listOrders),
              _Section('Impressão'),
              for (final document in CieloPrintsMock.all)
                action(document.label, () => viewModel.printText(document.request)),
              _Section('Consultas'),
              action('Produtos habilitados (paymentCode)', viewModel.listEnabledProducts),
              action('Estabelecimentos (ECs)', viewModel.listEstablishments),
              action('Informações do terminal', viewModel.getTerminalInfo),
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
