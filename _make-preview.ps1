# Erzeugt eine einzelne Vorschau-HTML aus allen Entwurfsseiten (fuer ein Artifact).
$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$root\wp-lib.ps1" | Out-Null

$order = @(
  'start','reparatur','marken','reparaturablauf','reparaturdauer','reparaturkosten','gewaehrleistung','hinweise-nach-der-reparatur',
  'leihgeraete','wertgarantie','wartung',
  'kaffeemaschinen-kaufen','jura','jura-kaffeevollautomaten','jura-zubehoer','jura-pflegeprodukte','jura-professional','nivona','nivona-kaffeevollautomaten','kaffeemaschine-mieten','kaffeemaschine-leasen','pflegemittel','unser-kaffee','unser-kaffee-wissen','wartungserinnerung','reparatur-check',
  'hilfethemen','ueber-uns','anfahrt','jobs','kontakt',
  'impressum','datenschutz','agb','widerruf'
)
$labels = @{
  'start'='Start'; 'reparatur'='Reparatur'; 'marken'='Marken'; 'reparaturablauf'='Reparaturablauf'
  'reparaturdauer'='Reparaturdauer (Weiterleitung)'; 'reparaturkosten'='Dauer & Kosten'; 'gewaehrleistung'='Gewaehrleistung (Weiterleitung)'; 'hinweise-nach-der-reparatur'='Hinweise nach der Reparatur'; 'unser-kaffee-wissen'='Unser Kaffee (Wissen)'
  'leihgeraete'='Ersatzgeraet fuer die Reparaturzeit'; 'wertgarantie'='WERTGARANTIE Reparaturschutz'; 'wartung'='Wartung'; 'wartungserinnerung'='Wartungserinnerung (Tool)'; 'reparatur-check'='Reparatur-Check (Tool)'
  'kaffeemaschinen-kaufen'='Neue Kaffeemaschinen'; 'jura'='JURA Online-Shop'; 'jura-kaffeevollautomaten'='JURA Kaffeevollautomaten'; 'jura-zubehoer'='JURA Zubehoer'; 'jura-pflegeprodukte'='JURA Pflegeprodukte'; 'jura-professional'='JURA Professional'; 'nivona'='NIVONA Online-Shop'; 'nivona-kaffeevollautomaten'='NIVONA Kaffeevollautomaten'; 'kaffeemaschine-mieten'='Mieten & Leasen'
  'kaffeemaschine-leasen'='Kaffeemaschine leasen (Weiterleitung)'; 'pflegemittel'='Pflegemittel & Zubehoer'; 'unser-kaffee'='Unser Kaffee & Tee'
  'hilfethemen'='Hilfe & Wissen'; 'ueber-uns'='Das Unternehmen'; 'anfahrt'='Anfahrt & Standort'; 'jobs'='Jobs & Karriere'
  'kontakt'='Kontakt'; 'impressum'='Impressum'; 'datenschutz'='Datenschutz'; 'agb'='AGB'; 'widerruf'='Widerrufsbelehrung'
}
$groups = @(
  @{ h='Hauptmenue'; items=@('start') }
  @{ h='Reparatur'; items=@('reparatur','reparatur-check','marken','reparaturablauf','reparaturdauer','reparaturkosten','gewaehrleistung','hinweise-nach-der-reparatur','leihgeraete','wertgarantie') }
  @{ h='Wartung'; items=@('wartung','wartungserinnerung') }
  @{ h='Kaufen'; items=@('kaffeemaschinen-kaufen','jura','jura-kaffeevollautomaten','jura-professional','jura-zubehoer','jura-pflegeprodukte','nivona','nivona-kaffeevollautomaten','kaffeemaschine-mieten','kaffeemaschine-leasen','pflegemittel','unser-kaffee','unser-kaffee-wissen') }
  @{ h='Hilfe & Wissen'; items=@('hilfethemen') }
  @{ h='Ueber uns'; items=@('ueber-uns','anfahrt','jobs') }
  @{ h='Kontakt'; items=@('kontakt') }
  @{ h='Footer / Rechtliches'; items=@('impressum','datenschutz','agb','widerruf') }
)

# Logo als data-URI einbetten (im Artifact sind externe Bild-Hosts gesperrt)
$logoDataUri = ''
$logoFile = Join-Path $root 'Logo mit text.png'
if (Test-Path $logoFile) {
  $bytes = [IO.File]::ReadAllBytes($logoFile)
  $logoDataUri = 'data:image/png;base64,' + [Convert]::ToBase64String($bytes)
}

# lokale Bilddateien nach Basisname -> data-URI (fuer die Artifact-Vorschau)
$mimeByExt = @{ '.png'='image/png'; '.jpg'='image/jpeg'; '.jpeg'='image/jpeg'; '.gif'='image/gif'; '.webp'='image/webp'; '.svg'='image/svg+xml' }
$localImg = @{}
$script:remoteImg = @{}
foreach ($f in (Get-ChildItem "$root\assets" -Recurse -File -ErrorAction SilentlyContinue)) {
  if ($mimeByExt.ContainsKey($f.Extension.ToLower())) {
    $localImg[$f.Name.ToLower()] = 'data:' + $mimeByExt[$f.Extension.ToLower()] + ';base64,' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($f.FullName))
  }
}

$pagesHtml = ''
foreach ($slug in $order) {
  $p = wp GET "/wp/v2/pages?slug=$slug&status=draft,publish&_fields=slug,content"
  $html = @($p)[0].content.rendered
  if (-not $html) { continue }
  # Google-Maps-iframe fuer die Artifact-Vorschau ersetzen (externe Hosts sind dort gesperrt)
  $html = [regex]::Replace($html, '<iframe[^>]*google\.com/maps[^>]*>\s*</iframe>',
    '<div style="background:#e2e0dc;border:1px dashed #b7b3ac;padding:40px 16px;text-align:center;color:#777;font-family:sans-serif;font-size:14px">Google-Maps-Karte &ndash; in der Live-Seite sichtbar</div>')
  # externe Skripte (WERTGARANTIE-Widget) fuer die Artifact-Vorschau durch Platzhalter ersetzen
  $html = [regex]::Replace($html, '<div id="wg-hyve-site-connect"[^>]*></div>\s*<script[^>]*hyve-site-connect[^>]*></script>',
    '<div style="background:#eef1f4;border:1px dashed #b7c2cf;padding:44px 16px;text-align:center;color:#5a6b7a;font-family:sans-serif;font-size:14px">WERTGARANTIE Online-Rechner &ndash; auf der Live-Seite sichtbar</div>')
  # Logo-<img> durch ein leichtes <span> ersetzen; das Bild steckt einmalig im CSS (siehe unten)
  if ($logoDataUri) {
    $html = [regex]::Replace($html,
      '<img[^>]*jb-logo-kaffeemaschinen[^>]*>',
      '<span class="kt-logo-img" role="img" aria-label="JB Kaffeemaschinen Service und Verkauf"></span>')
  }
  # alle uebrigen hochgeladenen Bilder (Hersteller-Logos, Siegel, Fotos, JURA-Packshots) einbetten:
  # erst lokal aus assets/ suchen, sonst einmalig vom Server laden und als data-URI cachen
  $html = [regex]::Replace($html, 'https://new\.kaffeetechniker\.de/wp-content/uploads/[^"'' )]*/([^"'' )/]+\.(?:png|jpe?g|gif|webp|svg))', {
    param($m)
    $url  = $m.Value
    $name = $m.Groups[1].Value.ToLower()
    if ($localImg.ContainsKey($name)) { return $localImg[$name] }
    if ($script:remoteImg.ContainsKey($url)) { return $script:remoteImg[$url] }
    try {
      $r    = Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop
      $ext  = [IO.Path]::GetExtension($name).ToLower()
      $mime = if ($mimeByExt.ContainsKey($ext)) { $mimeByExt[$ext] } else { 'image/jpeg' }
      $bytes = $r.Content
      # grosse Fotos fuer die Vorschau verkleinern (Artifact-Limit 16 MB)
      if ($bytes.Length -gt 140000 -and ($ext -in '.jpg', '.jpeg', '.png')) {
        try {
          Add-Type -AssemblyName System.Drawing
          $ms  = New-Object IO.MemoryStream(,$bytes)
          $img = [Drawing.Image]::FromStream($ms)
          $maxW = 1000
          if ($img.Width -gt $maxW) {
            $h2 = [int]($img.Height * $maxW / $img.Width)
            $bmp = New-Object Drawing.Bitmap($maxW, $h2)
            $g = [Drawing.Graphics]::FromImage($bmp)
            $g.InterpolationMode = 'HighQualityBicubic'
            $g.DrawImage($img, 0, 0, $maxW, $h2)
            $out = New-Object IO.MemoryStream
            $enc = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
            $ep  = New-Object Drawing.Imaging.EncoderParameters(1)
            $ep.Param[0] = New-Object Drawing.Imaging.EncoderParameter([Drawing.Imaging.Encoder]::Quality, [long]78)
            $bmp.Save($out, $enc, $ep)
            $bytes = $out.ToArray(); $mime = 'image/jpeg'
            $g.Dispose(); $bmp.Dispose(); $out.Dispose()
          }
          $img.Dispose(); $ms.Dispose()
        } catch {}
      }
      $dataUri = 'data:' + $mime + ';base64,' + [Convert]::ToBase64String($bytes)
      $script:remoteImg[$url] = $dataUri
      return $dataUri
    } catch { return $url }
  })
  $hidden = if ($slug -eq 'start') { '' } else { ' hidden' }
  $pagesHtml += "`n<div class=`"pg`" id=`"pg-$slug`"$hidden>`n$html`n</div>`n"
}

$navHtml = ''
foreach ($g in $groups) {
  $navHtml += "<div class=`"ng`"><div class=`"ngh`">$($g.h)</div>"
  foreach ($s in $g.items) {
    $navHtml += "<a href=`"#$s`" data-slug=`"$s`">$($labels[$s])</a>"
  }
  $navHtml += "</div>`n"
}

$doc = @"
<title>Vorschau &ndash; kaffeetechniker.de</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  :root{--bg:#eee;--panel:#333;--ink:#1c1c1c;--line:#d8d8d8;--accent:#334155}
  *{box-sizing:border-box}
  body{margin:0;background:#d9d7d3;color:var(--ink);font-family:'Source Sans 3',system-ui,sans-serif}
  .layout{display:flex;min-height:100vh}
  .side{width:270px;flex-shrink:0;background:#2b2b2b;color:#ccc;position:sticky;top:0;height:100vh;overflow-y:auto;padding:18px 0}
  .side h1{font-family:Tahoma,Arial,sans-serif;font-size:13px;letter-spacing:.12em;text-transform:uppercase;color:#fff;margin:0 20px 4px}
  .side .hint{font-size:11.5px;color:#8f8f8f;margin:0 20px 16px;line-height:1.5}
  .ng{margin:0 0 6px}
  .ngh{font-family:Tahoma,Arial,sans-serif;font-size:10.5px;letter-spacing:.14em;text-transform:uppercase;color:#8a8a8a;padding:12px 20px 4px}
  .side a{display:block;padding:7px 20px;color:#cdcdcd;text-decoration:none;font-size:13.5px;border-left:3px solid transparent}
  .side a:hover{background:#3a3a3a;color:#fff}
  .side a.active{background:#3f3f3f;color:#fff;border-left-color:var(--accent);font-weight:600}
  .main{flex:1;min-width:0;background:var(--bg)}
  .frame{max-width:1200px;margin:0 auto}
  .pg[hidden]{display:none}
  .kt-logo-img{display:block;height:56px;width:290px;background:url('$logoDataUri') center/contain no-repeat}
  @media(max-width:720px){ .kt-logo-img{height:44px;width:228px;margin:0 auto} }
  .toolbar{background:#1f1f1f;color:#bbb;font-size:12px;padding:8px 16px;position:sticky;top:0;z-index:5;display:flex;gap:14px;flex-wrap:wrap}
  .toolbar b{color:#fff}
  .side .mtoggle{display:none}
  @media(max-width:900px){
    .layout{flex-direction:column}
    .side{width:100%;height:auto;position:static}
    .frame{max-width:100%}
  }
</style>

<div class="layout">
  <nav class="side">
    <h1>Seiten-Vorschau</h1>
    <p class="hint">Alle Seiten sind Entwuerfe. Menue &amp; Struktur wie geplant. Interne Links und das Menue oben schalten hier zwischen den Seiten um.</p>
    $navHtml
  </nav>
  <div class="main">
    <div class="toolbar"><b>Vorschau</b> new.kaffeetechniker.de &mdash; Stand $(Get-Date -Format 'yyyy-MM-dd') &mdash; <span id="cur"></span></div>
    <div class="frame">
      $pagesHtml
    </div>
  </div>
</div>

<script>
(function(){
  var slugs = [$(($order | ForEach-Object { "'$_'" }) -join ',')];
  function show(slug){
    if(slugs.indexOf(slug)<0){ slug='start'; }
    document.querySelectorAll('.pg').forEach(function(el){ el.hidden = (el.id !== 'pg-'+slug); });
    document.querySelectorAll('.side a').forEach(function(a){ a.classList.toggle('active', a.dataset.slug===slug); });
    var cur=document.getElementById('cur'); if(cur) cur.textContent='/'+ (slug==='start'?'':slug+'/');
    window.scrollTo(0,0);
    if(location.hash!=='#'+slug){ history.replaceState(null,'','#'+slug); }
  }
  document.addEventListener('click',function(e){
    var a=e.target.closest('a'); if(!a) return;
    var href=a.getAttribute('href')||'';
    var m=href.match(/new\.kaffeetechniker\.de\/([a-z0-9-]+)\//i);
    if(!m) m=href.match(/^#([a-z0-9-]+)$/i);
    if(m){ e.preventDefault(); show(m[1].toLowerCase()); }
  });
  var initial=(location.hash||'#start').replace('#','').toLowerCase();
  show(initial);
})();
</script>
"@

$out = 'C:\Users\info\AppData\Local\Temp\claude\C--Homepage-Neue-Seite-2026\d6fde327-8546-442b-baa3-87d6a3b3766a\scratchpad\vorschau.html'
Set-Content -Path $out -Value $doc -Encoding UTF8
Write-Host "geschrieben: $out  ($([math]::Round((Get-Item $out).Length/1kb)) KB)"


