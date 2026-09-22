$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. "$root\wc-lib.ps1" | Out-Null

$origParentImages = @{
  444 = @(533,534,535,536,537,538)
  454 = @(563,564,565,566,567,568)
  456 = @(569,570,571,572,573,574)
  458 = @(575,576,577,578,579,580)
  460 = @(581,582,583,584,585,586)
  450 = @(551,552,553,554,555,556)
  464 = @(593,594,595,596,597,598)
}

$targets = @(
  @{ sku='15619'; parent=444; variation=806 }
  @{ sku='15749'; parent=454; variation=814 }
  @{ sku='15745'; parent=454; variation=816 }
  @{ sku='15747'; parent=454; variation=818 }
  @{ sku='15642'; parent=456; variation=822 }
  @{ sku='15433'; parent=458; variation=826 }
  @{ sku='15810'; parent=460; variation=830 }
  @{ sku='15482'; parent=450; variation=810 }
  @{ sku='15491'; parent=464; variation=834 }
)

$images = Get-Content "$root\jura-images.json" -Raw -Encoding UTF8 | ConvertFrom-Json

foreach ($t in $targets) {
  $urls = @($images.$($t.sku))
  if (-not $urls -or $urls.Count -eq 0) { Write-Host "[skip] $($t.sku): keine Bild-URLs" -ForegroundColor Yellow; continue }

  $origIds = $origParentImages[$t.parent]
  $newImgSpecs = $urls | ForEach-Object { @{ src = $_ } }
  $allSpecs = @($origIds | ForEach-Object { @{ id = $_ } }) + $newImgSpecs

  $res = wc PUT "products/$($t.parent)" @{ images = $allSpecs }
  $allNowIds = @($res.images | ForEach-Object { $_.id })
  $newIds = @($allNowIds | Where-Object { $origIds -notcontains $_ })

  if ($newIds.Count -eq 0) { Write-Host "[FEHLER] $($t.sku): keine neuen IDs erhalten" -ForegroundColor Red; continue }

  $vRes = wc PUT "products/$($t.parent)/variations/$($t.variation)" @{ image = @{ id = $newIds[0] }; gallery_image_ids = @($newIds | Select-Object -Skip 1) }

  # Elternprodukt sofort zuruecksetzen, bevor der naechste Durchlauf (ggf. gleicher Parent) startet
  $null = wc PUT "products/$($t.parent)" @{ images = ($origIds | ForEach-Object { @{ id = $_ } }) }

  Write-Host ("[ok] {0,-6} parent={1} var={2}  neue Bilder: {3}  ->  image={4} gallery={5}" -f $t.sku, $t.parent, $t.variation, $newIds.Count, $vRes.image.id, ($vRes.gallery_image_ids -join ','))
}
Write-Host "`nFertig." -ForegroundColor Cyan
