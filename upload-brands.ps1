# upload-brands.ps1 - laedt Hersteller-Logos aus assets/brands/ in die WP-Mediathek
# und schreibt brands-media.json (slug -> URL). Idempotent: vorhandene Medien
# (Titel "kt-brand-<slug>") werden wiederverwendet statt doppelt hochgeladen.
#
#   .\upload-brands.ps1
$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$root\wp-lib.ps1" | Out-Null

$dir = Join-Path $root 'assets\brands'
if (-not (Test-Path $dir)) { throw "Ordner fehlt: $dir" }

$mime = @{ '.png'='image/png'; '.jpg'='image/jpeg'; '.jpeg'='image/jpeg'; '.svg'='image/svg+xml'; '.webp'='image/webp'; '.gif'='image/gif' }
$map = @{}
$mapFile = Join-Path $root 'brands-media.json'
if (Test-Path $mapFile) {
  (Get-Content $mapFile -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $map[$_.Name] = $_.Value }
}

$files = Get-ChildItem $dir -File | Where-Object { $mime.ContainsKey($_.Extension.ToLower()) }
foreach ($f in $files) {
  $slug  = $f.BaseName.ToLower()
  $title = "kt-brand-$slug"

  $existing = wp GET "/wp/v2/media?search=$title&_fields=id,title,source_url&per_page=5"
  $hit = @($existing) | Where-Object { $_.title.rendered -eq $title } | Select-Object -First 1
  if ($hit) {
    $map[$slug] = $hit.source_url
    Write-Host ("[vorhanden] {0,-14} {1}" -f $slug, $hit.source_url)
    continue
  }

  $h = Get-KtWpHeaders
  $h['Content-Disposition'] = "attachment; filename=`"$($f.Name)`""
  $uri = (Get-KtWpBaseUrl) + '/wp/v2/media'
  $res = Invoke-RestMethod -Uri $uri -Method Post -Headers $h -ContentType $mime[$f.Extension.ToLower()] -InFile $f.FullName -ErrorAction Stop
  wp POST "/wp/v2/media/$($res.id)" @{ title = $title; alt_text = "$($f.BaseName) Logo" } | Out-Null
  $map[$slug] = $res.source_url
  Write-Host ("[neu]       {0,-14} ID {1}  {2}" -f $slug, $res.id, $res.source_url)
}

($map | ConvertTo-Json) | Set-Content $mapFile -Encoding UTF8
Write-Host "`n$($map.Count) Logos in brands-media.json. Jetzt: .\build-pages.ps1" -ForegroundColor Cyan
