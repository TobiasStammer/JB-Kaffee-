import os, json
os.chdir(r"C:\Homepage\Neue Seite 2026")
def rd(p):
    raw=open(p,'rb').read(); return raw[:3]==b'\xef\xbb\xbf', raw.decode('utf-8-sig').replace('\r\n','\n')
def wr(p,bom,s):
    open(p,'wb').write((bytes([239,187,191]) if bom else b'')+s.replace('\n','\r\n').encode('utf-8'))
bom,s=rd('build-pages.ps1')

func = r'''
# Ladenfotos (name -> Medien-URL + Alt-Text), befuellt von upload-laden.ps1
$ladenMedia = @{}; $ladenAlt = @{}
if (Test-Path "$root\laden-media.json") {
  (Get-Content "$root\laden-media.json" -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $ladenMedia[$_.Name] = $_.Value }
  (Get-Content "$root\assets\laden\alt.json" -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $ladenAlt[$_.Name] = $_.Value }
}
# Foto-Reihe aus den Ladenbildern: Namen-Liste, optionale Bildunterschriften (Hashtable name -> Text)
function Laden-Gallery($names, $caps = @{}) {
  $figs = foreach ($n in @($names)) {
    $u = $ladenMedia[$n]; if (-not $u) { continue }
    $c = if ($caps[$n]) { "<figcaption>$($caps[$n])</figcaption>" } else { '' }
    "<figure><img src=`"$u`" alt=`"$($ladenAlt[$n])`" loading=`"lazy`">$c</figure>"
  }
  if (-not $figs) { return '' }
  $cnt = @($figs).Count
  @"
<style>
.kt-lg{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,250px),1fr));gap:14px;margin:18px auto;max-width:1000px}
.kt-lg.n1{grid-template-columns:1fr;max-width:720px}
.kt-lg figure{margin:0;border-radius:10px;overflow:hidden;background:#fff;border:1px solid $($C.line);box-shadow:0 2px 10px rgba(0,0,0,.05)}
.kt-lg img{display:block;width:100%;height:auto;aspect-ratio:4/3;object-fit:cover}
.kt-lg figcaption{font-family:$FONT_BODY;font-size:12.5px;line-height:1.5;color:#6b7178;padding:8px 12px}
</style>
<div class="kt-lg n$cnt">
  $($figs -join "`n  ")
</div>
"@
}
'''
marker="function Jura-Marke-Content($p, $brandKey = 'jura') {"
assert marker in s
s=s.replace(marker,func.lstrip('\n')+marker,1)

# Marke: Fotozone vor dem Footer
old="  $zones += (Zone $bandColors[$bi]     '46px' '52px' (Html-Block $techHtml))\n  $zones += (Footer-Zone)"
assert old in s
new=("  $zones += (Zone $bandColors[$bi]     '46px' '52px' (Html-Block $techHtml))\n"
"  $ladenNames = if ($brandKey -eq 'jura') { @('laden-jura-wand','laden-jura-aussteller','laden-jura-pflege') } else { @('laden-nivona','laden-nivona-ecke') }\n"
"  $ladenHtml = Laden-Gallery $ladenNames\n"
"  if ($ladenHtml) {\n"
"    $zones += (Zone $C.white '40px' '44px' (Html-Block ((Sec-Head 'Im Gesch&auml;ft' 'Bei uns live erleben' 'Sehen, anfassen, probieren: In unserem Ladengesch&auml;ft in Hofheim-Langenhain k&ouml;nnen Sie die Ger&auml;te direkt ausprobieren.') + \"`n\" + $ladenHtml)))\n"
"  }\n"
"  $zones += (Footer-Zone)")
s=s.replace(old,new,1)

# Kaffee & Tee: Fotozone
old="""    (Zone $C.bg '44px' '60px' (Html-Block $body)),
    (Footer-Zone)"""
i0=s.index('$KAFFEETEE_JS' + chr(10) + '"@')
i1=s.index(old,i0)
s=s[:i1]+"""    (Zone $C.bg '44px' '60px' (Html-Block $body)),
    (Zone $C.bg '0' '56px' (Html-Block (Laden-Gallery @('laden-kaffee-regal','laden-kaffee-bohnen','laden-tee-regal','laden-tee-rote-liebe')))),
    (Footer-Zone)"""+s[i1+len(old):]

# gallery-Block
old="      'image' {\n"
assert old in s
s=s.replace(old,"      'gallery' { \"<!-- wp:html -->`n$(Laden-Gallery $b.x)`n<!-- /wp:html -->\" }\n"+old,1)
wr('build-pages.ps1',bom,s)

# JSON
bom,t=rd('pages-content.json')
d=json.loads(t)
for p in d['pages']:
    if p['slug']=='ueber-uns':
        i=[k for k,b in enumerate(p['blocks']) if b['t']=='h' and b['x']=='Unser Anspruch'][0]
        p['blocks'][i:i]=[{"t":"h","lvl":2,"icon":"check","x":"Unser Gesch\u00e4ft"},
                          {"t":"p","x":"In unserem Ladengesch\u00e4ft in Hofheim-Langenhain zeigen wir Ihnen JURA und NIVONA Kaffeevollautomaten zum Ausprobieren \u2013 dazu Pflegeprodukte, Zubeh\u00f6r sowie Kaffee aus eigener R\u00f6stung und lose Teemischungen."},
                          {"t":"gallery","x":["laden-gesamt","laden-gang","laden-jura-insel"]}]
    if p['slug']=='kaffeemaschinen-kaufen':
        bl=p['blocks']
        i=[k for k,b in enumerate(bl) if b['t']=='h' and b['x']=='Nivona'][0]
        bl.insert(i,{"t":"gallery","x":["laden-jura-insel2","laden-jura-aussteller"]})
        j=[k for k,b in enumerate(bl) if b['t']=='p' and b['x'].startswith('Bei Fragen')][0]
        bl.insert(j,{"t":"gallery","x":["laden-nivona"]})
wr('pages-content.json',bom,json.dumps(d,ensure_ascii=False,indent=2))
print('ok')
