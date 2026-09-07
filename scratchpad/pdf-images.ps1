# Zieht eingebettete JPEG-Bilder (DCTDecode) aus dem PDF.
$p = 'C:\Users\info\Desktop\Anhang 1.pdf'
$bytes = [IO.File]::ReadAllBytes($p)
$lat = [Text.Encoding]::GetEncoding(28591)
$s = $lat.GetString($bytes)
$dir = 'C:\Users\info\AppData\Local\Temp\claude\C--Homepage-Neue-Seite-2026\d6fde327-8546-442b-baa3-87d6a3b3766a\scratchpad\anhang1'
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }

# JPEG-Signatur FF D8 ... FF D9 im gesamten Byte-Array suchen
$n = 0
$i = 0
while ($i -lt $bytes.Length - 3) {
  if ($bytes[$i] -eq 0xFF -and $bytes[$i+1] -eq 0xD8 -and $bytes[$i+2] -eq 0xFF) {
    # Ende suchen
    $j = $i + 2
    while ($j -lt $bytes.Length - 1) {
      if ($bytes[$j] -eq 0xFF -and $bytes[$j+1] -eq 0xD9) { break }
      $j++
    }
    if ($j -lt $bytes.Length - 1) {
      $len = $j + 2 - $i
      if ($len -gt 8000) {
        $n++
        $chunk = New-Object byte[] $len
        [Array]::Copy($bytes, $i, $chunk, 0, $len)
        $f = Join-Path $dir ("p{0:00}.jpg" -f $n)
        [IO.File]::WriteAllBytes($f, $chunk)
        "  $f  ({0:N0} KB)" -f ($len/1kb)
      }
      $i = $j + 2
      continue
    }
  }
  $i++
}
"JPEGs extrahiert: $n  -> $dir"
