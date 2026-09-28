/* kaffeetechniker.de - WooCommerce-Meldungen (Fehler/Hinweise) auf Konto-, Warenkorb- und Kassenseite wieder sichtbar machen.
 * Ursache: Das SEO-Plugin (BeyondSEO/rankingCoach) holt den Seiteninhalt fuer sein JSON-LD ("articleBody", Schema/Article.php) per
 * apply_filters('the_content'). Dabei druckt WooCommerce die Session-Meldungen (wc_print_notices) und LEERT sie - die sichtbare Seite hat
 * dann keine mehr (falsches Passwort, unbekannter Benutzer, "Passwort vergessen" fuer unbekannte Adresse, E-Mail schon registriert, ...).
 * Loesung: Kommt der the_content-Aufruf aus dem SEO-Plugin (Backtrace-Klasse RankingCoach\...), Meldungen vorher sichern und danach
 * wiederherstellen. Unabhaengig davon, in welchem Hook das Plugin rendert.
 * Einbau: Code Snippets, PHP, "Ueberall ausfuehren" (Deploy: scratchpad/wc-notices-sichtbar.ps1). */
if ( ! function_exists( 'kt_called_from_seo_plugin' ) ) {
	function kt_called_from_seo_plugin() {
		foreach ( debug_backtrace( DEBUG_BACKTRACE_IGNORE_ARGS, 40 ) as $f ) { // phpcs:ignore WordPress.PHP.DevelopmentFunctions
			if ( ! empty( $f['class'] ) && 0 === strpos( $f['class'], 'RankingCoach' ) ) {
				return true;
			}
		}
		return false;
	}
}

add_filter( 'the_content', function ( $content ) {
	if ( function_exists( 'wc_get_notices' ) && function_exists( 'WC' ) && WC()->session && kt_called_from_seo_plugin() ) {
		$GLOBALS['kt_wc_notices_stash'] = wc_get_notices();
	}
	return $content;
}, -9999 );

add_filter( 'the_content', function ( $content ) {
	if ( isset( $GLOBALS['kt_wc_notices_stash'] ) ) {
		if ( $GLOBALS['kt_wc_notices_stash'] && function_exists( 'wc_set_notices' ) ) {
			wc_set_notices( $GLOBALS['kt_wc_notices_stash'] );
		}
		unset( $GLOBALS['kt_wc_notices_stash'] );
	}
	return $content;
}, 9999 );
