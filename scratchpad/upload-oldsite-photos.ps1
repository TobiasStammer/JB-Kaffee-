$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wp-lib.ps1" | Out-Null
$list = Get-Content "$root\scratchpad\oldsite-photos.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$base = (Import-KtEnv)['WP_URL'].TrimEnd('/')
$headers = Get-KtWpHeaders
$results = @()
foreach ($i in $list) {
  $tmp = Join-Path $env:TEMP $i.name
  try {
    Invoke-WebRequest -Uri $i.url -OutFile $tmp -UseBasicParsing -ErrorAction Stop
  } catch {
    Write-Host ("[DL FEHLER] {0}: {1}" -f $i.name, $_.Exception.Message.Split("`n")[0]) -ForegroundColor Red
    continue
  }
  $len = (Get-Item $tmp).Length
  if ($len -lt 3000) { Write-Host ("[zu klein] {0} ({1} B) - vermutlich Fehlerseite" -f $i.name, $len) -ForegroundColor Yellow; continue }
  $bytes = [IO.File]::ReadAllBytes($tmp)
  $ext = [IO.Path]::GetExtension($i.name).ToLower()
  $mime = if ($ext -eq '.png') { 'image/png' } else { 'image/jpeg' }
  $h = $headers.Clone()
  $h['Content-Disposition'] = "attachment; filename=$($i.name)"
  $h['Content-Type'] = $mime
  $r = Invoke-RestMethod -Uri "$base/wp-json/wp/v2/media" -Method Post -Headers $h -Body $bytes
  if ($i.alt) { $null = Invoke-RestMethod -Uri "$base/wp-json/wp/v2/media/$($r.id)" -Method Post -Headers ($headers + @{'Content-Type'='application/json'}) -Body (@{ alt_text = $i.alt } | ConvertTo-Json) }
  Write-Host ("[ok] {0,-28} {1}  ({2:N0} KB)" -f $i.name, $r.source_url, ($len/1kb))
  $results += [pscustomobject]@{ name = $i.name; url = $r.source_url; id = $r.id }
}
$results | ConvertTo-Json | Set-Content "$root\scratchpad\oldsite-photos-uploaded.json" -Encoding UTF8
