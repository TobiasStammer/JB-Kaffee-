$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null
$desc = '<p><strong>Tipp:</strong> Alle Modelle mit Serien-Filter, Farbwahl und Steckbrief finden Sie auf unserer <a href="/jura-kaffeevollautomaten/">ausf&uuml;hrlichen &Uuml;bersichtsseite</a>.</p>'
$body = @{ description = $desc }
$r = wc PUT 'products/categories/19' $body
$r | Select-Object id,name,description
