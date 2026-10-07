#!/bin/bash
# Scarica la foto della Foresta e, se è cambiata, la mette come sfondo su tutte
# le scrivanie. La lancia l'app nella barra dei menu: ogni ora, al risveglio e
# dal menu.
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

# System Events, nonostante "every desktop", cambia solo lo Space attivo: gli
# altri Space restano sulla foto vecchia (che poi cancelliamo). Nel registro
# degli sfondi si fanno puntare alla nuova tutte le voci che puntano a una
# nostra foto, e si riavvia WallpaperAgent perché lo rilegga.
INDICE="$HOME/Library/Application Support/com.apple.wallpaper/Store/Index.plist"
if [ -f "$INDICE" ]; then
  cambiate=$(osascript -l JavaScript - "$INDICE" "$CARTELLA" "$NUOVA" <<'EOF'
ObjC.import('Foundation');
function run([indice, cartella, nuova]) {
  const S = $.NSPropertyListSerialization;
  const leggi = (dati) => S.propertyListWithDataOptionsFormatError(dati, $.NSPropertyListMutableContainersAndLeaves, null, null);
  const scrivi = (plist) => S.dataWithPropertyListFormatOptionsError(plist, $.NSPropertyListBinaryFormat_v1_0, 0, null);
  const radice = leggi($.NSData.dataWithContentsOfFile(indice));
  const prefisso = $.NSURL.fileURLWithPath(cartella).absoluteString.js.replace(/\/?$/, '/');
  const url = $.NSURL.fileURLWithPath(nuova).absoluteString.js;
  let cambiate = 0;
  const visita = (x) => {
    if (x.isKindOfClass($.NSDictionary)) {
      // Configuration è a sua volta un plist binario: {type: imageFile, url: {relative: file://...}}
      const conf = x.objectForKey('Configuration');
      if (!conf.isNil() && conf.isKindOfClass($.NSData) && conf.length > 0) {
        const c = leggi(conf);
        const rel = c.isNil() ? null : c.valueForKeyPath('url.relative');
        if (rel && !rel.isNil() && rel.js.startsWith(prefisso) && rel.js !== url) {
          c.objectForKey('url').setObjectForKey($(url), 'relative');
          x.setObjectForKey(scrivi(c), 'Configuration');
          cambiate++;
        }
      }
      ObjC.unwrap(x.allValues).forEach(visita);
    } else if (x.isKindOfClass($.NSArray)) {
      ObjC.unwrap(x).forEach(visita);
    }
  };
  visita(radice);
  if (cambiate) scrivi(radice).writeToFileAtomically(indice, true);
  return cambiate;
}
EOF
  ) || cambiate="errore"
  case "$cambiate" in
    0) ;;
    errore) log "non riesco ad aggiornare gli altri Space: lì resta la foto vecchia" ;;
    *) killall WallpaperAgent 2>/dev/null || true ;;
  esac
fi

# Solo ora la foto conta come "già vista": se qualcosa sopra fallisce, il giro dopo riprova.
mv "$SCARICATA" "$ULTIMA"
# Le foto vecchie non servono più: lo sfondo ora punta alla nuova.
find "$CARTELLA" -name 'foresta-*.png' ! -path "$NUOVA" -delete
log "sfondo aggiornato: $(basename "$NUOVA")"
