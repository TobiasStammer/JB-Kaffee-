/* kaffeetechniker.de - XML-Sitemap: WordPress-Kern-Sitemap (/wp-sitemap.xml) mit Seiten + Produkten, ohne Shop-Systemseiten.
 * Ersetzt die Sitemap des SEO-Plugins (BeyondSEO), die keine Produkte enthielt, dafuer Warenkorb/Kasse/Konto/Beispielseite/noindex-Kategorien
 * und unter /sitemap.xml nicht erreichbar war (WordPress leitete auf die Startseite um). Voraussetzung: Plugin-Einstellung "sitemap.enabled" = false
 * (sonst deaktiviert das Plugin die Kern-Sitemap). Domain wird ueber home_url() gesetzt -> nach dem Domainumzug automatisch richtig.
 * Einbau: Code Snippets, PHP, "Ueberall ausfuehren" (Deploy: scratchpad/sitemap.ps1). */

// Kern-Sitemap immer an (auch wenn blog_public=0 ist, das wird am Go-live-Tag ohnehin auf 1 gestellt)
add_filter( 'wp_sitemaps_enabled', '__return_true', 99 );

// Keine Benutzer-Sitemap, keine Beitraege (kein Blog), keine Taxonomien (Produktkategorien sind noindex)
add_filter( 'wp_sitemaps_add_provider', function ( $provider, $name ) {
	return 'users' === $name ? false : $provider;
}, 10, 2 );
add_filter( 'wp_sitemaps_taxonomies', '__return_empty_array' );
add_filter( 'wp_sitemaps_post_types', function ( $types ) {
	unset( $types['post'] );
	return $types;
} );

// Seiten ohne Suchwert ausschliessen: Warenkorb, Kasse, Mein Konto, Shop-Basis, WordPress-Beispielseite
add_filter( 'wp_sitemaps_posts_query_args', function ( $args, $post_type ) {
	if ( 'page' === $post_type ) {
		$ex = array_filter( array_map( 'intval', array(
			get_option( 'woocommerce_cart_page_id' ),
			get_option( 'woocommerce_checkout_page_id' ),
			get_option( 'woocommerce_myaccount_page_id' ),
			get_option( 'woocommerce_shop_page_id' ),
		) ) );
		$sample = get_page_by_path( 'sample-page' );
		if ( $sample ) {
			$ex[] = (int) $sample->ID;
		}
		$args['post__not_in'] = array_merge( (array) ( isset( $args['post__not_in'] ) ? $args['post__not_in'] : array() ), $ex );
	}
	return $args;
}, 10, 2 );

// robots.txt: Sitemap-Zeile (Domain dynamisch)
add_filter( 'robots_txt', function ( $output ) {
	if ( false === stripos( $output, 'Sitemap:' ) ) {
		$output = rtrim( $output ) . "\n\nSitemap: " . home_url( '/wp-sitemap.xml' ) . "\n";
	}
	return $output;
}, 99 );

// Gaengige Adressen weiterleiten (vor dem Kern-Redirect auf die Startseite)
add_action( 'template_redirect', function () {
	$path = wp_parse_url( isset( $_SERVER['REQUEST_URI'] ) ? wp_unslash( $_SERVER['REQUEST_URI'] ) : '', PHP_URL_PATH );
	if ( in_array( $path, array( '/sitemap.xml', '/sitemap_index.xml', '/sitemap-index.xml' ), true ) ) {
		wp_safe_redirect( home_url( '/wp-sitemap.xml' ), 301 );
		exit;
	}
}, 0 );

// Einmalig nach dem Einspielen: Adress-Regeln neu schreiben, damit /wp-sitemap.xml greift (Flag-Option verhindert Wiederholung)
add_action( 'init', function () {
	if ( '2' !== get_option( 'kt_sitemap_flushed' ) ) {
		flush_rewrite_rules( false );
		update_option( 'kt_sitemap_flushed', '2', false );
	}
}, 9999 );
