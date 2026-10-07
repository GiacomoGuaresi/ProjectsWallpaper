// ProjectsWallpaper nella barra dei menu. La lancia il LaunchAgent
// it.giacomoguaresi.projectswallpaper all'accesso; fa il giro di
// aggiorna-sfondo.sh ogni ora al minuto 12 (poco dopo la pipeline, che parte al
// 7), al risveglio e all'avvio, e dal menu fa rigenerare la foto alla pipeline.
// La compila installa.sh con swiftc: niente progetto Xcode.

import AppKit

let cartella = NSHomeDirectory() + "/Library/Application Support/ProjectsWallpaper"
let script = cartella + "/aggiorna-sfondo.sh"
let percorsoLog = NSHomeDirectory() + "/Library/Logs/ProjectsWallpaper.log"
let funzione = URL(string: "https://fvsohjlrulwabvfvcfxo.supabase.co/functions/v1/foresta-aggiorna")!
let info = URL(string: "https://giacomoguaresi.github.io/ProjectsWallpaper/info.json")!
let attesaMassima: TimeInterval = 300   // un giro della pipeline, deploy compreso, ne dura un paio di minuti
let minutoDelGiro = 12

final class App: NSObject, NSApplicationDelegate {
  let voce = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  let stato = NSMenuItem(title: "Avvio…", action: nil, keyEquivalent: "")
  var aggiorna: NSMenuItem!
  var scarica: NSMenuItem!
  var orologio: Timer?
  var occupata = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    let menu = NSMenu()
    menu.autoenablesItems = false
    stato.isEnabled = false
    menu.addItem(stato)
    menu.addItem(.separator())
    aggiorna = menu.addItem(withTitle: "Aggiorna ora", action: #selector(aggiornaOra), keyEquivalent: "r")
    scarica = menu.addItem(withTitle: "Scarica l'ultima foto", action: #selector(scaricaOra), keyEquivalent: "")
    menu.addItem(.separator())
    menu.addItem(withTitle: "Apri il log", action: #selector(apriLog), keyEquivalent: "")
    menu.addItem(withTitle: "Esci", action: #selector(esci), keyEquivalent: "q")
    for v in menu.items { v.target = self }
    voce.menu = menu
    icona(.riposo)

    NSWorkspace.shared.notificationCenter.addObserver(
      self, selector: #selector(risveglio), name: NSWorkspace.didWakeNotification, object: nil)
    pianifica()
    Task { await giro(rigenerando: false) }
  }

  // MARK: orologio

  // Il prossimo minuto 12. Un Timer non scatta durante lo stop: al risveglio si ripianifica.
  func pianifica() {
    orologio?.invalidate()
    let cal = Calendar.current
    let prossimo = cal.nextDate(after: Date(), matching: DateComponents(minute: minutoDelGiro, second: 0),
                                matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600)
    let t = Timer(fire: prossimo, interval: 0, repeats: false) { [weak self] _ in
      guard let self else { return }
      self.pianifica()
      Task { await self.giro(rigenerando: false) }
    }
    t.tolerance = 30
    RunLoop.main.add(t, forMode: .common)
    orologio = t
  }

  @objc func risveglio() {
    pianifica()
    // Qualche secondo perché torni la rete.
    Task {
      try? await Task.sleep(nanoseconds: 10_000_000_000)
      await giro(rigenerando: false)
    }
  }

  // MARK: azioni

  @objc func aggiornaOra() { Task { await giro(rigenerando: true) } }
  @objc func scaricaOra() { Task { await giro(rigenerando: false) } }
  @objc func apriLog() { NSWorkspace.shared.open(URL(fileURLWithPath: percorsoLog)) }
  @objc func esci() { NSApp.terminate(nil) }

  @MainActor
  func giro(rigenerando: Bool) async {
    if occupata { return }
    occupata = true
    aggiorna.isEnabled = false
    scarica.isEnabled = false
    icona(.lavora)
    var finale = Aspetto.riposo
    defer {
      occupata = false
      aggiorna.isEnabled = true
      scarica.isEnabled = true
      icona(finale)
    }
    if rigenerando { await rigenera() }
    mostra("Aggiorno lo sfondo…")
    let (esito, ultima) = await lanciaScript()
    if esito == 0 {
      mostra("Ultimo controllo: \(ora())" + (ultima.contains("sfondo aggiornato") ? " · sfondo nuovo" : ""))
    } else {
      mostra("Errore alle \(ora()): \(ultima.isEmpty ? "vedi il log" : ultima)")
      finale = .errore
    }
  }

  // Fa partire la pipeline e aspetta la foto nuova. Se non riesce si scarica comunque l'ultima.
  @MainActor
  func rigenera() async {
    mostra("Genero la foto nuova…")
    let prima = await generato()
    var richiesta = URLRequest(url: funzione, timeoutInterval: 30)
    richiesta.httpMethod = "POST"
    guard let (dati, risposta) = try? await URLSession.shared.data(for: richiesta),
          (risposta as? HTTPURLResponse)?.statusCode == 200,
          let json = try? JSONSerialization.jsonObject(with: dati) as? [String: Any] else {
      registra("non riesco a far partire la pipeline: scarico l'ultima foto")
      return
    }
    switch json["stato"] as? String {
    case "avviato", "in-corso": break
    case "recente": return
    default:
      registra("risposta inattesa dalla pipeline: scarico l'ultima foto")
      return
    }
    let inizio = Date()
    while Date().timeIntervalSince(inizio) < attesaMassima {
      try? await Task.sleep(nanoseconds: 5_000_000_000)
      let secondi = Int(Date().timeIntervalSince(inizio))
      mostra("Genero la foto nuova… \(secondi / 60):\(String(format: "%02d", secondi % 60))")
      if let adesso = await generato(), adesso != prima { return }
    }
    registra("la foto nuova non è arrivata in \(Int(attesaMassima / 60)) minuti: scarico quella che c'è")
  }

  // Il campo "generato" di info.json: cambia a ogni foto nuova.
  func generato() async -> String? {
    var richiesta = URLRequest(url: info, timeoutInterval: 20)
    richiesta.cachePolicy = .reloadIgnoringLocalCacheData
    guard let (dati, _) = try? await URLSession.shared.data(for: richiesta),
          let json = try? JSONSerialization.jsonObject(with: dati) as? [String: Any] else { return nil }
    return json["generato"] as? String
  }

  // aggiorna-sfondo.sh con l'output in coda al log; restituisce l'esito e l'ultima riga.
  func lanciaScript() async -> (Int32, String) {
    await withCheckedContinuation { continua in
      let p = Process()
      p.executableURL = URL(fileURLWithPath: "/bin/bash")
      p.arguments = [script]
      let tubo = Pipe()
      p.standardOutput = tubo
      p.standardError = tubo
      p.terminationHandler = { p in
        let dati = tubo.fileHandleForReading.readDataToEndOfFile()
        aggiungiAlLog(dati)
        let testo = String(decoding: dati, as: UTF8.self)
        let ultima = testo.split(separator: "\n").last.map(String.init) ?? ""
        // Senza la data che mette log() nello script.
        let pulita = ultima.count > 20 && ultima.first?.isNumber == true ? String(ultima.dropFirst(20)) : ultima
        continua.resume(returning: (p.terminationStatus, pulita))
      }
      do { try p.run() } catch {
        continua.resume(returning: (-1, "non riesco a lanciare \(script)"))
      }
    }
  }

  // MARK: aspetto

  func mostra(_ testo: String) { stato.title = testo }

  func registra(_ testo: String) {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    aggiungiAlLog(Data("\(f.string(from: Date())) \(testo)\n".utf8))
  }

  func ora() -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f.string(from: Date())
  }

  enum Aspetto { case riposo, lavora, errore }

  // Tre abeti, la Foresta. Mentre lavora pulsano piano; dopo un errore c'è il
  // triangolo col punto esclamativo finché un giro non va a buon fine.
  // L'immagine sta in un NSImageView sopra il pulsante perché solo lì si può animare.
  lazy var vista: NSImageView = {
    let v = NSImageView()
    v.translatesAutoresizingMaskIntoConstraints = false
    v.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
    v.wantsLayer = true
    voce.button?.addSubview(v)
    if let b = voce.button {
      NSLayoutConstraint.activate([
        v.centerXAnchor.constraint(equalTo: b.centerXAnchor),
        v.centerYAnchor.constraint(equalTo: b.centerYAnchor),
      ])
    }
    return v
  }()

  static let foresta: NSImage = {
    // Un abete: tre palchi sovrapposti, che si stringono salendo, e il tronco.
    func abete(_ p: NSBezierPath, x: CGFloat, base: CGFloat, h: CGFloat, w: CGFloat) {
      for i in 0..<3 {
        let f = CGFloat(i) / 3
        let y0 = base + h * 0.18 + h * 0.82 * f * 0.62
        let larg = w * (1 - f * 0.35)
        p.move(to: NSPoint(x: x - larg / 2, y: y0))
        p.line(to: NSPoint(x: x + larg / 2, y: y0))
        p.line(to: NSPoint(x: x, y: min(y0 + h * 0.41, base + h)))
        p.close()
      }
      p.appendRect(NSRect(x: x - w * 0.08, y: base, width: w * 0.16, height: h * 0.2))
    }
    let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
      let p = NSBezierPath()
      abete(p, x: 4.5, base: 2, h: 10, w: 7)
      abete(p, x: 13.5, base: 2, h: 11, w: 7.5)
      abete(p, x: 9, base: 2, h: 14.5, w: 9)
      NSColor.black.setFill()
      p.fill()
      return true
    }
    img.isTemplate = true
    img.accessibilityDescription = "ProjectsWallpaper"
    return img
  }()

  func icona(_ aspetto: Aspetto) {
    let img = aspetto == .errore
      ? NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "ProjectsWallpaper")
      : App.foresta
    img?.isTemplate = true
    vista.image = img
    vista.layer?.removeAnimation(forKey: "pulsa")
    if aspetto == .lavora {
      let a = CABasicAnimation(keyPath: "opacity")
      a.fromValue = 1
      a.toValue = 0.3
      a.duration = 0.9
      a.autoreverses = true
      a.repeatCount = .infinity
      a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      vista.layer?.add(a, forKey: "pulsa")
    }
    voce.button?.toolTip = switch aspetto {
    case .riposo: "ProjectsWallpaper"
    case .lavora: "ProjectsWallpaper: aggiorno lo sfondo…"
    case .errore: "ProjectsWallpaper: l'ultimo giro non è andato, vedi il menu"
    }
  }
}

func aggiungiAlLog(_ dati: Data) {
  guard !dati.isEmpty else { return }
  if let h = FileHandle(forWritingAtPath: percorsoLog) {
    h.seekToEndOfFile()
    h.write(dati)
    h.closeFile()
  } else {
    FileManager.default.createFile(atPath: percorsoLog, contents: dati)
  }
}

let app = NSApplication.shared
let delegato = App()
app.delegate = delegato
app.setActivationPolicy(.accessory)
app.run()
