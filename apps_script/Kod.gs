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
  // Veteriner Kontrol Paneli: sayfa veri içermez, veri kodla gelir.
  // Panel uygulamadan kapatılmışsa yalnızca "kapalı" sayfası gösterilir.
  if (p.panel === 'veteriner') return vetPanelAcik_() ? vetPanel_() : vetPanelKapali_();
  // Tarla Haritası web paneli: paylaşım linkiyle açılır (uygulama kurmadan).
  if (p.panel === 'tarla') return tarlaPanel_(p.anahtar);
  var anahtar = PropertiesService.getScriptProperties().getProperty('ANAHTAR');
  if (!anahtar) {
    return json_({ ok: false, hata: 'Kurulum yapılmamış: Apps Script\'te "kurulum" fonksiyonunu çalıştırın.' });
  }
  if (p.anahtar !== anahtar) {
    // Tarla Haritası paylaşımı: yalnızca harita verisi gider.
    var pay = paylasimBul_(p.anahtar);
    if (pay === 'kapali') return json_({ ok: false, paylasimKapali: true, hata: 'Bu paylaşım kapatıldı.' });
    if (pay) {
      try { return json_(tarlaVeri_(pay)); } catch (err) { return json_({ ok: false, hata: 'Veri okunamadı: ' + err }); }
    }
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
    // Mali Raporlar: "Mali Raporlar" klasöründeki en yeni mali_veri.json
    // (fatura özetleri; şahıs tedarikçi adı, fatura no ve plaka içermez)
    mali: maliVeri_(),
    // ÇKS'de bildirilen parseller (Sezon, Çiftlik, Mevki, Ada, Parsel, Ürün,
    // Alan, Eşleşen tarla parseli, Belge, İşlenme tarihi)
    cks: basitOku_('ÇKS_Parseller', 10, tz),
    // Tarla Haritası karşılaştırma düzeltmeleri: Sezon, Çiftlik, Ürün, Seçim, Doğru değer, Açıklama, Tarih, Durum
    ekimDuzeltme: basitOku_('Ekim_Düzeltmeleri', 8, tz),
    // Tarla Haritası yeni sezon girişleri: Sezon, Çiftlik, Parsel, Ürün, Alan (da), Tarih, Durum
    sezonParsel: basitOku_('Sezon_Parselleri', 7, tz),
    // Ekim Planı dosyası: Yıl, Çiftlik, Ürün, Plan (da) — münavebe için tüm yıllar
    ekimPlani: (function () { try { return ekimPlaniOku_(); } catch (err) { return []; } })(),
    // Tarımsal Faaliyet › ÇİFTLİK BAZINDA: ekim alanı, verim, satış, maliyet, net kazanç
    tarimsalUretim: (function () { try { return tarimsalUretimOku_(); } catch (err) { return null; } })(),
    sezonParselSiniri: 400,
    paylasimlar: paylasimListesi_(),
    parselSinir: basitOku_('Parsel_Sınırları', 5, tz),
    // Ürün teslimat ve satışları (günlük toplamlar): TarKop pancar, patates fire listesi,
    // Ürün_Teslimatları sayfasına uygulamadan girilen kayıtlar. Plaka/satıcı no yok.
    urunTeslimat: (function () { try { return urunTeslimatlari_(); } catch (err) { return { hata: String(err) }; } })(),
    // Tarımsal Faaliyet › PARSEL: Çiftlik, İlçe, Köy, Ada, Parsel, Alan (da), Ürün
    resmiParsel: (function () { try { return resmiParsellerOku_(); } catch (err) { return []; } })(),
    // Veteriner Kontrol Paneli: kodlar (Kod, Etiket, Oluşturma, Durum, Son giriş)
    // ve veterinerlerin bildirimleri (Veteriner.gs)
    veteriner: (function () {
      try { return vetUygulamaVerisi_(); } catch (err) { return { acik: false, kodlar: [], bildirimler: [] }; }
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
    var pay = anahtar ? paylasimBul_(p.anahtar) : null;
    if (pay === 'kapali') return json_({ ok: false, paylasimKapali: true, hata: 'Bu paylaşım kapatıldı.' });
    if (!pay) return json_({ ok: false, hata: 'Anahtar hatalı.' });
    try {
      return json_(paylasimIslem_(pay, JSON.parse((e && e.postData && e.postData.contents) || '{}')));
    } catch (err) {
      return json_({ ok: false, hata: 'İşlem yapılamadı: ' + err });
    }
  }
  try {
    var govde = JSON.parse((e && e.postData && e.postData.contents) || '{}');
    if (String(govde.tur).indexOf('paylasim') === 0) return json_(paylasimYonet_(govde));
    if (govde.tur === 'esitle') return json_(esitle_());
    // KVKK: kişi, olay, mesaj ve danışmanlık işlemleri kapatıldı.
    if (['mesaj', 'kisi', 'olay', 'danismanlik', 'danismanlikDuzenle', 'danismanlikSil']
        .indexOf(govde.tur) >= 0) {
      return json_({ ok: false, hata: 'Bu bölüm KVKK kapsamında kaldırıldı.' });
    }
    if (govde.tur === 'raporKaydet') return json_(raporKaydet_(govde));
    if (govde.tur === 'cksYukle') return json_(cksYukle_(govde));
    if (govde.tur === 'ekimDuzelt' || govde.tur === 'ekimDuzeltGeriAl') return json_(ekimDuzelt_(govde));
    if (govde.tur === 'sezonParsel' || govde.tur === 'sezonParselGeriAl') return json_(sezonParsel_(govde));
    if (govde.tur === 'parselSinir' || govde.tur === 'parselSinirGeriAl') return json_(parselSinir_(govde));
    if (govde.tur === 'teslimatEkle' || govde.tur === 'teslimatSil') return json_(teslimatKaydet_(govde));
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
      CacheService.getScriptCache().removeAll(['ekimPlani', 'resmiParsel']);
      var ek = ekimAlanlariEsitle_(ss, sonuc.notlar);
      if (ek) sonuc.notlar.push('Ekim planından güncellenen plan alanı: ' + ek);
    } catch (err) {
      sonuc.notlar.push('Ekim planı okunamadı: ' + err);
    }
    try {
      sonuc.detay = detayEsitle_(ss, 2, sonuc.notlar);
    } catch (err) {
      sonuc.detay = 0;
      sonuc.notlar.push('İşletme raporları okunamadı: ' + err);
    }
    // Kaçırılan özet günleri (ör. hafta sonu raporları pazartesi art arda girildiğinde):
    // işletme tablosu ve çiftliklerin günlük rapor tablolarından tamamlanır.
    try {
      SpreadsheetApp.flush();
      sonuc.ozet += ozetEksikGunler_(ss, canliHayvanDosyasi_(), sonuc.notlar);
    } catch (err) {
      sonuc.notlar.push('Eksik özet günleri tamamlanamadı: ' + err);
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
    tamamlananCikar_(tarih);
    if (degisti) notlar.push(yazTarih_(tarih) + ' canlı hayvan özeti güncellendi (' + degisti + ' işletme)');
    return degisti ? 1 : 0;
  }
  tamamlananCikar_(tarih);
  yaz_(hedef, son + 1, satirlar, 18);
  return 1;
}

/** Tamamlanan (özet yerine işletme tablolarından üretilen) günler. */
function tamamlananlar_() {
  try { return JSON.parse(PropertiesService.getScriptProperties().getProperty('OZET_TAMAMLANAN') || '{}'); }
  catch (e) { return {}; }
}
function tamamlananYaz_(m) {
  PropertiesService.getScriptProperties().setProperty('OZET_TAMAMLANAN', JSON.stringify(m));
}
function tamamlananCikar_(tarih) {
  var m = tamamlananlar_();
  if (m[tarih]) { delete m[tarih]; tamamlananYaz_(m); }
}

// Özet olay sütunları (Hayvan_Özet H…R sırasıyla, OLAY dizisiyle aynı):
// doğan, inek-düve kesim/satış, buzağı ölümü, kesilen dana, inek ölüm,
// genç kesim/satış, genç ölüm, yavru atma/ölü doğum, ölen dana, dışarıdan alınan, satılan/transfer.
var OLAY_KURAL_ = [
  { i: 0, re: /bug[uü]n do[gğ]an/ },
  { i: 1, re: /kesilen (inek|d[uü]ve)|sat[ıi]lan (inek|d[uü]ve)/ },
  { i: 2, re: /(ölen|olen) buza[gğ]|buza[gğ][ıi] [öo]l[üu]m/ },
  { i: 3, re: /kesilen (dana|ithal|besi|erkek)/ },
  { i: 4, re: /(ölen|olen) inek|inek [öo]l[üu]m/ },
  { i: 5, re: /kesilen gen[cç]|sat[ıi]lan gen[cç]/ },
  { i: 6, re: /(ölen|olen) gen[cç]|gen[cç] [öo]l[üu]m/ },
  { i: 7, re: /at[ıi]k buza[gğ]|[öo]l[üu] do[gğ]um|yavru atma/ },
  { i: 8, re: /(ölen|olen) (ithal|dana|besi|erkek)/ },
  { i: 9, re: /d[ıi][sş]ardan al[ıi]nan .*besi/ },
  { i: 10, re: /sat[ıi]lan dana|transfer/ }
];
// Özet satırı → işletme tablosu bloğu / günlük rapor işletmesi
var OZET_KAYNAK_ = {
  'Fethiye Şube': { blok: 'FETHİYE ŞUBE', detay: 'Fethiye Şube' },
  'Erentepe Şube': { blok: 'ERENTEPE ŞUBE', detay: 'Erentepe Şube' },
  'Aslım Çiftliği Besi Danası': { blok: 'ASLIM', detay: 'Aslım Çiftliği' },
  'ESK-Taşağıl Çiftliği Besi Danası': { detay: 'ESK-Taşağıl Çiftliği', hayvan: /^ithal besi danas/ }
};

/**
 * "ozet" sayfası her gün aynı yere yazıldığı için (üzerine yazılır), eşitleme o günü
 * yakalayamazsa gün kaybolur. Eksik günler çiftliklerin günlük tablolarından kurulur:
 *  - hayvan, sağılan, süt, personel: "ozet"teki formüllerin (=isletme!W19 gibi) sütunu
 *    o güne kaydırılarak "isletme" sayfasından;
 *  - doğan buzağı: "isletme" sayfasındaki işletme bloğunun "bugün doğan" satırlarından;
 *  - ölüm, kesim, yavru atma, alınan: çiftlik rapor tablolarından (Hayvan_Detay,
 *    "sürüden çıkanlar" vb.).
 * Gerçek özet sonradan yakalanırsa o günün satırları gerçek özetle değiştirilir.
 */
function ozetEksikGunler_(ss, ch, notlar) {
  var oz = ch.getSheetByName('ozet'), isl = ch.getSheetByName('isletme');
  if (!oz || !isl) return 0;
  var ozTarih = tarihCoz_(oz.getRange(2, 2).getValue());
  if (!ozTarih) return 0;
  var gun0 = Number(ozTarih.slice(8, 10)), ay = ozTarih.slice(0, 8);
  var formul = oz.getRange(1, 1, 27, 18).getFormulas();
  var deger = oz.getRange(1, 1, 27, 18).getValues();
  var iv = isl.getRange(1, 1, Math.min(isl.getLastRow(), 150), Math.min(isl.getLastColumn(), 45)).getValues();
  var hedef = ss.getSheetByName(SAYFALAR.ozet);
  var mevcut = mevcutGunler_(hedef), tam = tamamlananlar_();

  function kucuk(x) { return String(x || '').toLocaleLowerCase('tr-TR').replace(/\s+/g, ' ').trim(); }
  function sutunNo(h) { var n = 0; for (var i = 0; i < h.length; i++) n = n * 26 + (h.charCodeAt(i) - 64); return n; }
  var re = /^=\s*isletme!\$?[A-Z]+\$?\d+(\s*\+\s*isletme!\$?[A-Z]+\$?\d+)*\s*$/i;
  var refSutun = null;
  function hesapla(f, kayma) {
    if (!f || !re.test(f)) return '';
    var top = 0, dolu = false, m, r2 = /isletme!\$?([A-Z]+)\$?(\d+)/gi;
    while ((m = r2.exec(f))) {
      var c = sutunNo(m[1].toUpperCase()), r = Number(m[2]);
      if (refSutun === null) refSutun = c;
      c += kayma;
      if (c < 1 || r > iv.length || c > iv[0].length) return '';
      var n = sayi_(iv[r - 1][c - 1]);
      if (n === '') continue;
      top += n; dolu = true;
    }
    return dolu ? top : '';
  }
  // İşletme tablosu blokları: başlık satırı → "bugün doğan" satırları
  function blokDogan(blok, sutun) {
    var bas = -1;
    for (var i = 0; i < iv.length; i++) if (kucuk(iv[i][0]) === kucuk(blok)) { bas = i; break; }
    if (bas < 0) return '';
    var top = 0, dolu = false;
    for (var j = bas + 1; j < iv.length && kucuk(iv[j][0]) !== 'tarih'; j++) {
      if (!/bug[uü]n do[gğ]an/.test(kucuk(iv[j][0]))) continue;
      var n = sayi_(iv[j][sutun - 1]);
      if (n !== '') { top += n; dolu = true; }
    }
    return dolu ? top : '';
  }
  // Çiftlik rapor tabloları (Hayvan_Detay): tarih|işletme → [[bölüm, gösterge, değer]]
  var detay = {};
  var dsh = ss.getSheetByName(DETAY_SAYFA_);
  if (dsh && dsh.getLastRow() > 1) {
    dsh.getRange(2, 1, dsh.getLastRow() - 1, 5).getValues().forEach(function (r) {
      var k = tarihCoz_(r[0]);
      if (!k || k.slice(0, 8) !== ay) return;
      (detay[k + '|' + r[1]] = detay[k + '|' + r[1]] || []).push([kucuk(r[2]), kucuk(r[3]), sayi_(r[4])]);
    });
  }

  var islenen = 0, yeniSatir = [], silinecek = {};
  for (var gun = 1; gun < gun0; gun++) {
    var tarih = ay + ('0' + gun).slice(-2);
    if (mevcut[tarih] && !tam[tarih]) continue;   // gerçek özet var
    var kayma = gun - gun0, gunSatir = [];
    for (var i = 3; i < 16; i++) {
      var ad = String(deger[i][0]).trim();
      if (!ad || /TOPLAM/i.test(ad)) continue;
      if (ad.toLocaleUpperCase('tr-TR') === 'YÖNETİCİ - MÜDÜR') ad = 'Yönetici - Müdür';
      var b = [1, 2, 3, 4, 5].map(function (k) { return hesapla(formul[i][k], kayma); });
      var kaynak = OZET_KAYNAK_[ad] || {};
      var d = kaynak.detay ? detay[tarih + '|' + kaynak.detay] : null;
      var olay = ['', '', '', '', '', '', '', '', '', '', ''];
      if (d) {
        olay = olay.map(function () { return 0; });
        d.forEach(function (x) {
          if (x[2] === '' || /toplam/.test(x[1])) return;
          if (kaynak.hayvan && kaynak.hayvan.test(x[1])) { b[2] = x[2]; return; }
          for (var q = 0; q < OLAY_KURAL_.length; q++) {
            if (OLAY_KURAL_[q].re.test(x[1])) { olay[OLAY_KURAL_[q].i] += x[2]; break; }
          }
        });
      }
      if (kaynak.blok && refSutun !== null) {
        var dg = blokDogan(kaynak.blok, refSutun + kayma);
        if (dg !== '') { if (olay[0] === '') olay = olay.map(function (v) { return v === '' ? 0 : v; }); olay[0] = dg; }
      }
      var olayVar = olay.some(function (v) { return v !== '' && v !== 0; });
      if (b[2] === '' && b[3] === '' && b[4] === '' && !olayVar) continue;
      gunSatir.push([yazTarih_(tarih), ad].concat(b, olay));
    }
    if (!gunSatir.length) continue;
    if (mevcut[tarih]) silinecek[tarih] = true;
    yeniSatir = yeniSatir.concat(gunSatir);
    tam[tarih] = true;
    islenen++;
    notlar.push(yazTarih_(tarih) + ' özeti çiftlik tablolarından tamamlandı');
  }
  if (!yeniSatir.length) return 0;
  // Önceden tamamlanan günlerin eski satırlarını kaldır (yeniden hesaplandı).
  if (Object.keys(silinecek).length) {
    var son = sonSatirA_(hedef);
    var a = hedef.getRange(2, 1, son - 1, 1).getValues();
    for (var j = a.length - 1; j >= 0; j--) {
      if (silinecek[tarihCoz_(a[j][0])]) hedef.deleteRow(j + 2);
    }
  }
  yaz_(hedef, sonSatirA_(hedef) + 1, yeniSatir, 18);
  tamamlananYaz_(tam);
  return islenen;
}

/**
 * Özet takibi: "ozet" sayfası değiştikçe (her gün üzerine yazıldığı için) o günü
 * kaçırmamak için 07:00–21:00 arasında dakikada bir yalnızca özeti okur.
 */
function ozetTakip() {
  var saat = Number(Utilities.formatDate(new Date(), TZ_, 'H'));
  if (saat < 7 || saat >= 21) return;
  var kilit = LockService.getScriptLock();
  if (!kilit.tryLock(5000)) return;
  try {
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    var notlar = [];
    ozetEsitle_(ss, canliHayvanDosyasi_(), ss.getSpreadsheetTimeZone() || TZ_, notlar);
  } finally {
    kilit.releaseLock();
  }
}

/** Bir kez editörden çalıştırın: özet takibini (dakikada bir) kurar. */
function ozetTakipKur() {
  ScriptApp.getProjectTriggers().forEach(function (t) {
    if (t.getHandlerFunction() === 'ozetTakip') ScriptApp.deleteTrigger(t);
  });
  ScriptApp.newTrigger('ozetTakip').timeBased().everyMinutes(1).create();
  Logger.log('Özet takibi kuruldu: 07:00–21:00 arası dakikada bir.');
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
    var bas = Math.max(5, sonK - 300);
    var gen = Math.min(sh.getLastColumn(), 10);
    // KVKK: 4. satırdaki başlıkta OPERATÖR / PERSONEL / ŞOFÖR geçen sütun okunmaz.
    var atla = {};
    sh.getRange(4, 1, 1, gen).getValues()[0].forEach(function (h, i) {
      if (/OPERAT|PERSONEL|ŞOFÖR|SÜRÜCÜ/i.test(String(h))) atla[i] = true;
    });
    var v = sh.getRange(bas, 1, sonK - bas + 1, gen).getValues();
    var gunler = {};
    v.forEach(function (r) {
      var d = tarihCoz_(r[0]);
      if (!d || d < sinir || d > bugun) return;
      var parca = [];
      for (var k = 1; k < r.length; k++) {
        if (atla[k]) continue;
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
// ÇKS belgeleri (Tarla Haritası): uygulamadan fotoğraf ya da dosya olarak
// yüklenir; "ÇKS Belgeleri" klasörüne konur. Belgedeki parseller ayrı bir
// görevle okunup 'ÇKS_Parseller' sayfasına yazılır (kişisel bilgi alınmaz).
var CKS_KLASOR_ID = '1ghie0n4Hr8-_ANfo-v-9M0m8qNTr2zkD';

// Ekim planı ve resmî parsel kaynakları (salt okunur; yalnızca alan/ürün/ada-parsel okunur).
var EKIM_PLANI_ID = '1uNlVzsbJOh8n9-8g_0NwBsSioPapVGeBRWlp5niY00c';
var TARIM_FAALIYET_ID = '1jeeLe8VF06l_a_JdcS1eF8n8yDGsgEPlIcjO4Y5T7u8';

/** Tarımsal Faaliyet dosyası › "ÇİFTLİK BAZINDA" sayfası (A:M) ve "ÜRÜN BAZINDA" başlığı.
 * Kişi bilgisi içermez; 30 dakika önbellekte tutulur. */
function tarimsalUretimOku_() {
  return onbellekli_('tarimsalUretim_v1', 1800, function () {
    var ss = SpreadsheetApp.openById(TARIM_FAALIYET_ID);
    var sh = ss.getSheetByName('ÇİFTLİK BAZINDA');
    if (!sh || sh.getLastRow() < 3) return null;
    var v = sh.getRange(1, 1, Math.min(sh.getLastRow(), 80), 13).getValues().map(function (r) {
      return r.map(function (x) { return x instanceof Date ? '' : x; });
    });
    var ub = ss.getSheetByName('ÜRÜN BAZINDA');
    return { dosya: ss.getName(), urunBasligi: ub ? String(ub.getRange(1, 1).getValue()) : '', satirlar: v };
  });
}

// ---------------------------------------------------------------------------
// ÜRÜN TAKİBİ: ekilen her ürünün teslimat / satış hareketleri.
// Kaynaklar (otomatik):
//   • Drive'da adında "TarKop" geçen .xlsx dosyaları → Şeker Pancarı (Konya Şeker)
//   • Patates fire bilgilendirme tablosu › LİSTE → Patates (bedele esas kg, fiyat, nakliye)
// Kaynak (elle): rapor tablosundaki "Ürün_Teslimatları" sayfası — uygulamadan girilir.
// Çıktı günlük toplamlardır. KVKK: plaka, satıcı no, şoför ve kişi adı okunmaz/gönderilmez.
var PATATES_FIRE_ID = '1JCn4ud7xVIiqotJSyDpm7_QqTN0fo3WfQIwK82cCcXE';
var TESLIMAT_SAYFASI = 'Ürün_Teslimatları';
var TESLIMAT_BASLIK = ['Tarih', 'Çiftlik', 'Ürün', 'Teslim edilen (kg)', 'Kesinti / fire (kg)',
  'Bedele esas (kg)', 'Alıcı / depo', 'Birim fiyat (TL/kg)', 'Açıklama', 'Kayıt tarihi', 'Durum'];

function xmlMetin_(x) {
  return String(x).replace(/<[^>]+>/g, '').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&apos;/g, "'").replace(/&amp;/g, '&');
}

/** xlsx (zip) → her sayfa için [{A: değer, B: …}] satırları. */
function xlsxSatirlari_(blob) {
  var dosyalar = {};
  Utilities.unzip(blob.setContentType('application/zip')).forEach(function (x) {
    var a = x.getName();
    if (a === 'xl/sharedStrings.xml' || /^xl\/worksheets\/sheet\d+\.xml$/.test(a)) dosyalar[a] = x.getDataAsString('UTF-8');
  });
  var paylasilan = [], m, re = /<si>([\s\S]*?)<\/si>/g;
  while ((m = re.exec(dosyalar['xl/sharedStrings.xml'] || ''))) {
    var t = '', m2, re2 = /<t[^>]*>([\s\S]*?)<\/t>/g;
    while ((m2 = re2.exec(m[1]))) t += m2[1];
    paylasilan.push(xmlMetin_(t));
  }
  return Object.keys(dosyalar).sort().filter(function (a) { return a.indexOf('worksheets') > 0; }).map(function (ad) {
    var satirlar = [], mr, reR = /<row[^>]*>([\s\S]*?)<\/row>/g;
    while ((mr = reR.exec(dosyalar[ad]))) {
      var h = {}, mc, reC = /<c r="([A-Z]+)\d+"([^>]*?)(?:\/>|>([\s\S]*?)<\/c>)/g;
      while ((mc = reC.exec(mr[1]))) {
        var tip = (/t="(\w+)"/.exec(mc[2]) || [])[1], ic = mc[3] || '', vm = /<v>([\s\S]*?)<\/v>/.exec(ic);
        h[mc[1]] = tip === 's' ? (vm ? paylasilan[Number(vm[1])] : '')
          : tip === 'inlineStr' ? xmlMetin_((/<t[^>]*>([\s\S]*?)<\/t>/.exec(ic) || [])[1] || '')
          : (tip === 'str' || tip === 'b') ? (vm ? xmlMetin_(vm[1]) : '')
          : (vm ? Number(vm[1]) : '');
      }
      satirlar.push(h);
    }
    return satirlar;
  });
}

/** Polar değeri dosyada 1741 / "1.73" / 181 gibi farklı yazılıyor → % 17,41 / 17,3 / 18,1. */
function polarDuzelt_(v) {
  var p = typeof v === 'number' ? v : Number(String(v).replace(',', '.'));
  if (!(p > 0)) return null;
  while (p >= 100) p /= 10;
  if (p < 10) p *= 10;
  return Math.round(p * 100) / 100;
}

/** Günlük toplam anahtarı: ürün|çiftlik|kaynak|tarih. */
function teslimatTopla_(g, k) {
  var a = [k.urun, k.ciftlik, k.kaynak, k.tarih].join('|');
  var x = g[a];
  if (!x) x = g[a] = { urun: k.urun, ciftlik: k.ciftlik, kaynak: k.kaynak, alici: k.alici || '', tarih: k.tarih,
    sefer: 0, teslim: 0, net: 0, fiyat: null, tutar: 0, ekGelir: 0, polarT: 0, polarN: 0, kantar: 0, tahmini: !!k.tahmini };
  x.sefer += k.sefer || 1;
  x.teslim += k.teslim || 0;
  x.net += k.net || 0;
  if (k.fiyat) { x.fiyat = k.fiyat; x.tutar += (k.net || 0) * k.fiyat; }
  x.ekGelir += k.ekGelir || 0;
  if (k.polar) { x.polarT += k.polar * (k.net || 0); x.polarN += k.net || 0; }
  x.kantar += k.kantar || 0;
}

function tarkopOku_(g, kaynaklar) {
  var it = DriveApp.searchFiles("title contains 'TarKop' and trashed = false");
  while (it.hasNext()) {
    var f = it.next();
    if (!/\.xlsx$/i.test(f.getName()) || f.getMimeType() === 'application/vnd.google-apps.shortcut') continue;
    var ciftlik = ciftlikAdi_((/(ASLIM|ŞEKER\s*SÜT|ŞEKERSÜT|TAŞAĞIL|ORMANLIK|FİDANLIK)/i.exec(f.getName()) || [])[1] || 'Aslım');
    var say = 0, gor = {};
    xlsxSatirlari_(f.getBlob()).forEach(function (satirlar) {
      var bi = -1, s = {};
      for (var i = 0; i < Math.min(satirlar.length, 10) && bi < 0; i++) {
        var h = satirlar[i];
        Object.keys(h).forEach(function (k) {
          var x = String(h[k]).toLocaleLowerCase('tr').trim();
          if (x === 'tarih') s.tarih = k;
          else if (x.indexOf('tartım no') === 0) s.tartim = k;
          else if (x.indexOf('net miktar') === 0) s.net = k;
          else if (x.indexOf('fabpolar') === 0) s.polar = k;
          else if (x.indexOf('fireli miktar') === 0) s.fireli = k;
        });
        if (s.tarih && s.net && s.tartim) {
          bi = i;
          for (var j = 0; j < i; j++) Object.keys(satirlar[j]).forEach(function (k) {
            var x = String(satirlar[j][k]);
            if (/kantar/i.test(x) && !/portal/i.test(x)) s.kantar = k;
          });
        } else s = {};
      }
      if (bi < 0) return;
      for (var r = bi + 1; r < satirlar.length; r++) {
        var x = satirlar[r], tn = x[s.tartim], tr = x[s.tarih];
        if (typeof tn !== 'number' || typeof tr !== 'number' || gor[tn]) continue;
        gor[tn] = 1; say++;
        var t = Utilities.formatDate(new Date(Date.UTC(1899, 11, 30) + Math.round(tr) * 86400000), 'UTC', 'yyyy-MM-dd');
        // Dosyada miktarlar ton; kg'a çevrilir.
        var net = typeof x[s.net] === 'number' ? x[s.net] * 1000 : 0;
        var fireli = typeof x[s.fireli] === 'number' ? x[s.fireli] * 1000 : net;
        teslimatTopla_(g, { urun: 'Şeker Pancarı', ciftlik: ciftlik, kaynak: 'TarKop', alici: 'Konya Şeker',
          tarih: t, teslim: fireli, net: net, polar: polarDuzelt_(x[s.polar]),
          kantar: s.kantar && typeof x[s.kantar] === 'number' ? x[s.kantar] : 0 });
      }
    });
    kaynaklar.push({ ad: f.getName(), urun: 'Şeker Pancarı', ciftlik: ciftlik, satir: say,
      guncelleme: Utilities.formatDate(f.getLastUpdated(), 'Europe/Istanbul', 'dd.MM.yyyy HH:mm') });
  }
}

function patatesOku_(g, kaynaklar) {
  var ss = SpreadsheetApp.openById(PATATES_FIRE_ID);
  var sh = ss.getSheetByName('LİSTE');
  if (!sh || sh.getLastRow() < 3) return;
  var v = sh.getRange(1, 1, sh.getLastRow(), Math.min(sh.getLastColumn(), 22)).getDisplayValues();
  var bi = v.findIndex(function (r) { return /tartım no/i.test(r[0]); });
  if (bi < 0) return;
  var h = v[bi].map(function (x) { return String(x).toLocaleLowerCase('tr').trim(); });
  function sut(re) { return h.findIndex(function (x) { return re.test(x); }); }
  var c = { tarih: sut(/tartım tarihi/), fiyat: sut(/^fiyat/), bolge: sut(/bölge/), teslim: sut(/fireli kg/),
    net: sut(/bedele esas/), nakKg: sut(/^nakliye kg/), nakFiyat: sut(/^nakliye tl/) };
  var say = 0;
  for (var r = bi + 1; r < v.length; r++) {
    var x = v[r], m = /(\d{2})\.(\d{2})\.(\d{4})/.exec(x[c.tarih] || '');
    var net = sayi_(x[c.net]);
    if (!m || net === '' || !x[0]) continue;
    say++;
    var fiyat = sayi_(x[c.fiyat]), nk = c.nakKg >= 0 ? sayi_(x[c.nakKg]) : '', nf = c.nakFiyat >= 0 ? sayi_(x[c.nakFiyat]) : '';
    teslimatTopla_(g, { urun: 'Patates', ciftlik: ciftlikAdi_(x[c.bolge] || 'Taşağıl'), kaynak: 'Patates fire listesi',
      alici: 'Konya Şeker', tarih: m[3] + '-' + m[2] + '-' + m[1],
      teslim: sayi_(x[c.teslim]) || net, net: net, fiyat: fiyat || null,
      ekGelir: nk !== '' && nf !== '' ? nk * nf : 0 });
  }
  kaynaklar.push({ ad: ss.getName(), urun: 'Patates', ciftlik: 'Taşağıl', satir: say,
    guncelleme: Utilities.formatDate(DriveApp.getFileById(PATATES_FIRE_ID).getLastUpdated(), 'Europe/Istanbul', 'dd.MM.yyyy HH:mm') });
}

function elleTeslimatOku_(g, kaynaklar, elle) {
  var ss = SpreadsheetApp.getActiveSpreadsheet(), sh = ss.getSheetByName(TESLIMAT_SAYFASI);
  if (!sh || sh.getLastRow() < 2) return;
  var tz = ss.getSpreadsheetTimeZone() || 'Europe/Istanbul';
  var v = sh.getRange(2, 1, sh.getLastRow() - 1, TESLIMAT_BASLIK.length).getValues(), say = 0;
  v.forEach(function (r, i) {
    if (r[10] === 'Silindi' || !(r[0] instanceof Date) || !r[2]) return;
    var net = sayi_(r[5]) !== '' ? sayi_(r[5]) : (sayi_(r[3]) || 0) - (sayi_(r[4]) || 0);
    say++;
    var tarih = Utilities.formatDate(r[0], tz, 'yyyy-MM-dd');
    elle.push([i + 2, tarih, ciftlikAdi_(r[1]), String(r[2]), sayi_(r[3]), sayi_(r[4]), net,
      String(r[6] || ''), sayi_(r[7]), String(r[8] || '')]);
    teslimatTopla_(g, { urun: String(r[2]), ciftlik: ciftlikAdi_(r[1]), kaynak: 'Uygulama girişi',
      alici: String(r[6] || ''), tarih: Utilities.formatDate(r[0], tz, 'yyyy-MM-dd'),
      teslim: sayi_(r[3]) || net, net: net, fiyat: sayi_(r[7]) || null });
  });
  if (say) kaynaklar.push({ ad: TESLIMAT_SAYFASI + ' (uygulamadan girilen)', urun: '', ciftlik: '', satir: say, guncelleme: '' });
}

function urunTeslimatlari_() {
  return onbellekli_('teslimat_v1', 600, function () {
    var g = {}, kaynaklar = [], hatalar = [], elle = [];
    [tarkopOku_, patatesOku_, elleTeslimatOku_].forEach(function (f) {
      try { f(g, kaynaklar, elle); } catch (e) { hatalar.push(String(e).slice(0, 200)); }
    });
    var satirlar = Object.keys(g).sort().map(function (k) {
      var x = g[k];
      return [x.urun, x.ciftlik, x.kaynak, x.alici, x.tarih, x.sefer, Math.round(x.teslim), Math.round(x.net),
        x.fiyat === null ? '' : x.fiyat, Math.round(x.tutar), Math.round(x.ekGelir),
        x.polarN ? Math.round(x.polarT / x.polarN * 100) / 100 : '', Math.round(x.kantar)];
    });
    return { satirlar: satirlar, elle: elle, kaynaklar: kaynaklar, hatalar: hatalar,
      okunma: Utilities.formatDate(new Date(), 'Europe/Istanbul', 'dd.MM.yyyy HH:mm') };
  });
}

/** Uygulamadan elle teslimat/satış kaydı ekler ya da kaydı "Silindi" yapar. Kişi adı tutulmaz. */
function teslimatKaydet_(g) {
  var ss = SpreadsheetApp.getActiveSpreadsheet(), sh = ss.getSheetByName(TESLIMAT_SAYFASI);
  if (!sh) {
    sh = ss.insertSheet(TESLIMAT_SAYFASI);
    sh.appendRow(TESLIMAT_BASLIK);
    sh.setFrozenRows(1);
  }
  var tz = ss.getSpreadsheetTimeZone() || 'Europe/Istanbul';
  CacheService.getScriptCache().remove('teslimat_v1');
  if (g.tur === 'teslimatSil') {
    var no = parseInt(g.satir, 10);
    if (!(no >= 2) || no > sh.getLastRow()) return { ok: false, hata: 'Kayıt bulunamadı.' };
    sh.getRange(no, 11).setValue('Silindi');
    return { ok: true, mesaj: 'Kayıt silindi.' };
  }
  var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(g.tarih || ''));
  var urun = String(g.urun || '').slice(0, 60), cf = String(g.ciftlik || '').slice(0, 60);
  var teslim = sayi_(g.teslim), kesinti = sayi_(g.kesinti), fiyat = sayi_(g.fiyat);
  if (!m || !urun || !cf || !(teslim > 0)) return { ok: false, hata: 'Tarih, çiftlik, ürün ve teslim edilen miktar gerekli.' };
  if (kesinti !== '' && (kesinti < 0 || kesinti > teslim)) return { ok: false, hata: 'Kesinti miktarı hatalı.' };
  var net = teslim - (kesinti || 0);
  sh.appendRow([new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3])), cf, urun, teslim, kesinti === '' ? 0 : kesinti, net,
    String(g.alici || '').slice(0, 80), fiyat === '' ? '' : fiyat, String(g.aciklama || '').slice(0, 200),
    Utilities.formatDate(new Date(), tz, 'dd.MM.yyyy HH:mm'), 'Aktif']);
  return { ok: true, mesaj: urun + ' · ' + cf + ': ' + net + ' kg kaydedildi.' };
}

function onbellekli_(anahtar, sure, uret) {
  var c = CacheService.getScriptCache();
  var v = c.get(anahtar);
  if (v) { try { return JSON.parse(v); } catch (e) {} }
  var sonuc = uret();
  try { c.put(anahtar, JSON.stringify(sonuc), sure); } catch (e) {}
  return sonuc;
}

function ciftlikAdi_(x) {
  var t = String(x).replace(/çiftliği/ig, '').replace(/\s+/g, ' ').trim();
  var k = t.toLocaleLowerCase('tr');
  if (k.indexOf('şeker') === 0 || k.indexOf('fethiye') >= 0) return 'Şekersüt';
  if (k.indexOf('aslım') >= 0) return 'Aslım';
  // Ormanlık, Taşağıl çiftliğine ait alandır.
  if (k.indexOf('taşağıl') >= 0 || k.indexOf('camili') >= 0 || k.indexOf('ormanlık') >= 0) return 'Taşağıl';
  if (k.indexOf('fidanlık') >= 0) return 'Fidanlık';
  return t;
}

/** Ekim Planı dosyasındaki "YYYY TARIM PLANI" tabloları: [Yıl, Çiftlik, Ürün, Plan (da)]. */
function ekimPlaniOku_() {
  return onbellekli_('ekimPlani', 3600, function () {
    var ss = SpreadsheetApp.openById(EKIM_PLANI_ID);
    var sh = ss.getSheets()[0];
    var v = sh.getRange(1, 1, Math.min(sh.getLastRow(), 200), Math.min(sh.getLastColumn(), 27)).getDisplayValues();
    var yil = '', urunler = null, cikti = [];
    v.forEach(function (r) {
      var metin = r.join(' ');
      var m = metin.match(/(\d{4})\s+TARIM PLANI/i);
      if (m) { yil = m[1]; urunler = null; return; }
      if (!yil) return;
      var i = r.findIndex(function (h) { return /toplam dekar/i.test(h); });
      if (i >= 0) { urunler = r; return; }
      if (!urunler) return;
      var ad = r.filter(function (x) { return String(x).trim() !== ''; })[0] || '';
      if (!ad || /toplam/i.test(ad)) { if (/toplam/i.test(ad)) urunler = null; return; }
      urunler.forEach(function (u, j) {
        u = String(u).trim();
        if (!u || /toplam/i.test(u)) return;
        var n = sayi_(r[j]);
        if (n === '' || n === 0) return;
        cikti.push([yil, ciftlikAdi_(ad), /boş|ıslah/i.test(u) ? 'Boş / ıslah edilen' : u, n]);
      });
    });
    return cikti;
  });
}

/** Tarımsal Faaliyet › PARSEL: [Çiftlik, İlçe, Köy, Ada, Parsel, Alan (da), Ürün]. */
function resmiParsellerOku_() {
  return onbellekli_('resmiParsel', 3600, function () {
    var sh = SpreadsheetApp.openById(TARIM_FAALIYET_ID).getSheetByName('PARSEL');
    if (!sh) return [];
    var v = sh.getRange(1, 1, Math.min(sh.getLastRow(), 400), 6).getDisplayValues();
    var cikti = [];
    v.forEach(function (r) {
      if (!r[0] || !r[1] || /^(İLÇESİ|TOPLAM)/i.test(r[0]) || !r[3]) return;
      var alan = sayi_(r[4]);
      cikti.push([ciftlikAdi_(r[1]), r[0].trim(), r[1].trim(), r[2].trim(), r[3].trim(),
        alan === '' ? '' : alan, String(r[5]).replace(/\d+$/, '').trim()]);
    });
    return cikti;
  });
}

function urunAnahtari_(u) {
  var k = String(u).toLocaleLowerCase('tr').replace(/\(.*?\)/g, '').trim();
  if (k.indexOf('pancar') >= 0) return 'pancar';
  if (k.indexOf('mısır') >= 0) return 'mısır';
  if (k.indexOf('buğday') >= 0) return 'buğday';
  if (k.indexOf('arpa') >= 0) return 'arpa';
  if (k.indexOf('yonca') >= 0) return 'yonca';
  if (k.indexOf('patates') >= 0) return 'patates';
  return k;
}

/** Ekim_Alanları "Plan (da)" sütununu bu yılın ekim planıyla günceller; Ekilen sütununa dokunmaz.
 * Eşleşmeyen plan satırları eklenmez, nota yazılır. */
function ekimAlanlariEsitle_(ss, notlar) {
  var yil = String(new Date().getFullYear());
  var plan = ekimPlaniOku_().filter(function (r) { return r[0] === yil && !/boş/i.test(r[2]); });
  if (!plan.length) return 0;
  var sh = ss.getSheetByName(SAYFALAR.ekim);
  if (!sh || sh.getLastRow() < 2) return 0;
  var rg = sh.getRange(2, 1, sh.getLastRow() - 1, 3), v = rg.getValues(), say = 0;
  plan.forEach(function (p) {
    var i = v.findIndex(function (r) {
      return ciftlikAdi_(r[0]) === p[1] && urunAnahtari_(r[1]) === urunAnahtari_(p[2]);
    });
    if (i < 0) { notlar.push('Ekim planında olup Ekim_Alanları\'nda olmayan: ' + p[1] + ' / ' + p[2] + ' ' + p[3] + ' da'); return; }
    if (Number(v[i][2]) !== Number(p[3])) { v[i][2] = p[3]; say++; }
  });
  if (say) rg.setValues(v);
  return say;
}

/** Tarla Haritası'nda bir parselin yeni sezon ürününü ve alanını kaydeder ya da
 * girişi geri alır. Parsel başına tek aktif satır tutulur; kişi adı tutulmaz. */
function sezonParsel_(g) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var ad = 'Sezon_Parselleri';
  var sh = ss.getSheetByName(ad);
  if (!sh) {
    sh = ss.insertSheet(ad);
    sh.appendRow(['Sezon', 'Çiftlik', 'Parsel', 'Ürün', 'Alan (da)', 'Tarih', 'Durum']);
    sh.setFrozenRows(1);
  }
  var sezon = String(g.sezon || '').slice(0, 20), cf = String(g.ciftlik || '').slice(0, 60),
    parsel = String(g.parsel || '').slice(0, 80);
  if (!sezon || !cf || !parsel) return { ok: false, hata: 'Sezon, çiftlik ya da parsel eksik.' };
  var son = sh.getLastRow();
  if (son >= 2) {
    var rg = sh.getRange(2, 1, son - 1, 7), v = rg.getValues(), deg = false;
    v.forEach(function (r) {
      if (String(r[0]) === sezon && String(r[1]) === cf && String(r[2]) === parsel && r[6] === 'Aktif') {
        r[6] = g.tur === 'sezonParselGeriAl' ? 'Geri alındı' : 'Güncellendi'; deg = true;
      }
    });
    if (deg) rg.setValues(v);
  }
  if (g.tur === 'sezonParselGeriAl') return { ok: true, mesaj: 'Parsel girişi geri alındı.' };
  // Bölünmüş parsel, tohum adı ve çizilen bölgeler için 400 karakter (uygulama sezonParselSiniri ile bilir).
  var urun = String(g.urun || '').slice(0, 400);
  if (!urun) return { ok: false, hata: 'Ürün eksik.' };
  var alan = sayi_(g.alan);
  if (alan !== '' && alan < 0) return { ok: false, hata: 'Alan okunamadı.' };
  var tz = ss.getSpreadsheetTimeZone() || 'Europe/Istanbul';
  sh.appendRow([sezon, cf, parsel, urun, alan, Utilities.formatDate(new Date(), tz, 'dd.MM.yyyy'), 'Aktif',
    g.giren ? 'Paylaşım: ' + g.giren : '']);
  return { ok: true, mesaj: sezon + ' sezonuna kaydedildi: ' + parsel + ' · ' + urun + (alan === '' ? '' : ' ' + alan + ' da') };
}

// ---------------------------------------------------------------------------
// Tarla Haritası paylaşımı. Her paylaşımın ayrı anahtarı vardır; ana anahtar paylaşılmaz.
// Paylaşım linkiyle yalnızca Tarla Haritası verisi okunur (rapor, mali, hayvan, araç verisi gitmez);
// "düzenle" yetkisinde yalnızca parsel ürünü/alanı ve parsel sınırı kaydedilebilir.
// Etiket olarak kişi adı değil görev/birim yazılır (KVKK). Kapatılan paylaşımın linki hemen çalışmaz olur.
// ---------------------------------------------------------------------------
function paylasimlar_() {
  try { return JSON.parse(PropertiesService.getScriptProperties().getProperty('PAYLASIMLAR') || '[]'); }
  catch (e) { return []; }
}

function paylasimKaydet_(l) {
  PropertiesService.getScriptProperties().setProperty('PAYLASIMLAR', JSON.stringify(l));
}

/** Anahtara ait paylaşım; kapatılmışsa 'kapali', yoksa null. */
function paylasimBul_(anahtar) {
  if (!anahtar) return null;
  var x = paylasimlar_().filter(function (p) { return p.anahtar === anahtar; })[0];
  if (!x) return null;
  return x.acik ? x : 'kapali';
}

function paylasimLinki_(p) {
  return ScriptApp.getService().getUrl() + '?panel=tarla&anahtar=' + p.anahtar;
}

/** Tarla Haritası web paneli: sayfa veri içermez; veri anahtarla google.script.run üzerinden gelir. */
function tarlaPanel_(anahtar) {
  var pay = paylasimBul_(anahtar);
  if (!pay || pay === 'kapali') {
    return HtmlService.createHtmlOutput('<meta name="viewport" content="width=device-width, initial-scale=1">' +
      '<div style="font-family:sans-serif;padding:24px;font-size:16px">Bu paylaşım kapalı ya da geçersiz.</div>')
      .setTitle('Tarla Haritası');
  }
  return HtmlService.createHtmlOutput(TARLA_PANEL_HTML_.replace('__ANAHTAR__', JSON.stringify(pay.anahtar)))
    .setTitle('Tarla Haritası')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.DEFAULT);
}

/** google.script.run: panel verisi (yalnızca parsel kayıtları ve sınırlar; harita çizimleri GitHub'daki paket dosyalarından). */
function tarlaPanelVeri(anahtar) {
  var pay = paylasimBul_(anahtar);
  if (pay === 'kapali') return { ok: false, kapali: true, hata: 'Bu paylaşım kapatıldı.' };
  if (!pay) return { ok: false, hata: 'Paylaşım bulunamadı.' };
  var tz = SpreadsheetApp.getActiveSpreadsheet().getSpreadsheetTimeZone() || 'Europe/Istanbul';
  var ekim = [];
  var sh = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SAYFALAR.ekim);
  if (sh && sh.getLastRow() >= 2) {
    ekim = sh.getRange(2, 1, sh.getLastRow() - 1, 4).getValues().filter(function (r) { return String(r[0]).trim() !== ''; })
      .map(function (r) { return r.map(function (v) { return v instanceof Date ? '' : v; }); });
  }
  return { ok: true, etiket: pay.etiket, yetki: pay.yetki, sezonParselSiniri: 400,
    sezonParsel: basitOku_('Sezon_Parselleri', 7, tz), parselSinir: basitOku_('Parsel_Sınırları', 5, tz),
    ekim: ekim, ekimPlani: (function () { try { return ekimPlaniOku_(); } catch (e) { return []; } })(),
    cks: basitOku_('ÇKS_Parseller', 10, tz) };
}

/** google.script.run: panelden parsel kayıtları (yalnızca düzenleme yetkisinde): ürün/dekar/tohum, bölme, birleştirme,
 * ayırma çizgisi, bölge, parça bağlama (Sezon_Parselleri) ve parsel sınırı / yeni parsel (Parsel_Sınırları).
 * g.coklu: sırayla uygulanacak işlemler (birleştirmede birden çok parsel). */
function tarlaPanelKaydet(anahtar, g) {
  var pay = paylasimBul_(anahtar);
  if (pay === 'kapali') return { ok: false, kapali: true, hata: 'Bu paylaşım kapatıldı.' };
  if (!pay) return { ok: false, hata: 'Paylaşım bulunamadı.' };
  g = g || {};
  var ops = Array.isArray(g.coklu) ? g.coklu.slice(0, 30) : [g], r = { ok: false, hata: 'İşlem yok.' };
  for (var i = 0; i < ops.length; i++) {
    r = paylasimIslem_(pay, ops[i] || {});
    if (!r.ok) break;
  }
  var tz = SpreadsheetApp.getActiveSpreadsheet().getSpreadsheetTimeZone() || 'Europe/Istanbul';
  r.sezonParsel = basitOku_('Sezon_Parselleri', 7, tz);
  r.parselSinir = basitOku_('Parsel_Sınırları', 5, tz);
  return r;
}

/** Uygulamanın sahibine giden liste (link dahil). */
function paylasimListesi_() {
  return paylasimlar_().map(function (p) {
    return { id: p.id, etiket: p.etiket, yetki: p.yetki, acik: p.acik, olusturma: p.olusturma,
      degisiklik: p.degisiklik || '', link: paylasimLinki_(p) };
  });
}

function paylasimYonet_(g) {
  var l = paylasimlar_();
  var tz = SpreadsheetApp.getActiveSpreadsheet().getSpreadsheetTimeZone() || 'Europe/Istanbul';
  var simdi = Utilities.formatDate(new Date(), tz, 'dd.MM.yyyy HH:mm');
  var yetki = g.yetki === 'duzenle' ? 'duzenle' : 'gor';
  if (g.tur === 'paylasimEkle') {
    var etiket = String(g.etiket || '').trim().slice(0, 40);
    if (!etiket) return { ok: false, hata: 'Paylaşım adı (görev/birim) girin.' };
    var p = { id: Utilities.getUuid().slice(0, 8), etiket: etiket, yetki: yetki, acik: true, olusturma: simdi,
      anahtar: 'p' + Utilities.getUuid().replace(/-/g, '') };
    l.push(p);
    paylasimKaydet_(l);
    return { ok: true, mesaj: etiket + ' için paylaşım açıldı.', paylasimlar: paylasimListesi_() };
  }
  var x = l.filter(function (p) { return p.id === g.id; })[0];
  if (!x) return { ok: false, hata: 'Paylaşım bulunamadı.' };
  if (g.tur === 'paylasimYetki') { x.yetki = yetki; }
  else if (g.tur === 'paylasimAd') {
    var ad = String(g.etiket || '').trim().slice(0, 40);
    if (!ad) return { ok: false, hata: 'Paylaşım adı boş olamaz.' };
    x.etiket = ad;
  }
  else if (g.tur === 'paylasimKapat') { x.acik = false; }
  else if (g.tur === 'paylasimAc') { x.acik = true; }
  else if (g.tur === 'paylasimSil') { l = l.filter(function (p) { return p.id !== g.id; }); }
  else return { ok: false, hata: 'Bilinmeyen işlem.' };
  x.degisiklik = simdi;
  paylasimKaydet_(l);
  return { ok: true, mesaj: 'Paylaşım güncellendi.', paylasimlar: paylasimListesi_() };
}

/** Paylaşım linkine giden veri: yalnızca Tarla Haritası'nın kullandığı alanlar. */
function tarlaVeri_(pay) {
  var v = veriTopla_(400);
  var o = { ok: true, surum: v.surum, olusturma: v.olusturma,
    paylasim: { kapsam: 'tarla', yetki: pay.yetki, etiket: pay.etiket } };
  ['ekim', 'hasat', 'cks', 'ekimDuzeltme', 'sezonParsel', 'ekimPlani', 'sezonParselSiniri', 'parselSinir', 'resmiParsel']
    .forEach(function (k) { o[k] = v[k]; });
  return o;
}

/** Paylaşım linkiyle gelen işlem: yalnızca düzenleme yetkisinde, yalnızca tarla kayıtları. */
function paylasimIslem_(pay, g) {
  var izinli = ['sezonParsel', 'sezonParselGeriAl', 'parselSinir', 'parselSinirGeriAl'];
  if (izinli.indexOf(g.tur) < 0) return { ok: false, hata: 'Bu işlem paylaşımda yapılamaz.' };
  if (pay.yetki !== 'duzenle') return { ok: false, hata: 'Bu paylaşımda yalnızca görüntüleme yetkisi var.' };
  g.giren = pay.etiket;
  return g.tur.indexOf('sezonParsel') === 0 ? sezonParsel_(g) : parselSinir_(g);
}

/** Tarla Haritası'nda KMZ'den gelen parsel sınırının yeniden çizilmesi ya da haritaya yeni parsel
 * eklenmesi. Sınır sezondan bağımsızdır (tüm sezonlarda kullanılır); parsel başına tek aktif satır.
 * Koordinatlar "boylam,enlem boylam,enlem …" biçimindedir; kişi adı tutulmaz. */
function parselSinir_(g) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var ad = 'Parsel_Sınırları';
  var sh = ss.getSheetByName(ad);
  if (!sh) {
    sh = ss.insertSheet(ad);
    sh.appendRow(['Çiftlik', 'Parsel', 'Koordinatlar', 'Tarih', 'Durum']);
    sh.setFrozenRows(1);
  }
  var cf = String(g.ciftlik || '').slice(0, 60), parsel = String(g.parsel || '').slice(0, 80);
  if (!cf || !parsel) return { ok: false, hata: 'Çiftlik ya da parsel eksik.' };
  var son = sh.getLastRow();
  if (son >= 2) {
    var rg = sh.getRange(2, 1, son - 1, 5), v = rg.getValues(), deg = false;
    v.forEach(function (r) {
      if (String(r[0]) === cf && String(r[1]) === parsel && r[4] === 'Aktif') {
        r[4] = g.tur === 'parselSinirGeriAl' ? 'Geri alındı' : 'Güncellendi'; deg = true;
      }
    });
    if (deg) rg.setValues(v);
  }
  if (g.tur === 'parselSinirGeriAl') return { ok: true, mesaj: parsel + ' için KMZ sınırına dönüldü.' };
  var k = String(g.koord || '').trim();
  if (!/^-?\d+(\.\d+)?,-?\d+(\.\d+)?( -?\d+(\.\d+)?,-?\d+(\.\d+)?){2,}$/.test(k) || k.length > 45000) {
    return { ok: false, hata: 'Sınır koordinatları okunamadı.' };
  }
  var tz = ss.getSpreadsheetTimeZone() || 'Europe/Istanbul';
  sh.appendRow([cf, parsel, k, Utilities.formatDate(new Date(), tz, 'dd.MM.yyyy'), 'Aktif',
    g.giren ? 'Paylaşım: ' + g.giren : '']);
  return { ok: true, mesaj: parsel + ' sınırı kaydedildi.' };
}

/** Tarla Haritası karşılaştırmasındaki bir farkı uygulamadan düzeltir ya da
 * düzeltmeyi geri alır. Kaynak dosyalara dokunmaz; kişi adı tutulmaz. */
function ekimDuzelt_(g) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var ad = 'Ekim_Düzeltmeleri';
  var sh = ss.getSheetByName(ad);
  if (!sh) {
    sh = ss.insertSheet(ad);
    sh.appendRow(['Sezon', 'Çiftlik', 'Ürün', 'Seçim', 'Doğru değer (da)', 'Açıklama', 'Tarih', 'Durum']);
    sh.setFrozenRows(1);
  }
  var sezon = String(g.sezon || '').slice(0, 20), cf = String(g.ciftlik || '').slice(0, 60),
    urun = String(g.urun || '').slice(0, 120);
  if (!cf || !urun) return { ok: false, hata: 'Çiftlik ya da ürün eksik.' };
  var son = sh.getLastRow();
  if (son >= 2) {
    var rg = sh.getRange(2, 1, son - 1, 8), v = rg.getValues(), deg = false;
    v.forEach(function (r) {
      if (String(r[0]) === sezon && String(r[1]) === cf && String(r[2]) === urun && r[7] === 'Aktif') { r[7] = 'Geri alındı'; deg = true; }
    });
    if (deg) rg.setValues(v);
  }
  if (g.tur === 'ekimDuzeltGeriAl') return { ok: true, mesaj: 'Düzeltme geri alındı.' };
  var secim = String(g.secim || '').slice(0, 80);
  if (!secim) return { ok: false, hata: 'Seçim eksik.' };
  var deger = sayi_(g.deger);
  if (deger !== '' && deger < 0) return { ok: false, hata: 'Doğru değer okunamadı.' };
  var tz = ss.getSpreadsheetTimeZone() || 'Europe/Istanbul';
  sh.appendRow([sezon, cf, urun, secim, deger, String(g.aciklama || '').slice(0, 300),
    Utilities.formatDate(new Date(), tz, 'dd.MM.yyyy'), 'Aktif']);
  return { ok: true, mesaj: 'Düzeltme kaydedildi.' };
}

function cksYukle_(g) {
  var mime = String(g.mime || '');
  if (['application/pdf', 'image/jpeg', 'image/png'].indexOf(mime) < 0) {
    return { ok: false, hata: 'Yalnızca PDF, JPG ya da PNG yüklenebilir.' };
  }
  var bayt = Utilities.base64Decode(String(g.veri || ''));
  if (bayt.length < 100 || bayt.length > 15 * 1024 * 1024) {
    return { ok: false, hata: 'Dosya okunamadı ya da 15 MB\'tan büyük.' };
  }
  var uzanti = mime === 'application/pdf' ? 'pdf' : (mime === 'image/png' ? 'png' : 'jpg');
  var sezon = String(g.sezon || '').replace(/[^0-9-]/g, '');
  var ad = 'CKS_' + (sezon ? sezon + '_' : '') +
      Utilities.formatDate(new Date(), 'Europe/Istanbul', 'yyyy-MM-dd_HHmmss') + '.' + uzanti;
  DriveApp.getFolderById(CKS_KLASOR_ID).createFile(Utilities.newBlob(bayt, mime, ad));
  return { ok: true, mesaj: 'ÇKS belgesi Drive\'a kaydedildi: ' + ad +
      '. Belgedeki parseller işlendiğinde haritada görünecek.' };
}

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
var VET_ARSIV_ID = '13m3kHW6whr56GRcgSZiMsyB00bCaXJRT'; // 23.11.2026: yalnızca Drive Sağlık Raporları (araclar/hastalik/olustur.py)

// Panel durumu (20.11.2026): Komut dosyası özelliği VET_PANEL = 'acik' ise
// açıktır; tanımlı değilse kapalı kabul edilir. Uygulamadaki anahtarla
// değiştirilir. Kapalıyken panel adresi veri göstermez, hiçbir kod çalışmaz,
// yeni kod üretilemez; kodlar ve bildirimler saklanır, açılınca aynen döner.
function vetPanelAcik_() {
  return PropertiesService.getScriptProperties().getProperty('VET_PANEL') === 'acik';
}

/** Panel kapalıyken gösterilen sayfa (veri içermez). */
function vetPanelKapali_() {
  return HtmlService.createHtmlOutput(
    '<meta charset="utf-8"><div style="font-family:sans-serif;padding:24px">' +
    '<h2>Veteriner Kontrol Paneli</h2><p>Panel şu anda erişime kapalıdır.</p></div>')
    .setTitle('Veteriner Kontrol Paneli')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1');
}

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
  if (!vetPanelAcik_()) throw new Error('Veteriner Kontrol Paneli şu anda erişime kapalıdır.');
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
  var m = cache.get('vet_arsiv_v2');
  if (!m) {
    m = DriveApp.getFileById(VET_ARSIV_ID).getBlob().getDataAsString('UTF-8');
    try { cache.put('vet_arsiv_v2', m, 21600); } catch (err) { /* büyükse önbelleğe alınmaz */ }
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
  if (g.tur === 'vetPanelDurum') {
    var props = PropertiesService.getScriptProperties();
    if (g.acik === '1') props.setProperty('VET_PANEL', 'acik');
    else props.deleteProperty('VET_PANEL');
    return { ok: true, acik: vetPanelAcik_() };
  }
  if (g.tur === 'vetKodEkle') {
    if (!vetPanelAcik_()) return { ok: false, hata: 'Panel kapalıyken yeni kod üretilemez. Önce paneli açın.' };
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
  return { acik: vetPanelAcik_(), kodlar: kodlar, bildirimler: vetBildirimleri_(null) };
}


// ---------------------------------------------------------------------------
// MALİ RAPORLAR: "Mali Raporlar" klasöründeki fatura dosyalarından hazırlanan
// özet (mali_veri.json). Fatura, açık bakiye ve kontrol satırları; şahıs
// tedarikçi adları, fatura numaraları, plaka ve personel ücret ayrıntısı yoktur.
var MALI_KLASOR_ID = '1mJBz8lhL7AETl_8SpSv8rjtsZm8cWIs5';

function maliVeri_() {
  try {
    var it = DriveApp.getFolderById(MALI_KLASOR_ID).getFiles();
    var en = null;
    while (it.hasNext()) {
      var f = it.next();
      if (f.getName().indexOf('mali_veri.json') !== 0) continue;
      if (!en || f.getLastUpdated() > en.getLastUpdated()) en = f;
    }
    return en ? JSON.parse(en.getBlob().getDataAsString('UTF-8')) : null;
  } catch (err) {
    return null;
  }
}

// <<TARLA_PANEL_HTML>> — apps_script/tarla_panel.html'den araclar/tarla/panel_gom.py ile üretilir; elle değiştirmeyin.
var TARLA_PANEL_HTML_ = "<!DOCTYPE html>\n<html lang=\"tr\">\n<head>\n<meta charset=\"utf-8\">\n<base target=\"_top\">\n<title>Tarla Haritası</title>\n<style>\n  :root { --mavi:#1d4ed8; --soluk:#64748b; --amber:#b45309; --kenar:#e2e8f0; }\n  * { box-sizing: border-box; }\n  body { margin:0; font-family: system-ui, -apple-system, \"Segoe UI\", Roboto, sans-serif; color:#0f172a; background:#f8fafc; }\n  header { background:#3D7A55; color:#fff; position:sticky; top:0; z-index:5; }\n  .cubuk { display:flex; align-items:center; gap:8px; padding:12px 10px; }\n  .cubuk h1 { margin:0; font-size:19px; font-weight:600; flex:1; }\n  .geri { background:none; border:0; color:#fff; font-size:24px; width:40px; height:40px; cursor:pointer; }\n  #ust { font-size:12px; opacity:.85; padding:0 14px 8px; }\n  .sekmeler { display:flex; overflow-x:auto; }\n  .sekme { flex:1; text-align:center; padding:10px 12px 12px; font-size:15px; color:rgba(255,255,255,.75); cursor:pointer; white-space:nowrap;\n    border-bottom:3px solid transparent; }\n  .sekme.secili { color:#fff; font-weight:700; border-bottom-color:#fff; }\n  .menu { display:flex; align-items:center; gap:14px; background:#f1f5f0; border:1px solid var(--kenar); border-radius:14px; padding:14px;\n    margin-bottom:10px; cursor:pointer; box-shadow:0 1px 2px rgba(0,0,0,.06); }\n  .menu .ik { width:46px; height:46px; border-radius:23px; background:#e3efe6; display:flex; align-items:center; justify-content:center;\n    font-size:22px; color:#14532d; flex:none; }\n  .menu b { display:block; font-size:16.5px; }\n  .menu span { font-size:13.5px; color:var(--soluk); }\n  .menu .ok { margin-left:auto; color:var(--soluk); font-size:22px; }\n  h3 { font-size:15px; color:#14532d; margin:14px 2px 6px; }\n  .rozet { display:inline-block; background:#dbeafe; color:#1d4ed8; font-weight:700; font-size:12px; border-radius:6px; padding:2px 8px; margin:3px 4px 0 0; }\n  .sag { text-align:right; } .yesil { color:#15803D; font-weight:800; } .amb { color:var(--amber); font-weight:800; }\n  main { max-width:1100px; margin:0 auto; padding:10px 12px 40px; }\n  .cipler { display:flex; gap:6px; overflow-x:auto; padding:4px 0 8px; }\n  .cip { border:1px solid var(--kenar); background:#fff; border-radius:16px; padding:6px 12px; font-size:13.5px; white-space:nowrap; cursor:pointer; }\n  .cip.secili { background:#14532d; color:#fff; border-color:#14532d; }\n  .kart { background:#fff; border:1px solid var(--kenar); border-radius:12px; padding:10px; margin-bottom:10px; }\n  .bilgi { background:#eff6ff; border:1px solid #bfdbfe; border-radius:10px; padding:8px 10px; font-size:13px; margin-bottom:10px; }\n  .uyari { color:var(--amber); font-size:12.5px; }\n  #haritaKap { position:relative; overflow:hidden; border-radius:10px; background:#eef2ee; width:100%; aspect-ratio:0.82;\n    max-height:78vh; touch-action:none; user-select:none; -webkit-user-select:none; }\n  #haritaKap.tam { position:fixed; inset:0; z-index:9; border-radius:0; max-height:none; aspect-ratio:auto; }\n  #harita, #yazilar { position:absolute; inset:0; width:100%; height:100%; display:block; }\n  #yazilar { pointer-events:none; }\n  .araclar { position:absolute; right:6px; top:6px; display:flex; flex-direction:column; gap:6px; z-index:2; }\n  .araclar button { width:40px; height:40px; border-radius:20px; border:1px solid var(--kenar); background:#fff; font-size:18px;\n    box-shadow:0 1px 3px rgba(0,0,0,.15); }\n  .ipucu { font-size:12px; color:var(--soluk); margin-top:6px; }\n  .solust { position:absolute; left:6px; top:6px; z-index:2; }\n  .solust button { height:40px; min-width:40px; border-radius:20px; border:1px solid var(--kenar); background:#fff; font-size:15px; padding:0 12px;\n    box-shadow:0 1px 3px rgba(0,0,0,.15); }\n  .solust button.etkin { background:#14532d; color:#fff; }\n  #cizimPanel { position:absolute; left:8px; right:8px; bottom:8px; background:#fff; border-radius:12px; padding:10px; z-index:3;\n    box-shadow:0 2px 8px rgba(0,0,0,.25); font-size:13px; max-height:45%; overflow:auto; }\n  #cizimPanel .cip { padding:5px 10px; font-size:13px; }\n  .kucukDugmeler { display:flex; flex-wrap:wrap; gap:6px; margin-top:8px; }\n  .kucukDugmeler button { border:1px solid #cbd5e1; background:#fff; border-radius:8px; padding:7px 10px; font-size:13.5px; }\n  .kucukDugmeler button.ana { background:#14532d; color:#fff; border-color:#14532d; }\n  .palet { display:flex; flex-wrap:wrap; gap:8px; margin-top:8px; }\n  .palet span { width:34px; height:34px; border-radius:8px; cursor:pointer; border:2px solid #fff; box-shadow:0 0 0 1px #cbd5e1; }\n  .lejant span { cursor:pointer; }\n  .secim label { display:flex; align-items:center; gap:8px; font-size:14px; color:#0f172a; margin:6px 0; }\n  .secim input[type=checkbox], .secim input[type=radio] { width:20px; height:20px; }\n  .lejant { display:flex; flex-wrap:wrap; gap:6px 12px; font-size:12.5px; margin-top:8px; }\n  .lejant span i { display:inline-block; width:12px; height:12px; border-radius:3px; margin-right:4px; vertical-align:-1px; }\n  table { width:100%; border-collapse:collapse; font-size:13px; }\n  td, th { border-bottom:1px solid var(--kenar); padding:6px 4px; text-align:left; vertical-align:top; }\n  tr.tik { cursor:pointer; }\n  #perde { position:fixed; inset:0; background:rgba(15,23,42,.45); display:none; z-index:10; }\n  #sayfa { position:fixed; left:0; right:0; bottom:0; max-height:88vh; overflow:auto; background:#fff; border-radius:16px 16px 0 0;\n           padding:14px 14px 24px; display:none; z-index:11; max-width:640px; margin:0 auto; }\n  #sayfa h2 { margin:0 0 2px; font-size:17px; }\n  label { display:block; font-size:12.5px; color:var(--soluk); margin-top:8px; }\n  select, input { width:100%; font-size:15px; padding:8px; border:1px solid #cbd5e1; border-radius:8px; background:#fff; }\n  .parca { border:1px solid var(--kenar); border-radius:10px; padding:8px; margin-top:8px; }\n  .satir { display:flex; gap:8px; } .satir > * { flex:1; }\n  .dugmeler { display:flex; gap:8px; flex-wrap:wrap; margin-top:14px; }\n  button.ana { background:#14532d; color:#fff; border:0; border-radius:10px; padding:10px 16px; font-size:15px; }\n  button.ikinci { background:#fff; color:#0f172a; border:1px solid #cbd5e1; border-radius:10px; padding:10px 16px; font-size:15px; }\n  button:disabled { opacity:.5; }\n  #durum { position:fixed; left:50%; transform:translateX(-50%); bottom:16px; background:#0f172a; color:#fff; padding:8px 14px;\n           border-radius:10px; font-size:13.5px; display:none; z-index:20; max-width:92vw; }\n  .yukleniyor { padding:40px; text-align:center; color:var(--soluk); }\n</style>\n</head>\n<body>\n<header><div class=\"cubuk\"><button class=\"geri\" id=\"geri\" onclick=\"geri()\" style=\"visibility:hidden\">←</button><h1 id=\"baslik\">Tarla Haritası</h1></div>\n<div id=\"ust\">Yükleniyor…</div><div class=\"sekmeler\" id=\"sekmeler\"></div></header>\n<main>\n  <div id=\"icerik\" class=\"yukleniyor\">Harita yükleniyor…</div>\n</main>\n<div id=\"perde\" onclick=\"kapat()\"></div>\n<div id=\"sayfa\"></div>\n<div id=\"durum\"></div>\n<script>\nvar ANAHTAR = __ANAHTAR__;\nvar VERI_ADRESI = 'https://raw.githubusercontent.com/ramazankcbss-alt/Yonetim-raporu/main/assets/veri/';\nvar DOSYALAR = ['tarla_2025_2026.json', 'tarla_2023_2024.json', 'tarla_2024_2025.json', 'tarla_2026_2027.json'];\nvar SINIR = 400;\nvar URUNLER = ['Buğday', 'Arpa', 'Tritikale', 'Çavdar', 'Yulaf', 'Dane mısır', 'Şeker pancarı', 'Patates', 'Soğan',\n  'Yağlık ayçiçeği', 'Çerezlik ayçiçeği', 'Kanola (kolza)', 'Aspir', 'Soya', 'Nohut', 'Kuru fasulye', 'Mercimek',\n  'Silajlık mısır', 'Silajlık mısır (2. ürün)', 'Yonca', 'Korunga', 'Fiğ', 'Silajlık sorgum', 'Sudan otu', 'Kimyon', 'Kişniş',\n  'Nadas', 'Deneme alanı', 'Islah edilen alan', 'Ağaçlık alan', 'Boş alan'];\nvar RENK = { 'Buğday':'#E0A526','Arpa':'#C9B458','Şeker pancarı':'#8E3B8A','Silajlık mısır':'#3F9142','Silajlık mısır (2. ürün)':'#7CC47F',\n  'Yonca':'#1E7FA8','Patates':'#A0522D','Soğan':'#B8860B','Dane mısır':'#F4D03F','Yağlık ayçiçeği':'#F1C40F','Çerezlik ayçiçeği':'#D4AC0D',\n  'Kanola (kolza)':'#E5E85C','Aspir':'#E67E22','Soya':'#7DAA5A','Nohut':'#D7B98E','Kuru fasulye':'#B05A4A','Mercimek':'#C8743A',\n  'Çavdar':'#A38B5B','Yulaf':'#D9C79E','Tritikale':'#BFA76A','Korunga':'#C2185B','Fiğ':'#6C7A3A','Silajlık sorgum':'#5E8C31',\n  'Sudan otu':'#8BC34A','Kimyon':'#9E7C5A','Kişniş':'#7FA67F','Nadas':'#B8A88A','Deneme alanı':'#00BCD4','Islah edilen alan':'#795548',\n  'Ağaçlık alan':'#2E7D32','Boş alan':'#D6D6D6' };\n\nvar S = { paket: [], sezonParsel: [], parselSinir: [], ekim: [], ekimPlani: [], cks: [], yetki: 'gor', etiket: '', sezon: null, ciftlik: null,\n  yazi: true, ekran: 'ana', sekme: 'harita', pCiftlik: null, tam: false };\n\n// ---------- yardımcılar ----------\nfunction kucuk(s) { return String(s || '').replace(/İ/g, 'i').replace(/I/g, 'ı').toLowerCase(); }\nfunction ciftlikAnahtari(c) {\n  var k = kucuk(c);\n  if (k.indexOf('ormanlık') >= 0) return 'taşağıl';\n  var l = ['şekersüt', 'aslım', 'taşağıl', 'fidanlık', 'pangev', 'pankent'];\n  for (var i = 0; i < l.length; i++) if (k.indexOf(l[i]) >= 0) return l[i];\n  return k;\n}\nfunction urunAnahtari(u) {\n  var k = kucuk(u);\n  if (k.indexOf('2. ürün') >= 0) return 'Silajlık mısır (2. ürün)';\n  if (k.indexOf('pancar') >= 0) return 'Şeker pancarı';\n  if (k.indexOf('dane mısır') >= 0 || k.indexOf('danelik mısır') >= 0) return 'Dane mısır';\n  if (k.indexOf('mısır') >= 0) return 'Silajlık mısır';\n  if (k.indexOf('çerez') >= 0) return 'Çerezlik ayçiçeği';\n  if (k.indexOf('ayçiçe') >= 0) return 'Yağlık ayçiçeği';\n  if (k.indexOf('kanola') >= 0 || k.indexOf('kolza') >= 0) return 'Kanola (kolza)';\n  if (k.indexOf('sorgum') >= 0) return 'Silajlık sorgum';\n  var l = [['buğday','Buğday'],['arpa','Arpa'],['yonca','Yonca'],['patates','Patates'],['soğan','Soğan'],['tritikale','Tritikale'],\n    ['deneme','Deneme alanı'],['ıslah','Islah edilen alan'],['ağaç','Ağaçlık alan'],['boş alan','Boş alan'],['nadas','Nadas']];\n  for (var i = 0; i < l.length; i++) if (k.indexOf(l[i][0]) >= 0) return l[i][1];\n  if (k === 'boş') return 'Boş alan';\n  return u;\n}\nvar OZEL_RENK = (function () { try { return JSON.parse(localStorage.getItem('tarla_urun_renkleri') || '{}'); } catch (e) { return {}; } })();\nfunction renk(u) { var k = urunAnahtari(u); return OZEL_RENK[k] || RENK[k] || '#6D8B74'; }\nvar PALET = ['#E0A526','#F4D03F','#C9B458','#D35400','#C0392B','#E91E63','#8E3B8A','#6C3483','#1E7FA8','#00BCD4','#1ABC9C','#3F9142','#7CC47F','#827717','#A0522D','#5D4037','#607D8B','#212121'];\nfunction renkSec(u) {\n  sayfaAc('<h2>' + esc(u) + ' rengi</h2><div class=\"palet\">' + PALET.map(function (r) { return '<span style=\"background:' + r + '\" onclick=\"renkKaydet(' + js(u) + ',\\'' + r + '\\')\"></span>'; }).join('') +\n    '</div><div class=\"dugmeler\"><button class=\"ikinci\" onclick=\"renkKaydet(' + js(u) + ',null)\">Varsayılan renk</button><button class=\"ikinci\" onclick=\"kapat()\">Kapat</button></div>');\n}\nfunction renkKaydet(u, r) { if (r) OZEL_RENK[u] = r; else delete OZEL_RENK[u]; try { localStorage.setItem('tarla_urun_renkleri', JSON.stringify(OZEL_RENK)); } catch (e) {} kapat(); ciz(); }\nfunction kisa(u) { var k = urunAnahtari(u); if (k.indexOf('Silajlık mısır') === 0) return k.indexOf('2.') >= 0 ? 'Mısır (2. ürün)' : 'Mısır'; if (k === 'Şeker pancarı') return 'Pancar'; return u; }\nfunction sayi(v) { return (Math.round(v * 10) / 10).toLocaleString('tr-TR'); }\nfunction esc(s) { return String(s == null ? '' : s).replace(/[&<>\"']/g, function (c) { return { '&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;',\"'\":'&#39;' }[c]; }); }\nfunction sayiOku(v) { if (v === '' || v == null) return null; if (typeof v === 'number') return v; var x = parseFloat(String(v).replace(/\\./g, '').replace(',', '.')); return isNaN(x) ? null : x; }\nfunction sonrakiSezon(s) { var m = /^(\\d{4})-(\\d{4})$/.exec(s); return m ? (+m[1] + 1) + '-' + (+m[2] + 1) : s; }\nfunction oncekiSezon(s) { var m = /^(\\d{4})-(\\d{4})$/.exec(s); return m ? (+m[1] - 1) + '-' + (+m[2] - 1) : s; }\nfunction durum(t) { var d = document.getElementById('durum'); d.textContent = t; d.style.display = 'block'; clearTimeout(durum.z); durum.z = setTimeout(function () { d.style.display = 'none'; }, 3500); }\n\n// ---------- Sezon_Parselleri \"Ürün\" metni ----------\nfunction urunCesit(s) { var i = s.indexOf('#'); return i < 0 ? [s.trim(), null] : [s.slice(0, i).trim(), s.slice(i + 1).trim()]; }\nfunction icerikOku(t) {\n  t = String(t || '').trim();\n  var at = t.indexOf('@');\n  if (at > 0 && t.indexOf(':') < 0) { var uc = urunCesit(t.slice(0, at)); return { parcalar: [[uc[0], null]], birlesik: t.slice(at + 1).trim(), cizgiler: [], baglar: [], cesitler: [uc[1]], bolgeler: [] }; }\n  if (t.indexOf(':') < 0) { var u = urunCesit(t); return { parcalar: [[u[0], null]], cizgiler: [], baglar: [], cesitler: [u[1]], bolgeler: [] }; }\n  var bolu = t.indexOf('/'), govde = bolu < 0 ? t : t.slice(0, bolu), ek = bolu < 0 ? '' : t.slice(bolu + 1);\n  var bolgeler = [], cizgiler = [];\n  if (ek.charAt(0) === 'B') {\n    ek.slice(1).split(';').forEach(function (b) {\n      if (b.length > 1 && 'DCP'.indexOf(b[0]) >= 0) bolgeler.push([b[0], b.slice(1).split(',').map(parseFloat).filter(function (x) { return !isNaN(x); })]);\n    });\n  } else if (ek) {\n    ek.split(';').forEach(function (c) { var a = c.split(','); if (a.length === 2 && !isNaN(parseFloat(a[0])) && !isNaN(parseFloat(a[1]))) cizgiler.push([parseFloat(a[0]), parseFloat(a[1])]); });\n  }\n  var parcalar = [], baglar = [], cesitler = [];\n  govde.split('+').forEach(function (x) {\n    if (!x.trim()) return;\n    var ad = x.split(':')[0].trim(), ok = ad.indexOf('>');\n    var uc = urunCesit(ok > 0 ? ad.slice(0, ok) : ad);\n    var da = x.indexOf(':') >= 0 ? parseFloat(x.split(':').pop().trim().replace(',', '.')) : null;\n    parcalar.push([uc[0], isNaN(da) ? null : da]); baglar.push(ok > 0 ? ad.slice(ok + 1).trim() : null); cesitler.push(uc[1]);\n  });\n  return { parcalar: parcalar, cizgiler: cizgiler, baglar: baglar, cesitler: cesitler, bolgeler: bolgeler };\n}\nfunction urunMetni(u, c) { return c && c.trim() ? u + '#' + c.trim() : u; }\nfunction sayiYaz(v) { return v % 1 === 0 ? String(v) : String(v); }\nfunction bolunmusMetin(l, cizgiler, baglar, cesitler, bolgeler) {\n  var g = l.map(function (x, i) { return urunMetni(x[0], cesitler[i]) + (baglar[i] ? '>' + baglar[i] : '') + ':' + sayiYaz(x[1]); }).join('+');\n  if (bolgeler && bolgeler.length) return g + '/B' + bolgeler.map(function (b) { return b[0] + b[1].map(function (x) { return Math.round(x); }).join(','); }).join(';');\n  if (cizgiler && cizgiler.length) return g + '/' + cizgiler.map(function (c) { return Math.round(c[0]) + ',' + Math.round(c[1]); }).join(';');\n  return g;\n}\n\n// ---------- sezonlar (uygulamadaki mantıkla) ----------\nfunction parselOku(j) {\n  return { ad: j.ad || '', tip: j.tip || '', not: j.not_ || '', beyan: j.beyan == null ? null : j.beyan,\n    urunler: (j.urunler || []).map(function (u) { return Array.isArray(u) ? [u[0], u.length > 1 ? +u[1] : 0] : [String(u), 0]; }),\n    koord: (j.koord || []).map(function (c) { return [+c[0], +c[1]]; }), cesitler: j.cesitler || [], bolgeler: j.bolgeler || [], bolme: [], baglar: [] };\n}\nfunction sezonOku(j) {\n  return { sezon: j.sezon, kaynak: j.kaynak || '', tur: j.tur || 'kmz', giris: false,\n    ciftlikler: (j.ciftlikler || []).map(function (c) { return { ad: c.ad, gorseller: c.gorseller || [], parseller: (c.parseller || []).map(parselOku) }; }) };\n}\nfunction parselGirisi(sezon, cf, parsel) {\n  var d = null;\n  S.sezonParsel.forEach(function (r) {\n    if (String(r[0]) === sezon && ciftlikAnahtari(r[1]) === ciftlikAnahtari(cf) && kucuk(r[2]).trim() === kucuk(parsel).trim()) {\n      if (r[6] === 'Aktif') d = { urun: String(r[3]), alan: sayiOku(r[4]) }; else if (r[6] === 'Geri alındı') d = null;\n    }\n  });\n  return d;\n}\nfunction kopya(p, ek) { var o = {}; for (var k in p) o[k] = p[k]; for (var k2 in ek) o[k2] = ek[k2]; return o; }\nfunction girisParseli(p, g, bagli, gelen) {\n  var ic = icerikOku(g.urun), y;\n  if (ic.birlesik) y = kopya(p, { tip: 'ekili', urunler: [[ic.parcalar[0][0], 0]], beyan: null, not: ic.birlesik + ' ile birleştirildi', cesitler: ic.cesitler, bolme: [], bolgeler: [], baglar: [], birlesik: ic.birlesik });\n  else if (ic.parcalar.length > 1) {\n    var l = ic.parcalar.map(function (x) { return [x[0], x[1] || 0]; }), giden = 0, top = 0;\n    l.forEach(function (x, i) { top += x[1]; if (ic.baglar[i]) giden += x[1]; });\n    y = kopya(p, { tip: 'ekili', urunler: l, beyan: giden > 0 ? top - giden : (g.alan != null ? g.alan : top), not: 'Parçalara bölündü',\n      bolme: ic.cizgiler.length === l.length - 1 ? ic.cizgiler : [], baglar: ic.baglar, cesitler: ic.cesitler,\n      bolgeler: ic.bolgeler.length === l.length - 1 ? ic.bolgeler : [] });\n  } else y = kopya(p, { tip: 'ekili', urunler: [[ic.parcalar[0][0], g.alan || 0]], beyan: g.alan, cesitler: ic.cesitler, bolme: [], bolgeler: [], baglar: [],\n      not: bagli.length ? bagli.join(', ') + ' ile birleştirildi (alan toplamdır)' : '' });\n  if (gelen.length) {\n    var ek = 0; gelen.forEach(function (x) { ek += x[2]; });\n    y.beyan = (y.beyan || 0) + ek;\n    y.not = [y.not, gelen.map(function (x) { return x[0] + ' parselinden ' + x[1] + ' ' + sayi(x[2]) + ' da'; }).join(', ')].filter(Boolean).join(' · ');\n  }\n  y.giris = true;\n  return y;\n}\nfunction kmzNotu(y, k) {\n  if (!k || !k.urunler.length || !k.not) return y;\n  function oz(x) { return x.urunler.map(function (u) { return urunAnahtari(u[0]) + ' ' + Math.round(u[1]); }).join('+'); }\n  if (oz(y) === oz(k)) return y;\n  return kopya(y, { not: [y.not, \"KMZ'de farklı → \" + k.not.replace('KMZ: ', '')].filter(Boolean).join(' · ') });\n}\nfunction katmanda(katman, cf, ad) {\n  if (!katman) return null;\n  for (var i = 0; i < katman.ciftlikler.length; i++) {\n    var c = katman.ciftlikler[i]; if (c.ad !== cf) continue;\n    for (var j = 0; j < c.parseller.length; j++) if (c.parseller[j].ad === ad) return c.parseller[j];\n  }\n  return null;\n}\nfunction girisSezonu(taban, ad, katman) {\n  return { sezon: ad, giris: true, tur: katman ? katman.tur : 'giris', kaynak: (katman ? katman.kaynak + ' + ' : '') + 'haritadan girilen bilgiler',\n    ciftlikler: taban.ciftlikler.map(function (c) {\n      return { ad: c.ad, gorseller: c.gorseller, parseller: c.parseller.map(function (p) {\n        var g = parselGirisi(ad, c.ad, p.ad), k = katmanda(katman, c.ad, p.ad);\n        if (g) {\n          var bagli = [], gelen = [];\n          c.parseller.forEach(function (q) {\n            if (q.ad === p.ad) return;\n            var h = parselGirisi(ad, c.ad, q.ad); if (!h) return;\n            var ic = icerikOku(h.urun);\n            if (ic.birlesik === p.ad) bagli.push(q.ad);\n            ic.parcalar.forEach(function (x, i) { if (ic.baglar[i] === p.ad) gelen.push([q.ad, x[0], x[1] || 0]); });\n          });\n          return kmzNotu(girisParseli(p, g, bagli, gelen), k);\n        }\n        if (k && k.urunler.length) {\n          var top = 0; k.urunler.forEach(function (u) { top += u[1]; });\n          return kopya(p, { tip: k.tip === 'girilmedi' || !k.tip ? 'parsel' : k.tip, urunler: k.urunler, beyan: top, not: k.not,\n            cesitler: k.cesitler, bolgeler: k.bolgeler.length === k.urunler.length - 1 ? k.bolgeler : [], bolme: [], baglar: [] });\n        }\n        return kopya(p, { tip: p.tip === 'diger' || p.tip === 'bos' ? p.tip : 'girilmedi', urunler: [], beyan: null, not: '', cesitler: [], bolgeler: [], bolme: [], baglar: [] });\n      }) };\n    }) };\n}\nfunction kmzUzerine(kmz) {\n  return { sezon: kmz.sezon, giris: false, tur: 'kmz', kaynak: kmz.kaynak, ciftlikler: kmz.ciftlikler.map(function (c) {\n    return { ad: c.ad, gorseller: c.gorseller, parseller: c.parseller.map(function (p) {\n      var g = parselGirisi(kmz.sezon, c.ad, p.ad);\n      if (g && (icerikOku(g.urun).parcalar.length > 1 || p.tip === 'girilmedi')) {\n        var y = girisParseli(p, g, [], []);\n        return kopya(y, { tip: p.tip === 'girilmedi' ? y.tip : p.tip, beyan: p.beyan != null ? p.beyan : y.beyan, giris: false });\n      }\n      return p;\n    }) };\n  }) };\n}\nfunction sinirUygula(kmz) {\n  var m = {};\n  S.parselSinir.forEach(function (r) {\n    var key = r[0] + '|' + r[1];\n    if (r[4] === 'Aktif') {\n      var k = String(r[2] || '').trim().split(/\\s+/).map(function (n) { var a = n.split(','); return [parseFloat(a[0]), parseFloat(a[1])]; })\n        .filter(function (c) { return !isNaN(c[0]) && !isNaN(c[1]); });\n      if (k.length > 2) m[key] = k;\n    } else if (r[4] === 'Geri alındı') delete m[key];\n  });\n  return kopya(kmz, { ciftlikler: kmz.ciftlikler.map(function (c) {\n    var l = c.parseller.map(function (p) { return m[c.ad + '|' + p.ad] ? kopya(p, { koord: m[c.ad + '|' + p.ad] }) : p; });\n    Object.keys(m).forEach(function (key) {\n      var a = key.split('|'); if (a[0] !== c.ad) return;\n      if (!c.parseller.some(function (p) { return p.ad === a[1]; }))\n        l.push({ ad: a[1], tip: 'girilmedi', urunler: [], koord: m[key], not: 'Haritadan eklendi', cesitler: [], bolgeler: [], bolme: [], baglar: [] });\n    });\n    return { ad: c.ad, gorseller: c.gorseller, parseller: l };\n  }) });\n}\nfunction sezonlar() {\n  var kmz = S.paket.filter(function (k) { return k.tur === 'kmz'; })[0];\n  if (!kmz) return [];\n  kmz = sinirUygula(kmz);\n  function bul(s, t) { return S.paket.filter(function (k) { return k.sezon === s && k.tur === t; })[0]; }\n  var s1 = oncekiSezon(kmz.sezon), s3 = sonrakiSezon(kmz.sezon), ayri = bul(oncekiSezon(s1), 'ayri');\n  var l = [];\n  if (ayri) l.push(girisSezonu(ayri, ayri.sezon, ayri));\n  l.push(girisSezonu(kmz, s1, bul(s1, 'katman')));\n  l.push(kmzUzerine(kmz));\n  l.push(girisSezonu(kmz, s3, bul(s3, 'katman')));\n  return l;\n}\n\n// ---------- geometri ----------\nfunction alan(k) { var a = 0; for (var i = 0; i < k.length; i++) { var p = k[i], q = k[(i + 1) % k.length]; a += p[0] * q[1] - q[0] * p[1]; } return Math.abs(a) / 2; }\nfunction cizgiDenklemi(k, cz) {\n  var r = cz[0] * Math.PI / 180, nx = -Math.sin(r), ny = Math.cos(r), mn = Infinity, mx = -Infinity;\n  k.forEach(function (p) { var v = nx * p[0] + ny * p[1]; mn = Math.min(mn, v); mx = Math.max(mx, v); });\n  return [nx, ny, mn + (mx - mn) * Math.max(0, Math.min(100, cz[1])) / 100];\n}\nfunction kirp(k, d, birinci) {\n  function f(p) { var v = d[0] * p[0] + d[1] * p[1] - d[2]; return birinci ? v : -v; }\n  var out = [];\n  for (var i = 0; i < k.length; i++) {\n    var a = k[i], b = k[(i + 1) % k.length], fa = f(a), fb = f(b);\n    if (fa <= 0) out.push(a);\n    if ((fa < 0 && fb > 0) || (fa > 0 && fb < 0)) { var t = fa / (fa - fb); out.push([a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1])]); }\n  }\n  return out;\n}\nfunction parcala(k, cizgiler) {\n  var d = cizgiler.map(function (c) { return cizgiDenklemi(k, c); }), l = [];\n  for (var i = 0; i <= d.length; i++) { var p = k; if (i > 0) p = kirp(p, d[i - 1], false); if (i < d.length) p = kirp(p, d[i], true); l.push(p); }\n  return l;\n}\nfunction otomatikCizgiler(k, dekarlar) {\n  var top = dekarlar.reduce(function (a, b) { return a + b; }, 0);\n  var oran = dekarlar.map(function (d) { return top > 0 ? d / top : 1 / dekarlar.length; }), tum = alan(k), l = [], bir = 0;\n  for (var i = 0; i < oran.length - 1; i++) {\n    bir += oran[i]; var a = 0, b = 100;\n    for (var j = 0; j < 30; j++) { var m = (a + b) / 2, p = kirp(k, cizgiDenklemi(k, [90, m]), true); if ((p.length < 3 ? 0 : alan(p)) / tum < bir) a = m; else b = m; }\n    l.push([90, (a + b) / 2]);\n  }\n  return l;\n}\nfunction kutu(k) { var xs = k.map(function (e) { return e[0]; }), ys = k.map(function (e) { return e[1]; });\n  return [Math.min.apply(null, xs), Math.min.apply(null, ys), Math.max.apply(null, xs), Math.max.apply(null, ys)]; }\nfunction bolgePoligon(k, b) {\n  var q = kutu(k), w = q[2] - q[0], h = q[3] - q[1], v = b[1];\n  function n(px, py) { return [q[0] + px / 100 * w, q[1] + py / 100 * h]; }\n  if (b[0] === 'D' && v.length >= 4) return [n(v[0], v[1]), n(v[2], v[1]), n(v[2], v[3]), n(v[0], v[3])];\n  if (b[0] === 'C' && v.length >= 4) { var l = []; for (var i = 0; i < 48; i++) l.push(n(v[0] + v[2] * Math.cos(i * Math.PI / 24), v[1] + v[3] * Math.sin(i * Math.PI / 24))); return l; }\n  if (b[0] === 'P' && v.length >= 6) { var p = []; for (var j = 0; j + 1 < v.length; j += 2) p.push(n(v[j], v[j + 1])); return p; }\n  return [];\n}\nfunction merkez(k) { var x = 0, y = 0; k.forEach(function (p) { x += p[0]; y += p[1]; }); return [x / k.length, y / k.length]; }\n\n// ---------- Excel / ÇKS (uygulamadaki karşılaştırma mantığı) ----------\nvar EXCEL2025 = [['Şekersüt','Silajlık mısır',670],['Şekersüt','Buğday',1700],['Şekersüt','Şeker pancarı',700],['Aslım','Silajlık mısır',140],\n  ['Aslım','Şeker pancarı',900],['Aslım','Arpa',1340],['Aslım','Buğday',520],['Aslım','Tritikale',200],['Aslım','Yonca',1360],\n  ['Taşağıl','Patates',400],['Ormanlık','Şeker pancarı',230],['Fidanlık','Buğday',130],['Fidanlık','Arpa',600]];\nfunction uretimYili(s) { return s.indexOf('-') >= 0 ? s.split('-').pop() : s; }\nfunction ekle(m, k, v) { m[k] = (m[k] || 0) + v; }\nfunction sezonExcel(s, cf) {\n  var m = {};\n  if (!s.giris) { S.ekim.forEach(function (r) { var pl = sayiOku(r[2]); if (ciftlikAnahtari(r[0]) === ciftlikAnahtari(cf) && pl > 0) ekle(m, urunAnahtari(String(r[1])), pl); }); return m; }\n  S.ekimPlani.forEach(function (r) { var pl = sayiOku(r[3]); if (String(r[0]) === uretimYili(s.sezon) && ciftlikAnahtari(r[1]) === ciftlikAnahtari(cf) && pl > 0) ekle(m, urunAnahtari(String(r[2])), pl); });\n  if (Object.keys(m).length || uretimYili(s.sezon) !== '2025') return m;\n  EXCEL2025.forEach(function (x) { if (ciftlikAnahtari(x[0]) === ciftlikAnahtari(cf)) ekle(m, urunAnahtari(x[1]), x[2]); });\n  return m;\n}\nfunction excelKaynak(s) { return !s.giris ? '2026-2027 Ekim Planı (Excel)' : uretimYili(s.sezon) === '2025' ? 'Tarımsal Faaliyet › ÇİFTLİK BAZINDA, 2025 yılı (Excel)' : uretimYili(s.sezon) + ' Excel ekim planı'; }\nfunction urunToplami(c) { var m = {}; c.parseller.forEach(function (p) { p.urunler.forEach(function (u) { ekle(m, urunAnahtari(u[0]), u[1] || 0); }); }); return m; }\nfunction cksKayit(r) { return { sezon: String(r[0] || ''), ciftlik: String(r[1] || ''), mevki: String(r[2] || ''), ada: String(r[3] || ''), parsel: String(r[4] || ''),\n  urun: String(r[5] || ''), alan: sayiOku(r[6]), eslesen: String(r[7] || '') }; }\nfunction sezonCks(s, cf) { return S.cks.map(cksKayit).filter(function (x) { return x.sezon === s.sezon && ciftlikAnahtari(x.ciftlik) === ciftlikAnahtari(cf); }); }\nfunction parselCks(s, cf, ad) { return S.cks.map(cksKayit).filter(function (x) { return (!x.sezon || x.sezon === s.sezon) && ciftlikAnahtari(x.ciftlik) === ciftlikAnahtari(cf) &&\n  x.eslesen.split(',').some(function (e) { return kucuk(e).trim() === kucuk(ad).trim(); }); }); }\nfunction yakin(a, b) { return Math.abs(a - b) <= Math.max(5, b * 0.03); }\n\n// ---------- ekranlar (uygulamadaki menüler) ----------\nfunction guncelSezon() { var l = sezonlar(); return l.filter(function (x) { return x.sezon === S.sezon; })[0] || l[l.length - 1]; }\nfunction menu(ik, b, alt, tik) { return '<div class=\"menu\" onclick=\"' + tik + '\"><div class=\"ik\">' + ik + '</div><div><b>' + esc(b) + '</b><span>' + esc(alt) + '</span></div><div class=\"ok\">›</div></div>'; }\nfunction geri() {\n  if (S.tam) { tamEkran(); return; }\n  if (S.ekran === 'ciftlikParsel') S.ekran = 'sezon'; else S.ekran = 'ana';\n  ciz(); window.scrollTo(0, 0);\n}\nfunction git(ekran, ek) { for (var k in (ek || {})) S[k] = ek[k]; S.ekran = ekran; ciz(); window.scrollTo(0, 0); }\nfunction ciz() {\n  var l = sezonlar(), kok = document.getElementById('icerik');\n  kok.className = '';\n  if (!l.length) { kok.innerHTML = '<div class=\"kart\">Harita verisi yok.</div>'; return; }\n  var geriB = document.getElementById('geri'), bas = document.getElementById('baslik'), sek = document.getElementById('sekmeler');\n  geriB.style.visibility = S.ekran === 'ana' ? 'hidden' : 'visible'; sek.innerHTML = '';\n  if (S.ekran === 'ana') { bas.textContent = 'Tarla Haritası'; kok.innerHTML = anaEkran(l); return; }\n  if (S.ekran === 'yil') { bas.textContent = 'Yıllara göre karşılaştırma'; kok.innerHTML = yilEkrani(l); return; }\n  var s = guncelSezon();\n  if (S.ekran === 'ciftlikParsel') {\n    var c0 = s.ciftlikler.filter(function (x) { return x.ad === S.pCiftlik; })[0];\n    bas.textContent = S.pCiftlik + ' parselleri'; kok.innerHTML = c0 ? ciftlikParselleri(s, c0) : ''; return;\n  }\n  bas.textContent = 'Tarla Haritası ' + s.sezon;\n  sek.innerHTML = [['harita', 'Harita'], ['parseller', 'Parseller'], ['karsi', 'Karşılaştırma'], ['cks', 'ÇKS']].map(function (t) {\n    return '<div class=\"sekme' + (S.sekme === t[0] ? ' secili' : '') + '\" onclick=\"S.sekme=\\'' + t[0] + '\\';ciz()\">' + t[1] + '</div>'; }).join('');\n  if (S.sekme === 'harita') return haritaSekmesi(s, kok);\n  kok.innerHTML = S.sekme === 'parseller' ? parselSekmesi(s) : S.sekme === 'karsi' ? karsiSekmesi(s) : cksSekmesi(s);\n}\nfunction anaEkran(l) {\n  var h = '<div class=\"bilgi\">Her sezon ayrı bir bölümdür; içinde Harita, Parseller, Karşılaştırma ve ÇKS sekmeleri yer alır. Parsel çizimleri ve sezonların ürünleri Google Earth KMZ haritasından alınır; 2023-2024 sezonu o yılın parsel düzeniyle gösterilir. ' +\n    (S.yetki === 'duzenle' ? 'Parsele dokunarak ürün, dekar ve tohum girebilirsiniz.' : 'Yalnızca görüntüleme yetkiniz var.') + '</div>';\n  l.forEach(function (x) {\n    var ps = []; x.ciftlikler.forEach(function (c) { c.parseller.forEach(function (p) { if (p.tip !== 'diger') ps.push(p); }); });\n    var gir = ps.filter(function (p) { return p.urunler.length; }).length, cks = S.cks.filter(function (r) { return String(r[0]) === x.sezon; }).length, ex = 0;\n    x.ciftlikler.forEach(function (c) { var m = sezonExcel(x, c.ad); for (var k in m) ex += m[k]; });\n    var alt = [uretimYili(x.sezon) + ' üretim yılı', x.giris ? 'Haritadan girilen: ' + gir + ' / ' + ps.length + ' parsel' : 'KMZ haritası (' + x.kaynak + ')',\n      ex > 0 ? 'Excel: ' + sayi(ex) + ' da' : 'Excel kaydı yok'].concat(cks ? ['ÇKS: ' + cks + ' kayıt'] : []).join(' · ');\n    h += menu(x.giris ? '✎' : '▦', x.sezon + ' sezonu', alt, \"git('sezon',{sezon:'\" + x.sezon + \"',sekme:'harita'})\");\n  });\n  h += menu('⇄', 'Yıllara göre ekim karşılaştırması', l.map(function (x) { return x.sezon; }).join(' · ') + ' — çiftlik ve ürün alanları, parsel geçmişi', \"git('yil')\");\n  return h;\n}\nfunction haritaSekmesi(s, kok) {\n  var cfler = s.ciftlikler.filter(function (c) { return c.parseller.some(function (p) { return p.koord.length > 2; }); });\n  if (!S.ciftlik || !cfler.some(function (c) { return c.ad === S.ciftlik; })) S.ciftlik = cfler.length ? cfler[0].ad : null;\n  var c = cfler.filter(function (x) { return x.ad === S.ciftlik; })[0];\n  var h = '<div class=\"cipler\">' + cfler.map(function (x) { return '<span class=\"cip' + (c && x.ad === c.ad ? ' secili' : '') + '\" onclick=\"ciftlikSec(' + js(x.ad) + ')\">' + esc(x.ad) + '</span>'; }).join('') + '</div>';\n  if (!c) { kok.innerHTML = h + '<div class=\"kart\">Bu sezonda çizili parsel yok.</div>'; return; }\n  var duz = S.yetki === 'duzenle' && s.giris;\n  h += '<div style=\"font-size:19px;font-weight:800;margin:4px 2px 0\">' + esc(c.ad) + '</div><div style=\"font-size:13px;color:var(--soluk);margin:0 2px 8px\">' + esc(s.sezon) + ' sezonu · kaynak: ' + esc(s.kaynak) + '</div>';\n  h += '<div class=\"kart\" style=\"padding:6px\"><div id=\"haritaKap\"' + (S.tam ? ' class=\"tam\"' : '') + '><svg id=\"harita\" xmlns=\"http://www.w3.org/2000/svg\"><g id=\"sahne\"></g></svg><svg id=\"yazilar\" xmlns=\"http://www.w3.org/2000/svg\"></svg>' +\n    '<div class=\"araclar\"><button title=\"Tam ekran\" onclick=\"tamEkran()\">⛶</button><button title=\"Sığdır\" onclick=\"sifirla()\">⟲</button><button title=\"Yazılar\" onclick=\"S.yazi=!S.yazi;yazilar()\" style=\"font-size:14px\">Aa</button></div>' +\n    (S.yetki === 'duzenle' ? '<div class=\"solust\"><button class=\"' + (C.acik ? 'etkin' : '') + '\" onclick=\"cizimAcKapa()\">' + (C.acik ? '✕ Çizimi bitir' : '✎') + '</button></div>' : '') +\n    '<div id=\"cizimPanel\" style=\"display:' + (C.acik ? 'block' : 'none') + '\"></div></div></div>';\n  h += '<div class=\"ipucu\">' + (duz ? 'Parsele dokunarak ' + esc(s.sezon) + ' sezonu için ürün, dekar ve tohum girebilirsiniz. ' : S.yetki !== 'duzenle' ? 'Parsele dokununca bilgisi açılır. ' : 'Bu sezon (KMZ esas haritası) yalnızca görüntülenir. ') +\n    'İki parmakla yakınlaştırabilir, tek parmakla kaydırabilir, sağ üstteki düğmeyle tam ekran açabilirsiniz.</div>';\n  var top = urunToplami(c), tur = {}; (c.gorseller || []).forEach(function (g) { tur[g.tur] = 1; });\n  var cksVar = c.parseller.some(function (p) { return parselCks(s, c.ad, p.ad).length; });\n  h += '<div class=\"lejant\">' + (cksVar ? '<span><i style=\"background:#fff;border:2px solid #1d4ed8\"></i>Mavi kenarlı: ÇKS\\'de bildirildi</span>' : '') +\n    (tur.hat || tur.og ? '<span><i style=\"background:#EF6C00;height:3px\"></i>Enerji / su hattı</span>' : '') + (tur.kuyu ? '<span><i style=\"background:#0277BD;border-radius:6px\"></i>Kuyu</span>' : '') + '</div>';\n  h += '<div class=\"lejant\">' + Object.keys(top).map(function (k) { return '<span onclick=\"renkSec(' + js(k) + ')\"><i style=\"background:' + renk(k) + '\"></i>' + esc(k) + (top[k] > 0 ? ': ' + sayi(top[k]) + ' da' : '') + '</span>'; }).join('') + '</div>' +\n    '<div class=\"ipucu\">Ürün rengini değiştirmek için renk kutusuna dokunun.' + (S.yetki === 'duzenle' ? ' Çizgi, kare, daire, nokta ile bölme, sınır düzenleme ve yeni parsel için haritanın sol üstündeki kalem düğmesine basın.' : '') + '</div>';\n  kok.innerHTML = h;\n  haritaKur(c, s);\n  cizimPaneli();\n}\nfunction parselKarti(s, c, p, i) {\n  var cks = parselCks(s, c.ad, p.ad), oz = {};\n  cks.forEach(function (x) { if (!oz[x.urun]) oz[x.urun] = [0, 0]; oz[x.urun][0] += x.alan || 0; oz[x.urun][1]++; });\n  var r = p.urunler.length ? renk(p.urunler[0][0]) : (p.tip === 'bos' || p.tip === 'girilmedi' ? '#D6D6D6' : '#90A4AE');\n  return '<div class=\"kart\" style=\"cursor:pointer\" onclick=\"S.ciftlik=' + js(c.ad) + ';parselAc(' + i + ')\"><div><i style=\"display:inline-block;width:12px;height:12px;background:' + r + ';margin-right:8px\"></i><b>' + esc(p.ad) + '</b></div>' +\n    '<div style=\"margin-top:2px\">' + esc(urunYazi(p)) + '</div>' +\n    Object.keys(oz).map(function (k) { return '<span class=\"rozet\">ÇKS\\'de bildirildi: ' + esc(k) + ' · ' + sayi(oz[k][0]) + ' da (' + oz[k][1] + ' kayıt)</span>'; }).join('') +\n    (p.not ? '<div class=\"uyari\">' + esc(p.not) + '</div>' : '') + '</div>';\n}\nfunction parselSekmesi(s) {\n  var h = '<h3>Çiftlikler</h3>';\n  s.ciftlikler.forEach(function (c) {\n    var top = 0, m = s.giris ? urunToplami(c) : sezonExcel(s, c.ad); for (var k in m) top += m[k];\n    var ck = c.parseller.filter(function (p) { return parselCks(s, c.ad, p.ad).length; }).length;\n    h += menu('▦', c.ad, c.parseller.length + ' parsel · ' + (s.giris ? 'Girilen' : 'Excel') + ': ' + sayi(top) + ' da ekili' + (ck ? ' · ' + ck + \" parsel ÇKS'de bildirildi\" : ''),\n      \"git('ciftlikParsel',{pCiftlik:\" + js(c.ad) + \"})\");\n  });\n  return h;\n}\nfunction ciftlikParselleri(s, c) { return c.parseller.map(function (p, i) { return parselKarti(s, c, p, i); }).join(''); }\nfunction karsiSekmesi(s) {\n  var sat = [], exVar = false, gir = 0;\n  s.ciftlikler.forEach(function (c) {\n    var g = urunToplami(c), ex = sezonExcel(s, c.ad), k = {};\n    if (Object.keys(ex).length) exVar = true;\n    sezonCks(s, c.ad).forEach(function (x) { if (x.alan != null) ekle(k, urunAnahtari(x.urun), x.alan); });\n    var tum = {}; [g, ex, k].forEach(function (m) { for (var u in m) tum[u] = 1; });\n    Object.keys(tum).forEach(function (u) { sat.push([c.ad, u, g[u], ex[u], k[u]]); });\n    c.parseller.forEach(function (p) { if (p.tip === 'girilmedi') gir++; });\n  });\n  var h = '<div class=\"bilgi\">' + (s.giris ? esc(s.sezon) + ' sezonu, haritada parsellere girilen ürün ve alanlardan oluşur. ' : 'KMZ esas haritası. ') +\n    'Esas alınan kaynak Excel: ' + esc(excelKaynak(s)) + '.' + (exVar ? '' : ' Excel dosyalarında bu yıl için henüz kayıt yok.') + '</div>';\n  if (gir) h += '<div class=\"uyari\">Ürün girilmemiş parsel: ' + gir + '</div>';\n  h += '<h3>Excel esaslı ekim alanları (da)</h3><div class=\"kart\"><table><tr><th>Çiftlik · Ürün</th><th class=\"sag\">Excel</th><th class=\"sag\">Harita</th><th class=\"sag\">ÇKS</th><th class=\"sag\">Fark</th></tr>' +\n    sat.map(function (r) {\n      var g = r[2], pl = r[3], k = r[4];\n      var fark = g == null || pl == null || g <= 0 ? '—' : yakin(g, pl) ? '<span class=\"yesil\">✓</span>' : '<span class=\"amb\">' + (g - pl >= 0 ? '+' : '−') + sayi(Math.abs(g - pl)) + '</span>';\n      return '<tr><td>' + esc(r[0] + ' · ' + r[1]) + '</td><td class=\"sag\">' + (pl == null ? '—' : sayi(pl)) + '</td><td class=\"sag' + (g > 0 && pl != null && !yakin(g, pl) ? ' amb' : '') + '\">' +\n        (g == null ? '—' : g > 0 ? sayi(g) : 'ekili') + '</td><td class=\"sag' + (k != null && pl != null && !yakin(k, pl) ? ' amb' : '') + '\">' + (k == null ? '—' : sayi(k)) + '</td><td class=\"sag\">' + fark + '</td></tr>';\n    }).join('') + '</table></div>';\n  // Münavebe: önceki sezonla aynı parselde aynı ürün\n  var l = sezonlar(), i = l.map(function (x) { return x.sezon; }).indexOf(s.sezon), once = i > 0 ? l[i - 1] : null;\n  if (s.giris && once) {\n    h += '<h3>Münavebe (' + esc(once.sezon) + ' → ' + esc(s.sezon) + ')</h3>';\n    s.ciftlikler.forEach(function (c) {\n      var oc = once.ciftlikler.filter(function (x) { return x.ad === c.ad; })[0];\n      c.parseller.forEach(function (p) {\n        if (!p.urunler.length) return;\n        var op = oc && oc.parseller.filter(function (x) { return x.ad === p.ad; })[0], ou = op ? op.urunler.map(function (u) { return urunAnahtari(u[0]); }) : [];\n        var ust = p.urunler.map(function (u) { return urunAnahtari(u[0]); }).filter(function (u) { return ou.indexOf(u) >= 0; });\n        var hata = ust.filter(function (u) { return ['Yonca', 'Korunga', 'Çayır'].indexOf(u) < 0 && ['Nadas', 'Deneme alanı', 'Islah edilen alan', 'Ağaçlık alan', 'Boş alan'].indexOf(u) < 0; });\n        h += '<div class=\"kart\"><b>' + (hata.length ? '⚠ ' : '✓ ') + esc(c.ad + ' · ' + p.ad) + '</b><div style=\"font-size:13px\">' + esc((ou.length ? ou.join(' + ') : 'ürün yok') + ' → ' + urunYazi(p)) + '</div>' +\n          (hata.length ? '<div class=\"uyari\">Aynı ürün üst üste ekiliyor: ' + esc(hata.join(', ')) + '.</div>' : '') + '</div>';\n      });\n    });\n  }\n  return h;\n}\nfunction cksSekmesi(s) {\n  var h = '<div class=\"bilgi\">ÇKS (Çiftçi Kayıt Sistemi) beyanları: ' + esc(s.sezon) + ' sezonu.</div>';\n  s.ciftlikler.forEach(function (c) {\n    var l = sezonCks(s, c.ad); if (!l.length) return;\n    var top = l.reduce(function (a, x) { return a + (x.alan || 0); }, 0);\n    h += '<h3>' + esc(c.ad) + ' · ' + l.length + ' kayıt · ' + sayi(top) + ' da</h3><div class=\"kart\"><table><tr><th>Ada / parsel</th><th>Ürün</th><th class=\"sag\">Alan</th><th>Haritada</th></tr>' +\n      l.map(function (x) { return '<tr><td>' + esc([x.ada ? 'Ada ' + x.ada : '', x.parsel ? 'Parsel ' + x.parsel : ''].filter(Boolean).join(' / ')) + (x.mevki ? '<div style=\"font-size:11.5px;color:var(--soluk)\">' + esc(x.mevki) + '</div>' : '') +\n        '</td><td>' + esc(x.urun) + '</td><td class=\"sag\">' + (x.alan == null ? '—' : sayi(x.alan)) + '</td><td>' + esc(x.eslesen || '—') + '</td></tr>'; }).join('') + '</table></div>';\n  });\n  if (h.indexOf('<h3>') < 0) h += '<div class=\"kart\">Bu sezon için ÇKS kaydı yok.</div>';\n  return h;\n}\nfunction yilEkrani(l) {\n  var cfler = {}; l.forEach(function (s) { s.ciftlikler.forEach(function (c) { cfler[c.ad] = 1; }); });\n  var h = '<div class=\"bilgi\">Alanlar Excel dosyalarından; Excel kaydı olmayan sezonda haritadan girilen alanlar (*) gösterilir.</div>';\n  Object.keys(cfler).forEach(function (cf) {\n    var m = {};\n    l.forEach(function (s, i) {\n      var ex = sezonExcel(s, cf), yildiz = false;\n      if (!Object.keys(ex).length) { var c = s.ciftlikler.filter(function (x) { return ciftlikAnahtari(x.ad) === ciftlikAnahtari(cf); })[0]; if (c) { ex = urunToplami(c); yildiz = true; } }\n      for (var u in ex) if (ex[u] > 0) { m[u] = m[u] || {}; m[u][i] = sayi(ex[u]) + (yildiz ? '*' : ''); }\n    });\n    if (!Object.keys(m).length) return;\n    h += '<h3>' + esc(cf) + '</h3><div class=\"kart\" style=\"overflow-x:auto\"><table><tr><th>Ürün</th>' + l.map(function (s) { return '<th class=\"sag\">' + esc(s.sezon) + '</th>'; }).join('') + '</tr>' +\n      Object.keys(m).map(function (u) { return '<tr><td><i style=\"display:inline-block;width:10px;height:10px;background:' + renk(u) + ';margin-right:6px\"></i>' + esc(u) + '</td>' +\n        l.map(function (_, i) { return '<td class=\"sag\">' + (m[u][i] || '—') + '</td>'; }).join('') + '</tr>'; }).join('') + '</table></div>';\n  });\n  return h;\n}\nfunction urunYazi(p) {\n  if (!p.urunler.length) return p.tip === 'bos' ? 'Boş alan' : p.tip === 'girilmedi' ? 'Girilmedi' : 'Ürün belirtilmemiş';\n  return p.urunler.map(function (u, i) { var c = p.cesitler[i]; return u[0] + (c ? ' (' + c + ')' : '') + (u[1] > 0 ? ' ' + sayi(u[1]) + ' da' : '') + (p.baglar[i] ? ' → ' + p.baglar[i] : ''); }).join(' + ');\n}\nfunction dekar(p) { if (p.beyan) return p.beyan; var t = 0; p.urunler.forEach(function (u) { t += u[1] || 0; }); return t; }\n\n// ---------- harita: parmakla yakınlaştırma/kaydırma, sabit boyutlu yazılar (uygulamadaki gibi) ----------\nvar H = null; // { c, G, gor, W, Hh, T:{s,x,y}, etiketler }\nvar GORSEL_RENK = { kuyu:'#0277BD', direk:'#37474F', og:'#D32F2F', pivot:'#455A64', nokta:'#D32F2F' };\nfunction icinde(n, k) { var ic = false; for (var i = 0, j = k.length - 1; i < k.length; j = i++) { var a = k[i], b = k[j];\n  if ((a[1] > n[1]) !== (b[1] > n[1]) && n[0] < (b[0] - a[0]) * (n[1] - a[1]) / (b[1] - a[1]) + a[0]) ic = !ic; } return ic; }\nfunction kenarUzak(n, k) { var m = Infinity; for (var i = 0; i < k.length; i++) { var a = k[i], b = k[(i + 1) % k.length], dx = b[0] - a[0], dy = b[1] - a[1], l2 = dx * dx + dy * dy;\n  var t = l2 === 0 ? 0 : Math.max(0, Math.min(1, ((n[0] - a[0]) * dx + (n[1] - a[1]) * dy) / l2)), x = a[0] + t * dx - n[0], y = a[1] + t * dy - n[1]; m = Math.min(m, Math.sqrt(x * x + y * y)); } return m; }\n/** Yazı noktası: üstteki küçük parsellerin dışında, kenarlardan en uzak iç nokta (uygulamadaki gibi). */\nfunction yaziNoktasi(g, G) {\n  var k = g.k, alt = G.filter(function (y) { return y !== g && y.alan < g.alan; }).map(function (y) { return y.k; });\n  var q0 = kutu(k), en = null, skor = -1, n = 28;\n  for (var i = 0; i <= n; i++) for (var j = 0; j <= n; j++) {\n    var q = [q0[0] + (q0[2] - q0[0]) * i / n, q0[1] + (q0[3] - q0[1]) * j / n];\n    if (!icinde(q, k) || alt.some(function (u) { return icinde(q, u); })) continue;\n    var d = kenarUzak(q, k); alt.forEach(function (u) { d = Math.min(d, kenarUzak(q, u)); });\n    if (d > skor) { skor = d; en = q; }\n  }\n  return en || merkez(k);\n}\nfunction haritaKur(c, sz) {\n  sz = sz || guncelSezon();\n  var kap = document.getElementById('haritaKap'), W = kap.clientWidth, Hh = kap.clientHeight;\n  var cizili = c.parseller.filter(function (p) { return p.koord.length > 2; });\n  var tum = []; cizili.forEach(function (p) { tum = tum.concat(p.koord); });\n  var lat0 = tum.reduce(function (a, b) { return a + b[1]; }, 0) / tum.length, kx = Math.cos(lat0 * Math.PI / 180);\n  var G = cizili.map(function (p) { var k = p.koord.map(function (x) { return [x[0] * kx, x[1]]; }); return { p: p, i: c.parseller.indexOf(p), k: k, alan: alan(k) }; });\n  var gor = (c.gorseller || []).filter(function (x) { return x.koord && x.koord.length; }).map(function (x) { return { g: x, k: x.koord.map(function (y) { return [y[0] * kx, y[1]]; }) }; });\n  var xs = [], ys = []; G.forEach(function (g) { g.k.forEach(function (n) { xs.push(n[0]); ys.push(n[1]); }); }); gor.forEach(function (g) { g.k.forEach(function (n) { xs.push(n[0]); ys.push(n[1]); }); });\n  var x0 = Math.min.apply(null, xs), x1 = Math.max.apply(null, xs), y0 = Math.min.apply(null, ys), y1 = Math.max.apply(null, ys);\n  var olc = 0.94 * Math.min(W / (x1 - x0), Hh / (y1 - y0)), ox = (W - (x1 - x0) * olc) / 2, oy = (Hh - (y1 - y0) * olc) / 2;\n  function d(p) { return [ox + (p[0] - x0) * olc, Hh - (oy + (p[1] - y0) * olc)]; }\n  function yol(k) { return k.map(function (p) { var q = d(p); return q[0].toFixed(1) + ',' + q[1].toFixed(1); }).join(' '); }\n  G.sort(function (a, b) { return b.alan - a.alan; });\n  var o = '<defs>', govde = '', et = [];\n  G.forEach(function (g, gi) {\n    var p = g.p, veri = ' data-i=\"' + g.i + '\" data-p=\"';\n    o += '<clipPath id=\"k' + gi + '\"><polygon points=\"' + yol(g.k) + '\"/></clipPath>';\n    function alt(i) { var u = p.urunler[i]; return [u && u[1] > 0 ? sayi(u[1]) + ' da' : '', p.cesitler[i] || ''].filter(Boolean).join(' · '); }\n    if (p.bolgeler.length && p.bolgeler.length === p.urunler.length - 1) {\n      var son = p.urunler.length - 1;\n      govde += '<polygon points=\"' + yol(g.k) + '\" fill=\"' + renk(p.urunler[son][0]) + '\" fill-opacity=\".6\"' + veri + son + '\"/>';\n      p.bolgeler.forEach(function (b, i) {\n        var bp = bolgePoligon(g.k, b); if (bp.length < 3) return;\n        govde += '<polygon clip-path=\"url(#k' + gi + ')\" points=\"' + yol(bp) + '\" fill=\"' + renk(p.urunler[i][0]) + '\" fill-opacity=\".75\" stroke=\"#fff\" stroke-width=\"1.5\"' + veri + i + '\"/>';\n        et.push({ n: d(merkez(bp)), satir: [[kisa(p.urunler[i][0]), 0.85, 600]].concat(alt(i) ? [[alt(i), 0.75, 400]] : []), oncelik: g.alan * 0.3 });\n      });\n      et.push({ n: d(yaziNoktasi(g, G)), satir: [[p.ad, 1, 800], [kisa(p.urunler[son][0]), 0.92, 600]].concat(alt(son) ? [[alt(son), 0.8, 400]] : []), oncelik: g.alan });\n    } else if (p.urunler.length > 1) {\n      var cz = C.bekleyen && C.bekleyen.ad === p.ad ? C.bekleyen.cz : mevcutCizgiler(p, g.k);\n      parcala(g.k, cz).forEach(function (pp, i) {\n        if (pp.length < 3) return;\n        govde += '<polygon points=\"' + yol(pp) + '\" fill=\"' + renk(p.urunler[i][0]) + '\" fill-opacity=\".6\" stroke=\"#fff\" stroke-width=\"1.2\"' + veri + i + '\"/>';\n        var ic = yaziNoktasi({ k: pp, alan: alan(pp) }, []);\n        et.push({ n: d(ic), satir: (i === 0 ? [[p.ad, 1, 800]] : []).concat([[kisa(p.urunler[i][0]) + (p.baglar[i] ? ' → ' + p.baglar[i] : ''), 0.92, 600]]).concat(alt(i) ? [[alt(i), 0.8, 400]] : []), oncelik: g.alan * (i === 0 ? 1 : 0.5) });\n      });\n    } else {\n      var r = p.urunler.length ? renk(p.urunler[0][0]) : (p.tip === 'bos' || p.tip === 'girilmedi' ? '#D6D6D6' : '#90A4AE');\n      govde += '<polygon points=\"' + yol(g.k) + '\" fill=\"' + r + '\" fill-opacity=\".6\"' + veri + 'null\"/>';\n      var a0 = alt(0), da = dekar(p);\n      et.push({ n: d(yaziNoktasi(g, G)), satir: [[p.ad, 1, 800], [p.urunler.length ? kisa(p.urunler[0][0]) : (p.tip === 'girilmedi' ? 'Girilmedi' : (p.tip === 'bos' ? 'Boş alan' : '')), 0.92, 600]]\n        .concat(p.urunler.length && (da || p.cesitler[0]) ? [[[da ? sayi(da) + ' da' : '', p.cesitler[0] || ''].filter(Boolean).join(' · '), 0.8, 400]] : []), oncelik: g.alan });\n    }\n    var ck = parselCks(sz, c.ad, p.ad).length;\n    govde += '<polygon points=\"' + yol(g.k) + '\" fill=\"none\" stroke=\"' + (ck ? '#1d4ed8' : 'rgba(0,0,0,.55)') + '\" stroke-width=\"' + (ck ? 3 : 1) + '\" pointer-events=\"none\"/>';\n  });\n  gor.forEach(function (x) {\n    var r = GORSEL_RENK[x.g.tur] || '#EF6C00', cizgi = x.g.tur === 'hat' || x.g.tur === 'og' || x.g.tur === 'pivot';\n    if (cizgi && x.k.length > 1) govde += '<polyline points=\"' + yol(x.k) + '\" fill=\"none\" stroke=\"' + r + '\" stroke-width=\"' + (x.g.tur === 'og' ? 2.2 : 1.4) + '\" pointer-events=\"none\"/>';\n    else { var m = d(x.k[0]); govde += x.g.tur === 'direk' ? '<rect x=\"' + (m[0] - 3) + '\" y=\"' + (m[1] - 3) + '\" width=\"6\" height=\"6\" fill=\"' + r + '\" pointer-events=\"none\"/>'\n      : '<circle cx=\"' + m[0] + '\" cy=\"' + m[1] + '\" r=\"3.5\" fill=\"' + r + '\" stroke=\"#fff\" stroke-width=\"1\" pointer-events=\"none\"/>'; }\n  });\n  var sahne = document.getElementById('sahne');\n  sahne.innerHTML = o + '</defs>' + govde;\n  sahne.querySelectorAll('polygon,polyline,rect,circle').forEach(function (e) { e.setAttribute('vector-effect', 'non-scaling-stroke'); });\n  et.sort(function (a, b) { return b.oncelik - a.oncelik; });\n  var eskiT = H && H.c && H.c.ad === c.ad && H.W === W ? H.T : null;\n  H = { c: c, sz: sz, W: W, Hh: Hh, T: eskiT || { s: 1, x: 0, y: 0 }, et: et, G: G, kx: kx, d: d,\n    ters: function (b) { return [x0 + (b[0] - ox) / olc, y0 + (Hh - b[1] - oy) / olc]; } };\n  uygula();\n  if (!kap.dataset.kuruldu) { dokunmaKur(kap); kap.dataset.kuruldu = '1'; }\n}\nfunction uygula() {\n  var T = H.T; document.getElementById('sahne').setAttribute('transform', 'matrix(' + T.s + ',0,0,' + T.s + ',' + T.x + ',' + T.y + ')');\n  yazilar();\n}\nfunction mevcutCizgiler(p, k) { return p.bolme.length === p.urunler.length - 1 ? p.bolme : otomatikCizgiler(k, p.urunler.map(function (u) { return u[1]; })); }\nfunction ekranaN(b) { return [b[0] * H.T.s + H.T.x, b[1] * H.T.s + H.T.y]; }\nfunction tabanaN(e) { return [(e[0] - H.T.x) / H.T.s, (e[1] - H.T.y) / H.T.s]; }\nfunction duzlemden(e) { return H.ters(tabanaN(e)); }\nfunction duzleme(n) { return ekranaN(H.d(n)); }\nfunction yazilar() {\n  var el = document.getElementById('yazilar'); if (!S.yazi) { el.innerHTML = ''; return; }\n  var T = H.T, fs = H.W > 700 ? 13 : 11.5, dolu = [], o = '';\n  H.et.forEach(function (e) {\n    var x = e.n[0] * T.s + T.x, y = e.n[1] * T.s + T.y;\n    var sat = e.satir.filter(function (s) { return s[0]; }); if (!sat.length) return;\n    var gen = Math.max.apply(null, sat.map(function (s) { return s[0].length * fs * s[1] * 0.56; })) + 6;\n    var yuk = sat.reduce(function (a, s) { return a + fs * s[1] * 1.15; }, 0) + 2;\n    var r = [x - gen / 2, y - yuk / 2, x + gen / 2, y + yuk / 2];\n    if (r[2] < 0 || r[0] > H.W || r[3] < 0 || r[1] > H.Hh) return;\n    if (dolu.some(function (q) { return r[0] < q[2] && r[2] > q[0] && r[1] < q[3] && r[3] > q[1]; })) return;\n    dolu.push(r);\n    var yy = r[1] + 1;\n    o += '<rect x=\"' + r[0].toFixed(1) + '\" y=\"' + r[1].toFixed(1) + '\" width=\"' + gen.toFixed(1) + '\" height=\"' + yuk.toFixed(1) + '\" rx=\"4\" fill=\"rgba(255,255,255,.82)\"/>';\n    o += '<text text-anchor=\"middle\">' + sat.map(function (s) {\n      var h = fs * s[1] * 1.15; yy += h;\n      return '<tspan x=\"' + x.toFixed(1) + '\" y=\"' + (yy - h * 0.25).toFixed(1) + '\" font-size=\"' + (fs * s[1]).toFixed(1) + '\" font-weight=\"' + s[2] + '\" fill=\"' + (s[2] >= 800 ? '#000' : s[2] >= 600 ? '#222' : '#555') + '\">' + esc(s[0]) + '</tspan>';\n    }).join('') + '</text>';\n  });\n  el.innerHTML = o + cizimKatmani();\n}\nfunction sinirla() {\n  var T = H.T; T.s = Math.max(1, Math.min(12, T.s));\n  T.x = Math.min(0, Math.max(H.W - H.W * T.s, T.x)); T.y = Math.min(0, Math.max(H.Hh - H.Hh * T.s, T.y));\n}\nfunction yakinlasNokta(f, px, py) { var T = H.T, s2 = Math.max(1, Math.min(12, T.s * f)); f = s2 / T.s; T.x = px - (px - T.x) * f; T.y = py - (py - T.y) * f; T.s = s2; sinirla(); uygula(); }\nfunction sifirla() { H.T = { s: 1, x: 0, y: 0 }; uygula(); }\nfunction tamEkran() {\n  S.tam = !S.tam; document.body.style.overflow = S.tam ? 'hidden' : '';\n  document.getElementById('haritaKap').classList.toggle('tam', S.tam);\n  var c = H.c; H = null; haritaKur(c);\n}\n// ---------- çizim araçları (uygulamadaki kalem: çizgi, kare, daire, nokta, sınır düzenle, yeni parsel) ----------\nvar C = { acik: false, mod: 'cizgi', bas: null, son: null, noktalar: [], duzenP: null, duzen: [], secKose: null, surukle: null, yenidenCiz: false, bekleyen: null, kaydediliyor: false };\nfunction js(x) { return esc(JSON.stringify(x)); }\nfunction cizimAcKapa() { C.acik = !C.acik; cizimSifirla(); C.bekleyen = null; ciz(); }\nfunction cizimSifirla() { C.bas = C.son = null; C.noktalar = []; C.duzenP = null; C.duzen = []; C.secKose = null; C.surukle = null; C.yenidenCiz = false; }\nfunction modSec(m) { C.mod = m; C.bekleyen = null; cizimSifirla(); yenidenKur(); }\nfunction yenidenKur() { if (!H) return; var c = H.c, sz = H.sz, T = H.T; haritaKur(c, sz); H.T = T; uygula(); cizimPaneli(); }\nvar MODLAR = [['cizgi', 'Çizgi'], ['kare', 'Kare'], ['daire', 'Daire'], ['nokta', 'Nokta'], ['sinir', 'Sınır düzenle'], ['yeni', 'Yeni parsel']];\nfunction cizimPaneli() {\n  var el = document.getElementById('cizimPanel'); if (!el) return;\n  el.style.display = C.acik ? 'block' : 'none'; if (!C.acik) return;\n  var h = '';\n  if (C.bekleyen) {\n    h = '<b>' + esc(C.bekleyen.ad) + '</b>: ' + esc(C.bekleyen.urunler) + '<div class=\"kucukDugmeler\"><button onclick=\"renkleriCevir()\">⇄ Renkleri çevir</button>' +\n      '<button onclick=\"C.bekleyen=null;yenidenKur()\">Vazgeç</button><button class=\"ana\" onclick=\"cizgiKaydet()\"' + (C.kaydediliyor ? ' disabled' : '') + '>✓ Kaydet</button></div>';\n    el.innerHTML = h; return;\n  }\n  h = '<div class=\"cipler\" style=\"flex-wrap:wrap;padding:0 0 6px\">' + MODLAR.map(function (m) { return '<span class=\"cip' + (C.mod === m[0] ? ' secili' : '') + '\" onclick=\"modSec(\\'' + m[0] + '\\')\">' + m[1] + '</span>'; }).join('') + '</div>';\n  var alan = C.duzen.length > 2 ? ' Çizilen alan ≈ ' + sayi(dekarAlan(C.duzen)) + ' da.' : '';\n  if (C.mod === 'cizgi') h += 'Ayırmak istediğiniz parselin üzerinden parmağınızla bir çizgi çekin. İki renkli parselde çizgi yer değiştirir; tek ürünlü parselde parsel iki parçaya bölünür.';\n  else if (C.mod === 'kare') h += 'Parselin içinde bir köşeden karşı köşeye parmağınızı sürükleyin; dikdörtgen bölge olur.';\n  else if (C.mod === 'daire') h += 'Bölgenin ortasına basıp dışa doğru sürükleyin; daire bölge olur.';\n  else if (C.mod === 'nokta') h += 'Bölgenin köşelerine sırayla dokunun (en az 3 nokta), sonra \"Bölgeyi kapat\".<div class=\"kucukDugmeler\"><button onclick=\"C.noktalar.pop();uygula();cizimPaneli()\"' + (C.noktalar.length ? '' : ' disabled') + '>↶ Son noktayı sil</button>' +\n    '<button class=\"ana\" onclick=\"sekilBitir()\"' + (C.noktalar.length < 3 ? ' disabled' : '') + '>✓ Bölgeyi kapat (' + C.noktalar.length + ')</button></div>';\n  else if (C.mod === 'sinir' && !C.duzenP) h += 'Sınırını değiştirmek istediğiniz parsele dokunun. İki parmakla yakınlaştırıp kaydırabilirsiniz.';\n  else if (C.mod === 'sinir' || C.mod === 'yeni') {\n    h += C.mod === 'yeni' ? 'Yeni parselin köşelerine sırayla dokunun (en az 3 nokta).' + alan :\n      C.yenidenCiz ? esc(C.duzenP) + ': yeni sınırın köşelerine sırayla dokunun (en az 3 nokta).' + alan :\n      esc(C.duzenP) + ': köşeleri sürükleyin; kenar ortasındaki küçük noktayı sürükleyerek köşe ekleyin; köşeye dokunup seçerek silin.' + alan;\n    h += '<div class=\"kucukDugmeler\">';\n    if (C.mod === 'yeni' || C.yenidenCiz) h += '<button onclick=\"C.duzen.pop();uygula();cizimPaneli()\"' + (C.duzen.length ? '' : ' disabled') + '>↶ Son noktayı sil</button>';\n    else h += '<button onclick=\"koseSil()\"' + (C.secKose == null || C.duzen.length <= 3 ? ' disabled' : '') + '>Seçili köşeyi sil</button><button onclick=\"C.duzen=[];C.yenidenCiz=true;C.secKose=null;uygula();cizimPaneli()\">Baştan çiz</button>';\n    if (C.mod === 'sinir' && degisenSinir(H.c.ad, C.duzenP)) h += '<button onclick=\"sinirGeriAl()\">Değişikliği geri al</button>';\n    if (C.mod === 'sinir') h += '<button onclick=\"cizimSifirla();uygula();cizimPaneli()\">Vazgeç</button>';\n    h += '<button class=\"ana\" onclick=\"sinirKaydet()\"' + (C.duzen.length < 3 || C.kaydediliyor ? ' disabled' : '') + '>✓ ' + (C.mod === 'yeni' ? 'Parseli kaydet' : 'Sınırı kaydet') + '</button></div>';\n  }\n  el.innerHTML = h;\n}\nfunction koseSil() { if (C.secKose == null) return; C.duzen.splice(C.secKose, 1); C.secKose = null; uygula(); cizimPaneli(); }\nfunction dekarAlan(k) { return k.length < 3 ? 0 : alan(k) * 111320 * 111320 / 1000; }\nfunction ortaNoktalar(e) { var l = []; for (var i = 0; i < e.length; i++) { var a = e[i], b = e[(i + 1) % e.length]; if (Math.hypot(a[0] - b[0], a[1] - b[1]) > 44) l.push([i, [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2]]); } return l; }\nfunction cizimKatmani() {\n  if (!C.acik || !H) return '';\n  var o = '', kalem = 'stroke=\"#e11d48\" stroke-width=\"3\" fill=\"none\" stroke-linecap=\"round\"';\n  if (C.bas && C.son) {\n    var a = C.bas, b = C.son;\n    if (C.mod === 'kare') o += '<rect x=\"' + Math.min(a[0], b[0]) + '\" y=\"' + Math.min(a[1], b[1]) + '\" width=\"' + Math.abs(b[0] - a[0]) + '\" height=\"' + Math.abs(b[1] - a[1]) + '\" ' + kalem + '/>';\n    else if (C.mod === 'daire') o += '<circle cx=\"' + a[0] + '\" cy=\"' + a[1] + '\" r=\"' + Math.hypot(b[0] - a[0], b[1] - a[1]) + '\" ' + kalem + '/>';\n    else o += '<line x1=\"' + a[0] + '\" y1=\"' + a[1] + '\" x2=\"' + b[0] + '\" y2=\"' + b[1] + '\" ' + kalem + '/>';\n  }\n  if (C.mod === 'nokta' && C.noktalar.length) {\n    var e = C.noktalar.map(duzleme);\n    o += '<polyline points=\"' + e.concat(e.length > 2 ? [e[0]] : []).map(function (x) { return x.join(','); }).join(' ') + '\" ' + kalem + '/>';\n    e.forEach(function (x) { o += '<circle cx=\"' + x[0] + '\" cy=\"' + x[1] + '\" r=\"5\" fill=\"#e11d48\"/>'; });\n  }\n  if ((C.mod === 'sinir' || C.mod === 'yeni') && C.duzen.length) {\n    var d = C.duzen.map(duzleme), kapali = C.mod === 'sinir' && !C.yenidenCiz;\n    o += '<polygon points=\"' + d.map(function (x) { return x.join(','); }).join(' ') + '\" fill=\"rgba(255,152,0,.25)\" stroke=\"#e65100\" stroke-width=\"2.5\"' + (d.length > 2 ? '' : ' fill-opacity=\"0\"') + '/>';\n    if (kapali) ortaNoktalar(d).forEach(function (m) { o += '<circle cx=\"' + m[1][0] + '\" cy=\"' + m[1][1] + '\" r=\"5\" fill=\"#fff\" stroke=\"#e65100\" stroke-width=\"1.5\"/>'; });\n    d.forEach(function (x, i) { var r = i === C.secKose ? 9 : 7; o += '<circle cx=\"' + x[0] + '\" cy=\"' + x[1] + '\" r=\"' + r + '\" fill=\"' + (i === C.secKose ? '#e11d48' : '#fff') + '\" stroke=\"#e65100\" stroke-width=\"2\"/>'; });\n  }\n  return o;\n}\nfunction parselBul(e) {\n  // Dokunulan noktadaki en küçük parsel ve parça\n  var hedef = document.elementsFromPoint(e[0] + document.getElementById('haritaKap').getBoundingClientRect().left, e[1] + document.getElementById('haritaKap').getBoundingClientRect().top)\n    .filter(function (x) { return x.dataset && x.dataset.i != null; })[0];\n  return hedef ? { i: +hedef.dataset.i, p: hedef.dataset.p === 'null' ? null : +hedef.dataset.p } : null;\n}\nfunction gOf(ad) { return H.G.filter(function (g) { return g.p.ad === ad; })[0]; }\nfunction koseYakala(e) {\n  if (C.mod !== 'sinir' || !C.duzenP || C.yenidenCiz || !C.duzen.length) return false;\n  var d = C.duzen.map(duzleme), en = null, enU = 24;\n  d.forEach(function (x, i) { var u = Math.hypot(x[0] - e[0], x[1] - e[1]); if (u < enU) { enU = u; en = i; } });\n  if (en != null) { C.surukle = en; return true; }\n  var o = ortaNoktalar(d);\n  for (var j = 0; j < o.length; j++) if (Math.hypot(o[j][1][0] - e[0], o[j][1][1] - e[1]) < 20) { C.duzen.splice(o[j][0] + 1, 0, duzlemden(o[j][1])); C.surukle = o[j][0] + 1; return true; }\n  return false;\n}\nfunction dokunmaKur(kap) {\n  var p = {}, bas = null, iki = null, sonDokunus = 0, cizer = false;\n  function yerel(e) { var r = kap.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; }\n  function cizmeModu() { return C.acik && !C.bekleyen && (C.mod === 'cizgi' || C.mod === 'kare' || C.mod === 'daire'); }\n  kap.addEventListener('pointerdown', function (e) {\n    if (e.target.closest('.araclar') || e.target.closest('.solust') || e.target.closest('#cizimPanel')) return;\n    kap.setPointerCapture(e.pointerId); p[e.pointerId] = yerel(e);\n    var l = Object.keys(p);\n    if (l.length === 1) {\n      bas = { n: p[e.pointerId], t: Date.now(), T: { s: H.T.s, x: H.T.x, y: H.T.y }, kaydi: false };\n      cizer = false;\n      if (C.acik && koseYakala(bas.n)) { cizer = 'kose'; bas.kaydi = true; }\n      else if (cizmeModu()) { cizer = 'sekil'; C.bas = C.son = bas.n; }\n    }\n    if (l.length === 2) {\n      if (cizer === 'sekil') { C.bas = C.son = null; yazilar(); }\n      cizer = false;\n      var a = p[l[0]], b = p[l[1]]; iki = { d: Math.hypot(a[0] - b[0], a[1] - b[1]), m: [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2], T: { s: H.T.s, x: H.T.x, y: H.T.y } }; if (bas) bas.kaydi = true;\n    }\n  });\n  kap.addEventListener('pointermove', function (e) {\n    if (!p[e.pointerId]) return; p[e.pointerId] = yerel(e);\n    var l = Object.keys(p);\n    if (l.length >= 2 && iki) {\n      var a = p[l[0]], b = p[l[1]], dd = Math.hypot(a[0] - b[0], a[1] - b[1]), m = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2];\n      var s2 = Math.max(1, Math.min(12, iki.T.s * dd / iki.d)), f = s2 / iki.T.s;\n      H.T = { s: s2, x: m[0] - (iki.m[0] - iki.T.x) * f, y: m[1] - (iki.m[1] - iki.T.y) * f }; sinirla(); uygula();\n    } else if (l.length === 1 && bas) {\n      var n = p[l[0]];\n      if (cizer === 'sekil') { C.son = n; yazilar(); return; }\n      if (cizer === 'kose') { if (C.surukle != null) { C.duzen[C.surukle] = duzlemden(n); yazilar(); } return; }\n      var dx = n[0] - bas.n[0], dy = n[1] - bas.n[1];\n      if (Math.hypot(dx, dy) > 6) bas.kaydi = true;\n      if (bas.kaydi) { H.T = { s: bas.T.s, x: bas.T.x + dx, y: bas.T.y + dy }; sinirla(); uygula(); }\n    }\n  });\n  function birak(e) {\n    if (!p[e.pointerId]) return;\n    var n = p[e.pointerId]; delete p[e.pointerId];\n    var l = Object.keys(p);\n    if (l.length === 1) { bas = { n: p[l[0]], t: Date.now(), T: { s: H.T.s, x: H.T.x, y: H.T.y }, kaydi: true }; iki = null; cizer = false; return; }\n    if (l.length) return;\n    if (cizer === 'sekil') { cizer = false; var a0 = C.bas, b0 = C.son; C.bas = C.son = null; yazilar(); if (a0 && b0 && Math.hypot(a0[0] - b0[0], a0[1] - b0[1]) >= 12) (C.mod === 'cizgi' ? cizgiBitir : sekilBitir)(a0, b0); bas = null; return; }\n    if (cizer === 'kose') { cizer = false; var tik = Math.hypot(n[0] - bas.n[0], n[1] - bas.n[1]) < 6; C.secKose = C.surukle; C.surukle = null; uygula(); cizimPaneli(); bas = null; return; }\n    if (bas && !bas.kaydi && Date.now() - bas.t < 600 && e.type === 'pointerup') {\n      var simdi = Date.now();\n      if (C.acik && (C.mod === 'nokta' || C.mod === 'yeni' || (C.mod === 'sinir' && (C.yenidenCiz || !C.duzenP)))) { dokunusCizim(n); bas = null; return; }\n      if (simdi - sonDokunus < 300) { sonDokunus = 0; clearTimeout(dokunmaKur.z); yakinlasNokta(2, n[0], n[1]); }\n      else {\n        sonDokunus = simdi; clearTimeout(dokunmaKur.z);\n        dokunmaKur.z = setTimeout(function () { if (C.acik && C.mod !== 'cizgi') return; var x = parselBul(n); if (x) parselAc(x.i, x.p); }, 280);\n      }\n    }\n    bas = null; iki = null;\n  }\n  kap.addEventListener('pointerup', birak); kap.addEventListener('pointercancel', birak);\n  kap.addEventListener('wheel', function (e) { e.preventDefault(); var n = yerel(e); yakinlasNokta(e.deltaY < 0 ? 1.2 : 1 / 1.2, n[0], n[1]); }, { passive: false });\n}\nfunction dokusCizimYok() {}\nfunction dokunusCizim(n) {\n  if (C.mod === 'nokta') C.noktalar.push(duzlemden(n));\n  else if (C.mod === 'yeni' || C.yenidenCiz) C.duzen.push(duzlemden(n));\n  else if (C.mod === 'sinir') { var x = parselBul(n); if (x) { var g = gOf(H.c.parseller[x.i].ad); if (g) { C.duzenP = g.p.ad; C.duzen = g.k.map(function (q) { return q.slice(); }); C.secKose = null; } } }\n  uygula(); cizimPaneli();\n}\n// --- çizgi: bölünmüş parselde çizgi yer değiştirir; tek ürünlü parselde iki parçaya böler\nfunction cizgiAl(k, p, q) {\n  var aci = Math.atan2(q[1] - p[1], q[0] - p[0]) * 180 / Math.PI, r = aci * Math.PI / 180, nx = -Math.sin(r), ny = Math.cos(r), mn = Infinity, mx = -Infinity;\n  k.forEach(function (x) { var v = nx * x[0] + ny * x[1]; mn = Math.min(mn, v); mx = Math.max(mx, v); });\n  var m = [(p[0] + q[0]) / 2, (p[1] + q[1]) / 2];\n  return [aci, Math.max(1, Math.min(99, (nx * m[0] + ny * m[1] - mn) / (mx - mn) * 100))];\n}\nfunction cizgiBitir(a, b) {\n  var p = duzlemden(a), q = duzlemden(b);\n  function say(k) { var n = 0; for (var i = 0; i <= 20; i++) { var f = i / 20; if (icinde([p[0] + (q[0] - p[0]) * f, p[1] + (q[1] - p[1]) * f], k)) n++; } return n; }\n  var hedef = null, enCok = 0;\n  H.G.forEach(function (g) { if (g.p.urunler.length > 1 && !(g.p.bolgeler.length && g.p.bolgeler.length === g.p.urunler.length - 1)) { var n = say(g.k); if (n > enCok) { enCok = n; hedef = g; } } });\n  if (!hedef) {\n    var duz = null, enIc = 0;\n    H.G.slice().reverse().forEach(function (g) { if (g.p.tip === 'diger') return; var n = say(g.k); if (n > enIc) { enIc = n; duz = g; } });\n    if (!duz) return durum('Çizgiyi bir parselin üzerinden, ayırmak istediğiniz yere çekin.');\n    var cz = cizgiAl(duz.k, p, q), yan = kirp(duz.k, cizgiDenklemi(duz.k, cz), true), oran = yan.length < 3 ? 0.5 : alan(yan) / alan(duz.k);\n    return cizgiIleBol(duz.p, cz, oran);\n  }\n  var k = hedef.k, yeni = cizgiAl(k, p, q), l = (C.bekleyen && C.bekleyen.ad === hedef.p.ad ? C.bekleyen.cz : mevcutCizgiler(hedef.p, k)).slice();\n  if (l.length <= 1) l = [yeni];\n  else { var m = [(p[0] + q[0]) / 2, (p[1] + q[1]) / 2], en = 0, enU = Infinity;\n    l.forEach(function (c, i) { var d = cizgiDenklemi(k, c), u = Math.abs(d[0] * m[0] + d[1] * m[1] - d[2]); if (u < enU) { enU = u; en = i; } }); l[en] = yeni; }\n  if (l.length === 1) {\n    var eski = parcala(k, mevcutCizgiler(hedef.p, k))[0];\n    if (eski && eski.length > 2) { var o = merkez(eski), d0 = cizgiDenklemi(k, l[0]); if (d0[0] * o[0] + d0[1] * o[1] - d0[2] > 0) l = [[(l[0][0] + 180) % 360, 100 - l[0][1]]]; }\n  }\n  C.bekleyen = { ad: hedef.p.ad, cz: l, urunler: hedef.p.urunler.map(function (u) { return u[0]; }).join(' / ') };\n  yenidenKur();\n}\nfunction renkleriCevir() { C.bekleyen.cz = C.bekleyen.cz.slice().reverse().map(function (c) { return [(c[0] + 180) % 360, 100 - c[1]]; }); yenidenKur(); }\nfunction cizgiKaydet() {\n  var b = C.bekleyen, p = H.c.parseller.filter(function (x) { return x.ad === b.ad; })[0];\n  var l = p.urunler.map(function (u) { return [u[0], u[1]]; });\n  var metin = bolunmusMetin(l, b.cz, p.baglar, p.cesitler, []);\n  var top = p.beyan != null ? p.beyan : l.reduce(function (a, x) { return a + x[1]; }, 0);\n  kayit([girisOp(H.sz.sezon, H.c.ad, p.ad, metin, top)], function () { C.bekleyen = null; });\n}\nfunction cizgiIleBol(p, cz, oran) {\n  var top = p.beyan || p.urunler.reduce(function (a, u) { return a + (u[1] || 0); }, 0), ilk = p.urunler.length ? urunAnahtari(p.urunler[0][0]) : 'Arpa';\n  function yuv(v) { return top > 0 ? Math.round(v * 10) / 10 : ''; }\n  parcaFormu(p, H.sz.sezon, '(çizgiyle)', [[URUNLER.indexOf(ilk) >= 0 ? ilk : 'Arpa', yuv(top * oran)], ['Buğday', yuv(top * (1 - oran))]], { cizgiler: [cz], sabit: 2 });\n}\n// --- şekil: dikdörtgen / daire / noktalar → bölge\nfunction sekilBitir(a, b) {\n  var duz, kod, tip;\n  if (C.mod === 'nokta') { if (C.noktalar.length < 3) return; duz = C.noktalar.slice(); kod = duz; tip = 'P'; }\n  else {\n    var p = duzlemden(a), q = duzlemden(b); kod = [p, q];\n    if (C.mod === 'kare') { duz = [[p[0], p[1]], [q[0], p[1]], [q[0], q[1]], [p[0], q[1]]]; tip = 'D'; }\n    else { var r = Math.hypot(q[0] - p[0], q[1] - p[1]); duz = []; for (var i = 0; i < 48; i++) duz.push([p[0] + r * Math.cos(i * Math.PI / 24), p[1] + r * Math.sin(i * Math.PI / 24)]); tip = 'C'; }\n  }\n  var o = tip === 'C' ? kod[0] : merkez(duz), hedef = null;\n  H.G.slice().reverse().forEach(function (g) { if (!hedef && g.p.tip !== 'diger' && icinde(o, g.k)) hedef = g; });\n  if (!hedef) return durum('Şekli bir parselin içine çizin (ortası parselin içinde kalmalı).');\n  var q0 = kutu(hedef.k), w = q0[2] - q0[0], hh = q0[3] - q0[1];\n  function px(x) { return (x - q0[0]) / w * 100; } function py(y) { return (y - q0[1]) / hh * 100; }\n  var bolge = tip === 'C' ? ['C', [px(kod[0][0]), py(kod[0][1]), Math.hypot(kod[1][0] - kod[0][0], kod[1][1] - kod[0][1]) / w * 100, Math.hypot(kod[1][0] - kod[0][0], kod[1][1] - kod[0][1]) / hh * 100]]\n    : tip === 'D' ? ['D', [px(Math.min(kod[0][0], kod[1][0])), py(Math.min(kod[0][1], kod[1][1])), px(Math.max(kod[0][0], kod[1][0])), py(Math.max(kod[0][1], kod[1][1]))]]\n    : ['P', [].concat.apply([], kod.map(function (n) { return [px(n[0]), py(n[1])]; }))];\n  var pay = bolgePaylari(hedef.k, [bolgePoligon(hedef.k, bolge)])[0];\n  C.noktalar = []; uygula(); cizimPaneli();\n  bolgeFormu(hedef.p, bolge, pay);\n}\nfunction bolgePaylari(k, bolgeler) {\n  var q = kutu(k), say = bolgeler.map(function () { return 0; }).concat([0]), top = 0, n = 70;\n  for (var i = 0; i < n; i++) for (var j = 0; j < n; j++) {\n    var p = [q[0] + (i + 0.5) / n * (q[2] - q[0]), q[1] + (j + 0.5) / n * (q[3] - q[1])];\n    if (!icinde(p, k)) continue; top++;\n    var h = bolgeler.length; for (var b = 0; b < bolgeler.length; b++) if (bolgeler[b].length > 2 && icinde(p, bolgeler[b])) { h = b; break; }\n    say[h]++;\n  }\n  return say.map(function (x) { return top ? x / top : 0; });\n}\n// --- sınır\nfunction degisenSinir(cf, ad) {\n  var m = {}; S.parselSinir.forEach(function (r) { var k = r[0] + '|' + r[1]; if (r[4] === 'Aktif') m[k] = 1; else if (r[4] === 'Geri alındı') delete m[k]; });\n  return !!m[cf + '|' + ad];\n}\nfunction sinirKaydet() {\n  var k = C.duzen.map(function (c) { return [c[0] / H.kx, c[1]]; }), da = dekarAlan(C.duzen);\n  var koord = k.map(function (c) { return c[0].toFixed(6) + ',' + c[1].toFixed(6); }).join(' ');\n  if (C.mod === 'yeni') {\n    var cizilmemis = H.c.parseller.filter(function (x) { return x.koord.length <= 2; }).map(function (x) { return x.ad; });\n    sayfaAc('<h2>Yeni parsel</h2><p style=\"font-size:13px\">Çizilen alan yaklaşık ' + sayi(da) + ' da. Sınır tüm sezonların haritasında kullanılır.</p>' +\n      (cizilmemis.length ? '<div style=\"font-size:12.5px;color:var(--soluk)\">Haritada sınırı olmayan parseller:</div><div class=\"cipler\" style=\"flex-wrap:wrap\">' +\n        cizilmemis.map(function (x) { return '<span class=\"cip\" onclick=\"document.getElementById(\\'yad\\').value=' + js(x) + '\">' + esc(x) + '</span>'; }).join('') + '</div>' : '') +\n      '<label>Parsel adı</label><input id=\"yad\" maxlength=\"80\" placeholder=\"Ör. 12. parsel\"><div class=\"dugmeler\"><button class=\"ana\" onclick=\"yeniParselKaydet(' + js(koord) + ')\">Kaydet</button><button class=\"ikinci\" onclick=\"kapat()\">Vazgeç</button></div>');\n    return;\n  }\n  sayfaAc('<h2>' + esc(C.duzenP) + ' sınırı</h2><p style=\"font-size:13px\">Yeni sınır tüm sezonların haritasında kullanılacak. Çizilen alan yaklaşık ' + sayi(da) + ' da (beyan edilen dekar değişmez; gerekirse parselden ayrıca düzeltin).</p>' +\n    '<div class=\"dugmeler\"><button class=\"ana\" onclick=\"kayit([{tur:\\'parselSinir\\',ciftlik:' + js(H.c.ad) + ',parsel:' + js(C.duzenP) + ',koord:' + js(koord) + '}],function(){cizimSifirla();})\">Kaydet</button><button class=\"ikinci\" onclick=\"kapat()\">Vazgeç</button></div>');\n}\nfunction yeniParselKaydet(koord) {\n  var ad = document.getElementById('yad').value.trim();\n  if (!ad) return durum('Parsel adı girin.');\n  if (H.c.parseller.some(function (x) { return x.ad === ad && x.koord.length > 2; })) return durum('Bu adla çizili bir parsel var.');\n  kayit([{ tur: 'parselSinir', ciftlik: H.c.ad, parsel: ad, koord: koord }], function () { C.duzen = []; });\n}\nfunction sinirGeriAl() { kayit([{ tur: 'parselSinirGeriAl', ciftlik: H.c.ad, parsel: C.duzenP }], function () { cizimSifirla(); }); }\nwindow.addEventListener('resize', function () { if (H && H.c && document.getElementById('haritaKap')) { var c = H.c; H = null; haritaKur(c); } });\nfunction sezonSec(s) { S.sezon = s; ciz(); }\nfunction ciftlikSec(c) { S.ciftlik = c; ciz(); }\n\n// ---------- parsel işlemleri (uygulamadaki parsel sayfası) ----------\nvar ACIK = null;\nfunction hedefSezon(s) { return s.giris ? s.sezon : sonrakiSezon(s.sezon); }\nfunction girisOp(sezon, cf, parsel, urun, alanDa) { return { tur: 'sezonParsel', sezon: sezon, ciftlik: cf, parsel: parsel, urun: urun, alan: alanDa == null || alanDa === '' ? '' : String(alanDa).replace('.', ',') }; }\nfunction geriOp(sezon, cf, parsel) { return { tur: 'sezonParselGeriAl', sezon: sezon, ciftlik: cf, parsel: parsel }; }\nfunction secenekler(sec) {\n  var k = sec ? urunAnahtari(sec) : '', varMi = URUNLER.indexOf(k) >= 0;\n  return (sec ? '' : '<option value=\"\">— seçin —</option>') + URUNLER.map(function (u) { return '<option' + (u === k ? ' selected' : '') + '>' + esc(u) + '</option>'; }).join('') +\n    '<option value=\"__diger\"' + (!varMi && sec ? ' selected' : '') + '>Diğer…</option>';\n}\nfunction urunAlani(id, u) {\n  var diger = u && URUNLER.indexOf(urunAnahtari(u)) < 0;\n  return '<select id=\"' + id + '\" onchange=\"document.getElementById(\\'' + id + 'd\\').style.display=this.value===\\'__diger\\'?\\'block\\':\\'none\\'\">' + secenekler(u) + '</select>' +\n    '<input id=\"' + id + 'd\" placeholder=\"Ürün adı\" style=\"margin-top:6px;display:' + (diger ? 'block' : 'none') + '\" value=\"' + esc(diger ? u : '') + '\">';\n}\nfunction urunOku(id) {\n  var u = document.getElementById(id).value; if (u === '__diger') u = document.getElementById(id + 'd').value.trim();\n  if (!u) { durum('Ürün seçin.'); return null; }\n  if (u.length > 40 || /[:+>@#\\/;]/.test(u)) { durum('Ürün adında : + > @ # / ; işaretleri kullanılamaz.'); return null; }\n  return u;\n}\nfunction metinOku(id) { var t = (document.getElementById(id).value || '').trim(); if (/[:+>@#\\/;]/.test(t)) { durum('Tohum adında : + > @ # / ; işaretleri kullanılamaz.'); return false; } return t || null; }\nfunction parselAc(i, parca) {\n  var s = guncelSezon(), c = s.ciftlikler.filter(function (x) { return x.ad === S.ciftlik; })[0], p = c.parseller[i];\n  var hedef = hedefSezon(s), g = parselGirisi(hedef, c.ad, p.ad), ic = g ? icerikOku(g.urun) : null;\n  ACIK = { s: s, c: c, p: p, i: i, hedef: hedef, g: g, ic: ic };\n  var l = sezonlar(), si = l.map(function (x) { return x.sezon; }).indexOf(hedef), once = si > 0 ? l[si - 1] : null;\n  var oc = once && once.ciftlikler.filter(function (x) { return x.ad === c.ad; })[0], op = oc && oc.parseller.filter(function (x) { return x.ad === p.ad; })[0];\n  var onceU = op ? op.urunler.map(function (u) { return urunAnahtari(u[0]); }) : [];\n  var bagli = c.parseller.filter(function (x) { var h = x.ad !== p.ad && parselGirisi(hedef, c.ad, x.ad); return h && icerikOku(h.urun).birlesik === p.ad; }).map(function (x) { return x.ad; });\n  ACIK.bagli = bagli;\n  var h = '<h2>' + esc(c.ad) + ' · ' + esc(p.ad) + '</h2>';\n  if (once) h += '<div style=\"color:var(--soluk);font-size:13px\">' + esc(once.sezon) + ': ' + esc(onceU.length ? onceU.join(' + ') : 'ürün yok') + '</div>';\n  h += '<div style=\"font-weight:700;margin:4px 0\">' + esc(hedef) + ': ' + esc(g ? girisYazi(g, ic, bagli) : (p.urunler.length && hedef === s.sezon ? urunYazi(p) + ' (KMZ)' : 'girilmedi')) + '</div>';\n  if (p.not) h += '<div class=\"uyari\">' + esc(p.not) + '</div>';\n  var ayni = ic && ic.parcalar.some(function (x) { var k = urunAnahtari(x[0]); return onceU.indexOf(k) >= 0 && ['Yonca', 'Korunga', 'Çayır'].indexOf(k) < 0 && ['Nadas', 'Deneme alanı', 'Islah edilen alan', 'Ağaçlık alan', 'Boş alan'].indexOf(k) < 0; });\n  if (ayni) h += '<div class=\"uyari\">Münavebe uyarısı: aynı ürün bu parselde üst üste ekiliyor.</div>';\n  var cks = parselCks(s, c.ad, p.ad); if (cks.length) h += cks.map(function (x) { return '<span class=\"rozet\">ÇKS: ' + esc(x.urun) + ' ' + (x.alan == null ? '' : sayi(x.alan) + ' da') + '</span>'; }).join('');\n  if (S.yetki !== 'duzenle' || p.tip === 'diger') {\n    h += '<p style=\"color:var(--soluk);font-size:13px\">' + (p.tip === 'diger' ? 'Ekim alanı değil, ürün girilemez.' : 'Yalnızca görüntüleme yetkiniz var.') + '</p><div class=\"dugmeler\"><button class=\"ikinci\" onclick=\"kapat()\">Kapat</button></div>';\n    return sayfaAc(h);\n  }\n  if (ic && ic.birlesik) {\n    h += '<p style=\"font-size:13px\">Bu parsel ' + esc(ic.birlesik) + ' ile birleştirilmiş; alan ana parselde sayılır.</p><div class=\"dugmeler\"><button class=\"ana\" onclick=\"kayit([geriOp(ACIK.hedef,ACIK.c.ad,ACIK.p.ad)])\">Birleşimden ayır</button><button class=\"ikinci\" onclick=\"kapat()\">Kapat</button></div>';\n    return sayfaAc(h);\n  }\n  // Ürün / dekar / tohum (bölünmüş parselde her parça)\n  var parcalar = ic ? ic.parcalar.map(function (x) { return [x[0], x[1]]; }) : (p.urunler.length && hedef === s.sezon ? p.urunler.map(function (u) { return [u[0], u[1]]; }) : [[onceU.length === 1 ? onceU[0] : '', null]]);\n  var cesit = ic ? ic.cesitler : (hedef === s.sezon ? p.cesitler : []), baglar = ic ? ic.baglar : [];\n  if (!ic && parcalar.length === 1 && hedef === s.sezon && p.beyan) parcalar[0][1] = p.beyan;\n  if (ic && !ic.birlesik && parcalar.length === 1 && g.alan != null) parcalar[0][1] = g.alan;\n  ACIK.parcaSayisi = parcalar.length;\n  ACIK.taban = { cizgiler: ic ? ic.cizgiler : (hedef === s.sezon ? p.bolme : []), bolgeler: ic ? ic.bolgeler : (hedef === s.sezon ? p.bolgeler : []) };\n  var adaylar = c.parseller.filter(function (x) { return x.ad !== p.ad && x.tip !== 'diger'; }).map(function (x) { return x.ad; });\n  if (parcalar.length > 1) h += '<p style=\"font-size:12.5px;color:var(--soluk);margin:8px 0 0\">Parçalar: ürün, dekar, tohum ve (isterseniz) bağlandığı parsel.</p>';\n  parcalar.forEach(function (u, j) {\n    h += '<div class=\"parca\"' + (parca === j && parcalar.length > 1 ? ' style=\"border:2px solid #14532d\"' : '') + '>' + (parcalar.length > 1 ? '<b><i style=\"display:inline-block;width:12px;height:12px;border-radius:3px;background:' + renk(u[0] || '') + ';margin-right:6px\"></i>' + (j + 1) + '. parça</b>' : '') +\n      '<label>Ürün / alan türü</label>' + urunAlani('u' + j, u[0]) +\n      '<div class=\"satir\"><div><label>Dekar</label><input id=\"d' + j + '\" inputmode=\"decimal\" value=\"' + (u[1] == null ? '' : u[1]) + '\"></div>' +\n      '<div><label>Tohum / çeşit</label><input id=\"t' + j + '\" value=\"' + esc(cesit[j] || '') + '\"></div></div>' +\n      (parcalar.length > 1 ? '<label>Bağlandığı parsel</label><select id=\"b' + j + '\"><option value=\"\">— bağlı değil —</option>' + adaylar.map(function (a) { return '<option' + (baglar[j] === a ? ' selected' : '') + '>' + esc(a) + '</option>'; }).join('') + '</select>' : '') + '</div>';\n  });\n  h += '<div class=\"dugmeler\"><button class=\"ana\" onclick=\"parselKaydet()\">Kaydet</button></div>';\n  h += '<div class=\"kucukDugmeler\"><button onclick=\"parcaFormu(ACIK.p,ACIK.hedef,\\'\\',null,{})\">✂ Parçalara böl</button><button onclick=\"birlestirFormu()\">⧉ Birleştir</button>' +\n    (g ? '<button onclick=\"girisGeriAl()\">↶ ' + (bagli.length ? 'Girişi ve birleştirmeyi geri al' : 'Girişi geri al') + '</button>' : '') + '<button onclick=\"kapat()\">Kapat</button></div>';\n  if (parcalar.length > 1) h += '<p style=\"font-size:12px;color:var(--soluk)\">Renk ayrımı için haritanın sol üstündeki kalem düğmesine basıp parselin üzerinden çizgi çekin.</p>';\n  h += '<p style=\"font-size:11.5px;color:var(--soluk)\">Kayıt ' + esc(hedef) + ' sezonu verilerine eklenir (Sezon_Parselleri). Kaynak Excel dosyaları değişmez.</p>';\n  sayfaAc(h);\n}\nfunction girisYazi(g, ic, bagli) {\n  if (ic.birlesik) return ic.parcalar[0][0] + ' · ' + ic.birlesik + ' ile birleştirildi';\n  if (ic.parcalar.length > 1) return ic.parcalar.map(function (x) { return x[0] + (x[1] == null ? '' : ' ' + sayi(x[1]) + ' da'); }).join(' + ');\n  return g.urun + (g.alan == null ? '' : ' · ' + sayi(g.alan) + ' da') + (bagli.length ? ' (' + bagli.join(', ') + ' ile birlikte)' : '');\n}\nfunction parselKaydet() {\n  var A = ACIK, n = A.parcaSayisi, l = [], ces = [], bag = [];\n  for (var j = 0; j < n; j++) {\n    var u = urunOku('u' + j); if (!u) return;\n    var d = sayiOku(document.getElementById('d' + j).value), t = metinOku('t' + j); if (t === false) return;\n    if (n > 1 && (d == null || d < 0)) return durum((j + 1) + '. parçanın dekarını girin.');\n    if (d != null && d < 0) return durum('Dekar okunamadı.');\n    var b = n > 1 ? document.getElementById('b' + j).value || null : null;\n    if (b && (!A.ic || A.ic.baglar[j] !== b)) { var hb = parselGirisi(A.hedef, A.c.ad, b), hu = hb ? icerikOku(hb.urun) : null; if (hu && hu.parcalar.length === 1 && !hu.birlesik && hu.parcalar[0][0]) u = hu.parcalar[0][0]; }\n    l.push([u, d]); ces.push(t); bag.push(b);\n  }\n  var metin, top;\n  if (n === 1) { metin = urunMetni(l[0][0], ces[0]); top = l[0][1]; }\n  else { metin = bolunmusMetin(l, A.taban.cizgiler, bag, ces, A.taban.bolgeler); top = l.reduce(function (a, x) { return a + x[1]; }, 0); }\n  if (metin.length > SINIR) return durum('Kayıt çok uzun; tohum adlarını ya da parça sayısını azaltın.');\n  kayit([girisOp(A.hedef, A.c.ad, A.p.ad, metin, top)]);\n}\nfunction girisGeriAl() { var A = ACIK; kayit(A.bagli.map(function (b) { return geriOp(A.hedef, A.c.ad, b); }).concat([geriOp(A.hedef, A.c.ad, A.p.ad)])); }\n/** Parçalara böl: 2–4 parça (ürün + dekar). ek.cizgiler: çizgiyle bölmede çizgi; ek.sabit: parça sayısı sabit. */\nfunction parcaFormu(p, sezon, ekBaslik, mevcut, ek) {\n  var A = ACIK || {}; ACIK = A; A.p = p; A.c = H ? H.c : A.c; A.bolSezon = sezon; A.bolEk = ek;\n  var g = parselGirisi(sezon, A.c.ad, p.ad), ic = g ? icerikOku(g.urun) : null; A.bolIc = ic;\n  var l = mevcut || (ic && ic.parcalar.length > 1 ? ic.parcalar.map(function (x) { return [x[0], x[1]]; }) : [[p.urunler.length ? urunAnahtari(p.urunler[0][0]) : '', null], ['', null]]);\n  A.bolSayi = l.length;\n  var h = '<h2>' + esc(p.ad) + ' ' + esc(ekBaslik) + ' — parçalar</h2><p style=\"font-size:12.5px;color:var(--soluk)\">Her parçanın ürününü ve dekarını girin.</p><div id=\"bolSatirlar\">';\n  l.forEach(function (x, j) { h += bolSatiri(j, x); });\n  h += '</div>' + (ek.sabit ? '' : '<div class=\"kucukDugmeler\"><button onclick=\"bolEkle()\">+ Parça ekle</button><button onclick=\"bolCikar()\">− Son parçayı çıkar</button></div>') +\n    '<div class=\"dugmeler\"><button class=\"ana\" onclick=\"bolKaydet()\">Kaydet</button><button class=\"ikinci\" onclick=\"kapat()\">Vazgeç</button></div>';\n  sayfaAc(h);\n}\nfunction bolSatiri(j, x) { return '<div class=\"parca\" id=\"bs' + j + '\"><b>' + (j + 1) + '. parça</b><label>Ürün</label>' + urunAlani('bu' + j, x[0]) + '<label>Dekar</label><input id=\"bd' + j + '\" inputmode=\"decimal\" value=\"' + (x[1] == null ? '' : x[1]) + '\"></div>'; }\nfunction bolEkle() { if (ACIK.bolSayi >= 4) return durum('En çok 4 parça.'); document.getElementById('bolSatirlar').insertAdjacentHTML('beforeend', bolSatiri(ACIK.bolSayi, ['', null])); ACIK.bolSayi++; }\nfunction bolCikar() { if (ACIK.bolSayi <= 2) return durum('En az 2 parça.'); ACIK.bolSayi--; document.getElementById('bs' + ACIK.bolSayi).remove(); }\nfunction bolKaydet() {\n  var A = ACIK, l = [];\n  for (var j = 0; j < A.bolSayi; j++) { var u = urunOku('bu' + j); if (!u) return; var d = sayiOku(document.getElementById('bd' + j).value); if (d == null || d < 0) return durum((j + 1) + '. parçanın dekarını girin.'); l.push([u, d]); }\n  var ic = A.bolIc, ayni = ic && ic.parcalar.length === l.length, metin;\n  if (A.bolEk.cizgiler) metin = bolunmusMetin(l, A.bolEk.cizgiler, [], [], []);\n  else metin = bolunmusMetin(l, ic && ic.parcalar.length > 1 && ic.cizgiler.length === l.length - 1 ? ic.cizgiler : [], ayni ? ic.baglar : [], ayni ? ic.cesitler : [], ayni ? ic.bolgeler : []);\n  if (metin.length > SINIR) return durum('Kayıt çok uzun.');\n  kayit([girisOp(A.bolSezon, A.c.ad, A.p.ad, metin, l.reduce(function (a, x) { return a + x[1]; }, 0))]);\n}\nfunction birlestirFormu() {\n  var A = ACIK, adaylar = A.c.parseller.filter(function (x) { return x.ad !== A.p.ad && x.tip !== 'diger'; });\n  var u0 = A.ic && A.ic.parcalar.length === 1 && !A.ic.birlesik ? A.ic.parcalar[0][0] : '';\n  var h = '<h2>' + esc(A.p.ad) + ' ile birleştir</h2><p style=\"font-size:12.5px;color:var(--soluk)\">Seçilen parseller bu parselle tek ürün olarak birleşir; toplam dekar bu parselde tutulur.</p><div class=\"secim\">' +\n    adaylar.map(function (x, j) { return '<label><input type=\"checkbox\" id=\"bk' + j + '\"' + (A.bagli.indexOf(x.ad) >= 0 ? ' checked' : '') + '>' + esc(x.ad) + '</label>'; }).join('') + '</div>' +\n    '<label>Ürün</label>' + urunAlani('bku', u0) + '<label>Toplam dekar</label><input id=\"bkd\" inputmode=\"decimal\" value=\"' + (A.g && A.g.alan != null ? A.g.alan : '') + '\">' +\n    '<div class=\"dugmeler\"><button class=\"ana\" onclick=\"birlestirKaydet()\">Kaydet</button><button class=\"ikinci\" onclick=\"kapat()\">Vazgeç</button></div>';\n  A.bkAdaylar = adaylar.map(function (x) { return x.ad; });\n  sayfaAc(h);\n}\nfunction birlestirKaydet() {\n  var A = ACIK, sec = A.bkAdaylar.filter(function (_, j) { return document.getElementById('bk' + j).checked; });\n  if (!sec.length) return durum('Birleştirilecek parsel seçin.');\n  var u = urunOku('bku'); if (!u) return;\n  var d = sayiOku(document.getElementById('bkd').value), ops = [];\n  A.bagli.forEach(function (b) { if (sec.indexOf(b) < 0) ops.push(geriOp(A.hedef, A.c.ad, b)); });\n  sec.forEach(function (b) { ops.push(girisOp(A.hedef, A.c.ad, b, u + '@' + A.p.ad, '')); });\n  ops.push(girisOp(A.hedef, A.c.ad, A.p.ad, u, d));\n  kayit(ops);\n}\n/** Parsel içine çizilen bölge: bölgenin ve parselin kalanının ürünü / dekarı. */\nfunction bolgeFormu(p, bolge, pay) {\n  var sz = H.sz, g = parselGirisi(sz.sezon, H.c.ad, p.ad), eskiBolge = p.bolgeler.length && p.urunler.length === p.bolgeler.length + 1;\n  var top = p.beyan || p.urunler.reduce(function (a, u) { return a + (u[1] || 0); }, 0), eskiDa = 0;\n  if (eskiBolge) for (var i = 0; i < p.bolgeler.length; i++) eskiDa += p.urunler[i][1] || 0;\n  var kalanU = p.urunler.length ? urunAnahtari(eskiBolge ? p.urunler[p.urunler.length - 1][0] : p.urunler[0][0]) : '';\n  ACIK = { p: p, c: H.c, bolge: bolge, eskiBolge: eskiBolge };\n  var bda = top > 0 ? Math.round(top * pay * 10) / 10 : '', kda = top > 0 && bda !== '' ? Math.max(0, Math.round(top - eskiDa - bda)) : '';\n  sayfaAc('<h2>' + esc(p.ad) + ' · çizilen bölge</h2><label>Bölgenin ürünü / alan türü</label>' + urunAlani('rbu', 'Deneme alanı') +\n    '<label>Bölgenin dekarı (öneri, çizdiğiniz alana göre)</label><input id=\"rbd\" inputmode=\"decimal\" value=\"' + bda + '\">' +\n    '<label>Parselin kalanının ürünü</label>' + urunAlani('rku', kalanU) + '<label>Kalanın dekarı</label><input id=\"rkd\" inputmode=\"decimal\" value=\"' + kda + '\">' +\n    '<div class=\"dugmeler\"><button class=\"ana\" onclick=\"bolgeKaydet()\">Kaydet</button><button class=\"ikinci\" onclick=\"kapat()\">Vazgeç</button></div>');\n}\nfunction bolgeKaydet() {\n  var A = ACIK, p = A.p, bu = urunOku('rbu'); if (!bu) return; var ku = urunOku('rku'); if (!ku) return;\n  var bd = sayiOku(document.getElementById('rbd').value), kd = sayiOku(document.getElementById('rkd').value);\n  if (bd == null || bd <= 0 || kd == null || kd < 0) return durum('Dekarları girin.');\n  var n = A.eskiBolge ? p.bolgeler.length : 0, l = [], ces = [], bag = [];\n  for (var i = 0; i < n; i++) { l.push([p.urunler[i][0], p.urunler[i][1]]); ces.push(p.cesitler[i] || null); bag.push(p.baglar[i] || null); }\n  l.push([bu, bd]); ces.push(null); bag.push(null);\n  l.push([ku, kd]); ces.push(A.eskiBolge ? p.cesitler[p.urunler.length - 1] || null : null); bag.push(A.eskiBolge ? p.baglar[p.urunler.length - 1] || null : null);\n  var metin = bolunmusMetin(l, [], bag, ces, (A.eskiBolge ? p.bolgeler : []).concat([A.bolge]));\n  if (metin.length > SINIR) return durum('Kayıt çok uzun; bölge sayısını azaltın.');\n  kayit([girisOp(H.sz.sezon, A.c.ad, p.ad, metin, l.reduce(function (a, x) { return a + x[1]; }, 0))]);\n}\nfunction sayfaAc(h) { var s = document.getElementById('sayfa'); s.innerHTML = h; s.style.display = 'block'; s.scrollTop = 0; document.getElementById('perde').style.display = 'block'; }\nfunction kapat() { document.getElementById('sayfa').style.display = 'none'; document.getElementById('perde').style.display = 'none'; }\n/** Kayıtları sırayla sunucuya gönderir; bitince veri yenilenir ve ekran yeniden çizilir. */\nfunction kayit(ops, sonra) {\n  if (S.yetki !== 'duzenle') return durum('Yalnızca görüntüleme yetkiniz var.');\n  C.kaydediliyor = true; cizimPaneli();\n  document.querySelectorAll('#sayfa button').forEach(function (b) { b.disabled = true; });\n  google.script.run.withSuccessHandler(function (r) {\n    C.kaydediliyor = false;\n    document.querySelectorAll('#sayfa button').forEach(function (b) { b.disabled = false; });\n    if (!r || !r.ok) { cizimPaneli(); return hataGoster(r); }\n    S.sezonParsel = r.sezonParsel || S.sezonParsel; S.parselSinir = r.parselSinir || S.parselSinir;\n    if (sonra) sonra();\n    kapat(); ciz(); durum(r.mesaj || 'Kaydedildi.');\n  }).withFailureHandler(function (e) { C.kaydediliyor = false; cizimPaneli(); document.querySelectorAll('#sayfa button').forEach(function (b) { b.disabled = false; }); durum('Kaydedilemedi: ' + e.message); })\n    .tarlaPanelKaydet(ANAHTAR, { coklu: ops });\n}\nfunction hataGoster(r) {\n  if (r && r.kapali) { document.querySelector('main').innerHTML = '<div class=\"kart\" style=\"margin-top:20px\">Bu paylaşım kapatıldı.</div>'; kapat(); return; }\n  durum((r && r.hata) || 'İşlem yapılamadı.');\n}\n// ---------- açılış ----------\nfunction yukle() {\n  var bekle = DOSYALAR.length + 1, hata = null;\n  function bitti() {\n    if (--bekle) return;\n    if (hata) { document.getElementById('icerik').innerHTML = '<div class=\"kart\">' + esc(hata) + '</div>'; return; }\n    ciz();\n  }\n  google.script.run.withSuccessHandler(function (r) {\n    if (!r || !r.ok) { hata = (r && r.hata) || 'Veri alınamadı.'; if (r && r.kapali) hata = 'Bu paylaşım kapatıldı.'; return bitti(); }\n    S.sezonParsel = r.sezonParsel || []; S.parselSinir = r.parselSinir || []; S.yetki = r.yetki; S.etiket = r.etiket; SINIR = r.sezonParselSiniri || 400;\n    S.ekim = r.ekim || []; S.ekimPlani = r.ekimPlani || []; S.cks = r.cks || [];\n    document.getElementById('ust').textContent = r.etiket + ' · ' + (r.yetki === 'duzenle' ? 'düzenleme yetkisi' : 'yalnızca görüntüleme');\n    bitti();\n  }).withFailureHandler(function (e) { hata = 'Veri alınamadı: ' + e.message; bitti(); }).tarlaPanelVeri(ANAHTAR);\n  var sira = {};\n  DOSYALAR.forEach(function (d, i) {\n    fetch(VERI_ADRESI + d, { cache: 'no-store' }).then(function (x) { if (!x.ok) throw new Error(x.status); return x.json(); })\n      .then(function (j) { sira[i] = sezonOku(j); }).catch(function () { if (i === 0) hata = 'Harita dosyası alınamadı. İnternet bağlantınızı kontrol edin.'; })\n      .then(function () { S.paket = DOSYALAR.map(function (_, k) { return sira[k]; }).filter(Boolean); bitti(); });\n  });\n}\nyukle();\n</script>\n</body>\n</html>\n";
// <</TARLA_PANEL_HTML>>
