
package com.example.example

import android.app.Activity
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger

/**
 * Integração nativa da adquirente do flavor (stone, cielo, pagbank, vero ou rede) com a [MainActivity]. Cada
 * flavor entrega a sua em `createAcquirerIntegration`, no próprio source set, então o APK leva só o código da
 * sua adquirente.
 */
internal interface AcquirerIntegration {

    /** Registra o canal da integração com o Dart. */
    fun configure(activity: Activity, messenger: BinaryMessenger)

    /** Intents que chegam à [MainActivity] já aberta, como os retornos de deep link. */
    fun onNewIntent(intent: Intent) = Unit

    /**
     * Resultados de `startActivityForResult` que chegam à [MainActivity], como o retorno do app da Vero.
     * Devolve se a integração tratou o [requestCode].
     */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean = false
}
