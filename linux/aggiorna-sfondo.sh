#!/bin/bash
# Scarica la foto della Foresta e, se è cambiata, la mette come sfondo. La
# lancia l'app nel vassoio di sistema: ogni ora, al risveglio e dal menu.
#
# Il desktop si riconosce da XDG_CURRENT_DESKTOP, che l'app riceve dalla
# sessione grafica. Supportati:
# GNOME (e Ubuntu, Budgie, Pantheon), Cinnamon, MATE, KDE Plasma, XFCE, sway;
# per gli altri window manager su X11, feh.
#
# Ogni foto nuova ha un nome nuovo: diversi desktop non ricaricano uno sfondo
# con lo stesso percorso.

set -euo pipefail

INDIRIZZO="https://giacomoguaresi.github.io/ProjectsWallpaper/desktop.png"
CARTELLA="$HOME/.local/share/projectswallpaper"
ULTIMA="$CARTELLA/ultima.png"       # l'ultima scaricata, con la data del server
SCARICATA="$CARTELLA/scaricata.png"

log() { echo "$*"; }   # l'app lo mette in registro.log, con data e ora

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
URI="file://$NUOVA"

# In minuscolo: "ubuntu:GNOME" → "ubuntu:gnome".
desktop="$(printf '%s' "${XDG_CURRENT_DESKTOP:-}" | tr '[:upper:]' '[:lower:]')"

case "$desktop" in
  *gnome* | *unity* | *budgie* | *pantheon*)
    gsettings set org.gnome.desktop.background picture-options 'zoom'
    gsettings set org.gnome.desktop.background picture-uri "$URI"
    # Da GNOME 42 col tema scuro vale questa chiave; prima non esiste.
    gsettings set org.gnome.desktop.background picture-uri-dark "$URI" 2>/dev/null || true
    ;;
  *cinnamon*)
    gsettings set org.cinnamon.desktop.background picture-options 'zoom'
    gsettings set org.cinnamon.desktop.background picture-uri "$URI"
    ;;
  *mate*)
    gsettings set org.mate.background picture-options 'zoom'
    gsettings set org.mate.background picture-filename "$NUOVA"
    ;;
  *kde*)
    plasma-apply-wallpaperimage "$NUOVA" >/dev/null
    ;;
  *xfce*)
    # Una proprietà per ogni schermo e ogni area di lavoro: si cambiano tutte.
    while read -r proprieta; do
      xfconf-query -c xfce4-desktop -p "$proprieta" -s "$NUOVA"
    done < <(xfconf-query -c xfce4-desktop -l | grep '/last-image$')
    ;;
  *sway*)
    # Vale fino al riavvio di sway; per tenerla, in config: output * bg ~/.local/share/projectswallpaper/ultima.png fill
    swaymsg output '*' bg "$NUOVA" fill >/dev/null
    ;;
  *)
    if command -v feh >/dev/null; then
      feh --no-fehbg --bg-fill "$NUOVA"
    else
      log "desktop \"${XDG_CURRENT_DESKTOP:-sconosciuto}\" non supportato e feh assente: foto in $NUOVA"
      exit 1
    fi
    ;;
esac

# Solo ora la foto conta come "già vista": se qualcosa sopra fallisce, il giro dopo riprova.
mv "$SCARICATA" "$ULTIMA"
# Le foto vecchie non servono più: lo sfondo ora punta alla nuova.
find "$CARTELLA" -name 'foresta-*.png' ! -path "$NUOVA" -delete
log "sfondo aggiornato: $(basename "$NUOVA")"
