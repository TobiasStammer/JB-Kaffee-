# update-jura-professional-prices.ps1
# Preise fuer die JURA-Professional-Produkte (aktuell "Preis auf Anfrage")
# aus der Lagerbestandsliste (export.pdf) uebernommen, Abgleich ueber die
# Herst.-Bezeichnung (Modell + Farbe), da diese Produkte im Shop
# Slug-SKUs statt HERST_NR-SKUs haben.
$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null

$prices = @(
  @{ id = 746; name='JURA W4 (Dark Inox)';      price = '1725.50' }  # Art.-Nr. 3011
  @{ id = 744; name='JURA W8 (Dark Inox)';      price = '2118.20' }  # Art.-Nr. 4112
  @{ id = 742; name='JURA X4 (Dark Inox)';      price = '2796.50' }  # Art.-Nr. 4082
  @{ id = 740; name='JURA X4c (Dark Inox)';     price = '3272.50' }  # Art.-Nr. 1134
  @{ id = 738; name='JURA X10 (Dark Inox)';     price = '3320.10' }  # Art.-Nr. 4342
  @{ id = 736; name='JURA X10c (Dark Inox)';    price = '3796.10' }  # Art.-Nr. 3008
  @{ id = 734; name='JURA GIGA X3 (Aluminium)'; price = '5224.10' }  # Art.-Nr. 3932
  @{ id = 732; name='JURA GIGA X3c (Aluminium)';price = '5462.10' }  # Art.-Nr. 4252
  @{ id = 730; name='JURA GIGA X8 (Aluminium)'; price = '7128.10' }  # Art.-Nr. 1133
  @{ id = 728; name='JURA GIGA X8c (Aluminium)';price = '7366.10' }  # Art.-Nr. 1137
)

foreach ($p in $prices) {
  $r = wc PUT "products/$($p.id)" @{ regular_price = $p.price }
  Write-Host ("id={0,-5} price={1,-10} name={2}" -f $r.id, $r.price, $r.name)
}
Write-Host "Fertig." -ForegroundColor Green
