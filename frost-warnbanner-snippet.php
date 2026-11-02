/* kaffeetechniker.de - Frost-Warnbanner: zeigt sitewide einen Hinweisbanner, sobald Frost angekuendigt ist.
 * Standort: Wallauer Str. 4, Hofheim-Langenhain (50.1029305 / 8.3966373), Umkreis 40 km.
 * Quellen (beide beruhen auf DWD-Daten, kostenlos, kein API-Key):
 *  1. DWD-Warnungen ueber Bright Sky (api.brightsky.dev/alerts): amtliche Frostwarnung (event_code 22)
 *     fuer den Standort und 8 Punkte im Abstand von 40 km (N, NO, O, SO, S, SW, W, NW).
 *  2. Vorhersage des DWD-Modells ICON ueber Open-Meteo (models=icon_seamless): Tiefstwert <= 0 Grad
 *     in den naechsten 3 Tagen am Standort oder an einem der 8 Punkte im 40-km-Ring.
 * Banner, wenn Quelle 1 ODER 2 Frost meldet. Ergebnis 1 Stunde im Transient gecacht. Faellt eine Quelle aus, zaehlt die
 * andere; fallen beide aus, kein Banner (fail-safe). Admin-Test: ?kt_frost_test=1 (Banner erzwingen),
 * Details: GET /wp-json/kt/v1/frost (nur Administrator). */

function kt_frost_punkte() {
	$lat0 = 50.1029305;
	$lon0 = 8.3966373;
	$km   = 40.0;
	$dlat = $km / 111.2;
	$dlon = $km / ( 111.2 * cos( deg2rad( $lat0 ) ) );
	$pts  = array( array( $lat0, $lon0 ) );
	foreach ( array( array( 1, 0 ), array( 0.7071, 0.7071 ), array( 0, 1 ), array( -0.7071, 0.7071 ), array( -1, 0 ), array( -0.7071, -0.7071 ), array( 0, -1 ), array( 0.7071, -0.7071 ) ) as $d ) {
		$pts[] = array( round( $lat0 + $d[0] * $dlat, 4 ), round( $lon0 + $d[1] * $dlon, 4 ) );
	}
	return $pts;
}

/** Quelle 2: ICON-Vorhersage (Open-Meteo). Rueckgabe: array( frost(bool), tief(float|null), fehler(bool) ) */
function kt_frost_vorhersage() {
	$pts = kt_frost_punkte();
	$lat = array();
	$lon = array();
	foreach ( $pts as $p ) {
		$lat[] = $p[0];
		$lon[] = $p[1];
	}
	$url = 'https://api.open-meteo.com/v1/forecast?latitude=' . implode( ',', $lat ) . '&longitude=' . implode( ',', $lon )
		. '&daily=temperature_2m_min&timezone=Europe%2FBerlin&forecast_days=3&models=icon_seamless';
	$r = wp_remote_get( $url, array( 'timeout' => 6 ) );
	if ( is_wp_error( $r ) || 200 !== wp_remote_retrieve_response_code( $r ) ) {
		return array( false, null, true );
	}
	$body = json_decode( wp_remote_retrieve_body( $r ), true );
	if ( isset( $body['daily'] ) ) {
		$body = array( $body );
	}
	if ( ! is_array( $body ) || ! $body ) {
		return array( false, null, true );
	}
	$tief = null;
	foreach ( $body as $pt ) {
		$mins = isset( $pt['daily']['temperature_2m_min'] ) ? $pt['daily']['temperature_2m_min'] : array();
		foreach ( $mins as $m ) {
			if ( is_numeric( $m ) && ( null === $tief || $m < $tief ) ) {
				$tief = (float) $m;
			}
		}
	}
	return array( null !== $tief && $tief <= 0, $tief, null === $tief );
}

/** Quelle 1: amtliche DWD-Frostwarnungen (Bright Sky). Rueckgabe: array( frost(bool), orte(array), fehler(bool) ) */
function kt_frost_dwd_warnungen() {
	$pts   = kt_frost_punkte();
	$use   = array( $pts[0], $pts[1], $pts[3], $pts[5], $pts[7] ); // Standort + N/O/S/W-Ring (reicht, Warnzellen sind gross)
	$cells = array();
	$orte  = array();
	$ok    = 0;
	foreach ( $use as $p ) {
		$r = wp_remote_get( 'https://api.brightsky.dev/alerts?lat=' . $p[0] . '&lon=' . $p[1], array( 'timeout' => 5 ) );
		if ( is_wp_error( $r ) || 200 !== wp_remote_retrieve_response_code( $r ) ) {
			continue;
		}
		++$ok;
		$b    = json_decode( wp_remote_retrieve_body( $r ), true );
		$cell = isset( $b['location']['warn_cell_id'] ) ? $b['location']['warn_cell_id'] : null;
		if ( $cell && isset( $cells[ $cell ] ) ) {
			continue;
		}
		$cells[ $cell ] = true;
		foreach ( (array) ( isset( $b['alerts'] ) ? $b['alerts'] : array() ) as $a ) {
			$code = isset( $a['event_code'] ) ? (int) $a['event_code'] : 0;
			$ev   = isset( $a['event_en'] ) ? strtolower( $a['event_en'] ) : '';
			if ( 22 === $code || false !== strpos( $ev, 'frost' ) ) {
				$orte[] = isset( $b['location']['name'] ) ? $b['location']['name'] : '';
			}
		}
	}
	return array( ! empty( $orte ), array_values( array_unique( $orte ) ), 0 === $ok );
}

function kt_frost_status() {
	$c = get_transient( 'kt_frost_status2' );
	if ( is_array( $c ) ) {
		return $c;
	}
	$v   = kt_frost_vorhersage();
	$w   = kt_frost_dwd_warnungen();
	$res = array(
		'frost'      => ( $v[0] || $w[0] ),
		'vorhersage' => array( 'frost' => $v[0], 'tiefstwert' => $v[1], 'fehler' => $v[2] ),
		'dwd'        => array( 'frost' => $w[0], 'orte' => $w[1], 'fehler' => $w[2] ),
		'stand'      => current_time( 'mysql' ),
	);
	set_transient( 'kt_frost_status2', $res, ( $v[2] && $w[2] ) ? 30 * MINUTE_IN_SECONDS : HOUR_IN_SECONDS );
	return $res;
}

function kt_frost_warnung_pruefen() {
	if ( is_user_logged_in() && current_user_can( 'manage_options' ) && isset( $_GET['kt_frost_test'] ) ) {
		return true;
	}
	$s = kt_frost_status();
	return ! empty( $s['frost'] );
}

add_action( 'rest_api_init', function () {
	register_rest_route( 'kt/v1', '/frost', array(
		'methods'             => 'GET',
		'permission_callback' => function () {
			return current_user_can( 'manage_options' );
		},
		'callback'            => function ( $req ) {
			if ( $req->get_param( 'neu' ) ) {
				delete_transient( 'kt_frost_status2' );
			}
			return rest_ensure_response( array( 'status' => kt_frost_status(), 'punkte' => kt_frost_punkte() ) );
		},
	) );
} );

add_action( 'wp_body_open', function () {
	if ( ! kt_frost_warnung_pruefen() ) {
		return;
	}
	?>
	<div id="kt-frost-banner" style="background:#b91c1c;color:#fff;text-align:center;padding:10px 44px;font-size:15px;line-height:1.4;position:relative;">
		<span>Achtung Frostgefahr: Bitte lassen Sie Ihr Gerät bei diesen Temperaturen nicht länger im Auto stehen.</span>
		<button type="button" onclick="document.getElementById('kt-frost-banner').style.display='none'" style="position:absolute;right:12px;top:50%;transform:translateY(-50%);background:none;border:none;color:#fff;font-size:20px;cursor:pointer;line-height:1;" aria-label="Banner schließen">&times;</button>
	</div>
	<?php
}, 5 );
