# Sipag no core: plano de implementação

> **Para quem for executar:** use o `superpowers:subagent-driven-development` (recomendado) ou o `superpowers:executing-plans` para seguir este plano tarefa por tarefa. Os passos usam caixas (`- [ ]`) para acompanhar o andamento.

**Objetivo:** pagamentos (crédito à vista, débito, Pix, estornos) e a última operação da Sipag neste core, nos terminais DX8000, X990 e P2, com os nomes do `centralizer` e do plugin `flutter_sipag_sdk`, e um flavor `sipag` com tela de teste.

**Arquitetura:**
- **`core`:** ganha o `ISiPagPaymentService`, no canal `sipag_sdk`, sem impressora.
- **Android:**
  - o flavor `sipag` leva os dois AARs e o driver genérico de impressão;
  - o handler escolhe o terminal pelo modelo;
  - cada terminal fica atrás de uma interface pequena (`SipagTerminal`), e cada SDK atrás de outra (`DxSdk`, `P2Sdk`), para os testes rodarem sem o terminal;
  - os parsers repetem as chaves e os códigos do plugin;
  - a marca de operação pendente fica no SharedPreferences.

**Tecnologias:**
- Flutter 3.35.2 (fvm), Dart com `fpdart`/`Either`;
- Kotlin, Robolectric 4.16, `org.json`;
- AGP com Kotlin DSL;
- `apix990-release.aar` (lib 1.2.0) e `pos7api-release-v1090004.aar`.

**Especificação:** `docs/superpowers/specs/2026-10-30-sipag-migracao-design.md`. Quem for executar lê a especificação e este plano. As tabelas de contrato, de resultado e de erros estão lá e valem literalmente.

## Restrições globais

- **Canal e métodos do plugin:**
  - canal `sipag_sdk`;
  - `get_last_operation`;
  - `pay_credit`, `pay_debit` e `pay_pix`, com `{amount: String}`;
  - `refund` e `refund_pix`, com `{nsu: String}`.
- **`amount`:** `amount.toStringAsFixed(2).replaceAll('.', ',')` no Dart. O P2 manda ao SDK o mesmo texto sem a vírgula.
- **Códigos, mensagens e chaves do resultado:** exatamente como nas tabelas da especificação, inclusive "paramêtros".
- **Nomes do Dart:** `SiPagTransactionResult`, `SiPagFailure`, `ISiPagPaymentService` e `SiPagPaymentService`, com o "P" maiúsculo do `centralizer`.
- **Marca de operação pendente:** SharedPreferences `sipag_sdk`, chave `has_error_on_last_operation`.
- **Arquivo do DX:** `Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS)/operation_result.json`.
- **Ação do app Sicoob:** `br.com.sicoob.skin.acquirerposskin.ACAO_ESPECIFICA`.
- **Escolha do terminal:** `Build.MODEL.contains("P2")` usa o P2; qualquer outro usa o DX.
- **Dependências, só no flavor `sipag`:**
  - `libs/apix990-release.aar`;
  - `libs/pos7api-release-v1090004.aar`;
  - `libs/posmpapi_1.01.10-partnersRelease.aar`;
  - `com.sunmi:printerlibrary:1.0.23`;
  - `org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1`.
- **Origem dos AARs:** `C:/Users/user/AppData/Local/Pub/Cache/git/flutter-sipag-sdk_192.168.50.59_fontes-6d3b2bed341dda1d6bab78d151811a8669bd9542/android/`, em `sipag-dx-sdk/` e `sipag-p2-sdk/`.
- **Robolectric:** os testes de `src/testSipag/` usam as APIs do `robolectric.properties` (25 e 30), sem `@Config(sdk = ...)`. O `org.json` só funciona com o Robolectric, então os testes dos parsers também rodam com ele.
- **Comandos:**
  - Flutter: `../.fvm/flutter_sdk/bin/flutter`, a partir de `core` ou `example`;
  - Gradle: `JAVA_HOME="C:/Program Files/Eclipse Adoptium/jdk-17.0.20.101-hotspot" ./gradlew`, em `example/android`.
- **Estilo:** comentários e textos em português, com no máximo 110 colunas. Cada classe nova abre com um KDoc/dartdoc que cita o plugin de onde vem, como a Vero e a Rede.
- **Sem commits:** a branch é a `main`, que estava limpa em `bb31cb3`. Cada tarefa termina com a suíte verde, não com um commit.

## Pontos de atenção na revisão

1. **Dois callbacks para a mesma operação.** Os pollers do apix990 não param, e o `AsyncTask` do pos7api lê um estado estático. A segunda resposta é ignorada, e o Dart recebe uma só. Teste na Tarefa 6.
2. **Callback numa thread de IO** (o apix990 chama assim). A resposta ao Flutter sai na main thread. Testes nas Tarefas 5 e 6.
3. **`get_last_operation` com uma operação em andamento neste processo.** A marca é dessa operação, não de uma queda, então a resposta é `LAST_OPERATION_NOT_FOUND` e a marca continua ligada. A especificação não cobria este caso; ele segue a intenção dela. Teste na Tarefa 6.
4. **JSON do DX com `null` explícito.** O `optString` do Android devolve "null" para `JSONObject.NULL`; o campo tem que virar "". Teste na Tarefa 4.
5. **Valor em formato inesperado** ("1,00" no lugar de centavos). Vira 0, sem derrubar o app. Teste na Tarefa 4.

---

### Tarefa 1: modelos da Sipag no `core`

**Arquivos:**
- Criar:
  - `core/lib/domain/models/sipag_transaction_result.dart`;
  - `core/lib/domain/failures/sipag_failure.dart`;
  - `core/test/domain/models/sipag_transaction_result_test.dart`;
  - `core/test/domain/failures/sipag_failure_test.dart`.
- Modificar: `core/lib/domain/models/models.dart` e `core/lib/domain/failures/failures.dart`, para exportar os novos.

**Interfaces:**
- Produz:
  - `class SiPagTransactionResult extends Equatable`, com `final String flag, nsu, authorization, cardNumber, merchantReceipt, customerReceipt, installments`, `final double amount`, construtor `const` com todos `required` e `factory SiPagTransactionResult.fromMap(Map<dynamic, dynamic> map)`;
  - `class SiPagFailure extends Equatable`, com `final String code, message` e as fábricas:
    - `nsuNotInformed()`: `nsu.not.informed` / "O campo: nsu não foi informado! Corrija-o e tente novamente!";
    - `invalidRefundType()`: `type.is.invalid` / "Função de estorno não encontrada!";
    - `notImplemented(String method)`: `$method.not.implemented` / "$method() has not been implemented.";
    - `unknown()`: `unknown.error` / "Erro desconhecido, tente novamente".

- [ ] **Passo 1: testes.**

```dart
test('lê as chaves do plugin flutter_sipag_sdk', () {
  final result = SiPagTransactionResult.fromMap({
    'MESSAGE': 'Operação efetuada com sucesso!', 'FLAG': 'VISA', 'NSU_SITEF': '123',
    'CARD_NUMBER': '************1234', 'AUTHORIZATION': 'A1', 'COMPANY_RECEIPT': 'VIA LOJA',
    'CLIENT_RECEIPT': 'VIA CLIENTE', 'INSTALLMENTS': 1, 'AMOUNT': 10.5,
  });
  expect(result, const SiPagTransactionResult(flag: 'VISA', nsu: '123', authorization: 'A1',
      cardNumber: '************1234', merchantReceipt: 'VIA LOJA', customerReceipt: 'VIA CLIENTE',
      installments: '1', amount: 10.5));
});
test('AMOUNT inteiro ou em texto vira double', () {
  expect(SiPagTransactionResult.fromMap({'AMOUNT': 10}).amount, 10.0);
  expect(SiPagTransactionResult.fromMap({'AMOUNT': '2.5'}).amount, 2.5);
});
test('campo ausente ou nulo vira texto vazio ou 0', () {
  final result = SiPagTransactionResult.fromMap({'FLAG': null, 'AMOUNT': null});
  expect([result.flag, result.nsu, result.customerReceipt, result.installments], ['', '', '', '']);
  expect(result.amount, 0.0);
});
```

O `sipag_failure_test.dart` confere o `code` e a `message` de cada fábrica com os textos acima.

- [ ] **Passo 2: rodar.** `cd core && ../.fvm/flutter_sdk/bin/flutter test test/domain`
Esperado: falha de compilação (`SiPagTransactionResult` não existe).

- [ ] **Passo 3: implementar** os dois arquivos, no molde do `RedeTransactionResult` e do `RedeFailure`. O dartdoc diz que os nomes são os do plugin, para o `AcquirerTransactionResult.fromSiPagTransaction` lê-los sem mudança. `INSTALLMENTS` vira texto com `toString()`, e o `AMOUNT` aceita `num` ou texto (`double.tryParse`), senão 0.

- [ ] **Passo 4: rodar.** `cd core && ../.fvm/flutter_sdk/bin/flutter test test/domain && ../.fvm/flutter_sdk/bin/flutter analyze`
Esperado: tudo verde, nenhum problema.

### Tarefa 2: serviço da Sipag no `core` (`ISiPagPaymentService`)

**Arquivos:**
- Criar:
  - `core/lib/data/interfaces/sipag_payment_interface.dart`;
  - `core/lib/infrastructure/sipag_payment/sipag_payment_service.dart`;
  - `core/test/infrastructure/sipag_payment/sipag_payment_service_test.dart`.
- Modificar: `core/lib/data/interfaces/interfaces.dart` e `core/lib/infrastructure/infrastructure.dart`.

**Interfaces:**
- Consome: a Tarefa 1.
- Produz:
  - `abstract class ISiPagPaymentService`, com `getLastOperation()`, `creditCardPayment(double amount)`, `debitCardPayment(double amount)`, `pixPayment(double amount)` e `refundPayment(int type, String nsu)`, todos `Future<Either<SiPagFailure, SiPagTransactionResult>>`;
  - `class SiPagPaymentService implements ISiPagPaymentService`, com `const SiPagPaymentService(MethodChannel channel)`.

- [ ] **Passo 1: testes**, com o canal simulado como no `rede_payment_service_test.dart` e uma resposta aprovada com as oito chaves:
  - os pagamentos de 0,29, 4,35, 33,3 e 1000 chamam `pay_credit` `{amount: '0,29'}`, `pay_debit` `{amount: '4,35'}`, `pay_pix` `{amount: '33,30'}` e `pay_credit` `{amount: '1000,00'}`;
  - `getLastOperation()` chama `get_last_operation` sem argumentos;
  - `refundPayment(1, '9')` chama `refund_pix` `{nsu: '9'}`, e `refundPayment` com 0 e -1 chama `refund` `{nsu: '9'}`;
  - `refundPayment` com 2, 3 e 4 devolve `SiPagFailure.invalidRefundType()` sem chamada;
  - `refundPayment(4, '  ')` devolve `SiPagFailure.nsuNotInformed()` sem chamada (o NSU vem antes do type);
  - uma resposta aprovada vira `right(SiPagTransactionResult.fromMap(approved))`;
  - `PlatformException(code: 'LICENCA_INVALIDA', message: 'Licença expirada.')` vira `left(SiPagFailure(code: 'LICENCA_INVALIDA', message: 'Licença expirada.'))`;
  - sem `message`, vale o `stacktrace`; sem os dois, o `toString()` da exceção;
  - canal sem handler devolve `SiPagFailure.notImplemented('pay_credit')`;
  - resposta `null` devolve `SiPagFailure.unknown()`.

- [ ] **Passo 2: rodar.** `cd core && ../.fvm/flutter_sdk/bin/flutter test test/infrastructure/sipag_payment`
Esperado: falha de compilação.

- [ ] **Passo 3: implementar** no molde do `VeroPaymentService`, sem impressora. O dartdoc da classe registra duas coisas:
  - na X990, o `centralizer` imprimia só com `model.contains("x990")`, que nunca casava, então nada é impresso aqui;
  - o `LAST_OPERATION_NOT_FOUND` vem do Android.

- [ ] **Passo 4: rodar.** `cd core && ../.fvm/flutter_sdk/bin/flutter test && ../.fvm/flutter_sdk/bin/flutter analyze && ../.fvm/flutter_sdk/bin/dart format --set-exit-if-changed lib test`
Esperado: tudo verde.

### Tarefa 3: flavor `sipag`, AARs, manifest e regras do driver

**Arquivos:**
- Criar:
  - `example/android/app/libs/apix990-release.aar` e `example/android/app/libs/pos7api-release-v1090004.aar`, copiados da origem das restrições globais;
  - `example/android/app/src/sipag/AndroidManifest.xml`;
  - `example/android/app/src/genericPrinter/proguard-rules.pro`, com o conteúdo de `src/vero/proguard-rules.pro`;
  - `example/android/app/src/sipag/kotlin/com/example/example/SipagIntegration.kt`, por enquanto com o `createAcquirerIntegration()` e o `configure` vazio;
  - `example/android/app/src/testSipag/kotlin/com/example/example/sipag/SipagDependenciesTest.kt`.
- Modificar:
  - `example/android/app/build.gradle.kts`;
  - `example/android/app/src/main/kotlin/com/example/example/AcquirerIntegration.kt` (o KDoc passa a citar "stone, cielo, pagbank, vero, rede ou sipag").
- Apagar: `example/android/app/src/vero/proguard-rules.pro`.

**Interfaces:**
- Produz:
  - o flavor `sipag` compilando, com `src/genericPrinter/kotlin` no source set;
  - `createAcquirerIntegration()` em `src/sipag`.

- [ ] **Passo 1: teste de dependências.** `SipagDependenciesTest`, em JUnit puro:

```kotlin
@Test fun `o flavor leva as classes que os AARs da Sipag e o driver usam sem trazer`() {
    listOf(
        "printx990.br.apix990.internal.TransactionInfo",
        "ger7.com.br.pos7api.POS7API",
        "kotlinx.coroutines.Dispatchers",
        "androidx.core.content.ContextCompat",
        "androidx.core.app.ActivityCompat",
        "com.sunmi.peripheral.printer.InnerPrinterManager",
    ).forEach { Class.forName(it, false, javaClass.classLoader) }
}
```

- [ ] **Passo 2: flavor só com os AARs.**
  - Criar `create("sipag") { dimension = "acquirer" }`.
  - No `sourceSets`, `getByName("sipag") { java.srcDir("src/genericPrinter/kotlin") }`.
  - Copiar os AARs e declarar com `"sipagImplementation"(files(...))` só os dois da Sipag e o posmpapi.
  - Criar o `SipagIntegration.kt` mínimo.
  - Rodar `./gradlew :app:testSipagDebugUnitTest --console=plain`.
  - Esperado: o `SipagDependenciesTest` falha com `ClassNotFoundException`, ao menos para a classe da Sunmi.
  - Se a mesclagem do manifest falhar antes, por causa do `label`, seguir para o Passo 4 e voltar.

- [ ] **Passo 3: declarar as dependências.** `com.sunmi:printerlibrary:1.0.23` e `kotlinx-coroutines-android:1.8.1` com `"sipagImplementation"`. O comentário explica:
  - o apix990 roda o polling em coroutines sem trazê-las;
  - no PDV, elas vinham do próprio plugin;
  - a Sunmi é a mesma da Vero, pelo P2.

  O `androidx.core` só é declarado se o teste acusar a falta dele.

- [ ] **Passo 4: manifest.** `src/sipag/AndroidManifest.xml`:
  - `<application android:label="example" tools:replace="android:label" />`. O comentário explica que o apix990 declara `label` no dele;
  - `<queries>` com:
    - `<package>` `woyou.aidlservice.jiuiv5`, `com.vfi.smartpos.deviceservice` e `com.usdk.apiservice`;
    - `<intent><action android:name="br.com.sicoob.skin.acquirerposskin.ACAO_ESPECIFICA" /></intent>`.

  Cada um leva um comentário, no estilo do manifest da Vero.

  Rodar `./gradlew :app:processSipagDebugMainManifest --console=plain`. Esperado: BUILD SUCCESSFUL. Sem o `tools:replace`, a tarefa falha com "Attribute application@label ... is also present at".

- [ ] **Passo 5: regras do driver comuns.**
  - O conteúdo de `src/vero/proguard-rules.pro` vai para `src/genericPrinter/proguard-rules.pro`, com o comentário dizendo que vale para os flavors com o driver.
  - Os flavors `vero` e `sipag` passam a usar `proguardFile("src/genericPrinter/proguard-rules.pro")`.
  - O arquivo da Vero é apagado.

- [ ] **Passo 6: rodar.** `./gradlew :app:testSipagDebugUnitTest :app:testVeroDebugUnitTest :app:testRedeDebugUnitTest :app:testStoneDebugUnitTest :app:testCieloDebugUnitTest :app:testPagbankDebugUnitTest --console=plain`
Esperado: BUILD SUCCESSFUL. Conferir no `app/build/intermediates/merged_manifests/sipagDebug/.../AndroidManifest.xml`:
  - os quatro `<queries>`;
  - `ger7.com.br.pos7api.Intercom`;
  - `READ_EXTERNAL_STORAGE`;
  - as `titan.extperm.*`;
  - a `uses-feature` `android.hardware.nfc`.

### Tarefa 4: respostas e parsers do Android

**Arquivos:**
- Criar, em `example/android/app/src/sipag/kotlin/com/example/example/sipag/`:
  - `SipagResponses.kt`;
  - `DxResultParser.kt`;
  - `P2ResultParser.kt`.
- Testes, em `src/testSipag/kotlin/com/example/example/sipag/`: `DxResultParserTest.kt` e `P2ResultParserTest.kt`.

**Interfaces:**
- Produz:

```kotlin
internal sealed interface SipagOutcome {
    data class Approved(val response: Map<String, Any?>) : SipagOutcome
    data class Failed(val code: String, val message: String, val details: Map<String, Any?>? = null) : SipagOutcome
}

/** Mapa do `TransactionResponse.responseToJson` do plugin, com as nove chaves; texto nulo vira "". */
internal fun transactionResponse(
    message: String, flag: String?, nsu: String?, cardNumber: String?, authorization: String?,
    companyReceipt: String?, clientReceipt: String?, installments: Int, amount: Double,
): Map<String, Any?>

/** Centavos em texto para reais; texto que não é um inteiro vira 0 (no plugin, `parseLong` derrubava o app). */
internal fun centsToReais(cents: String?): Double

internal object DxResultParser { fun parse(json: String): SipagOutcome } // lança JSONException se ilegível
internal object P2ResultParser { fun parse(out: ParamOut): SipagOutcome }
```

- O `SipagResponses.kt` também guarda as constantes dos códigos e das mensagens da especificação, com os nomes do `strings.xml` do plugin onde ele os tem:
  - `SUCCESS_PAYMENT`, `PAYMENT_FAILED`, `INVALID_OPERATION_CODE`, `INTERNAL_ERROR_MESSAGE`;
  - `ERRO_NA_OPERACAO`, `ERRO_INTERNO`, `ERRO_NO_TERMINAL`, `LICENCA_INVALIDA`;
  - `LAST_OPERATION_NOT_FOUND`, `FILE_DOES_NOT_EXIST`, `READ_OPERATION_FILE_FAILED`;
  - as mensagens novas: permissão, app ausente, operação substituída e licença inválida.

- [ ] **Passo 1: testes do DX** (`@RunWith(RobolectricTestRunner::class)`, JSON montado com `JSONObject`):
  - **cartão aprovado** `{label: "VISA", authorizationCode: "A1", installments: 1, product: "CREDITO", maskedPan: "****1234", transactionID: "T1", amount: "100", displayMessage: "APROVADA", mError: [], receiptList: [{lines: ["LOJA\u0000", "L2"]}, {lines: ["CLIENTE"]}]}` vira `Approved`:
    - `FLAG` "VISA", `NSU_SITEF` "T1", `CARD_NUMBER` "****1234", `AUTHORIZATION` "A1";
    - `COMPANY_RECEIPT` "LOJA\nL2\n", `CLIENT_RECEIPT` "CLIENTE\n";
    - `INSTALLMENTS` 1, `AMOUNT` 1.0;
    - `MESSAGE` "Operação efetuada com sucesso!";
  - **Pix:** `product` "PIX" e `pixID` "P9" dão `NSU_SITEF` "P9". Sem `maskedPan`, o `CARD_NUMBER` é "PIX";
  - **estorno:** sem `product`, dá `CARD_NUMBER` "Refund" e `NSU_SITEF` = `transactionID`;
  - **`mError`:** `[{mErrorCode: "E1", mErrorDescription: "Cartão recusado", mPOS7ErrorCode: 51}]` vira `Failed("E1", "Cartão recusado 51")`, com `details` em que o `MESSAGE` é a mesma mensagem. Com `mErrorCode` "", o código é `ERRO_NA_OPERACAO`;
  - **sem comprovante** (`receiptList: []`): com `displayMessage` "NEGADA", vira `Failed("INVALID_OPERATION", "NEGADA")`; sem ela, a mensagem é "Erro interno da adquirente!";
  - **um comprovante só** dá `CLIENT_RECEIPT` "";
  - **`null` explícito e chave ausente:** `label: JSONObject.NULL` dá `FLAG` "" (não "null"), e sem `installments` e sem `amount` dá 0 e 0.0;
  - **`amount` "1,00"** dá `AMOUNT` 0.0;
  - **`parse("{")`** lança `JSONException`.

- [ ] **Passo 2: testes do P2** (`ParamOut()` com os setters do AAR; base aprovada: status 0, config 2, license 1, response 0):
  - **cartão** (`resProduct` 1, `resLabel` "MASTER", `resRrn` "R1", `resAuthorization` "A1", `pan` "5555****", `resInstallments` 1, `resAmount` "1000", `resPrint` "LOJA VIA DO CLIENTE CLIENTE"): `FLAG` "MASTER", `NSU_SITEF` "R1", `AUTHORIZATION` "A1", `CARD_NUMBER` "5555****", `COMPANY_RECEIPT` "LOJA ", `CLIENT_RECEIPT` " CLIENTE", `AMOUNT` 10.0;
  - **Pix** (`resProduct` 8, `resPixId` "X1"): `FLAG` "Pix", `NSU_SITEF` "X1", `AUTHORIZATION` "X1", `CARD_NUMBER` "";
  - **cartão com `resLabel` e `pan` nulos:** "Pix" nos dois;
  - **`resPrint` sem "VIA DO CLIENTE" ou nulo:** os dois comprovantes "";
  - **`resAmount` nulo:** 0.0;
  - **status 1:** `Failed("ERRO_INTERNO", "Terminal não configurado.")`;
  - **config 1:** `Failed("ERRO_NO_TERMINAL", "Terminal configurado, mas sem paramêtros.")`; config 0 e 5: "Não configurado.";
  - **license** 0, 96, 97, 98 e 99: as mensagens do `TerminalStatus`; license 2: "Licença inválida.";
  - **response 5 com `resDisplay` "NEGADA":** `Failed("ERRO_NA_OPERACAO", "NEGADA", details)`; sem `resDisplay`, "Falha ao efetuar a operação!".

- [ ] **Passo 3: rodar.** `./gradlew :app:testSipagDebugUnitTest --console=plain`
Esperado: falha de compilação.

- [ ] **Passo 4: implementar.** Portar do `DxParseOperation`, do `TransactionResponse`, do `TerminalStatus` e do callback do `PaymentServiceP2Device` do plugin (pub cache, `android/src/main/kotlin/br/com/arpa/flutter_sipag_sdk/`), com estas decisões:
  - **No DX:** os campos são lidos por um ajudante que devolve "" quando a chave falta ou é `isNull`; os inteiros, por `optInt`. As listas, por `optJSONArray`.
  - **No P2:** a separação é `split("VIA DO CLIENTE")`, com `getOrElse(1) { "" }`.
  - **O sucesso no DX:** depende de `receiptList` ter o primeiro elemento não nulo, como no plugin.

- [ ] **Passo 5: rodar.** `./gradlew :app:testSipagDebugUnitTest --console=plain`
Esperado: BUILD SUCCESSFUL.

### Tarefa 5: os terminais DX e P2

**Arquivos:**
- Criar, em `src/sipag/kotlin/com/example/example/sipag/`:
  - `SipagTerminal.kt`;
  - `DxTerminal.kt`;
  - `P2Terminal.kt`.
- Testes, em `src/testSipag/kotlin/com/example/example/sipag/`:
  - `DxTerminalTest.kt`;
  - `P2TerminalTest.kt`;
  - `SipagTestDoubles.kt`, com `FakeDxSdk`, `FakeP2Sdk`, `approvedDxJson()` e `approvedParamOut()`.

**Interfaces:**
- Consome: a Tarefa 4.
- Produz:

```kotlin
internal typealias SipagReply = (SipagOutcome) -> Unit

internal interface SipagTerminal {
    fun creditPayment(amount: String, reply: SipagReply)
    fun debitPayment(amount: String, reply: SipagReply)
    fun pixPayment(amount: String, reply: SipagReply)
    fun refund(nsu: String, reply: SipagReply)
    fun pixRefund(nsu: String, reply: SipagReply)
}

internal interface DxSdk {
    fun isSicoobInstalled(context: Context): Boolean // TransactionInfo().getSipag(context)
    fun start(activity: Activity, data: TransactionData, onResult: (String) -> Unit) // initTransaction
}
internal object Apix990Sdk : DxSdk
internal class DxTerminal(private val activity: Activity, private val sdk: DxSdk = Apix990Sdk) : SipagTerminal

internal interface P2Sdk {
    fun process(context: Context, params: ParamIn, onResult: (ParamOut) -> Unit) // POS7API.processTransaction
}
internal object Pos7ApiSdk : P2Sdk
internal class P2Terminal(
    private val context: Context,
    private val sdk: P2Sdk = Pos7ApiSdk,
    private val now: () -> Long = System::currentTimeMillis,
) : SipagTerminal
```

- **`DxTerminal`**, nesta ordem:
  1. Sem `READ_EXTERNAL_STORAGE` concedida, chama `ActivityCompat.requestPermissions(activity, arrayOf(READ_EXTERNAL_STORAGE), 1001)` e responde `Failed(ERRO_NA_OPERACAO, "Permita o acesso ao armazenamento e tente novamente.")`.
  2. Com `!sdk.isSicoobInstalled`, responde `Failed(ERRO_NA_OPERACAO, "Não localizamos aplicativo de pagamento neste terminal.")`.
  3. Senão, chama `sdk.start` com o `TransactionData` da tabela da especificação. O callback passa pelo `DxResultParser`; uma `JSONException` vira `Failed(ERRO_NA_OPERACAO, "Falha ao efetuar a operação!")`.
  4. Uma exceção do `start` vira a mesma falha.
- **`P2Terminal`:**
  - monta o `ParamIn` da tabela da especificação, com `trsId` igual a `SimpleDateFormat("MMddHHmmss", Locale.getDefault()).format(Date(now()))`;
  - o callback passa pelo `P2ResultParser`;
  - uma exceção do `process` vira `Failed(ERRO_NA_OPERACAO, "Falha ao efetuar a operação!")`.
  - Recebe o `applicationContext`, como o plugin.

- [ ] **Passo 1: testes do DX com o SDK falso** (Robolectric, activity de `Robolectric.buildActivity(Activity::class.java).setup()`, permissão concedida com `shadowOf(application).grantPermissions` nos casos felizes):
  - **os cinco pedidos:** o `FakeDxSdk` recebe o `TransactionData` da tabela. Conferir `product`, `amount`, `typeTransaction`, `creditType?.type` ("AVISTA") e `creditType?.installments` (0), `pixId`, `pixReprinter` false, `packageName` = `activity.packageName` e `receipt` true;
  - **sem permissão:** responde a falha de permissão, o SDK não é chamado, e `shadowOf(activity).lastRequestedPermission.requestedPermissions` contém `READ_EXTERNAL_STORAGE`;
  - **sem o app Sicoob:** responde a falha de app ausente, e o SDK não é chamado;
  - **erros do SDK:** um `start` que lança dá "Falha ao efetuar a operação!", e um JSON ilegível no callback também;
  - **resultado:** um JSON aprovado no callback dá o `Approved` do parser.

- [ ] **Passo 2: testes do DX com o AAR de verdade** (`Apix990Sdk`, com a permissão concedida, porque o AAR também a confere):
  - **`isSicoobInstalled`:** é falso de início. Fica verdadeiro depois de `shadowOf(packageManager).addResolveInfoForIntent(Intent(ACAO_ESPECIFICA), resolveInfo)`;
  - **o Intent:** um crédito de "1,00" abre um Intent (`shadowOf(activity).nextStartedActivity`) com:
    - a ação `ACAO_ESPECIFICA`;
    - `EXTRA_AMOUNT` "1,00", `EXTRA_PRODUCT` "CREDITO" e `TRANSACTIONTYPE` "TRANSACTION";
    - `PACKAGENAME` = `activity.packageName`;
    - `RECEIPT` true, `EXTRA_CREDIT_TYPE` "AVISTA", `EXTRA_CREDIT_INSTALLMENT` 0 e `REPRINTERPIX` false;
  - **a leitura do arquivo:** depois do `start`, gravar um JSON no arquivo que o AAR vigia. Ler o caminho por reflexão no campo estático `file` do `AbstractionInfo`, porque o caminho é fixado quando a classe carrega; criar a pasta antes de gravar.
    - O `onResult` chega em até 5 s com o mesmo texto.
    - O callback chega fora da main thread (`Looper.myLooper() != Looper.getMainLooper()`).

- [ ] **Passo 3: testes do P2.**
  - **Com o SDK falso:**
    - os cinco pedidos montam o `ParamIn` da tabela: `trsType`, `trsProduct`, `trsAmount` "100" para "1,00", `trsInstallments` 1 no crédito e no débito e 0 no Pix, e `trsRefundId` ou `trsRefundPixId`;
    - com `now` em 30/10/2026 14:05:09 (`Calendar`), o `trsId` é "1030140509";
    - um `process` que lança dá a falha;
    - um `ParamOut` aprovado dá o `Approved`.
  - **Com o AAR de verdade:** o `Pos7ApiSdk.process` abre o `ger7.com.br.pos7api.Intercom` com `FLAG_ACTIVITY_NEW_TASK` e o extra `ParamIn` (`shadowOf(application).nextStartedActivity`). O `AsyncTask` do AAR fica esperando em segundo plano e não afeta o teste.

- [ ] **Passo 4: rodar.** `./gradlew :app:testSipagDebugUnitTest --console=plain`
Esperado: falha de compilação.

- [ ] **Passo 5: implementar** os três arquivos. O KDoc do `DxTerminal` explica os dois travamentos do AAR que as checagens evitam. O do `Apix990Sdk` diz que o callback chega numa thread de IO.

- [ ] **Passo 6: rodar.** `./gradlew :app:testSipagDebugUnitTest --console=plain`
Esperado: BUILD SUCCESSFUL.

### Tarefa 6: handler, marca de operação pendente e integração

**Arquivos:**
- Criar:
  - `src/sipag/kotlin/com/example/example/sipag/PendingOperationStore.kt`;
  - `src/sipag/kotlin/com/example/example/sipag/SipagPaymentHandler.kt`.
- Modificar: `src/sipag/kotlin/com/example/example/SipagIntegration.kt`.
- Testes:
  - `src/testSipag/kotlin/com/example/example/sipag/SipagPaymentHandlerTest.kt`, com um `FakeSipagTerminal` em `SipagTestDoubles.kt`, que guarda o método, o argumento e o `SipagReply` de cada pedido;
  - `src/testSipag/kotlin/com/example/example/SipagIntegrationTest.kt`, com o `FakeMessenger` copiado do `RedeIntegrationTest`.

**Interfaces:**
- Consome: as Tarefas 4 e 5.
- Produz:

```kotlin
internal class PendingOperationStore(context: Context) {
    val isPending: Boolean
    fun markPending()
    fun clear()
}

internal class SipagPaymentHandler(
    private val terminal: SipagTerminal,
    private val store: PendingOperationStore,
    private val lastOperationFile: () -> File,
) {
    fun handle(call: MethodCall, result: MethodChannel.Result)
}

internal fun isP2(model: String): Boolean = model.contains("P2")
internal fun operationResultFile(): File // Documents/operation_result.json

internal class SipagIntegration(
    private val model: String = Build.MODEL,
    private val dxSdk: DxSdk = Apix990Sdk,
    private val p2Sdk: P2Sdk = Pos7ApiSdk,
    private val lastOperationFile: () -> File = ::operationResultFile,
) : AcquirerIntegration
```

- **Handler, nas operações:**
  - confere o argumento: `amount`/"amount is null" ou `nsu`/"nsu is null";
  - responde a operação pendente anterior com `ERRO_NA_OPERACAO`/"Operação substituída por uma nova.";
  - guarda a nova com um id crescente, liga a marca e chama o terminal;
  - o `SipagReply` só responde se o id ainda for o pendente. Ele limpa a pendência e a marca e responde `success(response)` ou `error(code, message, details)`;
  - quando a chamada não vem da main thread, a resposta é postada nela com `Handler(Looper.getMainLooper())`.
- **Handler, no `get_last_operation`, nesta ordem:**
  1. Com operação pendente neste handler, ou sem a marca, responde `LAST_OPERATION_NOT_FOUND`.
  2. Senão, desliga a marca.
  3. Arquivo ausente responde `FILE_DOES_NOT_EXIST`.
  4. Erro de leitura ou `JSONException` responde `READ_OPERATION_FILE_FAILED`.
  5. Senão, responde o resultado do `DxResultParser`.
  - Método desconhecido responde `notImplemented()`.
- **Integração:**
  - o `configure` escolhe `P2Terminal(activity.applicationContext, p2Sdk)` se `isP2(model)`, senão `DxTerminal(activity, dxSdk)`;
  - registra `sipag_sdk` no handler e `acquirers_sdk` no `GenericPrinterHandler { PosmpPrinter(activity.applicationContext) }`, como a Vero;
  - `createAcquirerIntegration() = SipagIntegration()`.

- [ ] **Passo 1: testes do handler** (Robolectric):
  - **encaminhamento:** cada método chega ao terminal com o argumento;
  - **argumentos e método:** os ausentes respondem o erro e não chamam o terminal; método desconhecido dá `notImplemented`;
  - **respostas:** `Approved` responde `success` com o mapa, e `Failed` responde `error` com código, mensagem e `details`;
  - **resposta única:** o mesmo `SipagReply` chamado duas vezes responde uma vez só;
  - **thread:** um `SipagReply` chamado de `Thread { ... }` responde na main thread, depois de `shadowOf(getMainLooper()).idle()`;
  - **operação substituída:** um crédito, e depois um débito antes da resposta. O crédito recebe "Operação substituída por uma nova.", o reply atrasado do crédito é ignorado, e o do débito responde ao débito;
  - **a marca:** `isPending` fica verdadeiro durante a operação e falso depois da resposta, inclusive quando o terminal responde na hora;
  - **última operação:**
    - sem a marca, `LAST_OPERATION_NOT_FOUND` / "Não foi encontrado nenhuma operação no histórico!";
    - com a marca e sem arquivo, `FILE_DOES_NOT_EXIST`, e a marca desliga;
    - com o arquivo "{", `READ_OPERATION_FILE_FAILED`;
    - com o `approvedDxJson()`, `success` com o `NSU_SITEF`;
    - com uma operação pendente, `LAST_OPERATION_NOT_FOUND`, e a marca continua ligada;
  - **escolha do terminal:** `isP2` é verdadeiro para "P2-B" e "P2-A11" e falso para "DX8000" e "X990".

- [ ] **Passo 2: testes da integração:**
  - **X990:** com `FakeDxSdk` instalado e a permissão concedida, `messenger.call("sipag_sdk", "pay_credit", mapOf("amount" to "1,00"))` não responde até o `onResult`. Depois do `onResult(approvedDxJson())` e do `idle()`, a resposta é o mapa, com `AMOUNT` 1.0 e `NSU_SITEF`;
  - **P2-B:** com `FakeP2Sdk`, o `ParamOut` aprovado responde ao Dart;
  - **impressão:** o canal `acquirers_sdk` está registrado; um método desconhecido nele responde `notImplemented`.

- [ ] **Passo 3: rodar.** `./gradlew :app:testSipagDebugUnitTest --console=plain`
Esperado: falha de compilação.

- [ ] **Passo 4: implementar.** O KDoc do handler explica:
  - a pendência por id;
  - por que a operação nova responde a anterior (os pollers do AAR entregariam o mesmo resultado às duas);
  - a marca do plugin, agora no nativo.

- [ ] **Passo 5: rodar.** `./gradlew :app:testSipagDebugUnitTest :app:testVeroDebugUnitTest --console=plain`
Esperado: BUILD SUCCESSFUL.

### Tarefa 7: tela da Sipag no app de exemplo

**Arquivos:**
- Criar:
  - `example/lib/integrations/sipag_integration.dart`;
  - `example/lib/presentation/views/sipag/`: `sipag.dart`, `sipag.page.dart`, `sipag.state.dart` e `sipag.viewmodel.dart`;
  - `example/lib/presentation/mocks/sipag_payments_mock.dart`;
  - `example/lib/presentation/widgets/sipag_status_widget.dart`;
  - `assets/env/sipag_env.json` com `{"FLAVOR_TYPE": "sipag"}`;
  - `example/test/modules/sipag/fakes/fake_sipag_payment_service.dart`;
  - `example/test/modules/sipag/presentation/pages/sipag_viewmodel_test.dart` e `sipag_page_test.dart`.
- Modificar:
  - os barris `integrations.dart`, `views.dart`, `mocks.dart` e `widgets.dart`;
  - `example/lib/main.dart`;
  - `example/lib/integrations/acquirer_integration.dart` (o dartdoc passa a citar sipag);
  - `example/test/widget_test.dart`;
  - `.vscode/launch.json`.

**Interfaces:**
- Consome: as Tarefas 1 e 2, e o `INativePrinterService` do core.
- Produz:
  - `class SipagIntegration extends AcquirerIntegration`, em `/sipag`, que registra:
    - o `IPdfImageConverter`;
    - o `INativePrinterService` no canal `acquirers_sdk`;
    - o `ISiPagPaymentService` no canal `sipag_sdk`;
    - o `SipagViewModel`;
  - `enum SipagPageStatus { idle, success, loading, error }` e `enum SipagPaymentType { credit, debit, pix }`;
  - `SipagState`, com `message`, `status`, `transaction`, `lastPayment` e `lastPaymentType`;
  - `class SipagViewModel extends ViewModel<SipagState>`, com `SipagViewModel(ISiPagPaymentService, INativePrinterService)` e `pay(SipagPaymentType, double)`, `refundLastPayment()`, `getLastOperation()`, `printNfc(String)`, `printTxt(String)` e `testPrint()`.

- [ ] **Passo 1: testes do view model**, com o serviço falso e o `FakeNativePrinterService` de `test/modules/vero/fakes/`:
  - **pagamento:** cada tipo chama o método certo. O aprovado guarda `lastPayment` e `lastPaymentType`;
  - **estorno:** usa type 1 se o último foi Pix e 0 se foi cartão, com o NSU dele, e depois limpa o `lastPayment`;
  - **última operação:**
    - `Right` mostra "Última operação recuperada." com a transação;
    - `LAST_OPERATION_NOT_FOUND` vira `success` com a mensagem da falha;
    - outro código vira `error`;
  - **impressão e falhas:** as três impressões delegam ao driver, e uma falha mostra a mensagem dela.

- [ ] **Passo 2: testes da tela:**
  - os botões dos três pagamentos, "Estornar o último pagamento" (desabilitado sem `lastPayment`), "Buscar a última operação" e os quatro de impressão;
  - durante `loading`, os botões ficam desabilitados.

  No `widget_test.dart`: "flavor sipag: abre direto na tela da Sipag".

- [ ] **Passo 3: rodar.** `cd example && ../.fvm/flutter_sdk/bin/flutter test`
Esperado: falha de compilação.

- [ ] **Passo 4: implementar** no molde da Vero, com estas peças:
  - **tela:** a seção "Última venda" ganha o botão "Buscar a última operação";
  - **mock:** os três pagamentos de R$ 1,00;
  - **`main.dart`:** ganha `const _isSipag = appFlavor == 'sipag'` e `if (_isSipag) return SipagIntegration();`;
  - **`launch.json`:** ganha "Sipag Integration", com `--flavor sipag` e `../assets/env/sipag_env.json`.

- [ ] **Passo 5: rodar.** `cd example && ../.fvm/flutter_sdk/bin/flutter test && ../.fvm/flutter_sdk/bin/flutter analyze && ../.fvm/flutter_sdk/bin/dart format --set-exit-if-changed lib test`
Esperado: tudo verde.

### Tarefa 8: builds e varredura dos APKs

**Arquivos:**
- Possivelmente: criar `example/android/app/src/sipag/proguard-rules.pro` e citá-lo no flavor `sipag`, se o R8 pedir.
- Script de varredura no scratchpad da sessão (escrito com a ferramenta Write, por causa das barras invertidas).

- [ ] **Passo 1: APKs da Sipag.** Em `example`:
  - `../.fvm/flutter_sdk/bin/flutter build apk --debug --flavor sipag --dart-define-from-file=../assets/env/sipag_env.json`;
  - o mesmo com `--release`.

  Esperado: os dois APKs em `build/app/outputs/flutter-apk/`. Se o release parar no R8 com "Missing classes", criar o `src/sipag/proguard-rules.pro` com um `-dontwarn` por pacote listado e o comentário do motivo, e repetir. Apagar `app-debug.apk`/`app-release.apk` soltos antes, se houver.

- [ ] **Passo 2: manifest do release.** Pelo `merged_manifests` do `sipagRelease`, conferir:
  - `android:label="example"`;
  - os quatro `<queries>` da Tarefa 3;
  - `READ_EXTERNAL_STORAGE` e as `titan.extperm.*`;
  - a `uses-feature` de NFC;
  - o `Intercom`.

- [ ] **Passo 3: os outros flavors.** Gerar os releases de stone, cielo, pagbank, vero e rede, cada um com o env dele, e rodar a varredura. O script abre cada APK e procura em todas as entradas, sem diferenciar maiúsculas, em ASCII e em UTF-16LE.
  - **Nos cinco releases:** procurar `apix990`, `sicoob`, `pos7api`, `ger7` e `sipag`. Esperado: nenhuma ocorrência.
  - **No release da Sipag:** os cinco termos aparecem.
  - **No release do PagBank:** procurar também `posmp_api`, `veromobile` e `execucao`. Esperado: nenhuma ocorrência.

- [ ] **Passo 4: suítes completas.**
  - `cd core && ../.fvm/flutter_sdk/bin/flutter test && ../.fvm/flutter_sdk/bin/flutter analyze`;
  - o mesmo em `example`;
  - em `example/android`: `./gradlew :app:testSipagDebugUnitTest :app:testVeroDebugUnitTest :app:testRedeDebugUnitTest :app:testStoneDebugUnitTest :app:testCieloDebugUnitTest :app:testPagbankDebugUnitTest --console=plain`.

  Esperado: tudo verde.
