/* kaffeetechniker.de - Registrierung: Hinweis, wenn die E-Mail-Adresse schon ein Konto hat.
 * WooCommerce laedt die Seite sonst kommentarlos neu: das SEO-Plugin (BeyondSEO) rendert den Seiteninhalt
 * schon im <head> fuer das JSON-LD und verbraucht dabei die WC-Meldung, die sichtbare Seite hat dann keine mehr.
 * Deshalb: Fehler wie ueblich melden (verhindert das Anlegen), zusaetzlich Merker setzen und den Hinweis
 * nach dem Rendern selbst ausgeben, falls keine WC-Meldung mehr uebrig ist.
 * Einbau: Code Snippets, PHP, "Ueberall ausfuehren" (Deploy: scratchpad/konto-email-exists.ps1). */
if ( ! function_exists( 'kt_email_exists_msg' ) ) {
	function kt_email_exists_msg() {
		return sprintf(
			'Diese E-Mail-Adresse ist bereits registriert. Bitte <a href="%s">melde dich an</a> oder <a href="%s">setze dein Passwort zur&uuml;ck</a>.',
			esc_url( wc_get_page_permalink( 'myaccount' ) ),
			esc_url( wc_lostpassword_url() )
		);
	}
}

add_filter( 'woocommerce_process_registration_errors', function ( $errors, $username, $password, $email ) {
	if ( is_wp_error( $errors ) && ! $errors->get_error_code() && $email && email_exists( $email ) ) {
		$GLOBALS['kt_email_exists'] = true;
		$errors->add( 'kt-email-exists', kt_email_exists_msg() );
	}
	return $errors;
}, 10, 4 );

add_action( 'woocommerce_before_customer_login_form', function () {
	if ( empty( $GLOBALS['kt_email_exists'] ) || wc_notice_count( 'error' ) ) {
		return;
	}
	echo '<div class="woocommerce-error" role="alert" style="list-style:none;margin:0 0 20px;padding:12px 16px;'
		. 'background:#fdf3f3;border:1px solid #f0c9c9;border-left:4px solid #b32d2e;border-radius:6px;font-size:14.5px;line-height:1.5">'
		. '<strong>Fehler:</strong> ' . kt_email_exists_msg() . '</div>';
}, 20 );
