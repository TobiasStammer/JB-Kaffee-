$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
$sp   = 'C:\Users\info\AppData\Local\Temp\claude\C--Homepage-Neue-Seite-2026\5d0e8b70-2734-4f99-8508-5141a2537fa1\scratchpad'  # Geheimwerte, bewusst ausserhalb des Repos
. "$root\wp-lib.ps1" | Out-Null
# Geheimwerte (Slug, SHA-256 des Kennworts, Logo-URL) liegen nur lokal im Scratchpad, nicht im Repo
$slug = ((Get-Content "$sp\kt-ke-secret.txt")[0]).Trim()
$hash = (Get-Content "$sp\kt-ke-hash.txt").Trim()
$logo = (Get-Content "$sp\kt-ke-logo.txt").Trim()
$name = 'KT Intern: Kartenerfassung Paolos BOX'
$code = [IO.File]::ReadAllText("$root\kartenerfassung-snippet.php", [Text.Encoding]::UTF8)
$code = $code.Replace("'__SLUG__'", "'$slug'").Replace("'__HASH__'", "'$hash'").Replace("'__LOGO__'", "'$logo'")
$body = @{ name = $name; desc = 'Versteckte interne Seite: Vorname/Name/Kartennummer erfassen, Liste, CSV-Export (Quelle: kartenerfassung-snippet.php im Repo)'; code = $code; scope = 'global'; active = $true }
$all = wp GET '/code-snippets/v1/snippets'
$rows = @($all); if ($rows.Count -eq 1 -and $rows[0].Count -gt 1) { $rows = @($rows[0]) }
$ex = $rows | Where-Object { $_.name -eq $name } | Select-Object -First 1
if ($ex) { $r = wp PUT "/code-snippets/v1/snippets/$($ex.id)" $body } else { $r = wp POST '/code-snippets/v1/snippets' $body }
Write-Host ("Snippet {0}: {1} active={2} code_error='{3}'" -f $r.id, $r.name, $r.active, $r.code_error)
