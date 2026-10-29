import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart' hide State;
import 'package:flutter/material.dart';

import '../../mocks/mocks.dart';
import '../../widgets/widgets.dart';

import 'stone.state.dart';
import 'stone.viewmodel.dart';

class StonePage extends StatefulWidget {
  const StonePage({super.key});

  @override
  State<StonePage> createState() => _StonePageState();
}

class _StonePageState extends ViewState<StonePage, StoneViewModel> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CustomText.medium('Stone Payment Integration'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade500,
      ),
      body: BlocBuilder<StoneViewModel, StoneState>(
        bloc: viewModel,
        builder: (context, state) {
          final isLoading = state.status.isLoading;

          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            physics: BouncingScrollPhysics(),
            children: [
              PaymentStatus(
                status: state.status,
                message: state.message,
                response: state.response,
              ),
              const SizedBox(height: 16),
              CustomText.medium(
                'Pagamentos de teste (dados fake)',
                color: Colors.black,
              ),
              const SizedBox(height: 8),
              for (final payment in StonePaymentsMock.all)
                AbsorbPointer(
                  absorbing: isLoading,
                  child: FilledButton(
                    onPressed: () => viewModel.sendPayment(payment.request),
                    child: CustomText.small(payment.label),
                  ),
                ),
              const SizedBox(height: 16),
              CustomText.medium('Impressão de NFC-e', color: Colors.black),
              const SizedBox(height: 8),
              for (final nfce in const [
                (label: 'Imprimir a NFC-e de teste', pdf: NfceMock.pdf),
                (label: 'Imprimir a NFC-e de homologação', pdf: NfceHomologacaoMock.pdf),
              ])
                AbsorbPointer(
                  absorbing: isLoading,
                  child: FilledButton(
                    onPressed: () => viewModel.printNfc(nfce.pdf),
                    child: CustomText.small(nfce.label),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
