$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null
$m = wc GET 'shipping/zones/1/methods'
$m | ConvertTo-Json -Depth 8
