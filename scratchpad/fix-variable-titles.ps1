# fix-variable-titles.ps1
# Entfernt die fest einprogrammierte Standardfarbe aus dem Namen von
# mehrfarbigen (variablen) JURA-Produkten. Grund: WooCommerce zeigt im
# Warenkorb/an der Kasse immer den PRODUKTNAMEN (nicht die gewaehlte
# Variante) an - bei "JURA E8 (ED . Midnight Silver)" mit ausgewaehlter
# Farbe "Piano White" stand dort widerspruechlich beides gleichzeitig.
# Die tatsaechliche Farbe erscheint ohnehin separat als "Farbe: ..."-Zeile.
#
# Mittelpunkt als echtes Unicode-Zeichen (nicht &middot;-Entity), weil die
# Entity in einem Screenreader-Text (Warenkorb-Zusammenfassung) unverdaut
# als "&middot;" vorgelesen wird statt als "." - siehe Kundentest.
$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null
$dot = [char]0x00B7

$items = @(
  @{ id = 460; title = 'JURA C9 (EA)' }
  @{ id = 458; title = 'JURA E4 (EA)' }
  @{ id = 456; title = 'JURA E6 (ED)' }
  @{ id = 454; title = 'JURA E8 (ED)' }
  @{ id = 444; title = "JURA Z10 (EB $dot Diamond)" }
  @{ id = 442; title = "JURA Z10 (EB $dot Aluminium)" }
)
foreach ($it in $items) {
  $r = wc PUT "products/$($it.id)" @{ name = $it.title }
  Write-Host ("id={0,-5} name={1}" -f $r.id, $r.name)
}
Write-Host "Fertig." -ForegroundColor Green
