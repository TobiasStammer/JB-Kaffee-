$ErrorActionPreference = 'Stop'
$root = '/Users/tobiasstammer/JB-Kaffee-'
. "$root/wc-lib.ps1" | Out-Null
$cat = @(wc GET "products/categories?slug=nivona-kaffeevollautomaten")[0]
Write-Host "cat id: $($cat.id)"
$items = @(wc GET "products?per_page=100&status=publish&category=$($cat.id)")
if ($items.Count -eq 1 -and $items[0].Count -gt 1) { $items = @($items[0]) }
Write-Host "count: $($items.Count)"
$items | ForEach-Object { Write-Host ("{0,-30} type={1,-10} status={2,-8} price={3}" -f $_.sku, $_.type, $_.status, $_.price) }
