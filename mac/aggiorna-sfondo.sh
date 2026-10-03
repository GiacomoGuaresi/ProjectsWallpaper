#!/bin/bash
# Scarica la foto della Foresta e, se è cambiata, la mette come sfondo su tutte
# le scrivanie. La lancia launchd ogni ora (it.giacomoguaresi.projectswallpaper);
# a mano: launchctl kickstart gui/$UID/it.giacomoguaresi.projectswallpaper
#
# macOS non ricarica uno sfondo con lo stesso percorso: ogni foto nuova ha un
# nome nuovo, e le vecchie si cancellano.

set -euo pipefail

INDIRIZZO="https://giacomoguaresi.github.io/ProjectsWallpaper/desktop.png"
CARTELLA="$HOME/Library/Application Support/ProjectsWallpaper"
ULTIMA="$CARTELLA/ultima.png"       # l'ultima scaricata, con la data del server
SCARICATA="$CARTELLA/scaricata.png"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

mkdir -p "$CARTELLA"
rm -f "$SCARICATA"

# Con -z il server risponde 304 se la foto non è cambiata, e curl non scrive niente.
opzioni=(-fsS --max-time 60 -R -o "$SCARICATA")
[ -f "$ULTIMA" ] && opzioni+=(-z "$ULTIMA")
if ! curl "${opzioni[@]}" "$INDIRIZZO"; then
  log "download non riuscito (offline?): riprovo al prossimo giro"
  exit 0
fi
if [ ! -s "$SCARICATA" ]; then
  log "invariata"
  exit 0
fi

NUOVA="$CARTELLA/foresta-$(date +%s).png"
cp -p "$SCARICATA" "$NUOVA"

osascript -e "tell application \"System Events\" to tell every desktop to set picture to POSIX file \"$NUOVA\""

# Solo ora la foto conta come "già vista": se qualcosa sopra fallisce, il giro dopo riprova.
mv "$SCARICATA" "$ULTIMA"
# Le foto vecchie non servono più: lo sfondo ora punta alla nuova.
find "$CARTELLA" -name 'foresta-*.png' ! -path "$NUOVA" -delete
log "sfondo aggiornato: $(basename "$NUOVA")"
