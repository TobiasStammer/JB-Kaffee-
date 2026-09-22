$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. "$root\wp-lib.ps1" | Out-Null
$u=[char]0x00FC; $a=[char]0x00E4; $o=[char]0x00F6; $s=[char]0x00DF

$fid = 4

$notif = [pscustomobject]@{
  name      = ('Event-Mietanfrage an die Werkstatt')
  sendTo    = [pscustomobject]@{ type='email'; email='shop@kaffeetechniker.de' }
  fromName  = ('JB Kaffeemaschinen '+[char]0x2013+' Service & Verkauf')
  fromEmail = 'shop@kaffeetechniker.de'
  replyTo   = '{inputs.email}'
  bcc       = ''
  subject   = 'Neue Event-Mietanfrage: {inputs.name}'
  message   = (
    "<p>Neue Anfrage zur Kaffeemaschinen-Miete f$($u)r ein Event:</p>" +
    "<p><b>Name:</b> {inputs.name}<br>" +
    "<b>E-Mail:</b> {inputs.email}<br>" +
    "<b>Telefon:</b> {inputs.telefon}<br>" +
    "<b>Veranstaltungsort:</b> {inputs.ort}</p>" +
    "<p><b>Datum von:</b> {inputs.datum_von}<br>" +
    "<b>Datum bis:</b> {inputs.datum_bis}</p>" +
    "<p><b>Gew$($u)nschte Getr$($a)nke:</b> {inputs.getraenke}<br>" +
    "<b>Milch gew$($u)nscht:</b> {inputs.milch}</p>" +
    "<p><b>Gesch$($a)tzte Tassenanzahl:</b> {inputs.tassenanzahl}<br>" +
    "<b>Tassen/Becher ben$($o)tigt:</b> {inputs.tassen_benoetigt}</p>" +
    "<p><b>Nachricht:</b><br>{inputs.nachricht}</p>" +
    "<p>Verf$($u)gbarkeit pr$($u)fen und zur Best$($a)tigung melden.</p>"
  )
  enabled = $true
  conditionals = [pscustomobject]@{ status=$false; type='all'; conditions=@([pscustomobject]@{field='';operator='=';value=''}) }
}

$notifJson = $notif | ConvertTo-Json -Depth 10 -Compress
$body = @{ meta_key = 'notifications'; value = $notifJson }
$res = wp POST "/fluentform/v1/settings/$fid" $body
Write-Host ("Benachrichtigung angelegt: $($res.settings.name)")

# Kontrolle
$f = wp GET "/fluentform/v1/forms/$fid"
$f.form_meta | Where-Object { $_.meta_key -eq 'notifications' } | ForEach-Object {
  $v = $_.value | ConvertFrom-Json
  Write-Host ("  id=$($_.id)  name='$($v.name)'  an=$($v.sendTo.email)  enabled=$($v.enabled)")
}
