package it.giacomoguaresi.projectswallpaper

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.core.content.edit

/**
 * Il widget con la foto della Foresta. Il sistema non lo aggiorna da sé
 * (updatePeriodMillis=0): ci pensa AggiornaForesta, ogni ora. Toccandolo si
 * rigenera la foto subito (AGGIORNA, il PendingIntent lo mette Disegno):
 * finché la foto nuova non arriva, il widget la mostra sfocata con una rotellina.
 *
 * Il lavoro periodico resta in coda finché c'è un widget: così WorkManager non
 * spegne e riaccende i suoi receiver, cosa che farebbe richiamare onUpdate a
 * vuoto dal launcher.
 */
class WidgetForesta : AppWidgetProvider() {

    override fun onEnabled(context: Context) {
        AggiornaForesta.programma(context)
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        // Subito la foto che c'è già, poi una che forse è più nuova.
        ids.forEach { Disegno.disegna(context, manager, it) }
        AggiornaForesta.programma(context)
        AggiornaForesta.subito(context)
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, opzioni: Bundle) {
        // Ridimensionato: la foto va ritagliata e ridotta per la misura nuova.
        Disegno.disegna(context, manager, id)
    }

    override fun onDisabled(context: Context) {
        AggiornaForesta.ferma(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == AGGIORNA) {
            // Subito la rotellina, prima ancora che il lavoro parta.
            rigenero(context, true)
            ridisegnaTutti(context)
            AggiornaForesta.aMano(context)
        } else {
            super.onReceive(context, intent)
        }
    }

    companion object {
        const val AGGIORNA = "it.giacomoguaresi.projectswallpaper.AGGIORNA"

        private const val PREFERENZE = "widget"
        private const val RIGENERO_DAL = "rigenero_dal"

        /**
         * Oltre l'attesa massima della pipeline e un download: se il lavoro muore a metà
         * (app chiusa a forza), al primo ridisegno la rotellina sparisce comunque.
         */
        private const val RIGENERO_MASSIMO_MS = 7 * 60_000L

        /** Se la pipeline sta rigenerando la foto per un tocco sul widget. */
        fun rigenero(context: Context): Boolean {
            val dal = context.getSharedPreferences(PREFERENZE, Context.MODE_PRIVATE).getLong(RIGENERO_DAL, 0)
            return System.currentTimeMillis() - dal < RIGENERO_MASSIMO_MS
        }

        fun rigenero(context: Context, si: Boolean) {
            context.getSharedPreferences(PREFERENZE, Context.MODE_PRIVATE).edit {
                if (si) putLong(RIGENERO_DAL, System.currentTimeMillis()) else remove(RIGENERO_DAL)
            }
        }

        fun ridisegnaTutti(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            manager.getAppWidgetIds(ComponentName(context, WidgetForesta::class.java))
                .forEach { Disegno.disegna(context, manager, it) }
        }
    }
}
