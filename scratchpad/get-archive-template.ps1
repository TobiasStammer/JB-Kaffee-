$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wp-lib.ps1" | Out-Null
$t = wp GET '/wp/v2/templates/extendable//archive-product'
$t.content.raw | Out-File -FilePath "$root\scratchpad\archive-product-template.html" -Encoding utf8
Write-Host ("length: " + $t.content.raw.Length)
