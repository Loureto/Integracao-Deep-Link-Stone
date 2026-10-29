# SDK SmartRede do L400. O AAR não traz regras para o R8 (o proguard.txt dele é vazio).
#
# O Payment volta do app da Rede como JSON, desparcelado pelo Gson: o R8 não vê ninguém escrevendo status e
# recibo e apagava os dois, e a classe Receipt inteira. No release, toda aprovação virava "Operação negada!".
# O SDK também liga serviços da Positivo e do terminal por AIDL e injeção de dependências, então todas as
# classes que vêm no AAR ficam com nome e membros.
-keep class rede.smartrede.** { *; }
-keep class br.com.positivo.** { *; }
-keep class com.pos.** { *; }
-keep class com.emv.** { *; }
-keep class com.xcheng.** { *; }

# Anotação que o SDK usa só na compilação (kotlin-parcelize); o APK não a leva.
-dontwarn kotlinx.parcelize.Parcelize
