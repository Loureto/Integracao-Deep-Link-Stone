import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart' hide State;
import 'package:flutter/material.dart';

import '../../mocks/mocks.dart';
import '../../widgets/widgets.dart';

import 'pagbank.state.dart';
import 'pagbank.viewmodel.dart';

class PagBankPage extends StatefulWidget {
  const PagBankPage({super.key});

  @override
  State<PagBankPage> createState() => _PagBankPageState();
}

class _PagBankPageState extends ViewState<PagBankPage, PagBankViewModel> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CustomText.medium('PagBank Smart Integration'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade500,
      ),
      body: BlocBuilder<PagBankViewModel, PagBankState>(
        bloc: viewModel,
        builder: (context, state) {
          final isLoading = state.status.isLoading;

          // O app continua na tela durante a operação, então as ações ficam desabilitadas até ela terminar.
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
              PagBankStatusCard(
                status: state.status,
                message: state.message,
                transaction: state.transaction,
              ),
              FilledButton(
                onPressed: isLoading ? viewModel.abort : null,
                child: CustomText.small('Cancelar a operação em andamento'),
              ),
              _Section('Pagamentos de teste (dados fake)'),
              for (final payment in PagBankPaymentsMock.all)
                action(payment.label, () => viewModel.sendPayment(payment.request)),
              _Section('Última venda'),
              action(
                'Estornar o último pagamento',
                state.voidRequest == null ? null : viewModel.voidLastPayment,
              ),
              action('Consultar a última transação aprovada', viewModel.loadLastApprovedTransaction),
              _Section('Comprovantes'),
              action('Reimprimir a via do cliente', viewModel.reprintCustomerReceipt),
              action('Reimprimir a via do estabelecimento', viewModel.reprintEstablishmentReceipt),
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
