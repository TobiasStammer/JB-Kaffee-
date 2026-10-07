/* kaffeetechniker.de - Knopf "Bestelluebersicht drucken" in WooCommerce (Bestellung + Bestellliste).
 * Oeffnet eine druckfertige Uebersicht (Positionen, MwSt, Versand, PayPal-/Karten-Gebuehren) und startet den Druckdialog.
 * Gleiche Darstellung wie das PDF aus bestellung-uebersicht.ps1. Nur mit Recht manage_woocommerce.
 * Einbau: Code Snippets, PHP, "Ueberall ausfuehren" (Deploy: scratchpad/bestelluebersicht-button.ps1). */

if ( ! function_exists( 'kt_ov_eur' ) ) {

	function kt_ov_eur( $v ) {
		return number_format( (float) $v, 2, ',', '.' ) . '&nbsp;&euro;';
	}

	function kt_ov_dt( $d ) {
		return $d ? esc_html( $d->date_i18n( 'd.m.Y H:i' ) ) . ' Uhr' : '-';
	}

	function kt_ov_pp( $fees, $k ) {
		$v = null;
		if ( is_array( $fees ) && isset( $fees[ $k ] ) ) {
			$v = $fees[ $k ];
		} elseif ( is_object( $fees ) && isset( $fees->$k ) ) {
			$v = $fees->$k;
		}
		if ( is_array( $v ) ) {
			return isset( $v['value'] ) ? (float) $v['value'] : 0.0;
		}
		if ( is_object( $v ) ) {
			return isset( $v->value ) ? (float) $v->value : 0.0;
		}
		return 0.0;
	}

	function kt_ov_row( $name, $sku, $qty, $net, $tax ) {
		$rate = $net > 0 ? round( $tax / $net * 100 ) : 0;
		$skuh = $sku ? '<div class="sku">Art.-Nr.: ' . esc_html( $sku ) . '</div>' : '';
		return array(
			'rate' => $rate,
			'html' => '<tr><td>' . $name . $skuh . '</td><td class="r">' . (int) $qty . '</td><td class="r">' . kt_ov_eur( $net / max( 1, (int) $qty ) ) . '</td><td class="r">' . kt_ov_eur( $net ) . '</td><td class="r">' . $rate . '&nbsp;%</td><td class="r">' . kt_ov_eur( $tax ) . '</td><td class="r">' . kt_ov_eur( $net + $tax ) . '</td></tr>',
		);
	}

	function kt_ov_html( $order ) {
		$rows   = array();
		$groups = array();
		$sumnet = 0.0;
		$add    = function ( $r, $net, $tax ) use ( &$rows, &$groups, &$sumnet ) {
			$rows[]  = $r['html'];
			$sumnet += $net;
			$k       = (string) $r['rate'];
			if ( ! isset( $groups[ $k ] ) ) {
				$groups[ $k ] = array( 0.0, 0.0 );
			}
			$groups[ $k ][0] += $net;
			$groups[ $k ][1] += $tax;
		};
		foreach ( $order->get_items() as $it ) {
			$p   = $it->get_product();
			$net = (float) $it->get_total();
			$tax = (float) $it->get_total_tax();
			$add( kt_ov_row( esc_html( $it->get_name() ), $p ? $p->get_sku() : '', $it->get_quantity(), $net, $tax ), $net, $tax );
		}
		foreach ( $order->get_items( 'shipping' ) as $it ) {
			$net = (float) $it->get_total();
			$tax = (float) $it->get_total_tax();
			$add( kt_ov_row( 'Versand: ' . esc_html( $it->get_method_title() ), '', 1, $net, $tax ), $net, $tax );
		}
		foreach ( $order->get_items( 'fee' ) as $it ) {
			$net = (float) $it->get_total();
			$tax = (float) $it->get_total_tax();
			$add( kt_ov_row( 'Geb&uuml;hr: ' . esc_html( $it->get_name() ), '', 1, $net, $tax ), $net, $tax );
		}
		ksort( $groups, SORT_NUMERIC );
		$taxrows = '';
		foreach ( $groups as $rate => $g ) {
			$taxrows .= '<tr><td>MwSt. ' . $rate . '&nbsp;% auf ' . kt_ov_eur( $g[0] ) . '</td><td class="r">' . kt_ov_eur( $g[1] ) . '</td></tr>';
		}
		$disc    = (float) $order->get_discount_total();
		$discrow = $disc > 0 ? '<tr><td>Rabatt / Gutschein (netto, in den Zeilen abgezogen)</td><td class="r">-' . kt_ov_eur( $disc ) . '</td></tr>' : '';

		$pay = '<tr><th>Zahlungsart</th><td>' . esc_html( $order->get_payment_method_title() ) . '</td></tr>';
		if ( $order->get_transaction_id() ) {
			$pay .= '<tr><th>Transaktions-ID</th><td>' . esc_html( $order->get_transaction_id() ) . '</td></tr>';
		}
		if ( $order->get_meta( '_ppcp_paypal_order_id' ) ) {
			$pay .= '<tr><th>PayPal-Bestell-ID</th><td>' . esc_html( $order->get_meta( '_ppcp_paypal_order_id' ) ) . '</td></tr>';
		}
		if ( $order->get_meta( '_ppcp_paypal_payer_email' ) ) {
			$pay .= '<tr><th>PayPal-Konto Kunde</th><td>' . esc_html( $order->get_meta( '_ppcp_paypal_payer_email' ) ) . '</td></tr>';
		}

		$feeblock = '';
		$fees     = $order->get_meta( '_ppcp_paypal_fees' );
		if ( $fees && kt_ov_pp( $fees, 'paypal_fee' ) > 0 ) {
			$gross = kt_ov_pp( $fees, 'gross_amount' );
			$fee   = kt_ov_pp( $fees, 'paypal_fee' );
			$netin = kt_ov_pp( $fees, 'net_amount' );
			$quote = $gross > 0 ? number_format( $fee / $gross * 100, 2, ',', '.' ) . '&nbsp;%' : '-';
			$feeblock = '<h2>Zahlungsabwicklung (PayPal)</h2><table class="sum"><tr><td>Zahlungseingang brutto (Kundenzahlung)</td><td class="r">' . kt_ov_eur( $gross ) . '</td></tr>'
				. '<tr><td>PayPal-Geb&uuml;hr (' . $quote . ' vom Bruttobetrag)</td><td class="r">-' . kt_ov_eur( $fee ) . '</td></tr>'
				. '<tr class="tot"><td>Nettoeingang auf dem PayPal-Konto</td><td class="r">' . kt_ov_eur( $netin ) . '</td></tr></table>'
				. '<p class="note">Die Geb&uuml;hr wird von PayPal einbehalten und ist nicht Teil der Kundenrechnung. Angaben laut PayPal-Daten der Bestellung; ma&szlig;geblich ist die PayPal-Abrechnung.</p>';
		} elseif ( 0 === strpos( (string) $order->get_payment_method(), 'ppcp' ) ) {
			$feeblock = '<h2>Zahlungsabwicklung (PayPal)</h2><p class="note">Zu dieser Bestellung liegen keine PayPal-Geb&uuml;hrendaten vor.</p>';
		} elseif ( 'woocommerce_payments' === $order->get_payment_method() ) {
			// WooPayments (Karte, Apple/Google Pay): Gebuehr + Netto in den Bestell-Metadaten
			$wfee = $order->get_meta( '_wcpay_transaction_fee' );
			if ( '' !== (string) $wfee ) {
				$fee   = (float) $wfee;
				$gross = (float) $order->get_total();
				$wnet  = $order->get_meta( '_wcpay_net' );
				$netin = '' !== (string) $wnet ? (float) $wnet : $gross - $fee;
				$quote = $gross > 0 ? number_format( $fee / $gross * 100, 2, ',', '.' ) . '&nbsp;%' : '-';
				$brand = '';
				$pmd   = $order->get_meta( '_wcpay_payment_method_details' );
				if ( is_string( $pmd ) ) {
					$pmd = json_decode( $pmd, true );
				}
				if ( is_array( $pmd ) && ! empty( $pmd['card']['brand'] ) ) {
					$brand = ' (' . esc_html( ucfirst( $pmd['card']['brand'] ) ) . ')';
				}
				$feeblock = '<h2>Zahlungsabwicklung (Kartenzahlung' . $brand . ')</h2><table class="sum"><tr><td>Zahlungseingang brutto (Kundenzahlung)</td><td class="r">' . kt_ov_eur( $gross ) . '</td></tr>'
					. '<tr><td>Kartengeb&uuml;hr WooPayments (' . $quote . ' vom Bruttobetrag)</td><td class="r">-' . kt_ov_eur( $fee ) . '</td></tr>'
					. '<tr class="tot"><td>Nettoeingang (Auszahlungsbetrag)</td><td class="r">' . kt_ov_eur( $netin ) . '</td></tr></table>'
					. '<p class="note">Die Geb&uuml;hr wird von WooPayments/Stripe einbehalten und ist nicht Teil der Kundenrechnung. Angaben laut Bestelldaten; ma&szlig;geblich ist die WooPayments-Abrechnung.</p>';
			} else {
				$feeblock = '<h2>Zahlungsabwicklung (Kartenzahlung)</h2><p class="note">Zu dieser Bestellung liegen keine Geb&uuml;hrendaten vor.</p>';
			}
		}
		$note = $order->get_customer_note() ? '<h2>Kundenhinweis</h2><p>' . esc_html( $order->get_customer_note() ) . '</p>' : '';
		$nr   = esc_html( $order->get_order_number() );

		$css = '@page{size:A4;margin:16mm}*{box-sizing:border-box}body{font-family:"Segoe UI",Arial,sans-serif;color:#1c1c1c;font-size:10pt;line-height:1.45;margin:0;padding:18px}'
			. '.bar{max-width:820px;margin:0 auto 14px;display:flex;gap:10px;justify-content:flex-end}.bar button{font:inherit;padding:8px 16px;border:1px solid #334155;background:#334155;color:#fff;border-radius:5px;cursor:pointer}.bar button.sec{background:#fff;color:#334155}'
			. '.doc{max-width:820px;margin:0 auto}.head{display:flex;justify-content:space-between;align-items:flex-start;border-bottom:2px solid #334155;padding-bottom:10px;margin-bottom:16px}'
			. 'h1{font-size:19pt;margin:0 0 2px;color:#1e293b}.sub{color:#555}.firm{text-align:right;font-size:9pt;color:#444;line-height:1.4}.firm b{color:#1c1c1c;font-size:10pt}'
			. 'h2{font-size:11pt;margin:18px 0 6px;padding-bottom:3px;border-bottom:1px solid #ccc;color:#1e293b}table{border-collapse:collapse;width:100%}'
			. '.info th{text-align:left;width:34%;font-weight:600;color:#444;padding:3px 8px 3px 0;vertical-align:top}.info td{padding:3px 0}.cols{display:flex;gap:24px}.cols>div{flex:1}'
			. '.pos th{background:#eef1f5;text-align:left;font-size:9pt;padding:6px 7px;border-bottom:1px solid #b9c1cc}.pos td{padding:7px;border-bottom:1px solid #e3e6ea;vertical-align:top}'
			. '.pos th.r,.pos td.r,.sum td.r{text-align:right;white-space:nowrap}.sku{color:#666;font-size:8.5pt}.sum{width:62%;margin-left:auto;margin-top:8px}.sum td{padding:4px 7px;border-bottom:1px solid #eee}'
			. '.sum tr.tot td{font-weight:700;border-top:2px solid #334155;border-bottom:0;font-size:11pt}.note{font-size:8.5pt;color:#555;margin:4px 0 0}'
			. '.foot{margin-top:22px;padding-top:8px;border-top:1px solid #ccc;font-size:8pt;color:#666}@media print{.bar{display:none}body{padding:0}}';

		return '<!DOCTYPE html><html lang="de"><head><meta charset="utf-8"><meta name="robots" content="noindex"><title>Bestell&uuml;bersicht ' . $nr . '</title><style>' . $css . '</style></head><body>'
			. '<div class="bar"><button type="button" onclick="window.print()">Drucken / als PDF speichern</button><button type="button" class="sec" onclick="window.close()">Schlie&szlig;en</button></div><div class="doc">'
			. '<div class="head"><div><h1>Bestell&uuml;bersicht</h1><div class="sub">Bestellung Nr. ' . $nr . ' &middot; ' . kt_ov_dt( $order->get_date_created() ) . '</div></div>'
			. '<div class="firm"><b>Joachim Bl&ouml;chle Elektro-Service GmbH</b><br>JB Kaffeemaschinen &ndash; Service &amp; Verkauf<br>Wallauer Str. 4, 65719 Hofheim-Langenhain<br>shop@kaffeetechniker.de</div></div>'
			. '<h2>Bestelldaten</h2><table class="info"><tr><th>Bestellnummer</th><td>' . $nr . '</td></tr><tr><th>Bestelldatum</th><td>' . kt_ov_dt( $order->get_date_created() ) . '</td></tr>'
			. '<tr><th>Bezahlt am</th><td>' . kt_ov_dt( $order->get_date_paid() ) . '</td></tr><tr><th>Status</th><td>' . esc_html( wc_get_order_status_name( $order->get_status() ) ) . '</td></tr>' . $pay . '</table>'
			. '<div class="cols"><div><h2>Rechnungsadresse</h2>' . wp_kses_post( $order->get_formatted_billing_address( '-' ) ) . '<br>' . esc_html( $order->get_billing_email() ) . '</div>'
			. '<div><h2>Lieferadresse</h2>' . wp_kses_post( $order->get_formatted_shipping_address( '-' ) ) . '</div></div>'
			. '<h2>Positionen</h2><table class="pos"><tr><th>Artikel</th><th class="r">Menge</th><th class="r">Einzel netto</th><th class="r">Netto</th><th class="r">MwSt.-Satz</th><th class="r">MwSt.</th><th class="r">Brutto</th></tr>' . implode( '', $rows ) . '</table>'
			. '<table class="sum"><tr><td>Summe netto</td><td class="r">' . kt_ov_eur( $sumnet ) . '</td></tr>' . $discrow . $taxrows . '<tr class="tot"><td>Gesamtbetrag brutto</td><td class="r">' . kt_ov_eur( $order->get_total() ) . '</td></tr></table>'
			. $feeblock . $note
			. '<div class="foot">Diese &Uuml;bersicht wurde am ' . esc_html( wp_date( 'd.m.Y H:i' ) ) . ' Uhr aus den Bestelldaten des Shops erzeugt und ersetzt keine Rechnung. Betr&auml;ge in Euro.</div></div>'
			. '<script>window.addEventListener("load",function(){setTimeout(function(){window.print()},350)})</script></body></html>';
	}

	function kt_ov_url( $order_id ) {
		return add_query_arg(
			array(
				'action'   => 'kt_order_overview',
				'order_id' => (int) $order_id,
				'_wpnonce' => wp_create_nonce( 'kt_ov_' . (int) $order_id ),
			),
			admin_url( 'admin-post.php' )
		);
	}
}

// Ausgabe der Uebersicht (Admin, mit Nonce + Recht)
add_action( 'admin_post_kt_order_overview', function () {
	$id = isset( $_GET['order_id'] ) ? (int) $_GET['order_id'] : 0;
	if ( ! $id || ! current_user_can( 'manage_woocommerce' ) || ! wp_verify_nonce( isset( $_GET['_wpnonce'] ) ? $_GET['_wpnonce'] : '', 'kt_ov_' . $id ) ) {
		wp_die( 'Keine Berechtigung.', '', array( 'response' => 403 ) );
	}
	$order = wc_get_order( $id );
	if ( ! $order ) {
		wp_die( 'Bestellung nicht gefunden.', '', array( 'response' => 404 ) );
	}
	nocache_headers();
	header( 'Content-Type: text/html; charset=utf-8' );
	echo kt_ov_html( $order ); // phpcs:ignore WordPress.Security.EscapeOutput
	exit;
} );

// Knopf im Kasten "Bestellung" (Seitenleiste der Bestell-Bearbeitung)
add_action( 'add_meta_boxes', function () {
	$screen = function_exists( 'wc_get_page_screen_id' ) ? wc_get_page_screen_id( 'shop-order' ) : 'shop_order';
	add_meta_box( 'kt_order_overview', 'Bestell&uuml;bersicht', function ( $post_or_order ) {
		$order = ( $post_or_order instanceof WP_Post ) ? wc_get_order( $post_or_order->ID ) : $post_or_order;
		if ( ! $order ) {
			return;
		}
		echo '<p style="margin:0 0 8px">Preise, MwSt., Versand und PayPal-Geb&uuml;hren &ndash; druckfertig f&uuml;r den Steuerberater.</p>'
			. '<a class="button button-primary" target="_blank" rel="noopener" href="' . esc_url( kt_ov_url( $order->get_id() ) ) . '">Bestell&uuml;bersicht drucken</a>';
	}, $screen, 'side', 'high' );
} );

// Druck-Symbol in der Bestellliste (Spalte "Aktionen")
add_filter( 'woocommerce_admin_order_actions', function ( $actions, $order ) {
	$actions['kt_overview'] = array(
		'url'    => kt_ov_url( $order->get_id() ),
		'name'   => 'Bestell&uuml;bersicht drucken',
		'action' => 'kt_overview',
	);
	return $actions;
}, 20, 2 );
add_action( 'admin_head', function () {
	echo '<style>a.button.wc-action-button-kt_overview::after{font-family:Dashicons!important;content:"\f193"!important}</style>';
} );
