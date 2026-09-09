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
'@

$new = $css.TrimEnd() + "`n" + $add
$body = @{ styles = $g.styles }
$body.styles.css = $new
$res = wp POST '/wp/v2/global-styles/11' @{ styles = $body.styles }
Write-Host ("global-styles/11 aktualisiert, CSS-Laenge {0} -> {1}" -f $css.Length, $new.Length)
