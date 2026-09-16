$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null
function Norm($r) { $r = @($r); if ($r.Count -eq 1 -and $r[0].Count -gt 1) { $r = @($r[0]) }; $r }
$p = Norm (wc GET 'products?per_page=100&status=publish')
Write-Host ("total products: " + $p.Count)
$p | ForEach-Object {
  $cats = ($_.categories | ForEach-Object { $_.name }) -join ','
  $shipCls = $_.shipping_class
  Write-Host ("{0,-6} w={1,-6} sc={2,-10} type={3,-9} cats={4,-30} {5}" -f $_.id, $_.weight, $shipCls, $_.type, $cats, $_.name)
}
