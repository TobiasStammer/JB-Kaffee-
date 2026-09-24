. "C:\Homepage\Neue Seite 2026\wp-lib.ps1" | Out-Null
$p = wp GET "/wp/v2/pages?slug=wartungserinnerung&context=edit&_fields=id,modified,content"
$c = $p[0].content.raw
"modified $($p[0].modified); pp-plz: $(([regex]::Matches($c,'pp-plz')).Count); api: $(([regex]::Matches($c,'haerte.de/api')).Count); link: $(([regex]::Matches($c,'/wasserhaerte/')).Count)"
