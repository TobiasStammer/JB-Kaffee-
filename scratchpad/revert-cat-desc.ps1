$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null
$r = wc PUT 'products/categories/19' @{ description = '' }
$r | Select-Object id,description
