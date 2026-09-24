# build-jura-devices.ps1 - macht aus den variablen JURA-Haushaltsprodukten (Farbwechsel-
# Dropdown, Galerie/Bildwechsel funktionierte nicht zuverlaessig) EINZELPRODUKTE:
#  - Das bestehende Elternprodukt (ID/URL bleibt) wird zum einfachen Produkt der 1. Farbe.
#  - Jede weitere Farbe wird ein eigenes einfaches Produkt (Bilder/Galerie aus der
#    bisherigen Variation, Beschreibung/Kategorie/Versand vom Eltern-Produkt kopiert).
#  - Alle Farben einer Maschine bekommen in der Kurzbeschreibung einen Block
#    "Weitere Farben" mit Links zu den Geschwister-Produkten.
# Daten: jura-variants.json (colors). Snapshot der alten Variationen liegt in
# scratchpad\jura-variable-snapshot.json (Wiederaufnahme bei Abbruch moeglich).
#   .\build-jura-devices.ps1
$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$root\wc-lib.ps1" | Out-Null

$vars = Get-Content "$root\jura-variants.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$mid  = [string][char]0x00B7
$snapPath = "$root\scratchpad\jura-variable-snapshot.json"

# ---- Phase 1: Snapshot der variablen Produkte (nur wenn noch nicht vorhanden) ----
if (-not (Test-Path $snapPath)) {
  $snap = @()
  foreach ($sku in $vars.colors.PSObject.Properties.Name) {
    # SKUs im Shop tragen ein Suffix ("15609 (1099)") -> Eltern ueber Praefix-Suche finden
    $parent = @(wc GET "products?search=$sku&status=any&per_page=20" | ForEach-Object { $_ }) | Where-Object { $_.sku -like "$sku*" } | Select-Object -First 1
    if (-not $parent) { Write-Host "[fehlt] $sku" -ForegroundColor Yellow; continue }
    if ($parent.type -ne 'variable') { Write-Host "[schon einfach] $sku id=$($parent.id)"; continue }
    $vs = @(wc GET "products/$($parent.id)/variations?per_page=100" | ForEach-Object { $_ })
    if (-not $parent.id -or $vs.Count -eq 0) { throw "Snapshot unvollstaendig fuer $sku" }
    $snap += [pscustomobject]@{ sku = $sku; parent = $parent; variations = $vs }
  }
  $snap | ConvertTo-Json -Depth 30 | Set-Content $snapPath -Encoding UTF8
  Write-Host "Snapshot gespeichert: $($snap.Count) variable Produkte" -ForegroundColor Cyan
}
$snap = @(Get-Content $snapPath -Raw -Encoding UTF8 | ConvertFrom-Json | ForEach-Object { $_ })   # PS 5.1 entrollt JSON-Arrays nicht selbst

function New-Name($parentName, $color, $allColors) {
  # "JURA Z10 (EB · Aluminium)" + "Aluminium White" -> "JURA Z10 (EB · Aluminium White)"
  if ($parentName -notmatch '^(.*?)\s*\((.*)\)\s*$') { return "$parentName $mid $color" }
  $model = $Matches[1]; $inner = $Matches[2]
  $parts = @($inner -split " $mid ")
  $last  = $parts[$parts.Count - 1]
  $hit   = @($allColors | Where-Object { $_.StartsWith($last) })
  if ($hit.Count -gt 0) { $parts = @($parts | Select-Object -SkipLast 1) }
  $parts += $color
  return "$model ($($parts -join " $mid "))"
}

foreach ($g in $snap) {
  $colors    = @($vars.colors.($g.sku))
  $colorNames = @($colors | ForEach-Object { $_.name })
  $parent    = $g.parent
  $pid0      = $parent.id
  $base      = $colors[0]
  $catIds    = @($parent.categories | ForEach-Object { @{ id = $_.id } })
  $price     = $parent.regular_price
  if (-not $price) { $price = $parent.price }
  Write-Host "`n=== $($parent.name) (id=$pid0) ===" -ForegroundColor Cyan

  # ---- Phase 2: Variationen loeschen, Eltern -> einfaches Produkt (1. Farbe) ----
  $cur = wc GET "products/$pid0"
  if ($cur.type -eq 'variable') {
    foreach ($v in @($g.variations)) { $null = wc DELETE "products/$pid0/variations/$($v.id)?force=true" }
    $attrs = @($parent.attributes | ForEach-Object {
      @{ id = $_.id; name = $_.name; position = $_.position; visible = $true; variation = $false
         options = $(if ($_.name -eq 'Farbe') { @($base.name) } else { @($_.options) }) }
    })
    $null = wc PUT "products/$pid0" @{
      type = 'simple'; name = (New-Name $parent.name $base.name $colorNames)
      regular_price = "$price"; attributes = $attrs; default_attributes = @()
    }
    Write-Host ("  [Eltern -> einfach] {0}" -f (New-Name $parent.name $base.name $colorNames))
  } else { Write-Host "  [Eltern schon einfach]" }

  # ---- Phase 3: Geschwister-Produkte anlegen ----
  $members = @(@{ name = $base.name; id = $pid0; slug = $cur.slug })
  foreach ($c in ($colors | Select-Object -Skip 1)) {
    $var  = @($g.variations | Where-Object { ($_.attributes | Where-Object { $_.name -eq 'Farbe' }).option -eq $c.name }) | Select-Object -First 1
    $name = New-Name $parent.name $c.name $colorNames
    $sku  = if ($var -and $var.sku) { "$($var.sku)" } else { "$($c.art)" }
    $ex   = @(wc GET "products?sku=$([uri]::EscapeDataString($sku))&status=any" | ForEach-Object { $_ }) | Select-Object -First 1
    if ($ex) { Write-Host "  [vorhanden] $name id=$($ex.id)"; $members += @{ name = $c.name; id = $ex.id; slug = $ex.slug }; continue }

    $imgs = @()
    if ($var -and $var.image -and $var.image.id) { $imgs += @{ id = $var.image.id } }
    if ($var -and $var.gallery_image_ids) { $imgs += @($var.gallery_image_ids | ForEach-Object { @{ id = $_ } }) }
    $attrs = @($parent.attributes | ForEach-Object {
      @{ id = $_.id; name = $_.name; position = $_.position; visible = $true; variation = $false
         options = $(if ($_.name -eq 'Farbe') { @($c.name) } else { @($_.options) }) }
    })
    $vPrice = if ($var -and $var.regular_price) { $var.regular_price } else { "$price" }
    $body = @{
      name = $name; type = 'simple'; sku = $sku; status = $parent.status
      regular_price = "$vPrice"; catalog_visibility = 'visible'; manage_stock = $false
      categories = $catIds; attributes = $attrs
      short_description = $parent.short_description; description = $parent.description
      tax_status = $parent.tax_status; tax_class = $parent.tax_class
      weight = $parent.weight; dimensions = $parent.dimensions
      meta_data = @($parent.meta_data | Where-Object { $_.key -like '_kt_*' } | ForEach-Object { @{ key = $_.key; value = $_.value } })
    }
    if ($parent.shipping_class) { $body.shipping_class = $parent.shipping_class }
    if ($imgs.Count -gt 0) { $body.images = $imgs }
    $r = wc POST 'products' $body
    Write-Host ("  [neu ({0})] {1}  id={2}  Bilder={3}  {4} EUR" -f $r.status, $name, $r.id, @($r.images).Count, $r.regular_price)
    $members += @{ name = $c.name; id = $r.id; slug = $r.slug }
  }

  # ---- Phase 4: "Weitere Farben"-Links ----
  # Die Kurzbeschreibung wird im Shop als Post-Excerpt ausgegeben (HTML entfernt), darum
  # steht der Block am Anfang der Langbeschreibung (HTML erlaubt); ein Skript im Shop-Header
  # (build-pages.ps1) schiebt .kt-farben unter den Kurztext.
  $blockRe = '(?s)<div class="kt-farben".*?</div>\s*'
  foreach ($m in $members) {
    $me = wc GET "products/$($m.id)"
    $short = [regex]::Replace("$($me.short_description)", $blockRe, '').TrimEnd()
    $desc  = [regex]::Replace("$($me.description)", $blockRe, '')
    $others = @($members | Where-Object { $_.id -ne $m.id })
    $links = ($others | ForEach-Object {
      $u = (wc GET "products/$($_.id)").permalink
      "<a href=`"$u`" style=`"display:inline-block;margin:0 8px 8px 0;padding:6px 14px;border:1px solid #333;border-radius:20px;color:#222;text-decoration:none;font-size:14px;`">$($_.name)</a>"
    }) -join ''
    $block = "<div class=`"kt-farben`" style=`"margin:0 0 18px;`"><p style=`"margin:0 0 6px;font-weight:700;`">Farbe: $($m.name)</p><p style=`"margin:0 0 6px;font-size:14px;`">Auch erh&auml;ltlich in:</p>$links</div>"
    $upd = @{ short_description = $short; description = ($block + $desc) }
    if ($m.id -ne $pid0) {   # neue Produkte: ASCII-Slug statt "%c2%b7" (Mittelpunkt im Namen)
      $slug = ($me.name.ToLower() -replace [regex]::Escape($mid), ' ' -replace '[^a-z0-9]+', '-').Trim('-')
      $upd.slug = $slug
    }
    $null = wc PUT "products/$($m.id)" $upd
    Write-Host ("  [Farb-Links] {0} -> {1}" -f $m.name, (($others | ForEach-Object { $_.name }) -join ', '))
  }
}
Write-Host "`nFertig. JURA-Farbvarianten sind jetzt Einzelprodukte." -ForegroundColor Cyan
