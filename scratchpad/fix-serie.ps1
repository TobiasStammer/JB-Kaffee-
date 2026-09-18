$ErrorActionPreference = 'Stop'
$root = '/Users/tobiasstammer/JB-Kaffee-'
. "$root/wc-lib.ps1" | Out-Null
$data = Get-Content "$root/nivona-products.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$lineOf = @{}
foreach ($m in $data.machines) { $lineOf[$m.sku] = $m.line }

$skus = @('nivona-cube-4','nivona-5er','nivona-7er','nivona-nivo-7000','nivona-nivo-8000','nivona-nivo-9000')
foreach ($sku in $skus) {
  $wcp = @(wc GET "products?sku=$sku&status=any")[0]
  if (-not $wcp) { Write-Host "[fehlt] $sku" -ForegroundColor Yellow; continue }
  $line = $lineOf[$sku]
  $farbeAttr = $wcp.attributes | Where-Object { $_.name -eq 'Farbe' } | Select-Object -First 1
  $attrs = @(
    @{ name = 'Serie'; position = 1; visible = $true; variation = $false; options = @($line) }
    @{ name = 'Farbe'; position = 0; visible = $true; variation = $true; options = @($farbeAttr.options) }
  )
  $r = wc PUT "products/$($wcp.id)" @{ attributes = $attrs }
  $names = ($r.attributes | ForEach-Object { "$($_.name)=$($_.options -join '/')" }) -join ' | '
  Write-Host ("[ok] {0,-20} {1}" -f $sku, $names)
}
