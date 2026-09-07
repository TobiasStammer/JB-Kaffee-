# upload-shop-media.ps1 - laedt die Kategorie-Kachelbilder (JURA) in die WP-Mediathek
# und schreibt shop-media.json (key -> URL). Idempotent per Dateiname/Titel.
$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$root\wp-lib.ps1" | Out-Null
$base = (Get-KtWpBaseUrl)
$hdr  = Get-KtWpHeaders

$imgs = @{
  'cat-kaffeevollautomaten' = 'https://api.jura.com/media/global/images/home-products/navigation-menue-overview-hh/nav_menue_overview_machines_hh.jpg'
  'cat-professional'        = 'https://api.jura.com/media/global/images/professional-products/giga-professional-line/giga-x8-gen2/AluBlack/overview_gigax8_g2_aluminium_black.png'
  'cat-zubehoer'            = 'https://api.jura.com/media/global/images/home-products/navigation-menue-overview-hh/nav_menue_overview_accessories_hh.jpg'
  'cat-pflegeprodukte'      = 'https://api.jura.com/media/global/images/home-products/navigation-menue-overview-hh/nav_menue_overview_maintenance_hh.jpg'
  'jura-logo'               = 'https://de.jura.com/images/logo.png'
}

$out = [ordered]@{}
foreach ($k in $imgs.Keys) {
  $title = "kt-shop-$k"
  # vorhanden?
  $ex = Invoke-RestMethod -Uri "$base/wp/v2/media?search=$title&per_page=1&_fields=id,source_url,title" -Headers $hdr
  if ($ex -and @($ex)[0].title.rendered -eq $title) {
    $out[$k] = @($ex)[0].source_url
    Write-Host "[vorhanden] $title -> $($out[$k])"
    continue
  }
  $src = $imgs[$k]
  $ext = [IO.Path]::GetExtension(($src -split '\?')[0])
  $tmp = Join-Path $env:TEMP "$title$ext"
  Invoke-WebRequest -Uri $src -UseBasicParsing -OutFile $tmp
  $bytes = [IO.File]::ReadAllBytes($tmp)
  $mime = if ($ext -eq '.png') { 'image/png' } else { 'image/jpeg' }
  $up = Invoke-RestMethod -Uri "$base/wp/v2/media" -Method Post -Headers ($hdr + @{
      'Content-Disposition' = "attachment; filename=$title$ext"
      'Content-Type'        = $mime
    }) -Body $bytes
  $null = Invoke-RestMethod -Uri "$base/wp/v2/media/$($up.id)" -Method Post -Headers $hdr -Body (@{ title = $title; alt_text = $title } | ConvertTo-Json) -ContentType 'application/json'
  $out[$k] = $up.source_url
  Remove-Item $tmp -Force
  Write-Host "[neu] $title -> $($up.source_url)"
}

$out | ConvertTo-Json | Set-Content "$root\shop-media.json" -Encoding UTF8
Write-Host "`ngeschrieben: shop-media.json" -ForegroundColor Cyan
