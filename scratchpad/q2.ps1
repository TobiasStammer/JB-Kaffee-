. "C:\Homepage\Neue Seite 2026\wp-lib.ps1" | Out-Null
$e = wp GET "/wp/v2/pages?slug=wasserhaerte&status=publish,draft&_fields=id,status,link"
$e | ConvertTo-Json
$r = wp POST "/wp/v2/pages/$(@($e)[0].id)" @{ status = 'publish' }
"$($r.status) $($r.link)"
