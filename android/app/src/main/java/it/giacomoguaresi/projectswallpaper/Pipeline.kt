package it.giacomoguaresi.projectswallpaper

import android.util.Log
import kotlinx.coroutines.delay
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/**
 * Fa rigenerare la foto alla pipeline, come il comando projectswallpaper dei PC:
 * chiama la funzione foresta-aggiorna su Supabase, che fa partire il workflow su
 * GitHub, e aspetta che info.json dica che c'è una foto nuova. Dopo, i download
 * soliti di Foto la trovano.
 */
object Pipeline {
    private const val FUNZIONE = "https://fvsohjlrulwabvfvcfxo.supabase.co/functions/v1/foresta-aggiorna"
    private const val INFO = "https://giacomoguaresi.github.io/ProjectsWallpaper/info.json"

    /** Un giro della pipeline, deploy compreso, dura un paio di minuti. */
    private const val ATTESA_MASSIMA_MS = 5 * 60_000L
    private const val INTERVALLO_MS = 5_000L

    /** Rete giù o funzione in errore: IOException. Foto nuova che non arriva in tempo: solo un avviso nel log. */
    suspend fun rigenera() {
        val prima = runCatching { generato() }.getOrNull()
        val stato = JSONObject(leggi(FUNZIONE, "POST")).optString("stato")
        Log.i(Foto.TAG, "pipeline: $stato")
        if (stato != "avviato" && stato != "in-corso") return

        val fine = System.currentTimeMillis() + ATTESA_MASSIMA_MS
        while (System.currentTimeMillis() < fine) {
            delay(INTERVALLO_MS)
            val ora = runCatching { generato() }.getOrNull()
            if (ora != null && ora != prima) {
                Log.i(Foto.TAG, "pipeline: foto nuova ($ora)")
                return
            }
        }
        Log.w(Foto.TAG, "pipeline: la foto nuova non è arrivata in tempo, scarico quella che c'è")
    }

    /** Il campo "generato" di info.json: cambia a ogni foto nuova. */
    private fun generato(): String = JSONObject(leggi(INFO, "GET")).getString("generato")

    private fun leggi(indirizzo: String, metodo: String): String {
        val connessione = URL(indirizzo).openConnection() as HttpURLConnection
        try {
            connessione.requestMethod = metodo
            connessione.connectTimeout = 30_000
            connessione.readTimeout = 30_000
            connessione.useCaches = false
            val codice = connessione.responseCode
            if (codice != HttpURLConnection.HTTP_OK) throw IOException("$indirizzo: HTTP $codice")
            return connessione.inputStream.bufferedReader().use { it.readText() }
        } finally {
            connessione.disconnect()
        }
    }
}
