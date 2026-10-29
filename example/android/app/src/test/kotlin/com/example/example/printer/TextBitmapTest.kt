package com.example.example.printer

import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * O Robolectric só desenha texto de verdade (modo NATIVE) a partir da API 26, então este teste roda só na
 * API 30 do robolectric.properties. Ele vale para todos os flavors, como a função.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [30])
class TextBitmapTest {

    @Test
    fun `desenha em 576 px com uma linha por quebra`() {
        val one = textToBitmap("A")
        val line = one.height - 20

        assertEquals(576, one.width)
        assertEquals(2 * line + 20, textToBitmap("A\nB").height)
    }

    @Test
    fun `separa as linhas como o split do Java`() {
        // Linhas vazias do fim saem; só quebras não deixam linha; sem quebra, o texto é uma linha.
        assertEquals(textToBitmap("A").height, textToBitmap("A\n\n").height)
        assertEquals(20, textToBitmap("\n").height)
        assertEquals(textToBitmap("A").height, textToBitmap("").height)
    }
}
