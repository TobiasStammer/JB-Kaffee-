$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null
$ids = @(460,458,456,454,444,442)
foreach ($id in $ids) {
  $p = wc GET "products/$id"
  Write-Host ("=== " + $p.name + " (id=$id) ===")
  $vars = @(wc GET "products/$id/variations?per_page=50")
  if ($vars.Count -eq 1 -and $vars[0].Count -gt 1) { $vars = @($vars[0]) }
  foreach ($v in $vars) {
    $attrs = ($v.attributes | ForEach-Object { $_.option }) -join ','
    Write-Host ("  varId=$($v.id) sku=$($v.sku) price=$($v.price) attrs=$attrs")
  }
}
