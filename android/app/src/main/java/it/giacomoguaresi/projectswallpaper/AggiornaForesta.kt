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
import androidx.work.workDataOf
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONException
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * Scarica foto e dati e, se qualcosa è nuovo, ridisegna i widget. Gira ogni ora finché c'è
 * almeno un widget, una volta subito quando se ne aggiunge uno, e quando si tocca il widget:
 * allora prima fa rigenerare la foto alla pipeline e aspetta che sia pubblicata.
 */
class AggiornaForesta(context: Context, parametri: WorkerParameters) : CoroutineWorker(context, parametri) {

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        // Solo al primo tentativo: se poi è il download a non riuscire, la foto nuova c'è già.
        if (inputData.getBoolean(RIGENERA, false) && runAttemptCount == 0) {
            try {
                Pipeline.rigenera()
            } catch (e: IOException) {
                Log.w(Foto.TAG, "pipeline non avviata: ${e.message}")
            } catch (e: JSONException) {
                Log.w(Foto.TAG, "pipeline: risposta inattesa: ${e.message}")
            }
        }
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
        private const val A_MANO = "foresta-a-mano"
        private const val RIGENERA = "rigenera"

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

        /** Dal tocco sul widget: foto rigenerata adesso. Toccarlo di nuovo mentre aspetta non ne accoda un altro. */
        fun aMano(context: Context) {
            val richiesta = OneTimeWorkRequestBuilder<AggiornaForesta>()
                .setConstraints(conRete)
                .setInputData(workDataOf(RIGENERA to true))
                .build()
            WorkManager.getInstance(context).enqueueUniqueWork(A_MANO, ExistingWorkPolicy.KEEP, richiesta)
        }

        fun ferma(context: Context) {
            WorkManager.getInstance(context).run {
                cancelUniqueWork(PERIODICO)
                cancelUniqueWork(SUBITO)
                cancelUniqueWork(A_MANO)
            }
        }
    }
}
