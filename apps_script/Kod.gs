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

/** Uygulama veri dosyaları: depoda ve uygulama paketinde bulunmaz (ticari gizlilik). Drive'daki kapalı
 * "Yönetim Raporu – Uygulama Verileri (gizli, paylaşılmaz)" klasöründe tutulur; yalnızca anahtarla gönderilir.
 * Hastalık arşivi Veteriner Paneli'nin Drive dosyasıdır (VET_ARSIV_ID). */
var UYGULAMA_DOSYALARI_ = {
  ciftlik_rapor_2026: '1HGVDbd3sbAdlcBliKdRpITvmG5k2Wrmn',
  maliyet_takip_2026: '15fr-ol9R-oCJcrENyKMY0yDGFYTawpby',
  tarla_2025_2026: '1KKoDN_3OmhiDmCvANwifLMn1PHCce4za',
  tarla_2024_2025: '1OyrP5jygO-Ha0kp9SVpIbjfvDE3lt2g5',
  tarla_2026_2027: '12_B-3yYYrzM-pEP_nvBLNE6mL2uwMjVm'
};
var TARLA_DOSYALARI_ = ['tarla_2025_2026', 'tarla_2024_2025', 'tarla_2026_2027'];

/** Önbellek değeri 100 KB ile sınırlı: büyük metinler 90.000 karakterlik parçalar hâlinde tutulur. */
function parcaliYaz_(cache, k, m) {
  try {
    var o = {}, n = Math.ceil(m.length / 90000);
    if (n > 20) return;
    for (var i = 0; i < n; i++) o[k + '_' + i] = m.substr(i * 90000, 90000);
    o[k + '_n'] = String(n);
    cache.putAll(o, 21600);
  } catch (e) {}
}
function parcaliOku_(cache, k) {
  try {
    var n = +cache.get(k + '_n');
    if (!n) return null;
    var ad = [];
    for (var i = 0; i < n; i++) ad.push(k + '_' + i);
    var o = cache.getAll(ad), l = [];
    for (var j = 0; j < n; j++) { if (o[ad[j]] == null) return null; l.push(o[ad[j]]); }
    return l.join('');
  } catch (e) { return null; }
}

/** Hastalık arşivinin güncel dosyası: bu adla kayıtlı en yeni dosya (yeni sürüm yüklenince
 *  Kod.gs değiştirilmeden kullanılır); bulunamazsa VET_ARSIV_ID. Kimlik 10 dakika önbellekte. */
var VET_ARSIV_ADI_ = 'Veteriner Paneli – hastalık arşivi (Yönetim Raporu, silmeyin).json';
function vetArsivId_() { return adlaDosyaId_(VET_ARSIV_ADI_, VET_ARSIV_ID, 'vet_arsiv_id'); }

/** Sürü Sağlığı ve Üreme arşivi (araclar/hastalik/uygulamalar.py; doğum, tohumlama, gebelik, aşı vb.). */
var UYGULAMALAR_ADI_ = 'Yönetim Raporu – sürü sağlığı ve üreme arşivi (silmeyin).json';
var UYGULAMALAR_ID_ = '1myA4JE2_9dr-ENnlZQC7vPV2-Ek4KMjM';
function uygulamalarId_() { return adlaDosyaId_(UYGULAMALAR_ADI_, UYGULAMALAR_ID_, 'uygulamalar_id'); }

function adlaDosyaId_(dosyaAdi, varsayilan, onbellek) {
  var cache = CacheService.getScriptCache(), id = null;
  try { id = cache.get(onbellek); } catch (e) {}
  if (id) return id;
  id = varsayilan;
  try {
    var it = DriveApp.getFilesByName(dosyaAdi), en = null;
    while (it.hasNext()) {
      var f = it.next();
      if (f.isTrashed() || f.getOwner() && f.getOwner().getEmail() !== Session.getEffectiveUser().getEmail()) continue;
      if (!en || f.getDateCreated() > en.getDateCreated()) en = f;
    }
    if (en) id = en.getId();
  } catch (e) {}
  try { cache.put(onbellek, id, 600); } catch (e) {}
  return id;
}

/** {ad: JSON metni}. Dosyalar 6 saat önbellekte tutulur (değişince en geç 6 saatte yenilenir). */
function uygulamaDosyalari_(adlar) {
  var o = {}, cache = CacheService.getScriptCache();
  adlar.forEach(function (ad) {
    var id = ad === 'hastalik' ? vetArsivId_() : ad === 'uygulamalar' ? uygulamalarId_() : UYGULAMA_DOSYALARI_[ad];
    if (!id) return;
    var k = 'dosya_' + ad + '_' + id, m = parcaliOku_(cache, k);
    if (!m) {
      try { m = DriveApp.getFileById(id).getBlob().getDataAsString('UTF-8'); } catch (e) { m = null; }
      if (m) parcaliYaz_(cache, k, m);
    }
    if (m) o[ad] = m;
  });
  return o;
}

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
  if (p.panel === 'tarla') return tarlaPanel_(p.anahtar, p.eski === '1');
  var anahtar = PropertiesService.getScriptProperties().getProperty('ANAHTAR');
  if (!anahtar) {
    return json_({ ok: false, hata: 'Kurulum yapılmamış: Apps Script\'te "kurulum" fonksiyonunu çalıştırın.' });
  }
  if (p.anahtar !== anahtar) {
    // Paylaşımlar yalnızca şirket hesabıyla, web panelinden açılır; paylaşım anahtarıyla doğrudan veri verilmez.
    var pay = paylasimBul_(p.anahtar);
    if (pay === 'kapali') return json_({ ok: false, paylasimKapali: true, hata: 'Bu paylaşım kapatıldı.' });
    if (pay) return json_({ ok: false, hata: 'Paylaşım yalnızca size gönderilen linkle, şirket hesabınızla (@panagro.com.tr) tarayıcıda açılır.' });
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
    // Uygulama veri dosyaları (çiftlik raporu, maliyet takip, hastalık arşivi, tarla haritası)
    dosyalar: uygulamaDosyalari_(['ciftlik_rapor_2026', 'maliyet_takip_2026', 'hastalik', 'uygulamalar'].concat(TARLA_DOSYALARI_)),
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
    // Tarla Haritası'nda "Yeni sezon ekle" ile açılan sezonlar (ör. 2027-2028)
    tarlaSezonlari: tarlaSezonlari_(),
    paylasimlar: paylasimListesi_(),
    parselSinir: basitOku_('Parsel_Sınırları', 5, tz),
    // Ürün teslimat ve satışları (günlük toplamlar): TarKop pancar, patates fire listesi,
    // Ürün_Teslimatları sayfasına uygulamadan girilen kayıtlar. Plaka/satıcı no yok.
    urunTeslimat: (function () { try { return urunTeslimatlari_(); } catch (err) { return { hata: String(err) }; } })(),
    // Tarımsal Faaliyet › PARSEL: Çiftlik, İlçe, Köy, Ada, Parsel, Alan (da), Ürün
    resmiParsel: (function () { try { return resmiParsellerOku_(); } catch (err) { return []; } })(),
    // Veri kalitesi paneli: kaynak dosyaların ve kopyaların son değişiklik tarihleri (içerik okunmaz)
    veriKalitesi: (function () { try { return veriKalitesi_(); } catch (err) { return []; } })(),
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
    return json_({ ok: false, hata: 'Paylaşım işlemleri yalnızca şirket hesabıyla, web panelinden yapılır.' });
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
    if (govde.tur === 'tarlaSezonEkle' || govde.tur === 'tarlaSezonSil') return json_(tarlaSezon_(govde));
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

/**
 * Bir TarKop xlsx dosyasındaki tartım satırları. Tablo başlığı (Tarih + Tartım No + Net Miktar) her sayfada
 * herhangi bir satırda olabilir; başlık satırında ya da üstündeki iki satırda geçen çiftlik adı tabloya,
 * çiftlik adı veya "kantar" yazan ek sütun çiftlik kantarına atanır. Plaka ve satıcı no okunmaz (KVKK).
 */
function tarkopTablolari_(blob) {
  var out = [], CIFT = /(ASLIM|ŞEKER\s*SÜT|ŞEKERSÜT|TAŞAĞIL|ORMANLIK|FİDANLIK)/;
  xlsxSatirlari_(blob).forEach(function (satirlar) {
    var s = null;
    for (var i = 0; i < satirlar.length; i++) {
      var h = satirlar[i], yeni = {}, baslikVar = false;
      Object.keys(h).forEach(function (k) {
        var x = String(h[k]).toLocaleLowerCase('tr').trim();
        if (x === 'tarih') { yeni.tarih = k; baslikVar = true; }
        else if (x.indexOf('tartım no') === 0) yeni.tartim = k;
        else if (x.indexOf('net miktar') === 0) yeni.net = k;
        else if (x.indexOf('fabpolar') === 0) yeni.polar = k;
        else if (x.indexOf('fireli miktar') === 0) yeni.fireli = k;
      });
      if (yeni.tarih && yeni.tartim && yeni.net) {
        yeni.ciftlik = '';
        var tanimli = {};
        [yeni.tarih, yeni.tartim, yeni.net, yeni.polar, yeni.fireli].forEach(function (k) { if (k) tanimli[k] = 1; });
        // Önce başlık satırı, sonra üstündeki satırlar (en yakın bilgi geçerli).
        for (var j = i; j >= Math.max(0, i - 2); j--) {
          Object.keys(satirlar[j]).forEach(function (k) {
            var x = String(satirlar[j][k]), ust = x.toLocaleUpperCase('tr'), m = CIFT.exec(ust);
            if (m && !yeni.ciftlik) yeni.ciftlik = ciftlikAdi_(m[1].toLocaleLowerCase('tr'));
            if (!yeni.kantar && k !== 'A' && !tanimli[k] && !/portal/i.test(x) && (m || /kantar/i.test(x)) && !/kantar adı/i.test(x)) yeni.kantar = k;
          });
        }
        s = yeni;
        continue;
      }
      if (baslikVar) { s = null; continue; } // tartım tablosu olmayan başka bir tablo başladı
      if (!s) continue;
      var tn = h[s.tartim], tr = h[s.tarih];
      if (typeof tn !== 'number' || typeof tr !== 'number') continue;
      out.push({ tartim: tn, tarih: tr, net: h[s.net], fireli: s.fireli ? h[s.fireli] : null, polar: s.polar ? h[s.polar] : null,
        kantar: s.kantar ? h[s.kantar] : null, ciftlik: s.ciftlik });
    }
  });
  return out;
}

/**
 * Pancar teslimatı: portaldan indirilen TarKop dosyası sezonun tamamını kümülatif içerdiği için yalnızca
 * Drive'a en son yüklenen dosya okunur (eski sürümler toplanmaz). Adında "karşılaştırma" geçen çalışma
 * dosyalarından yalnızca tartım no eşleşmesiyle çiftlik ve çiftlik kantarı bilgisi alınır.
 */
function tarkopOku_(g, kaynaklar) {
  var dosyalar = [], it = DriveApp.searchFiles("title contains 'TarKop' and trashed = false");
  while (it.hasNext()) {
    var f = it.next();
    if (!/\.xlsx$/i.test(f.getName()) || f.getMimeType() === 'application/vnd.google-apps.shortcut') continue;
    dosyalar.push(f);
  }
  if (!dosyalar.length) return;
  var yardimci = function (f) { return /karşılaştırma|karsilastirma/i.test(f.getName()); };
  var adaylar = dosyalar.filter(function (f) { return !yardimci(f); });
  if (!adaylar.length) adaylar = dosyalar.slice();
  adaylar.sort(function (a, b) { return b.getDateCreated().getTime() - a.getDateCreated().getTime(); });
  var ana = adaylar[0];

  var ek = {};
  dosyalar.forEach(function (f) {
    if (f.getId() === ana.getId()) return;
    var n = 0;
    tarkopTablolari_(f.getBlob()).forEach(function (r) {
      var e = ek[r.tartim] || (ek[r.tartim] = {});
      if (r.ciftlik) { e.ciftlik = r.ciftlik; n++; }
      if (typeof r.kantar === 'number' && r.kantar > 0) e.kantar = r.kantar;
    });
    kaynaklar.push({ ad: f.getName() + ' (yalnızca çiftlik ve kantar eşleştirmesi)', urun: 'Şeker Pancarı', ciftlik: '', satir: n,
      guncelleme: Utilities.formatDate(f.getLastUpdated(), 'Europe/Istanbul', 'dd.MM.yyyy HH:mm') });
  });

  var adCiftlik = (/(ASLIM|ŞEKER\s*SÜT|ŞEKERSÜT|TAŞAĞIL|ORMANLIK|FİDANLIK)/i.exec(ana.getName()) || [])[1];
  // Aynı tartım no birden fazla satırda gelebilir (bir sefer iki parçaya bölünmüş): net miktarlar toplanır,
  // sefer ve fireli miktar bir kez sayılır. Birebir aynı satırlar yalnızca bir kez alınır.
  var tartimlar = {}, sira = [];
  tarkopTablolari_(ana.getBlob()).forEach(function (r) {
    var x = tartimlar[r.tartim];
    if (!x) { x = tartimlar[r.tartim] = { r: r, netler: {}, net: 0, fireli: 0 }; sira.push(r.tartim); }
    var nk = String(r.net);
    if (!x.netler[nk] && typeof r.net === 'number') { x.netler[nk] = 1; x.net += r.net; }
    if (typeof r.fireli === 'number' && r.fireli > x.fireli) x.fireli = r.fireli;
  });
  var say = 0;
  sira.forEach(function (tn) {
    var x = tartimlar[tn], r = { tartim: tn, tarih: x.r.tarih, net: x.net, fireli: x.fireli || null, polar: x.r.polar,
      kantar: x.r.kantar, ciftlik: x.r.ciftlik };
    say++;
    var e = ek[r.tartim] || {};
    var ciftlik = r.ciftlik || e.ciftlik || (adCiftlik ? ciftlikAdi_(adCiftlik) : 'Çiftlik belirtilmemiş');
    var t = Utilities.formatDate(new Date(Date.UTC(1899, 11, 30) + Math.round(r.tarih) * 86400000), 'UTC', 'yyyy-MM-dd');
    // Dosyada miktarlar ton; kg'a çevrilir. Çiftlik kantarı kg.
    var net = typeof r.net === 'number' ? r.net * 1000 : 0;
    var fireli = typeof r.fireli === 'number' ? r.fireli * 1000 : net;
    var kantar = typeof r.kantar === 'number' ? r.kantar : (e.kantar || 0);
    teslimatTopla_(g, { urun: 'Şeker Pancarı', ciftlik: ciftlik, kaynak: 'TarKop', alici: 'Konya Şeker',
      tarih: t, teslim: fireli, net: net, polar: polarDuzelt_(r.polar), kantar: kantar });
  });
  kaynaklar.unshift({ ad: ana.getName() + ' (güncel portal dosyası)', urun: 'Şeker Pancarı', ciftlik: '', satir: say,
    guncelleme: Utilities.formatDate(ana.getLastUpdated(), 'Europe/Istanbul', 'dd.MM.yyyy HH:mm') });
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
  return onbellekli_('teslimat_v2', 600, function () {
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
  CacheService.getScriptCache().remove('teslimat_v2');
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
  return x.acik && !paylasimSuresiDoldu_(x) ? x : 'kapali';
}

/** Süreli paylaşım: bitiş günü (yyyy-MM-dd) geçtiyse link çalışmaz. */
function paylasimSuresiDoldu_(p) {
  if (!p.bitis) return false;
  return Utilities.formatDate(new Date(), 'Europe/Istanbul', 'yyyy-MM-dd') > p.bitis;
}

/** Şirket hesabı kontrolü: panel yalnızca @panagro.com.tr Google hesabıyla girenlere açılır
 * (şirket içi dağıtımda Google girişi zorunludur; e-posta yalnızca kontrol için okunur, saklanmaz). */
var SIRKET_ALANI_ = 'panagro.com.tr';
function sirketKullanicisi_() {
  try {
    var e = String(Session.getActiveUser().getEmail() || '').toLowerCase();
    return e.slice(-(SIRKET_ALANI_.length + 1)) === '@' + SIRKET_ALANI_ ? e : '';
  } catch (err) { return ''; }
}

/** Erişim kaydı (madde 3): yalnızca paylaşımın son açılış zamanı ve açılış sayısı tutulur; kişi bilgisi tutulmaz. */
function erisimKaydet_(pay) {
  var kilit = LockService.getScriptLock();
  try { kilit.waitLock(5000); } catch (e) { return; }
  try {
    var l = paylasimlar_(), x = l.filter(function (p) { return p.id === pay.id; })[0];
    if (!x) return;
    x.sonErisim = Utilities.formatDate(new Date(), 'Europe/Istanbul', 'dd.MM.yyyy HH:mm');
    x.erisimSayisi = (x.erisimSayisi || 0) + 1;
    paylasimKaydet_(l);
  } finally { kilit.releaseLock(); }
}

/** Süre (gün) → bitiş günü; boş ya da 0 ise süresiz. */
function bitisGunu_(sure) {
  var n = parseInt(sure, 10);
  if (!n || n < 1) return '';
  return Utilities.formatDate(new Date(Date.now() + n * 86400000), 'Europe/Istanbul', 'yyyy-MM-dd');
}

/** Paylaşımda görünen menüler. Eski paylaşımlarda (seçim yapılmamış) üç menü de açıktır. */
var PAYLASIM_MENULERI_ = ['gunluk', 'haftalik', 'ziraat', 'hayvan', 'tarla', 'esk', 'mali', 'ciftlikRapor', 'urun', 'gecmis', 'hastalik', 'sureme', 'arac', 'bakim'];
function paylasimMenuleri_(p) {
  return Array.isArray(p.menuler) ? p.menuler.filter(function (m) { return PAYLASIM_MENULERI_.indexOf(m) >= 0; }) : ['ziraat', 'hayvan', 'tarla'];
}
function menuAcik_(p, m) { return paylasimMenuleri_(p).indexOf(m) >= 0; }
function menuSecimi_(g) {
  var l = Array.isArray(g.menuler) ? g.menuler : String(g.menuler || '').split(',');
  return PAYLASIM_MENULERI_.filter(function (m) { return l.indexOf(m) >= 0; });
}

/** Şirket içi dağıtımın adresi (Komut dosyası özelliği PAYLASIM_ADRESI; "…/exec"). Tanımlı değilse bu dağıtım. */
function paylasimAdresi_() {
  return PropertiesService.getScriptProperties().getProperty('PAYLASIM_ADRESI') || ScriptApp.getService().getUrl();
}

function paylasimLinki_(p) {
  return paylasimAdresi_() + '?panel=tarla&anahtar=' + p.anahtar;
}

/** Web sürümü: depodaki "web-yayin" dalı (yalnızca program kodu, veri içermez), jsDelivr üzerinden yüklenir.
 * Her derlemede jsDelivr önbelleği yenilenir (.github/workflows/web.yml). */
var WEB_DEPO_ = 'ramazankcbss-alt/Yonetim-raporu';
function webSurumAdresi_() {
  return 'https://cdn.jsdelivr.net/gh/' + WEB_DEPO_ + '@web-yayin/';
}

/** Paylaşım paneli: şirket hesabı zorunlu. Sayfa veri içermez; veri anahtarla google.script.run üzerinden gelir. */
function tarlaPanel_(anahtar, eski) {
  function sayfa(icerik) {
    return HtmlService.createHtmlOutput('<meta name="viewport" content="width=device-width, initial-scale=1">' +
      '<div style="font-family:sans-serif;padding:24px;font-size:16px;line-height:1.5">' + icerik + '</div>')
      .setTitle('Tarım ve Hayvancılık');
  }
  var pay = paylasimBul_(anahtar);
  if (!pay || pay === 'kapali') return sayfa('Bu paylaşım kapalı ya da geçersiz.');
  if (!sirketKullanicisi_()) {
    var adres = paylasimAdresi_();
    var git = adres && adres !== ScriptApp.getService().getUrl()
      ? '<p><a target="_top" style="display:inline-block;background:#14532d;color:#fff;padding:12px 18px;border-radius:10px;text-decoration:none" href="' +
        adres + '?panel=tarla&anahtar=' + encodeURIComponent(anahtar) + '">Şirket hesabıyla aç</a></p>' : '';
    return sayfa('<b>Tarım ve Hayvancılık</b><p>Bu panel yalnızca şirket Google hesabıyla (@' + SIRKET_ALANI_ + ') açılır.</p>' + git);
  }
  if (eski) {
    return HtmlService.createHtmlOutput(TARLA_PANEL_HTML_.replace('__ANAHTAR__', JSON.stringify(pay.anahtar)))
      .setTitle('Tarım ve Hayvancılık').addMetaTag('viewport', 'width=device-width, initial-scale=1')
      .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.DEFAULT);
  }
  // Web sürümünün en son sürüm adı (wN) depodaki küçük bir dosyadan tarayıcıda okunur; dosyalar o değişmez
  // sürümden jsDelivr üzerinden yüklenir. Böylece web sürümü güncellenince Apps Script'i yeniden dağıtmak gerekmez.
  var yedekLink = paylasimAdresi_() + '?panel=tarla&anahtar=' + encodeURIComponent(pay.anahtar) + '&eski=1';
  var html = '<!DOCTYPE html><html lang="tr"><head><meta charset="utf-8"><base target="_top">' +
    '<meta name="robots" content="noindex, nofollow"><title>Tarım ve Hayvancılık</title>' +
    '<style>html,body{margin:0;height:100%;background:#f8fafc;font-family:sans-serif}#yukl{padding:40px;text-align:center;color:#64748b}</style>' +
    '<script>var YR_ANAHTAR=' + JSON.stringify(pay.anahtar) + ';' +
    'window.yrSunucu=function(islem,govde){return new Promise(function(ok,hata){google.script.run' +
    '.withSuccessHandler(function(r){ok(String(r));}).withFailureHandler(function(e){hata(e&&e.message?e.message:String(e));})' +
    '.paylasimSunucu(YR_ANAHTAR,String(islem),String(govde||""));});};' +
    'function yrYedek(){var y=document.getElementById("yukl");if(y)y.innerHTML=' +
    JSON.stringify('Görünüm yüklenemedi. <a target="_top" href="' + yedekLink + '">Klasik görünümle açın</a>') + ';}' +
    'setTimeout(function(){if(document.getElementById("yukl"))yrYedek();},40000);' +
    'fetch("https://raw.githubusercontent.com/' + WEB_DEPO_ + '/web-yayin/surum.txt",{cache:"no-store"})' +
    '.then(function(r){return r.ok?r.text():"";}).catch(function(){return "";}).then(function(t){' +
    't=String(t||"").trim();var w="https://cdn.jsdelivr.net/gh/' + WEB_DEPO_ + '@"+(/^w\\d+$/.test(t)?t:"web-yayin")+"/";' +
    'window.YR_WEB=w;var b=document.querySelector("base");if(b)b.href=w;' +
    'var s=document.createElement("script");s.src=w+"flutter_bootstrap.js";s.onerror=yrYedek;document.head.appendChild(s);});' +
    '</script></head><body><div id="yukl">Yükleniyor…</div></body></html>';
  return HtmlService.createHtmlOutput(html)
    .setTitle('Tarım ve Hayvancılık')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.DEFAULT);
}

/** Kurulum sonrası bir kez düzenleyicide çalıştırın: web sürümü kontrolü için gereken izni (harici istek) verir. */
function yetkiVer() {
  var durum;
  try {
    var r = UrlFetchApp.fetch(webSurumAdresi_() + 'flutter_bootstrap.js', { muteHttpExceptions: true });
    durum = 'HTTP ' + r.getResponseCode();
  } catch (e) { durum = 'hata: ' + e; }
  Logger.log('Web sürümü (' + webSurumAdresi_() + '): ' + durum + ' · Paylaşım adresi: ' + paylasimAdresi_());
}

/** google.script.run (web sürümü): veri ('veri') ya da paylaşım işlemi. Şirket hesabı ve açık paylaşım zorunlu.
 * Sonuç JSON metni olarak döner. */
function paylasimSunucu(anahtar, islem, govde) {
  if (!sirketKullanicisi_()) return JSON.stringify({ ok: false, hata: 'Bu panel yalnızca şirket hesabıyla açılır.' });
  var pay = paylasimBul_(anahtar);
  if (pay === 'kapali') return JSON.stringify({ ok: false, paylasimKapali: true, hata: 'Bu paylaşım kapatıldı.' });
  if (!pay) return JSON.stringify({ ok: false, hata: 'Paylaşım bulunamadı.' });
  try {
    if (islem === 'veri') {
      var v = tarlaVeri_(pay);
      erisimKaydet_(pay);
      return JSON.stringify(v);
    }
    var g = JSON.parse(govde || '{}');
    g.tur = g.tur || islem;
    return JSON.stringify(paylasimIslem_(pay, g));
  } catch (err) {
    return JSON.stringify({ ok: false, hata: 'İşlem yapılamadı: ' + err });
  }
}

/** google.script.run: panel verisi (yalnızca parsel kayıtları ve sınırlar; harita çizimleri GitHub'daki paket dosyalarından). */
/** Tarla Haritası'nda kullanıcının açtığı sezonlar (komut dosyası özelliği TARLA_SEZONLARI). */
function tarlaSezonlari_() {
  try { return JSON.parse(PropertiesService.getScriptProperties().getProperty('TARLA_SEZONLARI') || '[]'); } catch (e) { return []; }
}

/** Yeni sezon açar ya da kaydı olmayan son açılan sezonu kaldırır. Sezon "YYYY-YYYY" ve ardışık yıllar olmalıdır. */
function tarlaSezon_(g) {
  var sezon = String(g.sezon || '').trim(), m = /^(\d{4})-(\d{4})$/.exec(sezon);
  if (!m || +m[2] !== +m[1] + 1) return { ok: false, hata: 'Sezon adı geçersiz (ör. 2027-2028).' };
  var l = tarlaSezonlari_();
  if (g.tur === 'tarlaSezonEkle') {
    if (l.indexOf(sezon) < 0) l.push(sezon);
    l.sort();
    PropertiesService.getScriptProperties().setProperty('TARLA_SEZONLARI', JSON.stringify(l));
    return { ok: true, mesaj: sezon + ' sezonu açıldı.', tarlaSezonlari: l };
  }
  var kayit = basitOku_('Sezon_Parselleri', 7, 'Europe/Istanbul').some(function (r) { return String(r[0]) === sezon; });
  if (kayit) return { ok: false, hata: sezon + ' sezonunda parsel kaydı var; sezon kaldırılamaz.' };
  l = l.filter(function (x) { return x !== sezon; });
  PropertiesService.getScriptProperties().setProperty('TARLA_SEZONLARI', JSON.stringify(l));
  return { ok: true, mesaj: sezon + ' sezonu kaldırıldı.', tarlaSezonlari: l };
}

function tarlaPanelVeri(anahtar) {
  if (!sirketKullanicisi_()) return { ok: false, hata: 'Bu panel yalnızca şirket hesabıyla açılır.' };
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
  var menuler = paylasimMenuleri_(pay), tarla = menuler.indexOf('tarla') >= 0;
  if (!tarla && menuler.indexOf('ziraat') < 0) ekim = [];
  return { ok: true, etiket: pay.etiket, yetki: pay.yetki, menuler: menuler, sezonParselSiniri: 400, tarlaSezonlari: tarla ? tarlaSezonlari_() : [],
    sezonParsel: tarla ? basitOku_('Sezon_Parselleri', 7, tz) : [], parselSinir: tarla ? basitOku_('Parsel_Sınırları', 5, tz) : [],
    ekim: ekim, ekimPlani: tarla ? (function () { try { return ekimPlaniOku_(); } catch (e) { return []; } })() : [],
    cks: tarla ? basitOku_('ÇKS_Parseller', 10, tz) : [], dosyalar: tarla ? uygulamaDosyalari_(TARLA_DOSYALARI_) : {} };
}

/** google.script.run: paylaşılan panelin Ziraat ve Hayvancılık menüleri (uygulamadaki Tarım ekranının verisi).
 * Yalnızca okunur. KVKK: personel/taşeron sayıları ve personel satırları gönderilmez; kişi adı içeren sayfa okunmaz. */
function tarlaPanelTarim(anahtar) {
  if (!sirketKullanicisi_()) return { ok: false, hata: 'Bu panel yalnızca şirket hesabıyla açılır.' };
  var pay = paylasimBul_(anahtar);
  if (pay === 'kapali') return { ok: false, kapali: true, hata: 'Bu paylaşım kapatıldı.' };
  if (!pay) return { ok: false, hata: 'Paylaşım bulunamadı.' };
  var ss = SpreadsheetApp.getActiveSpreadsheet(), tz = ss.getSpreadsheetTimeZone() || 'Europe/Istanbul';
  var sinir = new Date(Date.now() - 120 * 86400000), detaySinir = new Date(Date.now() - 70 * 86400000);
  function oku(ad, w) {
    var sh = ss.getSheetByName(ad);
    if (!sh || sh.getLastRow() < 2) return [];
    return sh.getRange(2, 1, sh.getLastRow() - 1, w).getValues();
  }
  function hucre(v) { return v instanceof Date ? Utilities.formatDate(v, tz, 'yyyy-MM-dd') : (v === null || v === undefined ? '' : v); }
  function tarihli(rows, s) { return rows.filter(function (r) { return r[0] instanceof Date && r[0] >= (s || sinir); }).map(function (r) { return r.map(hucre); }); }
  function dolu(rows) { return rows.filter(function (r) { return String(r[0]).trim() !== ''; }).map(function (r) { return r.map(hucre); }); }
  function personelMi(g) {
    var k = String(g || '').replace(/İ/g, 'i').replace(/I/g, 'ı').toLowerCase();
    return ['personel', 'pers.', 'işçi', 'isci', 'taşeron', 'taseron', 'güvenlik'].some(function (x) { return k.indexOf(x) >= 0; });
  }
  var zr = menuAcik_(pay, 'ziraat'), hy = menuAcik_(pay, 'hayvan'), form = [];
  if (!zr && !hy) return { ok: true, ozet: [], gunluk: [], detay: [], tarim: [], hasat: [], besi: [] };
  try { form = tarihli(formBildirimleri_()); } catch (e) { form = []; }
  // Faaliyetler türüne göre ayrılır; işaretli olmayan menünün kayıtları gönderilmez (uygulamadaki ayrımla aynı).
  function hayvanMi(f) {
    var x = String(f || '').toLowerCase().replace(/\u0307/g, '').replace(/ı/g, 'i').replace(/ğ/g, 'g').replace(/ş/g, 's').replace(/ö/g, 'o').replace(/ü/g, 'u').replace(/ç/g, 'c');
    return ['sagim', 'sagmal', 'buzag', 'inek', 'duve', 'dana', 'boga', 'besi', 'kesim', 'asilama', 'tohumlama', 'suni tohum', 'dogum', 'veteriner',
      'mastitis', 'kupe', 'ahir', 'agil', 'padok', 'tirnak', 'rasyon', 'hayvan'].some(function (k) { return x.indexOf(k) >= 0; });
  }
  return {
    ok: true,
    ozet: hy ? tarihli(oku(SAYFALAR.ozet, 18)).map(function (r) { r[2] = 0; r[3] = 0; return r; }) : [],
    gunluk: hy ? tarihli(oku(SAYFALAR.gunluk, 13)) : [],
    detay: hy ? tarihli(oku(DETAY_SAYFA_, 5), detaySinir).filter(function (r) { return !personelMi(r[3]); }) : [],
    tarim: tarihli(oku(SAYFALAR.tarim, 3)).concat(form).filter(function (r) { return hayvanMi(r[2]) ? hy : zr; }),
    hasat: zr ? dolu(oku(SAYFALAR.hasat, 6)) : [],
    besi: hy ? dolu(oku(SAYFALAR.besi, 4)) : []
  };
}

/** google.script.run: panelden parsel kayıtları (yalnızca düzenleme yetkisinde): ürün/dekar/tohum, bölme, birleştirme,
 * ayırma çizgisi, bölge, parça bağlama (Sezon_Parselleri) ve parsel sınırı / yeni parsel (Parsel_Sınırları).
 * g.coklu: sırayla uygulanacak işlemler (birleştirmede birden çok parsel). */
function tarlaPanelKaydet(anahtar, g) {
  if (!sirketKullanicisi_()) return { ok: false, hata: 'Bu panel yalnızca şirket hesabıyla açılır.' };
  var pay = paylasimBul_(anahtar);
  if (pay === 'kapali') return { ok: false, kapali: true, hata: 'Bu paylaşım kapatıldı.' };
  if (!pay) return { ok: false, hata: 'Paylaşım bulunamadı.' };
  g = g || {};
  if (!menuAcik_(pay, 'tarla')) return { ok: false, hata: 'Tarla Haritaları bu paylaşımda açık değil.' };
  var ops = Array.isArray(g.coklu) ? g.coklu.slice(0, 30) : [g], r = { ok: false, hata: 'İşlem yok.' };
  for (var i = 0; i < ops.length; i++) {
    r = paylasimIslem_(pay, ops[i] || {});
    if (!r.ok) break;
  }
  var tz = SpreadsheetApp.getActiveSpreadsheet().getSpreadsheetTimeZone() || 'Europe/Istanbul';
  r.sezonParsel = basitOku_('Sezon_Parselleri', 7, tz);
  r.parselSinir = basitOku_('Parsel_Sınırları', 5, tz);
  r.tarlaSezonlari = tarlaSezonlari_();
  return r;
}

/** Uygulamanın sahibine giden liste (link dahil). */
function paylasimListesi_() {
  return paylasimlar_().map(function (p) {
    return { id: p.id, etiket: p.etiket, yetki: p.yetki, acik: p.acik, olusturma: p.olusturma,
      degisiklik: p.degisiklik || '', menuler: paylasimMenuleri_(p), maliDetay: p.maliDetay === true, link: paylasimLinki_(p),
      bitis: p.bitis || '', suresiDoldu: paylasimSuresiDoldu_(p), sonErisim: p.sonErisim || '', erisimSayisi: p.erisimSayisi || 0 };
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
    var p = { id: Utilities.getUuid().slice(0, 8), etiket: etiket, yetki: yetki, acik: true, olusturma: simdi, bitis: bitisGunu_(g.sure),
      menuler: g.menuler !== undefined && g.menuler !== '' ? menuSecimi_(g) : ['tarla'],
      anahtar: 'p' + Utilities.getUuid().replace(/-/g, '') };
    l.push(p);
    paylasimKaydet_(l);
    return { ok: true, mesaj: etiket + ' için paylaşım açıldı.', paylasimlar: paylasimListesi_() };
  }
  var x = l.filter(function (p) { return p.id === g.id; })[0];
  if (!x) return { ok: false, hata: 'Paylaşım bulunamadı.' };
  if (g.tur === 'paylasimYetki') { x.yetki = yetki; }
  else if (g.tur === 'paylasimMenu') { x.menuler = menuSecimi_(g); }
  else if (g.tur === 'paylasimMali') { x.maliDetay = String(g.maliDetay) === 'true'; }
  else if (g.tur === 'paylasimSure') { x.bitis = bitisGunu_(g.sure); }
  else if (g.tur === 'paylasimYenile') { x.anahtar = 'p' + Utilities.getUuid().replace(/-/g, ''); x.sonErisim = ''; x.erisimSayisi = 0; }
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
  var v = veriTopla_(400), m = paylasimMenuleri_(pay);
  function acik() { for (var i = 0; i < arguments.length; i++) if (m.indexOf(arguments[i]) >= 0) return true; return false; }
  var o = { ok: true, surum: v.surum, olusturma: v.olusturma,
    paylasim: { kapsam: 'tarla', yetki: pay.yetki, etiket: pay.etiket, menuler: m, maliDetay: pay.maliDetay === true } };
  function al(l) { l.forEach(function (k) { o[k] = v[k]; }); }
  // KVKK: paylaşımda personel/taşeron sayıları, personel satırları ve kişi adları gönderilmez.
  if (acik('gunluk', 'haftalik', 'hayvan', 'esk')) {
    o.hayvanOzet = (v.hayvanOzet || []).map(function (r) { r = r.slice(); r[2] = 0; r[3] = 0; return r; });
    o.hayvanGunluk = v.hayvanGunluk;
    o.hayvanDetay = (v.hayvanDetay || []).filter(function (r) { return !paylasimPersonelMi_(r[3]); });
  }
  if (acik('gunluk', 'haftalik', 'hayvan')) al(['besi']);
  if (acik('gunluk', 'haftalik')) o.tarim = v.tarim;
  else if (acik('ziraat', 'hayvan')) {
    o.tarim = (v.tarim || []).filter(function (r) { return paylasimHayvanMi_(r[2]) ? acik('hayvan') : acik('ziraat'); });
  }
  if (acik('ziraat', 'tarla')) al(['ekim', 'hasat']);
  if (acik('tarla')) al(['cks', 'ekimDuzeltme', 'sezonParsel', 'ekimPlani', 'sezonParselSiniri', 'parselSinir', 'resmiParsel', 'tarlaSezonlari']);
  if (acik('esk')) al(['eskAylik', 'eskBilgi']);
  if (acik('urun')) al(['tarimsalUretim', 'urunTeslimat']);
  if (acik('gecmis', 'hastalik')) al(['gecmis', 'dersler']);
  if (acik('mali')) o.mali = paylasimMali_(v.mali, pay.maliDetay === true);
  if (acik('arac')) {
    al(['aracListe', 'aracPlan']);
    function sil(l, sut) { return (l || []).map(function (r) { r = r.slice(); sut.forEach(function (i) { if (i < r.length) r[i] = ''; }); return r; }); }
    o.aracKullanim = sil(v.aracKullanim, [3, 4, 18]);   // personel, (sicil), onaylayan
    o.aracBakim = sil(v.aracBakim, [11]);               // kaydı giren
    o.aracAriza = sil(v.aracAriza, [3, 4, 9, 14]);      // bildiren, (sicil), güncelleyen, birlikte çalışan
    o.aracIsEmri = sil(v.aracIsEmri, [3, 4, 5]);        // personel, (sicil), formen
  }
  var dos = [];
  if (acik('tarla')) dos = dos.concat(TARLA_DOSYALARI_);
  if (acik('ciftlikRapor')) dos = dos.concat(['ciftlik_rapor_2026', 'maliyet_takip_2026']);
  if (acik('hastalik')) dos.push('hastalik');
  if (acik('sureme')) dos.push('uygulamalar');
  o.dosyalar = uygulamaDosyalari_(dos);
  if (acik('bakim')) o.bakimOnarim = (v.bakimOnarim || []).map(function (r) { r = r.slice(); r[3] = ''; return r; }); // bildiren
  return o;
}

function paylasimPersonelMi_(g) {
  var k = String(g || '').replace(/İ/g, 'i').replace(/I/g, 'ı').toLowerCase();
  return ['personel', 'pers.', 'işçi', 'isci', 'taşeron', 'taseron', 'güvenlik'].some(function (x) { return k.indexOf(x) >= 0; });
}

function paylasimHayvanMi_(f) {
  var x = String(f || '').toLowerCase().replace(/̇/g, '').replace(/ı/g, 'i').replace(/ğ/g, 'g').replace(/ş/g, 's').replace(/ö/g, 'o').replace(/ü/g, 'u').replace(/ç/g, 'c');
  return ['sagim', 'sagmal', 'buzag', 'inek', 'duve', 'dana', 'boga', 'besi', 'kesim', 'asilama', 'tohumlama', 'suni tohum', 'dogum', 'veteriner',
    'mastitis', 'kupe', 'ahir', 'agil', 'padok', 'tirnak', 'rasyon', 'hayvan'].some(function (k) { return x.indexOf(k) >= 0; });
}

function maliSayi_(v) {
  if (typeof v === 'number') return v;
  var x = String(v === null || v === undefined ? '' : v).replace(/\s/g, '');
  if (!x) return null;
  if (x.indexOf(',') >= 0) x = x.replace(/\./g, '').replace(',', '.'); else if (/^-?\d{1,3}(\.\d{3})+$/.test(x)) x = x.replace(/\./g, '');
  var n = parseFloat(x); return isNaN(n) ? null : n;
}

/** Mali Raporlar paylaşımı. Detaylı: fatura bazında (Drive dosya bağlantıları çıkarılır).
 * Özet: tedarikçi bilgisi olmadan ay / birim / hesap / kategori toplamları; kontrol bulguları gönderilmez. */
function paylasimMali_(mali, detay) {
  if (!mali) return null;
  var o = JSON.parse(JSON.stringify(mali));
  if (o.muhasebeBilgi) o.muhasebeBilgi.link = '';
  if (detay) {
    o.kontrol = (o.kontrol || []).map(function (r) { r = r.slice(); if (r.length > 5) r[5] = ''; if (r.length > 7) r[7] = ''; return r; });
    return o;
  }
  function topla(l) {
    var m = {}, sira = [];
    (l || []).forEach(function (r) {
      var ay = String(r[0] || '').slice(0, 7);
      if (!ay) return;
      var k = [ay, r[1], r[2], r[3], r[6], r[8]].join('|');
      if (!m[k]) { m[k] = [ay + '-01', r[1], r[2], r[3], 'Özet (tedarikçi bilgisi yok)', 0, r[6], '', r[8], '', '', '']; sira.push(k); }
      var t = maliSayi_(r[5]); if (t !== null) m[k][5] += t;
    });
    return sira.map(function (k) { return m[k]; });
  }
  o.fatura = topla(o.fatura);
  o.muhasebe = topla(o.muhasebe);
  var a = {}, as = [];
  (o.acik || []).forEach(function (r) {
    var ay = String(r[0] || '').slice(0, 7), k = [ay, r[1], r[2]].join('|');
    if (!a[k]) { a[k] = [ay + '-01', r[1], r[2], 'Özet', 0, '', '', '']; as.push(k); }
    var t = maliSayi_(r[4]); if (t !== null) a[k][4] += t;
  });
  o.acik = as.map(function (k) { return a[k]; });
  o.kontrol = [];
  return o;
}

/** Paylaşım linkiyle gelen işlem: yalnızca düzenleme yetkisinde, yalnızca tarla kayıtları. */
function paylasimIslem_(pay, g) {
  if (!menuAcik_(pay, 'tarla')) return { ok: false, hata: 'Tarla Haritaları bu paylaşımda açık değil.' };
  var izinli = ['sezonParsel', 'sezonParselGeriAl', 'parselSinir', 'parselSinirGeriAl', 'tarlaSezonEkle', 'cksYukle'];
  if (izinli.indexOf(g.tur) < 0) return { ok: false, hata: 'Bu işlem paylaşımda yapılamaz.' };
  if (pay.yetki !== 'duzenle') return { ok: false, hata: 'Bu paylaşımda yalnızca görüntüleme yetkisi var.' };
  // Düzenleme yetkili paylaşım yeni sezon açabilir (kaldırma yalnızca sahibindedir). Uzak yıllar açılamaz.
  if (g.tur === 'tarlaSezonEkle') {
    var m = /^(\d{4})-(\d{4})$/.exec(String(g.sezon || '').trim());
    if (m && +m[1] > new Date().getFullYear() + 1) return { ok: false, hata: 'Yalnızca bir sonraki sezon açılabilir.' };
    return tarlaSezon_({ tur: 'tarlaSezonEkle', sezon: g.sezon });
  }
  // ÇKS belgesi: dosya kapalı "ÇKS Belgeleri" klasörüne konur; paylaşılan kişi klasörü görmez.
  if (g.tur === 'cksYukle') return cksYukle_({ veri: g.veri, mime: g.mime, sezon: g.sezon });
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
var VET_ARSIV_ID = '1pqRQEViMwHcoGC_X0MizSsB6kfd6_BAz'; // 26.11.2026: Drive Sağlık Raporları, günlük kırılımlı (araclar/hastalik/olustur.py)

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
  var k = 'dosya_hastalik_' + vetArsivId_(), m = parcaliOku_(cache, k);
  if (!m) {
    m = DriveApp.getFileById(vetArsivId_()).getBlob().getDataAsString('UTF-8');
    parcaliYaz_(cache, k, m);
  }
  var j = JSON.parse(m);
  delete j.gunluk; // Veteriner Paneli aylık kaydı kullanır
  return j;
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
var TARLA_PANEL_HTML_ = "<!DOCTYPE html>\n<html lang=\"tr\">\n<head>\n<meta charset=\"utf-8\">\n<base target=\"_top\">\n<title>Tarım ve Hayvancılık</title>\n<style>\n  :root { --mavi:#1d4ed8; --soluk:#64748b; --amber:#b45309; --kenar:#e2e8f0; }\n  * { box-sizing: border-box; }\n  body { margin:0; font-family: system-ui, -apple-system, \"Segoe UI\", Roboto, sans-serif; color:#0f172a; background:#f8fafc; }\n  header { background:#3D7A55; color:#fff; position:sticky; top:0; z-index:5; }\n  .cubuk { display:flex; align-items:center; gap:8px; padding:12px 10px; }\n  .cubuk h1 { margin:0; font-size:19px; font-weight:600; flex:1; }\n  .geri { background:none; border:0; color:#fff; font-size:24px; width:40px; height:40px; cursor:pointer; }\n  #ust { font-size:12px; opacity:.85; padding:0 14px 8px; }\n  .sekmeler { display:flex; overflow-x:auto; }\n  .sekme { flex:1; text-align:center; padding:10px 12px 12px; font-size:15px; color:rgba(255,255,255,.75); cursor:pointer; white-space:nowrap;\n    border-bottom:3px solid transparent; }\n  .sekme.secili { color:#fff; font-weight:700; border-bottom-color:#fff; }\n  .menu { display:flex; align-items:center; gap:14px; background:#f1f5f0; border:1px solid var(--kenar); border-radius:14px; padding:14px;\n    margin-bottom:10px; cursor:pointer; box-shadow:0 1px 2px rgba(0,0,0,.06); }\n  .menu .ik { width:46px; height:46px; border-radius:23px; background:#e3efe6; display:flex; align-items:center; justify-content:center;\n    font-size:22px; color:#14532d; flex:none; }\n  .menu b { display:block; font-size:16.5px; }\n  .menu span { font-size:13.5px; color:var(--soluk); }\n  .menu .ok { margin-left:auto; color:var(--soluk); font-size:22px; }\n  h3 { font-size:15px; color:#14532d; margin:14px 2px 6px; }\n  .rozet { display:inline-block; background:#dbeafe; color:#1d4ed8; font-weight:700; font-size:12px; border-radius:6px; padding:2px 8px; margin:3px 4px 0 0; }\n  .sag { text-align:right; } .yesil { color:#15803D; font-weight:800; } .amb { color:var(--amber); font-weight:800; }\n  main { max-width:1100px; margin:0 auto; padding:10px 12px 40px; }\n  .cipler { display:flex; gap:6px; overflow-x:auto; padding:4px 0 8px; }\n  .cip { border:1px solid var(--kenar); background:#fff; border-radius:16px; padding:6px 12px; font-size:13.5px; white-space:nowrap; cursor:pointer; }\n  .cip.secili { background:#14532d; color:#fff; border-color:#14532d; }\n  .kart { background:#fff; border:1px solid var(--kenar); border-radius:12px; padding:10px; margin-bottom:10px; }\n  .bilgi { background:#eff6ff; border:1px solid #bfdbfe; border-radius:10px; padding:8px 10px; font-size:13px; margin-bottom:10px; }\n  .uyari { color:var(--amber); font-size:12.5px; }\n  #haritaKap { position:relative; overflow:hidden; border-radius:10px; background:#eef2ee; width:100%; aspect-ratio:0.82;\n    max-height:78vh; touch-action:none; user-select:none; -webkit-user-select:none; }\n  #haritaKap.tam { position:fixed; inset:0; z-index:9; border-radius:0; max-height:none; aspect-ratio:auto; }\n  #harita, #yazilar { position:absolute; inset:0; width:100%; height:100%; display:block; }\n  #yazilar { pointer-events:none; }\n  .araclar { position:absolute; right:6px; top:6px; display:flex; flex-direction:column; gap:6px; z-index:2; }\n  .araclar button { width:40px; height:40px; border-radius:20px; border:1px solid var(--kenar); background:#fff; font-size:18px;\n    box-shadow:0 1px 3px rgba(0,0,0,.15); }\n  .ipucu { font-size:12px; color:var(--soluk); margin-top:6px; }\n  .solust { position:absolute; left:6px; top:6px; z-index:2; }\n  .solust button { height:40px; min-width:40px; border-radius:20px; border:1px solid var(--kenar); background:#fff; font-size:15px; padding:0 12px;\n    box-shadow:0 1px 3px rgba(0,0,0,.15); }\n  .solust button.etkin { background:#14532d; color:#fff; }\n  #cizimPanel { position:absolute; left:8px; right:8px; bottom:8px; background:#fff; border-radius:12px; padding:10px; z-index:3;\n    box-shadow:0 2px 8px rgba(0,0,0,.25); font-size:13px; max-height:45%; overflow:auto; }\n  #cizimPanel .cip { padding:5px 10px; font-size:13px; }\n  .kucukDugmeler { display:flex; flex-wrap:wrap; gap:6px; margin-top:8px; }\n  .kucukDugmeler button { border:1px solid #cbd5e1; background:#fff; border-radius:8px; padding:7px 10px; font-size:13.5px; }\n  .kucukDugmeler button.ana { background:#14532d; color:#fff; border-color:#14532d; }\n  .palet { display:flex; flex-wrap:wrap; gap:8px; margin-top:8px; }\n  .palet span { width:34px; height:34px; border-radius:8px; cursor:pointer; border:2px solid #fff; box-shadow:0 0 0 1px #cbd5e1; }\n  .lejant span { cursor:pointer; }\n  .secim label { display:flex; align-items:center; gap:8px; font-size:14px; color:#0f172a; margin:6px 0; }\n  .secim input[type=checkbox], .secim input[type=radio] { width:20px; height:20px; }\n  .lejant { display:flex; flex-wrap:wrap; gap:6px 12px; font-size:12.5px; margin-top:8px; }\n  .lejant span i { display:inline-block; width:12px; height:12px; border-radius:3px; margin-right:4px; vertical-align:-1px; }\n  table { width:100%; border-collapse:collapse; font-size:13px; }\n  td, th { border-bottom:1px solid var(--kenar); padding:6px 4px; text-align:left; vertical-align:top; }\n  tr.tik { cursor:pointer; }\n  #perde { position:fixed; inset:0; background:rgba(15,23,42,.45); display:none; z-index:10; }\n  #sayfa { position:fixed; left:0; right:0; bottom:0; max-height:88vh; overflow:auto; background:#fff; border-radius:16px 16px 0 0;\n           padding:14px 14px 24px; display:none; z-index:11; max-width:640px; margin:0 auto; }\n  #sayfa h2 { margin:0 0 2px; font-size:17px; }\n  label { display:block; font-size:12.5px; color:var(--soluk); margin-top:8px; }\n  select, input { width:100%; font-size:15px; padding:8px; border:1px solid #cbd5e1; border-radius:8px; background:#fff; }\n  .parca { border:1px solid var(--kenar); border-radius:10px; padding:8px; margin-top:8px; }\n  .satir { display:flex; gap:8px; } .satir > * { flex:1; }\n  .dugmeler { display:flex; gap:8px; flex-wrap:wrap; margin-top:14px; }\n  button.ana { background:#14532d; color:#fff; border:0; border-radius:10px; padding:10px 16px; font-size:15px; }\n  button.ikinci { background:#fff; color:#0f172a; border:1px solid #cbd5e1; border-radius:10px; padding:10px 16px; font-size:15px; }\n  button:disabled { opacity:.5; }\n  #durum { position:fixed; left:50%; transform:translateX(-50%); bottom:16px; background:#0f172a; color:#fff; padding:8px 14px;\n           border-radius:10px; font-size:13.5px; display:none; z-index:20; max-width:92vw; }\n  .gizgara { display:grid; grid-template-columns:repeat(auto-fill,minmax(150px,1fr)); gap:10px; margin-bottom:10px; }\n  .gk { background:#fff; border:1px solid var(--kenar); border-radius:12px; padding:10px 12px; }\n  .gk span { display:block; font-size:12.5px; color:var(--soluk); } .gk b { display:block; font-size:20px; margin-top:2px; } .gk i { display:block; font-style:normal; font-size:11.5px; color:var(--soluk); margin-top:2px; }\n  select { margin-bottom:8px; }\n  .yukleniyor { padding:40px; text-align:center; color:var(--soluk); }\n</style>\n</head>\n<body>\n<header><div class=\"cubuk\"><button class=\"geri\" id=\"geri\" onclick=\"geri()\" style=\"visibility:hidden\">←</button><h1 id=\"baslik\">Tarım ve Hayvancılık</h1></div>\n<div id=\"ust\">Yükleniyor…</div><div class=\"sekmeler\" id=\"sekmeler\"></div></header>\n<main>\n  <div id=\"icerik\" class=\"yukleniyor\">Harita yükleniyor…</div>\n</main>\n<div id=\"perde\" onclick=\"kapat()\"></div>\n<div id=\"sayfa\"></div>\n<div id=\"durum\"></div>\n<script>\nvar ANAHTAR = __ANAHTAR__;\n// Harita dosyaları sunucudan, paylaşım anahtarıyla gelir (depoda bulunmaz).\nvar DOSYALAR = ['tarla_2025_2026', 'tarla_2024_2025', 'tarla_2026_2027'];\nvar SINIR = 400;\nvar URUNLER = ['Buğday', 'Arpa', 'Tritikale', 'Çavdar', 'Yulaf', 'Dane mısır', 'Şeker pancarı', 'Patates', 'Soğan',\n  'Yağlık ayçiçeği', 'Çerezlik ayçiçeği', 'Kanola (kolza)', 'Aspir', 'Soya', 'Nohut', 'Kuru fasulye', 'Mercimek',\n  'Silajlık mısır', 'Silajlık mısır (2. ürün)', 'Yonca', 'Korunga', 'Fiğ', 'Silajlık sorgum', 'Sudan otu', 'Kimyon', 'Kişniş',\n  'Nadas', 'Deneme alanı', 'Islah edilen alan', 'Ağaçlık alan', 'Boş alan'];\nvar RENK = { 'Buğday':'#E0A526','Arpa':'#C9B458','Şeker pancarı':'#8E3B8A','Silajlık mısır':'#3F9142','Silajlık mısır (2. ürün)':'#7CC47F',\n  'Yonca':'#1E7FA8','Patates':'#A0522D','Soğan':'#B8860B','Dane mısır':'#F4D03F','Yağlık ayçiçeği':'#F1C40F','Çerezlik ayçiçeği':'#D4AC0D',\n  'Kanola (kolza)':'#E5E85C','Aspir':'#E67E22','Soya':'#7DAA5A','Nohut':'#D7B98E','Kuru fasulye':'#B05A4A','Mercimek':'#C8743A',\n  'Çavdar':'#A38B5B','Yulaf':'#D9C79E','Tritikale':'#BFA76A','Korunga':'#C2185B','Fiğ':'#6C7A3A','Silajlık sorgum':'#5E8C31',\n  'Sudan otu':'#8BC34A','Kimyon':'#9E7C5A','Kişniş':'#7FA67F','Nadas':'#B8A88A','Deneme alanı':'#00BCD4','Islah edilen alan':'#795548',\n  'Ağaçlık alan':'#2E7D32','Boş alan':'#D6D6D6' };\n\nvar S = { paket: [], sezonParsel: [], parselSinir: [], ekim: [], ekimPlani: [], cks: [], yetki: 'gor', etiket: '', sezon: null, ciftlik: null,\n  yazi: true, ekran: 'kok', sekme: 'harita', pCiftlik: null, tam: false };\n\n// ---------- yardımcılar ----------\nfunction kucuk(s) { return String(s || '').replace(/İ/g, 'i').replace(/I/g, 'ı').toLowerCase(); }\nfunction ciftlikAnahtari(c) {\n  var k = kucuk(c);\n  if (k.indexOf('ormanlık') >= 0) return 'taşağıl';\n  var l = ['şekersüt', 'aslım', 'taşağıl', 'fidanlık', 'pangev', 'pankent'];\n  for (var i = 0; i < l.length; i++) if (k.indexOf(l[i]) >= 0) return l[i];\n  return k;\n}\nfunction urunAnahtari(u) {\n  var k = kucuk(u);\n  if (k.indexOf('2. ürün') >= 0) return 'Silajlık mısır (2. ürün)';\n  if (k.indexOf('pancar') >= 0) return 'Şeker pancarı';\n  if (k.indexOf('dane mısır') >= 0 || k.indexOf('danelik mısır') >= 0) return 'Dane mısır';\n  if (k.indexOf('mısır') >= 0) return 'Silajlık mısır';\n  if (k.indexOf('çerez') >= 0) return 'Çerezlik ayçiçeği';\n  if (k.indexOf('ayçiçe') >= 0) return 'Yağlık ayçiçeği';\n  if (k.indexOf('kanola') >= 0 || k.indexOf('kolza') >= 0) return 'Kanola (kolza)';\n  if (k.indexOf('sorgum') >= 0) return 'Silajlık sorgum';\n  var l = [['buğday','Buğday'],['arpa','Arpa'],['yonca','Yonca'],['patates','Patates'],['soğan','Soğan'],['tritikale','Tritikale'],\n    ['deneme','Deneme alanı'],['ıslah','Islah edilen alan'],['ağaç','Ağaçlık alan'],['boş alan','Boş alan'],['nadas','Nadas']];\n  for (var i = 0; i < l.length; i++) if (k.indexOf(l[i][0]) >= 0) return l[i][1];\n  if (k === 'boş') return 'Boş alan';\n  return u;\n}\nvar OZEL_RENK = (function () { try { return JSON.parse(localStorage.getItem('tarla_urun_renkleri') || '{}'); } catch (e) { return {}; } })();\nfunction renk(u) { var k = urunAnahtari(u); return OZEL_RENK[k] || RENK[k] || '#6D8B74'; }\nvar PALET = ['#E0A526','#F4D03F','#C9B458','#D35400','#C0392B','#E91E63','#8E3B8A','#6C3483','#1E7FA8','#00BCD4','#1ABC9C','#3F9142','#7CC47F','#827717','#A0522D','#5D4037','#607D8B','#212121'];\nfunction renkSec(u) {\n  sayfaAc('<h2>' + esc(u) + ' rengi</h2><div class=\"palet\">' + PALET.map(function (r) { return '<span style=\"background:' + r + '\" onclick=\"renkKaydet(' + js(u) + ',\\'' + r + '\\')\"></span>'; }).join('') +\n    '</div><div class=\"dugmeler\"><button class=\"ikinci\" onclick=\"renkKaydet(' + js(u) + ',null)\">Varsayılan renk</button><button class=\"ikinci\" onclick=\"kapat()\">Kapat</button></div>');\n}\nfunction renkKaydet(u, r) { if (r) OZEL_RENK[u] = r; else delete OZEL_RENK[u]; try { localStorage.setItem('tarla_urun_renkleri', JSON.stringify(OZEL_RENK)); } catch (e) {} kapat(); ciz(); }\nfunction kisa(u) { var k = urunAnahtari(u); if (k.indexOf('Silajlık mısır') === 0) return k.indexOf('2.') >= 0 ? 'Mısır (2. ürün)' : 'Mısır'; if (k === 'Şeker pancarı') return 'Pancar'; return u; }\nfunction sayi(v) { return (Math.round(v * 10) / 10).toLocaleString('tr-TR'); }\nfunction esc(s) { return String(s == null ? '' : s).replace(/[&<>\"']/g, function (c) { return { '&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;',\"'\":'&#39;' }[c]; }); }\nfunction sayiOku(v) { if (v === '' || v == null) return null; if (typeof v === 'number') return v; var x = parseFloat(String(v).replace(/\\./g, '').replace(',', '.')); return isNaN(x) ? null : x; }\nfunction sonrakiSezon(s) { var m = /^(\\d{4})-(\\d{4})$/.exec(s); return m ? (+m[1] + 1) + '-' + (+m[2] + 1) : s; }\nfunction oncekiSezon(s) { var m = /^(\\d{4})-(\\d{4})$/.exec(s); return m ? (+m[1] - 1) + '-' + (+m[2] - 1) : s; }\nfunction durum(t) { var d = document.getElementById('durum'); d.textContent = t; d.style.display = 'block'; clearTimeout(durum.z); durum.z = setTimeout(function () { d.style.display = 'none'; }, 3500); }\n\n// ---------- Sezon_Parselleri \"Ürün\" metni ----------\nfunction urunCesit(s) { var i = s.indexOf('#'); return i < 0 ? [s.trim(), null] : [s.slice(0, i).trim(), s.slice(i + 1).trim()]; }\nfunction icerikOku(t) {\n  t = String(t || '').trim();\n  var at = t.indexOf('@');\n  if (at > 0 && t.indexOf(':') < 0) { var uc = urunCesit(t.slice(0, at)); return { parcalar: [[uc[0], null]], birlesik: t.slice(at + 1).trim(), cizgiler: [], baglar: [], cesitler: [uc[1]], bolgeler: [] }; }\n  if (t.indexOf(':') < 0) { var u = urunCesit(t); return { parcalar: [[u[0], null]], cizgiler: [], baglar: [], cesitler: [u[1]], bolgeler: [] }; }\n  var bolu = t.indexOf('/'), govde = bolu < 0 ? t : t.slice(0, bolu), ek = bolu < 0 ? '' : t.slice(bolu + 1);\n  var bolgeler = [], cizgiler = [];\n  if (ek.charAt(0) === 'B') {\n    ek.slice(1).split(';').forEach(function (b) {\n      if (b.length > 1 && 'DCP'.indexOf(b[0]) >= 0) bolgeler.push([b[0], b.slice(1).split(',').map(parseFloat).filter(function (x) { return !isNaN(x); })]);\n    });\n  } else if (ek) {\n    ek.split(';').forEach(function (c) { var a = c.split(','); if (a.length === 2 && !isNaN(parseFloat(a[0])) && !isNaN(parseFloat(a[1]))) cizgiler.push([parseFloat(a[0]), parseFloat(a[1])]); });\n  }\n  var parcalar = [], baglar = [], cesitler = [];\n  govde.split('+').forEach(function (x) {\n    if (!x.trim()) return;\n    var ad = x.split(':')[0].trim(), ok = ad.indexOf('>');\n    var uc = urunCesit(ok > 0 ? ad.slice(0, ok) : ad);\n    var da = x.indexOf(':') >= 0 ? parseFloat(x.split(':').pop().trim().replace(',', '.')) : null;\n    parcalar.push([uc[0], isNaN(da) ? null : da]); baglar.push(ok > 0 ? ad.slice(ok + 1).trim() : null); cesitler.push(uc[1]);\n  });\n  return { parcalar: parcalar, cizgiler: cizgiler, baglar: baglar, cesitler: cesitler, bolgeler: bolgeler };\n}\nfunction urunMetni(u, c) { return c && c.trim() ? u + '#' + c.trim() : u; }\nfunction sayiYaz(v) { return v % 1 === 0 ? String(v) : String(v); }\nfunction bolunmusMetin(l, cizgiler, baglar, cesitler, bolgeler) {\n  var g = l.map(function (x, i) { return urunMetni(x[0], cesitler[i]) + (baglar[i] ? '>' + baglar[i] : '') + ':' + sayiYaz(x[1]); }).join('+');\n  if (bolgeler && bolgeler.length) return g + '/B' + bolgeler.map(function (b) { return b[0] + b[1].map(function (x) { return Math.round(x); }).join(','); }).join(';');\n  if (cizgiler && cizgiler.length) return g + '/' + cizgiler.map(function (c) { return Math.round(c[0]) + ',' + Math.round(c[1]); }).join(';');\n  return g;\n}\n\n// ---------- sezonlar (uygulamadaki mantıkla) ----------\nfunction parselOku(j) {\n  return { ad: j.ad || '', tip: j.tip || '', not: j.not_ || '', beyan: j.beyan == null ? null : j.beyan,\n    urunler: (j.urunler || []).map(function (u) { return Array.isArray(u) ? [u[0], u.length > 1 ? +u[1] : 0] : [String(u), 0]; }),\n    koord: (j.koord || []).map(function (c) { return [+c[0], +c[1]]; }), cesitler: j.cesitler || [], bolgeler: j.bolgeler || [], bolme: [], baglar: [] };\n}\nfunction sezonOku(j) {\n  return { sezon: j.sezon, kaynak: j.kaynak || '', tur: j.tur || 'kmz', giris: false,\n    ciftlikler: (j.ciftlikler || []).map(function (c) { return { ad: c.ad, gorseller: c.gorseller || [], parseller: (c.parseller || []).map(parselOku) }; }) };\n}\nfunction parselGirisi(sezon, cf, parsel) {\n  var d = null;\n  S.sezonParsel.forEach(function (r) {\n    if (String(r[0]) === sezon && ciftlikAnahtari(r[1]) === ciftlikAnahtari(cf) && kucuk(r[2]).trim() === kucuk(parsel).trim()) {\n      if (r[6] === 'Aktif') d = { urun: String(r[3]), alan: sayiOku(r[4]) }; else if (r[6] === 'Geri alındı') d = null;\n    }\n  });\n  return d;\n}\nfunction kopya(p, ek) { var o = {}; for (var k in p) o[k] = p[k]; for (var k2 in ek) o[k2] = ek[k2]; return o; }\nfunction girisParseli(p, g, bagli, gelen) {\n  var ic = icerikOku(g.urun), y;\n  if (ic.birlesik) y = kopya(p, { tip: 'ekili', urunler: [[ic.parcalar[0][0], 0]], beyan: null, not: ic.birlesik + ' ile birleştirildi', cesitler: ic.cesitler, bolme: [], bolgeler: [], baglar: [], birlesik: ic.birlesik });\n  else if (ic.parcalar.length > 1) {\n    var l = ic.parcalar.map(function (x) { return [x[0], x[1] || 0]; }), giden = 0, top = 0;\n    l.forEach(function (x, i) { top += x[1]; if (ic.baglar[i]) giden += x[1]; });\n    y = kopya(p, { tip: 'ekili', urunler: l, beyan: giden > 0 ? top - giden : (g.alan != null ? g.alan : top), not: 'Parçalara bölündü',\n      bolme: ic.cizgiler.length === l.length - 1 ? ic.cizgiler : [], baglar: ic.baglar, cesitler: ic.cesitler,\n      bolgeler: ic.bolgeler.length === l.length - 1 ? ic.bolgeler : [] });\n  } else y = kopya(p, { tip: 'ekili', urunler: [[ic.parcalar[0][0], g.alan || 0]], beyan: g.alan, cesitler: ic.cesitler, bolme: [], bolgeler: [], baglar: [],\n      not: bagli.length ? bagli.join(', ') + ' ile birleştirildi (alan toplamdır)' : '' });\n  if (gelen.length) {\n    var ek = 0; gelen.forEach(function (x) { ek += x[2]; });\n    y.beyan = (y.beyan || 0) + ek;\n    y.not = [y.not, gelen.map(function (x) { return x[0] + ' parselinden ' + x[1] + ' ' + sayi(x[2]) + ' da'; }).join(', ')].filter(Boolean).join(' · ');\n  }\n  y.giris = true;\n  return y;\n}\nfunction kmzNotu(y) { return y; } // KMZ ile farklılıkta uygulama kaydı geçerlidir\nfunction katmanda(katman, cf, ad) {\n  if (!katman) return null;\n  for (var i = 0; i < katman.ciftlikler.length; i++) {\n    var c = katman.ciftlikler[i]; if (c.ad !== cf) continue;\n    for (var j = 0; j < c.parseller.length; j++) if (c.parseller[j].ad === ad) return c.parseller[j];\n  }\n  return null;\n}\nfunction girisSezonu(taban, ad, katman) {\n  return { sezon: ad, giris: true, tur: katman ? katman.tur : 'giris', kaynak: (katman ? katman.kaynak + ' + ' : '') + 'haritadan girilen bilgiler',\n    ciftlikler: taban.ciftlikler.map(function (c) {\n      return { ad: c.ad, gorseller: c.gorseller, parseller: c.parseller.map(function (p) {\n        var g = parselGirisi(ad, c.ad, p.ad), k = katmanda(katman, c.ad, p.ad);\n        if (g) {\n          var bagli = [], gelen = [];\n          c.parseller.forEach(function (q) {\n            if (q.ad === p.ad) return;\n            var h = parselGirisi(ad, c.ad, q.ad); if (!h) return;\n            var ic = icerikOku(h.urun);\n            if (ic.birlesik === p.ad) bagli.push(q.ad);\n            ic.parcalar.forEach(function (x, i) { if (ic.baglar[i] === p.ad) gelen.push([q.ad, x[0], x[1] || 0]); });\n          });\n          return kmzNotu(girisParseli(p, g, bagli, gelen), k);\n        }\n        if (k && k.urunler.length) {\n          var top = 0; k.urunler.forEach(function (u) { top += u[1]; });\n          return kopya(p, { tip: k.tip === 'girilmedi' || !k.tip ? 'parsel' : k.tip, urunler: k.urunler, beyan: top, not: k.not,\n            cesitler: k.cesitler, bolgeler: k.bolgeler.length === k.urunler.length - 1 ? k.bolgeler : [], bolme: [], baglar: [] });\n        }\n        return kopya(p, { tip: p.tip === 'diger' || p.tip === 'bos' ? p.tip : 'girilmedi', urunler: [], beyan: null, not: '', cesitler: [], bolgeler: [], bolme: [], baglar: [] });\n      }) };\n    }) };\n}\nfunction kmzUzerine(kmz) {\n  return { sezon: kmz.sezon, giris: false, tur: 'kmz', kaynak: kmz.kaynak, ciftlikler: kmz.ciftlikler.map(function (c) {\n    return { ad: c.ad, gorseller: c.gorseller, parseller: c.parseller.map(function (p) {\n      var g = parselGirisi(kmz.sezon, c.ad, p.ad);\n      if (g && (icerikOku(g.urun).parcalar.length > 1 || p.tip === 'girilmedi')) {\n        var y = girisParseli(p, g, [], []);\n        return kopya(y, { tip: p.tip === 'girilmedi' ? y.tip : p.tip, beyan: p.beyan != null ? p.beyan : y.beyan, giris: false });\n      }\n      return p;\n    }) };\n  }) };\n}\nfunction sinirUygula(kmz, sezon) {\n  var m = {};\n  S.parselSinir.forEach(function (r) {\n    var ad = String(r[1]);\n    if (sezon ? ad.indexOf(sezon + '|') !== 0 : ad.indexOf('|') >= 0) return;\n    if (sezon) ad = ad.slice(sezon.length + 1);\n    var key = r[0] + '|' + ad;\n    if (r[4] === 'Aktif') {\n      var k = String(r[2] || '').trim().split(/\\s+/).map(function (n) { var a = n.split(','); return [parseFloat(a[0]), parseFloat(a[1])]; })\n        .filter(function (c) { return !isNaN(c[0]) && !isNaN(c[1]); });\n      if (k.length > 2) m[key] = k;\n    } else if (r[4] === 'Geri alındı') delete m[key];\n  });\n  return kopya(kmz, { ciftlikler: kmz.ciftlikler.map(function (c) {\n    var l = c.parseller.map(function (p) { return m[c.ad + '|' + p.ad] ? kopya(p, { koord: m[c.ad + '|' + p.ad] }) : p; });\n    Object.keys(m).forEach(function (key) {\n      var i = key.indexOf('|'), cf = key.slice(0, i), ad = key.slice(i + 1); if (cf !== c.ad) return;\n      if (!c.parseller.some(function (p) { return p.ad === ad; }))\n        l.push({ ad: ad, tip: 'girilmedi', urunler: [], koord: m[key], not: 'Haritadan eklendi', cesitler: [], bolgeler: [], bolme: [], baglar: [] });\n    });\n    return { ad: c.ad, gorseller: c.gorseller, parseller: l };\n  }) });\n}\nfunction sezonlar() {\n  var kmz = S.paket.filter(function (k) { return k.tur === 'kmz'; })[0];\n  if (!kmz) return [];\n  kmz = sinirUygula(kmz);\n  function bul(s, t) { return S.paket.filter(function (k) { return k.sezon === s && k.tur === t; })[0]; }\n  var s1 = oncekiSezon(kmz.sezon), s3 = sonrakiSezon(kmz.sezon), ayri = bul(oncekiSezon(s1), 'ayri');\n  if (ayri) ayri = kopya(sinirUygula(ayri, ayri.sezon), { tur: 'ayri' });\n  var l = [];\n  if (ayri) l.push(girisSezonu(ayri, ayri.sezon, ayri));\n  l.push(girisSezonu(kmz, s1, bul(s1, 'katman')));\n  l.push(kmzUzerine(kmz));\n  l.push(girisSezonu(kmz, s3, bul(s3, 'katman')));\n  // Uygulamada \"Yeni sezon ekle\" ile açılan sezonlar ve kaydı bulunan sonraki sezonlar\n  var aday = (S.tarlaSezonlari || []).concat(S.sezonParsel.map(function (r) { return String(r[0]); }))\n    .filter(function (x) { return /^\\d{4}-\\d{4}$/.test(x) && x > s3; }).sort();\n  if (aday.length) for (var s = sonrakiSezon(s3); s <= aday[aday.length - 1]; s = sonrakiSezon(s)) l.push(girisSezonu(kmz, s, bul(s, 'katman')));\n  return l;\n}\n\n// ---------- geometri ----------\nfunction alan(k) { var a = 0; for (var i = 0; i < k.length; i++) { var p = k[i], q = k[(i + 1) % k.length]; a += p[0] * q[1] - q[0] * p[1]; } return Math.abs(a) / 2; }\nfunction cizgiDenklemi(k, cz) {\n  var r = cz[0] * Math.PI / 180, nx = -Math.sin(r), ny = Math.cos(r), mn = Infinity, mx = -Infinity;\n  k.forEach(function (p) { var v = nx * p[0] + ny * p[1]; mn = Math.min(mn, v); mx = Math.max(mx, v); });\n  return [nx, ny, mn + (mx - mn) * Math.max(0, Math.min(100, cz[1])) / 100];\n}\nfunction kirp(k, d, birinci) {\n  function f(p) { var v = d[0] * p[0] + d[1] * p[1] - d[2]; return birinci ? v : -v; }\n  var out = [];\n  for (var i = 0; i < k.length; i++) {\n    var a = k[i], b = k[(i + 1) % k.length], fa = f(a), fb = f(b);\n    if (fa <= 0) out.push(a);\n    if ((fa < 0 && fb > 0) || (fa > 0 && fb < 0)) { var t = fa / (fa - fb); out.push([a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1])]); }\n  }\n  return out;\n}\nfunction parcala(k, cizgiler) {\n  var d = cizgiler.map(function (c) { return cizgiDenklemi(k, c); }), l = [];\n  for (var i = 0; i <= d.length; i++) { var p = k; if (i > 0) p = kirp(p, d[i - 1], false); if (i < d.length) p = kirp(p, d[i], true); l.push(p); }\n  return l;\n}\nfunction otomatikCizgiler(k, dekarlar) {\n  var top = dekarlar.reduce(function (a, b) { return a + b; }, 0);\n  var oran = dekarlar.map(function (d) { return top > 0 ? d / top : 1 / dekarlar.length; }), tum = alan(k), l = [], bir = 0;\n  for (var i = 0; i < oran.length - 1; i++) {\n    bir += oran[i]; var a = 0, b = 100;\n    for (var j = 0; j < 30; j++) { var m = (a + b) / 2, p = kirp(k, cizgiDenklemi(k, [90, m]), true); if ((p.length < 3 ? 0 : alan(p)) / tum < bir) a = m; else b = m; }\n    l.push([90, (a + b) / 2]);\n  }\n  return l;\n}\nfunction kutu(k) { var xs = k.map(function (e) { return e[0]; }), ys = k.map(function (e) { return e[1]; });\n  return [Math.min.apply(null, xs), Math.min.apply(null, ys), Math.max.apply(null, xs), Math.max.apply(null, ys)]; }\nfunction bolgePoligon(k, b) {\n  var q = kutu(k), w = q[2] - q[0], h = q[3] - q[1], v = b[1];\n  function n(px, py) { return [q[0] + px / 100 * w, q[1] + py / 100 * h]; }\n  if (b[0] === 'D' && v.length >= 4) return [n(v[0], v[1]), n(v[2], v[1]), n(v[2], v[3]), n(v[0], v[3])];\n  if (b[0] === 'C' && v.length >= 4) { var l = []; for (var i = 0; i < 48; i++) l.push(n(v[0] + v[2] * Math.cos(i * Math.PI / 24), v[1] + v[3] * Math.sin(i * Math.PI / 24))); return l; }\n  if (b[0] === 'P' && v.length >= 6) { var p = []; for (var j = 0; j + 1 < v.length; j += 2) p.push(n(v[j], v[j + 1])); return p; }\n  return [];\n}\nfunction merkez(k) { var x = 0, y = 0; k.forEach(function (p) { x += p[0]; y += p[1]; }); return [x / k.length, y / k.length]; }\n\n// ---------- Excel / ÇKS (uygulamadaki karşılaştırma mantığı) ----------\nvar EXCEL2025 = [['Şekersüt','Silajlık mısır',670],['Şekersüt','Buğday',1700],['Şekersüt','Şeker pancarı',700],['Aslım','Silajlık mısır',140],\n  ['Aslım','Şeker pancarı',900],['Aslım','Arpa',1340],['Aslım','Buğday',520],['Aslım','Tritikale',200],['Aslım','Yonca',1360],\n  ['Taşağıl','Patates',400],['Ormanlık','Şeker pancarı',230],['Fidanlık','Buğday',130],['Fidanlık','Arpa',600]];\nfunction uretimYili(s) { return s.indexOf('-') >= 0 ? s.split('-').pop() : s; }\nfunction ekle(m, k, v) { m[k] = (m[k] || 0) + v; }\nfunction sezonExcel(s, cf) {\n  var m = {};\n  if (!s.giris) { S.ekim.forEach(function (r) { var pl = sayiOku(r[2]); if (ciftlikAnahtari(r[0]) === ciftlikAnahtari(cf) && pl > 0) ekle(m, urunAnahtari(String(r[1])), pl); }); return m; }\n  S.ekimPlani.forEach(function (r) { var pl = sayiOku(r[3]); if (String(r[0]) === uretimYili(s.sezon) && ciftlikAnahtari(r[1]) === ciftlikAnahtari(cf) && pl > 0) ekle(m, urunAnahtari(String(r[2])), pl); });\n  if (Object.keys(m).length || uretimYili(s.sezon) !== '2025') return m;\n  EXCEL2025.forEach(function (x) { if (ciftlikAnahtari(x[0]) === ciftlikAnahtari(cf)) ekle(m, urunAnahtari(x[1]), x[2]); });\n  return m;\n}\nfunction excelKaynak(s) { return !s.giris ? '2026-2027 Ekim Planı (Excel)' : uretimYili(s.sezon) === '2025' ? 'Tarımsal Faaliyet › ÇİFTLİK BAZINDA, 2025 yılı (Excel)' : uretimYili(s.sezon) + ' Excel ekim planı'; }\nfunction urunToplami(c) { var m = {}; c.parseller.forEach(function (p) { p.urunler.forEach(function (u) { ekle(m, urunAnahtari(u[0]), u[1] || 0); }); }); return m; }\nfunction cksKayit(r) { return { sezon: String(r[0] || ''), ciftlik: String(r[1] || ''), mevki: String(r[2] || ''), ada: String(r[3] || ''), parsel: String(r[4] || ''),\n  urun: String(r[5] || ''), alan: sayiOku(r[6]), eslesen: String(r[7] || '') }; }\nfunction sezonCks(s, cf) { return S.cks.map(cksKayit).filter(function (x) { return x.sezon === s.sezon && ciftlikAnahtari(x.ciftlik) === ciftlikAnahtari(cf); }); }\nfunction parselCks(s, cf, ad) { return S.cks.map(cksKayit).filter(function (x) { return (!x.sezon || x.sezon === s.sezon) && ciftlikAnahtari(x.ciftlik) === ciftlikAnahtari(cf) &&\n  x.eslesen.split(',').some(function (e) { return kucuk(e).trim() === kucuk(ad).trim(); }); }); }\nfunction yakin(a, b) { return Math.abs(a - b) <= Math.max(5, b * 0.03); }\n\n// ---------- ekranlar (uygulamadaki menüler) ----------\nfunction guncelSezon() { var l = sezonlar(); return l.filter(function (x) { return x.sezon === S.sezon; })[0] || l[l.length - 1]; }\nfunction menu(ik, b, alt, tik) { return '<div class=\"menu\" onclick=\"' + tik + '\"><div class=\"ik\">' + ik + '</div><div><b>' + esc(b) + '</b><span>' + esc(alt) + '</span></div><div class=\"ok\">›</div></div>'; }\nfunction geri() {\n  if (S.tam) { tamEkran(); return; }\n  if (S.ekran === 'ciftlikParsel') S.ekran = 'sezon'; else if (S.ekran === 'ana' || S.ekran === 'ziraat' || S.ekran === 'hayvan') S.ekran = 'kok'; else S.ekran = 'ana';\n  ciz(); window.scrollTo(0, 0);\n}\nfunction git(ekran, ek) { for (var k in (ek || {})) S[k] = ek[k]; S.ekran = ekran; ciz(); window.scrollTo(0, 0); }\nfunction ciz() {\n  var l = sezonlar(), kok = document.getElementById('icerik');\n  kok.className = '';\n  var geriB = document.getElementById('geri'), bas = document.getElementById('baslik'), sek = document.getElementById('sekmeler');\n  geriB.style.visibility = S.ekran === 'kok' ? 'hidden' : 'visible'; sek.innerHTML = '';\n  if (S.menuler && ((S.ekran === 'ziraat' && !menuAcik('ziraat')) || (S.ekran === 'hayvan' && !menuAcik('hayvan')) ||\n      (['kok', 'ziraat', 'hayvan'].indexOf(S.ekran) < 0 && !menuAcik('tarla')))) { S.ekran = 'kok'; geriB.style.visibility = 'hidden'; }\n  if (S.ekran === 'kok' || S.ekran === 'ziraat' || S.ekran === 'hayvan') return tarimCiz(kok, bas);\n  if (!l.length) { kok.innerHTML = '<div class=\"kart\">Harita verisi yok.</div>'; return; }\n  if (S.ekran === 'ana') { bas.textContent = 'Tarla Haritaları'; kok.innerHTML = anaEkran(l); return; }\n  if (S.ekran === 'yil') { bas.textContent = 'Yıllara göre karşılaştırma'; kok.innerHTML = yilEkrani(l); return; }\n  var s = guncelSezon();\n  if (S.ekran === 'ciftlikParsel') {\n    var c0 = s.ciftlikler.filter(function (x) { return x.ad === S.pCiftlik; })[0];\n    bas.textContent = S.pCiftlik + ' parselleri'; kok.innerHTML = c0 ? ciftlikParselleri(s, c0) : ''; return;\n  }\n  bas.textContent = 'Tarla Haritası ' + s.sezon;\n  sek.innerHTML = [['harita', 'Harita'], ['parseller', 'Parseller'], ['karsi', 'Karşılaştırma'], ['cks', 'ÇKS']].map(function (t) {\n    return '<div class=\"sekme' + (S.sekme === t[0] ? ' secili' : '') + '\" onclick=\"S.sekme=\\'' + t[0] + '\\';ciz()\">' + t[1] + '</div>'; }).join('');\n  if (S.sekme === 'harita') return haritaSekmesi(s, kok);\n  kok.innerHTML = S.sekme === 'parseller' ? parselSekmesi(s) : S.sekme === 'karsi' ? karsiSekmesi(s) : cksSekmesi(s);\n}\nfunction anaEkran(l) {\n  var h = '<div class=\"bilgi\">Her sezon ayrı bir bölümdür; içinde Harita, Parseller, Karşılaştırma ve ÇKS sekmeleri yer alır. Parsel çizimleri ve sezonların ürünleri Google Earth KMZ haritasından alınır. ' +\n    (S.yetki === 'duzenle' ? 'Parsele dokunarak ürün, dekar ve tohum girebilirsiniz.' : 'Yalnızca görüntüleme yetkiniz var.') + '</div>';\n  l.forEach(function (x) {\n    var ps = []; x.ciftlikler.forEach(function (c) { c.parseller.forEach(function (p) { if (p.tip !== 'diger') ps.push(p); }); });\n    var gir = ps.filter(function (p) { return p.urunler.length; }).length, cks = S.cks.filter(function (r) { return String(r[0]) === x.sezon; }).length, ex = 0;\n    x.ciftlikler.forEach(function (c) { var m = sezonExcel(x, c.ad); for (var k in m) ex += m[k]; });\n    var alt = [uretimYili(x.sezon) + ' üretim yılı', x.giris ? 'Haritadan girilen: ' + gir + ' / ' + ps.length + ' parsel' : 'KMZ haritası (' + x.kaynak + ')',\n      ex > 0 ? 'Excel: ' + sayi(ex) + ' da' : 'Excel kaydı yok'].concat(cks ? ['ÇKS: ' + cks + ' kayıt'] : []).join(' · ');\n    h += menu(x.giris ? '✎' : '▦', x.sezon + ' sezonu', alt, \"git('sezon',{sezon:'\" + x.sezon + \"',sekme:'harita'})\");\n  });\n  if (S.yetki === 'duzenle' && l.length) h += menu('⊕', 'Yeni sezon ekle', sonrakiSezon(l[l.length - 1].sezon) +\n    ' sezonunu açın; parseller güncel harita çizimleriyle gelir, ürünleri haritaya dokunarak girersiniz', 'yeniSezon()');\n  h += menu('⇄', 'Yıllara göre ekim karşılaştırması', l.map(function (x) { return x.sezon; }).join(' · ') + ' — çiftlik ve ürün alanları, parsel geçmişi', \"git('yil')\");\n  return h;\n}\nfunction haritaSekmesi(s, kok) {\n  var cfler = s.ciftlikler.filter(function (c) { return c.parseller.some(function (p) { return p.koord.length > 2; }); });\n  if (!S.ciftlik || !cfler.some(function (c) { return c.ad === S.ciftlik; })) S.ciftlik = cfler.length ? cfler[0].ad : null;\n  var c = cfler.filter(function (x) { return x.ad === S.ciftlik; })[0];\n  var h = '<div class=\"cipler\">' + cfler.map(function (x) { return '<span class=\"cip' + (c && x.ad === c.ad ? ' secili' : '') + '\" onclick=\"ciftlikSec(' + js(x.ad) + ')\">' + esc(x.ad) + '</span>'; }).join('') + '</div>';\n  if (!c) { kok.innerHTML = h + '<div class=\"kart\">Bu sezonda çizili parsel yok.</div>'; return; }\n  var duz = S.yetki === 'duzenle' && s.giris;\n  h += '<div style=\"font-size:19px;font-weight:800;margin:4px 2px 0\">' + esc(c.ad) + '</div><div style=\"font-size:13px;color:var(--soluk);margin:0 2px 8px\">' + esc(s.sezon) + ' sezonu · kaynak: ' + esc(s.kaynak) + '</div>';\n  h += '<div class=\"kart\" style=\"padding:6px\"><div id=\"haritaKap\"' + (S.tam ? ' class=\"tam\"' : '') + '><svg id=\"harita\" xmlns=\"http://www.w3.org/2000/svg\"><g id=\"sahne\"></g></svg><svg id=\"yazilar\" xmlns=\"http://www.w3.org/2000/svg\"></svg>' +\n    '<div class=\"araclar\"><button title=\"Tam ekran\" onclick=\"tamEkran()\">⛶</button><button title=\"Sığdır\" onclick=\"sifirla()\">⟲</button><button title=\"Yazılar\" onclick=\"S.yazi=!S.yazi;yazilar()\" style=\"font-size:14px\">Aa</button></div>' +\n    (S.yetki === 'duzenle' ? '<div class=\"solust\"><button class=\"' + (C.acik ? 'etkin' : '') + '\" onclick=\"cizimAcKapa()\">' + (C.acik ? '✕ Çizimi bitir' : '✎') + '</button></div>' : '') +\n    '<div id=\"cizimPanel\" style=\"display:' + (C.acik ? 'block' : 'none') + '\"></div></div></div>';\n  h += '<div class=\"ipucu\">' + (duz ? 'Parsele dokunarak ' + esc(s.sezon) + ' sezonu için ürün, dekar ve tohum girebilirsiniz. ' : S.yetki !== 'duzenle' ? 'Parsele dokununca bilgisi açılır. ' : 'Bu sezon (KMZ esas haritası) yalnızca görüntülenir. ') +\n    'İki parmakla yakınlaştırabilir, tek parmakla kaydırabilir, sağ üstteki düğmeyle tam ekran açabilirsiniz.</div>';\n  var top = urunToplami(c), tur = {}; (c.gorseller || []).forEach(function (g) { tur[g.tur] = 1; });\n  var cksVar = c.parseller.some(function (p) { return parselCks(s, c.ad, p.ad).length; });\n  h += '<div class=\"lejant\">' + (cksVar ? '<span><i style=\"background:#fff;border:2px solid #1d4ed8\"></i>Mavi kenarlı: ÇKS\\'de bildirildi</span>' : '') +\n    (tur.hat || tur.og ? '<span><i style=\"background:#EF6C00;height:3px\"></i>Enerji / su hattı</span>' : '') + (tur.kuyu ? '<span><i style=\"background:#0277BD;border-radius:6px\"></i>Kuyu</span>' : '') + '</div>';\n  h += '<div class=\"lejant\">' + Object.keys(top).map(function (k) { return '<span onclick=\"renkSec(' + js(k) + ')\"><i style=\"background:' + renk(k) + '\"></i>' + esc(k) + (top[k] > 0 ? ': ' + sayi(top[k]) + ' da' : '') + '</span>'; }).join('') + '</div>' +\n    '<div class=\"ipucu\">Ürün rengini değiştirmek için renk kutusuna dokunun.' + (S.yetki === 'duzenle' ? ' Çizgi, kare, daire, nokta ile bölme, sınır düzenleme ve yeni parsel için haritanın sol üstündeki kalem düğmesine basın.' : '') + '</div>';\n  kok.innerHTML = h;\n  haritaKur(c, s);\n  cizimPaneli();\n}\nfunction parselKarti(s, c, p, i) {\n  var cks = parselCks(s, c.ad, p.ad), oz = {};\n  cks.forEach(function (x) { if (!oz[x.urun]) oz[x.urun] = [0, 0]; oz[x.urun][0] += x.alan || 0; oz[x.urun][1]++; });\n  var r = p.urunler.length ? renk(p.urunler[0][0]) : (p.tip === 'bos' || p.tip === 'girilmedi' ? '#D6D6D6' : '#90A4AE');\n  return '<div class=\"kart\" style=\"cursor:pointer\" onclick=\"S.ciftlik=' + js(c.ad) + ';parselAc(' + i + ')\"><div><i style=\"display:inline-block;width:12px;height:12px;background:' + r + ';margin-right:8px\"></i><b>' + esc(p.ad) + '</b></div>' +\n    '<div style=\"margin-top:2px\">' + esc(urunYazi(p)) + '</div>' +\n    Object.keys(oz).map(function (k) { return '<span class=\"rozet\">ÇKS\\'de bildirildi: ' + esc(k) + ' · ' + sayi(oz[k][0]) + ' da (' + oz[k][1] + ' kayıt)</span>'; }).join('') +\n    (p.not ? '<div class=\"uyari\">' + esc(p.not) + '</div>' : '') + '</div>';\n}\nfunction parselSekmesi(s) {\n  var h = '<h3>Çiftlikler</h3>';\n  s.ciftlikler.forEach(function (c) {\n    var top = 0, m = s.giris ? urunToplami(c) : sezonExcel(s, c.ad); for (var k in m) top += m[k];\n    var ck = c.parseller.filter(function (p) { return parselCks(s, c.ad, p.ad).length; }).length;\n    h += menu('▦', c.ad, c.parseller.length + ' parsel · ' + (s.giris ? 'Girilen' : 'Excel') + ': ' + sayi(top) + ' da ekili' + (ck ? ' · ' + ck + \" parsel ÇKS'de bildirildi\" : ''),\n      \"git('ciftlikParsel',{pCiftlik:\" + js(c.ad) + \"})\");\n  });\n  return h;\n}\nfunction ciftlikParselleri(s, c) { return c.parseller.map(function (p, i) { return parselKarti(s, c, p, i); }).join(''); }\nfunction karsiSekmesi(s) {\n  var sat = [], exVar = false, gir = 0;\n  s.ciftlikler.forEach(function (c) {\n    var g = urunToplami(c), ex = sezonExcel(s, c.ad), k = {};\n    if (Object.keys(ex).length) exVar = true;\n    sezonCks(s, c.ad).forEach(function (x) { if (x.alan != null) ekle(k, urunAnahtari(x.urun), x.alan); });\n    var tum = {}; [g, ex, k].forEach(function (m) { for (var u in m) tum[u] = 1; });\n    Object.keys(tum).forEach(function (u) { sat.push([c.ad, u, g[u], ex[u], k[u]]); });\n    c.parseller.forEach(function (p) { if (p.tip === 'girilmedi') gir++; });\n  });\n  var h = '<div class=\"bilgi\">' + (s.giris ? esc(s.sezon) + ' sezonu, haritada parsellere girilen ürün ve alanlardan oluşur. ' : 'KMZ esas haritası. ') +\n    'Esas alınan kaynak Excel: ' + esc(excelKaynak(s)) + '.' + (exVar ? '' : ' Excel dosyalarında bu yıl için henüz kayıt yok.') + '</div>';\n  if (gir) h += '<div class=\"uyari\">Ürün girilmemiş parsel: ' + gir + '</div>';\n  h += '<h3>Excel esaslı ekim alanları (da)</h3><div class=\"kart\"><table><tr><th>Çiftlik · Ürün</th><th class=\"sag\">Excel</th><th class=\"sag\">Harita</th><th class=\"sag\">ÇKS</th><th class=\"sag\">Fark</th></tr>' +\n    sat.map(function (r) {\n      var g = r[2], pl = r[3], k = r[4];\n      var fark = g == null || pl == null || g <= 0 ? '—' : yakin(g, pl) ? '<span class=\"yesil\">✓</span>' : '<span class=\"amb\">' + (g - pl >= 0 ? '+' : '−') + sayi(Math.abs(g - pl)) + '</span>';\n      return '<tr><td>' + esc(r[0] + ' · ' + r[1]) + '</td><td class=\"sag\">' + (pl == null ? '—' : sayi(pl)) + '</td><td class=\"sag' + (g > 0 && pl != null && !yakin(g, pl) ? ' amb' : '') + '\">' +\n        (g == null ? '—' : g > 0 ? sayi(g) : 'ekili') + '</td><td class=\"sag' + (k != null && pl != null && !yakin(k, pl) ? ' amb' : '') + '\">' + (k == null ? '—' : sayi(k)) + '</td><td class=\"sag\">' + fark + '</td></tr>';\n    }).join('') + '</table></div>';\n  // Münavebe: önceki sezonla aynı parselde aynı ürün\n  var l = sezonlar(), i = l.map(function (x) { return x.sezon; }).indexOf(s.sezon), once = i > 0 ? l[i - 1] : null;\n  if (s.giris && once) {\n    h += '<h3>Münavebe (' + esc(once.sezon) + ' → ' + esc(s.sezon) + ')</h3>';\n    s.ciftlikler.forEach(function (c) {\n      var oc = once.ciftlikler.filter(function (x) { return x.ad === c.ad; })[0];\n      c.parseller.forEach(function (p) {\n        if (!p.urunler.length) return;\n        var op = oc && oc.parseller.filter(function (x) { return x.ad === p.ad; })[0], ou = op ? op.urunler.map(function (u) { return urunAnahtari(u[0]); }) : [];\n        var ust = p.urunler.map(function (u) { return urunAnahtari(u[0]); }).filter(function (u) { return ou.indexOf(u) >= 0; });\n        var hata = ust.filter(function (u) { return ['Yonca', 'Korunga', 'Çayır'].indexOf(u) < 0 && ['Nadas', 'Deneme alanı', 'Islah edilen alan', 'Ağaçlık alan', 'Boş alan'].indexOf(u) < 0; });\n        h += '<div class=\"kart\"><b>' + (hata.length ? '⚠ ' : '✓ ') + esc(c.ad + ' · ' + p.ad) + '</b><div style=\"font-size:13px\">' + esc((ou.length ? ou.join(' + ') : 'ürün yok') + ' → ' + urunYazi(p)) + '</div>' +\n          (hata.length ? '<div class=\"uyari\">Aynı ürün üst üste ekiliyor: ' + esc(hata.join(', ')) + '.</div>' : '') + '</div>';\n      });\n    });\n  }\n  return h;\n}\nfunction cksSekmesi(s) {\n  var h = '<div class=\"bilgi\">ÇKS (Çiftçi Kayıt Sistemi) beyanları: ' + esc(s.sezon) + ' sezonu.</div>';\n  if (S.yetki === 'duzenle') h += '<div class=\"kart\"><b>ÇKS belgesi ekle</b><div class=\"ipucu\">Belgenin fotoğrafını çekin ya da PDF / JPG / PNG dosyası seçin (en fazla 15 MB). ' +\n    'Belge, harita sahibinin Drive\\'ındaki kapalı \\'ÇKS Belgeleri\\' klasörüne kaydedilir; parseller işlendikten sonra burada görünür. ' +\n    'KVKK: belgedeki kimlik, ad ve iletişim bilgileri sisteme alınmaz; yalnızca mevki, ada/parsel, ürün ve alan işlenir.</div>' +\n    '<div class=\"dugmeler\"><button class=\"ana\" onclick=\"document.getElementById(\\'cksKamera\\').click()\">Fotoğraf çek</button>' +\n    '<button class=\"ikinci\" onclick=\"document.getElementById(\\'cksDosya\\').click()\">Dosya seç</button></div>' +\n    '<input type=\"file\" id=\"cksKamera\" accept=\"image/*\" capture=\"environment\" style=\"display:none\" onchange=\"cksYukle(this,' + js(s.sezon) + ')\">' +\n    '<input type=\"file\" id=\"cksDosya\" accept=\".pdf,.jpg,.jpeg,.png,application/pdf,image/jpeg,image/png\" style=\"display:none\" onchange=\"cksYukle(this,' + js(s.sezon) + ')\">' +\n    '<div id=\"cksDurum\" class=\"ipucu\"></div></div>';\n  s.ciftlikler.forEach(function (c) {\n    var l = sezonCks(s, c.ad); if (!l.length) return;\n    var top = l.reduce(function (a, x) { return a + (x.alan || 0); }, 0);\n    h += '<h3>' + esc(c.ad) + ' · ' + l.length + ' kayıt · ' + sayi(top) + ' da</h3><div class=\"kart\"><table><tr><th>Ada / parsel</th><th>Ürün</th><th class=\"sag\">Alan</th><th>Haritada</th></tr>' +\n      l.map(function (x) { return '<tr><td>' + esc([x.ada ? 'Ada ' + x.ada : '', x.parsel ? 'Parsel ' + x.parsel : ''].filter(Boolean).join(' / ')) + (x.mevki ? '<div style=\"font-size:11.5px;color:var(--soluk)\">' + esc(x.mevki) + '</div>' : '') +\n        '</td><td>' + esc(x.urun) + '</td><td class=\"sag\">' + (x.alan == null ? '—' : sayi(x.alan)) + '</td><td>' + esc(x.eslesen || '—') + '</td></tr>'; }).join('') + '</table></div>';\n  });\n  if (h.indexOf('<h3>') < 0) h += '<div class=\"kart\">Bu sezon için ÇKS kaydı yok.</div>';\n  return h;\n}\nfunction cksYukle(inp, sezon) {\n  var f = inp.files && inp.files[0]; inp.value = '';\n  if (!f) return;\n  var ad = f.name.toLowerCase(), mime = f.type;\n  if (!mime) mime = /\\.pdf$/.test(ad) ? 'application/pdf' : /\\.png$/.test(ad) ? 'image/png' : 'image/jpeg';\n  if (mime === 'image/jpg') mime = 'image/jpeg';\n  if (['application/pdf', 'image/jpeg', 'image/png'].indexOf(mime) < 0) return durum('Yalnızca PDF, JPG ya da PNG yüklenebilir.');\n  if (f.size > 15 * 1024 * 1024) return durum('Dosya 15 MB\\'tan büyük.');\n  var d = document.getElementById('cksDurum'); if (d) d.textContent = 'Yükleniyor…';\n  var o = new FileReader();\n  o.onload = function () {\n    var veri = String(o.result).split(',')[1] || '';\n    google.script.run.withSuccessHandler(function (r) {\n      if (d) d.textContent = '';\n      if (!r || !r.ok) return hataGoster(r);\n      if (d) d.textContent = r.mesaj; durum('ÇKS belgesi kaydedildi.');\n    }).withFailureHandler(function (e) { if (d) d.textContent = ''; durum('Yüklenemedi: ' + e.message); })\n      .tarlaPanelKaydet(ANAHTAR, { tur: 'cksYukle', veri: veri, mime: mime, sezon: sezon });\n  };\n  o.onerror = function () { if (d) d.textContent = ''; durum('Dosya okunamadı.'); };\n  o.readAsDataURL(f);\n}\nfunction yilEkrani(l) {\n  var cfler = {}; l.forEach(function (s) { s.ciftlikler.forEach(function (c) { cfler[c.ad] = 1; }); });\n  var h = '<div class=\"bilgi\">Alanlar Excel dosyalarından; Excel kaydı olmayan sezonda haritadan girilen alanlar (*) gösterilir.</div>';\n  Object.keys(cfler).forEach(function (cf) {\n    var m = {};\n    l.forEach(function (s, i) {\n      var ex = sezonExcel(s, cf), yildiz = false;\n      if (!Object.keys(ex).length) { var c = s.ciftlikler.filter(function (x) { return ciftlikAnahtari(x.ad) === ciftlikAnahtari(cf); })[0]; if (c) { ex = urunToplami(c); yildiz = true; } }\n      for (var u in ex) if (ex[u] > 0) { m[u] = m[u] || {}; m[u][i] = sayi(ex[u]) + (yildiz ? '*' : ''); }\n    });\n    if (!Object.keys(m).length) return;\n    h += '<h3>' + esc(cf) + '</h3><div class=\"kart\" style=\"overflow-x:auto\"><table><tr><th>Ürün</th>' + l.map(function (s) { return '<th class=\"sag\">' + esc(s.sezon) + '</th>'; }).join('') + '</tr>' +\n      Object.keys(m).map(function (u) { return '<tr><td><i style=\"display:inline-block;width:10px;height:10px;background:' + renk(u) + ';margin-right:6px\"></i>' + esc(u) + '</td>' +\n        l.map(function (_, i) { return '<td class=\"sag\">' + (m[u][i] || '—') + '</td>'; }).join('') + '</tr>'; }).join('') + '</table></div>';\n  });\n  return h;\n}\nfunction urunYazi(p) {\n  if (!p.urunler.length) return p.tip === 'bos' ? 'Boş alan' : p.tip === 'girilmedi' ? 'Girilmedi' : 'Ürün belirtilmemiş';\n  return p.urunler.map(function (u, i) { var c = p.cesitler[i]; return u[0] + (c ? ' (' + c + ')' : '') + (u[1] > 0 ? ' ' + sayi(u[1]) + ' da' : '') + (p.baglar[i] ? ' → ' + p.baglar[i] : ''); }).join(' + ');\n}\nfunction dekar(p) { if (p.beyan) return p.beyan; var t = 0; p.urunler.forEach(function (u) { t += u[1] || 0; }); return t; }\n\n// ---------- harita: parmakla yakınlaştırma/kaydırma, sabit boyutlu yazılar (uygulamadaki gibi) ----------\nvar H = null; // { c, G, gor, W, Hh, T:{s,x,y}, etiketler }\nvar GORSEL_RENK = { kuyu:'#0277BD', direk:'#37474F', og:'#D32F2F', pivot:'#455A64', nokta:'#D32F2F' };\nfunction icinde(n, k) { var ic = false; for (var i = 0, j = k.length - 1; i < k.length; j = i++) { var a = k[i], b = k[j];\n  if ((a[1] > n[1]) !== (b[1] > n[1]) && n[0] < (b[0] - a[0]) * (n[1] - a[1]) / (b[1] - a[1]) + a[0]) ic = !ic; } return ic; }\nfunction kenarUzak(n, k) { var m = Infinity; for (var i = 0; i < k.length; i++) { var a = k[i], b = k[(i + 1) % k.length], dx = b[0] - a[0], dy = b[1] - a[1], l2 = dx * dx + dy * dy;\n  var t = l2 === 0 ? 0 : Math.max(0, Math.min(1, ((n[0] - a[0]) * dx + (n[1] - a[1]) * dy) / l2)), x = a[0] + t * dx - n[0], y = a[1] + t * dy - n[1]; m = Math.min(m, Math.sqrt(x * x + y * y)); } return m; }\n/** Yazı noktası: üstteki küçük parsellerin dışında, kenarlardan en uzak iç nokta (uygulamadaki gibi). */\nfunction yaziNoktasi(g, G) {\n  var k = g.k, alt = G.filter(function (y) { return y !== g && y.alan < g.alan; }).map(function (y) { return y.k; });\n  var q0 = kutu(k), en = null, skor = -1, n = 28;\n  for (var i = 0; i <= n; i++) for (var j = 0; j <= n; j++) {\n    var q = [q0[0] + (q0[2] - q0[0]) * i / n, q0[1] + (q0[3] - q0[1]) * j / n];\n    if (!icinde(q, k) || alt.some(function (u) { return icinde(q, u); })) continue;\n    var d = kenarUzak(q, k); alt.forEach(function (u) { d = Math.min(d, kenarUzak(q, u)); });\n    if (d > skor) { skor = d; en = q; }\n  }\n  return en || merkez(k);\n}\nfunction haritaKur(c, sz) {\n  sz = sz || guncelSezon();\n  var kap = document.getElementById('haritaKap'), W = kap.clientWidth, Hh = kap.clientHeight;\n  var cizili = c.parseller.filter(function (p) { return p.koord.length > 2; });\n  var tum = []; cizili.forEach(function (p) { tum = tum.concat(p.koord); });\n  var lat0 = tum.reduce(function (a, b) { return a + b[1]; }, 0) / tum.length, kx = Math.cos(lat0 * Math.PI / 180);\n  var G = cizili.map(function (p) { var k = p.koord.map(function (x) { return [x[0] * kx, x[1]]; }); return { p: p, i: c.parseller.indexOf(p), k: k, alan: alan(k) }; });\n  var gor = (c.gorseller || []).filter(function (x) { return x.koord && x.koord.length; }).map(function (x) { return { g: x, k: x.koord.map(function (y) { return [y[0] * kx, y[1]]; }) }; });\n  var xs = [], ys = []; G.forEach(function (g) { g.k.forEach(function (n) { xs.push(n[0]); ys.push(n[1]); }); }); gor.forEach(function (g) { g.k.forEach(function (n) { xs.push(n[0]); ys.push(n[1]); }); });\n  var x0 = Math.min.apply(null, xs), x1 = Math.max.apply(null, xs), y0 = Math.min.apply(null, ys), y1 = Math.max.apply(null, ys);\n  var olc = 0.94 * Math.min(W / (x1 - x0), Hh / (y1 - y0)), ox = (W - (x1 - x0) * olc) / 2, oy = (Hh - (y1 - y0) * olc) / 2;\n  function d(p) { return [ox + (p[0] - x0) * olc, Hh - (oy + (p[1] - y0) * olc)]; }\n  function yol(k) { return k.map(function (p) { var q = d(p); return q[0].toFixed(1) + ',' + q[1].toFixed(1); }).join(' '); }\n  G.sort(function (a, b) { return b.alan - a.alan; });\n  var o = '<defs>', govde = '', et = [];\n  G.forEach(function (g, gi) {\n    var p = g.p, veri = ' data-i=\"' + g.i + '\" data-p=\"';\n    o += '<clipPath id=\"k' + gi + '\"><polygon points=\"' + yol(g.k) + '\"/></clipPath>';\n    function alt(i) { var u = p.urunler[i]; return [u && u[1] > 0 ? sayi(u[1]) + ' da' : '', p.cesitler[i] || ''].filter(Boolean).join(' · '); }\n    if (p.bolgeler.length && p.bolgeler.length === p.urunler.length - 1) {\n      var son = p.urunler.length - 1;\n      govde += '<polygon points=\"' + yol(g.k) + '\" fill=\"' + renk(p.urunler[son][0]) + '\" fill-opacity=\".6\"' + veri + son + '\"/>';\n      p.bolgeler.forEach(function (b, i) {\n        var bp = bolgePoligon(g.k, b); if (bp.length < 3) return;\n        govde += '<polygon clip-path=\"url(#k' + gi + ')\" points=\"' + yol(bp) + '\" fill=\"' + renk(p.urunler[i][0]) + '\" fill-opacity=\".75\" stroke=\"#fff\" stroke-width=\"1.5\"' + veri + i + '\"/>';\n        et.push({ n: d(merkez(bp)), satir: [[kisa(p.urunler[i][0]), 0.85, 600]].concat(alt(i) ? [[alt(i), 0.75, 400]] : []), oncelik: g.alan * 0.3 });\n      });\n      et.push({ n: d(yaziNoktasi(g, G)), satir: [[p.ad, 1, 800], [kisa(p.urunler[son][0]), 0.92, 600]].concat(alt(son) ? [[alt(son), 0.8, 400]] : []), oncelik: g.alan });\n    } else if (p.urunler.length > 1) {\n      var cz = C.bekleyen && C.bekleyen.ad === p.ad ? C.bekleyen.cz : mevcutCizgiler(p, g.k);\n      parcala(g.k, cz).forEach(function (pp, i) {\n        if (pp.length < 3) return;\n        govde += '<polygon points=\"' + yol(pp) + '\" fill=\"' + renk(p.urunler[i][0]) + '\" fill-opacity=\".6\" stroke=\"#fff\" stroke-width=\"1.2\"' + veri + i + '\"/>';\n        var ic = yaziNoktasi({ k: pp, alan: alan(pp) }, []);\n        et.push({ n: d(ic), satir: (i === 0 ? [[p.ad, 1, 800]] : []).concat([[kisa(p.urunler[i][0]) + (p.baglar[i] ? ' → ' + p.baglar[i] : ''), 0.92, 600]]).concat(alt(i) ? [[alt(i), 0.8, 400]] : []), oncelik: g.alan * (i === 0 ? 1 : 0.5) });\n      });\n    } else {\n      var r = p.urunler.length ? renk(p.urunler[0][0]) : (p.tip === 'bos' || p.tip === 'girilmedi' ? '#D6D6D6' : '#90A4AE');\n      govde += '<polygon points=\"' + yol(g.k) + '\" fill=\"' + r + '\" fill-opacity=\".6\"' + veri + 'null\"/>';\n      var a0 = alt(0), da = dekar(p);\n      et.push({ n: d(yaziNoktasi(g, G)), satir: [[p.ad, 1, 800], [p.urunler.length ? kisa(p.urunler[0][0]) : (p.tip === 'girilmedi' ? 'Girilmedi' : (p.tip === 'bos' ? 'Boş alan' : '')), 0.92, 600]]\n        .concat(p.urunler.length && (da || p.cesitler[0]) ? [[[da ? sayi(da) + ' da' : '', p.cesitler[0] || ''].filter(Boolean).join(' · '), 0.8, 400]] : []), oncelik: g.alan });\n    }\n    var ck = parselCks(sz, c.ad, p.ad).length;\n    govde += '<polygon points=\"' + yol(g.k) + '\" fill=\"none\" stroke=\"' + (ck ? '#1d4ed8' : 'rgba(0,0,0,.55)') + '\" stroke-width=\"' + (ck ? 3 : 1) + '\" pointer-events=\"none\"/>';\n  });\n  gor.forEach(function (x) {\n    var r = GORSEL_RENK[x.g.tur] || '#EF6C00', cizgi = x.g.tur === 'hat' || x.g.tur === 'og' || x.g.tur === 'pivot';\n    if (cizgi && x.k.length > 1) govde += '<polyline points=\"' + yol(x.k) + '\" fill=\"none\" stroke=\"' + r + '\" stroke-width=\"' + (x.g.tur === 'og' ? 2.2 : 1.4) + '\" pointer-events=\"none\"/>';\n    else { var m = d(x.k[0]); govde += x.g.tur === 'direk' ? '<rect x=\"' + (m[0] - 3) + '\" y=\"' + (m[1] - 3) + '\" width=\"6\" height=\"6\" fill=\"' + r + '\" pointer-events=\"none\"/>'\n      : '<circle cx=\"' + m[0] + '\" cy=\"' + m[1] + '\" r=\"3.5\" fill=\"' + r + '\" stroke=\"#fff\" stroke-width=\"1\" pointer-events=\"none\"/>'; }\n  });\n  var sahne = document.getElementById('sahne');\n  sahne.innerHTML = o + '</defs>' + govde;\n  sahne.querySelectorAll('polygon,polyline,rect,circle').forEach(function (e) { e.setAttribute('vector-effect', 'non-scaling-stroke'); });\n  et.sort(function (a, b) { return b.oncelik - a.oncelik; });\n  var eskiT = H && H.c && H.c.ad === c.ad && H.W === W ? H.T : null;\n  H = { c: c, sz: sz, W: W, Hh: Hh, T: eskiT || { s: 1, x: 0, y: 0 }, et: et, G: G, kx: kx, d: d,\n    ters: function (b) { return [x0 + (b[0] - ox) / olc, y0 + (Hh - b[1] - oy) / olc]; } };\n  uygula();\n  if (!kap.dataset.kuruldu) { dokunmaKur(kap); kap.dataset.kuruldu = '1'; }\n}\nfunction uygula() {\n  var T = H.T; document.getElementById('sahne').setAttribute('transform', 'matrix(' + T.s + ',0,0,' + T.s + ',' + T.x + ',' + T.y + ')');\n  yazilar();\n}\nfunction mevcutCizgiler(p, k) { return p.bolme.length === p.urunler.length - 1 ? p.bolme : otomatikCizgiler(k, p.urunler.map(function (u) { return u[1]; })); }\nfunction ekranaN(b) { return [b[0] * H.T.s + H.T.x, b[1] * H.T.s + H.T.y]; }\nfunction tabanaN(e) { return [(e[0] - H.T.x) / H.T.s, (e[1] - H.T.y) / H.T.s]; }\nfunction duzlemden(e) { return H.ters(tabanaN(e)); }\nfunction duzleme(n) { return ekranaN(H.d(n)); }\nfunction yazilar() {\n  var el = document.getElementById('yazilar'); if (!S.yazi) { el.innerHTML = ''; return; }\n  var T = H.T, fs = H.W > 700 ? 13 : 11.5, dolu = [], o = '';\n  H.et.forEach(function (e) {\n    var x = e.n[0] * T.s + T.x, y = e.n[1] * T.s + T.y;\n    var sat = e.satir.filter(function (s) { return s[0]; }); if (!sat.length) return;\n    var gen = Math.max.apply(null, sat.map(function (s) { return s[0].length * fs * s[1] * 0.56; })) + 6;\n    var yuk = sat.reduce(function (a, s) { return a + fs * s[1] * 1.15; }, 0) + 2;\n    var r = [x - gen / 2, y - yuk / 2, x + gen / 2, y + yuk / 2];\n    if (r[2] < 0 || r[0] > H.W || r[3] < 0 || r[1] > H.Hh) return;\n    if (dolu.some(function (q) { return r[0] < q[2] && r[2] > q[0] && r[1] < q[3] && r[3] > q[1]; })) return;\n    dolu.push(r);\n    var yy = r[1] + 1;\n    o += '<rect x=\"' + r[0].toFixed(1) + '\" y=\"' + r[1].toFixed(1) + '\" width=\"' + gen.toFixed(1) + '\" height=\"' + yuk.toFixed(1) + '\" rx=\"4\" fill=\"rgba(255,255,255,.82)\"/>';\n    o += '<text text-anchor=\"middle\">' + sat.map(function (s) {\n      var h = fs * s[1] * 1.15; yy += h;\n      return '<tspan x=\"' + x.toFixed(1) + '\" y=\"' + (yy - h * 0.25).toFixed(1) + '\" font-size=\"' + (fs * s[1]).toFixed(1) + '\" font-weight=\"' + s[2] + '\" fill=\"' + (s[2] >= 800 ? '#000' : s[2] >= 600 ? '#222' : '#555') + '\">' + esc(s[0]) + '</tspan>';\n    }).join('') + '</text>';\n  });\n  el.innerHTML = o + cizimKatmani();\n}\nfunction sinirla() {\n  var T = H.T; T.s = Math.max(1, Math.min(12, T.s));\n  T.x = Math.min(0, Math.max(H.W - H.W * T.s, T.x)); T.y = Math.min(0, Math.max(H.Hh - H.Hh * T.s, T.y));\n}\nfunction yakinlasNokta(f, px, py) { var T = H.T, s2 = Math.max(1, Math.min(12, T.s * f)); f = s2 / T.s; T.x = px - (px - T.x) * f; T.y = py - (py - T.y) * f; T.s = s2; sinirla(); uygula(); }\nfunction sifirla() { H.T = { s: 1, x: 0, y: 0 }; uygula(); }\nfunction tamEkran() {\n  S.tam = !S.tam; document.body.style.overflow = S.tam ? 'hidden' : '';\n  document.getElementById('haritaKap').classList.toggle('tam', S.tam);\n  var c = H.c; H = null; haritaKur(c);\n}\n// ---------- çizim araçları (uygulamadaki kalem: çizgi, kare, daire, nokta, sınır düzenle, yeni parsel) ----------\nvar KOPYA = null; // kopyalanan parsel şekli {ad, k: [[boylam, enlem]]}\nfunction yapistir() { C.duzen = KOPYA.k.map(function (c) { return [c[0] * H.kx, c[1]]; }); C.secKose = null; C.yenidenCiz = false; if (C.mod === 'yeni') C.yeniDuzen = true; uygula(); cizimPaneli(); }\nvar C = { acik: false, mod: 'cizgi', bas: null, son: null, noktalar: [], duzenP: null, duzen: [], secKose: null, surukle: null, yenidenCiz: false, bekleyen: null, kaydediliyor: false, yeniDuzen: false, tasi: null };\nfunction duzenleniyor() { return (C.mod === 'sinir' && C.duzenP && !C.yenidenCiz) || (C.mod === 'yeni' && C.yeniDuzen); }\nfunction sinirAnahtari(ad) { return H.sz.tur === 'ayri' ? H.sz.sezon + '|' + ad : ad; }\nfunction js(x) { return esc(JSON.stringify(x)); }\nfunction cizimAcKapa() { C.acik = !C.acik; cizimSifirla(); C.bekleyen = null; ciz(); }\nfunction cizimSifirla() { C.bas = C.son = null; C.noktalar = []; C.duzenP = null; C.duzen = []; C.secKose = null; C.surukle = null; C.yenidenCiz = false; C.yeniDuzen = false; C.tasi = null; }\nfunction modSec(m) { C.mod = m; C.bekleyen = null; cizimSifirla(); yenidenKur(); }\nfunction yenidenKur() { if (!H) return; var c = H.c, sz = H.sz, T = H.T; haritaKur(c, sz); H.T = T; uygula(); cizimPaneli(); }\nvar MODLAR = [['cizgi', 'Çizgi'], ['kare', 'Kare'], ['daire', 'Daire'], ['nokta', 'Nokta'], ['doldur', 'Boşluğu doldur'], ['sinir', 'Sınır düzenle'], ['yeni', 'Yeni parsel']];\nfunction cizimPaneli() {\n  var el = document.getElementById('cizimPanel'); if (!el) return;\n  el.style.display = C.acik ? 'block' : 'none'; if (!C.acik) return;\n  var h = '';\n  if (C.bekleyen) {\n    h = '<b>' + esc(C.bekleyen.ad) + '</b>: ' + esc(C.bekleyen.urunler) + '<div class=\"kucukDugmeler\"><button onclick=\"renkleriCevir()\">⇄ Renkleri çevir</button>' +\n      '<button onclick=\"C.bekleyen=null;yenidenKur()\">Vazgeç</button><button class=\"ana\" onclick=\"cizgiKaydet()\"' + (C.kaydediliyor ? ' disabled' : '') + '>✓ Kaydet</button></div>';\n    el.innerHTML = h; return;\n  }\n  h = '<div class=\"cipler\" style=\"flex-wrap:wrap;padding:0 0 6px\">' + MODLAR.map(function (m) { return '<span class=\"cip' + (C.mod === m[0] ? ' secili' : '') + '\" onclick=\"modSec(\\'' + m[0] + '\\')\">' + m[1] + '</span>'; }).join('') + '</div>';\n  var alan = C.duzen.length > 2 ? ' Çizilen alan ≈ ' + sayi(dekarAlan(C.duzen)) + ' da.' : '';\n  if (C.mod === 'cizgi') h += 'Ayırmak istediğiniz parselin üzerinden parmağınızla bir çizgi çekin. İki renkli parselde çizgi yer değiştirir; tek ürünlü parselde parsel iki parçaya bölünür.';\n  else if (C.mod === 'kare') h += 'Parselin içinde bir köşeden karşı köşeye parmağınızı sürükleyin; dikdörtgen bölge olur.';\n  else if (C.mod === 'daire') h += 'Bölgenin ortasına basıp dışa doğru sürükleyin; daire bölge olur.';\n  else if (C.mod === 'nokta') h += 'Bölgenin köşelerine sırayla dokunun (en az 3 nokta), sonra \"Bölgeyi kapat\".<div class=\"kucukDugmeler\"><button onclick=\"C.noktalar.pop();uygula();cizimPaneli()\"' + (C.noktalar.length ? '' : ' disabled') + '>↶ Son noktayı sil</button>' +\n    '<button class=\"ana\" onclick=\"sekilBitir()\"' + (C.noktalar.length < 3 ? ' disabled' : '') + '>✓ Bölgeyi kapat (' + C.noktalar.length + ')</button></div>';\n  else if (C.mod === 'doldur') h += 'Parsellerin arasındaki boşluğun (ör. pivot yeri) ortasına dokunun: komşu parsellerin kenarlarına göre daire bulunur ve boşluk doldurulur; sonra düzeltip kaydedersiniz.';\n  else if (C.mod === 'sinir' && !C.duzenP) h += 'Sınırını değiştirmek istediğiniz parsele dokunun. İki parmakla yakınlaştırıp kaydırabilirsiniz.';\n  else if (C.mod === 'sinir' || C.mod === 'yeni') {\n    h += C.mod === 'yeni' ? (C.yeniDuzen ? 'Yeni parsel: köşeleri sürükleyin, kenar ortasındaki küçük noktadan köşe ekleyin, şeklin içinden tutup taşıyın.' + alan :\n      'Yeni parselin köşelerine sırayla dokunun (en az 3 nokta) ya da Kare / Daire / Nokta ile parsel dışına şekil çizin.' + alan) :\n      C.yenidenCiz ? esc(C.duzenP) + ': yeni sınırın köşelerine sırayla dokunun (en az 3 nokta).' + alan :\n      esc(C.duzenP) + ': köşeleri sürükleyin; kenar ortasındaki küçük noktayı sürükleyerek köşe ekleyin; köşeye dokunup seçerek silin.' + alan;\n    h += '<div class=\"kucukDugmeler\">';\n    if (KOPYA) h += '<button onclick=\"yapistir()\">⎘ Yapıştır: ' + esc(KOPYA.ad) + ' şekli</button>';\n    if (C.mod === 'sinir' && C.duzen.length > 2) h += '<button onclick=\"KOPYA={ad:C.duzenP,k:C.duzen.map(function(c){return [c[0]/H.kx,c[1]];})};cizimPaneli();durum(\\'Şekil kopyalandı.\\')\">⎘ Bu şekli kopyala</button>';\n    if ((C.mod === 'yeni' && !C.yeniDuzen) || C.yenidenCiz) h += '<button onclick=\"C.duzen.pop();uygula();cizimPaneli()\"' + (C.duzen.length ? '' : ' disabled') + '>↶ Son noktayı sil</button>';\n    else h += '<button onclick=\"koseSil()\"' + (C.secKose == null || C.duzen.length <= 3 ? ' disabled' : '') + '>Seçili köşeyi sil</button><button onclick=\"C.duzen=[];if(C.mod===\\'yeni\\')C.yeniDuzen=false;else C.yenidenCiz=true;C.secKose=null;uygula();cizimPaneli()\">Baştan çiz</button>';\n    if (C.mod === 'sinir' && degisenSinir(H.c.ad, C.duzenP)) h += '<button onclick=\"sinirGeriAl()\">Değişikliği geri al</button>';\n    if (C.mod === 'sinir' || C.yeniDuzen) h += '<button onclick=\"cizimSifirla();uygula();cizimPaneli()\">Vazgeç</button>';\n    h += '<button class=\"ana\" onclick=\"sinirKaydet()\"' + (C.duzen.length < 3 || C.kaydediliyor ? ' disabled' : '') + '>✓ ' + (C.mod === 'yeni' ? 'Parseli kaydet' : 'Sınırı kaydet') + '</button></div>';\n  }\n  el.innerHTML = h;\n}\nfunction koseSil() { if (C.secKose == null) return; C.duzen.splice(C.secKose, 1); C.secKose = null; uygula(); cizimPaneli(); }\nfunction dekarAlan(k) { return k.length < 3 ? 0 : alan(k) * 111320 * 111320 / 1000; }\nfunction ortaNoktalar(e) { var l = []; for (var i = 0; i < e.length; i++) { var a = e[i], b = e[(i + 1) % e.length]; if (Math.hypot(a[0] - b[0], a[1] - b[1]) > 44) l.push([i, [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2]]); } return l; }\nfunction cizimKatmani() {\n  if (!C.acik || !H) return '';\n  var o = '', kalem = 'stroke=\"#e11d48\" stroke-width=\"3\" fill=\"none\" stroke-linecap=\"round\"';\n  if (C.bas && C.son) {\n    var a = C.bas, b = C.son;\n    if (C.mod === 'kare') o += '<rect x=\"' + Math.min(a[0], b[0]) + '\" y=\"' + Math.min(a[1], b[1]) + '\" width=\"' + Math.abs(b[0] - a[0]) + '\" height=\"' + Math.abs(b[1] - a[1]) + '\" ' + kalem + '/>';\n    else if (C.mod === 'daire') o += '<circle cx=\"' + a[0] + '\" cy=\"' + a[1] + '\" r=\"' + Math.hypot(b[0] - a[0], b[1] - a[1]) + '\" ' + kalem + '/>';\n    else o += '<line x1=\"' + a[0] + '\" y1=\"' + a[1] + '\" x2=\"' + b[0] + '\" y2=\"' + b[1] + '\" ' + kalem + '/>';\n  }\n  if (C.mod === 'nokta' && C.noktalar.length) {\n    var e = C.noktalar.map(duzleme);\n    o += '<polyline points=\"' + e.concat(e.length > 2 ? [e[0]] : []).map(function (x) { return x.join(','); }).join(' ') + '\" ' + kalem + '/>';\n    e.forEach(function (x) { o += '<circle cx=\"' + x[0] + '\" cy=\"' + x[1] + '\" r=\"5\" fill=\"#e11d48\"/>'; });\n  }\n  if ((C.mod === 'sinir' || C.mod === 'yeni') && C.duzen.length) {\n    var d = C.duzen.map(duzleme), kapali = duzenleniyor();\n    o += '<polygon points=\"' + d.map(function (x) { return x.join(','); }).join(' ') + '\" fill=\"rgba(255,152,0,.25)\" stroke=\"#e65100\" stroke-width=\"2.5\"' + (d.length > 2 ? '' : ' fill-opacity=\"0\"') + '/>';\n    if (kapali) ortaNoktalar(d).forEach(function (m) { o += '<circle cx=\"' + m[1][0] + '\" cy=\"' + m[1][1] + '\" r=\"5\" fill=\"#fff\" stroke=\"#e65100\" stroke-width=\"1.5\"/>'; });\n    d.forEach(function (x, i) { var r = i === C.secKose ? 9 : 7; o += '<circle cx=\"' + x[0] + '\" cy=\"' + x[1] + '\" r=\"' + r + '\" fill=\"' + (i === C.secKose ? '#e11d48' : '#fff') + '\" stroke=\"#e65100\" stroke-width=\"2\"/>'; });\n  }\n  return o;\n}\nfunction parselBul(e) {\n  // Dokunulan noktadaki en küçük parsel ve parça\n  var hedef = document.elementsFromPoint(e[0] + document.getElementById('haritaKap').getBoundingClientRect().left, e[1] + document.getElementById('haritaKap').getBoundingClientRect().top)\n    .filter(function (x) { return x.dataset && x.dataset.i != null; })[0];\n  return hedef ? { i: +hedef.dataset.i, p: hedef.dataset.p === 'null' ? null : +hedef.dataset.p } : null;\n}\nfunction gOf(ad) { return H.G.filter(function (g) { return g.p.ad === ad; })[0]; }\nfunction koseYakala(e) {\n  if (!duzenleniyor() || !C.duzen.length) return false;\n  var d = C.duzen.map(duzleme), en = null, enU = 24;\n  d.forEach(function (x, i) { var u = Math.hypot(x[0] - e[0], x[1] - e[1]); if (u < enU) { enU = u; en = i; } });\n  if (en != null) { C.surukle = en; return true; }\n  var o = ortaNoktalar(d);\n  for (var j = 0; j < o.length; j++) if (Math.hypot(o[j][1][0] - e[0], o[j][1][1] - e[1]) < 20) { C.duzen.splice(o[j][0] + 1, 0, duzlemden(o[j][1])); C.surukle = o[j][0] + 1; return true; }\n  var n = duzlemden(e);\n  if (C.mod === 'yeni' && C.duzen.length > 2 && icinde(n, C.duzen)) { C.tasi = { bas: n, ilk: C.duzen.map(function (x) { return x.slice(); }) }; C.surukle = null; return true; }\n  return false;\n}\nfunction dokunmaKur(kap) {\n  var p = {}, bas = null, iki = null, sonDokunus = 0, cizer = false;\n  function yerel(e) { var r = kap.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; }\n  function cizmeModu() { return C.acik && !C.bekleyen && (C.mod === 'cizgi' || C.mod === 'kare' || C.mod === 'daire'); }\n  kap.addEventListener('pointerdown', function (e) {\n    if (e.target.closest('.araclar') || e.target.closest('.solust') || e.target.closest('#cizimPanel')) return;\n    kap.setPointerCapture(e.pointerId); p[e.pointerId] = yerel(e);\n    var l = Object.keys(p);\n    if (l.length === 1) {\n      bas = { n: p[e.pointerId], t: Date.now(), T: { s: H.T.s, x: H.T.x, y: H.T.y }, kaydi: false };\n      cizer = false;\n      if (C.acik && koseYakala(bas.n)) { cizer = 'kose'; bas.kaydi = true; }\n      else if (cizmeModu()) { cizer = 'sekil'; C.bas = C.son = bas.n; }\n    }\n    if (l.length === 2) {\n      if (cizer === 'sekil') { C.bas = C.son = null; yazilar(); }\n      cizer = false;\n      var a = p[l[0]], b = p[l[1]]; iki = { d: Math.hypot(a[0] - b[0], a[1] - b[1]), m: [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2], T: { s: H.T.s, x: H.T.x, y: H.T.y } }; if (bas) bas.kaydi = true;\n    }\n  });\n  kap.addEventListener('pointermove', function (e) {\n    if (!p[e.pointerId]) return; p[e.pointerId] = yerel(e);\n    var l = Object.keys(p);\n    if (l.length >= 2 && iki) {\n      var a = p[l[0]], b = p[l[1]], dd = Math.hypot(a[0] - b[0], a[1] - b[1]), m = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2];\n      var s2 = Math.max(1, Math.min(12, iki.T.s * dd / iki.d)), f = s2 / iki.T.s;\n      H.T = { s: s2, x: m[0] - (iki.m[0] - iki.T.x) * f, y: m[1] - (iki.m[1] - iki.T.y) * f }; sinirla(); uygula();\n    } else if (l.length === 1 && bas) {\n      var n = p[l[0]];\n      if (cizer === 'sekil') { C.son = n; yazilar(); return; }\n      if (cizer === 'kose') {\n        if (C.tasi) { var q = duzlemden(n), dx0 = q[0] - C.tasi.bas[0], dy0 = q[1] - C.tasi.bas[1]; C.duzen = C.tasi.ilk.map(function (x) { return [x[0] + dx0, x[1] + dy0]; }); yazilar(); }\n        else if (C.surukle != null) { C.duzen[C.surukle] = duzlemden(n); yazilar(); }\n        return;\n      }\n      var dx = n[0] - bas.n[0], dy = n[1] - bas.n[1];\n      if (Math.hypot(dx, dy) > 6) bas.kaydi = true;\n      if (bas.kaydi) { H.T = { s: bas.T.s, x: bas.T.x + dx, y: bas.T.y + dy }; sinirla(); uygula(); }\n    }\n  });\n  function birak(e) {\n    if (!p[e.pointerId]) return;\n    var n = p[e.pointerId]; delete p[e.pointerId];\n    var l = Object.keys(p);\n    if (l.length === 1) { bas = { n: p[l[0]], t: Date.now(), T: { s: H.T.s, x: H.T.x, y: H.T.y }, kaydi: true }; iki = null; cizer = false; return; }\n    if (l.length) return;\n    if (cizer === 'sekil') { cizer = false; var a0 = C.bas, b0 = C.son; C.bas = C.son = null; yazilar(); if (a0 && b0 && Math.hypot(a0[0] - b0[0], a0[1] - b0[1]) >= 12) (C.mod === 'cizgi' ? cizgiBitir : sekilBitir)(a0, b0); bas = null; return; }\n    if (cizer === 'kose') { cizer = false; if (!C.tasi) C.secKose = C.surukle; C.surukle = null; C.tasi = null; uygula(); cizimPaneli(); bas = null; return; }\n    if (bas && !bas.kaydi && Date.now() - bas.t < 600 && e.type === 'pointerup') {\n      var simdi = Date.now();\n      if (C.acik && (C.mod === 'nokta' || C.mod === 'doldur' || (C.mod === 'yeni' && !C.yeniDuzen) || (C.mod === 'sinir' && (C.yenidenCiz || !C.duzenP)))) { dokunusCizim(n); bas = null; return; }\n      if (simdi - sonDokunus < 300) { sonDokunus = 0; clearTimeout(dokunmaKur.z); yakinlasNokta(2, n[0], n[1]); }\n      else {\n        sonDokunus = simdi; clearTimeout(dokunmaKur.z);\n        dokunmaKur.z = setTimeout(function () { if (C.acik && C.mod !== 'cizgi') return; var x = parselBul(n); if (x) parselAc(x.i, x.p); }, 280);\n      }\n    }\n    bas = null; iki = null;\n  }\n  kap.addEventListener('pointerup', birak); kap.addEventListener('pointercancel', birak);\n  kap.addEventListener('wheel', function (e) { e.preventDefault(); var n = yerel(e); yakinlasNokta(e.deltaY < 0 ? 1.2 : 1 / 1.2, n[0], n[1]); }, { passive: false });\n}\nfunction dokusCizimYok() {}\nfunction dokunusCizim(n) {\n  if (C.mod === 'doldur') {\n    var pl = H.G.map(function (g) { return g.k; }), b = bosluguBul(duzlemden(n), pl);\n    if (!b) return durum('Boşluk bulunamadı: parsellerin arasındaki boş alanın ortasına dokunun (parselin içine değil).');\n    var o = bosluguDoldur(b, pl), q = kutu(o), sade = sadelestir(o, Math.max(q[2] - q[0], q[3] - q[1]) * 0.002);\n    cizimSifirla(); C.mod = 'yeni'; C.yeniDuzen = true; C.duzen = sade.length >= 3 ? sade : o; uygula(); cizimPaneli();\n    return durum('Boşluk dolduruldu. Gerekirse köşeleri düzeltip \"Parseli kaydet\"e basın.');\n  }\n  if (C.mod === 'nokta') C.noktalar.push(duzlemden(n));\n  else if (C.mod === 'yeni' || C.yenidenCiz) C.duzen.push(duzlemden(n));\n  else if (C.mod === 'sinir') { var x = parselBul(n); if (x) { var g = gOf(H.c.parseller[x.i].ad); if (g) { C.duzenP = g.p.ad; C.duzen = g.k.map(function (q) { return q.slice(); }); C.secKose = null; } } }\n  uygula(); cizimPaneli();\n}\n// --- çizgi: bölünmüş parselde çizgi yer değiştirir; tek ürünlü parselde iki parçaya böler\nfunction cizgiAl(k, p, q) {\n  var aci = Math.atan2(q[1] - p[1], q[0] - p[0]) * 180 / Math.PI, r = aci * Math.PI / 180, nx = -Math.sin(r), ny = Math.cos(r), mn = Infinity, mx = -Infinity;\n  k.forEach(function (x) { var v = nx * x[0] + ny * x[1]; mn = Math.min(mn, v); mx = Math.max(mx, v); });\n  var m = [(p[0] + q[0]) / 2, (p[1] + q[1]) / 2];\n  return [aci, Math.max(1, Math.min(99, (nx * m[0] + ny * m[1] - mn) / (mx - mn) * 100))];\n}\nfunction cizgiBitir(a, b) {\n  var p = duzlemden(a), q = duzlemden(b);\n  function say(k) { var n = 0; for (var i = 0; i <= 20; i++) { var f = i / 20; if (icinde([p[0] + (q[0] - p[0]) * f, p[1] + (q[1] - p[1]) * f], k)) n++; } return n; }\n  var hedef = null, enCok = 0;\n  H.G.forEach(function (g) { if (g.p.urunler.length > 1 && !(g.p.bolgeler.length && g.p.bolgeler.length === g.p.urunler.length - 1)) { var n = say(g.k); if (n > enCok) { enCok = n; hedef = g; } } });\n  if (!hedef) {\n    var duz = null, enIc = 0;\n    H.G.slice().reverse().forEach(function (g) { if (g.p.tip === 'diger') return; var n = say(g.k); if (n > enIc) { enIc = n; duz = g; } });\n    if (!duz) return durum('Çizgiyi bir parselin üzerinden, ayırmak istediğiniz yere çekin.');\n    var cz = cizgiAl(duz.k, p, q), yan = kirp(duz.k, cizgiDenklemi(duz.k, cz), true), oran = yan.length < 3 ? 0.5 : alan(yan) / alan(duz.k);\n    return cizgiIleBol(duz.p, cz, oran);\n  }\n  var k = hedef.k, yeni = cizgiAl(k, p, q), l = (C.bekleyen && C.bekleyen.ad === hedef.p.ad ? C.bekleyen.cz : mevcutCizgiler(hedef.p, k)).slice();\n  if (l.length <= 1) l = [yeni];\n  else { var m = [(p[0] + q[0]) / 2, (p[1] + q[1]) / 2], en = 0, enU = Infinity;\n    l.forEach(function (c, i) { var d = cizgiDenklemi(k, c), u = Math.abs(d[0] * m[0] + d[1] * m[1] - d[2]); if (u < enU) { enU = u; en = i; } }); l[en] = yeni; }\n  if (l.length === 1) {\n    var eski = parcala(k, mevcutCizgiler(hedef.p, k))[0];\n    if (eski && eski.length > 2) { var o = merkez(eski), d0 = cizgiDenklemi(k, l[0]); if (d0[0] * o[0] + d0[1] * o[1] - d0[2] > 0) l = [[(l[0][0] + 180) % 360, 100 - l[0][1]]]; }\n  }\n  C.bekleyen = { ad: hedef.p.ad, cz: l, urunler: hedef.p.urunler.map(function (u) { return u[0]; }).join(' / ') };\n  yenidenKur();\n}\nfunction renkleriCevir() { C.bekleyen.cz = C.bekleyen.cz.slice().reverse().map(function (c) { return [(c[0] + 180) % 360, 100 - c[1]]; }); yenidenKur(); }\nfunction cizgiKaydet() {\n  var b = C.bekleyen, p = H.c.parseller.filter(function (x) { return x.ad === b.ad; })[0];\n  var l = p.urunler.map(function (u) { return [u[0], u[1]]; });\n  var metin = bolunmusMetin(l, b.cz, p.baglar, p.cesitler, []);\n  var top = p.beyan != null ? p.beyan : l.reduce(function (a, x) { return a + x[1]; }, 0);\n  kayit([girisOp(H.sz.sezon, H.c.ad, p.ad, metin, top)], function () { C.bekleyen = null; });\n}\nfunction cizgiIleBol(p, cz, oran) {\n  var top = p.beyan || p.urunler.reduce(function (a, u) { return a + (u[1] || 0); }, 0), ilk = p.urunler.length ? urunAnahtari(p.urunler[0][0]) : 'Arpa';\n  function yuv(v) { return top > 0 ? Math.round(v * 10) / 10 : ''; }\n  parcaFormu(p, H.sz.sezon, '(çizgiyle)', [[URUNLER.indexOf(ilk) >= 0 ? ilk : 'Arpa', yuv(top * oran)], ['Buğday', yuv(top * (1 - oran))]], { cizgiler: [cz], sabit: 2 });\n}\n// --- şekil: dikdörtgen / daire / noktalar → bölge\nfunction sekilBitir(a, b) {\n  var duz, kod, tip;\n  if (C.mod === 'nokta') { if (C.noktalar.length < 3) return; duz = C.noktalar.slice(); kod = duz; tip = 'P'; }\n  else {\n    var p = duzlemden(a), q = duzlemden(b); kod = [p, q];\n    if (C.mod === 'kare') { duz = [[p[0], p[1]], [q[0], p[1]], [q[0], q[1]], [p[0], q[1]]]; tip = 'D'; }\n    else { var r = Math.hypot(q[0] - p[0], q[1] - p[1]); duz = []; for (var i = 0; i < 48; i++) duz.push([p[0] + r * Math.cos(i * Math.PI / 24), p[1] + r * Math.sin(i * Math.PI / 24)]); tip = 'C'; }\n  }\n  var o = tip === 'C' ? kod[0] : merkez(duz), hedef = null;\n  H.G.slice().reverse().forEach(function (g) { if (!hedef && g.p.tip !== 'diger' && icinde(o, g.k)) hedef = g; });\n  if (!hedef) {\n    // Parsel dışına çizilen şekil yeni parsel olur: önce şekil düzeltilir, sonra ad, ürün ve dekar girilir.\n    var yeni = duz;\n    if (tip === 'C') { var rr = Math.hypot(kod[1][0] - kod[0][0], kod[1][1] - kod[0][1]); yeni = []; for (var t2 = 0; t2 < 24; t2++) yeni.push([kod[0][0] + rr * Math.cos(t2 * Math.PI / 12), kod[0][1] + rr * Math.sin(t2 * Math.PI / 12)]); }\n    var oturan = bosluguDoldur(tip === 'C' ? duz : yeni, H.G.map(function (g) { return g.k; })), oturdu = oturan !== (tip === 'C' ? duz : yeni);\n    cizimSifirla(); C.mod = 'yeni'; C.yeniDuzen = true; C.duzen = oturdu ? oturan : yeni; uygula(); cizimPaneli();\n    return durum(oturdu ? 'Şekil boşluğa oturtuldu: komşu parsellerle çakışan kısımlar çıkarıldı. Gerekirse köşeleri düzeltip \"Parseli kaydet\"e basın.'\n      : 'Şekil parsel dışında: yeni parsel olarak düzeltip \"Parseli kaydet\"e basın.');\n  }\n  var q0 = kutu(hedef.k), w = q0[2] - q0[0], hh = q0[3] - q0[1];\n  function px(x) { return (x - q0[0]) / w * 100; } function py(y) { return (y - q0[1]) / hh * 100; }\n  var bolge = tip === 'C' ? ['C', [px(kod[0][0]), py(kod[0][1]), Math.hypot(kod[1][0] - kod[0][0], kod[1][1] - kod[0][1]) / w * 100, Math.hypot(kod[1][0] - kod[0][0], kod[1][1] - kod[0][1]) / hh * 100]]\n    : tip === 'D' ? ['D', [px(Math.min(kod[0][0], kod[1][0])), py(Math.min(kod[0][1], kod[1][1])), px(Math.max(kod[0][0], kod[1][0])), py(Math.max(kod[0][1], kod[1][1]))]]\n    : ['P', [].concat.apply([], kod.map(function (n) { return [px(n[0]), py(n[1])]; }))];\n  var pay = bolgePaylari(hedef.k, [bolgePoligon(hedef.k, bolge)])[0];\n  C.noktalar = []; uygula(); cizimPaneli();\n  bolgeFormu(hedef.p, bolge, pay);\n}\n/** Çizilen şekli boşluğa oturtur: komşu parsellerle çakışan kısımlar çıkarılır (ızgara ile), kalan en büyük\n * parçanın sınırı döner. Çakışma yoksa şekil aynen döner. */\nfunction bosluguDoldur(sekil, parseller) {\n  var q = kutu(sekil), N = 260, w = q[2] - q[0], h = q[3] - q[1], hc = Math.max(w, h) / N;\n  var nx = Math.ceil(w / hc) + 2, ny = Math.ceil(h / hc) + 2, x0 = q[0] - hc, y0 = q[1] - hc;\n  var yakin = parseller.filter(function (k) { if (k.length < 3) return false; var b = kutu(k); return !(b[2] < q[0] || b[0] > q[2] || b[3] < q[1] || b[1] > q[3]); });\n  if (!yakin.length) return sekil;\n  var izgara = new Uint8Array(nx * ny), kesti = false;\n  for (var j = 0; j < ny; j++) for (var i = 0; i < nx; i++) {\n    var p = [x0 + (i + 0.5) * hc, y0 + (j + 0.5) * hc];\n    if (!icinde(p, sekil)) continue;\n    if (yakin.some(function (k) { return icinde(p, k); })) { kesti = true; continue; }\n    izgara[j * nx + i] = 1;\n  }\n  if (!kesti) return sekil;\n  // En büyük bağlı parça\n  var etiket = new Int32Array(nx * ny), enE = 0, enS = 0, e = 0;\n  for (var b0 = 0; b0 < nx * ny; b0++) {\n    if (!izgara[b0] || etiket[b0]) continue;\n    e++; var yigin = [b0], say = 0; etiket[b0] = e;\n    while (yigin.length) { var c = yigin.pop(), ci = c % nx, cj = (c - ci) / nx; say++;\n      [[1, 0], [-1, 0], [0, 1], [0, -1]].forEach(function (d) { var a = ci + d[0], b = cj + d[1]; if (a < 0 || b < 0 || a >= nx || b >= ny) return; var k = b * nx + a; if (izgara[k] && !etiket[k]) { etiket[k] = e; yigin.push(k); } }); }\n    if (say > enS) { enS = say; enE = e; }\n  }\n  if (!enE) return sekil;\n  function dolu(i, j) { return i >= 0 && j >= 0 && i < nx && j < ny && etiket[j * nx + i] === enE; }\n  // Sınır izleme (Moore komşuluğu, hücre merkezleri)\n  var bas = -1; for (var k2 = 0; k2 < nx * ny && bas < 0; k2++) if (etiket[k2] === enE) bas = k2;\n  var yon = [[1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1], [0, -1], [1, -1]];\n  var ci0 = bas % nx, cj0 = (bas - ci0) / nx, ci1 = ci0, cj1 = cj0, gel = 6, yol = [], sinirSay = 0;\n  do {\n    yol.push([x0 + (ci1 + 0.5) * hc, y0 + (cj1 + 0.5) * hc]);\n    var bulundu = false;\n    for (var t = 0; t < 8; t++) { var dn = (gel + 6 + t) % 8, a = ci1 + yon[dn][0], b2 = cj1 + yon[dn][1];\n      if (dolu(a, b2)) { ci1 = a; cj1 = b2; gel = dn; bulundu = true; break; } }\n    if (!bulundu) break;\n  } while ((ci1 !== ci0 || cj1 !== cj0) && ++sinirSay < nx * ny * 4);\n  if (yol.length < 3) return sekil;\n  return sadelestir(yol, hc * 0.9);\n}\n/** Boşluğu doldur: dokunulan noktadan ışınlarla komşu kenarlar bulunur, onlara daire oturtulur; daire merkezinden\n * ışınlar daire ve komşu kenarlarla sınırlanır. Bulunamazsa null. */\nfunction bosluguBul(n, parseller) {\n  if (parseller.some(function (k) { return k.length > 2 && icinde(n, k); })) return null;\n  function isin(o, aci) {\n    var dx = Math.cos(aci), dy = Math.sin(aci), en = null;\n    parseller.forEach(function (k) { for (var i = 0; i < k.length; i++) { var a = k[i], b = k[(i + 1) % k.length], ex = b[0] - a[0], ey = b[1] - a[1], den = dx * ey - dy * ex;\n      if (Math.abs(den) < 1e-15) continue; var t = ((a[0] - o[0]) * ey - (a[1] - o[1]) * ex) / den, u = ((a[0] - o[0]) * dy - (a[1] - o[1]) * dx) / den;\n      if (t > 0 && u >= 0 && u <= 1 && (en == null || t < en)) en = t; } });\n    return en;\n  }\n  var m = 96, l = [];\n  for (var i = 0; i < m; i++) { var a = i * 2 * Math.PI / m, t = isin(n, a); if (t != null) l.push([n[0] + t * Math.cos(a), n[1] + t * Math.sin(a)]); }\n  if (l.length < 8) return null;\n  function uz(p, o) { return Math.hypot(p[0] - o[0], p[1] - o[1]); }\n  var u = l.map(function (p) { return uz(p, n); }).sort(function (a, b) { return a - b; }), medyan = u[u.length >> 1];\n  l = l.filter(function (p) { return uz(p, n) <= medyan * 1.6; });\n  var daire = null;\n  for (var tur = 0; tur < 3 && l.length >= 6; tur++) {\n    var cx0 = 0, cy0 = 0; l.forEach(function (p) { cx0 += p[0]; cy0 += p[1]; }); cx0 /= l.length; cy0 /= l.length;\n    var sxx = 0, sxy = 0, syy = 0, sx = 0, sy = 0, sxz = 0, syz = 0, sz = 0;\n    l.forEach(function (p) { var x = p[0] - cx0, y = p[1] - cy0, z = x * x + y * y; sxx += x * x; sxy += x * y; syy += y * y; sx += x; sy += y; sxz += x * z; syz += y * z; sz += z; });\n    var A = [[sxx, sxy, sx, -sxz], [sxy, syy, sy, -syz], [sx, sy, l.length, -sz]];\n    for (var i2 = 0; i2 < 3; i2++) { var pv = i2; for (var r = i2 + 1; r < 3; r++) if (Math.abs(A[r][i2]) > Math.abs(A[pv][i2])) pv = r;\n      var g = A[i2]; A[i2] = A[pv]; A[pv] = g; if (Math.abs(A[i2][i2]) < 1e-30) return null;\n      for (var r2 = 0; r2 < 3; r2++) { if (r2 === i2) continue; var f = A[r2][i2] / A[i2][i2]; for (var c = i2; c < 4; c++) A[r2][c] -= f * A[i2][c]; } }\n    var D = A[0][3] / A[0][0], E = A[1][3] / A[1][1], F = A[2][3] / A[2][2], cx = -D / 2, cy = -E / 2, r2v = cx * cx + cy * cy - F;\n    if (r2v <= 0) return null;\n    daire = [cx + cx0, cy + cy0, Math.sqrt(r2v)];\n    var art = l.map(function (p) { return Math.abs(uz(p, daire) - daire[2]); }).sort(function (a, b) { return a - b; });\n    var esik = Math.max(art[art.length >> 1] * 2.5, daire[2] * 0.01);\n    l = l.filter(function (p) { return Math.abs(uz(p, daire) - daire[2]) <= esik; });\n  }\n  if (!daire || daire[2] > medyan * 3) return null;\n  var sonuc = [];\n  for (var j = 0; j < m; j++) { var a2 = j * 2 * Math.PI / m, t2 = Math.min(daire[2], isin(daire, a2) || daire[2]); sonuc.push([daire[0] + t2 * Math.cos(a2), daire[1] + t2 * Math.sin(a2)]); }\n  return sonuc;\n}\nfunction sadelestir(l, eps) {\n  function uzak(p, a, b) { var dx = b[0] - a[0], dy = b[1] - a[1], u = Math.hypot(dx, dy); return u === 0 ? Math.hypot(p[0] - a[0], p[1] - a[1]) : Math.abs((p[0] - a[0]) * dy - (p[1] - a[1]) * dx) / u; }\n  function parca(l) { if (l.length < 3) return l; var en = 0, i0 = 0; for (var i = 1; i < l.length - 1; i++) { var u = uzak(l[i], l[0], l[l.length - 1]); if (u > en) { en = u; i0 = i; } }\n    if (en <= eps) return [l[0], l[l.length - 1]]; var a = parca(l.slice(0, i0 + 1)), b = parca(l.slice(i0)); return a.slice(0, -1).concat(b); }\n  var j = 0, enU = 0; for (var i = 1; i < l.length; i++) { var u = Math.hypot(l[i][0] - l[0][0], l[i][1] - l[0][1]); if (u > enU) { enU = u; j = i; } }\n  var a = parca(l.slice(0, j + 1)), b = parca(l.slice(j).concat([l[0]]));\n  return a.slice(0, -1).concat(b.slice(0, -1));\n}\nfunction bolgePaylari(k, bolgeler) {\n  var q = kutu(k), say = bolgeler.map(function () { return 0; }).concat([0]), top = 0, n = 70;\n  for (var i = 0; i < n; i++) for (var j = 0; j < n; j++) {\n    var p = [q[0] + (i + 0.5) / n * (q[2] - q[0]), q[1] + (j + 0.5) / n * (q[3] - q[1])];\n    if (!icinde(p, k)) continue; top++;\n    var h = bolgeler.length; for (var b = 0; b < bolgeler.length; b++) if (bolgeler[b].length > 2 && icinde(p, bolgeler[b])) { h = b; break; }\n    say[h]++;\n  }\n  return say.map(function (x) { return top ? x / top : 0; });\n}\n// --- sınır\nfunction degisenSinir(cf, ad) {\n  var m = {}; S.parselSinir.forEach(function (r) { var k = r[0] + '#' + r[1]; if (r[4] === 'Aktif') m[k] = 1; else if (r[4] === 'Geri alındı') delete m[k]; });\n  return !!m[cf + '#' + sinirAnahtari(ad)];\n}\nfunction sinirKaydet() {\n  var k = C.duzen.map(function (c) { return [c[0] / H.kx, c[1]]; }), da = dekarAlan(C.duzen);\n  var koord = k.map(function (c) { return c[0].toFixed(6) + ',' + c[1].toFixed(6); }).join(' ');\n  if (C.mod === 'yeni') {\n    var cizilmemis = H.c.parseller.filter(function (x) { return x.koord.length <= 2; }).map(function (x) { return x.ad; });\n    var hs = hedefSezon(H.sz);\n    sayfaAc('<h2>Yeni parsel</h2><p style=\"font-size:13px\">Çizilen alan yaklaşık ' + sayi(da) + ' da. Sınır ' + (H.sz.tur === 'ayri' ? 'yalnızca ' + esc(H.sz.sezon) + ' sezonunun' : 'tüm sezonların') + ' haritasında kullanılır.</p>' +\n      (cizilmemis.length ? '<div style=\"font-size:12.5px;color:var(--soluk)\">Haritada sınırı olmayan parseller:</div><div class=\"cipler\" style=\"flex-wrap:wrap\">' +\n        cizilmemis.map(function (x) { return '<span class=\"cip\" onclick=\"document.getElementById(\\'yad\\').value=' + js(x) + '\">' + esc(x) + '</span>'; }).join('') + '</div>' : '') +\n      '<label>Parsel adı</label><input id=\"yad\" maxlength=\"80\" placeholder=\"Ör. 12. parsel\">' +\n      '<label>' + esc(hs) + ' ürünü / alan türü (isteğe bağlı)</label>' + urunAlani('yu', '') +\n      '<label>Dekar (öneri, çizdiğiniz alana göre)</label><input id=\"yda\" inputmode=\"decimal\" value=\"' + Math.round(da) + '\">' +\n      '<div class=\"dugmeler\"><button class=\"ana\" onclick=\"yeniParselKaydet(' + js(koord) + ')\">Kaydet</button><button class=\"ikinci\" onclick=\"kapat()\">Vazgeç</button></div>');\n    return;\n  }\n  sayfaAc('<h2>' + esc(C.duzenP) + ' sınırı</h2><p style=\"font-size:13px\">Yeni sınır tüm sezonların haritasında kullanılacak. Çizilen alan yaklaşık ' + sayi(da) + ' da (beyan edilen dekar değişmez; gerekirse parselden ayrıca düzeltin).</p>' +\n    '<div class=\"dugmeler\"><button class=\"ana\" onclick=\"kayit([{tur:\\'parselSinir\\',ciftlik:' + js(H.c.ad) + ',parsel:' + js(sinirAnahtari(C.duzenP)) + ',koord:' + js(koord) + '}],function(){cizimSifirla();})\">Kaydet</button><button class=\"ikinci\" onclick=\"kapat()\">Vazgeç</button></div>');\n}\nfunction yeniParselKaydet(koord) {\n  var ad = document.getElementById('yad').value.trim();\n  if (!ad) return durum('Parsel adı girin.');\n  if (H.c.parseller.some(function (x) { return x.ad === ad && x.koord.length > 2; })) return durum('Bu adla çizili bir parsel var.');\n  var ops = [{ tur: 'parselSinir', ciftlik: H.c.ad, parsel: sinirAnahtari(ad), koord: koord }];\n  var u = document.getElementById('yu').value;\n  if (u) {\n    if (u === '__diger') u = document.getElementById('yud').value.trim();\n    if (!u || /[:+>@#\\/;]/.test(u)) return durum('Ürün adını kontrol edin.');\n    var d = sayiOku(document.getElementById('yda').value); if (d == null || d <= 0) return durum('Dekarı girin.');\n    ops.push(girisOp(hedefSezon(H.sz), H.c.ad, ad, u, d));\n  }\n  kayit(ops, function () { cizimSifirla(); });\n}\nfunction sinirGeriAl() { kayit([{ tur: 'parselSinirGeriAl', ciftlik: H.c.ad, parsel: sinirAnahtari(C.duzenP) }], function () { cizimSifirla(); }); }\nwindow.addEventListener('resize', function () { if (H && H.c && document.getElementById('haritaKap')) { var c = H.c; H = null; haritaKur(c); } });\nfunction sezonSec(s) { S.sezon = s; ciz(); }\nfunction ciftlikSec(c) { S.ciftlik = c; ciz(); }\n\n// ---------- parsel işlemleri (uygulamadaki parsel sayfası) ----------\nvar ACIK = null;\nfunction hedefSezon(s) { return s.giris ? s.sezon : sonrakiSezon(s.sezon); }\nfunction girisOp(sezon, cf, parsel, urun, alanDa) { return { tur: 'sezonParsel', sezon: sezon, ciftlik: cf, parsel: parsel, urun: urun, alan: alanDa == null || alanDa === '' ? '' : String(alanDa).replace('.', ',') }; }\nfunction geriOp(sezon, cf, parsel) { return { tur: 'sezonParselGeriAl', sezon: sezon, ciftlik: cf, parsel: parsel }; }\nfunction secenekler(sec) {\n  var k = sec ? urunAnahtari(sec) : '', varMi = URUNLER.indexOf(k) >= 0;\n  return (sec ? '' : '<option value=\"\">— seçin —</option>') + URUNLER.map(function (u) { return '<option' + (u === k ? ' selected' : '') + '>' + esc(u) + '</option>'; }).join('') +\n    '<option value=\"__diger\"' + (!varMi && sec ? ' selected' : '') + '>Diğer…</option>';\n}\nfunction urunAlani(id, u) {\n  var diger = u && URUNLER.indexOf(urunAnahtari(u)) < 0;\n  return '<select id=\"' + id + '\" onchange=\"document.getElementById(\\'' + id + 'd\\').style.display=this.value===\\'__diger\\'?\\'block\\':\\'none\\'\">' + secenekler(u) + '</select>' +\n    '<input id=\"' + id + 'd\" placeholder=\"Ürün adı\" style=\"margin-top:6px;display:' + (diger ? 'block' : 'none') + '\" value=\"' + esc(diger ? u : '') + '\">';\n}\nfunction urunOku(id) {\n  var u = document.getElementById(id).value; if (u === '__diger') u = document.getElementById(id + 'd').value.trim();\n  if (!u) { durum('Ürün seçin.'); return null; }\n  if (u.length > 40 || /[:+>@#\\/;]/.test(u)) { durum('Ürün adında : + > @ # / ; işaretleri kullanılamaz.'); return null; }\n  return u;\n}\nfunction metinOku(id) { var t = (document.getElementById(id).value || '').trim(); if (/[:+>@#\\/;]/.test(t)) { durum('Tohum adında : + > @ # / ; işaretleri kullanılamaz.'); return false; } return t || null; }\nfunction parselAc(i, parca) {\n  var s = guncelSezon(), c = s.ciftlikler.filter(function (x) { return x.ad === S.ciftlik; })[0], p = c.parseller[i];\n  var hedef = hedefSezon(s), g = parselGirisi(hedef, c.ad, p.ad), ic = g ? icerikOku(g.urun) : null;\n  ACIK = { s: s, c: c, p: p, i: i, hedef: hedef, g: g, ic: ic };\n  var l = sezonlar(), si = l.map(function (x) { return x.sezon; }).indexOf(hedef), once = si > 0 ? l[si - 1] : null;\n  var oc = once && once.ciftlikler.filter(function (x) { return x.ad === c.ad; })[0], op = oc && oc.parseller.filter(function (x) { return x.ad === p.ad; })[0];\n  var onceU = op ? op.urunler.map(function (u) { return urunAnahtari(u[0]); }) : [];\n  var bagli = c.parseller.filter(function (x) { var h = x.ad !== p.ad && parselGirisi(hedef, c.ad, x.ad); return h && icerikOku(h.urun).birlesik === p.ad; }).map(function (x) { return x.ad; });\n  ACIK.bagli = bagli;\n  var h = '<h2>' + esc(c.ad) + ' · ' + esc(p.ad) + '</h2>';\n  if (once) h += '<div style=\"color:var(--soluk);font-size:13px\">' + esc(once.sezon) + ': ' + esc(onceU.length ? onceU.join(' + ') : 'ürün yok') + '</div>';\n  h += '<div style=\"font-weight:700;margin:4px 0\">' + esc(hedef) + ': ' + esc(g ? girisYazi(g, ic, bagli) : (p.urunler.length && hedef === s.sezon ? urunYazi(p) + ' (KMZ)' : 'girilmedi')) + '</div>';\n  if (p.not) h += '<div class=\"uyari\">' + esc(p.not) + '</div>';\n  var ayni = ic && ic.parcalar.some(function (x) { var k = urunAnahtari(x[0]); return onceU.indexOf(k) >= 0 && ['Yonca', 'Korunga', 'Çayır'].indexOf(k) < 0 && ['Nadas', 'Deneme alanı', 'Islah edilen alan', 'Ağaçlık alan', 'Boş alan'].indexOf(k) < 0; });\n  if (ayni) h += '<div class=\"uyari\">Münavebe uyarısı: aynı ürün bu parselde üst üste ekiliyor.</div>';\n  var cks = parselCks(s, c.ad, p.ad); if (cks.length) h += cks.map(function (x) { return '<span class=\"rozet\">ÇKS: ' + esc(x.urun) + ' ' + (x.alan == null ? '' : sayi(x.alan) + ' da') + '</span>'; }).join('');\n  if (S.yetki !== 'duzenle' || p.tip === 'diger') {\n    h += '<p style=\"color:var(--soluk);font-size:13px\">' + (p.tip === 'diger' ? 'Ekim alanı değil, ürün girilemez.' : 'Yalnızca görüntüleme yetkiniz var.') + '</p><div class=\"dugmeler\"><button class=\"ikinci\" onclick=\"kapat()\">Kapat</button></div>';\n    return sayfaAc(h);\n  }\n  if (ic && ic.birlesik) {\n    h += '<p style=\"font-size:13px\">Bu parsel ' + esc(ic.birlesik) + ' ile birleştirilmiş; alan ana parselde sayılır.</p><div class=\"dugmeler\"><button class=\"ana\" onclick=\"kayit([geriOp(ACIK.hedef,ACIK.c.ad,ACIK.p.ad)])\">Birleşimden ayır</button><button class=\"ikinci\" onclick=\"kapat()\">Kapat</button></div>';\n    return sayfaAc(h);\n  }\n  // Ürün / dekar / tohum (bölünmüş parselde her parça)\n  var parcalar = ic ? ic.parcalar.map(function (x) { return [x[0], x[1]]; }) : (p.urunler.length && hedef === s.sezon ? p.urunler.map(function (u) { return [u[0], u[1]]; }) : [[onceU.length === 1 ? onceU[0] : '', null]]);\n  var cesit = ic ? ic.cesitler : (hedef === s.sezon ? p.cesitler : []), baglar = ic ? ic.baglar : [];\n  if (!ic && parcalar.length === 1 && hedef === s.sezon && p.beyan) parcalar[0][1] = p.beyan;\n  if (ic && !ic.birlesik && parcalar.length === 1 && g.alan != null) parcalar[0][1] = g.alan;\n  ACIK.parcaSayisi = parcalar.length;\n  ACIK.taban = { cizgiler: ic ? ic.cizgiler : (hedef === s.sezon ? p.bolme : []), bolgeler: ic ? ic.bolgeler : (hedef === s.sezon ? p.bolgeler : []) };\n  var adaylar = c.parseller.filter(function (x) { return x.ad !== p.ad && x.tip !== 'diger'; }).map(function (x) { return x.ad; });\n  if (parcalar.length > 1) h += '<p style=\"font-size:12.5px;color:var(--soluk);margin:8px 0 0\">Parçalar: ürün, dekar, tohum ve (isterseniz) bağlandığı parsel.</p>';\n  parcalar.forEach(function (u, j) {\n    h += '<div class=\"parca\"' + (parca === j && parcalar.length > 1 ? ' style=\"border:2px solid #14532d\"' : '') + '>' + (parcalar.length > 1 ? '<b><i style=\"display:inline-block;width:12px;height:12px;border-radius:3px;background:' + renk(u[0] || '') + ';margin-right:6px\"></i>' + (j + 1) + '. parça</b>' : '') +\n      '<label>Ürün / alan türü</label>' + urunAlani('u' + j, u[0]) +\n      '<div class=\"satir\"><div><label>Dekar</label><input id=\"d' + j + '\" inputmode=\"decimal\" value=\"' + (u[1] == null ? '' : u[1]) + '\"></div>' +\n      '<div><label>Tohum / çeşit</label><input id=\"t' + j + '\" value=\"' + esc(cesit[j] || '') + '\"></div></div>' +\n      (parcalar.length > 1 ? '<label>Bağlandığı parsel</label><select id=\"b' + j + '\"><option value=\"\">— bağlı değil —</option>' + adaylar.map(function (a) { return '<option' + (baglar[j] === a ? ' selected' : '') + '>' + esc(a) + '</option>'; }).join('') + '</select>' : '') + '</div>';\n  });\n  h += '<div class=\"dugmeler\"><button class=\"ana\" onclick=\"parselKaydet()\">Kaydet</button></div>';\n  h += '<div class=\"kucukDugmeler\"><button onclick=\"parcaFormu(ACIK.p,ACIK.hedef,\\'\\',null,{})\">✂ Parçalara böl</button><button onclick=\"birlestirFormu()\">⧉ Birleştir</button>' +\n    (p.koord.length > 2 ? '<button onclick=\"KOPYA={ad:ACIK.p.ad,k:ACIK.p.koord.map(function(c){return c.slice();})};kapat();durum(ACIK.p.ad+\\' şekli kopyalandı. Kalem → Yeni parsel ya da Sınır düzenle\\\\\\'de Yapıştır.\\')\">⎘ Şekli kopyala</button>' : '') +\n    (g ? '<button onclick=\"girisGeriAl()\">↶ ' + (bagli.length ? 'Girişi ve birleştirmeyi geri al' : 'Girişi geri al') + '</button>' : '') + '<button onclick=\"kapat()\">Kapat</button></div>';\n  if (parcalar.length > 1) h += '<p style=\"font-size:12px;color:var(--soluk)\">Renk ayrımı için haritanın sol üstündeki kalem düğmesine basıp parselin üzerinden çizgi çekin.</p>';\n  h += '<p style=\"font-size:11.5px;color:var(--soluk)\">Kayıt ' + esc(hedef) + ' sezonu verilerine eklenir (Sezon_Parselleri). Kaynak Excel dosyaları değişmez.</p>';\n  sayfaAc(h);\n}\nfunction girisYazi(g, ic, bagli) {\n  if (ic.birlesik) return ic.parcalar[0][0] + ' · ' + ic.birlesik + ' ile birleştirildi';\n  if (ic.parcalar.length > 1) return ic.parcalar.map(function (x) { return x[0] + (x[1] == null ? '' : ' ' + sayi(x[1]) + ' da'); }).join(' + ');\n  return g.urun + (g.alan == null ? '' : ' · ' + sayi(g.alan) + ' da') + (bagli.length ? ' (' + bagli.join(', ') + ' ile birlikte)' : '');\n}\nfunction parselKaydet() {\n  var A = ACIK, n = A.parcaSayisi, l = [], ces = [], bag = [];\n  for (var j = 0; j < n; j++) {\n    var u = urunOku('u' + j); if (!u) return;\n    var d = sayiOku(document.getElementById('d' + j).value), t = metinOku('t' + j); if (t === false) return;\n    if (n > 1 && (d == null || d < 0)) return durum((j + 1) + '. parçanın dekarını girin.');\n    if (d != null && d < 0) return durum('Dekar okunamadı.');\n    var b = n > 1 ? document.getElementById('b' + j).value || null : null;\n    if (b && (!A.ic || A.ic.baglar[j] !== b)) { var hb = parselGirisi(A.hedef, A.c.ad, b), hu = hb ? icerikOku(hb.urun) : null; if (hu && hu.parcalar.length === 1 && !hu.birlesik && hu.parcalar[0][0]) u = hu.parcalar[0][0]; }\n    l.push([u, d]); ces.push(t); bag.push(b);\n  }\n  var metin, top;\n  if (n === 1) { metin = urunMetni(l[0][0], ces[0]); top = l[0][1]; }\n  else { metin = bolunmusMetin(l, A.taban.cizgiler, bag, ces, A.taban.bolgeler); top = l.reduce(function (a, x) { return a + x[1]; }, 0); }\n  if (metin.length > SINIR) return durum('Kayıt çok uzun; tohum adlarını ya da parça sayısını azaltın.');\n  kayit([girisOp(A.hedef, A.c.ad, A.p.ad, metin, top)]);\n}\nfunction girisGeriAl() { var A = ACIK; kayit(A.bagli.map(function (b) { return geriOp(A.hedef, A.c.ad, b); }).concat([geriOp(A.hedef, A.c.ad, A.p.ad)])); }\n/** Parçalara böl: 2–4 parça (ürün + dekar). ek.cizgiler: çizgiyle bölmede çizgi; ek.sabit: parça sayısı sabit. */\nfunction parcaFormu(p, sezon, ekBaslik, mevcut, ek) {\n  var A = ACIK || {}; ACIK = A; A.p = p; A.c = H ? H.c : A.c; A.bolSezon = sezon; A.bolEk = ek;\n  var g = parselGirisi(sezon, A.c.ad, p.ad), ic = g ? icerikOku(g.urun) : null; A.bolIc = ic;\n  var l = mevcut || (ic && ic.parcalar.length > 1 ? ic.parcalar.map(function (x) { return [x[0], x[1]]; }) : [[p.urunler.length ? urunAnahtari(p.urunler[0][0]) : '', null], ['', null]]);\n  A.bolSayi = l.length;\n  var h = '<h2>' + esc(p.ad) + ' ' + esc(ekBaslik) + ' — parçalar</h2><p style=\"font-size:12.5px;color:var(--soluk)\">Her parçanın ürününü ve dekarını girin.</p><div id=\"bolSatirlar\">';\n  l.forEach(function (x, j) { h += bolSatiri(j, x); });\n  h += '</div>' + (ek.sabit ? '' : '<div class=\"kucukDugmeler\"><button onclick=\"bolEkle()\">+ Parça ekle</button><button onclick=\"bolCikar()\">− Son parçayı çıkar</button></div>') +\n    '<div class=\"dugmeler\"><button class=\"ana\" onclick=\"bolKaydet()\">Kaydet</button><button class=\"ikinci\" onclick=\"kapat()\">Vazgeç</button></div>';\n  sayfaAc(h);\n}\nfunction bolSatiri(j, x) { return '<div class=\"parca\" id=\"bs' + j + '\"><b>' + (j + 1) + '. parça</b><label>Ürün</label>' + urunAlani('bu' + j, x[0]) + '<label>Dekar</label><input id=\"bd' + j + '\" inputmode=\"decimal\" value=\"' + (x[1] == null ? '' : x[1]) + '\"></div>'; }\nfunction bolEkle() { if (ACIK.bolSayi >= 4) return durum('En çok 4 parça.'); document.getElementById('bolSatirlar').insertAdjacentHTML('beforeend', bolSatiri(ACIK.bolSayi, ['', null])); ACIK.bolSayi++; }\nfunction bolCikar() { if (ACIK.bolSayi <= 2) return durum('En az 2 parça.'); ACIK.bolSayi--; document.getElementById('bs' + ACIK.bolSayi).remove(); }\nfunction bolKaydet() {\n  var A = ACIK, l = [];\n  for (var j = 0; j < A.bolSayi; j++) { var u = urunOku('bu' + j); if (!u) return; var d = sayiOku(document.getElementById('bd' + j).value); if (d == null || d < 0) return durum((j + 1) + '. parçanın dekarını girin.'); l.push([u, d]); }\n  var ic = A.bolIc, ayni = ic && ic.parcalar.length === l.length, metin;\n  if (A.bolEk.cizgiler) metin = bolunmusMetin(l, A.bolEk.cizgiler, [], [], []);\n  else metin = bolunmusMetin(l, ic && ic.parcalar.length > 1 && ic.cizgiler.length === l.length - 1 ? ic.cizgiler : [], ayni ? ic.baglar : [], ayni ? ic.cesitler : [], ayni ? ic.bolgeler : []);\n  if (metin.length > SINIR) return durum('Kayıt çok uzun.');\n  kayit([girisOp(A.bolSezon, A.c.ad, A.p.ad, metin, l.reduce(function (a, x) { return a + x[1]; }, 0))]);\n}\nfunction birlestirFormu() {\n  var A = ACIK, adaylar = A.c.parseller.filter(function (x) { return x.ad !== A.p.ad && x.tip !== 'diger'; });\n  var u0 = A.ic && A.ic.parcalar.length === 1 && !A.ic.birlesik ? A.ic.parcalar[0][0] : '';\n  var h = '<h2>' + esc(A.p.ad) + ' ile birleştir</h2><p style=\"font-size:12.5px;color:var(--soluk)\">Seçilen parseller bu parselle tek ürün olarak birleşir; toplam dekar bu parselde tutulur.</p><div class=\"secim\">' +\n    adaylar.map(function (x, j) { return '<label><input type=\"checkbox\" id=\"bk' + j + '\"' + (A.bagli.indexOf(x.ad) >= 0 ? ' checked' : '') + '>' + esc(x.ad) + '</label>'; }).join('') + '</div>' +\n    '<label>Ürün</label>' + urunAlani('bku', u0) + '<label>Toplam dekar</label><input id=\"bkd\" inputmode=\"decimal\" value=\"' + (A.g && A.g.alan != null ? A.g.alan : '') + '\">' +\n    '<div class=\"dugmeler\"><button class=\"ana\" onclick=\"birlestirKaydet()\">Kaydet</button><button class=\"ikinci\" onclick=\"kapat()\">Vazgeç</button></div>';\n  A.bkAdaylar = adaylar.map(function (x) { return x.ad; });\n  sayfaAc(h);\n}\nfunction birlestirKaydet() {\n  var A = ACIK, sec = A.bkAdaylar.filter(function (_, j) { return document.getElementById('bk' + j).checked; });\n  if (!sec.length) return durum('Birleştirilecek parsel seçin.');\n  var u = urunOku('bku'); if (!u) return;\n  var d = sayiOku(document.getElementById('bkd').value), ops = [];\n  A.bagli.forEach(function (b) { if (sec.indexOf(b) < 0) ops.push(geriOp(A.hedef, A.c.ad, b)); });\n  sec.forEach(function (b) { ops.push(girisOp(A.hedef, A.c.ad, b, u + '@' + A.p.ad, '')); });\n  ops.push(girisOp(A.hedef, A.c.ad, A.p.ad, u, d));\n  kayit(ops);\n}\n/** Parsel içine çizilen bölge: bölgenin ve parselin kalanının ürünü / dekarı. */\nfunction bolgeFormu(p, bolge, pay) {\n  var sz = H.sz, g = parselGirisi(sz.sezon, H.c.ad, p.ad), eskiBolge = p.bolgeler.length && p.urunler.length === p.bolgeler.length + 1;\n  var top = p.beyan || p.urunler.reduce(function (a, u) { return a + (u[1] || 0); }, 0), eskiDa = 0;\n  if (eskiBolge) for (var i = 0; i < p.bolgeler.length; i++) eskiDa += p.urunler[i][1] || 0;\n  var kalanU = p.urunler.length ? urunAnahtari(eskiBolge ? p.urunler[p.urunler.length - 1][0] : p.urunler[0][0]) : '';\n  ACIK = { p: p, c: H.c, bolge: bolge, eskiBolge: eskiBolge };\n  var bda = top > 0 ? Math.round(top * pay * 10) / 10 : '', kda = top > 0 && bda !== '' ? Math.max(0, Math.round(top - eskiDa - bda)) : '';\n  sayfaAc('<h2>' + esc(p.ad) + ' · çizilen bölge</h2><label>Bölgenin ürünü / alan türü</label>' + urunAlani('rbu', 'Deneme alanı') +\n    '<label>Bölgenin dekarı (öneri, çizdiğiniz alana göre)</label><input id=\"rbd\" inputmode=\"decimal\" value=\"' + bda + '\">' +\n    '<label>Parselin kalanının ürünü</label>' + urunAlani('rku', kalanU) + '<label>Kalanın dekarı</label><input id=\"rkd\" inputmode=\"decimal\" value=\"' + kda + '\">' +\n    '<div class=\"dugmeler\"><button class=\"ana\" onclick=\"bolgeKaydet()\">Kaydet</button><button class=\"ikinci\" onclick=\"kapat()\">Vazgeç</button></div>');\n}\nfunction bolgeKaydet() {\n  var A = ACIK, p = A.p, bu = urunOku('rbu'); if (!bu) return; var ku = urunOku('rku'); if (!ku) return;\n  var bd = sayiOku(document.getElementById('rbd').value), kd = sayiOku(document.getElementById('rkd').value);\n  if (bd == null || bd <= 0 || kd == null || kd < 0) return durum('Dekarları girin.');\n  var n = A.eskiBolge ? p.bolgeler.length : 0, l = [], ces = [], bag = [];\n  for (var i = 0; i < n; i++) { l.push([p.urunler[i][0], p.urunler[i][1]]); ces.push(p.cesitler[i] || null); bag.push(p.baglar[i] || null); }\n  l.push([bu, bd]); ces.push(null); bag.push(null);\n  l.push([ku, kd]); ces.push(A.eskiBolge ? p.cesitler[p.urunler.length - 1] || null : null); bag.push(A.eskiBolge ? p.baglar[p.urunler.length - 1] || null : null);\n  var metin = bolunmusMetin(l, [], bag, ces, (A.eskiBolge ? p.bolgeler : []).concat([A.bolge]));\n  if (metin.length > SINIR) return durum('Kayıt çok uzun; bölge sayısını azaltın.');\n  kayit([girisOp(H.sz.sezon, A.c.ad, p.ad, metin, l.reduce(function (a, x) { return a + x[1]; }, 0))]);\n}\nfunction sayfaAc(h) { var s = document.getElementById('sayfa'); s.innerHTML = h; s.style.display = 'block'; s.scrollTop = 0; document.getElementById('perde').style.display = 'block'; }\nfunction kapat() { document.getElementById('sayfa').style.display = 'none'; document.getElementById('perde').style.display = 'none'; }\n/** Kayıtları sırayla sunucuya gönderir; bitince veri yenilenir ve ekran yeniden çizilir. */\nfunction kayit(ops, sonra) {\n  if (S.yetki !== 'duzenle') return durum('Yalnızca görüntüleme yetkiniz var.');\n  C.kaydediliyor = true; cizimPaneli();\n  document.querySelectorAll('#sayfa button').forEach(function (b) { b.disabled = true; });\n  google.script.run.withSuccessHandler(function (r) {\n    C.kaydediliyor = false;\n    document.querySelectorAll('#sayfa button').forEach(function (b) { b.disabled = false; });\n    if (!r || !r.ok) { cizimPaneli(); return hataGoster(r); }\n    S.sezonParsel = r.sezonParsel || S.sezonParsel; S.parselSinir = r.parselSinir || S.parselSinir; S.tarlaSezonlari = r.tarlaSezonlari || S.tarlaSezonlari;\n    if (sonra) sonra();\n    kapat(); ciz(); durum(r.mesaj || 'Kaydedildi.');\n  }).withFailureHandler(function (e) { C.kaydediliyor = false; cizimPaneli(); document.querySelectorAll('#sayfa button').forEach(function (b) { b.disabled = false; }); durum('Kaydedilemedi: ' + e.message); })\n    .tarlaPanelKaydet(ANAHTAR, { coklu: ops });\n}\nfunction yeniSezon() {\n  var l = sezonlar(); if (!l.length) return;\n  var son = l[l.length - 1].sezon, yeni = sonrakiSezon(son);\n  sayfaAc('<h2>' + esc(yeni) + ' sezonu açılsın mı?</h2><p style=\"font-size:14px\">Yeni sezon ' + esc(son) + ' sezonunun ardından eklenir. ' +\n    'Parseller güncel harita çizimleriyle açılır; ürün ve dekarları haritada parsele dokunarak girersiniz. Açılan sezonu yalnızca harita sahibi kaldırabilir.</p>' +\n    '<div class=\"dugmeler\"><button class=\"ikinci\" onclick=\"kapat()\">Vazgeç</button><button class=\"ana\" onclick=\"yeniSezonAc(' + js(yeni) + ')\">Sezonu aç</button></div>');\n}\nfunction yeniSezonAc(sezon) {\n  if (S.yetki !== 'duzenle') return durum('Yalnızca görüntüleme yetkiniz var.');\n  document.querySelectorAll('#sayfa button').forEach(function (b) { b.disabled = true; });\n  google.script.run.withSuccessHandler(function (r) {\n    document.querySelectorAll('#sayfa button').forEach(function (b) { b.disabled = false; });\n    if (!r || !r.ok) return hataGoster(r);\n    S.tarlaSezonlari = r.tarlaSezonlari || S.tarlaSezonlari;\n    S.sezonParsel = r.sezonParsel || S.sezonParsel; S.parselSinir = r.parselSinir || S.parselSinir;\n    kapat(); ciz(); durum(r.mesaj || 'Sezon açıldı.');\n  }).withFailureHandler(function (e) { document.querySelectorAll('#sayfa button').forEach(function (b) { b.disabled = false; }); durum('Sezon açılamadı: ' + e.message); })\n    .tarlaPanelKaydet(ANAHTAR, { tur: 'tarlaSezonEkle', sezon: sezon });\n}\nfunction hataGoster(r) {\n  if (r && r.kapali) { document.querySelector('main').innerHTML = '<div class=\"kart\" style=\"margin-top:20px\">Bu paylaşım kapatıldı.</div>'; kapat(); return; }\n  durum((r && r.hata) || 'İşlem yapılamadı.');\n}\n// ---------- Tarım ve Hayvancılık: Ziraat ve Hayvancılık menüleri (uygulamadaki Tarım ekranının düzeni) ----------\nvar T = { yuklendi: false, hata: null, ozet: [], gunluk: [], detay: [], tarim: [], hasat: [], besi: [] };\nvar TS = { gunluk: false, gun: null, hafta: null, ciftlik: null };\nvar CIFTLIK_SIRASI = ['Şekersüt', 'Aslım', 'Taşağıl', 'Fidanlık'];\nvar ESK_BESI = 'ESK-Taşağıl Çiftliği Besi Danası', DIGER = 'Diğer (Güvenlik, Çumpaş, Konya Merkez, Yönetici)', ESK_DETAY = 'ESK-Taşağıl Çiftliği';\nvar ANA_ISLETMELER = ['Fethiye Şube', 'Fethiye Şube Holstein Besi', 'Pankent Çiftliği', 'Erentepe Şube', 'Aslım Çiftliği Besi Danası', ESK_BESI];\nvar DETAY_ISLETMELERI = ['Fethiye Şube', 'Erentepe Şube', 'Aslım Çiftliği', ESK_DETAY];\nvar AYLAR = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];\nvar GUNLER = ['Pazar', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi'];\n\nfunction tSayiOku(v) {\n  if (v === '' || v == null) return null; if (typeof v === 'number') return v;\n  var s = String(v).trim().replace(/ /g, ''); if (!s) return null;\n  if (s.indexOf(',') >= 0) s = s.replace(/\\./g, '').replace(',', '.'); else if (/^-?\\d{1,3}(\\.\\d{3})+$/.test(s)) s = s.replace(/\\./g, '');\n  var x = parseFloat(s); return isNaN(x) ? null : x;\n}\nfunction tn(r, i) { return i < r.length ? (tSayiOku(r[i]) || 0) : 0; }\nfunction tg(v) { var m = /^(\\d{4})-(\\d{2})-(\\d{2})/.exec(String(v || '').trim()); return m ? m[1] + '-' + m[2] + '-' + m[3] : null; }\nfunction tDate(s) { var a = s.split('-'); return new Date(+a[0], +a[1] - 1, +a[2]); }\nfunction tFmt(d) { return d.getFullYear() + '-' + ('0' + (d.getMonth() + 1)).slice(-2) + '-' + ('0' + d.getDate()).slice(-2); }\nfunction tEkle(s, n) { var d = tDate(s); d.setDate(d.getDate() + n); return tFmt(d); }\nfunction haftaBasi(s) { var d = tDate(s); d.setDate(d.getDate() - (d.getDay() + 6) % 7); return tFmt(d); }\nfunction isoHafta(s) { var d = tDate(s), p = new Date(d); p.setDate(d.getDate() + 3 - (d.getDay() + 6) % 7); return Math.floor((p - new Date(p.getFullYear(), 0, 1)) / 86400000 / 7) + 1; }\nfunction arada(t, b, s) { return t >= b && t <= s; }\nfunction tarihKisa(s) { var a = s.split('-'); return a[2] + '.' + a[1] + '.' + a[0]; }\nfunction tarihUzun(s) { var d = tDate(s); return d.getDate() + ' ' + AYLAR[d.getMonth()] + ' ' + d.getFullYear() + ' ' + GUNLER[d.getDay()]; }\nfunction haftaEtiketi(s) { var p = tEkle(s, 6); return isoHafta(s) + '. Hafta · ' + tarihKisa(s).slice(0, 5) + ' – ' + tarihKisa(p); }\nfunction ts(v, ond) {\n  if (v == null || isNaN(v) || !isFinite(v)) return '—';\n  ond = ond || 0; return (ond ? v : Math.round(v)).toLocaleString('tr-TR', { minimumFractionDigits: ond, maximumFractionDigits: ond });\n}\nfunction tsT(v, ond) { return v == null || v === 0 ? '—' : ts(v, ond); }\nfunction tKucuk(s) { return String(s || '').replace(/İ/g, 'i').replace(/I/g, 'ı').toLowerCase().replace(/\\s+/g, ' ').trim(); }\nfunction tIcerir(n, l) { return l.some(function (x) { return n.indexOf(x) >= 0; }); }\nfunction cikisMi(b) { return tIcerir(tKucuk(b), ['cikan', 'çıkan']); }\nfunction kayipMi(g) { return tIcerir(tKucuk(g), ['ölen', 'olen', 'ölü', 'olu dog', 'atık', 'atik']); }\nfunction girisMi(g) { return tIcerir(tKucuk(g), ['doğan', 'dogan', 'alınan', 'alinan', 'satın al', 'satin al']); }\nvar KELIMELER = { sut: 'süt', sagilan: 'sağılan', buzagi: 'buzağı', 'buzagı': 'buzağı', dogan: 'doğan', dogum: 'doğum', olen: 'ölen', disi: 'dişi', duve: 'düve', boga: 'boğa' };\nvar ETIKETLER = { 'olu dogum': 'Ölü doğum', 'ölü dogum': 'Ölü doğum', 'atık buzagı': 'Atık buzağı', 'atık buzagi': 'Atık buzağı' };\nfunction gostergeAdi(g) { var n = tKucuk(g); if (ETIKETLER[n]) return ETIKETLER[n]; n = n.split(' ').map(function (w) { return KELIMELER[w] || w; }).join(' ');\n  return n ? (n[0] === 'i' ? 'İ' : n[0].toUpperCase()) + n.slice(1) : n; }\nfunction faaliyetHayvancilik(f) {\n  var s = String(f).toLowerCase().replace(/̇/g, '').replace(/ı/g, 'i').replace(/ğ/g, 'g').replace(/ş/g, 's').replace(/ö/g, 'o').replace(/ü/g, 'u').replace(/ç/g, 'c');\n  return ['sagim', 'sagmal', 'buzag', 'inek', 'duve', 'dana', 'boga', 'besi', 'kesim', 'asilama', 'tohumlama', 'suni tohum', 'dogum', 'veteriner',\n    'mastitis', 'kupe', 'ahir', 'agil', 'padok', 'tirnak', 'rasyon', 'hayvan'].some(function (x) { return s.indexOf(x) >= 0; });\n}\nfunction ciftlikRengi(c) { return { 'Şekersüt': '#1d4ed8', 'Aslım': '#b45309', 'Taşağıl': '#ea580c', 'Fidanlık': '#15803D' }[c] || '#64748b'; }\n\nfunction tarimVerisiOku(r) {\n  T.ozet = (r.ozet || []).map(function (x) { var t = tg(x[0]); if (!t || !String(x[1] || '').trim()) return null;\n    return { t: t, isletme: String(x[1]).trim(), hayvan: tn(x, 4), sagilan: tn(x, 5), sut: tn(x, 6), dogan: tn(x, 7), kesimSatis: tn(x, 8), buzagiOlum: tn(x, 9),\n      kesilenDana: tn(x, 10), inekOlum: tn(x, 11), gencOlum: tn(x, 13), yavruAtma: tn(x, 14), olenDana: tn(x, 15), alinan: tn(x, 16) }; }).filter(Boolean)\n    .sort(function (a, b) { return a.t < b.t ? -1 : a.t > b.t ? 1 : 0; });\n  T.gunluk = (r.gunluk || []).map(function (x) { var t = tg(x[0]); if (!t) return null;\n    function suru(i) { return { toplam: tn(x, i), sagmal: tn(x, i + 1), kuruGebe: tn(x, i + 2), erkek: tn(x, i + 3), sut: tn(x, i + 4), satilan: tn(x, i + 5) }; }\n    var f = suru(1), e = suru(7);\n    return { t: t, f: f, e: e, toplamHayvan: f.toplam + e.toplam, sagmal: f.sagmal + e.sagmal, sut: f.sut + e.sut, satilan: f.satilan + e.satilan }; }).filter(Boolean)\n    .sort(function (a, b) { return a.t < b.t ? -1 : a.t > b.t ? 1 : 0; });\n  T.detay = (r.detay || []).map(function (x) { var t = tg(x[0]), d = tSayiOku(x[4]);\n    if (!t || d == null || !String(x[1] || '').trim() || !String(x[3] || '').trim() || /\\/\\s*(topl|hay)/i.test(String(x[3]))) return null;\n    return { t: t, isletme: String(x[1]).trim(), bolum: String(x[2] || '').trim(), gosterge: String(x[3]).trim(), deger: d }; }).filter(Boolean);\n  T.tarim = (r.tarim || []).map(function (x) { var t = tg(x[0]), c = String(x[1] || '').trim(), f = String(x[2] || '').trim();\n    return t && c && f ? { t: t, ciftlik: c, faaliyet: f, kaynak: String(x[3] || '').trim(), hayvancilik: faaliyetHayvancilik(f) } : null; }).filter(Boolean)\n    .sort(function (a, b) { return a.t < b.t ? -1 : a.t > b.t ? 1 : 0; });\n  T.hasat = (r.hasat || []).filter(function (x) { return x.length >= 2 && String(x[0]).trim(); }).map(function (x) {\n    var alan = tSayiOku(x[2]), top = tSayiOku(x[3]), v = tSayiOku(x[4]); if (v == null && alan > 0 && top != null) v = top / alan;\n    return { urun: String(x[0]).trim(), ciftlik: String(x[1]).trim(), alan: alan, toplam: top, verim: v, tarih: tg(x[5]) }; });\n  T.besi = (r.besi || []).filter(function (x) { return String(x[0] || '').trim(); })\n    .map(function (x) { return { isletme: String(x[0]).trim(), yerli: tn(x, 1), erkek: tn(x, 2), inek: tn(x, 3) }; });\n  T.yuklendi = true;\n}\nfunction tEkim() { return (S.ekim || []).filter(function (x) { return String(x[0] || '').trim(); })\n  .map(function (x) { return { ciftlik: String(x[0]).trim(), urun: String(x[1] || '').trim(), plan: tSayiOku(x[2]), ekilen: tSayiOku(x[3]) }; }); }\nfunction tUniq(l) { var m = {}; l.forEach(function (x) { m[x] = 1; }); return Object.keys(m).sort().reverse(); }\nfunction tGunler() { return tUniq(T.ozet.map(function (o) { return o.t; }).concat(T.gunluk.map(function (g) { return g.t; }), T.tarim.map(function (t) { return t.t; }))); }\nfunction tHaftalar() { return tUniq(T.ozet.concat(T.gunluk, T.tarim).map(function (x) { return haftaBasi(x.t); })); }\n\n// ---- hayvancılık hesapları (uygulamayla aynı) ----\nfunction canliHayvanOzeti(bas, son) {\n  var donem = T.ozet.filter(function (o) { return arada(o.t, bas, son); }), gun = null;\n  donem.forEach(function (o) { if (!gun || o.t > gun) gun = o.t; });\n  var A = ['sut', 'sagilanGun', 'dogan', 'kesimSatis', 'buzagiOlum', 'kesilenDana', 'inekOlum', 'gencOlum', 'yavruAtma', 'olenDana'];\n  function hesapla(ad, uyar) {\n    var s = { ad: ad, hayvan: 0, sagilan: 0 }; A.forEach(function (k) { s[k] = 0; });\n    donem.forEach(function (o) { if (!uyar(o.isletme)) return;\n      if (o.t === gun) { s.hayvan += o.hayvan; s.sagilan += o.sagilan; }\n      s.sut += o.sut; s.sagilanGun += o.sagilan; s.dogan += o.dogan; s.kesimSatis += o.kesimSatis; s.buzagiOlum += o.buzagiOlum;\n      s.kesilenDana += o.kesilenDana; s.inekOlum += o.inekOlum; s.gencOlum += o.gencOlum; s.yavruAtma += o.yavruAtma; s.olenDana += o.olenDana; });\n    return s;\n  }\n  var satirlar = ANA_ISLETMELER.map(function (a) { return hesapla(a, function (x) { return x === a; }); })\n    .concat([hesapla(DIGER, function (x) { return ANA_ISLETMELER.indexOf(x) < 0; })]);\n  function top(k, eskHaric) { return satirlar.filter(function (s) { return !(eskHaric && s.ad === ESK_BESI); }).reduce(function (a, s) { return a + s[k]; }, 0); }\n  var toplam = { ad: 'ÇİFTLİKLER TOPLAM', sagilan: top('sagilan'),\n    hayvan: satirlar.filter(function (s) { return s.ad !== ESK_BESI && s.ad !== DIGER; }).reduce(function (a, s) { return a + s.hayvan; }, 0) };\n  A.forEach(function (k) { toplam[k] = top(k, k === 'kesilenDana' || k === 'olenDana'); });\n  return { ozetGunu: gun, satirlar: satirlar, toplam: toplam, bul: function (ad) { return satirlar.filter(function (s) { return s.ad === ad; })[0]; } };\n}\nfunction ortVerim(s) { return s.sagilanGun > 0 ? s.sut / s.sagilanGun : 0; }\nfunction eskDetayGunleri() {\n  var g = {}, yedek = {};\n  T.detay.forEach(function (d) {\n    if (d.isletme !== ESK_DETAY) return;\n    var n = tKucuk(d.gosterge), x = g[d.t] || (g[d.t] = { mevcut: 0, giren: 0, kesilen: 0, olen: 0 });\n    if (cikisMi(d.bolum) && n === 'toplam') x.mevcut = d.deger;\n    else if (n === 'ithal besi danası' || n === 'yerli besi danası') yedek[d.t] = (yedek[d.t] || 0) + d.deger;\n    else if (girisMi(d.gosterge)) x.giren += d.deger;\n    else if (cikisMi(d.bolum) && kayipMi(d.gosterge)) x.olen += d.deger;\n    else if (cikisMi(d.bolum) && n.indexOf('kesilen') >= 0) x.kesilen += d.deger;\n  });\n  Object.keys(g).forEach(function (t) { if (g[t].mevcut === 0) g[t].mevcut = yedek[t] || 0; if (g[t].mevcut <= 0) delete g[t]; });\n  return g;\n}\nfunction eskSonHareketler(d) {\n  var kesim = {}, gelen = {};\n  T.ozet.forEach(function (o) { if (o.isletme !== ESK_BESI || o.t > d) return; if (o.kesilenDana > 0) kesim[o.t] = o.kesilenDana; if (o.alinan > 0) gelen[o.t] = o.alinan; });\n  var g = eskDetayGunleri(); Object.keys(g).forEach(function (t) { if (t > d) return; if (g[t].kesilen > 0) kesim[t] = g[t].kesilen; if (g[t].giren > 0) gelen[t] = g[t].giren; });\n  function enSon(m) { var k = Object.keys(m).sort(); return k.length ? { t: k[k.length - 1], adet: m[k[k.length - 1]] } : null; }\n  return { kesim: enSon(kesim), gelen: enSon(gelen) };\n}\nfunction eskGunSonuHayvan(d) { var x = eskDetayGunleri()[d]; return x && x.mevcut > 0 ? x.mevcut : null; }\nfunction eskGelenToplam(bas, son) {\n  var m = {};\n  T.ozet.forEach(function (o) { if (o.isletme === ESK_BESI && arada(o.t, bas, son) && o.alinan > 0) m[o.t] = o.alinan; });\n  var g = eskDetayGunleri(); Object.keys(g).forEach(function (t) { if (arada(t, bas, son) && g[t].giren > 0) m[t] = g[t].giren; });\n  return Object.keys(m).reduce(function (a, k) { return a + m[k]; }, 0);\n}\nfunction kayipOzeti(bas, son) {\n  if (!T.detay.some(function (d) { return arada(d.t, bas, son) && d.isletme !== ESK_DETAY; })) return null;\n  var ip = {};\n  T.detay.forEach(function (d) {\n    if (!arada(d.t, bas, son) || d.isletme === ESK_DETAY || !cikisMi(d.bolum) || !kayipMi(d.gosterge)) return;\n    var g = ip[d.isletme] || (ip[d.isletme] = {}), ad = gostergeAdi(d.gosterge).toLowerCase(); g[ad] = (g[ad] || 0) + d.deger;\n  });\n  var toplam = 0, p = [];\n  DETAY_ISLETMELERI.forEach(function (i) { var g = ip[i]; if (!g || !Object.keys(g).length) return;\n    Object.keys(g).forEach(function (k) { toplam += g[k]; });\n    p.push(i.split(' ')[0] + ': ' + Object.keys(g).map(function (k) { return k + ' ' + Math.round(g[k]); }).join(', ')); });\n  return { toplam: toplam, aciklama: p.length ? p.join(' · ') : 'Kayıp yok' };\n}\nfunction gostergeler(bas, gunlukMu) {\n  var son = gunlukMu ? bas : tEkle(bas, 6), oz = canliHayvanOzeti(bas, son), esk = oz.bul(ESK_BESI), ozVar = oz.ozetGunu != null;\n  var gunler = T.gunluk.filter(function (g) { return arada(g.t, bas, son); }), sonG = gunler.length ? gunler[gunler.length - 1] : null;\n  var e = eskSonHareketler(son), r = {};\n  if (gunlukMu) {\n    var g = gunler[0] || null;\n    r.toplamHayvan = ozVar ? oz.toplam.hayvan : g && g.toplamHayvan; r.sagilan = ozVar ? oz.toplam.sagilan : g && g.sagmal;\n    r.sut = ozVar ? oz.toplam.sut : g && g.sut; r.ortVerim = (r.sagilan || 0) > 0 && r.sut != null ? r.sut / r.sagilan : null;\n    r.eskBesiHayvan = eskGunSonuHayvan(bas); if (r.eskBesiHayvan == null && ozVar && esk) r.eskBesiHayvan = esk.hayvan;\n    r.eskGelen = ozVar || eskGunSonuHayvan(bas) != null ? eskGelenToplam(bas, bas) : null;\n    r.satilan = g ? g.satilan : null;\n  } else {\n    var sut = gunler.length ? gunler.reduce(function (a, x) { return a + x.sut; }, 0) : null, sagGun = gunler.reduce(function (a, x) { return a + x.sagmal; }, 0);\n    r.toplamHayvan = sonG ? sonG.toplamHayvan : ozVar ? oz.toplam.hayvan : null; r.sagilan = sonG ? sonG.sagmal : ozVar ? oz.toplam.sagilan : null;\n    r.sut = sut; r.ortVerim = sagGun > 0 && sut != null ? sut / sagGun : null;\n    r.eskBesiHayvan = ozVar && esk ? esk.hayvan : null; r.eskGelen = ozVar ? eskGelenToplam(bas, son) : null;\n    r.satilan = gunler.length ? gunler.reduce(function (a, x) { return a + x.satilan; }, 0) : null;\n  }\n  ['dogan', 'kesilenDana', 'kesimSatis', 'yavruAtma', 'inekOlum', 'gencOlum', 'olenDana'].forEach(function (k) { r[k] = ozVar ? oz.toplam[k] : null; });\n  r.olenBuzagi = ozVar ? oz.toplam.buzagiOlum : null;\n  r.eskKesilen = ozVar && esk ? esk.kesilenDana : null; r.eskOlenDana = ozVar && esk ? esk.olenDana : null;\n  r.eskSonKesim = e.kesim; r.eskSonGelen = e.gelen;\n  r.kayip = r.olenBuzagi == null ? null : r.olenBuzagi + (r.yavruAtma || 0) + (r.inekOlum || 0) + (r.gencOlum || 0) + (r.olenDana || 0);\n  if (r.olenBuzagi != null) {\n    var p = [];\n    if (r.yavruAtma > 0) p.push('Yavru atma/ölü doğum ' + Math.round(r.yavruAtma)); if (r.olenBuzagi > 0) p.push('Buzağı ' + Math.round(r.olenBuzagi));\n    if (r.inekOlum > 0) p.push('İnek ' + Math.round(r.inekOlum)); if (r.gencOlum > 0) p.push('Genç ' + Math.round(r.gencOlum)); if (r.olenDana > 0) p.push('Dana ' + Math.round(r.olenDana));\n    r.kayipAyrinti = p.length ? p.join(' · ') : 'Kayıp yok';\n  }\n  r.eskVar = r.eskBesiHayvan != null || r.eskKesilen != null || r.eskGelen != null;\n  r.oz = oz; r.son = son; r.gunler = gunler;\n  return r;\n}\n\n// ---- işletme raporları (uygulamadaki \"İşletme Raporları\" paneli) ----\nvar BOLUM_ADLARI = { 'hayvan sayisi': 'Hayvan Sayıları', 'hayvan sayısı': 'Hayvan Sayıları', 'sut (lt)': 'Süt Üretimi (lt)', 'sut (kg)': 'Süt Üretimi (kg)',\n  'ort.sut verimi': 'Ortalama Süt Verimi', 'lt': 'Süt Dağılımı (lt)', 'kg': 'Süt Dağılımı (kg)', 'suruden cikanlar': 'Sürüden Çıkanlar', 'sürüden çıkanlar': 'Sürüden Çıkanlar',\n  'disiler': 'Dişi Hayvanlar', 'dişiler': 'Dişi Hayvanlar', 'erkekler': 'Erkek Hayvanlar', 'aslım çiftliği': 'Sürü Yapısı', 'taşağıl çiftliği': 'Sürü Yapısı' };\n(function () {\n  var e = { 'toplam hayv.say.': 'Toplam hayvan', 'sagılan hay.say.': 'Sağılan hayvan', 'sagilan hay.say.': 'Sağılan hayvan', 'sagilan hayvan sayisi': 'Sağılan hayvan',\n    'buzag.ver.mama': 'Buzağıya verilen mama', 'buzag.ver.süt': 'Buzağıya verilen süt', 'buzag.ver.sut': 'Buzağıya verilen süt', 'buzag.ver.kolostrum': 'Buzağıya verilen kolostrum',\n    'dokulen kolostrum': 'Dökülen kolostrum', 'antibiyot.sut': 'Antibiyotikli süt', 'ant tank': 'Antibiyotik tankı', 'satilan sut': 'Satılan süt', 'satilan sut (kg)': 'Satılan süt (kg)',\n    'sagilan sut': 'Sağılan süt', 'sagilan': 'Sağılan' };\n  for (var k in e) ETIKETLER[k] = e[k];\n  var w = { yuksek: 'yüksek', dusuk: 'düşük', bugun: 'bugün', bos: 'boş', 'dısardan': 'dışarıdan', 'dışardan': 'dışarıdan', sutten: 'sütten', cikan: 'çıkan', satilan: 'satılan' };\n  for (var k2 in w) KELIMELER[k2] = w[k2];\n})();\nfunction buyukIlk(n) { return n ? (n[0] === 'i' ? 'İ' : n[0].toUpperCase()) + n.slice(1) : n; }\nfunction bolumAdi(b) { var n = tKucuk(b); return BOLUM_ADLARI[n] || buyukIlk(n.split(' ').map(function (x) { return KELIMELER[x] || x; }).join(' ')); }\nfunction detayTuru(b0, g0) {\n  var b = tKucuk(b0), g = tKucuk(g0);\n  if (b.indexOf('ort') >= 0 || g.indexOf('ort.') >= 0 || g.indexOf('süt ort') === 0) return 'ortalama';\n  if (cikisMi(b0) || b.indexOf('sut (') === 0 || b.indexOf('süt (') === 0 || b === 'lt' || b === 'kg' || girisMi(g0) ||\n    tIcerir(g, ['kesilen', 'ölen', 'olen', 'giden', 'satılan', 'satilan'])) return 'toplam';\n  return 'sonGun';\n}\nfunction detayGunleri(isl, bas, son) { return tUniq(T.detay.filter(function (d) { return d.isletme === isl && arada(d.t, bas, son); }).map(function (d) { return d.t; })).reverse(); }\nfunction isletmeDetayi(isl, bas, son) {\n  var gunler = detayGunleri(isl, bas, son); if (!gunler.length) return [];\n  var sonGun = gunler[gunler.length - 1], sira = [], bilgi = {}, toplam = {}, adet = {}, sonD = {};\n  T.detay.forEach(function (d) {\n    if (d.isletme !== isl || !arada(d.t, bas, son)) return;\n    var k = tKucuk(d.bolum) + '|' + tKucuk(d.gosterge);\n    if (!bilgi[k]) { bilgi[k] = [d.bolum, d.gosterge]; sira.push(k); }\n    toplam[k] = (toplam[k] || 0) + d.deger; adet[k] = (adet[k] || 0) + 1; if (d.t === sonGun) sonD[k] = d.deger;\n  });\n  var bolumler = {}, bsira = [];\n  sira.forEach(function (k) {\n    var b = bilgi[k][0], g = bilgi[k][1], tur = detayTuru(b, g);\n    var deger = tur === 'toplam' ? toplam[k] : tur === 'sonGun' ? (sonD[k] || 0) : toplam[k] / adet[k];\n    if (deger === 0) return;\n    var ad = bolumAdi(b), key = ad + '|' + tur;\n    if (!bolumler[key]) { bolumler[key] = { ad: ad, tur: tur, satirlar: [] }; bsira.push(key); }\n    bolumler[key].satirlar.push([gostergeAdi(g), deger]);\n  });\n  return { gunler: gunler, bolumler: bsira.map(function (k) { return bolumler[k]; }) };\n}\nvar TS_ISL = DETAY_ISLETMELERI[0];\nfunction isletmeRaporlari(bas, son) {\n  var tekGun = bas === son, x = isletmeDetayi(TS_ISL, bas, son);\n  var h = '<h3>İşletme Raporları</h3><div class=\"kart\"><div class=\"cipler\">' + DETAY_ISLETMELERI.map(function (i) {\n    return '<span class=\"cip' + (i === TS_ISL ? ' secili' : '') + '\" onclick=\"TS_ISL=' + js(i) + ';ciz()\">' + esc(i.replace(' Çiftliği', '').replace(' Şube', '')) + '</span>'; }).join('') + '</div>';\n  if (!x.bolumler || !x.bolumler.length) return h + '<div style=\"color:var(--soluk);padding:8px 2px\">Bu dönem için işletme raporu verisi yok.</div></div>';\n  var g = x.gunler, kis = function (t) { return tarihKisa(t).slice(0, 5); };\n  h += '<div class=\"ipucu\">' + (tekGun ? 'Kaynak: işletme günlük raporu, ' + tarihKisa(g[g.length - 1]) :\n    'Kaynak: işletme günlük raporları, ' + g.length + ' gün (' + kis(g[0]) + ' – ' + kis(g[g.length - 1]) + '). Hareketler dönem toplamı, hayvan sayıları ' + kis(g[g.length - 1]) + ' itibarıyla.') + '</div>';\n  x.bolumler.forEach(function (b) {\n    var ack = { toplam: 'dönem toplamı', sonGun: 'son veri günü', ortalama: 'günlük ortalama' }[b.tur];\n    h += '<div style=\"font-weight:700;font-size:13.5px;margin:12px 0 4px;color:' + (b.ad === 'Sürüden Çıkanlar' ? '#ea580c' : '#0f172a') + '\">' +\n      esc(tekGun || b.tur === 'sonGun' ? b.ad : b.ad + ' (' + ack + ')') + '</div><table>' +\n      b.satirlar.map(function (r) { return '<tr><td>' + esc(r[0]) + '</td><td class=\"sag\">' + ts(r[1], r[1] === Math.round(r[1]) ? 0 : 1) + '</td></tr>'; }).join('') + '</table>';\n  });\n  return h + '</div>';\n}\nfunction fark(v, ond) { var y = ond ? v : Math.round(v); if (Math.abs(y) < (ond ? 0.005 : 0.5)) return '—'; return (y > 0 ? '+' : '-') + ts(Math.abs(y), ond); }\nfunction suruTablosu(ilk, son, e1, e2) {\n  var bos = { toplam: 0, sagmal: 0, kuruGebe: 0, erkek: 0, sut: 0, satilan: 0 };\n  var fi = ilk ? ilk.f : bos, fs = son ? son.f : bos, ei = ilk ? ilk.e : bos, es = son ? son.e : bos;\n  function ort(s) { return s.sagmal > 0 ? s.sut / s.sagmal : 0; }\n  function satir(ad, f, ond) {\n    function d(x, g) { return g ? ts(f(x), ond) : '—'; } function fk(a, b) { return ilk && son ? fark(f(b) - f(a), ond) : '—'; }\n    return [ad, d(fi, ilk), d(fs, son), fk(fi, fs), d(ei, ilk), d(es, son), fk(ei, es)];\n  }\n  return tablo(['Gösterge', 'Fethiye ' + e1, 'Fethiye ' + e2, 'Fark', 'Erentepe ' + e1, 'Erentepe ' + e2, 'Fark'], [\n    satir('Toplam hayvan', function (s) { return s.toplam; }), satir('Sağmal', function (s) { return s.sagmal; }), satir('Kuru gebe', function (s) { return s.kuruGebe; }),\n    satir('Erkek', function (s) { return s.erkek; }), satir('Sağılan süt (kg)', function (s) { return s.sut; }), satir('Süt ortalaması (kg)', ort, 2),\n    satir('Satılan süt (kg)', function (s) { return s.satilan; })]);\n}\nfunction gunlukSutTablosu(gunler) {\n  var GK = ['Paz', 'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt'];\n  var r = gunler.map(function (g) { return [tarihKisa(g.t) + ' ' + GK[tDate(g.t).getDay()], ts(g.f.sut), ts(g.e.sut), ts(g.sut), ts(g.sagmal), g.sagmal > 0 ? ts(g.sut / g.sagmal, 1) : '—', ts(g.satilan)]; });\n  var t = function (f) { return gunler.reduce(function (a, g) { return a + f(g); }, 0); }, sag = t(function (g) { return g.sagmal; });\n  r.push(['Hafta Toplamı', ts(t(function (g) { return g.f.sut; })), ts(t(function (g) { return g.e.sut; })), ts(t(function (g) { return g.sut; })), ts(sag),\n    sag > 0 ? ts(t(function (g) { return g.sut; }) / sag, 1) : '—', ts(t(function (g) { return g.satilan; }))]);\n  return tablo(['Tarih', 'Fethiye Süt', 'Erentepe Süt', 'Toplam Süt', 'Sağmal', 'Ort. Verim', 'Satılan'], r, true);\n}\n\n// ---- görünüm ----\nfunction gKart(b, d, alt, renk) { return '<div class=\"gk\"><span>' + esc(b) + '</span><b' + (renk ? ' style=\"color:' + renk + '\"' : '') + '>' + esc(d) + '</b>' + (alt ? '<i>' + esc(alt) + '</i>' : '') + '</div>'; }\nfunction tablo(bas, satirlar, vurgu) {\n  return '<div class=\"kart\" style=\"overflow-x:auto\"><table><tr>' + bas.map(function (b, i) { return '<th' + (i ? ' class=\"sag\"' : '') + '>' + esc(b) + '</th>'; }).join('') + '</tr>' +\n    satirlar.map(function (r, j) { return '<tr' + (vurgu && j === satirlar.length - 1 ? ' style=\"font-weight:700;background:#f1f5f0\"' : '') + '>' +\n      r.map(function (c, i) { return '<td' + (i ? ' class=\"sag\"' : '') + '>' + esc(c) + '</td>'; }).join('') + '</tr>'; }).join('') + '</table></div>';\n}\nfunction donemSecici(gunlukMu) {\n  var l = gunlukMu ? tGunler() : tHaftalar(); if (!l.length) return { bas: null, html: '' };\n  var sec = gunlukMu ? TS.gun : TS.hafta; if (l.indexOf(sec) < 0) sec = l[0];\n  return { bas: sec, html: '<div class=\"cipler\"><span class=\"cip' + (gunlukMu ? ' secili' : '') + '\" onclick=\"TS.gunluk=true;ciz()\">Günlük</span>' +\n    '<span class=\"cip' + (gunlukMu ? '' : ' secili') + '\" onclick=\"TS.gunluk=false;ciz()\">Haftalık</span></div>' +\n    '<select onchange=\"TS.' + (gunlukMu ? 'gun' : 'hafta') + '=this.value;ciz()\">' +\n    l.map(function (x) { return '<option value=\"' + x + '\"' + (x === sec ? ' selected' : '') + '>' + esc(gunlukMu ? tarihUzun(x) : haftaEtiketi(x)) + '</option>'; }).join('') + '</select>' };\n}\nfunction faaliyetPaneli(hayvanMi, bas, son) {\n  var turC = {}; T.tarim.forEach(function (t) { if (t.hayvancilik === hayvanMi) turC[t.ciftlik] = 1; });\n  var cf = CIFTLIK_SIRASI.filter(function (c) { return turC[c]; }).concat(Object.keys(turC).filter(function (c) { return CIFTLIK_SIRASI.indexOf(c) < 0; }));\n  if (TS.ciftlik && cf.indexOf(TS.ciftlik) < 0) TS.ciftlik = null;\n  var akis = !bas ? [] : T.tarim.filter(function (t) { return arada(t.t, bas, son) && t.hayvancilik === hayvanMi && (!TS.ciftlik || t.ciftlik === TS.ciftlik); }).reverse();\n  var h = '<h3>' + (hayvanMi ? 'Hayvancılık' : 'Ziraat') + ' Faaliyetleri (' + (!bas ? 'kayıt yok' : TS.gunluk ? tarihUzun(bas) : haftaEtiketi(bas)) + ')</h3><div class=\"kart\"><div class=\"cipler\">' +\n    '<span class=\"cip' + (TS.ciftlik ? '' : ' secili') + '\" onclick=\"TS.ciftlik=null;ciz()\">Tümü</span>' +\n    cf.map(function (c) { return '<span class=\"cip' + (TS.ciftlik === c ? ' secili' : '') + '\" onclick=\"TS.ciftlik=' + js(c) + ';ciz()\">' + esc(c) + '</span>'; }).join('') + '</div>';\n  if (!akis.length) h += '<div style=\"color:var(--soluk);padding:10px 2px\">Bu dönemde kayıt yok.</div>';\n  akis.forEach(function (f) {\n    var r = ciftlikRengi(f.ciftlik);\n    h += '<div style=\"display:flex;gap:10px;padding:8px 0;border-bottom:1px solid var(--kenar)\"><div style=\"width:4px;min-height:38px;border-radius:2px;background:' + r + '\"></div><div>' +\n      '<div style=\"font-size:12.5px;font-weight:700;color:' + r + '\">' + esc(f.ciftlik) + ' · ' + tarihKisa(f.t) + (f.kaynak === 'Form-Bekliyor' ? ' · kontrol bekliyor' : '') + '</div>' +\n      '<div style=\"font-size:14px;line-height:1.35\">' + esc(f.faaliyet) + '</div></div></div>';\n  });\n  return h + '</div>';\n}\nfunction ziraatEkrani() {\n  var d = donemSecici(TS.gunluk), bas = d.bas, son = bas && (TS.gunluk ? bas : tEkle(bas, 6)), ekim = tEkim();\n  var plan = ekim.reduce(function (a, e) { return a + (e.plan || 0); }, 0), ekilen = ekim.reduce(function (a, e) { return a + (e.ekilen || 0); }, 0);\n  var h = d.html + '<div class=\"gizgara\">' + gKart('Planlanan Alan', ts(plan) + ' da') + gKart('Ekilen Alan', ts(ekilen) + ' da', plan > 0 ? \"Planın %\" + ts(ekilen / plan * 100) + \"'i\" : '', '#15803D') + '</div>';\n  if (menuAcik('tarla')) h += menu('▦', 'Tarla Haritaları', 'Parseller, haritadaki ekiliş ve tarım icmaliyle karşılaştırma', \"git('ana')\");\n  h += '<h3>Ekim Alanları (dekar)</h3><div class=\"kart\">' + (!ekim.length ? 'Ekim alanı verisi yok.' : ekim.map(function (e) {\n    var o = (e.plan || 0) > 0 && e.ekilen != null ? Math.min(1.5, e.ekilen / e.plan) : null;\n    return '<div style=\"padding:7px 0\"><div style=\"display:flex;justify-content:space-between;gap:8px;font-size:14px\"><span><b style=\"color:' + ciftlikRengi(e.ciftlik) + '\">' + esc(e.ciftlik) + '</b>&nbsp; ' + esc(e.urun) + '</span>' +\n      '<b style=\"font-size:13.5px\">' + (e.ekilen == null ? '—' : ts(e.ekilen)) + ' / ' + ts(e.plan) + ' da</b></div>' +\n      '<div style=\"height:7px;border-radius:4px;background:#e2e8f0;margin-top:6px\"><div style=\"height:7px;border-radius:4px;width:' + (o == null ? 0 : Math.min(1, o) * 100) + '%;background:' + (o >= 1 ? '#15803D' : '#3D7A55') + '\"></div></div></div>';\n  }).join('')) + '</div>';\n  h += '<h3>Hasat / Verim Özeti</h3>' + (!T.hasat.length ? '<div class=\"kart\">Hasat kaydı yok.</div>' : tablo(['Ürün', 'Çiftlik', 'Alan (da)', 'Toplam (kg)', 'Verim (kg/da)', 'Kayıt Tarihi'],\n    T.hasat.map(function (x) { return [x.urun, x.ciftlik, ts(x.alan), ts(x.toplam), ts(x.verim), x.tarih ? tarihKisa(x.tarih) : '—']; })));\n  return h + faaliyetPaneli(false, bas, son);\n}\nfunction hayvancilikEkrani() {\n  var d = donemSecici(TS.gunluk), bas = d.bas, h = d.html;\n  if (!bas) return h + '<div class=\"kart\">Hayvancılık verisi yok.</div>';\n  var g = gostergeler(bas, TS.gunluk), son = g.son, ko = kayipOzeti(bas, son), oz = g.oz;\n  if (oz.ozetGunu == null) h += '<div class=\"bilgi\" style=\"background:#fffbeb;border-color:#fde68a\">Bu ' + (TS.gunluk ? 'gün' : 'hafta') + ' için işletme özeti yok; kartlarda yalnızca günlük süt verisi bulunan değerler gösterilir.</div>';\n  h += '<h3>Çiftliklerimiz</h3><div class=\"gizgara\">' + gKart('Toplam Hayvan', ts(g.toplamHayvan)) + gKart('Sağılan Hayvan', ts(g.sagilan), '', '#1d4ed8') +\n    gKart(TS.gunluk ? 'Günlük Süt' : 'Haftalık Süt', g.sut == null ? '—' : ts(g.sut) + ' kg', g.ortVerim == null ? '' : 'Ort. ' + ts(g.ortVerim, 1) + ' kg/baş/gün', '#1d4ed8') +\n    gKart('Satılan Süt', g.satilan == null ? '—' : ts(g.satilan) + ' kg', 'Fethiye + Erentepe', '#1d4ed8') +\n    gKart('Doğan Buzağı', ts(g.dogan), g.olenBuzagi == null ? '' : 'Ölen buzağı: ' + ts(g.olenBuzagi), '#15803D') +\n    gKart('Hayvan Kayıpları', ts(ko ? ko.toplam : g.kayip), ko ? ko.aciklama : g.kayipAyrinti, '#ea580c') +\n    gKart('Kesilen Dana', ts(g.kesilenDana), '', '#ea580c') + gKart('İnek/Düve Kesim-Satış', ts(g.kesimSatis), '', '#ea580c') + '</div>';\n  if (g.eskVar) {\n    var alt = TS.gunluk ? 'Gün toplamı' : 'Hafta toplamı';\n    h += '<h3 style=\"color:#ea580c\">ESK-Taşağıl Çiftliği (Besi)</h3><div class=\"ipucu\" style=\"margin:-4px 2px 6px\">Çiftliklerimiz toplamına dahil değildir.</div><div class=\"gizgara\">' +\n      gKart('Besi Hayvanı', ts(g.eskBesiHayvan), '', '#ea580c') + gKart('Kesilen Dana', ts(g.eskKesilen), alt, '#ea580c') + gKart('Gelen Hayvan', ts(g.eskGelen), alt, '#15803D') +\n      (g.eskSonKesim && !(g.eskKesilen > 0) ? gKart('Son Kesim', ts(g.eskSonKesim.adet), tarihKisa(g.eskSonKesim.t), '#ea580c') : '') +\n      (g.eskSonGelen && !(g.eskGelen > 0) ? gKart('Son Gelen Hayvan', ts(g.eskSonGelen.adet), tarihKisa(g.eskSonGelen.t), '#15803D') : '') +\n      (g.eskOlenDana > 0 ? gKart('Ölen Dana', ts(g.eskOlenDana), '', '#ea580c') : '') + '</div>';\n  }\n  if (!TS.gunluk) h += '<h3>Günlük Süt Üretimi (kg)</h3>' + (g.gunler.length ? gunlukSutTablosu(g.gunler) : '<div class=\"kart\">Bu hafta için günlük süt verisi yok.</div>');\n  h += isletmeRaporlari(bas, son);\n  h += '<h3>İşletme Bazlı Canlı Hayvan</h3>' + (oz.ozetGunu == null ? '' : '<div class=\"ipucu\" style=\"margin:-4px 2px 6px\">' +\n    (TS.gunluk ? 'Kaynak: ' + tarihKisa(oz.ozetGunu) + ' işletme özeti.' : 'Hayvan ve sağılan: ' + tarihKisa(oz.ozetGunu) + '. Süt ve olaylar: hafta toplamı.') + '</div>');\n  if (oz.ozetGunu == null) h += '<div class=\"kart\">İşletme özeti verisi yok.</div>';\n  else h += tablo(['İşletme', 'Hayvan', 'Sağılan', 'Süt (kg)', 'Ort. Verim', 'İnek/Düve Kesim-Satış', 'Buzağı Ölümü', 'Yavru Atma/Ölü Doğum', 'İnek/Genç Ölüm', 'Kesilen Dana'],\n    oz.satirlar.concat([oz.toplam]).map(function (s) { var v = ortVerim(s);\n      return [s.ad, tsT(s.hayvan), tsT(s.sagilan), tsT(s.sut), v > 0 ? ts(v, 1) : '—', tsT(s.kesimSatis), tsT(s.buzagiOlum), tsT(s.yavruAtma), tsT(s.inekOlum + s.gencOlum), tsT(s.kesilenDana)]; }), true);\n  if (TS.gunluk) {\n    var bugun = T.gunluk.filter(function (x) { return x.t === bas; })[0] || null, onceki = null;\n    T.gunluk.forEach(function (x) { if (x.t < bas) onceki = x; });\n    h += '<h3>Süt Sığırı — Fethiye / Erentepe</h3>' + (!bugun ? '<div class=\"kart\">Bu gün için Fethiye / Erentepe günlük verisi yok.</div>' :\n      '<div class=\"ipucu\" style=\"margin:-4px 2px 6px\">' + (onceki ? 'Önceki veri günü (' + tarihKisa(onceki.t) + ') ile karşılaştırma' : 'Önceki gün verisi yok.') + '</div>' +\n      suruTablosu(onceki, bugun, onceki ? tarihKisa(onceki.t).slice(0, 5) : 'Önceki', tarihKisa(bas).slice(0, 5)));\n  } else {\n    var gl = g.gunler;\n    h += '<h3>Sürü Değişimi — Fethiye / Erentepe</h3>' + (!gl.length ? '<div class=\"kart\">Bu hafta için günlük veri yok.</div>' :\n      suruTablosu(gl[0], gl[gl.length - 1], tarihKisa(gl[0].t).slice(0, 5), tarihKisa(gl[gl.length - 1].t).slice(0, 5)));\n  }\n  h += '<h3>Besi Planı ve Kesim</h3>';\n  if (!T.besi.length) h += '<div class=\"kart\">Besi planı verisi yok.</div>';\n  else { var t = function (k) { return T.besi.reduce(function (a, b) { return a + b[k]; }, 0); };\n    h += tablo(['İşletme', 'Yerli Dana', 'Kesimi Planlanan Erkek Dana', 'Kesimi Planlanan İnek'],\n      T.besi.map(function (b) { return [b.isletme, tsT(b.yerli), tsT(b.erkek), tsT(b.inek)]; }).concat([['TOPLAM', ts(t('yerli')), ts(t('erkek')), ts(t('inek'))]]), true); }\n  return h + faaliyetPaneli(true, bas, son);\n}\nfunction menuAcik(m) { return (S.menuler || []).indexOf(m) >= 0; }\nfunction kokEkrani() {\n  if (!S.menuler) return '<div class=\"yukleniyor\">Yükleniyor…</div>';\n  if (!S.menuler.length) return '<div class=\"kart\">Bu paylaşımda görüntülenebilecek bölüm bulunmuyor.</div>';\n  var h = '<div class=\"bilgi\">' + (menuAcik('ziraat') || menuAcik('hayvan') ? 'Ziraat ve Hayvancılık bölümleri yalnızca görüntülenir; günlük ya da haftalık dönem seçilebilir. ' : '') +\n    (!menuAcik('tarla') ? '' : S.yetki === 'duzenle' ? 'Tarla Haritaları bölümünde parsel bilgisi girebilirsiniz.' : 'Tarla Haritaları bölümünde yalnızca görüntüleme yetkiniz var.') + '</div>';\n  if (menuAcik('ziraat')) h += menu('🌾', 'Ziraat', 'Ekim alanları, hasat ve verim, günlük / haftalık ziraat faaliyetleri', \"TS.ciftlik=null;git('ziraat')\");\n  if (menuAcik('hayvan')) h += menu('🐄', 'Hayvancılık', 'Hayvan sayıları, süt, doğum ve kayıplar, işletme raporları, besi, günlük / haftalık faaliyetler', \"TS.ciftlik=null;git('hayvan')\");\n  if (menuAcik('tarla')) h += menu('▦', 'Tarla Haritaları', 'Sezonlar, parseller, karşılaştırma ve ÇKS', \"git('ana')\");\n  return h;\n}\nfunction tarimCiz(kok, bas) {\n  if (S.ekran === 'kok') { bas.textContent = 'Tarım ve Hayvancılık'; kok.innerHTML = kokEkrani(); return; }\n  bas.textContent = S.ekran === 'ziraat' ? 'Ziraat' : 'Hayvancılık';\n  if (T.hata) { kok.innerHTML = '<div class=\"kart\">' + esc(T.hata) + '</div>'; return; }\n  if (!T.yuklendi) { kok.innerHTML = '<div class=\"yukleniyor\">Veriler yükleniyor…</div>'; return; }\n  kok.innerHTML = S.ekran === 'ziraat' ? ziraatEkrani() : hayvancilikEkrani();\n}\n// ---------- açılış ----------\nfunction yukle() {\n  var bekle = 1, hata = null, haritaHata = null;\n  function bitti() {\n    if (--bekle) return;\n    if (haritaHata && (!S.menuler || menuAcik('tarla'))) hata = hata || haritaHata;\n    if (hata) { document.getElementById('icerik').innerHTML = '<div class=\"kart\">' + esc(hata) + '</div>'; return; }\n    ciz();\n  }\n  google.script.run.withSuccessHandler(function (r) {\n    if (!r || !r.ok) { hata = (r && r.hata) || 'Veri alınamadı.'; if (r && r.kapali) hata = 'Bu paylaşım kapatıldı.'; return bitti(); }\n    S.sezonParsel = r.sezonParsel || []; S.parselSinir = r.parselSinir || []; S.tarlaSezonlari = r.tarlaSezonlari || []; S.yetki = r.yetki; S.etiket = r.etiket; S.menuler = r.menuler || ['ziraat', 'hayvan', 'tarla']; SINIR = r.sezonParselSiniri || 400;\n    S.ekim = r.ekim || []; S.ekimPlani = r.ekimPlani || []; S.cks = r.cks || [];\n    var dos = r.dosyalar || {};\n    S.paket = DOSYALAR.map(function (d) { try { return dos[d] ? sezonOku(JSON.parse(dos[d])) : null; } catch (e) { return null; } }).filter(Boolean);\n    if (!S.paket.length && S.menuler.indexOf('tarla') >= 0) haritaHata = 'Harita dosyası alınamadı.';\n    document.getElementById('ust').textContent = r.etiket + ' · ' + (r.yetki === 'duzenle' ? 'düzenleme yetkisi' : 'yalnızca görüntüleme');\n    bitti();\n  }).withFailureHandler(function (e) { hata = 'Veri alınamadı: ' + e.message; bitti(); }).tarlaPanelVeri(ANAHTAR);\n  google.script.run.withSuccessHandler(function (r) {\n    if (!r || !r.ok) T.hata = (r && r.hata) || 'Ziraat ve Hayvancılık verisi alınamadı.'; else tarimVerisiOku(r);\n    if (S.ekran === 'ziraat' || S.ekran === 'hayvan') ciz();\n  }).withFailureHandler(function (e) { T.hata = 'Ziraat ve Hayvancılık verisi alınamadı: ' + e.message; if (S.ekran === 'ziraat' || S.ekran === 'hayvan') ciz(); }).tarlaPanelTarim(ANAHTAR);\n}\nyukle();\n</script>\n</body>\n</html>\n";
// <</TARLA_PANEL_HTML>>


// ---------------------------------------------------------------------------
// VERİ KALİTESİ: kaynak dosyaların ve uygulamadaki kopyaların son değişiklik tarihleri.
// Yalnızca dosya tarihi okunur; içerik okunmaz, kişisel veri yoktur.
var VERI_KAYNAKLARI_ = [
  { ad: 'Çiftlik Raporları (muhasebe)', kaynak: ['1FniioMusJmKiQIjnt-JZjUtrLisNyGiN'], kopya: 'ciftlik_rapor_2026' },
  { ad: 'Maliyet Takip', kaynak: ['1Yj2GfYBZBK7HqDqb-iGG2dlsBnWFUcMWHWyLwF4pEaM'], kopya: 'maliyet_takip_2026' },
  { ad: 'Aylık gelir satış ve gider tabloları', kaynak: ['1SZdjPUrz3_1aHcWn5xBQJSpMeqBntKMw', '1_68Qn8esEbBH2LnTAfUCtP_V1OsXe1Ci'], kopya: 'mali' },
  { ad: 'Stok sayımları', kaynak: ['1W9LWXFlDk-jQoj1r-z6qN87T8FFRclcpEWVfBfPs_Kw'] },
  { ad: 'Sürü hareketleri', kaynak: ['1yp23PwaA_kFXMapnLQGZfcVhjzcTTbujSUJS3m77y48'] },
  { ad: 'Tarımsal Faaliyet', kaynak: ['1jeeLe8VF06l_a_JdcS1eF8n8yDGsgEPlIcjO4Y5T7u8'] }
];

function veriKalitesi_() {
  return onbellekli_('veriKalitesi_v1', 600, function () {
    function tarih(d) { return d ? Utilities.formatDate(d, 'Europe/Istanbul', "yyyy-MM-dd'T'HH:mm:ss") : ''; }
    function dosya(id) { try { return DriveApp.getFileById(id).getLastUpdated(); } catch (e) { return null; } }
    function maliKopya() {
      try {
        var it = DriveApp.getFolderById(MALI_KLASOR_ID).getFiles(), en = null;
        while (it.hasNext()) {
          var f = it.next();
          if (f.getName().indexOf('mali_veri.json') !== 0) continue;
          if (!en || f.getLastUpdated() > en) en = f.getLastUpdated();
        }
        return en;
      } catch (e) { return null; }
    }
    return VERI_KAYNAKLARI_.map(function (k) {
      var son = null;
      k.kaynak.forEach(function (id) { var d = dosya(id); if (d && (!son || d > son)) son = d; });
      var kopya = !k.kopya ? null : k.kopya === 'mali' ? maliKopya() : dosya(UYGULAMA_DOSYALARI_[k.kopya]);
      return { ad: k.ad, kaynak: tarih(son), kopya: tarih(kopya), canli: !k.kopya };
    });
  });
}
