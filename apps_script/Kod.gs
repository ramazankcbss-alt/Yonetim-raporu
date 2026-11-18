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
// Formenlerin "Günlük Tarım Bildirimi" Google Formu yanıt tablosu
var FORM_TABLO_ID = '17Q8craqrYd9UZ-QlOPp7M9qw6Rt16UjppgEypLquCVY';
var CANLI_HAYVAN_VARSAYILAN_ID = '17XVTYfpnwZi98-yGVWpFyHscyEdh1TcjSMvP2UYmvHY';

// Özel bölümler ("Özel Notlar – Sadece Ramazan Kocabaş" dosyası). Bu dosya
// paylaşılmadığı için yalnızca sahibi (siz) okuyup yazabilir; Apps Script
// sizin adınıza çalıştığından erişebilir.
// Araç Takip uygulamasının tablosu (salt okunur).
var ARAC_TABLO_ID = '1Pw9GSj3_d6T5epCgBLDwzRnrWiHYsLRp3Ifdx3rCybs';
// "Bakım Onarım Kayıtları" tablosu (Günlük Tarım Bildirimi formundan aktarılır,
// bakım onarım formeni onaylar). Salt okunur; kişisel veri içermez.
var BAKIM_TABLO_ID = '1S-2ziLyY2UdjOk6SM7A8Da2D_nPEhCa5R8yFMs5daaI';

/** Haftalık faaliyet raporu PDF'lerinin kaydedildiği Drive klasörü (paylaşılmaz). */
var RAPOR_KLASOR_ID = '1cZ7Hh5QEyEn52zflngLl6vZJsijU8PxG';
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
  // Veteriner Kontrol Paneli: sayfa veri içermez, veri kodla gelir (Veteriner.gs).
  if (p.panel === 'veteriner') return vetPanel_();
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
    // sutun = 0: sayfadaki tüm sütunlar (sonradan eklenen sütunlar için yeniden dağıtım gerekmez)
  var w = sutun > 0 ? sutun : Math.max(1, sh.getLastColumn());
  return sh.getRange(2, 1, son - 1, w).getValues();
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
    // İnek/Düve Kesim-Satış, Buzağı Ölümü, Kesilen Dana, İnek Ölüm,
    // Genç Kesim/Satış, Genç Ölüm, Yavru Atma/Ölü Doğum, Ölen Dana,
    // Dışarıdan Alınan, Satılan/Transfer Dana
    hayvanOzet: tarihli(satirlar(SAYFALAR.ozet, 18), 0),
    // Tarih, Fethiye (Toplam, Sağmal, Kuru Gebe, Erkek, Süt, Satılan),
    // Erentepe (Toplam, Sağmal, Kuru Gebe, Erkek, Süt, Satılan)
    hayvanGunluk: tarihli(satirlar(SAYFALAR.gunluk, 13), 0),
    // Tarih, İşletme, Bölüm, Gösterge, Değer — işletme günlük raporlarının
    // tüm satırları (personel listesi hariç), son 70 gün
    // Tarih, Dosya, Konu, Çiftlik, Bulgu, Veri günü, Durum, Bağlantı —
    // günlük Drive incelemesinin bulguları (kişisel veri içermez), son 45 gün
    driveBulgular: satirlar('Drive_Bulgular', 8)
      .filter(function (r) {
        return r[0] instanceof Date && r[0] >= new Date(Date.now() - 45 * 86400000);
      })
      .map(function (r) { return r.map(hucre); }),
    hayvanDetay: satirlar(DETAY_SAYFA_, 5)
      .filter(function (r) {
        return r[0] instanceof Date && r[0] >= new Date(Date.now() - 70 * 86400000);
      })
      .map(function (r) { return r.map(hucre); }),
    // Tarih, Çiftlik, Faaliyet[, Kaynak] — icmal + formen bildirim formu
    tarim: tarihli(satirlar(SAYFALAR.tarim, 3), 0)
      .concat(tarihli(formBildirimleri_(), 0)),
    // Çiftlik, Ürün, Plan (da), Ekilen (da)
    ekim: dolu(satirlar(SAYFALAR.ekim, 4)),
    // Ürün, Çiftlik, Alan (da), Toplam (kg), Verim (kg/da), Kayıt Tarihi
    hasat: dolu(satirlar(SAYFALAR.hasat, 6)),
    // İşletme, Yerli Dana, Kesimi Planlanan Erkek Dana, Kesimi Planlanan İnek
    besi: dolu(satirlar(SAYFALAR.besi, 4)),
    // No, Konu, Çiftlik/Birim, Kaynak, Açılış, Durum, Son değişiklik,
    // Son durum, Sorumlu (Kontrol Paneli sayfası, 8. satırdan itibaren)
    isler: [], // KVKK: Kontrol Paneli uygulamadan kaldırıldı
    // No, Başlık, Bölüm, Durum/son gelişme, Firma, Tutar, Anahtar, Açılış,
    // Son güncelleme, Kaynak, Sonraki adım, Detay (İş Akışı sayfası, 2'den)
    isakisi: [], // KVKK: İş Akışı uygulamadan kaldırıldı
    // Tarih, Kategori, Konu, Gönderen, Özet, Ekler, Periyot (Arşiv, 2'den)
    arsiv: [], // KVKK: Belge Havuzu uygulamadan kaldırıldı
    // Dönem, Tür, Konu, Gönderen, Özet, Belge, Tarih (Personel, 2'den)
    personel: [], // KVKK: Personel/Puantaj uygulamadan kaldırıldı
    // Ad Soyad, Görev/Birim, Telefon, E-posta, Eşleşme anahtarları, Not
    kisiler: [], // KVKK: Kişiler uygulamadan kaldırıldı
    // Ad Soyad, Görev, Birim, Telefon, Sicil No (tüm çiftlik personeli)
    personelListesi: [], // KVKK: telefon ve sicil bilgisi gönderilmez
    // Ay, Gelen, Hayvan-gün, Ort. baş, Panagro kesim, Dış kesim, Ölen,
    // Bakım geliri, Kira, Sap satışı, Sap maliyeti, İşletme gideri,
    // Kâr/Zarar, Durum, Not (ESK_Aylık, 2'den)
    eskAylik: basitOku_(SAYFALAR.eskAylik, 15, tz),
    // Bölüm, Başlık, Değer, Açıklama (ESK_Bilgi, 2'den)
    eskBilgi: basitOku_(SAYFALAR.eskBilgi, 4, tz),
    // Bilgi Bankası (ayrı tablo): Yıl, Ay, Alan, Konu, Gösterge, Değer, Birim, Kaynak, Not
    gecmis: basitOku_('Veriler', 9, tz, BILGI_BANKASI_ID),
    // Yıl, Alan, Konu, Ne oldu, Sonuç/ders, Kaynak
    dersler: basitOku_('Dersler', 6, tz, BILGI_BANKASI_ID),
    // Araç Takip (ayrı tablo, salt okunur)
    aracListe: basitOku_('Araçlar', 0, tz, ARAC_TABLO_ID),
    aracKullanim: sonSatirlar_(basitOku_('Kullanım', 0, tz, ARAC_TABLO_ID), 800),
    aracPlan: basitOku_('Bakım_Plan', 0, tz, ARAC_TABLO_ID),
    aracBakim: sonSatirlar_(basitOku_('Bakım_Kayıt', 0, tz, ARAC_TABLO_ID), 500),
    aracAriza: sonSatirlar_(basitOku_('Arıza', 0, tz, ARAC_TABLO_ID), 400),
    aracMutabakat: [], // KVKK: Mutabakat kontrolü uygulamadan kaldırıldı
    aracIsEmri: sonSatirlar_(basitOku_('İş_Emirleri', 0, tz, ARAC_TABLO_ID), 600),
    // Bakım Onarım Kayıtları: No, Bildirim zamanı, Çiftlik, Bildiren (görev),
    // Makine/ekipman, İşlem türü, Çalışma saati/km, Yapılan iş, Malzeme/parça,
    // Tedarik durumu, Servis, Durum, Onay (Evet/boş), Onay zamanı
    bakimOnarim: sonSatirlar_(bakimOnarimOku_(tz), 600),
    // Veteriner Kontrol Paneli: kodlar (Kod, Etiket, Oluşturma, Durum, Son giriş)
    // ve veterinerlerin bildirimleri (Veteriner.gs)
    veteriner: (function () {
      try { return vetUygulamaVerisi_(); } catch (err) { return { kodlar: [], bildirimler: [] }; }
    })()
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

/** Listenin son [n] satırı (en eskiler atılır). */
function sonSatirlar_(l, n) {
  return l.length > n ? l.slice(l.length - n) : l;
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
  // satirNo: true ise her kaydın sonuna tablodaki satır numarası eklenir
  // (uygulamadan değiştir/sil için).
  function oku(ad, sutun, satirNo) {
    var sh = ss.getSheetByName(ad);
    if (!sh) return [];
    var son = sh.getLastRow();
    if (son < 2) return [];
    return sh.getRange(2, 1, son - 1, sutun).getValues()
      .map(function (r, i) {
        var satir = r.map(function (v) {
          if (v instanceof Date) return Utilities.formatDate(v, tz, 'yyyy-MM-dd');
          if (v === null || v === undefined) return '';
          return v;
        });
        if (satirNo) satir.push(i + 2);
        return satir;
      })
      .filter(function (r) {
        return String(r[0]).trim() !== '' || String(r[1]).trim() !== '';
      });
  }
  return {
    ok: true,
    ozelNotlar: [], // KVKK: Özel Notlar uygulamadan kaldırıldı
    danismanlik: [], // KVKK: Danışmanlık uygulamadan kaldırıldı
    toplanti: oku(OZEL_SAYFALAR.toplanti.ad, OZEL_SAYFALAR.toplanti.sutun),
    gunluk: oku(OZEL_SAYFALAR.gunluk.ad, OZEL_SAYFALAR.gunluk.sutun),
    kisiOlaylari: [] // KVKK: kişi olayları uygulamadan kaldırıldı
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
    // KVKK: kişi, olay, mesaj ve danışmanlık işlemleri kapatıldı.
    if (['mesaj', 'kisi', 'olay', 'danismanlik', 'danismanlikDuzenle', 'danismanlikSil']
        .indexOf(govde.tur) >= 0) {
      return json_({ ok: false, hata: 'Bu bölüm KVKK kapsamında kaldırıldı.' });
    }
    if (govde.tur === 'raporKaydet') return json_(raporKaydet_(govde));
    if (String(govde.tur).indexOf('vet') === 0) return json_(vetYonetim_(govde));
    var ss = SpreadsheetApp.openById(OZEL_DOSYA_ID);
    var tz = ss.getSpreadsheetTimeZone() || 'Europe/Istanbul';
    var bugun = Utilities.formatDate(new Date(), tz, 'dd.MM.yyyy');
    function ekle(ad, satir) {
      var sh = ss.getSheetByName(ad);
      if (!sh) throw new Error(ad + ' sayfası bulunamadı.');
      sh.appendRow(satir);
    }
    if (govde.tur === 'danismanlikDuzenle' || govde.tur === 'danismanlikSil') {
      var dsh = ss.getSheetByName(OZEL_SAYFALAR.danismanlik.ad);
      var no = parseInt(govde.satir, 10);
      if (!dsh || !(no >= 2) || no > dsh.getLastRow()) {
        return json_({ ok: false, hata: 'Soru bulunamadı; listeyi yenileyip tekrar deneyin.' });
      }
      var mevcut = String(dsh.getRange(no, 3).getValue()).trim();
      if (mevcut !== String(govde.eskiSoru || '').trim()) {
        return json_({ ok: false, hata: 'Tablo bu arada değişmiş; listeyi yenileyip tekrar deneyin.' });
      }
      if (govde.tur === 'danismanlikSil') {
        dsh.deleteRow(no);
      } else {
        dsh.getRange(no, 2, 1, 5).setValues([[govde.konu || '', govde.soru || '', 'Yeni', '', '']]);
      }
      return json_({ ok: true });
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
    try {
      sonuc.detay = detayEsitle_(ss, 2, sonuc.notlar);
    } catch (err) {
      sonuc.detay = 0;
      sonuc.notlar.push('İşletme raporları okunamadı: ' + err);
    }
    SpreadsheetApp.flush();
    if (sonuc.detay) sonuc.notlar.push('İşletme raporları: ' + sonuc.detay + ' işletme-gün güncellendi');
    sonuc.mesaj = (sonuc.ozet + sonuc.gunluk + sonuc.tarim + (sonuc.detay || 0)) === 0
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
  // Kaynak sütunları: H Doğan, J İnek-Düve Kesim/Satış, N Buzağı Ölümü,
  // P Kesilen Dana, K İnek Ölüm, L Genç Kesim/Satış, M Genç Ölüm,
  // O Yavru Atma/Ölü Doğum, Q Ölen Dana, I Dışarıdan Alınan, R Satılan/Transfer.
  var OLAY = [7, 9, 13, 15, 10, 11, 12, 14, 16, 8, 17];
  var satirlar = [];
  adlar.forEach(function (ad) {
    var r = kaynak[ad];
    if (!r) return;
    var hareket = OLAY.some(function (k) { var n = sayi_(r[k]); return n !== '' && n !== 0; });
    var tam = sayi_(r[4]) !== '' || hareket;
    satirlar.push([yazTarih_(tarih), ad, sayi_(r[1]), sayi_(r[2]), sayi_(r[3]),
      tam ? sayi_(r[4]) : '', tam ? sayi_(r[5]) : ''].concat(
      OLAY.map(function (k) { return tam ? sayi_(r[k]) : ''; })));
  });
  if (!satirlar.length) return 0;

  // Gün zaten varsa: kaynakta sonradan düzeltilen/eklenen değerleri güncelle.
  var son = sonSatirA_(hedef);
  if (mevcutGunler_(hedef)[tarih]) {
    var mevcut = hedef.getRange(2, 1, son - 1, 18).getValues();
    var degisti = 0;
    satirlar.forEach(function (yeni) {
      for (var j = 0; j < mevcut.length; j++) {
        if (tarihCoz_(mevcut[j][0]) !== tarih || String(mevcut[j][1]).trim() !== yeni[1]) continue;
        var fark = false;
        for (var c = 2; c < 18; c++) {
          var a = mevcut[j][c] === '' ? '' : Number(mevcut[j][c]);
          var b = yeni[c] === '' ? '' : Number(yeni[c]);
          if (a !== b) { fark = true; break; }
        }
        if (fark) {
          hedef.getRange(j + 2, 3, 1, 16).setValues([yeni.slice(2)]);
          degisti++;
        }
        break;
      }
    });
    if (degisti) notlar.push(yazTarih_(tarih) + ' canlı hayvan özeti güncellendi (' + degisti + ' işletme)');
    return degisti ? 1 : 0;
  }
  yaz_(hedef, son + 1, satirlar, 18);
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


// ---------------------------------------------------------------------------
// FORMEN BİLDİRİM FORMU: yanıtlar tarım kaydına çevrilir (okuma anında; tabloya
// kopyalanmaz). KVKK: formda kişi bilgisi toplanmaz; not alanlarındaki olası
// kişi adları uygulamada raporlanmadan önce ayıklanır.
// ---------------------------------------------------------------------------

function formBildirimleri_() {
  var sh;
  try {
    var t = SpreadsheetApp.openById(FORM_TABLO_ID);
    sh = t.getSheets().filter(function (x) {
      return x.getLastColumn() > 0 &&
        x.getRange(1, 1, 1, x.getLastColumn()).getValues()[0].indexOf('Çiftlik') >= 0;
    })[0];
  } catch (e) {
    return [];
  }
  if (!sh || sh.getLastRow() < 2) return [];
  var v = sh.getRange(1, 1, sh.getLastRow(), sh.getLastColumn()).getValues();
  // Formda aynı başlık birden çok kez geçer (1. iş, 2. iş…): her başlığın
  // sütunları sırayla tutulur, n. iş n. sütundan okunur.
  var b = {};
  v[0].forEach(function (h, i) {
    var a = String(h).trim();
    (b[a] = b[a] || []).push(i);
  });
  function deger(x) {
    return x instanceof Date ? x : String(x === null || x === undefined ? '' : x).trim();
  }
  // n verilmezse: aynı başlıklı sütunlardan ilk dolu olan (form yeniden
  // düzenlendiğinde eski sütunlar tabloda kalır).
  function al(r, ad, n) {
    var s = b[ad];
    if (!s) return '';
    if (n !== undefined) return s[n] === undefined ? '' : deger(r[s[n]]);
    for (var i = 0; i < s.length; i++) {
      var x = deger(r[s[i]]);
      if (x !== '') return x;
    }
    return '';
  }
  function sayi(x) {
    var n = parseFloat(String(x).replace(',', '.'));
    return isNaN(n) ? '' : String(Math.round(n * 100) / 100).replace('.', ',');
  }
  var isAdet = (b['İş türü'] || []).length;
  var mAdet = (b['Hareket'] || []).length;
  var sonuc = [];
  for (var k = 1; k < v.length; k++) {
    var r = v[k];
    var tarih = al(r, 'Tarih (bugünden farklıysa)');
    if (!(tarih instanceof Date)) tarih = al(r, 'Tarih');
    if (!(tarih instanceof Date)) tarih = al(r, 'Zaman damgası');
    if (!(tarih instanceof Date)) continue;
    var ciftlik = al(r, 'Çiftlik');
    if (!ciftlik) continue;
    // Sedef Hanım kontrolü: reddedilen kullanılmaz, işaretlenmemiş "bekliyor"
    var kontrol = al(r, 'Kontrol durumu');
    if (kontrol === 'Reddedildi') continue;
    var kaynak = kontrol === 'Onaylandı' ? 'Form' : 'Form-Bekliyor';

    for (var n = 0; n < isAdet; n++) {
      var is = al(r, 'İş türü', n), urun = al(r, 'Ürün', n);
      var dk = sayi(al(r, 'Yapılan alan (dekar)', n));
      if (!is || !dk) continue;
      var etiket = is === 'Ekim' ? (urun && urun !== 'Diğer' ? urun + ' ekimi' : 'Ekim')
        : is + (urun && urun !== 'Diğer' && is !== 'Şeker pancarı sökümü' ? ' – ' + urun : '');
      var metin = etiket + ': ' + dk + ' dekar';
      if (al(r, 'Pivot / parsel', n)) metin += ' (' + al(r, 'Pivot / parsel', n) + ')';
      if (al(r, 'İş durumu', n) === 'Tamamlandı') metin += ', tamamlandı';
      if (al(r, 'Faaliyet notu', n)) metin += '; ' + al(r, 'Faaliyet notu', n);
      sonuc.push([tarih, ciftlik, metin.replace(/[\r\n]+/g, ' '), kaynak]);
    }

    for (var m = 0; m < mAdet; m++) {
      var hareket = al(r, 'Hareket', m);
      var miktar = sayi(al(r, 'Miktar', m));
      if (!hareket || !miktar) continue;
      var giris = hareket.indexOf('Giriş') === 0;
      var yer = al(r, 'Nereden / nereye', m);
      var yerMetin = yer === 'Dış tedarik' ? 'dış tedarik'
        : yer === 'Diğer' || !yer ? 'diğer'
        : yer + (giris ? ' çiftliğinden' : ' çiftliğine');
      var mm = (giris ? 'Malzeme girişi: ' : 'Malzeme çıkışı: ') + miktar + ' ' +
        al(r, 'Birim', m) + ' ' + al(r, 'Malzeme adı / çeşit', m) + ' (' + yerMetin + ')';
      if (al(r, 'Belge no', m)) mm += '; Belge no: ' + al(r, 'Belge no', m);
      if (al(r, 'Malzeme notu', m)) mm += '; ' + al(r, 'Malzeme notu', m);
      sonuc.push([tarih, ciftlik, mm.replace(/[\r\n]+/g, ' '), kaynak]);
    }
  }
  return sonuc;
}

// ---------------------------------------------------------------------------
// Bakım Onarım Kayıtları (ayrı tablo, salt okunur). Sütunlar başlık adına göre
// okunur; tabloya sonradan sütun eklense de sıra bozulmaz. Tabloda kişi adı
// yoktur ("Bildiren" görevdir); başka sütun eklenirse uygulamaya gönderilmez.
// ---------------------------------------------------------------------------

function bakimOnarimOku_(tz) {
  var sh;
  try {
    var t = SpreadsheetApp.openById(BAKIM_TABLO_ID);
    sh = t.getSheetByName('Kayıtlar') || t.getSheets()[0];
  } catch (e) {
    return [];
  }
  if (!sh || sh.getLastRow() < 2) return [];
  var v = sh.getRange(1, 1, sh.getLastRow(), sh.getLastColumn()).getValues();
  var bas = v[0].map(function (h) { return String(h).trim(); });
  var alanlar = ['Kayıt No', 'Bildirim zamanı', 'Çiftlik', 'Bildiren', 'Makine / ekipman',
    'İşlem türü', 'Çalışma saati / km', 'Yapılan iş', 'Kullanılan malzeme / yedek parça',
    'Tedarik durumu', 'Servis', 'Durum', 'Onay', 'Onay zamanı'];
  var sut = alanlar.map(function (a) { return bas.indexOf(a); });
  function metin(x, zamanli) {
    if (x instanceof Date) return Utilities.formatDate(x, tz, zamanli ? 'dd.MM.yyyy HH:mm' : 'dd.MM.yyyy');
    return String(x === null || x === undefined ? '' : x).replace(/[\r\n]+/g, ' ').trim();
  }
  var sonuc = [];
  for (var k = 1; k < v.length; k++) {
    var r = v[k];
    var satir = sut.map(function (i, n) {
      if (i < 0) return '';
      var x = r[i];
      if (n === 12) return x === true || String(x).toUpperCase() === 'TRUE' ? 'Evet' : '';
      return metin(x, n === 1 || n === 13);
    });
    // Çiftlik: eski form sürümünde "Bakım Onarım" seçeneği de yazılıyordu
    satir[2] = satir[2].split(',').map(function (c) { return c.trim(); })
      .filter(function (c) { return c && c !== 'Bakım Onarım'; }).join(', ');
    if (!satir[4] && !satir[7]) continue; // makine ve yapılan iş boşsa kayıt değil
    sonuc.push(satir);
  }
  return sonuc;
}


/**
 * Uygulamada oluşturulan haftalık rapor PDF'ini "Haftalık Faaliyet Raporları"
 * klasörüne kaydeder. Her hafta için tek dosya tutulur: dosya varsa içeriği
 * güncellenir (Drive eski içeriği "Sürümleri yönet" altında saklar), yoksa
 * oluşturulur. İçerik aynıysa hiçbir şey yapılmaz.
 * Gerekli: Hizmetler → Drive API (gelişmiş hizmet).
 * KVKK: PDF'te kişi adı bulunmaz; klasör kimseyle paylaşılmaz.
 */
function raporKaydet_(g) {
  var ad = String(g.ad || '');
  if (!/^Haftalik_Rapor_\d{1,2}_Hafta_\d{4}\.pdf$/.test(ad)) {
    return { ok: false, hata: 'Geçersiz rapor adı.' };
  }
  var bayt = Utilities.base64Decode(String(g.pdf || ''));
  if (bayt.length < 100 || bayt.length > 5 * 1024 * 1024) {
    return { ok: false, hata: 'Rapor dosyası okunamadı.' };
  }
  var ozet = function (b) {
    return Utilities.base64Encode(
      Utilities.computeDigest(Utilities.DigestAlgorithm.MD5, b));
  };
  var blob = Utilities.newBlob(bayt, 'application/pdf', ad);
  var klasor = DriveApp.getFolderById(RAPOR_KLASOR_ID);
  var it = klasor.getFilesByName(ad);
  var mevcut = it.hasNext() ? it.next() : null;
  if (!mevcut) {
    klasor.createFile(blob);
    return { ok: true, mesaj: 'Rapor Drive\'a kaydedildi: ' + ad };
  }
  if (ozet(mevcut.getBlob().getBytes()) === ozet(bayt)) {
    return { ok: true, mesaj: 'Drive\'daki rapor zaten güncel: ' + ad };
  }
  if (typeof Drive === 'undefined') {
    return { ok: false, hata: 'Raporu güncellemek için Apps Script\'te ' +
      'Hizmetler → Drive API eklenmelidir.' };
  }
  Drive.Files.update({}, mevcut.getId(), blob);
  return { ok: true, mesaj: 'Drive\'daki rapor güncellendi: ' + ad };
}

/**
 * Bir kez editörden çalıştırın: Drive'a rapor kaydetme iznini ister
 * (izin ekranında Google Drive kutusunu işaretleyin). Dosya oluşturmaz.
 */
function driveIzniVer() {
  ScriptApp.requireScopes(ScriptApp.AuthMode.FULL,
    ['https://www.googleapis.com/auth/drive']);
  Logger.log('Drive izni var. Klasör: ' + DriveApp.getFolderById(RAPOR_KLASOR_ID).getName());
}


// ---------------------------------------------------------------------------
// İŞLETME GÜNLÜK RAPORLARI (Fethiye, Erentepe, Aslım, ESK-Taşağıl)
// Her dosyada aylık sayfalar vardır; satırlar gösterge, sütunlar ayın
// günleridir. Başlık satırlarının B hücresi tarihtir ("1-Kas"). Tüm
// göstergeler "Hayvan_Detay" sayfasına uzun biçimde yazılır:
// Tarih | İşletme | Bölüm | Gösterge | Değer (yalnızca sıfırdan farklı).
// KVKK: "PERSONEL" başlığından sonraki satırlar (kişi listesi) OKUNMAZ;
// yalnızca personel sayıları alınır.
// ---------------------------------------------------------------------------

var DETAY_SAYFA_ = 'Hayvan_Detay';
var DETAY_DOSYALAR_ = [
  { isletme: 'Fethiye Şube', ara: 'fethiye şube raporları' },
  { isletme: 'Erentepe Şube', ara: 'erentepe şube raporları' },
  { isletme: 'Aslım Çiftliği', ara: 'aslım raporları' },
  { isletme: 'ESK-Taşağıl Çiftliği', ara: 'ESK raporlar' }
];

/** Başlığında aranan ifade geçen, en son güncellenen tabloyu bulur. */
function detayDosyasi_(ara) {
  var it = DriveApp.searchFiles('title contains "' + ara + '" and ' +
    'mimeType = "application/vnd.google-apps.spreadsheet" and trashed = false');
  var en = null, z = 0;
  while (it.hasNext()) {
    var f = it.next();
    var t = f.getLastUpdated().getTime();
    if (t > z) { en = f; z = t; }
  }
  return en ? SpreadsheetApp.openById(en.getId()) : null;
}

var AY_KISA_ = ['oca', 'şub', 'mar', 'nis', 'may', 'haz', 'tem', 'ağu', 'eyl', 'eki', 'kas', 'ara'];

/** Başlık hücresi: tarih ya da "1-Kas" metni → Date (yıl bilinmiyorsa bu yıl). */
function baslikTarihi_(h) {
  if (h instanceof Date) return h;
  var m = String(h || '').trim().toLocaleLowerCase('tr-TR')
    .match(/^(\d{1,2})[-.\s]([a-zçğıöşü]{3})/);
  if (!m) return null;
  var ay = AY_KISA_.indexOf(m[2]);
  if (ay < 0) return null;
  var simdi = new Date();
  var yil = simdi.getFullYear() - (ay > simdi.getMonth() ? 1 : 0);
  return new Date(yil, ay, Number(m[1]));
}

/** Sayfadaki ilk başlık satırının tarihinden ayı bulur (yyyy-MM) ya da null. */
function detayAyi_(sh) {
  var v = sh.getRange(1, 1, Math.min(4, sh.getMaxRows()), 2).getValues();
  for (var i = 0; i < v.length; i++) {
    var t = baslikTarihi_(v[i][1]);
    if (t) return Utilities.formatDate(t, TZ_, 'yyyy-MM');
  }
  return null;
}

/** Bir aylık sayfayı okur: { 'yyyy-MM-dd': [[bölüm, gösterge, değer], ...] } */
function detaySayfaOku_(sh) {
  var sonSatir = sh.getLastRow();
  if (sonSatir < 2) return {};
  // Önce yalnızca A sütunu: PERSONEL bloğunun başladığı satırı bul (KVKK).
  var a = sh.getRange(1, 1, sonSatir, 1).getValues();
  var bitis = sonSatir;
  for (var i = 0; i < a.length; i++) {
    if (String(a[i][0]).trim().toLocaleUpperCase('tr-TR') === 'PERSONEL') { bitis = i; break; }
  }
  if (bitis < 1) return {};
  var v = sh.getRange(1, 1, bitis, Math.min(sh.getLastColumn(), 33)).getValues();
  var yil = null, ay = null, bolum = '', sonuc = {};
  var bugun = bugun_();
  for (var r = 0; r < v.length; r++) {
    var etiket = String(v[r][0]).replace(/\s+/g, ' ').trim();
    var bt = baslikTarihi_(v[r][1]);
    if (bt) {                                // başlık satırı
      bolum = etiket;
      yil = bt.getFullYear(); ay = bt.getMonth();
      continue;
    }
    if (!etiket || yil === null) continue;
    if (/\/\s*(topl|hay)/i.test(etiket)) continue;   // oran satırları
    var gunSayisi = new Date(yil, ay + 1, 0).getDate();
    for (var g = 1; g <= gunSayisi && g < v[r].length; g++) {
      var ham = v[r][g];
      if (typeof ham === 'string' && /[%#]/.test(ham)) continue;
      var n = sayi_(ham);
      if (n === '' || n === 0 || isNaN(n)) continue;
      var k = yil + '-' + ('0' + (ay + 1)).slice(-2) + '-' + ('0' + g).slice(-2);
      if (k > bugun) continue;
      (sonuc[k] = sonuc[k] || []).push([bolum, etiket, n]);
    }
  }
  return sonuc;
}

/**
 * İşletme raporlarını Hayvan_Detay'a aktarır. aySayisi: bugünkü ay dahil
 * geriye kaç ay (eşitlemede 2; geçmişi doldurmak için daha büyük).
 * Okunan aylardaki kayıtlar her seferinde yeniden yazılır (sonradan yapılan
 * düzeltmeler de gelir). Döner: güncellenen işletme-gün sayısı.
 */
function detayEsitle_(ss, aySayisi, notlar) {
  var simdi = new Date();
  var aylar = {};
  for (var i = 0; i < aySayisi; i++) {
    var d = new Date(simdi.getFullYear(), simdi.getMonth() - i, 1);
    aylar[Utilities.formatDate(d, TZ_, 'yyyy-MM')] = true;
  }
  var hedef = ss.getSheetByName(DETAY_SAYFA_);
  if (!hedef) {
    hedef = ss.insertSheet(DETAY_SAYFA_);
    hedef.getRange(1, 1, 1, 5).setValues([['Tarih', 'İşletme', 'Bölüm', 'Gösterge', 'Değer']]);
    hedef.setFrozenRows(1);
  }
  var yeni = [], yenilenen = {}, gunSay = 0;
  DETAY_DOSYALAR_.forEach(function (df) {
    var dosya;
    try { dosya = detayDosyasi_(df.ara); } catch (e) { dosya = null; }
    if (!dosya) { notlar.push(df.isletme + ' raporu bulunamadı'); return; }
    dosya.getSheets().forEach(function (sh) {
      var ayK = detayAyi_(sh);
      if (!ayK || !aylar[ayK]) return;
      var anahtar = df.isletme + '|' + ayK;
      if (yenilenen[anahtar]) return;   // aynı ay iki sayfada varsa ilki
      yenilenen[anahtar] = true;
      var gunler = detaySayfaOku_(sh);
      Object.keys(gunler).sort().forEach(function (k) {
        gunSay++;
        gunler[k].forEach(function (x) {
          yeni.push([yazTarih_(k), df.isletme, x[0], x[1], x[2]]);
        });
      });
    });
  });
  if (!Object.keys(yenilenen).length) return 0;
  // Mevcut kayıtlardan, yeniden okunan (işletme, ay) çiftlerini çıkar.
  var son = hedef.getLastRow();
  var eski = son >= 2 ? hedef.getRange(2, 1, son - 1, 5).getValues() : [];
  var kalan = eski.filter(function (r) {
    var k = tarihCoz_(r[0]);
    return !(k && yenilenen[String(r[1]) + '|' + k.slice(0, 7)]);
  });
  var tum = kalan.concat(yeni);
  tum.sort(function (x, y) {
    var a = tarihCoz_(x[0]) || '', b = tarihCoz_(y[0]) || '';
    return a < b ? -1 : a > b ? 1 : 0;
  });
  if (son >= 2) hedef.getRange(2, 1, son - 1, 5).clearContent();
  if (tum.length) {
    hedef.getRange(2, 1, tum.length, 5).setValues(tum);
    hedef.getRange(2, 1, tum.length, 1).setNumberFormat('dd.mm.yyyy');
  }
  return gunSay;
}

/** Bir kez editörden çalıştırın: son 12 ayın işletme raporlarını aktarır. */
function detayGecmisiAl() {
  var notlar = [];
  var n = detayEsitle_(SpreadsheetApp.getActiveSpreadsheet(), 12, notlar);
  Logger.log(n + ' işletme-gün aktarıldı. ' + notlar.join(' / '));
}


// ---------------------------------------------------------------------------
/**
 * VETERİNER KONTROL PANELİ
 *
 * Veteriner hekimler, uygulama sahibinin verdiği kodla web panelinden
 * (…/exec?panel=veteriner) giriş yapar; Hayvancılık göstergelerini ve
 * Hastalık Dağılımını (etken, önleme tedbirleri) inceler, yanlış, eksik ya da
 * yetersiz gördükleri yerleri bildirir. Bildirimler uygulamada
 * "Veteriner Kontrol Paneli" ekranında görünür.
 *
 * KVKK:
 *  - Panel yalnızca hayvan sayıları ve hastalık istatistiklerini gösterir;
 *    personel, kişi, telefon ve sicil bilgisi gönderilmez.
 *  - Kodun etiketi kişi adı değil görev/rol olmalı (ör. "Şekersüt veteriner hekimi").
 *  - Bildirim metninde kişi adı, telefon, T.C. kimlik no yazılmaması panelde
 *    hatırlatılır; T.C. kimlik no ve telefon numarası biçimindeki ifadeler
 *    kaydedilmeden önce maskelenir.
 *  - Kod kapatılınca panel o kodla açılmaz; bildirimler raporda kalır.
 */

// Panel sayfası ve hastalık arşivi Drive'da tutulur (kişisel veri içermez):
// "Veteriner Paneli – sayfa (…).html" ve "Veteriner Paneli – hastalık arşivi (…).json".
// Kaynakları depoda: apps_script/Veteriner.html ve assets/veri/hastalik.json.
var VET_HTML_ID = '14izW3rxYQvhXV668iD_McdEcds4VvTs8';
var VET_ARSIV_ID = '1t_4NvUHrQDjyX-TmLPEidP51hi8Zun8e';

var VET_KOD_SAYFA_ = 'Veteriner_Kodları';      // Kod, Etiket, Oluşturma, Durum, Son giriş
var VET_BILDIRIM_SAYFA_ = 'Veteriner_Bildirimleri'; // Tarih, Etiket, Bölüm, Konu, Değerlendirme, Açıklama, Durum, Kod, Yanıt

function vetSayfa_(ad, baslik) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sh = ss.getSheetByName(ad);
  if (!sh) {
    sh = ss.insertSheet(ad);
    sh.getRange(1, 1, 1, baslik.length).setValues([baslik]).setFontWeight('bold');
    sh.setFrozenRows(1);
  }
  return sh;
}

function vetKodSayfasi_() {
  return vetSayfa_(VET_KOD_SAYFA_, ['Kod', 'Etiket (görev/rol)', 'Oluşturma', 'Durum', 'Son giriş']);
}

function vetBildirimSayfasi_() {
  return vetSayfa_(VET_BILDIRIM_SAYFA_,
    ['Tarih', 'Veteriner (etiket)', 'Bölüm', 'Konu', 'Değerlendirme', 'Açıklama', 'Durum', 'Kod', 'Yanıt']);
}

/** Panel sayfası (veri içermez; veri kod doğrulanınca gelir). */
function vetPanel_() {
  var html = DriveApp.getFileById(VET_HTML_ID).getBlob().getDataAsString('UTF-8');
  return HtmlService.createHtmlOutput(html)
    .setTitle('Veteriner Kontrol Paneli')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.DEFAULT);
}

/** Kaba kuvvet denemelerine karşı: 15 dakikada 30 hatalı girişten sonra kilit. */
function vetKodBul_(kod) {
  var cache = CacheService.getScriptCache();
  var hata = parseInt(cache.get('vet_hatali') || '0', 10);
  if (hata >= 30) throw new Error('Çok sayıda hatalı giriş denendi. 15 dakika sonra tekrar deneyin.');
  var k = String(kod || '').trim().toUpperCase();
  var sh = vetKodSayfasi_();
  var son = sh.getLastRow();
  if (k.length >= 6 && son >= 2) {
    var v = sh.getRange(2, 1, son - 1, 4).getValues();
    for (var i = 0; i < v.length; i++) {
      if (String(v[i][0]).trim().toUpperCase() === k) {
        if (String(v[i][3]).trim() !== 'Aktif') break;
        sh.getRange(i + 2, 5).setValue(new Date());
        return { kod: k, etiket: String(v[i][1]), satir: i + 2 };
      }
    }
  }
  cache.put('vet_hatali', String(hata + 1), 900);
  throw new Error('Kod geçersiz ya da kapatılmış.');
}

/** google.script.run: panel verisi. */
function vetVeri(kod) {
  var k = vetKodBul_(kod);
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var tz = ss.getSpreadsheetTimeZone() || 'Europe/Istanbul';
  function tarih(v) {
    return v instanceof Date ? Utilities.formatDate(v, tz, 'yyyy-MM-dd') : String(v || '');
  }
  var sinir = new Date(Date.now() - 63 * 86400000);

  // Hayvan_Özet: personel ve taşeron sütunları (C, D) gönderilmez.
  // Tarih, İşletme, Hayvan, Sağılan, Süt, Doğan, İnek/Düve Kesim-Satış,
  // Buzağı Ölümü, Kesilen Dana, İnek Ölüm, Genç Kesim/Satış, Genç Ölüm,
  // Yavru Atma/Ölü Doğum, Ölen Dana, Dışarıdan Alınan, Satılan/Transfer Dana
  var ozet = [];
  var osh = ss.getSheetByName(SAYFALAR.ozet);
  if (osh && osh.getLastRow() >= 2) {
    ozet = osh.getRange(2, 1, osh.getLastRow() - 1, 18).getValues()
      .filter(function (r) { return r[0] instanceof Date && r[0] >= sinir; })
      .map(function (r) {
        var o = [tarih(r[0]), String(r[1])];
        for (var c = 4; c < 18; c++) o.push(Number(r[c]) || 0);
        return o;
      });
  }

  // Aylık geçmiş (son 13 ay): işletme × ay. Hayvan/Sağılan ayın son veri
  // gününden, diğerleri ay toplamı. Personel ve taşeron gönderilmez.
  var aylik = [];
  if (osh && osh.getLastRow() >= 2) {
    var aySinir = new Date(); aySinir.setDate(1); aySinir.setMonth(aySinir.getMonth() - 12);
    aySinir.setHours(0, 0, 0, 0);
    var ay = {};
    osh.getRange(2, 1, osh.getLastRow() - 1, 18).getValues().forEach(function (r) {
      if (!(r[0] instanceof Date) || r[0] < aySinir) return;
      var t = tarih(r[0]), k = t.slice(0, 7) + '|' + String(r[1]);
      var x = ay[k] = ay[k] || { ay: t.slice(0, 7), isletme: String(r[1]), sonGun: '', gun: 0,
        hayvan: 0, sagilan: 0, sut: 0, sagGun: 0, dogan: 0, kesimSatis: 0, buzagiOlum: 0, kesilen: 0,
        inekOlum: 0, gencKesim: 0, gencOlum: 0, yavru: 0, olenDana: 0, alinan: 0, satilan: 0 };
      var n = function (c) { return Number(r[c]) || 0; };
      x.gun++;
      if (t >= x.sonGun) { x.sonGun = t; x.hayvan = n(4); x.sagilan = n(5); }
      x.sut += n(6); x.sagGun += n(5); x.dogan += n(7); x.kesimSatis += n(8); x.buzagiOlum += n(9);
      x.kesilen += n(10); x.inekOlum += n(11); x.gencKesim += n(12); x.gencOlum += n(13);
      x.yavru += n(14); x.olenDana += n(15); x.alinan += n(16); x.satilan += n(17);
    });
    aylik = Object.keys(ay).sort().map(function (k) { return ay[k]; });
  }

  // Hayvan_Detay: yalnızca sürüden çıkanlar ve kayıplar (personel bloğu zaten okunmaz).
  var kayip = [];
  var dsh = ss.getSheetByName(DETAY_SAYFA_);
  if (dsh && dsh.getLastRow() >= 2) {
    kayip = dsh.getRange(2, 1, dsh.getLastRow() - 1, 5).getValues()
      .filter(function (r) {
        if (!(r[0] instanceof Date) || r[0] < sinir) return false;
        var b = String(r[2]).toLocaleLowerCase('tr-TR');
        var g = String(r[3]).toLocaleLowerCase('tr-TR');
        if (/personel|işçi|taşeron|güvenlik/.test(g)) return false;
        return /çıkan|cikan/.test(b) && !/^toplam/.test(g);
      })
      .map(function (r) { return [tarih(r[0]), String(r[1]), String(r[3]), Number(r[4]) || 0]; });
  }

  // Bilgi Bankası'na sonradan eklenen hastalık kayıtları
  // (Yıl, Ay, Çiftlik, "Cins · Hastalık · Sonuç", Adet).
  var ek = [];
  try {
    var bsh = SpreadsheetApp.openById(BILGI_BANKASI_ID).getSheetByName('Veriler');
    if (bsh && bsh.getLastRow() >= 2) {
      ek = bsh.getRange(2, 1, bsh.getLastRow() - 1, 6).getValues()
        .filter(function (r) { return String(r[3]).trim() === 'Hastalık kaydı'; })
        .map(function (r) { return [String(r[0]), String(r[1]), String(r[2]), String(r[4]), Number(r[5]) || 1]; });
    }
  } catch (err) { /* Bilgi Bankası okunamazsa arşivle devam */ }

  return {
    etiket: k.etiket,
    olusturma: Utilities.formatDate(new Date(), tz, 'dd.MM.yyyy HH:mm'),
    ozet: ozet,
    aylik: aylik,
    kayip: kayip,
    hastalik: vetArsiv_(),
    hastalikEk: ek,
    bildirimler: vetBildirimleri_(k.kod)
  };
}

/** Hastalık arşivi (Drive'daki JSON; 6 saat önbellek). */
function vetArsiv_() {
  var cache = CacheService.getScriptCache();
  var m = cache.get('vet_arsiv');
  if (!m) {
    m = DriveApp.getFileById(VET_ARSIV_ID).getBlob().getDataAsString('UTF-8');
    try { cache.put('vet_arsiv', m, 21600); } catch (err) { /* büyükse önbelleğe alınmaz */ }
  }
  return JSON.parse(m);
}

function vetBildirimleri_(kod) {
  var sh = vetBildirimSayfasi_();
  var son = sh.getLastRow();
  if (son < 2) return [];
  var tz = SpreadsheetApp.getActiveSpreadsheet().getSpreadsheetTimeZone() || 'Europe/Istanbul';
  return sh.getRange(2, 1, son - 1, 9).getValues()
    .map(function (r, i) {
      return {
        satir: i + 2,
        tarih: r[0] instanceof Date ? Utilities.formatDate(r[0], tz, 'dd.MM.yyyy HH:mm') : String(r[0]),
        etiket: String(r[1]), bolum: String(r[2]), konu: String(r[3]),
        degerlendirme: String(r[4]), aciklama: String(r[5]), durum: String(r[6]),
        kod: String(r[7]), yanit: String(r[8])
      };
    })
    .filter(function (b) { return !kod || b.kod === kod; })
    .reverse();
}

/** Kişisel veri biçimindeki ifadeleri maskeler (T.C. kimlik no, telefon, e-posta). */
function vetMaskele_(s) {
  return String(s || '')
    .replace(/\b\d{11}\b/g, '[silindi]')
    .replace(/(\+?90[\s-]?)?0?5\d{2}[\s-]?\d{3}[\s-]?\d{2}[\s-]?\d{2}/g, '[silindi]')
    .replace(/[\w.+-]+@[\w-]+\.[\w.]+/g, '[silindi]')
    .slice(0, 2000);
}

/** google.script.run: bildirim kaydı. */
function vetBildir(kod, b) {
  var k = vetKodBul_(kod);
  b = b || {};
  var deg = String(b.degerlendirme || '');
  if (['Doğru', 'Yanlış', 'Eksik', 'Yetersiz', 'Öneri'].indexOf(deg) < 0) {
    throw new Error('Değerlendirme seçin.');
  }
  var aciklama = vetMaskele_(b.aciklama);
  if (deg !== 'Doğru' && aciklama.trim().length < 5) {
    throw new Error('Yanlış, eksik ya da yetersiz bulduğunuz noktayı kısaca açıklayın.');
  }
  var kilit = LockService.getScriptLock();
  kilit.waitLock(10000);
  try {
    vetBildirimSayfasi_().appendRow([new Date(), k.etiket, String(b.bolum || '').slice(0, 80),
      vetMaskele_(b.konu).slice(0, 200), deg, aciklama, 'Yeni', k.kod, '']);
  } finally {
    kilit.releaseLock();
  }
  return vetBildirimleri_(k.kod);
}

/** Uygulama sahibinin işlemleri (doPost, anahtar doğrulanmış). */
function vetYonetim_(g) {
  var sh, son, v, i;
  if (g.tur === 'vetKodEkle') {
    var etiket = vetMaskele_(g.etiket).trim().slice(0, 80);
    if (!etiket) return { ok: false, hata: 'Görev/rol yazın (ör. "Şekersüt veteriner hekimi").' };
    var harf = 'ABCDEFGHJKLMNPRSTUVYZ23456789';
    var kod = '';
    for (i = 0; i < 8; i++) kod += harf.charAt(Math.floor(Math.random() * harf.length));
    vetKodSayfasi_().appendRow([kod, etiket, new Date(), 'Aktif', '']);
    return { ok: true, kod: kod };
  }
  if (g.tur === 'vetKodKapat' || g.tur === 'vetKodAc') {
    sh = vetKodSayfasi_();
    son = sh.getLastRow();
    v = son >= 2 ? sh.getRange(2, 1, son - 1, 1).getValues() : [];
    for (i = 0; i < v.length; i++) {
      if (String(v[i][0]).trim() === String(g.kod || '').trim()) {
        sh.getRange(i + 2, 4).setValue(g.tur === 'vetKodKapat' ? 'Kapalı' : 'Aktif');
        return { ok: true };
      }
    }
    return { ok: false, hata: 'Kod bulunamadı.' };
  }
  if (g.tur === 'vetBildirimDurum') {
    sh = vetBildirimSayfasi_();
    var no = parseInt(g.satir, 10);
    if (!(no >= 2) || no > sh.getLastRow()) return { ok: false, hata: 'Bildirim bulunamadı; yenileyip tekrar deneyin.' };
    if (String(sh.getRange(no, 8).getValue()) !== String(g.kod || '')) {
      return { ok: false, hata: 'Tablo bu arada değişmiş; yenileyip tekrar deneyin.' };
    }
    if (['Yeni', 'Görüldü', 'Düzeltildi', 'Katılmıyorum'].indexOf(g.durum) < 0) {
      return { ok: false, hata: 'Geçersiz durum.' };
    }
    sh.getRange(no, 7).setValue(g.durum);
    if (g.yanit !== undefined) sh.getRange(no, 9).setValue(vetMaskele_(g.yanit).slice(0, 1000));
    return { ok: true };
  }
  return { ok: false, hata: 'Bilinmeyen işlem.' };
}

/** Uygulamaya giden özet: kodlar ve tüm bildirimler. */
function vetUygulamaVerisi_() {
  var sh = vetKodSayfasi_();
  var son = sh.getLastRow();
  var tz = SpreadsheetApp.getActiveSpreadsheet().getSpreadsheetTimeZone() || 'Europe/Istanbul';
  function t(x) { return x instanceof Date ? Utilities.formatDate(x, tz, 'dd.MM.yyyy HH:mm') : String(x || ''); }
  var kodlar = son >= 2
    ? sh.getRange(2, 1, son - 1, 5).getValues()
      .filter(function (r) { return String(r[0]).trim() !== ''; })
      .map(function (r) { return [String(r[0]), String(r[1]), t(r[2]), String(r[3]), t(r[4])]; })
    : [];
  return { kodlar: kodlar, bildirimler: vetBildirimleri_(null) };
}
