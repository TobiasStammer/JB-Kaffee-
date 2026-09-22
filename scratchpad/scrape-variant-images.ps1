$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

function Rank($u) {
  if ($u -match '_packshot\.') { return 0 }
  if ($u -match 'packshot')    { return 1 }
  if ($u -match '_overview\.|Overview') { return 2 }
  if ($u -match 'image-gallery') { return 3 }
  if ($u -match 'features')      { return 4 }
  return 5
}

# sku -> {url, lineRoot, modelFolder}  (lineRoot/modelFolder aus dem bestehenden
# jura-images.json des GESCHWISTER-SKUs desselben Produkts abgeleitet)
$targets = @(
  @{ sku='15613'; url='https://de.jura.com/de/produkte-haushalt/kaffeevollautomaten/z10-aluminium-white-eb-15613'; sibling='15609' }
  @{ sku='15619'; url='https://de.jura.com/de/produkte-haushalt/kaffeevollautomaten/z10diamond-white-eb-15619'; sibling='15615' }
  @{ sku='15482'; url='https://de.jura.com/de/produkte-haushalt/kaffeevollautomaten/s8-piano-black-eb-15482'; sibling='15483' }
  @{ sku='15749'; url='https://de.jura.com/de/produkte-haushalt/kaffeevollautomaten/e8-cosmic-black-ed-15749'; sibling='15712' }
  @{ sku='15745'; url='https://de.jura.com/de/produkte-haushalt/kaffeevollautomaten/e8piano-black-ed-15745'; sibling='15712' }
  @{ sku='15747'; url='https://de.jura.com/de/produkte-haushalt/kaffeevollautomaten/e8-piano-white-ed-15747'; sibling='15712' }
  @{ sku='15642'; url='https://de.jura.com/de/produkte-haushalt/kaffeevollautomaten/e6-piano-black-ed-15642'; sibling='15828' }
  @{ sku='15433'; url='https://de.jura.com/de/produkte-haushalt/kaffeevollautomaten/e4-piano-white-ea-15433'; sibling='15435' }
  @{ sku='15810'; url='https://de.jura.com/de/produkte-haushalt/kaffeevollautomaten/c9piano-white-ea-15810'; sibling='15753' }
  @{ sku='15491'; url='https://de.jura.com/de/produkte-haushalt/kaffeevollautomaten/ena-8-full-nordic-white-ec-15491'; sibling='15493' }
)

$existing = Get-Content "$root\jura-images.json" -Raw -Encoding UTF8 | ConvertFrom-Json
# in geordnetes Hashtable uebernehmen, damit wir mergen koennen
$out = [ordered]@{}
$existing.PSObject.Properties | ForEach-Object { $out[$_.Name] = @($_.Value) }

foreach ($t in $targets) {
  $sibImgs = @($out[$t.sibling])
  if (-not $sibImgs -or $sibImgs.Count -eq 0) { Write-Host "[skip] $($t.sku): kein Geschwister-Datensatz $($t.sibling)" -ForegroundColor Yellow; continue }
  try {
    $r = Invoke-WebRequest -Uri $t.url -UseBasicParsing -ErrorAction Stop
  } catch {
    Write-Host "[FEHLER] $($t.sku) -> $($_.Exception.Message)" -ForegroundColor Red
    continue
  }
  $all = [regex]::Matches($r.Content, 'https://api\.jura\.com/media/global/images/home-products/[^"'' <>\\]+\.(?:jpg|jpeg|png)') |
         ForEach-Object { $_.Value } | Sort-Object -Unique
  # og:image der Seite verrät den EXAKTEN Modell-Farb-Ordner dieser Variante
  # (z.B. .../Z10-EB-SB-Aluminium-White/...) - Filter darauf, damit keine
  # Bilder der Geschwisterfarbe reinrutschen.
  $og = [regex]::Match($r.Content, '<meta[^>]+property="og:image"[^>]+content="([^"]+)"').Groups[1].Value
  $ownFolder = ([regex]::Match($og, 'home-products/(.+)/[^/]+$')).Groups[1].Value
  if (-not $ownFolder) {
    Write-Host "[warn] $($t.sku): og:image-Ordner nicht gefunden, ueberspringe" -ForegroundColor Yellow
    continue
  }
  $keep = $all | Where-Object {
    $_ -match [regex]::Escape("home-products/$ownFolder/") -and
    $_ -notmatch '/accessories/|/maintenance-products/|/hero/|/flash/|_Play\.|360'
  }
  if (-not $keep) {
    Write-Host "[leer] $($t.sku): keine Bilder im Pfad $mPath gefunden (Seite evtl. anders aufgebaut)" -ForegroundColor Yellow
    continue
  }
  $keep = $keep | Sort-Object @{e={ Rank $_ }}, @{e={$_}} | Select-Object -Unique -First 8
  $out[$t.sku] = @($keep)
  Write-Host ("[ok] {0,-6} {1} Bilder" -f $t.sku, @($keep).Count)
}

$out | ConvertTo-Json -Depth 5 | Set-Content "$root\jura-images.json" -Encoding UTF8
Write-Host "`ngeschrieben: jura-images.json" -ForegroundColor Cyan
