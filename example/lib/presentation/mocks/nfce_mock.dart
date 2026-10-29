/// NFC-e padrão dos testes de impressão, a mesma em todas as adquirentes. O cupom é fictício, sem dados de
/// nenhuma empresa nem valor fiscal.
abstract final class NfceMock {
  /// Cupom em texto com 42 colunas, as da fonte condensada (9 x 17 pontos) na bobina de 58 mm dos
  /// terminais. As colunas se alinham por espaços, para fonte monoespaçada.
  static const text = """
        SUPERMERCADO EXEMPLO LTDA
         CNPJ: 12.345.678/0001-90
    Av. Central, 123 - Centro - SP/SP
           Tel: (11) 1234-5678

------------------------------------------
CUPOM FISCAL - NAO E DOCUMENTO FISCAL
------------------------------------------

ITEM   DESCRICAO                QTD  VALOR
1      ARROZ 5KG                 1   25,90
2      FEIJAO 1KG                2   12,00
3      REFRIGERANTE 2L           1    8,50
4      PÃO FRANCES               5    5,00
------------------------------------------
TOTAL                             R\$ 51,40
------------------------------------------

FORMA DE PAGAMENTO
CREDITO                           R\$ 51,40
------------------------------------------

    *** OBRIGADO PELA PREFERENCIA ***

DATA: 25/09/2025   HORA: 21:45


""";

  /// [text] num PDF de 80 mm de largura, em base64, como a API entrega a nota emitida. Na conversão para a
  /// bobina de 58 mm, a Courier Bold de 8,8 pt fica com 9 x 17 pontos por letra. Ela é monoespaçada, para
  /// as colunas ficarem alinhadas, e tem traços grossos, que a impressora térmica não apaga.
  static const pdf =
      'JVBERi0xLjQKJeLjz9MKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgPj4KZW5kb2JqCjIgMCBvYmoK'
      'PDwgL1R5cGUgL1BhZ2VzIC9LaWRzIFszIDAgUl0gL0NvdW50IDEgPj4KZW5kb2JqCjMgMCBvYmoKPDwgL1R5cGUgL1BhZ2Ug'
      'L1BhcmVudCAyIDAgUiAvTWVkaWFCb3ggWzAgMCAyMjYuNzcgMzE3LjAwXSAvQ29udGVudHMgNCAwIFIgL1Jlc291cmNlcyA8'
      'PCAvRm9udCA8PCAvRjEgNSAwIFIgPj4gPj4gPj4KZW5kb2JqCjQgMCBvYmoKPDwgL0xlbmd0aCAxMDA5ID4+CnN0cmVhbQpC'
      'VAovRjEgOC44IFRmCjExLjAgVEwKMSAwIDAgMSAyLjUwIDI5OC4yMCBUbQooICAgICAgICBTVVBFUk1FUkNBRE8gRVhFTVBM'
      'TyBMVERBKSBUaiBUKgooICAgICAgICAgQ05QSjogMTIuMzQ1LjY3OC8wMDAxLTkwKSBUaiBUKgooICAgIEF2LiBDZW50cmFs'
      'LCAxMjMgLSBDZW50cm8gLSBTUC9TUCkgVGogVCoKKCAgICAgICAgICAgVGVsOiBcKDExXCkgMTIzNC01Njc4KSBUaiBUKgpU'
      'KgooLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tKSBUaiBUKgooQ1VQT00gRklTQ0FMIC0gTkFP'
      'IEUgRE9DVU1FTlRPIEZJU0NBTCkgVGogVCoKKC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLSkg'
      'VGogVCoKVCoKKElURU0gICBERVNDUklDQU8gICAgICAgICAgICAgICAgUVREICBWQUxPUikgVGogVCoKKDEgICAgICBBUlJP'
      'WiA1S0cgICAgICAgICAgICAgICAgIDEgICAyNSw5MCkgVGogVCoKKDIgICAgICBGRUlKQU8gMUtHICAgICAgICAgICAgICAg'
      'IDIgICAxMiwwMCkgVGogVCoKKDMgICAgICBSRUZSSUdFUkFOVEUgMkwgICAgICAgICAgIDEgICAgOCw1MCkgVGogVCoKKDQg'
      'ICAgICBQw08gRlJBTkNFUyAgICAgICAgICAgICAgIDUgICAgNSwwMCkgVGogVCoKKC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t'
      'LS0tLS0tLS0tLS0tLS0tLS0tLSkgVGogVCoKKFRPVEFMICAgICAgICAgICAgICAgICAgICAgICAgICAgICBSJCA1MSw0MCkg'
      'VGogVCoKKC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLSkgVGogVCoKVCoKKEZPUk1BIERFIFBB'
      'R0FNRU5UTykgVGogVCoKKENSRURJVE8gICAgICAgICAgICAgICAgICAgICAgICAgICBSJCA1MSw0MCkgVGogVCoKKC0tLS0t'
      'LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLSkgVGogVCoKVCoKKCAgICAqKiogT0JSSUdBRE8gUEVMQSBQ'
      'UkVGRVJFTkNJQSAqKiopIFRqIFQqClQqCihEQVRBOiAyNS8wOS8yMDI1ICAgSE9SQTogMjE6NDUpIFRqIFQqClQqClQqCkVU'
      'CmVuZHN0cmVhbQplbmRvYmoKNSAwIG9iago8PCAvVHlwZSAvRm9udCAvU3VidHlwZSAvVHlwZTEgL0Jhc2VGb250IC9Db3Vy'
      'aWVyLUJvbGQgL0VuY29kaW5nIC9XaW5BbnNpRW5jb2RpbmcgPj4KZW5kb2JqCnhyZWYKMCA2CjAwMDAwMDAwMDAgNjU1MzUg'
      'ZiAKMDAwMDAwMDAxNSAwMDAwMCBuIAowMDAwMDAwMDY0IDAwMDAwIG4gCjAwMDAwMDAxMjEgMDAwMDAgbiAKMDAwMDAwMDI1'
      'MyAwMDAwMCBuIAowMDAwMDAxMzE0IDAwMDAwIG4gCnRyYWlsZXIKPDwgL1NpemUgNiAvUm9vdCAxIDAgUiA+PgpzdGFydHhy'
      'ZWYKMTQxNAolJUVPRgo=';
}
