# set-reduced-tax-class.ps1
# Setzt die Steuerklasse "Reduced rate" (7%) fuer Kaffee- und Tee-Produkte.
$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null

$ids = @(2267,2265,2263,2261,2259,2257,899,898)
foreach ($id in $ids) {
  $r = wc PUT "products/$id" @{ tax_class = 'reduced-rate' }
  Write-Host ("id={0,-6} tax_class={1,-14} name={2}" -f $r.id, $r.tax_class, $r.name)
}
Write-Host "Fertig." -ForegroundColor Green
