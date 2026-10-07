#!/bin/bash
# Installa l'app nella barra dei menu che aggiorna lo sfondo: copia lo script,
# compila l'app in ~/Applications, registra il LaunchAgent che la lancia
# all'accesso e installa il comando projectswallpaper. Rilanciabile, anche per
# aggiornare. Serve swiftc (Xcode o i Command Line Tools).
# La prima volta macOS chiede il permesso di controllare "System Events".

set -euo pipefail

ETICHETTA="it.giacomoguaresi.projectswallpaper"
QUI="$(cd "$(dirname "$0")" && pwd)"
CARTELLA="$HOME/Library/Application Support/ProjectsWallpaper"
AGENTE="$HOME/Library/LaunchAgents/$ETICHETTA.plist"
APP="$HOME/Applications/ProjectsWallpaper.app"

mkdir -p "$CARTELLA" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
cp "$QUI/aggiorna-sfondo.sh" "$CARTELLA/"
chmod +x "$CARTELLA/aggiorna-sfondo.sh"
# Il comando per aggiornare dal terminale: projectswallpaper [aggiorna|forza|scarica|log]
mkdir -p "$HOME/.local/bin"
cp "$QUI/projectswallpaper" "$HOME/.local/bin/"
chmod +x "$HOME/.local/bin/projectswallpaper"

echo "Compilo l'app…"
COSTRUZIONE="$(mktemp -d)"
trap 'rm -rf "$COSTRUZIONE"' EXIT
mkdir -p "$COSTRUZIONE/ProjectsWallpaper.app/Contents/MacOS"
cp "$QUI/app/Info.plist" "$COSTRUZIONE/ProjectsWallpaper.app/Contents/"
swiftc -O -swift-version 5 -o "$COSTRUZIONE/ProjectsWallpaper.app/Contents/MacOS/ProjectsWallpaper" "$QUI/app/ProjectsWallpaper.swift"
codesign --force --sign - "$COSTRUZIONE/ProjectsWallpaper.app"

sed "s|__HOME__|$HOME|g" "$QUI/$ETICHETTA.plist" > "$AGENTE"

# Se era già installato si ferma, si sostituisce l'app e si ricarica.
launchctl bootout "gui/$UID/$ETICHETTA" 2>/dev/null || true
mkdir -p "$HOME/Applications"
rm -rf "$APP"
mv "$COSTRUZIONE/ProjectsWallpaper.app" "$APP"
launchctl bootstrap "gui/$UID" "$AGENTE"

echo "Installato: l'icona è nella barra dei menu e fa subito un giro. Log: ~/Library/Logs/ProjectsWallpaper.log"
echo "Dal terminale: projectswallpaper (o projectswallpaper forza)"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) echo "Per usare il comando projectswallpaper aggiungi ~/.local/bin al PATH, ad esempio in ~/.zshrc:"
     echo "  export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac
