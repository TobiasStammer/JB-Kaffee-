# upload-laden.ps1 - laedt die Ladenfotos aus assets/laden/ in die WP-Mediathek
# und schreibt laden-media.json (name -> URL). Idempotent (Titel "kt-laden-<name>").
#   .\upload-laden.ps1
$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$root\wp-lib.ps1" | Out-Null
$dir = Join-Path $root 'assets\laden'
$alt = @{}
(Get-Content (Join-Path $dir 'alt.json') -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $alt[$_.Name] = $_.Value }
$map = [ordered]@{}
foreach ($f in (Get-ChildItem $dir -Filter *.jpg | Sort-Object Name)) {
  $slug = $f.BaseName; $title = "kt-laden-$slug"
  $existing = wp GET "/wp/v2/media?search=$title&_fields=id,title,source_url&per_page=5"
  $hit = @($existing) | Where-Object { $_.title.rendered -eq $title } | Select-Object -First 1
  if ($hit) { $map[$slug] = $hit.source_url; Write-Host "[vorhanden] $slug"; continue }
  $h = Get-KtWpHeaders
  $h['Content-Disposition'] = "attachment; filename=`"kt-laden-$($f.Name)`""
  $res = Invoke-RestMethod -Uri ((Get-KtWpBaseUrl) + '/wp/v2/media') -Method Post -Headers $h -ContentType 'image/jpeg' -InFile $f.FullName -ErrorAction Stop
  $altText = [string]$alt[$slug]
  wp POST "/wp/v2/media/$($res.id)" @{ title = $title; alt_text = $altText } | Out-Null
  $map[$slug] = $res.source_url
  Write-Host "[neu] $slug  $($res.source_url)"
}
($map | ConvertTo-Json) | Set-Content (Join-Path $root 'laden-media.json') -Encoding UTF8
Write-Host "$($map.Count) Bilder in laden-media.json" -ForegroundColor Cyan
