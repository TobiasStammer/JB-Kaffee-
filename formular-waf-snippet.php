/* kaffeetechniker.de - Formular-Absenden: IONOS-WAF blockt POSTs mit "%2B" (kodiertes Plus) mit "403 Forbidden nginx".
 * Betroffen: Fluent-Forms-Spamschutz-Token (base64, enthaelt fast immer "+") sowie Telefonnummern wie "+49 ...".
 * Loesung: Der Browser ersetzt das kodierte Plus im Fluent-Forms-Submit durch "KTPLUS"; der Server stellt es
 * vor der Verarbeitung wieder her. Quelle im Repo: formular-waf-snippet.php (Deploy: scratchpad/formular-waf.ps1).
 * Einbau: Code Snippets, PHP, "Ueberall ausfuehren". */
add_action( 'init', function () {
	if ( isset( $_POST['action'], $_POST['data'] ) && 'fluentform_submit' === $_POST['action'] && is_string( $_POST['data'] ) ) {
		$_POST['data']    = str_replace( 'KTPLUS', '%2B', $_POST['data'] );
		$_REQUEST['data'] = $_POST['data'];
	}
}, 1 );
add_action( 'wp_footer', function () {
	if ( is_admin() ) {
		return;
	}
	?>
<script>
(function(){
  if(!window.jQuery) return;
  jQuery.ajaxPrefilter(function(options){
    if(typeof options.data==='string' && options.data.indexOf('fluentform')>-1){
      options.data=options.data.replace(/%252B/g,'KTPLUS');
    }
  });
})();
</script>
	<?php
}, 99 );
