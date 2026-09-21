<?php
/**
 * JB Kaffeemaschinen - automatische Wartungserinnerung (Fluent Form #2 "Wartungserinnerung")
 *
 * Einbau: Plugin "Code Snippets" -> Neues Snippet -> Art "PHP", "Ueberall ausfuehren", diesen Code
 * OHNE die erste Zeile (<?php) einfuegen und aktivieren. Alternativ als mu-plugin ablegen.
 *
 * Was passiert:
 *  1. Beim Absenden des Formulars: Bestaetigungs-Mail an den Kunden mit dem berechneten Faelligkeitsmonat
 *     (letzte Wartung + 2 Jahre privat / + 1 Jahr gewerblich) und Abmelde-Link. Ist die Wartung schon faellig
 *     oder in weniger als lead_days faellig, geht statt dessen sofort die Erinnerung raus.
 *  2. Taeglich (WP-Cron): wer lead_days vor der Faelligkeit erreicht hat, bekommt EINE Erinnerung.
 *     Danach wird der Eintrag keep_days Tage aufbewahrt und dann geloescht (Datenschutz).
 *  3. Abmelde-Link: loescht den Eintrag sofort.
 *  4. Admin-Test ohne Versand:  GET  /wp-json/kt/v1/wartung          (Trockenlauf, listet alle Eintraege)
 *     Manuell ausloesen:        POST /wp-json/kt/v1/wartung?send=1   (nur Administrator, Application Password)
 */
if ( ! defined( 'ABSPATH' ) ) {
	return;
}

if ( ! function_exists( 'kt_we_cfg' ) ) {

	function kt_we_cfg() {
		return array(
			'form_id'   => 2,
			'lead_days' => 28,   // Erinnerung so viele Tage vor der Faelligkeit
			'keep_days' => 90,   // Daten so lange nach dem Erinnerungsversand aufbewahren, dann loeschen
			'from'      => 'JB Kaffeemaschinen <shop@kaffeetechniker.de>',
			'reply_to'  => 'info@kaffeetechniker.de',
			'admin'     => 'shop@kaffeetechniker.de',
			'max_mails' => 40,   // Sicherheitsgrenze je Lauf
		);
	}

	function kt_we_months() {
		return array( 1 => 'Januar', 2 => 'Februar', 3 => 'M&auml;rz', 4 => 'April', 5 => 'Mai', 6 => 'Juni', 7 => 'Juli',
			8 => 'August', 9 => 'September', 10 => 'Oktober', 11 => 'November', 12 => 'Dezember' );
	}

	function kt_we_month_text( $date ) {
		$m = kt_we_months();
		return $m[ (int) $date->format( 'n' ) ] . ' ' . $date->format( 'Y' );
	}

	function kt_we_table( $name ) {
		global $wpdb;
		return $wpdb->prefix . $name;
	}

	function kt_we_state() {
		$s = get_option( 'kt_we_state', array() );
		return is_array( $s ) ? $s : array();
	}

	function kt_we_state_save( $s ) {
		update_option( 'kt_we_state', $s, false );
	}

	/** Eintrag des Formulars -> Array oder null */
	function kt_we_parse( $row ) {
		$r = json_decode( $row->response, true );
		if ( ! is_array( $r ) ) {
			return null;
		}
		$email = isset( $r['email'] ) ? sanitize_email( $r['email'] ) : '';
		if ( ! is_email( $email ) ) {
			return null;
		}
		$kind = ( isset( $r['nutzung'] ) && 'gewerblich' === $r['nutzung'] ) ? 'gewerblich' : 'privat';
		$y    = 0;
		$m    = 0;
		if ( ! empty( $r['wartung_jahr'] ) ) {
			$y = (int) $r['wartung_jahr'];
			$m = isset( $r['wartung_monat'] ) ? (int) $r['wartung_monat'] : 0;
		} elseif ( ! empty( $r['letzte_wartung'] ) ) {
			$t = (string) $r['letzte_wartung']; // alte Eintraege: Freitext "10/2024"
			if ( preg_match( '/(\d{1,2})\s*[\/.\-]\s*(\d{4})/', $t, $mm ) ) {
				$m = (int) $mm[1];
				$y = (int) $mm[2];
			} elseif ( preg_match( '/(\d{4})/', $t, $mm ) ) {
				$y = (int) $mm[1];
				$m = 12;
			}
		}
		if ( $y < 2000 || $y > 2100 ) {
			return null;
		}
		if ( $m < 1 || $m > 12 ) {
			$m = 12;
		}
		$interval = ( 'gewerblich' === $kind ) ? 1 : 2;
		$due      = new DateTimeImmutable( sprintf( '%04d-%02d-01', $y + $interval, $m ), wp_timezone() );
		return array(
			'id'         => (int) $row->id,
			'name'       => isset( $r['name'] ) ? sanitize_text_field( $r['name'] ) : '',
			'email'      => $email,
			'kind'       => $kind,
			'hersteller' => isset( $r['hersteller'] ) ? sanitize_text_field( $r['hersteller'] ) : '',
			'due'        => $due,
		);
	}

	function kt_we_token( $id, $email ) {
		return substr( hash_hmac( 'sha256', $id . '|' . strtolower( $email ), wp_salt( 'auth' ) ), 0, 32 );
	}

	function kt_we_unsub_url( $id, $email ) {
		return add_query_arg( array( 'kt_we_unsub' => $id, 't' => kt_we_token( $id, $email ) ), home_url( '/' ) );
	}

	function kt_we_mail( $to, $subject, $inner_html ) {
		$cfg  = kt_we_cfg();
		$body = '<div style="font-family:Arial,Helvetica,sans-serif;font-size:15px;line-height:1.6;color:#1c1c1c;max-width:560px">'
			. $inner_html
			. '<p style="font-size:12px;color:#6b7178;margin-top:26px;border-top:1px solid #ddd;padding-top:12px">'
			. 'Joachim Bl&ouml;chle Elektro-Service GmbH &middot; Wallauer Stra&szlig;e 4 &middot; 65719 Hofheim-Langenhain &middot; Telefon 06192 2004363'
			. '</p></div>';
		$headers = array(
			'Content-Type: text/html; charset=UTF-8',
			'From: ' . $cfg['from'],
			'Reply-To: ' . $cfg['reply_to'],
		);
		return wp_mail( $to, $subject, $body, $headers );
	}

	function kt_we_unsub_line( $p ) {
		return '<p style="font-size:12px;color:#6b7178">Sie m&ouml;chten nicht mehr erinnert werden? '
			. '<a href="' . esc_url( kt_we_unsub_url( $p['id'], $p['email'] ) ) . '">Erinnerung beenden</a> '
			. '(Ihre Angaben werden dabei gel&ouml;scht).</p>';
	}

	function kt_we_greeting( $p ) {
		return '<p>' . ( $p['name'] ? 'Guten Tag ' . esc_html( $p['name'] ) . ',' : 'Guten Tag,' ) . '</p>';
	}

	/** Bestaetigung (Wartung noch nicht in Sicht) */
	function kt_we_send_confirmation( $p, $remind_from ) {
		$due  = kt_we_month_text( $p['due'] );
		$when = kt_we_month_text( $remind_from );
		$html = kt_we_greeting( $p )
			. '<p>vielen Dank f&uuml;r Ihre Anmeldung zur Wartungserinnerung' . ( $p['hersteller'] ? ' f&uuml;r Ihr Ger&auml;t (' . esc_html( $p['hersteller'] ) . ')' : '' ) . '.</p>'
			. '<p>Die n&auml;chste Wartung ist <b>' . $due . '</b> f&auml;llig'
			. ( 'gewerblich' === $p['kind'] ? ' (bei gewerblicher Nutzung j&auml;hrlich)' : ' (im Privathaushalt alle zwei Jahre)' )
			. '. Wir erinnern Sie per E-Mail rechtzeitig, voraussichtlich im <b>' . $when . '</b>.</p>'
			. kt_we_unsub_line( $p );
		return kt_we_mail( $p['email'], 'Ihre Wartungserinnerung ist eingerichtet', $html );
	}

	/** Erinnerung (Faelligkeit erreicht bzw. in Sicht) */
	function kt_we_send_reminder( $p ) {
		$due  = kt_we_month_text( $p['due'] );
		$html = kt_we_greeting( $p )
			. '<p>es ist Zeit f&uuml;r die Wartung Ihres Kaffeevollautomaten' . ( $p['hersteller'] ? ' (' . esc_html( $p['hersteller'] ) . ')' : '' )
			. ' &ndash; sie ist im <b>' . $due . '</b> f&auml;llig.</p>'
			. '<p>Eine regelm&auml;&szlig;ige Wartung sorgt f&uuml;r gleichbleibende Kaffeequalit&auml;t und Hygiene und beugt Defekten vor'
			. ( 'gewerblich' === $p['kind'] ? '; bei gewerblicher Nutzung inklusive VDE-Sicherheitspr&uuml;fung' : '' ) . '.</p>'
			. '<p><b>So einfach geht es:</b> Bringen Sie das Ger&auml;t w&auml;hrend der &Ouml;ffnungszeiten vorbei &ndash; ohne Termin '
			. '(Mo&ndash;Do 8:00&ndash;16:00 Uhr, Fr 8:00&ndash;13:00 Uhr). Auf Wunsch stellen wir Ihnen f&uuml;r die Dauer ein Mietger&auml;t.</p>'
			. '<p><a href="' . esc_url( home_url( '/wartung/' ) ) . '">Alle Infos zur Wartung</a> &middot; '
			. '<a href="' . esc_url( home_url( '/reparaturkosten/' ) ) . '">Dauer &amp; Kosten</a></p>'
			. kt_we_unsub_line( $p );
		return kt_we_mail( $p['email'], 'Zeit für die Wartung Ihres Kaffeevollautomaten', $html );
	}

	/** Eintrag samt Daten loeschen (Abmeldung / Aufbewahrungsfrist) */
	function kt_we_delete( $id ) {
		global $wpdb;
		$wpdb->suppress_errors( true );
		$wpdb->delete( kt_we_table( 'fluentform_entry_details' ), array( 'submission_id' => $id ), array( '%d' ) );
		$wpdb->delete( kt_we_table( 'fluentform_submission_meta' ), array( 'response_id' => $id ), array( '%d' ) );
		$wpdb->delete( kt_we_table( 'fluentform_submissions' ), array( 'id' => $id ), array( '%d' ) );
		$wpdb->suppress_errors( false );
		$s = kt_we_state();
		unset( $s[ $id ] );
		kt_we_state_save( $s );
	}

	/** Taeglicher Lauf. $dry = true -> nur berichten, nichts senden/loeschen. */
	function kt_we_run( $dry = false ) {
		global $wpdb;
		$cfg    = kt_we_cfg();
		$now    = new DateTimeImmutable( 'now', wp_timezone() );
		$state  = kt_we_state();
		$report = array();
		$sent   = 0;
		$rows   = $wpdb->get_results( $wpdb->prepare(
			'SELECT id, response FROM ' . kt_we_table( 'fluentform_submissions' ) . " WHERE form_id = %d AND status <> 'trashed' ORDER BY id ASC",
			$cfg['form_id']
		) );
		foreach ( (array) $rows as $row ) {
			$p = kt_we_parse( $row );
			if ( ! $p ) {
				continue;
			}
			$id          = $p['id'];
			$remind_from = $p['due']->modify( '-' . (int) $cfg['lead_days'] . ' days' );
			$item        = array(
				'id'          => $id,
				'email'       => preg_replace( '/^(.).*(@.*)$/', '$1***$2', $p['email'] ),
				'kind'        => $p['kind'],
				'faellig'     => $p['due']->format( 'Y-m' ),
				'erinnern_ab' => $remind_from->format( 'Y-m-d' ),
				'status'      => 'wartet',
			);
			if ( isset( $state[ $id ]['sent'] ) ) {
				$age = ( $now->getTimestamp() - (int) $state[ $id ]['sent'] ) / DAY_IN_SECONDS;
				if ( $age >= (int) $cfg['keep_days'] ) {
					$item['status'] = $dry ? 'wuerde geloescht' : 'geloescht';
					if ( ! $dry ) {
						kt_we_delete( $id );
					}
				} else {
					$item['status'] = 'erinnert am ' . wp_date( 'Y-m-d', (int) $state[ $id ]['sent'] );
				}
			} elseif ( $now >= $remind_from ) {
				if ( $dry ) {
					$item['status'] = 'wuerde erinnert';
				} elseif ( $sent < (int) $cfg['max_mails'] && kt_we_send_reminder( $p ) ) {
					$state[ $id ] = array( 'sent' => $now->getTimestamp() );
					kt_we_state_save( $state );
					++$sent;
					$item['status'] = 'erinnert';
					kt_we_mail( $cfg['admin'], 'Wartungserinnerung versendet: ' . $p['email'],
						'<p>Erinnerung verschickt an ' . esc_html( $p['email'] ) . ' (' . esc_html( $p['hersteller'] ) . ', ' . $p['kind'] . ', f&auml;llig ' . kt_we_month_text( $p['due'] ) . ').</p>' );
				} else {
					$item['status'] = 'Versand fehlgeschlagen / Limit';
				}
			}
			$report[] = $item;
		}
		return $report;
	}

	/** Beim Absenden: Bestaetigung bzw. sofortige Erinnerung */
	function kt_we_on_submit( $insert_id, $form_data = null, $form = null ) {
		static $done = array();
		$cfg = kt_we_cfg();
		$fid = 0;
		if ( is_object( $form ) && isset( $form->id ) ) {
			$fid = (int) $form->id;
		} elseif ( is_array( $form ) && isset( $form['id'] ) ) {
			$fid = (int) $form['id'];
		}
		if ( $fid !== (int) $cfg['form_id'] || isset( $done[ $insert_id ] ) ) {
			return;
		}
		$done[ $insert_id ] = true;
		global $wpdb;
		$row = $wpdb->get_row( $wpdb->prepare(
			'SELECT id, response FROM ' . kt_we_table( 'fluentform_submissions' ) . ' WHERE id = %d',
			(int) $insert_id
		) );
		$p = $row ? kt_we_parse( $row ) : null;
		if ( ! $p ) {
			return;
		}
		$now         = new DateTimeImmutable( 'now', wp_timezone() );
		$remind_from = $p['due']->modify( '-' . (int) $cfg['lead_days'] . ' days' );
		if ( $now >= $remind_from ) {
			if ( kt_we_send_reminder( $p ) ) {
				$state                  = kt_we_state();
				$state[ $p['id'] ]      = array( 'sent' => $now->getTimestamp() );
				kt_we_state_save( $state );
			}
		} else {
			kt_we_send_confirmation( $p, $remind_from );
		}
	}

	add_action( 'fluentform/submission_inserted', 'kt_we_on_submit', 10, 3 );
	add_action( 'fluentform_submission_inserted', 'kt_we_on_submit', 10, 3 );

	// taeglicher Lauf
	add_action( 'kt_we_daily', 'kt_we_run' );
	add_action( 'init', function () {
		if ( ! wp_next_scheduled( 'kt_we_daily' ) ) {
			wp_schedule_event( time() + 600, 'daily', 'kt_we_daily' );
		}
	} );

	// Abmelde-Link
	add_action( 'init', function () {
		if ( empty( $_GET['kt_we_unsub'] ) || empty( $_GET['t'] ) ) {
			return;
		}
		global $wpdb;
		$cfg = kt_we_cfg();
		$id  = (int) $_GET['kt_we_unsub'];
		$t   = sanitize_text_field( wp_unslash( $_GET['t'] ) );
		$row = $wpdb->get_row( $wpdb->prepare(
			'SELECT id, response FROM ' . kt_we_table( 'fluentform_submissions' ) . ' WHERE id = %d AND form_id = %d',
			$id,
			$cfg['form_id']
		) );
		$ok = false;
		if ( $row ) {
			$p = kt_we_parse( $row );
			if ( $p && hash_equals( kt_we_token( $id, $p['email'] ), $t ) ) {
				kt_we_delete( $id );
				$ok = true;
			}
		}
		wp_die(
			$ok ? 'Ihre Wartungserinnerung wurde beendet, Ihre Angaben sind gel&ouml;scht. Vielen Dank!'
				: 'Dieser Link ist ung&uuml;ltig oder die Erinnerung wurde bereits beendet.',
			'Wartungserinnerung',
			array( 'response' => 200 )
		);
	} );

	// Admin: Trockenlauf / manueller Lauf per REST
	add_action( 'rest_api_init', function () {
		register_rest_route( 'kt/v1', '/wartung', array(
			'methods'             => array( 'GET', 'POST' ),
			'permission_callback' => function () {
				return current_user_can( 'manage_options' );
			},
			'callback'            => function ( $req ) {
				$send = ( 'POST' === $req->get_method() && $req->get_param( 'send' ) );
				return rest_ensure_response( kt_we_run( ! $send ) );
			},
		) );
	} );
}
