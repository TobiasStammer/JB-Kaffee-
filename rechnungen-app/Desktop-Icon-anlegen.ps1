# Legt die Desktop-Verknuepfung "Rechnungen DATEV" an (mit lokalem Icon, unabhaengig von Netzlaufwerken).
# Aufruf: Rechtsklick -> "Mit PowerShell ausfuehren"  oder  powershell -ExecutionPolicy Bypass -File Desktop-Icon-anlegen.ps1
$app   = $PSScriptRoot
$lokal = Join-Path $env:LOCALAPPDATA "Rechnungen-App"
New-Item -ItemType Directory -Force $lokal | Out-Null
Copy-Item (Join-Path $app "static\icon.ico") (Join-Path $lokal "rechnungen-app-2.ico") -Force

# pythonw.exe der installierten Python-Version suchen (ohne Konsolenfenster)
$pyw = (Get-Command pythonw.exe -ErrorAction SilentlyContinue).Source
if (-not $pyw -or $pyw -like "*WindowsApps*") {
    $py = (& py -c "import sys; print(sys.executable)" 2>$null)
    if ($py) { $pyw = Join-Path (Split-Path $py) "pythonw.exe" }
}
if (-not $pyw -or -not (Test-Path $pyw)) { Write-Host "pythonw.exe nicht gefunden - ist Python installiert?"; exit 1 }

$ws  = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut((Join-Path ([Environment]::GetFolderPath("Desktop")) "Rechnungen DATEV.lnk"))
$lnk.TargetPath       = $pyw
$lnk.Arguments        = '"' + (Join-Path $app "fenster.pyw") + '"'
$lnk.WorkingDirectory = $app
$lnk.IconLocation     = (Join-Path $lokal "rechnungen-app-2.ico") + ",0"
$lnk.Description      = "Rechnungsverwaltung und DATEV-Export"
$lnk.Save()
& ie4uinit.exe -show 2>$null
Write-Host "Verknuepfung angelegt: $($lnk.FullName)"
