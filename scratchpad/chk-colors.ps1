$ErrorActionPreference='Stop'
. "C:\Homepage\Neue Seite 2026\wc-lib.ps1" | Out-Null
$catResp = wc GET "products/categories?slug=jura-kaffeevollautomaten"
$cat = @($catResp)[0]
$itemsResp = wc GET "products?per_page=100&status=any&category=$($cat.id)"
$items = @($itemsResp)
foreach ($p in ($items | Sort-Object name)) {
  $farbe = (($p.attributes | Where-Object { $_.name -eq 'Farbe' }).options -join '/')
  $nvar = 0
  if ($p.type -eq 'variable') { $vr = wc GET "products/$($p.id)/variations?per_page=50"; $nvar = @($vr).Count }
  "{0,-6} {1,-32} {2,-9} Farbe=[{3}] Var={4}" -f $p.sku, $p.name, $p.type, $farbe, $nvar
}
