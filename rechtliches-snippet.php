<?php
/* kaffeetechniker.de - Rechtliche Ergaenzungen
 * 1) Widerrufsbelehrung und AGB als Text in den Bestellbestaetigungen an Kunden (§ 312f BGB).
 * 2) PayPal-/Stripe-Skripte nur in Warenkorb, Kasse und Kundenkonto laden (§ 25 TDDDG).
 * 3) Datenschutz-Hinweis unter den Formularen (Fluent Forms).
 * Einbau: Code Snippets, PHP, "Ueberall ausfuehren". */

if ( ! function_exists( 'kt_re_legal_html' ) ) {

	// Inhaltsteil einer Rechtsseite (ohne Navigation, Icons, Styles). IDs: 124 Widerruf, 123 AGB.
	function kt_re_legal_html( $page_id ) {
		$c = (string) get_post_field( 'post_content', $page_id );
		$a = strpos( $c, '<div class="kt-main">' );
		if ( false === $a ) {
			return '';
		}
		$b = strpos( $c, '<!-- /wp:html -->', $a );
		$c = substr( $c, $a, false === $b ? null : $b - $a );
		$c = preg_replace( '#<(svg|style|script)\b.*?</\1>#is', '', $c );
		return wp_kses( $c, array( 'h1' => array(), 'h2' => array(), 'h3' => array(), 'p' => array(), 'br' => array(), 'ul' => array(), 'ol' => array(), 'li' => array(), 'strong' => array(), 'a' => array( 'href' => array() ) ) );
	}

	add_action( 'woocommerce_email_after_order_table', function ( $order, $sent_to_admin, $plain_text, $email ) {
		if ( $sent_to_admin || ! is_object( $email ) || ! in_array( $email->id, array( 'customer_processing_order', 'customer_on_hold_order' ), true ) ) {
			return;
		}
		$html = kt_re_legal_html( 124 ) . kt_re_legal_html( 123 );
		if ( $plain_text ) {
			$text = preg_replace( '#</(h1|h2|h3|p|li)>|<br\s*/?>#i', "\n", $html );
			echo "\n----------\n" . esc_html( html_entity_decode( wp_strip_all_tags( $text ), ENT_QUOTES, 'UTF-8' ) ) . "\n"; // phpcs:ignore
			return;
		}
		echo '<div style="margin-top:28px;border-top:1px solid #ddd;font-size:12px;line-height:1.5">' . $html . '</div>'; // phpcs:ignore WordPress.Security.EscapeOutput
	}, 99, 4 );

	function kt_re_pay_page() {
		return ! function_exists( 'is_cart' ) || is_cart() || is_checkout() || is_account_page();
	}

	// Skripte der Zahlungsanbieter und ihrer Plugins ausserhalb von Warenkorb/Kasse/Konto nicht ausgeben.
	add_filter( 'script_loader_tag', function ( $tag, $handle, $src ) {
		if ( is_admin() || kt_re_pay_page() ) {
			return $tag;
		}
		if ( preg_match( '#js\.stripe\.com|paypal\.com|plugins/woocommerce-paypal-payments/|plugins/woocommerce-payments/#i', (string) $src ) ) {
			return '';
		}
		return $tag;
	}, 99, 3 );

	add_filter( 'do_shortcode_tag', function ( $out, $tag ) {
		if ( 'fluentform' !== $tag ) {
			return $out;
		}
		return $out . '<p style="font-size:13px;color:#555">Ihre Angaben verarbeiten wir wie in der <a href="' . esc_url( home_url( '/datenschutz/' ) ) . '">Datenschutzerklärung</a> beschrieben.</p>';
	}, 10, 2 );
}
