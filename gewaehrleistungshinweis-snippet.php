/* kaffeetechniker.de - EU-Hinweis "Gesetzliche Gewaehrleistung" (harmonisierter Hinweis, DVO (EU) 2025/1960, Pflicht ab 27.09.2026).
 * Eingebunden wird das PNG aus der Gewaehrleistungslabel/-Vorlage der EU-Kommission in der vom Betreiber gewuenschten Kurzfassung
 * (Mediathek-ID siehe KT_GW_PNG_ID; Rechtspruefung durch Anwalt/Haendlerbund ist Sache des Betreibers).
 * Einbau: Kasse (vor "Zahlungspflichtig bestellen"), Seiten AGB + Gewaehrleistung (unter der Ueberschrift).
 * Nicht auf den Produktseiten (vom Betreiber entfernt, 2026-09-28). Kein PDF-Anhang an Kundenmails (vom Betreiber nicht gewuenscht, 2026-09-28).
 * Deploy: scratchpad/gewaehrleistungshinweis.ps1 */

if ( ! function_exists( 'kt_gw_notice' ) ) {

	define( 'KT_GW_PNG_ID', 4898 );

	function kt_gw_notice( $width = 170, $context = 'product' ) {
		$url = wp_get_attachment_url( KT_GW_PNG_ID );
		if ( ! $url ) {
			return '';
		}
		$alt = 'Gesetzliche Gewährleistung: Mindestens zwei Jahre gesetzliche Gewährleistung der Vertragsmäßigkeit für Waren, die in der Europäischen Union verkauft werden. Hinweis der EU-Kommission.';
		return '<div class="kt-gw kt-gw-' . esc_attr( $context ) . '" style="margin:18px 0;max-width:' . (int) $width . 'px">'
			. '<a href="' . esc_url( $url ) . '" target="_blank" rel="noopener" title="Hinweis in Originalgröße öffnen">'
			. '<img src="' . esc_url( $url ) . '" alt="' . esc_attr( $alt ) . '" width="' . (int) $width . '" height="' . (int) round( $width * 1.4142 ) . '" loading="lazy" decoding="async" '
			. 'style="display:block;width:100%;height:auto;border:1px solid #d5dae1;border-radius:4px;background:#fff"></a>'
			. '<p style="margin:6px 0 0;font-size:12px;line-height:1.4;color:#666">EU-Hinweis zur gesetzlichen Gewährleistung &ndash; zum Vergrößern anklicken.</p></div>';
	}
}

// Kasse (Block-Checkout): direkt vor dem Bestell-Button
add_filter( 'render_block', function ( $html, $block ) {
	if ( isset( $block['blockName'] ) && 'woocommerce/checkout-actions-block' === $block['blockName'] ) {
		return kt_gw_notice( 150, 'checkout' ) . $html;
	}
	return $html;
}, 20, 2 );

// Kasse (klassisch), falls jemals genutzt
add_action( 'woocommerce_review_order_before_submit', function () {
	echo kt_gw_notice( 150, 'checkout' ); // phpcs:ignore WordPress.Security.EscapeOutput
} );

// Seiten AGB + Gewaehrleistung: unter der Hauptueberschrift (die Seiten bringen Kopf/Fuss im Inhalt mit)
add_filter( 'the_content', function ( $content ) {
	if ( ! is_singular( 'page' ) || ! in_the_loop() || ! is_main_query() ) {
		return $content;
	}
	$slug = get_post_field( 'post_name', get_queried_object_id() );
	if ( ! in_array( $slug, array( 'agb', 'gewaehrleistung' ), true ) || false !== strpos( $content, 'kt-gw-page' ) ) {
		return $content;
	}
	$notice = kt_gw_notice( 260, 'page' );
	$new    = preg_replace( '#(</h1>)#i', '$1' . str_replace( '$', '\$', $notice ), $content, 1, $n );
	return $n ? $new : $content;
}, 20 );
