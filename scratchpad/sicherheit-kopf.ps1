$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wp-lib.ps1" | Out-Null
$brand = Get-Content 'C:\Users\info\AppData\Local\Temp\claude\C--Homepage-Neue-Seite-2026\42d494fc-f1fc-4de4-9612-1a5647f9ea02\scratchpad\brand-media.json' -Raw -Encoding UTF8 | ConvertFrom-Json
$name = 'KT Sicherheit + Kopf (Benutzerliste, Header, OG-Bild)'
$code = [IO.File]::ReadAllText("$root\sicherheit-kopf-snippet.php", [Text.Encoding]::UTF8)
$code = "define( 'KT_OG_IMAGE_ID', $($brand.og) );`n" + $code
$body = @{ name = $name; desc = 'Benutzerliste nicht oeffentlich, Sicherheits-Header, og:image (Quelle: sicherheit-kopf-snippet.php im Repo)'; code = $code; scope = 'global'; active = $true }
$all = wp GET '/code-snippets/v1/snippets'
$rows = @($all); if ($rows.Count -eq 1 -and $rows[0].Count -gt 1) { $rows = @($rows[0]) }
$ex = $rows | Where-Object { $_.name -eq $name } | Select-Object -First 1
if ($ex) { $r = wp PUT "/code-snippets/v1/snippets/$($ex.id)" $body } else { $r = wp POST '/code-snippets/v1/snippets' $body }
Write-Host ("Snippet {0}: {1} active={2} scope={3} code_error='{4}'" -f $r.id, $r.name, $r.active, $r.scope, $r.code_error)

