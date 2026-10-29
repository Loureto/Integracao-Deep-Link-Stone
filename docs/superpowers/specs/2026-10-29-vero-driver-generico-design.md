# Vero e driver genérico de impressão no core: design

- **Data:** 2026-10-29
- **Status:** aguardando revisão
- **Ciclo:** 1 de 3. Fiserv e Sipag vêm depois, uma por vez, no mesmo padrão.

## Objetivo

Trazer para este repositório as implementações da Vero que hoje estão no `centralizer` (`flutter_acquirers_sdk`):

- os pagamentos pelo app da Vero;
- a impressão pelo driver genérico (`posmpapi`).

O `centralizer` será aposentado e o PDV Varejo vai depender direto deste core. Por isso, todos os nomes repetem os do `centralizer`, para a integração ser plug and play:

- funções;
- canais e métodos;
- campos;
- códigos e mensagens de erro.

## O que o PDV Varejo usa hoje

Toda chamada passa pelo `AcquirerUseCase` (`pdv-varejo/lib/core/domain/usecases/native_request/acquirer_use_case.dart`), via `FlutterAcquirersSdk`, com `acquirer: Session.acquirer.acquirerName`.

| Função do PDV Varejo | Na Vero, dentro do `centralizer` |
|---|---|
| `creditPayment`, `debitPayment`, `pixPayment` | `VeroPayment.creditCardPayment`, `debitCardPayment`, `pixPayment` |
| `customAcquirerPayment` | `VeroPayment.acquirerPayment` (carteira) |
| `refund` | `VeroPayment.refundPayment(nsu)`. O `FlutterAcquirersSdk.refund` exige o NSU antes. |
| `printText`, `printNfc`, `printReceipt` | driver genérico: `NativePrinter.printTxt`, `printNfc`, `printCustomReceipt` |
| `initialSettings`, `getLastOperation` | não existem para a Vero e voltam `function.is.invalid`, que o PDV ignora |
| `generateReceipt` | `PrinterUtils.generateReceipt`, que ainda não é usado (veja "Fora do escopo") |

Do resultado, o PDV lê `nsu`, `authorization`, `flag` e `installments` (`AcquirerTransactionResult`). Dos erros, lê `code` e `message` (`AcquirerError`).

## Escopo

### Dentro

1. **Pagamentos da Vero:** crédito, débito, Pix, carteira e estorno.
2. **Comprovante automático:** depois de um pagamento ou estorno aprovado, o `customerReceiptTxt` é impresso pelo driver, como faz o `_sharedResponse` do `VeroPayment`.
3. **Driver genérico:** `printTxt`, `printNfc`, `testPrint` e `printReceipt(bitmap:)`.
4. **Flavor `vero` no app de exemplo,** com tela de teste.

### Fora do escopo

- **`reprint`:** nenhum fluxo do `centralizer` o chama, e o `vero_flutter` manda o NSU na chave `amount`, que o Kotlin não lê.
- **`initialSettings` e `getLastOperation`:** não existem para a Vero.
- **Comprovante customizado** (`PrinterDataModel`, `generateReceipt`, `printCustomReceipt`): o PDV Varejo ainda não usa. Será um sub-projeto à parte, para todas as adquirentes.
- **A fachada `FlutterAcquirersSdk`** (roteamento por `acquirer`, `AcquirerResponse`): será montada sobre estes serviços no ciclo de integração com o PDV Varejo, com os mesmos nomes.
- **O empacotamento do nativo para o PDV Varejo** (plugin ou cópia para o Android do PDV): decisão do ciclo de integração, válida para todas as adquirentes.
- **Fiserv e Sipag:** ciclos 2 e 3.

## Decisões tomadas no brainstorming

1. Só a Vero agora, com o driver genérico. Fiserv e Sipag depois.
2. O padrão é o da Stone: serviços no core com os nomes do `centralizer`, sem a fachada `FlutterAcquirersSdk` neste ciclo.
3. O comprovante customizado fica fora.
4. O driver é compartilhado entre os flavors que o usam: um source set próprio, ligado só a esses flavors, com o AAR só neles.

## Arquitetura

### Android (`example/android/app`)

- **Flavor `vero`,** na dimensão `acquirer`.
  - Em `src/vero/kotlin/com/example/example/`:
    - `VeroIntegration.kt`, com o `createAcquirerIntegration()`. Registra o canal `vero_flutter` e o canal `acquirers_sdk` do driver.
    - `vero/`, com o handler de pagamento: monta o Intent e trata o `onActivityResult`. Também converte o Bundle de retorno em mapa, copiando as URIs dos comprovantes para o cache, como o `Utils.kt` do plugin.
  - Os testes ficam em `src/testVero/`.
- **Driver genérico:**
  - O código fica em `src/genericPrinter/kotlin/...` e reproduz o `ServicePrinter` do `centralizer`. Ele fala com o `posmpapi` por uma interface pequena, que nos testes é trocada por uma falsa.
  - O AAR fica em `libs/posmpapi_1.01.10-partnersRelease.aar`, copiado do `centralizer`.
  - No `build.gradle.kts`, o source set `vero` inclui `src/genericPrinter/kotlin`, e só o flavor `vero` tem `"veroImplementation"(files("libs/posmpapi_1.01.10-partnersRelease.aar"))`. Fiserv e Sipag entram nessa mesma lista depois.
- **`AcquirerIntegration`:** ganha `onActivityResult(requestCode, resultCode, data): Boolean`, com padrão `false`. A `MainActivity` sobrescreve `onActivityResult`, chama o `super` e repassa à integração. Stone, Cielo e PagBank não mudam.

### Dart (`core`)

- **`IVeroPaymentService` / `VeroPaymentService`:**
  - recebe o `MethodChannel('vero_flutter')` e o `INativePrinterService`;
  - não registra handler de chamadas vindas do nativo, porque todo resultado volta na própria chamada.
- **`INativePrinterService` / `NativePrinterService`:**
  - recebe o `MethodChannel('acquirers_sdk')` e o `IPdfImageConverter`;
  - não depende de adquirente.
- **Modelos:**
  - `VeroTransactionResult` e `VeroError`, com os nomes do `vero_flutter`;
  - `NativePrinterError`, com `code` e `message`.

### App de exemplo

- **Integração:** `VeroIntegration` em Dart, com a rota `/vero`. Registra `INativePrinterService`, `IPdfImageConverter`, `IVeroPaymentService` e o view model.
- **Flavor:**
  - `main.dart` ganha `const _isVero = appFlavor == 'vero'`;
  - `assets/env/vero_env.json` tem `FLAVOR_TYPE=vero`;
  - `.vscode/launch.json` ganha "Vero Integration", com `--flavor vero`.
- **Tela da Vero:**
  - pagamentos de teste com valores fake: crédito, débito, Pix e carteira;
  - estorno do último pagamento aprovado, pelo NSU;
  - impressões pelo driver: NFC-e de teste (`NfceMock.pdf`), NFC-e de homologação (`NfceHomologacaoMock.pdf`), texto (`NfceMock.text`) e impressão de teste.

## Contrato

### Pagamentos da Vero

| `IVeroPaymentService` (como o `VeroPayment`) | Canal `vero_flutter` (como o plugin) | Intent para o app da Vero |
|---|---|---|
| `creditCardPayment(double amount)` | `payCredit {amount: int}` | ação `br.com.execucao.PAGAR`, `TRANSACAO=CREDITO_GENERICO` |
| `debitCardPayment(double amount)` | `payDebit {amount: int}` | `PAGAR`, `TRANSACAO=DEBITO` |
| `pixPayment(double amount)` | `payPix {amount: int}` | `PAGAR`, `TRANSACAO=PIX` |
| `acquirerPayment(double amount)` | `wallet {amount: int}` | `PAGAR`, `TRANSACAO=WALLET` |
| `refundPayment(String nsu)` | `refund {nsu: String}` | ação `br.com.execucao.ESTORNAR`, `NSU` |

- Todos devolvem `Future<Either<VeroError, VeroTransactionResult>>`.
- `amount` chega em reais e vai ao canal em centavos (`int`).
- O pagamento manda os extras `VALOR` (centavos, `Int`) e `TRANSACAO`. O estorno manda `NSU`. Todos mandam `IMPRIMIR_COMPROVANTE=false`.
- O app da Vero é aberto com `startActivityForResult(intent, 1)`.

### `VeroTransactionResult`

Todos os campos são `String`. Um campo ausente vira `''`, e um valor que não é texto é convertido com `toString()`.

| Campo | Chave | Campo | Chave |
|---|---|---|---|
| `serial` | `SERIAL` | `value` | `VALOR` |
| `acquiringCnpj` | `CNPJ_ADQUIRENTE` | `cardNumber` | `NUMCARTAO` |
| `flag` | `BANDEIRA` | `authorization` | `AUTORIZACAO` |
| `establishmentName` | `NOME_ESTABELECIMENTO` | `merchantReceipt` | `COMPROVANTE_LOJISTA` |
| `transaction` | `TRANSACAO` | `customerReceiptTxt` | `COMPROVANTE_CLIENTE_TXT` |
| `receipt` | `COMPROVANTE` | `customerReceipt` | `COMPROVANTE_CLIENTE` |
| `establishmentCnpj` | `CNPJ_ESTABELECIMENTO` | `installments` | `PARCELAS` |
| `nsu` | `NSU` | `acquirerName` | `NOME_ADQUIRENTE` |

`merchantReceipt` e `customerReceipt` chegam como caminhos de arquivo no cache: o nativo copia as URIs, como o plugin. Na fachada, o `AcquirerTransactionResult.fromVeroTransaction` já lê esses arquivos. Por terem os mesmos nomes, ele e o `AcquirerError.fromVeroError` funcionam sem mudança, com uma exceção:
- um comprovante ausente ou que não abriu chega como `''` (divergência 3);
- o `File('').readAsBytesSync()` do `fromVeroTransaction` lança `PathNotFoundException`, e o PDV mostra o erro sem gravar o pagamento já cobrado;
- por isso, no ciclo de integração, a fachada só lê o arquivo quando o caminho não é vazio e o arquivo existe.

### Erros da Vero (`VeroError {code, message}`)

| Situação | `code` | `message` |
|---|---|---|
| Recusa (extra `ERRO`) | `ERRO_DESCONHECIDO` | o texto do extra, sem `.` e espaços no começo, ou "Transação rejeitada" |
| Cancelamento ou retorno sem `AUTORIZACAO` | `ERRO_DESCONHECIDO` | "Operação cancelada pelo usuário!" |
| App da Vero ausente | `ERRO_DESCONHECIDO` | "Não localizamos aplicativo de pagamento neste terminal." |
| Outra exceção ao abrir o app da Vero | `ERRO_DESCONHECIDO` | a mensagem da exceção, ou "Não foi possível abrir o aplicativo de pagamento." |
| Estorno com NSU em branco (sem chamar o Android) | `nsu.not.informed` | "O campo: nsu não foi informado! Corrija-o e tente novamente!" |
| Canal inexistente | `<método>.not.implemented` | "`<método>`() has not been implemented." |
| Sucesso com resposta vazia | `unknown.error` | "Erro desconhecido, tente novamente" |
| Outra `PlatformException` | o código dela | `message`, ou o `stacktrace`, ou o `toString()`, como no plugin |

### Driver genérico

| `INativePrinterService` (como o `NativePrinter`) | Canal `acquirers_sdk` | Kotlin (como o `ServicePrinter`) |
|---|---|---|
| `printTxt(String text)` | `printTxt {text}` | `printTxtReceipt(text)`: texto em bitmap de 576 px, fonte monoespaçada 20, linhas por `\n`, altura `linhas × (descent − ascent) + 20` |
| `printReceipt({required Uint8List bitmap})` | `printReceipt {bitmap: Uint8List}` | `printReceipt(bytes)`: `BitmapFactory.decodeByteArray` e impressão |
| `printNfc(String nfcBase64)` | não tem método próprio: converte e chama `printReceipt` | |
| `testPrint()` | `testPrint` | imprime "Impressao teste" |

- Todos devolvem `Future<Either<NativePrinterError, Unit>>`.
- O nativo responde sucesso com "Sucesso ao efetuar a impressão".
- No `posmpapi`, o Kotlin faz o mesmo que hoje: `Printer.getInstance(context)`, `open()`, `print(bitmap, PrinterListener)` e `close()`.

| Situação | `code` | `message` |
|---|---|---|
| `onError` com `Printer.ERRO_SEM_PAPEL` | `ERRO_SEM_PAPEL` | "Impressora sem papel, verifique!" |
| `onError` com outro código, ou exceção | `ERRO_DESCONHECIDO` | "Erro na impressão" |
| Conversor da NFC-e falhou | o código do `PdfImageFailure` | a mensagem dele |
| Canal inexistente | `NOT_SUPPORTED` | "Driver de impressão indisponível nesta plataforma." |

## Fluxos

### Pagamento e estorno

1. O `core` valida o NSU (só no estorno), converte o valor e chama o canal.
2. O Kotlin monta o Intent, abre o app da Vero e guarda a resposta ao Dart, que só pode ser dada uma vez.
3. A `MainActivity` repassa o `onActivityResult`. O handler ignora outro código de requisição e traduz o retorno conforme as tabelas acima.
4. Com sucesso, o `core` monta o `VeroTransactionResult` e chama `printTxt(customerReceiptTxt)`. O resultado da impressão é ignorado, e a transação é devolvida.
5. Com erro, nada é impresso.

### Impressão

- `printReceipt` acrescenta 1 cm (80 linhas) em branco no fim do bitmap, como na Stone, e manda os bytes.
- `printNfc` usa o `PdfImageConverter`, que entrega 384 pontos de largura sem sobras, e depois o `printReceipt`.
- `printTxt` e `testPrint` mandam o pedido e o nativo desenha.
- Em `ERRO_DESCONHECIDO` ou `IMPRESSORA_INDISPONIVEL`, o pedido é repetido uma vez, por chamada.

## Divergências intencionais do `centralizer`

1. **Centavos com `round()`.** O `centralizer` usa `(amount * pow(10, 2)).toInt()`, que trunca: R$ 0,29 vira 28 centavos, R$ 0,57 vira 56, R$ 4,35 vira 434 e R$ 33,30 vira 3329. O `stone_sdk` tem o mesmo erro.
2. **Nova tentativa do driver: uma por chamada.** No `centralizer`, `IMPRESSORA_INDISPONIVEL || ERRO_DESCONHECIDO && !_attempts` deixa o `IMPRESSORA_INDISPONIVEL` sem limite, e a flag estática só volta a `false` com sucesso.
3. **Campo ausente no retorno da Vero vira `''`.** No plugin, os 16 campos são `String` obrigatórios, e um campo ausente derrubaria o app.
4. **Canal inexistente vira `<método>.not.implemented`.** O plugin pretendia isso, mas captura `UnimplementedError`, e o Flutter lança `MissingPluginException`.
5. **NFC-e pelo driver.** Usa o conversor atual mais 1 cm no fim. O `centralizer` imprimia a página inteira do PDF, com o branco do próprio PDF.
6. **Exceção inesperada ao abrir o app da Vero.** Responde `ERRO_DESCONHECIDO`. No plugin, essa exceção só ia para o log e a chamada ficava sem resposta.
7. **Falha do driver ao criar a impressora vira erro de impressão.** Uma biblioteca do fabricante fora do APK (`NoClassDefFoundError`) ou um modelo que o `posmpapi` não conhece respondem `ERRO_DESCONHECIDO` / "Erro na impressão". No `centralizer`, o `Error` derrubava o app, e o modelo desconhecido voltava com o código `error` e a stack trace como mensagem.
8. **Extras que o codec do Flutter não carrega vão como texto.** `Char`, arrays e `Parcelable`, por exemplo, viram `toString()`. No plugin, eles derrubavam o app no retorno aprovado.
9. **`AUTORIZACAO` aprova em qualquer tipo.** O plugin a lia só como `String`, e uma numérica virava "Operação cancelada pelo usuário!" depois da cobrança.
10. **Comprovante automático com espera de até 60 s.** Se o driver não responder, a transação aprovada volta assim mesmo. No `centralizer`, a espera não tinha limite, e o `posmpapi` pode nunca chamar o listener.
11. **Comprovante do cliente vazio não vai à impressora.** Sem esse cuidado, sairia uma faixa em branco.
12. **Comprovante copiado para a pasta do extra no cache, só com o nome do arquivo.** O plugin usava o `lastPathSegment` decodificado direto no cache. Um `%2F..` saía do cache, e dois comprovantes com o mesmo nome se sobrescreviam.
13. **O driver responde ao Dart uma vez só.** Um segundo retorno do listener é ignorado; na Sunmi, trabalhos sobrepostos podem gerá-lo. No `centralizer`, ele derrubava o app com "Reply already submitted".

A `com.sunmi:printerlibrary:1.0.23`, que o `posmpapi` usa no P2 sem trazê-la no AAR, é declarada direto no flavor. No PDV Varejo, ela vinha do plugin `vero_flutter`, na mesma versão. O flavor também declara a consulta ao serviço de impressão da Sunmi (`woyou.aidlservice.jiuiv5`), exigida no Android 11+. Nem o PDV nem o `centralizer` a declaram.

## Mantido igual ao `centralizer`

- Comprovante automático depois de pagamento e estorno, com o resultado da impressão ignorado.
- `IMPRIMIR_COMPROVANTE=false`: o app da Vero não imprime, quem imprime é o driver.
- Texto em bitmap de 576 px com fonte 20, e "Impressao teste".
- Uma operação nova, enquanto outra espera, fica com o próximo retorno.
- Se o Android matar o app enquanto o da Vero está na frente, o retorno se perde. É o mesmo ponto em aberto da Stone.

## Testes e verificação

TDD, como nas outras integrações.

### Dart (`core`)

- **`VeroTransactionResult`:** as 16 chaves, campo ausente e valor que não é texto.
- **`VeroPaymentService`:**
  - método e argumentos de cada chamada, com R$ 0,29 → 29 e R$ 4,35 → 435;
  - impressão do `customerReceiptTxt` depois de pagamento e estorno;
  - uma falha na impressão não muda o resultado;
  - erro não imprime;
  - todos os erros da tabela.
- **`NativePrinterService`:**
  - nomes e argumentos;
  - a margem de 1 cm, conferida decodificando a imagem enviada;
  - nova tentativa única em `ERRO_DESCONHECIDO` e `IMPRESSORA_INDISPONIVEL`, e nenhuma em `ERRO_SEM_PAPEL`;
  - `printNfc` passando pelo conversor e falha do conversor;
  - `NOT_SUPPORTED`.

### Dart (`example`)

- View model e tela da Vero: pagamentos, estorno do último NSU e as quatro impressões.
- `widget_test.dart`: com o flavor `vero`, o app abre direto na tela da Vero.

### Kotlin (Robolectric, `src/testVero/`)

- **Handler da Vero:**
  - ação, extras e código 1 do `startActivityForResult`;
  - recusa, sucesso com URIs copiadas para arquivo e cancelamento;
  - resposta única;
  - app ausente;
  - outro código de requisição.
- **Integração de ponta a ponta:** o canal `vero_flutter` chega ao handler, e o `onActivityResult` chega ao Dart.
- **`ServicePrinter` com a interface falsa:** bitmap de 576 px, `onFinish`, `onError` com e sem papel, e exceção.

### Builds e checagens

- APK do flavor `vero` montado com o AAR.
- Testes Kotlin de todos os flavors.
- `flutter analyze` e `dart format` em `core` e `example`.
- Varredura dos APKs de release de Stone, Cielo e PagBank à procura de `posmp_api`, `veromobile` e `execucao`, para confirmar que o AAR não vazou.

### No terminal Vero

- Crédito, débito, Pix, carteira e estorno, conferindo o comprovante automático.
- NFC-e de teste, NFC-e de homologação, texto e impressão de teste.
- O AAR já reconhece os terminais da Vero: `veromobile.gertecG760`, `veromobile.positivol3` e `veromobile.sunmiP2`.

## Riscos e pontos em aberto

- **Imagem de 384 pontos no `posmpapi`.** O `centralizer` mandava imagens maiores. A margem de 1 cm pode ser desnecessária se o `posmpapi` avançar o papel sozinho. Isso se confirma no terminal.
- **Texto do `printTxt` em 576 px.** É desenhado para 80 mm, como hoje. O `posmpapi` adapta à bobina de 58 mm, mas o tamanho final só se vê no terminal. Não muda neste ciclo, para não divergir.
- **Integração com o PDV Varejo.** Depende da fachada `FlutterAcquirersSdk` e do empacotamento do nativo, que ficam no ciclo de integração.
