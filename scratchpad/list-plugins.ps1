$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wp-lib.ps1" | Out-Null
$pl = wp GET '/wp/v2/plugins'
$pl | Select-Object plugin,status,name | Format-Table -AutoSize
