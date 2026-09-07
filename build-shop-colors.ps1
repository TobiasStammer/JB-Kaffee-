# build-shop-colors.ps1 - ergaenzt die JURA-Haushaltsmodelle, die es nur in EINER
# Ausfuehrung gibt, um ein sichtbares (nicht variables) Attribut "Farbe".
# Die Modelle mit mehreren Ausfuehrungen sind bereits variable Produkte
# (build-shop-variants.ps1 / jura-variants.json). Quelle der Farben: de.jura.com.
#   .\build-shop-colors.ps1
$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$root\wc-lib.ps1" | Out-Null

# SKU -> @{ serie; farbe }   (nur Einzel-Ausfuehrungs-Modelle)
$single = @{
  '15478' = @{ serie = 'GIGA'; farbe = 'Diamond Black' }        # GIGA 10
  '15706' = @{ serie = 'J';    farbe = 'Diamond Onyx' }          # J10 twin
  '15562' = @{ serie = 'J';    farbe = 'Piano Black' }           # J10
  '15743' = @{ serie = 'E';    farbe = 'Onyx Grey' }             # E10
  '15599' = @{ serie = 'C';    farbe = 'Piano Black' }           # C3
  '15696' = @{ serie = 'ENA';  farbe = 'Night Inox' }            # ENA 5
  '15501' = @{ serie = 'ENA';  farbe = 'Full Metropolitan Black' } # ENA 4
}

foreach ($sku in $single.Keys) {
  $cfg = $single[$sku]
  $exResp = wc GET "products?sku=$sku&status=any"
  $p = @($exResp) | Select-Object -First 1
  if (-not $p) { Write-Host "[fehlt]    SKU $sku nicht gefunden"; continue }
  if ($p.type -eq 'variable') { Write-Host "[skip]     SKU $sku ist variabel - unveraendert"; continue }

  $attrs = @(
    @{ name = 'Serie'; visible = $true;  variation = $false; options = @($cfg.serie) }
    @{ name = 'Farbe'; visible = $true;  variation = $false; options = @($cfg.farbe) }
  )
  $r = wc PUT "products/$($p.id)" @{ attributes = $attrs }
  $fa = (($r.attributes | Where-Object { $_.name -eq 'Farbe' }).options -join ', ')
  Write-Host ("[ok]       {0,-6} {1,-34} Farbe = {2}" -f $sku, $p.name, $fa)
}

Write-Host "`nFertig. Einzelausfuehrungs-Modelle haben jetzt ein sichtbares Attribut 'Farbe'." -ForegroundColor Cyan
