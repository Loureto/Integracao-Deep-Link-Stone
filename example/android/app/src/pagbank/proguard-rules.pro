# Regras do R8 do flavor pagbank, ligadas no build.gradle.kts. O build release do Flutter roda o R8 com minify.

# PagBank: o PlugPagServiceWrapper não traz regras próprias. Os retornos do PlugPagService chegam como
# Parcelable e Serializable, lidos pelo nome da classe e dos campos: se o R8 os renomear, a leitura falha.
-keep class br.com.uol.pagseguro.** { *; }

# Classes que o wrapper referencia sem trazer, e que fariam o R8 falhar por "Missing class":
# - RxJava 2 e RxAndroid 2: só as funções async* (pacote asyncplugpag) usam. Ver o build.gradle.kts.
# - Parcelize: anotação de compilação do antigo kotlin-android-extensions, que não existe em runtime.
-dontwarn io.reactivex.**
-dontwarn kotlinx.android.parcel.Parcelize
