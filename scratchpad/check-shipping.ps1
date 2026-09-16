$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null
function Norm($r) { $r = @($r); if ($r.Count -eq 1 -and $r[0].Count -gt 1) { $r = @($r[0]) }; $r }

Write-Host "=== Shipping classes ===" -ForegroundColor Cyan
$cls = Norm (wc GET 'products/shipping_classes')
$cls | ForEach-Object { Write-Host ("id={0,-5} slug={1,-20} name={2,-25} count={3}" -f $_.id, $_.slug, $_.name, $_.count) }

Write-Host "`n=== Shipping zones ===" -ForegroundColor Cyan
$zones = Norm (wc GET 'shipping/zones')
foreach ($z in $zones) {
  Write-Host ("Zone " + $z.id + ': ' + $z.name)
  $methods = Norm (wc GET "shipping/zones/$($z.id)/methods")
  foreach ($m in $methods) {
    Write-Host ("  method_id=" + $m.method_id + " instance=" + $m.instance_id + " enabled=" + $m.enabled + " title=" + $m.title)
  }
}
