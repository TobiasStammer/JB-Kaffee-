$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wp-lib.ps1" | Out-Null
$url = 'https://le-cdn.website-editor.net/s/b2fc05ff53384b93b50c9852b3edd61a/dms3rep/multi/opt/Wallauerstra%C3%9Fe.+4+Langehain+%284+von+36%29-1920w.jpg?Expires=1790793403&Signature=EP8U1KPnFdyBU1yNCteiX3D8XE6qwuuYcGHTizoWUXezX6RmrypwgFKhPmOlk1mVEuGuv5xkVSlJSnvuHY5l9j6mqDVpN7yoUdneZaeScxQgzNmBm1UE8mLS0v~cGTQiRowIgrF7PFDprW4C3~4bQ9h2mkHGOAFXX3D-Yjqar~7xnMpGZRyZ~HAZCYm~e-pJkEPV2uyT83RymU1I8iUqmi7Sewh43XBBfefLBgLvFCBT8FtoORiEDImz8DHuJdfZBdTiEDdINF8vdR90fUG9jdVjJ-ENFKUe7QPut74BqbQ2PKHiRPOW6qqud-sYCMMV1HlO8rNf6Xd3QaFq7fW0QQ__&Key-Pair-Id=K2NXBXLF010TJW'
$name = 'kt-werkstatt-hero.jpg'
$tmp = Join-Path $env:TEMP $name
Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
$len = (Get-Item $tmp).Length
if ($len -lt 5000) { throw "zu klein ($len B)" }
$bytes = [IO.File]::ReadAllBytes($tmp)
$h = (Get-KtWpHeaders).Clone()
$h['Content-Disposition'] = "attachment; filename=$name"
$h['Content-Type'] = 'image/jpeg'
$base = (Import-KtEnv)['WP_URL'].TrimEnd('/')
$r = Invoke-RestMethod -Uri "$base/wp-json/wp/v2/media" -Method Post -Headers $h -Body $bytes
$null = Invoke-RestMethod -Uri "$base/wp-json/wp/v2/media/$($r.id)" -Method Post -Headers ((Get-KtWpHeaders) + @{'Content-Type'='application/json'}) -Body (@{ alt_text = 'Reparaturwerkstatt fuer Kaffeevollautomaten in Hofheim-Langenhain' } | ConvertTo-Json)
Write-Host ("{0}  ({1:N0} KB)" -f $r.source_url, ($len/1kb))
