/* TEMP: Vorkasse-Bankverbindung einmalig setzen (Angaben vom Betreiber). Danach loeschen. */
add_action( 'init', function () {
	if ( '1' === get_option( 'kt_bacs_set' ) ) {
		return;
	}
	update_option(
		'woocommerce_bacs_accounts',
		array(
			array(
				'account_name'   => 'Joachim Blöchle Elektro-Service GmbH',
				'account_number' => '',
				'sort_code'      => '',
				'bank_name'      => 'Taunus Sparkasse',
				'iban'           => 'DE23 5125 0000 0002 2404 24',
				'bic'            => 'HELADEF1TSK',
			),
		)
	);
	update_option( 'kt_bacs_set', '1', false );
}, 20 );
