$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { Split-Path $PSScriptRoot -Parent } else { (Get-Location).Path }
. "$root\wp-lib.ps1" | Out-Null
$base = (Import-KtEnv)['WP_URL'].TrimEnd('/')
$src = Join-Path $PSScriptRoot 'tee-wissen-src\final'

$map = @(
  @{ f = 'kt-tee-sortierung.jpg'; alt = 'Sortierte schwarze Teeblaetter, Herkunft und Qualitaet' }
  @{ f = 'kt-tee-zeremonie.jpg';  alt = 'Ostfriesische Teezeremonie - Kanne, Tassen und Sahnekaennchen' }
  @{ f = 'kt-tee-tradition.jpg';  alt = 'Ostfriesische Teetradition - eine Tasse Tee am Hafen' }
)

$out = @()
foreach ($m in $map) {
  $p = Join-Path $src $m.f
  $bytes = [IO.File]::ReadAllBytes($p)
  $h = (Get-KtWpHeaders).Clone()
  $h['Content-Disposition'] = "attachment; filename=$($m.f)"
  $h['Content-Type'] = 'image/jpeg'
  $r = Invoke-RestMethod -Uri "$base/wp-json/wp/v2/media" -Method Post -Headers $h -Body $bytes
  $null = Invoke-RestMethod -Uri "$base/wp-json/wp/v2/media/$($r.id)" -Method Post -Headers ((Get-KtWpHeaders) + @{'Content-Type'='application/json'}) -Body (@{ alt_text = $m.alt } | ConvertTo-Json)
  Write-Host ("[ok] {0,-24} {1}  ({2:N0} KB)" -f $m.f, $r.source_url, ($bytes.Length/1kb))
  $out += [pscustomobject]@{ key = ($m.f -replace '^kt-tee-|\.jpg$',''); name = $m.f; url = $r.source_url; id = $r.id }
}
$out | ConvertTo-Json | Set-Content (Join-Path $PSScriptRoot 'tee-wissen-uploaded.json') -Encoding UTF8
Write-Host "`nFertig." -ForegroundColor Cyan
