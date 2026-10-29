
package com.example.example.vero

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.util.Log
import java.io.File

private const val TAG = "VeroBundle"

/**
 * Extras do retorno do app da Vero, para o Dart. Os comprovantes chegam como [Uri] e viram o caminho da cópia no
 * cache, como no `Utils.kt` do plugin `vero_flutter`; se a cópia falhar, o valor vai nulo. Os tipos que o codec do
 * Flutter não carrega, como Char, arrays e Parcelable, vão como texto: o Dart lê todos os campos como texto, e um
 * tipo desses derrubaria o app logo depois da cobrança.
 */
internal fun Bundle.toMap(context: Context): Map<String, Any?> = keySet().associateWith { key ->
    @Suppress("DEPRECATION")
    when (val value = get(key)) {
        null, is String, is Boolean, is Int, is Long, is Double -> value
        is Uri -> copyToCache(context, key, value)
        else -> value.toString()
    }
}

/** Valor do extra como texto, seja qual for o tipo em que o app da Vero o mandou. */
internal fun Bundle.textOf(key: String): String? {
    @Suppress("DEPRECATION")
    return get(key)?.toString()
}

/**
 * Copia o comprovante para a pasta do extra no cache, com o nome do arquivo da URI. A pasta separa comprovantes de
 * mesmo nome, e só o nome do arquivo entra no caminho: o lastPathSegment chega decodificado, e um `%2F..` subiria
 * pastas.
 */
private fun copyToCache(context: Context, key: String, uri: Uri): String? = try {
    val name = File(uri.lastPathSegment ?: error("URI sem nome de arquivo: $uri")).name
    val file = File(File(context.cacheDir, key), name)
    check(file.canonicalPath.startsWith(context.cacheDir.canonicalPath + File.separator)) {
        "Comprovante fora do cache: $uri"
    }
    file.parentFile!!.mkdirs()
    context.contentResolver.openInputStream(uri)!!.use { input ->
        file.outputStream().use { output -> input.copyTo(output) }
    }
    file.absolutePath
} catch (exception: Exception) {
    Log.w(TAG, "Não foi possível copiar o comprovante $uri.", exception)
    null
}
