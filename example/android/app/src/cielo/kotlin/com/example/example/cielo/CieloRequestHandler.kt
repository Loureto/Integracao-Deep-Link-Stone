
package com.example.example.cielo

import android.app.Activity
import android.content.ActivityNotFoundException
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Recebe a [Activity] porque a Cielo é aberta sem FLAG_ACTIVITY_NEW_TASK, como na documentação, e fora de
 * uma Activity o Android exige essa flag.
 */
internal class CieloRequestHandler(
    private val activity: Activity,
    returnScheme: String
) {

    private val deepLinkBuilder = CieloDeepLinkBuilder(returnScheme)

    fun send(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        val intent = try {
            val action = CieloAction.fromValue(call.argument<String>(ACTION))
                ?: throw IllegalArgumentException(
                    "action inválida. Valores aceitos: ${CieloAction.entries.map { it.value }}."
                )

            deepLinkBuilder.build(action, call.argument<String>(REQUEST))
        } catch (exception: IllegalArgumentException) {
            result.error("INVALID_ARGUMENT", exception.message, null)
            return
        } catch (exception: ClassCastException) {
            result.error("INVALID_ARGUMENT", "Tipo de argumento inválido.", null)
            return
        }

        try {
            activity.startActivity(intent)

            // Só a ação: o request leva o accessToken e não deve ir para o log.
            Log.d(TAG, "Deep link iniciado: lio://${intent.data?.authority}")
            result.success(true)
        } catch (exception: ActivityNotFoundException) {
            result.error(
                "PAYMENT_APP_NOT_FOUND",
                "Nenhum aplicativo da Cielo disponível para processar a operação.",
                null
            )
        } catch (exception: Exception) {
            Log.e(TAG, "Erro ao iniciar a operação Cielo.", exception)

            result.error(
                "PAYMENT_START_ERROR",
                exception.message ?: "Não foi possível abrir o app da Cielo.",
                null
            )
        }
    }

    companion object {
        private const val TAG = "CieloRequestHandler"
        private const val ACTION = "action"
        private const val REQUEST = "request"
    }
}
