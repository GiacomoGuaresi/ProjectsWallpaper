# Aggiorna lo sfondo adesso, senza aspettare il giro orario. Lo installa
# installa.ps1 in %LOCALAPPDATA%\ProjectsWallpaper, e projectswallpaper.cmd in
# WindowsApps (già nel PATH) lo rende un comando. Prima fa rigenerare la foto
# alla pipeline (funzione foresta-aggiorna su Supabase) e aspetta che sia
# pubblicata, poi fa partire l'attività pianificata, così il giro è quello di
# sempre, con lo stesso registro.
#
#   projectswallpaper          rigenera la foto, la scarica e la mette come sfondo
#   projectswallpaper forza    come sopra, e la rimette anche se non è cambiata
#   projectswallpaper scarica  solo scarica l'ultima foto pubblicata, senza rigenerarla
#   projectswallpaper log      le ultime righe del registro

param([string]$Comando = 'aggiorna')

$ErrorActionPreference = 'Stop'

$Nome = 'ProjectsWallpaper'
$Cartella = Join-Path $env:LOCALAPPDATA 'ProjectsWallpaper'
$Ultima = Join-Path $Cartella 'ultima.png'
$Registro = Join-Path $Cartella 'registro.log'
$Funzione = 'https://fvsohjlrulwabvfvcfxo.supabase.co/functions/v1/foresta-aggiorna'
$Info = 'https://giacomoguaresi.github.io/ProjectsWallpaper/info.json'
$AttesaMassima = 300   # secondi: un giro della pipeline, deploy compreso, ne dura un paio

function Righe { if (Test-Path $Registro) { @(Get-Content $Registro -Encoding UTF8) } else { @() } }

# Il campo "generato" di info.json: cambia a ogni foto nuova.
function Generato {
  try { (Invoke-RestMethod -Uri $Info -TimeoutSec 20).generato } catch { $null }
}

# Fa partire la pipeline e aspetta la foto nuova. Se non riesce si scarica comunque l'ultima.
function Rigenera {
  $Prima = Generato
  try {
    $Risposta = Invoke-RestMethod -Method Post -Uri $Funzione -TimeoutSec 30
  } catch {
    Write-Host "non riesco a far partire la pipeline ($($_.Exception.Message)): scarico l'ultima foto"
    return
  }
  switch ($Risposta.stato) {
    'avviato' { Write-Host 'pipeline avviata, aspetto la foto nuova…' }
    'in-corso' { Write-Host 'pipeline già in corso, aspetto la foto nuova…' }
    'recente' { Write-Host 'foto appena rigenerata'; return }
    default { Write-Host "risposta inattesa dalla pipeline: scarico l'ultima foto"; return }
  }
  for ($i = 0; $i -lt $AttesaMassima / 5; $i++) {
    Start-Sleep -Seconds 5
    $Ora = Generato
    if ($Ora -and $Ora -ne $Prima) { Write-Host "foto nuova pubblicata ($Ora)"; return }
  }
  Write-Host "la foto nuova non è arrivata in $($AttesaMassima / 60) minuti: scarico quella che c'è"
}

switch ($Comando) {
  { $_ -in 'aggiorna', 'forza', 'scarica' } { }
  'log' { Righe | Select-Object -Last 20; exit 0 }
  default { [Console]::Error.WriteLine('uso: projectswallpaper [aggiorna|forza|scarica|log]'); exit 2 }
}

if (-not (Get-ScheduledTask -TaskName $Nome -ErrorAction SilentlyContinue)) {
  [Console]::Error.WriteLine("ProjectsWallpaper non è installato: lancia windows\installa.ps1")
  exit 1
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if ($Comando -ne 'scarica') { Rigenera }
# Con una data vecchissima il server non può rispondere "non modificata".
if ($Comando -eq 'forza' -and (Test-Path $Ultima)) { (Get-Item $Ultima).LastWriteTimeUtc = [datetime]'2000-01-01' }

$Prima = (Righe).Count
Start-ScheduledTask -TaskName $Nome

# Start-ScheduledTask non aspetta la fine del giro: si aspetta che il registro cresca e l'attività sia ferma.
for ($i = 0; $i -lt 120; $i++) {
  Start-Sleep -Seconds 1
  $Ora = Righe
  if ($Ora.Count -gt $Prima -and (Get-ScheduledTask -TaskName $Nome).State -ne 'Running') {
    $Ora | Select-Object -Skip $Prima
    exit 0
  }
}
[Console]::Error.WriteLine("Il giro non è finito entro 2 minuti: guarda $Registro")
exit 1
