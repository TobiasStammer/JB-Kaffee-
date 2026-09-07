# build-shop-variants.ps1 - macht die JURA-Haushaltsmodelle mit mehreren Ausfuehrungen
# zu variablen WooCommerce-Produkten (Attribut "Farbe" + je eine Variation mit Bild).
# Preise/Bilder/Art-Nrn aus jura-variants.json. Idempotent. Status bleibt wie er ist.
#   .\build-shop-variants.ps1
$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$root\wc-lib.ps1" | Out-Null

$prod = Get-Content "$root\jura-products.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$vars = Get-Content "$root\jura-variants.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$priceOf = @{}
foreach ($h in $prod.haushalt) { $priceOf[$h.sku] = $h.price }

function Url-Ok($u) {
  try { $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 25 -ErrorAction Stop
        return ($r.StatusCode -eq 200 -and "$($r.Headers['Content-Type'])" -like 'image/*') }
  catch { return $false }
}

foreach ($sku in $vars.colors.PSObject.Properties.Name) {
  $colors = @($vars.colors.$sku)
  $price  = $priceOf[$sku]

  $found = wc GET "products?sku=$sku&status=any"
  $wcp   = @($found)[0]
  if (-not $wcp) { Write-Host "[fehlt] $sku" -ForegroundColor Yellow; continue }
  $prodId = $wcp.id

  # 1) Elternprodukt -> variable, Attribut "Farbe"
  $body = @{
    type       = 'variable'
    attributes = @(@{
      name = 'Farbe'; position = 0; visible = $true; variation = $true
      options = @($colors | ForEach-Object { $_.name })
    })
    default_attributes = @(@{ name = 'Farbe'; option = $colors[0].name })
  }
  $null = wc PUT "products/$prodId" $body
  Write-Host ("[variable] {0,-6} id={1}  Farben: {2}" -f $sku, $prodId, (($colors | ForEach-Object { $_.name }) -join ', '))

  # 2) vorhandene Variationen holen
  $existResp = wc GET "products/$prodId/variations?per_page=100"
  $exist = @($existResp)
  $haveOpts = @($exist | ForEach-Object { ($_.attributes | Where-Object { $_.name -eq 'Farbe' }).option })

  foreach ($c in $colors) {
    if ($haveOpts -contains $c.name) {
      Write-Host ("   = {0} (schon da)" -f $c.name); continue
    }
    $vsku = if ("$($c.art)" -and "$($c.art)" -ne "$sku") { "$($c.art)" } else { '' }
    $vbody = @{
      regular_price = $price
      attributes    = @(@{ name = 'Farbe'; option = $c.name })
      manage_stock  = $false
    }
    if ($vsku) { $vbody.sku = $vsku }
    $imgUrl = $c.img
    if (-not (Url-Ok $imgUrl)) { $imgUrl = $colors[0].img }   # Fallback: Standardfarbe
    if (Url-Ok $imgUrl) { $vbody.image = @{ src = $imgUrl } }
    $r = wc POST "products/$prodId/variations" $vbody
    Write-Host ("   + {0,-22} art={1,-6} Bild={2}" -f $c.name, $vsku, ([bool]$r.image.id))
  }
}
Write-Host "`nFertig. Variable Produkte angelegt. Status unveraendert." -ForegroundColor Cyan

