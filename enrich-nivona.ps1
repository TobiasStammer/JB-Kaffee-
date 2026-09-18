# enrich-nivona.ps1 - reichert 7 der 9 NIVONA-Kaffeevollautomaten mit
# strukturierter Beschreibung (Vorzuege / Technische Daten) aus dem offiziellen
# NIVONA-Katalog "Sortiment 25/26" an (Desktop-PDF, Stand 2026-09).
# NICHT abgedeckt (nicht im aktuellen Katalog enthalten, vermutlich Altmodelle):
#   id=1047 NIVONA NIVO 7000, id=1055 NIVONA NIVO 8000 Pro (8141)
# Nicht idempotent bzgl. Aenderungen von Hand - ueberschreibt description/short_description.
# WICHTIG: Diese Datei braucht ein UTF-8-BOM, sonst liest Windows PowerShell 5.1
# die Umlaute in den String-Literalen falsch ein (Mojibake in der Live-Beschreibung).
#   .\enrich-nivona.ps1
$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null
$base = (Import-KtEnv)['WP_URL'].TrimEnd('/')
function Enc($s) { [System.Net.WebUtility]::HtmlEncode([string]$s) }
$h2s = 'style="font-size:15px;line-height:1.3;font-weight:700;margin:22px 0 8px"'

function Build-Desc($vorzuege, $techdaten) {
  $vz = ($vorzuege | ForEach-Object { "<li>$(Enc $_)</li>" }) -join ''
  $td = ($techdaten | ForEach-Object { "<tr><th style=""text-align:left;padding:6px 14px 6px 0;color:#555;font-weight:600;vertical-align:top;white-space:nowrap"">$(Enc $_.k)</th><td style=""padding:6px 0"">$(Enc $_.v)</td></tr>" }) -join ''
  @"
<div class="jura-pd">
<h2 $h2s>Vorzüge</h2>
<ul style="margin:0 0 8px 1.1em;padding:0">$vz</ul>
<h2 $h2s>Technische Daten</h2>
<table style="border-collapse:collapse;font-size:13.5px;line-height:1.5">$td</table>
<hr style="border:0;border-top:1px solid #e2e2e2;margin:18px 0">
<p style="font-size:14px;line-height:1.6;margin:0 0 10px"><strong><a href="$base/nivona/">Zur NIVONA Markenseite</a></strong></p>
<p style="font-size:14px;line-height:1.6;margin:0 0 10px">Persönliche Beratung und Vorführung in unserem Geschäft in Hofheim-Langenhain oder telefonisch unter 06192 2004363. Verkauf, Service und Reparatur als autorisierter NIVONA-Fachhändler aus einer Hand.</p>
<p style="font-size:12px;color:#888">NIVONA® und die genannten Technologiebezeichnungen sind Marken der NIVONA Apparate GmbH. Abbildungen: NIVONA. Änderungen und Irrtümer vorbehalten. Quelle: NIVONA Sortiment 25/26.</p>
</div>
"@
}

$items = @(
  @{ id = 1039; short = 'Kompakter Kaffeeautomat, der Vollautomaten-Technik mit der Kompaktheit einer Kapselmaschine verbindet – ganz ohne Kapselabfall.'
     vorzuege = @(
       'Vereint die Technik von Kaffeevollautomat und Siebträger mit der Kompaktheit einer Kapselmaschine',
       'Patentierte automatische Tamping- und Brühdruckanpassung für Espresso und Kaffee auf hohem Niveau',
       'Innovativer Click Cup: Mahlen und Brühen in einem Schritt, Kaffeesatzentsorgung per einfachem Dreh',
       'Kein Kapsel- oder Padabfall – mahlfrischer Kaffee aus jeder Bohnensorte, auch unterwegs einsetzbar',
       'Erhältlich in Cremeweiß (CUBE 4102) oder Schwarzgrau (CUBE 4106)'
     )
     techdaten = @(
       @{ k='Baureihe'; v='CUBE 4´ (Sortiment 25/26)' }
       @{ k='Milchsystem'; v='nein (reiner Kaffee-/Espressoautomat)' }
       @{ k='Kaffeestärke einstellbar'; v='5 Stufen' }
       @{ k='Bohnenbehälter'; v='ca. 250 g' }
       @{ k='Wassertank'; v='1,4 l' }
       @{ k='Gewicht inkl. Verpackung'; v='7,0 kg' }
       @{ k='Maße (B × H × T)'; v='ca. 21 × 32 × 21 cm' }
       @{ k='Artikelnummer'; v='300 004 102 / 300 004 106' }
     ) }
  @{ id = 1041; short = 'Der Einstieg in die Welt des NIVONA-Kaffeevollautomaten – Kaffee und Espresso per Knopfdruck, auch für zwei Tassen gleichzeitig.'
     vorzuege = @(
       'Einstieg in die Welt des Kaffeevollautomaten – Kaffee und Espresso per Knopfdruck, auch für zwei Tassen gleichzeitig',
       'TFT-Farbdisplay für einfache, übersichtliche Bedienung',
       'Manueller SPUMATORE zum Milchaufschäumen für Cappuccino & Co.',
       'Erhältlich als NICR 5´50 (Schwarz/Chrom) oder NICR 5´60 (Weiß/Chrom)'
     )
     techdaten = @(
       @{ k='Baureihe'; v='5er-Serie' }
       @{ k='Milchsystem'; v='SPUMATORE, manuell' }
       @{ k='Kaffeestärke einstellbar'; v='3 Stufen' }
       @{ k='Kaffeetemperatur einstellbar'; v='3 Stufen' }
       @{ k='Bohnenbehälter'; v='ca. 250 g' }
       @{ k='Wassertank'; v='2,2 l' }
       @{ k='Gewicht inkl. Verpackung'; v='10,0 kg' }
       @{ k='Maße (B × H × T)'; v='ca. 24 × 34 × 46 cm' }
       @{ k='Artikelnummer'; v='300 500 550 / 300 500 560' }
     ) }
  @{ id = 1043; short = 'Bekannt für ihren einmaligen Milchschaum – der optimale Begleiter für alle, die Milchkaffee-Rezepte lieben.'
     vorzuege = @(
       'Bekannt für einmaligen Milchschaum – optimaler Begleiter für alle, die Milchkaffee-Rezepte lieben',
       'Manuell EASY SPUMATORE direkt im Auslauf integriert – kein Tassenschieben mehr nötig',
       'Aroma Balance System mit 3 Profilen für individuellen Kaffeegeschmack',
       'Farbausführung Titan/Chrom (NICR 6´95)'
     )
     techdaten = @(
       @{ k='Baureihe'; v='6er-Serie' }
       @{ k='Milchsystem'; v='Manuell EASY SPUMATORE' }
       @{ k='Aroma Balance System'; v='3 Profile' }
       @{ k='Kaffeestärke einstellbar'; v='5 Stufen' }
       @{ k='Kaffeetemperatur einstellbar'; v='3 Stufen' }
       @{ k='Kaffeeauslauf höhenverstellbar'; v='14 cm' }
       @{ k='Bohnenbehälter'; v='ca. 250 g' }
       @{ k='Wassertank'; v='2,2 l' }
       @{ k='Gewicht inkl. Verpackung'; v='10,0 kg' }
       @{ k='Maße (B × H × T)'; v='ca. 24 × 34 × 46 cm' }
       @{ k='Artikelnummer'; v='300 600 695' }
     ) }
  @{ id = 1045; short = 'Cappuccino und Latte Macchiato auf Knopfdruck – dank Cappuccino-Connaisseur ganz nach Ihrem Geschmack.'
     vorzuege = @(
       'Cappuccino und Latte Macchiato per Knopfdruck dank OneTouch-SPUMATORE',
       'Cappuccino-Connaisseur: frei wählbar, ob zuerst Kaffee oder Milch in die Tasse kommt',
       'Aroma Balance System für individuelle Geschmacksprofile',
       'NICR 790 (Schwarz) im Test von test.de am 26.06.2025 mit „GUT (2,0)“ bewertet',
       'Erhältlich als NICR 7´90 (Schwarz), 7´95 (Titan) oder 7´96 (Weiß)'
     )
     techdaten = @(
       @{ k='Baureihe'; v='7er-Serie' }
       @{ k='Milchsystem'; v='OneTouch plus SPUMATORE' }
       @{ k='Cappuccino-Connaisseur'; v='ja' }
       @{ k='Kaffeestärke einstellbar'; v='5 Stufen' }
       @{ k='Kaffeetemperatur einstellbar'; v='3 Stufen' }
       @{ k='Kaffeeauslauf höhenverstellbar'; v='14 cm' }
       @{ k='Bohnenbehälter'; v='ca. 250 g' }
       @{ k='Wassertank'; v='2,2 l' }
       @{ k='Gewicht inkl. Verpackung'; v='11,0 kg' }
       @{ k='Maße (B × H × T)'; v='ca. 24 × 34 × 46 cm' }
       @{ k='Artikelnummer'; v='300 700 790 / 300 700 795 / 300 700 796' }
     ) }
  @{ id = 1049; short = 'Brüht und reinigt so fortschrittlich wie möglich – dank der neuen Brüheinheit RomaticaPlus.'
     vorzuege = @(
       'Fortschrittlichste Brüheinheit RomaticaPlus für mehr Sauberkeit im Inneren und besonders schnelles Entkalken',
       'Brüheinheit lässt sich einfach entnehmen und unter fließendem, kaltem Wasser reinigen',
       'Neues Aromaprofil harmonic sorgt bei jeder Kaffeebohne für ausgewogenen Geschmack',
       'OneTouch DUOplus SPUMATORE für Cappuccino & Co. auf Knopfdruck',
       'Erhältlich als NIVO 8´101 (Schwarz) oder 8´103 (Titan) – als NIVO 8´107 (Perlenblau) zusätzlich mit Chilled Brew für kalten Kaffeegenuss'
     )
     techdaten = @(
       @{ k='Baureihe'; v='8000er-Serie' }
       @{ k='Brüheinheit'; v='RomaticaPlus, entnehmbar' }
       @{ k='Milchsystem'; v='OneTouch DUOplus SPUMATORE' }
       @{ k='Kaffeestärke einstellbar'; v='5 Stufen' }
       @{ k='Kaffeetemperatur einstellbar'; v='3 Stufen' }
       @{ k='Kaffeeauslauf höhenverstellbar'; v='14 cm' }
       @{ k='Bohnenbehälter'; v='ca. 250 g' }
       @{ k='Wassertank'; v='1,8 l' }
       @{ k='Gewicht inkl. Verpackung'; v='13,0 kg' }
       @{ k='Maße (B × H × T)'; v='ca. 24 × 34 × 48 cm' }
       @{ k='Artikelnummer'; v='300 008 101 / 300 008 103' }
     ) }
  @{ id = 1051; short = 'Kaffee auf einem ganz neuen Niveau: großes 7"-Touch-Farbdisplay, RomaticaPlus-Brüheinheit und individuelle Milchschaum-Einstellung.'
     vorzuege = @(
       'Innovative Brüheinheit RomaticaPlus für mehr Effizienz, Sauberkeit und besonders schnelles Entkalken',
       'Großes 7"-Touch-Farbdisplay – Menüführung, Rezeptauswahl und eigene Kreationen ganz einfach per Fingertipp',
       'LattePreSelect: Zubereitung individuell auf Kuhmilch oder pflanzliche Alternativen (z. B. Hafer) abgestimmt',
       'Doppelmilchschlauch mit easyclean+ – reinigt das Milchsystem automatisch oder per Knopfdruck',
       'Wassertankbeleuchtung in 8 Farben inkl. Disco-Modus, automatisches Einschalten, Extreme Mode bei kalkhaltigem Wasser',
       'Erhältlich als NIVO 9´101 (Schwarz) oder 9´103 (Titan)'
     )
     techdaten = @(
       @{ k='Baureihe'; v='9000er-Serie' }
       @{ k='Display'; v='7" Touch-Farbdisplay' }
       @{ k='Brüheinheit'; v='RomaticaPlus, entnehmbar' }
       @{ k='Milchsystem'; v='OneTouch DuoPlus Sense SPUMATORE' }
       @{ k='Kaffeetemperatur einstellbar'; v='4 Stufen' }
       @{ k='Kaffeeauslauf höhenverstellbar'; v='14 cm' }
       @{ k='Bohnenbehälter'; v='ca. 320 g' }
       @{ k='Wassertank'; v='2,2 l' }
       @{ k='Gewicht inkl. Verpackung'; v='14,8 kg' }
       @{ k='Maße (B × H × T)'; v='ca. 29 × 36 × 50 cm' }
       @{ k='Artikelnummer'; v='300 009 101 / 300 009 103' }
     ) }
  @{ id = 1053; short = 'Die Büromaschine von NIVONA – für bis zu 65 Tassen am Tag, mit großem Wassertank und automatischer Milchsystem-Reinigung.'
     vorzuege = @(
       'Büromaschine von NIVONA, ausgelegt für bis zu 65 Tassen am Tag',
       'Besonders großer Wassertank (3,5 l) und großer Bohnenbehälter (600 g) für lange Einsatzzeiten ohne Nachfüllen',
       'Doppelmilchschlauch mit easyclean+ reinigt das Milchsystem automatisch',
       'Mengen-Funktion für große Kaffeemengen bei Meetings, Quick-Profil für schnellen Cappuccino & Co.',
       'Optionales kostenloses Büropaket (Registrierung auf office.nivona.online): 2 Gratis-Wartungen, kostenfreier Versand, verlängerte Garantie auf 26.000 Tassen bzw. 24 Monate',
       'Inklusive MilchContainer NIMC 1000; Farbausführung Titan/Chrom'
     )
     techdaten = @(
       @{ k='Baureihe'; v='NICR 10´40 (Büromaschine)' }
       @{ k='Milchsystem'; v='OneTouch DUO SPUMATORE' }
       @{ k='Kaffeestärke einstellbar'; v='5 Stufen' }
       @{ k='Kaffeetemperatur einstellbar'; v='3 Stufen' }
       @{ k='Kaffeeauslauf höhenverstellbar'; v='16,5 cm' }
       @{ k='Bohnenbehälter'; v='ca. 600 g' }
       @{ k='Wassertank'; v='3,5 l' }
       @{ k='Gewicht inkl. Verpackung'; v='16,4 kg' }
       @{ k='Maße (B × H × T)'; v='ca. 30 × 42 × 48 cm' }
       @{ k='Artikelnummer'; v='300 001 040' }
     ) }
)

foreach ($it in $items) {
  $desc = Build-Desc $it.vorzuege $it.techdaten
  $short = "<p>$(Enc $it.short)</p>"
  $r = wc PUT "products/$($it.id)" @{ description = $desc; short_description = $short }
  Write-Host ("[ok] id={0,-5} {1,-40} desc={2} Zeichen" -f $r.id, $r.name, $r.description.Length)
}
