$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wp-lib.ps1" | Out-Null
. "$root\wc-lib.ps1" | Out-Null

$from = 'shop@kaffeetechniker.de'
$name = 'JB Kaffeemaschinen ' + [char]0x2013 + ' Service & Verkauf'

# --- WooCommerce Absender ---
$b = wc PUT 'settings/email/woocommerce_email_from_address' @{ value = $from }
Write-Host ("WC from_address  -> {0}" -f $b.value)
$b2 = wc PUT 'settings/email/woocommerce_email_from_name' @{ value = $name }
Write-Host ("WC from_name     -> {0}" -f $b2.value)

# --- Fluent Forms Notification (meta_id 15) ---
$resp = wp GET '/fluentform/v1/settings/1?meta_key=notifications'
$rows = @($resp)
if ($rows.Count -eq 1 -and $rows[0].Count -gt 1) { $rows = @($rows[0]) }
$n = $rows | Where-Object { $_.id -eq 15 } | Select-Object -First 1
if (-not $n) { throw 'notification meta_id 15 nicht gefunden' }
$v = $n.value
$v.fromEmail = $from
$v.fromName  = $name
$body = @{ form_id = 1; meta_key = 'notifications'; meta_id = 15; value = ($v | ConvertTo-Json -Depth 12 -Compress) }
$r = wp POST '/fluentform/v1/settings/1' $body
Write-Host ("FF notification  -> {0} / {1}  ({2})" -f $v.fromName, $v.fromEmail, $r.message)

# --- Kontrolle ---
Start-Sleep -Seconds 1
$chk = @(wp GET '/fluentform/v1/settings/1?meta_key=notifications')
if ($chk.Count -eq 1 -and $chk[0].Count -gt 1) { $chk = @($chk[0]) }
$chk | Where-Object { $_.id -eq 15 } | ForEach-Object { Write-Host ("  verifiziert: fromEmail={0} fromName={1} replyTo={2}" -f $_.value.fromEmail, $_.value.fromName, $_.value.replyTo) }
