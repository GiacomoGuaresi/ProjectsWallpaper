# ProjectsWallpaper

La **Foresta** di [Projects](https://github.com/GiacomoGuaresi/Projects) come sfondo di PC e telefono, aggiornata circa ogni ora.

```
GitHub Actions (ogni ora)                GitHub Pages                     dispositivi
Playwright apre #/foresta?sfondo  ──►  …/ProjectsWallpaper/desktop.png  ──►  Mac (launchd, ogni ora)
entra con la passphrase, fotografa                                         Windows (Utilità di pianificazione)
                                                                           Linux (timer systemd utente)
                                       …/widget.png + widget.json  ──►  Android (widget, WorkManager)
```

- **Pipeline** ([`pipeline/genera.ts`](pipeline/genera.ts), [`genera.yml`](.github/workflows/genera.yml)): Chromium headless apre la [modalità sfondo](https://github.com/GiacomoGuaresi/Projects/blob/main/doc/08-interfaccia.md) di Projects, cioè solo la scena senza interfaccia, con l'ora di Roma e "riduci movimento". Aspetta che dati e meteo siano arrivati e salva una PNG per formato. Se qualcosa va storto il deploy non parte, e restano le foto dell'ora prima.
- **Immagini**: <https://giacomoguaresi.github.io/ProjectsWallpaper/> (anteprime), con `desktop.png` (2560×1600), `widget.png` (2400×1800, solo la scena), `widget.json` (stagione, meteo, alba e tramonto, luna, alberi, boschetti, arbusti, avanzamento e alberi della settimana, letti dalla card del desktop) e `info.json` (quando sono state generate). Sono pubbliche, quindi niente titoli né nomi di progetti.
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

## Android

Un widget per la home con la Foresta: la vista scorre lenta sulla foto (25 s per andare, 25 per tornare) con l'ora. Grande (da 200dp per lato): in alto ora, data e stagione, in basso una card con meteo, alba, tramonto e luna, alberi, boschetti e arbusti, avanzamento e alberi della settimana. Piccolo: solo la card, con ora, data, meteo e alberi. Ora e data sono `TextClock`, le aggiorna il sistema ogni minuto. Toccandolo si apre la Foresta. Solo il widget: lo sfondo del telefono resta com'è.

- Installazione: l'APK `foresta-*.apk` dall'ultima [Release](https://github.com/GiacomoGuaresi/ProjectsWallpaper/releases) (consentire le app da origini sconosciute), poi dalla scelta dei widget del launcher **Foresta**. Non c'è un'icona nel drawer: l'app è solo il widget.
- Ogni ora (WorkManager, solo con la rete) scarica `widget.png` e `widget.json` se sono cambiati, e ridisegna. Il meteo più vecchio di 3 ore non si mostra.
- La carrellata è il centro della foto (metà larghezza e metà altezza, `RITAGLIO` in `Disegno.kt`), sempre in proporzione (`centerCrop`) e ingrandita almeno 1.2 volte, così sborda del 10% per lato, che vaga piano: in orizzontale (±7%) in 29 s, in verticale (±6%) in 41 s e con uno zoom da 1.2 a 1.28 in 53 s. Le durate non stanno in rapporto semplice, così il percorso sembra casuale e si ripete solo dopo decine di minuti. Sono tre `layoutAnimation` annidate ([`res/anim/carrellata_*.xml`](android/app/src/main/res/anim/)) che il launcher esegue da sé, perché un widget non può animare da codice.
- Alcuni launcher, chiudendo le app recenti, fanno *force stop* e cancellano il giro orario: torna quando il launcher aggiorna il widget, o togliendo e rimettendo il widget. Aiuta mettere l'app **senza restrizioni** nelle impostazioni della batteria.
- Log: `adb logcat -s ProjectsWallpaper`

Sviluppo (JDK 17, Android SDK):

```sh
cd android
./gradlew assembleDebug && adb install -r app/build/outputs/apk/debug/app-debug.apk
```

Una versione nuova: alzare `versionCode`/`versionName` in [`app/build.gradle.kts`](android/app/build.gradle.kts), poi `git tag android-v0.2.0 && git push origin android-v0.2.0`. Il workflow [`android.yml`](.github/workflows/android.yml) builda l'APK firmato e lo allega a una Release. Serve una volta il keystore:

```sh
keytool -genkeypair -v -keystore android/release.jks -alias foresta -keyalg RSA -keysize 4096 -validity 36500
gh secret set ANDROID_KEYSTORE < <(base64 -w0 android/release.jks)
gh secret set ANDROID_KEYSTORE_PASSWORD; gh secret set ANDROID_KEY_ALIAS; gh secret set ANDROID_KEY_PASSWORD
```

Il keystore non va nel repo (`.gitignore`): tenerne una copia, senza non si possono più aggiornare le installazioni. In locale la release si firma con `android/keystore.properties` (stesse chiavi dei secrets, `ANDROID_KEYSTORE_FILE=release.jks`).

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

- Android: anche lo sfondo del telefono, con un formato `telefono` verticale nella pipeline.

## Licenza

MIT
