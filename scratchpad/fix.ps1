$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wp-lib.ps1" | Out-Null

# 1) Attachment 209 belegt den Slug "nivona" -> umbenennen, damit die Seite ihn bekommt
$m = wp POST '/wp/v2/media/209' @{ slug = 'kt-brand-nivona' }
Write-Host ("media 209 slug -> {0}" -f $m.slug)

# 2) Markenseite auf Slug "nivona" + veroeffentlichen
$p = wp POST '/wp/v2/pages/1073' @{ slug = 'nivona'; status = 'publish' }
Write-Host ("page 1073 slug={0} status={1} link={2}" -f $p.slug,$p.status,$p.link)

# 3) Kategorieseite veroeffentlichen
$p2 = wp POST '/wp/v2/pages/1074' @{ status = 'publish' }
Write-Host ("page 1074 slug={0} status={1} link={2}" -f $p2.slug,$p2.status,$p2.link)
