# build-nivona-shop-extra.ps1 - legt NIVONA Zubehoer + Pflegeprodukte als
# WooCommerce-Produkte an (Kategorien 37 / 38), Namen/Preise/Bilder aus
# nivona-shop-extra.json. Idempotent per SKU. status=publish (im Gegensatz zu
# build-shop-extra.ps1, das JURA-Produkte als draft anlegt - hier soll die
# neue Nivona-Zubehoer-/Pflegeseite sofort live sein).
#   .\build-nivona-shop-extra.ps1
$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$root\wc-lib.ps1" | Out-Null

$x    = Get-Content "$root\nivona-shop-extra.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$base = (Import-KtEnv)['WP_URL'].TrimEnd('/')

$T = @{
  markenLink   = 'Zur NIVONA Markenseite'
  beratung     = 'Persönliche Beratung und Vorführung in unserem Geschäft in Hofheim-Langenhain oder telefonisch unter 06192 2004363. Verkauf, Service und Reparatur aus einer Hand durch die Joachim Blöchle Elektro-Service GmbH.'
  shortSuffix  = 'Verkauf und Beratung durch Ihren NIVONA-Fachhändler mit eigener Werkstatt in Hofheim-Langenhain.'
  footer       = 'NIVONA® ist eine Marke der NIVONA Apparate GmbH, Nürnberg. Abbildungen: NIVONA. Änderungen und Irrtümer vorbehalten.'
}

function Enc($s) { [System.Net.WebUtility]::HtmlEncode([string]$s) }
function Url-Ok($u) {
  try { $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 25 -ErrorAction Stop
        return ($r.StatusCode -eq 200 -and "$($r.Headers['Content-Type'])" -like 'image/*') }
  catch { return $false }
}
function First-Sentence($s) {
  $m = [regex]::Match([string]$s, '^(.*?[.!?])(\s|$)')
  if ($m.Success) { $m.Groups[1].Value } else { [string]$s }
}

$groups = @(
  @{ items = $x.pflege;   catId = 38; catName = 'Pflegeprodukte' }
  @{ items = $x.zubehoer; catId = 37; catName = 'Zubehör' }
)

foreach ($g in $groups) {
  foreach ($p in $g.items) {
    $descBody = @"
<div class="jura-pd">
<p style="font-size:14px;line-height:1.6;margin:0 0 10px">$(Enc $p.desc)</p>
<hr style="border:0;border-top:1px solid #e2e2e2;margin:16px 0">
<p style="font-size:14px;line-height:1.6;margin:0 0 10px"><strong><a href="$base/nivona/">$(Enc $T.markenLink)</a></strong></p>
<p style="font-size:14px;line-height:1.6;margin:0 0 10px">$(Enc $T.beratung)</p>
<p style="font-size:12px;color:#888">$(Enc $T.footer)</p>
</div>
"@
    $short = "<p>$(Enc (First-Sentence $p.desc)) $(Enc $T.shortSuffix)</p>"

    $body = @{
      name               = $p.name
      type               = 'simple'
      sku                = $p.sku
      regular_price      = $p.price
      catalog_visibility = 'visible'
      manage_stock       = $false
      categories         = @(@{ id = $g.catId })
      description        = $descBody
      short_description  = $short
      attributes         = @(
        @{ name = 'Serie'; position = 0; visible = $true; variation = $false; options = @($p.serie) }
        @{ id = 1; position = 1; visible = $true; variation = $false; options = @('1-3 Tage') }
      )
    }

    $existingResp = wc GET "products?sku=$($p.sku)&status=any"
    $existing = @($existingResp)[0]

    if ($existing) {
      $r = wc PUT "products/$($existing.id)" $body
      $act = "aktualisiert ($($existing.status))"
    } else {
      $body.status = 'publish'
      $src = "$($p.img)"
      if ($src -and (Url-Ok $src)) { $body.images = @(@{ src = $src; alt = $p.name }) }
      $r = wc POST 'products' $body
      $act = 'neu (publish)'
    }
    Write-Host ("[{0,-16}] {1,-14} {2,-46} id={3,-5} {4} EUR Bild={5}" -f $act, $g.catName, $p.name, $r.id, $r.regular_price, (@($r.images).Count))
  }
}
Write-Host "`nFertig." -ForegroundColor Cyan
