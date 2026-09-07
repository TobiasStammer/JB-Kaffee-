$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wp-lib.ps1" | Out-Null

$imgs = @(
  @{ url = 'https://nivona.com/assets/Kaffeevollautomaten-UB2vnOZl.jpg'; name = 'kt-nivona-cat-kaffeevollautomaten.jpg' }
  @{ url = 'https://nivona.com/assets/Reinigung-Cv3IUx9j.jpg';            name = 'kt-nivona-cat-pflege.jpg' }
)
$base = (Import-KtEnv)['WP_URL'].TrimEnd('/')
$headers = Get-KtWpHeaders

foreach ($i in $imgs) {
  $tmp = Join-Path $env:TEMP $i.name
  Invoke-WebRequest -Uri $i.url -OutFile $tmp -UseBasicParsing
  $bytes = [IO.File]::ReadAllBytes($tmp)
  $h = $headers.Clone()
  $h['Content-Disposition'] = "attachment; filename=$($i.name)"
  $h['Content-Type'] = 'image/jpeg'
  $r = Invoke-RestMethod -Uri "$base/wp-json/wp/v2/media" -Method Post -Headers $h -Body $bytes
  Write-Host ("{0} -> {1}" -f $i.name, $r.source_url)
}
