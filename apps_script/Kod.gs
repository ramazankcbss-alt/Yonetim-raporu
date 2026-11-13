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

// Geçmiş yıllar arşivi (Drive: Yönetim Raporu Arşivi / Bilgi Bankası)
var BILGI_BANKASI_ID = '1x9W9A1Eg7ItOu21lXTtx3vwHN3fFJZp05USSl1-aWLg';

var SAYFALAR = {
  ozet: 'Hayvan_Özet',
  gunluk: 'Hayvan_Günlük',
  tarim: 'Tarım_Veri',
  ekim: 'Ekim_Alanları',
  hasat: 'Hasat_Verim',
  besi: 'Besi_Plan',
  isler: 'Kontrol Paneli',
  isakisi: 'İş Akışı',
  arsiv: 'Arşiv',
  personel: 'Personel',
  kisiler: 'Kişiler',
  mesajKaydi: 'Mesaj_Kaydı',
  personelListesi: 'Personel_Listesi',
  eskAylik: 'ESK_Aylık',
  eskBilgi: 'ESK_Bilgi'
};

// "Eşitle" düğmesinin okuduğu kaynak tablolar.
var TARIM_ICMAL_ID = '1TF7yInFvLGCVjtxhK24YlKNVtHnhJ7TBEUANFGn5Pyg';
var CANLI_HAYVAN_VARSAYILAN_ID = '17XVTYfpnwZi98-yGVWpFyHscyEdh1TcjSMvP2UYmvHY';

// Özel bölümler ("Özel Notlar – Sadece Ramazan Kocabaş" dosyası). Bu dosya
// paylaşılmadığı için yalnızca sahibi (siz) okuyup yazabilir; Apps Script
// sizin adınıza çalıştığından erişebilir.
var OZEL_DOSYA_ID = '1-XtWC5sj1RydL01_Exf3Dh8EQDkBqPj3wl1NM9HzX6o';
var OZEL_SAYFALAR = {
  ozelNotlar: { ad: 'Notlar', sutun: 5 },
  danismanlik: { ad: 'Danışmanlık', sutun: 6 },
  toplanti: { ad: 'Toplantı Notları', sutun: 7 },
  gunluk: { ad: 'Günlük', sutun: 4 },
  // Kişi bazlı olaylar: Tarih, Kişi, Tür, Konu, Açıklama, Durum
  // (Olumsuz/Olumlu), Düzeltilme tarihi, Kaynak, Kimlik
  kisiOlaylari: { ad: 'Kişi_Olaylar', sutun: 9 }
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
    isakisi: isAkisiOku_(tz),
    // Tarih, Kategori, Konu, Gönderen, Özet, Ekler, Periyot (Arşiv, 2'den)
    arsiv: basitOku_(SAYFALAR.arsiv, 7, tz),
    // Dönem, Tür, Konu, Gönderen, Özet, Belge, Tarih (Personel, 2'den)
    personel: basitOku_(SAYFALAR.personel, 7, tz),
    // Ad Soyad, Görev/Birim, Telefon, E-posta, Eşleşme anahtarları, Not
    kisiler: basitOku_(SAYFALAR.kisiler, 6, tz),
    // Ad Soyad, Görev, Birim, Telefon, Sicil No (tüm çiftlik personeli)
    personelListesi: basitOku_(SAYFALAR.personelListesi, 5, tz),
    // Ay, Gelen, Hayvan-gün, Ort. baş, Panagro kesim, Dış kesim, Ölen,
    // Bakım geliri, Kira, Sap satışı, Sap maliyeti, İşletme gideri,
    // Kâr/Zarar, Durum, Not (ESK_Aylık, 2'den)
    eskAylik: basitOku_(SAYFALAR.eskAylik, 15, tz),
    // Bölüm, Başlık, Değer, Açıklama (ESK_Bilgi, 2'den)
    eskBilgi: basitOku_(SAYFALAR.eskBilgi, 4, tz),
    // Bilgi Bankası (ayrı tablo): Yıl, Ay, Alan, Konu, Gösterge, Değer, Birim, Kaynak, Not
    gecmis: basitOku_('Veriler', 9, tz, BILGI_BANKASI_ID),
    // Yıl, Alan, Konu, Ne oldu, Sonuç/ders, Kaynak
    dersler: basitOku_('Dersler', 6, tz, BILGI_BANKASI_ID)
  };
}

/** Başlık 1. satırda, veri 2'den olan düz bir sayfayı okur (ilk 2 sütun
 * dolu olan satırlar). Tarihler dd.MM.yyyy metnine çevrilir. */
function basitOku_(ad, sutun, tz, tabloId) {
  var ss;
  try {
    ss = tabloId ? SpreadsheetApp.openById(tabloId) : SpreadsheetApp.getActiveSpreadsheet();
  } catch (e) {
    return [];
  }
  var sh = ss.getSheetByName(ad);
  if (!sh) return [];
  var son = sh.getLastRow();
  if (son < 2) return [];
  return sh.getRange(2, 1, son - 1, sutun).getValues()
    .filter(function (r) {
      return String(r[0]).trim() !== '' || String(r[2]).trim() !== '';
    })
    .map(function (r) {
      return r.map(function (v) {
        if (v instanceof Date) return Utilities.formatDate(v, tz, 'dd.MM.yyyy');
        if (v === null || v === undefined) return '';
        return v;
      });
    });
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
    gunluk: oku(OZEL_SAYFALAR.gunluk.ad, OZEL_SAYFALAR.gunluk.sutun),
    kisiOlaylari: oku(OZEL_SAYFALAR.kisiOlaylari.ad, OZEL_SAYFALAR.kisiOlaylari.sutun)
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
    if (govde.tur === 'esitle') return json_(esitle_());
    if (govde.tur === 'mesaj') return json_(mesajGonder_(govde));
    if (govde.tur === 'kisi') return json_(kisiGuncelle_(govde));
    if (govde.tur === 'olay') return json_(olayDurumu_(govde));
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


// ---------------------------------------------------------------------------
// EŞİTLE: uygulamadaki "Güncelle/Eşitle" düğmesi. Canlı hayvan ve tarım kaynak
// tablolarındaki, raporda henüz olmayan günleri rapora ekler. Var olan
// satırlara dokunmaz (onları otomatik görev düzeltir).
// ---------------------------------------------------------------------------

function esitle_() {
  var kilit = LockService.getScriptLock();
  if (!kilit.tryLock(20000)) {
    return { ok: false, hata: 'Başka bir eşitleme sürüyor, biraz sonra tekrar deneyin.' };
  }
  try {
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    var tz = ss.getSpreadsheetTimeZone() || 'Europe/Istanbul';
    var sonuc = { ok: true, ozet: 0, gunluk: 0, tarim: 0, notlar: [] };
    try {
      var ch = canliHayvanDosyasi_();
      sonuc.ozet = ozetEsitle_(ss, ch, tz, sonuc.notlar);
      sonuc.gunluk = gunlukEsitle_(ss, ch, tz, sonuc.notlar);
    } catch (err) {
      sonuc.notlar.push('Canlı hayvan okunamadı: ' + err);
    }
    try {
      sonuc.tarim = tarimEsitle_(ss, tz);
    } catch (err) {
      sonuc.notlar.push('Tarım okunamadı: ' + err);
    }
    SpreadsheetApp.flush();
    sonuc.mesaj = (sonuc.ozet + sonuc.gunluk + sonuc.tarim) === 0
      ? 'Kaynaklarda yeni veri yok; rapor güncel.'
      : 'Eklendi: ' + sonuc.ozet + ' özet günü, ' + sonuc.gunluk +
        ' günlük süt/hayvan günü, ' + sonuc.tarim + ' tarım kaydı.';
    return sonuc;
  } finally {
    kilit.releaseLock();
  }
}

var AYLAR_ = ['OCAK', 'ŞUBAT', 'MART', 'NİSAN', 'MAYIS', 'HAZİRAN', 'TEMMUZ',
  'AĞUSTOS', 'EYLÜL', 'EKİM', 'KASIM', 'ARALIK'];

/** Bu ayın "CANLI HAYVAN GÜNCEL ÖZET RAPORU" dosyasını bulur. */
function canliHayvanDosyasi_() {
  var ay = AYLAR_[new Date().getMonth()];
  try {
    var it = DriveApp.searchFiles(
      'title contains "CANLI HAYVAN GÜNCEL ÖZET RAPORU" and ' +
      'mimeType = "application/vnd.google-apps.spreadsheet" and trashed = false');
    var enIyi = null, enIyiZaman = 0, ayli = null, ayliZaman = 0;
    while (it.hasNext()) {
      var f = it.next();
      var z = f.getLastUpdated().getTime();
      if (f.getName().toLocaleUpperCase('tr-TR').indexOf(ay) >= 0 && z > ayliZaman) {
        ayli = f; ayliZaman = z;
      }
      if (z > enIyiZaman) { enIyi = f; enIyiZaman = z; }
    }
    var sec = ayli || enIyi;
    if (sec) return SpreadsheetApp.openById(sec.getId());
  } catch (err) {
    // Drive araması olmazsa bilinen dosyaya düş.
  }
  return SpreadsheetApp.openById(CANLI_HAYVAN_VARSAYILAN_ID);
}

/** Türkçe biçimli sayıyı çevirir: '9.382' → 9382, '22,4' → 22.4. */
function sayi_(v) {
  if (typeof v === 'number') return v;
  var s = String(v === null || v === undefined ? '' : v).trim();
  if (s === '' || s.charAt(0) === '#') return '';
  s = s.replace(/\./g, '').replace(',', '.');
  var n = Number(s);
  return isNaN(n) ? '' : n;
}

var TZ_ = 'Europe/Istanbul';

/** Date, 'dd.MM.yyyy' veya 'dd/MM/yyyy' → 'yyyy-MM-dd' anahtarı (yoksa null). */
function tarihCoz_(v) {
  if (v instanceof Date) return Utilities.formatDate(v, TZ_, 'yyyy-MM-dd');
  var m = String(v || '').trim().match(/^(\d{1,2})[.\/](\d{1,2})[.\/](\d{4})$/);
  if (!m) return null;
  return m[3] + '-' + ('0' + m[2]).slice(-2) + '-' + ('0' + m[1]).slice(-2);
}

/** 'yyyy-MM-dd' → tabloya yazılacak 'dd.MM.yyyy' (tr_TR tarih olarak tanır). */
function yazTarih_(k) {
  return k.slice(8, 10) + '.' + k.slice(5, 7) + '.' + k.slice(0, 4);
}

function bugun_(gunOnce) {
  return Utilities.formatDate(new Date(Date.now() - (gunOnce || 0) * 86400000), TZ_, 'yyyy-MM-dd');
}

/** A sütunundaki son dolu satır (dizi formüllü sütunlardan etkilenmez). */
function sonSatirA_(sh) {
  var son = sh.getLastRow();
  if (son < 2) return 1;
  var a = sh.getRange(1, 1, son, 1).getValues();
  for (var i = a.length - 1; i >= 0; i--) {
    if (String(a[i][0]).trim() !== '') return i + 1;
  }
  return 1;
}

function mevcutGunler_(sh) {
  var son = sonSatirA_(sh), m = {};
  if (son < 2) return m;
  sh.getRange(2, 1, son - 1, 1).getValues().forEach(function (r) {
    var k = tarihCoz_(r[0]);
    if (k) m[k] = true;
  });
  return m;
}

/** Tarih sütununu metinden gerçek tarihe çevirerek yazar. */
function yaz_(sh, bas, satirlar, sutun) {
  sh.getRange(bas, 1, satirlar.length, sutun).setValues(satirlar);
  sh.getRange(bas, 1, satirlar.length, 1).setNumberFormat('dd.mm.yyyy');
}

var OZET_SIRA_ = ['Fethiye Şube', 'Fethiye Şube Holstein Besi', 'Pankent Çiftliği',
  'Erentepe Şube', 'Aslım Çiftliği Besi Danası', 'ESK-Taşağıl Çiftliği Besi Danası',
  'Yönetici - Müdür', 'Fethiye Şube Güvenlik', 'Çumpaş Çiftliği',
  'Aslım Çiftliği Güvenlik', 'ESK-Taşağıl Çiftliği Güvenlik', 'Konya Merkez Şeker Süt'];

function ozetEsitle_(ss, ch, tz, notlar) {
  var sh = ch.getSheetByName('ozet');
  if (!sh) { notlar.push("'ozet' sayfası yok"); return 0; }
  var v = sh.getRange(1, 1, 27, 18).getValues();
  var tarih = tarihCoz_(v[1][1]);
  if (!tarih || tarih > bugun_()) return 0;
  var hedef = ss.getSheetByName(SAYFALAR.ozet);
  if (mevcutGunler_(hedef)[tarih]) return 0;
  var kaynak = {};
  for (var i = 3; i < 16; i++) {
    var ad = String(v[i][0]).trim();
    if (!ad || /TOPLAM/i.test(ad)) continue;
    if (ad.toLocaleUpperCase('tr-TR') === 'YÖNETİCİ - MÜDÜR') ad = 'Yönetici - Müdür';
    kaynak[ad] = v[i];
  }
  var adlar = OZET_SIRA_.slice();
  Object.keys(kaynak).forEach(function (a) {
    if (adlar.indexOf(a) < 0) { adlar.push(a); notlar.push('Yeni işletme: ' + a); }
  });
  var satirlar = [];
  adlar.forEach(function (ad) {
    var r = kaynak[ad];
    if (!r) return;
    var hareket = [7, 9, 13, 15].some(function (k) { var n = sayi_(r[k]); return n !== '' && n !== 0; });
    var tam = sayi_(r[4]) !== '' || hareket;
    satirlar.push([yazTarih_(tarih), ad, sayi_(r[1]), sayi_(r[2]), sayi_(r[3]),
      tam ? sayi_(r[4]) : '', tam ? sayi_(r[5]) : '', tam ? sayi_(r[7]) : '',
      tam ? sayi_(r[9]) : '', tam ? sayi_(r[13]) : '', tam ? sayi_(r[15]) : '']);
  });
  if (!satirlar.length) return 0;
  yaz_(hedef, sonSatirA_(hedef) + 1, satirlar, 11);
  return 1;
}

function gunlukEsitle_(ss, ch, tz, notlar) {
  var sh = ch.getSheetByName('isletme');
  if (!sh) { notlar.push("'isletme' sayfası yok"); return 0; }
  var v = sh.getRange(1, 1, Math.min(sh.getLastRow(), 120), 33).getValues();
  var ozt = tarihCoz_(ch.getSheetByName('ozet').getRange(2, 2).getValue());
  if (!ozt) return 0;
  var yilAy = ozt.slice(0, 8);
  function blok(baslik) {
    var bas = -1;
    for (var i = 0; i < v.length; i++) {
      if (String(v[i][0]).trim().toLocaleUpperCase('tr-TR') === baslik) { bas = i; break; }
    }
    if (bas < 0) return null;
    var b = {};
    for (var j = bas + 1; j < v.length; j++) {
      var et = String(v[j][0]).trim().toLocaleLowerCase('tr-TR');
      if (et === 'tarih') break;
      if (!(et in b)) b[et] = v[j];
    }
    return b;
  }
  var fe = blok('FETHİYE ŞUBE'), er = blok('ERENTEPE ŞUBE');
  if (!fe) { notlar.push('Fethiye bloğu bulunamadı'); return 0; }
  var etiketler = ['toplam hayvan', 'sağmal hay', 'kuru gebe', 'erkek', 'sağılan süt', 'satılan süt'];
  function degerler(b, gun) {
    return etiketler.map(function (e) {
      var r = b && b[e];
      if (!r) return '';
      var n = sayi_(r[gun]);
      return n === 0 ? '' : n;
    });
  }
  var hedef = ss.getSheetByName(SAYFALAR.gunluk);
  var var_ = mevcutGunler_(hedef);
  var bugun = bugun_(), satirlar = [];
  var ayGun = new Date(Number(yilAy.slice(0, 4)), Number(yilAy.slice(5, 7)), 0).getDate();
  for (var gun = 1; gun <= ayGun; gun++) {
    var k = yilAy + ('0' + gun).slice(-2);
    if (k > bugun) break;
    if (var_[k]) continue;
    var f = degerler(fe, gun);
    if (f[4] === '' || f[0] === '') continue;
    satirlar.push([yazTarih_(k)].concat(f).concat(degerler(er, gun)));
  }
  if (!satirlar.length) return 0;
  yaz_(hedef, sonSatirA_(hedef) + 1, satirlar, 13);
  var son = sonSatirA_(hedef);
  hedef.getRange(2, 1, son - 1, 13).sort({ column: 1, ascending: true });
  return satirlar.length;
}

var TARIM_SAYFALARI_ = [['ŞEKER SÜT', 'Şekersüt'], ['ASLIM', 'Aslım'],
  ['TAŞAĞIL', 'Taşağıl'], ['FİDANLIK', 'Fidanlık']];

function cumle_(s) {
  var t = String(s).replace(/\s+/g, ' ').trim().toLocaleLowerCase('tr-TR');
  return t ? t.charAt(0).toLocaleUpperCase('tr-TR') + t.slice(1) : '';
}

function tarimEsitle_(ss, tz) {
  var kaynak = SpreadsheetApp.openById(TARIM_ICMAL_ID);
  var hedef = ss.getSheetByName(SAYFALAR.tarim);
  var son = sonSatirA_(hedef), var_ = {};
  if (son >= 2) {
    hedef.getRange(2, 1, son - 1, 2).getValues().forEach(function (r) {
      var k = tarihCoz_(r[0]);
      if (k) var_[String(r[1]).trim() + '|' + k] = true;
    });
  }
  var bugun = bugun_(), sinir = bugun_(21);
  var yeni = [];
  TARIM_SAYFALARI_.forEach(function (sp) {
    var sh = kaynak.getSheetByName(sp[0]);
    if (!sh) return;
    var sonK = sh.getLastRow();
    if (sonK < 4) return;
    var bas = Math.max(4, sonK - 300);
    var v = sh.getRange(bas, 1, sonK - bas + 1, Math.min(sh.getLastColumn(), 10)).getValues();
    var gunler = {};
    v.forEach(function (r) {
      var d = tarihCoz_(r[0]);
      if (!d || d < sinir || d > bugun) return;
      var parca = [];
      for (var k = 1; k < r.length; k++) {
        var x = r[k];
        if (x instanceof Date) continue;
        var s = String(x === null || x === undefined ? '' : x).trim();
        if (!s || /^-?[A-Za-zÇĞİÖŞÜçğıöşü]{3}-\d{4}$/.test(s)) continue;
        parca.push(s);
      }
      if (!parca.length) return;
      (gunler[d] = gunler[d] || { d: d, metin: [] }).metin.push(cumle_(parca.join(' – ')));
    });
    Object.keys(gunler).forEach(function (a) {
      if (var_[sp[1] + '|' + a]) return;
      yeni.push([yazTarih_(a), sp[1], gunler[a].metin.join('; ')]);
    });
  });
  if (!yeni.length) return 0;
  yaz_(hedef, son + 1, yeni, 3);
  var yeniSon = sonSatirA_(hedef);
  hedef.getRange(2, 1, yeniSon - 1, 3).sort([{ column: 1, ascending: true }, { column: 2, ascending: true }]);
  return yeni.length;
}

// ---------------------------------------------------------------------------
// KİŞİLER: uygulamadan e-posta gönderimi ve kişi bilgisi güncelleme.
// Yalnızca 'Kişiler' sayfasında kayıtlı adreslere gönderilir.
// ---------------------------------------------------------------------------

function kisilerOku_() {
  var sh = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SAYFALAR.kisiler);
  if (!sh) throw new Error("'Kişiler' sayfası bulunamadı.");
  var son = sh.getLastRow();
  return { sh: sh, satirlar: son < 2 ? [] : sh.getRange(2, 1, son - 1, 6).getValues() };
}

function mesajGonder_(g) {
  var ad = String(g.ad || '').trim();
  var konu = String(g.konu || '').trim();
  var metin = String(g.metin || '').trim();
  if (!ad || !konu || !metin) return { ok: false, hata: 'Kişi, konu ve mesaj gerekli.' };
  var k = kisilerOku_(), kisi = null;
  k.satirlar.forEach(function (r) { if (String(r[0]).trim() === ad) kisi = r; });
  if (!kisi) return { ok: false, hata: ad + " 'Kişiler' listesinde yok." };
  var eposta = String(kisi[3]).trim();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(eposta)) {
    return { ok: false, hata: ad + ' için geçerli e-posta adresi yok.' };
  }
  if (MailApp.getRemainingDailyQuota() < 1) {
    return { ok: false, hata: 'Günlük e-posta gönderim kotası doldu.' };
  }
  MailApp.sendEmail({ to: eposta, subject: konu, body: metin, name: 'Ramazan Kocabaş' });
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var log = ss.getSheetByName(SAYFALAR.mesajKaydi);
  if (!log) {
    log = ss.insertSheet(SAYFALAR.mesajKaydi);
    log.appendRow(['Zaman', 'Kanal', 'Kime', 'Adres', 'Konu', 'Mesaj']);
  }
  log.appendRow([new Date(), 'E-posta', ad, eposta, konu, metin]);
  return { ok: true };
}

function kisiGuncelle_(g) {
  var ad = String(g.ad || '').trim();
  if (!ad) return { ok: false, hata: 'Kişi adı gerekli.' };
  var k = kisilerOku_();
  for (var i = 0; i < k.satirlar.length; i++) {
    if (String(k.satirlar[i][0]).trim() !== ad) continue;
    if (g.telefon !== undefined) {
      k.sh.getRange(i + 2, 3).setNumberFormat('@').setValue(String(g.telefon).trim());
    }
    if (g.eposta !== undefined) k.sh.getRange(i + 2, 4).setValue(String(g.eposta).trim());
    return { ok: true };
  }
  var bas = k.sh.getLastRow() + 1;
  k.sh.getRange(bas, 3).setNumberFormat('@');
  k.sh.getRange(bas, 1, 1, 6).setValues([[ad, String(g.birim || ''),
    String(g.telefon || ''), String(g.eposta || ''), String(g.anahtar || ad), '']]);
  return { ok: true };
}

/** Kişi olayını Olumlu (düzeltildi) / Olumsuz olarak işaretler. */
function olayDurumu_(g) {
  var kimlik = String(g.kimlik || '').trim();
  var durum = g.durum === 'Olumlu' ? 'Olumlu' : 'Olumsuz';
  if (!kimlik) return { ok: false, hata: 'Olay kimliği gerekli.' };
  var sh = SpreadsheetApp.openById(OZEL_DOSYA_ID).getSheetByName(OZEL_SAYFALAR.kisiOlaylari.ad);
  if (!sh) return { ok: false, hata: "'Kişi_Olaylar' sayfası bulunamadı." };
  var son = sh.getLastRow();
  if (son < 2) return { ok: false, hata: 'Olay bulunamadı.' };
  var v = sh.getRange(2, 9, son - 1, 1).getValues();
  for (var i = 0; i < v.length; i++) {
    if (String(v[i][0]).trim() !== kimlik) continue;
    sh.getRange(i + 2, 6).setValue(durum);
    sh.getRange(i + 2, 7).setValue(durum === 'Olumlu'
      ? Utilities.formatDate(new Date(), TZ_, 'dd.MM.yyyy') : '');
    return { ok: true };
  }
  return { ok: false, hata: 'Olay bulunamadı.' };
}

/** Elle deneme: Apps Script editöründe çalıştırıp günlüğe bakın. */
function esitleDene() {
  Logger.log(JSON.stringify(esitle_()));
}
