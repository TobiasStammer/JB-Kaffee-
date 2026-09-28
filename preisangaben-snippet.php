/* kaffeetechniker.de - Preisangaben nach PAngV/BGB + deutsche Beschriftungen.
 * 1) Am Preis (Produktseite, Listen, verwandte Produkte; nicht extern/Warenkorb/Kasse): "inkl. MwSt., zzgl. Versandkosten" (Link auf AGB Abschnitt 3)
 * 2) Grundpreis bei Kaffee/Tee (Menge aus dem Produktnamen "... 1000 g"): bis 250 g je 100 g, sonst je 1 kg (PAngV). Auch in der Kartenliste "Unser Kaffee".
 * 3) Preislisten-Seiten (eigene Kartenlisten): Hinweiszeile unter der Ueberschrift.
 * 4) "SKU:" -> "Artikelnummer:", "Category:" -> "Kategorie:" usw. auf der Produktseite.
 * Einbau: Code Snippets, PHP, "Ueberall ausfuehren" (Deploy: scratchpad/preisangaben.ps1). */

if ( ! function_exists( 'kt_pn_link' ) ) {

	function kt_pn_link() {
		return '<a href="' . esc_url( home_url( '/agb/#3-preise-versandkosten-und-zahlung' ) ) . '" style="color:inherit;text-decoration:underline">Versandkosten</a>';
	}

	function kt_grams_from_name( $name ) {
		if ( preg_match( '/(\d+)\s*g\b/u', html_entity_decode( (string) $name, ENT_QUOTES, 'UTF-8' ), $m ) ) {
			return (int) $m[1];
		}
		return 0;
	}

	function kt_unit_price_text( $price_incl, $grams ) {
		if ( $grams <= 0 || $price_incl <= 0 ) {
			return '';
		}
		if ( $grams <= 250 ) {
			$unit = '100&nbsp;g';
			$val  = $price_incl / $grams * 100;
		} else {
			$unit = '1&nbsp;kg';
			$val  = $price_incl / $grams * 1000;
		}
		return 'Grundpreis: ' . number_format( $val, 2, ',', '.' ) . '&nbsp;&euro; / ' . $unit;
	}
}

// Fluessigkeiten: Grundpreis je 1 l (Menge in ml je Herstellernummer am Anfang der SKU)
if ( ! function_exists( 'kt_volume_ml' ) ) {
	function kt_volume_ml( $product ) {
		$vol = array( '390700500' => 500, '390700300' => 500 ); // NIVONA CreamClean 500 ml, NIVONA Fluessigentkalker 500 ml
		if ( preg_match( '/^(\d+)/', (string) $product->get_sku(), $m ) && isset( $vol[ $m[1] ] ) ) {
			return $vol[ $m[1] ];
		}
		return 0;
	}
}

// 1) + 2) am Preis
add_filter( 'woocommerce_get_price_html', function ( $html, $product ) {
	if ( '' === $html || is_admin() || is_cart() || is_checkout() || is_account_page() || $product->is_type( 'external' ) ) {
		return $html;
	}
	$out = $html . '<span class="kt-pn" style="display:block;margin-top:2px;font-size:12px;font-weight:400;line-height:1.4;color:#666">inkl. MwSt., zzgl. ' . kt_pn_link() . '</span>';
	if ( has_term( array( 'kaffee', 'tee' ), 'product_cat', $product->get_id() ) ) {
		$gp = kt_unit_price_text( (float) wc_get_price_to_display( $product ), kt_grams_from_name( $product->get_name() ) );
		if ( $gp ) {
			$out .= '<span class="kt-gp" style="display:block;font-size:12px;font-weight:400;line-height:1.4;color:#666">' . $gp . '</span>';
		}
	}
	$ml = kt_volume_ml( $product );
	if ( $ml ) {
		$out .= '<span class="kt-gp" style="display:block;font-size:12px;font-weight:400;line-height:1.4;color:#666">Grundpreis: ' . number_format( (float) wc_get_price_to_display( $product ) / $ml * 1000, 2, ',', '.' ) . '&nbsp;&euro; / 1&nbsp;l</span>';
	}
	return $out;
}, 20, 2 );

// 2) + 3) Kartenlisten-Seiten
add_filter( 'the_content', function ( $content ) {
	if ( ! is_singular( 'page' ) || ! in_the_loop() || ! is_main_query() ) {
		return $content;
	}
	// Grundpreis in der Kartenliste "Unser Kaffee" (Karten class="jprod": Name enthaelt die Menge)
	if ( false !== strpos( $content, 'class="jprod"' ) ) {
		$content = preg_replace_callback(
			'#(<article class="jprod"[^>]*data-name="([^"]*)"[\s\S]*?<div class="price">)([^<]+)(</div>)#u',
			function ( $m ) {
				$price = (float) str_replace( ',', '.', preg_replace( '/[^0-9,]/', '', html_entity_decode( $m[3], ENT_QUOTES, 'UTF-8' ) ) );
				$gp    = kt_unit_price_text( $price, kt_grams_from_name( $m[2] ) );
				return $m[1] . $m[3] . $m[4] . ( $gp ? '<div class="kt-gp" style="font-size:12px;color:#666;margin-top:2px">' . $gp . '</div>' : '' );
			},
			$content
		);
	}
	// Hinweiszeile auf Seiten mit Preislisten
	$slug = get_post_field( 'post_name', get_queried_object_id() );
	$list = array( 'jura-kaffeevollautomaten', 'jura-zubehoer', 'jura-pflegeprodukte', 'nivona-kaffeevollautomaten', 'nivona-pflegeprodukte', 'unser-kaffee' );
	if ( in_array( $slug, $list, true ) && false === strpos( $content, 'kt-pn-page' ) ) {
		$note = '<p class="kt-pn-page" style="margin:6px 0 14px;font-size:13px;color:#666">Alle Preise in Euro inkl. gesetzlicher MwSt., zzgl. ' . kt_pn_link() . '.</p>';
		$new  = preg_replace( '#(</h1>)#i', '$1' . str_replace( '$', '\$', $note ), $content, 1, $n );
		if ( $n ) {
			$content = $new;
		}
	}
	return $content;
}, 25 );

// 4) deutsche Beschriftungen
if ( ! function_exists( 'kt_de_labels' ) ) {
	function kt_de_labels() {
		return array(
			'SKU:'        => 'Artikelnummer:',
			'SKU'         => 'Artikelnummer',
			'Category:'   => 'Kategorie:',
			'Categories:' => 'Kategorien:',
			'Tag:'        => 'Schlagwort:',
			'Tags:'       => 'Schlagw&ouml;rter:',
		);
	}
}
add_filter( 'gettext', function ( $text, $original, $domain ) {
	if ( 'woocommerce' === $domain ) {
		$map = kt_de_labels();
		if ( isset( $map[ $text ] ) ) {
			return html_entity_decode( $map[ $text ], ENT_QUOTES, 'UTF-8' );
		}
	}
	return $text;
}, 20, 3 );
add_filter( 'render_block', function ( $html, $block ) {
	if ( isset( $block['blockName'] ) && in_array( $block['blockName'], array( 'woocommerce/product-meta', 'woocommerce/product-sku', 'woocommerce/product-details' ), true ) ) {
		$html = str_replace( array( '>SKU:', 'SKU: ', 'Category:', 'Categories:', 'Tags:', 'Tag:' ), array( '>Artikelnummer:', 'Artikelnummer: ', 'Kategorie:', 'Kategorien:', 'Schlagw&ouml;rter:', 'Schlagwort:' ), $html );
	}
	return $html;
}, 20, 2 );
