# build-shop-nivona-variants.ps1 - macht die NIVONA-Kaffeevollautomaten mit mehreren
# Ausfuehrungen zu variablen WooCommerce-Produkten (Attribut "Farbe" + je eine Variation
# mit eigenem Preis und Bild - anders als bei JURA hat bei NIVONA nicht jede Farbe den
# gleichen Preis). Modelle mit nur einer Ausfuehrung bekommen stattdessen ein sichtbares,
# nicht-variables Attribut "Farbe". Daten: nivona-variants.json. Idempotent. Status bleibt
# wie er ist (kein Publish/Unpublish durch dieses Skript).
#   .\build-shop-nivona-variants.ps1
$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$root\wc-lib.ps1" | Out-Null

$vars = Get-Content "$root\nivona-variants.json" -Raw -Encoding UTF8 | ConvertFrom-Json

function Url-Ok($u) {
  try { $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 25 -ErrorAction Stop
        return ($r.StatusCode -eq 200 -and "$($r.Headers['Content-Type'])" -like 'image/*') }
  catch { return $false }
}

# 1) Modelle mit mehreren Farben -> variables Produkt + Variationen
foreach ($sku in $vars.colors.PSObject.Properties.Name) {
  $colors = @($vars.colors.$sku)

  $found = wc GET "products?sku=$sku&status=any"
  $wcp   = @($found)[0]
  if (-not $wcp) { Write-Host "[fehlt] $sku" -ForegroundColor Yellow; continue }
  $prodId = $wcp.id

  $body = @{
    type       = 'variable'
    attributes = @(@{
      name = 'Farbe'; position = 0; visible = $true; variation = $true
      options = @($colors | ForEach-Object { $_.name })
    })
    default_attributes = @(@{ name = 'Farbe'; option = $colors[0].name })
  }
  $null = wc PUT "products/$prodId" $body
  Write-Host ("[variable] {0,-20} id={1}  Farben: {2}" -f $sku, $prodId, (($colors | ForEach-Object { $_.name }) -join ', '))

  $existResp = wc GET "products/$prodId/variations?per_page=100"
  $exist = @($existResp)
  $haveOpts = @($exist | ForEach-Object { ($_.attributes | Where-Object { $_.name -eq 'Farbe' }).option })

  foreach ($c in $colors) {
    $vbody = @{
      regular_price = $c.price
      attributes    = @(@{ name = 'Farbe'; option = $c.name })
      manage_stock  = $false
    }
    if ($c.name) {
      $slug = $c.name -replace 'ä','ae' -replace 'ö','oe' -replace 'ü','ue' -replace 'ß','ss'
      $slug = ($slug -replace '[^A-Za-z0-9]+','-').ToLower().Trim('-')
      $vbody.sku = "$sku-$slug"
    }
    $imgUrl = $c.img
    if (-not (Url-Ok $imgUrl)) { $imgUrl = $colors[0].img }
    if (Url-Ok $imgUrl) { $vbody.image = @{ src = $imgUrl } }

    if ($haveOpts -contains $c.name) {
      $existing = $exist | Where-Object { ($_.attributes | Where-Object { $_.name -eq 'Farbe' }).option -eq $c.name } | Select-Object -First 1
      $r = wc PUT "products/$prodId/variations/$($existing.id)" $vbody
      Write-Host ("   = {0,-22} {1,8} EUR  art={2}" -f $c.name, $r.regular_price, $c.art)
    } else {
      $r = wc POST "products/$prodId/variations" $vbody
      Write-Host ("   + {0,-22} {1,8} EUR  art={2}  Bild={3}" -f $c.name, $r.regular_price, $c.art, ([bool]$r.image.id))
    }
  }
}

# 2) Modelle mit nur einer Ausfuehrung -> sichtbares, nicht-variables Attribut "Farbe"
foreach ($sku in $vars.singleColor.PSObject.Properties.Name) {
  $farbe = $vars.singleColor.$sku
  $found = wc GET "products?sku=$sku&status=any"
  $wcp   = @($found)[0]
  if (-not $wcp) { Write-Host "[fehlt] $sku" -ForegroundColor Yellow; continue }
  if ($wcp.type -eq 'variable') { Write-Host "[skip] $sku ist bereits variabel"; continue }

  $existingAttrs = @($wcp.attributes | Where-Object { $_.name -ne 'Farbe' })
  $attrs = $existingAttrs + @(@{ name = 'Farbe'; visible = $true; variation = $false; options = @($farbe) })
  $r = wc PUT "products/$($wcp.id)" @{ attributes = $attrs }
  $fa = (($r.attributes | Where-Object { $_.name -eq 'Farbe' }).options -join ', ')
  Write-Host ("[ok]       {0,-20} {1,-34} Farbe = {2}" -f $sku, $wcp.name, $fa)
}

Write-Host "`nFertig. NIVONA-Farbvarianten angelegt/aktualisiert." -ForegroundColor Cyan
