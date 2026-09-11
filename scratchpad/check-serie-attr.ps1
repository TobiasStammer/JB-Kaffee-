$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null
$p = wc GET "products/2728"
$p.attributes | ConvertTo-Json -Depth 5
