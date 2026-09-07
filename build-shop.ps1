# build-shop.ps1 - legt die JURA-Kategorien + Haushalt-Kaffeevollautomaten als
# WooCommerce-Produkte an (Status = draft). Idempotent per Slug/SKU.
# Daten: jura-products.json (Bilder/Preise/Namen von de.jura.com).
#   .\build-shop.ps1
$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$root\wc-lib.ps1" | Out-Null

$data = Get-Content "$root\jura-products.json" -Raw -Encoding UTF8 | ConvertFrom-Json

# ---------- Kategorien ----------
function Ensure-Cat($name, $slug, $parentId) {
  $hit = @(wc GET "products/categories?slug=$slug") | Select-Object -First 1
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
$idZubehoer = Ensure-Cat $c.zubehoer.name $c.zubehoer.slug $idParent
$idPflege   = Ensure-Cat $c.pflege.name   $c.pflege.slug   $idParent

# ---------- Haushalt-Kaffeevollautomaten ----------
$shortHtml = @'
<p>Kaffeevollautomat der Marke JURA. Verkauf, Beratung, Vorf&uuml;hrung und Service durch Ihre autorisierte JURA-Servicestelle in Hofheim-Langenhain.</p>
'@

foreach ($p in $data.haushalt) {
  $existing = @(wc GET "products?sku=$($p.sku)&status=any") | Select-Object -First 1
  $body = @{
    name              = $p.name
    type              = 'simple'
    sku               = $p.sku
    regular_price     = $p.price
    status            = 'draft'
    catalog_visibility= 'visible'
    manage_stock      = $false
    categories        = @(@{ id = $idHaushalt })
    short_description  = $shortHtml
    description        = $shortHtml
    attributes        = @(
      @{ name = 'Serie'; visible = $true; options = @($p.line) }
    )
    meta_data         = @(
      @{ key = '_kt_jura_source'; value = $p.url }
    )
  }
  if ($existing) {
    $r = wc PUT "products/$($existing.id)" $body
    $act = 'aktualisiert'
  } else {
    # Bild nur beim Neuanlegen mitgeben (WooCommerce sideloaded es vom JURA-Server)
    $body.images = @(@{ src = $p.img; alt = $p.name })
    $r = wc POST 'products' $body
    $act = 'neu (draft)'
  }
  Write-Host ("[{0,-14}] {1,-38} id={2,-5} {3} EUR  Bild={4}" -f $act, $p.name, $r.id, $r.regular_price, (@($r.images).Count))
}

Write-Host "`nFertig. Alle Produkte Status = draft. Pruefen: wp-admin -> Produkte." -ForegroundColor Cyan
