$p = 'C:\Users\info\Desktop\Anhang 1.pdf'
$b = [IO.File]::ReadAllBytes($p)
$t = [Text.Encoding]::GetEncoding(28591).GetString($b)
"Groesse: $($b.Length)"
$types = ([regex]::Matches($t, '/Subtype\s*/(\w+)') | ForEach-Object { $_.Groups[1].Value }) | Group-Object | Sort-Object Count -Descending
$types | ForEach-Object { "  Subtype $($_.Name): $($_.Count)" }
if ($t -match '/Producer\s*\(([^)]{0,90})') { "Producer: $($matches[1])" }
if ($t -match '/Creator\s*\(([^)]{0,90})')  { "Creator:  $($matches[1])" }
"Textbloecke (BT): " + ([regex]::Matches($t, '\bBT\b')).Count
"Images (Image): "  + ([regex]::Matches($t, '/Subtype\s*/Image')).Count
"OCR/Tj-Operatoren: " + ([regex]::Matches($t, '\)\s*Tj')).Count
