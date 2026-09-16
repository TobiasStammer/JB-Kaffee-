# fix-middot-entity.ps1
# Ersetzt die HTML-Entity "&middot;" durch das echte Unicode-Zeichen in
# den restlichen (einfarbigen) JURA-Produkttiteln. Grund: in einem
# Screenreader-Text im Warenkorb/an der Kasse wird die Entity nicht
# aufgeloest und woertlich vorgelesen (siehe Kundentest).
$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null

$ids = @(2730,2728,468,466,462,452,448,446,440)
foreach ($id in $ids) {
  $p = wc GET "products/$id"
  if ($p.name -match '&middot;') {
    $dot = [char]0x00B7
    $newName = $p.name -replace '\s*&middot;\s*', " $dot "
    $r = wc PUT "products/$id" @{ name = $newName }
    Write-Host ("id={0,-5} name={1}" -f $r.id, $r.name)
  } else {
    Write-Host ("id={0,-5} unveraendert (kein &middot; gefunden): {1}" -f $id, $p.name)
  }
}
Write-Host "Fertig." -ForegroundColor Green
