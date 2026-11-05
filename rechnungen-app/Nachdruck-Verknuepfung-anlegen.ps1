# Legt auf dem Desktop die Verknuepfung "Rechnungen nachdrucken" an (oeffnet die Nachdruck-Seite wie eine eigene App).
# Aufruf auf JEDEM Rechner einmal: Rechtsklick -> "Mit PowerShell ausfuehren".
$ordner = $PSScriptRoot
$lokal = Join-Path $env:LOCALAPPDATA 'Rechnungen-Nachdruck'
New-Item -ItemType Directory -Force $lokal | Out-Null
if (Test-Path (Join-Path $ordner 'icon.ico')) { Copy-Item (Join-Path $ordner 'icon.ico') (Join-Path $lokal 'icon.ico') -Force }
$url = 'file:///' + ((Join-Path $ordner 'index.html') -replace '\', '/')
$browser = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
             "$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe") |
           Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $browser) { Write-Host 'Weder Edge noch Chrome gefunden.' -ForegroundColor Yellow; exit 1 }
$lnk = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Rechnungen nachdrucken.lnk'))
$lnk.TargetPath = $browser
$lnk.Arguments = "--app=$url --user-data-dir=`"$(Join-Path $lokal 'profil')`" --allow-file-access-from-files --window-size=1100,800"
$lnk.Description = 'Ausgangsrechnungen nachdrucken'
if (Test-Path (Join-Path $lokal 'icon.ico')) { $lnk.IconLocation = (Join-Path $lokal 'icon.ico') + ',0' }
$lnk.Save()
Write-Host "Verknuepfung 'Rechnungen nachdrucken' angelegt (Browser: $browser)"
