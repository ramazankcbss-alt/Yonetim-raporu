/**
 * Yönetim Raporu uygulaması — veri bağlantısı
 *
 * Bu kod "Haftalik_Yonetim_Raporu_Ciftlikler" Google E-Tablosuna eklenir
 * (Uzantılar → Apps Script). Telefondaki uygulama, rapor verilerini bu
 * kodun web adresinden okur. Kod sizin hesabınızla çalışır; uygulamada ayrıca
 * Google girişi gerekmez. Adres, yalnızca doğru "anahtar" ile birlikte
 * çağrıldığında veri verir.
 *
 * KURULUM (bir kez):
 *  1. Bu kodun tamamını yapıştırın ve kaydedin (Ctrl+S).
 *  2. Sağ üstte Dağıt → Yeni dağıtım → (dişli) Web uygulaması:
 *       Yürütme yetkisi: Ben
 *       Erişimi olanlar: Herkes
 *     Dağıt deyin, izinleri onaylayın, "Web uygulaması URL'si"ni kopyalayın.
 *  3. Aşağıdaki WEB_URL satırına bu adresi yapıştırın, kaydedin.
 *  4. Üstteki fonksiyon listesinden "kurulum"u seçip Çalıştır deyin.
 *     Bağlantı linki e-posta adresinize gelir. Telefonda bu e-postayı açıp
 *     linki kopyalayın ve uygulamadaki "Bağlantı linki" alanına yapıştırın.
 *
 * Kodu daha sonra değiştirirseniz: Dağıt → Dağıtımları yönet → (kalem) →
 * Sürüm: Yeni sürüm → Dağıt. Böylece adres değişmez.
 */

// 2. adımda kopyaladığınız adres (…/exec ile biter):
var WEB_URL = '';

var SAYFALAR = {
  ozet: 'Hayvan_Özet',
  gunluk: 'Hayvan_Günlük',
  tarim: 'Tarım_Veri',
  ekim: 'Ekim_Alanları',
  hasat: 'Hasat_Verim',
  besi: 'Besi_Plan',
  isler: 'Kontrol Paneli',
  isakisi: 'İş Akışı'
};

// Özel bölümler ("Özel Notlar – Sadece Ramazan Kocabaş" dosyası). Bu dosya
// paylaşılmadığı için yalnızca sahibi (siz) okuyup yazabilir; Apps Script
// sizin adınıza çalıştığından erişebilir.
var OZEL_DOSYA_ID = '1-XtWC5sj1RydL01_Exf3Dh8EQDkBqPj3wl1NM9HzX6o';
var OZEL_SAYFALAR = {
  ozelNotlar: { ad: 'Notlar', sutun: 5 },
  danismanlik: { ad: 'Danışmanlık', sutun: 6 },
  toplanti: { ad: 'Toplantı Notları', sutun: 7 },
  gunluk: { ad: 'Günlük', sutun: 4 }
};

/** Uygulamanın çağırdığı adres. */
function doGet(e) {
  var p = (e && e.parameter) || {};
  var anahtar = PropertiesService.getScriptProperties().getProperty('ANAHTAR');
  if (!anahtar) {
    return json_({ ok: false, hata: 'Kurulum yapılmamış: Apps Script\'te "kurulum" fonksiyonunu çalıştırın.' });
  }
  if (p.anahtar !== anahtar) {
    return json_({ ok: false, hata: 'Anahtar hatalı. Bağlantı linkini kurulum e-postasından yeniden kopyalayın.' });
  }
  try {
    if (p.bolum === 'ozel') return json_(ozelTopla_());
    var gun = Math.max(7, Math.min(1500, parseInt(p.gun, 10) || 400));
    return json_(veriTopla_(gun));
  } catch (err) {
    return json_({ ok: false, hata: 'Veri okunamadı: ' + err });
  }
}

/** Rapor verilerini toplar (uygulama bu yapıyı bekler). */
function veriTopla_(gun) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var tz = ss.getSpreadsheetTimeZone() || 'Europe/Istanbul';
  var sinir = new Date(Date.now() - gun * 24 * 3600 * 1000);

  function satirlar(ad, sutun) {
    var sh = ss.getSheetByName(ad);
    if (!sh) return [];
    var son = sh.getLastRow();
    if (son < 2) return [];
    return sh.getRange(2, 1, son - 1, sutun).getValues();
  }
  function hucre(v) {
    if (v instanceof Date) return Utilities.formatDate(v, tz, 'yyyy-MM-dd');
    if (v === null || v === undefined) return '';
    return v;
  }
  function tarihli(rows, tarihSutunu) {
    return rows
      .filter(function (r) {
        var t = r[tarihSutunu];
        return t instanceof Date && t >= sinir;
      })
      .map(function (r) { return r.map(hucre); });
  }
  function dolu(rows) {
    return rows
      .filter(function (r) { return String(r[0]).trim() !== ''; })
      .map(function (r) { return r.map(hucre); });
  }

  return {
    ok: true,
    surum: 1,
    olusturma: Utilities.formatDate(new Date(), tz, "yyyy-MM-dd'T'HH:mm:ss"),
    // Tarih, İşletme, Personel, Taşeron, Hayvan, Sağılan, Süt, Doğan Buzağı,
    // İnek/Düve Kesim-Satış, Buzağı Ölümü, Kesilen Dana
    hayvanOzet: tarihli(satirlar(SAYFALAR.ozet, 11), 0),
    // Tarih, Fethiye (Toplam, Sağmal, Kuru Gebe, Erkek, Süt, Satılan),
    // Erentepe (Toplam, Sağmal, Kuru Gebe, Erkek, Süt, Satılan)
    hayvanGunluk: tarihli(satirlar(SAYFALAR.gunluk, 13), 0),
    // Tarih, Çiftlik, Faaliyet
    tarim: tarihli(satirlar(SAYFALAR.tarim, 3), 0),
    // Çiftlik, Ürün, Plan (da), Ekilen (da)
    ekim: dolu(satirlar(SAYFALAR.ekim, 4)),
    // Ürün, Çiftlik, Alan (da), Toplam (kg), Verim (kg/da), Kayıt Tarihi
    hasat: dolu(satirlar(SAYFALAR.hasat, 6)),
    // İşletme, Yerli Dana, Kesimi Planlanan Erkek Dana, Kesimi Planlanan İnek
    besi: dolu(satirlar(SAYFALAR.besi, 4)),
    // No, Konu, Çiftlik/Birim, Kaynak, Açılış, Durum, Son değişiklik,
    // Son durum, Sorumlu (Kontrol Paneli sayfası, 8. satırdan itibaren)
    isler: islerOku_(tz),
    // No, Başlık, Bölüm, Durum/son gelişme, Firma, Tutar, Anahtar, Açılış,
    // Son güncelleme, Kaynak, Sonraki adım, Detay (İş Akışı sayfası, 2'den)
    isakisi: isAkisiOku_(tz)
  };
}

/** İş Akışı sayfasını okur (başlık 1. satırda, veri 2'den; 12 sütun). */
function isAkisiOku_(tz) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sh = ss.getSheetByName(SAYFALAR.isakisi);
  if (!sh) return [];
  var son = sh.getLastRow();
  if (son < 2) return [];
  var rows = sh.getRange(2, 1, son - 1, 12).getValues();
  return rows
    .filter(function (r) {
      var no = String(r[0]).trim();
      return no !== '' && !isNaN(parseFloat(no)) && String(r[1]).trim() !== '';
    })
    .map(function (r) {
      return r.map(function (v) {
        if (v instanceof Date) return Utilities.formatDate(v, tz, 'dd.MM.yyyy');
        if (v === null || v === undefined) return '';
        return v;
      });
    });
}

/** Kontrol Paneli'ndeki işleri okur (başlık 7. satırda, veri 8'den başlar). */
function islerOku_(tz) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sh = ss.getSheetByName(SAYFALAR.isler);
  if (!sh) return [];
  var son = sh.getLastRow();
  if (son < 8) return [];
  var rows = sh.getRange(8, 1, son - 7, 9).getValues();
  return rows
    .filter(function (r) {
      var no = String(r[0]).trim();
      return no !== '' && !isNaN(parseFloat(no)) && String(r[1]).trim() !== '';
    })
    .map(function (r) {
      return r.map(function (v) {
        if (v instanceof Date) return Utilities.formatDate(v, tz, 'yyyy-MM-dd');
        if (v === null || v === undefined) return '';
        return v;
      });
    });
}

/** Özel dosyadaki bölümleri okur (Danışmanlık, Toplantı, Özel Notlar, Günlük). */
function ozelTopla_() {
  var ss = SpreadsheetApp.openById(OZEL_DOSYA_ID);
  var tz = ss.getSpreadsheetTimeZone() || 'Europe/Istanbul';
  function oku(ad, sutun) {
    var sh = ss.getSheetByName(ad);
    if (!sh) return [];
    var son = sh.getLastRow();
    if (son < 2) return [];
    return sh.getRange(2, 1, son - 1, sutun).getValues()
      .filter(function (r) {
        return String(r[0]).trim() !== '' || String(r[1]).trim() !== '';
      })
      .map(function (r) {
        return r.map(function (v) {
          if (v instanceof Date) return Utilities.formatDate(v, tz, 'yyyy-MM-dd');
          if (v === null || v === undefined) return '';
          return v;
        });
      });
  }
  return {
    ok: true,
    ozelNotlar: oku(OZEL_SAYFALAR.ozelNotlar.ad, OZEL_SAYFALAR.ozelNotlar.sutun),
    danismanlik: oku(OZEL_SAYFALAR.danismanlik.ad, OZEL_SAYFALAR.danismanlik.sutun),
    toplanti: oku(OZEL_SAYFALAR.toplanti.ad, OZEL_SAYFALAR.toplanti.sutun),
    gunluk: oku(OZEL_SAYFALAR.gunluk.ad, OZEL_SAYFALAR.gunluk.sutun)
  };
}

/** Uygulamadan gelen yeni kayıtları (danışma, toplantı, günlük) ekler. */
function doPost(e) {
  var p = (e && e.parameter) || {};
  var anahtar = PropertiesService.getScriptProperties().getProperty('ANAHTAR');
  if (!anahtar || p.anahtar !== anahtar) {
    return json_({ ok: false, hata: 'Anahtar hatalı.' });
  }
  try {
    var govde = JSON.parse((e && e.postData && e.postData.contents) || '{}');
    var ss = SpreadsheetApp.openById(OZEL_DOSYA_ID);
    var tz = ss.getSpreadsheetTimeZone() || 'Europe/Istanbul';
    var bugun = Utilities.formatDate(new Date(), tz, 'dd.MM.yyyy');
    function ekle(ad, satir) {
      var sh = ss.getSheetByName(ad);
      if (!sh) throw new Error(ad + ' sayfası bulunamadı.');
      sh.appendRow(satir);
    }
    if (govde.tur === 'danismanlik') {
      ekle(OZEL_SAYFALAR.danismanlik.ad,
        [bugun, govde.konu || '', govde.soru || '', 'Yeni', '', '']);
    } else if (govde.tur === 'toplanti') {
      ekle(OZEL_SAYFALAR.toplanti.ad,
        [bugun, govde.yer || '', govde.katilimcilar || '', govde.konular || '',
          govde.notlar || '', '', '']);
    } else if (govde.tur === 'gunluk') {
      ekle(OZEL_SAYFALAR.gunluk.ad,
        [bugun, govde.baslik || '', govde.icerik || '', '']);
    } else {
      return json_({ ok: false, hata: 'Bilinmeyen kayıt türü.' });
    }
    return json_({ ok: true });
  } catch (err) {
    return json_({ ok: false, hata: 'Kaydedilemedi: ' + err });
  }
}

function json_(o) {
  return ContentService.createTextOutput(JSON.stringify(o))
    .setMimeType(ContentService.MimeType.JSON);
}

/**
 * Bir kez çalıştırın: gizli anahtarı oluşturur ve uygulamaya yapıştıracağınız
 * bağlantı linkini e-posta adresinize gönderir.
 */
function kurulum() {
  var props = PropertiesService.getScriptProperties();
  var anahtar = props.getProperty('ANAHTAR');
  if (!anahtar) {
    anahtar = Utilities.getUuid().replace(/-/g, '') + Utilities.getUuid().replace(/-/g, '').slice(0, 8);
    props.setProperty('ANAHTAR', anahtar);
  }
  var url = String(WEB_URL || '').trim();
  if (!url) {
    var hizmet = ScriptApp.getService().getUrl() || '';
    if (/\/exec$/.test(hizmet)) url = hizmet;
  }
  if (!/^https:\/\/script\.google\.com\/.+\/exec$/.test(url)) {
    throw new Error('Önce Dağıt → Yeni dağıtım ile web uygulamasını yayınlayın ve ' +
      'adresini (…/exec) kodun başındaki WEB_URL satırına yapıştırın, sonra kurulum\'u tekrar çalıştırın.');
  }
  // Kontrol: veri okunabiliyor mu?
  var v = veriTopla_(30);
  var link = url + '?anahtar=' + anahtar;
  var alici = Session.getEffectiveUser().getEmail();
  MailApp.sendEmail({
    to: alici,
    subject: 'Yönetim Raporu uygulaması — bağlantı linki',
    body:
      'Aşağıdaki linki telefonda kopyalayıp Yönetim Raporu uygulamasındaki ' +
      '"Bağlantı linki" alanına yapıştırın:\n\n' + link + '\n\n' +
      'Kontrol: son 30 günde ' + v.hayvanOzet.length + ' canlı hayvan özet satırı, ' +
      v.hayvanGunluk.length + ' günlük süt satırı ve ' + v.tarim.length +
      ' tarım kaydı okundu.\n\n' +
      'Bu link rapor verilerinizi okumaya yeter; kimseyle paylaşmayın. ' +
      'Linki değiştirmek isterseniz Apps Script\'te "anahtariYenile" fonksiyonunu çalıştırın.'
  });
  Logger.log('Bağlantı linki ' + alici + ' adresine gönderildi:\n' + link);
}

/** Link ele geçtiyse: yeni anahtar üretir, eski link çalışmaz olur. */
function anahtariYenile() {
  PropertiesService.getScriptProperties().deleteProperty('ANAHTAR');
  kurulum();
}
