// Paylasim.gs — Paylaşımlar ve Tarla Haritası web paneli
// Bu proje birden çok .gs dosyasından oluşur; hepsi birlikte çalışır (Kod.gs, Kayitlar.gs, Paylasim.gs,
// Isletme.gs, Kaynaklar.gs, Muhasebe.gs, Envanter.gs, TarlaPaneli.gs).

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
var PAYLASIM_MENULERI_ = ['gunluk', 'haftalik', 'ziraat', 'hayvan', 'tarla', 'esk', 'mali', 'ciftlikRapor', 'urun', 'gecmis', 'hastalik', 'sureme', 'arac', 'bakim', 'stokSuru', 'aracMasraf'];
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
  if (acik('ziraat', 'urun')) al(['hasatDurumu']);
  if (acik('tarla')) al(['cks', 'ekimDuzeltme', 'sezonParsel', 'ekimPlani', 'sezonParselSiniri', 'parselSinir', 'resmiParsel', 'tarlaSezonlari']);
  if (acik('esk')) al(['eskAylik', 'eskBilgi', 'eskKaynak', 'eskEk']);  // eskKaynak: yalnızca toplamlar (plaka/şoför yok)
  if (acik('stokSuru')) al(['suruHareketleri', 'stokSayimi']);  // sayılar; not sütunları zaten okunmaz
  if (acik('urun')) al(['tarimsalUretim', 'urunTeslimat']);
  if (acik('gecmis', 'hastalik')) al(['gecmis', 'dersler']);
  if (acik('gecmis')) al(['gecmisOzet']);
  if (v.kaynakTablolari && v.kaynakTablolari.menuler) {
    var kt = {};
    Object.keys(v.kaynakTablolari.menuler).forEach(function (mn) { if (acik(mn)) kt[mn] = v.kaynakTablolari.menuler[mn]; });
    o.kaynakTablolari = { menuler: kt, hatalar: [] };
  }
  if (acik('mali')) o.mali = paylasimMali_(v.mali, pay.maliDetay === true);
  // Ürün Takibi › Ürün Kârlılığı fatura gelirlerini (çiftlik × ürün toplamları, tedarikçi yok) kullanır.
  else if (acik('urun') && v.mali) o.mali = { gelirGider: v.mali.gelirGider };
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
  // Net Sonuç (Mali) ve Ürün Kârlılığı muhasebe ve maliyet toplamlarına dayanır.
  if (acik('ciftlikRapor')) al(['ciftlikRaporTam', 'maliyetTakipDetay']);
  if (acik('ciftlikRapor', 'mali', 'urun')) dos = dos.concat(['ciftlik_rapor_2026', 'maliyet_takip_2026']);
  if (acik('aracMasraf')) al(['aracMasraf']);
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
  if (!/^(Haftalik_Rapor_\d{1,2}_Hafta_\d{4}|Aylik_Yonetim_Raporu_\d{4}_\d{2})\.pdf$/.test(ad)) {
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
