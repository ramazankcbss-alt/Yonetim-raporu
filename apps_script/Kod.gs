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
var RAPOR_KLASOR_ID = '1fcEVsCnfocV9_PGbpjiLcLQ6emjjKwYY';  // 01 – Günlük ve Haftalık Raporlar
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
    if (p.bolum === 'kaynakEnvanteri') return json_(kaynakEnvanteriTam_());
    if (p.bolum === 'kaynakSayfa') return json_(kaynakSayfa_(p.dosya, p.sayfa, parseInt(p.bas, 10) || 0, parseInt(p.adet, 10) || 500));
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
    dosyalar: (function () { try { maliyetTakipGuncelle_(); } catch (e) {} return uygulamaDosyalari_(['ciftlik_rapor_2026', 'maliyet_takip_2026', 'hastalik', 'uygulamalar'].concat(TARLA_DOSYALARI_)); })(),
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
    aracKullanim: basitOku_('Kullanım', 0, tz, ARAC_TABLO_ID),
    aracPlan: basitOku_('Bakım_Plan', 0, tz, ARAC_TABLO_ID),
    aracBakim: basitOku_('Bakım_Kayıt', 0, tz, ARAC_TABLO_ID),
    aracAriza: basitOku_('Arıza', 0, tz, ARAC_TABLO_ID),
    aracMutabakat: [], // KVKK: Mutabakat kontrolü uygulamadan kaldırıldı
    aracIsEmri: basitOku_('İş_Emirleri', 0, tz, ARAC_TABLO_ID),
    // Bakım Onarım Kayıtları: No, Bildirim zamanı, Çiftlik, Bildiren (görev),
    // Makine/ekipman, İşlem türü, Çalışma saati/km, Yapılan iş, Malzeme/parça,
    // Tedarik durumu, Servis, Durum, Onay (Evet/boş), Onay zamanı
    bakimOnarim: bakimOnarimOku_(tz),
    // Mali Raporlar: "Mali Raporlar" klasöründeki en yeni mali_veri.json
    // (fatura özetleri; şahıs tedarikçi adı, fatura no ve plaka içermez)
    mali: (function () { try { maliGuncelle_(); } catch (e) {} return maliVeri_(); })(),
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
    // Sürü hareketleri (çiftlik × ay sayılar) ve en yeni stok sayımı (not sütunları okunmaz)
    suruHareketleri: (function () { try { return suruHareketleriOku_(); } catch (err) { return null; } })(),
    stokSayimi: (function () { try { return stokSayimiOku_(); } catch (err) { return null; } })(),
    // "Yönetim Raporu – Gelen Dosyalar" klasöründe işlenmeyi bekleyen dosyaların adı ve tarihi (içerik okunmaz)
    gelenDosyalar: (function () { try { return gelenDosyalar_(); } catch (err) { return []; } })(),
    // ESK kaynak dosyaları: aylık bakım hizmet tablosu toplamları, parti listesi, aylık yem girişi (plaka/şoför yok)
    eskKaynak: (function () { try { return eskKaynak_(); } catch (err) { return null; } })(),
    // ESK ek kaynaklar: ithal kesim/ölüm, kasaplık partileri, balya, gübre, nakliye, gelir tablosu (yalnızca toplamlar)
    eskEk: (function () { try { return eskEk_(); } catch (err) { return null; } })(),
    // Geçmiş yıl özetleri: kesim ve canlı hayvan alımı (2021–), tarım net gelir, süt verimi, ölüm oranları
    gecmisOzet: (function () { try { return gecmisOzet_(); } catch (err) { return null; } })(),
    // Hasadı tamamlanan ürünler (sezon × ürün; "Tümü" o sezonun bütün ürünleri)
    hasatDurumu: (function () { try { return hasatDurumuOku_(); } catch (err) { return []; } })(),
    // Çiftlik Raporları (muhasebe) E-Tablo kopyasının tamamı: gider raporu, yem ve tarım tüketimleri
    ciftlikRaporTam: (function () { try { return ciftlikRaporTam_(false); } catch (err) { return null; } })(),
    // Maliyet Takip › İLAÇ AŞI ve DİĞER MALZEMELER malzeme ayrıntısı
    maliyetTakipDetay: (function () { try { return maliyetTakipDetay_(); } catch (err) { return null; } })(),
    // Kaynak envanteri özeti: kullanılmayan sayfalar, KVKK hariç tutulanlar, okunamayanlar
    kaynakEnvanteri: (function () { try { return kaynakEnvanterOzet_(); } catch (err) { return null; } })(),
    // Ayrı analize bağlanmamış kaynak sayfaları (bütün hücreleriyle, menü bazında)
    kaynakTablolari: (function () { try { return kaynakTablolari_(); } catch (err) { return null; } })(),
    // Araç masrafları: muhasebe xlsx'i doğrudan okunur (araç adı × ay × iş alanı; plaka/satıcı/belge no yok)
    aracMasraf: (function () { try { return aracMasrafOku_(); } catch (err) { return null; } })(),
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
    if (govde.tur === 'hasatDurumu') return json_(hasatDurumuKaydet_(govde));
    // Kaynak Kapsamı / Kaynak Gezgini (yalnızca sahibi; paylaşımlara verilmez)
    if (govde.tur === 'kaynakEnvanteri') return json_(kaynakEnvanteriTam_());
    if (govde.tur === 'kaynakSayfa') return json_(kaynakSayfa_(govde.dosya, govde.sayfa, parseInt(govde.bas, 10) || 0, parseInt(govde.adet, 10) || 500));
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
  var iv = isl.getRange(1, 1, isl.getLastRow(), Math.max(isl.getLastColumn(), 45)).getValues();
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
  var v = sh.getRange(1, 1, sh.getLastRow(), Math.max(sh.getLastColumn(), 33)).getValues();
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
  // Sınır yok: kaynak sayfanın bütün satırları okunur; daha önce aktarılan günler tekrar yazılmaz.
  var bugun = bugun_(), sinir = new Date(2000, 0, 1);
  var yeni = [];
  TARIM_SAYFALARI_.forEach(function (sp) {
    var sh = kaynak.getSheetByName(sp[0]);
    if (!sh) return;
    var sonK = sh.getLastRow();
    if (sonK < 4) return;
    var bas = 5;
    var gen = sh.getLastColumn();
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
