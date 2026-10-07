#!/bin/bash
# Toglie l'app e l'aggiornamento orario dello sfondo. Lo sfondo attuale resta
# finché non se ne sceglie un altro; la sua foto resta nella cartella dell'app.

set -euo pipefail

DATI="$HOME/.local/share/projectswallpaper"
VOCE="projectswallpaper.desktop"

pkill -f "$DATI/projectswallpaper-app.py" 2>/dev/null || true
rm -f "$HOME/.config/autostart/$VOCE" "$HOME/.local/share/applications/$VOCE"
rm -f "$DATI/projectswallpaper-app.py" "$DATI/aggiorna-sfondo.sh"

# I resti della vecchia procedura, se ci sono.
systemctl --user disable --now projectswallpaper.timer 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/projectswallpaper.service" "$HOME/.config/systemd/user/projectswallpaper.timer"
systemctl --user daemon-reload 2>/dev/null || true
rm -f "$HOME/.local/bin/projectswallpaper"
rm -rf "$HOME/.config/projectswallpaper"

echo "Disinstallato. Per togliere anche le foto e il log: rm -r $DATI"
