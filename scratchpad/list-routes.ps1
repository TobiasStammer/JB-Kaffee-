$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wp-lib.ps1" | Out-Null
$idx = wp GET '/'
$idx.routes.PSObject.Properties.Name | Where-Object { $_ -match 'redirect|seo|beyond' } | Sort-Object
