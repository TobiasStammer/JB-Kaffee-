$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null
$all = @()
$page = 1
while ($true) {
  $batch = @(wc GET "products?per_page=100&page=$page&status=publish&category=")
  break
}
$p = @(wc GET "products?per_page=100&status=publish&search=Professional")
if ($p.Count -eq 1 -and $p[0].Count -gt 1) { $p = @($p[0]) }
foreach ($x in $p) { Write-Host ("{0,-6} {1,-14} {2,-10} {3}" -f $x.id, $x.sku, $x.price, $x.name) }
