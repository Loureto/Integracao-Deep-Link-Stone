# Migração da Sipag do centralizer para o core

## Objetivo

Trazer para este repositório a integração da Sipag que hoje está no `centralizer` (`flutter_acquirers_sdk`). Lá, o `SiPagPayment` é uma fachada sobre o plugin `flutter_sipag_sdk` (git `flutter-sipag-sdk@192.168.50.59:fontes`, ref `6d3b2be`, versão 1.0.1).

O `centralizer` será aposentado, e o PDV Varejo vai depender direto deste core. Por isso, a troca precisa ser plug and play. Os nomes repetem os do `centralizer` e os do plugin, e os erros seguem o sufixo `*Failure` deste core:
- os métodos do serviço;
- o canal e os métodos dele;
- os argumentos;
- as chaves do resultado;
- os códigos e as mensagens de erro.

Plug and play não impede melhorar: os defeitos do plugin que travam o Dart ou derrubam o app viram divergências registradas, sempre com códigos que já existem.

## Os três terminais

O plugin atende três modelos com dois SDKs. O nativo escolhe o SDK pelo modelo: `Build.MODEL.contains("P2")` usa o do P2, e qualquer outro usa o do DX.

| Terminal | SDK | App de pagamento | Como o resultado volta |
|---|---|---|---|
| Ingenico DX8000 e Verifone X990 ("DX") | `apix990-release.aar` (`printx990.br.apix990`, lib 1.2.0) | app Sicoob, pela ação `br.com.sicoob.skin.acquirerposskin.ACAO_ESPECIFICA` com `startActivity` | o AAR apaga `Documents/operation_result.json`, abre o app e lê esse arquivo a cada 1 s até ele aparecer; o callback chega numa thread de IO |
| Sunmi P2 e P2-A11 | `pos7api-release-v1090004.aar` (`ger7.com.br.pos7api`, Ger7 1.09.0004) | app da Ger7, pela URI `pos7api://pos7`, aberta pela activity `Intercom` do próprio AAR | um `AsyncTask` espera a saída do `Intercom` e chama o callback na main thread |

O plugin traz também o `pos7api-debug-v1090004.aar` e escolhe entre os dois pelo buildType. O bytecode dos dois é idêntico: só o `BuildConfig` muda, e nenhuma classe o lê. Este core usa só o release.

A impressão da Sipag não passa por esses SDKs. No `centralizer`, ela cai no `default` do `PrinterService`, que é o driver genérico (posmpapi, canal `acquirers_sdk`). O driver cobre os três modelos: o DX8000 pelo serviço `com.usdk.apiservice`, a X990 pelo `com.vfi.smartpos.deviceservice` e o P2 pela biblioteca da Sunmi.

## O que o PDV Varejo usa hoje

Toda chamada passa pelo `AcquirerUseCase`, via `FlutterAcquirersSdk`, com `acquirer: "sipag"`.

| Função do PDV Varejo | Na Sipag, dentro do `centralizer` |
|---|---|
| `creditPayment`, `debitPayment`, `pixPayment` | `SiPagPayment.creditCardPayment`, `debitCardPayment`, `pixPayment` |
| `refund` (type 1 se o pagamento foi Pix, senão 0) | `SiPagPayment.refundPayment(type, nsu)` |
| `getLastOperation`, chamado ao abrir o dashboard | `SiPagPayment.getLastOperation()` |
| `printText`, `printNfc`, teste de impressão | `NativePrinter` (driver genérico), já migrado com a Vero |
| `printReceipt` (comprovante customizado) | `NativePrinter.printCustomReceipt`, fora do escopo como na Vero |
| carteira, configurações iniciais | não existem para a Sipag |

Do resultado, o PDV lê `nsu`, `authorization`, `flag` e `installments`. O `AcquirerTransactionResult.fromSiPagTransaction` também lê `cardNumber`, `merchantReceipt`, `customerReceipt` e `amount`. Dos erros, o PDV lê `code` e `message`. No `getLastOperation`, ignora `LAST_OPERATION_NOT_FOUND` e `function.is.invalid`, e leva qualquer outro resultado para a tela de nova venda.

## Escopo

### Dentro

- Crédito à vista, débito, Pix, estorno de cartão e estorno de Pix, nos três terminais.
- Busca da última operação depois de uma queda do app no meio da transação.
- Impressão pelo driver genérico, que já existe no core, agora também no flavor da Sipag.
- Flavor `sipag` no app de exemplo, com tela de teste.

### Fora do escopo

- **Comprovante automático na X990:** o `centralizer` só imprime quando `model.contains("x990")`, em minúsculas. O posmpapi compara `Build.MODEL.equals("X990")`, então o modelo do terminal está em maiúsculas e essa impressão nunca acontece hoje. O comportamento fica como está: o core não imprime nada depois do pagamento da Sipag. A confirmação de que o app Sicoob imprime sozinho na X990 fica para o teste no terminal.
- **Recuperar a última transação no P2:** o pos7api tem `getLastTransactionResult()`, que lê `p7api/p7_trsResult.txt`. Esse arquivo pode guardar a transação anterior à que caiu, e o PDV a registraria como venda nova. O P2 continua lendo o arquivo do DX e respondendo `FILE_DOES_NOT_EXIST`, como hoje.
- **Crédito parcelado, voucher e reimpressão:** os SDKs têm (`PARCELADOLOJA`, `PARCELADOEMISSAOR`, `VOUCHER`, `REPRINTER`), mas o plugin não os usa.
- **Comprovante customizado** (`PrinterUtils.generateReceipt`): como na Vero e na Rede.
- **A fachada `FlutterAcquirersSdk` e o empacotamento do nativo para o PDV:** vêm no ciclo de integração com o PDV Varejo.

## Decisões tomadas no brainstorming

1. **Mesmo padrão da Vero e da Rede:** serviço no core e código nativo no flavor `sipag` do app de exemplo, com os AARs em `libs/`. Depender do plugin `flutter_sipag_sdk` foi descartado: plugin Flutter entra em todos os flavors, o APK do PagBank levaria a Sipag, e os defeitos do plugin continuariam.
2. **A marca de operação pendente mora no nativo** (SharedPreferences), e não no Dart com `flutter_secure_storage`, como no plugin. Assim o core não ganha dependência nova. O custo: a marca que o `centralizer` deixou no PDV se perde na troca, o que só importa se o app cair no meio de uma transação justo no dia da atualização.
3. **Na X990, nada é impresso depois do pagamento**, o mesmo comportamento de hoje (veja "Fora do escopo"). O serviço não recebe a impressora.
4. **Um AAR do P2 só**, o release, sem a troca por buildType.
5. **Defeitos que travam o Dart ou derrubam o app viram divergências registradas**, com os códigos que o plugin já usa.

## Arquitetura

### Dart (`core`)

- **`SiPagTransactionResult`** (`domain/models/sipag_transaction_result.dart`): campos `flag`, `nsu`, `authorization`, `cardNumber`, `merchantReceipt`, `customerReceipt`, `installments` (texto) e `amount` (double), mais o `fromMap`. Os nomes são os do `SiPagTransactionResult` do plugin, para o `AcquirerTransactionResult.fromSiPagTransaction` lê-lo sem mudança.
- **`SiPagFailure`** (`domain/failures/sipag_failure.dart`): `code` e `message`, com as fábricas `nsuNotInformed()`, `invalidRefundType()`, `notImplemented(method)` e `unknown()`.
- **`ISiPagPaymentService`** (`data/interfaces/sipag_payment_interface.dart`): `getLastOperation`, `creditCardPayment`, `debitCardPayment`, `pixPayment` e `refundPayment(type, nsu)`, os nomes do `SiPagPayment`.
- **`SiPagPaymentService`** (`infrastructure/sipag_payment/sipag_payment_service.dart`): recebe o `MethodChannel('sipag_sdk')`. Não recebe impressora.
- **Exportações** nos barris do core, como na Vero.

### Android (`example/android/app`)

- **Flavor `sipag`** (dimensão `acquirer`, `minSdk` padrão 24; o apix990 pede 23 e o pos7api, 22). Só ele leva:
  - `libs/apix990-release.aar` e `libs/pos7api-release-v1090004.aar`, copiados do plugin;
  - `org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1`, a versão da Rede. O apix990 roda a leitura do arquivo em coroutines (`Dispatchers.IO`, `launch`, `delay`) sem trazê-las, a mesma armadilha da Rede;
  - o driver genérico: `src/genericPrinter/kotlin` pelo `sourceSets`, `libs/posmpapi_1.01.10-partnersRelease.aar` e `com.sunmi:printerlibrary:1.0.23`, como na Vero;
  - `androidx.core` (`ContextCompat`, `ActivityCompat`, usados pelo apix990) vem pelo embedding do Flutter; um teste confere, e a dependência só é declarada se faltar.
- **Regras do R8:**
  - as `-dontwarn` do posmpapi saem de `src/vero/proguard-rules.pro` para `src/genericPrinter/proguard-rules.pro`, que os flavors `vero` e `sipag` passam a usar;
  - o que o release da Sipag pedir a mais vai para `src/sipag/proguard-rules.pro`. O exemplo do plugin usa `-dontwarn kotlinx.parcelize.Parcelize`.
- **`src/sipag/AndroidManifest.xml`:**
  - `tools:replace="android:label"` no `<application>`: o apix990 declara `label`, `icon` e `roundIcon` no dele, e o `label` diferente quebraria a fusão do manifest. O exemplo do plugin faz o mesmo;
  - `<queries>` para os serviços de impressão que o posmpapi liga no Android 11+: `woyou.aidlservice.jiuiv5` (Sunmi), `com.vfi.smartpos.deviceservice` (X990) e `com.usdk.apiservice` (DX8000). O manifest do posmpapi não os declara;
  - `<queries>` com a ação `br.com.sicoob.skin.acquirerposskin.ACAO_ESPECIFICA`, para conferir se o app Sicoob está instalado.
- **Permissões e recursos que vêm dos AARs:** `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`, `INTERNET`, as `titan.extperm.*` e `uses-feature android.hardware.nfc` obrigatória, todas do apix990. Também vêm `requestLegacyExternalStorage="true"`, as do posmpapi (localização, `READ_PHONE_STATE`, `WRITE_SETTINGS`, Bluetooth) e a activity `ger7.com.br.pos7api.Intercom`.
- **`src/sipag/kotlin/com/example/example/`:**
  - `SipagIntegration.kt`: o `createAcquirerIntegration()`. Registra o canal `sipag_sdk` no handler de pagamento e o `acquirers_sdk` no `GenericPrinterHandler`, como a Vero. Não usa `onActivityResult`: o DX lê um arquivo, e o P2 recebe pelo `Intercom` do AAR.
  - `sipag/SipagPaymentHandler.kt`: encaminha os seis métodos, confere os argumentos, escolhe o terminal pelo modelo, guarda a resposta pendente e a marca de operação pendente, e responde uma vez só, na main thread.
  - `sipag/SipagTerminal.kt`: a interface pequena dos dois terminais (crédito, débito, Pix, estorno e estorno Pix, com um callback de resultado), como o `PosPrinter` da Vero. Assim os testes rodam sem o terminal.
  - `sipag/DxTerminal.kt` (apix990) e `sipag/P2Terminal.kt` (pos7api).
  - `sipag/DxResultParser.kt` e `sipag/P2ResultParser.kt`: portados do `DxParseOperation` e do callback do `PaymentServiceP2Device`, com as mesmas chaves, códigos e mensagens, e o `TerminalStatus` do plugin.
- **Testes** em `src/testSipag/kotlin/...`.

### App de exemplo

- **Tela `/sipag`**, no molde da Vero:
  - pagamentos de R$ 1,00 (crédito, débito e Pix);
  - "Estornar o último pagamento", com type 1 se o último foi Pix e 0 se foi cartão, como o PDV;
  - "Buscar a última operação";
  - NFC-e de teste e de homologação, texto de teste e impressão de teste, pelo `INativePrinterService`.
- **Arquivos:**
  - `SipagIntegration` (Dart), com a injeção de dependências;
  - `const _isSipag = appFlavor == 'sipag'` no `main.dart`;
  - `assets/env/sipag_env.json` com `{"FLAVOR_TYPE": "sipag"}`;
  - configuração "Sipag Integration" no `.vscode/launch.json`.

## Contrato

### Serviço e canal

Todos os métodos retornam `Future<Either<SiPagFailure, SiPagTransactionResult>>`.

| `ISiPagPaymentService` | Canal `sipag_sdk` |
|---|---|
| `getLastOperation()` | `get_last_operation` |
| `creditCardPayment(double amount)` | `pay_credit` {`amount`} |
| `debitCardPayment(double amount)` | `pay_debit` {`amount`} |
| `pixPayment(double amount)` | `pay_pix` {`amount`} |
| `refundPayment(int type, String nsu)` | type 1: `refund_pix` {`nsu`}; 0 ou negativo: `refund` {`nsu`}; acima de 1: `type.is.invalid`, sem canal |

- **`amount`:** vai como texto em reais, com duas casas e vírgula: `amount.toStringAsFixed(2).replaceAll('.', ',')`, como o plugin. R$ 10 vira `"10,00"`. Não há truncamento de centavos aqui.
- **Estorno, no Dart, sem chamar o Android, nesta ordem (a da fachada e a do roteador do `centralizer`):**
  1. NSU em branco responde `nsu.not.informed` / "O campo: nsu não foi informado! Corrija-o e tente novamente!";
  2. `type > 1` responde `type.is.invalid` / "Função de estorno não encontrada!".
- **Erros do canal, no Dart:**
  - `PlatformException` vira `SiPagFailure(code, message ?? stacktrace ?? toString())`. Os `details` não são lidos, como no `centralizer`;
  - canal inexistente (`MissingPluginException`) responde `<método do canal>.not.implemented` / "<método do canal>() has not been implemented.";
  - resposta nula responde `unknown.error` / "Erro desconhecido, tente novamente".

### O que cada operação manda ao SDK

**DX** (`TransactionData`, todos com `pixReprinter = false`, `packageName` = o pacote do app e `receipt = true`):

| Operação | `product` | `amount` | `typeTransaction` | `creditType` | `pixId` |
|---|---|---|---|---|---|
| Crédito | `CREDITO` | `"10,00"` | `TRANSACTION` | `CreditInfo("AVISTA", 0)` | nulo |
| Débito | `DEBITO` | `"10,00"` | `TRANSACTION` | nulo | nulo |
| Pix | `PIX` | `"10,00"` | `TRANSACTION` | nulo | nulo |
| Estorno | nulo | nulo | `CANCELTRANSACTION` | nulo | nulo |
| Estorno Pix | nulo | nulo | `PIXREVERSE` | nulo | o NSU |

O estorno de cartão no DX não leva o NSU: o `TransactionData` não tem esse campo, e o app Sicoob pede ao operador a transação a estornar. Igual ao plugin.

**P2** (`ParamIn`, todos com `trsId` = data e hora no formato `MMddHHmmss`):

| Operação | `trsType` | `trsProduct` | `trsAmount` | Outros |
|---|---|---|---|---|
| Crédito | 1 | 1 | `"1000"` (o texto sem a vírgula) | `trsInstallments = 1` |
| Débito | 1 | 2 | `"1000"` | `trsInstallments = 1` |
| Pix | 1 | 8 | `"1000"` | não aplicável |
| Estorno | 2 | não aplicável | não aplicável | `trsRefundId` = o NSU |
| Estorno Pix | 21 | não aplicável | não aplicável | `trsRefundPixId` = o NSU |

### `SiPagTransactionResult`

| Campo | Chave | DX (JSON do app Sicoob) | P2 (`ParamOut`) |
|---|---|---|---|
| `flag` | `FLAG` | `label` | Pix (`resProduct == 8`): "Pix"; cartão: `resLabel`, e se nulo, "Pix" |
| `nsu` | `NSU_SITEF` | se `product == "PIX"`, `pixID`; senão, `transactionID` | Pix: `resPixId`; cartão: `resRrn` |
| `authorization` | `AUTHORIZATION` | `authorizationCode` | Pix: `resPixId`; cartão: `resAuthorization` |
| `cardNumber` | `CARD_NUMBER` | sem `product` (estorno), "Refund"; com ele, `maskedPan`, e sem `maskedPan`, o `product` | Pix: ""; cartão: `pan`, e se nulo, "Pix" |
| `installments` | `INSTALLMENTS` | `installments`, inteiro no canal e texto no Dart | `resInstallments` |
| `amount` | `AMOUNT` | `amount` em centavos ÷ 100; sem ele, 0 | `resAmount` em centavos ÷ 100; nulo, 0 |
| `merchantReceipt` | `COMPANY_RECEIPT` | as linhas de `receiptList[0].lines`, sem `\u0000`, cada uma seguida de `\n` | o `resPrint` antes de "VIA DO CLIENTE"; sem esse texto, "" |
| `customerReceipt` | `CLIENT_RECEIPT` | as linhas de `receiptList[1].lines`, do mesmo jeito | o `resPrint` depois de "VIA DO CLIENTE" |
| não lido | `MESSAGE` | "Operação efetuada com sucesso!" | "Operação efetuada com sucesso!" |

- **Campo ausente ou nulo:** vira texto vazio, ou 0 no `amount` e nas parcelas, no nativo e no `fromMap`. Valor que não for um inteiro de centavos também vira 0.
- **Comprovantes:** o do cliente ausente vira "", no DX com um comprovante só e no P2 sem a segunda via.

### Erros dos pagamentos

| Situação | Terminal | Código | Mensagem |
|---|---|---|---|
| JSON com `mError[0]` | DX | `mErrorCode`; vazio, `ERRO_NA_OPERACAO` | `mErrorDescription` + " " + `mPOS7ErrorCode` |
| JSON sem comprovante (`receiptList` vazia) | DX | `INVALID_OPERATION` | `displayMessage`; sem ela, "Erro interno da adquirente!" |
| JSON ilegível, também depois de 3 releituras do arquivo (a marca continua ligada) | DX | `ERRO_NA_OPERACAO` | Falha ao efetuar a operação! |
| Permissão `READ_EXTERNAL_STORAGE` negada; até o Android 10, também a `WRITE_EXTERNAL_STORAGE` | DX | `ERRO_NA_OPERACAO` | Permita o acesso ao armazenamento e tente novamente. |
| Resultado da operação anterior que não pôde ser apagado | DX | `ERRO_NA_OPERACAO` | Permita o acesso ao armazenamento e tente novamente. |
| App Sicoob ausente (`TransactionInfo.getSipag` falso) | DX | `ERRO_NA_OPERACAO` | Não localizamos aplicativo de pagamento neste terminal. |
| `status != 0` | P2 | `ERRO_INTERNO` | Terminal não configurado. |
| `config != 2` | P2 | `ERRO_NO_TERMINAL` | Não configurado. / Terminal configurado, mas sem paramêtros. |
| `license != 1` | P2 | `LICENCA_INVALIDA` | Licença inativa. / negada. / bloqueada. / desativada. / expirada.; outro código: Licença inválida. |
| `response != 0` | P2 | `ERRO_NA_OPERACAO` | `resDisplay`; nulo, "Falha ao efetuar a operação!" |
| Exceção ao iniciar o SDK | os dois | `ERRO_NA_OPERACAO` | Falha ao efetuar a operação! |
| Operação nova enquanto esta espera | os dois | `ERRO_NA_OPERACAO` | Operação substituída por uma nova. |
| `amount` ausente no canal | os dois | `amount` | amount is null |
| `nsu` ausente no canal | os dois | `nsu` | nsu is null |
| Método desconhecido | os dois | `notImplemented` do Flutter | não se aplica |

Quando o plugin mandava o mapa do resultado em `details` (erros do DX e `response != 0` do P2), este core também manda. O Dart não o lê.

As mensagens do P2 são as do `TerminalStatus` do plugin, inclusive o acento de "paramêtros".

### Última operação

| Situação | Código | Mensagem |
|---|---|---|
| Marca de operação pendente desligada, ou uma operação em andamento neste processo | `LAST_OPERATION_NOT_FOUND` | Não foi encontrado nenhuma operação no histórico! |
| Marca ligada e sem `Documents/operation_result.json` | `FILE_DOES_NOT_EXIST` | Não foi possível recuperar a última operação! |
| Marca ligada e falha ao ler ou ao interpretar o arquivo (JSON ilegível, inclusive) | `READ_OPERATION_FILE_FAILED` | Não foi possível recuperar a última operação! |
| Marca ligada e o arquivo lido | o resultado do DX, aprovado ou com os erros da tabela acima | não se aplica |

- **A marca:** fica no SharedPreferences, com a chave `has_error_on_last_operation`, a mesma do plugin. Ela é ligada quando o terminal abre o app da adquirente e desligada quando a operação responde, menos em duas situações em que a venda pode ter sido aprovada:
  - o JSON continua ilegível depois das releituras;
  - a resposta chega ao handler de uma activity que já foi recriada.
- **O `get_last_operation`:** desliga a marca em qualquer caso, como o plugin. A exceção é uma operação em andamento neste processo, que é dona da marca.
- **No P2:** o arquivo do DX não existe, e a resposta é `FILE_DOES_NOT_EXIST`, como hoje.

## Fluxos

### Pagamento e estorno

1. O Dart chama o canal. O handler confere os argumentos e escolhe o terminal pelo modelo.
2. **DX:**
   - sem a permissão de leitura, o terminal responde o erro e pede a permissão. O AAR pediria por conta própria e nunca retomaria a transação;
   - até o Android 10, também a de escrita: sem ela, o `File.delete()` do AAR falha calado, e o poller lê na hora o resultado da operação anterior como o da nova;
   - sem o app Sicoob, responde o erro. O AAR só mostraria um Toast;
   - o terminal apaga o resultado anterior antes de abrir o app; se ele não sair, responde o erro de permissão.
3. **A marca e a resposta pendente:** o terminal monta os dados (tabelas acima) e chama o SDK. A marca de operação pendente é ligada, e a resposta fica guardada com um identificador da operação.
4. **Operação nova enquanto outra espera:** a anterior responde "Operação substituída por uma nova.", e o callback atrasado dela é ignorado. O poller do apix990 só para quando lê um arquivo, e uma operação nova não o encerra, então os dois leriam o mesmo arquivo; o mesmo vale para os `AsyncTask` do pos7api. Sem isso, as duas chamadas receberiam o mesmo resultado, e o PDV poderia registrar a venda em dobro.
5. **Resultado:** o callback do SDK passa pelo parser e responde uma vez só, na main thread. O DX chama o callback numa thread de IO. O Flutter 3.35.2 aceita a resposta de lá, mas o canal pede a main thread.
   - O AAR lê o arquivo assim que ele aparece, e o app Sicoob pode ainda estar gravando. Um JSON ilegível é relido do arquivo até 3 vezes, com 500 ms entre elas.
6. A marca é desligada antes da resposta, menos quando o JSON continua ilegível.
7. **Activity recriada com o pagamento na frente:** o processo e o poller continuam vivos, e a integração cria um handler novo. O resultado chega ao handler antigo, cujo Dart morreu. Ele não responde nem desliga a marca, e o Dart novo recupera a venda pela última operação, como no plugin. Isso vale porque o PDV e o exemplo usam o `FlutterActivity` padrão, com o engine preso à activity.

### Última operação

1. O PDV chama `getLastOperation` ao abrir o dashboard.
2. Sem a marca, a resposta é `LAST_OPERATION_NOT_FOUND`, que o PDV ignora.
3. Com a marca, o handler a desliga e lê o arquivo do DX pelo mesmo parser dos pagamentos.

### Impressão

O canal `acquirers_sdk` do driver genérico, com o `NativePrinterService` do core. Nenhum comprovante é impresso automaticamente depois do pagamento.

A integração da Sipag abre a impressora do posmpapi uma vez, no `configure`, e a reaproveita. Na X990, o `Printer.getInstance` cria uma impressora nova a cada chamada, e ela só liga ao serviço da Verifone (`com.vfi.smartpos.deviceservice`) depois, de forma assíncrona. Criada na hora de imprimir, como na Vero e no `centralizer`, ela imprimia desligada e lançava `NullPointerException`, e a nova tentativa criava outra impressora desligada. No P2 e no DX8000, o posmpapi já reaproveita a instância, e o `open` e o `close` não fazem nada nos três modelos. Se a impressora não abrir no `configure`, o app segue, e a próxima impressão tenta abrir de novo.

## Divergências intencionais do plugin

1. **DX sem permissão de leitura responde erro e pede a permissão.** No plugin, o AAR pedia a permissão e nunca chamava o callback, e o Dart esperava para sempre. Até o Android 10, o terminal pede também a de escrita, e o resultado anterior é apagado antes de abrir o app; se ele não sair, a operação nem começa. No plugin, sem a escrita, o segundo pagamento recebia na hora o resultado do primeiro.
2. **App Sicoob ausente responde erro.** No plugin, o AAR capturava o `ActivityNotFoundException`, mostrava um Toast, e o Dart esperava para sempre.
3. **Campo ausente ou nulo vira texto vazio ou 0, e JSON ilegível é relido e só então responde erro, com a marca ligada.** No plugin, o `getString` lançava `JSONException` no callback e derrubava o app; a marca ficava ligada, e a última operação recuperava a venda. Do mesmo jeito, um comprovante do cliente ausente chegava nulo e quebrava o `toResult` do Dart com erro de tipo.
4. **Valor que não é um inteiro de centavos vira 0.** No plugin, o `Long.parseLong` derrubava o app.
5. **Argumento ausente responde e para.** No plugin, `amount` nulo não respondia nada, e `nsu` nulo ia vazio ao SDK.
6. **Resposta única, na main thread.** O DX respondia de uma thread de IO.
7. **Operação nova responde a anterior com erro e ignora o callback atrasado dela.** No plugin, as duas chamadas recebiam o mesmo resultado.
8. **Licença do P2 com código fora do mapa responde "Licença inválida.".** No plugin, a mensagem ia nula, e o Dart mostrava o texto da `PlatformException`.
9. **A marca de operação pendente fica no nativo.** No plugin, ficava no `flutter_secure_storage` do Dart. A chave é a mesma, mas a marca deixada pelo `centralizer` se perde na troca.
10. **`LAST_OPERATION_NOT_FOUND` vem do nativo.** No plugin, vinha do Dart. O código e a mensagem são os mesmos.
11. **Canal inexistente vira `<método>.not.implemented`.** O plugin capturava `UnimplementedError`, mas o Flutter lança `MissingPluginException`.
12. **Um AAR do P2 só.** O debug e o release têm o mesmo código.
13. **O código morto do comprovante da X990 não vem.** A comparação em minúsculas nunca casava, então o comportamento não muda.
14. **A resposta que chega ao handler de uma activity recriada não desliga a marca.** No plugin, a marca morria ligada junto com o Dart antigo, e a última operação recuperava a venda; aqui o comportamento é o mesmo, de propósito.
15. **`get_last_operation` com uma operação em andamento neste processo responde `LAST_OPERATION_NOT_FOUND`.** No plugin, ele lia o arquivo, que o AAR tinha acabado de apagar, e respondia `FILE_DOES_NOT_EXIST`.
16. **`mErrorCode` vazio vira `ERRO_NA_OPERACAO`, e `displayMessage` vazia vira "Erro interno da adquirente!".** No plugin, o código ia vazio, e a mensagem, vazia.
17. **A impressora do driver genérico abre uma vez, no `configure`.** No `centralizer`, ela era criada a cada impressão, e na X990 nenhuma impressão saía (confirmado no terminal em 2026-10-30).

## Mantido igual ao plugin e ao `centralizer`

- Canal, métodos, argumentos, formato do valor, chaves do resultado, códigos e mensagens.
- Escolha do terminal por `Build.MODEL.contains("P2")`.
- Crédito só à vista, débito, Pix e os dois estornos. Estorno de cartão no DX sem NSU.
- `trsId` do P2 no formato `MMddHHmmss` e comprovantes separados por "VIA DO CLIENTE".
- `cardNumber` "Refund" no estorno do DX e "Pix" quando o P2 não manda o cartão.
- No P2, a última operação continua sem recuperação.
- Nenhum comprovante automático depois do pagamento, em nenhum terminal.
- Se o Android matar o app enquanto o da adquirente está na frente, a resposta se perde. No DX, a última operação a recupera; no P2, não. É o mesmo ponto em aberto da Stone, da Vero e da Rede.

## Testes e verificação

### Dart (`core`)

- **`SiPagTransactionResult.fromMap`:**
  - lê as oito chaves;
  - `INSTALLMENTS` inteiro vira texto;
  - `AMOUNT` inteiro ou decimal vira double;
  - campo ausente ou nulo vira texto vazio ou 0.
- **`SiPagPaymentService`:**
  - cada método chama o do canal com os argumentos do plugin;
  - o valor formatado: 0,29 → "0,29"; 4,35 → "4,35"; 33,3 → "33,30"; 1000 → "1000,00";
  - o estorno: type 1 vai para `refund_pix`, e 0 e -1 para `refund`. Os types 2, 3 e 4 respondem `type.is.invalid` sem chamar o canal, como no roteador do `centralizer`;
  - NSU em branco não chama o canal, e é conferido antes do type;
  - `getLastOperation` chama `get_last_operation`;
  - erro do Android com código e mensagem, e os fallbacks de stack trace e do texto do erro;
  - canal inexistente;
  - resposta vazia.

### Dart (`example`)

- View model e tela da Sipag, como os da Vero.
- `widget_test`: o flavor `sipag` abre direto na tela da Sipag.

### Kotlin (Robolectric, `src/testSipag/`)

- **Handler, com terminais falsos:**
  - cada método no terminal certo, com `P2-B` e `P2-A11` no P2, e `DX8000` e `X990` no DX;
  - argumentos ausentes;
  - método desconhecido;
  - responde uma vez só, na main thread, inclusive quando o callback chega de outra thread;
  - operação nova enquanto outra espera: a anterior recebe o erro, e o callback atrasado dela é ignorado;
  - a marca ligada durante a operação e desligada na resposta;
  - os quatro casos da última operação.
- **`DxResultParser`:**
  - cartão aprovado;
  - Pix, com o `pixID` no NSU;
  - estorno, sem `product`;
  - `mError`, com e sem `mErrorCode`;
  - sem comprovante, com e sem `displayMessage`;
  - um comprovante só;
  - campos ausentes ou nulos;
  - JSON ilegível;
  - valor que não é inteiro.
- **`P2ResultParser`:**
  - `status`, `config` e `license`, inclusive a licença com código fora do mapa;
  - Pix e cartão;
  - comprovantes com e sem "VIA DO CLIENTE";
  - `response != 0`, com e sem `resDisplay`;
  - `resAmount` nulo.
- **Terminais com os AARs de verdade:**
  - **DX:** o Intent que o apix990 abre em cada operação, com a ação e os extras, pelo Robolectric. Também a permissão negada e o app Sicoob ausente;
  - **P2:** o `ParamIn` de cada operação e a abertura do `Intercom`.
- **Integração:** o canal `sipag_sdk` de ponta a ponta pelo `StandardMethodCodec`.
- **Dependências:** `Class.forName` das classes que os AARs usam sem trazer:
  - `kotlinx.coroutines.Dispatchers`;
  - `androidx.core.content.ContextCompat`;
  - `androidx.core.app.ActivityCompat`;
  - a classe da biblioteca da Sunmi que o posmpapi usa no P2.

### Builds e checagens

- **APK da Sipag:** gerar o `app-sipag-debug.apk` e o `app-sipag-release.apk`. No manifest mesclado, conferir o `label` do app, os `<queries>`, as permissões dos AARs, a `uses-feature` de NFC e a activity `Intercom`.
- **APKs dos outros flavors:** gerar os de release de stone, cielo, pagbank, vero e rede e varrer por `apix990`, `sicoob`, `pos7api`, `ger7` e `sipag`, sem diferenciar maiúsculas.
  - Nenhum deve aparecer.
  - O APK da Sipag deve conter todos e serve de controle positivo.
  - O do PagBank continua sem o posmpapi (`posmp_api`, `veromobile`, `execucao`).
- **Suítes:** core e example (`test`, `analyze`, `format`) e Kotlin dos seis flavors, todos verdes.

### Nos terminais (DX8000, X990 e P2)

- Crédito, débito e Pix de R$ 1,00, e os estornos de cartão e de Pix.
- No DX, matar o app no meio de um pagamento e buscar a última operação.
- NFC-e de teste e de homologação, texto de teste e impressão de teste.
- Na X990, conferir que o app Sicoob imprime o comprovante sozinho.
- Conferir a versão do Android de cada terminal (veja "Riscos").

## Riscos e pontos em aberto

- **Android do DX8000 e da X990:**
  - **Android 11 ou mais:** o app só lê o `Documents/operation_result.json` do app Sicoob com o armazenamento legado, que só vale até o Android 10 (o apix990 declara `requestLegacyExternalStorage`). A partir do 11, é preciso `MANAGE_EXTERNAL_STORAGE`, que o PDV declara e o exemplo não.
  - **Android 13 ou mais:** a `READ_EXTERNAL_STORAGE` nunca é concedida, e todo pagamento do DX cai no erro de permissão.
- **Permissões no PDV:** o PDV declara a `READ_EXTERNAL_STORAGE` e a `MANAGE_EXTERNAL_STORAGE`, mas não pede nenhuma em tempo de execução. No DX, o primeiro pagamento vai responder o erro de permissão e pedir a READ e a WRITE, a menos que o terminal as conceda na instalação; conferir com `dumpsys package` e fazer dois pagamentos seguidos.
- **Leitura sem fim no DX:** se o app Sicoob voltar sem gravar o arquivo, o poller do AAR continua, e o Dart espera, como hoje.
- **Resultado gravado duas vezes no DX:** o app Sicoob grava `operation_result.json` com a resposta real e, uns 10 s depois, de novo com "Cancelado" (`-2101`). Isso foi visto em recusas e desistências na X990. O poller do AAR lê a primeira gravação, então a operação ao vivo recebe a resposta certa. Mas a última operação, depois de uma queda do app, pode ler o "Cancelado". Falta conferir se isso também acontece depois de uma aprovação.
- **Teste nos terminais (2026-10-30):**
  - **X990:** o crédito foi aprovado, e o app Sicoob imprimiu o comprovante sozinho. As quatro impressões livres passaram depois da correção do driver.
  - **Débito na X990:** o débito com chip de um cartão Maestro "Debito BMG" voltou do autorizador com 12 ("TRANS INVALIDA"). O terminal tinha escolhido a aplicação de débito certa (`A0000000043060`). Pela tarja, o app Sicoob recusa com `-2107` ("Insira o cartão"). A DX8000 também deu 012 no débito; a aplicação escolhida lá não foi conferida.
  - **P2:** chip e aproximação falham no app da Ger7 com `PPCOMP_CTLSSAPPNAV` (aplicação sem contato não disponível), e a tarja aprova crédito e débito. Isso indica tabelas EMV do terminal, que dependem do suporte da Sipag.
- **Ícone:** o apix990 traz `mipmap-anydpi-v26/ic_launcher` e `drawable-anydpi-v24/ic_launcher_foreground`, que valem mais que os PNGs do app no Android 8+. O exemplo `sipag` vai mostrar o ícone padrão do Android. O PDV já contorna isso com o próprio ícone adaptativo.
- **NFC obrigatória:** a `uses-feature` do apix990 só pesa em loja. Instalação direta não confere.
- **Nomes de outras adquirentes:** os `<queries>` do posmpapi citam pacotes da Vero e da Rede. É aceitável no APK da Sipag, porque só o PagBank barra essas referências.
- **Última operação no P2:** continua sem recuperação.
- **Integração com o PDV Varejo:** depende da fachada `FlutterAcquirersSdk` e do empacotamento do nativo. O PDV também vai precisar, no flavor da Sipag:
  - das mesmas dependências (coroutines, Sunmi);
  - dos `<queries>`;
  - do `tools:replace`;
  - das regras do R8.
