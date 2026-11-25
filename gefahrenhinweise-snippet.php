<?php
/* kaffeetechniker.de - Gefahrenhinweise (CLP Art. 48) auf Produktseiten der JURA-Pflegeprodukte.
 * Quelle: Sicherheitsdatenblaetter und Produktseiten auf de.jura.com, abgerufen am 25.11.2026
 * (Reinigungstabletten V4 15.08.2025, Entkalkung V4 13.08.2025, Milchsystem-Reiniger V4 18.08.2025).
 * Bei neuer Rezeptur/Etikett hier anpassen. NIVONA fehlt: Hersteller veroeffentlicht keine Einstufung.
 * Einbau: Code Snippets, PHP, "Ueberall ausfuehren". */

if ( ! function_exists( 'kt_ghs_data' ) ) {

	function kt_ghs_data( $product_id ) {
		$base = 'https://de.jura.com/-/media/global/pdf/sicherheitsdatenblatt/';
		$r    = array(
			'name' => 'JURA 3-Phasen-Reinigungstabletten',
			'h'    => array( 'H315 Verursacht Hautreizungen.', 'H319 Verursacht schwere Augenreizung.' ),
			'x'    => '',
			'sdb'  => $base . 'UFI-FS02-50AC-N00V-DGP7_V5/cleaning/SDB-Reinigungstabs-UFI-FS02-50AC-N00V-DGP7.pdf',
		);
		$e    = array(
			'name' => 'JURA 2-Phasen-Entkalkungstabletten',
			'h'    => array( 'H302 Gesundheitsschädlich bei Verschlucken.', 'H315 Verursacht Hautreizungen.', 'H317 Kann allergische Hautreaktionen verursachen.', 'H319 Verursacht schwere Augenreizung.', 'H335 Kann die Atemwege reizen.', 'H412 Schädlich für Wasserorganismen, mit langfristiger Wirkung.' ),
			'x'    => 'Enthält: Maleinsäure.',
			'sdb'  => $base . 'SDB-JURA-Descaling_V4/SDB_JURA-Descaling_V4.pdf',
		);
		$m    = array(
			'name' => 'JURA Milchsystem-Reiniger (Mini-Tabs)',
			'h'    => array( 'H319 Verursacht schwere Augenreizung.', 'H335 Kann die Atemwege reizen.' ),
			'x'    => 'Enthält: Citronensäure.',
			'sdb'  => $base . 'SDB-JURA-milksystemcleaner_V4/SDB_Milchsystem-Reiniger_Minitabs_V4.pdf',
		);
		$map  = array(
			621 => array( $r ),
			623 => array( $e ),
			625 => array( $m ),
			629 => array( $r, $m ), // Care Kit
			627 => array( $r ),     // Care Kit Basic
		);
		return $map[ $product_id ] ?? array();
	}

	add_action( 'woocommerce_single_product_summary', function () {
		$parts = kt_ghs_data( get_the_ID() );
		if ( ! $parts ) {
			return;
		}
		$icon = '<svg width="44" height="44" viewBox="0 0 44 44" role="img" aria-label="Gefahrenpiktogramm GHS07 Ausrufezeichen" style="flex:none"><path d="M22 2 42 22 22 42 2 22Z" fill="#fff" stroke="#d40000" stroke-width="3"/><path d="M19.5 12h5l-1.2 14h-2.6z"/><circle cx="22" cy="31" r="2.6"/></svg>';
		echo '<div class="kt-ghs" style="clear:both;border:1px solid #d5dae1;border-radius:4px;padding:12px;margin:14px 0;font-size:13px;line-height:1.5">';
		foreach ( $parts as $p ) {
			echo '<div style="display:flex;gap:12px;margin:4px 0">' . $icon . '<div><strong>Achtung</strong> – ' . esc_html( $p['name'] ) . '<br>' // phpcs:ignore WordPress.Security.EscapeOutput
				. implode( '<br>', array_map( 'esc_html', $p['h'] ) )
				. ( $p['x'] ? '<br>' . esc_html( $p['x'] ) : '' )
				. '<br><a href="' . esc_url( $p['sdb'] ) . '" target="_blank" rel="noopener">Sicherheitsdatenblatt (JURA)</a></div></div>';
		}
		echo '<div>Darf nicht in die Hände von Kindern gelangen.</div></div>';
	}, 45 );
}
