/* kaffeetechniker.de - 301-Weiterleitungen von der alten Seite (www.kaffeetechniker.de) auf die neuen Adressen. Nur bei 404, greift also nie
 * in bestehende Seiten ein. Schluessel = kleingeschriebener, dekodierter Pfad ohne abschliessenden Schraegstrich.
 * Quelle der alten Adressen: alte Sitemap (95 URLs, Stand 2026-09-28); Liste: Weiterleitungen-alte-Seite.csv im Repo.
 * Einbau: Code Snippets, PHP, "Ueberall ausfuehren" (Deploy: scratchpad/weiterleitungen.ps1). */
if ( ! function_exists( 'kt_old_redirect_map' ) ) {
	function kt_old_redirect_map() {
		return array(
		'/10-reasons-you-should-love-bloggingbeeba7c8' => '/',
		'/gewaehrleistung' => '/reparaturkosten/',
		'/kaffeemaschinen-mieten' => '/kaffeemaschine-mieten/',
		'/kontakt1' => '/kontakt/',
		'/kopie-kaffeemaschinen-leasin' => '/kaffeemaschine-mieten/',
		'/my-first-blog-post64e0fa77' => '/',
		'/neugeraete' => '/kaffeemaschinen-kaufen/',
		'/produkte' => '/kaffeemaschinen-kaufen/',
		'/reparaturdauer' => '/reparaturkosten/',
		'/service' => '/wartung/',
		'/shop/jura' => '/jura/',
		'/shop/jura/3-phasen-reinigungstabletten-25st-p431136344' => '/product/jura-3-phasen-reinigungstabletten-6-stueck/',
		'/shop/jura/3-phasen-reinigungstabletten-6st-p428071763' => '/product/jura-3-phasen-reinigungstabletten-6-stueck/',
		'/shop/jura/cool-control-schwarz-0-6-l-p431156758' => '/product/jura-cool-control-0-6-l/',
		'/shop/jura/cool-control-schwarz-1-0-l-eb-p431136426' => '/product/jura-cool-control-1-0-l/',
		'/shop/jura/cool-control-weiss-0-6-l-p431155511' => '/product/jura-cool-control-0-6-l/',
		'/shop/jura/cool-control-weiss-1-0-l-p431136427' => '/product/jura-cool-control-1-0-l/',
		'/shop/jura/entkalkung-c125025265' => '/jura-pflegeprodukte/',
		'/shop/jura/filterpatrone-claris-blue-1er-p431132903' => '/jura-pflegeprodukte/',
		'/shop/jura/filterpatrone-claris-blue-3er-set-p428071003' => '/product/jura-filterpatrone-claris-blue-3er-pack/',
		'/shop/jura/filterpatrone-claris-pro-smart-1er-p434899041' => '/jura-pflegeprodukte/',
		'/shop/jura/filterpatrone-claris-smart-1er-p418977001' => '/jura-pflegeprodukte/',
		'/shop/jura/filterpatrone-claris-smart-3er-set-p431958140' => '/product/jura-filterpatrone-claris-smart-3er-pack/',
		'/shop/jura/filterpatrone-claris-smart-pro-maxi-1er-p434899061' => '/jura-pflegeprodukte/',
		'/shop/jura/filterpatrone-claris-white-1er-p431135596' => '/jura-pflegeprodukte/',
		'/shop/jura/filterpatrone-claris-white-3er-set-p431144252' => '/product/jura-filterpatrone-claris-white-3er-pack/',
		'/shop/jura/glacette-schwarz-p431137462' => '/product/jura-glacette/',
		'/shop/jura/glacette-weiss-p431147573' => '/product/jura-glacette/',
		'/shop/jura/glas-milchbehalter-0-5l-p431146837' => '/product/jura-glas-milchbehaelter/',
		'/shop/jura/jb-unser-kaffee-crema-1000g-p434972035' => '/product/jb-caff-crema-1000-g/',
		'/shop/jura/jb-unser-kaffee-espresso-1000g-p434898488' => '/product/jb-espresso-1000-g/',
		'/shop/jura/jura-c-serie-c173081509' => '/jura-kaffeevollautomaten/',
		'/shop/jura/jura-c3-ea-piano-black-p569565034' => '/product/jura-c3-piano-black/',
		'/shop/jura/jura-c9-ea-piano-black-p428049143' => '/product/jura-c9-piano-black/',
		'/shop/jura/jura-care-kit-smart-p431144269' => '/product/jura-care-kit/',
		'/shop/jura/jura-e-serie-c125025753' => '/jura-kaffeevollautomaten/',
		'/shop/jura/jura-e4-ea-piano-black-p428046475' => '/product/jura-e4-piano-black/',
		'/shop/jura/jura-e4-ea-piano-white-p428050962' => '/product/jura-e4-ea-piano-white/',
		'/shop/jura/jura-e8-ed-cosmic-black-p571079515' => '/product/jura-e8-ed-cosmic-black/',
		'/shop/jura/jura-e8-ed-midnight-silver-p427998598' => '/product/jura-e8-midnight-silver/',
		'/shop/jura/jura-e8-ed-piano-white-p570990937' => '/product/jura-e8-ed-piano-white/',
		'/shop/jura/jura-ena-4-full-metropolitan-black-p428050991' => '/product/jura-ena-4-full-metropolitan-black/',
		'/shop/jura/jura-ena-5-ea-night-inox-p428058794' => '/product/jura-ena-5-night-inox/',
		'/shop/jura/jura-ena-8-ec-full-nordic-white-p428061053' => '/jura-kaffeevollautomaten/',
		'/shop/jura/jura-ena-8ec-full-metropolitan-black-p428062878' => '/jura-kaffeevollautomaten/',
		'/shop/jura/jura-ena-serie-c125025762' => '/jura-kaffeevollautomaten/',
		'/shop/jura/jura-entkalkungstabletten-2-phasen-36-tabletten-p431144277' => '/product/jura-2-phasen-entkalkungstabletten-3-x-3-stueck/',
		'/shop/jura/jura-entkalkungstabletten-2-phasen-9-tabletten-p431137433' => '/product/jura-2-phasen-entkalkungstabletten-3-x-3-stueck/',
		'/shop/jura/jura-giga-10-ea-diamond-black-p428050980' => '/product/jura-giga-10-diamond-black/',
		'/shop/jura/jura-giga-c139699330' => '/jura-kaffeevollautomaten/',
		'/shop/jura/jura-j-serie-c139696642' => '/jura-kaffeevollautomaten/',
		'/shop/jura/jura-j10-ea-piano-black-p428058799' => '/product/jura-j10-piano-black/',
		'/shop/jura/jura-milchsystem-reiniger-mini-tabs-mit-dosierer-90g-p431132934' => '/product/jura-milchsystem-reiniger-mini-tabs-90-g/',
		'/shop/jura/jura-e6-eb-piano-black-p428062761' => '/product/jura-e6-ed-piano-black/',
		'/shop/jura/jura-e8-ec-piano-black-p428052179' => '/product/jura-e8-ed-piano-black/',
		'/shop/jura/milchschaumer-hot-cold-p431132940' => '/product/jura-milchschaeumer-hot-cold/',
		'/shop/jura/jura-e6-eb-platin-p428049409' => '/jura-kaffeevollautomaten/',
		'/shop/jura/jura-s8-ea-chrom-p427995274' => '/jura-kaffeevollautomaten/',
		'/shop/jura/jura-s-serie-c125027501' => '/jura-kaffeevollautomaten/',
		'/shop/jura/jura-s8-eb-dark-inox-p369531574' => '/jura-kaffeevollautomaten/',
		'/shop/jura/jura-s8-eb-piano-black-p694914317' => '/jura-kaffeevollautomaten/',
		'/shop/jura/jura-s8-eb-platin-p694937814' => '/jura-kaffeevollautomaten/',
		'/shop/jura/jura-w-serie-c125918263' => '/jura-professional/',
		'/shop/jura/jura-w4-dark-inox-ea-p434908049' => '/product/jura-w4-professional/',
		'/shop/jura/jura-w8-dark-inox-ea-p434898345' => '/product/jura-w8-professional/',
		'/shop/jura/jura-x-serie-c125918762' => '/jura-professional/',
		'/shop/jura/jura-x10-dark-inox-ea-p434906412' => '/product/jura-x10-professional/',
		'/shop/jura/jura-x10c-dark-inox-ea-p507042654' => '/product/jura-x10c-professional/',
		'/shop/jura/jura-x4-dark-inox-ea-p434898882' => '/product/jura-x4-professional/',
		'/shop/jura/jura-x4c-dark-inox-ea-p428049178' => '/product/jura-x4c-professional/',
		'/shop/jura/jura-z-serie-c125024015' => '/jura-kaffeevollautomaten/',
		'/shop/jura/jura-z10-eb-aluminium-black-p427985541' => '/product/jura-z10-aluminium-black/',
		'/shop/jura/jura-z10-eb-aluminium-white-p427980911' => '/product/jura-z10-eb-aluminium-white/',
		'/shop/jura/kaffeevollautomaten-haushalt-c113257763' => '/jura-kaffeevollautomaten/',
		'/shop/jura/kaffeevollautomaten-professional-c125247390' => '/jura-professional/',
		'/shop/jura/pflegeprodukte-c113257762' => '/jura-pflegeprodukte/',
		'/shop/jura/reinigung-c125024016' => '/jura-pflegeprodukte/',
		'/shop/jura/smart-connect-p431146057' => '/product/jura-smart-connect/',
		'/shop/jura/unser-kaffee-c113248585' => '/unser-kaffee/',
		'/shop/jura/wasserfilter-c125028501' => '/jura-pflegeprodukte/',
		'/shop/jura/wifi-connect-p431147569' => '/product/jura-wi-fi-connect-v2/',
		'/shop/jura/wireless-transmitter-p431146789' => '/product/jura-wireless-transmitter/',
		'/shop/jura/zubehor-c123401001' => '/jura-zubehoer/',
		'/test' => '/',
		'/unser_kaffee' => '/unser-kaffee/',
		'/über-uns' => '/ueber-uns/',
		);
	}
}

add_action( 'template_redirect', function () {
	if ( ! is_404() ) {
		return;
	}
	$uri  = isset( $_SERVER['REQUEST_URI'] ) ? wp_unslash( $_SERVER['REQUEST_URI'] ) : '';
	$path = rtrim( strtolower( rawurldecode( (string) wp_parse_url( $uri, PHP_URL_PATH ) ) ), '/' );
	if ( '' === $path ) {
		return;
	}
	$map = kt_old_redirect_map();
	$to  = isset( $map[ $path ] ) ? $map[ $path ] : '';
	// Alte Shop-Adresse mit abweichendem Namenstext (z. B. "-ec-" statt "-ed-"): ueber die Produkt-/Kategorie-ID (-pNNN / -cNNN) zuordnen
	if ( ! $to && 0 === strpos( $path, '/shop/jura/' ) && preg_match( '/-([pc]\d{6,})$/', $path, $m ) ) {
		foreach ( $map as $k => $v ) {
			if ( substr( $k, -strlen( $m[1] ) - 1 ) === '-' . $m[1] ) {
				$to = $v;
				break;
			}
		}
	}
	if ( ! $to && 0 === strpos( $path, '/shop/jura/' ) ) { // unbekannte alte Shop-Adresse: auf die Jura-Seite
		$to = '/jura/';
	}
	if ( $to ) {
		wp_safe_redirect( home_url( $to ), 301 );
		exit;
	}
}, 1 );
