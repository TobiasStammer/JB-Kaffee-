/* kaffeetechniker.de - Sendungsverfolgung: Anbieter (DHL/GLS) + Sendungsnummer pro Bestellung.
 * - Kasten "Sendungsverfolgung" in der Bestellung (Admin, Seitenleiste)
 * - Die Nummer erscheint in der Kundenmail "Bestellung abgeschlossen" (mit Verfolgungslink) und unter "Mein Konto > Bestellung ansehen"
 * - Bei PayPal-Bestellungen wird das Feld automatisch gefuellt, wenn im PayPal-Kasten eine Nummer eingetragen wird
 * Meta: _kt_tracking_carrier (dhl|gls), _kt_tracking_number
 * Einbau: Code Snippets, PHP, "Ueberall ausfuehren" (Deploy: scratchpad/sendungsverfolgung.ps1). */

if ( ! function_exists( 'kt_trk_carriers' ) ) {

	function kt_trk_carriers() {
		return array(
			'dhl' => array( 'DHL', 'https://www.dhl.de/de/privatkunden/pakete-empfangen/verfolgen.html?piececode=%s' ),
			'gls' => array( 'GLS', 'https://gls-group.com/DE/de/paketverfolgung?match=%s' ),
		);
	}

	function kt_trk_get( $order ) {
		$all = kt_trk_carriers();
		$c   = (string) $order->get_meta( '_kt_tracking_carrier' );
		$n   = trim( (string) $order->get_meta( '_kt_tracking_number' ) );
		if ( '' === $n || ! isset( $all[ $c ] ) ) {
			return null;
		}
		return array(
			'name'   => $all[ $c ][0],
			'number' => $n,
			'url'    => sprintf( $all[ $c ][1], rawurlencode( $n ) ),
		);
	}

	function kt_trk_block( $order, $plain = false ) {
		$t = kt_trk_get( $order );
		if ( ! $t ) {
			return '';
		}
		if ( $plain ) {
			return "\n" . 'Ihre Sendungsverfolgung' . "\n" . 'Versanddienstleister: ' . $t['name'] . "\n" . 'Sendungsnummer: ' . $t['number'] . "\n" . 'Sendung verfolgen: ' . $t['url'] . "\n\n";
		}
		return '<div style="margin:0 0 24px;padding:14px 18px;border:1px solid #e0e0e0;border-radius:6px;background:#f7f7f7;line-height:1.6">'
			. '<strong style="font-size:16px">Ihre Sendungsverfolgung</strong><br>'
			. 'Versanddienstleister: ' . esc_html( $t['name'] ) . '<br>'
			. 'Sendungsnummer: <strong>' . esc_html( $t['number'] ) . '</strong><br>'
			. '<a href="' . esc_url( $t['url'] ) . '" style="color:#334155;font-weight:bold">Sendung verfolgen &rarr;</a></div>';
	}
}

// Kasten in der Bestellung (Admin)
add_action( 'add_meta_boxes', function () {
	$screen = function_exists( 'wc_get_page_screen_id' ) ? wc_get_page_screen_id( 'shop-order' ) : 'shop_order';
	add_meta_box( 'kt_tracking', 'Sendungsverfolgung', function ( $post_or_order ) {
		$order = ( $post_or_order instanceof WP_Post ) ? wc_get_order( $post_or_order->ID ) : $post_or_order;
		if ( ! $order ) {
			return;
		}
		$cur = (string) $order->get_meta( '_kt_tracking_carrier' );
		$num = (string) $order->get_meta( '_kt_tracking_number' );
		wp_nonce_field( 'kt_trk_save', 'kt_trk_nonce' );
		echo '<p style="margin:0 0 6px"><label for="kt_trk_carrier"><strong>Versanddienstleister</strong></label><br><select name="kt_trk_carrier" id="kt_trk_carrier" style="width:100%"><option value="">&ndash; keiner &ndash;</option>';
		foreach ( kt_trk_carriers() as $k => $v ) {
			echo '<option value="' . esc_attr( $k ) . '"' . selected( $cur, $k, false ) . '>' . esc_html( $v[0] ) . '</option>';
		}
		echo '</select></p><p style="margin:0 0 6px"><label for="kt_trk_number"><strong>Sendungsnummer</strong></label><br>'
			. '<input type="text" name="kt_trk_number" id="kt_trk_number" value="' . esc_attr( $num ) . '" style="width:100%"></p>'
			. '<p class="description" style="margin:0">Erscheint in der Kundenmail &bdquo;Bestellung abgeschlossen&ldquo;. Nummer eintragen, Status auf &bdquo;Abgeschlossen&ldquo; setzen und dann <em>Aktualisieren</em> klicken. Bei PayPal-Bestellungen f&uuml;llt der PayPal-Kasten dieses Feld automatisch.</p>';
	}, $screen, 'side', 'high' );
} );

// Speichern - vor WooCommerce (Prio 40), damit die Nummer schon in der "abgeschlossen"-Mail steht
add_action( 'woocommerce_process_shop_order_meta', function ( $order_id ) {
	if ( ! isset( $_POST['kt_trk_nonce'] ) || ! wp_verify_nonce( sanitize_text_field( wp_unslash( $_POST['kt_trk_nonce'] ) ), 'kt_trk_save' ) || ! current_user_can( 'manage_woocommerce' ) ) {
		return;
	}
	$order = wc_get_order( $order_id );
	if ( ! $order ) {
		return;
	}
	$c   = isset( $_POST['kt_trk_carrier'] ) ? sanitize_key( wp_unslash( $_POST['kt_trk_carrier'] ) ) : '';
	$n   = isset( $_POST['kt_trk_number'] ) ? preg_replace( '/[^A-Za-z0-9\-]/', '', wp_unslash( $_POST['kt_trk_number'] ) ) : '';
	$all = kt_trk_carriers();
	$order->update_meta_data( '_kt_tracking_carrier', isset( $all[ $c ] ) ? $c : '' );
	$order->update_meta_data( '_kt_tracking_number', $n );
	$order->save_meta_data();
}, 20 );

// PayPal-Kasten -> Feld automatisch fuellen
add_action( 'woocommerce_paypal_payments_before_tracking_is_added', function ( $order_id, $data ) {
	$order = wc_get_order( $order_id );
	if ( ! $order || ! is_array( $data ) ) {
		return;
	}
	$n   = isset( $data['tracking_number'] ) ? preg_replace( '/[^A-Za-z0-9\-]/', '', (string) $data['tracking_number'] ) : '';
	$car = isset( $data['carrier'] ) ? (string) $data['carrier'] : '';
	$key = in_array( $car, array( 'DE_DHL', 'DHL' ), true ) ? 'dhl' : ( 'GLS' === $car ? 'gls' : '' );
	if ( $n && $key ) {
		$order->update_meta_data( '_kt_tracking_carrier', $key );
		$order->update_meta_data( '_kt_tracking_number', $n );
		$order->save_meta_data();
	}
}, 10, 2 );

// Kundenmail "Bestellung abgeschlossen": Block vor der Bestelltabelle
add_action( 'woocommerce_email_before_order_table', function ( $order, $sent_to_admin, $plain_text, $email ) {
	if ( $sent_to_admin || ! $email || 'customer_completed_order' !== $email->id ) {
		return;
	}
	echo kt_trk_block( $order, (bool) $plain_text ); // phpcs:ignore WordPress.Security.EscapeOutput
}, 5, 4 );

// Mein Konto > Bestellung ansehen
add_action( 'woocommerce_order_details_before_order_table', function ( $order ) {
	if ( is_a( $order, 'WC_Order' ) && is_account_page() ) {
		echo kt_trk_block( $order, false ); // phpcs:ignore WordPress.Security.EscapeOutput
	}
}, 5 );
