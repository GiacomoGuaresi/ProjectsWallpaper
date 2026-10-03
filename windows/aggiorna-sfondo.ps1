# Scarica la foto della Foresta e, se è cambiata, la mette come sfondo.
# La lancia l'Utilità di pianificazione ogni ora e all'accesso (attività
# "ProjectsWallpaper"); a mano: Start-ScheduledTask -TaskName ProjectsWallpaper
#
# Funziona con Windows PowerShell 5.1, quello già presente in Windows 10 e 11.

$ErrorActionPreference = 'Stop'

$Indirizzo = 'https://giacomoguaresi.github.io/ProjectsWallpaper/desktop.png'
$Cartella = Join-Path $env:LOCALAPPDATA 'ProjectsWallpaper'
$Ultima = Join-Path $Cartella 'ultima.png'   # l'ultima scaricata, con la data del server
$Registro = Join-Path $Cartella 'registro.log'

function Scrivi([string]$Messaggio) {
  "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Messaggio" | Add-Content -Path $Registro -Encoding UTF8
}

New-Item -ItemType Directory -Force -Path $Cartella | Out-Null
# Qualunque errore non previsto finisce nel registro, invece di perdersi.
trap { Scrivi "errore: $_"; exit 1 }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# If-Modified-Since: se la foto non è cambiata il server risponde 304 e non si scarica niente.
$Richiesta = [Net.HttpWebRequest]::Create($Indirizzo)
$Richiesta.Timeout = 60000
if (Test-Path $Ultima) { $Richiesta.IfModifiedSince = (Get-Item $Ultima).LastWriteTimeUtc }
try {
  $Risposta = $Richiesta.GetResponse()
} catch [Net.WebException] {
  $Stato = $_.Exception.Response
  if ($Stato -and [int]$Stato.StatusCode -eq 304) { Scrivi 'invariata'; exit 0 }
  Scrivi "download non riuscito (offline?): $($_.Exception.Message)"
  exit 0
}

$Scaricata = Join-Path $Cartella 'scaricata.png'
$DataServer = $Risposta.LastModified.ToUniversalTime()   # da leggere prima di chiudere la risposta
$File = $null
try {
  $Flusso = $Risposta.GetResponseStream()
  $File = [IO.File]::Create($Scaricata)
  $Flusso.CopyTo($File)
} finally {
  if ($File) { $File.Dispose() }
  $Risposta.Dispose()
}
(Get-Item $Scaricata).LastWriteTimeUtc = $DataServer

# Ogni foto nuova ha un nome nuovo, così Windows la ricarica di sicuro.
$Nuova = Join-Path $Cartella "foresta-$([DateTimeOffset]::Now.ToUnixTimeSeconds()).png"
Copy-Item $Scaricata $Nuova

# Adattamento "Riempi": la foto copre lo schermo, ritagliando i bordi se il rapporto è diverso.
Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value '10'
Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value '0'

Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public static class Sfondo {
  [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
  public static extern bool SystemParametersInfo(int azione, int param, string percorso, int opzioni);
}
'@
# SPI_SETDESKWALLPAPER = 20; SPIF_UPDATEINIFILE | SPIF_SENDCHANGE = 3
if (-not [Sfondo]::SystemParametersInfo(20, 0, $Nuova, 3)) {
  Scrivi "impostazione non riuscita (errore $([Runtime.InteropServices.Marshal]::GetLastWin32Error()))"
  exit 1
}

# Solo ora la foto conta come "già vista": se qualcosa sopra fallisce, il giro dopo riprova.
Move-Item -Force $Scaricata $Ultima
# Le foto vecchie non servono più: lo sfondo ora punta alla nuova.
Get-ChildItem $Cartella -Filter 'foresta-*.png' | Where-Object FullName -ne $Nuova | Remove-Item -Force
Scrivi "sfondo aggiornato: $(Split-Path $Nuova -Leaf)"
