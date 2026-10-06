package it.giacomoguaresi.projectswallpaper

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.Toast

/**
 * Il widget con la foto della Foresta. Il sistema non lo aggiorna da sé
 * (updatePeriodMillis=0): ci pensa AggiornaForesta, ogni ora. Toccandolo si
 * rigenera la foto subito (AGGIORNA, il PendingIntent lo mette Disegno).
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
            Toast.makeText(context, R.string.widget_aggiorno, Toast.LENGTH_SHORT).show()
            AggiornaForesta.aMano(context)
        } else {
            super.onReceive(context, intent)
        }
    }

    companion object {
        const val AGGIORNA = "it.giacomoguaresi.projectswallpaper.AGGIORNA"

        fun ridisegnaTutti(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            manager.getAppWidgetIds(ComponentName(context, WidgetForesta::class.java))
                .forEach { Disegno.disegna(context, manager, it) }
        }
    }
}
