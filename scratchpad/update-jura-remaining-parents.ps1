# update-jura-remaining-parents.ps1
# Der erste Lauf brach bei der ersten Variante ab (product_invalid_sku),
# dadurch blieben 5 Parent-Produkte unbehandelt. Hier nachgeholt.
$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null

$parents = @(
  @{ id = 458; sku = '15435'; nr = '1120'; title = 'JURA E4 (EA &middot; Piano Black)' }
  @{ id = 456; sku = '15828'; nr = '4355'; title = 'JURA E6 (ED &middot; Dark Inox)' }
  @{ id = 454; sku = '15712'; nr = '1131'; title = 'JURA E8 (ED &middot; Midnight Silver)' }
  @{ id = 444; sku = '15615'; nr = '4358'; title = 'JURA Z10 (EB &middot; Diamond Black)' }
  @{ id = 442; sku = '15609'; nr = '1099'; title = 'JURA Z10 (EB &middot; Aluminium Black)' }
)
foreach ($p in $parents) {
  $r = wc PUT "products/$($p.id)" @{ name = $p.title; sku = "$($p.sku) ($($p.nr))" }
  Write-Host ("id={0,-5} sku={1,-16} name={2}" -f $r.id, $r.sku, $r.name)
}
Write-Host "Fertig." -ForegroundColor Green
