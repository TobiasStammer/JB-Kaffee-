$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wp-lib.ps1" | Out-Null

# aktuelle Notification(s) holen
$cur = wp GET '/fluentform/v1/settings/1?meta_key=notifications'
$list = @($cur)
Write-Host ("Vorher: {0} Notification(s)" -f $list.Count)
$list | ForEach-Object { Write-Host ("  meta_id={0} name='{1}' fromEmail='{2}'" -f $_.id, $_.value.name, $_.value.fromEmail) }

$target = $list | Where-Object { $_.id -eq 15 } | Select-Object -First 1
if (-not $target) { throw "meta_id 15 nicht gefunden" }

$v = $target.value
$v.fromName  = 'JB Kaffeemaschinen ' + [char]0x2013 + ' Service & Verkauf'
$v.fromEmail = 'info@kaffeetechniker.de'

$body = @{
  form_id  = 1
  meta_key = 'notifications'
  meta_id  = 15
  value    = ($v | ConvertTo-Json -Depth 12 -Compress)
}
$res = wp POST '/fluentform/v1/settings/1' $body
Write-Host "POST-Antwort:"
$res | ConvertTo-Json -Depth 6

Start-Sleep -Seconds 1
$after = @(wp GET '/fluentform/v1/settings/1?meta_key=notifications')
Write-Host ("Nachher: {0} Notification(s)" -f $after.Count)
$after | ForEach-Object { Write-Host ("  meta_id={0} name='{1}' fromName='{2}' fromEmail='{3}'" -f $_.id, $_.value.name, $_.value.fromName, $_.value.fromEmail) }
