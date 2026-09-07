# Versucht, Textstroeme aus dem PDF zu extrahieren (FlateDecode -> Deflate).
$p = 'C:\Users\info\Desktop\Anhang 1.pdf'
$bytes = [IO.File]::ReadAllBytes($p)
$lat = [Text.Encoding]::GetEncoding(28591)
$s = $lat.GetString($bytes)

$out = New-Object System.Text.StringBuilder
$rx = [regex]'stream\r?\n'
$pos = 0
$count = 0
foreach ($m in $rx.Matches($s)) {
  $start = $m.Index + $m.Length
  $end = $s.IndexOf('endstream', $start)
  if ($end -lt 0) { continue }
  $len = $end - $start
  if ($len -lt 4 -or $len -gt 4000000) { continue }
  $chunk = New-Object byte[] $len
  [Array]::Copy($bytes, $start, $chunk, 0, $len)
  # zlib-Header (0x78) ueberspringen
  try {
    $ms = New-Object System.IO.MemoryStream(,$chunk)
    if ($chunk.Length -gt 2 -and $chunk[0] -eq 0x78) { $ms.Position = 2 }
    $ds = New-Object System.IO.Compression.DeflateStream($ms, [System.IO.Compression.CompressionMode]::Decompress)
    $sr = New-Object System.IO.StreamReader($ds, $lat)
    $dec = $sr.ReadToEnd()
    $sr.Close()
    # Text aus PDF-Content-Operatoren ( Tj / TJ ) ziehen
    $texts = [regex]::Matches($dec, '\(((?:[^()\\]|\\.)*)\)\s*T[jJ]')
    foreach ($t in $texts) {
      $val = $t.Groups[1].Value -replace '\\([()\\])','$1' -replace '\\n',' ' -replace '\\r',' '
      if ($val.Trim().Length -gt 0) { [void]$out.Append($val); [void]$out.Append(' ') }
    }
    # TJ-Arrays
    $arrs = [regex]::Matches($dec, '\[((?:[^\[\]])*)\]\s*TJ')
    foreach ($a in $arrs) {
      $inner = [regex]::Matches($a.Groups[1].Value, '\(((?:[^()\\]|\\.)*)\)')
      foreach ($iv in $inner) { $v = $iv.Groups[1].Value -replace '\\([()\\])','$1'; [void]$out.Append($v) }
      [void]$out.Append(' ')
    }
    $count++
  } catch {}
}
"Streams verarbeitet: $count"
"---- extrahierter Text ----"
$res = $out.ToString()
$res | Set-Content 'C:\Homepage\Neue Seite 2026\scratchpad\anhang1.txt' -Encoding UTF8
"Laenge: $($res.Length) Zeichen -> scratchpad/anhang1.txt"
$res.Substring(0, [Math]::Min(1500, $res.Length))
