# Migração da Rede do centralizer para o core

## Objetivo

Trazer para este repositório a integração da Rede que hoje está no `centralizer` (`flutter_acquirers_sdk`). Lá, o `RedeIntegration` é uma fachada sobre o plugin `flutter_rede_sdk` (git `flutter-package-rede@192.168.50.59:fontes`, ref `93f6ad4`).

O `centralizer` será aposentado, e o PDV Varejo vai depender direto deste core. Por isso, a troca precisa ser plug and play. Os nomes repetem os do `centralizer` e os do plugin, e os erros seguem o sufixo `*Failure` deste core:
- os métodos do serviço;
- o canal e os métodos dele;
- os argumentos;
- as chaves do resultado;
- os códigos e as mensagens de erro.

Só o terminal L400, o único que a Rede usa hoje, com o SDK SmartRede 4.1.1 (`smartrede-sdk-l400-4.1.1.release.aar`).

## O que o PDV Varejo usa hoje

Toda chamada passa pelo `AcquirerUseCase`, via `FlutterAcquirersSdk`, com `acquirer: "rede"`.

| Função do PDV Varejo | Na Rede, dentro do `centralizer` |
|---|---|
| `creditPayment`, `debitPayment`, `pixPayment` | `RedeIntegration.creditCardPayment`, `debitCardPayment`, `pixPayment` |
| `refund` | `RedeIntegration.refundPayment(nsu)` |
| `printText`, `printNfc`, teste de impressão | `RedeIntegration.printTxt`, `printNfc`, `testPrint` |
| `printReceipt` (comprovante customizado) | `RedeIntegration.printCustomReceipt`, que usa o `PrinterUtils.generateReceipt` (veja "Fora do escopo") |
| carteira, configurações iniciais, última operação | não existem para a Rede e voltam `function.is.invalid` |

Do resultado, o PDV lê `nsu`, `authorization`, `flag` e `installments`. O `AcquirerTransactionResult.fromRedeTransaction` também lê `cardNumber` e `amount`. Dos erros, o PDV lê `code` e `message`.

## Escopo

### Dentro

- Crédito à vista, débito, Pix e estorno pelo NSU, pelo app da Rede.
- Impressão de texto, de bitmap e da NFC-e, e a impressão de teste, pela impressora do SDK da Rede. O driver genérico não cobre a Rede.
- Flavor `rede` no app de exemplo, com tela de teste.

### Fora do escopo

- **Comprovante customizado** (`printCustomReceipt` / `PrinterUtils.generateReceipt`): ainda não é usado, como na Vero.
- **Crédito parcelado, voucher e reimpressão** (`intentForReprint`): o plugin não os usa.
- **A fachada `FlutterAcquirersSdk`:** vem no ciclo de integração com o PDV Varejo.
- **O empacotamento do nativo para o PDV:** também vem no ciclo de integração.

## Decisões tomadas no brainstorming

1. **Mesmo padrão da Vero:** serviço no core e código nativo no flavor `rede` do app de exemplo, com o AAR em `libs/`. A outra opção era depender do plugin `flutter_rede_sdk`. Ela foi descartada: plugin Flutter entra em todos os flavors, o APK do PagBank levaria a Rede, e os defeitos do plugin continuariam.
2. **Pagamento e impressão no mesmo serviço** (`IRedePaymentService`), como na Stone, no PagBank e na Cielo, e como no `RedeIntegration`.
3. **Contrato igual ao do plugin**, inclusive nos pontos estranhos (veja "Mantido igual").
4. **Defeitos que travam ou derrubam o app viram divergências registradas.** Os centavos passam a ser arredondados.
5. **NFC-e com 1 cm de margem**, para reproduzir o resultado do `centralizer`, que imprimia a página inteira do PDF. O SDK já avança 4 linhas depois da imagem; no L400 dá para ver se a margem sobra.

## Arquitetura

### Dart (`core`)

- **`RedeTransactionResult`** (`domain/models/rede_transaction_result.dart`): campos `flag`, `nsu`, `authorization`, `installments` (texto), `amount` (double) e `cardNumber`, mais o `fromMap`.
- **`RedeFailure`** (`domain/failures/rede_failure.dart`): `code` e `message`, com as fábricas `nsuNotInformed()`, `notImplemented(method)`, `unknown()` e `invalidImage()`.
- **`IRedePaymentService`** (`data/interfaces/rede_payment_interface.dart`): `creditCardPayment`, `debitCardPayment`, `pixPayment`, `refundPayment`, `printTxt`, `printNfc`, `testPrint` e `printReceipt({bitmap})`.
- **`RedePaymentService`** (`infrastructure/rede_payment/rede_payment_service.dart`): recebe o `MethodChannel('rede_sdk')` e o `IPdfImageConverter`.
- **Margem de 1 cm:** sai do `NativePrinterService` para uma função comum, `withBottomMargin` em `infrastructure/receipt_image/bottom_margin.dart`. O `NativePrinterService` e o `RedePaymentService` passam a usá-la. A da Stone não muda, porque também converte a imagem para preto e branco.
- **Exportações** nos barris do core, como na Vero.

### Android (`example/android/app`)

- **Flavor `rede`** (dimensão `acquirer`, `minSdk = 28`). Só ele leva o SDK e as dependências:
  - `libs/smartrede-sdk-l400-4.1.1.release.aar`, copiado do plugin;
  - `com.google.code.gson:gson:2.11.0`, a versão que o plugin declara;
  - `org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1`, a versão que o app já resolve hoje, agora declarada;
  - `androidx.appcompat:appcompat:1.7.0`.
- **Dependências que o AAR usa sem trazer:** Gson, kotlinx-coroutines (a impressão roda em `runBlocking`), appcompat, activity, fragment e core. No PDV, elas chegam por outros plugins. Sem elas, a impressão daria `NoClassDefFoundError`, como aconteceu com a biblioteca da Sunmi na Vero.
- **`src/rede/kotlin/...`:**
  - `RedeIntegration.kt`: o `createAcquirerIntegration()`. Registra o canal `rede_sdk`, encaminha os métodos de pagamento a um handler e os de impressão a outro, e repassa o `onActivityResult`.
  - Handler de pagamento e estorno, e handler de impressão.
  - O SDK fica atrás de duas interfaces pequenas, uma para pagamentos e uma para a impressora, como o `PosPrinter` da Vero. Assim os testes rodam sem o terminal.
- **Texto em bitmap:** a função sai do `ServicePrinter` da Vero para `src/main/kotlin/.../printer/`, com o texto "Impressao teste", e passa a valer para a Vero e para a Rede. Ela é genérica e não cita adquirente.
- **Testes** em `src/testRede/kotlin/...`. Os do texto em bitmap vão para `src/test/`.

### App de exemplo

- **Tela `/rede`:**
  - pagamentos de R$ 1,00 (crédito, débito e Pix);
  - estornar o último pagamento;
  - NFC-e de teste e de homologação;
  - texto de teste e impressão de teste.
- **Arquivos:**
  - `RedeIntegration` (Dart) com a injeção de dependências;
  - `const _isRede = appFlavor == 'rede'` no `main.dart`;
  - `assets/env/rede_env.json` com `{"FLAVOR_TYPE": "rede"}`;
  - configuração "Rede Integration" no `.vscode/launch.json`.

## Contrato

### Pagamentos da Rede

Retornam `Future<Either<RedeFailure, RedeTransactionResult>>`.

| `IRedePaymentService` | Canal `rede_sdk` | No SDK |
|---|---|---|
| `creditCardPayment(double amount)` | `credit_payment` {`amount`} | `FlexTipoPagamento.CREDITO_A_VISTA` |
| `debitCardPayment(double amount)` | `debit_payment` {`amount`} | `FlexTipoPagamento.DEBITO` |
| `pixPayment(double amount)` | `pix_payment` {`amount`} | `FlexTipoPagamento.PIX` |
| `refundPayment(String nsu)` | `refund` {`nsu`} | `intentForReversal(nsu)` |

- **`amount`:** vai em centavos inteiros, `(amount * 100).round()`.
- **Abertura do app da Rede:** `RedePayments.getInstance(context).intentForPaymentBuilder(tipo, centavos).build()`, com `startActivityForResult` e código 4. No estorno, código 5.
- **Leitura do resultado:** `RedePayments.getPaymentFromIntent(data)`, que lê o extra `rede.smartrede.sdk.INTENT_EXTRAS_PAYMENT`.

### `RedeTransactionResult`

| Campo | Chave | Pagamento aprovado | Estorno aprovado |
|---|---|---|---|
| `flag` | `FLAG` | `receipt.issuerName`; se nulo, "Pagamento " + `receipt.operationType` | "Estorno" |
| `nsu` | `NSU_SITEF` | `receipt.NSU` | "" |
| `authorization` | `AUTHORIZATION` | se o tipo da operação contém "pix", `receipt.NSU`; senão, `receipt.AUTO` | "" |
| `installments` | `INSTALLMENTS` | `receipt.installments`, inteiro no canal e texto no Dart | 1 |
| `amount` | `AMOUNT` | `receipt.value` (double) | 0 |
| `cardNumber` | `CARD_NUMBER` | `receipt.operationType` | "refund" |

Campo ausente ou nulo, inclusive o recibo inteiro, vira texto vazio, ou 0 no `amount`.

### Erros dos pagamentos

Os códigos e as mensagens vêm do `strings.xml` do plugin.

| Situação | Código | Mensagem |
|---|---|---|
| Pagamento com status `FAILED` | `TRANSACTION_FAILED` | Falha ao efetuar a transação! |
| Estorno com status `FAILED` | `REFUND_FAILED` | Falha ao realizar estorno! |
| Pagamento com outro status diferente de `AUTHORIZED` | `TRANSACTION_DENY` | Operação negada! |
| Estorno com outro status diferente de `AUTHORIZED` | `REFUND_DENY` | Estorno negado! |
| `RESULT_CANCELED` | `OPERATION_CANCELED` | Operação cancelada! |
| `RESULT_OK` sem dados, ou sem pagamento nos dados | `ERRO_DESCONHECIDO` | Erro desconhecido, tente novamente! |
| Outro `resultCode` | `UNKNOWN_ERROR` | Erro desconhecido, tente novamente! |
| App da Rede ausente (`ActivityNotFoundException`) | `ERRO_DESCONHECIDO` | Não localizamos aplicativo de pagamento neste terminal. |
| Validação do SDK (`RedePaymentValidationError`) ou outra exceção ao abrir o app | `ERRO_DESCONHECIDO` | a mensagem da exceção; sem ela, "Erro ao iniciar pagamento, tente novamente!" ou "Erro ao iniciar estorno, tente novamente!" |
| `amount` ausente no canal | `amount` | amount is null |
| `nsu` ausente no canal | `nsu` | nsu is null |

No Dart:
- NSU em branco responde `nsu.not.informed` / "O campo: nsu não foi informado! Corrija-o e tente novamente!" sem chamar o Android;
- canal inexistente responde `<método do canal>.not.implemented` / "<método do canal>() has not been implemented.";
- resposta vazia responde `unknown.error` / "Erro desconhecido, tente novamente";
- `PlatformException` vira `RedeFailure(code, message ?? stacktrace ?? toString())`.

### Impressão

Retorna `Future<Either<RedeFailure, Unit>>`.

| `IRedePaymentService` | Canal `rede_sdk` | Detalhe |
|---|---|---|
| `printTxt(String text)` | `print_txt` {`text`} | texto num bitmap de 576 px, com fonte monoespaçada 20 |
| `testPrint()` | `test_print` | o texto "Impressao teste" |
| `printReceipt({required Uint8List bitmap})` | `print_receipt` {`bitmap`} | o PNG com 1 cm de margem no fim |
| `printNfc(String nfcBase64)` | não usa canal | a primeira página pelo `IPdfImageConverter` e depois `printReceipt` |

| Situação | Código | Mensagem |
|---|---|---|
| Sucesso | não se aplica | Sucesso ao efetuar a impressão |
| O SDK avisa "Printer out of paper" | `ERRO_SEM_PAPEL` | Impressora sem papel, verifique! |
| O SDK avisa "Init failed" ou "Printer not ready", ou não abre | `IMPRESSORA_INDISPONIVEL` | Módulo de impressão não inicializado |
| Outra mensagem, exceção ou `LinkageError` | `ERRO_DESCONHECIDO` | Erro na impressão |
| Bytes que não formam imagem | `ERRO_DESCONHECIDO` | Erro na impressão |
| `bitmap` ausente no canal | `bitmap` | bitmap is null |
| `text` ausente no canal | `text` | text is null |

- **Nova tentativa:** `IMPRESSORA_INDISPONIVEL` tenta de novo uma vez por chamada.
- **Bytes que não formam imagem:** o Dart responde sem chamar o canal, e o nativo também confere.
- **Canal inexistente e `PlatformException`:** são tratados como nos pagamentos.

## Fluxos

### Pagamento e estorno

1. O Dart chama o canal. O handler monta o Intent pelo SDK e abre o app da Rede.
2. A resposta pendente só é guardada depois que o app abre. Se a abertura falha, o erro sai na hora.
3. Uma operação nova, enquanto outra espera, fica com o próximo retorno.
4. O `onActivityResult` (códigos 4 e 5) tira a resposta pendente antes de responder, e responde uma vez só.
5. A impressão nunca mexe na resposta pendente do pagamento.

### Impressão

1. A impressora do SDK é aberta uma vez por processo, com `IRedeSdk.getTerminalFunctions().getConnectorPrinter()`:
   - o `IRedeSdk.newInstance` lança "Already initialized!" na segunda chamada, e a `MainActivity` pode ser recriada com o processo vivo;
   - a integração a abre já ao configurar, porque o SDK liga o serviço de impressão de forma assíncrona; aberta só na hora, a primeira impressão caía em "Init failed";
   - cada integração registra o próprio callback;
   - se o SDK não abre, só a impressão responde `IMPRESSORA_INDISPONIVEL`, e a próxima impressão tenta abrir de novo. O pagamento não depende dela.
2. A impressão roda na main thread, como no plugin. O SDK segura o `printBitmap` enquanto confere a impressora (pronta, com papel) e entrega o bitmap ao serviço; os erros dessas checagens chegam pelo `onError` durante a chamada.
3. O handler guarda o primeiro erro e interrompe o SDK no callback, como o plugin. Se o callback só guardasse o erro, o SDK seguiria para a nova tentativa atrasada dele (`postDelayed` de 1 s, até 3 vezes): a NFC-e sairia em dobro, ou o app cairia na terceira vez. Um erro que o serviço avise depois do `printBitmap`, por outra thread, só vai para o log. Exceções e `LinkageError` viram erro de impressão.
4. O texto vira bitmap pela função comum, com 576 px, fonte monoespaçada 20 e as linhas como o `split` do Java.

## Divergências intencionais do plugin

1. **Centavos com `round()`.** O plugin usa `(amount * pow(10, 2)).toInt()`, que trunca: R$ 0,29 vira 28 centavos.
2. **Nova tentativa da impressão: uma por chamada.** A flag estática `_attempts` do plugin só volta a `false` com sucesso.
3. **Canal inexistente vira `<método>.not.implemented`.** O plugin captura `UnimplementedError`, mas o Flutter lança `MissingPluginException`.
4. **Exceção ao abrir o app da Rede responde erro.** No plugin, ela só ia para o log, e o Dart ficava esperando.
5. **`RESULT_OK` com dados mas sem pagamento responde `ERRO_DESCONHECIDO`.** O plugin não respondia.
6. **Resposta pendente separada da impressão.** O plugin guardava num campo só a resposta de qualquer chamada. Uma impressão durante o pagamento roubava o resultado dele.
7. **Argumento ausente responde e para.** O plugin respondia e seguia em frente:
   - com `bitmap` ou `text` nulo, caía num NPE;
   - com `nsu` nulo, o SDK lançava uma exceção que ia só para o log;
   - com `amount` nulo, caía direto num NPE, sem responder.
8. **A falha da impressora do SDK não afeta o pagamento.** O plugin a iniciava em toda chamada, inclusive nos pagamentos, e num aparelho sem o SDK até o pagamento falhava. Aqui ela é aberta ao configurar, protegida, e só a impressão responde o erro.
9. **"Printer not ready" e SDK que não abre viram `IMPRESSORA_INDISPONIVEL`.** No plugin, o primeiro virava `ERRO_DESCONHECIDO`. O segundo virava o erro genérico `error` do Flutter, com a stack trace como mensagem.
10. **Campo ausente ou nulo no recibo vira texto vazio ou 0.** No plugin, um AUTO nulo quebrava o Dart com erro de tipo, e um recibo nulo derrubava o app.
11. **Bytes que não formam imagem respondem `ERRO_DESCONHECIDO` no Dart, sem chamar o canal.** No plugin, o bitmap nulo ia ao SDK, e o NPE que ele lançava acabava respondido como `ERRO_DESCONHECIDO`.
12. **NFC-e pelo conversor, com 1 cm de margem.** O conversor entrega a primeira página com 384 pontos e sem o branco do PDF. O `centralizer` imprimia a página inteira.
13. **Falta de biblioteca na impressão (`LinkageError`) vira erro de impressão.** No plugin, o `Error` derrubava o app.
14. **Retorno que o SDK não consegue ler responde `ERRO_DESCONHECIDO`.** Um `BadParcelableException` ou `ClassCastException` no `getPaymentFromIntent` derrubava o app no plugin, e o Dart ficava sem resposta.

O release do flavor `rede` leva as regras `src/rede/proguard-rules.pro`, que mantêm as classes do AAR. O SDK desparcela o `Payment` com Gson, e sem elas o R8 apagava o status e o recibo: toda aprovação virava "Operação negada!". O PDV também vai precisar delas no flavor da Rede.

## Mantido igual ao plugin e ao `centralizer`

- Canal, métodos, argumentos, códigos, mensagens e chaves do resultado.
- `cardNumber` com o tipo da operação. O estorno aprovado volta com valores fixos: "Estorno", "refund", parcelas 1, valor 0.
- Só o status `AUTHORIZED` aprova, no pagamento e no estorno.
- Crédito só à vista.
- Nenhum comprovante automático depois do pagamento.
- Impressão síncrona na main thread.
- Texto em bitmap de 576 px com fonte 20, e "Impressao teste".
- Uma operação nova, enquanto outra espera, fica com o próximo retorno.
- Se o Android matar o app enquanto o da Rede está na frente, o retorno se perde. É o mesmo ponto em aberto da Stone e da Vero.

## Testes e verificação

### Dart (`core`)

- **`RedeTransactionResult.fromMap`:**
  - lê as seis chaves;
  - `INSTALLMENTS` inteiro vira texto;
  - `AMOUNT` inteiro ou decimal vira double;
  - campo ausente ou nulo vira texto vazio ou 0.
- **`RedePaymentService`, pagamentos:**
  - cada pagamento chama o método do plugin com centavos arredondados (0,29 → 29; 4,35 → 435; 33,30 → 3330);
  - o estorno manda o NSU;
  - NSU em branco não chama o Android;
  - erro do Android com código e mensagem, e o fallback de stack trace e do texto do erro;
  - canal inexistente;
  - resposta vazia.
- **`RedePaymentService`, impressão:**
  - nomes e argumentos do plugin;
  - `printReceipt` com 1 cm de margem;
  - bytes que não formam imagem não chamam o canal;
  - `printNfc` converte e imprime;
  - falha do conversor volta sem chamar o Android;
  - `IMPRESSORA_INDISPONIVEL` tenta de novo uma vez, e os outros códigos não;
  - nova tentativa que dá certo.
- **`withBottomMargin`:** a margem e o `Picture` liberado. Os testes do `NativePrinterService` continuam verdes.

### Dart (`example`)

- View model e tela da Rede, como os da Vero.
- `widget_test`: o flavor `rede` abre direto na tela da Rede.

### Kotlin (Robolectric, `src/testRede/`)

- **Pagamento, com o SDK falso:**
  - tipo, valor e código de cada pagamento, e o estorno com o NSU;
  - a resposta pendente só depois que o app abre;
  - cada linha da tabela de erros;
  - Pix com a autorização igual ao NSU;
  - emissor ausente vira "Pagamento " + tipo;
  - estorno com os valores fixos;
  - recibo nulo;
  - operação nova fica com o próximo retorno;
  - responde uma vez só;
  - exceções ao abrir o app, com e sem mensagem;
  - argumentos ausentes.
- **Leitura do retorno com o SDK de verdade:** um `Payment` real no extra `rede.smartrede.sdk.INTENT_EXTRAS_PAYMENT` é lido pelo adaptador.
- **Impressão, com a impressora falsa:**
  - sucesso;
  - "Printer out of paper", "Init failed", "Printer not ready" e outra mensagem;
  - `PrinterException` e `LinkageError`;
  - SDK que não abre;
  - argumentos ausentes;
  - a impressora é iniciada só na primeira impressão, e nunca num pagamento;
  - uma impressão durante um pagamento não responde por ele.
- **Integração:** o canal `rede_sdk` de ponta a ponta pelo `StandardMethodCodec`, e o `onActivityResult` chegando ao Dart.
- **Dependências:** `Class.forName` das classes que o AAR usa sem trazer:
  - `com.google.gson.Gson`;
  - `kotlinx.coroutines.BuildersKt`;
  - a fábrica do `Dispatchers.Main` (`kotlinx.coroutines.android.AndroidDispatcherFactory`);
  - `androidx.appcompat.app.AppCompatActivity`;
  - `androidx.activity.result.ActivityResultLauncher`;
  - `androidx.fragment.app.Fragment`.
- **Texto em bitmap** (`src/test/`): 576 px de largura, e as linhas como o `split` do Java.

### Builds e checagens

- **APK da Rede:** gerar o `app-rede-debug.apk` e conferir no manifest mesclado a `minSdkVersion` 28 e as permissões do AAR.
- **APKs dos outros flavors:** gerar os de release de stone, cielo, pagbank e vero e varrer por `smartrede`, `rede_sdk`, `br/com/positivo`, `com/pos/sdk` e `libPOS_EMV_Kernel`, sem diferenciar maiúsculas.
  - Nenhum deve aparecer. Antes desta migração, os quatro já estavam limpos.
  - O APK da Rede deve conter todos e serve de controle positivo.
- **Suítes:** core e example (`test`, `analyze`, `format`) e Kotlin dos cinco flavors, todos verdes.

### No L400

- Crédito, débito e Pix de R$ 1,00, e o estorno do último pelo NSU.
- NFC-e de teste e de homologação: conferir a última linha e se a margem sobra.
- Texto de teste, impressão de teste e impressão sem papel.

## Riscos e pontos em aberto

- **Impressão na main thread:** pode travar a tela numa impressão longa, como hoje.
- **Texto em 576 px numa impressora de 384 pontos:** como hoje.
- **Bibliotecas nativas:** o AAR só traz as de 32 bits (`armeabi` e `armeabi-v7a`). Se o L400 instalar o APK como 64 bits, elas faltam, como hoje no PDV.
- **Status do estorno:** só `AUTHORIZED` aprova, como no plugin. Se o app da Rede devolver outro status num estorno aprovado (`VOIDED` ou `REFUNDED`), aparece "Estorno negado!". Conferir no L400.
- **Margem de 1 cm:** pode sobrar, porque o SDK já avança 4 linhas.
- **Integração com o PDV Varejo:** depende da fachada `FlutterAcquirersSdk` e do empacotamento do nativo. O PDV também vai precisar das mesmas dependências (Gson, coroutines e appcompat) no flavor da Rede.
