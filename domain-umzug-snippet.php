/* kaffeetechniker.de - DOMAIN-UMZUG (Suchen/Ersetzen in der Datenbank, serialisierte Daten sicher). NUR am Livetag nach Rueckfrage ausfuehren!
 * Nur fuer Administratoren. Standardmaessig Probelauf (zaehlt nur). Ausfuehren nur mit  execute=true  UND  confirm="JA-UMZIEHEN".
 *   Probelauf:  GET  /wp-json/kt/v1/domainmove?from=new.kaffeetechniker.de&to=www.kaffeetechniker.de
 *   Ausfuehren: POST /wp-json/kt/v1/domainmove  {"from":"...","to":"...","execute":true,"confirm":"JA-UMZIEHEN","finish":true}
 *   Rueckgaengig: dieselbe Ausfuehrung mit vertauschtem from/to.
 * "finish": setzt siteurl/home auf https://<to>, blog_public=1 (Suchmaschinen erlaubt), leert Caches, schreibt die Regeln neu.
 * Ersetzt nur den Host (Schema bleibt https) -> auch in JSON mit maskierten Schraegstrichen (https:\/\/host\/...) korrekt.
 * Tabellen: posts (content, excerpt, content_filtered - NICHT guid, KEINE Revisionen/Auto-Entwuerfe), postmeta, options, termmeta, term_taxonomy.description, snippets (Code Snippets),
 * fluentform_forms/-form_meta, wc_webhooks. Vor dem Ausfuehren: Vollbackup bei IONOS.
 * Einbau: Code Snippets (Deploy: scratchpad/domain-umzug.ps1). Nach dem Umzug Snippet wieder deaktivieren/loeschen. */

if ( ! function_exists( 'kt_dm_replace' ) ) {

	function kt_dm_replace( $value, $from, $to ) {
		if ( is_string( $value ) ) {
			if ( is_serialized( $value ) ) {
				$u = @unserialize( $value, array( 'allowed_classes' => false ) ); // phpcs:ignore WordPress.PHP.DiscouragedPHPFunctions
				if ( false !== $u || 'b:0;' === $value ) {
					return serialize( kt_dm_replace( $u, $from, $to ) ); // phpcs:ignore WordPress.PHP.DiscouragedPHPFunctions
				}
			}
			return str_replace( $from, $to, $value );
		}
		if ( is_array( $value ) ) {
			$out = array();
			foreach ( $value as $k => $v ) {
				$out[ is_string( $k ) ? str_replace( $from, $to, $k ) : $k ] = kt_dm_replace( $v, $from, $to );
			}
			return $out;
		}
		if ( is_object( $value ) ) {
			foreach ( get_object_vars( $value ) as $k => $v ) {
				$value->$k = kt_dm_replace( $v, $from, $to );
			}
			return $value;
		}
		return $value;
	}

	function kt_dm_targets() {
		global $wpdb;
		$p = $wpdb->prefix;
		$t = array(
			array( $wpdb->posts, 'ID', array( 'post_content', 'post_excerpt', 'post_content_filtered' ) ),
			array( $wpdb->postmeta, 'meta_id', array( 'meta_value' ) ),
			array( $wpdb->options, 'option_id', array( 'option_value' ) ),
			array( $wpdb->termmeta, 'meta_id', array( 'meta_value' ) ),
			array( $wpdb->term_taxonomy, 'term_taxonomy_id', array( 'description' ) ),
			array( $p . 'snippets', 'id', array( 'code', 'description' ) ),
			array( $p . 'fluentform_forms', 'id', array( 'form_fields', 'settings' ) ),
			array( $p . 'fluentform_form_meta', 'id', array( 'value' ) ),
			array( $p . 'wc_webhooks', 'webhook_id', array( 'delivery_url' ) ),
		);
		$out = array();
		foreach ( $t as $row ) {
			if ( $wpdb->get_var( $wpdb->prepare( 'SHOW TABLES LIKE %s', $row[0] ) ) === $row[0] ) { // phpcs:ignore
				$out[] = $row;
			}
		}
		return $out;
	}

	function kt_dm_run( $from, $to, $execute ) {
		global $wpdb;
		$report = array();
		foreach ( kt_dm_targets() as $tg ) {
			list( $table, $pk, $cols ) = $tg;
			$labelcol = array( $wpdb->options => 'option_name', $wpdb->postmeta => 'meta_key', $wpdb->termmeta => 'meta_key', $wpdb->prefix . 'snippets' => 'name', $wpdb->prefix . 'fluentform_form_meta' => 'meta_key', $wpdb->prefix . 'wc_webhooks' => 'name' );
			$label    = isset( $labelcol[ $table ] ) ? $labelcol[ $table ] : '';
			// Revisionen/Auto-Entwuerfe werden nicht umgeschrieben (Historie, aufgeblaehte Datenmengen)
			$extra = ( $table === $wpdb->posts ) ? " AND post_type NOT IN ('revision','auto-draft')" : '';
			foreach ( $cols as $col ) {
				$like = '%' . $wpdb->esc_like( $from ) . '%';
				$last = 0;
				$rowsN = 0;
				$occ   = 0;
				$chg   = 0;
				$types = array();
				do {
					$rows = $wpdb->get_results( $wpdb->prepare( "SELECT `$pk` AS id, `$col` AS val" . ( $table === $wpdb->posts ? ', post_type AS pt' : '' ) . ( $label ? ", `$label` AS lbl" : '' ) . " FROM `$table` WHERE `$pk` > %d AND `$col` LIKE %s$extra ORDER BY `$pk` ASC LIMIT 100", $last, $like ), ARRAY_A ); // phpcs:ignore
					foreach ( $rows as $r ) {
						$last   = (int) $r['id'];
						$rowsN++;
						$c      = substr_count( (string) $r['val'], $from );
						$occ   += $c;
						if ( isset( $r['lbl'] ) && count( $types ) < 40 ) {
							$types[ $r['lbl'] ] = $c;
						}
						if ( isset( $r['pt'] ) ) {
							$types[ $r['pt'] ] = ( isset( $types[ $r['pt'] ] ) ? $types[ $r['pt'] ] : 0 ) + $c;
						}
						if ( $execute ) {
							$new = kt_dm_replace( $r['val'], $from, $to );
							if ( $new !== $r['val'] ) {
								$wpdb->update( $table, array( $col => $new ), array( $pk => $r['id'] ) ); // phpcs:ignore
								$chg++;
							}
						}
					}
				} while ( count( $rows ) === 100 );
				if ( $rowsN ) {
					$item = array( 'table' => $table, 'column' => $col, 'rows' => $rowsN, 'occurrences' => $occ, 'changed' => $execute ? $chg : null );
					if ( $types ) {
						arsort( $types );
						$item['nach_typ'] = $types;
					}
					$report[] = $item;
				}
			}
		}
		return $report;
	}
}

add_action( 'rest_api_init', function () {
	register_rest_route( 'kt/v1', '/domainmove', array(
		'methods'             => array( 'GET', 'POST' ),
		'permission_callback' => function () {
			return current_user_can( 'manage_options' );
		},
		'callback'            => function ( $req ) {
			$from = strtolower( trim( (string) $req['from'] ) );
			$to   = strtolower( trim( (string) $req['to'] ) );
			if ( ! preg_match( '/^[a-z0-9.\-]+\.[a-z]{2,}$/', $from ) || ! preg_match( '/^[a-z0-9.\-]+\.[a-z]{2,}$/', $to ) || $from === $to ) {
				return new WP_Error( 'kt_dm_bad', 'from/to ungueltig oder gleich.', array( 'status' => 400 ) );
			}
			$execute = ( 'POST' === $req->get_method() ) && true === filter_var( $req['execute'], FILTER_VALIDATE_BOOLEAN ) && 'JA-UMZIEHEN' === $req['confirm'];
			$out     = array(
				'modus'   => $execute ? 'AUSFUEHRUNG' : 'PROBELAUF (nichts wurde geaendert)',
				'from'    => $from,
				'to'      => $to,
				'aktuell' => array( 'siteurl' => get_option( 'siteurl' ), 'home' => get_option( 'home' ), 'blog_public' => get_option( 'blog_public' ) ),
			);
			@set_time_limit( 300 ); // phpcs:ignore
			$out['bericht'] = kt_dm_run( $from, $to, $execute );
			$out['summe']   = array(
				'zeilen'     => array_sum( wp_list_pluck( $out['bericht'], 'rows' ) ),
				'vorkommen'  => array_sum( wp_list_pluck( $out['bericht'], 'occurrences' ) ),
				'geaendert'  => $execute ? array_sum( array_map( 'intval', wp_list_pluck( $out['bericht'], 'changed' ) ) ) : null,
			);
			if ( $execute && true === filter_var( $req['finish'], FILTER_VALIDATE_BOOLEAN ) ) {
				update_option( 'siteurl', 'https://' . $to );
				update_option( 'home', 'https://' . $to );
				update_option( 'blog_public', 1 );
				wp_cache_flush();
				flush_rewrite_rules( false );
				$out['abschluss'] = 'siteurl/home = https://' . $to . ', blog_public = 1, Caches geleert, Regeln neu geschrieben';
			}
			return $out;
		},
	) );
} );
