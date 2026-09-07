$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wp-lib.ps1" | Out-Null
$oe = [char]0x00F6; $ue = [char]0x00FC; $ell = [char]0x2026

$repl = @(
  @{ from = 'Your cart is currently empty!';    to = 'Ihr Warenkorb ist noch leer.' }
  @{ from = 'New in store';                     to = 'Neu im Sortiment' }
  @{ from = 'You may be interested in&hellip;'; to = "Das k${oe}nnte Sie interessieren${ell}" }
  @{ from = 'Place Order';                      to = 'Jetzt kaufen' }
  @{ from = 'Order summary';                    to = "Bestell${ue}bersicht" }
  @{ from = 'Contact information';              to = 'Kontaktdaten' }
  @{ from = 'Shipping address';                 to = 'Lieferadresse' }
  @{ from = 'Billing address';                  to = 'Rechnungsadresse' }
  @{ from = 'Add a note to your order';         to = 'Anmerkung zur Bestellung' }
)

foreach ($pg in 7, 8) {
  $url = '/wp/v2/pages/' + $pg + '?context=edit&_fields=content'
  $raw = (wp GET $url).content.raw
  $new = $raw
  $hits = @()
  foreach ($r in $repl) { if ($new.Contains($r.from)) { $hits += $r.from; $new = $new.Replace($r.from, $r.to) } }
  if ($hits.Count) {
    $null = wp POST ('/wp/v2/pages/' + $pg) @{ content = $new }
    Write-Host ("[{0}] geaendert: {1}" -f $pg, ($hits -join ' | '))
  } else {
    Write-Host ("[{0}] nichts zu aendern" -f $pg)
  }
}
