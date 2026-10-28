
package com.example.example

import android.app.Activity
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger

/**
 * Integração nativa da adquirente do flavor (stone, cielo ou pagbank) com a [MainActivity]. Cada flavor
 * entrega a sua em `createAcquirerIntegration`, no próprio source set, então o APK leva só o código da
 * sua adquirente.
 */
internal interface AcquirerIntegration {

    /** Registra o canal da integração com o Dart. */
    fun configure(activity: Activity, messenger: BinaryMessenger)

    /** Intents que chegam à [MainActivity] já aberta, como os retornos de deep link. */
    fun onNewIntent(intent: Intent) = Unit
}
