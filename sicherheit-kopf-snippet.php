/* kaffeetechniker.de - Sicherheit + Kopfbereich (Go-live).
 * 1) Benutzerliste per REST nur noch fuer berechtigte Benutzer; Autoren-Archive/?author=N leiten auf die Startseite (kein Benutzernamen-Leak).
 * 2) Sicherheits-Header: X-Content-Type-Options, X-Frame-Options (SAMEORIGIN), Referrer-Policy, HSTS (6 Monate, ohne Subdomains).
 * 3) Vorschaubild fuers Teilen: og:image/twitter:image (Produktseiten: Produktbild, sonst Standardbild; das SEO-Plugin gibt keins aus).
 * Einbau: Code Snippets, PHP, "Ueberall ausfuehren" (Deploy: scratchpad/sicherheit-kopf.ps1). */

// 1) Benutzernamen nicht oeffentlich
add_filter( 'rest_endpoints', function ( $endpoints ) {
	if ( ! current_user_can( 'list_users' ) ) {
		foreach ( array_keys( $endpoints ) as $route ) {
			if ( 0 === strpos( $route, '/wp/v2/users' ) && '/wp/v2/users/me' !== $route ) {
				unset( $endpoints[ $route ] );
			}
		}
	}
	return $endpoints;
} );
add_action( 'template_redirect', function () {
	if ( is_author() || ( isset( $_GET['author'] ) && '' !== $_GET['author'] ) ) { // phpcs:ignore WordPress.Security.NonceVerification
		wp_safe_redirect( home_url( '/' ), 301 );
		exit;
	}
}, 0 );

// 2) Sicherheits-Header
add_action( 'send_headers', function () {
	if ( is_admin() ) {
		return;
	}
	header( 'X-Content-Type-Options: nosniff' );
	header( 'X-Frame-Options: SAMEORIGIN' );
	header( 'Referrer-Policy: strict-origin-when-cross-origin' );
	if ( is_ssl() ) {
		header( 'Strict-Transport-Security: max-age=15552000' );
	}
} );

// 3) Vorschaubild
add_action( 'wp_head', function () {
	$img = '';
	if ( is_singular( 'product' ) && has_post_thumbnail() ) {
		$img = (string) wp_get_attachment_image_url( get_post_thumbnail_id(), 'large' );
	}
	if ( ! $img ) {
		$img = (string) wp_get_attachment_image_url( KT_OG_IMAGE_ID, 'full' );
	}
	if ( $img ) {
		echo '<meta property="og:image" content="' . esc_url( $img ) . '" />' . "\n" . '<meta name="twitter:image" content="' . esc_url( $img ) . '" />' . "\n";
	}
}, 6 );
