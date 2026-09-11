$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null
$all = @()
$page = 1
while ($true) {
  $batch = @(wc GET "products?per_page=100&page=$page&status=publish")
  if ($batch.Count -eq 1 -and $batch[0].Count -gt 1) { $batch = @($batch[0]) }
  if (-not $batch -or $batch.Count -eq 0) { break }
  $all += $batch
  if ($batch.Count -lt 100) { break }
  $page++
}
$out = $all | Select-Object id, name, sku, price, type, @{n='cats';e={($_.categories | ForEach-Object { $_.name }) -join '|'}}
$out | ConvertTo-Json -Depth 5 | Set-Content "$root\scratchpad\wc-products-dump.json" -Encoding utf8
Write-Host ("Total products: " + $all.Count)
