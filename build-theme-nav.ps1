# build-theme-nav.ps1 - setzt im Extendable-Theme die Kopfzeilen-Vorlage 'header'
# (greift auf Produkt-/Warenkorb-/Kasse-/Konto-Seiten) auf die selbsttragende
# Shop-Kopfzeile aus theme-shopbar.html (erzeugt von build-pages.ps1 -> Shop-Bar-Html).
# So sieht die Kopfzeile dort identisch aus wie auf den Shop-Inhaltsseiten
# (weisser Balken + klebendes dunkles Menueband).
#   1. .\build-pages.ps1   (erzeugt theme-shopbar.html)
#   2. .\build-theme-nav.ps1
$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$root\wp-lib.ps1" | Out-Null

$barFile = "$root\theme-shopbar.html"
if (-not (Test-Path $barFile)) { throw "theme-shopbar.html fehlt - zuerst build-pages.ps1 ausfuehren." }
$bar = Get-Content $barFile -Raw -Encoding UTF8

# ganze 'header'-Vorlage = 1 wp:html-Block mit der Shop-Kopfzeile
$headerContent = "<!-- wp:html -->`n$bar`n<!-- /wp:html -->"

$tps = wp GET '/wp/v2/template-parts?context=edit'
$tp = $tps | Where-Object { $_.slug -eq 'header' } | Select-Object -First 1
if (-not $tp) { throw "template-part 'header' nicht gefunden" }

$res = wp POST "/wp/v2/template-parts/$($tp.id)" @{ content = $headerContent }
$ok = ($res.content.raw -match 'shnav-wrap') -and -not ($res.content.raw -match 'wp:site-title')
Write-Host ("[header gesetzt] id={0}  shop-bar={1}" -f $tp.id, $ok)
Write-Host "Fertig. Produktseiten nutzen jetzt die Shop-Kopfzeile." -ForegroundColor Cyan
