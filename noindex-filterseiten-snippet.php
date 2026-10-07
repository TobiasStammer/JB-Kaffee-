/* kaffeetechniker.de - Filter-/Feed-Seiten aus dem Google-Index halten (nur Crawl-Ballast, keine eigenen Inhalte).
 * Betrifft: Lieferzeit-Taxonomie (/lieferzeit/...), alle RSS/Atom-Feeds (X-Robots-Tag: noindex).
 * Einbau: Code Snippets, PHP, "Ueberall ausfuehren" (Deploy: scratchpad/noindex-filterseiten.ps1). */
add_action( 'send_headers', function () {
	$uri = isset( $_SERVER['REQUEST_URI'] ) ? (string) wp_unslash( $_SERVER['REQUEST_URI'] ) : '';
	$path = (string) wp_parse_url( $uri, PHP_URL_PATH );
	if ( preg_match( '#/feed(/|$)|^/lieferzeit(/|$)#', $path ) ) {
		header( 'X-Robots-Tag: noindex, follow', true );
	}
}, 20 );
add_filter( 'wp_robots', function ( $robots ) {
	if ( is_tax( 'product_delivery_time' ) || is_tax( 'lieferzeit' ) || ( function_exists( 'is_tax' ) && is_tax() && false !== strpos( (string) get_query_var( 'taxonomy' ), 'lieferzeit' ) ) ) {
		$robots['noindex'] = true;
		$robots['follow']  = true;
		unset( $robots['index'] );
	}
	return $robots;
}, 99 );
