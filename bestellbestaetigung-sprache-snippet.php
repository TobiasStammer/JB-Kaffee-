/* kaffeetechniker.de - Bestellbestaetigung/Kundenkonto: Sprache an den Rest der Seite anpassen.
 * Die Seite siezt; die WooCommerce-Uebersetzung (de_DE) duzt und hat vereinzelt englische Reste.
 * Ersetzt exakte Saetze in der Ausgabe der Bestaetigungs-Bloecke und ergaenzt fehlende Uebersetzungen.
 * Einbau: Code Snippets, PHP, "Ueberall ausfuehren" (Deploy: scratchpad/bestellbestaetigung-sprache.ps1). */
if ( ! function_exists( 'kt_sie_map' ) ) {
	function kt_sie_map() {
		return array(
			"Vielen Dank. Deine Bestellung ist eingegangen."                       => "Vielen Dank. Ihre Bestellung ist eingegangen.",
			"Tolle Neuigkeiten! Deine Bestellung ist eingegangen und eine Best\u{e4}tigung wird an deine E-Mail-Adresse gesendet." => "Tolle Neuigkeiten! Ihre Bestellung ist eingegangen und eine Best\u{e4}tigung wird an Ihre E-Mail-Adresse gesendet.",
			"Hast du ein Konto bei uns?"                                           => "Haben Sie ein Konto bei uns?",
			"Melde dich hier an"                                                   => "Melden Sie sich hier an",
			", um deine Bestellung anzuzeigen"                                     => ", um Ihre Bestellung anzuzeigen",
			"Order details"                                                        => "Bestelldetails",
			"Shipping address"                                                     => "Lieferadresse",
			"Billing address"                                                      => "Rechnungsadresse",
			"Additional information"                                               => "Zus\u{e4}tzliche Informationen",
		);
	}
}

add_filter( 'render_block', function ( $html, $block ) {
	if ( empty( $block['blockName'] ) || 0 !== strpos( $block['blockName'], 'woocommerce/order-confirmation' ) ) {
		return $html;
	}
	$map = kt_sie_map();
	return str_replace( array_keys( $map ), array_values( $map ), $html );
}, 20, 2 );

add_filter( 'gettext', function ( $text, $original, $domain ) {
	if ( 'woocommerce' !== $domain ) {
		return $text;
	}
	$map = kt_sie_map();
	return isset( $map[ $text ] ) ? $map[ $text ] : $text;
}, 20, 3 );
