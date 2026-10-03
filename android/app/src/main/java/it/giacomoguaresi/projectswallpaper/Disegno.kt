package it.giacomoguaresi.projectswallpaper

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import androidx.core.graphics.scale
import androidx.core.net.toUri
import org.json.JSONObject
import java.time.Duration
import java.time.Instant
import java.time.LocalTime
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Disegna un widget: la foto e il pannello coi dati. La carrellata non passa da
 * qui: è un'animazione del layout (res/anim/carrellata.xml) che fa scorrere la
 * foto, e la esegue il launcher.
 */
object Disegno {
    private const val FORESTA = "https://giacomoguaresi.github.io/Projects/#/foresta"

    /** Quando il launcher non dice quanto è grande il widget: 4×3 celle, più o meno. */
    private const val LARGHEZZA_DP = 320
    private const val ALTEZZA_DP = 240

    /** Dopo quante ore il meteo è troppo vecchio per mostrarlo. */
    private val METEO_VALIDO = Duration.ofHours(3)

    private val ICONE_CIELO = mapOf(
        "sereno" to "☀️",
        "nuvoloso" to "☁️",
        "nebbia" to "🌫️",
        "pioggia" to "🌧️",
        "temporale" to "⛈️",
        "neve" to "❄️",
    )

    fun disegna(context: Context, manager: AppWidgetManager, id: Int) {
        val viste = RemoteViews(context.packageName, R.layout.widget_foresta)
        val foto = foto(context, manager.getAppWidgetOptions(id))
        if (foto != null) {
            viste.setImageViewBitmap(R.id.foto, foto)
            viste.setViewVisibility(R.id.carrellata, View.VISIBLE)
            viste.setViewVisibility(R.id.attesa, View.GONE)
        }
        pannello(context, viste)
        viste.setOnClickPendingIntent(android.R.id.background, apriForesta(context))
        manager.updateAppWidget(id, viste)
    }

    /**
     * La foto ridotta quanto basta a coprire il widget più il margine in cui
     * scorre, con le sue proporzioni: il taglio lo fa l'ImageView (centerCrop).
     * Più grande del necessario peserebbe sul limite di memoria dei RemoteViews.
     */
    private fun foto(context: Context, opzioni: Bundle): Bitmap? {
        val file = Foto.IMMAGINE.file(context)
        val misure = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, misure)
        if (misure.outWidth <= 0) return null

        // In verticale il widget è largo MIN_WIDTH e alto MAX_HEIGHT.
        val risorse = context.resources
        val densita = risorse.displayMetrics.density
        val larghezzaDp = opzioni.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH).takeIf { it > 0 } ?: LARGHEZZA_DP
        val altezzaDp = opzioni.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT).takeIf { it > 0 } ?: ALTEZZA_DP
        val larghezza = larghezzaDp * densita + 2 * risorse.getDimension(R.dimen.margine_carrellata)
        val altezza = altezzaDp * densita

        val scala = max(larghezza / misure.outWidth, altezza / misure.outHeight)
        var campione = 1
        while (misure.outWidth * scala * campione * 2 <= misure.outWidth) campione *= 2
        val foto = BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply { inSampleSize = campione })
            ?: return null
        val finale = scala * campione
        if (finale >= 1f) return foto
        return foto.scale((foto.width * finale).roundToInt(), (foto.height * finale).roundToInt())
    }

    /** Giorno (TextClock), meteo se è fresco, alberi e percentuale. Senza dati, nascosto. */
    private fun pannello(context: Context, viste: RemoteViews) {
        val dati = runCatching { JSONObject(Foto.DATI.file(context).readText()) }.getOrNull() ?: return
        val generato = runCatching { Instant.parse(dati.getString("generato")) }.getOrNull() ?: return

        val meteo = if (Duration.between(generato, Instant.now()) < METEO_VALIDO) {
            listOfNotNull(
                icona(dati),
                dati.optIntOrNull("temperatura")?.let { "$it°" },
            ).joinToString(" ")
        } else {
            ""
        }
        if (meteo.isNotEmpty()) {
            viste.setTextViewText(R.id.meteo, " · $meteo")
            viste.setViewVisibility(R.id.meteo, View.VISIBLE)
        }

        val numeri = listOfNotNull(
            dati.optIntOrNull("alberi")?.let { if (it == 1) "1 albero" else "$it alberi" },
            dati.optIntOrNull("percentuale")?.let { "$it%" },
        )
        if (numeri.isNotEmpty()) {
            viste.setTextViewText(R.id.numeri, "🌳 " + numeri.joinToString(" · "))
            viste.setViewVisibility(R.id.numeri, View.VISIBLE)
        }
        viste.setViewVisibility(R.id.pannello, View.VISIBLE)
    }

    /** Come sul desktop: di notte col cielo sereno la luna, non il sole. */
    private fun icona(dati: JSONObject): String? {
        val cielo = dati.optString("cielo").takeIf { it.isNotEmpty() } ?: return null
        if (cielo == "sereno") {
            val alba = runCatching { LocalTime.parse(dati.getString("alba")) }.getOrNull()
            val tramonto = runCatching { LocalTime.parse(dati.getString("tramonto")) }.getOrNull()
            val adesso = LocalTime.now()
            if (alba != null && tramonto != null && (adesso < alba || adesso > tramonto)) return "🌙"
        }
        return ICONE_CIELO[cielo]
    }

    private fun JSONObject.optIntOrNull(nome: String): Int? = if (has(nome) && !isNull(nome)) optInt(nome) else null

    private fun apriForesta(context: Context): PendingIntent = PendingIntent.getActivity(
        context,
        0,
        Intent(Intent.ACTION_VIEW, FORESTA.toUri()),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )
}
