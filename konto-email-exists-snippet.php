/* kaffeetechniker.de - Registrierung: Hinweis, wenn die E-Mail-Adresse schon ein Konto hat.
 * WooCommerce legt bei bekannter E-Mail kein neues Konto an und zeigt sonst keine (verstaendliche) Rueckmeldung.
 * Hier: Fehler mit Links zu Anmelden/"Passwort vergessen" melden - das verhindert das Anlegen, WooCommerce zeigt die Meldung an.
 * (Frueher gab es zusaetzlich einen Notbehelf zum Selbst-Ausgeben, weil das SEO-Plugin die Meldung verbrauchte; das loest jetzt das
 *  Snippet "KT WC-Meldungen sichtbar" - wc-notices-sichtbar-snippet.php.)
 * Einbau: Code Snippets, PHP, "Ueberall ausfuehren" (Deploy: scratchpad/konto-email-exists.ps1). */
add_filter( 'woocommerce_process_registration_errors', function ( $errors, $username, $password, $email ) {
	if ( is_wp_error( $errors ) && ! $errors->get_error_code() && $email && email_exists( $email ) ) {
		$errors->add(
			'kt-email-exists',
			sprintf(
				'Diese E-Mail-Adresse ist bereits registriert. Bitte <a href="%s">melden Sie sich an</a> oder <a href="%s">setzen Sie Ihr Passwort zur&uuml;ck</a>.',
				esc_url( wc_get_page_permalink( 'myaccount' ) ),
				esc_url( wc_lostpassword_url() )
			)
		);
	}
	return $errors;
}, 10, 4 );
