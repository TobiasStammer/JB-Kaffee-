/* kaffeetechniker.de - Interne Kartenerfassung "Paolos nahkauf BOX" (versteckte Seite, kein WP-Seitentyp).
 * URL: /<KT_KE_SLUG>/ - nicht verlinkt, noindex, Zugang nur mit Kennwort (Sitzungs-Cookie 12 h).
 * Erfasst Vorname, Name, Kartennummer; Liste mit Suche, Loeschen, CSV-Export (Excel/Semikolon) und Druck.
 * Speicherung: eigene Tabelle {prefix}kt_karten. Alle Aktionen laufen als JSON-POST auf dieselbe URL
 * (kein Seitencache-Problem, kein %2B im Body).
 * Quelle im Repo: kartenerfassung-snippet.php (Platzhalter __SLUG__/__HASH__/__LOGO__ werden beim Deploy
 * durch scratchpad/kartenerfassung.ps1 ersetzt; Werte stehen nur im Live-Snippet).
 * Einbau: Code Snippets, PHP, "Ueberall ausfuehren".
 * Kennwort aendern: SHA-256 (hex) des neuen Kennworts in KT_KE_HASH eintragen. */
define( 'KT_KE_SLUG', '__SLUG__' );
define( 'KT_KE_HASH', '__HASH__' );
define( 'KT_KE_LOGO', '__LOGO__' );

add_action( 'init', function () {
	$path = trim( (string) wp_parse_url( $_SERVER['REQUEST_URI'] ?? '', PHP_URL_PATH ), '/' );
	if ( $path !== KT_KE_SLUG ) {
		return;
	}
	if ( ! defined( 'DONOTCACHEPAGE' ) ) {
		define( 'DONOTCACHEPAGE', true );
	}
	nocache_headers();
	header( 'Cache-Control: no-store, no-cache, must-revalidate, max-age=0' );
	header( 'X-Robots-Tag: noindex, nofollow, noarchive' );
	header( 'Referrer-Policy: no-referrer' );

	global $wpdb;
	$table = $wpdb->prefix . 'kt_karten';
	if ( get_option( 'kt_ke_db' ) !== '1' ) {
		require_once ABSPATH . 'wp-admin/includes/upgrade.php';
		dbDelta( "CREATE TABLE $table (
			id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
			vorname varchar(100) NOT NULL,
			nachname varchar(100) NOT NULL,
			karte varchar(40) NOT NULL,
			created datetime NOT NULL,
			PRIMARY KEY  (id),
			KEY karte (karte)
		) " . $wpdb->get_charset_collate() . ';' );
		update_option( 'kt_ke_db', '1', false );
	}

	$key    = wp_salt( 'auth' ) . KT_KE_HASH;
	$cookie = 'kt_ke';
	$authed = false;
	if ( ! empty( $_COOKIE[ $cookie ] ) && is_string( $_COOKIE[ $cookie ] ) ) {
		$parts = explode( '.', $_COOKIE[ $cookie ] );
		if ( 2 === count( $parts ) && (int) $parts[0] > time() && hash_equals( hash_hmac( 'sha256', $parts[0], $key ), $parts[1] ) ) {
			$authed = true;
		}
	}
	$cookie_path = '/' . KT_KE_SLUG . '/';
	$set_cookie  = function ( $val, $exp ) use ( $cookie, $cookie_path ) {
		setcookie( $cookie, $val, [ 'expires' => $exp, 'path' => $cookie_path, 'secure' => true, 'httponly' => true, 'samesite' => 'Strict' ] );
	};

	if ( 'POST' === $_SERVER['REQUEST_METHOD'] ) {
		header( 'Content-Type: application/json; charset=utf-8' );
		$out = function ( $a ) {
			echo wp_json_encode( $a );
			exit;
		};
		if ( empty( $_SERVER['HTTP_X_KT'] ) ) {
			http_response_code( 400 );
			$out( [ 'ok' => false, 'msg' => 'Ungueltige Anfrage.' ] );
		}
		$in = json_decode( (string) file_get_contents( 'php://input' ), true );
		$a  = is_array( $in ) && isset( $in['a'] ) ? (string) $in['a'] : '';

		if ( 'login' === $a ) {
			$lk   = 'kt_ke_fail_' . md5( (string) ( $_SERVER['REMOTE_ADDR'] ?? '' ) );
			$fail = (int) get_transient( $lk );
			if ( $fail >= 5 ) {
				$out( [ 'ok' => false, 'msg' => 'Zu viele Versuche. Bitte 15 Minuten warten.' ] );
			}
			$pw = isset( $in['pw'] ) ? trim( (string) $in['pw'] ) : '';
			if ( '' !== $pw && hash_equals( KT_KE_HASH, hash( 'sha256', $pw ) ) ) {
				delete_transient( $lk );
				$exp = time() + 12 * HOUR_IN_SECONDS;
				$set_cookie( $exp . '.' . hash_hmac( 'sha256', (string) $exp, $key ), $exp );
				$out( [ 'ok' => true ] );
			}
			set_transient( $lk, $fail + 1, 15 * MINUTE_IN_SECONDS );
			$out( [ 'ok' => false, 'msg' => 'Kennwort falsch.' ] );
		}
		if ( 'logout' === $a ) {
			$set_cookie( '', time() - 3600 );
			$out( [ 'ok' => true ] );
		}
		if ( ! $authed ) {
			$out( [ 'ok' => false, 'auth' => false ] );
		}
		$rows = function () use ( $wpdb, $table ) {
			return $wpdb->get_results( "SELECT id, vorname, nachname, karte, created FROM $table ORDER BY id DESC", ARRAY_A );
		};
		if ( 'list' === $a ) {
			$out( [ 'ok' => true, 'rows' => $rows() ] );
		}
		if ( 'add' === $a ) {
			$vn = trim( preg_replace( '/\s+/u', ' ', wp_strip_all_tags( (string) ( $in['vorname'] ?? '' ) ) ) );
			$nn = trim( preg_replace( '/\s+/u', ' ', wp_strip_all_tags( (string) ( $in['nachname'] ?? '' ) ) ) );
			$kn = trim( preg_replace( '/\s+/u', ' ', (string) ( $in['karte'] ?? '' ) ) );
			if ( '' === $vn || '' === $nn || '' === $kn ) {
				$out( [ 'ok' => false, 'msg' => 'Bitte Vorname, Name und Kartennummer ausfuellen.' ] );
			}
			if ( mb_strlen( $vn ) > 100 || mb_strlen( $nn ) > 100 ) {
				$out( [ 'ok' => false, 'msg' => 'Name zu lang.' ] );
			}
			if ( ! preg_match( '/^[0-9A-Za-z][0-9A-Za-z \-\.\/]{2,38}$/', $kn ) ) {
				$out( [ 'ok' => false, 'msg' => 'Kartennummer: nur Ziffern, Buchstaben, Leerzeichen und Bindestrich (3-39 Zeichen).' ] );
			}
			// Schutz: Zahlungskarten-Nummern (15-19 Ziffern, Luhn-gueltig) werden nicht gespeichert.
			$digits = preg_replace( '/\D/', '', $kn );
			if ( preg_match( '/^[\d \-]+$/', $kn ) && strlen( $digits ) >= 15 && strlen( $digits ) <= 19 ) {
				$sum = 0;
				$alt = false;
				for ( $i = strlen( $digits ) - 1; $i >= 0; $i-- ) {
					$d = (int) $digits[ $i ];
					if ( $alt ) {
						$d *= 2;
						if ( $d > 9 ) {
							$d -= 9;
						}
					}
					$sum += $d;
					$alt  = ! $alt;
				}
				if ( 0 === $sum % 10 ) {
					$out( [ 'ok' => false, 'msg' => 'Das sieht nach einer Bank-/Kreditkartennummer aus. Diese bitte nicht erfassen.' ] );
				}
			}
			$dup = $wpdb->get_row( $wpdb->prepare( "SELECT vorname, nachname FROM $table WHERE karte = %s LIMIT 1", $kn ), ARRAY_A );
			if ( $dup ) {
				$out( [ 'ok' => false, 'msg' => 'Diese Kartennummer ist schon erfasst (' . $dup['vorname'] . ' ' . $dup['nachname'] . ').' ] );
			}
			$wpdb->insert( $table, [ 'vorname' => $vn, 'nachname' => $nn, 'karte' => $kn, 'created' => current_time( 'mysql' ) ] );
			$out( [ 'ok' => true, 'rows' => $rows() ] );
		}
		if ( 'del' === $a ) {
			$wpdb->delete( $table, [ 'id' => (int) ( $in['id'] ?? 0 ) ] );
			$out( [ 'ok' => true, 'rows' => $rows() ] );
		}
		$out( [ 'ok' => false, 'msg' => 'Unbekannte Aktion.' ] );
	}

	status_header( 200 );
	header( 'Content-Type: text/html; charset=utf-8' );
	echo str_replace( '__KTLOGO__', esc_url( KT_KE_LOGO ), kt_ke_page() );
	exit;
}, 1 );

function kt_ke_page() {
	return <<<'KTHTML'
<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow, noarchive">
<title>Paolos nahkauf BOX – Kartenerfassung</title>
<style>
:root{--rot:#c8372d;--rot-d:#a82a21;--holz:#8a6244;--holz-d:#5e3f28;--papier:#f3eee2;--tinte:#3a2a1e;--rand:#cbbfa8}
*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%}
body{margin:0;min-height:100vh;color:var(--tinte);font:17px/1.45 "Rockwell","Roboto Slab","Georgia",serif;
background-color:#8a6244;
background-image:
 repeating-linear-gradient(90deg,rgba(0,0,0,.20) 0 2px,transparent 2px 190px),
 repeating-linear-gradient(90deg,rgba(255,255,255,.05) 0 60px,rgba(0,0,0,.06) 60px 130px,rgba(255,255,255,.03) 130px 190px),
 repeating-linear-gradient(0deg,rgba(60,35,15,.10) 0 1px,transparent 1px 7px)}
.wrap{max-width:960px;margin:0 auto;padding:20px 16px 48px}
.logo{display:block;width:min(420px,88%);height:auto;margin:6px auto 22px;border-radius:22px;box-shadow:0 8px 22px rgba(0,0,0,.45)}
.card{background:var(--papier);border:2px solid var(--rand);border-radius:20px;padding:22px;margin-bottom:20px;box-shadow:0 4px 14px rgba(0,0,0,.3)}
h1,h2{margin:0 0 14px;font-weight:700;line-height:1.2}
h1{font-size:22px;text-align:center}h2{font-size:20px}
label{display:block;font-weight:700;margin:0 0 4px;font-size:15px}
input[type=text],input[type=password],input[type=search]{width:100%;font:inherit;padding:12px 14px;border:2px solid var(--rand);border-radius:12px;background:#fff;color:var(--tinte)}
input:focus{outline:3px solid rgba(200,55,45,.35);border-color:var(--rot)}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:14px}
.full{grid-column:1/-1}
@media(max-width:620px){.grid{grid-template-columns:1fr}}
button{font:inherit;font-weight:700;cursor:pointer;border:0;border-radius:12px;padding:12px 20px;color:#fff;background:var(--rot);box-shadow:0 2px 0 var(--rot-d)}
button:hover{background:var(--rot-d)}
button.sec{background:var(--holz-d);box-shadow:0 2px 0 #3d2818}
button.sec:hover{background:#4a3120}
button.mini{padding:6px 12px;font-size:14px;background:#fff;color:var(--rot-d);border:2px solid var(--rand);box-shadow:none}
button.mini:hover{background:#fbe9e6}
.btn-main{width:100%;font-size:19px;padding:14px}
.msg{margin:12px 0;min-height:1.4em;font-weight:700}
.msg.err{color:var(--rot-d)}.msg.ok{color:#2f6b2f}
.bar{display:flex;flex-wrap:wrap;gap:10px;align-items:center;justify-content:space-between;margin-bottom:14px}
.bar .tools{display:flex;flex-wrap:wrap;gap:10px}
.bar input[type=search]{max-width:260px;padding:9px 12px}
.count{font-size:15px;opacity:.8}
.tw{overflow-x:auto}
table{width:100%;border-collapse:collapse;font-size:16px}
th,td{text-align:left;padding:9px 10px;border-bottom:1px solid var(--rand);white-space:nowrap}
th{font-size:13px;text-transform:uppercase;letter-spacing:.05em;opacity:.7}
td.k{font-variant-numeric:tabular-nums;letter-spacing:.03em}
td.x,th.x{text-align:right}
tr:nth-child(even) td{background:rgba(255,255,255,.45)}
.leer{padding:18px 4px;opacity:.7}
.out{text-align:right;margin-top:6px}
.out button{background:transparent;color:#fff;box-shadow:none;text-decoration:underline;padding:6px}
.hide{display:none!important}
@media print{
 body{background:#fff;color:#000}.logo,.card.form,.tools,.out,button{display:none!important}
 .card{box-shadow:none;border:0;padding:0;background:#fff}.wrap{padding:0}
 th,td{white-space:normal}td.x,th.x{display:none}
}
</style>
</head>
<body>
<div class="wrap">
<img class="logo" src="__KTLOGO__" alt="Paolos nahkauf BOX – Nichts liegt näher" width="466" height="290">

<section id="login" class="card hide" style="max-width:420px;margin-left:auto;margin-right:auto">
<h1>Interner Bereich</h1>
<form id="fLogin" autocomplete="off">
<label for="pw">Kennwort</label>
<input id="pw" type="password" autocomplete="current-password" required>
<p class="msg err" id="mLogin" role="alert"></p>
<button class="btn-main" type="submit">Anmelden</button>
</form>
</section>

<div id="app" class="hide">
<section class="card form">
<h1>Neue Karte erfassen</h1>
<form id="fAdd" autocomplete="off">
<div class="grid">
<div><label for="vn">Vorname</label><input id="vn" type="text" maxlength="100" required autocapitalize="words"></div>
<div><label for="nn">Name</label><input id="nn" type="text" maxlength="100" required autocapitalize="words"></div>
<div class="full"><label for="kn">Kartennummer</label><input id="kn" type="text" maxlength="39" inputmode="text" required></div>
</div>
<p class="msg" id="mAdd" role="status"></p>
<button class="btn-main" type="submit">Speichern</button>
</form>
</section>

<section class="card">
<div class="bar">
<h2 style="margin:0">Erfasste Karten <span class="count" id="cnt"></span></h2>
<div class="tools">
<input type="search" id="q" placeholder="Suchen …" aria-label="Suchen">
<button class="sec" id="bCsv" type="button">CSV exportieren</button>
<button class="sec" id="bPrint" type="button">Drucken</button>
</div>
</div>
<div class="tw"><table>
<thead><tr><th>Nr.</th><th>Vorname</th><th>Name</th><th>Kartennummer</th><th>Erfasst</th><th class="x"></th></tr></thead>
<tbody id="tb"></tbody>
</table></div>
<p class="leer hide" id="leer">Noch keine Einträge.</p>
</section>
<div class="out"><button type="button" id="bOut">Abmelden</button></div>
</div>
</div>
<script>
(function(){
var $=function(s){return document.querySelector(s)},rows=[];
function api(a,d){
  var b=Object.assign({a:a},d||{});
  return fetch(location.pathname,{method:'POST',credentials:'same-origin',headers:{'Content-Type':'application/json','X-KT':'1'},body:JSON.stringify(b)})
   .then(function(r){return r.json()}).catch(function(){return {ok:false,msg:'Keine Verbindung zum Server.'}});
}
function show(app){$('#login').classList.toggle('hide',app);$('#app').classList.toggle('hide',!app);if(app)$('#vn').focus();else $('#pw').focus()}
function fmt(s){var m=/^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d)/.exec(s||'');return m?m[3]+'.'+m[2]+'.'+m[1]+' '+m[4]+':'+m[5]:(s||'')}
function render(){
  var q=$('#q').value.trim().toLowerCase(),tb=$('#tb'),n=0;tb.textContent='';
  rows.forEach(function(r,i){
    var nr=rows.length-i;
    if(q&&(r.vorname+' '+r.nachname+' '+r.karte).toLowerCase().indexOf(q)<0)return;
    n++;var tr=document.createElement('tr');
    [nr,r.vorname,r.nachname,r.karte,fmt(r.created)].forEach(function(v,j){var td=document.createElement('td');if(j===3)td.className='k';td.textContent=v;tr.appendChild(td)});
    var tx=document.createElement('td');tx.className='x';var b=document.createElement('button');b.type='button';b.className='mini';b.textContent='Löschen';
    b.onclick=function(){if(confirm('Eintrag löschen?\n'+r.vorname+' '+r.nachname+' – '+r.karte))api('del',{id:r.id}).then(function(j){if(j.ok){rows=j.rows;render()}else if(j.auth===false)show(false)})};
    tx.appendChild(b);tr.appendChild(tx);tb.appendChild(tr);
  });
  $('#cnt').textContent='('+(q?n+' von ':'')+rows.length+')';
  $('#leer').classList.toggle('hide',n>0);
}
function load(){api('list').then(function(j){if(j.ok){rows=j.rows;render();show(true)}else show(false)})}
$('#fLogin').onsubmit=function(e){e.preventDefault();$('#mLogin').textContent='';
  api('login',{pw:$('#pw').value}).then(function(j){if(j.ok){$('#pw').value='';load()}else $('#mLogin').textContent=j.msg||'Fehler'})};
$('#fAdd').onsubmit=function(e){e.preventDefault();var m=$('#mAdd');m.className='msg';m.textContent='';
  api('add',{vorname:$('#vn').value,nachname:$('#nn').value,karte:$('#kn').value}).then(function(j){
    if(j.ok){rows=j.rows;render();m.className='msg ok';m.textContent='Gespeichert: '+$('#vn').value+' '+$('#nn').value;$('#fAdd').reset();$('#vn').focus()}
    else if(j.auth===false)show(false);else{m.className='msg err';m.textContent=j.msg||'Fehler'}})};
$('#q').oninput=render;
$('#bPrint').onclick=function(){window.print()};
$('#bOut').onclick=function(){api('logout').then(function(){rows=[];show(false)})};
$('#bCsv').onclick=function(){
  function c(v){v=String(v==null?'':v);if(/^\d+$/.test(v))return '="'+v+'"';if(/^[=+\-@\t\r]/.test(v))v="'"+v;return '"'+v.replace(/"/g,'""')+'"'}
  var l=['Nr;Vorname;Name;Kartennummer;Erfasst am'],t=rows.slice().reverse();
  t.forEach(function(r,i){l.push([i+1,c(r.vorname),c(r.nachname),c(r.karte),c(fmt(r.created))].join(';'))});
  var d=new Date(),p=function(x){return (x<10?'0':'')+x};
  var blob=new Blob(['﻿'+l.join('\r\n')],{type:'text/csv;charset=utf-8'});
  var a=document.createElement('a');a.href=URL.createObjectURL(blob);
  a.download='paolos-box-karten-'+d.getFullYear()+'-'+p(d.getMonth()+1)+'-'+p(d.getDate())+'.csv';
  document.body.appendChild(a);a.click();setTimeout(function(){URL.revokeObjectURL(a.href);a.remove()},500)};
load();
})();
</script>
</body>
</html>
KTHTML;
}
