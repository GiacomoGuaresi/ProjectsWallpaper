# Aggiorna lo sfondo adesso, senza aspettare il giro orario. Lo installa
# installa.ps1 in %LOCALAPPDATA%\ProjectsWallpaper, e projectswallpaper.cmd in
# WindowsApps (già nel PATH) lo rende un comando. Fa partire l'attività
# pianificata, così il giro è quello di sempre, con lo stesso registro.
#
#   projectswallpaper          scarica la foto se è cambiata e la mette come sfondo
#   projectswallpaper forza    la riscarica e la rimette anche se non è cambiata
#   projectswallpaper log      le ultime righe del registro

param([string]$Comando = 'aggiorna')

$ErrorActionPreference = 'Stop'

$Nome = 'ProjectsWallpaper'
$Cartella = Join-Path $env:LOCALAPPDATA 'ProjectsWallpaper'
$Ultima = Join-Path $Cartella 'ultima.png'
$Registro = Join-Path $Cartella 'registro.log'

function Righe { if (Test-Path $Registro) { @(Get-Content $Registro -Encoding UTF8) } else { @() } }

switch ($Comando) {
  'aggiorna' { }
  'forza' {
    # Con una data vecchissima il server non può rispondere "non modificata".
    if (Test-Path $Ultima) { (Get-Item $Ultima).LastWriteTimeUtc = [datetime]'2000-01-01' }
  }
  'log' { Righe | Select-Object -Last 20; exit 0 }
  default { [Console]::Error.WriteLine('uso: projectswallpaper [aggiorna|forza|log]'); exit 2 }
}

if (-not (Get-ScheduledTask -TaskName $Nome -ErrorAction SilentlyContinue)) {
  [Console]::Error.WriteLine("ProjectsWallpaper non è installato: lancia windows\installa.ps1")
  exit 1
}

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
