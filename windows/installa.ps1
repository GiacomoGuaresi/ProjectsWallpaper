# Installa l'aggiornamento orario dello sfondo: copia lo script e registra
# l'attività "ProjectsWallpaper" (all'accesso e poi ogni ora), installa il
# comando projectswallpaper, poi fa subito un primo giro. Rilanciabile, anche
# per aggiornare.
#
# Uso, da PowerShell nella cartella del repo:
#   powershell -ExecutionPolicy Bypass -File windows\installa.ps1

$ErrorActionPreference = 'Stop'

$Nome = 'ProjectsWallpaper'
$Cartella = Join-Path $env:LOCALAPPDATA 'ProjectsWallpaper'
$Script = Join-Path $Cartella 'aggiorna-sfondo.ps1'

New-Item -ItemType Directory -Force -Path $Cartella | Out-Null
Copy-Item -Force (Join-Path $PSScriptRoot 'aggiorna-sfondo.ps1') $Script

# Il comando per aggiornare a mano: projectswallpaper [aggiorna|forza|log]. Il .cmd
# va in WindowsApps, che Windows 10 e 11 hanno già nel PATH dell'utente.
Copy-Item -Force (Join-Path $PSScriptRoot 'projectswallpaper.ps1') $Cartella
Copy-Item -Force (Join-Path $PSScriptRoot 'projectswallpaper.cmd') (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps')

# conhost --headless: PowerShell gira senza aprire nemmeno per un attimo una finestra.
$Azione = New-ScheduledTaskAction -Execute 'conhost.exe' `
  -Argument "--headless powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$Script`""
$Inneschi = @(
  (New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"),
  (New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1))
)
# StartWhenAvailable: se il PC era spento o in sospensione, il giro perso parte appena può.
$Impostazioni = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -MultipleInstances IgnoreNew
# Interactive: gira nella sessione dell'utente, l'unica in cui si può cambiare lo sfondo.
$Utente = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $Nome -Action $Azione -Trigger $Inneschi -Settings $Impostazioni `
  -Principal $Utente -Description 'La Foresta di Projects come sfondo, ogni ora' -Force | Out-Null
Start-ScheduledTask -TaskName $Nome

Write-Host "Installato. Primo giro in corso; il registro è in $Cartella\registro.log"
Write-Host "Aggiornare a mano: projectswallpaper (o projectswallpaper forza)"
