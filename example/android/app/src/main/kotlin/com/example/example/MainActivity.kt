
package com.example.example

import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import com.example.example.cielo.CieloRequestHandler
import com.example.example.cielo.CieloResponseHandler
import com.example.example.stone.payment.StonePaymentHandler
import com.example.example.stone.payment.StonePaymentResponseHandler

class MainActivity : FlutterActivity() {

    private lateinit var stoneScheme: String
    private lateinit var cieloScheme: String

    private lateinit var stonePaymentHandler: StonePaymentHandler
    private lateinit var stoneResponseHandler: StonePaymentResponseHandler
    private lateinit var cieloRequestHandler: CieloRequestHandler
    private lateinit var cieloResponseHandler: CieloResponseHandler

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        configureStone(messenger)
        configureCielo(messenger)
    }

    // Um canal por integração: no Dart, cada canal aceita um único handler para receber os retornos.
    private fun configureStone(messenger: BinaryMessenger) {
        stoneScheme = getString(R.string.scheme_return)
        val channel = MethodChannel(messenger, STONE_CHANNEL)

        stonePaymentHandler = StonePaymentHandler(this, stoneScheme)
        stoneResponseHandler = StonePaymentResponseHandler(stoneScheme) { response ->
            channel.invokeMethod(METHOD_ON_STONE_PAYMENT_RESPONSE, response)
        }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                METHOD_SEND_STONE_DEEP_LINK -> stonePaymentHandler.sendPayment(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun configureCielo(messenger: BinaryMessenger) {
        cieloScheme = getString(R.string.cielo_scheme_return)
        val channel = MethodChannel(messenger, CIELO_CHANNEL)

        cieloRequestHandler = CieloRequestHandler(this, cieloScheme)
        cieloResponseHandler = CieloResponseHandler(cieloScheme) { response ->
            channel.invokeMethod(METHOD_ON_CIELO_RESPONSE, response)
        }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                METHOD_SEND_CIELO_DEEP_LINK -> cieloRequestHandler.send(call, result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        if (intent.action != Intent.ACTION_VIEW) return

        when (val scheme = intent.data?.scheme) {
            stoneScheme -> stoneResponseHandler.handle(intent)
            cieloScheme -> cieloResponseHandler.handle(intent)
            else -> Log.w(TAG, "Retorno ignorado: o scheme $scheme não pertence a nenhuma integração.")
        }
    }

    companion object {
        private const val TAG = "MainActivity"

        private const val STONE_CHANNEL = "stoneDeeplinkChannel"
        private const val METHOD_SEND_STONE_DEEP_LINK = "sendStoneDeeplink"
        private const val METHOD_ON_STONE_PAYMENT_RESPONSE = "onStonePaymentResponse"

        private const val CIELO_CHANNEL = "cieloDeeplinkChannel"
        private const val METHOD_SEND_CIELO_DEEP_LINK = "sendCieloDeeplink"
        private const val METHOD_ON_CIELO_RESPONSE = "onCieloResponse"
    }
}
