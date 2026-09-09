$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. "$root\wp-lib.ps1" | Out-Null
$u=[char]0x00FC; $a=[char]0x00E4; $o=[char]0x00F6; $s=[char]0x00DF
$fid = 3

# --- Notification an shop@ ---
$notif = [pscustomobject]@{
  name    = 'Mietgeraet-Reservierung an die Werkstatt'
  sendTo  = [pscustomobject]@{ type = 'email'; email = 'shop@kaffeetechniker.de' }
  fromName  = 'JB Kaffeemaschinen ' + [char]0x2013 + ' Service & Verkauf'
  fromEmail = 'shop@kaffeetechniker.de'
  replyTo   = '{inputs.email}'
  bcc = ''
  subject = 'Neue Mietgeraet-Reservierung: {inputs.name}'
  message = "<p>Neue Mietger${a}t-Reservierung:</p><p><b>Name:</b> {inputs.name}<br><b>E-Mail:</b> {inputs.email}<br><b>Telefon:</b> {inputs.telefon}<br><b>Gew${u}nschtes Mietger${a}t:</b> {inputs.mietgeraet}<br><b>Wunschzeitraum:</b> {inputs.zeitraum}</p><p><b>Nachricht:</b><br>{inputs.nachricht}</p><p>Verf${u}gbarkeit pr${u}fen und zur Best${a}tigung melden.</p>"
  enabled = $true
  conditionals = [pscustomobject]@{ status = $false; type = 'all'; conditions = @([pscustomobject]@{ field=''; operator='='; value='' }) }
}
$ex = @(wp GET "/fluentform/v1/settings/$fid?meta_key=notifications")
if ($ex.Count -eq 1 -and $ex[0].Count -gt 1) { $ex = @($ex[0]) }
foreach ($e in $ex) {
  if ($e.id) { try { wp DELETE "/fluentform/v1/settings/$fid" @{ form_id=$fid; meta_key='notifications'; meta_id=$e.id } | Out-Null; Write-Host "alte Notification $($e.id) geloescht" } catch {} }
}
$r1 = wp POST "/fluentform/v1/settings/$fid" @{ form_id=$fid; meta_key='notifications'; value=($notif | ConvertTo-Json -Depth 10 -Compress) }
Write-Host "Notification: $($r1.message)"

# --- Bestaetigungstext ---
$confMsg = "Danke! Ihre Reservierungs-Anfrage f${u}r ein Mietger${a}t ist bei uns. Wir pr${u}fen die Verf${u}gbarkeit und melden uns zur Best${a}tigung - meist am selben oder n${a}chsten Werktag."
$resp = wp GET "/fluentform/v1/settings/$fid?meta_key=formSettings"
$rows = @($resp); if ($rows.Count -eq 1 -and $rows[0].Count -gt 1) { $rows = @($rows[0]) }
$main = $rows | Where-Object { $_.value.confirmation } | Select-Object -First 1
if ($main) {
  $v = $main.value
  $v.confirmation.messageToShow = $confMsg
  $v.confirmation.redirectTo = 'samePage'
  $v.confirmation.samePageFormBehavior = 'hide_form'
  $r2 = wp POST "/fluentform/v1/settings/$fid" @{ form_id=$fid; meta_key='formSettings'; meta_id=$main.id; value=($v | ConvertTo-Json -Depth 15 -Compress) }
  Write-Host "Bestaetigung (id $($main.id)): $($r2.message)"
  foreach ($r in $rows) { if ($r.id -ne $main.id) { try { wp DELETE "/fluentform/v1/settings/$fid" @{ form_id=$fid; meta_key='formSettings'; meta_id=$r.id } | Out-Null; Write-Host "doppelte formSettings $($r.id) geloescht" } catch {} } }
} else {
  $fs = [pscustomobject]@{ confirmation = [pscustomobject]@{ redirectTo='samePage'; messageToShow=$confMsg; customPage=$null; samePageFormBehavior='hide_form'; customUrl=$null } }
  $r2 = wp POST "/fluentform/v1/settings/$fid" @{ form_id=$fid; meta_key='formSettings'; value=($fs | ConvertTo-Json -Depth 15 -Compress) }
  Write-Host "Bestaetigung neu: $($r2.message)"
}

try { wp POST "/fluentform/v1/forms/$fid" @{ status='published' } | Out-Null; Write-Host "Form $fid published" } catch {}
