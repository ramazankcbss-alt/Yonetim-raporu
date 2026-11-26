{{flutter_js}}
{{flutter_build_config}}

// Şirket panelinin sayfası (Apps Script) web sürümünü bu adresten yükler: window.YR_WEB = yayın adresi.
// Veri bu dosyalarda bulunmaz; panel köprüsüyle (yrSunucu) şirket hesabı ve paylaşım anahtarıyla gelir.
(function () {
  var taban = window.YR_WEB;
  var ayar = taban ? { entrypointBaseUrl: taban, assetBase: taban } : {};
  _flutter.loader.load({
    config: ayar,
    onEntrypointLoaded: async function (motor) {
      var calistir = await motor.initializeEngine(ayar);
      var y = document.getElementById('yukl');
      if (y) y.remove();
      await calistir.runApp();
    },
  });
})();
