package it.giacomoguaresi.projectswallpaper

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import androidx.core.graphics.scale
import org.json.JSONObject
import java.time.Duration
import java.time.Instant
import java.time.LocalTime
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Disegna un widget: la foto e il pannello coi dati. La carrellata non passa da
 * qui: sono animazioni del layout (res/anim/carrellata_*.xml) che fanno vagare la
 * foto, e le esegue il launcher.
 */
object Disegno {
    /** Quando il launcher non dice quanto è grande il widget: 4×3 celle, più o meno. */
    private const val LARGHEZZA_DP = 320
    private const val ALTEZZA_DP = 240

    /** Lo zoom più forte della carrellata (res/anim/carrellata_zoom.xml): la foto deve restare nitida. */
    private const val ZOOM_MASSIMO = 1.28f

    /** Quante volte dimezzare la foto per sfocarla: 5 è un trentaduesimo. */
    private const val GRADINI_SFOCATURA = 5

    /** Da questa misura in su (dp) stagione e card; sotto, solo ora e data. */
    private const val GRANDE_DP = 200

    /** Dopo quante ore il meteo è troppo vecchio per mostrarlo. */
    private val METEO_VALIDO = Duration.ofHours(3)

    /** Le icone Lucide della card del desktop (OverlaySfondo di Projects). */
    private val ICONE_CIELO = mapOf(
        "sereno" to R.drawable.ic_sole,
        "nuvoloso" to R.drawable.ic_nuvola,
        "nebbia" to R.drawable.ic_nebbia,
        "pioggia" to R.drawable.ic_pioggia,
        "temporale" to R.drawable.ic_temporale,
        "neve" to R.drawable.ic_neve,
    )

    /** Le fasi di nomeFaseLunare di Projects, nell'ordine dei disegni luna_0…luna_7. */
    private val FASI_LUNARI = listOf(
        "Luna nuova", "Falce crescente", "Primo quarto", "Gibbosa crescente",
        "Luna piena", "Gibbosa calante", "Ultimo quarto", "Falce calante",
    )
    private val DISEGNI_LUNA = listOf(
        R.drawable.luna_0, R.drawable.luna_1, R.drawable.luna_2, R.drawable.luna_3,
        R.drawable.luna_4, R.drawable.luna_5, R.drawable.luna_6, R.drawable.luna_7,
    )

    fun disegna(context: Context, manager: AppWidgetManager, id: Int) {
        val viste = RemoteViews(context.packageName, R.layout.widget_foresta)
        val opzioni = manager.getAppWidgetOptions(id)
        val rigenero = WidgetForesta.rigenero(context)
        val foto = foto(context, opzioni)?.let { if (rigenero) sfoca(it) else it }
        if (foto != null) {
            viste.setImageViewBitmap(R.id.foto, foto)
            viste.setViewVisibility(R.id.carrellata, View.VISIBLE)
            viste.setViewVisibility(R.id.attesa, View.GONE)
        }
        pannello(context, viste, grande(opzioni))
        viste.setViewVisibility(R.id.rigenero, if (rigenero) View.VISIBLE else View.GONE)
        viste.setOnClickPendingIntent(android.R.id.background, aggiorna(context))
        manager.updateAppWidget(id, viste)
    }

    /**
     * La foto ridotta quanto basta a coprire il widget allo zoom più forte
     * della carrellata, con le sue proporzioni: il taglio lo fa l'ImageView (centerCrop).
     * Più grande del necessario peserebbe sul limite di memoria dei RemoteViews.
     */
    private fun foto(context: Context, opzioni: Bundle): Bitmap? {
        val file = Foto.IMMAGINE.file(context)
        val misure = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, misure)
        if (misure.outWidth <= 0) return null

        // In verticale il widget è largo MIN_WIDTH e alto MAX_HEIGHT.
        val densita = context.resources.displayMetrics.density
        val larghezzaDp = opzioni.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH).takeIf { it > 0 } ?: LARGHEZZA_DP
        val altezzaDp = opzioni.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT).takeIf { it > 0 } ?: ALTEZZA_DP
        val larghezza = larghezzaDp * densita * ZOOM_MASSIMO
        val altezza = altezzaDp * densita * ZOOM_MASSIMO

        val scala = max(larghezza / misure.outWidth, altezza / misure.outHeight)
        var campione = 1
        while (scala * campione * 2 <= 1f) campione *= 2
        val foto = BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply { inSampleSize = campione })
            ?: return null
        val finale = scala * campione
        if (finale >= 1f) return foto
        return foto.scale((foto.width * finale).roundToInt(), (foto.height * finale).roundToInt())
    }

    /**
     * La foto sfocata mentre si rigenera: i RemoteViews non hanno filtri, quindi la si
     * rimpicciolisce molto e la si riporta alla sua misura, dimezzando e raddoppiando a
     * gradini: in un passo solo il filtro bilineare lascerebbe i quadretti.
     */
    private fun sfoca(foto: Bitmap): Bitmap {
        var sfocata = foto
        repeat(GRADINI_SFOCATURA) { sfocata = sfocata.scale(max(1, sfocata.width / 2), max(1, sfocata.height / 2)) }
        repeat(GRADINI_SFOCATURA - 1) { sfocata = sfocata.scale(sfocata.width * 2, sfocata.height * 2) }
        return sfocata.scale(foto.width, foto.height)
    }

    /** In verticale il widget è largo MIN_WIDTH e alto MAX_HEIGHT. */
    private fun grande(opzioni: Bundle): Boolean {
        val larghezza = opzioni.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH).takeIf { it > 0 } ?: LARGHEZZA_DP
        val altezza = opzioni.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT).takeIf { it > 0 } ?: ALTEZZA_DP
        return larghezza >= GRANDE_DP && altezza >= GRANDE_DP
    }

    /**
     * Grande: ora, data e stagione in alto; nella card meteo, sole e luna,
     * alberi, boschetti e arbusti, avanzamento e alberi della settimana.
     * Piccolo: solo ora e data, la data più piccola perché ci stia.
     * Il meteo vecchio di più di METEO_VALIDO non si mostra; il resto sì.
     */
    private fun pannello(context: Context, viste: RemoteViews, grande: Boolean) {
        val dati = runCatching { JSONObject(Foto.DATI.file(context).readText()) }.getOrNull()
        val generato = dati?.let { runCatching { Instant.parse(it.getString("generato")) }.getOrNull() }
        val fresco = generato != null && Duration.between(generato, Instant.now()) < METEO_VALIDO

        fun mostra(vararg viste_: Int) = viste_.forEach { viste.setViewVisibility(it, View.VISIBLE) }
        /** Il testo e le viste che vanno con lui (riga, icona), solo se c'è. */
        fun testo(vista: Int, valore: String?, vararg insieme: Int): Boolean {
            if (valore.isNullOrEmpty()) return false
            viste.setTextViewText(vista, valore)
            mostra(vista, *insieme)
            return true
        }
        fun icona(vista: Int, disegno: Int?) {
            if (disegno == null) return
            viste.setImageViewResource(vista, disegno)
            mostra(vista)
        }

        mostra(R.id.intestazione)
        if (!grande) {
            viste.setTextViewTextSize(R.id.data, TypedValue.COMPLEX_UNIT_SP, 12f)
            return
        }
        if (dati == null) return

        val temperatura = dati.optIntOrNull("temperatura")?.takeIf { fresco }?.let { "$it°" }
        val cielo = dati.optStringOrNull("cielo")?.takeIf { fresco }
        val alberi = dati.optIntOrNull("alberi")?.let { plurale(it, "albero", "alberi") }
        val percentuale = dati.optIntOrNull("percentuale")
        if (fresco) icona(R.id.icona_cielo, iconaCielo(dati))

        mostra(R.id.pannello)
        testo(R.id.stagione, dati.optStringOrNull("stagione")?.let { " · $it" })
        testo(R.id.meteo, listOfNotNull(temperatura, cielo).joinToString(" · "), R.id.riga_meteo)

        testo(R.id.alba, dati.optStringOrNull("alba"), R.id.riga_sole, R.id.icona_alba)
        testo(R.id.tramonto, dati.optStringOrNull("tramonto"), R.id.riga_sole, R.id.icona_tramonto)
        val luna = dati.optStringOrNull("luna")
        if (testo(R.id.luna, luna, R.id.riga_sole)) icona(R.id.icona_luna, DISEGNI_LUNA.getOrNull(FASI_LUNARI.indexOf(luna)))

        testo(R.id.numeri, listOfNotNull(
            alberi,
            dati.optIntOrNull("boschetti")?.let { plurale(it, "boschetto", "boschetti") },
            dati.optIntOrNull("arbusti")?.let { plurale(it, "arbusto", "arbusti") },
        ).joinToString(" · "), R.id.riga_numeri)

        if (percentuale != null) {
            viste.setProgressBar(R.id.barra, 100, percentuale, false)
            val settimana = dati.optIntOrNull("settimana")?.takeIf { it > 0 }
            testo(R.id.percentuale, listOfNotNull("$percentuale%", settimana?.let { "+$it in settimana" }).joinToString(" · "),
                R.id.avanzamento)
        }
    }

    private fun plurale(n: Int, uno: String, tanti: String) = "$n ${if (n == 1) uno else tanti}"

    /** Come sul desktop: di notte col cielo sereno la luna, non il sole. */
    private fun iconaCielo(dati: JSONObject): Int? {
        val cielo = dati.optStringOrNull("cielo") ?: return null
        if (cielo == "sereno") {
            val alba = runCatching { LocalTime.parse(dati.getString("alba")) }.getOrNull()
            val tramonto = runCatching { LocalTime.parse(dati.getString("tramonto")) }.getOrNull()
            val adesso = LocalTime.now()
            if (alba != null && tramonto != null && (adesso < alba || adesso > tramonto)) return R.drawable.ic_luna
        }
        return ICONE_CIELO[cielo]
    }

    private fun JSONObject.optIntOrNull(nome: String): Int? = if (has(nome) && !isNull(nome)) optInt(nome) else null

    private fun JSONObject.optStringOrNull(nome: String): String? = optString(nome).takeIf { has(nome) && !isNull(nome) && it.isNotEmpty() }

    /** Il tocco sul widget: rigenera la foto (WidgetForesta.onReceive). */
    private fun aggiorna(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        Intent(context, WidgetForesta::class.java).setAction(WidgetForesta.AGGIORNA),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )
}
