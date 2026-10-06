// Fa partire la pipeline (workflow "Genera", genera.yml) con workflow_dispatch.
//
// Il cron di GitHub Actions è "best effort": spesso salta ore intere. L'orologio
// vero è pg_cron di Supabase, che chiama questa funzione ogni ora con ?orario
// (sql/foresta-aggiorna.sql). La chiamano anche il comando projectswallpaper dei
// PC e il tocco sul widget Android, per avere subito una foto nuova.
//
// È pubblica (verify_jwt = false): non legge né scrive dati, e al peggio fa
// partire la pipeline. Per non accodare giri inutili:
//   - se un giro è già in coda o in corso, non ne parte un altro;
//   - a mano, non prima di MINUTI_MANUALE dall'ultimo giro partito;
//   - ?orario, non se l'ultimo giro riuscito è di meno di MINUTI_ORARIO fa.
//
// Risponde { stato, dal }: "avviato" (giro partito ora), "in-corso" (c'è già un
// giro, partito "dal"), "recente" (l'ultimo giro è di "dal", basta quello).
//
// Secret GITHUB_DISPATCH_TOKEN: un token fine-grained solo per il repo
// ProjectsWallpaper, con il permesso Actions in lettura e scrittura.

const REPO = 'GiacomoGuaresi/ProjectsWallpaper'
const WORKFLOW = 'genera.yml'
const MINUTI_MANUALE = 3
const MINUTI_ORARIO = 20

type Giro = { status: string; conclusion: string | null; created_at: string }

async function github(percorso: string, opzioni: RequestInit = {}): Promise<Response> {
  return await fetch(`https://api.github.com/repos/${REPO}/actions/workflows/${WORKFLOW}/${percorso}`, {
    ...opzioni,
    headers: {
      Accept: 'application/vnd.github+json',
      Authorization: `Bearer ${Deno.env.get('GITHUB_DISPATCH_TOKEN')}`,
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'foresta-aggiorna',
    },
    signal: AbortSignal.timeout(10_000),
  })
}

const minutiFa = (data: string) => (Date.now() - Date.parse(data)) / 60_000

Deno.serve(async (richiesta) => {
  const json = (corpo: unknown, stato = 200) =>
    new Response(JSON.stringify(corpo), { status: stato, headers: { 'Content-Type': 'application/json' } })
  const orario = new URL(richiesta.url).searchParams.has('orario')

  try {
    const elenco = await github('runs?per_page=10')
    if (!elenco.ok) return json({ errore: `GitHub: HTTP ${elenco.status}` }, 502)
    const giri: Giro[] = (await elenco.json()).workflow_runs

    // Dal più recente: "queued", "in_progress", "waiting", "requested", "pending" sono tutti non finiti.
    const inCorso = giri.find((g) => g.status !== 'completed')
    if (inCorso) return json({ stato: 'in-corso', dal: inCorso.created_at })

    const ultimo = orario ? giri.find((g) => g.conclusion === 'success') : giri[0]
    if (ultimo && minutiFa(ultimo.created_at) < (orario ? MINUTI_ORARIO : MINUTI_MANUALE)) {
      return json({ stato: 'recente', dal: ultimo.created_at })
    }

    const avvio = await github('dispatches', { method: 'POST', body: JSON.stringify({ ref: 'main' }) })
    await avvio.body?.cancel()
    if (!avvio.ok) return json({ errore: `GitHub: HTTP ${avvio.status}` }, 502)
    return json({ stato: 'avviato', dal: new Date().toISOString() })
  } catch {
    return json({ errore: 'GitHub non ha risposto' }, 502)
  }
})
