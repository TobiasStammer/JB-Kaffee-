# build-shop-professional.ps1 - JURA Professional als WooCommerce-Produkte
# (type=external, "Preis auf Anfrage", Button -> Beratung/Kontakt). Idempotent per SKU.
# Alle status=draft. Legt Kategorie 'jura-professional' unter JURA (18) an.
#   .\build-shop-professional.ps1
$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$root\wc-lib.ps1" | Out-Null

$data = Get-Content "$root\jura-professional.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$T    = (Get-Content "$root\jura-specs.json" -Raw -Encoding UTF8 | ConvertFrom-Json)._tpl
$base = (Import-KtEnv)['WP_URL'].TrimEnd('/')

function Enc($s) { [System.Net.WebUtility]::HtmlEncode([string]$s) }
function Url-Ok($u) {
  try { $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 25 -ErrorAction Stop
        return ($r.StatusCode -eq 200 -and "$($r.Headers['Content-Type'])" -like 'image/*') }
  catch { return $false }
}

# JURA-Elternkategorie + Professional-Kategorie
$parent = @(wc GET 'products/categories?slug=jura')
$parentId = @($parent)[0].id
$existingCat = @(wc GET "products/categories?slug=$($data.category.slug)")
$catId = @($existingCat)[0].id
if (-not $catId) {
  $c = wc POST 'products/categories' @{ name = $data.category.name; slug = $data.category.slug; parent = $parentId }
  $catId = $c.id
  Write-Host "[cat neu] $($data.category.slug) id=$catId"
} else { Write-Host "[cat vorhanden] $($data.category.slug) id=$catId" }

$ctaUrl = "$base/kontakt/"

foreach ($p in $data.items) {
  $desc = @"
<div class="jura-pd">
<p style="font-size:14px;line-height:1.6;margin:0 0 10px"><strong>Empfohlene Tagesleistung:</strong> $(Enc $p.tages)</p>
<p style="font-size:14px;line-height:1.6;margin:0 0 10px">$(Enc $p.desc)</p>
<h2 style="font-size:15px;line-height:1.3;font-weight:700;margin:20px 0 8px">Preis auf Anfrage</h2>
<p style="font-size:14px;line-height:1.6;margin:0 0 10px">JURA Professional-Ger&auml;te konfigurieren wir gemeinsam mit Ihnen (Festwasseranschluss, Milchl&ouml;sung, Zahlsystem, Wartungsvertrag). Sie erhalten von uns ein auf Ihren Bedarf zugeschnittenes Angebot &ndash; inkl. Aufstellung, Einweisung und Service vor Ort.</p>
<hr style="border:0;border-top:1px solid #e2e2e2;margin:16px 0">
<p style="font-size:14px;line-height:1.6;margin:0 0 10px"><strong><a href="$base/jura/">$(Enc $T.markenLink)</a></strong></p>
<p style="font-size:14px;line-height:1.6;margin:0 0 10px">$(Enc $T.beratung)</p>
<p style="font-size:12px;color:#888">$(Enc $T.footer)</p>
</div>
"@
  $short = "<p>JURA Professional-Kaffeevollautomat, $(Enc $p.tages). Preis auf Anfrage &ndash; Beratung, Angebot und Service durch Ihre JURA-Servicestelle in Hofheim-Langenhain.</p>"

  $body = @{
    name               = $p.name
    type               = 'external'
    sku                = $p.sku
    catalog_visibility = 'visible'
    button_text        = 'Beratung & Angebot anfragen'
    external_url       = $ctaUrl
    categories         = @(@{ id = $catId })
    description        = $desc
    short_description  = $short
  }

  $existing = @(wc GET "products?sku=$($p.sku)&status=any")
  $wcp = @($existing)[0]
  if ($wcp) {
    $r = wc PUT "products/$($wcp.id)" $body
    $act = "aktualisiert ($($wcp.status))"
  } else {
    $body.status = 'draft'
    if ($p.img -and (Url-Ok $p.img)) { $body.images = @(@{ src = $p.img; alt = $p.name }) }
    $r = wc POST 'products' $body
    $act = 'neu (draft)'
  }
  Write-Host ("[{0,-14}] {1,-32} id={2,-5} Bild={3}" -f $act, $p.name, $r.id, (@($r.images).Count))
}
Write-Host "`nFertig. Alle Professional-Produkte status=draft, type=external (Preis auf Anfrage)." -ForegroundColor Cyan
