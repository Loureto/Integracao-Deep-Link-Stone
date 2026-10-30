# Driver genérico (posmpapi), comum aos flavors que imprimem por ele (vero e sipag). Ele cita os SDKs de
# impressão de vários fabricantes, mas só usa o do terminal em que roda, escolhido pelo modelo. O APK não
# leva esses SDKs, e sem estas regras o R8 parava o release com "Missing classes". O proguard-rules.pro do
# PDV Varejo tem as mesmas.
-dontwarn br.com.gertec.gedi.**
-dontwarn br.com.tectoy.**
-dontwarn br.com.tectoylib.**
-dontwarn com.clover.sdk.**
-dontwarn com.newland.**
-dontwarn com.perto.pos.**
-dontwarn com.wizarpos.htmllibrary.**
-dontwarn com.xcheng.printerservice.**
