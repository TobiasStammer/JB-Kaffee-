# update-jura-variations.ps1
# Zweiter Durchgang: nur die Farb-Varianten, deren SKU sich vom Parent
# unterscheidet (die mit dem Parent identische "Standardfarb"-Variante wird
# NICHT angefasst - WooCommerce lehnt eine zur eigenen Parent-SKU identische
# Varianten-SKU als "doppelte Artikelnummer" ab, sobald der Parent bereits
# die geklammerte Form traegt; der Parent allein reicht als Kennzeichnung).
$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null

$vars = @(
  @{ pid=460; vid=830; sku='15810'; nr='4354' }                                  # C9 Piano White
  @{ pid=458; vid=826; sku='15433'; nr='1122' }                                  # E4 Piano White
  @{ pid=456; vid=822; sku='15642'; nr='4356'; regular_price='899.00' }          # E6 Piano Black (Preiskorrektur)
  @{ pid=454; vid=814; sku='15749'; nr='1130' }                                  # E8 Cosmic Black
  @{ pid=454; vid=816; sku='15745'; nr='1127'; regular_price='1149.00' }         # E8 Piano Black (Preiskorrektur)
  @{ pid=454; vid=818; sku='15747'; nr='1129' }                                  # E8 Piano White
  @{ pid=444; vid=806; sku='15619'; nr='4357' }                                  # Z10 Diamond White
  @{ pid=442; vid=802; sku='15613'; nr='1100' }                                  # Z10 Aluminium White
)

foreach ($v in $vars) {
  $body = @{ sku = "$($v.sku) ($($v.nr))" }
  if ($v.regular_price) { $body.regular_price = $v.regular_price }
  $r = wc PUT "products/$($v.pid)/variations/$($v.vid)" $body
  Write-Host ("parent={0,-5} varId={1,-5} sku={2,-16} price={3}" -f $v.pid, $r.id, $r.sku, $r.price)
}
Write-Host "Fertig." -ForegroundColor Green
