# Bestelluebersicht als PDF (fuer Steuerberater / zur Rechnung legen)
# Aufruf:  .\bestellung-uebersicht.ps1 -Id 4888        (Ausgabe: .\Bestellungen\Bestellung-4888.pdf)
# Nutzt die WooCommerce-REST-Daten (Positionen, Versand, MwSt, PayPal-/Karten-Gebuehren) und Edge zum PDF-Druck.
# Nur ASCII im Skript (PS 5.1 liest .ps1 als ANSI) - deutsche Texte als HTML-Entities.
param(
  [Parameter(Mandatory = $true)][int]$Id,
  [string]$OutDir = (Join-Path $PSScriptRoot 'Bestellungen'),
  [switch]$Preview
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
. "$PSScriptRoot\wp-lib.ps1" | Out-Null

$de = [Globalization.CultureInfo]::GetCultureInfo('de-DE')
$inv = [Globalization.CultureInfo]::InvariantCulture
function Num($s) { if ($null -eq $s -or "$s" -eq '') { return [double]0 }; [double]::Parse("$s", $inv) }
function Eur($v) { ([double]$v).ToString('N2', $de) + '&nbsp;&euro;' }
function Hx($s) { [Net.WebUtility]::HtmlEncode("$s") }
function Dt($s) { if (-not $s) { return '-' }; $u = [datetime]::Parse($s, $inv, [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal); [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($u, 'W. Europe Standard Time').ToString('dd.MM.yyyy HH:mm', $de) + ' Uhr' }
function Addr($a) {
  $l = @()
  $n = (($a.first_name + ' ' + $a.last_name).Trim()); if ($a.company) { $l += Hx $a.company }; if ($n) { $l += Hx $n }
  if ($a.address_1) { $l += Hx $a.address_1 }; if ($a.address_2) { $l += Hx $a.address_2 }
  $ort = (($a.postcode + ' ' + $a.city).Trim()); if ($ort) { $l += Hx $ort }
  if ($a.country -and $a.country -ne 'DE') { $l += Hx $a.country }
  if ($l.Count -eq 0) { return '-' }; $l -join '<br>'
}

$o = wp GET "/wc/v3/orders/$Id"
if (-not $o.id) { throw "Bestellung $Id nicht gefunden" }

$status = @{ completed = 'Abgeschlossen'; processing = 'In Bearbeitung'; 'on-hold' = 'Wartet auf Zahlung'; pending = 'Zahlung ausstehend'; cancelled = 'Storniert'; refunded = 'Erstattet'; failed = 'Fehlgeschlagen' }
$st = if ($status.ContainsKey($o.status)) { $status[$o.status] } else { $o.status }
function Meta($k) { ($o.meta_data | Where-Object { $_.key -eq $k } | Select-Object -First 1).value }

# ---- Zeilen (netto / MwSt / brutto) ----
$rows = @(); $sumNet = 0.0; $groups = @{}
function AddTax($rate, $tax, $net) {
  $k = "$rate"; if (-not $groups.ContainsKey($k)) { $groups[$k] = @{ net = 0.0; tax = 0.0 } }
  $groups[$k].net += $net; $groups[$k].tax += $tax
}
foreach ($li in $o.line_items) {
  $net = Num $li.total; $tax = Num $li.total_tax; $qty = [int]$li.quantity
  $rate = if ($net -gt 0) { [math]::Round($tax / $net * 100, 0) } else { 0 }
  $sku = if ($li.sku) { '<div class="sku">Art.-Nr.: ' + (Hx $li.sku) + '</div>' } else { '' }
  $rows += '<tr><td>' + (Hx $li.name) + $sku + '</td><td class="r">' + $qty + '</td><td class="r">' + (Eur ($net / [math]::Max($qty, 1))) + '</td><td class="r">' + (Eur $net) + '</td><td class="r">' + $rate + '&nbsp;%</td><td class="r">' + (Eur $tax) + '</td><td class="r">' + (Eur ($net + $tax)) + '</td></tr>'
  $sumNet += $net; AddTax $rate $tax $net
}
foreach ($sl in $o.shipping_lines) {
  $net = Num $sl.total; $tax = Num $sl.total_tax
  $rate = if ($net -gt 0) { [math]::Round($tax / $net * 100, 0) } else { 0 }
  $rows += '<tr><td>Versand: ' + (Hx $sl.method_title) + '</td><td class="r">1</td><td class="r">' + (Eur $net) + '</td><td class="r">' + (Eur $net) + '</td><td class="r">' + $rate + '&nbsp;%</td><td class="r">' + (Eur $tax) + '</td><td class="r">' + (Eur ($net + $tax)) + '</td></tr>'
  $sumNet += $net; AddTax $rate $tax $net
}
foreach ($fl in $o.fee_lines) {
  $net = Num $fl.total; $tax = Num $fl.total_tax
  $rate = if ($net -ne 0) { [math]::Round($tax / $net * 100, 0) } else { 0 }
  $rows += '<tr><td>Geb&uuml;hr: ' + (Hx $fl.name) + '</td><td class="r">1</td><td class="r">' + (Eur $net) + '</td><td class="r">' + (Eur $net) + '</td><td class="r">' + $rate + '&nbsp;%</td><td class="r">' + (Eur $tax) + '</td><td class="r">' + (Eur ($net + $tax)) + '</td></tr>'
  $sumNet += $net; AddTax $rate $tax $net
}
$taxRows = ''
foreach ($k in ($groups.Keys | Sort-Object { [double]$_ })) {
  $taxRows += '<tr><td>MwSt. ' + $k + '&nbsp;% auf ' + (Eur $groups[$k].net) + '</td><td class="r">' + (Eur $groups[$k].tax) + '</td></tr>'
}
$disc = Num $o.discount_total
$discRow = if ($disc -gt 0) { '<tr><td>Rabatt / Gutschein (netto, bereits in den Zeilen abgezogen)</td><td class="r">-' + (Eur $disc) + '</td></tr>' } else { '' }
$total = Num $o.total

# ---- Zahlung / PayPal ----
$pay = '<tr><th>Zahlungsart</th><td>' + (Hx $o.payment_method_title) + '</td></tr>'
if ($o.transaction_id) { $pay += '<tr><th>Transaktions-ID</th><td>' + (Hx $o.transaction_id) + '</td></tr>' }
$ppOrder = Meta '_ppcp_paypal_order_id'; if ($ppOrder) { $pay += '<tr><th>PayPal-Bestell-ID</th><td>' + (Hx $ppOrder) + '</td></tr>' }
$ppMail = Meta '_ppcp_paypal_payer_email'; if ($ppMail) { $pay += '<tr><th>PayPal-Konto Kunde</th><td>' + (Hx $ppMail) + '</td></tr>' }
$fees = Meta '_ppcp_paypal_fees'
$feeBlock = ''
if ($fees -and $fees.paypal_fee) {
  $gross = Num $fees.gross_amount.value; $fee = Num $fees.paypal_fee.value; $netIn = Num $fees.net_amount.value
  $quote = if ($gross -gt 0) { ($fee / $gross * 100).ToString('N2', $de) + '&nbsp;%' } else { '-' }
  $feeBlock = '<h2>Zahlungsabwicklung (PayPal)</h2><table class="sum"><tr><td>Zahlungseingang brutto (Kundenzahlung)</td><td class="r">' + (Eur $gross) + '</td></tr>' +
    '<tr><td>PayPal-Geb&uuml;hr (' + $quote + ' vom Bruttobetrag)</td><td class="r">-' + (Eur $fee) + '</td></tr>' +
    '<tr class="tot"><td>Nettoeingang auf dem PayPal-Konto</td><td class="r">' + (Eur $netIn) + '</td></tr></table>' +
    '<p class="note">Die Geb&uuml;hr wird von PayPal einbehalten und ist nicht Teil der Kundenrechnung. Angaben laut PayPal-Daten der Bestellung; ma&szlig;geblich ist die PayPal-Abrechnung.</p>'
} elseif ($o.payment_method -like 'ppcp*') {
  $feeBlock = '<h2>Zahlungsabwicklung (PayPal)</h2><p class="note">Zu dieser Bestellung liegen keine PayPal-Geb&uuml;hrendaten vor.</p>'
} elseif ($o.payment_method -eq 'woocommerce_payments') {
  # WooPayments (Karte, Apple/Google Pay): Gebuehr + Netto stehen in den Bestell-Metadaten
  $wFee = Meta '_wcpay_transaction_fee'; $wNet = Meta '_wcpay_net'
  $cardInfo = ''
  $pmd = Meta '_wcpay_payment_method_details'
  if ($pmd) { try { $pj = $pmd | ConvertFrom-Json; if ($pj.card.brand) { $cardInfo = ' (' + (Hx (($pj.card.brand.Substring(0,1).ToUpper() + $pj.card.brand.Substring(1)))) + ')' } } catch {} }
  if ($wFee) {
    $fee = Num $wFee; $gross = $total
    $netIn = if ($wNet) { Num $wNet } else { $gross - $fee }
    $quote = if ($gross -gt 0) { ($fee / $gross * 100).ToString('N2', $de) + '&nbsp;%' } else { '-' }
    $feeBlock = '<h2>Zahlungsabwicklung (Kartenzahlung' + $cardInfo + ')</h2><table class="sum"><tr><td>Zahlungseingang brutto (Kundenzahlung)</td><td class="r">' + (Eur $gross) + '</td></tr>' +
      '<tr><td>Kartengeb&uuml;hr WooPayments (' + $quote + ' vom Bruttobetrag)</td><td class="r">-' + (Eur $fee) + '</td></tr>' +
      '<tr class="tot"><td>Nettoeingang (Auszahlungsbetrag)</td><td class="r">' + (Eur $netIn) + '</td></tr></table>' +
      '<p class="note">Die Geb&uuml;hr wird von WooPayments/Stripe einbehalten und ist nicht Teil der Kundenrechnung. Angaben laut Bestelldaten; ma&szlig;geblich ist die WooPayments-Abrechnung.</p>'
  } else {
    $feeBlock = '<h2>Zahlungsabwicklung (Kartenzahlung)</h2><p class="note">Zu dieser Bestellung liegen keine Geb&uuml;hrendaten vor.</p>'
  }
}
$note = if ($o.customer_note) { '<h2>Kundenhinweis</h2><p>' + (Hx $o.customer_note) + '</p>' } else { '' }

$html = @"
<!DOCTYPE html><html lang="de"><head><meta charset="utf-8"><title>Bestell&uuml;bersicht $($o.number)</title>
<style>
@page { size: A4; margin: 16mm 16mm 18mm 16mm; }
* { box-sizing: border-box; }
body { font-family: "Segoe UI", Arial, sans-serif; color: #1c1c1c; font-size: 10pt; line-height: 1.45; margin: 0; }
.head { display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 2px solid #334155; padding-bottom: 10px; margin-bottom: 16px; }
h1 { font-size: 19pt; margin: 0 0 2px; color: #1e293b; }
.sub { color: #555; font-size: 10pt; }
.firm { text-align: right; font-size: 9pt; color: #444; line-height: 1.4; }
.firm b { color: #1c1c1c; font-size: 10pt; }
h2 { font-size: 11pt; margin: 18px 0 6px; padding-bottom: 3px; border-bottom: 1px solid #ccc; color: #1e293b; }
table { border-collapse: collapse; width: 100%; }
.info th { text-align: left; width: 34%; font-weight: 600; color: #444; padding: 3px 8px 3px 0; vertical-align: top; }
.info td { padding: 3px 0; }
.cols { display: flex; gap: 24px; } .cols > div { flex: 1; }
.pos th { background: #eef1f5; text-align: left; font-size: 9pt; padding: 6px 7px; border-bottom: 1px solid #b9c1cc; }
.pos td { padding: 7px; border-bottom: 1px solid #e3e6ea; vertical-align: top; }
.pos th.r, .pos td.r, .sum td.r { text-align: right; white-space: nowrap; }
.sku { color: #666; font-size: 8.5pt; }
.sum { width: 62%; margin-left: auto; margin-top: 8px; }
.sum td { padding: 4px 7px; border-bottom: 1px solid #eee; }
.sum tr.tot td { font-weight: 700; border-top: 2px solid #334155; border-bottom: 0; font-size: 11pt; }
.note { font-size: 8.5pt; color: #555; margin: 4px 0 0; }
.foot { margin-top: 22px; padding-top: 8px; border-top: 1px solid #ccc; font-size: 8pt; color: #666; }
</style></head><body>
<div class="head">
  <div><h1>Bestell&uuml;bersicht</h1><div class="sub">Bestellung Nr. $($o.number) &middot; $(Dt $o.date_created_gmt)</div></div>
  <div class="firm"><b>Joachim Bl&ouml;chle Elektro-Service GmbH</b><br>JB Kaffeemaschinen &ndash; Service &amp; Verkauf<br>Wallauer Str. 4, 65719 Hofheim-Langenhain<br>shop@kaffeetechniker.de</div>
</div>
<h2>Bestelldaten</h2>
<table class="info">
<tr><th>Bestellnummer</th><td>$($o.number)</td></tr>
<tr><th>Bestelldatum</th><td>$(Dt $o.date_created_gmt)</td></tr>
<tr><th>Bezahlt am</th><td>$(Dt $o.date_paid_gmt)</td></tr>
<tr><th>Status</th><td>$(Hx $st)</td></tr>
$pay
</table>
<div class="cols"><div><h2>Rechnungsadresse</h2>$(Addr $o.billing)<br>$(Hx $o.billing.email)</div><div><h2>Lieferadresse</h2>$(Addr $o.shipping)</div></div>
<h2>Positionen</h2>
<table class="pos"><tr><th>Artikel</th><th class="r">Menge</th><th class="r">Einzel netto</th><th class="r">Netto</th><th class="r">MwSt.-Satz</th><th class="r">MwSt.</th><th class="r">Brutto</th></tr>
$($rows -join "`n")
</table>
<table class="sum">
<tr><td>Summe netto</td><td class="r">$(Eur $sumNet)</td></tr>
$discRow
$taxRows
<tr class="tot"><td>Gesamtbetrag brutto</td><td class="r">$(Eur $total)</td></tr>
</table>
$feeBlock
$note
<div class="foot">Diese &Uuml;bersicht wurde am $((Get-Date).ToString('dd.MM.yyyy HH:mm', $de)) Uhr aus den Bestelldaten des Shops erzeugt und ersetzt keine Rechnung. Betr&auml;ge in Euro.</div>
</body></html>
"@

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$htmlPath = Join-Path $OutDir "Bestellung-$($o.number).html"
$pdfPath = Join-Path $OutDir "Bestellung-$($o.number).pdf"
[IO.File]::WriteAllText($htmlPath, $html, (New-Object Text.UTF8Encoding($false)))

$edge = @("$env:ProgramFiles (x86)\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Google\Chrome\Application\chrome.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { throw 'Weder Edge noch Chrome gefunden - HTML liegt unter ' + $htmlPath }
if (Test-Path $pdfPath) { Remove-Item $pdfPath -Force }
$uri = ([uri]$htmlPath).AbsoluteUri
$prof = Join-Path ([IO.Path]::GetTempPath()) ('ktpdf-' + [guid]::NewGuid().ToString('N'))
$errLog = Join-Path ([IO.Path]::GetTempPath()) ('ktpdf-err-' + [guid]::NewGuid().ToString('N') + '.txt')
$edgeArgs = @('--headless=new', '--disable-gpu', '--no-pdf-header-footer', "--user-data-dir=`"$prof`"", "--print-to-pdf=`"$pdfPath`"", "`"$uri`"")
Start-Process -FilePath $edge -ArgumentList $edgeArgs -Wait -NoNewWindow -RedirectStandardError $errLog
Remove-Item $errLog -Force -ErrorAction SilentlyContinue
$t = 0; while (-not (Test-Path $pdfPath) -and $t -lt 30) { Start-Sleep -Milliseconds 500; $t++ }
Remove-Item $prof -Recurse -Force -ErrorAction SilentlyContinue
if (-not (Test-Path $pdfPath)) { throw 'PDF wurde nicht erzeugt' }
if ($Preview) {
  $png = Join-Path $OutDir "Bestellung-$($o.number)-vorschau.png"
  $shotArgs = @('--headless=new', '--disable-gpu', "--user-data-dir=`"$prof`"", '--window-size=794,1123', "--screenshot=`"$png`"", "`"$uri`"")
  Start-Process -FilePath $edge -ArgumentList $shotArgs -Wait -NoNewWindow -RedirectStandardError $errLog
  Write-Host "Vorschau: $png"
}
Remove-Item $prof -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $htmlPath -Force
Write-Host ("PDF: {0} ({1} KB) | netto {2} | brutto {3}" -f $pdfPath, [math]::Round((Get-Item $pdfPath).Length / 1KB), $sumNet.ToString('N2', $de), $total.ToString('N2', $de))
