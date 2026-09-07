$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wp-lib.ps1" | Out-Null
Add-Type -AssemblyName System.Drawing
$src = 'C:\Users\info\AppData\Local\Temp\claude\C--Homepage-Neue-Seite-2026\d6fde327-8546-442b-baa3-87d6a3b3766a\scratchpad\gesch'
$base = (Import-KtEnv)['WP_URL'].TrimEnd('/')

$items = @(
  @{ file='Stadthausstra_e_4___01.jpg';               name='kt-gesch-rasierer-stadthausstr.jpg'; rot=$null;  alt='Elektro-Rasierer-Spezialgeschaeft Bloechle in der Mainzer Stadthausstrasse' }
  @{ file='Anhang_4__01.jpg';                          name='kt-gesch-beratung-1960er.jpg';       rot=$null;  alt='Beratung im Elektro-Rasierer-Fachgeschaeft in den 1960er-Jahren' }
  @{ file='1961__01.jpg';                              name='kt-gesch-mainz-1961.jpg';            rot=$null;  alt='Mainzer Innenstadt im Wiederaufbau um 1961' }
  @{ file='25_Jahre__01.jpg';                          name='kt-gesch-anzeige-1986.jpg';          rot=$null;  alt='Zeitungsanzeige zu den Jubilaeumswochen im Oktober 1986' }
  @{ file='Stadthausstra_e_4_1964__01.jpg';            name='kt-gesch-schaufenster-1964.jpg';     rot='Rotate270FlipNone'; alt='Schaufensterauslage des Rasierer-Fachgeschaefts, 1964' }
  @{ file='Philip_von_Zabern_Platz_5_1998__01.jpg';    name='kt-gesch-laden-mainz-nr20.jpg';      rot=$null;  alt='Eckladen JB Elektro-Rasierer-Spezialgeschaeft in Mainz' }
  @{ file='Anhang_7__01.jpg';                          name='kt-gesch-ladenumbau.jpg';           rot=$null;  alt='Neugestaltung der Ladenfront des Elektro-Rasierer-Spezialgeschaefts' }
)

$maxW = 1200
$out = @()
foreach ($it in $items) {
  $p = Join-Path $src $it.file
  if (-not (Test-Path $p)) { Write-Host "[fehlt] $($it.file)" -ForegroundColor Yellow; continue }
  $img = [System.Drawing.Image]::FromFile($p)
  if ($it.rot) { $img.RotateFlip([System.Drawing.RotateFlipType]::($it.rot)) }
  $w = $img.Width; $h = $img.Height
  if ($w -gt $maxW) { $nh = [int]($h * $maxW / $w); $nw = $maxW } else { $nw = $w; $nh = $h }
  $bmp = New-Object System.Drawing.Bitmap $nw, $nh
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.DrawImage($img, 0, 0, $nw, $nh)
  $g.Dispose(); $img.Dispose()
  $tmp = Join-Path $env:TEMP $it.name
  $enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
  $ep = New-Object System.Drawing.Imaging.EncoderParameters 1
  $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]82)
  $bmp.Save($tmp, $enc, $ep); $bmp.Dispose()
  $len = (Get-Item $tmp).Length
  $bytes = [IO.File]::ReadAllBytes($tmp)
  $hd = (Get-KtWpHeaders).Clone()
  $hd['Content-Disposition'] = "attachment; filename=$($it.name)"
  $hd['Content-Type'] = 'image/jpeg'
  $r = Invoke-RestMethod -Uri "$base/wp-json/wp/v2/media" -Method Post -Headers $hd -Body $bytes
  $null = Invoke-RestMethod -Uri "$base/wp-json/wp/v2/media/$($r.id)" -Method Post -Headers ((Get-KtWpHeaders) + @{'Content-Type'='application/json'}) -Body (@{ alt_text = $it.alt } | ConvertTo-Json)
  Write-Host ("[ok] {0,-34} {1}  ({2:N0} KB, {3}x{4})" -f $it.name, $r.source_url, ($len/1kb), $nw, $nh)
  $out += [pscustomobject]@{ name=$it.name; url=$r.source_url; id=$r.id }
}
$out | ConvertTo-Json | Set-Content "$root\scratchpad\gesch2-uploaded.json" -Encoding UTF8
