#!/bin/bash
# Toglie l'aggiornamento orario dello sfondo. Lo sfondo attuale resta finché
# non se ne sceglie un altro; la sua foto resta nella cartella dell'app.

set -euo pipefail

DATI="$HOME/.local/share/projectswallpaper"   # fissa: la usa anche il .service
UNITA="$HOME/.config/systemd/user"

systemctl --user disable --now projectswallpaper.timer 2>/dev/null || true
rm -f "$UNITA/projectswallpaper.service" "$UNITA/projectswallpaper.timer"
systemctl --user daemon-reload
rm -f "$DATI/aggiorna-sfondo.sh" "$HOME/.local/bin/projectswallpaper"
rm -rf "$HOME/.config/projectswallpaper"

echo "Disinstallato. Per togliere anche le foto: rm -r $DATI"
