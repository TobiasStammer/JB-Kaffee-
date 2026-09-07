# build-nivona-shop.ps1 - legt die NIVONA-Kategorien + Kaffeevollautomaten als
# WooCommerce-Produkte an. Idempotent per Slug/SKU. Status wird nur beim
# Neuanlegen gesetzt (draft); bestehende Produkte werden nicht zurueckgesetzt.
# Daten: nivona-products.json (Bilder/Preise/Namen von nivona.com).
#   .\build-nivona-shop.ps1  [-Publish]
param([switch]$Publish)
$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$root\wc-lib.ps1" | Out-Null

$data = Get-Content "$root\nivona-products.json" -Raw -Encoding UTF8 | ConvertFrom-Json

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

foreach ($p in $data.machines) {
  $exResp   = wc GET "products?sku=$($p.sku)&status=any"
  $existing = @($exResp) | Select-Object -First 1
  $body = @{
    name               = $p.name
    type               = 'simple'
    sku                = $p.sku
    regular_price      = $p.price
    catalog_visibility = 'visible'
    manage_stock       = $false
    categories         = @(@{ id = $idHaushalt })
    short_description   = $short
    description         = ("{0}<p>{1}</p>" -f $short, $p.tx)
    attributes         = @(
      @{ name = 'Serie'; visible = $true; options = @($p.line) }
    )
    meta_data          = @(
      @{ key = '_kt_nivona_source'; value = $p.url }
    )
  }
  if ($existing) {
    if ($Publish) { $body.status = 'publish' }
    $r = wc PUT "products/$($existing.id)" $body
    $act = if ($Publish) { 'publiziert' } else { 'aktualisiert' }
  } else {
    $body.status = if ($Publish) { 'publish' } else { 'draft' }
    $body.images = @(@{ src = $p.img; alt = $p.name })
    $r = wc POST 'products' $body
    $act = "neu ($($body.status))"
  }
  Write-Host ("[{0,-12}] {1,-34} id={2,-5} {3} EUR  Bild={4}" -f $act, $p.name, $r.id, $r.regular_price, (@($r.images).Count))
}

Write-Host "`nFertig. NIVONA-Shop-Produkte angelegt." -ForegroundColor Cyan
