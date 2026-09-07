# build-shop-extra.ps1 - legt JURA Zubehoer + Pflegeprodukte als WooCommerce-Produkte
# an (Kategorien 20 / 21), Namen/Preise/Bilder aus jura-shop-extra.json.
# Idempotent per SKU. Alle Produkte status=draft. Bild nur beim Anlegen (sideload).
#   .\build-shop-extra.ps1
$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$root\wc-lib.ps1" | Out-Null

$x    = Get-Content "$root\jura-shop-extra.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$T    = (Get-Content "$root\jura-specs.json" -Raw -Encoding UTF8 | ConvertFrom-Json)._tpl
$base = (Import-KtEnv)['WP_URL'].TrimEnd('/')

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
  @{ items = $x.pflege;   catId = 21; catName = 'Pflegeprodukte'; base = $x.imgBaseCare }
  @{ items = $x.zubehoer; catId = 20; catName = 'Zubehör';        base = $x.imgBaseAcc  }
)

foreach ($g in $groups) {
  foreach ($p in $g.items) {
    $descBody = @"
<div class="jura-pd">
<p style="font-size:14px;line-height:1.6;margin:0 0 10px">$(Enc $p.desc)</p>
<hr style="border:0;border-top:1px solid #e2e2e2;margin:16px 0">
<p style="font-size:14px;line-height:1.6;margin:0 0 10px"><strong><a href="$base/jura/">$(Enc $T.markenLink)</a></strong></p>
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
    }

    $existingResp = wc GET "products?sku=$($p.sku)&status=any"
    $existing = @($existingResp)[0]

    if ($existing) {
      # vorhandenen Status NICHT ueberschreiben (sonst faellt eine publizierte Seite auf draft)
      $r = wc PUT "products/$($existing.id)" $body
      $act = "aktualisiert ($($existing.status))"
    } else {
      $body.status = 'draft'
      $src = if ("$($p.img)") { if ($p.img -like 'http*') { $p.img } else { $g.base + $p.img } } else { '' }
      if ($src -and (Url-Ok $src)) { $body.images = @(@{ src = $src; alt = $p.name }) }
      $r = wc POST 'products' $body
      $act = 'neu (draft)'
    }
    Write-Host ("[{0,-14}] {1,-12} {2,-46} id={3,-5} {4} EUR Bild={5}" -f $act, $g.catName, $p.name, $r.id, $r.regular_price, (@($r.images).Count))
  }
}
Write-Host "`nFertig. Neue Produkte = draft; vorhandene behalten ihren Status." -ForegroundColor Cyan
