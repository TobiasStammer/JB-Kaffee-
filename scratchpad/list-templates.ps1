$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wp-lib.ps1" | Out-Null
$t = wp GET '/wp/v2/templates'
$t | Select-Object id,slug,title | Format-Table -AutoSize
