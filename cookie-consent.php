/* kaffeetechniker.de – Cookie-/Consent-Banner (Code Snippet, Scope: front-end)
   Blockiert bis zur Einwilligung: Google Maps (maps), Wertgarantie-Widget (wg).
   Auswahl liegt im localStorage 'ktc_consent'. Quelle: cookie-consent.php im Repo. */
if ( ! function_exists( 'ktc_filter_html' ) ) {

	function ktc_placeholder( $cat, $title, $text, $btn ) {
		return '<div class="ktc-ph" data-ktc-ph="' . $cat . '"><strong>' . $title . '</strong><p>' . $text
			. '</p><button type="button" class="ktc-btn ktc-p" data-ktc-grant="' . $cat . '">' . $btn . '</button></div>';
	}

	function ktc_filter_html( $html ) {
		// Google Maps: iframe erst nach Einwilligung laden
		$html = preg_replace_callback(
			'#<iframe\b[^>]*\bsrc=(["\'])(https?://(?:www\.)?google\.com/maps[^"\']*)\1[^>]*></iframe>#i',
			function ( $m ) {
				$tag = preg_replace( '#\bsrc=(["\'])[^"\']*\1#i', 'data-ktc-src="' . $m[2] . '" data-ktc="maps" hidden', $m[0], 1 );
				$tag = str_replace( ' loading="lazy"', '', $tag );
				return ktc_placeholder(
					'maps',
					'Karte von Google Maps',
					'Zum Anzeigen der Karte wird eine Verbindung zu Google aufgebaut, dabei wird u.&nbsp;a. Ihre IP-Adresse an Google &uuml;bermittelt. Details in der <a href="/datenschutz/">Datenschutzerkl&auml;rung</a>.',
					'Karte laden'
				) . $tag;
			},
			$html
		);
		// Wertgarantie-Widget: Skript erst nach Einwilligung ausfuehren
		$html = preg_replace_callback(
			'#<script\b[^>]*\bsrc=(["\'])(https://siteconnect\.wertgarantie-services\.de/[^"\']*)\1[^>]*></script>#i',
			function ( $m ) {
				return ktc_placeholder(
					'wg',
					'Wertgarantie-Widget',
					'Zum Anzeigen wird ein Skript von Wertgarantie (siteconnect.wertgarantie-services.de) geladen, dabei wird u.&nbsp;a. Ihre IP-Adresse &uuml;bermittelt. Details in der <a href="/datenschutz/">Datenschutzerkl&auml;rung</a>.',
					'Widget laden'
				) . '<script type="text/plain" data-ktc="wg" data-ktc-src="' . $m[2] . '"></script>';
			},
			$html
		);
		return $html;
	}

	add_action( 'template_redirect', function () {
		if ( is_admin() || is_feed() || wp_doing_ajax() || ( defined( 'REST_REQUEST' ) && REST_REQUEST ) ) {
			return;
		}
		ob_start( 'ktc_filter_html' );
	}, 1 );

	add_action( 'wp_footer', function () {
		?>
<style>
#ktc{position:fixed;left:0;right:0;bottom:0;z-index:100000;background:#fff;color:#1c1c1c;border-top:3px solid #334155;box-shadow:0 -8px 30px rgba(0,0,0,.18);font:15px/1.5 'Source Sans 3','Source Sans Pro',system-ui,sans-serif;padding:18px 20px;display:none}
#ktc.on{display:block}
#ktc .ktc-in{max-width:1100px;margin:0 auto}
#ktc h2{font:700 17px Tahoma,Arial,sans-serif;margin:0 0 6px;color:#2b2b2b}
#ktc p{margin:0 0 12px}
#ktc a{color:#334155;text-decoration:underline}
#ktc .ktc-row{display:flex;flex-wrap:wrap;gap:10px}
.ktc-btn{font:700 14px Tahoma,Arial,sans-serif;padding:11px 20px;border-radius:8px;border:2px solid #334155;background:#fff;color:#334155;cursor:pointer}
.ktc-btn:hover{background:#eef1f5}
.ktc-btn.ktc-p{background:#334155;color:#fff}
.ktc-btn.ktc-p:hover{background:#1e293b}
#ktc .ktc-opts{display:none;margin:0 0 12px;border:1px solid #d8d8d8;border-radius:8px;padding:6px 14px}
#ktc.det .ktc-opts{display:block}
#ktc .ktc-opts label{display:flex;gap:10px;align-items:flex-start;padding:8px 0;border-bottom:1px solid #eee}
#ktc .ktc-opts label:last-child{border:0}
#ktc .ktc-opts input{margin-top:4px;width:18px;height:18px;flex-shrink:0}
#ktc .ktc-sv{display:none}
#ktc.det .ktc-sv{display:inline-block}
#ktc.det .ktc-det{display:none}
#ktc-open{position:fixed;left:14px;bottom:14px;z-index:99990;background:#fff;color:#334155;border:1px solid #c9c9c9;border-radius:999px;padding:7px 13px;font:600 12.5px Tahoma,Arial,sans-serif;cursor:pointer;box-shadow:0 2px 10px rgba(0,0,0,.15);display:none}
#ktc-open.on{display:block}
.ktc-ph{background:#f0efec;border:1px dashed #b5b5b5;border-radius:10px;padding:26px 22px;text-align:center;font:15px/1.5 'Source Sans 3',system-ui,sans-serif;color:#1c1c1c;margin:10px 0}
.ktc-ph p{max-width:560px;margin:8px auto 14px}
@media(max-width:600px){#ktc{padding:14px 14px 16px}#ktc .ktc-row .ktc-btn{flex:1 1 100%}}
</style>
<div id="ktc" role="dialog" aria-labelledby="ktc-t" aria-live="polite">
 <div class="ktc-in">
  <h2 id="ktc-t">Ihre Privatsphäre</h2>
  <p>Wir verwenden nur technisch notwendige Cookies (z.&nbsp;B. Warenkorb). Externe Inhalte wie Google Maps oder das Wertgarantie-Widget laden wir nur mit Ihrer Einwilligung. Sie können Ihre Auswahl jederzeit ändern. Mehr in der <a href="/datenschutz/">Datenschutzerklärung</a> und im <a href="/impressum/">Impressum</a>.</p>
  <div class="ktc-opts">
   <label><input type="checkbox" checked disabled><span><b>Notwendig</b> &ndash; Warenkorb, Anmeldung, Sicherheit. Immer aktiv.</span></label>
   <label><input type="checkbox" data-ktc-opt="maps"><span><b>Google Maps</b> &ndash; Karte auf der Anfahrtsseite (Google, USA).</span></label>
   <label><input type="checkbox" data-ktc-opt="wg"><span><b>Wertgarantie</b> &ndash; Widget der Wertgarantie-Services.</span></label>
  </div>
  <div class="ktc-row">
   <button type="button" class="ktc-btn ktc-p" data-ktc-act="all">Alle akzeptieren</button>
   <button type="button" class="ktc-btn ktc-p" data-ktc-act="none">Nur notwendige</button>
   <button type="button" class="ktc-btn ktc-det" data-ktc-act="det">Einstellungen</button>
   <button type="button" class="ktc-btn ktc-sv" data-ktc-act="save">Auswahl speichern</button>
  </div>
 </div>
</div>
<button type="button" id="ktc-open" aria-label="Cookie-Einstellungen öffnen">Cookie-Einstellungen</button>
<script>
(function(){
var K='ktc_consent',bar=document.getElementById('ktc'),pill=document.getElementById('ktc-open');
function get(){try{var v=JSON.parse(localStorage.getItem(K));return v&&v.v===1?v:null}catch(e){return null}}
function put(o){o.v=1;o.t=Date.now();try{localStorage.setItem(K,JSON.stringify(o))}catch(e){}}
function apply(c){
  ['maps','wg'].forEach(function(cat){
    var ph=document.querySelectorAll('[data-ktc-ph="'+cat+'"]'),el=document.querySelectorAll('[data-ktc="'+cat+'"]');
    if(c&&c[cat]){
      ph.forEach(function(p){p.style.display='none'});
      el.forEach(function(e){
        if(e.dataset.ktcDone)return;e.dataset.ktcDone=1;
        if(e.tagName==='IFRAME'){e.src=e.dataset.ktcSrc;e.removeAttribute('hidden')}
        else if(e.tagName==='SCRIPT'){var s=document.createElement('script');s.src=e.dataset.ktcSrc;e.parentNode.insertBefore(s,e)}
      });
    }else{ph.forEach(function(p){p.style.display=''})}
  });
}
function show(){
  var c=get()||{};
  bar.querySelectorAll('[data-ktc-opt]').forEach(function(i){i.checked=!!c[i.dataset.ktcOpt]});
  bar.classList.add('on');pill.classList.remove('on');
}
function done(o){put(o);bar.classList.remove('on','det');pill.classList.add('on');apply(o)}
bar.addEventListener('click',function(e){
  var a=e.target.getAttribute&&e.target.getAttribute('data-ktc-act');if(!a)return;
  if(a==='all')done({maps:1,wg:1});
  else if(a==='none')done({maps:0,wg:0});
  else if(a==='det')bar.classList.add('det');
  else if(a==='save'){var o={};bar.querySelectorAll('[data-ktc-opt]').forEach(function(i){o[i.dataset.ktcOpt]=i.checked?1:0});done(o)}
});
document.addEventListener('click',function(e){
  var g=e.target.closest&&e.target.closest('[data-ktc-grant]');
  if(g){var c=get()||{maps:0,wg:0};c[g.dataset.ktcGrant]=1;put(c);apply(c);return}
  var l=e.target.closest&&e.target.closest('a[href$="#cookie-einstellungen"]');
  if(l){e.preventDefault();show()}
});
pill.addEventListener('click',show);
var c=get();
if(c){pill.classList.add('on');apply(c)}else{bar.classList.add('on');apply(null)}
})();
</script>
		<?php
	}, 99 );
}
