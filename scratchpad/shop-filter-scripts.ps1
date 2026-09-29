$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wp-lib.ps1" | Out-Null
$name = 'KT Shop-Filter-Skripte (jk2grid, shnav)'
$code = [IO.File]::ReadAllText("$root\shop-filter-scripts-snippet.php", [Text.Encoding]::UTF8)
$body = @{ name = $name; desc = 'jk2grid Serienfilter/Vergleich + Produktseiten-Skripte ueber wp_footer statt im Content (the_content-Filter bricht sonst <script>-Bloecke). Quelle: shop-filter-scripts-snippet.php'; code = $code; scope = 'front-end'; active = $true }
$all = wp GET '/code-snippets/v1/snippets'
$rows = @($all); if ($rows.Count -eq 1 -and $rows[0].Count -gt 1) { $rows = @($rows[0]) }
$ex = $rows | Where-Object { $_.name -eq $name } | Select-Object -First 1
if ($ex) { $r = wp PUT "/code-snippets/v1/snippets/$($ex.id)" $body } else { $r = wp POST '/code-snippets/v1/snippets' $body }
Write-Host ("Snippet {0}: {1} active={2} scope={3} code_error='{4}'" -f $r.id, $r.name, $r.active, $r.scope, $r.code_error)
