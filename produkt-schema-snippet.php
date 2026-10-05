/* kaffeetechniker.de - WooCommerce-Produkt-Schema (JSON-LD) bereinigen.
 * Google Search Console (05.10.2026, Haendlereintraege): "Ungueltiger Wert in Feld sku" und "Feld validFrom fehlt (offers)".
 * - sku: Shop-SKU ist "Herstellernr (Lager-Art.-Nr.)", z. B. "15643 (4380)". Im Schema nur die Herstellernr. ausgeben
 *   (ohne Klammerzusatz/Leerzeichen); ist sie leer, wird sku weggelassen statt einen ungueltigen Wert zu senden.
 * - validFrom: im Offer und in der UnitPriceSpecification ergaenzt (Datum der Produkterstellung, ISO 8601).
 * - description/seller.name: doppelt kodierte HTML-Entities (&amp;#228;) decodiert.
 * Einbau: Code Snippets, PHP, "Ueberall ausfuehren" (Deploy: scratchpad/produkt-schema.ps1). */
add_filter( 'woocommerce_structured_data_product', function ( $markup, $product ) {
	if ( ! is_array( $markup ) ) {
		return $markup;
	}
	$dec = function ( $s ) {
		return is_string( $s ) ? html_entity_decode( html_entity_decode( $s, ENT_QUOTES, 'UTF-8' ), ENT_QUOTES, 'UTF-8' ) : $s;
	};
	if ( isset( $markup['sku'] ) ) {
		$sku = trim( preg_replace( '/\s*\(.*$/', '', (string) $markup['sku'] ) );
		if ( $sku === '' ) {
			unset( $markup['sku'] );
		} else {
			$markup['sku'] = $sku;
		}
	}
	if ( isset( $markup['description'] ) ) {
		$markup['description'] = $dec( $markup['description'] );
	}
	$created = $product && $product->get_date_created() ? $product->get_date_created()->date( 'Y-m-d' ) : gmdate( 'Y-m-d' );
	if ( ! empty( $markup['offers'] ) && is_array( $markup['offers'] ) ) {
		foreach ( $markup['offers'] as $i => $offer ) {
			if ( ! is_array( $offer ) ) {
				continue;
			}
			$offer['validFrom'] = $created;
			if ( ! empty( $offer['priceSpecification'] ) && is_array( $offer['priceSpecification'] ) ) {
				foreach ( $offer['priceSpecification'] as $j => $spec ) {
					if ( is_array( $spec ) ) {
						$offer['priceSpecification'][ $j ]['validFrom'] = $created;
					}
				}
			}
			if ( isset( $offer['seller']['name'] ) ) {
				$offer['seller']['name'] = $dec( $offer['seller']['name'] );
			}
			$markup['offers'][ $i ] = $offer;
		}
	}
	return $markup;
}, 20, 2 );
