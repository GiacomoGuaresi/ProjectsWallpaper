# ProjectsWallpaper

La **Foresta** di [Projects](https://github.com/GiacomoGuaresi/Projects) come sfondo di PC e telefono, aggiornata circa ogni ora.

```
GitHub Actions (ogni ora)                GitHub Pages                     dispositivi
Playwright apre #/foresta?sfondo  ──►  …/ProjectsWallpaper/desktop.png  ──►  Mac (launchd, ogni ora)
entra con la passphrase, fotografa                                         Windows (Utilità di pianificazione)
                                                                           Linux (timer systemd utente)
```

- **Pipeline** ([`pipeline/genera.ts`](pipeline/genera.ts), [`genera.yml`](.github/workflows/genera.yml)): Chromium headless apre la [modalità sfondo](https://github.com/GiacomoGuaresi/Projects/blob/main/doc/08-interfaccia.md) di Projects, cioè solo la scena senza interfaccia, con l'ora di Roma e "riduci movimento". Aspetta che dati e meteo siano arrivati e salva una PNG per formato. Se qualcosa va storto il deploy non parte, e restano le foto dell'ora prima.
- **Immagini**: <https://giacomoguaresi.github.io/ProjectsWallpaper/> (anteprime), con `desktop.png` (2560×1600) e `info.json` (quando è stata generata). Sono pubbliche, quindi niente titoli né nomi di progetti.
- **Overlay**: in basso a sinistra una card con data, meteo e temperatura a Milano, alba, tramonto e luna, e i numeri della foresta (alberi, boschetti, arbusti, avanzamento, alberi piantati in settimana). Pannelli e posizione si scelgono per formato con `parametri` in `FORMATI` ([`genera.ts`](pipeline/genera.ts)), ad esempio `pannelli=oggi,numeri&posizione=basso-sinistra`. Tutte le opzioni sono nella doc di Projects, "Modalità sfondo".
- **PC** ([`mac/`](mac/), [`windows/`](windows/), [`linux/`](linux/)): su ogni sistema uno script fa lo stesso lavoro, lanciato ogni ora e all'accesso dal pianificatore del sistema. Scarica la PNG solo se è cambiata (`If-Modified-Since`), la salva con un nome nuovo (alcuni sistemi non ricaricano uno sfondo con lo stesso percorso) e la mette come sfondo. Se qualcosa non va, il giro dopo riprova. Se un giro è stato perso perché il PC era spento, parte appena possibile.

## Mac

```sh
./mac/installa.sh      # installa e fa subito un giro
./mac/disinstalla.sh   # toglie tutto
```

- La prima volta macOS chiede di consentire a `bash` (o al Terminale) di controllare **System Events**: serve per cambiare lo sfondo.
- Aggiornare subito: `launchctl kickstart gui/$UID/it.giacomoguaresi.projectswallpaper`
- Log: `~/Library/Logs/ProjectsWallpaper.log` · Stato: `launchctl print gui/$UID/it.giacomoguaresi.projectswallpaper`
- File: `~/Library/Application Support/ProjectsWallpaper/`

## Windows

Testato solo sulla carta. Richiede Windows 10 21H2+ o 11 (per `conhost --headless`) e usa Windows PowerShell 5.1, già presente.

```powershell
powershell -ExecutionPolicy Bypass -File windows\installa.ps1      # installa e fa subito un giro
powershell -ExecutionPolicy Bypass -File windows\disinstalla.ps1   # toglie tutto
```

- Attività **ProjectsWallpaper** nell'Utilità di pianificazione: all'accesso e poi ogni ora, solo con l'utente collegato.
- Aggiornare subito: `Start-ScheduledTask -TaskName ProjectsWallpaper`
- Registro e foto: `%LOCALAPPDATA%\ProjectsWallpaper\` (`registro.log`)
- Adattamento *Riempi*: su uno schermo 16:9 la foto 16:10 perde un filo sopra e sotto, dove c'è solo cielo.

## Linux

Testato solo sulla carta. Va lanciato **dentro la sessione grafica**, perché salva il desktop in uso:

```sh
./linux/installa.sh      # installa e fa subito un giro
./linux/disinstalla.sh   # toglie tutto
```

- Desktop supportati: GNOME (Ubuntu, Budgie, Pantheon), Cinnamon, MATE, KDE Plasma, XFCE e sway. Su altri window manager X11 serve `feh`.
- Timer systemd **utente** `projectswallpaper.timer`: ogni ora, un minuto dopo l'accesso, con recupero dei giri persi.
- Aggiornare subito: `systemctl --user start projectswallpaper.service`
- Log: `journalctl --user -u projectswallpaper` · Prossimi giri: `systemctl --user list-timers`
- File: `~/.local/share/projectswallpaper/` (foto), `~/.config/projectswallpaper/config.env` (desktop e display salvati). Se cambi desktop, rilancia `installa.sh`.
- Su sway lo sfondo vale fino al riavvio di sway. Per tenerlo, aggiungi alla config: `output * bg ~/.local/share/projectswallpaper/ultima.png fill`.

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

- Android: app con `WorkManager` ogni ora che imposta lo sfondo, più un widget; nella pipeline un formato `telefono` verticale.

## Licenza

MIT
