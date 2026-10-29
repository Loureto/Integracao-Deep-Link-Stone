package com.example.example.printer

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface

/** Texto da impressão de teste, o mesmo do centralizer e do plugin da Rede. */
internal const val TEST_PRINT_TEXT = "Impressao teste"

/** Largura da bobina de 80 mm, como no centralizer; a impressora do terminal adapta. */
private const val PRINTER_80MM_WIDTH = 576

/**
 * Texto num bitmap para as impressoras que só recebem imagem, como o driver genérico e o SDK da Rede. Repete
 * o `textToBitmap` do centralizer e do plugin `flutter_rede_sdk`, que eram iguais.
 */
internal fun textToBitmap(text: String): Bitmap {
    val paint = Paint().apply {
        color = Color.BLACK
        textSize = 20f
        typeface = Typeface.MONOSPACE
        isAntiAlias = true
    }

    // Mesmas linhas do String.split do Java no centralizer: sem quebra, uma linha; com quebras, sem as linhas
    // vazias do fim.
    val lines = if ('\n' !in text) listOf(text) else text.split('\n').dropLastWhile { it.isEmpty() }

    val lineHeight = (paint.descent() - paint.ascent()).toInt()
    val height = lineHeight * lines.size + 20

    val bitmap = Bitmap.createBitmap(PRINTER_80MM_WIDTH, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    canvas.drawColor(Color.WHITE)

    var y = (-paint.ascent()).toInt()
    for (line in lines) {
        canvas.drawText(line, 0f, y.toFloat(), paint)
        y += lineHeight
    }

    return bitmap
}
