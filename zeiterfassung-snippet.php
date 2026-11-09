/* kaffeetechniker.de - Zeiterfassung per NFC-Karte (Tablet im Laden) + Auswertung im WP-Backend.
 * Tablet: versteckte Seite /<KT_ZE_SLUG>/ (noindex, nicht verlinkt). Karte ans Tablet -> Kommen / Pause / Gehen,
 *         unten "Urlaub beantragen" (Karte scannen -> Antrag). Die Seite spricht per POST (JSON) mit sich selbst.
 * Backend: Menue "Zeiterfassung" (nur Admins): Monat/Buchungen, Mitarbeiter+Karten, Urlaub, CSV-Export.
 * Daten: eigene Tabellen kt_ze_staff, kt_ze_log, kt_ze_leave (Teil der normalen DB-Sicherung).
 * Einbau: Code Snippets, PHP, "Ueberall ausfuehren" (Deploy: deploy-zeiterfassung.ps1). */
define( 'KT_ZE_SLUG', 'zeit-r6n2v' );

function kt_ze_t( $n ) {
	global $wpdb;
	return $wpdb->prefix . 'kt_ze_' . $n;
}

add_action( 'init', function () {
	if ( get_option( 'kt_ze_db' ) === '3' ) {
		return;
	}
	global $wpdb;
	require_once ABSPATH . 'wp-admin/includes/upgrade.php';
	$cs = $wpdb->get_charset_collate();
	dbDelta( "CREATE TABLE " . kt_ze_t( 'staff' ) . " (
  id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  name varchar(120) NOT NULL DEFAULT '',
  uid varchar(40) NOT NULL DEFAULT '',
  email varchar(190) NOT NULL DEFAULT '',
  vac_days decimal(4,1) NOT NULL DEFAULT 0,
  active tinyint(1) NOT NULL DEFAULT 1,
  is_master tinyint(1) NOT NULL DEFAULT 0,
  created datetime NOT NULL,
  PRIMARY KEY  (id),
  KEY uid (uid)
) $cs;" );
	dbDelta( "CREATE TABLE " . kt_ze_t( 'log' ) . " (
  id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  staff_id bigint(20) unsigned NOT NULL,
  type varchar(12) NOT NULL,
  ts datetime NOT NULL,
  edited tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY  (id),
  KEY staff_ts (staff_id,ts)
) $cs;" );
	dbDelta( "CREATE TABLE " . kt_ze_t( 'leave' ) . " (
  id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  staff_id bigint(20) unsigned NOT NULL,
  d_from date NOT NULL,
  d_to date NOT NULL,
  kind varchar(20) NOT NULL DEFAULT 'urlaub',
  note varchar(255) NOT NULL DEFAULT '',
  status varchar(12) NOT NULL DEFAULT 'offen',
  created datetime NOT NULL,
  PRIMARY KEY  (id),
  KEY staff_id (staff_id)
) $cs;" );
	// Master-Benutzer (Menue am Tablet): Tobias Stammer; die Karte wird im Backend zugeordnet
	if ( ! $wpdb->get_var( 'SELECT id FROM ' . kt_ze_t( 'staff' ) . ' WHERE is_master=1 LIMIT 1' ) ) {
		$tid = (int) $wpdb->get_var( $wpdb->prepare( 'SELECT id FROM ' . kt_ze_t( 'staff' ) . ' WHERE name=%s LIMIT 1', 'Tobias Stammer' ) );
		if ( $tid ) {
			$wpdb->update( kt_ze_t( 'staff' ), array( 'is_master' => 1 ), array( 'id' => $tid ) );
		} else {
			$wpdb->insert( kt_ze_t( 'staff' ), array( 'name' => 'Tobias Stammer', 'uid' => '', 'email' => '', 'vac_days' => 30, 'active' => 1, 'is_master' => 1, 'created' => current_time( 'mysql' ) ) );
		}
	}
	update_option( 'kt_ze_db', '3', false );
}, 0 );

/* ---------- Hilfsfunktionen ---------- */

function kt_ze_norm_uid( $s ) {
	return preg_replace( '/[^0-9A-F]/', '', strtoupper( (string) $s ) );
}

function kt_ze_kinds() {
	return array( 'urlaub' => 'Urlaub', 'sonder' => 'Sonderurlaub', 'ueberstunden' => 'Überstundenausgleich' );
}

function kt_ze_types() {
	return array( 'kommen' => 'Kommen', 'pause_start' => 'Pause', 'pause_ende' => 'Pause beendet', 'gehen' => 'Gehen' );
}

function kt_ze_hm( $sec ) {
	$sec = max( 0, (int) $sec );
	return sprintf( '%d:%02d', floor( $sec / 3600 ), floor( ( $sec % 3600 ) / 60 ) );
}

function kt_ze_holidays( $y ) {
	static $cache = array();
	if ( isset( $cache[ $y ] ) ) {
		return $cache[ $y ];
	}
	$a = $y % 19; $b = intdiv( $y, 100 ); $c = $y % 100; $d = intdiv( $b, 4 ); $e = $b % 4;
	$f = intdiv( $b + 8, 25 ); $g = intdiv( $b - $f + 1, 3 ); $h = ( 19 * $a + $b - $d - $g + 15 ) % 30;
	$i = intdiv( $c, 4 ); $k = $c % 4; $l = ( 32 + 2 * $e + 2 * $i - $h - $k ) % 7;
	$m = intdiv( $a + 11 * $h + 22 * $l, 451 );
	$mo = intdiv( $h + $l - 7 * $m + 114, 31 );
	$da = ( ( $h + $l - 7 * $m + 114 ) % 31 ) + 1;
	$easter = gmmktime( 0, 0, 0, $mo, $da, $y );
	$rel = function ( $days ) use ( $easter ) {
		return gmdate( 'Y-m-d', $easter + $days * 86400 );
	};
	$cache[ $y ] = array(
		"$y-01-01"  => 'Neujahr',
		$rel( -2 )  => 'Karfreitag',
		$rel( 1 )   => 'Ostermontag',
		"$y-05-01"  => 'Tag der Arbeit',
		$rel( 39 )  => 'Christi Himmelfahrt',
		$rel( 50 )  => 'Pfingstmontag',
		$rel( 60 )  => 'Fronleichnam',
		"$y-10-03"  => 'Tag der Deutschen Einheit',
		"$y-12-25"  => '1. Weihnachtstag',
		"$y-12-26"  => '2. Weihnachtstag',
	);
	return $cache[ $y ];
}

/* Arbeitstage Mo-Fr ohne hessische Feiertage zwischen zwei Daten (inklusive), optional auf [$lo,$hi] begrenzt */
function kt_ze_workdays( $from, $to, $lo = null, $hi = null ) {
	$n = 0;
	$t = strtotime( $from . ' 12:00:00 UTC' );
	$end = strtotime( $to . ' 12:00:00 UTC' );
	for ( $i = 0; $t <= $end && $i < 400; $t += 86400, $i++ ) {
		$ds = gmdate( 'Y-m-d', $t );
		if ( ( $lo && $ds < $lo ) || ( $hi && $ds > $hi ) ) {
			continue;
		}
		if ( (int) gmdate( 'N', $t ) > 5 ) {
			continue;
		}
		if ( isset( kt_ze_holidays( (int) gmdate( 'Y', $t ) )[ $ds ] ) ) {
			continue;
		}
		$n++;
	}
	return $n;
}

function kt_ze_vac_taken( $sid, $year, $status = 'genehmigt' ) {
	global $wpdb;
	$rows = $wpdb->get_results( $wpdb->prepare(
		'SELECT d_from,d_to FROM ' . kt_ze_t( 'leave' ) . " WHERE staff_id=%d AND status=%s AND kind='urlaub' AND d_to>=%s AND d_from<=%s",
		$sid, $status, "$year-01-01", "$year-12-31"
	) );
	$n = 0;
	foreach ( $rows as $r ) {
		$n += kt_ze_workdays( $r->d_from, $r->d_to, "$year-01-01", "$year-12-31" );
	}
	return $n;
}

/* Status eines Mitarbeiters: out | working | pause (+ Zeit des letzten Eintrags) */
function kt_ze_state( $sid ) {
	global $wpdb;
	$last = $wpdb->get_row( $wpdb->prepare( 'SELECT type,ts FROM ' . kt_ze_t( 'log' ) . ' WHERE staff_id=%d ORDER BY ts DESC,id DESC LIMIT 1', $sid ) );
	if ( ! $last || $last->type === 'gehen' || substr( $last->ts, 0, 10 ) !== current_time( 'Y-m-d' ) ) {
		return array( 'out', $last );
	}
	return array( $last->type === 'pause_start' ? 'pause' : 'working', $last );
}

/* Arbeits- und Pausenzeit von heute (laufender Abschnitt zaehlt bis jetzt mit) */
function kt_ze_today( $sid ) {
	global $wpdb;
	$day  = current_time( 'Y-m-d' );
	$rows = $wpdb->get_results( $wpdb->prepare( 'SELECT type,ts FROM ' . kt_ze_t( 'log' ) . ' WHERE staff_id=%d AND ts BETWEEN %s AND %s ORDER BY ts,id', $sid, "$day 00:00:00", "$day 23:59:59" ) );
	$net = 0; $pause = 0; $ws = null; $ps = null;
	foreach ( $rows as $r ) {
		$t = strtotime( $r->ts );
		if ( $r->type === 'kommen' ) {
			$ws = $t;
		} elseif ( $r->type === 'pause_ende' ) {
			if ( $ps !== null ) { $pause += $t - $ps; $ps = null; }
			$ws = $t;
		} elseif ( $r->type === 'pause_start' ) {
			if ( $ws !== null ) { $net += $t - $ws; $ws = null; }
			$ps = $t;
		} elseif ( $r->type === 'gehen' ) {
			if ( $ws !== null ) { $net += $t - $ws; $ws = null; }
			if ( $ps !== null ) { $pause += $t - $ps; $ps = null; }
		}
	}
	$now = strtotime( current_time( 'mysql' ) );
	if ( $ws !== null ) { $net += $now - $ws; }
	if ( $ps !== null ) { $pause += $now - $ps; }
	return array( 'net' => kt_ze_hm( $net ), 'pause' => kt_ze_hm( $pause ), 'any' => (bool) $rows, 'net_s' => $net, 'pause_s' => $pause );
}

function kt_ze_allowed( $state ) {
	if ( $state === 'working' ) {
		return array( 'pause_start', 'gehen' );
	}
	if ( $state === 'pause' ) {
		return array( 'pause_ende', 'gehen' );
	}
	return array( 'kommen' );
}

/* ---------- Tablet-Seite + API ---------- */

add_action( 'init', function () {
	$path = trim( (string) wp_parse_url( $_SERVER['REQUEST_URI'] ?? '', PHP_URL_PATH ), '/' );
	if ( $path !== KT_ZE_SLUG ) {
		return;
	}
	if ( ! defined( 'DONOTCACHEPAGE' ) ) {
		define( 'DONOTCACHEPAGE', true );
	}
	nocache_headers();
	header( 'Cache-Control: no-store, no-cache, must-revalidate, max-age=0' );
	header( 'X-Robots-Tag: noindex, nofollow, noarchive' );
	header( 'Referrer-Policy: no-referrer' );
	status_header( 200 );
	if ( ( $_SERVER['REQUEST_METHOD'] ?? '' ) === 'POST' ) {
		header( 'Content-Type: application/json; charset=utf-8' );
		$in = json_decode( (string) file_get_contents( 'php://input' ), true );
		echo wp_json_encode( kt_ze_api( is_array( $in ) ? $in : array() ) );
		exit;
	}
	header( 'Content-Type: text/html; charset=utf-8' );
	echo kt_ze_page();
	exit;
}, 1 );

function kt_ze_api( $in ) {
	global $wpdb;
	$a   = (string) ( $in['a'] ?? '' );
	$uid = kt_ze_norm_uid( $in['uid'] ?? '' );
	if ( strpos( $a, 'adm_' ) === 0 ) {
		return kt_ze_api_admin( $a, $in );
	}
	if ( $uid === '' ) {
		return array( 'ok' => false, 'err' => 'uid' );
	}
	$st = $wpdb->get_row( $wpdb->prepare( 'SELECT * FROM ' . kt_ze_t( 'staff' ) . ' WHERE uid=%s AND active=1 LIMIT 1', $uid ) );
	if ( ! $st ) {
		$ip  = md5( (string) ( $_SERVER['REMOTE_ADDR'] ?? '' ) );
		$key = 'kt_ze_rl_' . $ip;
		$cnt = (int) get_transient( $key );
		if ( $cnt > 40 ) {
			return array( 'ok' => false, 'err' => 'limit' );
		}
		set_transient( $key, $cnt + 1, 600 );
		update_option( 'kt_ze_unknown', array( 'uid' => $uid, 'at' => current_time( 'mysql' ) ), false );
		return array( 'ok' => false, 'unknown' => true );
	}
	$sid = (int) $st->id;
	list( $state, $last ) = kt_ze_state( $sid );
	$info = function () use ( $st, $sid, $state, $last ) {
		$y = (int) current_time( 'Y' );
		return array(
			'ok'      => true,
			'name'    => $st->name,
			'state'   => $state,
			'allowed' => kt_ze_allowed( $state ),
			'since'   => ( $last && $state !== 'out' ) ? substr( $last->ts, 11, 5 ) : '',
			'today'   => kt_ze_today( $sid ),
			'vac'     => array( 'anspruch' => (float) $st->vac_days, 'genommen' => kt_ze_vac_taken( $sid, $y ), 'jahr' => $y ),
			'leaves'  => kt_ze_my_leaves( $sid ),
			'master'  => (bool) $st->is_master,
			'token'   => $st->is_master ? kt_ze_adm_token( $sid ) : '',
		);
	};
	if ( $a === 'scan' ) {
		// Erster Scan des Tages = automatisch "Kommen"; erst danach gibt es die Auswahl
		if ( $state === 'out' && ! (int) $wpdb->get_var( $wpdb->prepare( 'SELECT COUNT(*) FROM ' . kt_ze_t( 'log' ) . ' WHERE staff_id=%d AND ts>=%s', $sid, current_time( 'Y-m-d' ) . ' 00:00:00' ) ) ) {
			$now = current_time( 'mysql' );
			$wpdb->insert( kt_ze_t( 'log' ), array( 'staff_id' => $sid, 'type' => 'kommen', 'ts' => $now, 'edited' => 0 ) );
			list( $state, $last ) = kt_ze_state( $sid );
			return array( 'ok' => true, 'auto' => true, 'done' => 'kommen', 'time' => substr( $now, 11, 5 ), 'name' => $st->name, 'state' => $state );
		}
		return $info();
	}
	if ( $a === 'stamp' ) {
		$t = (string) ( $in['t'] ?? '' );
		if ( ! in_array( $t, kt_ze_allowed( $state ), true ) ) {
			return array( 'ok' => false, 'err' => 'state' ) + $info();
		}
		$now = current_time( 'mysql' );
		$wpdb->insert( kt_ze_t( 'log' ), array( 'staff_id' => $sid, 'type' => $t, 'ts' => $now, 'edited' => 0 ) );
		list( $state, $last ) = kt_ze_state( $sid );
		return array( 'ok' => true, 'done' => $t, 'time' => substr( $now, 11, 5 ), 'name' => $st->name, 'state' => $state, 'today' => kt_ze_today( $sid ) );
	}
	if ( $a === 'overview' ) {
		$cur   = current_time( 'Y-m' );
		$lower = gmdate( 'Y-m', strtotime( $cur . '-01 12:00:00 UTC -24 months' ) );
		$ym    = preg_match( '/^\d{4}-\d{2}$/', (string) ( $in['ym'] ?? '' ) ) ? (string) $in['ym'] : $cur;
		if ( $ym > $cur ) {
			$ym = $cur;
		}
		if ( $ym < $lower ) {
			$ym = $lower;
		}
		list( $rows ) = kt_ze_month_rows( $sid, $ym );
		$today = current_time( 'Y-m-d' );
		$td    = kt_ze_today( $sid );
		$sum   = 0;
		$out   = array();
		foreach ( $rows as $r ) {
			$net   = $r['net'];
			$pause = $r['pause'];
			$secs  = $r['netsec'];
			$note  = $r['note'] ?: ( $r['missing'] ? 'keine Buchung' : '' );
			if ( $r['date'] === $today && $td['any'] ) {
				$net   = $td['net'];
				$pause = $td['pause'];
				$secs  = $td['net_s'];
				$note  = $state !== 'out' ? 'läuft' : $note;
			}
			$sum  += $secs;
			$out[] = array( 'd' => $r['label'], 'k' => $r['in'], 'g' => $r['out'], 'p' => $pause, 'n' => $net, 'h' => $note );
		}
		$y = (int) substr( $ym, 0, 4 );
		return array(
			'ok'     => true,
			'ym'     => $ym,
			'monat'  => mysql2date( 'F Y', $ym . '-01' ),
			'sum'    => kt_ze_hm( $sum ),
			'rows'   => $out,
			'vac'    => array( 'anspruch' => (float) $st->vac_days, 'genommen' => kt_ze_vac_taken( $sid, $y ), 'angefragt' => kt_ze_vac_taken( $sid, $y, 'offen' ), 'jahr' => $y ),
			'leaves' => kt_ze_my_leaves( $sid ),
			'prev'   => $ym > $lower ? gmdate( 'Y-m', strtotime( $ym . '-01 12:00:00 UTC -1 month' ) ) : null,
			'next'   => $ym < $cur ? gmdate( 'Y-m', strtotime( $ym . '-01 12:00:00 UTC +1 month' ) ) : null,
		);
	}
	if ( $a === 'leave' ) {
		$from = (string) ( $in['from'] ?? '' );
		$to   = (string) ( $in['to'] ?? '' );
		$kind = (string) ( $in['kind'] ?? 'urlaub' );
		$note = mb_substr( sanitize_text_field( (string) ( $in['note'] ?? '' ) ), 0, 200 );
		$today = current_time( 'Y-m-d' );
		if ( ! preg_match( '/^\d{4}-\d{2}-\d{2}$/', $from ) || ! preg_match( '/^\d{4}-\d{2}-\d{2}$/', $to ) || $from > $to || $from < $today || ( strtotime( $to ) - strtotime( $from ) ) > 60 * 86400 || ! isset( kt_ze_kinds()[ $kind ] ) ) {
			return array( 'ok' => false, 'err' => 'datum' );
		}
		$wpdb->insert( kt_ze_t( 'leave' ), array( 'staff_id' => $sid, 'd_from' => $from, 'd_to' => $to, 'kind' => $kind, 'note' => $note, 'status' => 'offen', 'created' => current_time( 'mysql' ) ) );
		$days = kt_ze_workdays( $from, $to );
		wp_mail( get_option( 'admin_email' ), 'Urlaubsantrag: ' . $st->name,
			$st->name . ' beantragt ' . kt_ze_kinds()[ $kind ] . ' vom ' . mysql2date( 'd.m.Y', $from ) . ' bis ' . mysql2date( 'd.m.Y', $to ) . " ($days Arbeitstage).\n" . ( $note ? "Bemerkung: $note\n" : '' ) . "\nBearbeiten: " . admin_url( 'admin.php?page=kt-ze&tab=urlaub' ) );
		return array( 'ok' => true, 'days' => $days );
	}
	return array( 'ok' => false, 'err' => 'action' );
}

function kt_ze_my_leaves( $sid ) {
	global $wpdb;
	$rows = $wpdb->get_results( $wpdb->prepare(
		'SELECT d_from,d_to,kind,status FROM ' . kt_ze_t( 'leave' ) . ' WHERE staff_id=%d AND d_to>=%s ORDER BY d_from LIMIT 6',
		$sid, current_time( 'Y-m-d' )
	) );
	$out = array();
	foreach ( $rows as $r ) {
		$out[] = array(
			'from'   => mysql2date( 'd.m.', $r->d_from ),
			'to'     => mysql2date( 'd.m.Y', $r->d_to ),
			'kind'   => kt_ze_kinds()[ $r->kind ] ?? $r->kind,
			'status' => array( 'offen' => 'angefragt', 'genehmigt' => 'bestätigt', 'abgelehnt' => 'abgelehnt' )[ $r->status ] ?? $r->status,
		);
	}
	return $out;
}

/* Master-Sitzung: nach dem Scan der Master-Karte gibt der Server ein Token (5 Min.), das jede Verwaltungsaktion braucht */
function kt_ze_adm_token( $sid ) {
	$tok = wp_generate_password( 24, false );
	set_transient( 'kt_ze_adm_' . $tok, (int) $sid, 300 );
	return $tok;
}

function kt_ze_api_admin( $a, $in ) {
	global $wpdb;
	$tok = preg_replace( '/[^A-Za-z0-9]/', '', (string) ( $in['token'] ?? '' ) );
	$sid = $tok ? (int) get_transient( 'kt_ze_adm_' . $tok ) : 0;
	$m   = $sid ? $wpdb->get_row( $wpdb->prepare( 'SELECT id FROM ' . kt_ze_t( 'staff' ) . ' WHERE id=%d AND is_master=1 AND active=1', $sid ) ) : null;
	if ( ! $m ) {
		return array( 'ok' => false, 'err' => 'token' );
	}
	set_transient( 'kt_ze_adm_' . $tok, $sid, 300 );
	$uid = kt_ze_norm_uid( $in['uid'] ?? '' );
	if ( $a === 'adm_list' ) {
		$rows = $wpdb->get_results( 'SELECT id,name,uid FROM ' . kt_ze_t( 'staff' ) . ' WHERE active=1 ORDER BY name' );
		$out  = array();
		foreach ( $rows as $r ) {
			$out[] = array( 'id' => (int) $r->id, 'name' => $r->name, 'card' => $r->uid !== '' );
		}
		return array( 'ok' => true, 'staff' => $out );
	}
	if ( $a === 'adm_present' ) {
		$rows = $wpdb->get_results( 'SELECT id,name FROM ' . kt_ze_t( 'staff' ) . ' WHERE active=1 ORDER BY name' );
		$out  = array();
		foreach ( $rows as $r ) {
			list( $state, $last ) = kt_ze_state( (int) $r->id );
			$out[] = array( 'name' => $r->name, 'state' => $state, 'since' => ( $last && $state !== 'out' ) ? substr( $last->ts, 11, 5 ) : '' );
		}
		return array( 'ok' => true, 'staff' => $out );
	}
	if ( $a === 'adm_new' || $a === 'adm_repl' ) {
		if ( strlen( $uid ) < 8 ) {
			return array( 'ok' => false, 'err' => 'uid' );
		}
		$id = $a === 'adm_repl' ? (int) ( $in['id'] ?? 0 ) : 0;
		$o  = $wpdb->get_row( $wpdb->prepare( 'SELECT id,name FROM ' . kt_ze_t( 'staff' ) . ' WHERE uid=%s AND active=1 AND id<>%d LIMIT 1', $uid, $id ) );
		if ( $o ) {
			return array( 'ok' => false, 'err' => 'vergeben', 'name' => $o->name );
		}
		if ( $a === 'adm_new' ) {
			$name = mb_substr( sanitize_text_field( (string) ( $in['name'] ?? '' ) ), 0, 80 );
			if ( mb_strlen( $name ) < 2 ) {
				return array( 'ok' => false, 'err' => 'name' );
			}
			$wpdb->insert( kt_ze_t( 'staff' ), array( 'name' => $name, 'uid' => $uid, 'email' => '', 'vac_days' => 30, 'active' => 1, 'is_master' => 0, 'created' => current_time( 'mysql' ) ) );
			delete_option( 'kt_ze_unknown' );
			return array( 'ok' => true, 'name' => $name );
		}
		$st = $wpdb->get_row( $wpdb->prepare( 'SELECT id,name FROM ' . kt_ze_t( 'staff' ) . ' WHERE id=%d AND active=1', $id ) );
		if ( ! $st ) {
			return array( 'ok' => false, 'err' => 'name' );
		}
		$wpdb->update( kt_ze_t( 'staff' ), array( 'uid' => $uid ), array( 'id' => $id ) );
		return array( 'ok' => true, 'name' => $st->name );
	}
	return array( 'ok' => false, 'err' => 'action' );
}

function kt_ze_page() {
	return <<<'KTHTML'
<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<meta name="mobile-web-app-capable" content="yes">
<title>Zeiterfassung</title>
<style>
*{box-sizing:border-box}
html,body{height:100%;margin:0;background:#f2f4f6;color:#1c1c1c;font-family:'Source Sans 3','Source Sans Pro',system-ui,-apple-system,Segoe UI,Arial,sans-serif;font-size:20px;line-height:1.45;-webkit-text-size-adjust:100%;user-select:none;-webkit-user-select:none}
[hidden]{display:none !important}
.app{min-height:100%;display:flex;flex-direction:column}
header{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:16px 26px;background:#fff;border-bottom:1px solid #dde1e6}
header img{height:64px;width:auto;max-width:50%;object-fit:contain}
.clock{text-align:right;font-family:Tahoma,Arial,sans-serif;color:#334155}
.clock b{display:block;font-size:34px;line-height:1.1}
.clock span{font-size:15px;color:#777}
main{flex:1;display:flex;align-items:center;justify-content:center;padding:22px}
.screen{width:100%;max-width:880px;text-align:center}
h1{font-family:Tahoma,Arial,sans-serif;color:#334155;font-size:34px;margin:0 0 6px}
p.sub{color:#555;margin:0 0 20px;font-size:21px}
.nfc{position:relative;width:260px;height:260px;margin:6px auto 18px}
.nfc svg{position:relative;width:100%;height:100%}
.nfc i{position:absolute;inset:18px;border-radius:50%;border:3px solid #334155;opacity:0;animation:pulse 2.8s infinite}
.nfc i:nth-child(2){animation-delay:.9s}.nfc i:nth-child(3){animation-delay:1.8s}
@keyframes pulse{0%{transform:scale(.7);opacity:.45}100%{transform:scale(1.25);opacity:0}}
.warn{background:#fdf3f3;border:1px solid #e3b4ae;color:#8a2c20;border-radius:10px;padding:12px 16px;margin:0 auto 14px;max-width:560px;font-size:18px}
.btn{display:inline-flex;align-items:center;justify-content:center;border:0;border-radius:12px;padding:20px 34px;font-family:Tahoma,Arial,sans-serif;font-weight:700;font-size:26px;cursor:pointer;background:#334155;color:#fff;min-width:230px}
.btn.sec{background:#fff;color:#334155;border:2px solid #334155}
.btn.grn{background:#2f7d4f}.btn.org{background:#b9722a}.btn.red{background:#a8392f}
.btn:active{transform:scale(.98)}
.row{display:flex;gap:18px;justify-content:center;flex-wrap:wrap;margin:14px 0}
.chip{display:inline-block;padding:6px 18px;border-radius:99px;font-weight:700;font-size:19px;margin:0 0 20px}
.chip.out{background:#e5e8ec;color:#475569}.chip.working{background:#d6efdf;color:#1d6a3d}.chip.pause{background:#f6e3c8;color:#8a5414}
footer{padding:14px 26px 22px;text-align:center}
.card{background:#fff;border:1px solid #dde1e6;border-radius:12px;padding:20px 22px;text-align:left}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:14px 18px}
label{display:block;font-size:16px;font-weight:600;color:#334155;margin:0 0 4px}
input,select{width:100%;padding:14px;border:1px solid #c4c4c4;border-radius:8px;font-size:22px;font-family:inherit;background:#fff;color:#1c1c1c}
.full{grid-column:1/-1}
.list{margin:14px 0 0;font-size:17px;color:#444;text-align:left}
.list div{padding:3px 0;border-bottom:1px solid #eceef1}
.ovt{width:100%;border-collapse:collapse;font-size:18px;text-align:left}.ovt th,.ovt td{padding:5px 8px;border-bottom:1px solid #eceef1}.ovt th{color:#555;font-size:15px}.ovt td.n,.ovt th.n{text-align:right}
.btn.sm{min-width:0;padding:8px 22px;font-size:28px}.btn[disabled]{opacity:.35}
.msg-ok h1{color:#1d6a3d}.msg-bad h1{color:#a8392f}
.big{font-size:60px;line-height:1;margin:0 0 8px}
.side{display:flex;position:fixed;left:calc(20% - 70px);bottom:22px;flex-direction:column;align-items:flex-start;gap:6px;width:140px;color:#334155;font-family:Tahoma,Arial,sans-serif;font-weight:700;font-size:26px;line-height:1.2}
.side svg{width:110px;height:110px;animation:nudge 1.4s ease-in-out infinite}
@keyframes nudge{0%,100%{transform:translate(0,0)}50%{transform:translate(0,14px)}}
@media(max-width:700px){.grid{grid-template-columns:1fr}.btn{min-width:0;width:100%}.nfc{width:200px;height:200px}h1{font-size:28px}}
</style>
</head>
<body>
<div class="app">
<header>
<img src="https://kaffeetechniker.de/wp-content/uploads/2026/08/jb-logo-kaffeemaschinen-scaled.png" alt="Joachim Bl&ouml;chle Elektro-Service GmbH">
<div class="clock"><b id="clk">--:--</b><span id="dat"></span></div>
</header>
<main>

<section class="screen" id="s-home">
<div id="warn" class="warn" hidden></div>
<h1 id="h-title">Willkommen</h1>
<p class="sub" id="h-sub">Bitte Karte ans Tablet halten</p>
<p class="sub" id="snd" hidden style="font-size:16px;color:#888">Ton aus: einmal auf den Bildschirm tippen</p>
<div class="nfc"><i></i><i></i><i></i>
<svg viewBox="0 0 260 260" aria-hidden="true">
<g fill="none" stroke="#334155" stroke-width="7" stroke-linecap="round" stroke-linejoin="round">
<rect x="46" y="112" width="168" height="108" rx="16" fill="#fff"/>
<rect x="70" y="140" width="34" height="26" rx="5" fill="#e8c9a0" stroke="#334155" stroke-width="4"/>
<path d="M126 150h64M126 170h44" stroke-width="5" opacity=".45"/>
<path d="M92 82a52 52 0 0 1 76 0"/><path d="M108 62a78 78 0 0 1 44 0" opacity=".7"/><path d="M76 98a76 76 0 0 1 108 0" opacity=".45"/>
</g></svg></div>
<div class="side" aria-hidden="true"><span>Karte hier scannen</span><svg viewBox="0 0 96 96"><path d="M48 12V82M20 54L48 82L76 54" fill="none" stroke="#334155" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/></svg></div>
<div id="h-cancel" hidden><button class="btn sec" id="b-cancel">Abbrechen</button></div>
<div id="h-btn" hidden><button class="btn" id="b-start">Zum Aktivieren tippen</button></div>
</section>

<section class="screen" id="s-act" hidden>
<h1 id="a-name">&nbsp;</h1>
<div class="chip out" id="a-chip">&nbsp;</div>
<div class="sub" id="a-today" hidden></div>
<div class="row" id="a-btns"></div>
</section>

<section class="screen" id="s-leave" hidden>
<h1 id="l-name">Urlaub beantragen</h1>
<p class="sub" id="l-vac"></p>
<div class="card"><div class="grid">
<div><label for="l-from">Von</label><input type="date" id="l-from"></div>
<div><label for="l-to">Bis</label><input type="date" id="l-to"></div>
<div class="full"><label for="l-kind">Art</label><select id="l-kind"></select></div>
<div class="full"><label for="l-note">Bemerkung (optional)</label><input type="text" id="l-note" maxlength="200"></div>
</div>
<div id="l-days" style="margin-top:10px;color:#555"></div>
<div id="l-err" class="warn" hidden style="margin-top:12px"></div>
</div>
<div class="row"><button class="btn sec" id="l-back">Zur&uuml;ck</button><button class="btn grn" id="l-send">Antrag senden</button></div>
<div class="list" id="l-list"></div>
</section>

<section class="screen" id="s-msg" hidden>
<div class="big" id="m-ico"></div>
<h1 id="m-title"></h1>
<p class="sub" id="m-text"></p>
</section>

<section class="screen" id="s-ov" hidden>
<h1 id="ov-h">&Uuml;bersicht</h1>
<div class="row" style="margin:4px 0 8px;align-items:center"><button class="btn sec sm" id="ov-prev">&lsaquo;</button><div class="sub" id="ov-month" style="margin:0;min-width:240px"></div><button class="btn sec sm" id="ov-next">&rsaquo;</button></div>
<div class="row" id="ov-sum" style="margin:6px 0"></div>
<div class="card" style="max-height:36vh;overflow:auto;padding:6px 12px"><table class="ovt" id="ov-tab"></table></div>
<div class="list" id="ov-leaves"></div>
<div class="row"><button class="btn sec" id="ov-back">Zur&uuml;ck</button></div>
</section>
<section class="screen" id="s-adm" hidden>
<h1>Verwaltung</h1>
<p class="sub">Master-Men&uuml;</p>
<div class="row"><button class="btn" id="adm-new">Neuer Mitarbeiter</button><button class="btn" id="adm-repl">Karte ersetzen</button></div>
<div class="row"><button class="btn sec" id="adm-pres">Wer ist da?</button><button class="btn sec" id="adm-back">Zur&uuml;ck</button></div>
</section>
<section class="screen" id="s-name" hidden>
<h1>Neuer Mitarbeiter</h1>
<div class="card"><label for="n-name">Vor- und Nachname</label><input type="text" id="n-name" maxlength="80" autocomplete="off"></div>
<div class="row"><button class="btn sec" id="n-back">Zur&uuml;ck</button><button class="btn grn" id="n-go">Weiter: Karte scannen</button></div>
</section>
<section class="screen" id="s-list" hidden>
<h1 id="li-title"></h1>
<div class="row" id="li-btns"></div>
<div class="row"><button class="btn sec" id="li-back">Zur&uuml;ck</button></div>
</section>
</main>
</div>
<script>
(function(){
var API=location.pathname,$=function(i){return document.getElementById(i);};
var S={mode:'',uid:'',d:null,timer:null,last:0,ac:null,reader:null};
var KIND={urlaub:'Urlaub',sonder:'Sonderurlaub',ueberstunden:'Überstundenausgleich'};
var LBL={kommen:'Kommen',pause_start:'Pause',pause_ende:'Pause beenden',gehen:'Gehen'};
var CLS={kommen:'grn',pause_start:'org',pause_ende:'grn',gehen:'red'};
var CH={out:'Nicht eingestempelt',working:'Eingestempelt',pause:'In der Pause'};
function show(id){['home','act','leave','msg','adm','name','list','ov'].forEach(function(s){$('s-'+s).hidden=(s!==id);});}
function later(ms){clearTimeout(S.timer);S.timer=setTimeout(home,ms);}
function home(){clearTimeout(S.timer);S.uid='';S.mode='';S.token='';S.pend=null;$('h-title').textContent='Willkommen';$('h-sub').textContent='Bitte Karte ans Tablet halten';$('h-cancel').hidden=true;show('home');}
function tick(){var n=new Date();$('clk').textContent=n.toLocaleTimeString('de-DE',{hour:'2-digit',minute:'2-digit'});
 $('dat').textContent=n.toLocaleDateString('de-DE',{weekday:'long',day:'2-digit',month:'long',year:'numeric'});}
setInterval(tick,1000);tick();
function post(o){return fetch(API,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(o),cache:'no-store'}).then(function(r){if(!r.ok)throw new Error('http '+r.status);return r.json();});}
function msg(ico,title,text,cls,ms,snd){beep(snd||(cls==='bad'?'err':'ok'));$('m-ico').textContent=ico;$('m-title').textContent=title;$('m-text').textContent=text||'';
 $('s-msg').className='screen msg-'+cls;show('msg');later(ms||4500);}
function greet(){var h=new Date().getHours();return h<11?'Guten Morgen':(h<18?'Hallo':'Guten Abend');}
function vacText(v){var rest=v.anspruch-v.genommen;return 'Urlaub '+v.jahr+': '+v.genommen+' von '+v.anspruch+' Tagen genommen, Rest '+rest;}
function onUid(uid){
 if(S.mode==='enrol'||S.mode==='replace'){enrol(uid);return;}
 var now=Date.now();if(uid===S.uid&&now-S.last<1500)return;S.last=now;
 post({a:'scan',uid:uid}).then(function(d){
  if(!d.ok){msg(d.unknown?'⚠':'⚠',d.unknown?'Karte nicht zugeordnet':'Fehler',d.unknown?'Bitte beim Chef melden.':'Bitte erneut versuchen.','bad',5000);return;}
  S.uid=uid;
  if(d.auto){msg('✓',greet()+', '+d.name,'Kommen gebucht um '+d.time+' Uhr','ok',4000,'kommen');return;}
  S.d=d;showAct(d);
 }).catch(function(){msg('⚠','Keine Verbindung','Bitte Karte erneut halten oder Internet prüfen.','bad',5000);});
}
function showAct(d){
 $('a-name').textContent=greet()+', '+d.name;
 var c=$('a-chip');c.className='chip '+d.state;c.textContent=CH[d.state]+(d.since?' seit '+d.since+' Uhr':'');
 var td=$('a-today');td.hidden=!d.today.any;td.textContent='Heute gearbeitet: '+d.today.net+' h · Pause: '+d.today.pause+' h';
 var b=$('a-btns');b.innerHTML='';
 d.allowed.forEach(function(t){var x=document.createElement('button');x.className='btn '+CLS[t];x.textContent=LBL[t];x.onclick=function(){stamp(t);};b.appendChild(x);});
 if(d.master){S.token=d.token;var a2=document.createElement('button');a2.className='btn';a2.textContent='Verwaltung';a2.onclick=function(){showAdm();};b.appendChild(a2);}
 var ov=document.createElement('button');ov.className='btn sec';ov.textContent='Meine Übersicht';ov.onclick=function(){showOv('');};b.appendChild(ov);
 var u=document.createElement('button');u.className='btn sec';u.textContent='Urlaub beantragen';u.onclick=function(){showLeave(S.d);};b.appendChild(u);
 var x=document.createElement('button');x.className='btn sec';x.textContent='Abbrechen';x.onclick=home;b.appendChild(x);
 show('act');later(14000);
}
function stamp(t){
 var btns=$('a-btns').querySelectorAll('button');for(var i=0;i<btns.length;i++)btns[i].disabled=true;
 post({a:'stamp',uid:S.uid,t:t}).then(function(r){
  if(!r.ok){if(r.name||r.allowed){showAct(r);}else{msg('⚠','Nicht möglich','Bitte Karte erneut halten.','bad');}return;}
  var txt={kommen:'Kommen gebucht um ',pause_start:'Pause gestartet um ',pause_ende:'Pause beendet um ',gehen:'Gehen gebucht um '}[r.done]+r.time+' Uhr'+(r.done==='gehen'||r.done==='pause_start'?'. Heute gearbeitet: '+r.today.net+' h':'');
  msg(r.done==='gehen'?'👋':'✓',r.done==='gehen'?'Schönen Feierabend, '+r.name:'Danke, '+r.name,txt,'ok',4000,r.done);
 }).catch(function(){msg('⚠','Keine Verbindung','Buchung wurde NICHT gespeichert. Bitte erneut versuchen.','bad',6000);});
}
/* Urlaub */
var kinds=$('l-kind');Object.keys(KIND).forEach(function(k){var o=document.createElement('option');o.value=k;o.textContent=KIND[k];kinds.appendChild(o);});
function iso(d){return d.getFullYear()+'-'+('0'+(d.getMonth()+1)).slice(-2)+'-'+('0'+d.getDate()).slice(-2);}
function showLeave(d){
 $('l-name').textContent='Urlaub beantragen – '+d.name;$('l-vac').textContent=vacText(d.vac);
 var t=iso(new Date());$('l-from').min=t;$('l-to').min=t;$('l-from').value=t;$('l-to').value=t;$('l-note').value='';$('l-err').hidden=true;
 var L=$('l-list');L.innerHTML='';
 if(d.leaves.length){var h=document.createElement('div');h.innerHTML='<b>Ihre Anträge</b>';L.appendChild(h);
  d.leaves.forEach(function(x){var r=document.createElement('div');r.textContent=x.from+' – '+x.to+'  ·  '+x.kind+'  ·  '+x.status;L.appendChild(r);});}
 show('leave');later(120000);
}
$('l-from').onchange=function(){if($('l-to').value<$('l-from').value)$('l-to').value=$('l-from').value;$('l-to').min=$('l-from').value;};
$('l-back').onclick=home;
$('l-send').onclick=function(){
 $('l-send').disabled=true;
 post({a:'leave',uid:S.uid,from:$('l-from').value,to:$('l-to').value,kind:kinds.value,note:$('l-note').value}).then(function(r){
  $('l-send').disabled=false;
  if(!r.ok){$('l-err').textContent='Bitte Zeitraum prüfen (Datum nicht in der Vergangenheit, höchstens 60 Tage).';$('l-err').hidden=false;return;}
  msg('✓','Antrag gesendet',r.days+' Arbeitstag'+(r.days===1?'':'e')+' beantragt. Sie bekommen Bescheid.','ok',5000);
 }).catch(function(){$('l-send').disabled=false;$('l-err').textContent='Keine Verbindung. Bitte erneut versuchen.';$('l-err').hidden=false;});
};
/* Uebersicht */
function showOv(ym){later(60000);
 post({a:'overview',uid:S.uid,ym:ym||''}).then(function(r){
  if(!r.ok){msg('\u26A0','Nicht m\u00f6glich','Bitte Karte erneut halten.','bad',5000);return;}
  $('ov-h').textContent='\u00dcbersicht \u2013 '+S.d.name;$('ov-month').textContent=r.monat;
  $('ov-prev').disabled=!r.prev;$('ov-prev').onclick=function(){if(r.prev)showOv(r.prev);};
  $('ov-next').disabled=!r.next;$('ov-next').onclick=function(){if(r.next)showOv(r.next);};
  var s=$('ov-sum');s.innerHTML='';
  [['working','Gearbeitet: '+r.sum+' h'],['out','Urlaub '+r.vac.jahr+': '+r.vac.genommen+' von '+r.vac.anspruch+' Tagen bestätigt, Rest '+(r.vac.anspruch-r.vac.genommen)+(r.vac.angefragt?' (angefragt: '+r.vac.angefragt+')':'')]].forEach(function(c){var e=document.createElement('div');e.className='chip '+c[0];e.textContent=c[1];s.appendChild(e);});
  var t=$('ov-tab');t.innerHTML='<tr><th>Tag</th><th class="n">Kommen</th><th class="n">Gehen</th><th class="n">Pause</th><th class="n">Netto</th><th></th></tr>';
  r.rows.forEach(function(x){var tr=document.createElement('tr');[x.d,x.k,x.g,x.p,x.n,x.h].forEach(function(v,i){var td=document.createElement('td');td.textContent=v;if(i>=1&&i<=4)td.className='n';tr.appendChild(td);});t.appendChild(tr);});
  if(!r.rows.length){var e0=document.createElement('tr');e0.innerHTML='<td colspan="6">Keine Eintr\u00e4ge in diesem Monat.</td>';t.appendChild(e0);}
  var L=$('ov-leaves');L.innerHTML='';
  if(r.leaves.length){var h=document.createElement('div');h.innerHTML='<b>Ihr Urlaub</b>';L.appendChild(h);r.leaves.forEach(function(x){var e=document.createElement('div');e.textContent=x.from+' \u2013 '+x.to+'  \u00b7  '+x.kind+'  \u00b7  '+x.status;L.appendChild(e);});}
  show('ov');
 }).catch(function(){msg('\u26A0','Keine Verbindung','Bitte erneut versuchen.','bad',5000);});}
$('ov-back').onclick=function(){showAct(S.d);};
/* Ton */
var AC=null;
function audio(){try{if(!AC)AC=new (window.AudioContext||window.webkitAudioContext)();if(AC.state==='suspended')AC.resume();}catch(e){}}
['click','touchstart','keydown'].forEach(function(ev){document.addEventListener(ev,audio,{passive:true});});
function tone(f,t0,d,type,vol){var o=AC.createOscillator(),g=AC.createGain();o.type=type||'sine';o.frequency.value=f;
 g.gain.setValueAtTime(0.0001,AC.currentTime+t0);g.gain.exponentialRampToValueAtTime(vol||0.35,AC.currentTime+t0+0.02);g.gain.exponentialRampToValueAtTime(0.0001,AC.currentTime+t0+d);
 o.connect(g);g.connect(AC.destination);o.start(AC.currentTime+t0);o.stop(AC.currentTime+t0+d+0.05);}
var TON=(new URLSearchParams(location.search)).get('ton')||'windows';
function clack(v){var n=Math.floor(AC.sampleRate*0.04),b=AC.createBuffer(1,n,AC.sampleRate),d=b.getChannelData(0);for(var i=0;i<n;i++)d[i]=(Math.random()*2-1)*(1-i/n);var q=AC.createBufferSource();q.buffer=b;var g=AC.createGain();g.gain.value=v||0.5;var f=AC.createBiquadFilter();f.type='highpass';f.frequency.value=1500;q.connect(f);f.connect(g);g.connect(AC.destination);q.start();}
function bell(f,t0,d,v){v=v||0.3;tone(f,t0,d*2,'sine',v);tone(f*2.76,t0,d,'sine',v*0.33);tone(f*5.4,t0,d*0.5,'sine',v*0.13);}
function pluck(f,t0,v){tone(f,t0,0.3,'triangle',v||0.4);tone(f*4,t0,0.07,'sine',0.12);}
function sweep(f1,f2,t0,d,v){var o=AC.createOscillator(),g=AC.createGain();o.type='sine';o.frequency.setValueAtTime(f1,AC.currentTime+t0);o.frequency.exponentialRampToValueAtTime(f2,AC.currentTime+t0+d);
 g.gain.setValueAtTime(0.0001,AC.currentTime+t0);g.gain.exponentialRampToValueAtTime(v||0.2,AC.currentTime+t0+0.015);g.gain.exponentialRampToValueAtTime(0.0001,AC.currentTime+t0+d+0.02);
 o.connect(g);g.connect(AC.destination);o.start(AC.currentTime+t0);o.stop(AC.currentTime+t0+d+0.05);}
function bling(f,t0,v){v=v||0.28;tone(f,t0,0.5,'sine',v);tone(f*2,t0,0.28,'sine',v*0.35);tone(f*3,t0,0.14,'sine',v*0.15);}
function wding(f,t0,v){v=v||0.35;tone(f,t0,0.32,'sine',v);tone(f*2,t0,0.14,'sine',v*0.2);tone(f*0.5,t0,0.05,'sine',v*0.12);}
var SETS={
 windows:{ok:function(){wding(1175,0);},gehen:function(){wding(880,0);},pause_start:function(){wding(1047,0,0.3);},err:function(){tone(330,0,0.2,'triangle',0.3);tone(247,0.2,0.3,'triangle',0.3);}},
 bling:{ok:function(){sweep(900,1800,0,0.09,0.2);bling(2093,0.09);},gehen:function(){bling(1760,0);sweep(1700,850,0.14,0.1,0.18);},pause_start:function(){sweep(1100,1700,0,0.07,0.18);bling(1568,0.07,0.24);},err:function(){tone(196,0,0.25,'triangle',0.3);tone(147,0.28,0.4,'triangle',0.3);}},
 klassisch:{ok:function(){tone(660,0,0.13);tone(990,0.15,0.2);},gehen:function(){tone(880,0,0.13);tone(660,0.15,0.2);},pause_start:function(){tone(740,0,0.2);},err:function(){tone(220,0,0.18,'square',0.25);tone(180,0.22,0.3,'square',0.25);}},
 glocke:{ok:function(){bell(784,0,0.4);bell(1175,0.2,0.5);},gehen:function(){bell(1175,0,0.4);bell(784,0.2,0.5);},pause_start:function(){bell(880,0,0.5);},err:function(){tone(196,0,0.25,'triangle',0.3);tone(147,0.28,0.4,'triangle',0.3);}},
 xylo:{ok:function(){pluck(523,0);pluck(659,0.1);pluck(784,0.2);},gehen:function(){pluck(784,0);pluck(659,0.1);pluck(523,0.2);},pause_start:function(){pluck(659,0);pluck(659,0.14);},err:function(){pluck(196,0,0.5);pluck(165,0.18,0.5);}},
 arcade:{ok:function(){tone(880,0,0.07,'square',0.15);tone(1320,0.08,0.12,'square',0.15);},gehen:function(){tone(1320,0,0.07,'square',0.15);tone(880,0.08,0.12,'square',0.15);},pause_start:function(){tone(1100,0,0.1,'square',0.15);},err:function(){tone(150,0,0.3,'sawtooth',0.2);}},
 stempel:{ok:function(){clack(0.6);bell(1568,0.08,0.3,0.25);},gehen:function(){clack(0.6);bell(1047,0.08,0.3,0.25);},pause_start:function(){clack(0.6);bell(784,0.08,0.25,0.2);},err:function(){clack(0.7);tone(110,0.1,0.35,'sawtooth',0.2);}}
};
function beep(k,set){try{audio();if(!AC||AC.state!=='running')return;
 var st=SETS[set||TON]||SETS.klassisch;(k==='err'?st.err:(k==='gehen'?st.gehen:(k==='pause_start'?st.pause_start:st.ok)))();}catch(e){}}
if(TON==='test'){var tp=document.createElement('div');tp.style.cssText='margin:14px 0;text-align:left;max-width:700px;margin-left:auto;margin-right:auto';
 Object.keys(SETS).forEach(function(n){var r=document.createElement('div');r.style.cssText='display:flex;gap:8px;align-items:center;margin:6px 0;flex-wrap:wrap';var l=document.createElement('b');l.textContent=n;l.style.minWidth='100px';r.appendChild(l);
  [['ok','Kommen'],['gehen','Gehen'],['pause_start','Pause'],['err','Fehler']].forEach(function(x){var b=document.createElement('button');b.className='btn sec sm';b.style.fontSize='18px';b.textContent=x[1];b.onclick=function(){beep(x[0],n);};r.appendChild(b);});tp.appendChild(r);});
 $('s-home').appendChild(tp);}
setInterval(function(){$('snd').hidden=!!(AC&&AC.state==='running');},1500);
/* Master-Verwaltung */
function showAdm(){later(90000);show('adm');}
$('adm-back').onclick=function(){showAct(S.d);};
$('adm-new').onclick=function(){$('n-name').value='';later(90000);show('name');setTimeout(function(){$('n-name').focus();},100);};
$('n-back').onclick=showAdm;
$('n-go').onclick=function(){var n=$('n-name').value.trim();if(n.length<2){$('n-name').focus();return;}
 S.mode='enrol';S.pend={name:n};$('h-title').textContent='Neue Karte scannen';$('h-sub').textContent='Karte f\u00fcr '+n+' jetzt ans Tablet halten';$('h-cancel').hidden=false;show('home');later(60000);};
$('b-cancel').onclick=function(){var t=S.token,d=S.d;home();if(t&&d){S.token=t;S.d=d;showAdm();}};
function liste(titel,fn){later(90000);$('li-title').textContent=titel;$('li-btns').innerHTML='Lade \u2026';show('list');
 post({a:'adm_list',token:S.token}).then(function(r){
  if(!r.ok){msg('\u26A0','Sitzung abgelaufen','Bitte Master-Karte erneut scannen.','bad',5000);return;}
  var b=$('li-btns');b.innerHTML='';r.staff.forEach(function(x){var e=document.createElement('button');e.className='btn sec';e.textContent=x.name+(x.card?'':' (keine Karte)');e.onclick=function(){fn(x);};b.appendChild(e);});
 }).catch(function(){msg('\u26A0','Keine Verbindung','Bitte erneut versuchen.','bad',5000);});}
$('adm-repl').onclick=function(){liste('F\u00fcr wen ist die neue Karte?',function(x){S.mode='replace';S.pend={id:x.id,name:x.name};
 $('h-title').textContent='Neue Karte scannen';$('h-sub').textContent='Neue Karte f\u00fcr '+x.name+' jetzt ans Tablet halten';$('h-cancel').hidden=false;show('home');later(60000);});};
$('adm-pres').onclick=function(){later(90000);$('li-title').textContent='Wer ist da?';$('li-btns').innerHTML='Lade \u2026';show('list');
 post({a:'adm_present',token:S.token}).then(function(r){
  if(!r.ok){msg('\u26A0','Sitzung abgelaufen','Bitte Master-Karte erneut scannen.','bad',5000);return;}
  var b=$('li-btns');b.innerHTML='';var T={out:'nicht da',working:'da seit ',pause:'Pause seit '};
  r.staff.forEach(function(x){var e=document.createElement('div');e.className='chip '+x.state;e.textContent=x.name+': '+T[x.state]+(x.since||'');b.appendChild(e);});
 }).catch(function(){msg('\u26A0','Keine Verbindung','Bitte erneut versuchen.','bad',5000);});};
$('li-back').onclick=showAdm;
function enrol(uid){
 var o=S.mode==='enrol'?{a:'adm_new',name:S.pend.name}:{a:'adm_repl',id:S.pend.id};o.token=S.token;o.uid=uid;var nm=S.pend.name;
 post(o).then(function(r){
  if(!r.ok){var t=r.err==='vergeben'?['Karte schon vergeben','Diese Karte geh\u00f6rt '+r.name+'.']:(r.err==='token'?['Sitzung abgelaufen','Bitte Master-Karte erneut scannen.']:['Nicht m\u00f6glich','Bitte erneut versuchen.']);
   S.mode='';msg('\u26A0',t[0],t[1],'bad',6000);return;}
  msg('\u2713','Karte zugeordnet',nm+' kann jetzt stempeln.','ok',5000);
 }).catch(function(){S.mode='';msg('\u26A0','Keine Verbindung','Nichts gespeichert. Bitte erneut versuchen.','bad',6000);});}
/* NFC */
function wake(){try{navigator.wakeLock&&navigator.wakeLock.request('screen').catch(function(){});}catch(e){}}
function warn(t,btn){var w=$('warn');w.textContent=t;w.hidden=!t;$('h-btn').hidden=!btn;}
async function startNfc(){
 if(!('NDEFReader' in window)){warn('NFC nicht verfügbar: bitte Chrome auf dem Android-Tablet verwenden.',false);return;}
 try{
  if(S.ac)S.ac.abort();S.ac=new AbortController();
  var r=new NDEFReader();await r.scan({signal:S.ac.signal});
  r.onreading=function(e){onUid(e.serialNumber);};
  warn('',false);wake();
 }catch(e){warn('NFC ist noch nicht aktiv ('+e.name+'). Bitte tippen, dann die Berechtigung erlauben.',true);}
}
$('b-start').onclick=startNfc;
document.addEventListener('click',function(){var e=document.documentElement;if(!document.fullscreenElement&&e.requestFullscreen)e.requestFullscreen().catch(function(){});});
document.addEventListener('visibilitychange',function(){if(document.visibilityState==='visible')startNfc();});
startNfc();home();
})();
</script>
</body>
</html>
KTHTML;
}

/* ---------- Backend ---------- */

add_action( 'admin_menu', function () {
	add_menu_page( 'Zeiterfassung', 'Zeiterfassung', 'manage_options', 'kt-ze', 'kt_ze_admin_page', 'dashicons-clock', 58 );
} );

function kt_ze_dt( $v ) {
	$v = str_replace( 'T', ' ', (string) $v );
	return preg_match( '/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}/', $v ) ? substr( $v, 0, 16 ) . ':00' : '';
}

add_action( 'admin_init', function () {
	if ( empty( $_POST['kt_ze_act'] ) || ! current_user_can( 'manage_options' ) ) {
		return;
	}
	check_admin_referer( 'kt_ze' );
	global $wpdb;
	$act  = sanitize_key( $_POST['kt_ze_act'] );
	$tab  = sanitize_key( $_POST['tab'] ?? 'monat' );
	$args = array();
	foreach ( array( 'ym', 'sid' ) as $k ) {
		if ( isset( $_POST[ $k ] ) ) {
			$args[ $k ] = sanitize_text_field( wp_unslash( $_POST[ $k ] ) );
		}
	}
	$m = 'ok';
	if ( $act === 'staff_save' ) {
		$id  = (int) ( $_POST['id'] ?? 0 );
		$uid = kt_ze_norm_uid( $_POST['uid'] ?? '' );
		$d   = array(
			'name'     => sanitize_text_field( wp_unslash( $_POST['name'] ?? '' ) ),
			'uid'      => $uid,
			'email'    => sanitize_email( wp_unslash( $_POST['email'] ?? '' ) ),
			'vac_days' => (float) str_replace( ',', '.', (string) ( $_POST['vac_days'] ?? 0 ) ),
			'active'   => empty( $_POST['active'] ) ? 0 : 1,
			'is_master' => empty( $_POST['is_master'] ) ? 0 : 1,
		);
		$dupe = $uid ? (int) $wpdb->get_var( $wpdb->prepare( 'SELECT id FROM ' . kt_ze_t( 'staff' ) . ' WHERE uid=%s AND id<>%d AND active=1 LIMIT 1', $uid, $id ) ) : 0;
		if ( $d['name'] === '' ) {
			$m = 'noname';
		} elseif ( $dupe && $d['active'] ) {
			$m = 'dupe';
		} elseif ( $id ) {
			$wpdb->update( kt_ze_t( 'staff' ), $d, array( 'id' => $id ) );
		} else {
			$d['created'] = current_time( 'mysql' );
			$wpdb->insert( kt_ze_t( 'staff' ), $d );
			delete_option( 'kt_ze_unknown' );
		}
	} elseif ( $act === 'log_save' ) {
		$id = (int) ( $_POST['id'] ?? 0 );
		$ts = kt_ze_dt( $_POST['ts'] ?? '' );
		$t  = sanitize_key( $_POST['type'] ?? '' );
		$sid = (int) ( $_POST['staff'] ?? 0 );
		if ( ! $ts || ! isset( kt_ze_types()[ $t ] ) || ! $sid ) {
			$m = 'bad';
		} elseif ( $id ) {
			$wpdb->update( kt_ze_t( 'log' ), array( 'type' => $t, 'ts' => $ts, 'edited' => 1 ), array( 'id' => $id ) );
		} else {
			$wpdb->insert( kt_ze_t( 'log' ), array( 'staff_id' => $sid, 'type' => $t, 'ts' => $ts, 'edited' => 1 ) );
		}
	} elseif ( $act === 'log_del' ) {
		$wpdb->delete( kt_ze_t( 'log' ), array( 'id' => (int) ( $_POST['id'] ?? 0 ) ) );
	} elseif ( $act === 'leave_set' ) {
		$id = (int) ( $_POST['id'] ?? 0 );
		$s  = sanitize_key( $_POST['status'] ?? '' );
		if ( in_array( $s, array( 'offen', 'genehmigt', 'abgelehnt' ), true ) ) {
			$wpdb->update( kt_ze_t( 'leave' ), array( 'status' => $s ), array( 'id' => $id ) );
			$r = $wpdb->get_row( $wpdb->prepare( 'SELECT l.*,s.email,s.name FROM ' . kt_ze_t( 'leave' ) . ' l JOIN ' . kt_ze_t( 'staff' ) . ' s ON s.id=l.staff_id WHERE l.id=%d', $id ) );
			if ( $r && $r->email && $s !== 'offen' ) {
				wp_mail( $r->email, 'Ihr Urlaubsantrag wurde ' . $s,
					'Hallo ' . $r->name . ",\n\nIhr Antrag (" . ( kt_ze_kinds()[ $r->kind ] ?? $r->kind ) . ' vom ' . mysql2date( 'd.m.Y', $r->d_from ) . ' bis ' . mysql2date( 'd.m.Y', $r->d_to ) . ') wurde ' . $s . ".\n\nJoachim Blöchle Elektro-Service GmbH" );
			}
		}
	} elseif ( $act === 'leave_del' ) {
		$wpdb->delete( kt_ze_t( 'leave' ), array( 'id' => (int) ( $_POST['id'] ?? 0 ) ) );
	} elseif ( $act === 'leave_add' ) {
		$sid  = (int) ( $_POST['staff'] ?? 0 );
		$from = sanitize_text_field( $_POST['d_from'] ?? '' );
		$to   = sanitize_text_field( $_POST['d_to'] ?? '' );
		$kind = sanitize_key( $_POST['kind'] ?? 'urlaub' );
		if ( ! $sid || ! preg_match( '/^\d{4}-\d{2}-\d{2}$/', $from ) || ! preg_match( '/^\d{4}-\d{2}-\d{2}$/', $to ) || $from > $to || ! isset( kt_ze_kinds()[ $kind ] ) ) {
			$m = 'bad';
		} else {
			$wpdb->insert( kt_ze_t( 'leave' ), array( 'staff_id' => $sid, 'd_from' => $from, 'd_to' => $to, 'kind' => $kind, 'note' => mb_substr( sanitize_text_field( wp_unslash( $_POST['note'] ?? '' ) ), 0, 200 ), 'status' => 'genehmigt', 'created' => current_time( 'mysql' ) ) );
		}
	}
	wp_safe_redirect( add_query_arg( array_merge( array( 'page' => 'kt-ze', 'tab' => $tab, 'm' => $m ), $args ), admin_url( 'admin.php' ) ) );
	exit;
} );

/* Auswertung eines Monats fuer einen Mitarbeiter */
function kt_ze_month( $sid, $ym ) {
	global $wpdb;
	$from = "$ym-01 00:00:00";
	$to   = gmdate( 'Y-m-t 23:59:59', strtotime( "$ym-01 12:00:00 UTC" ) );
	$rows = $wpdb->get_results( $wpdb->prepare( 'SELECT * FROM ' . kt_ze_t( 'log' ) . ' WHERE staff_id=%d AND ts BETWEEN %s AND %s ORDER BY ts,id', $sid, $from, $to ) );
	$days = array();
	foreach ( $rows as $r ) {
		$days[ substr( $r->ts, 0, 10 ) ][] = $r;
	}
	$today = current_time( 'Y-m-d' );
	$out   = array();
	foreach ( $days as $d => $list ) {
		$net = 0; $pause = 0; $ws = null; $ps = null; $first = null; $last = null; $edited = false;
		foreach ( $list as $r ) {
			$t = strtotime( $r->ts );
			if ( $r->edited ) {
				$edited = true;
			}
			if ( $r->type === 'kommen' ) {
				if ( $first === null ) { $first = $t; }
				$ws = $t;
			} elseif ( $r->type === 'pause_ende' ) {
				if ( $ps !== null ) { $pause += $t - $ps; $ps = null; }
				$ws = $t;
			} elseif ( $r->type === 'pause_start' ) {
				if ( $ws !== null ) { $net += $t - $ws; $ws = null; }
				$ps = $t;
			} elseif ( $r->type === 'gehen' ) {
				if ( $ws !== null ) { $net += $t - $ws; $ws = null; }
				if ( $ps !== null ) { $pause += $t - $ps; $ps = null; }
				$last = $t;
			}
		}
		$out[ $d ] = array( 'net' => $net, 'pause' => $pause, 'first' => $first, 'last' => $last, 'edited' => $edited, 'open' => ( $ws !== null || $ps !== null ) && $d !== $today, 'list' => $list );
	}
	return $out;
}

function kt_ze_month_leaves( $sid, $ym ) {
	global $wpdb;
	$first = "$ym-01";
	$last  = gmdate( 'Y-m-t', strtotime( "$ym-01 12:00:00 UTC" ) );
	$rows  = $wpdb->get_results( $wpdb->prepare( 'SELECT * FROM ' . kt_ze_t( 'leave' ) . " WHERE staff_id=%d AND status='genehmigt' AND d_to>=%s AND d_from<=%s", $sid, $first, $last ) );
	$map = array();
	foreach ( $rows as $r ) {
		$t = strtotime( $r->d_from . ' 12:00:00 UTC' );
		$e = strtotime( $r->d_to . ' 12:00:00 UTC' );
		for ( ; $t <= $e; $t += 86400 ) {
			$map[ gmdate( 'Y-m-d', $t ) ] = kt_ze_kinds()[ $r->kind ] ?? $r->kind;
		}
	}
	return $map;
}

/* Zeilen fuer Monatsansicht und CSV: [datum, kommen, gehen, pause, netto, hinweis, netto_sek] */
function kt_ze_month_rows( $sid, $ym ) {
	$data   = kt_ze_month( $sid, $ym );
	$leaves = kt_ze_month_leaves( $sid, $ym );
	$hol    = kt_ze_holidays( (int) substr( $ym, 0, 4 ) );
	$n      = (int) gmdate( 't', strtotime( "$ym-01 12:00:00 UTC" ) );
	$wd     = array( 1 => 'Mo', 2 => 'Di', 3 => 'Mi', 4 => 'Do', 5 => 'Fr', 6 => 'Sa', 7 => 'So' );
	$rows   = array();
	for ( $i = 1; $i <= $n; $i++ ) {
		$d  = sprintf( '%s-%02d', $ym, $i );
		$ts = strtotime( "$d 12:00:00 UTC" );
		$x  = $data[ $d ] ?? null;
		$note = array();
		if ( isset( $hol[ $d ] ) ) { $note[] = $hol[ $d ]; }
		if ( isset( $leaves[ $d ] ) ) { $note[] = $leaves[ $d ]; }
		if ( $x && $x['open'] ) { $note[] = 'Gehen fehlt'; }
		if ( $x && $x['edited'] ) { $note[] = 'korrigiert'; }
		$weekend = (int) gmdate( 'N', $ts ) > 5;
		if ( ! $x && ! $note && $weekend ) {
			continue;
		}
		$rows[] = array(
			'date'   => $d,
			'label'  => $wd[ (int) gmdate( 'N', $ts ) ] . ' ' . gmdate( 'd.m.', $ts ),
			'in'     => $x && $x['first'] ? gmdate( 'H:i', $x['first'] ) : '',
			'out'    => $x && $x['last'] ? gmdate( 'H:i', $x['last'] ) : '',
			'pause'  => $x ? kt_ze_hm( $x['pause'] ) : '',
			'net'    => $x ? kt_ze_hm( $x['net'] ) : '',
			'netsec' => $x ? $x['net'] : 0,
			'note'   => implode( ', ', $note ),
			'missing' => ! $x && ! $note && ! $weekend && $d < current_time( 'Y-m-d' ),
		);
	}
	return array( $rows, $data );
}

add_action( 'admin_post_kt_ze_csv', function () {
	if ( ! current_user_can( 'manage_options' ) ) {
		wp_die( 'Keine Berechtigung' );
	}
	check_admin_referer( 'kt_ze_csv' );
	global $wpdb;
	$ym = preg_match( '/^\d{4}-\d{2}$/', $_GET['ym'] ?? '' ) ? $_GET['ym'] : current_time( 'Y-m' );
	$only = (int) ( $_GET['sid'] ?? 0 );
	$staff = $wpdb->get_results( 'SELECT id,name FROM ' . kt_ze_t( 'staff' ) . ( $only ? $wpdb->prepare( ' WHERE id=%d', $only ) : '' ) . ' ORDER BY name' );
	nocache_headers();
	header( 'Content-Type: text/csv; charset=utf-8' );
	header( 'Content-Disposition: attachment; filename="zeiterfassung-' . $ym . '.csv"' );
	echo "\xEF\xBB\xBF";
	$f = fopen( 'php://output', 'w' );
	fputcsv( $f, array( 'Mitarbeiter', 'Datum', 'Kommen', 'Gehen', 'Pause (h:mm)', 'Netto (h:mm)', 'Netto (Dezimal)', 'Hinweis' ), ';' );
	foreach ( $staff as $s ) {
		list( $rows ) = kt_ze_month_rows( (int) $s->id, $ym );
		$sum = 0;
		foreach ( $rows as $r ) {
			$sum += $r['netsec'];
			fputcsv( $f, array( $s->name, mysql2date( 'd.m.Y', $r['date'] ), $r['in'], $r['out'], $r['pause'], $r['net'], $r['netsec'] ? str_replace( '.', ',', (string) round( $r['netsec'] / 3600, 2 ) ) : '', $r['note'] ), ';' );
		}
		fputcsv( $f, array( $s->name, 'Summe', '', '', '', kt_ze_hm( $sum ), str_replace( '.', ',', (string) round( $sum / 3600, 2 ) ), '' ), ';' );
	}
	fclose( $f );
	exit;
} );

function kt_ze_hidden( $act, $extra = array() ) {
	$h = wp_nonce_field( 'kt_ze', '_wpnonce', true, false ) . '<input type="hidden" name="kt_ze_act" value="' . esc_attr( $act ) . '">';
	foreach ( $extra as $k => $v ) {
		$h .= '<input type="hidden" name="' . esc_attr( $k ) . '" value="' . esc_attr( $v ) . '">';
	}
	return $h;
}

function kt_ze_admin_page() {
	if ( ! current_user_can( 'manage_options' ) ) {
		return;
	}
	global $wpdb;
	$tab   = sanitize_key( $_GET['tab'] ?? 'monat' );
	$tabs  = array( 'monat' => 'Monat &amp; Buchungen', 'mitarbeiter' => 'Mitarbeiter &amp; Karten', 'urlaub' => 'Urlaub' );
	$staff = $wpdb->get_results( 'SELECT * FROM ' . kt_ze_t( 'staff' ) . ' ORDER BY active DESC,name' );
	$msgs  = array( 'ok' => array( 'updated', 'Gespeichert.' ), 'dupe' => array( 'error', 'Diese Karte ist schon einem anderen aktiven Mitarbeiter zugeordnet.' ), 'noname' => array( 'error', 'Bitte einen Namen eingeben.' ), 'bad' => array( 'error', 'Eingabe unvollständig oder ungültig.' ) );
	echo '<div class="wrap"><h1>Zeiterfassung</h1>';
	if ( isset( $_GET['m'], $msgs[ $_GET['m'] ] ) ) {
		echo '<div class="notice notice-' . ( $msgs[ $_GET['m'] ][0] === 'updated' ? 'success' : 'error' ) . ' is-dismissible"><p>' . esc_html( $msgs[ $_GET['m'] ][1] ) . '</p></div>';
	}
	echo '<h2 class="nav-tab-wrapper">';
	foreach ( $tabs as $k => $l ) {
		echo '<a class="nav-tab' . ( $k === $tab ? ' nav-tab-active' : '' ) . '" href="' . esc_url( admin_url( 'admin.php?page=kt-ze&tab=' . $k ) ) . '">' . $l . '</a>';
	}
	echo '</h2>';
	if ( $tab === 'mitarbeiter' ) {
		kt_ze_tab_staff( $staff );
	} elseif ( $tab === 'urlaub' ) {
		kt_ze_tab_leave( $staff );
	} else {
		kt_ze_tab_month( $staff );
	}
	echo '<p style="color:#666;margin-top:24px">Tablet-Adresse: <code>' . esc_html( home_url( '/' . KT_ZE_SLUG . '/' ) ) . '</code> (nicht verlinkt, nur im Laden-Tablet öffnen). Urlaubstage = Mo–Fr ohne hessische Feiertage.</p></div>';
}

function kt_ze_tab_month( $staff ) {
	global $wpdb;
	$ym  = preg_match( '/^\d{4}-\d{2}$/', $_GET['ym'] ?? '' ) ? $_GET['ym'] : current_time( 'Y-m' );
	$active = array_values( array_filter( $staff, function ( $s ) { return $s->active; } ) );
	$sid = (int) ( $_GET['sid'] ?? ( $active ? $active[0]->id : 0 ) );
	$prev = gmdate( 'Y-m', strtotime( "$ym-01 12:00:00 UTC -1 month" ) );
	$next = gmdate( 'Y-m', strtotime( "$ym-01 12:00:00 UTC +1 month" ) );
	$base = admin_url( 'admin.php?page=kt-ze&tab=monat&sid=' . $sid . '&ym=' );
	echo '<form method="get" style="margin:14px 0"><input type="hidden" name="page" value="kt-ze"><input type="hidden" name="tab" value="monat">';
	echo '<select name="sid">';
	foreach ( $staff as $s ) {
		echo '<option value="' . (int) $s->id . '"' . selected( $sid, (int) $s->id, false ) . '>' . esc_html( $s->name . ( $s->active ? '' : ' (inaktiv)' ) ) . '</option>';
	}
	echo '</select> <input type="month" name="ym" value="' . esc_attr( $ym ) . '"> <button class="button">Anzeigen</button> ';
	echo '<a class="button" href="' . esc_url( $base . $prev ) . '">&laquo; Vormonat</a> <a class="button" href="' . esc_url( $base . $next ) . '">Folgemonat &raquo;</a> ';
	$csv = wp_nonce_url( admin_url( 'admin-post.php?action=kt_ze_csv&ym=' . $ym ), 'kt_ze_csv' );
	echo '<a class="button button-primary" href="' . esc_url( $csv ) . '">CSV alle Mitarbeiter</a> <a class="button" href="' . esc_url( $csv . '&sid=' . $sid ) . '">CSV dieser Mitarbeiter</a></form>';
	if ( ! $sid ) {
		echo '<p>Noch keine Mitarbeiter angelegt – bitte zuerst im Reiter „Mitarbeiter &amp; Karten“ anlegen.</p>';
		return;
	}
	list( $rows, $data ) = kt_ze_month_rows( $sid, $ym );
	$sum = 0;
	echo '<table class="widefat striped" style="max-width:900px"><thead><tr><th>Tag</th><th>Kommen</th><th>Gehen</th><th>Pause</th><th>Netto</th><th>Hinweis</th></tr></thead><tbody>';
	foreach ( $rows as $r ) {
		$sum += $r['netsec'];
		echo '<tr' . ( $r['missing'] ? ' style="background:#fff7e0"' : '' ) . '><td>' . esc_html( $r['label'] ) . '</td><td>' . esc_html( $r['in'] ) . '</td><td>' . esc_html( $r['out'] ) . '</td><td>' . esc_html( $r['pause'] ) . '</td><td><b>' . esc_html( $r['net'] ) . '</b></td><td>' . esc_html( $r['note'] ?: ( $r['missing'] ? 'keine Buchung' : '' ) ) . '</td></tr>';
	}
	echo '<tr><td colspan="4"><b>Summe</b></td><td><b>' . esc_html( kt_ze_hm( $sum ) ) . ' h</b></td><td>' . esc_html( str_replace( '.', ',', (string) round( $sum / 3600, 2 ) ) ) . ' Std.</td></tr></tbody></table>';

	echo '<h2 style="margin-top:28px">Einzelbuchungen bearbeiten</h2><table class="widefat" style="max-width:900px"><thead><tr><th>Zeitpunkt</th><th>Art</th><th></th></tr></thead><tbody>';
	$hidden = array( 'tab' => 'monat', 'ym' => $ym, 'sid' => $sid );
	foreach ( $data as $d ) {
		foreach ( $d['list'] as $r ) {
			echo '<tr><td colspan="3"><form method="post" style="display:flex;gap:8px;align-items:center;margin:0">' . kt_ze_hidden( 'log_save', $hidden + array( 'id' => $r->id, 'staff' => $sid ) );
			echo '<input type="datetime-local" name="ts" value="' . esc_attr( str_replace( ' ', 'T', substr( $r->ts, 0, 16 ) ) ) . '"><select name="type">';
			foreach ( kt_ze_types() as $k => $l ) {
				echo '<option value="' . esc_attr( $k ) . '"' . selected( $r->type, $k, false ) . '>' . esc_html( $l ) . '</option>';
			}
			echo '</select><button class="button">Speichern</button>' . ( $r->edited ? ' <em style="color:#a60">korrigiert</em>' : '' ) . '</form>';
			echo '<form method="post" style="display:inline" onsubmit="return confirm(\'Buchung löschen?\')">' . kt_ze_hidden( 'log_del', $hidden + array( 'id' => $r->id ) ) . '<button class="button-link-delete">Löschen</button></form></td></tr>';
		}
	}
	echo '</tbody></table><h3>Buchung nachtragen</h3><form method="post" style="display:flex;gap:8px;align-items:center">' . kt_ze_hidden( 'log_save', $hidden + array( 'id' => 0, 'staff' => $sid ) );
	echo '<input type="datetime-local" name="ts" value="' . esc_attr( current_time( 'Y-m-d\TH:i' ) ) . '"><select name="type">';
	foreach ( kt_ze_types() as $k => $l ) {
		echo '<option value="' . esc_attr( $k ) . '">' . esc_html( $l ) . '</option>';
	}
	echo '</select><button class="button button-primary">Nachtragen</button></form>';
}

function kt_ze_tab_staff( $staff ) {
	$unk = get_option( 'kt_ze_unknown' );
	if ( $unk && ! empty( $unk['uid'] ) ) {
		echo '<div class="notice notice-info"><p>Zuletzt am Tablet gescannte, <b>nicht zugeordnete Karte</b>: <code>' . esc_html( $unk['uid'] ) . '</code> (' . esc_html( mysql2date( 'd.m.Y H:i', $unk['at'] ) ) . ') – unten eintragen.</p></div>';
	}
	echo '<p>Karte zuordnen: neue Karte am Tablet scannen (erscheint dann oben als „nicht zugeordnet“), Namen eintragen, Karten-ID einfügen.</p>';
	echo '<table class="widefat striped" style="max-width:1100px"><thead><tr><th>Name</th><th>Karten-ID (UID)</th><th>E-Mail (für Urlaubs-Bescheid)</th><th>Urlaubstage/Jahr</th><th>Aktiv</th><th>Master (Menü am Tablet)</th><th></th></tr></thead><tbody>';
	$rows = $staff;
	$rows[] = (object) array( 'id' => 0, 'name' => '', 'uid' => $unk['uid'] ?? '', 'email' => '', 'vac_days' => 30, 'active' => 1, 'is_master' => 0 );
	foreach ( $rows as $s ) {
		echo '<tr><form method="post">' . kt_ze_hidden( 'staff_save', array( 'tab' => 'mitarbeiter', 'id' => $s->id ) );
		echo '<td><input type="text" name="name" value="' . esc_attr( $s->name ) . '" placeholder="' . ( $s->id ? '' : 'Neuer Mitarbeiter' ) . '"></td>';
		echo '<td><input type="text" name="uid" value="' . esc_attr( $s->uid ) . '" style="font-family:monospace"></td>';
		echo '<td><input type="email" name="email" value="' . esc_attr( $s->email ) . '"></td>';
		echo '<td><input type="number" step="0.5" min="0" name="vac_days" value="' . esc_attr( $s->vac_days ) . '" style="width:80px"></td>';
		echo '<td><input type="checkbox" name="active" value="1"' . checked( $s->active, 1, false ) . '></td>';
		echo '<td><input type="checkbox" name="is_master" value="1"' . checked( $s->is_master, 1, false ) . '></td>';
		echo '<td><button class="button' . ( $s->id ? '' : ' button-primary' ) . '">' . ( $s->id ? 'Speichern' : 'Anlegen' ) . '</button></td></form></tr>';
	}
	echo '</tbody></table>';
}

function kt_ze_tab_leave( $staff ) {
	global $wpdb;
	$year = (int) current_time( 'Y' );
	echo '<h2>Urlaubskonto ' . $year . '</h2><table class="widefat striped" style="max-width:600px"><thead><tr><th>Mitarbeiter</th><th>Anspruch</th><th>Genommen</th><th>Rest</th></tr></thead><tbody>';
	foreach ( $staff as $s ) {
		if ( ! $s->active ) {
			continue;
		}
		$g = kt_ze_vac_taken( (int) $s->id, $year );
		echo '<tr><td>' . esc_html( $s->name ) . '</td><td>' . esc_html( $s->vac_days + 0 ) . '</td><td>' . (int) $g . '</td><td><b>' . esc_html( $s->vac_days - $g ) . '</b></td></tr>';
	}
	echo '</tbody></table><h2 style="margin-top:28px">Anträge</h2>';
	$rows = $wpdb->get_results( 'SELECT l.*,s.name FROM ' . kt_ze_t( 'leave' ) . ' l LEFT JOIN ' . kt_ze_t( 'staff' ) . " s ON s.id=l.staff_id ORDER BY FIELD(l.status,'offen','genehmigt','abgelehnt'), l.d_from DESC LIMIT 200" );
	echo '<table class="widefat striped" style="max-width:1000px"><thead><tr><th>Mitarbeiter</th><th>Zeitraum</th><th>Tage</th><th>Art</th><th>Bemerkung</th><th>Status</th><th></th></tr></thead><tbody>';
	if ( ! $rows ) {
		echo '<tr><td colspan="7">Noch keine Anträge.</td></tr>';
	}
	foreach ( $rows as $r ) {
		$clash = '';
		if ( $r->status === 'offen' ) {
			$o = $wpdb->get_col( $wpdb->prepare( 'SELECT s.name FROM ' . kt_ze_t( 'leave' ) . ' l JOIN ' . kt_ze_t( 'staff' ) . " s ON s.id=l.staff_id WHERE l.status='genehmigt' AND l.staff_id<>%d AND l.d_from<=%s AND l.d_to>=%s", $r->staff_id, $r->d_to, $r->d_from ) );
			if ( $o ) {
				$clash = ' <span style="color:#a60">⚠ zeitgleich abwesend: ' . esc_html( implode( ', ', $o ) ) . '</span>';
			}
		}
		echo '<tr><td>' . esc_html( $r->name ) . '</td><td>' . esc_html( mysql2date( 'd.m.Y', $r->d_from ) . ' – ' . mysql2date( 'd.m.Y', $r->d_to ) ) . '</td><td>' . (int) kt_ze_workdays( $r->d_from, $r->d_to ) . '</td><td>' . esc_html( kt_ze_kinds()[ $r->kind ] ?? $r->kind ) . '</td><td>' . esc_html( $r->note ) . $clash . '</td><td><b>' . esc_html( $r->status ) . '</b></td><td style="white-space:nowrap">';
		foreach ( array( 'genehmigt' => 'Genehmigen', 'abgelehnt' => 'Ablehnen', 'offen' => 'Zurücksetzen' ) as $k => $l ) {
			if ( $k !== $r->status ) {
				echo '<form method="post" style="display:inline">' . kt_ze_hidden( 'leave_set', array( 'tab' => 'urlaub', 'id' => $r->id, 'status' => $k ) ) . '<button class="button' . ( $k === 'genehmigt' ? ' button-primary' : '' ) . '">' . esc_html( $l ) . '</button></form> ';
			}
		}
		echo '<form method="post" style="display:inline" onsubmit="return confirm(\'Antrag löschen?\')">' . kt_ze_hidden( 'leave_del', array( 'tab' => 'urlaub', 'id' => $r->id ) ) . '<button class="button-link-delete">Löschen</button></form></td></tr>';
	}
	echo '</tbody></table><h3>Urlaub direkt eintragen (sofort genehmigt)</h3><form method="post" style="display:flex;gap:8px;align-items:center;flex-wrap:wrap">' . kt_ze_hidden( 'leave_add', array( 'tab' => 'urlaub' ) ) . '<select name="staff">';
	foreach ( $staff as $s ) {
		if ( $s->active ) {
			echo '<option value="' . (int) $s->id . '">' . esc_html( $s->name ) . '</option>';
		}
	}
	echo '</select><input type="date" name="d_from"><input type="date" name="d_to"><select name="kind">';
	foreach ( kt_ze_kinds() as $k => $l ) {
		echo '<option value="' . esc_attr( $k ) . '">' . esc_html( $l ) . '</option>';
	}
	echo '</select><input type="text" name="note" placeholder="Bemerkung"><button class="button button-primary">Eintragen</button></form>';
}
