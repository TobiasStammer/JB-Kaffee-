# jura-scrape-images.ps1 - holt je JURA-Produktseite die echten Bild-URLs von
# api.jura.com (Packshot, Overview, image-gallery/*, features/*) und schreibt
# jura-images.json  { "<sku>": ["url", ...] }.  Zubehoer/Pflege/Hero werden gefiltert.
$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$data = Get-Content "$root\jura-products.json" -Raw -Encoding UTF8 | ConvertFrom-Json

# Reihenfolge/Prioritaet der Bildtypen
function Rank($u) {
  if ($u -match '_packshot\.') { return 0 }
  if ($u -match 'packshot')    { return 1 }
  if ($u -match '_overview\.|Overview') { return 2 }
  if ($u -match 'image-gallery') { return 3 }
  if ($u -match 'features')      { return 4 }
  return 5
}

$out = [ordered]@{}
foreach ($p in $data.haushalt) {
  # Modellordner aus der bekannten overview-URL ableiten: .../home-products/<PFAD>/<datei>
  $mPath = ([regex]::Match($p.img, 'home-products/(.+)/[^/]+$')).Groups[1].Value
  $lineRoot = ($mPath -split '/')[0]   # z.B. giga-line, z-line-2025
  try {
    $r = Invoke-WebRequest -Uri $p.url -UseBasicParsing -ErrorAction Stop
  } catch {
    Write-Host ("[FEHLER] {0} {1} -> {2}" -f $p.sku, $p.name, $_.Exception.Message) -ForegroundColor Red
    $out[$p.sku] = @($p.img)
    continue
  }
  $all = [regex]::Matches($r.Content, 'https://api\.jura\.com/media/global/images/home-products/[^"'' <>\\]+\.(?:jpg|jpeg|png)') |
         ForEach-Object { $_.Value } | Sort-Object -Unique
  # nur Bilder aus dem Modell-Zweig, keine Zubehoer/Pflege/Hero/360
  $keep = $all | Where-Object {
    $_ -match [regex]::Escape("home-products/$lineRoot/") -and
    $_ -notmatch '/accessories/|/maintenance-products/|/hero/|/flash/|_Play\.|360'
  }
  # Modell-spezifisch (Ordnername) zuerst, dann nach Typ, overview an den Anfang
  $modelFolder = ($mPath -split '/')[-1]
  $keep = $keep | Sort-Object @{e={ if ($_ -match [regex]::Escape("/$modelFolder/")) {0} else {1} }}, @{e={ Rank $_ }}, @{e={$_}}
  if (-not $keep) { $keep = @($p.img) }
  # overview als erstes Bild erzwingen (Haupt-Packshot der Kategorieseite bleibt konsistent)
  $keep = @($p.img) + @($keep | Where-Object { $_ -ne $p.img })
  $keep = $keep | Select-Object -Unique -First 8
  $out[$p.sku] = @($keep)
  Write-Host ("[ok] {0,-6} {1,-34} {2} Bilder" -f $p.sku, $p.name, @($keep).Count)
}

$out | ConvertTo-Json -Depth 5 | Set-Content "$root\jura-images.json" -Encoding UTF8
Write-Host "`ngeschrieben: jura-images.json" -ForegroundColor Cyan
