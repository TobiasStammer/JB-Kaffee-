/* kaffeetechniker.de - EU-Hinweis "Gesetzliche Gewaehrleistung" (harmonisierter Hinweis, DVO (EU) 2025/1960, Pflicht ab 27.09.2026).
 * Eingebunden wird das unveraenderte Original-PNG (DE, farbig) der EU-Kommission (Mediathek-ID KT_GW_PNG_ID, Datei Gewaehrleistungslabel/Gewaehrleistungshinweis-DE-original.png).
 * Einbau: Warenkorb, direkt unter dem Warenkorb-Block (ausserhalb des React-Roots), klein mit Klick auf Originalgroesse.
 * Rechtspruefung durch Anwalt/Haendlerbund ist Sache des Betreibers.
 * Deploy: scratchpad/gewaehrleistungshinweis.ps1 */

if ( ! function_exists( 'kt_gw_notice' ) ) {

	define( 'KT_GW_PNG_ID', 5066 );

	function kt_gw_notice( $width = 240, $context = 'cart' ) {
		$url = wp_get_attachment_url( KT_GW_PNG_ID );
		if ( ! $url ) {
			return '';
		}
		$alt = 'Gesetzliche Gewährleistung: Mindestens zwei Jahre gesetzliche Gewährleistung der Vertragsmäßigkeit für Waren, die in der Europäischen Union verkauft werden. Hinweis der EU-Kommission.';
		return '<div class="kt-gw kt-gw-' . esc_attr( $context ) . '" style="margin:24px 0;max-width:' . (int) $width . 'px">'
			. '<a href="' . esc_url( $url ) . '" target="_blank" rel="noopener" title="Hinweis in Originalgröße öffnen">'
			. '<img src="' . esc_url( $url ) . '" alt="' . esc_attr( $alt ) . '" width="' . (int) $width . '" height="' . (int) round( $width * 1.4142 ) . '" decoding="async" '
			. 'style="display:block;width:100%;height:auto;border:1px solid #d5dae1;border-radius:4px;background:#fff"></a>'
			. '<p style="margin:6px 0 0;font-size:12px;line-height:1.4;color:#666">EU-Hinweis zur gesetzlichen Gewährleistung &ndash; zum Vergrößern anklicken.</p></div>';
	}
}

// Warenkorb (Block-Cart): unter dem gesamten Warenkorb-Block
add_filter( 'render_block', function ( $html, $block ) {
	if ( isset( $block['blockName'] ) && 'woocommerce/cart' === $block['blockName'] ) {
		return $html . kt_gw_notice( 240, 'cart' );
	}
	return $html;
}, 20, 2 );
