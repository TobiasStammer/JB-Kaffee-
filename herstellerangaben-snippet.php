/* kaffeetechniker.de - Herstellerangaben auf Produktseiten (EU-Produktsicherheitsverordnung GPSR, seit 13.12.2024): Name, Anschrift und E-Mail
 * des Herstellers bzw. der verantwortlichen Person in der EU. Ausgabe unter Artikelnummer/Kategorie (Block product-meta) fuer JURA- und NIVONA-Produkte.
 * Quellen: Impressum de.jura.com (JURA Elektrogeraete Vertriebs-GmbH, Nuernberg) / nivona.com (NIVONA Apparate GmbH), Stand 2026-09-28.
 * Hinweis: JURA (Schweiz) hat keinen ausdruecklich benannten "EU-Bevollmaechtigten" veroeffentlicht - die deutsche Vertriebs-GmbH ist die Anlaufstelle;
 * Angaben bei Gelegenheit vom Hersteller bestaetigen lassen.
 * Einbau: Code Snippets, PHP, "Ueberall ausfuehren" (Deploy: scratchpad/herstellerangaben.ps1). */
add_filter( 'render_block', function ( $html, $block ) {
	if ( empty( $block['blockName'] ) || 'woocommerce/product-meta' !== $block['blockName'] || ! is_singular( 'product' ) ) {
		return $html;
	}
	$id = get_the_ID();
	if ( has_term( array( 'jura', 'jura-kaffeevollautomaten', 'jura-zubehoer', 'jura-pflegeprodukte', 'jura-professional' ), 'product_cat', $id ) ) {
		$txt = '<strong>Herstellerangaben:</strong> JURA Elektroapparate AG, Kaffeeweltstr. 10, CH-4626 Niederbuchsiten, Schweiz.<br>'
			. 'Ansprechpartner in der EU (Deutschland): JURA Elektrogeräte Vertriebs-GmbH, Bamberger Straße 10, 90425 Nürnberg, '
			. '<a href="mailto:zentrale@de.jura.com" style="color:inherit">zentrale@de.jura.com</a>.';
	} elseif ( has_term( array( 'nivona', 'nivona-kaffeevollautomaten', 'nivona-pflegeprodukte' ), 'product_cat', $id ) ) {
		$txt = '<strong>Herstellerangaben:</strong> NIVONA Apparate GmbH, Südwestpark 49, 90449 Nürnberg, Deutschland, '
			. '<a href="mailto:info@nivona.com" style="color:inherit">info@nivona.com</a>.';
	} else {
		return $html;
	}
	$txt .= '<br>Sicherheits- und Warnhinweise sowie die Bedienungsanleitung finden Sie in den Unterlagen des Herstellers, die dem Gerät bzw. Produkt beiliegen.';
	return $html . '<p class="kt-gpsr" style="margin:14px 0 0;font-size:13px;line-height:1.55;color:#555">' . $txt . '</p>';
}, 25, 2 );
