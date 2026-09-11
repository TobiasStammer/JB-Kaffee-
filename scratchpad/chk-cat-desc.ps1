$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null
$c = wc GET 'products/categories?slug=jura-kaffeevollautomaten'
$c | ConvertTo-Json -Depth 5
