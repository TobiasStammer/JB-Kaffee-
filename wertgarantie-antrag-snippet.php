/* kaffeetechniker.de - Wertgarantie-Widget: "Weiter zum Antrag" im selben Tab oeffnen.
 * Das Widget (siteconnect.wertgarantie-services.de) oeffnet den Antrag per window.open(..., '_blank'), nachdem es
 * zuvor Daten geladen hat. Popup-Blocker (Safari/iOS, Chrome mobil, Firmen-Browser) unterdruecken das, dann passiert
 * beim Klick scheinbar nichts. Wir leiten Aufrufe an https://www.wertgarantie.de/ daher im selben Tab weiter.
 * Nur auf der Seite /wertgarantie/. Einbau: Code Snippets, PHP, front-end (Deploy: scratchpad/wertgarantie-antrag.ps1).
 * Einzeiliges Script (keine Leerzeilen, sonst fuegt WordPress <p> ein). */
add_action( 'wp_footer', function () {
	if ( ! is_page( 'wertgarantie' ) ) {
		return;
	}
	?>
<script>(function(){var o=window.open;window.open=function(u,t,f){try{var s=String(u||'');if(/^https:\/\/www\.wertgarantie\.de\//.test(s)){window.location.assign(s);return null}}catch(e){}return o.apply(window,arguments)}})();</script>
	<?php
}, 100 );
