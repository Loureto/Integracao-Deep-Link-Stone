# apix990 (DX8000 e X990): o TransactionData e o CreditInfo levam a anotação @Parcelize, que só existe na
# compilação, e o AAR não traz a biblioteca dela. Sem esta regra, o R8 parava o release com "Missing classes".
# O exemplo do plugin flutter_sipag_sdk tem a mesma.
-dontwarn kotlinx.parcelize.Parcelize
