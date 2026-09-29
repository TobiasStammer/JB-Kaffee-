$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null
$catResp = wc GET 'products/categories?slug=nivona-kaffeevollautomaten'
$cat = @($catResp)[0]
$items = @(wc GET "products?per_page=100&status=publish&category=$($cat.id)")
if ($items.Count -eq 1 -and $items[0].Count -gt 1) { $items = @($items[0]) }
Write-Host "Produkte gefunden:" $items.Count

$lieferzeitAttr = @{ id = 1; name = 'Lieferzeit'; slug = 'pa_lieferzeit'; position = 2; visible = $true; variation = $false; options = @('1-3 Tage') }

foreach ($p in $items) {
  $hasLZ = ($p.attributes | Where-Object { $_.name -eq 'Lieferzeit' })
  if ($hasLZ) { Write-Host ("SKIP (schon vorhanden): {0}" -f $p.name); continue }
  $newAttrs = @($p.attributes) + $lieferzeitAttr
  $body = @{ attributes = $newAttrs }
  $r = wc PUT "/products/$($p.id)" $body
  $lz = ($r.attributes | Where-Object { $_.name -eq 'Lieferzeit' }).options -join ', '
  Write-Host ("OK: {0} (id {1}) -> Lieferzeit={2}" -f $r.name, $r.id, $lz)
}
