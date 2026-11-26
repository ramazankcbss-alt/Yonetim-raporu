{{flutter_js}}
{{flutter_build_config}}

// Şirket panelinin sayfası (Apps Script) web sürümünü bu adresten yükler: window.YR_WEB = yayın adresi.
// Veri bu dosyalarda bulunmaz; panel köprüsüyle (yrSunucu) şirket hesabı ve paylaşım anahtarıyla gelir.
(function () {
  // Açılış durumu ve hatalar ekranın altında gösterilir (geliştirici araçları kapalı bilgisayarlar için).
  var kutu = document.createElement('div');
  kutu.id = 'yr-durum';
  kutu.style.cssText = 'position:fixed;left:0;right:0;bottom:0;z-index:99999;background:#fff7ed;color:#9a3412;' +
    'font:13px sans-serif;padding:8px 12px;border-top:1px solid #fdba74;white-space:pre-wrap;max-height:40%;overflow:auto';
  var satir = 0;
  function yaz(t) {
    if (++satir > 25) return; // aynı hata tekrar tekrar gelirse sayfa kilitlenmesin
    if (!kutu.parentNode && document.body) document.body.appendChild(kutu);
    kutu.textContent += t + '\n';
  }
  ['error'].forEach(function (k) {
    var eski = console[k];
    console[k] = function () { try { yaz((k === 'error' ? 'KONSOL HATA: ' : 'KONSOL UYARI: ') + Array.prototype.join.call(arguments, ' ').slice(0, 400)); } catch (e) {} return eski.apply(console, arguments); };
  });
  window.addEventListener('error', function (e) { yaz('HATA: ' + (e.message || e) + (e.filename ? ' @ ' + e.filename + ':' + e.lineno : '')); });
  window.addEventListener('unhandledrejection', function (e) { yaz('HATA (söz): ' + (e.reason && (e.reason.message || e.reason))); });
  yaz('1/4 Açılış dosyası yüklendi · köprü: ' + (typeof window.yrSunucu === 'function' ? 'var' : 'yok'));
  var taban = window.YR_WEB;
  // Sayfanın <base> adresi başka bir siteyi (CDN) gösterirse uygulamanın adres geçmişi işlemleri güvenlik hatası verir
  // ve sayfa kilitlenir; dosya adresleri aşağıda tam yazıldığı için <base> adresi kaldırılır.
  var b = document.querySelector('base');
  if (b && taban) b.removeAttribute('href');
  var ayar = taban ? { entrypointBaseUrl: taban, assetBase: taban } : {};
  try {
    _flutter.loader.load({
      config: ayar,
      onEntrypointLoaded: async function (motor) {
        try {
          yaz('2/4 Uygulama kodu yüklendi');
          var calistir = await motor.initializeEngine(ayar);
          yaz('3/4 Motor başlatıldı');
          var y = document.getElementById('yukl');
          if (y) y.remove();
          await calistir.runApp();
          yaz('4/4 Uygulama çalışıyor');
          setTimeout(function () {
            var v = document.querySelector('flutter-view') || document.querySelector('flt-glass-pane');
            var r = v ? v.getBoundingClientRect() : null;
            var gl = false;
            try { gl = !!document.createElement('canvas').getContext('webgl2'); } catch (e) {}
            yaz('Tanı: görünüm ' + (r ? Math.round(r.width) + 'x' + Math.round(r.height) : 'yok') + ' · tuval ' +
              document.querySelectorAll('canvas').length + ' · WebGL2 ' + (gl ? 'var' : 'yok') + ' · pencere ' + innerWidth + 'x' + innerHeight);
          }, 6000);
        } catch (e) { yaz('HATA (başlatma): ' + (e && (e.message || e))); }
      },
    });
  } catch (e) { yaz('HATA (yükleyici): ' + (e && (e.message || e))); }
})();
