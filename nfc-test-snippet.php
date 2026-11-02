/* kaffeetechniker.de - NFC-Test fuer das Zeiterfassungs-Tablet (versteckte Seite, kein WP-Seitentyp).
 * URL: /<KT_NFC_SLUG>/ - nicht verlinkt, noindex. Zeigt Web-NFC-Status und liest Tags (UID, Typ, NDEF).
 * Es wird NICHTS gespeichert. Web NFC funktioniert nur in Chrome auf Android, ueber HTTPS, mit Bildschirm an.
 * Einbau: Code Snippets, PHP, "Ueberall ausfuehren" (Deploy: deploy-nfc-test.ps1). */
define( 'KT_NFC_SLUG', 'nfc-test-p4w8x' );

add_action( 'init', function () {
	$path = trim( (string) wp_parse_url( $_SERVER['REQUEST_URI'] ?? '', PHP_URL_PATH ), '/' );
	if ( $path !== KT_NFC_SLUG ) {
		return;
	}
	if ( ! defined( 'DONOTCACHEPAGE' ) ) {
		define( 'DONOTCACHEPAGE', true );
	}
	nocache_headers();
	header( 'Cache-Control: no-store, no-cache, must-revalidate, max-age=0' );
	header( 'X-Robots-Tag: noindex, nofollow, noarchive' );
	header( 'Referrer-Policy: no-referrer' );
	status_header( 200 );
	header( 'Content-Type: text/html; charset=utf-8' );
	echo kt_nfc_page();
	exit;
}, 1 );

function kt_nfc_page() {
	return <<<'KTHTML'
<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>NFC-Test</title>
<style>
*{box-sizing:border-box}
html,body{margin:0;background:#f2f4f6;color:#1c1c1c;font-family:system-ui,-apple-system,Segoe UI,Arial,sans-serif;font-size:18px;line-height:1.5}
.wrap{max-width:760px;margin:0 auto;padding:18px 16px 60px}
h1{font-size:24px;margin:0 0 12px}
.box{background:#fff;border:1px solid #d5d9de;border-radius:10px;padding:14px 16px;margin:0 0 14px}
.ok{color:#1a7f37;font-weight:600}.bad{color:#b42318;font-weight:600}
button{font:inherit;font-weight:600;padding:14px 22px;border:0;border-radius:10px;background:#3b2a20;color:#fff;cursor:pointer}
button:disabled{opacity:.5}
.uid{font:700 30px/1.2 ui-monospace,Consolas,monospace;letter-spacing:1px;word-break:break-all}
.log{font:14px/1.5 ui-monospace,Consolas,monospace;white-space:pre-wrap;max-height:40vh;overflow:auto}
.flash{animation:f .6s}@keyframes f{from{background:#c9f2d3}to{background:#fff}}
</style>
</head>
<body>
<div class="wrap">
<h1>NFC-Test</h1>
<div class="box" id="status">Pr&uuml;fe &hellip;</div>
<div class="box"><button id="go">Lesen starten</button></div>
<div class="box" id="last"><div style="color:#667">Noch kein Tag gelesen.</div></div>
<div class="box"><b>Verlauf</b><div class="log" id="log"></div></div>
</div>
<script>
(function(){
var st=document.getElementById('status'),go=document.getElementById('go'),last=document.getElementById('last'),log=document.getElementById('log');
var reader=null,count=0;
function line(s){log.textContent=new Date().toLocaleTimeString('de-DE')+'  '+s+'\n'+log.textContent;}
var checks=[];
checks.push(['HTTPS',location.protocol==='https:']);
checks.push(['Web NFC (NDEFReader)','NDEFReader' in window]);
checks.push(['Bildschirm-Wachhalten',!!(navigator.wakeLock)]);
st.innerHTML=checks.map(function(c){return c[0]+': <span class="'+(c[1]?'ok':'bad')+'">'+(c[1]?'ja':'nein')+'</span>';}).join('<br>')+'<br><span style="color:#667;font-size:15px">'+navigator.userAgent.replace(/</g,'&lt;')+'</span>';
if(!('NDEFReader' in window)){go.disabled=true;line('NDEFReader fehlt - Chrome auf Android und HTTPS noetig.');}
function wake(){try{navigator.wakeLock&&navigator.wakeLock.request('screen').then(function(){line('Bildschirm bleibt an (Wake Lock)');}).catch(function(e){line('Wake Lock: '+e.message);});}catch(e){}}
document.addEventListener('visibilitychange',function(){if(document.visibilityState==='visible'&&reader)wake();});
go.onclick=async function(){
 try{
  reader=new NDEFReader();
  await reader.scan();
  go.disabled=true;go.textContent='Lesen aktiv - Tag ans Tablet halten';
  line('Scan gestartet');wake();
  reader.onreadingerror=function(){line('Tag erkannt, aber nicht lesbar (z.B. Mifare Classic ohne NDEF)');};
  reader.onreading=function(ev){
   count++;
   var recs=[];
   for(var i=0;i<ev.message.records.length;i++){var r=ev.message.records[i];var t='';
    try{t=new TextDecoder(r.encoding||'utf-8').decode(r.data);}catch(e){t='(binaer)';}
    recs.push(r.recordType+': '+t);}
   last.className='box flash';
   last.innerHTML='<div style="color:#667">Tag #'+count+'</div><div class="uid">'+(ev.serialNumber||'(keine UID)')+'</div>'+(recs.length?'<div style="font-size:15px">'+recs.join('<br>').replace(/</g,'&lt;')+'</div>':'');
   void last.offsetWidth;
   line('UID '+ev.serialNumber+(recs.length?'  NDEF '+recs.join(' | '):''));
  };
 }catch(e){line('Fehler: '+e.name+' - '+e.message);st.innerHTML+='<br><span class="bad">'+e.name+': '+e.message+'</span>';}
};
})();
</script>
</body>
</html>
KTHTML;
}
