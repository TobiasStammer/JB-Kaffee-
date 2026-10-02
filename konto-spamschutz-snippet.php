// KT Konto-Spamschutz: Honeypot + Zeit-Token fuer WooCommerce-Registrierung, Login, Passwort-Reset.
// Ohne Cookies/Fremdanbieter (DSGVO-neutral). Token ist hex (kein '+', IONOS-WAF-sicher).
if ( ! function_exists( 'kt_ks_token' ) ) {
	function kt_ks_token() {
		$t = time();
		return $t . '.' . hash_hmac( 'sha256', 'ktks' . $t, wp_salt( 'auth' ) );
	}
	function kt_ks_valid( $tok ) {
		if ( ! is_string( $tok ) || ! preg_match( '/^(\d{9,12})\.([a-f0-9]{64})$/', $tok, $m ) ) {
			return false;
		}
		if ( ! hash_equals( hash_hmac( 'sha256', 'ktks' . $m[1], wp_salt( 'auth' ) ), $m[2] ) ) {
			return false;
		}
		$age = time() - (int) $m[1];
		return $age >= 3 && $age <= 7 * DAY_IN_SECONDS;
	}
	function kt_ks_fields() {
		echo '<div class="kt-ks" aria-hidden="true" style="position:absolute;left:-9999px;top:auto;width:1px;height:1px;overflow:hidden;">'
			. '<label>Website<input type="text" name="kt_website" value="" tabindex="-1" autocomplete="off"></label>'
			. '<input type="hidden" name="kt_ts" value="' . esc_attr( kt_ks_token() ) . '">'
			. '</div>';
	}
	add_action( 'woocommerce_register_form', 'kt_ks_fields' );
	add_action( 'woocommerce_login_form', 'kt_ks_fields' );
	add_action( 'woocommerce_lostpassword_form', 'kt_ks_fields' );

	// Vor den WC-Handlern (wp_loaded, Prio 20) pruefen; bei Bot-Verdacht Handler ausser Gefecht setzen.
	add_action( 'wp_loaded', function () {
		if ( 'POST' !== ( $_SERVER['REQUEST_METHOD'] ?? '' ) ) {
			return;
		}
		$forms = array(
			'woocommerce-register-nonce'      => 'register',
			'woocommerce-login-nonce'         => 'login',
			'woocommerce-lost-password-nonce' => 'wc_reset_password',
		);
		$hit = false;
		foreach ( $forms as $nonce => $submit ) {
			if ( isset( $_POST[ $nonce ] ) ) {
				$hit = array( $nonce, $submit );
				break;
			}
		}
		if ( ! $hit ) {
			return;
		}
		$bot = ! empty( $_POST['kt_website'] ) || ! kt_ks_valid( $_POST['kt_ts'] ?? '' );
		if ( ! $bot ) {
			return;
		}
		unset( $_POST[ $hit[0] ], $_POST[ $hit[1] ], $_REQUEST[ $hit[0] ], $_REQUEST[ $hit[1] ] );
		if ( function_exists( 'wc_add_notice' ) ) {
			wc_add_notice( 'Die Anfrage konnte nicht verarbeitet werden. Bitte lade die Seite neu und versuche es erneut.', 'error' );
		}
	}, 5 );
}
