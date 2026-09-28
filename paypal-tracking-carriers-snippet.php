/* kaffeetechniker.de - PayPal-Paketverfolgung: nur die Versanddienstleister GLS und DHL anbieten.
 * Die Liste "Lieferant" im Kasten "PayPal-Paketverfolgung" der Bestellung enthaelt sonst ~370 Dienste weltweit.
 * Die Schluessel muessen gueltige PayPal-Carrier-Codes bleiben (DE_DHL, DHL, GLS), nur die Bezeichnungen sind eigene.
 * Einbau: Code Snippets, PHP, "Ueberall ausfuehren" (Deploy: scratchpad/paypal-tracking-carriers.ps1). */
add_filter( 'woocommerce_paypal_payments_tracking_carriers', function ( $carriers ) {
	$keep  = array(
		'DE_DHL' => 'DHL (Deutschland)',
		'DHL'    => 'DHL (International)',
		'GLS'    => 'GLS',
	);
	$items = array();
	foreach ( (array) $carriers as $group ) {
		if ( empty( $group['items'] ) ) {
			continue;
		}
		foreach ( $keep as $code => $label ) {
			if ( isset( $group['items'][ $code ] ) ) {
				$items[ $code ] = $label;
			}
		}
	}
	if ( ! $items ) {
		return $carriers; // Sicherheitsnetz: nichts filtern, falls PayPal die Codes umbenennt.
	}
	return array( 'DE' => array( 'name' => 'Deutschland', 'items' => $items ) );
}, 100 );
