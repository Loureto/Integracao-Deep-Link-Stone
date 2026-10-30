package com.example.example.sipag

import org.junit.Test

/**
 * Classes que os SDKs da Sipag e o driver genérico usam: o flavor precisa levá-las. O teste vê o classpath do
 * teste unitário; a presença no APK de verdade se confere no dex, como na Tarefa 8 do plano da Sipag.
 */
class SipagDependenciesTest {

    @Test
    fun `o flavor leva as classes que os AARs da Sipag e o driver usam sem trazer`() {
        // O apix990 lê o resultado do app Sicoob em coroutines e confere a permissão com o androidx.core; o
        // posmpapi imprime no P2 pela biblioteca da Sunmi. No PDV Varejo, elas vinham dos plugins.
        listOf(
            "printx990.br.apix990.internal.TransactionInfo",
            "ger7.com.br.pos7api.POS7API",
            "kotlinx.coroutines.Dispatchers",
            "androidx.core.content.ContextCompat",
            "androidx.core.app.ActivityCompat",
            "com.sunmi.peripheral.printer.InnerPrinterManager"
        ).forEach { Class.forName(it, false, javaClass.classLoader) }
    }
}
