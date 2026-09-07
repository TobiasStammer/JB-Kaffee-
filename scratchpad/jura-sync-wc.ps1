$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null

$data = Get-Content "$root\jura-products.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$catResp = wc GET 'products/categories?slug=jura-kaffeevollautomaten'
$catId = @($catResp)[0].id
$short = '<p>Kaffeevollautomat der Marke JURA. Verkauf, Beratung, Vorf&uuml;hrung und Service durch Ihre autorisierte JURA-Servicestelle in Hofheim-Langenhain.</p>'

# --- NEU: A8 (15736) + S10 (15775) anlegen, falls nicht vorhanden ---
foreach ($sku in '15736','15775') {
  $p = $data.haushalt | Where-Object { $_.sku -eq $sku } | Select-Object -First 1
  $ex = @(wc GET "products?sku=$sku&status=any")[0]
  if ($ex) { Write-Host "[vorhanden] $sku id=$($ex.id)"; continue }
  $body = @{
    name = $p.name; type = 'simple'; sku = $sku; status = 'draft'
    catalog_visibility = 'visible'; manage_stock = $false
    categories = @(@{ id = $catId })
    short_description = $short; description = $short
    attributes = @(@{ name = 'Serie'; visible = $true; options = @($p.line) })
    meta_data = @(@{ key = '_kt_jura_source'; value = $p.url })
    images = @(@{ src = $p.img; alt = $p.name })
  }
  if ($p.price) { $body.regular_price = $p.price }
  $r = wc POST 'products' $body
  Write-Host ("[neu] {0,-28} id={1}  {2} EUR  Bild={3}" -f $p.name, $r.id, $r.regular_price, (@($r.images).Count))
}

# --- AUSGELAUFEN bei JURA: ENA 8 (15493) + S8 (15483) -> draft + Hinweis ---
$discNote = '<p style="background:#fbeeee;border:1px solid #d8a0a0;border-radius:6px;padding:10px 14px;font-size:13.5px;color:#8a3b3b;margin:0 0 14px"><strong>Nicht mehr im aktuellen JURA-Sortiment.</strong> Nachfolgemodell und Beratung: telefonisch unter 06192 2004363 oder in unserem Gesch&auml;ft in Hofheim-Langenhain. Reparatur und Wartung dieses Modells bieten wir weiterhin an.</p>'
foreach ($sku in '15493','15483') {
  $ex = @(wc GET "products?sku=$sku&status=any")[0]
  if (-not $ex) { Write-Host "[fehlt] $sku"; continue }
  $desc = [string]$ex.description
  if ($desc -notmatch 'Nicht mehr im aktuellen JURA-Sortiment') { $desc = $discNote + $desc }
  $r = wc PUT "products/$($ex.id)" @{ status = 'draft'; description = $desc; catalog_visibility = 'hidden' }
  Write-Host ("[ausgelaufen] {0,-24} id={1} -> {2}" -f $ex.name, $r.id, $r.status)
}
