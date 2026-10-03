#!/bin/bash
# Installa l'aggiornamento orario dello sfondo: copia lo script, registra il
# LaunchAgent e fa subito un primo giro. Rilanciabile, anche per aggiornare.
# La prima volta macOS chiede il permesso di controllare "System Events".

set -euo pipefail

ETICHETTA="it.giacomoguaresi.projectswallpaper"
QUI="$(cd "$(dirname "$0")" && pwd)"
CARTELLA="$HOME/Library/Application Support/ProjectsWallpaper"
AGENTE="$HOME/Library/LaunchAgents/$ETICHETTA.plist"

mkdir -p "$CARTELLA" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
cp "$QUI/aggiorna-sfondo.sh" "$CARTELLA/"
chmod +x "$CARTELLA/aggiorna-sfondo.sh"
sed "s|__HOME__|$HOME|g" "$QUI/$ETICHETTA.plist" > "$AGENTE"

# Se era già installato si ricarica, così prende lo script e il plist nuovi.
launchctl bootout "gui/$UID/$ETICHETTA" 2>/dev/null || true
launchctl bootstrap "gui/$UID" "$AGENTE"

echo "Installato. Primo giro in corso (RunAtLoad); il log è in ~/Library/Logs/ProjectsWallpaper.log"
echo "Aggiornare a mano: launchctl kickstart gui/\$UID/$ETICHETTA"
