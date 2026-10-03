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
import { chromium, type Browser } from 'playwright'

const INDIRIZZO = process.env.FORESTA_INDIRIZZO ?? 'https://giacomoguaresi.github.io/Projects/'
const PASSPHRASE = process.env.FORESTA_PASSPHRASE
const USCITA = new URL('../uscita/', import.meta.url)
/** Login, attività, arbusti e meteo: Open-Meteo da solo può metterci 8 s. */
const ATTESA_MASSIMA = 60_000
/** Dopo il "pronto", un attimo perché font e filtri SVG finiscano di disegnarsi. */
const MARGINE = 1500

/** I formati: la vista CSS per la densità dà i pixel della PNG. */
const FORMATI = {
  /** Mac 16:10, Retina: 2560×1600. */
  desktop: { larga: 1280, alta: 800, densita: 2 },
} satisfies Record<string, { larga: number; alta: number; densita: number }>

type Formato = keyof typeof FORMATI

async function fotografa(browser: Browser, nome: Formato) {
  const { larga, alta, densita } = FORMATI[nome]
  const contesto = await browser.newContext({
    viewport: { width: larga, height: alta },
    deviceScaleFactor: densita,
    timezoneId: 'Europe/Rome',
    locale: 'it-IT',
    reducedMotion: 'reduce',
  })
  try {
    const pagina = await contesto.newPage()
    await pagina.goto(`${INDIRIZZO}#/foresta?sfondo`)

    // Senza sessione compare la passphrase; con la sessione, direttamente la scena.
    const passphrase = pagina.locator('input[type="password"]')
    const pronto = pagina.locator('html[data-sfondo-pronto]')
    await passphrase.or(pronto).first().waitFor({ state: 'attached', timeout: ATTESA_MASSIMA })
    if (await passphrase.isVisible()) {
      if (!PASSPHRASE) throw new Error('Serve la passphrase: manca FORESTA_PASSPHRASE')
      await passphrase.fill(PASSPHRASE)
      await passphrase.press('Enter')
    }

    await pronto.waitFor({ state: 'attached', timeout: ATTESA_MASSIMA })
    await pagina.waitForTimeout(MARGINE)
    const file = new URL(`${nome}.png`, USCITA)
    await pagina.screenshot({ path: file.pathname, animations: 'disabled' })
    console.log(`${nome}: ${larga * densita}×${alta * densita} → uscita/${nome}.png`)
  } finally {
    await contesto.close()
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
  for (const nome of formati) await fotografa(browser, nome)
  const generato = new Date().toISOString()
  writeFileSync(new URL('info.json', USCITA), JSON.stringify({ generato, formati }, null, 2) + '\n')
  writeFileSync(new URL('index.html', USCITA), indice(generato, formati))
} finally {
  await browser.close()
}
