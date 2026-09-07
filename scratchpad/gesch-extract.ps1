$dir = 'C:\Homepage\Neue Seite 2026\Bilder Geschichte'
$out = 'C:\Users\info\AppData\Local\Temp\claude\C--Homepage-Neue-Seite-2026\d6fde327-8546-442b-baa3-87d6a3b3766a\scratchpad\gesch'
if (-not (Test-Path $out)) { New-Item -ItemType Directory -Path $out | Out-Null }

Get-ChildItem $dir -Filter *.pdf | ForEach-Object {
  $bytes = [IO.File]::ReadAllBytes($_.FullName)
  $base = [IO.Path]::GetFileNameWithoutExtension($_.Name) -replace '[^A-Za-z0-9]+','_'
  $n = 0; $i = 0
  while ($i -lt $bytes.Length - 3) {
    if ($bytes[$i] -eq 0xFF -and $bytes[$i+1] -eq 0xD8 -and $bytes[$i+2] -eq 0xFF) {
      $j = $i + 2
      while ($j -lt $bytes.Length - 1) {
        if ($bytes[$j] -eq 0xFF -and $bytes[$j+1] -eq 0xD9) { break }
        $j++
      }
      if ($j -lt $bytes.Length - 1) {
        $len = $j + 2 - $i
        if ($len -gt 20000) {
          $n++
          $chunk = New-Object byte[] $len
          [Array]::Copy($bytes, $i, $chunk, 0, $len)
          $f = Join-Path $out ("{0}__{1:00}.jpg" -f $base, $n)
          [IO.File]::WriteAllBytes($f, $chunk)
          "  {0}  ({1:N0} KB)" -f $f, ($len/1kb)
        }
        $i = $j + 2; continue
      }
    }
    $i++
  }
  "[$($_.Name)] -> $n JPEG(s)"
}
