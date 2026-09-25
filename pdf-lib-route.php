/* kaffeetechniker.de – liefert pdf-lib 1.17.1 (MIT) lokal aus, damit keine Anfrage an cdnjs/Cloudflare noetig ist. Datei: Mediathek-ID 4880 */
add_action( 'init', function () {
	$p = isset( $_SERVER['REQUEST_URI'] ) ? strtok( $_SERVER['REQUEST_URI'], '?' ) : '';
	if ( $p !== '/ktc-assets/pdf-lib.min.js' ) { return; }
	$f = get_attached_file( 4880 );
	if ( ! $f || ! is_readable( $f ) ) { status_header( 404 ); exit; }
	header( 'Content-Type: application/javascript; charset=utf-8' );
	header( 'Cache-Control: public, max-age=31536000, immutable' );
	header( 'X-Content-Type-Options: nosniff' );
	readfile( $f );
	exit;
}, 0 );
