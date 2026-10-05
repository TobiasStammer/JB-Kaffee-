/* kaffeetechniker.de - SEO-Titel und Meta-Descriptions (ergaenzt BeyondSEO/rankingcoach, dessen REST-Schnittstelle ein Browser-Nonce verlangt).
 * Stand 05.10.2026 (Search-Console-Auswertung): 56 von 65 Seiten hatten Titel > 60 Zeichen wegen des langen Anhangs
 * " - JB Kaffeemaschinen - Service & Verkauf"; Kategorieseiten hatten nur den Begriffsnamen als Titel ("JURA", "Tee") und
 * teils keine Description; Startseite/Reparatur rankten fuer "kaffeemaschinen reparatur" (1.400 Impressionen, 10 Klicks).
 * Mechanik: wp_head wird gepuffert, <title> und description/og:description/twitter:description werden ersetzt.
 *  - Anhang wird zu " | JB Kaffeemaschinen" gekuerzt.
 *  - Startseite und /reparatur/ haben feste Titel/Descriptions; Produktkategorien bekommen "<Name> kaufen | ..." und,
 *    falls keine/zu kurze Description, eine generische; Produkte ohne Description ebenso.
 * Einbau: Code Snippets, PHP, "Ueberall ausfuehren" (Deploy: scratchpad/seo-titel.ps1). */
// Redaktionelle Descriptions fuer Seiten (BeyondSEO zieht sonst Menuetext: "Rufen Sie uns an ... Menue Start ...")
$kt_seo_page_desc = array(
	'kontakt' => 'Kontakt zu JB Kaffeemaschinen in Hofheim-Langenhain: Telefon, E-Mail und Anfahrt für Reparatur, Wartung, Kauf und Miete von Kaffeemaschinen.',
	'anfahrt' => 'So finden Sie JB Kaffeemaschinen: Wallauer Straße 4 in 65719 Hofheim-Langenhain, zwischen Wiesbaden, Mainz und Frankfurt. Öffnungszeiten und Anfahrt.',
	'ueber-uns' => 'Über JB Kaffeemaschinen: Elektro-Service Blöchle in Hofheim-Langenhain – Werkstatt, Verkauf und Beratung rund um Kaffeevollautomaten.',
	'jobs' => 'Jobs bei JB Kaffeemaschinen in Hofheim-Langenhain: Werden Sie Teil unseres Teams rund um Kaffeevollautomaten, Service und Verkauf.',
	'impressum' => 'Impressum von JB Kaffeemaschinen – Joachim Blöchle Elektro-Service GmbH, Wallauer Straße 4, 65719 Hofheim-Langenhain.',
	'datenschutz' => 'Datenschutzerklärung von JB Kaffeemaschinen: So verarbeiten wir Ihre Daten beim Besuch der Website, im Online-Shop und bei Anfragen.',
	'agb' => 'Allgemeine Geschäftsbedingungen von JB Kaffeemaschinen für Online-Shop, Reparatur und Service.',
	'widerruf' => 'Widerrufsbelehrung und Muster-Widerrufsformular von JB Kaffeemaschinen für Bestellungen im Online-Shop.',
	'versand-und-zahlung' => 'Versand und Zahlung im Shop von JB Kaffeemaschinen: Versandkosten nach Gewicht, versandkostenfrei ab 1.500 €, Abholung im Laden und Zahlungsarten.',
	'wartung' => 'Wartung für Kaffeevollautomaten in Hofheim-Langenhain: regelmäßige Entkalkung, Reinigung und Pflege für bessere Qualität und längere Lebensdauer.',
	'wartungserinnerung' => 'Wartungserinnerung für Ihre Kaffeemaschine: Wir erinnern Sie rechtzeitig an den nächsten Wartungstermin bei JB Kaffeemaschinen.',
	'reparaturablauf' => 'So läuft die Reparatur Ihrer Kaffeemaschine bei JB Kaffeemaschinen ab: von der Anmeldung über die Diagnose bis zur Rückgabe.',
	'reparaturkosten' => 'Was kostet die Reparatur einer Kaffeemaschine? Richtwerte, Kostenvoranschlag und Dauer bei JB Kaffeemaschinen in Hofheim-Langenhain.',
	'reparaturauftrag' => 'Reparaturauftrag online erteilen: Kaffeemaschine bei JB Kaffeemaschinen in Hofheim-Langenhain zur Reparatur anmelden.',
	'reparatur-check' => 'Reparatur-Check für Ihre Kaffeemaschine: Problem kurz beschreiben und eine erste Einschätzung zu Ursache und Kostenrahmen erhalten.',
	'hinweise-nach-der-reparatur' => 'Hinweise nach der Reparatur: Das sollten Sie bei Ihrer Kaffeemaschine nach der Rückgabe beachten.',
	'marken' => 'Marken, die wir reparieren und verkaufen: JURA, NIVONA und weitere Hersteller – Service und Beratung bei JB Kaffeemaschinen in Hofheim-Langenhain.',
	'leihgeraete' => 'Leihgerät für die Reparaturzeit: Mietgerät von JB Kaffeemaschinen, damit Sie auch während der Reparatur Kaffee genießen können.',
	'kaffeemaschine-mieten' => 'Kaffeemaschine mieten bei JB Kaffeemaschinen in Hofheim-Langenhain: Kaffeevollautomaten für Zuhause, Büro und Veranstaltungen.',
	'kaffeemaschine-leasen' => 'Kaffeemaschine leasen für Büro und Gewerbe: Kaffeevollautomaten von JURA mit Service von JB Kaffeemaschinen im Rhein-Main-Gebiet.',
	'wertgarantie' => 'WERTGARANTIE Reparaturschutz für Ihre Kaffeemaschine: Absicherung gegen Reparaturkosten, erhältlich bei JB Kaffeemaschinen.',
	'kaffeemaschinen-kaufen' => 'Neue Kaffeemaschinen von JURA und NIVONA kaufen: Beratung, Vorführung und Service beim Fachhändler in Hofheim-Langenhain.',
	'jura' => 'JURA Online-Shop: Kaffeevollautomaten, Zubehör und Pflegeprodukte vom autorisierten Fachhändler JB Kaffeemaschinen in Hofheim-Langenhain.',
	'jura-kaffeevollautomaten' => 'JURA Kaffeevollautomaten für Zuhause kaufen: Modelle von A bis GIGA, Beratung und Service vom Fachhändler in Hofheim-Langenhain.',
	'jura-professional' => 'JURA Professional Kaffeevollautomaten für Büro, Gastronomie und Gewerbe – Beratung, Verkauf und Service von JB Kaffeemaschinen.',
	'jura-zubehoer' => 'JURA Zubehör: Tassen, Gläser, Düsen, Milchsysteme und mehr – original vom autorisierten Fachhändler JB Kaffeemaschinen.',
	'jura-pflegeprodukte' => 'JURA Pflegeprodukte: Reinigungstabletten, Entkalker, Milchsystem-Reiniger und Wasserfilter für Ihren Kaffeevollautomaten.',
	'jura-fehlercodes' => 'JURA Fehlercodes und Meldungen verstehen: Bedeutung und erste Schritte zur Lösung bei Störungen am Kaffeevollautomaten.',
	'nivona' => 'NIVONA Online-Shop: Kaffeevollautomaten, Zubehör und Pflegeprodukte vom Fachhändler JB Kaffeemaschinen in Hofheim-Langenhain.',
	'nivona-kaffeevollautomaten' => 'NIVONA Kaffeevollautomaten kaufen: Modelle im Vergleich, Beratung und Service von JB Kaffeemaschinen in Hofheim-Langenhain.',
	'nivona-pflegeprodukte' => 'NIVONA Pflegeprodukte: Reiniger, Entkalker und Filter für Ihren Kaffeevollautomaten – bei JB Kaffeemaschinen bestellen.',
	'pflegemittel' => 'Pflegemittel für Kaffeevollautomaten: Entkalker, Reiniger und Filter für JURA und NIVONA – im Shop von JB Kaffeemaschinen.',
	'unser-kaffee' => 'Unser Kaffee und Tee: Eigene Röstung und lose Teemischungen aus dem Geschäft von JB Kaffeemaschinen in Hofheim-Langenhain.',
	'unser-kaffee-wissen' => 'Kaffee-Wissen von JB Kaffeemaschinen: Sorten, Röstung, Zubereitung und Tipps für besseren Kaffee aus dem Vollautomaten.',
	'unser-tee-wissen' => 'Tee-Wissen von JB Kaffeemaschinen: Sorten, Zubereitung und Tipps für den perfekten Tee.',
	'kaffee-quiz' => 'Kaffee-Quiz von JB Kaffeemaschinen: Testen Sie Ihr Wissen rund um Kaffee.',
	'wasserhaerte' => 'Wasserhärte in Hofheim und Umgebung: So stellen Sie Ihren Kaffeevollautomaten richtig ein und schützen ihn vor Kalk.',
	'hilfethemen' => 'Hilfe und Ratgeber rund um Ihre Kaffeemaschine: Störungen beheben, reinigen, pflegen und die richtige Maschine finden.',
	'hilfe-ratgeber' => 'Ratgeber zu Kaffeevollautomaten: Reparieren oder neu kaufen, Systeme im Vergleich und Kaufberatung von JB Kaffeemaschinen.',
	'hilfe-reinigung-pflege' => 'Reinigung und Pflege von Kaffeevollautomaten: Brühgruppe, Milchsystem, Entkalken und Wasserfilter Schritt für Schritt.',
	'hilfe-stoerungen' => 'Störung am Kaffeevollautomaten selbst beheben: Häufige Probleme wie kalter Kaffee, Undichtigkeit oder Milchschaum und ihre Lösungen.',
	'ratgeber-siebtraeger' => 'Siebträgermaschine: Was Sie zu Funktion, Reinigung und Wartung wissen sollten – Ratgeber von JB Kaffeemaschinen.',
	'ratgeber-systeme-vergleich' => 'Kaffeemaschinen-Systeme im Vergleich: Vollautomat, Siebträger, Kapsel und Filter – Vor- und Nachteile auf einen Blick.',
	'ratgeber-kaufberatung' => 'Kaufberatung Kaffeevollautomat: Worauf es bei Mahlwerk, Milchsystem, Bedienung und Pflege ankommt.',
	'ratgeber-reparieren-lohnt-sich' => 'Kaffeemaschine reparieren oder neu kaufen? Wann sich eine Reparatur lohnt und wann ein neues Gerät sinnvoller ist.',
	'pflege-bruehgruppe' => 'Brühgruppe reinigen und pflegen: So halten Sie die Brühgruppe Ihres Kaffeevollautomaten sauber und funktionsfähig.',
	'pflege-milchsystem' => 'Milchsystem reinigen: So pflegen Sie Milchschlauch und Milchschaumdüse Ihres Kaffeevollautomaten hygienisch.',
	'pflege-wasserfilter' => 'Wasserfilter im Kaffeevollautomaten: Wann und wie Sie ihn wechseln und warum er für Geschmack und Gerät wichtig ist.',
	'pflege-entkalken' => 'Kaffeevollautomat entkalken: Wann es nötig ist, welches Mittel passt und wie das Entkalken Schritt für Schritt funktioniert.',
	'stoerung-kaffee-kalt' => 'Kaffee ist nicht heiß genug? Mögliche Ursachen und Lösungen beim Kaffeevollautomaten.',
	'stoerung-milchschaum' => 'Kein oder schlechter Milchschaum beim Kaffeevollautomaten? Ursachen und Lösungen im Überblick.',
	'stoerung-kaffeesatz-nass' => 'Kaffeesatz zu nass oder Trester matschig? Mögliche Ursachen und Lösungen beim Kaffeevollautomaten.',
	'stoerung-undicht' => 'Wasser unter oder im Kaffeevollautomaten? Typische Ursachen für Undichtigkeit und was Sie tun können.',
	'stoerung-entlueften' => 'Kaffeevollautomat entlüften: So beheben Sie Luft im System, wenn kein Wasser mehr gefördert wird.',
	'stoerung-wassertank-meldung' => 'Meldung zum Wassertank trotz vollem Tank? Ursachen und Lösungen beim Kaffeevollautomaten.',
	'stoerung-abtropfschale' => 'Meldung zur Abtropfschale oder zum Satzbehälter? Ursachen und Lösungen beim Kaffeevollautomaten.',
	'stoerung-bruehgruppe' => 'Störung an der Brühgruppe des Kaffeevollautomaten: Typische Ursachen und was Sie selbst prüfen können.',
	'stoerung-kaffee-langsam' => 'Kaffee läuft nur langsam oder tröpfelt? Mögliche Ursachen und Lösungen beim Kaffeevollautomaten.',
	'stoerung-kein-wasser' => 'Kein Wasser oder keine Kaffeeausgabe? Ursachen und Lösungen beim Kaffeevollautomaten.',
);

add_action( 'wp_head', function () {
	if ( is_admin() || is_feed() ) {
		return;
	}
	ob_start();
}, 0 );

add_action( 'wp_head', function () use ( $kt_seo_page_desc ) {
	if ( is_admin() || is_feed() || ob_get_level() < 1 ) {
		return;
	}
	$html  = ob_get_clean();
	$brand = ' | JB Kaffeemaschinen';
	$title = null;
	$desc  = null;

	if ( is_front_page() ) {
		$title = 'Kaffeemaschinen Reparatur Hofheim' . $brand;
		$desc  = 'Kaffeevollautomaten reparieren, warten und kaufen in Hofheim-Langenhain. Autorisierte JURA-Servicestelle für Wiesbaden, Frankfurt, Mainz und den Taunus.';
	} elseif ( is_page( 'reparatur' ) ) {
		$title = 'Kaffeemaschine Reparatur Rhein-Main' . $brand;
		$desc  = 'Kaffeemaschine defekt? Reparatur von JURA, NIVONA und Siebträgermaschinen in Hofheim-Langenhain – für Wiesbaden, Frankfurt, Mainz und den Taunus.';
	} elseif ( is_page() && isset( $kt_seo_page_desc[ get_post_field( 'post_name', get_queried_object_id() ) ] ) ) {
		$desc = $kt_seo_page_desc[ get_post_field( 'post_name', get_queried_object_id() ) ];
	} elseif ( is_tax( 'product_cat' ) ) {
		$term = get_queried_object();
		if ( $term && ! is_wp_error( $term ) ) {
			$name = $term->name;
			if ( $term->parent ) {
				$par = get_term( $term->parent, 'product_cat' );
				if ( $par && ! is_wp_error( $par ) && stripos( $name, $par->name ) !== 0 ) {
					$name = $par->name . ' ' . $name;
				}
			}
			$title = $name . ' kaufen' . $brand;
			$desc  = $name . ' vom Fachhändler: Beratung, Lieferung und Service von JB Kaffeemaschinen in Hofheim-Langenhain.';
		}
	} elseif ( is_singular( 'product' ) ) {
		$short = trim( wp_strip_all_tags( html_entity_decode( (string) get_post_field( 'post_excerpt', get_queried_object_id() ), ENT_QUOTES, 'UTF-8' ) ) );
		$desc  = $short !== '' ? get_the_title() . ': ' . $short : get_the_title() . ' kaufen bei JB Kaffeemaschinen in Hofheim-Langenhain – Beratung, Lieferung und Service vom Fachhändler.';
	}

	// Titel: fester Titel, sonst Anhang kuerzen
	if ( $title !== null ) {
		$html = preg_replace( '#<title>.*?</title>#s', '<title>' . esc_html( $title ) . '</title>', $html, 1 );
	} else {
		$html = preg_replace( '#\s+[-–]\s+JB Kaffeemaschinen\s+[-–]\s+Service (?:&amp;|&) Verkauf</title>#u', $brand . '</title>', $html, 1 );
	}

	// Description: feste (Start/Reparatur) immer, generische nur wenn fehlend oder < 70 Zeichen
	if ( $desc !== null ) {
		$force = is_front_page() || is_page( 'reparatur' );
		$cur   = '';
		if ( preg_match( '#<meta name="description"[^>]*content="([^"]*)"#', $html, $m ) ) {
			$cur = html_entity_decode( $m[1], ENT_QUOTES, 'UTF-8' );
		}
		if ( $force || mb_strlen( $cur ) < 70 || preg_match( '/Rufen Sie uns an|Menü Start/u', $cur ) || is_singular( 'product' ) || ( is_page() && isset( $kt_seo_page_desc[ get_post_field( 'post_name', get_queried_object_id() ) ] ) ) ) {
			$e = esc_attr( $desc );
			if ( preg_match( '#<meta name="description"#', $html ) ) {
				$html = preg_replace( '#(<meta name="description"[^>]*content=")[^"]*(")#', '${1}' . $e . '${2}', $html, 1 );
			} else {
				$html .= '<meta name="description" content="' . $e . '" />' . "\n";
			}
			$html = preg_replace( '#(<meta property="og:description"[^>]*content=")[^"]*(")#', '${1}' . $e . '${2}', $html, 1 );
			$html = preg_replace( '#(<meta name="twitter:description"[^>]*content=")[^"]*(")#', '${1}' . $e . '${2}', $html, 1 );
		}
	}
	echo $html;
}, 99999 );
