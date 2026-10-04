/**
 * Fotografa la Foresta di Projects e salva le PNG da usare come sfondo.
 *
 * Apre `#/foresta?sfondo` (la modalità sfondo di Projects: solo la scena, senza
 * interfaccia), entra con la passphrase se serve, aspetta `data-sfondo-pronto`
 * su `<html>` e scatta una foto per ogni formato. Il browser è a Roma e con
 * "riduci movimento": la luce segue l'ora italiana e la scena sta ferma.
 *
 * Uso: FORESTA_PASSPHRASE=… npm run genera  →  uscita/<formato>.png
 * Per provare contro `npm run dev` di Projects:
 *   FORESTA_INDIRIZZO=http://localhost:5173/Projects/ npm run genera
 */
import { mkdirSync, writeFileSync } from 'node:fs'
import { chromium, type Browser, type Page } from 'playwright'

const INDIRIZZO = process.env.FORESTA_INDIRIZZO ?? 'https://giacomoguaresi.github.io/Projects/'
const PASSPHRASE = process.env.FORESTA_PASSPHRASE
const USCITA = new URL('../uscita/', import.meta.url)
const DIAGNOSI = new URL('../diagnosi/', import.meta.url)
/** Login, attività, arbusti e meteo: Open-Meteo da solo può metterci 8 s. */
const ATTESA_MASSIMA = 60_000
/** Dopo il "pronto", un attimo perché font e filtri SVG finiscano di disegnarsi. */
const MARGINE = 1500
/** Quante volte premere Riprova se le attività non si caricano, e quanto aspettare prima. */
const TENTATIVI = 3
const ATTESA_RIPROVA = 5000

/**
 * I formati: la vista CSS per la densità dà i pixel della PNG. `parametri` si
 * aggiungono a `#/foresta?sfondo`: quali pannelli dell'overlay e dove
 * (doc/08 di Projects, "Modalità sfondo").
 */
const FORMATI = {
  /** Mac 16:10, Retina: 2560×1600. In basso a sinistra: lontano da menu, icone, Dock e barra di Windows. */
  desktop: { larga: 1280, alta: 800, densita: 2, parametri: 'pannelli=oggi,numeri&posizione=basso-sinistra' },
  /**
   * Widget Android 4:3, 1600×1200. Solo la scena: il widget la ingrandisce e ci
   * scorre sopra, e il pannello lo disegna lui da `widget.json`.
   */
  widget: { larga: 800, alta: 600, densita: 2, parametri: '' },
} satisfies Record<string, { larga: number; alta: number; densita: number; parametri: string }>

type Formato = keyof typeof FORMATI

/** Fotografa un formato e restituisce il testo visibile della pagina (quello dell'overlay). */
async function fotografa(browser: Browser, nome: Formato): Promise<string> {
  const { larga, alta, densita, parametri } = FORMATI[nome]
  const contesto = await browser.newContext({
    viewport: { width: larga, height: alta },
    deviceScaleFactor: densita,
    timezoneId: 'Europe/Rome',
    locale: 'it-IT',
    reducedMotion: 'reduce',
  })
  const pagina = await contesto.newPage()
  // Per capire cosa è andato storto: la console della pagina e le richieste fallite.
  const registro: string[] = []
  pagina.on('console', (m) => registro.push(`[console.${m.type()}] ${m.text()}`))
  pagina.on('pageerror', (e) => registro.push(`[pageerror] ${e.message}`))
  pagina.on('requestfailed', (r) => registro.push(`[requestfailed] ${r.url()} ${r.failure()?.errorText ?? ''}`))
  pagina.on('response', (r) => {
    if (r.status() >= 400) registro.push(`[http ${r.status()}] ${r.url()}`)
  })

  try {
    await pagina.goto(`${INDIRIZZO}#/foresta?sfondo${parametri ? `&${parametri}` : ''}`)

    // Senza sessione compare la passphrase; con la sessione, direttamente la scena.
    const passphrase = pagina.locator('input[type="password"]')
    const pronto = pagina.locator('html[data-sfondo-pronto]')
    await passphrase.or(pronto).first().waitFor({ state: 'attached', timeout: ATTESA_MASSIMA })
    if (await passphrase.isVisible()) {
      if (!PASSPHRASE) throw new Error('Serve la passphrase: manca FORESTA_PASSPHRASE')
      await passphrase.fill(PASSPHRASE)
      await passphrase.press('Enter')
      // Passphrase sbagliata o rete giù: la schermata d'accesso lo dice in un role="alert".
      const avviso = pagina.locator('[role="alert"]')
      const riprova = avviso.getByRole('button', { name: 'Riprova' })
      for (let tentativo = 1; ; tentativo++) {
        await avviso.or(pronto).first().waitFor({ state: 'attached', timeout: ATTESA_MASSIMA })
        if (!(await avviso.isVisible())) break
        // Subito dopo il login Supabase può rifiutare il token appena emesso ("JWT issued at
        // future": gli orologi di Auth e PostgREST sfasati di qualche secondo). Passa da sé:
        // si aspetta e si preme Riprova. Una passphrase sbagliata non ha Riprova.
        if (tentativo > TENTATIVI || !(await riprova.isVisible())) {
          throw new Error(`Accesso non riuscito: ${await avviso.innerText()}`)
        }
        console.warn(`${nome}: ${(await avviso.innerText()).split('\n')[0]}, riprovo (${tentativo}/${TENTATIVI})`)
        await pagina.waitForTimeout(ATTESA_RIPROVA)
        await riprova.click()
      }
    }

    await pronto.waitFor({ state: 'attached', timeout: ATTESA_MASSIMA })
    await pagina.waitForTimeout(MARGINE)
    const file = new URL(`${nome}.png`, USCITA)
    await pagina.screenshot({ path: file.pathname, animations: 'disabled' })
    console.log(`${nome}: ${larga * densita}×${alta * densita} → uscita/${nome}.png`)
    return await pagina.locator('body').innerText()
  } catch (errore) {
    await diagnosi(pagina, nome, registro)
    throw errore
  } finally {
    await contesto.close()
  }
}

/**
 * Quando una foto non riesce: screenshot, testo della pagina e registro in
 * `diagnosi/` (in CI diventano un artifact del run). Mai in `uscita/`, che si
 * pubblica. Il testo visibile non contiene la passphrase, che sta solo nel campo.
 */
async function diagnosi(pagina: Page, nome: Formato, registro: string[]) {
  try {
    mkdirSync(DIAGNOSI, { recursive: true })
    await pagina.screenshot({ path: new URL(`${nome}.png`, DIAGNOSI).pathname })
    const testo = await pagina.locator('body').innerText({ timeout: 2000 }).catch(() => '(nessun testo)')
    const html = await pagina.evaluate(() => document.documentElement.outerHTML.length)
    const riassunto = [
      `indirizzo: ${pagina.url()}`,
      `pronto: ${await pagina.evaluate(() => document.documentElement.dataset.sfondoPronto ?? 'no')}`,
      `html: ${html} caratteri`,
      '--- testo visibile ---',
      testo,
      '--- registro ---',
      ...registro,
    ].join('\n')
    writeFileSync(new URL(`${nome}.txt`, DIAGNOSI), riassunto + '\n')
    console.error(riassunto)
  } catch (e) {
    console.error('Diagnosi non riuscita', e)
  }
}

/**
 * I dati per il pannello del widget Android, letti dal testo della card del
 * desktop (OverlaySfondo di Projects), per esempio:
 *   "Sabato 3 ottobre · Autunno\n18°\n· sereno a Milano\n07:23\n18:59\nUltimo quarto\n
 *    34 alberi · 14 boschetti · 3 arbusti\n34% completato\n+16 alberi questa settimana…"
 * Quello che non si trova resta fuori: il widget mostra il resto.
 */
function datiWidget(testo: string, generato: string) {
  const numero = (re: RegExp) => {
    const trovato = testo.match(re)
    return trovato ? Number(trovato[1]) : undefined
  }
  const [alba, tramonto] = testo.match(/\b\d{2}:\d{2}\b/g) ?? []
  return {
    generato,
    stagione: testo.match(/^[^\n]*·\s*(Primavera|Estate|Autunno|Inverno)\b/i)?.[1],
    temperatura: numero(/(-?\d+)°/),
    cielo: testo.match(/·\s*(sereno|nuvoloso|nebbia|pioggia|temporale|neve)\b/i)?.[1].toLowerCase(),
    alba,
    tramonto,
    // nomeFaseLunare di Projects
    luna: testo.match(/\b(Luna nuova|Falce crescente|Primo quarto|Gibbosa crescente|Luna piena|Gibbosa calante|Ultimo quarto|Falce calante)\b/)?.[1],
    alberi: numero(/(\d+) alber[oi] ·/),
    boschetti: numero(/(\d+) boschett[oi]/),
    arbusti: numero(/(\d+) arbust[oi]/),
    percentuale: numero(/(\d+)% completato/),
    settimana: numero(/\+(\d+) alber[oi] questa settimana/),
  }
}

/** Una pagina minima per vedere le foto dal browser. */
function indice(generato: string, formati: Formato[]) {
  const foto = formati.map((f) => `<figure><img src="${f}.png" alt="${f}"><figcaption>${f}.png</figcaption></figure>`)
  return `<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Foresta · sfondi</title>
<style>
  body { margin: 0; padding: 16px; font-family: system-ui, sans-serif; background: #f3f6f1; color: #2b3a29 }
  img { max-width: 100%; height: auto; border-radius: 8px; box-shadow: 0 1px 4px #0003 }
  figure { margin: 0 0 24px }
</style>
</head>
<body>
<h1>Foresta · sfondi</h1>
<p>Generati il ${new Date(generato).toLocaleString('it-IT', { timeZone: 'Europe/Rome' })}.</p>
${foto.join('\n')}
</body>
</html>
`
}

mkdirSync(USCITA, { recursive: true })
const browser = await chromium.launch()
try {
  const formati = Object.keys(FORMATI) as Formato[]
  const testi: Partial<Record<Formato, string>> = {}
  for (const nome of formati) testi[nome] = await fotografa(browser, nome)
  const generato = new Date().toISOString()
  const dati = datiWidget(testi.desktop ?? '', generato)
  console.log('widget.json:', JSON.stringify(dati))
  writeFileSync(new URL('widget.json', USCITA), JSON.stringify(dati, null, 2) + '\n')
  writeFileSync(new URL('info.json', USCITA), JSON.stringify({ generato, formati }, null, 2) + '\n')
  writeFileSync(new URL('index.html', USCITA), indice(generato, formati))
} finally {
  await browser.close()
}
