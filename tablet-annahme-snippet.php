/* kaffeetechniker.de - Tablet-Annahme im Laden (versteckte Seite, kein WP-Seitentyp).
 * URL: /<KT_TA_SLUG>/ - nicht verlinkt, noindex. Der Kunde gibt am Tablet nur Kontaktdaten ein und unterschreibt.
 * Daraus entsteht im Browser ein PDF auf der Vorlage rep-auftrag-vorlage.pdf (Mediathek, wie reparaturauftrag-Seite).
 * Danach zeigt die Seite die Daten fuer den Abgleich mit PS-WIN (Kopier-Buttons) und bietet Drucken/Download.
 * Es wird NICHTS auf dem Server gespeichert; Daten und Unterschrift bleiben im Browser des Tablets.
 * Einbau: Code Snippets, PHP, "Ueberall ausfuehren" (Deploy: scratchpad/tablet-annahme.ps1). */
define( 'KT_TA_SLUG', 'annahme-tablet-k7q3m' );

add_action( 'init', function () {
	$path = trim( (string) wp_parse_url( $_SERVER['REQUEST_URI'] ?? '', PHP_URL_PATH ), '/' );
	if ( $path !== KT_TA_SLUG ) {
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
	echo kt_ta_page();
	exit;
}, 1 );

function kt_ta_page() {
	return <<<'KTHTML'
<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>Annahme am Tablet</title>
<style>
*{box-sizing:border-box}
html,body{margin:0;background:#f2f4f6;color:#1c1c1c;font-family:'Source Sans 3','Source Sans Pro',system-ui,-apple-system,Segoe UI,Arial,sans-serif;font-size:18px;line-height:1.5;-webkit-text-size-adjust:100%}
.wrap{max-width:860px;margin:0 auto;padding:18px 16px 60px}
header{display:flex;align-items:center;justify-content:space-between;gap:12px;margin:0 0 14px}
header h1{font-family:Tahoma,Arial,sans-serif;font-size:22px;margin:0;color:#334155}
header small{color:#777;font-size:14px}
.card{background:#fff;border:1px solid #dde1e6;border-radius:10px;padding:18px 18px 20px;margin:0 0 16px}
.card h2{font-family:Tahoma,Arial,sans-serif;font-size:16px;margin:0 0 12px;padding:0 0 6px;border-bottom:1px solid #e2e2e2;color:#1c1c1c}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:14px 16px}
.full{grid-column:1/-1}
@media(max-width:620px){.grid{grid-template-columns:1fr}}
label{display:block;font-size:15px;font-weight:600;color:#334155;margin:0 0 4px}
.req::after{content:" *";color:#c0392b}
input[type=text],input[type=tel],input[type=email]{width:100%;padding:13px 14px;border:1px solid #c4c4c4;border-radius:7px;font-size:20px;font-family:inherit;background:#fff;color:#1c1c1c}
input:focus{outline:none;border-color:#334155;box-shadow:0 0 0 3px rgba(51,65,85,.15)}
.invalid{border-color:#c0392b !important;background:#fdf3f3}
.sig{position:relative;border:2px dashed #94a3b8;border-radius:10px;background:#fff;height:210px;touch-action:none}
.sig canvas{position:absolute;inset:0;width:100%;height:100%;touch-action:none;border-radius:8px}
.sig .ph{position:absolute;left:0;right:0;top:50%;transform:translateY(-50%);text-align:center;color:#a0aab6;font-size:20px;pointer-events:none}
.sig .line{position:absolute;left:5%;right:5%;bottom:38px;border-bottom:1px solid #94a3b8;pointer-events:none}
.sig.invalid{border-color:#c0392b}
.txt{font-size:15px;color:#444;margin:0 0 10px}
.note{font-size:13.5px;color:#777;margin:10px 0 0}
.btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;border:0;border-radius:8px;padding:15px 28px;font-family:Tahoma,Arial,sans-serif;font-weight:700;font-size:18px;cursor:pointer;background:#334155;color:#fff;text-decoration:none}
.btn.sec{background:#fff;color:#334155;border:1px solid #334155}
.btn[disabled]{opacity:.6;cursor:default}
.row{display:flex;flex-wrap:wrap;gap:12px;margin-top:6px}
.err{margin:12px 0 0;padding:12px 14px;background:#fbeeee;border:1px solid #d8a0a0;color:#8a3b3b;border-radius:8px;font-size:16px}
.err[hidden],[hidden]{display:none !important}
.big{font-family:Tahoma,Arial,sans-serif;font-size:30px;font-weight:700;color:#1c1c1c;margin:0 0 4px}
.kv{display:grid;grid-template-columns:130px 1fr auto;gap:8px 12px;align-items:center;margin:0}
.kv div.k{font-size:15px;color:#777}
.kv div.v{font-size:20px;font-weight:600;word-break:break-word}
.cp{border:1px solid #c4c4c4;background:#fff;border-radius:7px;padding:8px 14px;font-size:15px;cursor:pointer;font-family:inherit}
.cp.done{background:#eef7f0;border-color:#63a375;color:#2f5d3f}
.hint{background:#eef2f7;border:1px solid #cdd6e2;border-radius:8px;padding:12px 14px;font-size:15px;color:#334155;margin:0 0 16px}
</style>
</head>
<body>
<div class="wrap">
<header><h1>Reparaturauftrag &ndash; Ihre Daten</h1><small>Joachim Bl&ouml;chle Elektro-Service GmbH</small></header>

<!-- Schritt 1: Kunde -->
<form id="ta-form" novalidate autocomplete="off">
  <div class="card">
    <h2>Ihre Kontaktdaten</h2>
    <div class="grid">
      <div><label class="req" for="nachname">Nachname</label><input type="text" id="nachname" name="nachname" autocapitalize="words" autocomplete="off"></div>
      <div><label class="req" for="vorname">Vorname</label><input type="text" id="vorname" name="vorname" autocapitalize="words" autocomplete="off"></div>
      <div class="full"><label class="req" for="strasse">Stra&szlig;e und Hausnummer</label><input type="text" id="strasse" name="strasse" autocapitalize="words" autocomplete="off"></div>
      <div><label class="req" for="plzort">PLZ, Ort</label><input type="text" id="plzort" name="plzort" autocapitalize="words" autocomplete="off"></div>
      <div><label class="req" for="telefon">Telefon</label><input type="tel" id="telefon" name="telefon" autocomplete="off"></div>
      <div class="full"><label for="email">E-Mail <span style="font-weight:400;color:#777">(optional)</span></label><input type="email" id="email" name="email" autocomplete="off"></div>
    </div>
  </div>

  <div class="card">
    <h2>Unterschrift</h2>
    <p class="txt">Hiermit best&auml;tige ich die ordnungsgem&auml;&szlig;e Auflistung der Ger&auml;teanteile, die von mir abgegeben werden, und erteile den Auftrag. Eine Reparaturkostenermittlung wird mit 60,00&nbsp;&euro; berechnet, wenn keine Reparatur ausgef&uuml;hrt wird.</p>
    <div class="sig" id="ta-sig"><canvas id="ta-cv"></canvas><div class="ph" id="ta-ph">Hier mit dem Finger unterschreiben</div><div class="line"></div></div>
    <div class="row"><button type="button" class="btn sec" id="ta-clear">Unterschrift l&ouml;schen</button></div>
    <p class="note">Ihre Angaben werden nur f&uuml;r die Auftragsbearbeitung genutzt. Sie werden nicht im Internet gespeichert, sondern nur auf diesem Tablet in den Auftragsschein eingetragen.</p>
  </div>

  <div class="err" id="ta-err" hidden></div>
  <div class="row"><button type="submit" class="btn" id="ta-go">Fertig &ndash; Auftragsschein erstellen</button></div>
</form>

<!-- Schritt 2: Mitarbeiter -->
<div id="ta-done" hidden>
  <div class="hint"><b>Bitte Tablet an Mitarbeiter zur&uuml;ckgeben.</b> Der Auftragsschein ist fertig. Zuerst drucken, dann den Kunden in PS-WIN suchen oder neu anlegen.</div>
  <div class="card">
    <h2>Auftragsschein</h2>
    <div class="row" style="margin-top:0">
      <button type="button" class="btn" id="ta-print">Drucken</button>
      <a class="btn sec" id="ta-open" target="_blank" rel="noopener">PDF &ouml;ffnen</a>
      <a class="btn sec" id="ta-dl">PDF speichern</a>
    </div>
    <p class="note" id="ta-printnote" hidden>Falls das Drucken nicht startet: &bdquo;PDF &ouml;ffnen&ldquo; und dort drucken.</p>
  </div>
  <div class="card">
    <h2>Kundendaten f&uuml;r PS-WIN</h2>
    <div class="big" id="ta-name"></div>
    <p class="note" style="margin:0 0 12px">In PS-WIN unter Adressverwaltung nach dem Nachnamen suchen und Adresse und Telefon abgleichen. Ist der Kunde neu, mit den Kopier-Buttons anlegen.</p>
    <div class="kv" id="ta-kv"></div>
  </div>
  <div class="row"><button type="button" class="btn sec" id="ta-new">N&auml;chster Kunde (Eingaben l&ouml;schen)</button></div>
</div>
</div>

<script src="/ktc-assets/pdf-lib.min.js"></script>
<script>
(function(){
  var TPL='/wp-content/uploads/2026/09/rep-auftrag-vorlage.pdf';
  var f=document.getElementById('ta-form'), done=document.getElementById('ta-done');
  var err=document.getElementById('ta-err'), go=document.getElementById('ta-go');
  var sig=document.getElementById('ta-sig'), cv=document.getElementById('ta-cv'), ph=document.getElementById('ta-ph');
  var ctx, drawing=false, hasInk=false, last=null, bbox=null, pdfUrl=null;

  function val(n){ return String(f.elements[n].value||'').trim(); }

  // ---------- Unterschriftenfeld ----------
  function sizeCanvas(){
    var r=sig.getBoundingClientRect(), d=Math.max(window.devicePixelRatio||1,1.5);
    var old=hasInk?cv.toDataURL():null;
    cv.width=Math.round(r.width*d); cv.height=Math.round(r.height*d);
    ctx=cv.getContext('2d'); ctx.scale(d,d);
    ctx.lineWidth=2.6; ctx.lineCap='round'; ctx.lineJoin='round'; ctx.strokeStyle='#0b1220';
    if(old){ var im=new Image(); im.onload=function(){ ctx.drawImage(im,0,0,r.width,r.height); }; im.src=old; }
  }
  function pos(e){ var r=cv.getBoundingClientRect(); return {x:e.clientX-r.left,y:e.clientY-r.top}; }
  function grow(p){
    if(!bbox) bbox={x0:p.x,y0:p.y,x1:p.x,y1:p.y};
    else { bbox.x0=Math.min(bbox.x0,p.x); bbox.y0=Math.min(bbox.y0,p.y); bbox.x1=Math.max(bbox.x1,p.x); bbox.y1=Math.max(bbox.y1,p.y); }
  }
  cv.addEventListener('pointerdown',function(e){
    e.preventDefault(); cv.setPointerCapture(e.pointerId);
    drawing=true; last=pos(e); hasInk=true; ph.hidden=true; sig.classList.remove('invalid'); grow(last);
    ctx.beginPath(); ctx.arc(last.x,last.y,1.3,0,6.283); ctx.fillStyle='#0b1220'; ctx.fill();
  });
  cv.addEventListener('pointermove',function(e){
    if(!drawing) return; e.preventDefault();
    var p=pos(e); ctx.beginPath(); ctx.moveTo(last.x,last.y); ctx.lineTo(p.x,p.y); ctx.stroke(); last=p; grow(p);
  });
  ['pointerup','pointercancel','pointerleave'].forEach(function(t){ cv.addEventListener(t,function(){ drawing=false; }); });
  function clearSig(){ var r=sig.getBoundingClientRect(); ctx.clearRect(0,0,r.width,r.height); hasInk=false; bbox=null; ph.hidden=false; }
  document.getElementById('ta-clear').addEventListener('click',clearSig);
  window.addEventListener('load',sizeCanvas);
  sizeCanvas();

  // ---------- Pruefen ----------
  function validate(){
    var miss=[];
    [['nachname','Nachname'],['vorname','Vorname'],['strasse','Straße und Hausnummer'],['plzort','PLZ, Ort'],['telefon','Telefon']].forEach(function(p){
      var el=f.elements[p[0]], bad=!val(p[0]); el.classList.toggle('invalid',bad); if(bad) miss.push(p[1]);
    });
    var email=val('email');
    if(email && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)){ f.elements.email.classList.add('invalid'); miss.push('gültige E-Mail'); } else f.elements.email.classList.remove('invalid');
    if(!hasInk){ sig.classList.add('invalid'); miss.push('Unterschrift'); }
    return miss;
  }

  f.addEventListener('submit',function(e){
    e.preventDefault();
    var miss=validate();
    if(miss.length){
      err.innerHTML='Bitte noch ausfüllen: <b>'+miss.join(', ')+'</b>.'; err.hidden=false;
      err.scrollIntoView({behavior:'smooth',block:'center'}); return;
    }
    err.hidden=true;
    if(typeof PDFLib==='undefined'){ err.textContent='PDF-Bibliothek konnte nicht geladen werden. Bitte Seite neu laden.'; err.hidden=false; return; }
    go.disabled=true; go.textContent='PDF wird erstellt …';
    build().catch(function(x){
      go.disabled=false; go.innerHTML='Fertig &ndash; Auftragsschein erstellen';
      err.textContent='Fehler beim Erstellen: '+x; err.hidden=false;
    });
  });

  // ---------- PDF ----------
  function signatureCrop(){
    var d=cv.width/sig.getBoundingClientRect().width, pad=8;
    var x0=Math.max(0,Math.floor((bbox.x0-pad)*d)), y0=Math.max(0,Math.floor((bbox.y0-pad)*d));
    var x1=Math.min(cv.width,Math.ceil((bbox.x1+pad)*d)), y1=Math.min(cv.height,Math.ceil((bbox.y1+pad)*d));
    var w=Math.max(1,x1-x0), h=Math.max(1,y1-y0);
    var t=document.createElement('canvas'); t.width=w; t.height=h;
    t.getContext('2d').drawImage(cv,x0,y0,w,h,0,0,w,h);
    return t.toDataURL('image/png');
  }
  function safe(font,s,size){ // Zeichen, die Helvetica (WinAnsi) nicht kann, entschaerfen
    var out='';
    String(s||'').split('').forEach(function(ch){
      try{ font.widthOfTextAtSize(ch,size); out+=ch; }
      catch(e){ var b=ch.normalize('NFD').replace(/[̀-ͯ]/g,''); try{ font.widthOfTextAtSize(b,size); out+=b; }catch(e2){ out+='?'; } }
    });
    return out;
  }

  async function build(){
    var buf=await fetch(TPL).then(function(r){ if(!r.ok) throw 'Vorlage nicht erreichbar ('+r.status+')'; return r.arrayBuffer(); });
    var doc=await PDFLib.PDFDocument.load(buf);
    var page=doc.getPages()[0], H=page.getHeight();
    var font=await doc.embedFont(PDFLib.StandardFonts.Helvetica);
    function T(str,x,topY,size){ size=size||10; page.drawText(safe(font,str,size),{x:x,y:H-topY,size:size,font:font,color:PDFLib.rgb(0.08,0.08,0.1)}); }

    // Positionen wie auf der Seite /reparaturauftrag/
    T(val('nachname'),108,182);
    T(val('vorname'),100,214);
    T(val('strasse'),90,246.5);
    T(val('plzort'),98,279.5);
    T(val('telefon'),95,312.5);

    // Unterschrift ueber der Linie "Unterschrift: ____" (Linie ca. 975 von oben, x ca. 309-537)
    var png=await doc.embedPng(signatureCrop());
    var maxW=235, maxH=38, sc=Math.min(maxW/png.width,maxH/png.height), w=png.width*sc, h=png.height*sc;
    page.drawImage(png,{x:309+(maxW-w)/2,y:H-973,width:w,height:h});
    var dt=new Date(), p=function(n){return (n<10?'0':'')+n};
    T('Hofheim, '+p(dt.getDate())+'.'+p(dt.getMonth()+1)+'.'+dt.getFullYear(),552,973,8.5);

    var bytes=await doc.save();
    if(pdfUrl) URL.revokeObjectURL(pdfUrl);
    pdfUrl=URL.createObjectURL(new Blob([bytes],{type:'application/pdf'}));
    var fn=('Reparaturauftrag_'+val('nachname')).replace(/[^A-Za-z0-9_\-]/g,'_')+'.pdf';
    document.getElementById('ta-open').href=pdfUrl;
    var dl=document.getElementById('ta-dl'); dl.href=pdfUrl; dl.download=fn;
    showDone();
  }

  // ---------- Ergebnis fuer Mitarbeiter ----------
  function showDone(){
    document.getElementById('ta-name').textContent=val('nachname')+', '+val('vorname');
    var rows=[['Nachname',val('nachname')],['Vorname',val('vorname')],['Straße',val('strasse')],['PLZ, Ort',val('plzort')],['Telefon',val('telefon')]];
    var plz=val('plzort').match(/^(\d{4,5})\s+(.*)$/);
    if(plz){ rows.splice(4,1,['PLZ',plz[1]],['Ort',plz[2]]); }
    if(val('email')) rows.push(['E-Mail',val('email')]);
    var kv=document.getElementById('ta-kv'); kv.innerHTML='';
    rows.forEach(function(r){
      var k=document.createElement('div'); k.className='k'; k.textContent=r[0];
      var v=document.createElement('div'); v.className='v'; v.textContent=r[1];
      var b=document.createElement('button'); b.type='button'; b.className='cp'; b.textContent='Kopieren';
      b.addEventListener('click',function(){ copy(r[1]).then(function(){ b.textContent='✓ kopiert'; b.classList.add('done'); setTimeout(function(){ b.textContent='Kopieren'; b.classList.remove('done'); },1800); }); });
      kv.appendChild(k); kv.appendChild(v); kv.appendChild(b);
    });
    f.hidden=true; done.hidden=false; window.scrollTo(0,0);
  }
  function copy(t){
    if(navigator.clipboard && window.isSecureContext) return navigator.clipboard.writeText(t).catch(fallback);
    return fallback();
    function fallback(){ var a=document.createElement('textarea'); a.value=t; a.style.cssText='position:fixed;opacity:0'; document.body.appendChild(a); a.select(); try{ document.execCommand('copy'); }catch(e){} a.remove(); return Promise.resolve(); }
  }

  document.getElementById('ta-print').addEventListener('click',function(){
    document.getElementById('ta-printnote').hidden=false;
    var fr=document.createElement('iframe'); fr.style.cssText='position:fixed;width:0;height:0;border:0;visibility:hidden';
    fr.src=pdfUrl; document.body.appendChild(fr);
    fr.onload=function(){ try{ fr.contentWindow.focus(); fr.contentWindow.print(); }catch(e){ window.open(pdfUrl,'_blank'); } };
  });

  document.getElementById('ta-new').addEventListener('click',function(){
    if(!confirm('Eingaben und Unterschrift jetzt löschen und nächsten Kunden beginnen?')) return;
    f.reset(); clearSig(); if(pdfUrl){ URL.revokeObjectURL(pdfUrl); pdfUrl=null; }
    [].forEach.call(f.querySelectorAll('.invalid'),function(x){ x.classList.remove('invalid'); });
    go.disabled=false; go.innerHTML='Fertig &ndash; Auftragsschein erstellen';
    done.hidden=true; f.hidden=false; document.getElementById('ta-printnote').hidden=true; window.scrollTo(0,0);
  });
})();
</script>
</body>
</html>
KTHTML;
}
