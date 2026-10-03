#!/bin/bash
# Installa l'aggiornamento orario dello sfondo: copia lo script, salva il
# desktop in uso, attiva il timer systemd utente e fa subito un primo giro.
# Rilanciabile, anche per aggiornare. Da lanciare dentro la sessione grafica.

set -euo pipefail

QUI="$(cd "$(dirname "$0")" && pwd)"
DATI="$HOME/.local/share/projectswallpaper"   # fissa: la usa anche il .service
CONFIG="$HOME/.config/projectswallpaper"
UNITA="$HOME/.config/systemd/user"

mkdir -p "$DATI" "$CONFIG" "$UNITA"
cp "$QUI/aggiorna-sfondo.sh" "$DATI/"
chmod +x "$DATI/aggiorna-sfondo.sh"
cp "$QUI/projectswallpaper.service" "$QUI/projectswallpaper.timer" "$UNITA/"

# Il servizio parte fuori dalla sessione grafica: gli si passa quello che serve
# per trovarla. Se un giorno si cambia desktop, basta rilanciare questo script.
{
  echo "# Scritto da installa.sh il $(date '+%Y-%m-%d %H:%M')"
  for v in XDG_CURRENT_DESKTOP DISPLAY WAYLAND_DISPLAY XAUTHORITY SWAYSOCK DBUS_SESSION_BUS_ADDRESS; do
    if [ -n "${!v:-}" ]; then echo "$v=${!v}"; fi
  done
} > "$CONFIG/config.env"

systemctl --user daemon-reload
systemctl --user enable --now projectswallpaper.timer
systemctl --user start projectswallpaper.service || true

echo "Installato per il desktop \"${XDG_CURRENT_DESKTOP:-sconosciuto}\"."
echo "Log: journalctl --user -u projectswallpaper"
echo "Aggiornare a mano: systemctl --user start projectswallpaper.service"
