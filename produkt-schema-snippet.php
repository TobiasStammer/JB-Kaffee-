/* kaffeetechniker.de - WooCommerce-Produkt-Schema (JSON-LD) bereinigen.
 * Google Search Console (05.10.2026, Haendlereintraege): "Ungueltiger Wert in Feld sku" und "Feld validFrom fehlt (offers)".
 * - sku: Shop-SKU ist "Herstellernr (Lager-Art.-Nr.)", z. B. "15643 (4380)". Im Schema nur die Herstellernr. ausgeben
 *   (ohne Klammerzusatz/Leerzeichen); ist sie leer, wird sku weggelassen statt einen ungueltigen Wert zu senden.
 * - validFrom: im Offer und in der UnitPriceSpecification ergaenzt (Datum der Produkterstellung, ISO 8601).
 * - description/seller.name: doppelt kodierte HTML-Entities (&amp;#228;) decodiert.
 * - Verbesserungshinweise (Search Console): offers.shippingDetails (Versand DE nach Klasse, brutto, frei ab 1.500 EUR),
 *   offers.hasMerchantReturnPolicy (14 Tage Widerruf, Rücksendekosten traegt der Kunde, lt. Widerrufsbelehrung),
 *   brand (JURA / NIVONA / JB aus dem Produktnamen). GTIN liegt nicht vor.
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
	if ( empty( $markup['brand'] ) && ! empty( $markup['name'] ) ) {
		$n = (string) $markup['name'];
		if ( stripos( $n, 'JURA' ) === 0 ) {
			$markup['brand'] = array( '@type' => 'Brand', 'name' => 'JURA' );
		} elseif ( stripos( $n, 'NIVONA' ) === 0 ) {
			$markup['brand'] = array( '@type' => 'Brand', 'name' => 'NIVONA' );
		} elseif ( stripos( $n, 'JB ' ) === 0 ) {
			$markup['brand'] = array( '@type' => 'Brand', 'name' => 'JB' );
		}
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
			$class = $product ? $product->get_shipping_class() : '';
			$rates = array( 'bis-2kg' => '4.90', 'bis-8kg' => '6.90', 'bis-15kg' => '9.90', 'ab-15kg' => '12.90' );
			$rate  = isset( $rates[ $class ] ) ? $rates[ $class ] : '9.90';
			if ( $product && (float) $product->get_price() >= 1500 ) {
				$rate = '0.00';
			}
			$offer['shippingDetails'] = array(
				'@type'               => 'OfferShippingDetails',
				'shippingRate'        => array( '@type' => 'MonetaryAmount', 'value' => $rate, 'currency' => 'EUR' ),
				'shippingDestination' => array( '@type' => 'DefinedRegion', 'addressCountry' => 'DE' ),
			);
			$offer['hasMerchantReturnPolicy'] = array(
				'@type'                => 'MerchantReturnPolicy',
				'applicableCountry'    => 'DE',
				'returnPolicyCategory' => 'https://schema.org/MerchantReturnFiniteReturnWindow',
				'merchantReturnDays'   => 14,
				'returnMethod'         => 'https://schema.org/ReturnByMail',
				'returnFees'           => 'https://schema.org/ReturnShippingFees',
				'merchantReturnLink'   => home_url( '/widerruf/' ),
			);
			$markup['offers'][ $i ] = $offer;
		}
	}
	return $markup;
}, 20, 2 );
