$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wp-lib.ps1" | Out-Null
$name = 'KT Bestelluebersicht drucken (Knopf)'
$code = [IO.File]::ReadAllText("$root\bestelluebersicht-button-snippet.php", [Text.Encoding]::UTF8)
$body = @{ name = $name; desc = 'Knopf "Bestelluebersicht drucken" in Bestellung + Bestellliste (Quelle: bestelluebersicht-button-snippet.php im Repo)'; code = $code; scope = 'global'; active = $true }
$all = wp GET '/code-snippets/v1/snippets'
$rows = @($all); if ($rows.Count -eq 1 -and $rows[0].Count -gt 1) { $rows = @($rows[0]) }
$ex = $rows | Where-Object { $_.name -eq $name } | Select-Object -First 1
if ($ex) { $r = wp PUT "/code-snippets/v1/snippets/$($ex.id)" $body } else { $r = wp POST '/code-snippets/v1/snippets' $body }
Write-Host ("Snippet {0}: {1} active={2} scope={3} code_error='{4}'" -f $r.id, $r.name, $r.active, $r.scope, $r.code_error)
