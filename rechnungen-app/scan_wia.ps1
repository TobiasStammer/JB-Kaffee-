# Scannt ueber WIA und speichert JPEGs. Zuerst direkt aus dem Papiereinzug (alle eingelegten Seiten, ohne Dialog).
# Papierquelle ist immer der Einzug (kein Dialog). Liegt kein Papier im Einzug: Exitcode 4.
# Aufruf: powershell -STA -File scan_wia.ps1 <Zieldatei.jpg>
#   Bei mehreren Seiten: <Ziel>-01.jpg, <Ziel>-02.jpg ...
# Exitcode: 0 = gescannt, 3 = abgebrochen/nichts gescannt, 2 = Fehler, 4 = Einzug leer
param([Parameter(Mandatory = $true)][string]$Ziel)
$jpeg = '{B96B3CAE-0728-11D3-9D7B-0000F81EF32E}'
function Setze($obj, $id, $wert) {
    try { $p = $obj.Properties | Where-Object { $_.PropertyID -eq $id }; if ($p) { $p.Value = $wert } } catch { }
}
try {
    $stamm = [IO.Path]::Combine([IO.Path]::GetDirectoryName($Ziel), [IO.Path]::GetFileNameWithoutExtension($Ziel))
    $anzahl = 0
    $fehler = ''
    try {
        $dm = New-Object -ComObject WIA.DeviceManager
        # Jede Seite mit frischer Verbindung: nach einer Seite (Pages=1) bleibt das Gerät sonst "ausgelastet"
        while ($true) {
            $dev = $null
            foreach ($info in $dm.DeviceInfos) { if ($info.Type -eq 1) { $dev = $info.Connect(); break } }
            if (-not $dev) { break }
            Setze $dev 3088 1      # Papierquelle = Einzug (wird bei jedem Connect zurückgesetzt)
            Setze $dev 3096 1      # eine Seite je Durchgang (0 = "Falscher Parameter")
            $item = $dev.Items.Item(1)
            Setze $item 6146 1     # Farbe
            Setze $item 6147 200   # dpi horizontal
            Setze $item 6148 200   # dpi vertikal
            Setze $item 6149 0; Setze $item 6150 0
            Setze $item 6151 1654  # A4 bei 200 dpi
            Setze $item 6152 2339
            $bild = $null; $fehler = ''
            for ($v = 0; $v -lt 4; $v++) {
                try { $bild = $item.Transfer($jpeg); $fehler = ''; break } catch {
                    $fehler = $_.Exception.Message
                    if ($fehler -notmatch '0x80210006|ausgelastet|busy') { break }
                    Start-Sleep -Seconds 2
                }
            }
            if ($fehler) { try { Add-Content -LiteralPath (Join-Path (Split-Path $PSCommandPath) 'scan_fehler.log') -Value ("{0} Seite {1}: {2}" -f (Get-Date -Format s), ($anzahl + 1), $fehler) } catch { } }
            if ($fehler -or $null -eq $bild) { break }   # Einzug leer / Ende
            $anzahl++
            $datei = "{0}-{1:D2}.jpg" -f $stamm, $anzahl
            if (Test-Path -LiteralPath $datei) { Remove-Item -LiteralPath $datei -Force }
            $bild.SaveFile($datei)
            $bild = $null; $item = $null; $dev = $null
            [GC]::Collect(); [GC]::WaitForPendingFinalizers()
            Start-Sleep -Seconds 1
            if ($anzahl -ge 60) { break }
        }
    } catch { }
    if ($anzahl -gt 0) { exit 0 }
    # Papierquelle ist dauerhaft der Einzug: kein Flachbett-Dialog
    if ($fehler -match '0x80210003|paper|Papier') { exit 4 }
    if ($fehler) { Write-Error $fehler; exit 2 }
    exit 4
} catch {
    Write-Error $_.Exception.Message
    exit 2
}
