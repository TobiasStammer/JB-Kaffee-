/* kaffeetechniker.de - LIVETAG: alte Hostadresse new.kaffeetechniker.de -> www.kaffeetechniker.de per 301 (Pfad + Query bleiben erhalten).
 * Erst NACH dem Domainumzug aktivieren (Snippet ist bis dahin inaktiv). Cron/CLI/REST-Anfragen der Zahlungsanbieter sind auf der neuen Domain unproblematisch.
 * Einbau: Code Snippets (Deploy: scratchpad/host-umleitung.ps1). */
add_action( 'init', function () {
	if ( defined( 'WP_CLI' ) || ( defined( 'DOING_CRON' ) && DOING_CRON ) ) {
		return;
	}
	$host = isset( $_SERVER['HTTP_HOST'] ) ? strtolower( preg_replace( '/:\d+$/', '', (string) wp_unslash( $_SERVER['HTTP_HOST'] ) ) ) : '';
	if ( 'new.kaffeetechniker.de' === $host ) {
		$uri = isset( $_SERVER['REQUEST_URI'] ) ? (string) wp_unslash( $_SERVER['REQUEST_URI'] ) : '/';
		wp_redirect( 'https://kaffeetechniker.de' . $uri, 301 ); // phpcs:ignore WordPress.Security.SafeRedirect
		exit;
	}
}, 0 );
