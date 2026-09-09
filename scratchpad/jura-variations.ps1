$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. "$root\wc-lib.ps1" | Out-Null

function Rows($resp) {
  $r = @($resp)
  if ($r.Count -eq 1 -and $r[0].Count -gt 1) { $r = @($r[0]) }
  $r
}

$cat = (Rows (wc GET 'products/categories?slug=jura-kaffeevollautomaten'))[0]
$items = Rows (wc GET "products?per_page=100&status=publish&category=$($cat.id)")
Write-Host ("{0} Produkte" -f $items.Count)
foreach ($p in $items) {
  $farb = @(($p.attributes | Where-Object { $_.name -eq 'Farbe' }).options)
  Write-Host ("`n=== {0}  [{1}]  id={2}  farben={3}" -f $p.name, $p.type, $p.id, ($farb -join ' / '))
  Write-Host ("    main-img: {0}" -f $p.images[0].src)
  if ($p.type -eq 'variable') {
    $vs = Rows (wc GET "products/$($p.id)/variations?per_page=30")
    foreach ($x in $vs) {
      $col = ($x.attributes | Where-Object { $_.name -eq 'Farbe' }).option
      Write-Host ("    - {0,-26} img={1}" -f $col, $x.image.src)
    }
  }
}
