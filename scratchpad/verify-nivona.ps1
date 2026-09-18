$ErrorActionPreference = 'Stop'
$root = '/Users/tobiasstammer/JB-Kaffee-'
. "$root/wc-lib.ps1" | Out-Null
$skus = @('nivona-cube-4','nivona-5er','nivona-7er','nivona-nivo-7000','nivona-nivo-8000','nivona-nivo-9000')
foreach ($s in $skus) {
  $p = @(wc GET "products?sku=$s&status=any")[0]
  $vars = @(wc GET "products/$($p.id)/variations?per_page=100")
  Write-Host ("{0} (id={1}, type={2}): {3} Variationen -> {4}" -f $s, $p.id, $p.type, $vars.Count, (($vars | ForEach-Object { ($_.attributes | Where-Object {$_.name -eq 'Farbe'}).option + '=' + $_.regular_price }) -join ' | '))
}
