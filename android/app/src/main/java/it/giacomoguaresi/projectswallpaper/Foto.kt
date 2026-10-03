package it.giacomoguaresi.projectswallpaper

import android.content.Context
import android.graphics.BitmapFactory
import androidx.core.content.edit
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/**
 * I file che il widget scarica da GitHub Pages: la foto della Foresta e i dati
 * del pannello, entrambi rigenerati ogni ora dalla pipeline (pipeline/genera.ts).
 *
 * Come gli script dei PC (mac/aggiorna-sfondo.sh): ogni file si chiede solo se
 * è cambiato (If-Modified-Since), si scrive su un temporaneo e solo a buon fine
 * sostituisce il vecchio e ne ricorda la data. Se qualcosa va storto resta il
 * file di prima e il giro dopo riprova.
 */
enum class Foto(val nome: String, private val valido: (File) -> Boolean) {
    IMMAGINE("widget.png", { file ->
        val misure = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, misure)
        misure.outWidth > 0
    }),
    DATI("widget.json", { file -> runCatching { JSONObject(file.readText()) }.isSuccess });

    fun file(context: Context) = File(context.filesDir, nome)

    /** Scarica il file se è cambiato: true se ce n'è uno nuovo. Rete giù, HTTP non 200/304 o file rotto: IOException. */
    fun scarica(context: Context): Boolean {
        val file = file(context)
        val preferenze = context.getSharedPreferences(PREFERENZE, Context.MODE_PRIVATE)
        val chiave = "ultima_modifica_$nome"
        val connessione = URL(INDIRIZZO + nome).openConnection() as HttpURLConnection
        try {
            connessione.connectTimeout = 30_000
            connessione.readTimeout = 60_000
            connessione.useCaches = false
            val ultima = preferenze.getString(chiave, null)
            if (ultima != null && file.exists()) connessione.setRequestProperty("If-Modified-Since", ultima)

            when (val codice = connessione.responseCode) {
                HttpURLConnection.HTTP_NOT_MODIFIED -> return false
                HttpURLConnection.HTTP_OK -> Unit
                else -> throw IOException("$nome: HTTP $codice")
            }

            val temporaneo = File(context.filesDir, "$nome.tmp")
            connessione.inputStream.use { dati -> temporaneo.outputStream().use { dati.copyTo(it) } }
            if (!valido(temporaneo)) {
                temporaneo.delete()
                throw IOException("$nome: file non valido")
            }
            if (!temporaneo.renameTo(file)) throw IOException("$nome: non riesco a salvarlo")
            // Solo ora il file conta come "già visto".
            preferenze.edit { putString(chiave, connessione.getHeaderField("Last-Modified")) }
            return true
        } finally {
            connessione.disconnect()
        }
    }

    companion object {
        const val TAG = "ProjectsWallpaper"
        private const val INDIRIZZO = "https://giacomoguaresi.github.io/ProjectsWallpaper/"
        private const val PREFERENZE = "foto"
    }
}
