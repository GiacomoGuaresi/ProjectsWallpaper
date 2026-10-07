#!/bin/bash
# Installa l'app nel vassoio di sistema che aggiorna lo sfondo: copia lo script
# e l'app, la mette nell'avvio automatico e nel menu delle applicazioni, toglie
# la vecchia procedura (timer systemd e comando projectswallpaper) e la avvia.
# Rilanciabile, anche per aggiornare. Da lanciare dentro la sessione grafica.
# Serve PyQt6: sudo apt install python3-pyqt6

set -euo pipefail

QUI="$(cd "$(dirname "$0")" && pwd)"
DATI="$HOME/.local/share/projectswallpaper"
APP="$DATI/projectswallpaper-app.py"
VOCE="projectswallpaper.desktop"

if ! python3 -c 'import PyQt6.QtWidgets' 2>/dev/null; then
  echo "Manca PyQt6: sudo apt install python3-pyqt6, poi rilancia questo script." >&2
  exit 1
fi

mkdir -p "$DATI" "$HOME/.config/autostart" "$HOME/.local/share/applications"
cp "$QUI/aggiorna-sfondo.sh" "$QUI/app/projectswallpaper-app.py" "$DATI/"
chmod +x "$DATI/aggiorna-sfondo.sh" "$APP"
# All'accesso e nel menu delle applicazioni, per riaprirla dopo "Esci".
sed "s|__HOME__|$HOME|g" "$QUI/app/$VOCE" > "$HOME/.config/autostart/$VOCE"
sed "s|__HOME__|$HOME|g" "$QUI/app/$VOCE" > "$HOME/.local/share/applications/$VOCE"

# La vecchia procedura: timer systemd utente, comando e desktop salvato.
if systemctl --user list-unit-files projectswallpaper.timer >/dev/null 2>&1; then
  systemctl --user disable --now projectswallpaper.timer 2>/dev/null || true
fi
rm -f "$HOME/.config/systemd/user/projectswallpaper.service" "$HOME/.config/systemd/user/projectswallpaper.timer"
systemctl --user daemon-reload 2>/dev/null || true
rm -f "$HOME/.local/bin/projectswallpaper"
rm -rf "$HOME/.config/projectswallpaper"

# Se era già aperta si chiude, così parte la versione nuova.
pkill -f "$APP" 2>/dev/null || true
sleep 1
setsid -f python3 "$APP" >/dev/null 2>&1 < /dev/null

echo "Installato: l'icona è nel vassoio di sistema e fa subito un giro."
echo "Log: $DATI/registro.log"
