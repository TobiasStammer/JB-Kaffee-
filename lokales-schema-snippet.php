/* kaffeetechniker.de - Strukturierte Daten (Schema.org JSON-LD): LocalBusiness-Angaben sitewide im <head>.
 * Das SEO-Plugin (BeyondSEO) liefert bereits ein eigenes @graph mit Organization (nur Name+URL, ohne Adresse/
 * Telefon/Oeffnungszeiten) und WebSite+SearchAction (bereits vollstaendig, NICHT duplizieren!). Dieses Snippet
 * REICHERT den vorhandenen Organization-Knoten an (gleiche @id "#organization", damit Schema-Parser beide
 * Bloecke als EINE Entitaet zusammenfuehren) statt einen zweiten, konkurrierenden Eintrag anzulegen.
 * Fuer ein lokales Handwerks-/Verkaufsgeschaeft der wichtigste Hebel: Google kann Adresse, Oeffnungszeiten,
 * Telefon direkt im Suchergebnis zeigen (Rich Snippet / Local Pack). Alle Angaben 1:1 aus Impressum/Kontakt/
 * Anfahrt uebernommen (NAP-Konsistenz), Name exakt wie im Seitentitel ("-" nicht "–"). Geo-Koordinaten per
 * Google Maps ermittelt (2026-09-29). Kein Google-Unternehmensprofil fuer die Adresse gefunden - das ist
 * Sache des Betreibers, deckt sich nicht automatisch mit diesem Schema.
 * Einbau: Code Snippets, PHP, "Ueberall ausfuehren" (Deploy: scratchpad/lokales-schema.ps1). */
add_action( 'wp_head', function () {
	$logo = wp_get_attachment_image_url( 149, 'full' );
	$data = array(
		'@context' => 'https://schema.org',
		'@graph'   => array(
			array(
				'@type'             => array( 'Organization', 'LocalBusiness', 'ElectronicsStore' ),
				'@id'               => home_url( '/#organization' ),
				'name'              => 'JB Kaffeemaschinen - Service & Verkauf',
				'legalName'         => 'Joachim Blöchle Elektro-Service GmbH',
				'url'               => home_url( '/' ),
				'image'             => $logo ? $logo : null,
				'logo'              => $logo ? $logo : null,
				'telephone'         => '+49 6192 2004363',
				'email'             => 'info@kaffeetechniker.de',
				'address'           => array(
					'@type'           => 'PostalAddress',
					'streetAddress'   => 'Wallauer Straße 4',
					'postalCode'      => '65719',
					'addressLocality' => 'Hofheim-Langenhain',
					'addressCountry'  => 'DE',
				),
				'geo'               => array(
					'@type'     => 'GeoCoordinates',
					'latitude'  => 50.1029305,
					'longitude' => 8.3966373,
				),
				'openingHoursSpecification' => array(
					array(
						'@type'     => 'OpeningHoursSpecification',
						'dayOfWeek' => array( 'Monday', 'Tuesday', 'Wednesday', 'Thursday' ),
						'opens'     => '08:00',
						'closes'    => '16:00',
					),
					array(
						'@type'     => 'OpeningHoursSpecification',
						'dayOfWeek' => array( 'Friday' ),
						'opens'     => '08:00',
						'closes'    => '13:00',
					),
				),
				'areaServed'        => array( 'Hofheim am Taunus', 'Wiesbaden', 'Mainz', 'Frankfurt am Main' ),
				'hasMap'            => 'https://www.google.com/maps/search/?api=1&query=50.1029305,8.3966373',
			),
		),
	);
	echo '<script type="application/ld+json">' . wp_json_encode( $data, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE ) . '</script>' . "\n"; // phpcs:ignore WordPress.Security.EscapeOutput
}, 20 );
