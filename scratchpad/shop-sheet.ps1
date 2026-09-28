$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wp-lib.ps1" | Out-Null

$g = wp GET '/wp/v2/global-styles/11'
$css = $g.styles.css
$marker = 'Shop-Template-Seiten ins Seiten-Blatt'
if ($css -match [regex]::Escape($marker)) {
  # alten Block ab dem Marker abschneiden (idempotent)
  $css = $css -replace "(?s)\r?\n/\* =+ Shop-Template-Seiten ins Seiten-Blatt.*$", ''
}

$add = @'

/* ===== Shop-Template-Seiten ins Seiten-Blatt (Kachel) 2026-09-04 ===== */
body.woocommerce-page { background: #e3e5ea !important; }
body.woocommerce-page .wp-site-blocks {
  max-width: 1240px;
  margin-inline: auto;
  margin-block: clamp(0px, 2.2vw, 30px);
  background: #ffffff;
  border-radius: 16px;
  box-shadow: 0 1px 2px rgba(0,0,0,.04), 0 14px 40px -16px rgba(0,0,0,.16);
  overflow: clip;
}
@media (max-width: 600px) {
  body.woocommerce-page .wp-site-blocks { margin-inline: 8px; border-radius: 10px; }
}
/* zu grosses Theme-Innen-Padding des main-Bereichs zaehmen */
body.woocommerce-page .wp-site-blocks > main,
body.woocommerce-page .wp-site-blocks > *:not(header):not(footer) > main {
  padding-block: clamp(28px, 3.5vw, 52px) !important;
  padding-inline: clamp(16px, 4vw, 44px) !important;
}
/* keine Kachel-in-Kachel bei Produkt-Detailtext / Tabs */
body.woocommerce-page .wp-block-woocommerce-product-details,
body.woocommerce-page .woocommerce div.product .woocommerce-tabs .panel {
  border: 0 !important;
  border-radius: 0 !important;
  padding-inline: 0 !important;
  background: transparent !important;
}
body.woocommerce-page .wp-block-woocommerce-product-details {
  border-top: 1px solid #e6e6e6 !important;
  margin-top: 10px;
  padding-top: 8px !important;
}
body.woocommerce-page .woocommerce-Tabs-panel {
  padding: 6px 0 0 0 !important;
  border: 0 !important;
  border-radius: 0 !important;
  background: transparent !important;
}
/* doppelte "Beschreibung"-Ueberschrift (Tab sagt es schon) ausblenden */
body.woocommerce-page .woocommerce-Tabs-panel--description > h2:first-child { display: none !important; }

/* ----- Produktbeschreibung: einheitlich & lesbar (JURA, NIVONA, Kaffee, Zubehoer) ----- */
body.woocommerce-page .woocommerce-Tabs-panel--description {
  max-width: 800px;
  font-size: 15px;
  line-height: 1.65;
  color: #2b2b2b;
}
body.woocommerce-page .woocommerce-Tabs-panel--description .jura-pd > :first-child,
body.woocommerce-page .woocommerce-Tabs-panel--description > *:not(h2):first-child { margin-top: 0 !important; }
body.woocommerce-page .woocommerce-Tabs-panel--description h2,
body.woocommerce-page .woocommerce-Tabs-panel--description h3 {
  font-size: 16px !important;
  font-weight: 700 !important;
  line-height: 1.3 !important;
  margin: 26px 0 10px !important;
  padding: 0 0 6px !important;
  border-bottom: 1px solid #ececec;
  color: #1c1c1c;
}
body.woocommerce-page .woocommerce-Tabs-panel--description p { margin: 0 0 12px !important; font-size: 15px !important; }
body.woocommerce-page .woocommerce-Tabs-panel--description ul {
  margin: 0 0 14px !important;
  padding-left: 1.4em !important;
  list-style: disc outside !important;
}
body.woocommerce-page .woocommerce-Tabs-panel--description li { margin: 5px 0 !important; padding-left: 2px; }
body.woocommerce-page .woocommerce-Tabs-panel--description table {
  width: 100%; max-width: 560px;
  margin: 0 0 16px !important;
  font-size: 13.5px !important;
  border-collapse: collapse;
}
body.woocommerce-page .woocommerce-Tabs-panel--description table th,
body.woocommerce-page .woocommerce-Tabs-panel--description table td {
  border-bottom: 1px solid #f0f0f0;
  padding: 7px 16px 7px 0 !important;
  vertical-align: top;
}
body.woocommerce-page .woocommerce-Tabs-panel--description table th { white-space: normal !important; color: #555; font-weight: 600; }
body.woocommerce-page .woocommerce-Tabs-panel--description hr { margin: 22px 0 !important; }
body.woocommerce-page .woocommerce-Tabs-panel--description a { color: #334155; }

/* ----- Produktbild-Groesse je Kategorie ----- */
/* Vollautomaten: 380px (Hero-Wirkung) - bleibt Standard */
/* Kaffee, Zubehoer, Pflege: kompakter, das Bild soll nicht dominieren */
body.product_cat-kaffee div.product .wp-block-woocommerce-product-image-gallery,
body.product_cat-kaffee div.product .woocommerce-product-gallery,
body.product_cat-kaffee div.product div.images,
body.product_cat-tee div.product .wp-block-woocommerce-product-image-gallery,
body.product_cat-tee div.product .woocommerce-product-gallery,
body.product_cat-tee div.product div.images { max-width: 260px !important; }
body.product_cat-jura-zubehoer div.product .wp-block-woocommerce-product-image-gallery,
body.product_cat-jura-zubehoer div.product .woocommerce-product-gallery,
body.product_cat-jura-zubehoer div.product div.images,
body.product_cat-jura-pflegeprodukte div.product .wp-block-woocommerce-product-image-gallery,
body.product_cat-jura-pflegeprodukte div.product .woocommerce-product-gallery,
body.product_cat-jura-pflegeprodukte div.product div.images { max-width: 260px !important; }

/* ----- WooCommerce Kategorie-Archiv an das Shop-Design angleichen ----- */
body.woocommerce-page.archive .wp-site-blocks > .wp-block-group {
  padding: clamp(28px,3.5vw,50px) clamp(16px,4vw,44px) !important;
}
body.woocommerce-page.archive .wp-block-query-title,
body.woocommerce-page.archive .woocommerce-products-header__title {
  font-size: 24px !important; line-height: 1.25 !important; margin: 0 0 6px !important;
}
body.woocommerce-page.archive .woocommerce-result-count { font-size: 12.5px !important; color: #8a8a8a !important; }
body.woocommerce-page.archive .woocommerce-ordering select,
body.woocommerce-page.archive select.orderby {
  font-size: 12.5px !important; padding: 7px 9px !important; border: 1px solid #cfcfcf !important; border-radius: 6px !important;
}
body.woocommerce-page.archive .wc-block-product-template,
body.woocommerce-page.archive ul.products {
  max-width: 1040px !important; margin-left: auto !important; margin-right: auto !important;
}
body.woocommerce-page.archive .wc-block-product .wp-block-post-title,
body.woocommerce-page.archive .wc-block-product h3,
body.tax-product_cat .wc-block-grid__product-title,
body.tax-product_cat h2.woocommerce-loop-product__title,
body.tax-product_cat li.product h2 {
  font-size: 15.5px !important; font-weight: 500 !important; line-height: 1.3 !important; margin: 9px 0 3px !important;
}
body.woocommerce-page.archive .wc-block-product .wp-block-post-title a { font-weight: 500 !important; }
body.tax-product_cat .wc-block-components-product-price,
body.tax-product_cat li.product .price {
  font-size: 15px !important; font-weight: 700 !important;
}
body.woocommerce-page.archive .wc-block-product img,
body.tax-product_cat li.product img {
  max-height: 210px !important; object-fit: contain !important;
}
body.woocommerce-page.archive .wc-block-product .wp-block-button__link,
body.woocommerce-page.archive .wc-block-product a.button {
  font-size: 12.5px !important; padding: 8px 14px !important;
}

/* ----- Einzel-Produktseite: Bild + Text mittig, engere Breite, Schrift wie Homepage ----- */
body.single-product .wc-block-breadcrumbs,
body.single-product .kt-pback,
body.single-product .wc-block-store-notices,
body.single-product div.product .wp-block-columns.alignwide,
body.single-product .wp-block-woocommerce-product-details {
  max-width: 860px !important;
  margin-left: auto !important;
  margin-right: auto !important;
}
body.single-product div.product .wp-block-columns.alignwide {
  gap: 44px !important;
  align-items: flex-start !important;
}
body.single-product .wp-block-post-title,
body.single-product .product_title {
  font-size: 21px !important;
  line-height: 1.3 !important;
  margin: 0 0 8px !important;
}
body.single-product .wc-block-components-product-price,
body.single-product div.product p.price,
body.single-product .summary .price .woocommerce-Price-amount {
  font-size: 17px !important;
  font-weight: 700 !important;
}
body.single-product .wc-block-components-product-price.has-medium-font-size { --wp--preset--font-size--medium: 17px; }
body.single-product .wp-block-woocommerce-product-summary,
body.single-product .entry-summary,
body.single-product .wc-block-components-product-summary { font-size: 15px !important; line-height: 1.6 !important; }
body.single-product .wp-block-woocommerce-product-details h2:first-child { display: none !important; }

/* ----- Warenkorb / Kasse: Schriftgroessen an die Seite angleichen ----- */
body.woocommerce-cart .wc-block-components-checkout-step__title,
body.woocommerce-checkout .wc-block-components-checkout-step__title,
body.woocommerce-page .wp-block-woocommerce-checkout h2,
body.woocommerce-page .wp-block-woocommerce-cart h2 { font-size: 17px !important; line-height: 1.3 !important; }
body.woocommerce-page .wc-block-components-checkout-step__description { font-size: 13px !important; }
body.woocommerce-page .wc-block-components-order-summary-item__description,
body.woocommerce-page .wc-block-cart-item__product-name,
body.woocommerce-page .wc-block-components-product-name { font-size: 15px !important; }
body.woocommerce-page .wc-block-components-totals-item { font-size: 14.5px !important; }
body.woocommerce-page .wc-block-components-text-input label,
body.woocommerce-page .wc-block-components-text-input input,
body.woocommerce-page .wc-block-components-checkout-step .wc-block-components-radio-control__label { font-size: 15px !important; }

/* ----- Bestellbestaetigung (order-received): kompakt wie die uebrige Seite ----- */
body.woocommerce-order-received main { max-width: 940px; margin-inline: auto; padding-inline: clamp(16px, 4vw, 44px) !important; }
/* Seitenueberschrift ("Bestellung eingegangen") auf die Groesse von Warenkorb/Konto (26px) */
body.woocommerce-order-received h1,
body.woocommerce-order-received .wp-block-post-title,
body.woocommerce-order-received .entry-title {
  font-size: clamp(22px, 2.4vw, 26px) !important; line-height: 1.25 !important; margin: 0 0 12px !important;
  max-width: 940px; margin-inline: auto !important; padding-inline: clamp(16px, 4vw, 44px) !important; box-sizing: border-box;
}
body.woocommerce-order-received .wp-block-woocommerce-order-confirmation-status,
body.woocommerce-order-received .wc-block-order-confirmation-status {
  font-size: 20px !important; line-height: 1.35 !important; font-weight: 700; margin: 0 0 8px !important;
}
body.woocommerce-order-received .wc-block-order-confirmation-status p { font-size: inherit !important; margin: 0 !important; }
body.woocommerce-order-received .wc-block-order-confirmation-status-description,
body.woocommerce-order-received .wc-block-order-confirmation-status-description p { font-size: 15px !important; line-height: 1.6 !important; }
body.woocommerce-order-received .wc-block-order-confirmation-summary,
body.woocommerce-order-received .wc-block-order-confirmation-summary * { font-size: 14px !important; line-height: 1.5 !important; }
body.woocommerce-order-received .wc-block-order-confirmation-summary { margin: 14px 0 6px !important; }
body.woocommerce-order-received main h2,
body.woocommerce-order-received main h3,
body.woocommerce-order-received main .wp-block-heading {
  font-size: 17px !important; line-height: 1.3 !important; margin: 26px 0 10px !important;
}
body.woocommerce-order-received .wc-block-order-confirmation-totals table,
body.woocommerce-order-received .wc-block-order-confirmation-totals table *,
body.woocommerce-order-received .wc-block-order-confirmation-shipping-address *,
body.woocommerce-order-received .wc-block-order-confirmation-billing-address *,
body.woocommerce-order-received .wc-block-order-confirmation-additional-fields * { font-size: 14.5px !important; line-height: 1.55 !important; }
body.woocommerce-order-received .wc-block-order-confirmation-totals th,
body.woocommerce-order-received .wc-block-order-confirmation-totals td { padding: 9px 14px !important; }
body.woocommerce-order-received .wc-block-order-confirmation-shipping-address,
body.woocommerce-order-received .wc-block-order-confirmation-billing-address { padding: 12px 16px !important; }
body.woocommerce-order-received .wc-block-order-confirmation-create-account h3 { font-size: 16px !important; }
body.woocommerce-order-received .wc-block-order-confirmation-create-account li { font-size: 14.5px !important; }

/* ----- Mein Konto (Anmelden/Registrieren + Kundenbereich): Groessen wie die uebrige Seite ----- */
body.woocommerce-account .wp-block-post-title,
body.woocommerce-account main h1 { font-size: 22px !important; line-height: 1.3 !important; margin: 0 0 18px !important; }
body.woocommerce-account .woocommerce {
  max-width: 940px !important; margin-inline: auto !important; font-size: 15px; line-height: 1.6;
}
/* doppeltes Seiten-Padding (main + post-content) auf dem Konto-Bereich nicht addieren */
body.woocommerce-account .wp-block-post-content { padding-inline: 0 !important; }
body.woocommerce-account .woocommerce h2,
body.woocommerce-account .woocommerce h3 { font-size: 17px !important; line-height: 1.3 !important; margin: 0 0 14px !important; }
body.woocommerce-account .woocommerce label { font-size: 14px !important; font-weight: 600; }
body.woocommerce-account .woocommerce input.input-text,
body.woocommerce-account .woocommerce select,
body.woocommerce-account .woocommerce textarea { font-size: 15px !important; padding: 10px 12px !important; }
body.woocommerce-account .woocommerce .button,
body.woocommerce-account .woocommerce button.button { font-size: 14px !important; padding: 10px 20px !important; }
body.woocommerce-account .woocommerce-form .form-row { margin: 0 0 14px !important; }
body.woocommerce-account .woocommerce-privacy-policy-text p,
body.woocommerce-account .woocommerce-form-register > p:not(.form-row) { font-size: 13px !important; color: #666; margin: 0 0 14px !important; }
/* Anmelden + Registrieren: zwei gleich hohe Karten */
body.woocommerce-account #customer_login {
  display: grid !important; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 24px; align-items: start;
  width: 100% !important; max-width: none !important; justify-content: stretch !important;
}
@media (max-width: 720px) {
  body.woocommerce-account #customer_login { grid-template-columns: minmax(0, 1fr); }
}
/* WooCommerce-Clearfix (::before/::after) wuerde im Raster zu leeren Zellen */
body.woocommerce-account #customer_login::before,
body.woocommerce-account #customer_login::after,
body.woocommerce-account .woocommerce::before,
body.woocommerce-account .woocommerce::after { content: none !important; display: none !important; }
body.woocommerce-account #customer_login .u-column1,
body.woocommerce-account #customer_login .u-column2 {
  float: none !important; width: auto !important; margin: 0 !important; box-sizing: border-box;
  border: 1px solid #e6e6e6; border-radius: 10px; padding: 22px 24px;
}
/* Kundenbereich: Menue links, Inhalt rechts */
body.woocommerce-account .woocommerce:has(.woocommerce-MyAccount-navigation) {
  display: grid; grid-template-columns: 210px minmax(0, 1fr); gap: 12px 36px; align-items: start;
}
body.woocommerce-account .woocommerce-notices-wrapper { grid-column: 1 / -1; }
body.woocommerce-account .woocommerce-MyAccount-navigation,
body.woocommerce-account .woocommerce-MyAccount-content { float: none !important; width: auto !important; margin: 0 !important; }
body.woocommerce-account .woocommerce-MyAccount-navigation ul { list-style: none; margin: 0; padding: 0; }
body.woocommerce-account .woocommerce-MyAccount-navigation li { margin: 0 0 3px; padding: 0; }
body.woocommerce-account .woocommerce-MyAccount-navigation li a {
  display: block; padding: 9px 14px; border-radius: 6px; font-size: 14.5px; color: #334155; text-decoration: none;
}
body.woocommerce-account .woocommerce-MyAccount-navigation li a:hover { background: #f3f4f6; }
body.woocommerce-account .woocommerce-MyAccount-navigation li.is-active a { background: #eceff3; font-weight: 700; color: #1e293b; }
body.woocommerce-account .woocommerce-MyAccount-content p { margin: 0 0 12px; }
body.woocommerce-account .woocommerce-MyAccount-content table { font-size: 14px; }
@media (max-width: 720px) {
  body.woocommerce-account .woocommerce:has(.woocommerce-MyAccount-navigation) { grid-template-columns: 1fr; }
  body.woocommerce-account #customer_login .u-column1,
  body.woocommerce-account #customer_login .u-column2 { padding: 18px; }
}
'@

$new = $css.TrimEnd() + "`n" + $add
$body = @{ styles = $g.styles }
$body.styles.css = $new
$res = wp POST '/wp/v2/global-styles/11' @{ styles = $body.styles }
Write-Host ("global-styles/11 aktualisiert, CSS-Laenge {0} -> {1}" -f $css.Length, $new.Length)
