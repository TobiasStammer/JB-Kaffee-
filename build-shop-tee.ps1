# build-shop-tee.ps1 - Kategorie "Tee" ("Unser Tee") + 6 Sorten.
# Preis 6,90 EUR je Sorte. Bilder = Etiketten-Renders (kt-tee-*.jpg in der Mediathek).
# Idempotent per SKU. Neu -> status = draft (Nutzer schaltet frei, wenn der Tee verfuegbar ist).
#   .\build-shop-tee.ps1            (Standard: neue Produkte als draft)
#   .\build-shop-tee.ps1 -Publish   (neue Produkte direkt veroeffentlichen)
param([switch]$Publish)
$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$root\wc-lib.ps1" | Out-Null
$base = (Import-KtEnv)['WP_URL'].TrimEnd('/')
function Enc($s) { [System.Net.WebUtility]::HtmlEncode([string]$s) }

# Kategorie
$catResp = wc GET 'products/categories?slug=tee'
$catId = @($catResp)[0].id
if (-not $catId) {
  $c = wc POST 'products/categories' @{ name = 'Tee'; slug = 'tee'; description = 'Unser Tee - lose Teemischungen, abgefuellt fuer die Joachim Bloechle Elektro-Service GmbH.' }
  $catId = $c.id; Write-Host "[cat neu] tee id=$catId"
} else { Write-Host "[cat vorhanden] tee id=$catId" }

$img = 'https://new.kaffeetechniker.de/wp-content/uploads/2026/09'
$foot = 'Lose Teemischung. Hergestellt f&uuml;r die Joachim Bl&ouml;chle Elektro-Service GmbH, Wallauer Stra&szlig;e 4, 65719 Hofheim-Langenhain. MHD: siehe Beutelboden. Preise inkl. MwSt.'

$items = @(
  @{ sku='jb-tee-beerenzauber';  name='JB &bdquo;Unser Tee&ldquo; Beerenzauber, 150 g'; art='Fr&uuml;chtetee'; menge='150 g'; pic="$img/kt-tee-beerenzauber.jpg"
     desc='Nat&uuml;rlich aromatisierte Fr&uuml;chteteemischung mit Kirsch-, Erdbeer-, Brombeer- und Johannisbeer-Geschmack.'
     zut='Apfelst&uuml;cke, Hagebuttenschalen, Hibiscusbl&uuml;ten, Brombeeren, schwarze Johannisbeeren, rote Johannisbeeren, nat&uuml;rliches Aroma, Kirschst&uuml;cke, Erdbeerst&uuml;cke.' }
  @{ sku='jb-tee-bluetenzeit';   name='JB &bdquo;Unser Tee&ldquo; Bl&uuml;tenzeit, 150 g'; art='Gr&uuml;ner Tee'; menge='150 g'; pic="$img/kt-tee-bluetenzeit.jpg"
     desc='Aromatisierter gr&uuml;ner Tee mit dem Geschmack einer feinen Fruchtkomposition.'
     zut='Gr&uuml;ner Tee, Apfelst&uuml;cke, Aroma, Granatapfelbl&uuml;ten, Rhabarberst&uuml;cke, Heide-, Ringelblumen- und Malvenbl&uuml;ten.' }
  @{ sku='jb-tee-earl-grey';     name='JB &bdquo;Unser Tee&ldquo; Earl Grey, 150 g'; art='Schwarzer Tee'; menge='150 g'; pic="$img/kt-tee-earl-grey.jpg"
     desc='Nat&uuml;rlich aromatisierter schwarzer Tee mit Bergamotte-Geschmack.'
     zut='Schwarzer Tee, nat&uuml;rliches Aroma.' }
  @{ sku='jb-tee-erdbeer-sahne'; name='JB &bdquo;Unser Tee&ldquo; Erdbeer-Sahne, 150 g'; art='Rooibos-Tee'; menge='150 g'; pic="$img/kt-tee-erdbeer-sahne.jpg"
     desc='Aromatisierter Rooibos-Tee mit Erdbeer-Sahne-Geschmack.'
     zut='Rooibos, Erdbeerbl&auml;tter 4&nbsp;%, Erdbeerst&uuml;cke 2&nbsp;%, Aroma.' }
  @{ sku='jb-tee-frische-kraft'; name='JB &bdquo;Unser Tee&ldquo; Frische Kraft, 100 g'; art='Kr&auml;utertee'; menge='100 g'; pic="$img/kt-tee-frische-kraft.jpg"
     desc='Nat&uuml;rlich aromatisierter Kr&auml;utertee mit Limonen-Grapefruit-Geschmack.'
     zut='Apfelst&uuml;cke, Karottenscheiben, Himbeerbl&auml;tter, Orangenschale, Hibiscusbl&uuml;ten, Weidenr&ouml;schen, M&auml;des&uuml;&szlig;kraut, Lemongras, Holunderbeeren, Cistrosenkraut, Katzenpf&ouml;tchen, nat&uuml;rliches Aroma.' }
  @{ sku='jb-tee-rote-liebe';    name='JB &bdquo;Unser Tee&ldquo; Rote Liebe, 150 g'; art='Fr&uuml;chtetee'; menge='150 g'; pic="$img/kt-tee-rote-liebe.jpg"
     desc='Aromatisierte Fr&uuml;chteteemischung mit dem Geschmack von reifen Erdbeeren mit Vanilleso&szlig;e.'
     zut='Apfelst&uuml;cke, Hibiscusbl&uuml;ten, Granatapfelbl&uuml;ten, Cranberries, Himbeerst&uuml;cke, Erdbeerst&uuml;cke, Aroma.' }
)

foreach ($p in $items) {
  $descHtml = "<div class=""jura-pd""><p>$($p.desc)</p><h2>Zutaten</h2><p>$($p.zut)</p><hr style=""border:0;border-top:1px solid #e2e2e2;margin:16px 0""><p style=""font-size:12px;color:#888"">$foot</p></div>"
  $body = @{
    name = $p.name; type = 'simple'; sku = $p.sku; regular_price = '6.90'
    catalog_visibility = 'visible'; manage_stock = $false
    categories = @(@{ id = $catId })
    description = $descHtml
    short_description = "<p>$($p.art) &ndash; $($p.desc)</p>"
    attributes = @(
      @{ name = 'Art';    visible = $true; options = @($p.art) }
      @{ name = 'Inhalt'; visible = $true; options = @($p.menge) }
    )
  }
  $ex = @(wc GET "products?sku=$($p.sku)&status=any")[0]
  if ($ex) {
    if ($p.pic -and -not @($ex.images).Count) { $body.images = @(@{ src = $p.pic; alt = $p.name }) }
    $r = wc PUT "products/$($ex.id)" $body; $act = "aktualisiert ($($ex.status))"
  } else {
    $body.status = if ($Publish) { 'publish' } else { 'draft' }
    if ($p.pic) { $body.images = @(@{ src = $p.pic; alt = $p.name }) }
    $r = wc POST 'products' $body; $act = "neu ($($body.status))"
  }
  Write-Host ("[{0,-18}] {1,-42} id={2} {3} EUR" -f $act, ($p.name -replace '&[a-z]+;','?'), $r.id, $r.regular_price)
}
Write-Host "`nFertig. 6 Sorten a 6,90 EUR, Kategorie 'tee'." -ForegroundColor Cyan
if (-not $Publish) { Write-Host "Neu angelegte Produkte sind DRAFT - mit -Publish oder in wp-admin freischalten." -ForegroundColor Yellow }
