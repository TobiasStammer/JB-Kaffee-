param([switch]$Off)
$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wp-lib.ps1" | Out-Null
$name = 'KT Host-Umleitung new -> www (Livetag)'
$code = [IO.File]::ReadAllText("$root\host-umleitung-snippet.php", [Text.Encoding]::UTF8)
$body = @{ name = $name; desc = '301 von new.kaffeetechniker.de auf www.kaffeetechniker.de. Erst am Livetag aktivieren. Quelle: host-umleitung-snippet.php im Repo'; code = $code; scope = 'global'; active = (-not $Off) }
$all = wp GET '/code-snippets/v1/snippets'
$rows = @($all); if ($rows.Count -eq 1 -and $rows[0].Count -gt 1) { $rows = @($rows[0]) }
$ex = $rows | Where-Object { $_.name -eq $name } | Select-Object -First 1
if ($ex) { $r = wp PUT "/code-snippets/v1/snippets/$($ex.id)" $body } else { $r = wp POST '/code-snippets/v1/snippets' $body }
Write-Host ("Snippet {0}: {1} active={2} code_error='{3}'" -f $r.id, $r.name, $r.active, $r.code_error)
