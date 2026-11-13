# Scannt aus dem Papiereinzug des Scanners (Windows.Devices.Scanners, alle eingelegten Seiten in einem Durchgang) und speichert JPEGs.
# Papierquelle ist immer der Einzug (kein Dialog). Liegt kein Papier im Einzug: Exitcode 4.
# Aufruf: powershell -STA -File scan_wia.ps1 <Zieldatei.jpg>   ->  <Ziel>-01.jpg, <Ziel>-02.jpg ...
# Exitcode: 0 = gescannt, 2 = Fehler, 4 = Einzug leer / nichts gescannt
param([Parameter(Mandatory = $true)][string]$Ziel)
$log = Join-Path (Split-Path $PSCommandPath) 'scan_fehler.log'
try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    [void][Windows.Devices.Enumeration.DeviceInformation, Windows.Devices.Enumeration, ContentType = WindowsRuntime]
    [void][Windows.Devices.Scanners.ImageScanner, Windows.Devices.Scanners, ContentType = WindowsRuntime]
    [void][Windows.Storage.StorageFolder, Windows.Storage, ContentType = WindowsRuntime]
    $m = [System.WindowsRuntimeSystemExtensions].GetMethods()
    $opM = $m | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
    $opP = $m | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperationWithProgress`2' } | Select-Object -First 1
    function Warte($op, $typ) { $t = $opM.MakeGenericMethod($typ).Invoke($null, @($op)); [void]$t.Wait(-1); $t.Result }
    function WarteP($op, $typ, $prog) { $t = $opP.MakeGenericMethod($typ, $prog).Invoke($null, @($op)); [void]$t.Wait(-1); $t.Result }

    $sel = [Windows.Devices.Scanners.ImageScanner]::GetDeviceSelector()
    $devs = Warte ([Windows.Devices.Enumeration.DeviceInformation]::FindAllAsync($sel)) ([Windows.Devices.Enumeration.DeviceInformationCollection])
    if ($devs.Count -eq 0) { Write-Error 'Kein Scanner gefunden.'; exit 2 }
    $sc = Warte ([Windows.Devices.Scanners.ImageScanner]::FromIdAsync($devs[0].Id)) ([Windows.Devices.Scanners.ImageScanner])
    if (-not $sc.IsScanSourceSupported([Windows.Devices.Scanners.ImageScannerScanSource]::Feeder)) { Write-Error 'Scanner hat keinen Einzug.'; exit 2 }
    $f = $sc.FeederConfiguration
    try { $f.Format = [Windows.Devices.Scanners.ImageScannerFormat]::Jpeg } catch { }
    try { $f.ColorMode = [Windows.Devices.Scanners.ImageScannerColorMode]::Color } catch { }
    try { $f.AutoDetectPageSize = $true } catch { }
    try { $f.DesiredResolution = New-Object Windows.Devices.Scanners.ImageScannerResolution; } catch { }
    try { $r = $f.DesiredResolution; $r.DpiX = 200; $r.DpiY = 200; $f.DesiredResolution = $r } catch { }
    try { $f.MaxNumberOfPages = 0 } catch { }

    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('scan_' + [guid]::NewGuid().ToString('N'))
    [void](New-Item -ItemType Directory -Path $tmp)
    $ordner = Warte ([Windows.Storage.StorageFolder]::GetFolderFromPathAsync($tmp)) ([Windows.Storage.StorageFolder])
    $res = WarteP ($sc.ScanFilesToFolderAsync([Windows.Devices.Scanners.ImageScannerScanSource]::Feeder, $ordner)) ([Windows.Devices.Scanners.ImageScannerScanResult]) ([uint32])
    $dateien = @(Get-ChildItem -LiteralPath $tmp -File | Sort-Object Name)
    $stamm = [IO.Path]::Combine([IO.Path]::GetDirectoryName($Ziel), [IO.Path]::GetFileNameWithoutExtension($Ziel))
    $n = 0
    foreach ($d in $dateien) {
        $n++
        Move-Item -LiteralPath $d.FullName -Destination ("{0}-{1:D2}.jpg" -f $stamm, $n) -Force
    }
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    if ($n -gt 0) { exit 0 }
    exit 4
} catch {
    try { Add-Content -LiteralPath $log -Value ("{0} {1}" -f (Get-Date -Format s), $_.Exception.ToString()) } catch { }
    $msg = $_.Exception.Message
    if ($msg -match '0x80210003|paper|Papier') { exit 4 }
    Write-Error $msg
    exit 2
}
