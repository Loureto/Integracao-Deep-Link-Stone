package com.example.example.printer

import org.junit.Test

/** Bibliotecas de fabricante que o posmpapi chama sem trazer no AAR: o flavor precisa levá-las. */
class PosmpDependenciesTest {

    @Test
    fun `o flavor leva as classes da Sunmi que o posmpapi usa no P2`() {
        // Sem elas, o Printer.getInstance lança NoClassDefFoundError no P2, e a primeira impressão é o comprovante
        // de um pagamento já aprovado. No PDV Varejo, a biblioteca vinha do plugin vero_flutter.
        listOf(
            "InnerPrinterCallback",
            "InnerPrinterException",
            "InnerPrinterManager",
            "InnerResultCallback",
            "SunmiPrinterService"
        ).forEach { Class.forName("com.sunmi.peripheral.printer.$it", false, javaClass.classLoader) }
    }
}
