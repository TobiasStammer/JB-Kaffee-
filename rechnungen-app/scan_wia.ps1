# Scannt eine Seite ueber den Windows-Scandialog (WIA) und speichert sie als JPEG.
# Aufruf: powershell -STA -File scan_wia.ps1 <Zieldatei.jpg>
# Exitcode: 0 = gescannt, 3 = abgebrochen, 2 = Fehler
param([Parameter(Mandatory = $true)][string]$Ziel)
try {
    $dlg = New-Object -ComObject WIA.CommonDialog
    # Scanner (1), Farbe (1), beste Qualitaet (0x20000), Format JPEG, Geraet nicht erzwingen, Windows-Oberflaeche an, Abbruch ohne Fehler
    $bild = $dlg.ShowAcquireImage(1, 1, 0x20000, '{B96B3CAE-0728-11D3-9D7B-0000F81EF32E}', $false, $true, $false)
    if ($null -eq $bild) { exit 3 }
    if (Test-Path -LiteralPath $Ziel) { Remove-Item -LiteralPath $Ziel -Force }
    $bild.SaveFile($Ziel)
    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 2
}
