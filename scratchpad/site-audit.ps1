$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. "$root\wp-lib.ps1" | Out-Null

# ASCII-safe Helfer fuer Mojibake-Muster (keine Literal-Umlaute im Skript, PS5.1-ANSI-Falle)
function CC([int[]]$codes) { -join ($codes | ForEach-Object { [char]$_ }) }
$moji = @(
  (CC 0xC3,0xA4), (CC 0xC3,0xB6), (CC 0xC3,0xBC),      # ae oe ue (klein)
  (CC 0xC3,0x84), (CC 0xC3,0x96), (CC 0xC3,0x9C),      # AE OE UE (gross)
  (CC 0xC3,0x9F),                                        # ss
  (CC 0xC3,0xA2), (CC 0xE2,0x82,0xAC)                   # generische Bruchstuecke
)

$pages = @()
$p = 1
do {
  $batch = wp GET "/wp/v2/pages?per_page=100&page=$p&status=publish&_fields=id,slug,link,title,content"
  $pages += $batch
  $p++
} while ($batch.Count -eq 100)

$knownSlugs = @($pages | ForEach-Object { $_.slug }) + @('shop','cart','checkout','my-account','product','product-category','')

$issues = New-Object System.Collections.Generic.List[object]

foreach ($pg in $pages) {
  $html = $pg.content.rendered
  $slug = $pg.slug

  foreach ($pat in @('\[TODO','Platzhalter','Lorem ipsum','TODO:','XXX-','undefined','NaN\b')) {
    if ($html -match $pat) {
      $m = [regex]::Match($html, ".{0,40}$pat.{0,40}")
      $issues.Add([pscustomobject]@{ slug=$slug; typ='Platzhalter-TODO'; detail="Muster $pat : ...$($m.Value)..." })
    }
  }

  if ($html -match '\[fluentform') {
    $issues.Add([pscustomobject]@{ slug=$slug; typ='Shortcode-nicht-gerendert'; detail='[fluentform als Text sichtbar' })
  }

  foreach ($pat in $moji) {
    $idx = 0
    while (($idx = $html.IndexOf($pat, $idx)) -ge 0) {
      $s = [Math]::Max(0,$idx-20)
      $len = [Math]::Min(60, $html.Length-$s)
      $issues.Add([pscustomobject]@{ slug=$slug; typ='Mojibake'; detail=$html.Substring($s,$len) })
      $idx += $pat.Length
    }
  }

  $hrefMatches = [regex]::Matches($html, 'href="([^"]*)"')
  foreach ($hm in $hrefMatches) {
    $href = $hm.Groups[1].Value
    if ($href -eq '' -or $href -eq '#') {
      $issues.Add([pscustomobject]@{ slug=$slug; typ='Leerer-Link'; detail="href=$href" })
    }
  }

  $internal = [regex]::Matches($html, 'href="(?:https://new\.kaffeetechniker\.de)?/([a-z0-9-]+)/?"')
  foreach ($im in $internal) {
    $target = $im.Groups[1].Value
    if ($target -and ($knownSlugs -notcontains $target) -and $target -ne 'wp-content' -and $target -notmatch '^\d+$') {
      $issues.Add([pscustomobject]@{ slug=$slug; typ='Interner-Link-unbekannt'; detail="/$target/" })
    }
  }

  $imgMatches = [regex]::Matches($html, '<img\b[^>]*>')
  foreach ($imm in $imgMatches) {
    $tag = $imm.Value
    if ($tag -notmatch 'alt="') {
      $issues.Add([pscustomobject]@{ slug=$slug; typ='img-ohne-alt'; detail=($tag.Substring(0,[Math]::Min(80,$tag.Length))) })
    }
    if ($tag -match 'src=""') {
      $issues.Add([pscustomobject]@{ slug=$slug; typ='img-leerer-src'; detail=($tag.Substring(0,[Math]::Min(80,$tag.Length))) })
    }
  }

  if ($html -match '&amp;amp;') {
    $issues.Add([pscustomobject]@{ slug=$slug; typ='Doppelt-escaped-Entity'; detail='amp;amp; gefunden' })
  }
}

Write-Host "Seiten geprueft: $($pages.Count)"
Write-Host "Gefundene Auffaelligkeiten: $($issues.Count)"
Write-Host ""
$issues | Group-Object typ | ForEach-Object { Write-Host ("{0,-30} {1,4}" -f $_.Name, $_.Count) }
Write-Host ""
$issues | Sort-Object slug,typ | Format-Table slug,typ,detail -AutoSize -Wrap | Out-String -Width 300 | Out-File "$env:TEMP\kt-audit-issues.txt" -Encoding utf8
Write-Host "Details in $env:TEMP\kt-audit-issues.txt"
