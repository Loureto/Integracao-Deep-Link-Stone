package com.example.example.sipag

import android.content.Context

/**
 * Marca de operação pendente: ligada enquanto o app da adquirente está na frente, desligada quando a
 * operação responde. Se o app cair no meio, ela continua ligada, e a última operação sabe que há um resultado
 * a buscar.
 *
 * No plugin `flutter_sipag_sdk`, a marca ficava no `flutter_secure_storage` do Dart, com a mesma chave. A
 * gravação é síncrona (`commit`), porque o processo pode morrer logo depois de abrir o app da adquirente.
 */
internal class PendingOperationStore(context: Context) {

    private val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    val isPending: Boolean
        get() = preferences.getBoolean(KEY, false)

    fun markPending() {
        preferences.edit().putBoolean(KEY, true).commit()
    }

    fun clear() {
        preferences.edit().putBoolean(KEY, false).commit()
    }

    private companion object {
        const val PREFERENCES = "sipag_sdk"
        const val KEY = "has_error_on_last_operation"
    }
}
