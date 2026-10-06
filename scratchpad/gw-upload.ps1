$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wp-lib.ps1" | Out-Null
$h = Get-KtWpHeaders
$h['Content-Disposition'] = 'attachment; filename="eu-gewaehrleistungshinweis-de.png"'
$bytes = [IO.File]::ReadAllBytes("$root\Gewaehrleistungslabel\Gewaehrleistungshinweis-DE-original.png")
$r = Invoke-RestMethod -Uri ((Get-KtWpBaseUrl) + '/wp/v2/media') -Method POST -Headers $h -Body $bytes -ContentType 'image/png'
Write-Host "Media $($r.id) $($r.source_url)"
wp POST "/wp/v2/media/$($r.id)" @{ alt_text = 'Gesetzliche Gewährleistung: Mindestens zwei Jahre gesetzliche Gewährleistung der Vertragsmäßigkeit für Waren, die in der Europäischen Union verkauft werden. Hinweis der EU-Kommission.'; title = 'EU-Hinweis Gesetzliche Gewährleistung (Original)' } | Out-Null
"{`"png`": $($r.id)}" | Set-Content "$root\Gewaehrleistungslabel\media-ids.json" -Encoding utf8
