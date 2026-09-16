$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null
function Norm($r) { $r = @($r); if ($r.Count -eq 1 -and $r[0].Count -gt 1) { $r = @($r[0]) }; $r }

$r = wc PUT 'settings/tax/woocommerce_tax_classes' @{ value = 'Reduced rate' }
Write-Host ("Steuerklassen-Feld: '" + $r.value + "'")

Start-Sleep -Seconds 2
$classes = Norm (wc GET 'taxes/classes')
Write-Host "Klassen:"
$classes | ForEach-Object { Write-Host ("  " + $_.slug + ' | ' + $_.name) }
