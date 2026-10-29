package com.example.example.rede

import android.content.Context
import rede.smartrede.commons.contract.IConnectorPrinter

/**
 * A impressora do SDK da Rede, aberta uma vez por processo. O `IRedeSdk.newInstance` lança "Already
 * initialized!" na segunda chamada, e a MainActivity, com a integração, pode ser recriada com o processo
 * vivo, como depois do "voltar". No plugin, o singleton `RuntimeCache` fazia esse papel.
 */
internal class ProcessPrinter(private val open: (Context) -> IConnectorPrinter) {

    private var printer: IConnectorPrinter? = null

    @Synchronized
    fun get(context: Context): IConnectorPrinter = printer ?: open(context).also { printer = it }
}
