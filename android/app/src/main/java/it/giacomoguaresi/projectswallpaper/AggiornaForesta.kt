package it.giacomoguaresi.projectswallpaper

import android.content.Context
import android.util.Log
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * Scarica foto e dati e, se qualcosa è nuovo, ridisegna i widget. Gira ogni ora finché c'è
 * almeno un widget, e una volta subito quando se ne aggiunge uno.
 */
class AggiornaForesta(context: Context, parametri: WorkerParameters) : CoroutineWorker(context, parametri) {

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        var nuovi = false
        var errore = false
        for (foto in Foto.entries) {
            try {
                if (foto.scarica(applicationContext)) {
                    Log.i(Foto.TAG, "${foto.nome}: nuovo")
                    nuovi = true
                } else {
                    Log.i(Foto.TAG, "${foto.nome}: invariato")
                }
            } catch (e: IOException) {
                Log.w(Foto.TAG, "download non riuscito: ${e.message}")
                errore = true
            }
        }
        if (nuovi) WidgetForesta.ridisegnaTutti(applicationContext)
        // Il giro periodico riprova tra un'ora; quello "subito" qualche volta prima.
        if (errore && PERIODICO !in tags && runAttemptCount < 3) Result.retry() else Result.success()
    }

    companion object {
        private const val PERIODICO = "foresta-periodico"
        private const val SUBITO = "foresta-subito"

        private val conRete = Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()

        /** Il giro orario; se c'è già, resta quello (KEEP) senza ripartire da zero. */
        fun programma(context: Context) {
            val richiesta = PeriodicWorkRequestBuilder<AggiornaForesta>(1, TimeUnit.HOURS)
                .setConstraints(conRete)
                .addTag(PERIODICO)
                .build()
            WorkManager.getInstance(context)
                .enqueueUniquePeriodicWork(PERIODICO, ExistingPeriodicWorkPolicy.KEEP, richiesta)
        }

        fun subito(context: Context) {
            val richiesta = OneTimeWorkRequestBuilder<AggiornaForesta>()
                .setConstraints(conRete)
                .build()
            WorkManager.getInstance(context).enqueueUniqueWork(SUBITO, ExistingWorkPolicy.KEEP, richiesta)
        }

        fun ferma(context: Context) {
            WorkManager.getInstance(context).run {
                cancelUniqueWork(PERIODICO)
                cancelUniqueWork(SUBITO)
            }
        }
    }
}
