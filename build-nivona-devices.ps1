# build-nivona-devices.ps1 - legt die NIVONA-Geraete EINZELN an (kein Farbwechsel-
# Dropdown mehr): jede Farbe/jedes Modell ist ein eigenes einfaches WooCommerce-
# Produkt unter dem echten Modellnamen (z.B. "NIVONA NICR 7'93"), statt vorher
# ein variables Produkt "NIVONA 7er-Serie" mit Farbvariationen.
# Ersetzt build-nivona-shop.ps1 + build-shop-nivona-variants.ps1 fuer diese Geraete.
# Daten: nivona-devices.json. Idempotent per SKU. Status wird nur beim Neuanlegen
# gesetzt (draft, ausser -Publish).
#   .\build-nivona-devices.ps1  [-Publish]
param([switch]$Publish)
$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$root\wc-lib.ps1" | Out-Null

$data = Get-Content "$root\nivona-devices.json" -Raw -Encoding UTF8 | ConvertFrom-Json

function Ensure-Cat($name, $slug, $parentId) {
  $hitResp = wc GET "products/categories?slug=$slug"
  $hit = @($hitResp) | Select-Object -First 1
  if ($hit) { Write-Host ("[cat vorhanden] {0,-30} id={1}" -f $slug, $hit.id); return $hit.id }
  $body = @{ name = $name; slug = $slug }
  if ($parentId) { $body.parent = $parentId }
  $r = wc POST 'products/categories' $body
  Write-Host ("[cat neu]       {0,-30} id={1}" -f $slug, $r.id)
  $r.id
}

$c = $data.categories
$idParent   = Ensure-Cat $c.parent.name   $c.parent.slug   $null
$idHaushalt = Ensure-Cat $c.haushalt.name $c.haushalt.slug $idParent

$short = $data.shortHtml

foreach ($d in $data.devices) {
  $name = "NIVONA $($d.art) ($($d.color))"
  $exResp   = wc GET "products?sku=$($d.sku)&status=any"
  $existing = @($exResp) | Select-Object -First 1
  $body = @{
    name               = $name
    type               = 'simple'
    sku                = $d.sku
    regular_price      = $d.price
    catalog_visibility = 'visible'
    manage_stock       = $false
    categories         = @(@{ id = $idHaushalt })
    short_description  = $short
    description        = ("{0}<p>{1}</p>" -f $short, $d.tx)
    attributes         = @(
      @{ name = 'Serie';  visible = $true; options = @($d.serie) }
      @{ name = 'Farbe';  visible = $true; options = @($d.color) }
    )
    meta_data          = @(
      @{ key = '_kt_nivona_art'; value = $d.art }
    )
  }
  if ($existing) {
    if ($Publish) { $body.status = 'publish' }
    $r = wc PUT "products/$($existing.id)" $body
    $act = if ($Publish) { 'publiziert' } else { 'aktualisiert' }
  } else {
    $body.status = if ($Publish) { 'publish' } else { 'draft' }
    $body.images = @(@{ src = $d.img; alt = $name })
    $r = wc POST 'products' $body
    $act = "neu ($($body.status))"
  }
  Write-Host ("[{0,-12}] {1,-34} id={2,-5} {3} EUR  Bild={4}" -f $act, $name, $r.id, $r.regular_price, (@($r.images).Count))
}

Write-Host "`nFertig. $($data.devices.Count) NIVONA-Einzelgeraete angelegt/aktualisiert." -ForegroundColor Cyan
