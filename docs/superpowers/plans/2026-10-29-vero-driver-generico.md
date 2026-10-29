# Vero e driver genérico de impressão: plano de implementação

> **Para quem for executar:** use o `superpowers:subagent-driven-development` (recomendado) ou o `superpowers:executing-plans` para seguir este plano tarefa por tarefa. Os passos usam caixas (`- [ ]`) para acompanhar o andamento.

**Objetivo:** pagamentos da Vero (crédito, débito, Pix, carteira e estorno) e o driver genérico de impressão (`posmpapi`) neste core, com os nomes do `centralizer`, e um flavor `vero` com tela de teste.

**Arquitetura:**
- **`core`:** ganha `IVeroPaymentService`, no canal `vero_flutter`, e `INativePrinterService`, no canal `acquirers_sdk`.
- **Android:**
  - o flavor `vero` traz o handler de pagamento, que abre o app da Vero por `startActivityForResult`;
  - o source set `src/genericPrinter/` traz o `ServicePrinter` atrás de uma porta (`PosPrinter`). Ele só entra no flavor `vero`, junto com o AAR.
- **`MainActivity`:** passa a repassar o `onActivityResult` para a integração.

**Tecnologias:**
- Flutter 3.35.2 (fvm), Dart com `fpdart`/`Either`, `dart:ui`;
- Kotlin, Robolectric 4.16;
- AGP com Kotlin DSL;
- `posmpapi_1.01.10-partnersRelease.aar`.

**Especificação:** `docs/superpowers/specs/2026-10-29-vero-driver-generico-design.md`. Quem for executar lê a especificação e este plano.

## Restrições globais

- **Nomes iguais aos do `centralizer`:**
  - canais `vero_flutter` e `acquirers_sdk`;
  - métodos `payCredit`, `payDebit`, `payPix`, `wallet` (`{amount: int}`) e `refund` (`{nsu}`);
  - métodos `printReceipt {bitmap}`, `printTxt {text}` e `testPrint`.
- **Intent da Vero:**
  - ação `br.com.execucao.PAGAR`, com extras `VALOR` (o `Number` recebido do canal), `TRANSACAO` ∈ {`CREDITO_GENERICO`, `DEBITO`, `PIX`, `WALLET`} e `IMPRIMIR_COMPROVANTE=false`;
  - ação `br.com.execucao.ESTORNAR`, com `NSU` e `IMPRIMIR_COMPROVANTE=false`;
  - código de requisição `1`.
- **Centavos:** `(amount * 100).round()`.
- **Códigos e mensagens:** exatamente como nas tabelas da especificação.
  - Vero: `ERRO_DESCONHECIDO`, `nsu.not.informed`, `<método>.not.implemented`, `unknown.error`.
  - Driver: `ERRO_SEM_PAPEL`, `ERRO_DESCONHECIDO`, `NOT_SUPPORTED`.
  - Argumento ausente no canal `acquirers_sdk`: `bitmap` / "bitmap is null" e `text` / "text is null", como no plugin do `centralizer`.
- **Texto em bitmap:**
  - 576 px de largura, `textSize` 20, `Typeface.MONOSPACE`, antialias e fundo branco;
  - linhas separadas por `\n`, com altura `linhas × (descent − ascent) + 20`;
  - o teste de impressão manda "Impressao teste".
- **Sucesso do driver:** "Sucesso ao efetuar a impressão".
- **`NativePrinterService.printReceipt`:** acrescenta 80 linhas em branco no fim do PNG.
- **Novas tentativas do driver:** uma por chamada, em `ERRO_DESCONHECIDO` ou `IMPRESSORA_INDISPONIVEL`.
- **AAR:** o `posmpapi` só entra no flavor `vero`, porque cita Vero e Rede e o PagBank não homologa APK com outras adquirentes.
- **Comandos:**
  - Flutter: `fvm flutter`;
  - Gradle: `$env:JAVA_HOME = 'C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot'`, em `example/android`.
- **Estilo:** comentários e textos em português, com no máximo 110 colunas.
- **Sem commits:** a branch é a `main`, com outro trabalho ainda não commitado, e o usuário não pediu commit. Cada tarefa termina com a suíte verde, não com um commit.

## Pontos de atenção na revisão

1. **O app da Vero devolve um extra que não é texto,** por exemplo `PARCELAS` como inteiro. Ele deve virar texto, não erro de tipo. Teste na Tarefa 1.
2. **URI de comprovante que não abre.** O valor vai `null` ao Dart, que o lê como `''`, e o pagamento continua aprovado. Testes nas Tarefas 1 e 5.
3. **Bytes que não são imagem no `printReceipt`.** A resposta é `ERRO_DESCONHECIDO`, sem derrubar o app. Teste na Tarefa 4.
4. **Uma segunda operação enquanto a primeira espera.** O próximo retorno vai para a segunda, e o app não quebra. Teste na Tarefa 5.
5. **Falha na impressão do comprovante automático.** Não muda o resultado da transação aprovada. Teste na Tarefa 3.

---

### Tarefa 1: modelos da Vero no `core`

**Arquivos:**
- Criar: `core/lib/domain/models/vero_transaction_result.dart`, `core/lib/domain/failures/vero_error.dart`
- Modificar: `core/lib/domain/models/models.dart` e `core/lib/domain/failures/failures.dart`, para exportar os novos arquivos
- Teste: `core/test/domain/models/vero_transaction_result_test.dart`

**Interfaces:**
- **Produz `VeroTransactionResult`** (`extends Equatable`):
  - 16 campos `final String`: `serial`, `acquiringCnpj`, `flag`, `establishmentName`, `transaction`, `receipt`, `establishmentCnpj`, `nsu`, `value`, `cardNumber`, `authorization`, `merchantReceipt`, `customerReceiptTxt`, `customerReceipt`, `installments`, `acquirerName`;
  - construtor `const` com todos `required`;
  - `factory VeroTransactionResult.fromMap(Map<dynamic, dynamic> map)`, que lê as chaves da tabela da especificação. Valor ausente vira `''`; outro tipo vira `toString()`.
- **Produz `VeroError`** (`extends Equatable`):
  - `final String code, message` e `const VeroError({required this.code, required this.message})`;
  - `factory VeroError.nsuNotInformed()` → `nsu.not.informed` / "O campo: nsu não foi informado! Corrija-o e tente novamente!";
  - `factory VeroError.notImplemented(String method)` → `'$method.not.implemented'` / `'$method() has not been implemented.'`;
  - `factory VeroError.unknown()` → `unknown.error` / "Erro desconhecido, tente novamente".

- [ ] **Passo 1: escrever os testes que falham**

```dart
test('fromMap lê as 16 chaves do retorno da Vero', () {
  final result = VeroTransactionResult.fromMap({
    'SERIAL': 'S1', 'CNPJ_ADQUIRENTE': '92702067000196', 'BANDEIRA': 'VISA', 'NOME_ESTABELECIMENTO': 'LOJA',
    'TRANSACAO': 'CREDITO', 'COMPROVANTE': 'C', 'CNPJ_ESTABELECIMENTO': '07056528000121', 'NSU': '123',
    'VALOR': '1000', 'NUMCARTAO': '************1234', 'AUTORIZACAO': 'A1', 'COMPROVANTE_LOJISTA': '/cache/l.png',
    'COMPROVANTE_CLIENTE_TXT': 'TXT', 'COMPROVANTE_CLIENTE': '/cache/c.png', 'PARCELAS': '1', 'NOME_ADQUIRENTE': 'VERO',
  });
  expect(result, const VeroTransactionResult(serial: 'S1', acquiringCnpj: '92702067000196', flag: 'VISA',
    establishmentName: 'LOJA', transaction: 'CREDITO', receipt: 'C', establishmentCnpj: '07056528000121', nsu: '123',
    value: '1000', cardNumber: '************1234', authorization: 'A1', merchantReceipt: '/cache/l.png',
    customerReceiptTxt: 'TXT', customerReceipt: '/cache/c.png', installments: '1', acquirerName: 'VERO'));
});

test('campo ausente ou nulo vira texto vazio', () {
  final result = VeroTransactionResult.fromMap({'NSU': '123', 'COMPROVANTE_CLIENTE': null});
  expect(result.nsu, '123');
  expect([result.serial, result.customerReceipt, result.customerReceiptTxt], ['', '', '']);
});

test('valor que não é texto vira texto', () {
  expect(VeroTransactionResult.fromMap({'PARCELAS': 3, 'VALOR': 1000}).installments, '3');
});
```

- [ ] **Passo 2: rodar e ver falhar.** Em `core`: `fvm flutter test test/domain/models/vero_transaction_result_test.dart`. Esperado: erro de compilação, porque `VeroTransactionResult` não existe.
- [ ] **Passo 3: implementar os dois arquivos** com as assinaturas acima e exportá-los nos barris.
- [ ] **Passo 4: rodar e ver passar.** O mesmo comando dá `All tests passed!`.

---

### Tarefa 2: driver genérico no `core` (`INativePrinterService`)

**Arquivos:**
- Criar:
  - `core/lib/data/interfaces/native_printer_interface.dart`
  - `core/lib/domain/failures/native_printer_error.dart`
  - `core/lib/infrastructure/native_printer/native_printer_service.dart`
- Modificar: `interfaces.dart`, `failures.dart` e `infrastructure.dart`, para exportar os novos arquivos
- Teste: `core/test/infrastructure/native_printer/native_printer_service_test.dart`

**Interfaces:**
- **Consome:** `IPdfImageConverter.firstPageToPng(String)` → `Either<PdfImageFailure, Uint8List>`, que já existe.
- **Produz `INativePrinterService`.** Todos os métodos devolvem `Future<Either<NativePrinterError, Unit>>`:
  - `printTxt(String text)`
  - `printNfc(String nfcBase64)`
  - `testPrint()`
  - `printReceipt({required Uint8List bitmap})`
- **Produz `NativePrinterError`:**
  - `final String code, message` e `const NativePrinterError({required this.code, required this.message})`;
  - `factory NativePrinterError.notSupported()` → `NOT_SUPPORTED` / "Driver de impressão indisponível nesta plataforma.".
- **Produz o construtor** `NativePrinterService(MethodChannel channel, IPdfImageConverter pdfImage)`.

**Comportamento:**
- `printReceipt` acrescenta 80 linhas brancas no fim, com `dart:ui`: o canvas tem `altura + 80`, é pintado de branco e recebe a imagem no topo. Depois chama `printReceipt` no canal com `{'bitmap': png}`.
- `printTxt` chama `printTxt` no canal com `{'text': text}`. `testPrint` chama `testPrint` no canal com `{}`.
- `PlatformException` vira `NativePrinterError(code: e.code, message: e.message ?? e.stacktrace ?? e.toString())`. Em `ERRO_DESCONHECIDO` ou `IMPRESSORA_INDISPONIVEL`, o pedido é repetido uma vez antes de virar erro.
- `MissingPluginException` vira `notSupported()`.
- Se o conversor falhar no `printNfc`, o resultado é `NativePrinterError(code: falha.code, message: falha.message)`, sem chamar o canal.

- [ ] **Passo 1: escrever os testes que falham.** O formato é o do `stone_payment_service_test.dart`:
  - mock do canal `acquirers_sdk` que registra as chamadas;
  - auxiliares `_png(tones, {width})` e `_decode(png)`, copiados de lá;
  - um `_FakePdfImageConverter`.

```dart
test('printTxt e testPrint usam os nomes do NativePrinter', () async {
  mockAndroid((_) async => 'Sucesso ao efetuar a impressão');
  await service.printTxt('LINHA');
  await service.testPrint();
  expect(calls.map((c) => c.method), ['printTxt', 'testPrint']);
  expect(calls.first.arguments, {'text': 'LINHA'});
});

test('printReceipt manda o bitmap com 1 cm de papel em branco no fim', () async {
  mockAndroid((_) async => 'Sucesso ao efetuar a impressão');
  await service.printReceipt(bitmap: await _png([0, 0, 0]));
  final sent = await _decode((calls.single.arguments as Map)['bitmap'] as Uint8List);
  expect([sent.width, sent.height], [3, 81]);
  expect(sent.tones.take(3), [0, 0, 0]);
  expect(sent.tones.skip(3), everyElement(255));
});

test('tenta mais uma vez em ERRO_DESCONHECIDO e em IMPRESSORA_INDISPONIVEL, e não em ERRO_SEM_PAPEL', () async {
  for (final code in ['ERRO_DESCONHECIDO', 'IMPRESSORA_INDISPONIVEL']) {
    calls.clear();
    mockAndroid((_) async => throw PlatformException(code: code, message: 'Erro na impressão'));
    expect((await service.printTxt('X')).getLeft().toNullable()?.code, code);
    expect(calls, hasLength(2));
  }
  calls.clear();
  mockAndroid((_) async => throw PlatformException(code: 'ERRO_SEM_PAPEL', message: 'Impressora sem papel, verifique!'));
  final failure = (await service.printTxt('X')).getLeft().toNullable();
  expect([failure?.code, failure?.message], ['ERRO_SEM_PAPEL', 'Impressora sem papel, verifique!']);
  expect(calls, hasLength(1));
});

test('printNfc converte a NFC-e e imprime a imagem', () async {
  mockAndroid((_) async => 'Sucesso ao efetuar a impressão');
  converter.result = right(await _png([0, 255]));
  expect((await service.printNfc('JVBERi0=')).isRight(), isTrue);
  expect(converter.pdfs.single, 'JVBERi0=');
  expect(calls.single.method, 'printReceipt');
});

test('printNfc devolve a falha do conversor sem chamar o Android', () async { /* INVALID_PDF, 'PDF corrompido', calls vazio */ });

test('canal inexistente vira NOT_SUPPORTED', () async {
  mockAndroid(null);
  final failure = (await service.testPrint()).getLeft().toNullable();
  expect([failure?.code, failure?.message], ['NOT_SUPPORTED', 'Driver de impressão indisponível nesta plataforma.']);
});
```

- [ ] **Passo 2: rodar e ver falhar.** `fvm flutter test test/infrastructure/native_printer/` dá erro de compilação, porque as classes não existem.
- [ ] **Passo 3: implementar** a interface, o erro e o serviço com as assinaturas acima e exportar nos barris.
- [ ] **Passo 4: rodar e ver passar.** Rodar também `fvm flutter analyze` em `core`, que não deve acusar nada.

---

### Tarefa 3: pagamentos da Vero no `core` (`IVeroPaymentService`)

**Arquivos:**
- Criar: `core/lib/data/interfaces/vero_payment_interface.dart` e `core/lib/infrastructure/vero_payment/vero_payment_service.dart`
- Modificar: `interfaces.dart` e `infrastructure.dart`, para exportar os novos arquivos
- Teste: `core/test/infrastructure/vero_payment/vero_payment_service_test.dart`

**Interfaces:**
- **Consome:**
  - `VeroTransactionResult.fromMap` e os construtores de `VeroError`, da Tarefa 1;
  - `INativePrinterService.printTxt`, da Tarefa 2.
- **Produz `IVeroPaymentService`.** Todos os métodos devolvem `Future<Either<VeroError, VeroTransactionResult>>`:
  - `creditCardPayment(double amount)`
  - `debitCardPayment(double amount)`
  - `pixPayment(double amount)`
  - `acquirerPayment(double amount)`
  - `refundPayment(String nsu)`
- **Produz o construtor** `VeroPaymentService(MethodChannel channel, INativePrinterService printer)`.

**Comportamento:**
- Mapeamento de métodos: `creditCardPayment` → `payCredit`, `debitCardPayment` → `payDebit`, `pixPayment` → `payPix`, `acquirerPayment` → `wallet`, todos com `{'amount': (amount * 100).round()}`. `refundPayment` → `refund {'nsu': nsu}`.
- O resultado é lido com `invokeMethod<Map<dynamic, dynamic>>`.
  - Um mapa nulo vira `VeroError.unknown()`.
  - Com sucesso, o serviço chama `printer.printTxt(result.customerReceiptTxt)`, ignora o resultado e devolve `right(result)`.
- `PlatformException` vira `VeroError(code: e.code, message: e.message ?? e.stacktrace ?? e.toString())`.
- `MissingPluginException` vira `VeroError.notImplemented(<método do canal>)`.
- Um NSU em branco depois de `trim()` vira `VeroError.nsuNotInformed()`, sem chamar o canal.

- [ ] **Passo 1: escrever os testes que falham.** O mock é do canal `vero_flutter`, com um `_FakePrinter implements INativePrinterService` que registra os `printTxt` e devolve um `result` configurável.

```dart
test('cada pagamento chama o método do plugin com o valor em centavos arredondado', () async {
  mockAndroid((_) async => {'AUTORIZACAO': 'A1', 'NSU': '1'});
  await service.creditCardPayment(0.29);
  await service.debitCardPayment(4.35);
  await service.pixPayment(33.30);
  await service.acquirerPayment(1.00);
  expect(calls.map((c) => [c.method, c.arguments]), [
    ['payCredit', {'amount': 29}], ['payDebit', {'amount': 435}],
    ['payPix', {'amount': 3330}], ['wallet', {'amount': 100}],
  ]);
});

test('pagamento aprovado devolve a transação e imprime o comprovante do cliente', () async {
  mockAndroid((_) async => {'AUTORIZACAO': 'A1', 'NSU': '123', 'COMPROVANTE_CLIENTE_TXT': 'VIA CLIENTE'});
  final result = (await service.creditCardPayment(10)).getRight().toNullable();
  expect([result?.nsu, result?.authorization], ['123', 'A1']);
  expect(printer.texts, ['VIA CLIENTE']);
});

test('estorno aprovado também imprime o comprovante do cliente', () async {
  mockAndroid((_) async => {'AUTORIZACAO': 'A1', 'COMPROVANTE_CLIENTE_TXT': 'ESTORNO'});
  await service.refundPayment('123');
  expect([calls.single.method, calls.single.arguments], ['refund', {'nsu': '123'}]);
  expect(printer.texts, ['ESTORNO']);
});

test('falha na impressão do comprovante não muda o resultado', () async {
  printer.result = left(const NativePrinterError(code: 'ERRO_SEM_PAPEL', message: 'Impressora sem papel, verifique!'));
  mockAndroid((_) async => {'AUTORIZACAO': 'A1', 'NSU': '123'});
  expect((await service.debitCardPayment(1)).getRight().toNullable()?.nsu, '123');
});

test('erro do app da Vero volta com o mesmo código e mensagem, sem imprimir', () async {
  mockAndroid((_) async => throw PlatformException(code: 'ERRO_DESCONHECIDO', message: 'Operação cancelada pelo usuário!'));
  final failure = (await service.pixPayment(1)).getLeft().toNullable();
  expect([failure?.code, failure?.message], ['ERRO_DESCONHECIDO', 'Operação cancelada pelo usuário!']);
  expect(printer.texts, isEmpty);
});

test('estorno com NSU em branco não chama o Android', () async {
  mockAndroid((_) async => {'AUTORIZACAO': 'A1'});
  final failure = (await service.refundPayment('  ')).getLeft().toNullable();
  expect([failure?.code, failure?.message], ['nsu.not.informed', 'O campo: nsu não foi informado! Corrija-o e tente novamente!']);
  expect(calls, isEmpty);
});

test('canal inexistente vira <método>.not.implemented', () async {
  mockAndroid(null);
  final failure = (await service.creditCardPayment(1)).getLeft().toNullable();
  expect([failure?.code, failure?.message], ['payCredit.not.implemented', 'payCredit() has not been implemented.']);
});

test('resposta vazia vira unknown.error', () async {
  mockAndroid((_) async => null);
  final failure = (await service.acquirerPayment(1)).getLeft().toNullable();
  expect([failure?.code, failure?.message], ['unknown.error', 'Erro desconhecido, tente novamente']);
});
```

- [ ] **Passo 2: rodar e ver falhar.** `fvm flutter test test/infrastructure/vero_payment/` dá erro de compilação.
- [ ] **Passo 3: implementar** a interface e o serviço e exportar nos barris.
- [ ] **Passo 4: rodar a suíte inteira do `core`.** `fvm flutter test`, `fvm flutter analyze` e `fvm dart format --output=none --set-exit-if-changed lib test` devem passar sem nada a acusar.

---

### Tarefa 4: flavor `vero` com o driver genérico no Android

**Arquivos:**
- Copiar: `C:/Users/user/Desktop/Projetos/Mobile/centralizer/android/libs/posmpapi_1.01.10-partnersRelease.aar` para `example/android/app/libs/posmpapi_1.01.10-partnersRelease.aar`. Conferir com `git check-ignore -v` que ele não é ignorado; se for, avisar o usuário.
- Modificar: `example/android/app/build.gradle.kts`
  - criar o flavor `vero` com `dimension = "acquirer"`;
  - adicionar `sourceSets.getByName("vero").java.srcDir("src/genericPrinter/kotlin")`;
  - adicionar `"veroImplementation"(files("libs/posmpapi_1.01.10-partnersRelease.aar"))`.
- Criar, no pacote `com.example.example.printer`, em `example/android/app/src/genericPrinter/kotlin/com/example/example/printer/`:
  - `PosPrinter.kt`: a porta, o listener e o adaptador `PosmpPrinter`;
  - `ServicePrinter.kt`;
  - `GenericPrinterHandler.kt`.
- Criar: `example/android/app/src/vero/kotlin/com/example/example/VeroIntegration.kt`, com `createAcquirerIntegration()` e `VeroIntegration`. Nesta tarefa ele só registra o canal `acquirers_sdk`.
- Testes: `example/android/app/src/testVero/kotlin/com/example/example/printer/ServicePrinterTest.kt` e `GenericPrinterHandlerTest.kt`

**Interfaces:**
- **Produz a porta e o listener:**
  - `internal interface PosPrinter { fun open(); fun print(bitmap: Bitmap, listener: PosPrinterListener); fun close() }`
  - `internal interface PosPrinterListener { fun onFinish(); fun onError(outOfPaper: Boolean) }`
- **Produz o adaptador `internal class PosmpPrinter(context: Context) : PosPrinter`:**
  - usa `Printer.getInstance(context)`;
  - `onError(error)` repassa `error == Printer.ERRO_SEM_PAPEL`;
  - não tem teste unitário, porque o `posmpapi` precisa do serviço do fabricante. É verificado no terminal.
- **Produz o `ServicePrinter`**, com os nomes do `centralizer`:
  - `internal class ServicePrinter(private val printer: PosPrinter, private val result: MethodChannel.Result)`;
  - `open()` no `init`;
  - métodos `fun printReceipt(byteArray: ByteArray)`, `fun testPrint()` e `fun printTxtReceipt(text: String)`;
  - `companion object { fun textToBitmap(text: String): Bitmap }`.
  - Depois de `print`, chama `close()`, como o `centralizer`.
  - `onFinish` responde `success("Sucesso ao efetuar a impressão")`.
  - `onError(true)` responde `error("ERRO_SEM_PAPEL", "Impressora sem papel, verifique!", null)`.
  - `onError(false)`, uma exceção ou bytes que não decodificam respondem `error("ERRO_DESCONHECIDO", "Erro na impressão", detalhe)`.
- **Produz o handler `internal class GenericPrinterHandler(private val printerFactory: () -> PosPrinter)`:**
  - `fun handle(call: MethodCall, result: MethodChannel.Result)`;
  - `companion object { const val CHANNEL = "acquirers_sdk" }`.

- [ ] **Passo 1: copiar o AAR, criar o flavor no Gradle e escrever os testes que falham.** Os testes usam Robolectric e `@GraphicsMode(GraphicsMode.Mode.NATIVE)`. Se o modo nativo não rodar no Windows, as asserções de pixel saem e ficam as de dimensão.

```kotlin
// ServicePrinterTest: FakePosPrinter registra "open"/"print"/"close", guarda o bitmap e o listener, e pode lançar no print.
@Test fun `printTxtReceipt desenha o texto em 576 px e responde sucesso no onFinish`() {
    ServicePrinter(fake, result).printTxtReceipt("LINHA 1\nLINHA 2\nLINHA 3")
    assertEquals(576, fake.bitmap!!.width)
    assertTrue(fake.bitmap!!.height > ServicePrinter.textToBitmap("LINHA 1").height)
    fake.listener!!.onFinish()
    assertEquals(listOf("success:Sucesso ao efetuar a impressão"), result.replies)
}
@Test fun `abre a impressora ao criar e fecha depois de mandar imprimir`() { /* log == [open, print, close] */ }
@Test fun `onError sem papel responde ERRO_SEM_PAPEL`() { /* "error:ERRO_SEM_PAPEL:Impressora sem papel, verifique!" */ }
@Test fun `onError com outro codigo responde ERRO_DESCONHECIDO`() { /* "error:ERRO_DESCONHECIDO:Erro na impressão" */ }
@Test fun `excecao da impressora responde ERRO_DESCONHECIDO`() { /* fake.print lança RuntimeException */ }
@Test fun `printReceipt decodifica os bytes e imprime o bitmap`() { /* PNG 10x4 feito com Bitmap.compress; fake.bitmap 10x4 */ }
@Test fun `printReceipt com bytes que nao sao imagem responde ERRO_DESCONHECIDO sem imprimir`() { /* byteArrayOf(1,2,3) */ }
@Test fun `testPrint imprime Impressao teste`() { assertTrue(fake.bitmap!!.sameAs(ServicePrinter.textToBitmap("Impressao teste"))) }

// GenericPrinterHandlerTest
@Test fun `printTxt printReceipt e testPrint chegam ao ServicePrinter`() { /* factory devolve um fake novo por chamada */ }
@Test fun `sem argumento responde os codigos do plugin`() {
    /* printReceipt sem bitmap -> "error:bitmap:bitmap is null"; printTxt sem text -> "error:text:text is null" */
}
@Test fun `metodo desconhecido responde notImplemented`() { }
```

- [ ] **Passo 2: rodar e ver falhar.** Em `example/android`, com o JDK 17: `.\gradlew.bat :app:testVeroDebugUnitTest --console=plain`. Esperado: `Unresolved reference` para `ServicePrinter`/`GenericPrinterHandler`.
- [ ] **Passo 3: implementar** a porta, o adaptador, o `ServicePrinter`, o handler e o `VeroIntegration.kt`. O `configure` registra `MethodChannel(messenger, GenericPrinterHandler.CHANNEL)` com `GenericPrinterHandler { PosmpPrinter(activity.applicationContext) }`; a impressora só é criada por chamada.
- [ ] **Passo 4: rodar e ver passar.** O mesmo comando dá `BUILD SUCCESSFUL`. Rodar também `:app:testStoneDebugUnitTest :app:testCieloDebugUnitTest :app:testPagbankDebugUnitTest`, que devem passar sem mudança.

---

### Tarefa 5: pagamento da Vero no Android, com `onActivityResult`

**Arquivos:**
- Modificar:
  - `example/android/app/src/main/kotlin/com/example/example/AcquirerIntegration.kt`: adicionar `fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean = false`, com KDoc;
  - `MainActivity.kt`: `override fun onActivityResult(...)`, que chama o `super` e depois `integration.onActivityResult(...)`;
  - `example/android/app/src/vero/kotlin/com/example/example/VeroIntegration.kt`: registrar o canal `vero_flutter` e repassar o `onActivityResult`.
- Criar, no pacote `com.example.example.vero`:
  - `example/android/app/src/vero/kotlin/com/example/example/vero/VeroPaymentHandler.kt`
  - `example/android/app/src/vero/kotlin/com/example/example/vero/VeroBundle.kt`, com `internal fun Bundle.toMap(context: Context): Map<String, Any?>`. Uma `Uri` é copiada para `cacheDir/<lastPathSegment>` e devolvida como caminho absoluto; se a cópia falhar, o valor é `null`, como no `Utils.kt` do plugin.
- Testes: `example/android/app/src/testVero/kotlin/com/example/example/vero/VeroPaymentHandlerTest.kt` e `example/android/app/src/testVero/kotlin/com/example/example/VeroIntegrationTest.kt`. O integration test segue o modelo do `StoneIntegrationTest`.

**Interfaces:**
- **Produz `internal class VeroPaymentHandler(private val activity: Activity)`:**
  - `fun handle(call: MethodCall, result: MethodChannel.Result)`
  - `fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean`
  - `companion object { const val CHANNEL = "vero_flutter"; const val PAYMENT_REQUEST = 1 }`

**Comportamento:**
- A resposta pendente é guardada num wrapper de resposta única. Uma operação nova substitui a pendente.
- Sem `amount` ou `nsu`, a resposta é `error("INVALID_ARGUMENT", "<argumento> é obrigatório.", null)`.
- Se o app não for encontrado (`ActivityNotFoundException`), a resposta é `ERRO_DESCONHECIDO` / "Não localizamos aplicativo de pagamento neste terminal.".
- Outra exceção responde `ERRO_DESCONHECIDO` com a mensagem dela, ou "Não foi possível abrir o aplicativo de pagamento.".
- O `onActivityResult` é traduzido pela tabela de erros da especificação.

- [ ] **Passo 1: escrever os testes que falham.** O `activity` vem de `Robolectric.buildActivity(Activity::class.java).setup().get()`.

```kotlin
@Test fun `payCredit abre o app da Vero com os extras do plugin e codigo 1`() {
    handler.handle(MethodCall("payCredit", mapOf("amount" to 100)), result)
    val started = shadowOf(activity).nextStartedActivityForResult
    assertEquals(1, started.requestCode)
    assertEquals("br.com.execucao.PAGAR", started.intent.action)
    assertEquals(100, started.intent.extras!!.get("VALOR"))
    assertEquals("CREDITO_GENERICO", started.intent.getStringExtra("TRANSACAO"))
    assertEquals(false, started.intent.getBooleanExtra("IMPRIMIR_COMPROVANTE", true))
    assertEquals(emptyList<String>(), result.replies)
}
@Test fun `payDebit payPix e wallet usam DEBITO PIX e WALLET`() { }
@Test fun `refund abre ESTORNAR com o NSU`() { /* action br.com.execucao.ESTORNAR, NSU "123", IMPRIMIR_COMPROVANTE false */ }
@Test fun `RESULT_OK com AUTORIZACAO responde o mapa dos extras`() {
    /* onActivityResult(1, RESULT_OK, Intent().putExtra("AUTORIZACAO","A1").putExtra("NSU","123")) == true
       e replies == ["success:{AUTORIZACAO=A1, NSU=123}"] (comparar como mapa) */
}
@Test fun `URI de comprovante vira caminho de arquivo no cache`() { /* Uri.fromFile(tmp "via.png") -> File(cacheDir,"via.png").absolutePath, mesmo conteúdo */ }
@Test fun `URI que nao abre vira nulo`() { }
@Test fun `extra ERRO responde ERRO_DESCONHECIDO sem pontos e espacos no comeco`() {
    /* ". Saldo insuficiente" -> "Saldo insuficiente"; ERRO "  " -> "Transação rejeitada" */
}
@Test fun `cancelado ou sem AUTORIZACAO responde Operacao cancelada pelo usuario`() { }
@Test fun `responde uma unica vez`() { }
@Test fun `outro requestCode e ignorado`() { /* devolve false, sem resposta */ }
@Test fun `app da Vero ausente responde ERRO_DESCONHECIDO`() { /* shadowOf(application).checkActivities(true) */ }
@Test fun `operacao nova fica com o proximo retorno`() { /* dois payCredit, um retorno: só a segunda resposta */ }

// VeroIntegrationTest (FakeMessenger como no StoneIntegrationTest)
@Test fun `payCredit pelo canal vero_flutter abre o app e o onActivityResult responde ao Dart`() { }
@Test fun `o canal acquirers_sdk do driver esta registrado`() { /* método inexistente responde notImplemented */ }
```

- [ ] **Passo 2: rodar e ver falhar.** `.\gradlew.bat :app:testVeroDebugUnitTest --console=plain` dá `Unresolved reference` para `VeroPaymentHandler`.
- [ ] **Passo 3: implementar** o `AcquirerIntegration`, a `MainActivity`, o `VeroBundle.kt`, o `VeroPaymentHandler` e o `VeroIntegration`.
- [ ] **Passo 4: rodar e ver passar.** Os testes Kotlin dos quatro flavors dão `BUILD SUCCESSFUL`.

---

### Tarefa 6: tela da Vero no app de exemplo

**Arquivos:**
- Criar:
  - `example/lib/integrations/vero_integration.dart`, com a rota `/vero` e o DI de `IPdfImageConverter`, `INativePrinterService` (canal `acquirers_sdk`), `IVeroPaymentService` (canal `vero_flutter`) e `VeroViewModel`;
  - `example/lib/presentation/views/vero/{vero.dart, vero.page.dart, vero.state.dart, vero.viewmodel.dart}`;
  - `example/lib/presentation/mocks/vero_payments_mock.dart`;
  - `example/lib/presentation/widgets/vero_status_widget.dart`, com `VeroStatusCard`, que mostra a mensagem, o NSU, a autorização, a bandeira e o valor, no formato do `PagBankStatusCard`;
  - `assets/env/vero_env.json`, com `{"FLAVOR_TYPE": "vero"}` (fica fora do git).
- Modificar:
  - `integrations.dart`, `views.dart`, `mocks.dart` e `widgets.dart`, para exportar os novos arquivos;
  - `example/lib/main.dart`: `const _isVero = appFlavor == 'vero';` e `if (_isVero) return VeroIntegration();`;
  - `.vscode/launch.json`: a configuração "Vero Integration", com `--flavor vero` e `../assets/env/vero_env.json`.
- Testes:
  - `example/test/modules/vero/fakes/{fake_vero_payment_service.dart, fake_native_printer_service.dart}`;
  - `example/test/modules/vero/presentation/pages/{vero_viewmodel_test.dart, vero_page_test.dart}`;
  - `example/test/widget_test.dart`.

**Interfaces:**
- **Consome** as interfaces das Tarefas 2 e 3.
- **Estado em `vero.state.dart`:**
  - `enum VeroPageStatus { idle, loading, success, error }`. O nome evita colidir com o `VeroStatus` do plugin;
  - `enum VeroPaymentType { credit, debit, pix, wallet }`;
  - `VeroState({VeroPageStatus status, String message, VeroTransactionResult? transaction, VeroTransactionResult? lastPayment})`.
- **Mock:** `VeroPaymentsMock.all` é uma lista de `({String label, VeroPaymentType type, double amount})`, com crédito, débito, Pix e carteira de R$ 1,00 cada.
- **`VeroViewModel(IVeroPaymentService payments, INativePrinterService printer)`:**

| Método | Mensagem de carregamento | Mensagem de sucesso |
|---|---|---|
| `pay(VeroPaymentType type, double amount)` | "Processando o pagamento no app da Vero..." | "Pagamento aprovado." |
| `refundLastPayment()`, que usa o `lastPayment.nsu` | "Estornando o último pagamento..." | "Pagamento estornado." |
| `printNfc(String pdfBase64)` | "Imprimindo a NFC-e..." | "NFC-e impressa." |
| `printTxt(String text)` | "Imprimindo o texto..." | "Texto impresso." |
| `testPrint()` | "Imprimindo o teste..." | "Impressão de teste concluída." |

  - Uma falha mostra `failure.message`.
  - Um pagamento aprovado preenche `transaction` e `lastPayment`, e o estorno aprovado limpa o `lastPayment`.

- **Rótulos dos botões na tela:**
  - os do `VeroPaymentsMock`;
  - "Estornar o último pagamento", desabilitado sem `lastPayment`;
  - "Imprimir a NFC-e de teste" (`NfceMock.pdf`) e "Imprimir a NFC-e de homologação" (`NfceHomologacaoMock.pdf`);
  - "Imprimir o texto de teste" (`NfceMock.text`) e "Impressão de teste".

- [ ] **Passo 1: escrever os testes que falham.**
  - **View model:**
    - o pagamento aprovado chama o método certo do serviço e mostra "Pagamento aprovado.";
    - uma falha mostra a mensagem;
    - o estorno usa o NSU do último pagamento e mostra "Pagamento estornado.";
    - as três impressões chamam o driver com `NfceMock.pdf`, `NfceMock.text` e `testPrint`.
  - **Tela:** com `tester.view.physicalSize = Size(800, 2400)`, como no teste do PagBank, tocar cada botão chama o serviço com o mock certo.
  - **`widget_test.dart`:** um teste `flavor vero: abre direto na tela da Vero`, com `pumpApp(tester, 'vero', const VeroIntegration())` e `find.byType(VeroPage)`.
- [ ] **Passo 2: rodar e ver falhar.** Em `example`, `fvm flutter test` dá erro de compilação.
- [ ] **Passo 3: implementar** o estado, o view model, o mock, o widget, a tela e a integração, com os exports, o `main.dart`, o `vero_env.json` e o `launch.json`.
- [ ] **Passo 4: rodar e ver passar.** Em `example`, `fvm flutter test`, `fvm flutter analyze` e `fvm dart format --output=none --set-exit-if-changed lib test` devem passar sem nada a acusar.

---

### Tarefa 7: builds e varredura dos APKs

**Arquivos:** nenhum no repositório. O script de varredura fica no scratchpad.

- [ ] **Passo 1: APK do flavor `vero`.** Em `example`: `fvm flutter build apk --debug --flavor vero --dart-define-from-file=../assets/env/vero_env.json`. Esperado: `Built build\app\outputs\flutter-apk\app-vero-debug.apk`. Conferir no manifest mesclado (`build/app/intermediates/merged_manifest/veroDebug/...`) que as permissões e as `<queries>` do AAR estão lá.
- [ ] **Passo 2: APKs de release dos outros flavors.** Para cada `f` em `stone`, `cielo` e `pagbank`: `fvm flutter build apk --release --flavor f --dart-define-from-file=../assets/env/f_env.json`.
- [ ] **Passo 3: varredura.** Um script Python (`python -I`) abre cada APK como zip e procura, sem diferenciar maiúsculas, em ASCII e em UTF-16LE, em todas as entradas: `posmp_api`, `veromobile` e `execucao`.
  - Esperado: nenhuma ocorrência em `app-stone-release.apk`, `app-cielo-release.apk` e `app-pagbank-release.apk`.
  - O `app-vero-debug.apk` tem `posmp_api`, o que confirma que a varredura funciona.
- [ ] **Passo 4: suítes finais.** `core` e `example` (`test`, `analyze`, `format`), mais os testes Kotlin dos quatro flavors, todos verdes. Registrar os números de testes para o relatório.
