# update-jura-sku-ea.ps1
# Ergaenzt bei den 15 JURA-Haushaltsgeraeten, die per HERST_NR/SKU eindeutig
# mit der SUP-Lagerliste (Daten.pdf) abgeglichen wurden:
#  - fehlende Edition (EA/EB/EC/ED) im Produktnamen, im selben schliessenden
#    Klammerpaar wie die Farbe (die Kartenanzeige auf /jura-kaffeevollautomaten/
#    entfernt nur EIN schliessendes Klammerpaar am Ende -> zwei getrennte
#    Klammern wuerden die Kurzbezeichnung kaputt machen)
#  - SUP-Artikelnummer in Klammern an die SKU (Feld bleibt fuer Kunden
#    unsichtbar, Personal sieht sie im Bestellwesen/Adminbereich)
# Preiskorrekturen (aus export.pdf, Abgleich ueber Art.-Nr. = SUP-Nummer):
#  - JURA S10 (Obsidian Black): Preis war leer -> 1799.00
#  - JURA E6 Piano White... nein, Piano Black-Variante: 979.00 -> 899.00
#  - JURA E8 Piano Black-Variante: 1249.00 -> 1149.00
$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null

$simple = @(
  @{ id = 2730; sku = '15775'; nr = '4379'; title = 'JURA S10 (EA &middot; Obsidian Black)'; regular_price = '1799.00' }
  @{ id = 2728; sku = '15736'; nr = '4381'; title = 'JURA A8 (EA &middot; Piano Black)' }
  @{ id = 468;  sku = '15501'; nr = '1136'; title = 'JURA ENA 4 (EB &middot; Full Metropolitan Black)' }
  @{ id = 466;  sku = '15696'; nr = '1135'; title = 'JURA ENA 5 (EA &middot; Night Inox)' }
  @{ id = 462;  sku = '15599'; nr = '1125'; title = 'JURA C3 (EA &middot; Piano Black)' }
  @{ id = 452;  sku = '15743'; nr = '4376'; title = 'JURA E10 (EA &middot; Onyx Grey)' }
  @{ id = 448;  sku = '15562'; nr = '4052'; title = 'JURA J10 (EA &middot; Piano Black)' }
  @{ id = 446;  sku = '15706'; nr = '1132'; title = 'JURA J10 twin (EA &middot; Diamond Onyx)' }
  @{ id = 440;  sku = '15478'; nr = '3608'; title = 'JURA GIGA 10 (EA &middot; Diamond Black)' }
)

$variable = @(
  @{ id = 460; title = 'JURA C9 (EA &middot; Piano Black)';  parentSku = '15753'; parentNr = '1126'
     vars = @(@{ vid=828; sku='15753'; nr='1126' }, @{ vid=830; sku='15810'; nr='4354' }) }
  @{ id = 458; title = 'JURA E4 (EA &middot; Piano Black)';  parentSku = '15435'; parentNr = '1120'
     vars = @(@{ vid=824; sku='15435'; nr='1120' }, @{ vid=826; sku='15433'; nr='1122' }) }
  @{ id = 456; title = 'JURA E6 (ED &middot; Dark Inox)';    parentSku = '15828'; parentNr = '4355'
     vars = @(@{ vid=820; sku='15828'; nr='4355' }, @{ vid=822; sku='15642'; nr='4356'; regular_price='899.00' }) }
  @{ id = 454; title = 'JURA E8 (ED &middot; Midnight Silver)'; parentSku = '15712'; parentNr = '1131'
     vars = @(@{ vid=812; sku='15712'; nr='1131' }, @{ vid=814; sku='15749'; nr='1130' }, @{ vid=816; sku='15745'; nr='1127'; regular_price='1149.00' }, @{ vid=818; sku='15747'; nr='1129' }) }
  @{ id = 444; title = 'JURA Z10 (EB &middot; Diamond Black)'; parentSku = '15615'; parentNr = '4358'
     vars = @(@{ vid=804; sku='15615'; nr='4358' }, @{ vid=806; sku='15619'; nr='4357' }) }
  @{ id = 442; title = 'JURA Z10 (EB &middot; Aluminium Black)'; parentSku = '15609'; parentNr = '1099'
     vars = @(@{ vid=800; sku='15609'; nr='1099' }, @{ vid=802; sku='15613'; nr='1100' }) }
)

Write-Host "=== Simple products ===" -ForegroundColor Cyan
foreach ($p in $simple) {
  $body = @{ name = $p.title; sku = "$($p.sku) ($($p.nr))" }
  if ($p.regular_price) { $body.regular_price = $p.regular_price }
  $r = wc PUT "products/$($p.id)" $body
  Write-Host ("id={0,-5} sku={1,-16} name={2}" -f $r.id, $r.sku, $r.name)
}

Write-Host "`n=== Variable products (parent + Farb-Varianten) ===" -ForegroundColor Cyan
foreach ($p in $variable) {
  $pbody = @{ name = $p.title; sku = "$($p.parentSku) ($($p.parentNr))" }
  $rp = wc PUT "products/$($p.id)" $pbody
  Write-Host ("PARENT id={0,-5} sku={1,-16} name={2}" -f $rp.id, $rp.sku, $rp.name)
  foreach ($v in $p.vars) {
    $vbody = @{ sku = "$($v.sku) ($($v.nr))" }
    if ($v.regular_price) { $vbody.regular_price = $v.regular_price }
    $rv = wc PUT "products/$($p.id)/variations/$($v.vid)" $vbody
    Write-Host ("  VAR id={0,-5} sku={1,-16} price={2}" -f $rv.id, $rv.sku, $rv.price)
  }
}
Write-Host "`nFertig." -ForegroundColor Green
