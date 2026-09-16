$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null
function Norm($r) { $r = @($r); if ($r.Count -eq 1 -and $r[0].Count -gt 1) { $r = @($r[0]) }; $r }
$p = Norm (wc GET 'products?per_page=100&status=publish')
$kt = $p | Where-Object { ($_.categories | ForEach-Object { $_.name }) -match 'Kaffee|Tee' -and ($_.categories | ForEach-Object { $_.name }) -notmatch 'Kaffeevollautomat' }
$kt | ForEach-Object { Write-Host ($_.id.ToString().PadRight(6) + ($_.tax_class.PadRight(14)) + ' | ' + $_.name + ' | cats=' + (($_.categories | ForEach-Object { $_.name }) -join ',')) }
