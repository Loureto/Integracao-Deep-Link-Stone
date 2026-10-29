package com.example.example.rede

import org.junit.Test

/**
 * Bibliotecas que o SDK da Rede usa sem trazer no AAR: o flavor precisa levá-las. O teste vê o classpath do
 * teste unitário; a presença no APK de verdade se confere no dex, como na Tarefa 8 do plano da Rede.
 */
class RedeDependenciesTest {

    @Test
    fun `o flavor leva as classes que o SDK da Rede usa sem trazer no AAR`() {
        // O Gson lê o pagamento que volta do app da Rede, e a impressora do L400 roda em runBlocking; sem
        // estas classes, o pagamento e a impressão lançam NoClassDefFoundError. No PDV Varejo, elas vinham de
        // outros plugins.
        listOf(
            "com.google.gson.Gson",
            "kotlinx.coroutines.BuildersKt",
            "kotlinx.coroutines.android.AndroidDispatcherFactory",
            "androidx.appcompat.app.AppCompatActivity",
            "androidx.activity.result.ActivityResultLauncher",
            "androidx.fragment.app.Fragment"
        ).forEach { Class.forName(it, false, javaClass.classLoader) }
    }
}
