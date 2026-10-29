# Rede no core: plano de implementação

> **Para quem for executar:** use o `superpowers:subagent-driven-development` (recomendado) ou o `superpowers:executing-plans` para seguir este plano tarefa por tarefa. Os passos usam caixas (`- [ ]`) para acompanhar o andamento.

**Objetivo:** pagamentos (crédito à vista, débito, Pix e estorno) e impressão da Rede neste core, com os nomes do `centralizer` e do plugin `flutter_rede_sdk`, e um flavor `rede` com tela de teste.

**Arquitetura:**
- **`core`:**
  - ganha o `IRedePaymentService`, no canal `rede_sdk`;
  - a margem de 1 cm vira uma função comum ao driver genérico e à Rede.
- **Android:**
  - o flavor `rede` (minSdk 28) leva o AAR do L400 e as bibliotecas que ele usa sem trazer;
  - o handler de pagamento abre o app da Rede por `startActivityForResult`;
  - o handler de impressão usa a impressora do SDK;
  - o SDK fica atrás de interfaces pequenas para os testes;
  - o texto em bitmap passa para `src/main` e vale para a Vero e a Rede.

**Tecnologias:**
- Flutter 3.35.2 (fvm), Dart com `fpdart`/`Either`, `dart:ui`;
- Kotlin, Robolectric 4.16;
- AGP com Kotlin DSL;
- `smartrede-sdk-l400-4.1.1.release.aar`.

**Especificação:** `docs/superpowers/specs/2026-10-29-rede-migracao-design.md`. Quem for executar lê a especificação e este plano.

## Restrições globais

- **Canal e métodos do plugin:**
  - canal `rede_sdk`;
  - `credit_payment`, `debit_payment` e `pix_payment` com `{amount: int}`, e `refund` com `{nsu}`;
  - `print_receipt` com `{bitmap}`, `print_txt` com `{text}`, e `test_print`.
- **SDK:**
  - `FlexTipoPagamento.CREDITO_A_VISTA`, `DEBITO` e `PIX`;
  - códigos de requisição 4 (pagamento) e 5 (estorno);
  - o resultado vem por `RedePayments.getPaymentFromIntent`, que lê o extra `rede.smartrede.sdk.INTENT_EXTRAS_PAYMENT`.
- **Centavos:** `(amount * 100).round()`.
- **Códigos, mensagens e chaves do resultado:** exatamente como nas tabelas da especificação.
- **Nomes de erro:** sufixo `*Failure` (`RedeFailure`), como o resto do core.
- **Texto em bitmap:** o mesmo da Vero.
  - 576 px de largura, `textSize` 20, `Typeface.MONOSPACE`, antialias e fundo branco;
  - linhas como o `split` do Java;
  - altura `linhas × (descent − ascent) + 20`;
  - o teste de impressão manda "Impressao teste".
- **Margem:** o `printReceipt` acrescenta 80 linhas brancas no fim do PNG.
- **Novas tentativas:** uma por chamada, só em `IMPRESSORA_INDISPONIVEL`.
- **Dependências, só no flavor `rede`:**
  - o AAR;
  - `com.google.code.gson:gson:2.11.0`;
  - `org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1`;
  - `androidx.appcompat:appcompat:1.7.0`.
- **Robolectric:** os testes de `src/testRede/` levam `@Config(sdk = [30])`. O flavor tem minSdk 28, e o `robolectric.properties` pede as APIs 25 e 30.
- **Comandos:**
  - Flutter: `../.fvm/flutter_sdk/bin/flutter`, a partir de `core` ou `example`;
  - Gradle: `JAVA_HOME="C:/Program Files/Eclipse Adoptium/jdk-17.0.20.101-hotspot" ./gradlew`, em `example/android`.
- **Estilo:** comentários e textos em português, com no máximo 110 colunas.
- **Sem commits:** a branch é a `main`, que estava limpa em `8f1b584`. Cada tarefa termina com a suíte verde, não com um commit.

## Pontos de atenção na revisão

1. **Recibo com campos nulos.** Um AUTO nulo num débito, ou o recibo inteiro nulo, vira texto vazio, e a aprovação continua aprovação. Testes nas Tarefas 2 e 5.
2. **`AMOUNT` inteiro ou em texto.** Ele vira double, sem erro de tipo. Teste na Tarefa 2.
3. **Impressão pedida enquanto um pagamento espera o app da Rede.** O retorno do pagamento continua indo para quem pagou. Teste na Tarefa 6.
4. **Aparelho sem o SDK da impressora** (emulador, outro terminal). A impressão responde `IMPRESSORA_INDISPONIVEL`, e o pagamento funciona. Testes na Tarefa 6.
5. **Biblioteca que o AAR usa faltando no APK.** O teste de dependências pega a falta na Tarefa 4, e um `LinkageError` na impressão vira erro de impressão na Tarefa 6.

---

### Tarefa 1: margem de 1 cm comum no `core`

**Arquivos:**
- Criar:
  - `core/lib/infrastructure/receipt_image/bottom_margin.dart`;
  - `core/test/helpers/images.dart`;
  - `core/test/infrastructure/receipt_image/bottom_margin_test.dart`.
- Modificar:
  - `core/lib/infrastructure/native_printer/native_printer_service.dart`;
  - `core/test/infrastructure/native_printer/native_printer_service_test.dart`.

**Interfaces:**
- Produz:
  - `Future<Uint8List> withBottomMargin(Uint8List png)`, que lança `Exception` quando os bytes não formam imagem;
  - os ajudantes de teste `Future<Uint8List> png(List<int> tones, {int? width})` e `Future<({int width, int height, List<int> tones})> decodePng(Uint8List png)`.

- [ ] **Passo 1: ajudantes de teste.** Mover o `_png` e o `_decode` do `native_printer_service_test.dart` para `core/test/helpers/images.dart`, com os nomes `png` e `decodePng`. O teste do driver passa a importá-los.

- [ ] **Passo 2: testes da função.** Em `bottom_margin_test.dart`:

```dart
test('acrescenta 80 linhas brancas abaixo da imagem', () async {
  final result = await decodePng(await withBottomMargin(await png([0, 0, 0])));
  expect([result.width, result.height], [3, 81]);
  expect(result.tones.take(3), [0, 0, 0]);
  expect(result.tones.skip(3), everyElement(255));
});
test('libera o Picture usado para a margem', ...); // movido do teste do driver: created hasLength(1), disposed == created
test('bytes que não formam imagem lançam Exception', () {
  expect(withBottomMargin(Uint8List.fromList([1, 2, 3])), throwsException);
});
```

O teste do `Picture` sai do `native_printer_service_test.dart`. Os de margem e de bytes inválidos do driver ficam lá.

- [ ] **Passo 3: rodar.** `cd core && ../.fvm/flutter_sdk/bin/flutter test test/infrastructure/receipt_image/bottom_margin_test.dart`
Esperado: falha de compilação ("withBottomMargin" não existe).

- [ ] **Passo 4: implementar.** A função é a `_withBottomMargin` do driver, com o 80 e o comentário dele: 1 cm na impressora de 8 pontos por milímetro. O driver passa a chamá-la, sem `_bottomMargin` nem `_withBottomMargin`. A função não sai no barril `infrastructure.dart`.

- [ ] **Passo 5: rodar.** `cd core && ../.fvm/flutter_sdk/bin/flutter test && ../.fvm/flutter_sdk/bin/flutter analyze`
Esperado: todos os testes passam, inclusive os do `NativePrinterService`, e nenhum problema no analyze.

### Tarefa 2: modelos da Rede no `core`

**Arquivos:**
- Criar:
  - `core/lib/domain/models/rede_transaction_result.dart`;
  - `core/lib/domain/failures/rede_failure.dart`;
  - `core/test/domain/models/rede_transaction_result_test.dart`.
- Modificar: `core/lib/domain/models/models.dart` e `core/lib/domain/failures/failures.dart`, para exportar os novos.

**Interfaces:**
- Produz:
  - `class RedeTransactionResult extends Equatable`, com `final String flag, nsu, authorization, installments, cardNumber`, `final double amount` e `factory RedeTransactionResult.fromMap(Map<dynamic, dynamic> map)`;
  - `class RedeFailure extends Equatable`, com `final String code, message` e as fábricas:
    - `nsuNotInformed()`: `nsu.not.informed` / "O campo: nsu não foi informado! Corrija-o e tente novamente!";
    - `notImplemented(String method)`: `$method.not.implemented` / "$method() has not been implemented.";
    - `unknown()`: `unknown.error` / "Erro desconhecido, tente novamente";
    - `invalidImage()`: `ERRO_DESCONHECIDO` / "Erro na impressão".

- [ ] **Passo 1: testes do `fromMap`.**

```dart
test('lê as chaves do plugin flutter_rede_sdk', () {
  final result = RedeTransactionResult.fromMap({
    'FLAG': 'VISA', 'NSU_SITEF': '123', 'AUTHORIZATION': 'A1',
    'INSTALLMENTS': 2, 'AMOUNT': 10.5, 'CARD_NUMBER': 'Crédito',
  });
  expect(result, const RedeTransactionResult(flag: 'VISA', nsu: '123', authorization: 'A1',
      installments: '2', amount: 10.5, cardNumber: 'Crédito'));
});
test('AMOUNT inteiro ou em texto vira double', () {
  expect(RedeTransactionResult.fromMap({'AMOUNT': 1}).amount, 1.0);
  expect(RedeTransactionResult.fromMap({'AMOUNT': '2.5'}).amount, 2.5);
});
test('campo ausente ou nulo vira texto vazio e valor 0', () {
  for (final map in [{}, {'FLAG': null, 'AUTHORIZATION': null, 'AMOUNT': null}]) {
    final result = RedeTransactionResult.fromMap(map);
    expect([result.flag, result.authorization, result.installments, result.amount], ['', '', '', 0]);
  }
});
```

- [ ] **Passo 2: rodar.** `cd core && ../.fvm/flutter_sdk/bin/flutter test test/domain/models/rede_transaction_result_test.dart`
Esperado: falha de compilação ("RedeTransactionResult" não existe).

- [ ] **Passo 3: implementar.**
  - Os textos são lidos com `map[key]?.toString() ?? ''`, como na Vero.
  - O `amount` é `double.tryParse(read('AMOUNT')) ?? 0`.
  - Os comentários de classe dizem que os nomes são os do `RedeTransactionResult` e do `RedeError` do `flutter_rede_sdk`. Assim, o `AcquirerTransactionResult.fromRedeTransaction` lê o resultado sem mudança.

- [ ] **Passo 4: rodar.** `cd core && ../.fvm/flutter_sdk/bin/flutter test && ../.fvm/flutter_sdk/bin/flutter analyze`
Esperado: tudo verde.

### Tarefa 3: serviço da Rede no `core` (`IRedePaymentService`)

**Arquivos:**
- Criar:
  - `core/lib/data/interfaces/rede_payment_interface.dart`;
  - `core/lib/infrastructure/rede_payment/rede_payment_service.dart`;
  - `core/test/infrastructure/rede_payment/rede_payment_service_test.dart`.
- Modificar: `core/lib/data/interfaces/interfaces.dart` e `core/lib/infrastructure/infrastructure.dart`, para exportar os novos.

**Interfaces:**
- Consome: `RedeTransactionResult`, `RedeFailure` (Tarefa 2), `withBottomMargin` (Tarefa 1) e `IPdfImageConverter`.
- Produz: `abstract class IRedePaymentService`, com os métodos abaixo, e `class RedePaymentService implements IRedePaymentService`, com `const RedePaymentService(MethodChannel channel, IPdfImageConverter pdfImage)`.
  - `Future<Either<RedeFailure, RedeTransactionResult>>`: `creditCardPayment(double amount)`, `debitCardPayment(double amount)`, `pixPayment(double amount)` e `refundPayment(String nsu)`.
  - `Future<Either<RedeFailure, Unit>>`: `printTxt(String text)`, `printNfc(String nfcBase64)`, `testPrint()` e `printReceipt({required Uint8List bitmap})`.

- [ ] **Passo 1: testes.** Mock do canal `rede_sdk` como no teste da Vero, um conversor falso e um `_FailingChannel` para o fallback da stack trace. Os testes têm estes nomes e asserções:

```dart
test('cada pagamento chama o método do plugin com o valor em centavos arredondado') // 0.29, 4.35, 33.30 →
  // [['credit_payment', {'amount': 29}], ['debit_payment', {'amount': 435}], ['pix_payment', {'amount': 3330}]]
test('pagamento aprovado devolve a transação, sem comprovante automático')
  // resposta com as 6 chaves → nsu '123', authorization 'A1', amount 1.0; calls.map(method) == ['credit_payment']
test('estorno manda o NSU') // ['refund', {'nsu': '123'}], resposta {'FLAG': 'Estorno'} → flag 'Estorno'
test('estorno com NSU em branco não chama o Android') // nsu.not.informed e a mensagem; calls isEmpty
test('erro do Android volta com o mesmo código e mensagem') // TRANSACTION_DENY / 'Operação negada!'
test('erro sem mensagem usa a stack trace e, sem ela, o texto do erro')
  // 'at RedePaymentHandler.start' e 'PlatformException(error, null, null, null)'
test('canal inexistente vira <método>.not.implemented')
  // credit_payment.not.implemented / 'credit_payment() has not been implemented.' e print_txt.not.implemented
test('resposta vazia vira unknown.error')
test('printTxt e testPrint usam os nomes do plugin') // ['print_txt', 'test_print'], {'text': 'LINHA'}
test('printReceipt manda o bitmap com 1 cm de papel em branco no fim') // decodePng → [3, 81]
test('printReceipt não manda o que não é imagem') // ERRO_DESCONHECIDO / 'Erro na impressão'; calls isEmpty
test('printNfc converte a NFC-e e imprime a imagem') // converter.pdfs.single e calls.single.method 'print_receipt'
test('printNfc devolve a falha do conversor sem chamar o Android') // INVALID_PDF / 'PDF corrompido'
test('tenta mais uma vez em IMPRESSORA_INDISPONIVEL e não nos outros códigos')
  // IMPRESSORA_INDISPONIVEL → 2 chamadas; ERRO_SEM_PAPEL e ERRO_DESCONHECIDO → 1 chamada cada
test('a nova tentativa que dá certo devolve sucesso')
```

- [ ] **Passo 2: rodar.** `cd core && ../.fvm/flutter_sdk/bin/flutter test test/infrastructure/rede_payment/rede_payment_service_test.dart`
Esperado: falha de compilação ("RedePaymentService" não existe).

- [ ] **Passo 3: implementar.** A estrutura é a do `VeroPaymentService` (`_pay`, `_call`) e do `NativePrinterService` (`_print` com `isRetry`).
  - Sem comprovante automático.
  - Nova tentativa só em `IMPRESSORA_INDISPONIVEL`.
  - `MissingPluginException` vira `RedeFailure.notImplemented(<método do canal>)`, tanto nos pagamentos quanto na impressão.
  - O comentário da interface diz que os nomes são os do `RedeIntegration` do flutter_acquirers_sdk.

- [ ] **Passo 4: rodar.** `cd core && ../.fvm/flutter_sdk/bin/flutter test && ../.fvm/flutter_sdk/bin/flutter analyze && ../.fvm/flutter_sdk/bin/dart format --output=none --set-exit-if-changed lib test`
Esperado: tudo verde.

### Tarefa 4: flavor `rede`, dependências do AAR e texto em bitmap comum

**Arquivos:**
- Criar:
  - `example/android/app/libs/smartrede-sdk-l400-4.1.1.release.aar`, copiado de `C:/Users/user/AppData/Local/Pub/Cache/git/flutter-package-rede_192.168.50.59_fontes-93f6ad4c8985106426fd820ade377d5e33c7ef23/android/rede-sdk/`;
  - `example/android/app/src/main/kotlin/com/example/example/printer/TextBitmap.kt`;
  - `example/android/app/src/test/kotlin/com/example/example/printer/TextBitmapTest.kt`;
  - `example/android/app/src/rede/kotlin/com/example/example/RedeIntegration.kt`, por enquanto só com o `createAcquirerIntegration()` e o `configure` vazio;
  - `example/android/app/src/testRede/kotlin/com/example/example/rede/RedeDependenciesTest.kt`.
- Modificar:
  - `example/android/app/build.gradle.kts`;
  - `example/android/app/src/genericPrinter/kotlin/com/example/example/printer/ServicePrinter.kt`;
  - `example/android/app/src/testVero/kotlin/com/example/example/printer/ServicePrinterTest.kt`;
  - `example/android/app/src/main/kotlin/com/example/example/AcquirerIntegration.kt` (o comentário cita "stone, cielo, pagbank, vero ou rede").

**Interfaces:**
- Produz:
  - `internal fun textToBitmap(text: String): Bitmap` e `internal const val TEST_PRINT_TEXT = "Impressao teste"`, no pacote `com.example.example.printer`;
  - o flavor `rede` compilando;
  - `createAcquirerIntegration()` em `src/rede`.

- [ ] **Passo 1: testes do texto em bitmap.** `TextBitmapTest` com `@RunWith(RobolectricTestRunner::class)`, `@GraphicsMode(NATIVE)` e `@Config(sdk = [30])`:

```kotlin
@Test fun `desenha em 576 px com uma linha por quebra`() {
    val one = textToBitmap("A")
    val line = one.height - 20
    assertEquals(576, one.width)
    assertEquals(2 * line + 20, textToBitmap("A\nB").height)
}
@Test fun `separa as linhas como o split do Java`() {
    assertEquals(textToBitmap("A").height, textToBitmap("A\n\n").height) // vazias do fim saem
    assertEquals(20, textToBitmap("\n").height)                            // nenhuma linha
    assertEquals(textToBitmap("A").height, textToBitmap("").height)       // sem quebra, uma linha
}
```

O `ServicePrinterTest` troca `ServicePrinter.textToBitmap(...)` por `textToBitmap(...)`.

- [ ] **Passo 2: rodar.** Em `example/android`, com o `JAVA_HOME` das restrições globais: `./gradlew :app:testVeroDebugUnitTest --console=plain`
Esperado: falha de compilação (`textToBitmap` não resolvido).

- [ ] **Passo 3: mover a função.** O `textToBitmap` e o "Impressao teste" saem do `companion` do `ServicePrinter` para `TextBitmap.kt`, com o comentário da largura de 80 mm. O `ServicePrinter` passa a usá-los.

- [ ] **Passo 4: rodar.** `./gradlew :app:testVeroDebugUnitTest :app:testStoneDebugUnitTest --console=plain`
Esperado: BUILD SUCCESSFUL. A Vero passa com 59 testes mais os do `TextBitmapTest`, e a Stone, com 46 mais os do `TextBitmapTest`.

- [ ] **Passo 5: teste de dependências.** `RedeDependenciesTest`, em JUnit puro, sem Robolectric:

```kotlin
@Test fun `o flavor leva as classes que o SDK da Rede usa sem trazer no AAR`() {
    listOf(
        "com.google.gson.Gson",
        "kotlinx.coroutines.BuildersKt",
        "kotlinx.coroutines.android.AndroidDispatcherFactory",
        "androidx.appcompat.app.AppCompatActivity",
        "androidx.activity.result.ActivityResultLauncher",
        "androidx.fragment.app.Fragment",
    ).forEach { Class.forName(it, false, javaClass.classLoader) }
}
```

- [ ] **Passo 6: flavor sem as dependências extras.** Criar o flavor `create("rede") { dimension = "acquirer"; minSdk = 28 }`, copiar o AAR e declarar só `"redeImplementation"(files("libs/smartrede-sdk-l400-4.1.1.release.aar"))`. Criar o `RedeIntegration.kt` mínimo.
Rodar `./gradlew :app:testRedeDebugUnitTest --console=plain`.
Esperado: o `RedeDependenciesTest` falha com `ClassNotFoundException: com.google.gson.Gson`.

- [ ] **Passo 7: declarar as dependências.** Declarar Gson 2.11.0, coroutines-android 1.8.1 e appcompat 1.7.0 com `"redeImplementation"`. O comentário explica:
  - o SDK da Rede as usa sem trazê-las;
  - no PDV, elas vinham de outros plugins;
  - sem elas, a impressão lança `NoClassDefFoundError`, como aconteceu com a Sunmi.

- [ ] **Passo 8: rodar.** `./gradlew :app:testRedeDebugUnitTest :app:testVeroDebugUnitTest :app:testStoneDebugUnitTest :app:testCieloDebugUnitTest :app:testPagbankDebugUnitTest --console=plain`
Esperado: BUILD SUCCESSFUL, com o `RedeDependenciesTest` e o `TextBitmapTest` verdes na Rede. Se a mesclagem do manifest falhar por causa do AAR, registrar a decisão e ajustar no `src/rede/AndroidManifest.xml`.

### Tarefa 5: pagamento e estorno da Rede no Android

**Arquivos:**
- Criar:
  - `example/android/app/src/rede/kotlin/com/example/example/rede/RedePaymentApp.kt`;
  - `example/android/app/src/rede/kotlin/com/example/example/rede/RedePaymentHandler.kt`;
  - `example/android/app/src/testRede/kotlin/com/example/example/rede/RedePaymentHandlerTest.kt`;
  - `example/android/app/src/testRede/kotlin/com/example/example/rede/SmartRedePaymentAppTest.kt`.

**Interfaces:**
- Consome: o flavor `rede` (Tarefa 4).
- Produz:
  - `internal interface RedePaymentApp`, com `paymentIntent(type: FlexTipoPagamento, amount: Long): Intent` e `reversalIntent(nsu: String): Intent`;
  - `internal class SmartRedePaymentApp(context: Context) : RedePaymentApp`, com `RedePayments.getInstance(context).intentForPaymentBuilder(type, amount).build()` e `.intentForReversal(nsu)`;
  - `internal class RedePaymentHandler(activity: Activity, app: RedePaymentApp)`, com `handle(call, result)` e `onActivityResult(requestCode, resultCode, data): Boolean`;
  - no `companion`: `METHODS = setOf("credit_payment", "debit_payment", "pix_payment", "refund")`, `PAYMENT_REQUEST = 4` e `REFUND_REQUEST = 5`.

- [ ] **Passo 1: testes do handler.** Robolectric com `@Config(sdk = [30])`.
  - Um `FakeRedePaymentApp` registra `(tipo, valor)` e o NSU e devolve um `Intent` qualquer. Ele pode lançar a exceção configurada.
  - Os retornos usam `Payment` e `Receipt` reais do SDK no extra `rede.smartrede.sdk.INTENT_EXTRAS_PAYMENT`.

```kotlin
`credit_payment debit_payment e pix_payment abrem o app da Rede com o tipo e o valor e codigo 4`
    // app.calls == [(CREDITO_A_VISTA, 100L), (DEBITO, 100L), (PIX, 100L)]; requestCode 4; sem resposta
`refund abre o estorno com o NSU e codigo 5`
`pagamento aprovado responde as chaves do plugin`
    // receipt NSU '123', AUTO 'A1', issuerName 'VISA', operationType 'Crédito', value 1.0, installments 1 →
    // mapOf(FLAG to VISA, NSU_SITEF to 123, AUTHORIZATION to A1, INSTALLMENTS to 1, AMOUNT to 1.0, CARD_NUMBER to Crédito)
`no Pix a autorizacao e o NSU e sem emissor a bandeira e Pagamento mais o tipo`
    // operationType 'PIX', issuerName null → AUTHORIZATION '123', FLAG 'Pagamento PIX'
`recibo nulo responde as chaves sem valor` // todas as seis chaves presentes, com null
`estorno aprovado responde os valores fixos do plugin`
    // mapOf(FLAG to Estorno, NSU_SITEF to "", AUTHORIZATION to "", INSTALLMENTS to 1, AMOUNT to 0.0, CARD_NUMBER to refund)
`FAILED responde TRANSACTION_FAILED no pagamento e REFUND_FAILED no estorno`
`outro status responde TRANSACTION_DENY no pagamento e REFUND_DENY no estorno` // DECLINED
`RESULT_CANCELED responde OPERATION_CANCELED` // 'Operação cancelada!'
`RESULT_OK sem dados ou sem pagamento responde ERRO_DESCONHECIDO` // 'Erro desconhecido, tente novamente!'
`outro resultCode responde UNKNOWN_ERROR`
`outro requestCode e ignorado` // false, sem resposta
`responde uma unica vez`
`operacao nova fica com o proximo retorno`
`app da Rede ausente responde ERRO_DESCONHECIDO`
    // checkActivities(true) → 'Não localizamos aplicativo de pagamento neste terminal.'
`excecao ao abrir responde a mensagem ou o texto padrao`
    // RuntimeException("valor do pagamento menor ou igual a zero") → essa mensagem;
    // IllegalArgumentException() no estorno → 'Erro ao iniciar estorno, tente novamente!'
`sem amount ou nsu responde o erro do plugin sem abrir o app`
    // error:amount:amount is null e error:nsu:nsu is null; nextStartedActivityForResult null
```

- [ ] **Passo 2: testes do adaptador com o SDK de verdade** (`SmartRedePaymentAppTest`, Robolectric com `@Config(sdk = [30])`):

```kotlin
`paymentIntent leva o valor e o tipo no pagamento do SDK`
    // getParcelableExtra<Payment>("rede.smartrede.sdk.INTENT_EXTRAS_PAYMENT"): amount 100L, paymentType CREDITO_A_VISTA
`valor zero e recusado pela validacao do SDK`
    // assertThrows(RedePaymentValidationError::class.java) { app.paymentIntent(DEBITO, 0) }
```

Se o SDK não montar o Intent no Robolectric, registrar a decisão e deixar o adaptador para o teste no L400. O adaptador tem duas linhas.

- [ ] **Passo 3: rodar.** `./gradlew :app:testRedeDebugUnitTest --console=plain`
Esperado: falha de compilação (`RedePaymentHandler` e `SmartRedePaymentApp` não existem).

- [ ] **Passo 4: implementar.** A estrutura é a do `VeroPaymentHandler`.
  - O `pending` só é guardado depois do `startActivityForResult` e sai do campo antes de responder.
  - As exceções ao abrir:
    - `ActivityNotFoundException` responde a mensagem do app ausente;
    - as outras respondem `exception.message`, ou "Erro ao iniciar pagamento, tente novamente!" / "Erro ao iniciar estorno, tente novamente!".
  - A Pix é detectada por `operationType.lowercase().contains("pix")`.
  - O `AMOUNT` é double, e o `INSTALLMENTS`, inteiro.
  - Todos os códigos e mensagens estão nas tabelas da especificação.

- [ ] **Passo 5: rodar.** `./gradlew :app:testRedeDebugUnitTest --console=plain`
Esperado: BUILD SUCCESSFUL.

### Tarefa 6: impressão da Rede no Android e a integração completa

**Arquivos:**
- Criar:
  - `example/android/app/src/rede/kotlin/com/example/example/rede/RedePrinterHandler.kt`;
  - `example/android/app/src/testRede/kotlin/com/example/example/rede/RedePrinterHandlerTest.kt`;
  - `example/android/app/src/testRede/kotlin/com/example/example/RedeIntegrationTest.kt`.
- Modificar: `example/android/app/src/rede/kotlin/com/example/example/RedeIntegration.kt`.

**Interfaces:**
- Consome:
  - `textToBitmap` e `TEST_PRINT_TEXT` (Tarefa 4);
  - `RedePaymentApp`, `SmartRedePaymentApp` e `RedePaymentHandler` (Tarefa 5).
- Produz:
  - `internal class RedePrinterHandler(openPrinter: () -> IConnectorPrinter)`, com `handle(call, result)` e `METHODS = setOf("print_receipt", "print_txt", "test_print")`. A impressora fica atrás da interface do próprio SDK (`IConnectorPrinter`), aberta pela fábrica `openPrinter`. É a interface pequena da especificação, e os testes trocam a impressora por uma falsa;
  - `internal class RedeIntegration(paymentApp: (Context) -> RedePaymentApp = ::SmartRedePaymentApp, openPrinter: (Context) -> IConnectorPrinter = { IRedeSdk.newInstance(it).terminalFunctions.connectorPrinter }) : AcquirerIntegration`. Ela roteia o canal `rede_sdk` pelos dois `METHODS`; método desconhecido responde `notImplemented()`.

- [ ] **Passo 1: testes da impressão.**
  - Robolectric com `@Config(sdk = [30])` e `@GraphicsMode(NATIVE)`.
  - Um `FakeConnectorPrinter : IConnectorPrinter` guarda o callback e os bitmaps. No `printBitmap`, executa uma ação configurável: chamar `callback.onError(...)` ou lançar uma exceção.

```kotlin
`print_txt imprime o texto em 576 px e responde sucesso` // success:Sucesso ao efetuar a impressão
`print_receipt decodifica o PNG e imprime` // bitmap 10 x 4
`test_print imprime Impressao teste` // sameAs(textToBitmap(TEST_PRINT_TEXT))
`Printer out of paper responde ERRO_SEM_PAPEL` // 'Impressora sem papel, verifique!'
`Init failed e Printer not ready respondem IMPRESSORA_INDISPONIVEL` // 'Módulo de impressão não inicializado'
`outra mensagem do SDK responde ERRO_DESCONHECIDO` // 'Error during print' → 'Erro na impressão'
`PrinterException responde pela mensagem dela` // PrinterException("Printer out of paper", null) → ERRO_SEM_PAPEL
`LinkageError na impressao responde ERRO_DESCONHECIDO sem derrubar o app` // NoClassDefFoundError
`SDK que nao abre responde IMPRESSORA_INDISPONIVEL e tenta abrir de novo na proxima impressao`
`a impressora e aberta uma vez so e o callback registrado nela` // openPrinter chamado 1 vez em 2 impressões
`o erro de uma impressao nao passa para a seguinte`
`bytes que nao formam imagem respondem ERRO_DESCONHECIDO sem imprimir`
`sem bitmap ou text responde o erro do plugin sem abrir a impressora` // error:bitmap:bitmap is null, error:text:text is null
```

- [ ] **Passo 2: testes da integração.** `RedeIntegrationTest`, com o `FakeMessenger` do teste da Vero (codec real). Os fakes entram pelo construtor da `RedeIntegration`.

```kotlin
`credit_payment pelo canal rede_sdk abre o app e o onActivityResult responde ao Dart` // mapa com AMOUNT 1.0 pelo codec
`impressao durante um pagamento nao responde por ele`
    // credit_payment pendente; print_txt responde sucesso; o onActivityResult responde ao pagamento
`pagamento funciona num aparelho sem o SDK da impressora` // openPrinter lança; o credit_payment abre o app
`metodo desconhecido responde notImplemented`
```

- [ ] **Passo 3: rodar.** `./gradlew :app:testRedeDebugUnitTest --console=plain`
Esperado: falha de compilação (`RedePrinterHandler` não existe, e a `RedeIntegration` não tem o construtor).

- [ ] **Passo 4: implementar.**
  - **Impressora:** é aberta na primeira impressão, com `setPrinterCallback` uma vez. Se `openPrinter` lança `RuntimeException`, a resposta é `IMPRESSORA_INDISPONIVEL`, e a próxima impressão tenta abrir de novo.
  - **Erro de cada impressão:** o callback guarda o erro, que é zerado antes de cada `printBitmap`.
  - **Mapeamento pela mensagem**, também para a da `PrinterException`:
    - "Printer out of paper" ou "Impressora sem papel, verifique!" viram `ERRO_SEM_PAPEL`;
    - "Init failed", "Printer not ready" ou "Módulo de impressão não inicializado" viram `IMPRESSORA_INDISPONIVEL`;
    - o resto vira `ERRO_DESCONHECIDO` / "Erro na impressão".
  - **Detalhes do erro:** levam a mensagem crua do SDK.
  - **`LinkageError`:** vira `ERRO_DESCONHECIDO`.
  - **Thread:** tudo na main thread, síncrono.
  - **`RedeIntegration`:** `createAcquirerIntegration()` devolve `RedeIntegration()`.

- [ ] **Passo 5: rodar.** `./gradlew :app:testRedeDebugUnitTest :app:testVeroDebugUnitTest :app:testStoneDebugUnitTest :app:testCieloDebugUnitTest :app:testPagbankDebugUnitTest --console=plain`
Esperado: BUILD SUCCESSFUL.

### Tarefa 7: tela da Rede no app de exemplo

**Arquivos:**
- Criar:
  - `example/lib/integrations/rede_integration.dart`;
  - `example/lib/presentation/views/rede/{rede.state.dart, rede.viewmodel.dart, rede.page.dart, rede.dart}`;
  - `example/lib/presentation/mocks/rede_payments_mock.dart`;
  - `example/lib/presentation/widgets/rede_status_widget.dart`;
  - `example/test/modules/rede/fakes/fake_rede_payment_service.dart`;
  - `example/test/modules/rede/presentation/pages/{rede_viewmodel_test.dart, rede_page_test.dart}`;
  - `assets/env/rede_env.json` com `{"FLAVOR_TYPE": "rede"}`. Ele é ignorado pelo git.
- Modificar:
  - os barris `integrations.dart`, `views.dart`, `mocks.dart` e `widgets.dart`;
  - `example/lib/main.dart`;
  - `example/test/widget_test.dart`;
  - `.vscode/launch.json`, com "Rede Integration";
  - o comentário de `example/lib/integrations/acquirer_integration.dart`, que passa a citar a rede.

**Interfaces:**
- Consome: `IRedePaymentService`, `RedePaymentService` e `RedeTransactionResult`.
- Produz:
  - `RedeViewModel(IRedePaymentService)`, com `pay(RedePaymentType type, double amount)`, `refundLastPayment()`, `printNfc(String)`, `printTxt(String)` e `testPrint()`;
  - `RedePageStatus {idle, success, loading, error}`, com extensão `isIdle`/`isLoading`/`isSuccess`/`isError`;
  - `RedePaymentType {credit, debit, pix}`;
  - `RedeState {message, status, transaction, lastPayment}`.

- [ ] **Passo 1: testes.** Iguais aos da Vero, trocando os nomes.
  - **View model:**
    - cada tipo chama `creditCardPayment`, `debitCardPayment` ou `pixPayment`;
    - fica em "Processando o pagamento no app da Rede..." até a resposta;
    - mostra a falha;
    - estorna pelo NSU e some o estorno;
    - sem pagamento, o estorno não chama o serviço;
    - as impressões mostram "NFC-e impressa.", "Texto impresso." e "Impressão de teste concluída.";
    - a falha da impressão aparece, e o último pagamento continua estornável.
  - **Tela:**
    - mocks "Crédito • R\$ 1,00", "Débito • R\$ 1,00" e "Pix • R\$ 1,00";
    - estorno liberado depois do pagamento;
    - a seção "Impressão pela impressora da Rede" com os botões da Vero.
  - **`widget_test`:** `'flavor rede: abre direto na tela da Rede'`.

- [ ] **Passo 2: rodar.** `cd example && ../.fvm/flutter_sdk/bin/flutter test test/modules/rede test/widget_test.dart`
Esperado: falha de compilação.

- [ ] **Passo 3: implementar.**
  - A tela, o estado e o view model espelham os da Vero. O view model usa o `IRedePaymentService` para pagar e imprimir.
  - O card mostra NSU, Autorização, Bandeira e "Valor: ${amount}".
  - A injeção: `IPdfImageConverter` → `PdfImageConverter`; `IRedePaymentService` → `RedePaymentService(MethodChannel('rede_sdk'), converter)`; `RedeViewModel`, como fábrica.
  - No `main.dart`, `const _isRede = appFlavor == 'rede'` e `if (_isRede) return RedeIntegration();`.

- [ ] **Passo 4: rodar.** `cd example && ../.fvm/flutter_sdk/bin/flutter test && ../.fvm/flutter_sdk/bin/flutter analyze && ../.fvm/flutter_sdk/bin/dart format --output=none --set-exit-if-changed lib test`
Esperado: tudo verde.

### Tarefa 8: builds e varredura dos APKs

**Arquivos:** nenhum. Os scripts de varredura ficam no scratchpad.

- [ ] **Passo 1: APK da Rede.** `cd example && ../.fvm/flutter_sdk/bin/flutter build apk --debug --flavor rede --dart-define-from-file=../assets/env/rede_env.json`
Esperado: `app-rede-debug.apk`. No manifest mesclado (`build/app/intermediates/merged_manifest/redeDebug/...`) estão `minSdkVersion="28"` e `com.pos.permission.PRINTER`.

- [ ] **Passo 2: APKs de release dos outros flavors.** Gerar os de stone, cielo, pagbank e vero, com o env de cada um.
Varrer os quatro, sem diferenciar maiúsculas, em ASCII e UTF-16LE, por `smartrede`, `rede_sdk`, `br/com/positivo`, `com/pos/sdk` e `libpos_emv_kernel`.
Esperado: nenhuma ocorrência. O `app-rede-debug.apk` tem todas, como controle positivo.

- [ ] **Passo 3: suítes finais.** `core` e `example` (`test`, `analyze`, `format`) e os testes Kotlin dos cinco flavors.
Esperado: tudo verde. Registrar os números para o relatório.
