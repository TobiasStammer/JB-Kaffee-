$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null
$w = wc GET 'settings/products/woocommerce_weight_unit'
Write-Host ("weight unit: " + $w.value)
