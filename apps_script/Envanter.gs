// Envanter.gs — Kaynak envanteri, Kaynak Gezgini ve kaynak tabloları
// Bu proje birden çok .gs dosyasından oluşur; hepsi birlikte çalışır (Kod.gs, Kayitlar.gs, Paylasim.gs, Mali.gs,
// Isletme.gs, Kaynaklar.gs, Muhasebe.gs, Envanter.gs, TarlaPaneli.gs).

// ---------------------------------------------------------------------------
// KAYNAK ENVANTERİ: piramidi besleyen bütün kaynak dosyaların her sayfası, sütunu, satırı ve notu.
// • Her dosyanın her sayfası okunur (satır/sütun sınırı yoktur); xlsx dosyaları otomatik E-Tabloya dönüştürülür.
// • Her sayfa için: boyut, başlık satırı, sütunlar (dolu hücre, sayısal toplam), formül hataları, hücre notları
//   ve piramitte nerede kullanıldığı. Kullanılmayan sayfa ve sütunlar Veri Kalitesi › Kaynak Kapsamı'nda görünür.
// • Uygulama her sayfanın tamamını "Kaynak Gezgini"nden açabilir (kaynakSayfa).
// KVKK: kişi bilgisi içeren sayfalar (personel, organizasyon şeması, kişiler, mesaj kaydı) okunmaz;
//   kişi bilgisi sütunları (ad soyad, operatör, şoför, TC, telefon, IBAN, plaka, adres, e-posta) ve hücre
//   içindeki TC / telefon / IBAN / e-posta / plaka kalıpları maskelenir; uygulamaya hiçbir zaman açık gitmez.
var KAYNAK_ENVANTER_DOSYA_ = 'kaynak_envanteri.json';
// Dosyaya özgü maskeler: stok sayımlarında açıklama sütunu kişi adı içerebilir.
var KVKK_DOSYA_SUTUN_ = [[/Stok Sayımları/i, /açıklama|aciklama|not/i]];
function kvkkSutunMu_(dosyaAdi, baslik) {
  baslik = String(baslik || '');
  if (KVKK_SUTUN_.test(baslik)) return true;
  return KVKK_DOSYA_SUTUN_.some(function (k) { return k[0].test(dosyaAdi || '') && k[1].test(baslik); });
}
var KVKK_SAYFA_ = /personel|organizasyon|şoför|sürücü|kişiler|kisiler|kişi olay|mesaj|iletişim|telefon|ekipler|görevlendirme|roller|cihazlar|bildirimler|^mutabakat$|veteriner_bildirim/i;
var KVKK_SUTUN_ = /tedarikçi|tedarikci|cari|müşteri|musteri|alıcı|alici|satıcı|unvan|ünvan|firma adı|kullanıcı|kullanici|ad[ıi]?\s*[-\/]?\s*soyad|^ad[ıi]?$|^soyad|isim|personel|çalışan|şoför|sürücü|operatör|operator|^tc\b|t\.c\.|kimlik|telefon|^tel\b|gsm|cep no|iban|plaka|adres|e-?posta|mail|imza|bildiren|onaylayan|teslim alan|teslim eden|kişi/i;

function kvkkHucre_(x) {
  var t = String(x == null ? '' : x);
  if (!t) return t;
  return t
    .replace(/\bTR\s?\d{2}(?:\s?\d{4}){5}\s?\d{2}\b/gi, '••• (IBAN)')
    .replace(/[\w.+-]+@[\w-]+\.[\w.-]+/g, '••• (e-posta)')
    .replace(/\b[1-9]\d{10}\b/g, '••• (TC)')
    .replace(/(?:\+?90[\s-]?)?\b0?5\d{2}[\s-]?\d{3}[\s-]?\d{2}[\s-]?\d{2}\b/g, '••• (telefon)')
    .replace(/\b(0[1-9]|[1-7]\d|8[01])\s?[A-PR-VYZ]{1,3}\s?\d{2,4}\b/g, '••• (plaka)');
}

/** Piramitte hangi sayfanın nerede kullanıldığı: [dosya kimliği | /dosya adı deseni/, /sayfa deseni/, yer]. */
function kaynakKullanim_() {
  return [
    [MALIYET_TAKIP_ID_, /^(MALİYET ÖZET HAYVANCILIK|MALİYET ÖZET TARIM 2026|YEM|SÜT MALİYETİ|KARKAS MALİYETİ|KAYAR ORTALAMA|ÖZET)$/, 'Çiftlik Sonuçları › maliyet (sunucuda, otomatik)'],
    [MALIYET_TAKIP_ID_, /^(İLAÇ AŞI|DİĞER MALZEMELER)$/, 'Çiftlik Sonuçları › İlaç ve Malzeme'],
    [GECMIS_OZET_.degerlendirme, /./, 'Geçmiş Yıllar › yıllık göstergeler ve kaynak tabloları'],
    [GECMIS_OZET_.kesim, /^(ALIM ÖZET|Sayfa6|Sayfa7|GENEL MALİYETLER)$/, 'Geçmiş Yıllar › Kaynak tabloları'],
    [BILGI_BANKASI_ID, /^(Envanter|Aylık_Sürü)$/, 'Geçmiş Yıllar › Kaynak tabloları'],
    [ESK_EK_.calisma, /./, 'ESK › Kaynak tabloları'],
    [SURU_HAREKETLERI_ID, /^ÖZET/, 'Stok ve Sürü › Kaynak tabloları'],
    [/Stok Sayımları/, /ARASI NAKİL/, 'Stok ve Sürü › Kaynak tabloları'],
    [TARIM_FAALIYET_ID, /./, 'Ziraat › Kaynak tabloları'],
    [TARIM_ICMAL_ID, /^(ÖZE|ÖZET 2027)$/, 'Ziraat › Kaynak tabloları'],
    [EKIM_PLANI_ID, /./, 'Ziraat › Kaynak tabloları'],
    [PATATES_FIRE_ID, /./, 'Ürün teslimatı › Kaynak tabloları'],
    [/Çiftlik Raporları/, /^(Çiftlikler Gider Raporu Detay|Besi-Düve Yem Tüketimi|Duran Varlık Yem Tüketimi|Tarımsal Alan Tüketim Raporu)$/, 'Çiftlik Sonuçları › Gider / Yem ve Tüketim'],
    [/Çiftlik Raporları/, /^(Çiftlikler Konsolide( \(2\))?|16\d\d - .+)$/, 'Çiftlik Sonuçları › gelir tabloları (iki senaryo)'],
    [/Çiftlik Raporları/, /^(Satış|SMM Detay)$/, 'Çiftlik Sonuçları › birim maliyet, tarım ürünleri, teşvikler'],
    [/Çiftlik Raporları/, /(Gider Raporu Detay|Detay Gider Raporu|Gider Raporu Özet|Tüketim(i)? Özet|Satılan Mamül Maliyeti Özet)$/, 'Veri Kalitesi › özet / detay mutabakatı'],
    [/Çiftlik Raporları/, /^Satış Özet$/, 'Ürün listesi (malzeme kodu ve adı)'],
    [TARIM_FAALIYET_ID, /^(ÇİFTLİK BAZINDA|ÜRÜN BAZINDA)$/, 'Ürün Karlılığı › üretim'],
    [TARIM_FAALIYET_ID, /^PARSEL$/, 'Tarla Haritası › resmi parseller'],
    [TARIM_ICMAL_ID, /^(ŞEKER SÜT|ASLIM|TAŞAĞIL|FİDANLIK)$/, 'Tarım günlük kayıtları (Eşitle)'],
    [EKIM_PLANI_ID, /^2026-2027$/, 'Ekim planı'],
    [SURU_HAREKETLERI_ID, /^20\d\d$/, 'Stok ve Sürü › sürü hareketleri'],
    [PATATES_FIRE_ID, /^LİSTE$/, 'Ürün teslimatı › patates'],
    [GECMIS_OZET_.kesim, /^KESİMLER$/, 'Geçmiş Yıllar › kesim ve alım'],
    [GECMIS_OZET_.degerlendirme, /^(tarım 5yıllık kazanç|süt verimliliği|Ölüm oranları)\s*$/, 'Geçmiş Yıllar › yıllık göstergeler'],
    [ESK_EK_.calisma, /^Gelir Tablosuna Göre\.$/, 'ESK › gelir tablosu'],
    [ESK_KAYNAK_.maliyet, /./, 'ESK › bakım hizmeti'], [ESK_KAYNAK_.parti, /./, 'ESK › partiler'], [ESK_KAYNAK_.yem, /./, 'ESK › yem'],
    [ESK_EK_.balya, /./, 'ESK › balya'], [ESK_EK_.gubre, /./, 'ESK › gübre'],
    [/İTHAL ÖLÜM/, /^(KESİM|ÖLÜM)$/, 'ESK › kesim ve ölüm'], [/KASAPLIK HAYVAN/, /./, 'ESK › kasaplık'],
    [/ARAÇ MASRAFLARI/, /^(GENEL LİSTE|DETAY)/, 'Araç Masrafları'],
    [/TarKop/, /./, 'Ürün teslimatı › pancar'],
    [/Stok Sayımları/, /^16\d\d$/, 'Stok ve Sürü › stok sayımı'],
    [ARAC_TABLO_ID, /^(Araçlar|Kullanım|Bakım_Plan|Bakım_Kayıt|Arıza|İş_Emirleri)$/, 'Makine ve Bakım'],
    [BAKIM_TABLO_ID, /./, 'Makine ve Bakım › bakım onarım'],
    [BILGI_BANKASI_ID, /^(Veriler|Dersler)$/, 'Bilgi Bankası'],
    [FORM_TABLO_ID, /./, 'Günlük tarım bildirimi'],
    [CANLI_HAYVAN_VARSAYILAN_ID, /^(ozet|isletme)$/, 'Hayvan özeti'],
    [/aylık (gider|gelir satış) tablosu/i, /./, 'Mali Raporlar (sunucuda, otomatik)'],
    [/Haftalik_Yonetim_Raporu/, /^(Hayvan_Özet|Hayvan_Günlük|Hayvan_Detay|Tarım_Veri|Ekim_Alanları|Hasat_Verim|Besi_Plan|ESK_Aylık|ESK_Bilgi|Hasat Durumu|Sezon_Parselleri|Parsel_Sınırları|ÇKS_Parseller|Veteriner_Kodları|Yönetici Özeti)$/, 'Uygulamanın ana tablosu (rapor verileri)'],
    [/Haftalik_Yonetim_Raporu/, /^Hafta /, 'Haftalık rapor arşivi (uygulamanın ürettiği)']
  ];
}

// Kurum kararıyla bilerek kullanılmayan kaynaklar: [/dosya adı/, açıklama]
var KARAR_HARIC_ = [[/GELEN FATURA RAPOR/i, 'Kurum kararı (26.11.2026): Mali Raporlar yalnızca muhasebenin 2026 Fatura listesinden beslenir; birim gelen fatura raporu kullanılmaz.']];
function kararHaric_(dosyaAdi) { for (var i = 0; i < KARAR_HARIC_.length; i++) if (KARAR_HARIC_[i][0].test(dosyaAdi || '')) return KARAR_HARIC_[i][1]; return ''; }

function kaynakKullanimBul_(dosya, sayfa) {
  var l = kaynakKullanim_(), ad = dosya.ad || '', o = [];
  l.forEach(function (k) {
    var eslesir = typeof k[0] === 'string' ? (k[0] === dosya.id || k[0] === dosya.kaynakId) : k[0].test(ad);
    if (eslesir && k[1].test(sayfa)) o.push(k[2]);
  });
  return o.join(' · ');
}

/** Envanterdeki kaynak listesi: VERI_KAYNAKLARI_ + uygulamanın okuduğu diğer tablolar ve klasörler. */
function kaynakListesi_() {
  var l = VERI_KAYNAKLARI_.map(function (k) { return { ad: k.ad, kaynak: k.kaynak || [], ara: k.ara }; });
  [['Tarım günlük icmali', TARIM_ICMAL_ID], ['Ekim planı', EKIM_PLANI_ID], ['Patates fire listesi', PATATES_FIRE_ID],
   ['Günlük tarım bildirimi formu', FORM_TABLO_ID], ['Canlı hayvan tablosu', CANLI_HAYVAN_VARSAYILAN_ID],
   ['Araç Takip tablosu', ARAC_TABLO_ID], ['Bakım Onarım Kayıtları', BAKIM_TABLO_ID], ['Bilgi Bankası', BILGI_BANKASI_ID],
   ['Mali Raporlar klasörü', MALI_KLASOR_ID], ['Günlük ve Haftalık raporlar klasörü', RAPOR_KLASOR_ID],
   ['Gelen Dosyalar klasörü', GELEN_DOSYALAR_KLASOR_ID]
  ].forEach(function (x) { l.push({ ad: x[0], kaynak: [x[1]] }); });
  return l;
}

function kaynakDosyalari_(k) {
  var o = [], gor = {};
  function ekle(f, kaynakId) {
    var mt = f.getMimeType();
    if (mt === MimeType.FOLDER) { try { klasor(DriveApp.getFolderById(f.getId()), kaynakId, 0); } catch (e) {} return; }
    if (mt === MimeType.SHORTCUT) { try { f = DriveApp.getFileById(f.getTargetId()); } catch (e) { return; } }  // kısayol: asıl dosya
    if (!gor[f.getId()]) { gor[f.getId()] = true; o.push({ f: f, kaynakId: kaynakId }); }
  }
  function klasor(d, kaynakId, derin) {
    var fi = d.getFiles();
    while (fi.hasNext()) ekle(fi.next(), kaynakId);
    if (derin > 3) return;
    var di = d.getFolders();
    while (di.hasNext()) klasor(di.next(), kaynakId, derin + 1);
  }
  (k.kaynak || []).forEach(function (id) {
    try { ekle(DriveApp.getFileById(id), id); return; } catch (e) {}
    try { klasor(DriveApp.getFolderById(id), id, 0); } catch (e2) {}
  });
  if (k.ara) { var it = DriveApp.searchFiles(k.ara); while (it.hasNext()) ekle(it.next(), ''); }
  // Aynı adlı E-Tablo varsa xlsx'in kendisi ayrıca incelenmez (içerik aynı).
  var tablolar = {};
  o.forEach(function (x) { if (x.f.getMimeType() === MimeType.GOOGLE_SHEETS) tablolar[x.f.getName().trim()] = true; });
  return o.filter(function (x) { return !(/\.xlsx$/i.test(x.f.getName()) && tablolar[x.f.getName().replace(/\.xlsx$/i, '').trim()]); });
}

var DONUSTURULEN_KLASOR_ADI_ = 'Dönüştürülmüş kaynaklar (otomatik)';
/** xlsx / xls / csv için E-Tablo kopyası: dosya her güncellendiğinde yeniden dönüştürülür. */
function kaynakDonustur_(f) {
  var mt = f.getMimeType();
  if (mt === MimeType.GOOGLE_SHEETS) return { id: f.getId() };
  if (!/\.(xlsx|xlsm|xls|csv)$/i.test(f.getName()) && !/spreadsheetml|ms-excel|text\/csv/.test(mt)) return null;
  if (/Çiftlik Raporları/.test(f.getName())) { var t = ciftlikRaporTabloBul_(); return t ? { id: t.getId(), not: 'otomatik dönüştürme (Çiftlik Raporları)' } : { hata: 'E-Tablo kopyası yok' }; }
  var pr = PropertiesService.getScriptProperties(), anahtar = 'dn_' + f.getId(), imza = String(f.getLastUpdated().getTime());
  var kayit = pr.getProperty(anahtar);
  if (kayit) {
    var p = kayit.split('|');
    if (p[0] === imza) { try { DriveApp.getFileById(p[1]); return { id: p[1] }; } catch (e) {} }
  }
  if (typeof Drive === 'undefined') return { hata: 'Drive API hizmeti ekli değil' };
  var kl, it = DriveApp.getFolderById(UYGULAMA_VERI_KLASOR_).getFoldersByName(DONUSTURULEN_KLASOR_ADI_);
  kl = it.hasNext() ? it.next() : DriveApp.getFolderById(UYGULAMA_VERI_KLASOR_).createFolder(DONUSTURULEN_KLASOR_ADI_);
  var ad = f.getName().replace(/\.(xlsx|xlsm|xls|csv)$/i, '') + ' (kopya)', yeni;
  try {
    try { yeni = Drive.Files.copy({ name: ad, mimeType: MimeType.GOOGLE_SHEETS, parents: [kl.getId()] }, f.getId()); }
    catch (e) { yeni = Drive.Files.copy({ title: ad, mimeType: MimeType.GOOGLE_SHEETS, parents: [{ id: kl.getId() }] }, f.getId(), { convert: true }); }
  } catch (e3) { return { hata: 'dönüştürülemedi: ' + e3 }; }
  if (kayit) { try { DriveApp.getFileById(kayit.split('|')[1]).setTrashed(true); } catch (e4) {} }  // eski otomatik kopya (kaynak değil)
  pr.setProperty(anahtar, imza + '|' + yeni.id);
  return { id: yeni.id };
}

function kaynakSayfaIncele_(sh, dosyaAdi) {
  var ad = sh.getName(), o = { ad: ad, satir: sh.getLastRow(), sutun: sh.getLastColumn(), dolu: 0, hata: 0, notlar: [], sutunlar: [] };
  if (KVKK_SAYFA_.test(ad)) { o.durum = 'kvkk'; return o; }
  if (!o.satir || !o.sutun) { o.durum = 'bos'; return o; }
  var rg = sh.getRange(1, 1, o.satir, o.sutun), d = rg.getDisplayValues(), n = [];
  try { n = rg.getNotes(); } catch (e) {}
  // Başlık satırı: ilk 40 satırda en çok metin hücresi olan satır
  var bs = 0, en = -1;
  for (var r = 0; r < Math.min(40, d.length); r++) {
    var m = 0; d[r].forEach(function (x) { if (/[A-Za-zÇĞİÖŞÜçğıöşü]/.test(x)) m++; });
    if (m > en) { en = m; bs = r; }
  }
  o.baslikSatiri = bs + 1;
  if (o.satir <= bs + 1) { o.durum = 'bos'; o.bosNedeni = 'yalnızca başlık satırı var, kayıt yok'; }
  var gizliSut = {};
  for (var c0 = 0; c0 < o.sutun; c0++) if (kvkkSutunMu_(dosyaAdi, d[bs][c0])) gizliSut[c0] = true;
  for (var c = 0; c < o.sutun; c++) {
    var bas = String(d[bs][c] || '').trim(), dolu = 0, sayisal = 0, top = 0, hata = 0;
    for (var r2 = bs + 1; r2 < d.length; r2++) {
      var x = d[r2][c];
      if (x === '' || x == null) continue;
      dolu++;
      if (/^#(REF|N\/A|DIV\/0|VALUE|NAME|NUM|ERROR)/.test(x)) { hata++; continue; }
      var v = eskTrSayi_(String(x).replace(/[₺%\s]/g, '').replace(/-$/, ''));
      if (v !== null && !isNaN(v)) { sayisal++; top += v; }
    }
    for (var r3 = 0; r3 <= bs; r3++) if (d[r3][c]) dolu++;
    o.dolu += dolu; o.hata += hata;
    if (!dolu) continue;
    var gizli = kvkkSutunMu_(dosyaAdi, bas);
    o.sutunlar.push({ no: c + 1, baslik: gizli ? bas + ' (KVKK, maskeli)' : kvkkHucre_(bas), dolu: dolu, sayisal: gizli ? 0 : sayisal,
      toplam: !gizli && sayisal ? Math.round(top * 100) / 100 : null, hata: hata, kvkk: gizli });
  }
  for (var a = 0; a < n.length; a++) for (var b = 0; b < n[a].length; b++) if (n[a][b] && !gizliSut[b]) {
    o.notlar.push({ hucre: sutunHarf_(b + 1) + (a + 1), not: kvkkHucre_(n[a][b]) });
  }
  // Hücreye yazılmış açıklamalar (uzun metinler) ayrıca not olarak listelenir
  for (var a2 = 0; a2 < d.length; a2++) for (var b2 = 0; b2 < d[a2].length; b2++) {
    var t = gizliSut[b2] ? '' : String(d[a2][b2] || '');
    if (t.length >= 40 && /\s/.test(t) && /[a-zçğıöşü]{3}/i.test(t)) o.notlar.push({ hucre: sutunHarf_(b2 + 1) + (a2 + 1), not: kvkkHucre_(t), metin: true });
  }
  return o;
}

function sutunHarf_(n) { var s = ''; while (n > 0) { var m = (n - 1) % 26; s = String.fromCharCode(65 + m) + s; n = Math.floor((n - 1) / 26); } return s; }

function kaynakEnvanterDosyasi_() {
  var it = DriveApp.getFolderById(UYGULAMA_VERI_KLASOR_).getFilesByName(KAYNAK_ENVANTER_DOSYA_);
  return it.hasNext() ? it.next() : null;
}

/** Bütün kaynakları inceler. 5 dakikayı aşarsa kaldığı yerden devam etmek için kendini 1 dakika sonraya kurar.
 *  Değişmeyen dosyalar (aynı güncelleme zamanı) yeniden okunmaz. Günlük otomatik çalışma da kurulur. */
function kaynakEnvanteriHazirla() {
  try { maliyetTakipGuncelle_(); } catch (e) { Logger.log('Maliyet Takip güncellenemedi: ' + e); }
  try { maliGuncelle_(); } catch (e) { Logger.log('Mali Raporlar güncellenemedi: ' + e); }
  try { ciftlikRaporTam_(false); } catch (e) { Logger.log('Çiftlik Raporları güncellenemedi: ' + e); }
  var bas = Date.now(), f = kaynakEnvanterDosyasi_(), eski = {};
  try { if (f) (JSON.parse(f.getBlob().getDataAsString()).kaynaklar || []).forEach(function (k) { (k.dosyalar || []).forEach(function (x) { eski[x.id] = x; }); }); } catch (e) {}
  var pr = PropertiesService.getScriptProperties(), yarim = {};
  var o = { olusturma: new Date().toISOString(), kaynaklar: [], tamam: true }, bitmedi = false, okunan = {};
  kaynakListesi_().forEach(function (k) {
    var kk = { ad: k.ad, dosyalar: [] };
    o.kaynaklar.push(kk);
    var l = [];
    try { l = kaynakDosyalari_(k); } catch (e) { kk.hata = String(e); return; }
    l.forEach(function (x) {
      var fl = x.f, id = fl.getId(), imza = String(fl.getLastUpdated().getTime());
      var e0 = eski[id] || yarim[id];
      if (e0 && e0.imza === imza && !e0.yarim) {
        // Dosya değişmedi: sayfalar yeniden okunmaz, yalnızca piramitteki kullanım durumu güncel kurallara göre yenilenir.
        (e0.sayfalar || []).forEach(function (s0) {
          if (KVKK_SAYFA_.test(s0.ad)) { s0.durum = 'kvkk'; s0.sutunlar = []; s0.notlar = []; return; }
          if (s0.durum === 'kullanilmiyor' && s0.baslikSatiri && s0.satir <= s0.baslikSatiri) { s0.durum = 'bos'; s0.bosNedeni = 'yalnızca başlık satırı var, kayıt yok'; }
          if (s0.durum === 'kullaniliyor' || s0.durum === 'kullanilmiyor' || s0.durum === 'bos') {
            s0.kullanim = kaynakKullanimBul_(e0, s0.ad);
            if (s0.durum !== 'bos') s0.durum = s0.kullanim ? 'kullaniliyor' : 'kullanilmiyor';
          }
          if ((s0.durum === 'kullanilmiyor' || s0.durum === 'haric') && kararHaric_(e0.ad)) { s0.durum = 'haric'; s0.kullanim = kararHaric_(e0.ad); }
        });
        if (e0.okunanId && okunan[e0.okunanId] && okunan[e0.okunanId] !== e0.ad) { e0.ayni = okunan[e0.okunanId]; e0.sayfalar = []; }
        else if (e0.okunanId) okunan[e0.okunanId] = e0.ad;
        kk.dosyalar.push(e0); return;
      }
      var onceki = e0 && e0.imza === imza && e0.yarim ? e0.sayfalar || [] : [];
      var kayit = { id: id, kaynakId: x.kaynakId, ad: fl.getName(), tur: fl.getMimeType(), imza: imza,
        guncelleme: Utilities.formatDate(fl.getLastUpdated(), 'Europe/Istanbul', 'dd.MM.yyyy HH:mm'), sayfalar: [] };
      kk.dosyalar.push(kayit);
      if (bitmedi || Date.now() - bas > 210000) { bitmedi = true; kayit.yarim = true; return; }
      var dn = null;
      try { dn = kaynakDonustur_(fl); } catch (e) { dn = { hata: String(e) }; }
      if (!dn) { kayit.tablo = false; return; }
      if (dn.hata) { kayit.hata = dn.hata; return; }
      kayit.tablo = true; kayit.okunanId = dn.id; if (dn.not) kayit.not = dn.not;
      if (okunan[dn.id]) { kayit.ayni = okunan[dn.id]; return; }  // aynı tablo başka kaynakta zaten incelendi
      okunan[dn.id] = kayit.ad;
      var yapilan = {};
      onceki.forEach(function (s0) { yapilan[s0.ad] = true; kayit.sayfalar.push(s0); });
      try {
        SpreadsheetApp.openById(dn.id).getSheets().forEach(function (sh) {
          if (yapilan[sh.getName()]) return;
          if (bitmedi || Date.now() - bas > 240000) { bitmedi = true; kayit.yarim = true; return; }
          var s;
          try { s = kaynakSayfaIncele_(sh, kayit.ad); } catch (e) { s = { ad: sh.getName(), durum: 'hata', hataMetni: String(e) }; }
          if (!s.durum || s.durum === 'bos') { s.kullanim = kaynakKullanimBul_(kayit, s.ad); if (!s.durum) s.durum = s.kullanim ? 'kullaniliyor' : 'kullanilmiyor'; }
          if (s.durum === 'kullanilmiyor' && kararHaric_(kayit.ad)) { s.durum = 'haric'; s.kullanim = kararHaric_(kayit.ad); }
          kayit.sayfalar.push(s);
        });
      } catch (e) { kayit.hata = 'açılamadı: ' + e; }
    });
  });
  o.tamam = !bitmedi;
  var metin = JSON.stringify(o);
  if (f) f.setContent(metin); else DriveApp.getFolderById(UYGULAMA_VERI_KLASOR_).createFile(KAYNAK_ENVANTER_DOSYA_, metin, 'application/json');
  CacheService.getScriptCache().remove('kaynakEnvOzet_n');
  var tetik = ScriptApp.getProjectTriggers().filter(function (t) { return t.getHandlerFunction() === 'kaynakEnvanteriDevam_'; });
  tetik.forEach(function (t) { ScriptApp.deleteTrigger(t); });
  if (bitmedi) {
    ScriptApp.newTrigger('kaynakEnvanteriDevam_').timeBased().after(60 * 1000).create();
  }
  if (!ScriptApp.getProjectTriggers().some(function (t) { return t.getHandlerFunction() === 'kaynakEnvanteriHazirla'; })) {
    ScriptApp.newTrigger('kaynakEnvanteriHazirla').timeBased().everyDays(1).atHour(5).create();
  }
  var oz = kaynakEnvanterOzetHesapla_(o);
  Logger.log('Kaynak envanteri: ' + oz.dosya + ' dosya, ' + oz.sayfa + ' sayfa; kullanılmayan ' + oz.kullanilmayan + ', kararla hariç ' + (oz.haric || 0) +
    ', KVKK nedeniyle hariç ' + oz.kvkk + ', hata ' + oz.hata + (bitmedi ? ' — süre doldu, 1 dakika sonra kendiliğinden devam edecek.' : ' — tamamlandı.'));
  return oz;
}
function kaynakEnvanteriDevam_() { kaynakEnvanteriHazirla(); }

function kaynakEnvanterOzetHesapla_(o) {
  var z = { olusturma: o.olusturma, tamam: o.tamam, dosya: 0, sayfa: 0, kullanilan: 0, kullanilmayan: 0, kvkk: 0, bos: 0, hata: 0, tabloDegil: 0, not: 0, formulHatasi: 0, liste: [] };
  (o.kaynaklar || []).forEach(function (k) {
    (k.dosyalar || []).forEach(function (d) {
      z.dosya++;
      if (d.tablo === false) z.tabloDegil++;
      if (d.hata) { z.hata++; z.liste.push([k.ad, d.ad, '', 'hata', d.hata]); }
      (d.sayfalar || []).forEach(function (s) {
        z.sayfa++;
        if (s.durum === 'kullaniliyor') z.kullanilan++;
        else if (s.durum === 'kullanilmiyor') { z.kullanilmayan++; z.liste.push([k.ad, d.ad, s.ad, 'kullanilmiyor', (s.satir || 0) + ' satır × ' + (s.sutun || 0) + ' sütun']); }
        else if (s.durum === 'kvkk') z.kvkk++;
        else if (s.durum === 'haric') z.haric = (z.haric || 0) + 1;
        else if (s.durum === 'bos') z.bos++;
        else if (s.durum === 'hata') { z.hata++; z.liste.push([k.ad, d.ad, s.ad, 'hata', s.hataMetni || '']); }
        z.not += (s.notlar || []).length; z.formulHatasi += s.hata || 0;
      });
    });
  });
  return z;
}

/** Ana veri paketine giden kısa özet (ayrıntı kaynakEnvanteri isteğiyle gelir). */
function kaynakEnvanterOzet_() {
  var c = CacheService.getScriptCache(), m = parcaliOku_(c, 'kaynakEnvOzet');
  if (m) { try { return JSON.parse(m); } catch (e) {} }
  var f = kaynakEnvanterDosyasi_();
  if (!f) return null;
  var oz = kaynakEnvanterOzetHesapla_(JSON.parse(f.getBlob().getDataAsString()));
  parcaliYaz_(c, 'kaynakEnvOzet', JSON.stringify(oz));
  return oz;
}

function kaynakEnvanteriTam_() {
  var f = kaynakEnvanterDosyasi_();
  if (!f) return { ok: false, hata: 'Kaynak envanteri henüz hazırlanmadı: Apps Script\'te kaynakEnvanteriHazirla çalıştırılmalı.' };
  var o = JSON.parse(f.getBlob().getDataAsString());
  o.ok = true;
  return o;
}

/** Kaynak Gezgini: envanterdeki bir sayfanın satırları (KVKK maskeli). Yalnızca envanterde olan dosyalar açılır. */
function kaynakSayfa_(dosyaId, sayfa, bas, adet) {
  var f = kaynakEnvanterDosyasi_();
  if (!f) return { ok: false, hata: 'Kaynak envanteri yok.' };
  var env = JSON.parse(f.getBlob().getDataAsString()), bul = null;
  (env.kaynaklar || []).forEach(function (k) { (k.dosyalar || []).forEach(function (d) { if (d.id === dosyaId) bul = d; }); });
  if (!bul || !bul.okunanId) return { ok: false, hata: 'Dosya envanterde yok.' };
  if (KVKK_SAYFA_.test(sayfa)) return { ok: false, hata: 'Bu sayfa kişi bilgisi içerdiği için KVKK gereği açılmaz.' };
  var sh = SpreadsheetApp.openById(bul.okunanId).getSheetByName(sayfa);
  if (!sh) return { ok: false, hata: 'Sayfa bulunamadı.' };
  var n = sh.getLastRow(), w = sh.getLastColumn();
  if (!n || !w) return { ok: true, toplam: 0, satirlar: [] };
  bas = Math.max(0, bas || 0); adet = Math.max(1, Math.min(2000, adet || 500));
  var son = Math.min(n, bas + adet);
  if (bas >= n) return { ok: true, toplam: n, bas: bas, satirlar: [] };
  var bsr = 1;
  (bul.sayfalar || []).forEach(function (s) { if (s.ad === sayfa && s.baslikSatiri) bsr = s.baslikSatiri; });
  var bslk = sh.getRange(bsr, 1, 1, w).getDisplayValues()[0], maske = bslk.map(function (h) { return kvkkSutunMu_(bul.ad, h); });
  var d = sh.getRange(bas + 1, 1, son - bas, w).getDisplayValues().map(function (r) {
    return r.map(function (x, j) { return maske[j] && x ? '•••' : kvkkHucre_(x); });
  });
  return { ok: true, toplam: n, sutun: w, bas: bas, baslikSatiri: bsr, satirlar: d };
}


// ---------------------------------------------------------------------------
// KAYNAK TABLOLARI: piramidin hesaplarında henüz ayrı bir analize bağlanmamış sayfalar, bütün hücreleriyle
// tablo blokları hâlinde ilgili menüye taşınır (boş satırlarla ayrılan her blok ayrı tablo). Böylece kaynak
// dosyalarda okunmayan sayfa kalmaz. KVKK: kişi bilgisi sayfaları alınmaz, kişi bilgisi sütunları ve kalıpları maskelenir.
function kaynakTabloTanimlari_() {
  return [
    ['gecmis', 'Değerlendirme Raporu (31.12.2025)', GECMIS_OZET_.degerlendirme, /./],
    ['gecmis', 'Kesim özeti 2021–2026', GECMIS_OZET_.kesim, /^(ALIM ÖZET|Sayfa6|Sayfa7|GENEL MALİYETLER)$/],
    ['gecmis', 'Bilgi Bankası', BILGI_BANKASI_ID, /^(Envanter|Aylık_Sürü)$/],
    ['esk', 'ESK çalışma dosyası', ESK_EK_.calisma, /^(?!Gelir Tablosuna Göre\.$)/],
    ['stokSuru', 'Sürü hareketleri – özet sayfaları', SURU_HAREKETLERI_ID, /^ÖZET/],
    ['stokSuru', 'Stok sayımları – çiftlikler arası nakil', 'ara:' + "title contains 'Stok Sayımları' and mimeType = 'application/vnd.google-apps.spreadsheet' and trashed = false", /ARASI NAKİL/],
    ['ziraat', 'Tarımsal Faaliyet – diğer sayfalar', TARIM_FAALIYET_ID, /^(?!(ÇİFTLİK BAZINDA|ÜRÜN BAZINDA|PARSEL)$)/],
    ['ziraat', 'Tarım günlük icmali – özet sayfaları', TARIM_ICMAL_ID, /^(ÖZE|ÖZET 2027)$/],
    ['ziraat', 'Ekim planı – aylık raporlar', EKIM_PLANI_ID, /^(OCAK|ŞUBAT|MART|NİSAN|MAYIS|HAZİRAN|TEMMUZ|AĞUSTOS|EYLÜL|EKİM|KASIM|ARALIK)$/],
    ['urun', 'Patates fire listesi – fatura ve özet', PATATES_FIRE_ID, /^(fatura edilecek miktar|Pivot Tablo 1)$/]
  ];
}

/** 2B görüntü değerleri → boş satırlarla ayrılmış bloklar [{satirlar: [[...]]}] (boş sütunlar kırpılır). */
function kaynakBloklar_(d, maske) {
  var bloklar = [], cur = [];
  function bitir() {
    if (!cur.length) return;
    var w = 0, dolu = {};
    cur.forEach(function (r) { r.forEach(function (x, j) { if (x !== '') { dolu[j] = true; if (j + 1 > w) w = j + 1; } }); });
    var sut = []; for (var j = 0; j < w; j++) if (dolu[j]) sut.push(j);
    bloklar.push({ satirlar: cur.map(function (r) { return sut.map(function (j) { return maske[j] && r[j] && r !== cur[0] ? '•••' : kvkkHucre_(r[j] == null ? '' : String(r[j]).trim()); }); }) });
    cur = [];
  }
  d.forEach(function (r) {
    if (r.every(function (x) { return String(x).trim() === ''; })) bitir(); else cur.push(r.map(function (x) { return String(x).trim(); }));
  });
  bitir();
  return bloklar;
}

function kaynakTablolari_() {
  var c = CacheService.getScriptCache(), m = parcaliOku_(c, 'kaynakTablolari_v1');
  if (m) { try { return JSON.parse(m); } catch (e) {} }
  var o = { menuler: {}, hatalar: [] };
  kaynakTabloTanimlari_().forEach(function (t) {
    try {
      var ids = [];
      if (String(t[2]).indexOf('ara:') === 0) {
        var it = DriveApp.searchFiles(String(t[2]).slice(4)), en = null;
        while (it.hasNext()) { var f = it.next(); if (!en || f.getLastUpdated() > en.getLastUpdated()) en = f; }
        if (en) ids.push(en.getId());
      } else ids.push(t[2]);
      ids.forEach(function (id) {
        var ss = SpreadsheetApp.openById(id), ad = ss.getName();
        ss.getSheets().forEach(function (sh) {
          var sa = sh.getName();
          if (!t[3].test(sa) || KVKK_SAYFA_.test(sa) || !sh.getLastRow() || !sh.getLastColumn()) return;
          var d = sh.getRange(1, 1, sh.getLastRow(), sh.getLastColumn()).getDisplayValues();
          var bas = d.find(function (r) { return r.some(function (x) { return x !== ''; }); }) || [];
          var maske = {};
          d.slice(0, 40).forEach(function (r) { r.forEach(function (x, j) { if (kvkkSutunMu_(ad, x)) maske[j] = true; }); });
          (o.menuler[t[0]] = o.menuler[t[0]] || []).push({ grup: t[1], dosya: ad, sayfa: sa.trim(), bloklar: kaynakBloklar_(d, maske) });
        });
      });
    } catch (e) { o.hatalar.push(t[1] + ': ' + e); }
  });
  parcaliYaz_(c, 'kaynakTablolari_v1', JSON.stringify(o));
  return o;
}
