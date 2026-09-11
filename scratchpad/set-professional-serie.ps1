# set-professional-serie.ps1
# Ergaenzt das Attribut "Serie" (wie bei den Haushaltsgeraeten) bei den
# JURA-Professional-Produkten, damit sie sich in Serien-Kacheln (W/X/GIGA)
# einsortieren lassen.
$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null

$items = @(
  @{ id = 746; serie = 'W' }     # W4
  @{ id = 744; serie = 'W' }     # W8
  @{ id = 742; serie = 'X' }     # X4
  @{ id = 740; serie = 'X' }     # X4c
  @{ id = 738; serie = 'X' }     # X10
  @{ id = 736; serie = 'X' }     # X10c
  @{ id = 734; serie = 'GIGA' }  # GIGA X3
  @{ id = 732; serie = 'GIGA' }  # GIGA X3c
  @{ id = 730; serie = 'GIGA' }  # GIGA X8
  @{ id = 728; serie = 'GIGA' }  # GIGA X8c
)
foreach ($it in $items) {
  $body = @{ attributes = @(@{ name = 'Serie'; options = @($it.serie); visible = $true; variation = $false }) }
  $r = wc PUT "products/$($it.id)" $body
  $s = ($r.attributes | Where-Object { $_.name -eq 'Serie' }).options -join ','
  Write-Host ("id={0,-5} serie={1,-6} name={2}" -f $r.id, $s, $r.name)
}
Write-Host "Fertig." -ForegroundColor Green
