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
  function yaz(t) { if (!kutu.parentNode && document.body) document.body.appendChild(kutu); kutu.textContent += t + '\n'; }
  window.addEventListener('error', function (e) { yaz('HATA: ' + (e.message || e) + (e.filename ? ' @ ' + e.filename + ':' + e.lineno : '')); });
  window.addEventListener('unhandledrejection', function (e) { yaz('HATA (söz): ' + (e.reason && (e.reason.message || e.reason))); });
  yaz('1/4 Açılış dosyası yüklendi · köprü: ' + (typeof window.yrSunucu === 'function' ? 'var' : 'yok'));
  var taban = window.YR_WEB;
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
          setTimeout(function () { if (kutu.textContent.indexOf('HATA') < 0 && kutu.parentNode) kutu.parentNode.removeChild(kutu); }, 8000);
        } catch (e) { yaz('HATA (başlatma): ' + (e && (e.message || e))); }
      },
    });
  } catch (e) { yaz('HATA (yükleyici): ' + (e && (e.message || e))); }
})();
