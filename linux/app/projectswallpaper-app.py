#!/usr/bin/env python3
# ProjectsWallpaper nel vassoio di sistema (pensata per KDE Plasma, va su ogni
# desktop con un vassoio StatusNotifierItem). La lancia l'autostart all'accesso;
# fa il giro di aggiorna-sfondo.sh ogni ora al minuto 12 (poco dopo la pipeline,
# che parte al 7), al risveglio e all'avvio, e dal menu fa rigenerare la foto
# alla pipeline. È la stessa app del Mac (mac/app/ProjectsWallpaper.swift).
# Serve PyQt6: sudo apt install python3-pyqt6

import json
import math
import sys
import threading
import time
import urllib.request
from datetime import datetime, timedelta
from pathlib import Path

from PyQt6.QtCore import QObject, QPointF, QProcess, QRectF, Qt, QTimer, QUrl, pyqtSignal
from PyQt6.QtGui import QAction, QColor, QCursor, QDesktopServices, QIcon, QPainter, QPen, QPixmap, QPolygonF
from PyQt6.QtNetwork import QLocalServer, QLocalSocket
from PyQt6.QtWidgets import QApplication, QMenu, QSystemTrayIcon

CARTELLA = Path.home() / ".local/share/projectswallpaper"
SCRIPT = CARTELLA / "aggiorna-sfondo.sh"
LOG = CARTELLA / "registro.log"
FUNZIONE = "https://fvsohjlrulwabvfvcfxo.supabase.co/functions/v1/foresta-aggiorna"
INFO = "https://giacomoguaresi.github.io/ProjectsWallpaper/info.json"
ATTESA_MASSIMA = 300   # secondi: un giro della pipeline, deploy compreso, ne dura un paio di minuti
MINUTO_DEL_GIRO = 12
NOME_ISTANZA = "projectswallpaper-app"


def registra(testo):
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a", encoding="utf-8") as f:
        f.write(f"{datetime.now():%Y-%m-%d %H:%M:%S} {testo}\n")


def ora():
    return f"{datetime.now():%H:%M}"


# MARK: icona

def abete(x, base, h, w):
    """Un abete: tre palchi sovrapposti, che si stringono salendo, e il tronco.
    Coordinate come nello Swift: tela 18x18 con la y che sale."""
    forme = []
    for i in range(3):
        f = i / 3
        y0 = base + h * 0.18 + h * 0.82 * f * 0.62
        larg = w * (1 - f * 0.35)
        forme.append([(x - larg / 2, y0), (x + larg / 2, y0), (x, min(y0 + h * 0.41, base + h))])
    t = w * 0.08
    forme.append([(x - t, base), (x + t, base), (x + t, base + h * 0.2), (x - t, base + h * 0.2)])
    return forme


def foresta(lato, colore, opacita=1.0):
    """Tre abeti, la Foresta, con un bordo vuoto attorno a quello centrale."""
    k = lato / 18

    def poligono(punti):
        return QPolygonF([QPointF(px * k, (18 - py) * k) for px, py in punti])

    img = QPixmap(lato, lato)
    img.fill(Qt.GlobalColor.transparent)
    p = QPainter(img)
    p.setRenderHint(QPainter.RenderHint.Antialiasing)
    p.setPen(Qt.PenStyle.NoPen)
    p.setBrush(colore)
    for forma in abete(4.5, 2, 10, 7) + abete(13.5, 2, 11, 7.5):
        p.drawPolygon(poligono(forma))
    centro = abete(9, 2, 14.5, 9)
    p.setCompositionMode(QPainter.CompositionMode.CompositionMode_Clear)
    p.setPen(QPen(Qt.GlobalColor.black, 2 * k, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap, Qt.PenJoinStyle.RoundJoin))
    for forma in centro:
        p.drawPolygon(poligono(forma))
    p.setCompositionMode(QPainter.CompositionMode.CompositionMode_SourceOver)
    p.setPen(Qt.PenStyle.NoPen)
    for forma in centro:
        p.drawPolygon(poligono(forma))
    p.end()
    if opacita < 1:
        sbiadita = QPixmap(lato, lato)
        sbiadita.fill(Qt.GlobalColor.transparent)
        p = QPainter(sbiadita)
        p.setOpacity(opacita)
        p.drawPixmap(0, 0, img)
        p.end()
        img = sbiadita
    return img


# MARK: app

class Segnali(QObject):
    stato = pyqtSignal(str)
    fatto = pyqtSignal()


class App:
    def __init__(self, app):
        self.app = app
        self.occupata = False
        self.errore = False
        self.fase = 0.0

        self.menu = QMenu()
        self.stato = QAction("Avvio…")
        self.stato.setEnabled(False)
        self.menu.addAction(self.stato)
        self.menu.addSeparator()
        self.aggiorna = self.menu.addAction("Aggiorna ora", lambda: self.giro(rigenerando=True))
        self.scarica = self.menu.addAction("Scarica l'ultima foto", lambda: self.giro(rigenerando=False))
        self.menu.addSeparator()
        self.menu.addAction("Apri il log", lambda: QDesktopServices.openUrl(QUrl.fromLocalFile(str(LOG))))
        self.menu.addAction("Esci", app.quit)

        self.vassoio = QSystemTrayIcon()
        self.vassoio.setContextMenu(self.menu)
        # Anche il clic sinistro apre il menu, come sul Mac.
        self.vassoio.activated.connect(
            lambda motivo: self.menu.popup(QCursor.pos()) if motivo == QSystemTrayIcon.ActivationReason.Trigger else None)
        self.pulsa = QTimer()
        self.pulsa.setInterval(80)
        self.pulsa.timeout.connect(self.battito)
        self.icona()
        self.vassoio.show()
        # Il tema può cambiare tra chiaro e scuro: si ridisegna col colore nuovo.
        suggerimenti = app.styleHints()
        if hasattr(suggerimenti, "colorSchemeChanged"):   # Qt 6.5+
            suggerimenti.colorSchemeChanged.connect(lambda _: self.icona())

        self.segnali = Segnali()
        self.segnali.stato.connect(self.mostra)
        self.segnali.fatto.connect(self.lancia_script)

        # Orologio: ogni 30 s si guarda se è passato il prossimo minuto 12, e se il
        # PC si è appena svegliato. time.monotonic() si ferma durante la
        # sospensione, time.time() no: se lo scarto cresce, il PC dormiva.
        self.prossimo = self.calcola_prossimo()
        self.ultimo_muro, self.ultimo_mono = time.time(), time.monotonic()
        self.orologio = QTimer()
        self.orologio.setInterval(30_000)
        self.orologio.timeout.connect(self.controlla)
        self.orologio.start()
        QTimer.singleShot(0, lambda: self.giro(rigenerando=False))

    # MARK: orologio

    def calcola_prossimo(self):
        adesso = datetime.now()
        prossimo = adesso.replace(minute=MINUTO_DEL_GIRO, second=0, microsecond=0)
        if prossimo <= adesso:
            prossimo += timedelta(hours=1)
        return prossimo

    def controlla(self):
        muro, mono = time.time(), time.monotonic()
        dormiva = (muro - self.ultimo_muro) - (mono - self.ultimo_mono) > 60
        self.ultimo_muro, self.ultimo_mono = muro, mono
        if dormiva:
            self.prossimo = self.calcola_prossimo()
            # Qualche secondo perché torni la rete.
            QTimer.singleShot(10_000, lambda: self.giro(rigenerando=False))
        elif datetime.now() >= self.prossimo:
            self.prossimo = self.calcola_prossimo()
            self.giro(rigenerando=False)

    # MARK: azioni

    def giro(self, rigenerando):
        if self.occupata:
            return
        self.occupata = True
        self.aggiorna.setEnabled(False)
        self.scarica.setEnabled(False)
        self.errore = False
        self.icona()
        if rigenerando:
            self.mostra("Genero la foto nuova…")
            threading.Thread(target=self.rigenera, daemon=True).start()
        else:
            self.lancia_script()

    def rigenera(self):
        """Fa partire la pipeline e aspetta la foto nuova. Se non riesce si scarica comunque l'ultima.
        Gira in un thread: parla con l'interfaccia solo con i segnali."""
        try:
            prima = generato()
            richiesta = urllib.request.Request(FUNZIONE, method="POST", data=b"")
            with urllib.request.urlopen(richiesta, timeout=30) as r:
                stato = json.load(r).get("stato")
            if stato == "recente":
                return
            if stato not in ("avviato", "in-corso"):
                registra("risposta inattesa dalla pipeline: scarico l'ultima foto")
                return
            inizio = time.monotonic()
            while time.monotonic() - inizio < ATTESA_MASSIMA:
                time.sleep(5)
                secondi = int(time.monotonic() - inizio)
                self.segnali.stato.emit(f"Genero la foto nuova… {secondi // 60}:{secondi % 60:02d}")
                adesso = generato()
                if adesso and adesso != prima:
                    return
            registra(f"la foto nuova non è arrivata in {ATTESA_MASSIMA // 60} minuti: scarico quella che c'è")
        except Exception as e:
            registra(f"non riesco a far partire la pipeline ({e}): scarico l'ultima foto")
        finally:
            self.segnali.fatto.emit()

    def lancia_script(self):
        """aggiorna-sfondo.sh con l'output in coda al log."""
        self.mostra("Aggiorno lo sfondo…")
        self.processo = QProcess()
        self.processo.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
        self.processo.finished.connect(self.finito)
        self.processo.errorOccurred.connect(
            lambda e: self.finito(-1, None) if e == QProcess.ProcessError.FailedToStart else None)
        self.processo.start("/bin/bash", [str(SCRIPT)])

    def finito(self, esito, _stato):
        uscita = bytes(self.processo.readAll()).decode("utf-8", "replace")
        righe = [r for r in uscita.splitlines() if r.strip()]
        for r in righe:
            registra(r)
        ultima = righe[-1] if righe else ""
        if esito == 0:
            self.mostra(f"Ultimo controllo: {ora()}" + (" · sfondo nuovo" if "sfondo aggiornato" in ultima else ""))
        else:
            if esito == -1:
                ultima = f"non riesco a lanciare {SCRIPT}"
                registra(ultima)
            self.mostra(f"Errore alle {ora()}: {ultima or 'vedi il log'}")
            self.errore = True
        self.occupata = False
        self.aggiorna.setEnabled(True)
        self.scarica.setEnabled(True)
        self.icona()

    # MARK: aspetto

    def mostra(self, testo):
        self.stato.setText(testo)

    def icona(self):
        """Tre abeti, la Foresta. Mentre lavora pulsano piano; dopo un errore c'è il
        triangolo finché un giro non va a buon fine."""
        if self.errore:
            self.pulsa.stop()
            self.vassoio.setIcon(QIcon.fromTheme("dialog-warning"))
            self.vassoio.setToolTip("ProjectsWallpaper: l'ultimo giro non è andato, vedi il menu")
            return
        if self.occupata:
            if not self.pulsa.isActive():
                self.fase = 0.0
                self.pulsa.start()
            self.vassoio.setToolTip("ProjectsWallpaper: aggiorno lo sfondo…")
        else:
            self.pulsa.stop()
            self.vassoio.setToolTip("ProjectsWallpaper")
        self.disegna(1.0)

    def battito(self):
        self.fase += self.pulsa.interval() / 1000
        self.disegna(0.65 + 0.35 * math.cos(2 * math.pi * self.fase / 1.8))

    def disegna(self, opacita):
        colore = QColor(self.app.palette().windowText().color())
        icona = QIcon()
        for lato in (22, 44):
            icona.addPixmap(foresta(lato, colore, opacita))
        self.vassoio.setIcon(icona)


def generato():
    """Il campo "generato" di info.json: cambia a ogni foto nuova."""
    try:
        richiesta = urllib.request.Request(INFO, headers={"Cache-Control": "no-cache"})
        with urllib.request.urlopen(richiesta, timeout=20) as r:
            return json.load(r).get("generato")
    except Exception:
        return None


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("ProjectsWallpaper")
    app.setDesktopFileName("projectswallpaper")
    app.setQuitOnLastWindowClosed(False)

    # Una sola istanza: se ce n'è già una che ascolta, questa esce.
    prova = QLocalSocket()
    prova.connectToServer(NOME_ISTANZA)
    if prova.waitForConnected(300):
        return 0
    QLocalServer.removeServer(NOME_ISTANZA)
    server = QLocalServer()
    server.listen(NOME_ISTANZA)

    if not QSystemTrayIcon.isSystemTrayAvailable():
        registra("nessun vassoio di sistema: l'app non può mostrarsi")
    tenuta = App(app)  # noqa: F841 — tiene vivi vassoio e timer
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
