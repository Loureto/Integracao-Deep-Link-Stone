
package com.example.example.cielo

/**
 * Ações do deep link `lio://` da Cielo Smart. O valor também é o host do `urlCallback`, então o retorno
 * informa a ação que o originou. Cada host precisa estar no intent-filter da Cielo no AndroidManifest.
 */
internal enum class CieloAction(val value: String, val requiresRequest: Boolean = true) {
    PAYMENT("payment"),
    PAYMENT_REVERSAL("payment-reversal"),
    PRINT("print"),
    ORDER("order"),
    ORDERS("orders"),
    ENABLED_PRODUCTS("enabledproducts"),
    ESTABLISHMENTS("establishments"),

    // Pela documentação, a consulta do terminal é chamada sem o parâmetro `request`.
    TERMINAL_INFO("terminalinfo", requiresRequest = false);

    companion object {
        fun fromValue(value: String?): CieloAction? = entries.firstOrNull { it.value == value }
    }
}
