<?php
/* kaffeetechniker.de - Elektronische Widerrufsfunktion (§ 356a BGB).
 * Live seit 25.11.2026 (Seite /vertrag-widerrufen/, Code Snippets "KT Widerrufsfunktion").
 * Einbau: Code Snippets, PHP, "Ueberall ausfuehren" (ohne die erste Zeile "<?php").
 *
 * - Button "Vertrag widerrufen" auf jeder Seite (Fuss), fuehrt auf /vertrag-widerrufen/ (ohne Anmeldung).
 * - Seite "vertrag-widerrufen" mit dem Shortcode [kt_widerruf]; Absenden-Knopf "Widerruf bestätigen".
 * - Eingang wird gespeichert (WooCommerce -> Widerrufe), an den Betrieb und als Eingangsbestaetigung
 *   (Inhalt, Datum, Uhrzeit) an die angegebene E-Mail geschickt.
 * - multipart/form-data, damit die IONOS-WAF Plus-Zeichen nicht blockt. Keine Nonce (Seitencache). */

if ( ! function_exists( 'kt_wr_fields' ) ) {

	define( 'KT_WR_SLUG', 'vertrag-widerrufen' );
	define( 'KT_WR_TO', 'shop@kaffeetechniker.de,info@kaffeetechniker.de' );

	// Feldname => array( Beschriftung, Pflichtfeld, Typ, maximale Laenge )
	function kt_wr_fields() {
		return array(
			'kt_w_name'    => array( 'Vor- und Nachname', true, 'text', 120 ),
			'kt_w_vertrag' => array( 'Bestellnummer oder Auftrag (ersatzweise Datum und Artikel)', true, 'text', 200 ),
			'kt_w_email'   => array( 'E-Mail-Adresse für die Eingangsbestätigung', true, 'email', 150 ),
			'kt_w_text'    => array( 'Nur Teile widerrufen? Welche? / Anmerkung (freiwillig)', false, 'textarea', 1000 ),
		);
	}

	function kt_wr_state( $set = null ) {
		static $state = array( 'errors' => array(), 'values' => array() );
		if ( null !== $set ) {
			$state = $set;
		}
		return $state;
	}

	add_action( 'init', function () {
		register_post_type( 'kt_widerruf', array(
			'labels'       => array( 'name' => 'Widerrufe', 'singular_name' => 'Widerruf', 'menu_name' => 'Widerrufe' ),
			'public'       => false,
			'show_ui'      => true,
			'show_in_menu' => 'woocommerce',
			'show_in_rest' => false,
			'supports'     => array( 'title', 'editor' ),
			'map_meta_cap' => false,
			'capabilities' => array_fill_keys( array( 'edit_post', 'read_post', 'delete_post', 'edit_posts', 'edit_others_posts', 'delete_posts', 'publish_posts', 'read_private_posts' ), 'manage_woocommerce' ),
		) );
	} );

	add_action( 'template_redirect', function () {
		if ( ! is_page( KT_WR_SLUG ) ) {
			return;
		}
		if ( ! defined( 'DONOTCACHEPAGE' ) ) {
			define( 'DONOTCACHEPAGE', true );
		}
		if ( 'POST' === ( $_SERVER['REQUEST_METHOD'] ?? '' ) || isset( $_GET['erledigt'] ) ) {
			nocache_headers();
		}
		if ( 'POST' !== ( $_SERVER['REQUEST_METHOD'] ?? '' ) || ! isset( $_POST['kt_w_send'] ) ) {
			return;
		}

		$values = array();
		$errors = array();
		foreach ( kt_wr_fields() as $key => $f ) {
			$raw = isset( $_POST[ $key ] ) && is_string( $_POST[ $key ] ) ? wp_unslash( $_POST[ $key ] ) : '';
			$val = 'textarea' === $f[2] ? sanitize_textarea_field( $raw ) : sanitize_text_field( $raw );
			$val = mb_substr( $val, 0, $f[3] );
			if ( $f[1] && '' === $val ) {
				$errors[] = 'Bitte ausfüllen: ' . $f[0];
			}
			$values[ $key ] = $val;
		}
		if ( '' !== $values['kt_w_email'] && ! is_email( $values['kt_w_email'] ) ) {
			$errors[] = 'Bitte prüfen Sie die E-Mail-Adresse.';
		}
		$fallback = 'Bitte senden Sie Ihren Widerruf per E-Mail an info@kaffeetechniker.de oder rufen Sie an: 06192 2004363.';
		$rate_key = 'kt_wr_rate_' . md5( ( $_SERVER['REMOTE_ADDR'] ?? '' ) . wp_salt() );
		$count    = (int) get_transient( $rate_key );
		if ( ! empty( $_POST['kt_w_hp'] ) || $count >= 10 ) {
			$errors[] = 'Das Formular konnte nicht verarbeitet werden. ' . $fallback;
		}
		if ( $errors ) {
			kt_wr_state( array( 'errors' => $errors, 'values' => $values ) );
			return;
		}
		set_transient( $rate_key, $count + 1, HOUR_IN_SECONDS );

		$when = wp_date( 'd.m.Y, H:i:s', time(), new DateTimeZone( 'Europe/Berlin' ) ) . ' Uhr';
		$body = "Hiermit widerrufe ich den nachstehend bezeichneten Vertrag.\n\n"
			. 'Name: ' . $values['kt_w_name'] . "\n"
			. 'Vertrag/Bestellung: ' . $values['kt_w_vertrag'] . "\n"
			. 'E-Mail: ' . $values['kt_w_email'] . "\n"
			. ( '' !== $values['kt_w_text'] ? 'Anmerkung: ' . $values['kt_w_text'] . "\n" : '' )
			. "\nEingegangen am: " . $when . "\n";

		$post_id = wp_insert_post( array(
			'post_type'    => 'kt_widerruf',
			'post_status'  => 'private',
			'post_title'   => $when . ' - ' . $values['kt_w_name'] . ' - ' . $values['kt_w_vertrag'],
			'post_content' => $body,
		) );

		$headers  = array( 'Content-Type: text/plain; charset=UTF-8' );
		$to_shop  = wp_mail( explode( ',', KT_WR_TO ), 'WIDERRUF eingegangen: ' . $values['kt_w_vertrag'], $body, array_merge( $headers, array( 'Reply-To: ' . $values['kt_w_email'] ) ) );
		$to_kunde = wp_mail(
			$values['kt_w_email'],
			'Eingangsbestätigung Ihres Widerrufs',
			"Guten Tag,\n\nwir bestätigen den Eingang Ihrer Widerrufserklärung mit folgendem Inhalt:\n\n" . $body
			. "\nDiese Nachricht bestätigt den Eingang. Zum weiteren Ablauf melden wir uns bei Ihnen.\n\n"
			. "Joachim Blöchle Elektro-Service GmbH\nWallauer Straße 4, 65719 Hofheim-Langenhain\nTelefon 06192 2004363, info@kaffeetechniker.de\n",
			array_merge( $headers, array( 'Reply-To: info@kaffeetechniker.de' ) )
		);

		if ( ! $post_id && ! $to_shop ) {
			kt_wr_state( array( 'errors' => array( 'Ihr Widerruf konnte technisch nicht übermittelt werden. ' . $fallback ), 'values' => $values ) );
			return;
		}
		if ( $post_id && ( ! $to_shop || ! $to_kunde ) ) {
			wp_update_post( array( 'ID' => $post_id, 'post_content' => $body . "\nACHTUNG Mailversand: Betrieb " . ( $to_shop ? 'ok' : 'FEHLER' ) . ', Kunde ' . ( $to_kunde ? 'ok' : 'FEHLER' ) ) );
		}

		// Passende Bestellung (Nummer + E-Mail) bekommt eine Notiz. Nach aussen wird nichts verraten.
		if ( function_exists( 'wc_get_order' ) && preg_match( '/\d{3,}/', $values['kt_w_vertrag'], $m ) ) {
			$order = wc_get_order( (int) $m[0] );
			if ( $order instanceof WC_Order && 0 === strcasecmp( $order->get_billing_email(), $values['kt_w_email'] ) ) {
				$order->add_order_note( 'Widerruf über das Online-Formular eingegangen am ' . $when . '.' );
			}
		}

		$token = wp_generate_password( 20, false );
		set_transient( 'kt_wr_ok_' . $token, array( 'body' => $body, 'mail' => $to_kunde ), HOUR_IN_SECONDS );
		wp_safe_redirect( add_query_arg( 'erledigt', $token, get_permalink() ) );
		exit;
	} );

	add_shortcode( 'kt_widerruf', function () {
		$css = '<style>.ktwr{max-width:620px;margin:0 auto;padding:8px 16px 32px;font-size:16px;line-height:1.55}'
			. '.ktwr label{display:block;font-weight:600;margin:14px 0 4px}.ktwr input,.ktwr textarea{width:100%;box-sizing:border-box;padding:10px;border:1px solid #9aa3af;border-radius:4px;font:inherit}'
			. '.ktwr button{margin-top:18px;padding:12px 24px;background:#334155;color:#fff;border:0;border-radius:4px;font-family:inherit;font-size:16px;font-weight:600;cursor:pointer}'
			. '.ktwr .err{border:2px solid #b91c1c;padding:10px 14px;color:#7f1d1d}.ktwr .hp{position:absolute;left:-9999px}.ktwr pre{white-space:pre-wrap;background:#f3f4f6;padding:12px;font:inherit}</style>';

		$token = isset( $_GET['erledigt'] ) ? preg_replace( '/[^A-Za-z0-9]/', '', (string) $_GET['erledigt'] ) : '';
		if ( $token && ( $done = get_transient( 'kt_wr_ok_' . $token ) ) ) {
			return $css . '<div class="ktwr"><h2>Ihr Widerruf ist eingegangen</h2><p>'
				. ( $done['mail'] ? 'Eine Eingangsbestätigung haben wir an Ihre E-Mail-Adresse geschickt.' : 'Die E-Mail-Bestätigung konnte nicht versendet werden. Bitte drucken oder speichern Sie diese Seite und melden Sie sich unter 06192 2004363.' )
				. '</p><pre>' . esc_html( $done['body'] ) . '</pre></div>';
		}

		$state = kt_wr_state();
		$out   = $css . '<div class="ktwr"><h2>Vertrag widerrufen</h2><p>Hier können Verbraucherinnen und Verbraucher einen online geschlossenen Vertrag widerrufen. Eine Anmeldung oder Begründung ist nicht nötig. Einzelheiten stehen in der <a href="' . esc_url( home_url( '/widerruf/' ) ) . '">Widerrufsbelehrung</a>.</p>';
		if ( $state['errors'] ) {
			$out .= '<div class="err" role="alert">' . implode( '<br>', array_map( 'esc_html', $state['errors'] ) ) . '</div>';
		}
		$out .= '<form method="post" enctype="multipart/form-data" action="' . esc_url( get_permalink() ) . '">';
		foreach ( kt_wr_fields() as $key => $f ) {
			$val  = $state['values'][ $key ] ?? '';
			$attr = 'id="' . $key . '" name="' . $key . '" maxlength="' . (int) $f[3] . '"' . ( $f[1] ? ' required' : '' );
			$out .= '<label for="' . $key . '">' . esc_html( $f[0] ) . ( $f[1] ? ' *' : '' ) . '</label>';
			$out .= 'textarea' === $f[2]
				? '<textarea rows="3" ' . $attr . '>' . esc_textarea( $val ) . '</textarea>'
				: '<input type="' . $f[2] . '" ' . $attr . ' value="' . esc_attr( $val ) . '">';
		}
		$out .= '<div class="hp" aria-hidden="true"><input type="text" name="kt_w_hp" tabindex="-1" autocomplete="off"></div>'
			. '<button type="submit" name="kt_w_send" value="1">Widerruf bestätigen</button></form>'
			. '<p style="font-size:14px">Wir verwenden Ihre Angaben, um den Widerruf zu bearbeiten. Näheres in der <a href="' . esc_url( home_url( '/datenschutz/' ) ) . '">Datenschutzerklärung</a>.</p></div>';
		return $out;
	} );

	add_action( 'wp_footer', function () {
		if ( is_admin() || is_page( KT_WR_SLUG ) ) {
			return;
		}
		echo '<div style="text-align:center;padding:16px 16px 72px"><a href="' . esc_url( home_url( '/' . KT_WR_SLUG . '/' ) ) . '" style="display:inline-block;padding:11px 22px;border:2px solid #334155;border-radius:4px;background:#fff;color:#334155;font-weight:700;font-size:15px;text-decoration:none">Vertrag widerrufen</a></div>';
	}, 5 );
}
