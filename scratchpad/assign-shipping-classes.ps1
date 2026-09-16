# assign-shipping-classes.ps1
# Ordnet Produkten die vom Nutzer angelegten Gewichtsklassen zu:
#   bis-2kg (4,90 EUR) / bis-8kg (6,90 EUR) / bis-15kg (9,90 EUR) / ab-15kg (12,90 EUR)
$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null
function Norm($r) { $r = @($r); if ($r.Count -eq 1 -and $r[0].Count -gt 1) { $r = @($r[0]) }; $r }

# ---- 1) JURA Kaffeevollautomaten Haushalt: echtes Gewicht aus jura-specs.json ----
# S10 (2730) hat noch kein vollstaendiges Datenblatt -> 10 kg als vorlaeufige
# Schaetzung (Groessenklasse wie E10/J10), spaeter mit echtem Wert ersetzen.
$machines = @(
  @{ id = 440; weight = '18';   class = 'ab-15kg' }   # GIGA 10
  @{ id = 442; weight = '12.3'; class = 'bis-15kg' }  # Z10 Aluminium
  @{ id = 444; weight = '12';   class = 'bis-15kg' }  # Z10 Diamond
  @{ id = 446; weight = '11.5'; class = 'bis-15kg' }  # J10 twin
  @{ id = 448; weight = '10.4'; class = 'bis-15kg' }  # J10
  @{ id = 452; weight = '10';   class = 'bis-15kg' }  # E10
  @{ id = 454; weight = '10';   class = 'bis-15kg' }  # E8
  @{ id = 456; weight = '9.7';  class = 'bis-15kg' }  # E6
  @{ id = 458; weight = '9.8';  class = 'bis-15kg' }  # E4
  @{ id = 460; weight = '9.5';  class = 'bis-15kg' }  # C9
  @{ id = 462; weight = '8.8';  class = 'bis-15kg' }  # C3
  @{ id = 466; weight = '8.7';  class = 'bis-15kg' }  # ENA 5
  @{ id = 468; weight = '8.4';  class = 'bis-15kg' }  # ENA 4
  @{ id = 2728; weight = '8.9'; class = 'bis-15kg' }  # A8
  @{ id = 2730; weight = '10';  class = 'bis-15kg' }  # S10 (Schaetzung, kein Datenblatt)
)
Write-Host "=== JURA Haushalt (echte Geraetegewichte) ===" -ForegroundColor Cyan
foreach ($m in $machines) {
  $r = wc PUT "products/$($m.id)" @{ weight = $m.weight; shipping_class = $m.class }
  Write-Host ("id={0,-5} weight={1,-6} class={2,-10} name={3}" -f $r.id, $r.weight, $r.shipping_class, $r.name)
}

# ---- 2) NIVONA Kaffeevollautomaten: vorlaeufig alle in "bis 15kg" (kein Datenblatt) ----
Write-Host "`n=== NIVONA Haushalt (Schaetzung, kein Datenblatt) ===" -ForegroundColor Cyan
$nivonaIds = @(1055,1053,1051,1049,1047,1045,1043,1041,1039)
foreach ($id in $nivonaIds) {
  $r = wc PUT "products/$id" @{ shipping_class = 'bis-15kg' }
  Write-Host ("id={0,-5} class={1,-10} name={2}" -f $r.id, $r.shipping_class, $r.name)
}

# ---- 3) Zubehoer / Pflegeprodukte / Kaffee / Tee: klein -> bis 2kg ----
Write-Host "`n=== Zubehoer/Pflege/Kaffee/Tee -> bis 2kg ===" -ForegroundColor Cyan
$all = Norm (wc GET 'products?per_page=100&status=publish')
$small = $all | Where-Object {
  $slugs = ($_.categories | ForEach-Object { $_.slug }) -join ','
  $slugs -match 'zubehoer|pflegeprodukte|^kaffee$|^tee$'
}
Write-Host ("gefunden: " + $small.Count)
foreach ($p in $small) {
  $r = wc PUT "products/$($p.id)" @{ shipping_class = 'bis-2kg' }
  Write-Host ("id={0,-5} class={1,-10} name={2}" -f $r.id, $r.shipping_class, $r.name)
}

Write-Host "`nFertig. JURA Professional (externe Produkte, kein Warenkorb/Versand) und NIVONA-Zubehoer/Pflege bewusst ausgelassen." -ForegroundColor Green
