# Ersetzt die Extendable-Theme-Footer-Vorlage durch den dunklen JB-Footer,
# damit Produkt-/Warenkorb-/Kasse-/Konto-Seiten unten identisch zu den
# Content-Seiten aussehen. Quelle: theme-footer.html (von build-pages.ps1).
$ErrorActionPreference = 'Stop'
$root = Split-Path $MyInvocation.MyCommand.Path -Parent
. "$root\wp-lib.ps1" | Out-Null

$html = Get-Content "$root\theme-footer.html" -Raw -Encoding UTF8
$content = "<!-- wp:html -->`n$html`n<!-- /wp:html -->"

$id = 'extendable//footer'
$res = wp POST "/wp/v2/template-parts/$id" @{ content = $content }
$ok = ($res.content.raw -match 'kt-wa') -and -not ($res.content.raw -match 'wp:social-links')
Write-Host "[footer gesetzt] id=$id  jb-footer=$ok"
