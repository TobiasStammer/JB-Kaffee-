$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wp-lib.ps1" | Out-Null

$u = [char]0x00FC  # ue
$msg = "Vielen Dank f${u}r Ihre Nachricht. Wir haben Ihre Anfrage erhalten und melden uns zeitnah bei Ihnen zur${u}ck."

$resp = wp GET '/fluentform/v1/settings/1?meta_key=formSettings'
$rows = @($resp)
if ($rows.Count -eq 1 -and $rows[0].Count -gt 1) { $rows = @($rows[0]) }  # PS5.1 collapse-Schutz
Write-Host ("formSettings-Zeilen: {0} -> ids {1}" -f $rows.Count, (($rows | ForEach-Object { $_.id }) -join ','))

$main = $rows | Where-Object { $_.id -eq 2 } | Select-Object -First 1
if (-not $main) { throw "meta_id 2 (formSettings) nicht gefunden" }

$v = $main.value
$v.confirmation.messageToShow = $msg
$v.confirmation.redirectTo = 'samePage'
$v.confirmation.samePageFormBehavior = 'hide_form'

$body = @{ form_id = 1; meta_key = 'formSettings'; meta_id = 2; value = ($v | ConvertTo-Json -Depth 15 -Compress) }
$res = wp POST '/fluentform/v1/settings/1' $body
Write-Host ("update id 2: {0}" -f $res.message)

foreach ($r in $rows) {
  if ($r.id -ne 2) {
    try {
      $d = wp DELETE '/fluentform/v1/settings/1' @{ form_id = 1; meta_key = 'formSettings'; meta_id = $r.id }
      Write-Host ("geloescht id {0}: {1}" -f $r.id, $d.message)
    } catch { Write-Host ("delete id {0} fehlgeschlagen: {1}" -f $r.id, $_.Exception.Message) }
  }
}

Start-Sleep -Seconds 1
$after = @(wp GET '/fluentform/v1/settings/1?meta_key=formSettings')
if ($after.Count -eq 1 -and $after[0].Count -gt 1) { $after = @($after[0]) }
Write-Host ("nachher: {0} Zeile(n)" -f $after.Count)
$after | ForEach-Object { Write-Host ("  id={0}  msg='{1}'" -f $_.id, $_.value.confirmation.messageToShow) }
