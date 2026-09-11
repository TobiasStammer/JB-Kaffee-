# build-pages.ps1 - Baut die 10 Seiten im Design "Klassisch" (DESIGN-KLASSISCH-UMSETZUNG.md)
# Aktualisierte Fassung: Anthrazit statt Schwarz, nur 3 Farbzonen von oben nach unten
#   Anthrazit (Kopf)  ->  Hell #eeeeee (durchgehend, Hero..Vorteile)  ->  Anthrazit (CTA+Footer verschmolzen)
# Inhalte/Texte: pages-content.json (UTF-8). Alle Seiten bleiben STATUS = draft.
# Idempotent: vorhandene Seiten werden per Slug aktualisiert.
#
#   .\build-pages.ps1

$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$root\wp-lib.ps1" | Out-Null
. "$root\wc-lib.ps1" | Out-Null   # WooCommerce-API fuer die JURA-Shop-Seiten

# ---------- Farb- / Schrift-Tokens ----------
$C = @{
  bg      = '#f5f5f5'   # heller Sektionshintergrund (innerhalb des Blatts)
  pagebg  = '#e3e5ea'   # Seitenhintergrund AUSSERHALB des Blatts (kuehles Grau)
  white   = '#ffffff'   # helle Sektion
  soft    = '#f0efec'   # abwechselndes Sektionsband (leicht waermer als bg)
  text    = '#1c1c1c'
  head    = '#2b2b2b'
  dark1   = '#4a4a4a'   # Menueband
  dark2   = '#4a4a4a'   # CTA + Footer (gleiches Dunkelgrau wie das Menueband)
  onDark  = '#ffffff'
  onDark2 = '#c9c9c9'
  line    = '#d8d8d8'
  accent  = '#334155'   # Schiefer/Graphit-Akzent (Eyebrows, Links, Primaer-Button)
  accentD = '#1e293b'   # Akzent dunkler (Hover)
  btnBg   = '#334155'
  btnTx   = '#ffffff'
}
$FONT_HEAD = "Tahoma, 'Tahoma Fallback', Arial, sans-serif"
$FONT_BODY = "'Source Sans 3', 'Source Sans Pro', system-ui, sans-serif"
$MAXW      = '1200px'
$SECW      = '980px'   # einheitliche Inhaltsbreite der Startseiten-Abschnitte

# Text -> Anker-Slug (deutsche Umlaute, Satzzeichen raus)
function Slugify($t) {
  $s = ($t -replace '&[a-z]+;', ' ').ToLower()
  $s = $s.Replace('ä','ae').Replace('ö','oe').Replace('ü','ue').Replace('ß','ss')
  $s = ($s -replace '[^a-z0-9]+','-').Trim('-')
  if ($s.Length -gt 40) { $s = $s.Substring(0,40).Trim('-') }
  $s
}

# TOC (h2-Liste) aus den Bloecken einer Unterseite
function Toc-From-Blocks($blocks) {
  foreach ($b in $blocks) {
    if ($b.t -eq 'h' -and [int]$b.lvl -eq 2) {
      $id = if ($b.id) { $b.id } else { Slugify $b.x }
      [pscustomobject]@{ id = $id; text = $b.x }
    }
  }
}

# ---------- native Bloecke (Fliesstext der Unterseiten) ----------
function Native-Blocks($blocks) {
  $out = foreach ($b in $blocks) {
    switch ($b.t) {
      'h' {
        $lvl = [int]$b.lvl; $tag = "h$lvl"
        $id  = if ($b.id) { $b.id } elseif ($lvl -eq 2) { Slugify $b.x } else { '' }
        $idAttr = if ($id) { " id=`"$id`"" } else { '' }
        $anchor = if ($id) { ',"anchor":"' + $id + '"' } else { '' }
        $j = '{"level":' + $lvl + $anchor + ',"style":{"color":{"text":"' + $C.head + '"},"typography":{"fontFamily":"' + $FONT_HEAD + '"}}}'
        $hico = if ($lvl -eq 2) { H2-Ico $b.icon } else { '' }
        $hcls = if ($hico) { 'wp-block-heading has-text-color kt-h2i' } else { 'wp-block-heading has-text-color' }
        "<!-- wp:heading $j -->`n<$tag$idAttr class=`"$hcls`" style=`"color:$($C.head);font-family:$FONT_HEAD`">$hico$($b.x)</$tag>`n<!-- /wp:heading -->"
      }
      'p'  { "<!-- wp:paragraph -->`n<p>$($b.x)</p>`n<!-- /wp:paragraph -->" }
      'form' { if ($b.id) { Form-Block ([int]$b.id) $b.anchor } else { Form-Block } }
      'ul' {
        $li = ($b.x | ForEach-Object { "<!-- wp:list-item -->`n<li>$_</li>`n<!-- /wp:list-item -->" }) -join "`n"
        "<!-- wp:list -->`n<ul class=`"wp-block-list`">`n$li`n</ul>`n<!-- /wp:list -->"
      }
      'btns' {
        # Nutzerwunsch 2026-09-01: CTA-Buttons global aus; {keep:true} schaltet einen
        # Block gezielt an. Einheitliche, ruhige Button-Reihe: 1. = gefuellt (primaer),
        # weitere = Umriss.
        if ($b.keep) {
          $xs = @($b.x)
          $bb = for ($k = 0; $k -lt $xs.Count; $k++) {
            $it = $xs[$k]
            $st = if ($k -eq 0) { "background:$($C.accent);color:#ffffff;border:1px solid $($C.accent)" }
                  else          { "background:transparent;color:$($C.accent);border:1px solid #ccd1d8" }
            "<a href=`"$($it.url)`" style=`"display:inline-flex;align-items:center;padding:10px 18px;font-family:$FONT_HEAD;font-size:13px;font-weight:700;letter-spacing:.01em;text-decoration:none;border-radius:4px;$st`">$($it.label)</a>"
          }
          "<!-- wp:html -->`n<div style=`"display:flex;flex-wrap:wrap;gap:10px;margin:22px 0 4px`">`n  $($bb -join "`n  ")`n</div>`n<!-- /wp:html -->"
        } else { '' }
      }
      'html' { "<!-- wp:html -->`n$($b.x)`n<!-- /wp:html -->" }
      'table' {
        $thead = if ($b.head) { "<thead><tr>" + (($b.head | ForEach-Object { "<th>$_</th>" }) -join '') + "</tr></thead>" } else { '' }
        $tbody = "<tbody>" + (($b.rows | ForEach-Object {
          "<tr>" + (($_ | ForEach-Object { "<td>$_</td>" }) -join '') + "</tr>"
        }) -join '') + "</tbody>"
        $cap = if ($b.caption) { "<figcaption style=`"font-size:12.5px;color:#777;margin-top:8px`">$($b.caption)</figcaption>" } else { '' }
        $ts = "<style>.kt-tbl{width:100%;border-collapse:collapse;font-size:14px;margin:6px 0}.kt-tbl th,.kt-tbl td{text-align:left;padding:9px 12px;border-bottom:1px solid #e6e6e6}.kt-tbl th{font-family:$FONT_HEAD;color:$($C.head);font-weight:700;background:$($C.soft)}.kt-tbl td:last-child,.kt-tbl th:last-child{text-align:right;white-space:nowrap;font-variant-numeric:tabular-nums}.kt-tbl tr:last-child td{border-bottom:0}</style>"
        "<!-- wp:html -->`n$ts`n<figure style=`"margin:0;overflow-x:auto`"><table class=`"kt-tbl`">$thead$tbody</table>$cap</figure>`n<!-- /wp:html -->"
      }
      'image' {
        $cap = if ($b.caption) { "`n  <figcaption style=`"text-align:center;font-size:13px;color:$($C.text);margin-top:8px`">$($b.caption)</figcaption>" } else { '' }
        $mw  = if ($b.max) { $b.max } else { '820px' }
        "<!-- wp:html -->`n<figure style=`"margin:0 auto;max-width:$mw`"><img src=`"$($b.src)`" alt=`"$($b.alt)`" style=`"width:100%;height:auto;display:block;border:1px solid $($C.line)`">$cap</figure>`n<!-- /wp:html -->"
      }
      'brandgrid' {
        $names = if ($b.x) { $b.x } else { $SD.brands }
        "<!-- wp:html -->`n$(Brands-Grid $names)`n<!-- /wp:html -->"
      }
      'brandmodels' {
        $grps = @(
          @{ h = 'Kaffeevollautomaten'; items = @($b.x.vollautomaten) }
          @{ h = 'Siebtr&auml;germaschinen'; items = @($b.x.siebtraeger) }
        )
        # Logo-Raster oben (wie Startseite), jede Kachel springt zur Marken-Sektion
        $allItems = @($grps | ForEach-Object { $_.items } | Where-Object { $_ })
        $gridTiles = ($allItems | ForEach-Object {
          $slug = Brand-Slug $_.name
          $u = $brandMedia[$slug]
          $inner = if ($u) { "<img src=`"$u`" alt=`"$($_.name)`">" } else { "<span class=`"kt-brandtxt`">$($_.name)</span>" }
          "<a href=`"#brand-$slug`">$inner</a>"
        }) -join "`n    "
        $grid = "$BRANDS_CSS`n<div class=`"kt-brands kt-brands-link`">`n    $gridTiles`n</div>"
        $blocks2 = foreach ($g in $grps) {
          if (-not $g.items.Count) { continue }
          $rows = ($g.items | ForEach-Object {
            $slug = Brand-Slug $_.name
            $u = $brandMedia[$slug]
            $logo = if ($u) { "<img src=`"$u`" alt=`"$($_.name)`" style=`"max-height:32px;max-width:108px;width:auto;object-fit:contain`">" }
                    else    { "<span style=`"font-family:$FONT_HEAD;font-weight:700;font-size:14px;color:$($C.head)`">$($_.name)</span>" }
            "<div id=`"brand-$slug`" style=`"scroll-margin-top:90px;display:grid;grid-template-columns:120px 1fr;gap:20px;align-items:baseline;padding:15px 0;border-top:1px solid #e6e6e6`"><div style=`"font-family:$FONT_HEAD;font-weight:700;font-size:13.5px;color:$($C.head);display:flex;align-items:center;min-height:20px`">$logo</div><div style=`"font-size:14px;line-height:1.65;color:$($C.text)`">$($_.models)</div></div>"
          }) -join "`n"
          "<h3 class=`"kt-bmsec`">$($g.h)</h3>`n<div style=`"font-family:$FONT_BODY`">`n$rows`n</div>"
        }
        # .kt-prose h3 erzwingt sonst 11.5px/grau/uppercase - hier ueberschreiben
        $bmSecCss = "<style>.kt-prose h3.kt-bmsec{font-family:$FONT_HEAD !important;color:$($C.head) !important;font-size:17px !important;font-weight:700;line-height:1.3;text-transform:none;letter-spacing:0;margin:36px 0 6px !important;padding-bottom:9px;border-bottom:2px solid #e2e2e2}</style>"
        "<!-- wp:html -->`n$bmSecCss`n$grid`n" + ($blocks2 -join "`n") + "`n<!-- /wp:html -->"
      }
      'steps' {
        $items = ($b.x | ForEach-Object {
          $body = if ($_.p) { "<p>$($_.p)</p>" } else { '' }
          if ($_.points) {
            $li = ($_.points | ForEach-Object { "<li>$_</li>" }) -join ''
            $body += "<ul>$li</ul>"
          }
          $sid = if ($b.nav) { " id=`"kt-step-$($_.n)`" style=`"scroll-margin-top:84px`"" } else { '' }
          "  <div class=`"kt-step`"$sid><span class=`"kt-step-n`">$($_.n)</span><div><h3>$($_.h)</h3>$body</div></div>"
        }) -join "`n"
        # optionale Kachel-Navigation oben (Icon + kurze Beschreibung, Klick springt zum Schritt)
        $navHtml = ''
        if ($b.nav) {
          $tiles = ($b.x | ForEach-Object {
            $ic = if ($_.icon -and $STEP_ICONS.ContainsKey($_.icon)) { $STEP_ICONS[$_.icon] } else { '' }
            $sx = if ($_.short) { $_.short } else { '' }
            "<a class=`"kt-sn`" href=`"#kt-step-$($_.n)`"><span class=`"kt-sn-ic`">$ic</span><span class=`"kt-sn-n`">Schritt $($_.n)</span><b>$($_.h)</b><span class=`"kt-sn-x`">$sx</span></a>"
          }) -join "`n    "
          $navHtml = "<div class=`"kt-stepnav`">`n    $tiles`n</div>`n"
        }
        $st = @"
<style>
.kt-stepnav{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:4px 0 22px}
.kt-sn{display:flex;flex-direction:column;background:#ffffff;border:1px solid #e0e0e0;border-radius:9px;padding:16px 15px 15px;text-decoration:none;transition:border-color .12s,box-shadow .12s,transform .12s}
.kt-sn:hover{border-color:$($C.accent);box-shadow:0 4px 16px rgba(0,0,0,.07);transform:translateY(-2px)}
.kt-sn-ic{width:38px;height:38px;display:flex;align-items:center;justify-content:center;border-radius:50%;background:$($C.soft);color:$($C.accent);margin-bottom:10px}
.kt-sn-ic svg{width:20px;height:20px}
.kt-sn-n{font-family:Tahoma,Arial,sans-serif;font-size:10px;font-weight:700;letter-spacing:.1em;text-transform:uppercase;color:#8a8a8a}
.kt-sn b{font-family:$FONT_HEAD;color:$($C.head);font-size:13.5px;line-height:1.3;margin:3px 0 5px}
.kt-sn-x{font-size:12px;line-height:1.5;color:#666}
.kt-steps{display:grid;gap:14px}
.kt-step{display:grid;grid-template-columns:46px 1fr;gap:18px;align-items:start;background:#ffffff;border:1px solid #e0e0e0;border-radius:7px;padding:20px 22px}
.kt-step-n{width:46px;height:46px;border-radius:50%;background:$($C.accent);color:#ffffff;font-family:Tahoma,Arial,sans-serif;font-weight:700;font-size:19px;display:flex;align-items:center;justify-content:center}
.kt-step h3{margin:6px 0 7px;font-family:$FONT_HEAD;color:$($C.head);font-size:15px;font-weight:700}
.kt-step p{margin:0 0 8px;line-height:1.6;font-size:14.5px;color:$($C.text)}
.kt-step ul{margin:0;padding:0;list-style:none}
.kt-step li{position:relative;padding-left:18px;margin:0 0 5px;font-size:13.5px;line-height:1.55;color:#555}
.kt-step li::before{content:'';position:absolute;left:2px;top:8px;width:5px;height:5px;border-radius:50%;background:$($C.accent)}
.kt-step>div>*:last-child{margin-bottom:0}
@media(max-width:1040px){.kt-stepnav{grid-template-columns:1fr 1fr}}
@media(max-width:460px){.kt-stepnav{grid-template-columns:1fr}}
</style>
"@
        "<!-- wp:html -->`n$st`n$navHtml<div class=`"kt-steps`">`n$items`n</div>`n<!-- /wp:html -->"
      }
      'timeline' {
        $hl   = @($b.highlights)
        $eras = @($b.eras)
        $ncol = [Math]::Max($hl.Count, 1)
        $strip = ($hl | ForEach-Object {
          "<a class=`"kt-tp`" href=`"#era-$($_.era)`"><span class=`"dot`"></span><span class=`"y`">$($_.y)</span><span class=`"e`">$($_.e)</span></a>"
        }) -join "`n      "
        $chron = ($eras | ForEach-Object {
          $its = ($_.items | ForEach-Object {
            $cls = if ($_.hl) { 'kt-it hl' } else { 'kt-it' }
            $ifig = if ($_.img) { "<figure class=`"kt-itfig`"><img src=`"$($_.img)`" alt=`"$($_.imgAlt)`" loading=`"lazy`">$(if ($_.imgCap) { "<figcaption>$($_.imgCap)</figcaption>" })</figure>" } else { '' }
            "<div class=`"$cls`"><div class=`"yr`">$($_.yr)</div><div class=`"bd`"><b>$($_.b)</b><p>$($_.x)</p>$ifig</div></div>"
          }) -join "`n        "
          $imgList = @(); if ($_.imgs) { $imgList = @($_.imgs) } elseif ($_.img) { $imgList = @(@{ src = $_.img; alt = $_.imgAlt; cap = $_.imgCap }) }
          $fig = if ($imgList.Count) {
            $figs = ($imgList | ForEach-Object { "<figure class=`"kt-erafig`"><img src=`"$($_.src)`" alt=`"$($_.alt)`" loading=`"lazy`">$(if ($_.cap) { "<figcaption>$($_.cap)</figcaption>" })</figure>" }) -join "`n        "
            "<div class=`"kt-erafigs`">`n        $figs`n      </div>"
          } else { '' }
          "<section class=`"kt-era`" id=`"era-$($_.id)`"><div class=`"kt-era-h`"><span class=`"sp`">$($_.span)</span><h2>$($_.title)</h2></div><div class=`"kt-items`">`n        $fig`n        $its`n      </div></section>"
        }) -join "`n    "
        $ts = @"
<style>
.kt-miles{background:$($C.soft);border:1px solid $($C.line);border-radius:8px;padding:26px 22px 28px;margin:4px 0 6px}
.kt-tl{display:grid;grid-template-columns:repeat($ncol,1fr);position:relative;max-width:780px;margin:0 auto}
.kt-tl::before{content:"";position:absolute;height:3px;background:$($C.line);top:10px;left:9%;right:9%}
.kt-tp{display:block;text-align:center;text-decoration:none;color:$($C.head);position:relative}
.kt-tp .dot{display:block;width:22px;height:22px;border:3px solid $($C.accent);border-radius:50%;background:#fff;margin:0 auto 10px;position:relative;z-index:1;transition:transform .12s}
.kt-tp:hover .dot{transform:scale(1.14)}
.kt-tp .y{display:block;font-family:$FONT_HEAD;font-size:16px;font-weight:700;color:$($C.head)}
.kt-tp .e{display:block;font-size:11.5px;color:#6b7178;line-height:1.4;margin-top:2px;padding:0 4px}
.kt-chron{max-width:820px;margin:24px auto 0}
.kt-era{scroll-margin-top:24px;margin-bottom:34px}
.kt-era:last-child{margin-bottom:6px}
.kt-era-h{display:flex;align-items:baseline;gap:12px;margin-bottom:16px;padding-bottom:9px;border-bottom:2px solid $($C.line)}
.kt-era-h .sp{font-family:$FONT_HEAD;font-size:11px;font-weight:700;letter-spacing:.08em;color:#6b7178;background:#fff;border:1px solid $($C.line);border-radius:999px;padding:4px 11px;white-space:nowrap}
.kt-era-h h2{font-family:$FONT_HEAD !important;font-size:19px !important;line-height:1.25 !important;margin:0 !important;padding:0 !important;border:0 !important;font-weight:700;color:$($C.head)}
.kt-erafigs{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:14px;margin:0 0 20px;max-width:760px}
.kt-erafig{margin:0;border:1px solid $($C.line);border-radius:8px;overflow:hidden;background:#fff}
.kt-erafigs:has(.kt-erafig:only-child){grid-template-columns:1fr;max-width:440px}
.kt-erafig img{display:block;width:100%;height:auto;aspect-ratio:4/3;object-fit:cover}
.kt-erafig figcaption{font-size:12px;color:#6b7178;padding:8px 12px;line-height:1.5}
.kt-itfig{margin:11px 0 2px;max-width:360px;border:1px solid $($C.line);border-radius:8px;overflow:hidden;background:#fff}
.kt-itfig img{display:block;width:100%;height:auto;aspect-ratio:4/3;object-fit:cover}
.kt-itfig figcaption{font-size:11.5px;color:#6b7178;padding:7px 11px;line-height:1.5}
.kt-items{position:relative;padding-left:22px}
.kt-items::before{content:"";position:absolute;left:5px;top:10px;bottom:10px;width:2px;background:$($C.line)}
.kt-it{display:grid;grid-template-columns:100px 1fr;gap:16px;position:relative;padding:11px 0}
.kt-it::before{content:"";position:absolute;left:-22px;top:16px;width:12px;height:12px;background:#fff;border:3px solid $($C.accent);border-radius:50%}
.kt-it .yr{font-family:$FONT_HEAD;font-size:14.5px;font-weight:700;color:$($C.accent);line-height:1.5}
.kt-it .bd b{font-family:$FONT_HEAD;font-size:15.5px;font-weight:700;display:block;margin:0 0 3px;color:$($C.head)}
.kt-it .bd p{font-size:14.5px;line-height:1.6;color:$($C.text);margin:0}
.kt-it.hl .bd{background:#fff;border:1px solid $($C.line);border-radius:9px;padding:13px 15px}
.kt-it.hl .yr{color:$($C.head)}
@media(max-width:720px){
  .kt-tl{grid-template-columns:repeat(3,1fr);gap:20px 0}
  .kt-tl::before{display:none}
  .kt-it{grid-template-columns:1fr;gap:2px}
  .kt-it::before{display:none}
  .kt-items{padding-left:0}
  .kt-items::before{display:none}
  .kt-era-h{flex-direction:column;align-items:flex-start;gap:7px}
}
</style>
"@
        "<!-- wp:html -->`n$ts`n<div class=`"kt-miles`"><div class=`"kt-tl`">`n      $strip`n</div></div>`n<div class=`"kt-chron`">`n    $chron`n</div>`n<!-- /wp:html -->"
      }
      'callout' {
        # hervorgehobener Hinweiskasten. $b.title = Ueberschrift, $b.x = Listenpunkte,
        # $b.intro = optionaler Vorspann, $b.variant = 'warn' (rot) | 'ok' (gruen) | sonst neutral.
        # CSS deckt alle Varianten ab und ist nach Varianten-Klasse getrennt, damit
        # mehrere Callouts unterschiedlicher Variante auf einer Seite nicht kollidieren.
        $vcls = if ($b.variant -eq 'warn') { 'kt-co kt-co-warn' }
                elseif ($b.variant -eq 'ok') { 'kt-co kt-co-ok' }
                else { 'kt-co' }
        $intro = if ($b.intro) { "<p class=`"kt-co-i`">$($b.intro)</p>" } else { '' }
        $lis = ($b.x | ForEach-Object { "<li>$_</li>" }) -join "`n    "
        $ttl = if ($b.title) { "<p class=`"kt-co-t`">$($b.title)</p>" } else { '' }
        $co = @"
<style>
.kt-co{max-width:$SECW;margin:24px auto;background:$($C.soft);border:1px solid $($C.line);border-left:3px solid $($C.accent);border-radius:10px;padding:18px 22px 20px;font-family:$FONT_BODY}
.kt-co-warn{background:#fbf2f2;border-color:#e8c9c9;border-left-color:#b23b3b}
.kt-co-ok{background:#eef6ef;border-color:#cbe3cf;border-left-color:#2f7d4a}
.kt-co-t{font-family:$FONT_HEAD;font-weight:700;font-size:15px;color:$($C.accent);margin:0 0 10px}
.kt-co-warn .kt-co-t{color:#b23b3b}
.kt-co-ok .kt-co-t{color:#2f7d4a}
.kt-co-i{font-size:14px;line-height:1.6;color:$($C.text);margin:0 0 12px}
.kt-co ul{list-style:none;margin:0;padding:0}
.kt-co li{position:relative;padding-left:24px;margin:0 0 7px;font-size:14px;line-height:1.6;color:$($C.text)}
.kt-co li:last-child{margin-bottom:0}
.kt-co li::before{content:"\2013";position:absolute;left:2px;top:0;color:$($C.accent);font-weight:700}
.kt-co-warn li::before{content:"\2715";color:#b23b3b}
.kt-co-ok li::before{content:"\2713";color:#2f7d4a}
</style>
<div class="$vcls">$ttl$intro<ul>
    $lis
</ul></div>
"@
        "<!-- wp:html -->`n$co`n<!-- /wp:html -->"
      }
      default { throw "Unbekannter Blocktyp: $($b.t)" }
    }
  }
  ($out -join "`n`n")
}

# wp-Blockkommentare entfernen (fuer Einbettung in einen einzigen wp:html-Block)
function Strip-Wp($h) { ([regex]::Replace([string]$h, '<!--\s*/?wp:[^>]*?-->', '')).Trim() }

# eine Farbzone ueber die volle Breite, Inhalt zentriert bis $MAXW
# $extra: zusaetzliche Inline-Styles (z. B. "position:sticky;top:0;z-index:90")
function Zone($bg, $padTop, $padBottom, $innerHtml, $extra = '') {
  $j = '{"align":"full","style":{"color":{"background":"' + $bg + '"},"spacing":{"padding":{"top":"' + $padTop + '","bottom":"' + $padBottom + '","left":"24px","right":"24px"}}},"layout":{"type":"constrained","contentSize":"' + $MAXW + '"}}'
  $st = "background-color:$bg;padding-top:$padTop;padding-bottom:$padBottom;padding-left:24px;padding-right:24px"
  if ($extra) { $st += ";$extra" }
  "<!-- wp:group $j -->`n<div class=`"wp-block-group alignfull has-background`" style=`"$st`">`n$innerHtml`n</div>`n<!-- /wp:group -->"
}
function Html-Block($h) { "<!-- wp:html -->`n$h`n<!-- /wp:html -->" }

# Kontaktformular: Contact Form 7 (Shortcode muss in einem wp:shortcode-Block stehen,
# NICHT in wp:html - dort wird kein do_shortcode ausgefuehrt).
$FORM_SHORTCODE = if ($chrome.contactFormShortcode) { $chrome.contactFormShortcode } else { '[fluentform id="1"]' }
$FORM_CSS = @"
<style>
.kt-formwrap{max-width:640px;margin:0 auto;font-family:$FONT_BODY}
.kt-formwrap .fluentform .ff-el-group{margin-bottom:16px}
.kt-formwrap .fluentform .ff-el-input--label label,
.kt-formwrap .fluentform .ff-el-input--label{font-family:$FONT_BODY !important;font-size:14px;color:$($C.head);font-weight:600}
.kt-formwrap .fluentform .ff-el-form-control{
  width:100%;padding:10px 12px !important;border:1px solid #c4c4c4 !important;border-radius:5px !important;
  font-size:15px !important;font-family:$FONT_BODY !important;background:#fff !important;color:$($C.text) !important;
  line-height:1.5 !important;box-shadow:none !important}
.kt-formwrap .fluentform textarea.ff-el-form-control{min-height:130px;resize:vertical}
.kt-formwrap .fluentform .ff-el-form-control:focus{
  outline:none !important;border-color:$($C.accent) !important;box-shadow:0 0 0 3px rgba(51,65,85,.12) !important}
.kt-formwrap .fluentform .ff-btn-submit{
  background:$($C.accent) !important;color:#fff !important;border:1px solid $($C.accent) !important;border-radius:4px !important;
  padding:11px 26px !important;font-family:$FONT_HEAD !important;font-size:14px !important;font-weight:700 !important;
  letter-spacing:.01em !important;box-shadow:none !important;text-transform:none !important;cursor:pointer}
.kt-formwrap .fluentform .ff-btn-submit:hover{background:$($C.accentD) !important;border-color:$($C.accentD) !important}
.kt-formwrap .ff-message-success,.kt-formwrap .ff_submit_success{
  margin:16px 0 0;padding:14px 16px;border:1px solid #63a375;background:#eef7f0;color:#2f5d3f;
  border-radius:6px;font-family:$FONT_BODY !important;font-size:14.5px;line-height:1.6}
.kt-formwrap .fluentform .ff-el-is-error .ff-el-form-control{border-color:#d8a0a0 !important}
.kt-formwrap .fluentform .text-danger,.kt-formwrap .fluentform .error{
  color:#c0392b !important;font-size:12.5px;font-weight:400;font-family:$FONT_BODY !important}
.kt-formwrap .ff-message-error,.kt-formwrap .fluentform .ff-errors-in-stack{
  font-family:$FONT_BODY !important;font-size:13.5px;color:#8a3b3b;border:1px solid #d8a0a0;background:#fbeeee;
  padding:12px 14px;border-radius:6px;margin-top:12px}
</style>
"@
function Form-Block($formId = $null, $anchor = 'kontakt') {
  $sc  = if ($formId) { "[fluentform id=`"$formId`"]" } else { $FORM_SHORTCODE }
  $anc = if ($anchor) { $anchor } else { 'kontakt' }
  "<!-- wp:html -->`n$FORM_CSS`n<div id=`"$anc`"></div>`n<div class=`"kt-formwrap`">`n<!-- /wp:html -->`n`n<!-- wp:shortcode -->`n$sc`n<!-- /wp:shortcode -->`n`n<!-- wp:html -->`n</div>`n<!-- /wp:html -->"
}

# alle Farbzonen einer Seite in EIN zentriertes "Blatt" (weiss, weiche Schatten,
# leicht abgerundet) auf kuehlgrauem Seitenhintergrund huellen - der Lesebereich
# hebt sich dadurch klar ab (Idee: staging.feuerwehr-langenhain.de).
# blockGap 0, damit das Theme keine weissen Abstaende zwischen die Zonen setzt.
$SHEET_CSS = @"
<style>
.kt-sheet{max-width:1240px;margin:0 auto;background:$($C.white);border-radius:16px;box-shadow:0 14px 46px rgba(20,22,25,.14),0 3px 10px rgba(20,22,25,.06)}
.kt-sheet .alignfull{width:100% !important;max-width:none !important;margin-left:0 !important;margin-right:0 !important;left:auto !important;right:auto !important}
/* Ecken der ersten/letzten Zone runden - statt overflow:clip auf .kt-sheet,
   damit die klebende Menueleiste (position:sticky) nicht von einem
   Clip-Kontext gefangen wird (Safari/Firefox). */
.kt-sheet>.wp-block-group:first-of-type{border-top-left-radius:16px;border-top-right-radius:16px}
.kt-sheet>.wp-block-group:last-of-type{border-bottom-left-radius:16px;border-bottom-right-radius:16px;overflow:clip}
@media(max-width:560px){
  .kt-sheet{border-radius:9px}
  .kt-sheet>.wp-block-group:first-of-type{border-top-left-radius:9px;border-top-right-radius:9px}
  .kt-sheet>.wp-block-group:last-of-type{border-bottom-left-radius:9px;border-bottom-right-radius:9px}
}
</style>
"@
function Wrap-Page($zonesHtml) {
  $j = '{"align":"full","style":{"spacing":{"blockGap":"0","margin":{"top":"0","bottom":"0"},"padding":{"top":"0","bottom":"0","left":"0","right":"0"}}},"layout":{"type":"default"}}'
  @"
<!-- wp:group $j -->
<div class="wp-block-group alignfull" style="margin:0;padding:clamp(0px,2.4vw,32px) clamp(0px,2.4vw,32px);background-color:$($C.pagebg)">
$(Html-Block $SHEET_CSS)
<div class="kt-sheet">
$zonesHtml
</div>
</div>
<!-- /wp:group -->
"@
}

function Btn-Html($label, $url, $style) {
  $base = "display:inline-flex;align-items:center;justify-content:center;padding:13px 26px;font-family:Tahoma,Arial,sans-serif;font-size:14.5px;font-weight:700;letter-spacing:.01em;border-radius:3px;text-decoration:none"
  if ($style -eq 'outline') { "<a href=`"$url`" style=`"$base;background:transparent;color:$($C.head);border:1px solid #b7b7b7`">$label</a>" }
  else                      { "<a href=`"$url`" style=`"$base;background:$($C.accent);color:#ffffff;border:1px solid $($C.accent)`">$label</a>" }
}

# Eyebrow-Label (kleiner Akzent-Text ueber Ueberschriften) im Feuerwehr-Stil
function Eyebrow($t) { "<p style=`"font-family:$FONT_HEAD;color:$($C.accent);font-weight:700;font-size:11px;letter-spacing:.16em;text-transform:uppercase;margin:0 0 10px`">$t</p>" }

# ---------- Daten ----------
$data   = Get-Content "$root\pages-content.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$chrome = $data.chrome
$SD     = $data.start

# FAQ/Hilfe-Seiten aus faq-content.json dazumergen; Hub = hilfethemen
$FAQ_HUB = $null
$faqFile = "$root\faq-content.json"
if (Test-Path $faqFile) {
  $faq = Get-Content $faqFile -Raw -Encoding UTF8 | ConvertFrom-Json
  $FAQ_HUB = $faq.hub
  $data.pages = @($data.pages) + @($faq.pages)
}

$base = (Import-KtEnv)['WP_URL'].TrimEnd('/')
$linkOf = @{}
$menuOf = @{}
foreach ($p in $data.pages) { $linkOf[$p.slug] = "$base/$($p.slug)/"; $menuOf[$p.slug] = $p.menu }
# "Start" ist die statische Startseite -> Home-Links auf die Wurzel-URL, nicht /start/
$linkOf['start'] = "$base/"

# Hersteller-Logos (slug -> Medien-URL), befuellt von upload-brands.ps1
$brandMedia = @{}
$bmFile = "$root\brands-media.json"
if (Test-Path $bmFile) {
  (Get-Content $bmFile -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $brandMedia[$_.Name] = $_.Value }
}
function Brand-Slug($name) { ($name -replace '[^A-Za-z0-9]+','-').Trim('-').ToLower() }

# einheitliches Logo-Raster; Marke mit Datei = Logo (grau, bei Hover voll), sonst Text-Kachel
$BRANDS_CSS = @"
<style>
.kt-brands{max-width:$SECW;margin:0 auto;display:grid;grid-template-columns:repeat(auto-fill,minmax(148px,1fr));gap:1px;background:#dddddd;border:1px solid #dddddd}
.kt-brands>div,.kt-brands>a{background:#ffffff;display:flex;align-items:center;justify-content:center;padding:18px 14px;min-height:76px;transition:background .15s;text-decoration:none}
.kt-brands>div:hover,.kt-brands>a:hover{background:#ececec}
.kt-brands img{max-height:42px;max-width:80%;width:auto;object-fit:contain}
.kt-brands .kt-brandtxt{font-family:Tahoma,Arial,sans-serif;font-weight:700;font-size:15px;letter-spacing:.02em;color:$($C.head)}
</style>
"@
function Brands-Grid($names) {
  $tiles = foreach ($n in $names) {
    $url = $brandMedia[(Brand-Slug $n)]
    $inner = if ($url) { "<img src=`"$url`" alt=`"$n`">" }
             else      { "<span class=`"kt-brandtxt`">$n</span>" }
    "<div>$inner</div>"
  }
  "$BRANDS_CSS`n<div class=`"kt-brands`">`n    " + ($tiles -join "`n    ") + "`n</div>"
}

# Menue-Baum wie www.kaffeetechniker.de: Top-Ebene mit aufklappbaren Untermenues.
# Knoten: entweder { slug = '<seiten-slug>' } (Label/URL aus den Seiten-Maps) oder
# { label = '...'; url = '...' } fuer externe Ziele (Shop/Warenkorb/Konto).
# kids = Liste aus Slugs (String) und/oder solchen Hashtables.
$NAVTREE = @(
  @{ slug = 'start' }
  @{ slug = 'reparatur'; kids = @(
      'reparaturablauf',
      @{ slug = 'reparaturkosten'; label = 'Dauer &amp; Kosten' },
      @{ slug = 'reparatur-check'; label = 'Reparatur-Check' },
      'marken',
      @{ slug = 'leihgeraete' }
    ) }
  @{ slug = 'wartung'; label = 'Wartung'; kids = @(
      @{ slug = 'wartung'; label = 'Wartung &amp; Reinigung' }
      @{ slug = 'wartungserinnerung'; label = 'Wartungserinnerung' }
    ) }
  @{ slug = 'kaffeemaschinen-kaufen'; label = 'Kaufen'; kids = @(
      @{ label = 'JURA Online-Shop &rsaquo;'; url = "$base/jura/" }
      @{ label = 'NIVONA Online-Shop &rsaquo;'; url = "$base/nivona/" }
      @{ slug = 'kaffeemaschine-mieten'; label = 'Mieten &amp; Leasen' }
      @{ slug = 'unser-kaffee'; label = 'Unser Kaffee &amp; Tee' }
      @{ slug = 'unser-kaffee-wissen'; label = 'Kaffee: Herkunft &amp; R&ouml;stung' }
    ) }
  @{ slug = 'hilfethemen'; label = 'Hilfe &amp; Wissen'; kids = @(
      $FAQ_HUB.groups | ForEach-Object { @{ url = "$base/hilfethemen/#$($_.anchor)"; label = [string]$_.nav } }
      @{ slug = 'hilfethemen'; label = 'Alle Hilfethemen &rarr;' }
    ) }
  @{ slug = 'ueber-uns'; label = '&Uuml;ber uns'; kids = @(
      @{ slug = 'ueber-uns'; label = 'Das Unternehmen' }
      @{ slug = 'anfahrt' }
      @{ slug = 'jobs' }
    ) }
  @{ slug = 'kontakt' }
)

# Icons fuer die obere Leiste (Warenkorb + Konto), Feather-Stil, faerben ueber currentColor
$ICON_CART = '<svg width="21" height="21" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="21" r="1"></circle><circle cx="20" cy="21" r="1"></circle><path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6"></path></svg>'
$ICON_USER = '<svg width="21" height="21" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path><circle cx="12" cy="7" r="4"></circle></svg>'

# Zaehler-Blase am Warenkorb-Icon. Die Seiten sind statisch gecacht, daher
# wird die Anzahl per WooCommerce Store-API (Cookie-Session) nachgeladen.
$CART_BADGE = '<span class="kt-cartn" data-cart-badge hidden aria-hidden="true"></span>'
$CART_BADGE_JS = @"
<style>
a.kt-ic,a.ic{position:relative}
.kt-cartn{position:absolute;top:-4px;right:-4px;min-width:16px;height:16px;padding:0 4px;border-radius:9px;background:#c0392b;color:#fff;font:700 11px/16px $FONT_BODY;text-align:center;white-space:nowrap;box-shadow:0 0 0 2px #fff;pointer-events:none}
</style>
<script>
(function(){
  var U='$base/wp-json/wc/store/v1/cart';
  function paint(n){
    var e=document.querySelectorAll('[data-cart-badge]'),i;
    for(i=0;i<e.length;i++){
      if(n>0){e[i].textContent=n>99?'99+':(''+n);e[i].hidden=false;}
      else{e[i].hidden=true;}
    }
  }
  function refresh(){
    try{
      fetch(U,{credentials:'include',cache:'no-store',headers:{'Accept':'application/json'}})
        .then(function(r){return r.ok?r.json():null;})
        .then(function(d){if(d&&d.items_count!=null)paint(d.items_count);})
        .catch(function(){});
    }catch(e){}
  }
  refresh();
  window.addEventListener('pageshow',function(ev){if(ev.persisted)refresh();});
  document.addEventListener('visibilitychange',function(){if(!document.hidden)refresh();});
  document.addEventListener('wc-blocks_added_to_cart',refresh);
  document.addEventListener('wc-blocks_removed_from_cart',refresh);
  if(window.jQuery){window.jQuery(document.body).on('added_to_cart removed_from_cart updated_cart_totals',refresh);}
})();
</script>
"@

# Hinweisbanner auf rohen WooCommerce-Kategorie-Archiven (/product-category/...),
# die es auch als ausgebaute eigene Seite gibt (Serien, Filter, Genusswelten).
# Erscheint per body-Klasse (term-<slug>) gezielt nur auf dieser einen Kategorie,
# nicht sitezweit - Landeplatz ist das gemeinsame 'header'-Template-Part
# (siehe build-theme-nav.ps1), das auf allen Shop-/Kategorie-Seiten liegt.
$CATEGORY_BANNER_JS = @'
<script>
(function(){
  var MAP = {
    'term-jura-kaffeevollautomaten': {
      url: '/jura-kaffeevollautomaten/',
      label: 'Zur \u00dcbersicht mit Filtern \u2192',
      text: 'Alle Modelle mit Serien-Filter, Farbwahl und Genusswelten finden Sie auf unserer ausf\u00fchrlichen \u00dcbersichtsseite.'
    }
  };
  function init(){
    if (document.getElementById('kt-catbanner')) { return; }
    var cls = document.body.className.split(/\s+/);
    var cfg = null;
    for (var i = 0; i < cls.length; i++) { if (MAP[cls[i]]) { cfg = MAP[cls[i]]; break; } }
    if (!cfg) { return; }
    var h1 = document.querySelector('.wp-block-query-title');
    if (!h1) { return; }
    var el = document.createElement('div');
    el.id = 'kt-catbanner';
    el.style.cssText = "max-width:1160px;margin:14px auto 4px;background:#f0efec;border:1px solid #d8d8d8;border-left:3px solid #334155;border-radius:8px;padding:14px 18px;display:flex;flex-wrap:wrap;align-items:center;justify-content:space-between;gap:12px;font-family:'Source Sans 3','Source Sans Pro',system-ui,sans-serif";
    el.innerHTML = '<span style="font-size:14px;line-height:1.5;color:#1c1c1c">' + cfg.text + '</span>' +
      '<a href="' + cfg.url + '" style="display:inline-flex;align-items:center;padding:9px 16px;font-family:Tahoma,Arial,sans-serif;font-size:13px;font-weight:700;color:#ffffff;background:#334155;border-radius:4px;text-decoration:none;white-space:nowrap">' + cfg.label + '</a>';
    h1.insertAdjacentElement('afterend', el);
  }
  if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', init); } else { init(); }
})();
</script>
'@

# Icons fuer Ablauf-Schritte (Feather-Stil, faerben ueber currentColor)
$STEP_ICONS = @{
  box   = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/><path d="M3.27 6.96L12 12.01l8.73-5.05M12 22.08V12"/></svg>'
  quote = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6"/><path d="M9 15l2 2 4-4"/></svg>'
  tool  = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M14.7 6.3a4 4 0 0 0-5.4 5.4L3 18v3h3l6.3-6.3a4 4 0 0 0 5.4-5.4l-2.8 2.8-2-2 2.8-2.8z"/></svg>'
  check = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><path d="M22 4L12 14.01l-3-3"/></svg>'
}

# Piktogramme fuer Abschnitts-Ueberschriften (h2), Feather-Stil, currentColor.
# In den JSON-Bloecken: { "t":"h", "lvl":2, "icon":"tool", "x":"..." }
$SEC_ICONS = @{
  tool    = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M14.7 6.3a4 4 0 0 0-5.4 5.4L3 18v3h3l6.3-6.3a4 4 0 0 0 5.4-5.4l-2.8 2.8-2-2 2.8-2.8z"/></svg>'
  flow    = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><polyline points="13 17 18 12 13 7"/><polyline points="6 17 11 12 6 7"/></svg>'
  users   = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>'
  compare = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/></svg>'
  info    = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>'
  clock   = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>'
  euro    = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M14 21a8 8 0 1 1 0-16"/><line x1="4" y1="10" x2="13" y2="10"/><line x1="4" y1="14" x2="11" y2="14"/></svg>'
  shield  = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>'
  check   = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><path d="M22 4L12 14.01l-3-3"/></svg>'
  coffee  = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8h1a4 4 0 0 1 0 8h-1"/><path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"/><line x1="6" y1="1" x2="6" y2="4"/><line x1="10" y1="1" x2="10" y2="4"/><line x1="14" y1="1" x2="14" y2="4"/></svg>'
  droplet = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2.7s6 6.8 6 11.3a6 6 0 0 1-12 0C6 9.5 12 2.7 12 2.7z"/></svg>'
  flame   = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22a7 7 0 0 0 7-7c0-3-2-5-3.5-7C14 6 12 2 12 2S10 6 8.5 8C7 10 5 12 5 15a7 7 0 0 0 7 7z"/></svg>'
  sun     = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v3M12 19v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M2 12h3M19 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1"/></svg>'
  sparkle = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v4M12 17v4M3 12h4M17 12h4M6 6l2.5 2.5M15.5 15.5 18 18M18 6l-2.5 2.5M8.5 15.5 6 18"/></svg>'
  quote   = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6"/><path d="M9 15l2 2 4-4"/></svg>'
  box     = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/><path d="M3.27 6.96L12 12.01l8.73-5.05M12 22.08V12"/></svg>'
  map     = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>'
  car     = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M5 17h14M5 17a2 2 0 1 1-4 0 2 2 0 0 1 4 0zm18 0a2 2 0 1 1-4 0 2 2 0 0 1 4 0zM3 17l1.5-6.5A2 2 0 0 1 6.4 9h11.2a2 2 0 0 1 1.9 1.5L21 17M6 9l1-4h10l1 4"/></svg>'
  shop    = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.3 4.6a1 1 0 0 0 .9 1.4H19"/><circle cx="9" cy="20" r="1"/><circle cx="17" cy="20" r="1"/></svg>'
  mail    = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M4 4h16a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z"/><polyline points="22,6 12,13 2,6"/></svg>'
  building= '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="3" width="16" height="18" rx="1"/><path d="M9 8h.01M15 8h.01M9 12h.01M15 12h.01M9 16h6"/></svg>'
}
function H2-Ico($key) {
  if ($key -and $SEC_ICONS.ContainsKey($key)) { "<span class=`"kt-h2ico`">$($SEC_ICONS[$key])</span>" } else { '' }
}


# Label + URL eines Navi-Knotens ermitteln.
# Knoten: "slug" (String) | @{slug=...} | @{label=...;url=...} | @{slug=...;label=...} (Label ueberschreibt)
function Nav-Node($n) {
  if ($n -is [string]) { return @{ label = $menuOf[$n]; url = $linkOf[$n]; slug = $n } }
  $slug  = $n.slug
  $label = if ($n.label) { $n.label } elseif ($slug) { $menuOf[$slug] } else { $null }
  $url   = if ($n.url)   { $n.url }   elseif ($slug) { $linkOf[$slug] } else { $null }
  return @{ label = $label; url = $url; slug = $slug }
}

# ---------- Zone 1: Kopf = weisser Logo-Balken + dunkles, mittiges Menueband ----------
function Header-Zone($activeSlug) {
  $t    = $chrome.topbar
  $b    = $chrome.brand
  $logo = $b.logoUrl

  # weisser Balken: Telefon links, Logo mittig, Warenkorb-/Konto-Icon rechts
  $whiteBar = @"
<div class="kt-topbar">
  <div class="kt-phone"><span style="color:#666666">$($t.phoneLabel)</span> <a href="$($t.phoneUrl)">$($t.phone)</a></div>
  <a class="kt-logo" href="$($linkOf['start'])" aria-label="Startseite"><img src="$logo" alt="$($b.logoAlt)"></a>
  <div class="kt-icons">
    <a class="kt-ic" href="$base/cart/" aria-label="Warenkorb" title="Warenkorb">$ICON_CART$CART_BADGE</a>
    <a class="kt-ic" href="$base/my-account/" aria-label="Mein Konto" title="Mein Konto">$ICON_USER</a>
  </div>
</div>
"@

  # aufklappbare, mittig zentrierte Navigation (CSS-only: :hover fuer Desktop,
  # :focus-within fuer Tastatur/Touch; unter 860px klappen die Untermenues dauerhaft auf)
  $navCss = @"
<style>
html{overflow-x:clip}
.kt-page *,.kt-intro *,.kt-brands *,.kt-steps *{box-sizing:border-box}
.kt-topbar{max-width:$MAXW;margin:0 auto;display:grid;grid-template-columns:1fr auto 1fr;align-items:center;gap:10px 20px;font-family:$FONT_BODY}
.kt-topbar .kt-phone{font-size:13px;color:#333333;white-space:nowrap}
.kt-topbar .kt-phone a{color:#1f1f1f;text-decoration:none;font-weight:700;letter-spacing:.02em}
.kt-topbar .kt-logo{justify-self:center;display:inline-flex}
.kt-topbar .kt-logo img{display:block;height:56px;width:auto}
.kt-topbar .kt-icons{justify-self:end;display:flex;gap:2px}
.kt-topbar .kt-ic{display:inline-flex;padding:6px;color:#444444;text-decoration:none}
.kt-topbar .kt-ic:hover,.kt-topbar .kt-ic:focus{color:#000000}
@media (max-width:720px){
  .kt-topbar{grid-template-columns:1fr 1fr;row-gap:12px}
  .kt-topbar .kt-logo{order:-1;grid-column:1 / -1;justify-self:center}
  .kt-topbar .kt-logo img{height:44px}
}
.kt-navwrap{max-width:$MAXW;margin:0 auto;display:flex;justify-content:center;align-items:flex-start}
.kt-navtoggle{display:none}
.ktnav,.ktnav ul{list-style:none;margin:0;padding:0}
.ktnav{display:flex;flex-wrap:wrap;justify-content:center;align-items:center;gap:2px;font-family:Tahoma,Arial,sans-serif}
.ktnav li{position:relative}
.ktnav>li>a{display:block;color:$($C.onDark2);font-weight:400;font-size:14px;line-height:1.2;padding:10px 14px;text-decoration:none;white-space:nowrap}
.ktnav>li>a:hover,.ktnav>li>a:focus{color:$($C.onDark)}
.ktnav>li.is-active>a{color:$($C.onDark);font-weight:700}
.ktnav>li.has-sub>a::after{content:"";display:inline-block;margin-left:7px;border:4px solid transparent;border-top-color:currentColor;position:relative;top:2px}
.ktnav .sub{position:absolute;top:100%;left:50%;transform:translateX(-50%) translateY(4px);min-width:220px;background:#3d3d3d;border:1px solid #606060;box-shadow:0 12px 28px rgba(0,0,0,.35);padding:6px 0;opacity:0;visibility:hidden;transition:opacity .15s,transform .15s,visibility .15s;z-index:60}
.ktnav li.has-sub:hover>.sub,.ktnav li.has-sub:focus-within>.sub{opacity:1;visibility:visible;transform:translateX(-50%) translateY(0)}
.ktnav .sub li a{display:block;color:$($C.onDark2);font-size:13px;line-height:1.3;padding:9px 18px;text-decoration:none;white-space:nowrap}
.ktnav .sub li a:hover,.ktnav .sub li a:focus{background:#565656;color:$($C.onDark)}
.ktnav .sub li a.is-active{color:$($C.onDark);font-weight:700}
@media (max-width:860px){
  .kt-navwrap{display:block;position:relative}
  .kt-navtoggle{display:flex;align-items:center;justify-content:center;gap:11px;width:100%;background:transparent;border:0;color:$($C.onDark);font-family:Tahoma,Arial,sans-serif;font-size:15px;font-weight:700;letter-spacing:.04em;padding:11px 4px;cursor:pointer}
  .kt-burger{position:relative;display:block;width:22px;height:2px;background:currentColor}
  .kt-burger::before,.kt-burger::after{content:"";position:absolute;left:0;width:22px;height:2px;background:currentColor;transition:transform .2s}
  .kt-burger::before{top:-7px}
  .kt-burger::after{top:7px}
  .kt-navtoggle[aria-expanded="true"] .kt-burger{background:transparent}
  .kt-navtoggle[aria-expanded="true"] .kt-burger::before{transform:translateY(7px) rotate(45deg)}
  .kt-navtoggle[aria-expanded="true"] .kt-burger::after{transform:translateY(-7px) rotate(-45deg)}
  .ktnav{display:none;flex-direction:column;align-items:stretch;justify-content:flex-start;width:100%;gap:0;max-height:78vh;overflow-y:auto;border-top:1px solid #5a5a5a;padding-bottom:6px}
  .ktnav.is-open{display:flex}
  .ktnav li{width:100%;border-top:1px solid #5a5a5a}
  .ktnav>li:first-child{border-top:0}
  .ktnav>li>a{padding:12px 4px;text-align:center}
  .ktnav>li.has-sub>a::after{display:inline-block;margin-left:8px;transition:transform .2s;border-top-color:currentColor}
  .ktnav>li.has-sub.is-open>a::after{transform:rotate(180deg)}
  .ktnav .sub{position:static;left:auto;right:auto;min-width:0;width:100%;box-sizing:border-box;opacity:1;visibility:visible;transform:none;border:0;box-shadow:none;background:transparent;padding:0;margin:0;max-height:0;overflow:hidden;transition:max-height .28s ease;text-align:center}
  .ktnav li.has-sub:hover>.sub,.ktnav li.has-sub:focus-within>.sub{position:static;left:auto;right:auto;transform:none;width:100%;min-width:0}
  .ktnav>li.has-sub.is-open>.sub{max-height:640px;padding:4px 0 12px;background:#333333;box-shadow:inset 0 6px 8px -8px rgba(0,0,0,.6)}
  .ktnav .sub li{border-top:0;list-style:none;width:100%;margin:0;padding:0;text-align:center}
  .ktnav .sub li a{display:block;width:100%;box-sizing:border-box;margin:0;padding:11px 14px;text-align:center;text-indent:0;white-space:normal;overflow-wrap:anywhere;font-size:14px;line-height:1.35;color:$($C.onDark2)}
  .ktnav .sub li a:hover,.ktnav .sub li a:focus{background:#4a4a4a;color:#ffffff}
}
</style>
<script>
(function(){
  function init(){
    var mq=window.matchMedia('(max-width:860px)');
    var tgl=document.querySelector('.kt-navtoggle');
    var nav=document.getElementById('kt-mainnav');
    if(tgl&&nav){
      tgl.addEventListener('click',function(){
        var open=nav.classList.toggle('is-open');
        tgl.setAttribute('aria-expanded',open?'true':'false');
      });
    }
    document.querySelectorAll('.ktnav>li.has-sub>a').forEach(function(a){
      a.addEventListener('click',function(e){
        if(!mq.matches) return;
        var li=a.parentElement;
        if(li.classList.contains('is-open')) return;          // 2. Tipp: Link folgen
        e.preventDefault();
        var sibs=li.parentElement.children;
        for(var i=0;i<sibs.length;i++){ if(sibs[i]!==li) sibs[i].classList.remove('is-open'); }
        li.classList.add('is-open');
      });
    });
  }
  if(document.readyState==='loading'){ document.addEventListener('DOMContentLoaded',init); } else { init(); }
})();
</script>
"@

  $navItems = foreach ($top in $NAVTREE) {
    $node     = Nav-Node $top
    $kids     = @($top.kids | Where-Object { $_ })
    $kidNodes = @($kids | ForEach-Object { Nav-Node $_ })
    $isActive = ($activeSlug -and (($node.slug -eq $activeSlug) -or ($kidNodes.slug -contains $activeSlug)))
    $cls      = @('kt-top')
    if ($kids.Count) { $cls += 'has-sub' }
    if ($isActive)   { $cls += 'is-active' }
    $topLink  = "<a href=`"$($node.url)`">$($node.label)</a>"
    if ($kids.Count) {
      $subLis = ($kidNodes | ForEach-Object {
        $ac = if ($_.slug -and $_.slug -eq $activeSlug) { ' class="is-active"' } else { '' }
        "<li><a href=`"$($_.url)`"$ac>$($_.label)</a></li>"
      }) -join "`n            "
      "<li class=`"$($cls -join ' ')`">$topLink<ul class=`"sub`">`n            $subLis`n          </ul></li>"
    } else {
      "<li class=`"$($cls -join ' ')`">$topLink</li>"
    }
  }
  $navList = "<ul class=`"ktnav`" id=`"kt-mainnav`">`n        " + ($navItems -join "`n        ") + "`n      </ul>"

  $navBand = @"
$navCss
<nav class="kt-navwrap">
      <button class="kt-navtoggle" type="button" aria-expanded="false" aria-controls="kt-mainnav"><span class="kt-burger" aria-hidden="true"></span>Men&uuml;</button>
      $navList
</nav>
"@
  # optionaler Hinweis-Banner direkt unter dem Menue (z.B. Betriebsferien);
  # ueber $chrome.announce.enabled in pages-content.json an/aus. Nicht im Shop-Kopf.
  $announce = ''
  if ($chrome.announce -and $chrome.announce.enabled -and $chrome.announce.text) {
    $announce = "`n`n" + (Zone '#f7e6c4' '9px' '9px' (Html-Block (
      "<p style=`"max-width:$MAXW;margin:0 auto;text-align:center;font-family:$FONT_BODY;font-size:13.5px;line-height:1.5;color:#5b4a24`">$($chrome.announce.text)</p>"
    )))
  }

  # weisser Logo-Balken, direkt darunter das dunkle Menueband (wie www.kaffeetechniker.de)
  # Menueband bleibt beim Scrollen oben kleben
  (Zone '#ffffff' '16px' '16px' (Html-Block ($whiteBar + "`n" + $CART_BADGE_JS))) + "`n`n" +
  (Zone $C.dark1 '4px' '4px' (Html-Block $navBand) 'position:sticky;top:0;z-index:90') + $announce
}

# ---------- eigene Kopfzeile fuer den JURA-Shop-Bereich ----------
# Links "zurueck zur Website", nur Shop-Kategorien, Suche + Warenkorb/Konto.
$SHOP_SLUGS = @('jura','jura-kaffeevollautomaten','jura-professional','jura-zubehoer','jura-pflegeprodukte','unser-kaffee')
$SHOP_NAV = @(
  @{ label = 'JURA-Shop';           slug = 'jura' }
  @{ label = 'Kaffeevollautomaten'; slug = 'jura-kaffeevollautomaten' }
  @{ label = 'Professional';        slug = 'jura-professional' }
  @{ label = 'Zubeh&ouml;r';        slug = 'jura-zubehoer' }
  @{ label = 'Pflegeprodukte';      slug = 'jura-pflegeprodukte' }
  @{ label = 'Unser Kaffee &amp; Tee'; slug = 'unser-kaffee' }
)
$NIVONA_SHOP_SLUGS = @('nivona','nivona-kaffeevollautomaten')
$NIVONA_NAV = @(
  @{ label = 'NIVONA-Shop';         slug = 'nivona' }
  @{ label = 'Kaffeevollautomaten'; slug = 'nivona-kaffeevollautomaten' }
  @{ label = 'Zum JURA-Shop';       slug = 'jura' }
)
# gemeinsames CSS fuer die Shop-Kopfzeile
function Shop-Bar-CSS {
  @"
<style>
html{overflow-x:clip}
header.wp-block-template-part{display:contents}
.shbwrap{background:#ffffff}
.shb{max-width:$MAXW;margin:0 auto;padding:13px 24px;display:grid;grid-template-columns:1fr auto 1fr;align-items:center;gap:10px 18px;font-family:$FONT_BODY}
.shb .ph{font-size:13px;color:#333;white-space:nowrap;display:flex;flex-direction:column;gap:3px}
.shb .ph span{color:#666}
.shb .ph .tel a{color:#1f1f1f;text-decoration:none;font-weight:700;letter-spacing:.02em}
.shb .ph .bk{color:#666;text-decoration:none;font-size:12px;font-weight:400;display:inline-flex;align-items:center;gap:5px}
.shb .ph .bk:hover{color:$($C.accent);text-decoration:underline}
.shb .lg{justify-self:center;display:inline-flex}
.shb .lg img{display:block;height:52px;width:auto}
.shb .rt{justify-self:end;display:flex;align-items:center;gap:6px}
.shb form{display:flex;align-items:center}
.shb input[type=search]{width:160px;max-width:30vw;padding:7px 10px;border:1px solid #cfcfcf;border-radius:6px 0 0 6px;font-size:13px;font-family:$FONT_BODY}
.shb .sbtn{border:1px solid $($C.accent);background:$($C.accent);color:#fff;padding:7px 11px;border-radius:0 6px 6px 0;cursor:pointer;display:inline-flex}
.shb .ic{display:inline-flex;padding:6px;color:#444;text-decoration:none}
.shb .ic:hover{color:#000}
.shnav-wrap{background:$($C.dark1);position:sticky;top:0;z-index:90}
.shnav-box{max-width:$MAXW;margin:0 auto}
.shnav-toggle{display:none}
.shnav{max-width:$MAXW;margin:0 auto;display:flex;flex-wrap:wrap;align-items:center;justify-content:center;gap:2px;font-family:Tahoma,Arial,sans-serif;list-style:none;padding:0}
.shnav a{display:block;color:$($C.onDark2);font-size:14px;line-height:1.2;padding:11px 15px;text-decoration:none;white-space:nowrap}
.shnav a:hover{color:$($C.onDark)}
.shnav a.is-active{color:$($C.onDark);font-weight:700}
@media(max-width:760px){
  .shb{grid-template-columns:minmax(0,1fr);justify-items:center;row-gap:11px}
  .shb .lg{order:-1}
  .shb .lg img{height:42px}
  .shb .ph{order:1;align-items:center;text-align:center}
  .shb .rt{order:2;width:100%;justify-self:stretch;justify-content:center;flex-wrap:wrap;gap:8px}
  .shb form{flex:1 1 200px;min-width:0}
  .shb input[type=search]{flex:1;max-width:none;min-width:0}
  .shnav-toggle{display:flex;align-items:center;justify-content:center;gap:11px;width:100%;background:transparent;border:0;color:$($C.onDark);font-family:Tahoma,Arial,sans-serif;font-size:15px;font-weight:700;letter-spacing:.04em;padding:11px 4px;cursor:pointer}
  .shnav-toggle .bg{position:relative;display:block;width:22px;height:2px;background:currentColor}
  .shnav-toggle .bg::before,.shnav-toggle .bg::after{content:"";position:absolute;left:0;width:22px;height:2px;background:currentColor;transition:transform .2s}
  .shnav-toggle .bg::before{top:-7px}
  .shnav-toggle .bg::after{top:7px}
  .shnav-toggle[aria-expanded="true"] .bg{background:transparent}
  .shnav-toggle[aria-expanded="true"] .bg::before{transform:translateY(7px) rotate(45deg)}
  .shnav-toggle[aria-expanded="true"] .bg::after{transform:translateY(-7px) rotate(-45deg)}
  .shnav{display:none;flex-direction:column;align-items:stretch;width:100%;gap:0;border-top:1px solid #5a5a5a;max-height:78vh;overflow-y:auto;padding-bottom:6px}
  .shnav.is-open{display:flex}
  .shnav li{width:100%;border-top:1px solid #5a5a5a}
  .shnav li:first-child{border-top:0}
  .shnav a{padding:12px 4px;text-align:center;font-size:14px}
}
</style>
<script>
(function(){
  function init(){
    var t=document.querySelector('.shnav-toggle'), n=document.getElementById('shnav');
    if(!t||!n||t.dataset.b) return; t.dataset.b='1';
    t.addEventListener('click',function(){
      var o=n.classList.toggle('is-open');
      t.setAttribute('aria-expanded',o?'true':'false');
    });
  }
  if(document.readyState==='loading'){document.addEventListener('DOMContentLoaded',init);}else{init();}
})();
</script>
"@
}
# weisser Balken (Back-Link, Telefon, Logo, Suche, Konto/Warenkorb)
function Shop-Bar-White {
  $b = $chrome.brand
  $t = $chrome.topbar
  $homeUrl = if ($linkOf['start']) { $linkOf['start'] } else { "$base/" }
  @"
<div class="shbwrap"><div class="shb">
  <div class="ph">
    <span class="tel"><span>$($t.phoneLabel)</span> <a href="$($t.phoneUrl)">$($t.phone)</a></span>
  </div>
  <a class="lg" href="$homeUrl" aria-label="Startseite"><img src="$($b.logoUrl)" alt="$($b.logoAlt)"></a>
  <div class="rt">
    <form role="search" method="get" action="$base/">
      <input type="search" name="s" placeholder="Im Shop suchen&hellip;" aria-label="Im Shop suchen">
      <input type="hidden" name="post_type" value="product">
      <button class="sbtn" type="submit" aria-label="Suchen">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"></circle><path d="M21 21l-4.3-4.3"></path></svg>
      </button>
    </form>
    <a class="ic" href="$base/my-account/" aria-label="Mein Konto" title="Mein Konto">$ICON_USER</a>
    <a class="ic" href="$base/cart/" aria-label="Warenkorb" title="Warenkorb">$ICON_CART$CART_BADGE</a>
  </div>
</div></div>
$CART_BADGE_JS
$CATEGORY_BANNER_JS
"@
}
# <ul class="shnav"> mit den Shop-Links
function Shop-Nav-List($activeSlug) {
  $navItems = if ($NIVONA_SHOP_SLUGS -contains $activeSlug) { $NIVONA_NAV } else { $SHOP_NAV }
  $links = ($navItems | ForEach-Object {
    $u  = if ($linkOf[$_.slug]) { $linkOf[$_.slug] } else { "$base/$($_.slug)/" }
    $ac = if ($_.slug -eq $activeSlug) { ' class="is-active"' } else { '' }
    "<li><a href=`"$u`"$ac>$($_.label)</a></li>"
  }) -join "`n      "
  $hu = if ($linkOf['start']) { $linkOf['start'] } else { "$base/" }
  $homeLi = "<li><a href=`"$hu`">Start</a></li>"
  @"
<div class="shnav-box">
    <button class="shnav-toggle" type="button" aria-expanded="false" aria-controls="shnav"><span class="bg" aria-hidden="true"></span>Men&uuml;</button>
    <ul class="shnav" id="shnav">
      $homeLi
      $links
    </ul>
  </div>
"@
}
# selbsttragende Shop-Kopfzeile fuer die Theme-Vorlage 'header'
# (Produkt-/Warenkorb-/Kasse-Seiten). header.wp-block-template-part{display:contents}
# im CSS loest die Theme-Kopfzeile auf, damit .shnav-wrap die ganze Seite lang klebt.
function Shop-Bar-Html($activeSlug) {
  (Shop-Bar-CSS) + "`n" + (Shop-Bar-White) + "`n<nav class=`"shnav-wrap`">" + (Shop-Nav-List $activeSlug) + "</nav>`n"
}
function Shop-Header-Zone($activeSlug) {
  # wie Header-Zone: weisser Zone-Block + separater, KLEBENDER dunkler Zone-Block
  # (direktes Kind der langen Wrap-Page-Gruppe -> klebt die ganze Seite lang)
  $nav = "<nav style=`"max-width:$MAXW;margin:0 auto`">$(Shop-Nav-List $activeSlug)</nav>"
  (Zone '#ffffff' '0' '0' (Html-Block ((Shop-Bar-CSS) + "`n" + (Shop-Bar-White)))) + "`n`n" +
  (Zone $C.dark1 '0' '0' (Html-Block $nav) 'position:sticky;top:0;z-index:90')
}
function Pick-Header($slug) {
  if (($SHOP_SLUGS -contains $slug) -or ($NIVONA_SHOP_SLUGS -contains $slug)) { Shop-Header-Zone $slug } else { Header-Zone $slug }
}

# ---------- Zone 3: Anthrazit-Abschluss (CTA + Footer verschmolzen) ----------
function Footer-Inner-Html {
  $f   = $chrome.footer
  $addr = ($f.address -join '<br>')
  $hrs  = ($f.hours -join '<br>')
  $navLinks = ($f.navSlugs | ForEach-Object {
    $pg = $data.pages | Where-Object slug -eq $_
    "<a href=`"$($linkOf[$_])`" style=`"color:$($C.onDark2);text-decoration:none`">$($pg.menu)</a>"
  }) -join "`n          "
  $legalLinks = ($f.legalSlugs | ForEach-Object {
    $pg = $data.pages | Where-Object slug -eq $_
    "<a href=`"$($linkOf[$_])`" style=`"color:#c2c2c2;text-decoration:none;white-space:nowrap`">$($pg.menu)</a>"
  }) -join '<span style="color:#8a8a8a">&middot;</span>'
  # CTA-Block ("Haben Sie eine defekte Kaffeemaschine...") auf Nutzerwunsch entfernt
  # (2026-09-03) - war auf jeder Seite. $chrome.cta bleibt ungenutzt im JSON.
  $footHtml = @"
<div style="max-width:$MAXW;margin:0 auto;color:$($C.onDark2);font-family:$FONT_BODY;border-top:1px solid rgba(255,255,255,.16);padding-top:40px">
  <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:40px">
    <div>
      <div style="color:$($C.onDark);font-family:Tahoma,Arial,sans-serif;font-weight:700;font-size:16px;margin-bottom:10px">$($f.companyName)</div>
      <div style="font-size:14px;line-height:1.8">$addr</div>
    </div>
    <div>
      <div style="color:$($C.onDark);font-family:Tahoma,Arial,sans-serif;font-weight:700;font-size:16px;margin-bottom:10px">$($f.hoursTitle)</div>
      <div style="font-size:14px;line-height:1.8">$hrs</div>
    </div>
    <div>
      <div style="color:$($C.onDark);font-family:Tahoma,Arial,sans-serif;font-weight:700;font-size:16px;margin-bottom:10px">$($f.navTitle)</div>
      <div style="font-size:14px;line-height:1.9;display:flex;flex-direction:column">
          $navLinks
      </div>
    </div>
  </div>
  <div style="border-top:1px solid rgba(255,255,255,.16);margin-top:32px;padding-top:18px;display:flex;flex-wrap:wrap;gap:10px 18px;justify-content:space-between;align-items:center;font-size:12.5px;color:#bdbdbd">
    <span>$($f.note)</span>
    <span style="display:flex;flex-wrap:wrap;gap:8px 12px;align-items:center">$legalLinks</span>
  </div>
</div>
"@
  # schwebender WhatsApp-Button (auf jeder Seite, da Footer ueberall)
  $waMsg = 'Hallo, ich habe eine Frage zu meiner Kaffeemaschine.'
  $wa = @"
<style>
.kt-wa{position:fixed;right:16px;bottom:16px;z-index:120;display:flex;align-items:center;gap:9px;background:#25D366;color:#fff;text-decoration:none;padding:11px 16px 11px 13px;border-radius:999px;box-shadow:0 6px 20px rgba(0,0,0,.28);font-family:$FONT_HEAD;font-weight:700;font-size:14px}
.kt-wa:hover{background:#1ebe5b}
.kt-wa svg{width:22px;height:22px;flex-shrink:0}
.kt-wa span{white-space:nowrap}
@media(max-width:600px){.kt-wa{padding:12px;right:14px;bottom:14px}.kt-wa span{display:none}}
</style>
<a class="kt-wa" href="https://wa.me/4961922004363?text=$([uri]::EscapeDataString($waMsg))" target="_blank" rel="noopener" aria-label="Per WhatsApp schreiben">
<svg viewBox="0 0 24 24" fill="#fff"><path d="M12.04 2C6.58 2 2.13 6.45 2.13 11.91c0 2.1.55 4.05 1.6 5.77L2 22l4.45-1.68a9.87 9.87 0 0 0 5.59 1.73h.01c5.46 0 9.91-4.45 9.91-9.91S17.5 2 12.04 2Zm0 18.02h-.01a8.2 8.2 0 0 1-4.18-1.15l-.3-.18-2.64 1 .7-2.58-.2-.31a8.17 8.17 0 0 1-1.26-4.36c0-4.54 3.7-8.24 8.25-8.24 2.2 0 4.27.86 5.83 2.42a8.19 8.19 0 0 1 2.41 5.83c0 4.55-3.7 8.25-8.25 8.25Zm4.52-6.18c-.25-.13-1.47-.72-1.69-.8-.23-.09-.39-.13-.56.12-.16.25-.64.8-.78.97-.14.16-.29.18-.54.06-.25-.13-1.05-.39-1.99-1.23-.74-.66-1.23-1.47-1.38-1.72-.14-.25-.01-.39.11-.51.11-.11.25-.29.37-.43.12-.14.16-.25.25-.41.08-.16.04-.31-.02-.43-.06-.12-.56-1.34-.76-1.84-.2-.48-.4-.42-.56-.43-.14-.01-.31-.01-.47-.01-.16 0-.43.06-.65.31-.22.25-.86.84-.86 2.05 0 1.21.88 2.38 1 2.55.12.16 1.73 2.64 4.19 3.7.58.25 1.04.4 1.4.51.59.19 1.12.16 1.54.1.47-.07 1.47-.6 1.68-1.18.21-.58.21-1.07.14-1.18-.06-.1-.22-.16-.47-.28Z"/></svg>
<span>WhatsApp</span>
</a>
"@
  "$footHtml`n`n$wa"
}
function Footer-Zone {
  Zone $C.dark2 '48px' '36px' (Html-Block (Footer-Inner-Html))
}

# ---------- Startseite: Bausteine ----------
# zentrierter Sektionskopf: Eyebrow + Ueberschrift (Feuerwehr-Stil)
function Sec-Head($eyebrow, $title, $lead) {
  $lh = if ($lead) { "<p style=`"font-size:15px;line-height:1.6;color:#555555;max-width:560px;margin:11px auto 0`">$lead</p>" } else { '' }
  @"
<div style="text-align:center;margin:0 auto 28px;max-width:640px">
  $(Eyebrow $eyebrow)
  <h2 style="font-family:$FONT_HEAD;color:$($C.head);font-weight:700;font-size:18px;line-height:1.3;margin:0">$title</h2>
  $lh
</div>
"@
}

function Hero-Html {
  $btns = ($SD.heroButtons | ForEach-Object { Btn-Html $_.label $_.url $_.style }) -join "`n      "
  @"
<div style="max-width:720px;margin:0 auto;text-align:center;font-family:$FONT_BODY">
  $(Eyebrow $SD.heroEyebrow)
  <h1 style="font-family:$FONT_HEAD;color:$($C.head);font-weight:700;font-size:clamp(21px,2.7vw,26px);line-height:1.25;letter-spacing:-.005em;margin:0 0 14px">$($SD.heroH1)</h1>
  <p style="font-size:16px;line-height:1.62;margin:0 auto 24px;max-width:560px;color:$($C.text)">$($SD.heroP)</p>
  <div style="display:flex;gap:14px;justify-content:center;flex-wrap:wrap">
      $btns
  </div>
</div>
"@
}

function Stats-Html {
  $cells = ($SD.stats | ForEach-Object { @"
<div style="background:#ffffff;border:1px solid #e6e6e6;border-radius:5px;padding:20px 16px;text-align:center">
      <div style="font-family:$FONT_HEAD;color:$($C.head);font-weight:700;font-size:clamp(24px,3vw,30px);line-height:1">$($_.n)</div>
      <div style="font-size:12.5px;line-height:1.4;color:#666666;margin-top:7px">$($_.l)</div>
    </div>
"@ }) -join "`n    "
  @"
<div style="max-width:$SECW;margin:0 auto;display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px;font-family:$FONT_BODY">
    $cells
</div>
"@
}

function Services-Html {
  $cards = ($SD.services | ForEach-Object { @"
<a href="$base$($_.url)" style="display:flex;flex-direction:column;background:$($C.bg);border:1px solid #e2e2e2;border-radius:5px;padding:22px 24px;text-decoration:none;transition:border-color .15s">
      <span style="font-family:$FONT_HEAD;color:$($C.head);font-weight:700;font-size:16px;margin-bottom:8px">$($_.t)</span>
      <span style="font-size:14.5px;line-height:1.6;color:$($C.text);flex:1 0 auto">$($_.x)</span>
      <span style="font-family:$FONT_HEAD;color:$($C.accent);font-weight:700;font-size:12.5px;margin-top:16px">$($_.cta) &rarr;</span>
    </a>
"@ }) -join "`n    "
  @"
$(Sec-Head $SD.servicesEyebrow $SD.servicesTitle '')
<div style="max-width:$SECW;margin:0 auto;display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:14px;font-family:$FONT_BODY">
    $cards
</div>
"@
}

$MAPS_G = 'https://www.google.com/maps/dir/?api=1&destination=Wallauer%20Stra%C3%9Fe%204%2C%2065719%20Hofheim-Langenhain'
$MAPS_A = 'https://maps.apple.com/?daddr=Wallauer%20Stra%C3%9Fe%204,%2065719%20Hofheim-Langenhain&dirflg=d'

function Store-Html {
  $paras = ($SD.storeText | ForEach-Object { "<p style=`"font-size:15.5px;line-height:1.7;margin:0 0 12px;color:$($C.text)`">$_</p>" }) -join "`n      "
  $addr  = (($SD.storeAddress | ForEach-Object {
    if ($_ -match '@') { "<a href=`"mailto:$_`" style=`"color:$($C.accent);text-decoration:none`">$_</a>" }
    elseif ($_ -match 'Telefon\s*(.+)') { "Telefon <a href=`"tel:+4961922004363`" style=`"color:$($C.accent);text-decoration:none;font-weight:600`">$($matches[1])</a>" }
    else { $_ }
  }) -join '<br>')
  # Oeffnungszeiten als sauber ausgerichtetes 2-Spalten-Raster (Tag | Zeit)
  $hoursRows = ($SD.storeHours | ForEach-Object {
    if ($_ -is [string]) { "<span style=`"grid-column:1 / -1`">$_</span>" }
    else {
      $tv = if ($_.t -match '\d') { $_.t } else { "<span style=`"color:#8a8a8a`">$($_.t)</span>" }
      "<span>$($_.d)</span><span style=`"white-space:nowrap`">$tv</span>"
    }
  }) -join "`n          "
  $iconPin   = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" style="flex-shrink:0"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>'
  $iconClock = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" style="flex-shrink:0"><circle cx="12" cy="12" r="9"/><path d="M12 7.5V12l3 1.7"/></svg>'
  $badge = if ($SD.juraBadgeUrl) { "<img src=`"$($SD.juraBadgeUrl)`" alt=`"Autorisierte JURA Servicestelle und Fachh&auml;ndler`" style=`"width:112px;height:auto;display:block;flex-shrink:0`">" } else { '' }
  $bs   = "display:inline-flex;align-items:center;justify-content:center;padding:11px 20px;border-radius:5px;font-family:$FONT_HEAD;font-size:13.5px;font-weight:700;text-decoration:none"
  $btn  = "<div style=`"display:flex;flex-wrap:wrap;justify-content:center;gap:10px`">" +
          "<a href=`"$MAPS_G`" target=`"_blank`" rel=`"noopener`" style=`"$bs;background:$($C.accent);color:#fff`">Route mit Google Maps</a>" +
          "<a href=`"$MAPS_A`" target=`"_blank`" rel=`"noopener`" style=`"$bs;background:$($C.accent);color:#fff`">Route mit Apple Karten</a>" +
          "<a href=`"$base$($SD.storeButton.url)`" style=`"$bs;background:transparent;color:$($C.accent);border:1px solid #ccd1d8`">$($SD.storeButton.label)</a>" +
          "</div>"
  $img   = if ($SD.storeImageUrl) { "<img src=`"$($SD.storeImageUrl)`" alt=`"$($SD.storeImageAlt)`" style=`"width:100%;height:auto;display:block`">" } else { '' }
  @"
$(Sec-Head $SD.storeEyebrow $SD.storeTitle '')
<div style="max-width:$SECW;margin:0 auto;border:1px solid #e2e2e2;border-radius:8px;overflow:hidden;background:#ffffff;font-family:$FONT_BODY">
  $img
  <div style="padding:28px 30px">
    <div style="display:flex;gap:18px;align-items:flex-start;flex-wrap:wrap">
      <div style="flex:1 1 260px">$paras</div>
      $badge
    </div>
    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:14px;border-top:1px solid $($C.line);padding-top:22px;margin-top:22px">
      <div style="background:$($C.soft);border-radius:8px;padding:16px 20px 18px">
        <div style="display:flex;align-items:center;gap:8px;color:$($C.accent);font-family:$FONT_HEAD;font-weight:700;font-size:10.5px;letter-spacing:.11em;text-transform:uppercase;padding-bottom:9px;margin-bottom:10px;border-bottom:1px solid $($C.line)">$iconPin $($SD.storeAddrTitle)</div>
        <div style="font-size:14px;line-height:1.85;color:$($C.text)">$addr</div>
      </div>
      <div style="background:$($C.soft);border-radius:8px;padding:16px 20px 18px">
        <div style="display:flex;align-items:center;gap:8px;color:$($C.accent);font-family:$FONT_HEAD;font-weight:700;font-size:10.5px;letter-spacing:.11em;text-transform:uppercase;padding-bottom:9px;margin-bottom:10px;border-bottom:1px solid $($C.line)">$iconClock $($SD.storeHoursTitle)</div>
        <div style="display:grid;grid-template-columns:auto 1fr;gap:6px 18px;font-size:14px;line-height:1.5;color:$($C.text)">
          $hoursRows
        </div>
      </div>
    </div>
    <div style="margin-top:20px">$btn</div>
  </div>
</div>
"@
}

function Brands-Html {
  @"
$(Sec-Head $SD.brandsEyebrow $SD.brandsTitle 'Kaffeevollautomaten und Siebtr&auml;germaschinen aller g&auml;ngigen Hersteller.')
$(Brands-Grid $SD.brands)
"@
}

# Shop-Kategorien als Bild-Kacheln (Stil wie de.jura.com)
function Shop-Html {
  $tiles = ($SD.shopTiles | ForEach-Object { @"
<a href="$base$($_.url)" style="display:flex;flex-direction:column;background:#ffffff;border:1px solid #e2e2e2;border-radius:7px;overflow:hidden;text-decoration:none;transition:border-color .15s,box-shadow .15s">
      <span style="display:block;aspect-ratio:4/3;background:#f3f3f1 url('$($_.img)') center/cover no-repeat"></span>
      <span style="padding:15px 17px 17px">
        <span style="display:block;font-family:$FONT_HEAD;color:$($C.head);font-weight:700;font-size:15.5px">$($_.t)</span>
        <span style="display:block;font-size:13px;line-height:1.5;color:#666;margin-top:3px">$($_.x)</span>
        <span style="display:block;font-family:$FONT_HEAD;color:$($C.accent);font-weight:700;font-size:12px;margin-top:11px">Ansehen &rarr;</span>
      </span>
    </a>
"@ }) -join "`n    "
  @"
$(Sec-Head $SD.shopEyebrow $SD.shopTitle $SD.shopLead)
<div style="max-width:$SECW;margin:0 auto;display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:16px;font-family:$FONT_BODY">
    $tiles
</div>
"@
}

function Benefits-Html {
  $checks = ($SD.benefits | ForEach-Object { @"
<div style="display:flex;gap:12px;align-items:flex-start">
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" style="flex-shrink:0;margin-top:3px"><path d="M4 12.5L9.5 18L20 6" stroke="$($C.accent)" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/></svg>
      <span style="font-size:15px;line-height:1.6;color:$($C.text)">$_</span>
    </div>
"@ }) -join "`n    "
  @"
$(Sec-Head $SD.benefitsEyebrow $SD.benefitsTitle '')
<div style="max-width:$SECW;margin:0 auto;display:grid;grid-template-columns:repeat(auto-fit,minmax(400px,1fr));gap:18px 44px;font-family:$FONT_BODY">
    $checks
</div>
"@
}

function Contact-Html {
  $intro = if ($SD.contactIntro) { "<p style=`"font-size:15px;line-height:1.6;color:#555555;max-width:560px;margin:12px auto 24px`">$($SD.contactIntro)</p>" } else { '' }
  @"
<div style="text-align:center;margin:0 auto 6px;max-width:640px">
  $(Eyebrow $SD.contactEyebrow)
  <h2 style="font-family:$FONT_HEAD;color:$($C.head);font-weight:700;font-size:18px;line-height:1.3;margin:0">$($SD.contactTitle)</h2>
  $intro
</div>
"@
}

function Reviews-Html {
  $r = $SD.googleReviews
  if (-not $r -or -not $r.enabled) { return '' }
  $revs = @($r.reviews) | Where-Object { $_ }
  if (-not $revs.Count) { return '' }
  $cards = ($revs | ForEach-Object {
    $s = [int]$_.stars; if ($s -lt 1) { $s = 5 }
    $fill = ('&#9733;' * $s) + ('&#9734;' * (5 - $s))
    $dt = if ($_.date) { " &middot; <span>$($_.date)</span>" } else { '' }
    "<figure class=`"kt-rev`"><div class=`"kt-rev-st`">$fill</div><blockquote>$($_.text)</blockquote><figcaption>$($_.name)$dt</figcaption></figure>"
  }) -join "`n    "
  $more = if ($r.url) { "<p class=`"kt-rev-more`"><a href=`"$($r.url)`" target=`"_blank`" rel=`"noopener`">Alle Bewertungen auf Google ansehen &rarr;</a></p>" } else { '' }
  $sum = if ($r.rating) { "<div class=`"kt-rev-sum`"><span class=`"kt-rev-st big`">&#9733;&#9733;&#9733;&#9733;&#9733;</span> <b>$($r.rating)</b>$(if ($r.count) { " <span>&middot; $($r.count) Bewertungen auf Google</span>" })</div>" } else { '' }
  @"
<style>
.kt-revs{max-width:$SECW;margin:0 auto;font-family:$FONT_BODY}
.kt-rev-sum{text-align:center;margin:0 0 22px;font-size:15px;color:$($C.text)}
.kt-rev-sum b{font-family:$FONT_HEAD;font-size:17px;color:$($C.head)}
.kt-rev-sum span{color:#6b7178}
.kt-revs .kt-rev-st{color:#f5a623 !important;letter-spacing:1px;font-size:14px}
.kt-revs .kt-rev-st.big{font-size:18px}
.kt-rev-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(270px,1fr));gap:16px}
.kt-rev{margin:0;background:#fff;border:1px solid $($C.line);border-radius:10px;padding:18px 20px;display:flex;flex-direction:column}
.kt-rev blockquote{margin:9px 0 12px;font-size:14.5px;line-height:1.6;color:$($C.text)}
.kt-rev figcaption{font-family:$FONT_HEAD;font-size:13px;font-weight:700;color:$($C.head);margin-top:auto}
.kt-rev figcaption span{font-weight:400;color:#8a8a8a}
.kt-rev-more{text-align:center;margin:20px 0 0}
.kt-rev-more a{font-family:$FONT_HEAD;font-size:13.5px;font-weight:700;color:$($C.accent);text-decoration:none}
</style>
$(Sec-Head $r.eyebrow $r.title '')
<div class="kt-revs">
  $sum
  <div class="kt-rev-grid">
    $cards
  </div>
  $more
</div>
"@
}

# ---------- Startseite ----------
function Start-Content {
  # abwechselnde Sektionsbaender: weiss / soft / weiss / soft ...
  $zones = @(
    (Header-Zone 'start'),
    (Zone $C.white '44px' '34px' (Html-Block (Hero-Html))),
    (Zone $C.soft  '46px' '46px' (Html-Block (Store-Html))),
    (Zone $C.white '44px' '44px' (Html-Block (Brands-Html))),
    (Zone $C.soft  '30px' '30px' (Html-Block (Stats-Html))),
    (Zone $C.white '48px' '48px' (Html-Block (Services-Html))),
    (Zone $C.soft  '48px' '48px' (Html-Block (Shop-Html))),
    (Zone $C.white '48px' '48px' (Html-Block (Benefits-Html)))
  )
  $rev = Reviews-Html
  $contactBg = $C.soft
  if ($rev) { $zones += (Zone $C.soft '46px' '46px' (Html-Block $rev)); $contactBg = $C.white }
  $zones += (Zone $contactBg '48px' '52px' ((Html-Block (Contact-Html)) + "`n`n" + (Form-Block)))
  $zones += (Footer-Zone)
  Wrap-Page ($zones -join "`n`n")
}

# ================= JURA Online-Shop: Markenseite + Kategorieseite =================
# Geraete kommen live aus WooCommerce (Kategorie-Slug 'jura-kaffeevollautomaten').
function Jura-Products($catSlug = 'jura-kaffeevollautomaten') {
  # Hinweis: PS 5.1 gibt eine JSON-Array-Antwort als EIN [object[]] zurueck;
  # daher erst in Variable, dann @() - nicht @(wc ...) direkt (kollabiert auf 1).
  $catResp = wc GET "products/categories?slug=$catSlug"
  $cat = @($catResp)[0]
  if (-not $cat) { return @() }
  $itemsResp = wc GET "products?per_page=100&status=publish&category=$($cat.id)"
  $items = @($itemsResp)
  if ($items.Count -eq 1 -and $items[0].Count -gt 1) { $items = @($items[0]) }
  # helle Farbe zuerst, "Black" zuletzt - damit die Uebersicht nicht nur schwarz ist
  $farbRank = {
    param($n)
    if ($n -match 'White|Weiss|Weiß') { 0 }
    elseif ($n -match 'Inox|Silver|Silber|Grey|Grau|Alu|Chrome|Metropolitan') { 1 }
    elseif ($n -match 'Black|Schwarz|Onyx|Obsidian') { 3 }
    else { 2 }
  }
  $items | ForEach-Object {
    $serie = (($_.attributes | Where-Object { $_.name -eq 'Serie' }).options | Select-Object -First 1)
    $farben = @(($_.attributes | Where-Object { $_.name -eq 'Farbe' }).options)
    $isVar = ($_.type -eq 'variable')
    $pnum  = ($_.regular_price -as [decimal])
    if ((-not $pnum -or $pnum -le 0) -and $_.price) { $pnum = ($_.price -as [decimal]) }
    $de    = [Globalization.CultureInfo]::GetCultureInfo('de-DE')
    $pstr  = if ($pnum -and $pnum -gt 0) {
               $f = ([decimal]$pnum).ToString('N2', $de) + ' &euro;'
               if ($isVar) { "ab $f" } else { $f }
             } else { 'Preis auf Anfrage' }
    $mainImg = if ($_.images -and $_.images[0]) { $_.images[0].src } else { '' }

    # Farbvarianten (color -> Bild)
    $variants = @()
    if ($isVar) {
      $vResp = wc GET "products/$($_.id)/variations?per_page=30"
      $vs = @($vResp); if ($vs.Count -eq 1 -and $vs[0].Count -gt 1) { $vs = @($vs[0]) }
      foreach ($v in $vs) {
        $vc = ($v.attributes | Where-Object { $_.name -eq 'Farbe' }).option
        if ($vc) {
          $variants += [pscustomobject]@{ color = "$vc"; img = if ($v.image -and $v.image.src) { $v.image.src } else { $mainImg } }
        }
      }
    }
    if (-not $variants -or $variants.Count -eq 0) {
      $c0 = if ($farben.Count -ge 1) { $farben[0] } else { '' }
      $variants = @([pscustomobject]@{ color = "$c0"; img = $mainImg })
    }
    # nach Helligkeit sortieren, hellstes zuerst -> Standardbild
    $variants = @($variants | Sort-Object @{ Expression = { & $farbRank $_.color } }, color)
    $displayImg = if ($variants[0].img) { $variants[0].img } else { $mainImg }

    [pscustomobject]@{
      name       = $_.name
      sku        = "$($_.sku)"
      serie      = if ($serie) { "$serie" } else { '' }
      art        = (($_.attributes | Where-Object { $_.name -eq 'Art' }).options | Select-Object -First 1)
      price      = if ($pnum) { $pnum } else { [decimal]0 }
      priceStr   = $pstr
      url        = $_.permalink
      img        = $mainImg
      displayImg = $displayImg
      farben     = $farben
      variants   = $variants
    }
  } | Sort-Object price
}

$JURA_CSS = @"
<style>
.jstore{max-width:$MAXW;margin:0 auto;font-family:$FONT_BODY;color:$($C.text)}
.jstore h1,.jstore h2,.jstore h3{font-family:$FONT_HEAD;color:$($C.head);font-weight:700;line-height:1.3;margin:0;padding:0;border:0}
.jwm{font-family:$FONT_HEAD;font-weight:700;letter-spacing:.32em;font-size:24px !important;color:$($C.head);text-align:center;margin:0 0 18px;padding-left:.32em}
.jlogo{display:block;margin:0 auto 20px;height:34px;width:auto}
.jherofig{max-width:900px;margin:0 auto 34px;border-radius:8px;overflow:hidden;border:1px solid #e2e2e2}
.jherofig img{display:block;width:100%;height:auto;aspect-ratio:21/9;object-fit:cover}
.jhero{max-width:640px;margin:0 auto;text-align:center}
.jhero h1{font-size:20px !important;line-height:1.3 !important;margin:0 0 12px}
.jhero p{font-size:15.5px;line-height:1.62;color:$($C.text);margin:0 auto 22px;max-width:560px}
.jhero .jbtns{display:flex;gap:13px;justify-content:center;flex-wrap:wrap}
.jbanner{max-width:900px;margin:0 auto;display:grid;grid-template-columns:1fr auto;gap:22px;align-items:center;background:#ffffff;border:1px solid #e2e2e2;border-left:3px solid $($C.accent);border-radius:6px;padding:22px 26px}
.jbanner h2{font-size:15px !important;margin:0 0 6px}
.jbanner p{font-size:14.5px;line-height:1.6;color:$($C.text);margin:0}
.jabout{max-width:760px;margin:0 auto;display:grid;grid-template-columns:1fr 1fr;gap:26px}
.jabout p{font-size:15px;line-height:1.7;margin:0;color:$($C.text)}
.jcats{max-width:960px;margin:0 auto;display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:14px}
.jcat{display:flex;flex-direction:column;background:#ffffff;border:1px solid #e2e2e2;border-radius:7px;overflow:hidden;text-decoration:none}
.jcat>.pic{display:block;aspect-ratio:4/3;background:#f3f3f1 center/cover no-repeat}
.jcat>.bd{display:flex;flex-direction:column;flex:1;padding:15px 17px 17px}
.jcat .bd b{font-family:$FONT_HEAD;color:$($C.head);font-size:15px;margin-bottom:6px}
.jcat .bd .tx{font-size:13.5px;line-height:1.55;color:$($C.text);flex:1}
.jcat .bd em{font-style:normal;font-family:$FONT_HEAD;color:$($C.accent);font-weight:700;font-size:12px;margin-top:12px}
.jtech{max-width:960px;margin:0 auto;display:grid;grid-template-columns:repeat(auto-fit,minmax(258px,1fr));gap:16px}
.jtc{background:#ffffff;border:1px solid #e2e2e2;border-radius:7px;overflow:hidden}
.jtc .vid{position:relative;aspect-ratio:16/9;background:#000;cursor:pointer}
.jtc .vid img{width:100%;height:100%;object-fit:cover;display:block}
.jtc .vid .pl{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;transition:opacity .15s}
.jtc .vid:hover .pl{opacity:.82}
.jtc .vid .pl svg{width:52px;height:38px;filter:drop-shadow(0 2px 6px rgba(0,0,0,.4))}
.jtc .vid iframe{position:absolute;inset:0;width:100%;height:100%;border:0}
.jtc .bd{padding:14px 16px 16px}
.jtc b{font-family:$FONT_HEAD;color:$($C.head);font-size:13.5px;display:block;margin-bottom:4px}
.jtc span{font-size:12.5px;line-height:1.55;color:#555}
.jnote{max-width:760px;margin:20px auto 0;font-size:12px;line-height:1.6;color:#888;text-align:center}
.jkat h1{font-size:20px !important;line-height:1.3 !important;margin:0 0 8px}
.jkat .crumb{font-size:12px;color:#8a8a8a;margin:0 0 14px}
.jkat .crumb a{color:#8a8a8a;text-decoration:none}
.jkat .lead{font-size:15.5px;line-height:1.65;color:$($C.text);max-width:720px;margin:0 0 26px}
.jfilter{max-width:$MAXW;margin:0 auto 18px;display:flex;flex-wrap:wrap;gap:8px;align-items:center}
.jfilter .lbl{font-family:$FONT_HEAD;font-size:11px;letter-spacing:.1em;text-transform:uppercase;color:#8a8a8a;margin-right:4px}
.jchip{font-family:$FONT_BODY;font-size:13px;padding:7px 13px;border:1px solid #cfcfcf;border-radius:999px;background:#fff;color:#555;cursor:pointer}
.jchip.on{background:$($C.accent);border-color:$($C.accent);color:#fff}
.jslbl{max-width:$MAXW;margin:0 auto 8px;font-family:$FONT_HEAD;font-size:11px;letter-spacing:.1em;text-transform:uppercase;color:#8a8a8a}
.jseries{max-width:$MAXW;margin:0 auto 24px;display:flex;gap:10px;flex-wrap:wrap}
.jserie{flex:0 0 auto;width:106px;border:1px solid #d8d8d8;border-radius:9px;background:#fff;padding:9px 8px 8px;cursor:pointer;font-family:$FONT_BODY;transition:border-color .12s,box-shadow .12s}
.jserie:hover{border-color:#b0b0b0}
.jserie.is-on{border-color:$($C.accent);box-shadow:inset 0 0 0 2px $($C.accent)}
.jserie img{width:100%;height:62px;object-fit:contain;display:block;margin-bottom:5px}
.jserie b{display:block;font-family:$FONT_HEAD;font-size:12.5px;color:$($C.head);text-align:center}
.jserie small{display:block;font-size:10px;color:#999;text-align:center;margin-top:1px}
.jserie.jserie-all{display:flex;flex-direction:column;align-items:center;justify-content:center;min-height:104px}
.jgrid{max-width:$MAXW;margin:0 auto;display:grid;grid-template-columns:repeat(auto-fill,minmax(216px,1fr));gap:16px}
.jprod{display:flex;flex-direction:column;background:#fff;border:1px solid #e4e4e4;border-radius:6px;overflow:hidden;cursor:pointer;transition:border-color .12s,box-shadow .12s}
.jprod:hover{border-color:$($C.accent);box-shadow:0 2px 14px rgba(0,0,0,.08)}
.jprod .pic img{transition:transform .18s}
.jprod:hover .pic img{transform:scale(1.03)}
.jprod .pic{background:#fff;height:196px;display:flex;align-items:center;justify-content:center;padding:16px;border-bottom:1px solid #eee}
.jprod .pic img{max-width:100%;max-height:100%;object-fit:contain}
.jprod .body{padding:13px 15px;display:flex;flex-direction:column;flex:1}
.jprod .serie{font-family:$FONT_HEAD;font-size:10px;letter-spacing:.1em;text-transform:uppercase;color:$($C.accent);font-weight:700}
.jprod h3{font-size:14px !important;line-height:1.3 !important;margin:4px 0 6px}
.jprod .jfarb{font-size:11px;line-height:1.4;color:#8a8a8a;margin:0 0 8px}
.jprod .price{font-family:$FONT_HEAD;color:$($C.head);font-size:15px;font-weight:700;margin-top:auto}
.jprod .row{display:flex;align-items:center;justify-content:space-between;margin-top:11px;gap:8px}
.jprod .row a{font-family:$FONT_HEAD;font-size:12.5px;font-weight:700;color:$($C.accent);text-decoration:none;white-space:nowrap}
.jprod .cmp{font-size:11.5px;color:#777;display:flex;align-items:center;gap:5px;cursor:pointer;user-select:none}
.jbar{position:fixed;left:0;right:0;bottom:0;background:$($C.dark2);color:#fff;transform:translateY(110%);transition:transform .2s;z-index:80}
.jbar.show{transform:translateY(0)}
.jbar .inner{max-width:$MAXW;margin:0 auto;padding:12px 24px;display:flex;align-items:center;gap:14px;flex-wrap:wrap;font-family:$FONT_BODY;font-size:13px}
.jbar button{font-family:$FONT_HEAD;font-weight:700;font-size:13px;padding:9px 16px;border-radius:3px;border:0;cursor:pointer}
.jbar .go{background:$($C.accent);color:#fff}
.jbar .clr{background:transparent;color:#c9c9c9;text-decoration:underline}
.jmodal{position:fixed;inset:0;background:rgba(0,0,0,.55);display:none;z-index:90;padding:20px;overflow:auto}
.jmodal.show{display:block}
.jmodal .box{max-width:900px;margin:16px auto;background:#fff;border-radius:8px;padding:24px}
.jmodal h2{font-size:16px !important;line-height:1.3 !important;margin:0 0 14px}
.jmodal .tblwrap{overflow-x:auto}
.jmodal table{width:100%;border-collapse:collapse;font-size:13.5px}
.jmodal th,.jmodal td{text-align:left;padding:9px 12px;border-bottom:1px solid #eee;vertical-align:top}
.jmodal th{font-family:$FONT_HEAD;color:#8a8a8a;font-size:11px;text-transform:uppercase;letter-spacing:.06em;width:110px}
.jmodal .close{float:right;cursor:pointer;color:#999;font-size:22px;line-height:1}
/* Kategorie 2026: Serien-Karten oben, klebende Filterleiste, 2er-Grid */
.jk2{max-width:$MAXW;margin:0 auto;font-family:$FONT_BODY}
.jk2-series{display:flex;flex-wrap:wrap;justify-content:center;gap:8px;margin:0 auto 4px;max-width:1000px}
.jk2-serie{flex:0 0 auto;width:112px;display:flex;flex-direction:column;align-items:center;gap:3px;padding:11px 5px 9px;background:#fff;border:1px solid #e2e2e2;border-radius:8px;text-decoration:none;cursor:pointer;transition:border-color .12s,box-shadow .12s}
.jk2-serie:hover{border-color:#b6b6b6}
.jk2-serie.is-on{border-color:$($C.accent);box-shadow:inset 0 0 0 2px $($C.accent)}
.jk2-serie .pic{width:100%;height:44px;background:center center no-repeat;background-size:contain}
.jk2-serie b{font-family:$FONT_HEAD;font-size:12px;color:$($C.head)}
.jk2-serie i{font-style:normal;font-size:9.5px;color:#9a9a9a}
.jk2-bar{position:sticky;top:40px;z-index:60;display:flex;flex-wrap:wrap;align-items:center;justify-content:center;gap:10px 22px;background:$($C.bg);border-top:1px solid #e2e2e2;border-bottom:1px solid #e2e2e2;padding:11px 2px;margin:16px 0 22px}
.jk2-bar .grp{display:flex;align-items:center;gap:7px;flex-wrap:wrap}
.jk2-bar .lbl{font-family:$FONT_HEAD;font-size:9.5px;letter-spacing:.11em;text-transform:uppercase;color:#8a8a8a}
.jk2-bar select{padding:7px 9px;border:1px solid #cfcfcf;border-radius:6px;font-size:12.5px;font-family:$FONT_BODY;background:#fff}
.jk2-chip,.jk2-feat{font-size:12px;padding:5px 11px;border:1px solid #cfcfcf;border-radius:999px;background:#fff;color:#555;cursor:pointer;font-family:$FONT_BODY}
.jk2-chip.is-on,.jk2-feat.is-on{background:$($C.accent);border-color:$($C.accent);color:#fff}
.jk2-fdot{width:19px;height:19px;border-radius:50%;border:1px solid rgba(0,0,0,.28);cursor:pointer;padding:0}
.jk2-fdot.is-on{box-shadow:0 0 0 2px $($C.bg),0 0 0 4px $($C.accent)}
.jk2-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px}
@media(max-width:680px){.jk2-grid{grid-template-columns:1fr}}
.jp2{display:grid;grid-template-columns:186px minmax(0,1fr);background:#fff;border:1px solid #e2e2e2;border-radius:10px;overflow:hidden}
.jp2.is-hidden{display:none}
.jp2-pic{background:#fafafa;display:flex;align-items:center;justify-content:center;padding:15px;border-right:1px solid #eee}
.jp2-pic img{max-width:100%;max-height:196px;object-fit:contain}
.jp2-bd{padding:15px 17px 16px;display:flex;flex-direction:column;min-width:0}
.jp2-serie{font-family:$FONT_HEAD;font-size:10px;letter-spacing:.1em;text-transform:uppercase;color:$($C.accent);font-weight:700}
.jp2-bd h3{font-size:16px !important;line-height:1.25 !important;margin:3px 0 6px;color:$($C.head)}
.jp2-fx{list-style:none;margin:0 0 9px;padding:0;display:flex;flex-wrap:wrap;gap:5px 6px}
.jp2-fx li{font-size:11px;line-height:1;color:#4a4a4a;background:$($C.soft);border-radius:4px;padding:5px 8px;font-family:$FONT_BODY;white-space:nowrap}
.jp2-tx{font-size:12.5px;line-height:1.5;color:#6b6b6b;margin:0 0 10px}
.jp2-sw{display:flex;gap:7px;flex-wrap:wrap;margin:0 0 12px}
.jp2-sw button{width:18px;height:18px;border-radius:50%;border:1px solid rgba(0,0,0,.28);cursor:pointer;padding:0}
.jp2-sw button.is-on{box-shadow:0 0 0 2px #fff,0 0 0 4px $($C.accent)}
.jp2-price{font-family:$FONT_HEAD;font-weight:700;font-size:15.5px;color:$($C.head);margin-top:auto}
.jp2-row{display:flex;align-items:center;justify-content:space-between;gap:10px;margin-top:9px}
.jp2-row a{font-family:$FONT_HEAD;font-size:12.5px;font-weight:700;color:$($C.accent);text-decoration:none;white-space:nowrap}
.jp2-row .cmp{font-size:11.5px;color:#777;display:flex;gap:5px;align-items:center;cursor:pointer;user-select:none}
@media(max-width:520px){.jp2{grid-template-columns:1fr}.jp2-pic{border-right:0;border-bottom:1px solid #eee}}
.jk2-empty{padding:40px 10px;text-align:center;color:#8a8a8a;font-size:14px}
@media(max-width:640px){.jabout{grid-template-columns:1fr}.jbanner{grid-template-columns:1fr}}
</style>
"@

function Shop-Promo-Html {
  $pr = $chrome.shopPromo
  if (-not $pr -or -not $pr.enabled) { return '' }
  $btn = if ($pr.btnLabel) { "<a class=`"ktp-btn`" href=`"$base$($pr.btnUrl)`">$($pr.btnLabel)</a>" } else { '' }
  $eyebrow = if ($pr.eyebrow) { "<span class=`"ktp-eyebrow`">$($pr.eyebrow)</span>" } else { '' }
  $media = if ($pr.video) {
    "<div class=`"ktp-vid`" data-yt=`"$($pr.video)`" role=`"button`" tabindex=`"0`" aria-label=`"Video abspielen`"><img src=`"https://i.ytimg.com/vi/$($pr.video)/hqdefault.jpg`" alt=`"`" loading=`"lazy`"><span class=`"ktp-play`"><svg viewBox=`"0 0 68 48`" xmlns=`"http://www.w3.org/2000/svg`"><path d=`"M66.5 7.7c-.8-2.9-3-5.2-6-6C55.4.9 34 .9 34 .9S12.6.9 7.5 1.7c-3 .8-5.2 3.1-6 6C.7 12.8.7 24 .7 24s0 11.2.8 16.3c.8 2.9 3 5.2 6 6C12.6 47 34 47 34 47s21.4 0 26.5-.8c3-.8 5.2-3.1 6-6 .8-5.1.8-16.2.8-16.2s0-11.2-.8-16.3z`" fill=`"#f00`"/><path d=`"M27 34l18-10L27 14v20z`" fill=`"#fff`"/></svg></span></div>"
  } elseif ($pr.image) {
    "<div class=`"ktp-img`" style=`"background-image:url('$($pr.image)')`" role=`"img`" aria-label=`"$($pr.title)`"></div>"
  } else { '' }
  $grid = if ($media) { 'grid-template-columns:1.15fr .85fr' } else { 'grid-template-columns:1fr' }
  @"
<style>
.ktp{max-width:$MAXW;margin:0 auto;display:grid;$grid;background:$($C.dark1);color:#fff;border-radius:10px;overflow:hidden;font-family:$FONT_BODY}
.ktp-txt{padding:24px 30px;display:flex;flex-direction:column;justify-content:center}
.ktp-eyebrow{font-family:$FONT_HEAD;font-size:11px;font-weight:700;letter-spacing:.1em;text-transform:uppercase;color:#c9c9c9;margin:0 0 7px}
.ktp h2{font-family:$FONT_HEAD;font-size:19px;line-height:1.25;margin:0 0 8px;color:#fff}
.ktp p{font-size:14.5px;line-height:1.6;color:#e4e4e4;margin:0 0 16px;max-width:440px}
.ktp-btn{align-self:flex-start;display:inline-block;background:#fff;color:$($C.head);border-radius:5px;padding:10px 20px;font-family:$FONT_HEAD;font-size:13.5px;font-weight:700;text-decoration:none}
.ktp-btn:hover{background:#efefef}
.ktp-img,.ktp-vid{min-height:200px;background:#000 center/cover no-repeat;position:relative;cursor:pointer}
.ktp-vid img{width:100%;height:100%;object-fit:cover;display:block;position:absolute;inset:0}
.ktp-vid iframe{width:100%;height:100%;border:0;display:block}
.ktp-play{position:absolute;inset:0;display:flex;align-items:center;justify-content:center}
.ktp-play svg{width:60px;height:42px;filter:drop-shadow(0 2px 8px rgba(0,0,0,.45))}
@media(max-width:640px){.ktp{grid-template-columns:1fr}.ktp-img,.ktp-vid{min-height:180px;order:-1}}
</style>
<div class="ktp">
  <div class="ktp-txt">$eyebrow<h2>$($pr.title)</h2><p>$($pr.text)</p>$btn</div>
  $media
</div>
<script>
(function(){var v=document.querySelector('.ktp-vid');if(!v||v.dataset.b)return;v.dataset.b=1;function go(){var id=v.getAttribute('data-yt');if(!id)return;v.innerHTML='<iframe src="https://www.youtube-nocookie.com/embed/'+id+'?autoplay=1&rel=0" title="Video" allow="autoplay; encrypted-media; picture-in-picture" allowfullscreen></iframe>';}v.addEventListener('click',go);v.addEventListener('keydown',function(e){if(e.key==='Enter'||e.key===' '){e.preventDefault();go();}});})();
</script>
"@
}

function Jura-Marke-Content($p, $brandKey = 'jura') {
  $J = $data.$brandKey
  $bn = $J.brandName
  $btns = ($J.heroButtons | ForEach-Object { Btn-Html $_.label "$base$($_.url)" $_.style }) -join "`n      "
  $mark = if ($J.logoUrl) { "<img class=`"jlogo`" src=`"$($J.logoUrl)`" alt=`"$bn`">" } else { "<p class=`"jwm`">$($J.wordmark)</p>" }
  $herofig = if ($J.heroImage) { "<figure class=`"jstore jherofig`"><img src=`"$($J.heroImage)`" alt=`"$bn Kaffeevollautomaten`"></figure>" } else { '' }
  $hero = @"
<div class="jstore">
  $mark
  <div class="jhero">
    $(Eyebrow $J.heroEyebrow)
    <h1>$($J.heroTitle)</h1>
  </div>
</div>
$herofig
"@
  # Vier Genusswelten (offizieller JURA-Markenbegriff), Bilder + Texte von
  # de.jura.com/de/einkaufsberatung/genusswelten. Nur bei JURA, nicht bei NIVONA.
  # Jede Kachel verlinkt in die Kategorie mit vorgewaehltem Genusswelten-Filter.
  $genussTiles = if ($brandKey -eq 'jura') {
    $gw = @(
      @{ k='hot';   t='Hot Brew';   x='Intensiver Espresso in Barista-Qualit&auml;t dank Puls-Extraktionsprozess P.E.P.&reg;, dazu klassischer Kaffee und vollmundige Lungo-Spezialit&auml;ten.'; img='https://de.jura.com/-/media/global/images/why-jura/genusswelten/Genusswelten_Range_HotBrew_1600x1200.jpg?mw=600' }
      @{ k='light'; t='Light Brew'; x='Bei rund 60&nbsp;&deg;C gebr&uuml;ht und mit weniger Kaffeepulver als Hot Brew &ndash; luftig-leicht, aromatisch mild und sofort trinkbereit.'; img='https://de.jura.com/-/media/global/images/why-jura/genusswelten/Genusswelten_Range_LightBrew_1600x1200.jpg?mw=600' }
      @{ k='cold';  t='Cold Brew';  x='Der Cold Extraction Process br&uuml;ht mit kaltem Wasser unter hohem Druck: erfrischend fruchtig, ganz ohne Bitterstoffe.'; img='https://de.jura.com/-/media/global/images/why-jura/genusswelten/Genusswelten_Range_ColdBrew_1600x1200.jpg?mw=600' }
      @{ k='sweet'; t='Sweet Foam'; x='Die Sweet-Foam-Funktion aromatisiert den Milchschaum direkt bei der Zubereitung mit Sirup nach Wahl.'; img='https://de.jura.com/-/media/global/images/why-jura/genusswelten/Genusswelten_Range_SweetFoam_1600x1200.jpg?mw=600' }
    )
    $gwTiles = ($gw | ForEach-Object {
      "<a class=`"jcat`" href=`"$base/$($J.katHeaderSlug)/?genuss=$($_.k)`"><span class=`"pic`" style=`"background-image:url('$($_.img)')`"></span><span class=`"bd`"><b>$($_.t)</b><span class=`"tx`">$($_.x)</span><em>Passende Modelle &rarr;</em></span></a>"
    }) -join "`n    "
    @"
$(Sec-Head 'Genusswelten' 'Vier Genusswelten von JURA' 'Von intensivem Espresso bis erfrischendem Cold Brew &ndash; jede Genusswelt steht f&uuml;r ein eigenes Geschmackserlebnis.')
<div class="jstore"><div class="jcats">
    $gwTiles
</div></div>
"@
  } else { '' }

  $banner = @"
<div class="jstore"><div class="jbanner">
  <div><h2>$($J.banner.title)</h2><p>$($J.banner.text)</p></div>
  <div>$(Btn-Html $J.banner.ctaLabel "$base$($J.banner.ctaUrl)" 'outline')</div>
</div></div>
"@
  $about = @"
$(Sec-Head $bn $J.aboutTitle '')
<div class="jstore"><div class="jabout">
  $(($J.about | ForEach-Object { "<p>$_</p>" }) -join "`n  ")
</div></div>
"@
  $cats = ($J.categories | ForEach-Object {
    $pic = if ($_.img) { "<span class=`"pic`" style=`"background-image:url('$($_.img)')`"></span>" } else { '' }
    "<a class=`"jcat`" href=`"$base$($_.url)`">$pic<span class=`"bd`"><b>$($_.t)</b><span class=`"tx`">$($_.x)</span><em>$($_.cta) &rarr;</em></span></a>"
  }) -join "`n    "
  $catsHtml = @"
$(Sec-Head $J.categoriesTitle 'Was Sie bei uns bekommen' '')
<div class="jstore"><div class="jcats">
    $cats
</div></div>
<div class="jstore"><div class="jhero" style="margin-top:30px">
    <p>$($J.heroText)</p>
    <div class="jbtns">
      $btns
    </div>
</div></div>
"@
  $tech = ($J.tech | ForEach-Object {
    $y = $_.yt
    if ($y) {
@"
<div class="jtc">
  <div class="vid" data-yt="$y" role="button" tabindex="0" aria-label="Video abspielen">
    <img src="https://i.ytimg.com/vi/$y/hqdefault.jpg" alt="$($_.t)" loading="lazy">
    <span class="pl"><svg viewBox="0 0 68 48" xmlns="http://www.w3.org/2000/svg"><path d="M66.5 7.7c-.8-2.9-3-5.2-6-6C55.4.9 34 .9 34 .9S12.6.9 7.5 1.7c-3 .8-5.2 3.1-6 6C.7 12.8.7 24 .7 24s0 11.2.8 16.3c.8 2.9 3 5.2 6 6C12.6 47 34 47 34 47s21.4 0 26.5-.8c3-.8 5.2-3.1 6-6 .8-5.1.8-16.2.8-16.2s0-11.2-.8-16.3z" fill="#f00"/><path d="M27 34l18-10L27 14v20z" fill="#fff"/></svg></span>
  </div>
  <div class="bd"><b>$($_.t)</b><span>$($_.x)</span></div>
</div>
"@
    } else {
      "<div class=`"jtc`"><div class=`"bd`"><b>$($_.t)</b><span>$($_.x)</span></div></div>"
    }
  }) -join "`n    "
  $techJs = @'
<script>
(function(){
  document.querySelectorAll('.jtc .vid').forEach(function(v){
    function go(){var id=v.getAttribute('data-yt');if(!id)return;v.innerHTML='<iframe src="https://www.youtube-nocookie.com/embed/'+id+'?autoplay=1&rel=0" title="JURA Schluesseltechnologie" allow="autoplay; encrypted-media; picture-in-picture" allowfullscreen></iframe>';}
    v.addEventListener('click',go);
    v.addEventListener('keydown',function(e){if(e.key==='Enter'||e.key===' '){e.preventDefault();go();}});
  });
})();
</script>
'@
  $techHtml = @"
$(Sec-Head 'Technik' $J.techTitle $J.techIntro)
<div class="jstore"><div class="jtech">
    $tech
</div>
<p class="jnote">$($J.footerNote)</p></div>
$techJs
"@
  $zones = @( (Shop-Header-Zone $J.shopSlug) )
  $promo = if ($brandKey -eq 'jura') { Shop-Promo-Html } else { '' }
  if ($promo) { $zones += (Zone $C.bg '22px' '2px' (Html-Block $promo)) }
  $zones += (Zone $C.white '46px' '34px' (Html-Block ($JURA_CSS + "`n" + $hero)))
  if ($genussTiles) { $zones += (Zone $C.soft '40px' '44px' (Html-Block $genussTiles)) }
  $zones += (Zone $C.white '40px' '44px' (Html-Block $catsHtml))
  $zones += (Zone $C.soft  '42px' '34px' (Html-Block $banner))
  $zones += (Zone $C.white '44px' '44px' (Html-Block $about))
  $zones += (Zone $C.soft  '46px' '52px' (Html-Block $techHtml))
  $zones += (Footer-Zone)
  Wrap-Page ($zones -join "`n`n")
}

$JURA_KAT_JS = @'
<script>
(function(){
  var grid=document.getElementById('jk2grid'); if(!grid) return;
  var cards=[].slice.call(grid.querySelectorAll('.jp2'));
  var origOrder=cards.slice();
  var serTiles=[].slice.call(document.querySelectorAll('#jk2series .jk2-serie'));
  var serChips=[].slice.call(document.querySelectorAll('#jk2bar .jk2-chip'));
  var fdots=[].slice.call(document.querySelectorAll('#jk2bar .jk2-fdot'));
  var featBtns=[].slice.call(document.querySelectorAll('#jk2bar .jk2-feat[data-f]'));
  var genussBtns=[].slice.call(document.querySelectorAll('#jk2bar .jk2-feat[data-g]'));
  var sortSel=document.getElementById('jsort');
  var emptyMsg=document.getElementById('jk2empty');
  var activeSerie='*';
  var activeFarben=[];
  var activeFeat=[];
  var activeGenuss=[];

  grid.addEventListener('click',function(e){
    if(e.target.closest('a,input,label,button,.cmp')) return;
    var c=e.target.closest('.jp2'); if(!c) return;
    var u=c.getAttribute('data-url'); if(u) location.href=u;
  });

  function apply(){
    var vis=0;
    cards.forEach(function(c){
      var okS=(activeSerie==='*'||c.getAttribute('data-s')===activeSerie);
      var f=(c.getAttribute('data-farben')||'').split('|');
      var okF=(!activeFarben.length||activeFarben.some(function(x){return f.indexOf(x)>-1;}));
      var ft=(c.getAttribute('data-feat')||'').split(' ');
      var okA=(!activeFeat.length||activeFeat.every(function(x){return ft.indexOf(x)>-1;}));
      var gt=(c.getAttribute('data-genuss')||'').split(' ');
      var okG=(!activeGenuss.length||activeGenuss.every(function(x){return gt.indexOf(x)>-1;}));
      var show=okS && okF && okA && okG;
      c.classList.toggle('is-hidden',!show);
      if(show) vis++;
    });
    if(emptyMsg) emptyMsg.hidden=(vis>0);
  }
  function setSerie(s){
    activeSerie=s;
    serTiles.forEach(function(t){ t.classList.toggle('is-on',t.getAttribute('data-s')===s); });
    serChips.forEach(function(t){ t.classList.toggle('is-on',t.getAttribute('data-s')===s); });
    apply();
  }
  serTiles.forEach(function(t){ t.addEventListener('click',function(e){ e.preventDefault(); setSerie(t.getAttribute('data-s')); grid.scrollIntoView({behavior:'smooth',block:'start'}); }); });
  serChips.forEach(function(t){ t.addEventListener('click',function(){ setSerie(t.getAttribute('data-s')); }); });

  fdots.forEach(function(d){
    d.addEventListener('click',function(){
      var c=d.getAttribute('data-c'), i=activeFarben.indexOf(c);
      if(i>-1) activeFarben.splice(i,1); else activeFarben.push(c);
      d.classList.toggle('is-on',activeFarben.indexOf(c)>-1);
      apply();
    });
  });
  featBtns.forEach(function(b){
    b.addEventListener('click',function(){
      var k=b.getAttribute('data-f'), i=activeFeat.indexOf(k);
      if(i>-1) activeFeat.splice(i,1); else activeFeat.push(k);
      b.classList.toggle('is-on',activeFeat.indexOf(k)>-1);
      apply();
    });
  });
  genussBtns.forEach(function(b){
    b.addEventListener('click',function(){
      var k=b.getAttribute('data-g'), i=activeGenuss.indexOf(k);
      if(i>-1) activeGenuss.splice(i,1); else activeGenuss.push(k);
      b.classList.toggle('is-on',activeGenuss.indexOf(k)>-1);
      apply();
    });
  });
  // Vorauswahl per Link von der Genusswelten-Erklaerung auf /jura/ (?genuss=cold)
  (function(){
    var q=(new URLSearchParams(location.search)).get('genuss'); if(!q) return;
    var b=genussBtns.filter(function(x){return x.getAttribute('data-g')===q;})[0]; if(!b) return;
    activeGenuss.push(q); b.classList.add('is-on'); apply();
    grid.scrollIntoView({behavior:'smooth',block:'start'});
  })();

  function applySort(){
    var m=sortSel.value;
    var arr=cards.slice();
    if(m==='asc'||m==='desc'){
      arr.sort(function(a,b){
        var pa=+a.getAttribute('data-pnum')||0, pb=+b.getAttribute('data-pnum')||0;
        if(!pa) pa=(m==='asc')?9e9:-1; if(!pb) pb=(m==='asc')?9e9:-1;
        return (m==='asc')?pa-pb:pb-pa;
      });
    } else if(m==='az'){
      arr.sort(function(a,b){ return a.getAttribute('data-name').localeCompare(b.getAttribute('data-name')); });
    } else {
      arr.sort(function(a,b){ return origOrder.indexOf(a)-origOrder.indexOf(b); });
    }
    arr.forEach(function(c){ grid.appendChild(c); });
  }
  if(sortSel) sortSel.addEventListener('change',applySort);

  cards.forEach(function(card){
    var img=card.querySelector('.jp2-pic img');
    [].slice.call(card.querySelectorAll('.jsw')).forEach(function(sw){
      sw.addEventListener('click',function(){
        var src=sw.getAttribute('data-img'); if(src && img) img.src=src;
        [].slice.call(card.querySelectorAll('.jsw')).forEach(function(x){ x.classList.remove('is-on'); });
        sw.classList.add('is-on');
      });
    });
  });

  var sel=[], bar=document.getElementById('jbar'), cnt=document.getElementById('jcnt');
  function sync(){ bar.classList.toggle('show', sel.length>0); cnt.textContent=sel.length+' von 3'; }
  cards.forEach(function(card){
    var b=card.querySelector('.cmpbox'); if(!b) return;
    b.addEventListener('change',function(){
      if(b.checked){ if(sel.length>=3){b.checked=false;return;} sel.push(card); }
      else{ sel=sel.filter(function(x){return x!==card;}); }
      sync();
    });
  });
  document.getElementById('jclr').addEventListener('click',function(){
    sel=[]; cards.forEach(function(c){var b=c.querySelector('.cmpbox'); if(b) b.checked=false;}); sync();
  });
  function cell(fn){ return sel.map(function(c){return '<td>'+fn(c)+'</td>';}).join(''); }
  document.getElementById('jgo').addEventListener('click',function(){
    var html='<tr><th></th>'+cell(function(c){return '<b>'+c.getAttribute('data-name')+'</b>';})+'</tr>'
      +'<tr><th>Serie</th>'+cell(function(c){return c.getAttribute('data-serie');})+'</tr>'
      +'<tr><th>Preis</th>'+cell(function(c){return c.getAttribute('data-price');})+'</tr>'
      +'<tr><th>Charakter</th>'+cell(function(c){return c.getAttribute('data-blurb')||'';})+'</tr>'
      +'<tr><th></th>'+cell(function(c){return '<a href="'+c.getAttribute('data-url')+'">Details &rarr;</a>';})+'</tr>';
    document.getElementById('jtbl').innerHTML=html;
    document.getElementById('jmodal').classList.add('show');
  });
  [].slice.call(document.querySelectorAll('.jclose')).forEach(function(x){
    x.addEventListener('click',function(){ document.getElementById('jmodal').classList.remove('show'); });
  });
})();
</script>
'@

function Jura-Kategorie-Content($p, $brandKey = 'jura') {
  $J = $data.$brandKey
  $bn = $J.brandName
  $sfx = [string]$J.serieSuffix
  $prods = @(Jura-Products $J.katHeaderSlug)
  $present = @($J.seriesOrder | Where-Object { $prods.serie -contains $_ })
  $extra   = @($prods.serie | Select-Object -Unique | Where-Object { $_ -and ($present -notcontains $_) })
  $order   = @($present) + @($extra)

  $HEX = @{
    'Piano Black'='#1a1a1a'; 'Piano White'='#f0f0ee'; 'Diamond Black'='#151210'; 'Diamond White'='#e9e6df';
    'Aluminium Black'='#2b2b2d'; 'Aluminium White'='#d9d9db'; 'Dark Inox'='#4b4b4b'; 'Night Inox'='#3a3a3c';
    'Midnight Silver'='#9a9ea3'; 'Cosmic Black'='#232327'; 'Onyx Grey'='#6d6d70'; 'Full Metropolitan Black'='#1b1b1b';
    'Obsidian Black'='#141416'; 'Chrome'='#c9ccce'
  }
  function FbHex($n) {
    $k = "$n"
    if ($HEX.ContainsKey($k)) { $HEX[$k] }
    elseif ($k -match 'White|Weiss') { '#ededea' }
    elseif ($k -match 'Inox|Silver|Silber|Grey|Grau|Alu|Chrome') { '#8b8b8d' }
    else { '#212121' }
  }

  $allFarben = @($prods | ForEach-Object { $_.variants } | ForEach-Object { $_.color } | Where-Object { $_ } | Select-Object -Unique)

  # technische Kurzdaten je SKU (nur JURA)
  $SPEC = @{}
  $specFile = "$root\$brandKey-specs.json"
  if (Test-Path $specFile) {
    $sp = Get-Content $specFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($pn in $sp.PSObject.Properties) { if ($pn.Name -notmatch '^_') { $SPEC[$pn.Name] = $pn.Value } }
  }
  function SpecOf($sku) { if ($sku -and $SPEC.ContainsKey("$sku")) { $SPEC["$sku"] } else { $null } }
  function Td($spec, $rx) { if ($spec) { ([string](($spec.techdaten | Where-Object { $_.k -match $rx }).v | Select-Object -First 1)) } else { '' } }
  function ShortDisplay($v) {
    if (-not $v) { return '' }
    $sz = if ($v -match '(\d+[.,]\d+)') { $matches[1] + '&Prime; ' } else { '' }
    if ($v -match 'Touch')       { $sz + 'Touch' }
    elseif ($v -match 'Farbdisplay|Farb-Display') { $sz + 'Farbdisplay' }
    elseif ($v -match 'Klartext|Text') { 'Textdisplay' }
    else { ($sz + 'Anzeige').Trim() }
  }

  $serTiles = "<a class=`"jk2-serie is-on`" data-s=`"*`"><span class=`"pic`"></span><b>Alle</b><i>$($prods.Count)</i></a>" + (($order | ForEach-Object {
    $s = $_
    $items = @($prods | Where-Object { $_.serie -eq $s })
    $pic = if ($items[0].displayImg) { " style=`"background-image:url('$($items[0].displayImg)')`"" } else { '' }
    "<a class=`"jk2-serie`" data-s=`"$s`"><span class=`"pic`"$pic></span><b>$s$sfx</b><i>$($items.Count)</i></a>"
  }) -join "`n      ")

  $serChips = "<button class=`"jk2-chip is-on`" data-s=`"*`">Alle</button>" + (($order | ForEach-Object {
    "<button class=`"jk2-chip`" data-s=`"$_`">$_$sfx</button>"
  }) -join '')

  $farbDots = ($allFarben | ForEach-Object {
    "<button class=`"jk2-fdot`" data-c=`"$_`" title=`"$_`" aria-label=`"$_`" style=`"background:$(FbHex $_)`"></button>"
  }) -join ''

  $ranked = @()
  foreach ($s in $order) { $ranked += @($prods | Where-Object { $_.serie -eq $s } | Sort-Object price) }

  $cards = ($ranked | ForEach-Object {
    $pr = $_
    $shortName = ($pr.name -replace '\s*\([^)]*\)\s*$','')
    $vs = @($pr.variants)
    $sw = ($vs | ForEach-Object {
      $on = if ($_.img -eq $pr.displayImg) { ' is-on' } else { '' }
      "<button class=`"jsw$on`" data-img=`"$($_.img)`" data-c=`"$($_.color)`" title=`"$($_.color)`" aria-label=`"$($_.color)`" style=`"background:$(FbHex $_.color)`"></button>"
    }) -join ''
    $txt = if ($vs.Count -gt 1) { "$($vs.Count) Farben &middot; " + ((@($vs | ForEach-Object { $_.color })) -join ', ') }
           elseif ($vs[0].color) { $vs[0].color }
           else { [string]$J.seriesBlurb.$($pr.serie) }
    $cData = (@($vs | ForEach-Object { $_.color }) -join '|')

    # Kurz-Steckbrief + Ausstattungs-Merkmale aus den Spezifikationen
    $sp = SpecOf $pr.sku
    $spez = Td $sp 'Spezialit'
    $disp = Td $sp 'Display'
    $tank = Td $sp 'Wassertank'
    $milch = Td $sp 'Milchsystem'
    $mahl = Td $sp 'Mahlwerk'
    $vz = if ($sp -and $sp.vorzuege) { [string]::Join(' ', @($sp.vorzuege)) } else { '' }

    # Genusswelten (offizielle JURA-Markenbegriffe, siehe de.jura.com/einkaufsberatung/genusswelten):
    # Hot Brew kann jedes Geraet, Light/Cold Brew und Sweet Foam aus den Vorzuegen abgeleitet.
    $genuss = @('hot')
    if ($vz -match '\bCold\b')  { $genuss += 'cold' }
    if ($vz -match '\bLight\b') { $genuss += 'light' }
    if ($vz -match '\bSweet\b') { $genuss += 'sweet' }
    $genussData = ($genuss -join ' ')
    $genussLabel = @{ hot = 'Hot'; light = 'Light'; cold = 'Cold'; sweet = 'Sweet' }
    $genussFact = 'Genusswelten: ' + (($genuss | ForEach-Object { $genussLabel[$_] }) -join ', ')

    $facts = @()
    if ($spez) { $facts += "$spez Spezialit&auml;ten" }
    $sd = ShortDisplay $disp
    if ($sd)   { $facts += $sd }
    if ($tank) { $facts += "$tank Tank" }
    $facts += $genussFact
    $factHtml = if ($facts.Count) { "<ul class=`"jp2-fx`">" + (($facts | Select-Object -First 4 | ForEach-Object { "<li>$_</li>" }) -join '') + "</ul>" } else { '' }

    $feat = @()
    if ($milch -or $vz -match 'Milch(schaum|system|spezialit)') { $feat += 'milch' }
    if ($disp -match 'Touch|Farbdisplay') { $feat += 'display' }
    if ($vz -match 'J\.O\.E\.|WLAN|WiFi|App') { $feat += 'app' }
    if ($mahl -match '^\s*2|Zwei|2 ' -or $vz -match 'zwei (Mahlwerke|Keramik|verschiedene)') { $feat += 'mahl2' }
    $featData = ($feat -join ' ')
    @"
<article class="jp2" data-s="$($pr.serie)" data-name="$shortName" data-serie="$($pr.serie)$sfx" data-price="$($pr.priceStr)" data-pnum="$([int]$pr.price)" data-farben="$cData" data-feat="$featData" data-genuss="$genussData" data-blurb="$([string]$J.seriesBlurb.$($pr.serie))" data-url="$($pr.url)">
  <div class="jp2-pic"><img src="$($pr.displayImg)" alt="$shortName"></div>
  <div class="jp2-bd">
    <span class="jp2-serie">$($pr.serie)$sfx</span>
    <h3>$shortName</h3>
    $factHtml
    <p class="jp2-tx">$txt</p>
    <div class="jp2-sw">$sw</div>
    <div class="jp2-price">$($pr.priceStr)</div>
    <div class="jp2-row"><a href="$($pr.url)">Details ansehen &rarr;</a><label class="cmp"><input type="checkbox" class="cmpbox"> Vergleichen</label></div>
  </div>
</article>
"@
  }) -join "`n"

  $farbBar = if ($farbDots) { "<div class=`"grp`"><span class=`"lbl`">Farbe</span>$farbDots</div>" } else { '' }

  $featBar = if ($SPEC.Count) {
    $fd = @(
      @{ k='milch';   t='Milchsystem' }
      @{ k='display'; t='Farbdisplay / Touch' }
      @{ k='app';     t='App-Steuerung' }
      @{ k='mahl2';   t='Zwei Mahlwerke' }
    ) | ForEach-Object { "<button class=`"jk2-feat`" data-f=`"$($_.k)`">$($_.t)</button>" }
    "<div class=`"grp`"><span class=`"lbl`">Ausstattung</span>$($fd -join '')</div>"
  } else { '' }

  # Namen/Reihenfolge wie auf de.jura.com/de/einkaufsberatung/genusswelten
  $genussBar = if ($SPEC.Count) {
    $gd = @(
      @{ k='hot';   t='Hot Brew';   x='Intensiver Espresso, hei&szlig; gebr&uuml;hter Kaffee und Lungo in Barista-Qualit&auml;t' }
      @{ k='light'; t='Light Brew'; x='Bei ca. 60&nbsp;&deg;C gebr&uuml;ht &ndash; wohltemperiert, luftig-leicht, sofort trinkbereit' }
      @{ k='cold';  t='Cold Brew';  x='Cold Extraction: kalt, pulsierend, unter Druck gebr&uuml;ht &ndash; fruchtig, ohne Bitterstoffe' }
      @{ k='sweet'; t='Sweet Foam'; x='Milchschaum direkt bei der Zubereitung mit Sirup aromatisiert' }
    ) | ForEach-Object { "<button class=`"jk2-feat`" data-g=`"$($_.k)`" title=`"$($_.x)`">$($_.t)</button>" }
    "<div class=`"grp`"><span class=`"lbl`">Genusswelten</span>$($gd -join '')</div>"
  } else { '' }

  $body = @"
$JURA_CSS
<div class="jstore jkat">
  <p class="crumb"><a href="$base/$($J.shopSlug)/">$bn</a> &rsaquo; $($J.katCrumbTail)</p>
  <h1>$($J.katTitle)</h1>
  <p class="lead">$($J.katIntro)</p>
</div>
<div class="jk2">
  <div class="jk2-series" id="jk2series">
      $serTiles
  </div>
  <div class="jk2-bar" id="jk2bar">
    $genussBar
    <div class="grp"><span class="lbl">Serie</span>$serChips</div>
    <div class="grp"><span class="lbl">Sortieren</span>
      <select id="jsort">
        <option value="serie">Serie (GIGA &rarr; ENA)</option>
        <option value="asc">Preis aufsteigend</option>
        <option value="desc">Preis absteigend</option>
        <option value="az">Name A&ndash;Z</option>
      </select>
    </div>
    $farbBar
    $featBar
  </div>
  <div class="jk2-grid" id="jk2grid">
$cards
  </div>
  <p class="jk2-empty" id="jk2empty" hidden>Keine Modelle f&uuml;r diese Auswahl.</p>
</div>
<div class="jstore"><p class="jnote" style="text-align:left;max-width:720px;margin-top:26px">$($J.katNote)</p>
<p class="jnote" style="text-align:left;max-width:720px">$($J.footerNote)</p></div>
<div class="jbar" id="jbar"><div class="inner">
  <span>Vergleichen: <b id="jcnt">0 von 3</b></span>
  <button class="go" id="jgo">Vergleich anzeigen</button>
  <button class="clr" id="jclr">Zur&uuml;cksetzen</button>
</div></div>
<div class="jmodal" id="jmodal"><div class="box">
  <span class="close jclose">&times;</span>
  <h2>Modelle im Vergleich</h2>
  <div class="tblwrap"><table><tbody id="jtbl"></tbody></table></div>
  <p style="margin:16px 0 0;font-size:12.5px;color:#777">Ausf&uuml;hrliche technische Daten und eine Vorf&uuml;hrung erhalten Sie in unserem Gesch&auml;ft in Hofheim-Langenhain oder telefonisch unter 06192 2004363.</p>
</div></div>
$JURA_KAT_JS
"@

  Wrap-Page (@(
    (Shop-Header-Zone $J.katHeaderSlug),
    (Zone $C.bg '44px' '60px' (Html-Block $body)),
    (Footer-Zone)
  ) -join "`n`n")
}

$JURA_LISTE_JS = @'
<script>
(function(){
  var grid=document.getElementById('jgrid'); if(!grid) return;
  var q=document.getElementById('jq');
  var cards=Array.prototype.slice.call(grid.querySelectorAll('.jprod'));
  grid.addEventListener('click',function(e){
    if(e.target.closest('a,input,label')) return;
    var card=e.target.closest('.jprod'); if(!card) return;
    var u=card.getAttribute('data-url'); if(u) window.location.href=u;
  });
  if(q){ q.addEventListener('input',function(){
    var v=q.value.trim().toLowerCase();
    cards.forEach(function(c){ c.style.display=(!v||c.getAttribute('data-name').toLowerCase().indexOf(v)>-1)?'':'none'; });
  }); }
})();
</script>
'@

function Jura-Liste-Content($p) {
  $J   = $data.jura
  $cfg = $J.listen.$($p.slug)
  $prods = @(Jura-Products $cfg.catSlug)
  $cards = ($prods | ForEach-Object {
    $img = if ($_.img) { "<img src=`"$($_.img)`" alt=`"$($_.name)`">" } else { "<span style=`"font-size:11px;color:#aaa`">Abbildung folgt</span>" }
    @"
<article class="jprod" data-name="$($_.name)" data-url="$($_.url)">
  <div class="pic">$img</div>
  <div class="body">
    <h3>$($_.name)</h3>
    <div class="price">$($_.priceStr)</div>
    <div class="row"><a href="$($_.url)">Details &rarr;</a></div>
  </div>
</article>
"@
  }) -join "`n"

  $body = @"
$JURA_CSS
<div class="jstore jkat">
  <p class="crumb"><a href="$base/jura/">Shop</a> &rsaquo; $($cfg.crumb)</p>
  <h1>$($cfg.h1)</h1>
  <p class="lead">$($cfg.intro)</p>
</div>
<div class="jfilter"><span class="lbl">Suche</span><input id="jq" type="search" placeholder="Produkt suchen&hellip;" style="flex:1;min-width:200px;max-width:320px;padding:8px 12px;border:1px solid #cfcfcf;border-radius:6px;font-size:14px;font-family:$FONT_BODY"></div>
<div class="jgrid" id="jgrid">
$cards
</div>
<div class="jstore"><p class="jnote" style="text-align:left;max-width:720px;margin-top:26px">$($cfg.note)</p>
<p class="jnote" style="text-align:left;max-width:720px">$($J.footerNote)</p></div>
$JURA_LISTE_JS
"@

  Wrap-Page (@(
    (Pick-Header $p.slug),
    (Zone $C.bg '44px' '60px' (Html-Block $body)),
    (Footer-Zone)
  ) -join "`n`n")
}

# ---- Kombi-Seite "Unser Kaffee & Tee" mit Auswahl-Kacheln nach Art ----
$KAFFEETEE_JS = @'
<script>
(function(){
  var grid=document.getElementById('jgrid'); if(!grid) return;
  var chips=Array.prototype.slice.call(document.querySelectorAll('.jserie'));
  var cards=Array.prototype.slice.call(grid.querySelectorAll('.jprod'));
  grid.addEventListener('click',function(e){
    if(e.target.closest('a,input,label')) return;
    var card=e.target.closest('.jprod'); if(!card) return;
    var u=card.getAttribute('data-url'); if(u) window.location.href=u;
  });
  chips.forEach(function(c){c.addEventListener('click',function(){
    chips.forEach(function(x){x.classList.remove('is-on')});c.classList.add('is-on');
    var s=c.getAttribute('data-s');
    cards.forEach(function(p){p.style.display=(s==='*'||p.getAttribute('data-s')===s)?'':'none';});
    grid.scrollIntoView({behavior:'smooth',block:'start'});
  });});
})();
</script>
'@

function KaffeeTee-Content($p) {
  $cfg = $data.jura.kaffeeTee
  $prods = @(Jura-Products 'kaffee') + @(Jura-Products 'tee')
  $order = @($cfg.artOrder)
  $arts = @($order | Where-Object { $a = $_; @($prods | Where-Object { $_.art -eq $a }).Count -gt 0 })
  $arts += @($prods | ForEach-Object { $_.art } | Where-Object { $_ -and ($order -notcontains $_) } | Select-Object -Unique)
  $arts = @($arts | Select-Object -Unique)
  $tiles = "<button class=`"jserie jserie-all is-on`" data-s=`"*`"><b>Alle</b><small>$($prods.Count) Sorten</small></button>" +
    (($arts | ForEach-Object {
       $a = $_
       $cnt = @($prods | Where-Object { $_.art -eq $a }).Count
       "<button class=`"jserie jserie-all`" data-s=`"$a`"><b>$a</b><small>$cnt Sorte$(if ($cnt -ne 1) {'n'})</small></button>"
     }) -join '')
  $cards = ($prods | ForEach-Object {
    $img = if ($_.img) { "<img src=`"$($_.img)`" alt=`"$($_.name)`">" } else { '' }
    @"
<article class="jprod" data-s="$($_.art)" data-name="$($_.name)" data-url="$($_.url)">
  <div class="pic">$img</div>
  <div class="body">
    <span class="serie">$($_.art)</span>
    <h3>$($_.name)</h3>
    <div class="price">$($_.priceStr)</div>
    <div class="row"><a href="$($_.url)">Details &rarr;</a></div>
  </div>
</article>
"@
  }) -join "`n"
  $body = @"
$JURA_CSS
<div class="jstore jkat">
  <p class="crumb"><a href="$base/jura/">Shop</a> &rsaquo; $($cfg.crumb)</p>
  <h1>$($cfg.h1)</h1>
  <p class="lead">$($cfg.intro)</p>
</div>
<p class="jslbl">Auswahl</p>
<div class="jseries" id="jseries">$tiles</div>
<div class="jgrid" id="jgrid">
$cards
</div>
<div class="jstore"><p class="jnote" style="text-align:left;max-width:720px;margin-top:26px">$($cfg.note)</p></div>
$KAFFEETEE_JS
"@
  Wrap-Page (@(
    (Pick-Header $p.slug),
    (Zone $C.bg '44px' '60px' (Html-Block $body)),
    (Footer-Zone)
  ) -join "`n`n")
}

# kompakte Unterseiten-Typografie + optionale Seitenspalte (Sprungmarken + Kurzfakten)
$PROSE_CSS = @"
<style>
.kt-page{max-width:1060px;margin:0 auto;font-family:$FONT_BODY;color:$($C.text)}
.kt-page.has-rail{display:grid;grid-template-columns:190px 1fr;gap:52px;align-items:start}
.kt-rail{position:sticky;top:16px;font-size:13px}
.kt-rail .lbl{font-family:Tahoma,Arial,sans-serif;font-size:10px;letter-spacing:.13em;text-transform:uppercase;color:#8f8f8f;margin:0 0 10px}
.kt-rail a{display:block;color:#5a5a5a;text-decoration:none;padding:5px 0 5px 12px;border-left:2px solid $($C.line);line-height:1.35;margin-bottom:2px}
.kt-rail a:hover{color:$($C.head);border-left-color:$($C.head)}
.kt-facts{margin-top:24px;font-size:12.5px;color:#555555;line-height:1.55}
.kt-facts b{display:block;font-family:Tahoma,Arial,sans-serif;font-size:10px;letter-spacing:.08em;text-transform:uppercase;color:$($C.head);margin:13px 0 2px}
.kt-facts b:first-child{margin-top:0}
.kt-facts a{display:inline;border:0;padding:0;margin:0;color:$($C.accent);text-decoration:underline}
.kt-facts a:hover{color:$($C.accentD)}
.kt-main{min-width:0;max-width:760px}
.kt-page:not(.has-rail){max-width:840px}
.kt-page:not(.has-rail) .kt-main{max-width:none}
.kt-main>h1{font-family:$FONT_HEAD;color:$($C.head);font-weight:700;font-size:23px;line-height:1.25;margin:0 0 10px}
.kt-lead{font-size:16px;line-height:1.6;color:$($C.text);margin:0;max-width:620px}
.kt-lead.kt-lead-wide{max-width:none}
.kt-sub{font-size:14px;line-height:1.55;color:#666666;margin:8px 0 0}
.kt-prose{margin-top:26px}
.kt-prose h3{font-family:$FONT_HEAD !important;color:#6d6d6d !important;font-weight:700;font-size:11.5px !important;text-transform:uppercase;letter-spacing:.09em;margin:16px 0 5px}
.kt-prose>p,.kt-prose>ul{font-size:15.5px;line-height:1.72;color:$($C.text)}
.kt-prose>p{margin:0 0 12px}
.kt-prose>ul{margin:2px 0 14px;padding:0;list-style:none}
.kt-prose>ul>li{position:relative;padding-left:20px;margin:0 0 6px;font-size:15.5px;line-height:1.55}
.kt-prose>ul>li::before{content:"";position:absolute;left:3px;top:9px;width:5px;height:5px;background:$($C.head);border-radius:50%}
.kt-secs{display:grid;gap:12px;margin-top:16px}
.kt-sec{background:#ffffff;border:1px solid #e6e6e6;border-radius:5px;padding:20px 24px}
.kt-sec>*:last-child{margin-bottom:0}
.kt-sec h2{font-family:$FONT_HEAD !important;color:$($C.head) !important;font-weight:700;font-size:15.5px !important;line-height:1.35;margin:0 0 11px;padding:0;border:0}
.kt-h2i{display:flex;align-items:center;gap:9px}
.kt-h2ico{display:inline-flex;align-items:center;justify-content:center;flex:0 0 auto;width:26px;height:26px;border-radius:6px;background:$($C.soft);color:$($C.accent)}
.kt-h2ico svg{width:15px;height:15px;display:block}
.kt-prose h2.kt-h2i{align-items:flex-start}
.kt-sec h3{font-family:$FONT_HEAD !important;color:#6d6d6d !important;font-weight:700;font-size:11.5px !important;text-transform:uppercase;letter-spacing:.09em;margin:15px 0 5px}
.kt-sec p{font-size:15.5px;line-height:1.7;margin:0 0 11px;color:$($C.text)}
.kt-sec ul{margin:2px 0 12px;padding:0;list-style:none}
.kt-sec li{position:relative;padding-left:20px;margin:0 0 6px;font-size:15.5px;line-height:1.55}
.kt-sec li::before{content:"";position:absolute;left:3px;top:9px;width:5px;height:5px;background:$($C.head);border-radius:50%}
.kt-sec .wp-block-buttons{margin-top:14px}
@media(max-width:900px){
  .kt-page.has-rail{grid-template-columns:1fr;gap:0}
  .kt-rail{position:static;border-bottom:1px solid $($C.line);padding-bottom:16px;margin-bottom:24px}
  .kt-main{max-width:none}
  .kt-sec{padding:18px 18px}
}
</style>
"@

# ---------- Unterseite ----------
function Sub-Content($p) {
  $blocks = @($p.blocks)
  $heroP = ''
  if ($blocks.Count -gt 0 -and $blocks[0].t -eq 'p') {
    $leadCls = if ($p.leadWide) { 'kt-lead kt-lead-wide' } else { 'kt-lead' }
    $heroP = "<p class=`"$leadCls`">$($blocks[0].x)</p>"
    $blocks = @($blocks[1..($blocks.Count-1)])
  }
  # Excerpt nur als sichtbare Unterzeile zeigen, wenn KEIN Intro-Absatz da ist -
  # sonst doppeln sich Lead und Unterzeile (Nutzerhinweis 2026-09-03).
  $sub = if ($p.excerpt -and -not $heroP) { "<p class=`"kt-sub`">$($p.excerpt)</p>" } else { '' }

  $toc   = @(Toc-From-Blocks $blocks)
  $facts = @($p.facts | Where-Object { $_ })
  $useRail = ($toc.Count -ge 3) -or ($facts.Count -ge 1)

  $rail = ''
  if ($useRail) {
    $tocHtml = ($toc | ForEach-Object { "<a href=`"#$($_.id)`">$($_.text)</a>" }) -join "`n      "
    $factsHtml = if ($facts.Count) {
      "<div class=`"kt-facts`">`n      " + (($facts | ForEach-Object { "<b>$($_.k)</b>$($_.v)" }) -join "`n      ") + "`n    </div>"
    } else { '' }
    $tocBlock = if ($toc.Count -ge 2) { "<p class=`"lbl`">Auf dieser Seite</p>`n      $tocHtml" } else { '' }
    $rail = "<aside class=`"kt-rail`">`n      $tocBlock`n    $factsHtml`n  </aside>"
  }

  # Bloecke in Karten-Abschnitte gruppieren: jede h2 startet eine neue Karte,
  # Inhalt vor der ersten h2 (Intro-Absatz, Bild, Marken-Raster) bleibt lose darueber
  $pre = @(); $secs = @(); $cur = $null
  foreach ($b in $blocks) {
    if ($b.t -eq 'h' -and [int]$b.lvl -eq 2) {
      if ($null -ne $cur) { $secs += ,$cur }
      $cur = @($b)
    } elseif ($null -ne $cur) { $cur += $b }
    else { $pre += $b }
  }
  if ($null -ne $cur) { $secs += ,$cur }

  $preHtml = if ($pre.Count) { Strip-Wp (Native-Blocks $pre) } else { '' }
  if ($secs.Count) {
    $secHtml = ($secs | ForEach-Object {
      $sb = @($_)
      $h2 = $sb[0]
      $rest = @($sb | Select-Object -Skip 1)
      $id = if ($h2.id) { $h2.id } else { Slugify $h2.x }
      $restHtml = if ($rest.Count) { Strip-Wp (Native-Blocks $rest) } else { '' }
      $ico = H2-Ico $h2.icon
      $h2cls = if ($ico) { 'wp-block-heading kt-h2i' } else { 'wp-block-heading' }
      "<div class=`"kt-sec`" id=`"$id`">`n<h2 class=`"$h2cls`">$ico$($h2.x)</h2>`n$restHtml`n</div>"
    }) -join "`n"
    $proseHtml = ($preHtml + "`n<div class=`"kt-secs`">`n$secHtml`n</div>").Trim()
  } else {
    $proseHtml = $preHtml.Trim()
  }
  $cls = if ($useRail) { 'kt-page has-rail' } else { 'kt-page' }

  $pageHtml = @"
$PROSE_CSS
<div class="$cls">
  $rail
  <div class="kt-main">
    <h1>$($p.title)</h1>
    $heroP
    $sub
    <div class="kt-prose">
$proseHtml
    </div>
  </div>
</div>
"@

  Wrap-Page (@(
    (Pick-Header $p.slug),
    (Zone $C.bg '48px' '56px' (Html-Block $pageHtml)),
    (Footer-Zone)
  ) -join "`n`n")
}

# ---------- FAQ / Hilfe-Hub (Startseite von "Hilfe & Wissen") ----------
function Faq-Hub-Content($p) {
  $H = $FAQ_HUB
  $pageBySlug = @{}
  foreach ($pg in $data.pages) { $pageBySlug[$pg.slug] = $pg }
  $groupsHtml = ($H.groups | ForEach-Object {
    $cards = ($_.slugs | ForEach-Object {
      $sp = $pageBySlug[$_]
      if (-not $sp) { return }
      "<a class=`"kt-fq`" href=`"$base/$_/`"><b>$($sp.menu)</b><span>$($sp.excerpt)</span><em>Ansehen &rarr;</em></a>"
    }) -join "`n    "
    $aid = if ($_.anchor) { " id=`"$($_.anchor)`"" } else { '' }
    "<section class=`"kt-fqg`"$aid hidden>`n<h2 class=`"wp-block-heading`">$($_.title)</h2>`n<div class=`"kt-fqs`">`n    $cards`n</div>`n</section>"
  }) -join "`n"
  $catsHtml = ($H.groups | ForEach-Object {
    $ic = H2-Ico $_.icon
    $bl = if ($_.blurb) { $_.blurb } else { '' }
    $n  = @($_.slugs | Where-Object { $pageBySlug[$_] }).Count
    "<button type=`"button`" class=`"kt-cat`" data-cat=`"$($_.anchor)`"><span class=`"ci`">$ic</span><b>$($_.title)</b><span class=`"cd`">$bl</span><em>$n Themen</em></button>"
  }) -join "`n    "
  $css = @"
<style>
.kt-hub{max-width:1000px;margin:0 auto;font-family:$FONT_BODY;color:$($C.text)}
.kt-hub>h1{font-family:$FONT_HEAD;color:$($C.head);font-weight:700;font-size:22px;margin:0 0 10px}
.kt-hub>.lead{font-size:15.5px;line-height:1.6;max-width:640px;margin:0 0 20px;color:$($C.text)}
.kt-hub-find{position:relative;max-width:440px;margin:0 0 22px}
.kt-hub-find .ic{position:absolute;left:13px;top:50%;transform:translateY(-50%);width:17px;height:17px;color:#8a8a8a;pointer-events:none}
.kt-hub-find input{width:100%;box-sizing:border-box;padding:11px 40px;border:1px solid #cfcfcf;border-radius:8px;font-size:14.5px;font-family:$FONT_BODY;background:#fff;color:$($C.text)}
.kt-hub-find input:focus{outline:none;border-color:$($C.accent);box-shadow:0 0 0 3px rgba(51,65,85,.12)}
.kt-hub-find .clr{position:absolute;right:8px;top:50%;transform:translateY(-50%);width:24px;height:24px;border:0;background:#ececec;border-radius:50%;color:#555;font-size:15px;line-height:1;cursor:pointer;padding:0}
.kt-hub-find .clr:hover{background:#dcdcdc}
.kt-hub-cats{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin:0 0 12px}
.kt-cat{display:flex;flex-direction:column;align-items:flex-start;text-align:left;background:#fff;border:1px solid #e2e2e2;border-radius:10px;padding:16px 17px 15px;cursor:pointer;font-family:$FONT_BODY;transition:border-color .12s,box-shadow .12s}
.kt-cat:hover{border-color:$($C.accent);box-shadow:0 3px 14px rgba(0,0,0,.06)}
.kt-cat.is-on{border-color:$($C.accent);background:$($C.soft)}
.kt-cat .ci{display:flex;align-items:center;justify-content:center;width:34px;height:34px;border-radius:8px;background:$($C.soft);color:$($C.accent);margin-bottom:10px}
.kt-cat.is-on .ci{background:#fff}
.kt-cat .ci .kt-h2ico{width:auto;height:auto;background:none;border-radius:0}
.kt-cat .ci svg{width:18px;height:18px;display:block}
.kt-cat b{font-family:$FONT_HEAD;color:$($C.head);font-size:14.5px;line-height:1.3;margin-bottom:3px}
.kt-cat .cd{font-size:12px;line-height:1.45;color:#666;flex:1}
.kt-cat em{font-style:normal;font-family:$FONT_HEAD;font-size:11px;font-weight:700;color:$($C.accent);margin-top:10px}
.kt-hub-all{margin:0 0 30px;font-size:13px}
.kt-hub-all[hidden]{display:none}
.kt-hub-all a{color:$($C.accent);text-decoration:none;border-bottom:1px solid rgba(51,65,85,.35);cursor:pointer}
.kt-hub-all a:hover{color:$($C.accentD)}
.kt-hub-cnt{font-size:12px;color:#8a8a8a;margin:0 0 16px}
.kt-hub-cnt:empty{margin:0}
.kt-hub h2{font-family:$FONT_HEAD;color:$($C.head);font-weight:700;font-size:16px;margin:24px 0 12px;padding:0;border:0}
.kt-fqg{scroll-margin-top:16px}
.kt-fqg:first-of-type h2{margin-top:4px}
.kt-fqg[hidden]{display:none}
.kt-fqs{display:grid;grid-template-columns:repeat(auto-fill,minmax(224px,1fr));gap:10px;margin-bottom:6px}
.kt-fq{display:flex;flex-direction:column;background:#fff;border:1px solid #e2e2e2;border-radius:6px;padding:13px 15px;text-decoration:none;transition:border-color .12s}
.kt-fq:hover{border-color:$($C.accent)}
.kt-fq[hidden]{display:none}
.kt-fq b{font-family:$FONT_HEAD;color:$($C.head);font-size:13.5px;line-height:1.3;margin-bottom:4px}
.kt-fq span{font-size:12px;line-height:1.45;color:#5a5a5a;flex:1;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.kt-fq em{font-style:normal;font-family:$FONT_HEAD;color:$($C.accent);font-weight:700;font-size:11px;margin-top:9px}
.kt-hub-none{font-size:14.5px;line-height:1.6;color:#555;background:#f6f6f4;border:1px solid #e6e6e6;border-radius:8px;padding:15px 18px;margin-top:6px}
.kt-hub-none a{color:$($C.accent)}
.kt-hub-none[hidden]{display:none}
@media(max-width:720px){.kt-hub-cats{grid-template-columns:1fr}}
</style>
"@
  $iconSearch = '<svg class="ic" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="7"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>'
  $hubJs = @'
<script>
(function(){
  var inp = document.getElementById('kt-hub-q');
  if (!inp) { return; }
  var cards  = [].slice.call(document.querySelectorAll('.kt-fq'));
  var groups = [].slice.call(document.querySelectorAll('.kt-fqg'));
  var cats   = [].slice.call(document.querySelectorAll('.kt-cat'));
  var none   = document.getElementById('kt-hub-none');
  var clr    = document.getElementById('kt-hub-clr');
  var cnt    = document.getElementById('kt-hub-cnt');
  var allWrap= document.getElementById('kt-hub-all');
  var allLink= document.getElementById('kt-hub-alllink');
  var total  = cards.length;
  var activeCat = '';
  cards.forEach(function(c){ c.setAttribute('data-kw', (c.textContent || '').toLowerCase().replace(/\s+/g, ' ')); });

  function render(){
    var q = inp.value.toLowerCase().replace(/\s+/g, ' ').trim();
    var searching = q.length > 0;
    var hits = 0;
    groups.forEach(function(g){
      var gid = g.getAttribute('id');
      var inScope;
      if (searching) { inScope = true; }
      else if (activeCat === '__all__') { inScope = true; }
      else if (activeCat) { inScope = (gid === activeCat); }
      else { inScope = false; }
      var anyVisible = false;
      [].slice.call(g.querySelectorAll('.kt-fq')).forEach(function(c){
        var show = inScope;
        if (show) { if (searching) { show = c.getAttribute('data-kw').indexOf(q) > -1; } }
        c.hidden = !show;
        if (show) { anyVisible = true; hits = hits + 1; }
      });
      g.hidden = !anyVisible;
    });
    cats.forEach(function(b){
      var on = (b.getAttribute('data-cat') === activeCat) && !searching;
      b.classList.toggle('is-on', on);
    });
    if (clr)  { clr.hidden = !searching; }
    if (none) { none.hidden = !(searching && hits === 0); }
    if (allWrap) { allWrap.hidden = searching; }
    if (allLink) { allLink.textContent = activeCat ? '\u2039 Bereiche einklappen' : ('Alle ' + total + ' Themen anzeigen'); }
    if (cnt) {
      if (searching) { cnt.textContent = hits + ' von ' + total + ' Themen'; }
      else if (activeCat) { cnt.textContent = hits + ' Themen'; }
      else { cnt.textContent = ''; }
    }
  }

  cats.forEach(function(b){
    b.addEventListener('click', function(){
      var c = b.getAttribute('data-cat');
      activeCat = (activeCat === c) ? '' : c;
      inp.value = '';
      render();
      if (activeCat) {
        var g = document.getElementById(activeCat);
        if (g) { g.scrollIntoView({ behavior: 'smooth', block: 'start' }); }
      }
    });
  });
  if (allLink) {
    allLink.addEventListener('click', function(e){
      e.preventDefault();
      activeCat = activeCat ? '' : '__all__';
      inp.value = '';
      render();
    });
  }
  inp.addEventListener('input', function(){
    if (inp.value.trim()) { activeCat = ''; }
    render();
  });
  if (clr) { clr.addEventListener('click', function(){ inp.value = ''; render(); inp.focus(); }); }

  var h = (location.hash || '').replace('#', '');
  if (h) { cats.forEach(function(b){ if (b.getAttribute('data-cat') === h) { activeCat = h; } }); }
  render();
  if (activeCat) {
    var gg = document.getElementById(activeCat);
    if (gg) { gg.scrollIntoView({ block: 'start' }); }
  }
})();
</script>
'@
  $body = @"
$css
<div class="kt-hub">
  <h1>$($p.title)</h1>
  <p class="lead">$($H.intro)</p>
  <div class="kt-hub-find">
    $iconSearch
    <input id="kt-hub-q" type="text" inputmode="search" autocomplete="off" placeholder="Thema suchen &ndash; z.&nbsp;B. Milchschaum, entkalken, Br&uuml;hgruppe">
    <button type="button" class="clr" id="kt-hub-clr" hidden aria-label="Suche zur&uuml;cksetzen">&times;</button>
  </div>
  <div class="kt-hub-cats">
    $catsHtml
  </div>
  <p class="kt-hub-all" id="kt-hub-all"><a id="kt-hub-alllink" href="#">Alle Themen anzeigen</a></p>
  <p class="kt-hub-cnt" id="kt-hub-cnt"></p>
  <div class="kt-hub-groups">
  $groupsHtml
  </div>
  <p class="kt-hub-none" id="kt-hub-none" hidden>Dazu haben wir keinen Treffer. Rufen Sie uns an unter <a href="tel:+4961922004363">06192&nbsp;2004363</a> oder bringen Sie das Ger&auml;t bei uns vorbei.</p>
</div>
$hubJs
"@
  Wrap-Page (@(
    (Pick-Header $p.slug),
    (Zone $C.bg '48px' '60px' (Html-Block $body)),
    (Footer-Zone)
  ) -join "`n`n")
}

# ---------- Pflegeplaner (interaktiv, reines JS) ----------
function Wartungserinnerung-Content($p) {
  $shop   = "$base/jura-pflegeprodukte/"
  $pEntk  = "$base/product/jura-2-phasen-entkalkungstabletten-3-x-3-stueck/"
  $pRein  = "$base/product/jura-3-phasen-reinigungstabletten-6-stueck/"
  $pMilch = "$base/product/jura-milchsystem-reiniger-mini-tabs-90-g/"
  $pFilt  = "$base/product/jura-filterpatrone-claris-blue-3er-pack/"
  $tEntk  = "$base/pflege-entkalken/"
  $tMilch = "$base/pflege-milchsystem/"
  $tBrew  = "$base/pflege-bruehgruppe/"
  $tFilt  = "$base/pflege-wasserfilter/"
  $tWart  = "$base/reparaturkosten/"

  $curY = (Get-Date).Year
  $yearOpts = (($curY..($curY - 14)) | ForEach-Object { "<option value=`"$_`">$_</option>" }) -join ''
  $monthOpts = @('Januar','Februar','M&auml;rz','April','Mai','Juni','Juli','August','September','Oktober','November','Dezember')
  $monthSel = (0..11 | ForEach-Object { "<option value=`"$_`">$($monthOpts[$_])</option>" }) -join ''

  $weHtml = @"
<style>
.we{max-width:820px;margin:0 auto;font-family:$FONT_BODY;color:$($C.text)}
.we h1{font-family:$FONT_HEAD;font-size:22px;line-height:1.25;margin:0 0 10px;color:$($C.head)}
.we-lead{font-size:15.5px;line-height:1.6;color:#444;margin:0 0 22px;max-width:640px}
.we-box{background:#fff;border:1px solid $($C.line);border-radius:10px;padding:18px 20px;margin:0 0 14px}
.we-box2{border-left:3px solid $($C.accent)}
.we-q{display:block;font-family:$FONT_HEAD;font-size:15px;font-weight:700;color:$($C.head);margin:0 0 4px}
.we-sub{font-size:13.5px;color:#555;margin:0 0 2px}
.we-row{display:flex;flex-wrap:wrap;gap:10px;margin:12px 0 0}
.we-row select{flex:1 1 150px;padding:9px 11px;border:1px solid #c4c4c4;border-radius:6px;font-size:14.5px;font-family:$FONT_BODY;background:#fff;color:$($C.text)}
.we-next{font-family:$FONT_HEAD;font-size:16px;font-weight:700;color:$($C.head);margin:14px 0 0}
.we-btn{display:inline-flex;align-items:center;gap:8px;background:$($C.accent);color:#fff;border-radius:4px;padding:11px 20px;font-family:$FONT_HEAD;font-size:13.5px;font-weight:700;text-decoration:none;margin:12px 0 0}
.we-btn:hover{background:$($C.accentD)}
.we-hint{font-size:12px;line-height:1.5;color:#6b7178;margin:10px 0 0}
</style>
$FORM_CSS
<div class="we">
  <h1>Wartungserinnerung</h1>
  <p class="we-lead">Ein Kaffeevollautomat sollte etwa alle zwei Jahre professionell gewartet werden &ndash; f&uuml;r gleichbleibende Kaffeequalit&auml;t, Hygiene und eine lange Lebensdauer. Damit Sie den Termin nicht vergessen:</p>

  <div class="we-box">
    <span class="we-q">Wann war die letzte Wartung oder der Kauf?</span>
    <span class="we-sub">Monat und Jahr gen&uuml;gen &ndash; wenn unbekannt, das ungef&auml;hre Kaufjahr.</span>
    <div class="we-row">
      <select id="we-m"><option value="">Monat</option>$monthSel</select>
      <select id="we-y"><option value="">Jahr</option>$yearOpts</select>
    </div>
    <p class="we-next" id="we-next" hidden></p>
    <a class="we-btn" id="we-ics" download="wartungserinnerung-kaffeetechniker.ics" hidden>Erinnerung in den Kalender</a>
    <p class="we-hint">Die Datei legt einen Termin an, der sich alle zwei Jahre wiederholt (Handy, Outlook, Google). Zwei Wochen vorher werden Sie erinnert.</p>
  </div>

  <div class="we-box we-box2">
    <span class="we-q">Oder: Wir erinnern Sie per E-Mail</span>
    <span class="we-sub">Kurz anmelden &ndash; wir melden uns rechtzeitig vor der n&auml;chsten Wartung. Absender: shop@kaffeetechniker.de.</span>
  </div>
</div>
<script>
(function(){
  var m=document.getElementById('we-m'), y=document.getElementById('we-y');
  if(!m||!y) return;
  var MON=['Januar','Februar','M\u00e4rz','April','Mai','Juni','Juli','August','September','Oktober','November','Dezember'];
  function z(n){return(n<10?'0':'')+n;}
  function day(d){return d.getFullYear()+z(d.getMonth()+1)+z(d.getDate());}
  function stamp(d){return d.getUTCFullYear()+z(d.getUTCMonth()+1)+z(d.getUTCDate())+'T'+z(d.getUTCHours())+z(d.getUTCMinutes())+z(d.getUTCSeconds())+'Z';}
  function upd(){
    var mi=parseInt(m.value,10), yi=parseInt(y.value,10);
    var nEl=document.getElementById('we-next'), a=document.getElementById('we-ics');
    if(isNaN(mi)||isNaN(yi)){ nEl.hidden=true; a.hidden=true; return; }
    var next=new Date(yi+2,mi,1);
    nEl.textContent='N\u00e4chste Wartung: '+MON[next.getMonth()]+' '+next.getFullYear();
    nEl.hidden=false;
    var dt=new Date(yi+2,mi,1);
    var now=new Date();
    var L=['BEGIN:VCALENDAR','VERSION:2.0','PRODID:-//JB Kaffeemaschinen//Wartung//DE','CALSCALE:GREGORIAN','METHOD:PUBLISH','BEGIN:VEVENT',
      'UID:kt-wartung-'+now.getTime()+'@kaffeetechniker.de',
      'DTSTAMP:'+stamp(now),
      'DTSTART;VALUE=DATE:'+day(dt),
      'SUMMARY:Kaffeevollautomat: Wartung f\u00e4llig',
      'DESCRIPTION:Zeit f\u00fcr die Wartung Ihres Kaffeevollautomaten. Ohne Termin w\u00e4hrend der \u00d6ffnungszeiten vorbeibringen: JB Kaffeemaschinen\\, Wallauer Stra\u00dfe 4\\, 65719 Hofheim-Langenhain. Infos: $base/wartung/',
      'RRULE:FREQ=YEARLY;INTERVAL=2',
      'BEGIN:VALARM','TRIGGER:-P14D','ACTION:DISPLAY','DESCRIPTION:Kaffeevollautomat warten lassen','END:VALARM',
      'END:VEVENT','END:VCALENDAR'];
    if(a.dataset.u) URL.revokeObjectURL(a.dataset.u);
    var u=URL.createObjectURL(new Blob([L.join('\r\n')],{type:'text/calendar;charset=utf-8'}));
    a.href=u; a.dataset.u=u; a.hidden=false;
  }
  m.addEventListener('change',upd); y.addEventListener('change',upd);
})();
</script>
"@

  $formBlock = "<!-- wp:html -->`n<div class=`"kt-formwrap`" id=`"we-anmeldung`">`n<!-- /wp:html -->`n`n<!-- wp:shortcode -->`n[fluentform id=`"2`"]`n<!-- /wp:shortcode -->`n`n<!-- wp:html -->`n</div>`n<!-- /wp:html -->"

  $html = @"
<style>
.pp{max-width:820px;margin:38px auto 0;font-family:$FONT_BODY;color:$($C.text);border-top:1px solid $($C.line);padding-top:32px}
.pp h2.pp-h2{font-family:$FONT_HEAD;font-size:19px;line-height:1.25;margin:0 0 10px;color:$($C.head)}
.pp .lead{font-size:15.5px;line-height:1.6;color:#444;margin:0 0 26px;max-width:640px}
.pp-step{background:#fff;border:1px solid $($C.line);border-radius:10px;padding:16px 18px;margin:0 0 14px}
.pp-q{display:block;font-family:$FONT_HEAD;font-size:14px;font-weight:700;color:$($C.head);margin:0 0 11px}
.pp-opts{display:flex;flex-wrap:wrap;gap:9px}
.pp-opts button{flex:1 1 120px;min-width:96px;background:#fff;border:1px solid #ccd1d8;border-radius:7px;padding:9px 10px;cursor:pointer;font-family:$FONT_BODY;text-align:center;transition:border-color .12s,box-shadow .12s}
.pp-opts button:hover{border-color:#9aa3ad}
.pp-opts button.on{border-color:$($C.accent);box-shadow:inset 0 0 0 2px $($C.accent)}
.pp-opts button b{display:block;font-family:$FONT_HEAD;font-size:13.5px;color:$($C.head)}
.pp-opts button small{display:block;font-size:11px;color:#8a8a8a;margin-top:2px}
.pp-hint{font-size:12.5px;line-height:1.5;color:#6b7178;margin:11px 0 0}
.pp-go{display:inline-block;background:$($C.accent);color:#fff;border:0;border-radius:5px;padding:13px 30px;font-family:$FONT_HEAD;font-size:15px;font-weight:700;letter-spacing:.01em;cursor:pointer;margin:6px 0 0}
.pp-go:hover{background:$($C.accentD)}
.pp-res{margin:30px 0 0;background:#fff;border:1px solid $($C.line);border-radius:10px;padding:20px 20px 22px}
.pp-res h2{font-family:$FONT_HEAD;font-size:17px;margin:0 0 4px;color:$($C.head)}
.pp-res .sub{font-size:12.5px;color:#6b7178;margin:0 0 16px}
.pp-tbl{width:100%;border-collapse:collapse;font-size:14px}
.pp-tbl th{text-align:left;font-family:$FONT_HEAD;font-size:11px;letter-spacing:.05em;text-transform:uppercase;color:#8a8a8a;padding:0 12px 8px 0;border-bottom:2px solid $($C.line)}
.pp-tbl td{padding:11px 12px 11px 0;border-bottom:1px solid #eee;vertical-align:top;line-height:1.45}
.pp-tbl td b{font-family:$FONT_HEAD;font-size:14px;color:$($C.head)}
.pp-tbl .pp-lk{display:block;font-size:12px;margin-top:3px}
.pp-tbl .pp-lk a{color:$($C.accent)}
.pp-tbl td:nth-child(2){white-space:nowrap;color:#444}
.pp-tbl td:nth-child(3){white-space:nowrap;font-family:$FONT_HEAD;font-weight:700;color:$($C.head)}
.pp-actions{display:flex;flex-wrap:wrap;gap:10px;margin:18px 0 0}
.pp-btn{display:inline-flex;align-items:center;gap:8px;background:$($C.accent);color:#fff;border-radius:4px;padding:11px 20px;font-family:$FONT_HEAD;font-size:13.5px;font-weight:700;text-decoration:none}
.pp-btn:hover{background:$($C.accentD)}
.pp-btn.ghost{background:transparent;color:$($C.accent);border:1px solid #ccd1d8}
.pp-note{font-size:12.5px;line-height:1.6;color:#6b7178;margin:16px 0 0}
.pp-note a{color:$($C.accent)}
@media(max-width:560px){.pp-tbl,.pp-tbl tbody,.pp-tbl tr,.pp-tbl td{display:block;width:100%}.pp-tbl thead{display:none}.pp-tbl tr{border:1px solid $($C.line);border-radius:8px;padding:10px 12px;margin:0 0 10px}.pp-tbl td{border:0;padding:3px 0}.pp-tbl td:nth-child(2)::before{content:"Intervall: ";color:#8a8a8a}.pp-tbl td:nth-child(3)::before{content:"Termin: ";color:#8a8a8a;font-weight:400;font-family:$FONT_BODY}}
</style>
<div class="pp">
  <h2 class="pp-h2">Zwischendurch: Ihr Entkalkungsplan</h2>
  <p class="lead">Zwischen den professionellen Wartungen halten Sie Ihr Ger&auml;t mit regelm&auml;&szlig;igem Entkalken und Reinigen in Form. In vier Klicks zu Ihrem pers&ouml;nlichen Entkalkungsplan &ndash; mit Terminen f&uuml;r den Kalender.</p>

  <div class="pp-step">
    <span class="pp-q">1 &middot; Wie hart ist Ihr Wasser?</span>
    <div class="pp-opts" data-k="hard">
      <button type="button" data-v="weich"><b>Weich</b><small>bis 8,4 &deg;dH</small></button>
      <button type="button" data-v="mittel"><b>Mittel</b><small>8,4 &ndash; 14 &deg;dH</small></button>
      <button type="button" data-v="hart" class="on"><b>Hart</b><small>&uuml;ber 14 &deg;dH</small></button>
    </div>
    <p class="pp-hint">Region Hofheim / Rhein-Main: das Leitungswasser ist meist <b>hart</b>. Den genauen Wert nennt Ihr Wasserversorger; einen Teststreifen erhalten Sie auch bei uns im Gesch&auml;ft.</p>
  </div>

  <div class="pp-step">
    <span class="pp-q">2 &middot; Wie viele Tassen pro Tag?</span>
    <div class="pp-opts" data-k="cups">
      <button type="button" data-v="a"><b>1 &ndash; 2</b></button>
      <button type="button" data-v="b" class="on"><b>3 &ndash; 5</b></button>
      <button type="button" data-v="c"><b>6 &ndash; 10</b></button>
      <button type="button" data-v="d"><b>mehr als 10</b></button>
    </div>
  </div>

  <div class="pp-step">
    <span class="pp-q">3 &middot; Bereiten Sie Milchspezialit&auml;ten zu (Cappuccino, Latte)?</span>
    <div class="pp-opts" data-k="milk">
      <button type="button" data-v="yes" class="on"><b>Ja</b></button>
      <button type="button" data-v="no"><b>Nein</b></button>
    </div>
  </div>

  <div class="pp-step">
    <span class="pp-q">4 &middot; Nutzen Sie einen Wasserfilter im Ger&auml;t?</span>
    <div class="pp-opts" data-k="filter">
      <button type="button" data-v="yes"><b>Ja</b></button>
      <button type="button" data-v="no" class="on"><b>Nein</b></button>
    </div>
  </div>

  <button type="button" class="pp-go" id="pp-go">Entkalkungsplan erstellen</button>

  <div class="pp-res" id="pp-res" hidden>
    <h2>Ihr Entkalkungsplan</h2>
    <p class="sub">Richtwerte aus unserer Werkstattpraxis &ndash; angepasst an Ihre Angaben.</p>
    <table class="pp-tbl"><thead><tr><th>Aufgabe</th><th>Intervall</th><th>N&auml;chster Termin</th></tr></thead><tbody id="pp-rows"></tbody></table>
    <div class="pp-actions">
      <a class="pp-btn" id="pp-ics" download="pflegeplan-kaffeetechniker.ics">In den Kalender (.ics)</a>
      <a class="pp-btn ghost" href="$shop">Passende Pflegeprodukte</a>
    </div>
    <p class="pp-note">Fordert Ihr Ger&auml;t selbst zum Entkalken oder Reinigen auf, folgen Sie bitte der Anzeige &ndash; auch wenn der Termin fr&uuml;her kommt. Einmal im Jahr empfehlen wir zus&auml;tzlich eine <a href="$tWart">Grundwartung in unserer Werkstatt</a> (Innenreinigung, Dichtungen, Sicherheitspr&uuml;fung).</p>
  </div>
</div>
<script>
(function(){
  var wrap=document.querySelector('.pp'); if(!wrap) return;
  var st={hard:'hart',cups:'b',milk:'yes',filter:'no'};
  try{var s=JSON.parse(localStorage.getItem('kt_pp')||'null'); if(s&&s.hard){st=s;}}catch(e){}
  function paint(){ wrap.querySelectorAll('.pp-opts').forEach(function(g){ var k=g.getAttribute('data-k'); g.querySelectorAll('button').forEach(function(b){ b.classList.toggle('on', b.getAttribute('data-v')===st[k]); }); }); }
  paint();
  wrap.querySelectorAll('.pp-opts').forEach(function(g){
    var k=g.getAttribute('data-k');
    g.querySelectorAll('button').forEach(function(b){
      b.addEventListener('click',function(){ st[k]=b.getAttribute('data-v'); paint(); });
    });
  });

  var cpd={a:2,b:4,c:8,d:13};
  var base={weich:56,mittel:42,hart:26};
  var MON=['Jan.','Feb.','M\u00e4rz','Apr.','Mai','Juni','Juli','Aug.','Sept.','Okt.','Nov.','Dez.'];
  function fmt(d){ return d.getDate()+'. '+MON[d.getMonth()]+' '+d.getFullYear(); }
  function ivText(n){ if(n<=1)return 't\u00e4glich'; if(n<14)return 'alle '+n+' Tage'; if(n<60){var w=Math.round(n/7);return 'ca. alle '+w+' Wochen';} var mo=Math.round(n/30); return 'ca. alle '+mo+' Monate'; }

  function build(){
    var c=cpd[st.cups];
    var uf=(st.cups==='a')?1.15:(st.cups==='b')?1.0:(st.cups==='c')?0.8:0.62;
    var descale=Math.round(base[st.hard]*uf);
    if(st.filter==='yes') descale=Math.round(descale*1.9);
    descale=Math.max(14,Math.min(120,descale));
    var out=[];
    out.push({t:'Entkalken',iv:descale,tip:'$tEntk',shop:'$pEntk',d:'Kalkablagerungen im Wasserlauf und Boiler entfernen.'});
    out.push({t:'Reinigungsprogramm (Kaffeefett)',iv:Math.max(30,Math.min(75,Math.round(200/c))),tip:'$tBrew',shop:'$pRein',d:'\u00d6l- und Kaffeefettreste aus dem Br\u00fchweg l\u00f6sen (Reinigungstablette).'});
    out.push({t:'Br\u00fchgruppe absp\u00fclen',iv:Math.max(7,Math.min(21,Math.round(12*uf))),tip:'$tBrew',shop:'',d:'Br\u00fchgruppe entnehmen und unter klarem Wasser absp\u00fclen (falls herausnehmbar).'});
    if(st.milk==='yes'){
      out.push({t:'Milchsystem t\u00e4glich sp\u00fclen',iv:1,tip:'$tMilch',shop:'',d:'Nach dem letzten Milchgetr\u00e4nk mit klarem Wasser sp\u00fclen.'});
      out.push({t:'Milchsystem mit Reiniger sp\u00fclen',iv:7,tip:'$tMilch',shop:'$pMilch',d:'Einmal pro Woche mit Milchsystem-Reiniger durchsp\u00fclen.'});
    }
    if(st.filter==='yes'){
      var f=Math.min(60,Math.round(50/(c*0.12)));
      out.push({t:'Wasserfilter wechseln',iv:Math.max(30,f),tip:'$tFilt',shop:'$pFilt',d:'Filterpatrone tauschen \u2013 sp\u00e4testens nach 2 Monaten.'});
    }
    out.push({t:'Grundwartung in der Werkstatt',iv:365,tip:'$tWart',shop:'',d:'Einmal j\u00e4hrlich: Innenreinigung, Dichtungen, Funktions- und Sicherheitspr\u00fcfung.'});
    return out;
  }

  function z(n){return (n<10?'0':'')+n;}
  function icsStamp(d){return d.getUTCFullYear()+z(d.getUTCMonth()+1)+z(d.getUTCDate())+'T'+z(d.getUTCHours())+z(d.getUTCMinutes())+z(d.getUTCSeconds())+'Z';}
  function icsDay(d){return d.getFullYear()+z(d.getMonth()+1)+z(d.getDate());}
  function esc(x){return String(x).split('\\').join('\\\\').split(';').join('\\;').split(',').join('\\,').split('\n').join('\\n');}
  function fold(s){ var o=[]; s.split('\r\n').forEach(function(ln){ while(ln.length>73){ o.push(ln.slice(0,73)); ln=' '+ln.slice(73); } o.push(ln); }); return o.join('\r\n'); }
  function makeIcs(all,today){
    var now=new Date();
    var list=all.filter(function(tk){return tk.iv>=3;});
    var L=['BEGIN:VCALENDAR','VERSION:2.0','PRODID:-//JB Kaffeemaschinen//Pflegeplaner//DE','CALSCALE:GREGORIAN','METHOD:PUBLISH'];
    list.forEach(function(tk,i){
      var due=new Date(today.getTime()+tk.iv*86400000);
      L.push('BEGIN:VEVENT');
      L.push('UID:kt-pp-'+i+'-'+now.getTime()+'@kaffeetechniker.de');
      L.push('DTSTAMP:'+icsStamp(now));
      L.push('DTSTART;VALUE=DATE:'+icsDay(due));
      L.push('SUMMARY:'+esc(tk.t)+' \u2013 Kaffeevollautomat');
      L.push('DESCRIPTION:'+esc(tk.d+' Anleitung: '+tk.tip));
      L.push('RRULE:FREQ=DAILY;INTERVAL='+Math.max(1,tk.iv));
      L.push('BEGIN:VALARM','TRIGGER:PT0S','ACTION:DISPLAY','DESCRIPTION:'+esc(tk.t),'END:VALARM');
      L.push('END:VEVENT');
    });
    L.push('END:VCALENDAR');
    return fold(L.join('\r\n'));
  }

  function render(){
    try{localStorage.setItem('kt_pp',JSON.stringify(st));}catch(e){}
    var list=build();
    var today=new Date(); today.setHours(9,0,0,0);
    var tb=document.getElementById('pp-rows'); tb.innerHTML='';
    list.forEach(function(tk){
      var due=new Date(today.getTime()+tk.iv*86400000);
      var lk=''; if(tk.shop) lk+='<a href="'+tk.shop+'">Produkt</a>'; if(tk.tip){ if(lk)lk+=' &middot; '; lk+='<a href="'+tk.tip+'">Anleitung</a>'; }
      var tr=document.createElement('tr');
      tr.innerHTML='<td><b>'+tk.t+'</b>'+(lk?'<span class="pp-lk">'+lk+'</span>':'')+'</td><td>'+ivText(tk.iv)+'</td><td>'+fmt(due)+'</td>';
      tb.appendChild(tr);
    });
    var a=document.getElementById('pp-ics');
    if(a.dataset.u){ URL.revokeObjectURL(a.dataset.u); }
    var blob=new Blob([makeIcs(list,today)],{type:'text/calendar;charset=utf-8'});
    var u=URL.createObjectURL(blob); a.href=u; a.dataset.u=u;
    var res=document.getElementById('pp-res'); res.hidden=false;
    res.scrollIntoView({behavior:'smooth',block:'start'});
  }
  document.getElementById('pp-go').addEventListener('click',render);
})();
</script>
"@
  $zoneInner = (Html-Block $weHtml) + "`n`n" + $formBlock + "`n`n" + (Html-Block $html)
  Wrap-Page (@(
    (Pick-Header $p.slug),
    (Zone $C.bg '44px' '58px' $zoneInner),
    (Footer-Zone)
  ) -join "`n`n")
}

# ---------- Reparatur-Check (interaktiv, reines JS) -- TEST ----------
function ReparaturCheck-Content($p) {
  $ablauf = "$base/reparaturablauf/"
  $kosten = "$base/reparaturkosten/"
  $miet   = "$base/leihgeraete/"
  $kontakt= "$base/kontakt/"
  $shop   = "$base/kaffeemaschinen-kaufen/"
  $auftrag = if ($chrome.auftragsscheinUrl) { $chrome.auftragsscheinUrl } else { "$base/reparaturablauf/" }
  $brandOpts = (@($SD.brands) | ForEach-Object { "<option>$_</option>" }) -join ''

  $html = @"
<style>
.rc{max-width:820px;margin:0 auto;font-family:$FONT_BODY;color:$($C.text)}
.rc h1{font-family:$FONT_HEAD;font-size:22px;line-height:1.25;margin:0 0 8px;color:$($C.head)}
.rc .lead{font-size:15.5px;line-height:1.6;color:#444;margin:0 0 8px;max-width:640px}
.rc .beta{display:inline-block;font-family:$FONT_HEAD;font-size:10.5px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:#8a5a00;background:#fdf1dc;border:1px solid #f0d9b0;border-radius:4px;padding:2px 7px;margin:0 0 20px}
.rc-step{background:#fff;border:1px solid $($C.line);border-radius:10px;padding:15px 18px;margin:0 0 13px}
.rc-q{display:block;font-family:$FONT_HEAD;font-size:14px;font-weight:700;color:$($C.head);margin:0 0 10px}
.rc-opts{display:flex;flex-wrap:wrap;gap:8px}
.rc-opts button{background:#fff;border:1px solid #ccd1d8;border-radius:7px;padding:8px 13px;cursor:pointer;font-family:$FONT_BODY;font-size:13.5px;transition:border-color .12s,box-shadow .12s}
.rc-opts button:hover{border-color:#9aa3ad}
.rc-opts button.on{border-color:$($C.accent);box-shadow:inset 0 0 0 2px $($C.accent);font-weight:700}
.rc select,.rc input[type=number]{width:100%;max-width:340px;padding:9px 11px;border:1px solid #c4c4c4;border-radius:6px;font-size:14.5px;font-family:$FONT_BODY;background:#fff;color:$($C.text)}
.rc-go{display:inline-block;background:$($C.accent);color:#fff;border:0;border-radius:5px;padding:13px 30px;font-family:$FONT_HEAD;font-size:15px;font-weight:700;cursor:pointer;margin:6px 0 0}
.rc-go:hover{background:$($C.accentD)}
.rc-res{margin:28px 0 0}
.rc-card{background:#fff;border:1px solid $($C.line);border-radius:10px;padding:20px;margin:0 0 14px}
.rc-card h2{font-family:$FONT_HEAD;font-size:15px;margin:0 0 8px;color:$($C.head)}
.rc-card p{font-size:14.5px;line-height:1.6;margin:0 0 8px}
.rc-amp{display:flex;gap:14px;align-items:flex-start;border-radius:10px;padding:18px 20px;margin:0 0 14px}
.rc-amp .dot{flex:0 0 auto;width:16px;height:16px;border-radius:50%;margin-top:4px}
.rc-amp.g{background:#eef7f0;border:1px solid #63a375}
.rc-amp.g .dot{background:#3d8a56}
.rc-amp.y{background:#fdf6e3;border:1px solid #d9b64e}
.rc-amp.y .dot{background:#caa02e}
.rc-amp.r{background:#fbeeee;border:1px solid #d08a8a}
.rc-amp.r .dot{background:#b84c4c}
.rc-amp b{font-family:$FONT_HEAD;font-size:14.5px;color:$($C.head);display:block;margin:0 0 3px}
.rc-amp span{font-size:14px;line-height:1.55;color:#333}
.rc-price{font-family:$FONT_HEAD;font-size:20px;font-weight:700;color:$($C.head)}
.rc-btns{display:flex;flex-wrap:wrap;gap:9px;margin:14px 0 0}
.rc-btns a{display:inline-flex;background:$($C.accent);color:#fff;border-radius:4px;padding:10px 17px;font-family:$FONT_HEAD;font-size:13px;font-weight:700;text-decoration:none}
.rc-btns a.ghost{background:transparent;color:$($C.accent);border:1px solid #ccd1d8}
.rc-btns a:hover{background:$($C.accentD)}
.rc-btns a.ghost:hover{background:#f2f4f6}
.rc-dis{font-size:12px;line-height:1.6;color:#6b7178;margin:14px 0 0}
</style>
<div class="rc">
  <h1>Reparatur-Check</h1>
  <span class="beta">Test &ndash; wir freuen uns &uuml;ber R&uuml;ckmeldung</span>
  <p class="lead">Beschreiben Sie kurz Ihr Problem &ndash; Sie bekommen die wahrscheinliche Ursache, einen groben Kostenrahmen und unsere Einsch&auml;tzung, ob sich die Reparatur lohnt.</p>

  <div class="rc-step">
    <span class="rc-q">1 &middot; Um welches Ger&auml;t geht es?</span>
    <div class="rc-opts" data-k="typ">
      <button type="button" data-v="vollautomat" class="on">Kaffeevollautomat</button>
      <button type="button" data-v="siebtraeger">Siebtr&auml;germaschine</button>
    </div>
  </div>

  <div class="rc-step">
    <span class="rc-q">2 &middot; Marke</span>
    <select id="rc-brand"><option value="">Bitte w&auml;hlen</option>$brandOpts<option>andere / unbekannt</option></select>
  </div>

  <div class="rc-step">
    <span class="rc-q">3 &middot; Was ist das Problem?</span>
    <select id="rc-sym">
      <option value="">Bitte w&auml;hlen</option>
      <option value="kein-wasser">Kein Wasser / kein Kaffee</option>
      <option value="langsam">Kaffee l&auml;uft zu langsam oder zu wenig</option>
      <option value="bruehgruppe">Br&uuml;hgruppe klemmt / l&auml;sst sich nicht einsetzen</option>
      <option value="undicht">Ger&auml;t ist undicht / Wasser unter dem Ger&auml;t</option>
      <option value="fehler">Fehlermeldung / Blinken / Fehlercode</option>
      <option value="mahlwerk">Mahlwerk laut oder mahlt nicht</option>
      <option value="milch">Kein oder schlechter Milchschaum</option>
      <option value="kalt">Kaffee zu kalt / schmeckt nicht</option>
      <option value="tot">Ger&auml;t reagiert nicht mehr</option>
      <option value="anderes">Anderes / wei&szlig; ich nicht</option>
    </select>
  </div>

  <div class="rc-step">
    <span class="rc-q">4 &middot; Wie alt ist das Ger&auml;t ungef&auml;hr?</span>
    <div class="rc-opts" data-k="alter">
      <button type="button" data-v="a">unter 2 Jahre</button>
      <button type="button" data-v="b" class="on">2 &ndash; 5 Jahre</button>
      <button type="button" data-v="c">5 &ndash; 8 Jahre</button>
      <button type="button" data-v="d">&uuml;ber 8 Jahre</button>
      <button type="button" data-v="x">wei&szlig; ich nicht</button>
    </div>
  </div>

  <div class="rc-step">
    <span class="rc-q">5 &middot; Neupreis damals (optional)</span>
    <input type="number" id="rc-price" min="0" step="10" placeholder="z. B. 800 &euro;">
  </div>

  <button type="button" class="rc-go" id="rc-go">Auswerten</button>

  <div class="rc-res" id="rc-res" hidden></div>
</div>
<script>
(function(){
  var wrap=document.querySelector('.rc'); if(!wrap) return;
  var st={typ:'vollautomat',alter:'b'};
  wrap.querySelectorAll('.rc-opts').forEach(function(g){
    var k=g.getAttribute('data-k');
    g.querySelectorAll('button').forEach(function(b){
      b.addEventListener('click',function(){ st[k]=b.getAttribute('data-v'); g.querySelectorAll('button').forEach(function(x){x.classList.remove('on')}); b.classList.add('on'); });
    });
  });

  var SY={
    'kein-wasser':{u:'Meist Verkalkung, eine schwache oder defekte Pumpe, ein verstopftes Ventil oder Luft im System.',self:'$base/stoerung-kein-wasser/',lo:0,hi:90},
    'langsam':{u:'H&auml;ufig Verkalkung, ein verstelltes oder verschlissenes Mahlwerk oder eine verharzte Br&uuml;hgruppe.',self:'$base/stoerung-kaffee-langsam/',lo:0,hi:120},
    'bruehgruppe':{u:'Verharzung, ein defekter Antrieb bzw. das Getriebe, oder die Br&uuml;hgruppe sitzt nicht in Grundstellung.',self:'$base/stoerung-bruehgruppe/',lo:40,hi:150},
    'undicht':{u:'Por&ouml;se Dichtungen, ein Riss in Schlauch oder Tank, oder ein verkalktes Ventil.',self:'$base/stoerung-undicht/',lo:20,hi:110},
    'fehler':{u:'Je nach Code: Verkalkung, ein Sensor, der Antrieb oder die Heizung &ndash; der Code grenzt die Ursache meist klar ein.',self:'$base/jura-fehlercodes/',lo:0,hi:160},
    'mahlwerk':{u:'Oft ein Fremdk&ouml;rper (z.&nbsp;B. ein Steinchen), stumpfe Mahlscheiben oder ein defekter Mahlwerksmotor.',self:'$base/stoerung-kaffee-langsam/',lo:50,hi:150},
    'milch':{u:'Meist ein verschmutztes oder verkalktes Milchsystem, eine falsche Einstellung oder eine defekte Venturid&uuml;se.',self:'$base/stoerung-milchschaum/',lo:0,hi:70},
    'kalt':{u:'Verkalkte oder defekte Heizung, verstellte Temperatur oder ein defekter Thermoblock.',self:'$base/stoerung-kaffee-kalt/',lo:20,hi:150},
    'tot':{u:'Netzteil, Hauptschalter, Kabel oder Elektronik &ndash; das muss in der Werkstatt gepr&uuml;ft werden.',self:'',lo:30,hi:200},
    'anderes':{u:'Wir sehen uns das Ger&auml;t an und melden uns mit einem Kostenvoranschlag, bevor etwas gemacht wird.',self:'$base/reparaturablauf/',lo:0,hi:160}
  };
  var YEARS={a:1,b:3.5,c:6.5,d:10,x:null};

  document.getElementById('rc-go').addEventListener('click',function(){
    var symK=document.getElementById('rc-sym').value;
    var price=parseFloat(document.getElementById('rc-price').value)||0;
    if(!symK){ alert('Bitte w' + String.fromCharCode(228) + 'hlen Sie ein Problem aus.'); return; }
    var s=SY[symK];
    var base=(st.typ==='siebtraeger')?300:160;
    var lo=base+s.lo, hi=base+s.hi;
    var mid=(lo+hi)/2;
    var years=YEARS[st.alter];
    var np=price>0?price:((st.typ==='siebtraeger')?1200:700);

    var amp='g',t='',tx='';
    if((years!==null&&years>=8)||(mid>np*0.5)){
      amp='r'; t='Eher Richtung Neuger&auml;t';
      tx='Der voraussichtliche Aufwand liegt &uuml;ber der H&auml;lfte des Neuwerts'+(years&&years>=8?' und das Ger&auml;t ist bereits einige Jahre im Einsatz':'')+'. Eine Reparatur kann sich noch lohnen, wenn Ihnen das Ger&auml;t viel wert ist &ndash; wirtschaftlich ist meist ein neues Ger&auml;t die bessere Wahl. Wir beraten Sie ehrlich.';
    } else if((years!==null&&years>=5)||(mid>np/3)){
      amp='y'; t='Reparatur meist sinnvoll &ndash; kurz abw&auml;gen';
      tx='Der Aufwand liegt im mittleren Bereich. Bei einem gepflegten Ger&auml;t und verf&uuml;gbaren Ersatzteilen lohnt sich die Reparatur in der Regel. Wir pr&uuml;fen das Ger&auml;t und machen einen Kostenvoranschlag, bevor etwas repariert wird.';
    } else {
      amp='g'; t='Reparatur lohnt sich';
      tx='Das Ger&auml;t ist noch jung und der Aufwand &uuml;berschaubar. Eine Reparatur ist klar die wirtschaftlichere Wahl.';
    }

    var selfHtml='';
    if(s.self){ selfHtml='<p><b>Erst selbst probieren:</b> Ein paar Handgriffe l&ouml;sen das Problem oft schon. <a href="'+s.self+'">Zur Anleitung</a>.</p>'; }
    else { selfHtml='<p><b>Fall f&uuml;r die Werkstatt:</b> Hier hilft Ausprobieren nicht weiter &ndash; das Ger&auml;t sollte gepr&uuml;ft werden.</p>'; }

    var pruef=(st.typ==='siebtraeger')?'100':'80';
    var h='';
    h+='<div class="rc-card"><h2>Wahrscheinliche Ursache</h2><p>'+s.u+'</p>'+selfHtml+'</div>';
    h+='<div class="rc-card"><h2>Grober Kostenrahmen</h2>';
    h+='<p class="rc-price">ca. '+lo+' &ndash; '+hi+' &euro;</p>';
    h+='<p>Enthalten sind Grundwartung, Kleinteile und Arbeitszeit. Sind gr&ouml;&szlig;ere Ersatzteile n&ouml;tig, bekommen Sie vorab einen Kostenvoranschlag. Bei abgelehntem Kostenvoranschlag f&auml;llt eine Pr&uuml;fpauschale an ('+pruef+' &euro;).</p>';
    h+='<p style="font-size:13px;color:#6b7178">Genaue Preise je Ger&auml;tekategorie: <a href="$kosten">Dauer &amp; Kosten</a>.</p></div>';
    h+='<div class="rc-amp '+amp+'"><span class="dot"></span><span><b>'+t+'</b>'+tx+' Die Ersatzteilversorgung ist f&uuml;r g&auml;ngige Marken gut; bei sehr alten oder seltenen Ger&auml;ten pr&uuml;fen wir die Verf&uuml;gbarkeit vorab.</span></div>';
    h+='<div class="rc-card"><h2>So geht es weiter</h2><p>Bringen Sie das Ger&auml;t einfach w&auml;hrend der &Ouml;ffnungszeiten vorbei &ndash; ohne Termin. Wir pr&uuml;fen es und melden uns mit einem Kostenvoranschlag.</p>';
    h+='<div class="rc-btns"><a href="$auftrag">Auftragsschein ausf&uuml;llen</a><a class="ghost" href="$ablauf">Ablauf im Detail</a><a class="ghost" href="$miet">Mietger&auml;t</a>';
    if(amp==='r'){ h+='<a class="ghost" href="$shop">Neue Ger&auml;te ansehen</a>'; }
    h+='<a class="ghost" href="$kontakt">Frage stellen</a></div></div>';
    h+='<p class="rc-dis">Alle Angaben sind grobe Richtwerte aus unserer Werkstattpraxis und ersetzen keine Pr&uuml;fung des Ger&auml;ts. Verbindlich ist erst der Kostenvoranschlag nach Sichtung.</p>';

    var res=document.getElementById('rc-res');
    res.innerHTML=h; res.hidden=false;
    res.scrollIntoView({behavior:'smooth',block:'start'});
  });
})();
</script>
"@
  Wrap-Page (@(
    (Pick-Header $p.slug),
    (Zone $C.bg '44px' '58px' (Html-Block $html)),
    (Footer-Zone)
  ) -join "`n`n")
}

# ---------- Anlegen / Aktualisieren (immer draft) ----------
$results = @()
foreach ($p in $data.pages) {
  $content = switch ($p.kind) {
    'jura-marke'    { Jura-Marke-Content $p; break }
    'jura-kategorie'{ Jura-Kategorie-Content $p; break }
    'jura-liste'    { Jura-Liste-Content $p; break }
    'kaffee-tee'    { KaffeeTee-Content $p; break }
    'wartungserinnerung' { Wartungserinnerung-Content $p; break }
    'reparatur-check' { ReparaturCheck-Content $p; break }
    'nivona-marke'    { Jura-Marke-Content $p 'nivona'; break }
    'nivona-kategorie'{ Jura-Kategorie-Content $p 'nivona'; break }
    default         {
      if ($p.slug -eq 'start') { Start-Content }
      elseif ($p.slug -eq 'hilfethemen' -and $FAQ_HUB) { Faq-Hub-Content $p }
      else { Sub-Content $p }
    }
  }
  # template 'blank' = Extendable-Vorlage ohne Theme-Header/-Footer/-Titel
  # (jede Seite bringt Kopf + Fuss selbst mit; sonst doppelte Navigation)
  # WICHTIG: vorhandenen status NICHT ueberschreiben (sonst wird eine
  # veroeffentlichte Seite bei jedem Build zurueck auf draft gesetzt).
  $body = @{ title = $p.title; slug = $p.slug; content = $content; excerpt = $p.excerpt; template = 'blank' }
  $existing = wp GET "/wp/v2/pages?slug=$($p.slug)&status=publish,draft,pending,private&_fields=id,status"
  if ($existing -and @($existing).Count -ge 1) {
    $res = wp POST "/wp/v2/pages/$(@($existing)[0].id)" $body
    $action = "aktualisiert ($(@($existing)[0].status))"
  } else {
    $body.status = 'draft'
    $res = wp POST "/wp/v2/pages" $body
    $action = 'neu (draft)'
  }
  $results += [pscustomobject]@{ menu = $p.menu; titel = $res.title.rendered; id = $res.id; slug = $res.slug; status = $res.status; link = $res.link; aktion = $action }
  Write-Host ("[{0,-11}] {1,-16} ID {2,-4} status={3}" -f $action, $p.slug, $res.id, $res.status)
}

$results | ConvertTo-Json -Depth 5 | Set-Content "$root\_page-results.json" -Encoding utf8
Write-Host "`nUebersicht (alle als Entwurf):" -ForegroundColor Cyan
$results | Format-Table menu, id, slug, status -AutoSize
Write-Host "Vorschau je Seite: wp-admin -> Seiten -> <Titel> -> Vorschau"

# Shop-Kopfzeile fuer die Theme-Vorlage 'header' (Produkt-/Warenkorb-/Kasse-Seiten)
# ablegen -> build-theme-nav.ps1 schreibt sie in die Vorlage.
Shop-Bar-Html $null | Set-Content "$root\theme-shopbar.html" -Encoding utf8
Write-Host "theme-shopbar.html geschrieben (fuer build-theme-nav.ps1)."

# dunkler Footer als Theme-Footer-Vorlage (Produkt-/Warenkorb-/Kasse-/Konto-Seiten)
$themeFooter = "<div style=`"background:$($C.dark2);padding:48px 24px 36px`">`n" + (Footer-Inner-Html) + "`n</div>"
$themeFooter | Set-Content "$root\theme-footer.html" -Encoding utf8
Write-Host "theme-footer.html geschrieben (fuer build-theme-footer.ps1)."
