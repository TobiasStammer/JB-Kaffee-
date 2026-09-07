$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wp-lib.ps1" | Out-Null
$u=[char]0x00FC; $a=[char]0x00E4; $o=[char]0x00F6; $s=[char]0x00DF

# --- Notification an shop@ ---
$notif = [pscustomobject]@{
  name    = 'Wartungserinnerung an die Werkstatt'
  sendTo  = [pscustomobject]@{ type = 'email'; email = 'shop@kaffeetechniker.de' }
  fromName  = 'JB Kaffeemaschinen ' + [char]0x2013 + ' Service & Verkauf'
  fromEmail = 'shop@kaffeetechniker.de'
  replyTo   = '{inputs.email}'
  bcc = ''
  subject = 'Neue Wartungserinnerung: {inputs.name}'
  message = "<p>Neue Anmeldung zur Wartungserinnerung:</p><p><b>Name:</b> {inputs.name}<br><b>E-Mail:</b> {inputs.email}<br><b>Kaffeemaschine:</b> {inputs.hersteller}<br><b>Letzte Wartung / Kaufdatum:</b> {inputs.letzte_wartung}</p><p>Bitte in die Wiedervorlage aufnehmen: Erinnerung in ca. 2 Jahren.</p>"
  enabled = $true
  conditionals = [pscustomobject]@{ status = $false; type = 'all'; conditions = @([pscustomobject]@{ field=''; operator='='; value='' }) }
}
$existing = @(wp GET '/fluentform/v1/settings/2?meta_key=notifications')
if ($existing.Count -eq 1 -and $existing[0].Count -gt 1) { $existing = @($existing[0]) }
foreach ($e in $existing) {
  if ($e.id) { try { wp DELETE '/fluentform/v1/settings/2' @{ form_id=2; meta_key='notifications'; meta_id=$e.id } | Out-Null; Write-Host "alte Notification $($e.id) geloescht" } catch {} }
}
$r1 = wp POST '/fluentform/v1/settings/2' @{ form_id=2; meta_key='notifications'; value=($notif | ConvertTo-Json -Depth 10 -Compress) }
Write-Host "Notification: $($r1.message)"

# --- Bestaetigung ---
$confMsg = "Vielen Dank! Wir haben Ihre Anmeldung zur Wartungserinnerung erhalten und melden uns in rund zwei Jahren rechtzeitig bei Ihnen. Tipp: Tragen Sie sich den Termin oben zus${a}tzlich in Ihren eigenen Kalender ein."
$resp = wp GET '/fluentform/v1/settings/2?meta_key=formSettings'
$rows = @($resp); if ($rows.Count -eq 1 -and $rows[0].Count -gt 1) { $rows = @($rows[0]) }
$main = $rows | Where-Object { $_.value.confirmation } | Select-Object -First 1
if ($main) {
  $v = $main.value
  $v.confirmation.messageToShow = $confMsg
  $v.confirmation.redirectTo = 'samePage'
  $v.confirmation.samePageFormBehavior = 'hide_form'
  $r2 = wp POST '/fluentform/v1/settings/2' @{ form_id=2; meta_key='formSettings'; meta_id=$main.id; value=($v | ConvertTo-Json -Depth 15 -Compress) }
  Write-Host "Bestaetigung (id $($main.id)): $($r2.message)"
} else {
  $fs = [pscustomobject]@{ confirmation = [pscustomobject]@{ redirectTo='samePage'; messageToShow=$confMsg; customPage=$null; samePageFormBehavior='hide_form'; customUrl=$null } }
  $r2 = wp POST '/fluentform/v1/settings/2' @{ form_id=2; meta_key='formSettings'; value=($fs | ConvertTo-Json -Depth 15 -Compress) }
  Write-Host "Bestaetigung neu: $($r2.message)"
}

# --- Form aktiv schalten ---
try { $r3 = wp POST '/fluentform/v1/forms/2' @{ status='published' }; Write-Host "Form-Status: published" } catch {}
