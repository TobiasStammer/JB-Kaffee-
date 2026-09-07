$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wp-lib.ps1" | Out-Null
Add-Type -AssemblyName System.Drawing
$src = 'C:\Users\info\AppData\Local\Temp\claude\C--Homepage-Neue-Seite-2026\d6fde327-8546-442b-baa3-87d6a3b3766a\scratchpad\tee-render'
$base = (Import-KtEnv)['WP_URL'].TrimEnd('/')

# Quelldatei -> Ziel-Slug (WP-Medienname) + Alt
$map = @(
  @{ f='beerenzauber-150g.png';  name='kt-tee-beerenzauber.jpg';  alt='JB Unser Tee Beerenzauber - Fruechtetee, 150 g' }
  @{ f='bl-tenzeit-150g.png';    name='kt-tee-bluetenzeit.jpg';   alt='JB Unser Tee Bluetenzeit - Gruener Tee, 150 g' }
  @{ f='earl-grey-150g.png';     name='kt-tee-earl-grey.jpg';     alt='JB Unser Tee Earl Grey - Schwarzer Tee, 150 g' }
  @{ f='erdbeer-sahne-150g.png'; name='kt-tee-erdbeer-sahne.jpg'; alt='JB Unser Tee Erdbeer-Sahne - Rooibos-Tee, 150 g' }
  @{ f='frische-kraft-100g.png'; name='kt-tee-frische-kraft.jpg'; alt='JB Unser Tee Frische Kraft - Kraeutertee, 100 g' }
  @{ f='rote-liebe-150g.png';    name='kt-tee-rote-liebe.jpg';    alt='JB Unser Tee Rote Liebe - Fruechtetee, 150 g' }
)

$cropBottom = 1165   # nur Kopf + Name + Beschreibung + Teefoto behalten
$targetW = 620
$enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ep = New-Object System.Drawing.Imaging.EncoderParameters 1
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]86)

$out = @()
foreach ($m in $map) {
  $p = Join-Path $src $m.f
  $img = [System.Drawing.Image]::FromFile($p)
  $cropH = [Math]::Min($cropBottom, $img.Height)
  $ratio = $targetW / $img.Width
  $destH = [int]($cropH * $ratio)
  $bmp = New-Object System.Drawing.Bitmap $targetW, $destH
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $srcRect = New-Object System.Drawing.Rectangle 0, 0, $img.Width, $cropH
  $dstRect = New-Object System.Drawing.Rectangle 0, 0, $targetW, $destH
  $g.DrawImage($img, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose(); $img.Dispose()
  $tmp = Join-Path $env:TEMP $m.name
  $bmp.Save($tmp, $enc, $ep); $bmp.Dispose()
  $bytes = [IO.File]::ReadAllBytes($tmp)
  $h = (Get-KtWpHeaders).Clone()
  $h['Content-Disposition'] = "attachment; filename=$($m.name)"
  $h['Content-Type'] = 'image/jpeg'
  $r = Invoke-RestMethod -Uri "$base/wp-json/wp/v2/media" -Method Post -Headers $h -Body $bytes
  $null = Invoke-RestMethod -Uri "$base/wp-json/wp/v2/media/$($r.id)" -Method Post -Headers ((Get-KtWpHeaders) + @{'Content-Type'='application/json'}) -Body (@{ alt_text = $m.alt } | ConvertTo-Json)
  Write-Host ("[ok] {0,-26} {1}  ({2:N0} KB, {3}x{4})" -f $m.name, $r.source_url, ($bytes.Length/1kb), $targetW, $destH)
  $out += [pscustomobject]@{ key = ($m.name -replace '^kt-tee-|\.jpg$',''); name = $m.name; url = $r.source_url; id = $r.id }
}
$out | ConvertTo-Json | Set-Content "$root\scratchpad\tee-images-uploaded.json" -Encoding UTF8
