# enrich-shop.ps1 - reichert die 15 JURA-Haushaltsprodukte an:
#   * strukturierte description (Vorzuege / Technische Daten / Zubehoer / Pflege /
#     Link Markenseite / JURA-Fussnote) gemaess JURA-Shop-in-Shop-Richtlinie
#   * short_description
#   * Bildergalerie (Overview + image-gallery) von api.jura.com, per WooCommerce
#     sideloaded - nur einmal (Meta _kt_jura_gallery), danach nur noch Text-Update
# Idempotent. Alle Produkte bleiben status=draft.
#   .\enrich-shop.ps1            # Text aktualisieren
#   .\enrich-shop.ps1 -Images   # zusaetzlich Galerie setzen (nur fehlende)
param([switch]$Images)
$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$root\wc-lib.ps1" | Out-Null

$prod  = Get-Content "$root\jura-products.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$specs = Get-Content "$root\jura-specs.json"    -Raw -Encoding UTF8 | ConvertFrom-Json
$imgs  = Get-Content "$root\jura-images.json"   -Raw -Encoding UTF8 | ConvertFrom-Json
$vars  = Get-Content "$root\jura-variants.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$T     = $specs._tpl
$base  = (Import-KtEnv)['WP_URL'].TrimEnd('/')

function Url-Ok($u) {
  # api.jura.com lehnt HEAD ab (405) -> GET; Bild ist klein genug
  try { $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 25 -ErrorAction Stop
        return ($r.StatusCode -eq 200 -and "$($r.Headers['Content-Type'])" -like 'image/*') }
  catch { return $false }
}
function Enc($s) { [System.Net.WebUtility]::HtmlEncode([string]$s) }

foreach ($p in $prod.haushalt) {
  $sku = $p.sku
  $sp  = $specs.$sku
  if (-not $sp) { Write-Host "[skip] $sku ohne specs"; continue }

  # Produkt holen
  $found = wc GET "products?sku=$sku&status=any"
  $wcp   = @($found)[0]
  if (-not $wcp) { Write-Host "[fehlt] $sku ($($p.name))" -ForegroundColor Yellow; continue }

  # ---- description ----
  $vz = ($sp.vorzuege | ForEach-Object { "<li>$(Enc $_)</li>" }) -join ''
  $td = ($sp.techdaten | ForEach-Object { "<tr><th style=""text-align:left;padding:6px 14px 6px 0;color:#555;font-weight:600;vertical-align:top;white-space:nowrap"">$(Enc $_.k)</th><td style=""padding:6px 0"">$(Enc $_.v)</td></tr>" }) -join ''
  # Ueberschriften im Theme sind sehr gross -> Groesse INLINE erzwingen (schlaegt Theme-CSS)
  $h2s = 'style="font-size:15px;line-height:1.3;font-weight:700;margin:22px 0 8px"'
  # Produktvideo (YouTube, nocookie)
  # Hinweis: WooCommerce entfernt <iframe> aus Produktbeschreibungen -> Video als
  # anklickbares YouTube-Vorschaubild (oeffnet in neuem Tab)
  $vid = [string]$vars.video.$sku
  $videoHtml = if ($vid) { @"
<h2 $h2s>Video</h2>
<a href="https://www.youtube.com/watch?v=$vid" target="_blank" rel="noopener" style="position:relative;display:block;max-width:560px;border-radius:8px;overflow:hidden;text-decoration:none">
<img src="https://i.ytimg.com/vi/$vid/hqdefault.jpg" alt="$(Enc $p.name) Video ansehen" style="display:block;width:100%;height:auto">
<span style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center">
<span style="display:flex;align-items:center;justify-content:center;width:64px;height:44px;border-radius:10px;background:rgba(0,0,0,.75)">
<svg width="20" height="20" viewBox="0 0 24 24" fill="#fff"><path d="M8 5v14l11-7z"/></svg></span></span>
</a>
<p style="font-size:12px;color:#888;margin:5px 0 0">Produktvideo auf YouTube ansehen</p>
"@ } else { '' }
  $desc = @"
<div class="jura-pd">
<h2 $h2s>$(Enc $T.hVorzuege)</h2>
<ul style="margin:0 0 8px 1.1em;padding:0">$vz</ul>
<h2 $h2s>$(Enc $T.hTechnik)</h2>
<table style="border-collapse:collapse;font-size:13.5px;line-height:1.5">$td</table>
$videoHtml
<h2 $h2s>$(Enc $T.hZubehoer)</h2>
<p style="font-size:14px;line-height:1.6;margin:0 0 10px">$(Enc $T.zubehoerText) <a href="$base/jura-zubehoer/">$(Enc $T.zubehoerLink)</a></p>
<h2 $h2s>$(Enc $T.hPflege)</h2>
<p style="font-size:14px;line-height:1.6;margin:0 0 10px">$(Enc $T.pflegeText) <a href="$base/jura-pflegeprodukte/">$(Enc $T.pflegeLink)</a></p>
<hr style="border:0;border-top:1px solid #e2e2e2;margin:18px 0">
<p style="font-size:14px;line-height:1.6;margin:0 0 10px"><strong><a href="$base/jura/">$(Enc $T.markenLink)</a></strong></p>
<p style="font-size:14px;line-height:1.6;margin:0 0 10px">$(Enc $T.beratung)</p>
<p style="font-size:12px;color:#888">$(Enc $T.footer)</p>
</div>
"@
  $short = "<p>$(Enc $sp.spez). $(Enc $T.shortSuffix)</p>"

  $body = @{ description = $desc; short_description = $short }

  # ---- Galerie (einmalig) ----
  $doneMeta = @($wcp.meta_data | Where-Object { $_.key -eq '_kt_jura_gallery' })
  if ($Images -and -not $doneMeta) {
    $cand = @($imgs.$sku)
    $good = @()
    foreach ($u in $cand) { if (Url-Ok $u) { $good += $u }; if ($good.Count -ge 6) { break } }
    if ($good.Count -ge 1) {
      $body.images = @($good | ForEach-Object { @{ src = $_; alt = $p.name } })
      $body.meta_data = @(@{ key = '_kt_jura_gallery'; value = ("{0} Bilder" -f $good.Count) })
      Write-Host ("  Galerie: {0} Bilder" -f $good.Count)
    }
  }

  $r = wc PUT "products/$($wcp.id)" $body
  Write-Host ("[ok] {0,-6} {1,-34} id={2} desc={3} Zeichen" -f $sku, $p.name, $wcp.id, $r.description.Length)
}
Write-Host "`nFertig. status weiterhin draft." -ForegroundColor Cyan
