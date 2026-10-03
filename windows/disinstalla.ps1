# Toglie l'aggiornamento orario dello sfondo. Lo sfondo attuale resta finché
# non se ne sceglie un altro; la sua foto resta nella cartella dell'app.
#
# Uso: powershell -ExecutionPolicy Bypass -File windows\disinstalla.ps1

$ErrorActionPreference = 'Stop'

Unregister-ScheduledTask -TaskName 'ProjectsWallpaper' -Confirm:$false -ErrorAction SilentlyContinue
Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $env:LOCALAPPDATA 'ProjectsWallpaper\aggiorna-sfondo.ps1')

Write-Host "Disinstallato. Per togliere anche le foto: Remove-Item -Recurse `"$env:LOCALAPPDATA\ProjectsWallpaper`""
