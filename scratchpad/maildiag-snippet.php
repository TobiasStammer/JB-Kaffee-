/* TEMP: Mail-Diagnose. Nur fuer Administratoren. Nach der Fehlersuche wieder deaktivieren/loeschen. */
add_action( 'rest_api_init', function () {
	register_rest_route( 'kt/v1', '/maildiag', array(
		'methods'             => 'GET,POST',
		'permission_callback' => function () {
			return current_user_can( 'manage_options' );
		},
		'callback'            => function ( $req ) {
			global $wpdb;
			$out = array();
			$t   = $wpdb->prefix . 'fsmpt_email_logs';
			$out['tables'] = $wpdb->get_col( "SHOW TABLES LIKE '%fsmpt%'" );
			if ( $wpdb->get_var( "SHOW TABLES LIKE '" . esc_sql( $t ) . "'" ) === $t ) {
				$out['log'] = $wpdb->get_results( "SELECT id, `to`, subject, status, created_at, LEFT(response, 400) AS response FROM $t ORDER BY id DESC LIMIT 12", ARRAY_A );
			} else {
				$out['log'] = 'keine Log-Tabelle';
			}
			$s = get_option( 'fluentmail-settings' );
			$c = array();
			if ( is_array( $s ) && ! empty( $s['connections'] ) ) {
				foreach ( $s['connections'] as $k => $v ) {
					$p   = isset( $v['provider_settings'] ) ? $v['provider_settings'] : array();
					$c[] = array(
						'key'        => $k,
						'provider'   => isset( $p['provider'] ) ? $p['provider'] : null,
						'sender'     => isset( $p['sender_email'] ) ? $p['sender_email'] : null,
						'host'       => isset( $p['host'] ) ? $p['host'] : null,
						'port'       => isset( $p['port'] ) ? $p['port'] : null,
						'encryption' => isset( $p['encryption'] ) ? $p['encryption'] : null,
						'force_from' => isset( $p['force_from_email'] ) ? $p['force_from_email'] : null,
					);
				}
			}
			$out['connections'] = $c;
			$out['mappings']    = ( is_array( $s ) && isset( $s['mappings'] ) ) ? $s['mappings'] : null;
			$out['misc']        = ( is_array( $s ) && isset( $s['misc'] ) ) ? $s['misc'] : null;
			$out['wp_from']     = array( 'wp_mail_from' => apply_filters( 'wp_mail_from', 'wordpress@' . wp_parse_url( home_url(), PHP_URL_HOST ) ), 'admin_email' => get_option( 'admin_email' ) );
			if ( 'POST' === $req->get_method() && $req['to'] ) {
				$err = null;
				add_action( 'wp_mail_failed', function ( $e ) use ( &$err ) {
					$err = $e->get_error_message();
				} );
				$out['sent']  = wp_mail( sanitize_email( $req['to'] ), 'KT Mail-Test ' . gmdate( 'H:i:s' ), 'Testmail von der Mail-Diagnose.' );
				$out['error'] = $err;
			}
			if ( 'POST' === $req->get_method() && $req['reset'] ) {
				$u = get_user_by( 'email', sanitize_email( $req['reset'] ) );
				if ( ! $u ) {
					$out['reset'] = 'kein Benutzer mit dieser E-Mail';
				} else {
					$k = get_password_reset_key( $u );
					if ( is_wp_error( $k ) ) {
						$out['reset'] = 'FEHLER ' . $k->get_error_code() . ': ' . $k->get_error_message();
					} else {
						$err = null;
						add_action( 'wp_mail_failed', function ( $e ) use ( &$err ) {
							$err = $e->get_error_message();
						} );
						WC()->mailer();
						do_action( 'woocommerce_reset_password_notification', $u->user_login, $k );
						$out['reset']       = 'Schluessel erzeugt, Mail ausgeloest';
						$out['reset_error'] = $err;
					}
				}
				$out['reset_filters'] = array(
					'allow_password_reset' => apply_filters( 'allow_password_reset', true, $u ? $u->ID : 0 ),
					'user_caps_reset'      => $u ? $u->has_cap( 'read' ) : null,
				);
			}
			if ( $req['overview'] && function_exists( 'kt_ov_html' ) ) {
				$oo = wc_get_order( (int) $req['overview'] );
				$out['overview_html'] = $oo ? kt_ov_html( $oo ) : 'keine Bestellung';
				$out['overview_url']  = $oo ? preg_replace( '/_wpnonce=[a-z0-9]+/i', '_wpnonce=XXX', kt_ov_url( $oo->get_id() ) ) : null;
			}
			if ( $req['sitemapgrep'] ) {
				$base = WP_PLUGIN_DIR . '/beyondseo';
				$hits = array();
				if ( is_dir( $base ) ) {
					$it = new RecursiveIteratorIterator( new RecursiveDirectoryIterator( $base, FilesystemIterator::SKIP_DOTS ) );
					foreach ( $it as $f ) {
						if ( $f->isFile() && '.php' === substr( $f->getFilename(), -4 ) && false === strpos( str_replace( '\', '/', $f->getPathname() ), '/vendor/' ) ) {
							foreach ( file( $f->getPathname() ) as $i => $line ) {
								if ( preg_match( '/sitemap.*(\.xml|rewrite|template_redirect|query_var|home_url|site_url)|(add_rewrite|wp_sitemaps_enabled).*sitemap|robots_txt.*sitemap/i', $line ) ) {
									$hits[] = str_replace( $base, '', str_replace( '\', '/', $f->getPathname() ) ) . ':' . ( $i + 1 ) . ': ' . substr( trim( $line ), 0, 190 );
								}
							}
						}
					}
				}
				$out['sitemapgrep'] = $hits;
				$out['core_sitemaps_enabled'] = wp_sitemaps_get_server() ? wp_sitemaps_get_server()->sitemaps_enabled() : null;
				$out['blog_public'] = get_option( 'blog_public' );
			}
			if ( $req['seogrep'] ) {
				$base = WP_PLUGIN_DIR . '/beyondseo';
				$hits = array();
				if ( is_dir( $base ) ) {
					$it = new RecursiveIteratorIterator( new RecursiveDirectoryIterator( $base, FilesystemIterator::SKIP_DOTS ) );
					foreach ( $it as $f ) {
						if ( $f->isFile() && '.php' === substr( $f->getFilename(), -4 ) && false === strpos( $f->getPathname(), '/vendor/' ) && false === strpos( $f->getPathname(), '\\vendor\\' ) ) {
							foreach ( file( $f->getPathname() ) as $i => $line ) {
								if ( preg_match( '/articleBody|apply_filters\(\s*.the_content|do_blocks\(|do_shortcode\(|wp_strip_all_tags\(\s*\$post|get_the_content/i', $line ) ) {
									$hits[] = str_replace( $base, '', $f->getPathname() ) . ':' . ( $i + 1 ) . ': ' . substr( trim( $line ), 0, 170 );
								}
							}
						}
					}
				}
				$out['seogrep'] = $hits;
			}
			if ( $req['hooks'] ) {
				global $wp_filter;
				$found = array();
				foreach ( array( 'plugins_loaded', 'init', 'wp_loaded', 'template_redirect', 'wp', 'wp_head', 'wp_footer', 'the_content', 'wp_print_footer_scripts', 'shutdown', 'wp_enqueue_scripts', 'get_header', 'wp_body_open' ) as $tag ) {
					if ( empty( $wp_filter[ $tag ] ) ) {
						continue;
					}
					foreach ( $wp_filter[ $tag ]->callbacks as $prio => $cbs ) {
						foreach ( $cbs as $cb ) {
							try {
								$f = $cb['function'];
								if ( is_array( $f ) ) {
									$ref = new ReflectionMethod( $f[0], $f[1] );
									$lbl = ( is_object( $f[0] ) ? get_class( $f[0] ) : $f[0] ) . '::' . $f[1];
								} elseif ( $f instanceof Closure ) {
									$ref = new ReflectionFunction( $f );
									$lbl = 'closure';
								} else {
									$ref = new ReflectionFunction( $f );
									$lbl = (string) $f;
								}
								$file = str_replace( WP_PLUGIN_DIR, '', (string) $ref->getFileName() );
								if ( preg_match( '#beyondseo|rankingcoach|seo#i', $file . $lbl ) ) {
									$found[] = $tag . ' @' . $prio . ' ' . $lbl . ' ' . $file . ':' . $ref->getStartLine();
								}
							} catch ( \Throwable $e ) {
								continue;
							}
						}
					}
				}
				$out['seo_hooks'] = $found;
			}
			if ( $req['gwcheck'] ) {
				$oo  = wc_get_order( (int) $req['gwcheck'] );
				$res = array();
				foreach ( array( 'customer_on_hold_order', 'customer_processing_order', 'customer_completed_order', 'new_order', 'customer_reset_password' ) as $eid ) {
					$att = apply_filters( 'woocommerce_email_attachments', array(), $eid, $oo, null );
					$res[ $eid ] = array_map( function ( $f ) {
						return basename( $f ) . ' (' . ( file_exists( $f ) ? filesize( $f ) . ' Bytes' : 'FEHLT' ) . ')';
					}, $att );
				}
				$out['gw_attachments'] = $res;
			}
			if ( $req['langcopy'] ) {
				$copied = array();
				$skipped = array();
				foreach ( array( 'plugins', 'themes' ) as $sub ) {
					$d = WP_LANG_DIR . '/' . $sub;
					if ( ! is_dir( $d ) ) {
						continue;
					}
					foreach ( scandir( $d ) as $f ) {
						if ( preg_match( '/^(.+)-de_DE\.(mo|po|l10n\.php)$/', $f, $m ) ) {
							$dst = $d . '/' . $m[1] . '-de_DE_formal.' . $m[2];
						} elseif ( preg_match( '/^(.+)-de_DE-([a-f0-9]{32})\.json$/', $f, $m ) ) {
							$dst = $d . '/' . $m[1] . '-de_DE_formal-' . $m[2] . '.json';
						} else {
							continue;
						}
						if ( file_exists( $dst ) ) {
							$skipped[] = $sub . '/' . basename( $dst );
						} elseif ( copy( $d . '/' . $f, $dst ) ) {
							$copied[] = $sub . '/' . basename( $dst );
						} else {
							$skipped[] = 'FEHLER ' . $sub . '/' . $f;
						}
					}
				}
				$out['copied']  = $copied;
				$out['skipped'] = $skipped;
			}
			if ( $req['trtest'] ) {
				$out['locale_now'] = get_locale();
				$out['tr']         = array(
					'ppcp'   => __( 'PayPal Package Tracking', 'woocommerce-paypal-payments' ),
					'ppcp2'  => __( 'Tracking number', 'woocommerce-paypal-payments' ),
					'wc'     => __( 'Your cart is currently empty!', 'woocommerce' ),
					'fluent' => __( 'Settings', 'fluentform' ),
					'smtp'   => __( 'Send Test Email', 'fluent-smtp' ),
					'wcpay'  => __( 'Payments', 'woocommerce-payments' ),
				);
				$inst              = wp_get_installed_translations( 'plugins' );
				$out['installed']  = array();
				foreach ( array( 'woocommerce-paypal-payments', 'fluentform', 'fluent-smtp', 'woocommerce-payments', 'woocommerce-services' ) as $d ) {
					$out['installed'][ $d ] = isset( $inst[ $d ] ) ? array_keys( $inst[ $d ] ) : array();
				}
			}
			if ( $req['langdl'] ) {
				require_once ABSPATH . 'wp-admin/includes/file.php';
				require_once ABSPATH . 'wp-admin/includes/translation-install.php';
				require_once ABSPATH . 'wp-admin/includes/class-wp-upgrader.php';
				$out['langdl']    = wp_download_language_pack( sanitize_text_field( $req['langdl'] ) );
				$out['available'] = get_available_languages();
			}
			if ( $req['langplugins'] ) {
				require_once ABSPATH . 'wp-admin/includes/file.php';
				require_once ABSPATH . 'wp-admin/includes/misc.php';
				require_once ABSPATH . 'wp-admin/includes/plugin.php';
				require_once ABSPATH . 'wp-admin/includes/class-wp-upgrader.php';
				require_once ABSPATH . 'wp-admin/includes/update.php';
				delete_site_transient( 'update_plugins' );
				delete_site_transient( 'update_themes' );
				delete_site_transient( 'update_core' );
				wp_update_plugins();
				wp_update_themes();
				wp_version_check();
				$ups                      = wp_get_translation_updates();
				$out['lang_updates']      = array();
				foreach ( $ups as $u ) {
					$out['lang_updates'][] = $u->type . ':' . $u->slug . ':' . $u->language;
				}
				$skin                     = new Automatic_Upgrader_Skin();
				$up                       = new Language_Pack_Upgrader( $skin );
				$res                      = $up->bulk_upgrade( $ups );
				$out['lang_result']       = is_array( $res ) ? count( $res ) : var_export( $res, true );
				$out['lang_messages']     = $skin->get_upgrade_messages();
				$out['locale_installed']  = array( 'plugins' => array_keys( wp_get_installed_translations( 'plugins' ) ), 'wc' => array_keys( (array) ( wp_get_installed_translations( 'plugins' )['woocommerce'] ?? array() ) ) );
			}
			if ( $req['emailpreview'] ) {
				$oo = wc_get_order( (int) $req['emailpreview'] );
				if ( $oo ) {
					if ( $req['tc'] ) {
						$oo->update_meta_data( '_kt_tracking_carrier', sanitize_key( $req['tc'] ) ); // nur im Speicher, wird nicht gespeichert
						$oo->update_meta_data( '_kt_tracking_number', sanitize_text_field( $req['tn'] ) );
					}
					$em                = WC()->mailer()->get_emails()['WC_Email_Customer_Completed_Order'];
					$em->object        = $oo;
					$em->recipient     = $oo->get_billing_email();
					$em->placeholders['{order_date}']   = wc_format_datetime( $oo->get_date_created() );
					$em->placeholders['{order_number}'] = $oo->get_order_number();
					$out['email_subject'] = $em->get_subject();
					$out['email_html']    = $em->get_content();
				}
			}
			if ( $req['grep'] ) {
				$base = WP_PLUGIN_DIR . '/woocommerce-paypal-payments/modules/ppcp-order-tracking/src';
				$res  = array();
				if ( is_dir( $base ) ) {
					$it = new RecursiveIteratorIterator( new RecursiveDirectoryIterator( $base, FilesystemIterator::SKIP_DOTS ) );
					foreach ( $it as $f ) {
						if ( $f->isFile() && '.php' === substr( $f->getFilename(), -4 ) ) {
							foreach ( file( $f->getPathname() ) as $i => $line ) {
								if ( preg_match( '/meta|action\(|do_action|apply_filters|TRACKING_INFO_META|const /i', $line ) ) {
									$res[] = str_replace( $base, '', $f->getPathname() ) . ':' . ( $i + 1 ) . ': ' . substr( trim( $line ), 0, 200 );
								}
							}
						}
					}
				}
				$out['grep'] = $res;
			}
			if ( $req['carriers'] ) {
				$dir  = WP_PLUGIN_DIR . '/woocommerce-paypal-payments/modules/ppcp-order-tracking';
				$hits = array();
				$fl   = array();
				if ( is_dir( $dir ) ) {
					$it = new RecursiveIteratorIterator( new RecursiveDirectoryIterator( $dir, FilesystemIterator::SKIP_DOTS ) );
					foreach ( $it as $f ) {
						if ( $f->isFile() && '.php' === substr( $f->getFilename(), -4 ) ) {
							$fl[] = str_replace( $dir, '', $f->getPathname() );
							foreach ( file( $f->getPathname() ) as $i => $line ) {
								if ( false !== stripos( $line, 'carrier' ) && ( false !== stripos( $line, 'apply_filters' ) || false !== stripos( $line, "'order-tracking.carriers'" ) ) ) {
									$hits[] = str_replace( $dir, '', $f->getPathname() ) . ':' . ( $i + 1 ) . ': ' . trim( $line );
								}
							}
						}
					}
				}
				$out['carrier_dir']   = is_dir( $dir );
				$out['carrier_files'] = $fl;
				$out['carrier_hits']  = $hits;
				$cf = $dir . '/carriers.php';
				if ( is_file( $cf ) ) {
					$car = include $cf;
					$sum = array();
					if ( is_array( $car ) ) {
						foreach ( $car as $cc => $g ) {
							$items = isset( $g['items'] ) ? $g['items'] : array();
							$m     = array();
							foreach ( $items as $k => $v ) {
								if ( preg_match( '/dhl|gls|hermes|other|sonstig/i', $k . ' ' . $v ) ) {
									$m[ $k ] = $v;
								}
							}
							$sum[ $cc ] = array( 'name' => isset( $g['name'] ) ? $g['name'] : null, 'count' => count( $items ), 'match' => $m );
						}
					}
					$out['carrier_de']     = isset( $car['DE']['items'] ) ? $car['DE']['items'] : null;
					$gl                    = array();
					if ( isset( $car['global']['items'] ) ) {
						foreach ( $car['global']['items'] as $k => $v ) {
							if ( preg_match( '/dhl|gls|deutsche|dpd|post/i', $k . ' ' . $v ) ) {
								$gl[ $k ] = $v;
							}
						}
					}
					$out['carrier_global'] = $gl;
					$out['carrier_groups'] = count( $sum );
					$out['carriers']       = $sum;
				}
			}
			$out['locale']    = array(
				'site'      => get_locale(),
				'option'    => get_option( 'WPLANG' ),
				'available' => get_available_languages(),
				'core'      => array_keys( wp_get_installed_translations( 'core' ) ),
				'wc_de'     => array_keys( (array) ( wp_get_installed_translations( 'plugins' )['woocommerce'] ?? array() ) ),
			);
			return $out;
		},
	) );
} );
