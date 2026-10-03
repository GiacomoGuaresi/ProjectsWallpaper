# ProjectsWallpaper

La **Foresta** di [Projects](https://github.com/GiacomoGuaresi/Projects) come sfondo di PC e telefono, aggiornata circa ogni ora.

```
GitHub Actions (ogni ora)                GitHub Pages                     dispositivi
Playwright apre #/foresta?sfondo  ──►  …/ProjectsWallpaper/desktop.png  ──►  Mac (launchd, ogni ora)
entra con la passphrase, fotografa                                         Windows, Linux, Android: dopo
```

- **Pipeline** ([`pipeline/genera.ts`](pipeline/genera.ts), [`genera.yml`](.github/workflows/genera.yml)): Chromium headless apre la [modalità sfondo](https://github.com/GiacomoGuaresi/Projects/blob/main/doc/08-interfaccia.md) di Projects, cioè solo la scena senza interfaccia, con l'ora di Roma e "riduci movimento". Aspetta che dati e meteo siano arrivati e salva una PNG per formato. Se qualcosa va storto il deploy non parte, e restano le foto dell'ora prima.
- **Immagini**: <https://giacomoguaresi.github.io/ProjectsWallpaper/> (anteprime), con `desktop.png` (2560×1600) e `info.json` (quando è stata generata). Sono pubbliche: mostrano solo alberi e colori, niente titoli.
- **Mac** ([`mac/`](mac/)): uno script che scarica la PNG solo se è cambiata e la mette come sfondo su tutte le scrivanie, lanciato da un LaunchAgent ogni ora e all'accesso.

## Mac

```sh
./mac/installa.sh      # installa e fa subito un giro
./mac/disinstalla.sh   # toglie tutto
```

- La prima volta macOS chiede di consentire a `bash` (o al Terminale) di controllare **System Events**: serve per cambiare lo sfondo.
- Aggiornare subito: `launchctl kickstart gui/$UID/it.giacomoguaresi.projectswallpaper`
- Log: `~/Library/Logs/ProjectsWallpaper.log` · Stato: `launchctl print gui/$UID/it.giacomoguaresi.projectswallpaper`
- File: `~/Library/Application Support/ProjectsWallpaper/`

## Pipeline

Configurazione una tantum del repo:

1. **Secret** `FORESTA_PASSPHRASE` con la passphrase dell'account condiviso (Settings → Secrets and variables → Actions), oppure `gh secret set FORESTA_PASSPHRASE`.
2. **Pages**: Settings → Pages → Source: *GitHub Actions*.

Rigenerare subito: `gh workflow run genera.yml` (o *Run workflow* da Actions).

In locale:

```sh
npm install && npx playwright install chromium
FORESTA_PASSPHRASE=… npm run genera                                            # contro il sito pubblicato
FORESTA_INDIRIZZO=http://localhost:5173/Projects/ FORESTA_PASSPHRASE=… npm run genera   # contro npm run dev di Projects
```

Il risultato è in `uscita/` (non versionata).

⚠️ GitHub **sospende i cron** dei repo pubblici dopo 60 giorni senza commit. Se lo sfondo smette di cambiare, basta *Enable workflow* nella scheda Actions, oppure un commit.

## Prossimi passi

- Windows e Linux: stesso schema del Mac (script più operazione pianificata o timer systemd).
- Android: app con `WorkManager` ogni ora che imposta lo sfondo, più un widget; nella pipeline un formato `telefono` verticale.

## Licenza

MIT
