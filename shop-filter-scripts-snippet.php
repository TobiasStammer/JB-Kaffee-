/* kaffeetechniker.de - JURA/NIVONA-Uebersichtsseiten: Serien-Filter, Vergleichstool (jk2grid)
 * und Produktseiten-Skripte (Farbwahl-Menue, Galerie-Fix, "Empfohlenes Zubehoer").
 * WICHTIG: Diese Skripte laufen ueber wp_footer statt im Seiteninhalt (post_content), weil
 * WordPress' the_content-Filterkette (vermutlich wpautop) bei bestimmten Seiten Leerzeilen
 * innerhalb von <script>-Bloecken im Content in <p>/</p> umwandelt und dadurch das JS bricht -
 * reproduzierbar, bei jedem Seitenaufruf neu, unabhaengig vom gespeicherten Rohinhalt (der ist
 * nachweislich sauber). Ueber einen Action-Hook ausgegebener Code durchlaeuft diese Filter nicht.
 * Einbau: Code Snippets, PHP, "Ueberall ausfuehren" (Deploy: scratchpad/shop-filter-scripts.ps1). */
add_action( 'wp_footer', function () {
	if ( is_admin() ) {
		return;
	}
	?>
<script>

(function(){
  var grid=document.getElementById('jk2grid'); if(!grid) return;
  var cards=[].slice.call(grid.querySelectorAll('.jp2'));
  var origOrder=cards.slice();
  // Ziel unter die klebende Menue- und Filterleiste scrollen (sonst verdecken sie die ersten Karten)
  function toGrid(){ var bar=document.getElementById('jk2bar'); var off=(bar?bar.offsetHeight:0)+40+16; window.scrollTo({top:grid.getBoundingClientRect().top+window.pageYOffset-off,behavior:'smooth'}); }
  var serTiles=[].slice.call(document.querySelectorAll('#jk2series .jk2-serie'));
  var serChips=[].slice.call(document.querySelectorAll('#jk2bar .jk2-chip'));
  var fdots=[].slice.call(document.querySelectorAll('#jk2bar .jk2-fdot'));
  var featBtns=[].slice.call(document.querySelectorAll('#jk2bar .jk2-feat[data-f]'));
  var genussBtns=[].slice.call(document.querySelectorAll('#jk2bar .jk2-feat[data-g]'));
  var sortSel=document.getElementById('jsort');
  var emptyMsg=document.getElementById('jk2empty');
  var activeSerie='*';
  var activeFarben=[];
  var activeFeat=[];
  var activeGenuss=[];


  function apply(){
    var vis=0;
    cards.forEach(function(c){
      var okS=(activeSerie==='*'||c.getAttribute('data-s')===activeSerie);
      var f=(c.getAttribute('data-farben')||'').split('|');
      var okF=(!activeFarben.length||activeFarben.some(function(x){return f.indexOf(x)>-1;}));
      var ft=(c.getAttribute('data-feat')||'').split(' ');
      var okA=(!activeFeat.length||activeFeat.every(function(x){return ft.indexOf(x)>-1;}));
      var gt=(c.getAttribute('data-genuss')||'').split(' ');
      var okG=(!activeGenuss.length||activeGenuss.every(function(x){return gt.indexOf(x)>-1;}));
      var show=okS && okF && okA && okG;
      c.classList.toggle('is-hidden',!show);
      if(show) vis++;
    });
    if(emptyMsg) emptyMsg.hidden=(vis>0);
  }
  function setSerie(s){
    activeSerie=s;
    serTiles.forEach(function(t){ t.classList.toggle('is-on',t.getAttribute('data-s')===s); });
    serChips.forEach(function(t){ t.classList.toggle('is-on',t.getAttribute('data-s')===s); });
    apply();
  }
  serTiles.forEach(function(t){ t.addEventListener('click',function(e){ e.preventDefault(); setSerie(t.getAttribute('data-s')); toGrid(); }); });
  serChips.forEach(function(t){ t.addEventListener('click',function(){ setSerie(t.getAttribute('data-s')); }); });

  fdots.forEach(function(d){
    d.addEventListener('click',function(){
      var c=d.getAttribute('data-c'), i=activeFarben.indexOf(c);
      if(i>-1) activeFarben.splice(i,1); else activeFarben.push(c);
      d.classList.toggle('is-on',activeFarben.indexOf(c)>-1);
      apply();
    });
  });
  featBtns.forEach(function(b){
    b.addEventListener('click',function(){
      var k=b.getAttribute('data-f'), i=activeFeat.indexOf(k);
      if(i>-1) activeFeat.splice(i,1); else activeFeat.push(k);
      b.classList.toggle('is-on',activeFeat.indexOf(k)>-1);
      apply();
    });
  });
  genussBtns.forEach(function(b){
    b.addEventListener('click',function(){
      var k=b.getAttribute('data-g'), i=activeGenuss.indexOf(k);
      if(i>-1) activeGenuss.splice(i,1); else activeGenuss.push(k);
      b.classList.toggle('is-on',activeGenuss.indexOf(k)>-1);
      apply();
    });
  });
  // Vorauswahl per Link von der Genusswelten-Erklaerung auf /jura/ (?genuss=cold)
  (function(){
    var q=(new URLSearchParams(location.search)).get('genuss'); if(!q) return;
    var b=genussBtns.filter(function(x){return x.getAttribute('data-g')===q;})[0]; if(!b) return;
    activeGenuss.push(q); b.classList.add('is-on'); apply();
    toGrid();
  })();

  function applySort(){
    var m=sortSel.value;
    var arr=cards.slice();
    if(m==='asc'||m==='desc'){
      arr.sort(function(a,b){
        var pa=+a.getAttribute('data-pnum')||0, pb=+b.getAttribute('data-pnum')||0;
        if(!pa) pa=(m==='asc')?9e9:-1; if(!pb) pb=(m==='asc')?9e9:-1;
        return (m==='asc')?pa-pb:pb-pa;
      });
    } else if(m==='az'){
      arr.sort(function(a,b){ return a.getAttribute('data-name').localeCompare(b.getAttribute('data-name')); });
    } else {
      arr.sort(function(a,b){ return origOrder.indexOf(a)-origOrder.indexOf(b); });
    }
    arr.forEach(function(c){ grid.appendChild(c); });
  }
  if(sortSel) sortSel.addEventListener('change',applySort);

  cards.forEach(function(card){
    var img=card.querySelector('.jp2-pic img');
    var link=card.querySelector('.jp2-row a');
    var titleLink=card.querySelector('.jp2-bd h3 a');
    var priceEl=card.querySelector('.jp2-price');
    var baseUrl=card.getAttribute('data-url');
    [].slice.call(card.querySelectorAll('.jsw')).forEach(function(sw){
      sw.addEventListener('click',function(){
        var src=sw.getAttribute('data-img'); if(src && img) img.src=src;
        var price=sw.getAttribute('data-price'); if(price && priceEl) priceEl.innerHTML=price;
        [].slice.call(card.querySelectorAll('.jsw')).forEach(function(x){ x.classList.remove('is-on'); });
        sw.classList.add('is-on');
        // Farbauswahl in die Zielseite mitgeben, damit "Details ansehen" und
        // der Titel-Link zur passenden Variante fuehren, nicht zur
        // Standardfarbe (Kundentest hat das als Widerspruch aufgedeckt).
        var color=sw.getAttribute('data-c');
        if(baseUrl && color){
          var sep=(baseUrl.indexOf('?')>-1) ? '&' : '?';
          var u=baseUrl+sep+'attribute_farbe='+encodeURIComponent(color);
          card.setAttribute('data-url',u);
          if(link) link.href=u;
          if(titleLink) titleLink.href=u;
        }
      });
    });
  });

  var sel=[], bar=document.getElementById('jbar'), cnt=document.getElementById('jcnt');
  function sync(){ bar.classList.toggle('show', sel.length>0); cnt.textContent=sel.length+' von 3'; }
  cards.forEach(function(card){
    var b=card.querySelector('.cmpbox'); if(!b) return;
    b.addEventListener('change',function(){
      if(b.checked){ if(sel.length>=3){b.checked=false;return;} sel.push(card); }
      else{ sel=sel.filter(function(x){return x!==card;}); }
      sync();
    });
  });
  document.getElementById('jclr').addEventListener('click',function(){
    sel=[]; cards.forEach(function(c){var b=c.querySelector('.cmpbox'); if(b) b.checked=false;}); sync();
  });
  function cell(fn){ return sel.map(function(c){return '<td>'+fn(c)+'</td>';}).join(''); }
  document.getElementById('jgo').addEventListener('click',function(){
    var html='<tr><th></th>'+cell(function(c){return '<b>'+c.getAttribute('data-name')+'</b>';})+'</tr>'
      +'<tr><th>Serie</th>'+cell(function(c){return c.getAttribute('data-serie');})+'</tr>'
      +'<tr><th>Preis</th>'+cell(function(c){return c.getAttribute('data-price');})+'</tr>'
      +'<tr><th>Charakter</th>'+cell(function(c){return c.getAttribute('data-blurb')||'';})+'</tr>'
      +'<tr><th></th>'+cell(function(c){return '<a href="'+c.getAttribute('data-url')+'">Details &rarr;</a>';})+'</tr>';
    document.getElementById('jtbl').innerHTML=html;
    document.getElementById('jmodal').classList.add('show');
  });
  [].slice.call(document.querySelectorAll('.jclose')).forEach(function(x){
    x.addEventListener('click',function(){ document.getElementById('jmodal').classList.remove('show'); });
  });
})();

</script>
<script>

(function(){
  function init(){
    var t=document.querySelector('.shnav-toggle'), n=document.getElementById('shnav');
    if(!t||!n||t.dataset.b) return; t.dataset.b='1';
    t.addEventListener('click',function(){
      var o=n.classList.toggle('is-open');
      t.setAttribute('aria-expanded',o?'true':'false');
    });
  }
  if(document.readyState==='loading'){document.addEventListener('DOMContentLoaded',init);}else{init();}
})();
// Bugfix Variantenbild: FlexSlider berechnet die Galerie-Hoehe/-Breite beim
// Farbwechsel manchmal neu, BEVOR das neue Bild geladen ist -> Viewport/Slide
// bleiben bei 0x0 haengen, das Bild verschwindet (nur die Lupe bleibt sichtbar).
// Fix: nach jedem Variantenwechsel die kaputten Inline-Styles zuruecksetzen
// und FlexSlider neu berechnen lassen - wiederholt im Kurzintervall (statt
// nur zu 3 festen Zeitpunkten), bis der Viewport eine plausible Hoehe hat.
// Feste Verzoegerungen (80/500/1200ms) reichten nicht, wenn das Bild auf
// langsamen Verbindungen (IONOS-Hosting) erst spaeter fertig laedt - dann
// blieb die Galerie dauerhaft kaputt, weil kein weiterer Versuch mehr kam.
(function(){
  if(!window.jQuery) return;
  function galleryWidth(g, vp){
    // vp.width() kann im kaputten Zustand ebenfalls 0 sein - dann auf die
    // Breite des Wrappers bzw. der ganzen Galerie ausweichen.
    return vp.width() || g.find('.woocommerce-product-gallery__wrapper').width() || g.width() || 0;
  }
  function fixGallery(){
    var g = window.jQuery('.woocommerce-product-gallery');
    if(!g.length) return true;
    var vp = g.find('.flex-viewport');
    g.find('.flex-active-slide').css('width','');
    if(g.data('flexslider')){ try{ g.flexslider('resize'); }catch(e){} }
    var h = vp.height();
    if(h && h >= 20) return true;
    // FlexSlider setzt dem Viewport manchmal GAR KEINE Hoehe (0px oder
    // leer) - nicht nur nach Farbwechsel, auch schon beim allerersten
    // Laden (v.a. auf schmalen/mobilen Viewports). Ohne Hoehe clippt
    // overflow:hidden nicht mehr, die (je volle Breite, float:left)
    // Slides rutschen dann untereinander -> "riesige" Bilder statt
    // Miniaturen. flexslider('resize') allein behebt das nicht
    // zuverlaessig -> Hoehe notfalls selbst aus dem aktiven Bild
    // berechnen (Seitenverhaeltnis * aktuelle Viewport-Breite).
    var img = g.find('.flex-active-slide img')[0] || g.find('.woocommerce-product-gallery__wrapper img')[0];
    var w = galleryWidth(g, vp);
    if(img && img.naturalWidth && w){
      vp.css('height', Math.round(w * img.naturalHeight / img.naturalWidth) + 'px');
      return true;
    }
    return false;
  }
  function fixGalleryUntilStable(){
    var tries = 0;
    (function tick(){
      if(fixGallery() || ++tries > 25) return;
      setTimeout(tick, 200);
    })();
  }
  window.jQuery(window).on('load', fixGalleryUntilStable);
  window.jQuery(document.body).on('found_variation woocommerce_gallery_init_gallery woocommerce_gallery_reset_slide_position reset_data', fixGalleryUntilStable);
  window.jQuery(document).on('load','.woocommerce-product-gallery__wrapper img',function(){
    fixGalleryUntilStable();
  });
})();
// "Weitere Farben": JURA-Farbvarianten sind Einzelprodukte. Der Block .kt-farben
// steht in der Produktbeschreibung (HTML erlaubt, die Kurzbeschreibung nicht) und
// wird hier direkt unter den Kurztext geschoben.
(function(){
  function move(){
    if(!document.body.classList.contains('single-product')) return;
    var k = document.querySelector('.kt-farben');
    var ex = document.querySelector('.wp-block-post-excerpt');
    if(k && ex && ex.parentNode) ex.parentNode.insertBefore(k, ex.nextSibling);
  }
  if(document.readyState === 'loading') document.addEventListener('DOMContentLoaded', move); else move();
})();
// "Empfohlenes Zubehoer": auf JURA/NIVONA-Geraete-Produktseiten (nicht auf
// Zubehoer/Pflege-Seiten selbst) unten eine Kachelreihe mit 4 Zubehoer-
// Produkten aus der passenden Kategorie einblenden (WC Store API, oeffentlich).
(function(){
  function init(){
  var body = document.body;
  if(!body.classList.contains('single-product')) return;
  var isJura = false, isNivona = false, skip = false;
  body.classList.forEach(function(c){
    if(c.indexOf('product_cat-jura-')===0) isJura = true;
    if(c.indexOf('product_cat-nivona-')===0) isNivona = true;
    if(c==='product_cat-jura-zubehoer' || c==='product_cat-jura-pflegeprodukte' || c==='product_cat-nivona-zubehoer' || c==='product_cat-nivona-pflegeprodukte') skip = true;
  });
  if(skip) return;
  if(!isJura){ if(!isNivona){ return; } }
  var catId = isJura ? 20 : 37;
  var main = document.querySelector('main');
  if(!main) return;
  var qs = ['category='+catId,'per_page=4','orderby=popularity'].join(String.fromCharCode(38));
  fetch('/wp-json/wc/store/v1/products?'+qs)
    .then(function(r){ return r.ok ? r.json() : []; })
    .then(function(items){
      if(!items || !items.length) return;
      var tiles = items.map(function(p){
        var img = (p.images ? p.images[0] : null) ? (p.images[0].thumbnail || p.images[0].src) : '';
        var price = p.prices ? (parseInt(p.prices.price,10)/Math.pow(10,p.prices.currency_minor_unit)).toFixed(2).replace('.',',')+' '+p.prices.currency_symbol : '';
        return '<a class="kt-rz-t" href="'+p.permalink+'">'+
          '<span class="pic" style="background-image:url(\''+img+'\')"></span>'+
          '<span class="nm">'+p.name+'</span>'+
          '<span class="pr">'+price+'</span></a>';
      }).join('');
      var sec = document.createElement('div');
      sec.className = 'kt-rz';
      sec.innerHTML = '<h2>Empfohlenes Zubeh&ouml;r</h2><div class="kt-rz-grid">'+tiles+'</div>';
      main.appendChild(sec);
    })
    .catch(function(){});
  }
  if(document.readyState==='loading'){document.addEventListener('DOMContentLoaded',init);}else{init();}
})();

</script>
	<?php
}, 5 );
