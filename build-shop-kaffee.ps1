# build-shop-kaffee.ps1 - Kategorie "Kaffee" (eigene Roestung) + 2 Produkte.
# ACHTUNG: Preise sind PLATZHALTER - echte Preise + Produktfotos von Joachim.
# Idempotent per SKU. Status: neu = draft (bis Preis/Fotos stimmen).
#   .\build-shop-kaffee.ps1
$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$root\wc-lib.ps1" | Out-Null
$base = (Import-KtEnv)['WP_URL'].TrimEnd('/')
function Enc($s) { [System.Net.WebUtility]::HtmlEncode([string]$s) }

# Kategorie
$catResp = wc GET 'products/categories?slug=kaffee'
$catId = @($catResp)[0].id
if (-not $catId) {
  $c = wc POST 'products/categories' @{ name = 'Kaffee'; slug = 'kaffee' }
  $catId = $c.id; Write-Host "[cat neu] kaffee id=$catId"
} else { Write-Host "[cat vorhanden] kaffee id=$catId" }

$foot = 'Eigene R&ouml;stung der Joachim Bl&ouml;chle Elektro-Service GmbH. Schonend im Trommelr&ouml;stverfahren in kleinen Mengen ger&ouml;stet, im 1000-g-Beutel mit Aromaventil. Preise inkl. MwSt.'

$items = @(
  @{ sku='jb-kaffee-caffe-crema-1000';  name='JB &bdquo;Unser Kaffee&ldquo; Caff&egrave; Crema, 1000 g';  price='22.90'
     img='https://d2j6dbq0eux0bg.cloudfront.net/images/62563039/2876279691.jpg'
     desc='<p>60&nbsp;% Arabica- und 40&nbsp;% Robustabohnen. Nussig, schokoladig, mildes bis kr&auml;ftiges Aroma. Ideal f&uuml;r Kaffeevollautomaten.</p>' }
  @{ sku='jb-kaffee-espresso-1000'; name='JB &bdquo;Unser Kaffee&ldquo; Espresso, 1000 g'; price='22.90'
     img='https://d2j6dbq0eux0bg.cloudfront.net/images/62563039/2876307959.jpg'
     desc='<p>80&nbsp;% Arabica- und 20&nbsp;% Robustabohnen. Nussig, r&ouml;stig, kr&auml;ftiges Aroma. Ideal f&uuml;r Kaffeevollautomaten und Siebtr&auml;germaschinen.</p>' }
)

foreach ($p in $items) {
  $body = @{
    name = $p.name; type = 'simple'; sku = $p.sku; regular_price = $p.price
    catalog_visibility = 'visible'; manage_stock = $false
    categories = @(@{ id = $catId })
    description = "<div class=""jura-pd"">$($p.desc)<hr style=""border:0;border-top:1px solid #e2e2e2;margin:16px 0""><p style=""font-size:12px;color:#888"">$foot</p></div>"
    short_description = "<p>$($p.desc -replace '<[^>]+>','')</p>"
    attributes = @(
      @{ name = 'Art';    visible = $true; options = @('Kaffee') }
      @{ name = 'Inhalt'; visible = $true; options = @('1000 g') }
    )
  }
  $ex = @(wc GET "products?sku=$($p.sku)&status=any")[0]
  if ($ex) {
    if ($p.img -and -not @($ex.images).Count) { $body.images = @(@{ src = $p.img; alt = $p.name }) }
    $r = wc PUT "products/$($ex.id)" $body; $act = "aktualisiert ($($ex.status))"
  } else {
    $body.status = 'draft'
    if ($p.img) { $body.images = @(@{ src = $p.img; alt = $p.name }) }
    $r = wc POST 'products' $body; $act = 'neu (draft)'
  }
  Write-Host ("[{0,-16}] {1,-28} id={2} {3} EUR" -f $act, $p.name, $r.id, $r.regular_price)
}
Write-Host "`nFertig. Preise 22,90 EUR, Fotos von kaffeetechniker.de." -ForegroundColor Cyan
