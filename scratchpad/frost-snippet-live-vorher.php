/* kaffeetechniker.de - Frost-Warnbanner: zeigt sitewide einen Hinweisbanner, wenn fuer den Standort
 * (Wallauer Str. 4, Hofheim-Langenhain, 50.1029305/8.3966373) in den naechsten 48h Frost (<=0 Grad)
 * vorhergesagt ist. Wetterdaten von Open-Meteo (kostenlos, kein API-Key noetig). Die Vorhersage wird
 * 3 Stunden lang zwischengespeichert (Transient), damit nicht bei jedem Seitenaufruf extern angefragt
 * wird. Bei API-Fehlern wird kein Banner angezeigt (fail-safe), damit die Seite nie davon abhaengt.
 * Preview fuer Admins zum Testen des Aussehens: URL mit ?kt_frost_test=1 aufrufen (eingeloggt). */

function kt_frost_warnung_pruefen() {
	if ( is_user_logged_in() && current_user_can( 'manage_options' ) && isset( $_GET['kt_frost_test'] ) ) {
		return true;
	}

	$cached = get_transient( 'kt_frost_status' );
	if ( false !== $cached ) {
		return '1' === $cached;
	}

	$url      = 'https://api.open-meteo.com/v1/forecast?latitude=50.1029305&longitude=8.3966373&daily=temperature_2m_min&timezone=Europe%2FBerlin&forecast_days=2';
	$response = wp_remote_get( $url, array( 'timeout' => 5 ) );

	if ( is_wp_error( $response ) || 200 !== wp_remote_retrieve_response_code( $response ) ) {
		set_transient( 'kt_frost_status', '0', 30 * MINUTE_IN_SECONDS );
		return false;
	}

	$body = json_decode( wp_remote_retrieve_body( $response ), true );
	$mins = isset( $body['daily']['temperature_2m_min'] ) ? $body['daily']['temperature_2m_min'] : array();

	$frost = false;
	foreach ( $mins as $min ) {
		if ( is_numeric( $min ) && $min <= 0 ) {
			$frost = true;
			break;
		}
	}

	set_transient( 'kt_frost_status', $frost ? '1' : '0', 3 * HOUR_IN_SECONDS );
	return $frost;
}

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
