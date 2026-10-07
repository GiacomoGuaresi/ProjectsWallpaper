#!/bin/bash
# Toglie l'app e l'aggiornamento orario dello sfondo. Lo sfondo attuale resta
# finché non se ne sceglie un altro; la sua foto resta nella cartella dell'app.

set -euo pipefail

ETICHETTA="it.giacomoguaresi.projectswallpaper"

launchctl bootout "gui/$UID/$ETICHETTA" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$ETICHETTA.plist"
rm -rf "$HOME/Applications/ProjectsWallpaper.app"
rm -f "$HOME/Library/Application Support/ProjectsWallpaper/aggiorna-sfondo.sh"

echo "Disinstallato. Per togliere anche le foto: rm -r ~/Library/Application\\ Support/ProjectsWallpaper"
