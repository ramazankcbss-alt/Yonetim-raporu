// Muhasebe.gs — Çiftlik Raporları (muhasebe) ve Maliyet Takip: tam okuma ve sunucuda üretim
// Bu proje birden çok .gs dosyasından oluşur; hepsi birlikte çalışır (Kod.gs, Kayitlar.gs, Paylasim.gs,
// Isletme.gs, Kaynaklar.gs, Muhasebe.gs, Envanter.gs, TarlaPaneli.gs).

// ---------------------------------------------------------------------------
// ÇİFTLİK RAPORLARI – TAM OKUMA: muhasebenin "Çiftlik Raporları" dosyasının Google E-Tablolar kopyası
// (xlsx 22 MB olduğu için Drive bağlantısıyla tamamı okunamıyordu). En yeni E-Tablo kopyası kullanılır.
// Okunan sayfalar: Çiftlikler Gider Raporu Detay (yıl × üretim yeri × hesap × ay), Besi-Düve Yem Tüketimi
// (hayvan bazlı ham kayıt → yıl × ay × üretim yeri × malzeme × cins toplamı), Duran Varlık Yem Tüketimi,
// Tarımsal Alan Tüketim Raporu. Sonuç, kaynak değişene kadar "Uygulama Verileri" klasöründe saklanır.
// KVKK: personel hesapları (2. İşçi, 3. Memur) yalnızca grup toplamı olarak alınır (kıdem tazminatı gibi tek
// kişiye ait olabilecek satırlar ayrıştırılmaz); kulak küpe no ve sipariş/parti no çıktıya yazılmaz.
var CIFTLIK_RAPOR_KLASOR_ = '12WB0NVfd94hnMefdq8X7qOn4f75-xSwY';  // 06 – Çiftlikler Rapor 2026
var UYGULAMA_VERI_KLASOR_ = '1p5jLVOBAOZP0RdOMm7qN4zQOpLQKllp-';
var CR_AYLAR_ = ['OCAK', 'ŞUBAT', 'MART', 'NİSAN', 'MAYIS', 'HAZİRAN', 'TEMMUZ', 'AĞUSTOS', 'EYLÜL', 'EKİM', 'KASIM', 'ARALIK'];

function crAy_(v) { return CR_AYLAR_.indexOf(String(v || '').trim().toLocaleUpperCase('tr')) + 1; }
function crSayi_(v) { if (typeof v === 'number') return v; var n = eskTrSayi_(String(v || '').replace(/-\s*$/, '')); return n || 0; }

function ciftlikRaporTabloBul_() {
  var en = null;
  function bak(it) {
    while (it.hasNext()) {
      var f = it.next();
      if (f.getMimeType() !== MimeType.GOOGLE_SHEETS || !/Çiftlik Raporları/i.test(f.getName())) continue;
      if (!en || f.getLastUpdated() > en.getLastUpdated()) en = f;
    }
  }
  try { bak(DriveApp.getFolderById(CIFTLIK_RAPOR_KLASOR_).getFiles()); } catch (e) {}
  if (!en) { try { bak(DriveApp.searchFiles("title contains 'Çiftlik Raporları' and mimeType = 'application/vnd.google-apps.spreadsheet' and trashed = false")); } catch (e) {} }
  return en;
}


/**
 * Otomatik dönüştürme: muhasebenin gönderdiği en yeni "Çiftlik Raporları" xlsx dosyası, klasördeki E-Tablo
 * kopyasından daha yeniyse Google'a E-Tablo olarak dönüştürtülür ve "06 – Çiftlikler Rapor 2026" klasörüne konur.
 * Gereken: Apps Script › Hizmetler › Drive API (bir kez eklenir). Eski kopyalar silinmez; en yenisi kullanılır.
 */
function ciftlikRaporDonustur_() {
  var xlsx = null, it = DriveApp.searchFiles("title contains 'Çiftlik Raporları' and trashed = false");
  while (it.hasNext()) {
    var f = it.next();
    if (!/\.xlsx$/i.test(f.getName()) || f.getMimeType() === 'application/vnd.google-apps.shortcut') continue;
    if (!xlsx || f.getLastUpdated() > xlsx.getLastUpdated()) xlsx = f;
  }
  if (!xlsx) return { durum: 'xlsx yok' };
  var imza = xlsx.getId() + '@' + xlsx.getLastUpdated().getTime(), pr = PropertiesService.getScriptProperties();
  if (pr.getProperty('crDonusum') === imza) return { durum: 'güncel' };
  // Klasörde xlsx'ten sonra oluşturulmuş bir E-Tablo kopyası varsa (ör. elle kaydedilen) yeniden dönüştürülmez.
  var tablo = ciftlikRaporTabloBul_();
  if (tablo && tablo.getDateCreated() > xlsx.getLastUpdated()) { pr.setProperty('crDonusum', imza); return { durum: 'güncel (mevcut kopya)' }; }
  if (typeof Drive === 'undefined') return { durum: 'Drive API hizmeti ekli değil' };
  var ad = xlsx.getName().replace(/\.xlsx$/i, ''), yeni;
  try {
    yeni = Drive.Files.copy({ name: ad, mimeType: MimeType.GOOGLE_SHEETS, parents: [CIFTLIK_RAPOR_KLASOR_] }, xlsx.getId());  // Drive API v3
  } catch (e) {
    yeni = Drive.Files.copy({ title: ad, mimeType: MimeType.GOOGLE_SHEETS, parents: [{ id: CIFTLIK_RAPOR_KLASOR_ }] }, xlsx.getId(), { convert: true });  // v2
  }
  pr.setProperty('crDonusum', imza);
  return { durum: 'dönüştürüldü', id: yeni && yeni.id };
}

function ciftlikRaporTamHesapla_(dosya) {
  var ss = SpreadsheetApp.open(dosya), o = { dosya: dosya.getName(), sayfalar: [], gider: [], yem: [], duranVarlik: [], tarim: [], hatalar: [] };
  ss.getSheets().forEach(function (s) { o.sayfalar.push({ ad: s.getName(), satir: s.getLastRow(), sutun: s.getLastColumn() }); });
  function topla(m, k, v) { m[k] = (m[k] || 0) + v; }

  // 1) Gider raporu detay
  try {
    var sh = ss.getSheetByName('Çiftlikler Gider Raporu Detay'), d = sh.getDataRange().getValues(), h = d[0].map(String);
    var c = { yil: h.indexOf('Yıl'), uy: h.indexOf('Üretim Yeri'), kod: h.indexOf('Hesap Kodu'), grup: h.indexOf('Grup'), ack: h.indexOf('Hesap Açıklaması') };
    var aySut = [];
    h.forEach(function (x, j) { var a = crAy_(x); if (a) aySut.push([j, a]); });
    var g = {};
    for (var i = 1; i < d.length; i++) {
      var r = d[i], yil = Number(r[c.yil]), uy = String(r[c.uy]).trim(), grup = String(r[c.grup]).trim();
      if (!yil || !uy || !grup) continue;
      var personel = /^\s*[23]\./.test(grup);
      var hesap = personel ? '' : String(r[c.kod]).trim() + ' ' + String(r[c.ack]).trim();
      aySut.forEach(function (p) {
        var v = crSayi_(r[p[0]]);
        if (v) topla(g, [yil, p[1], uy, grup, hesap].join('|'), v);
      });
    }
    o.gider = Object.keys(g).map(function (k) { var a = k.split('|'); return [+a[0], +a[1], a[2], a[3], a[4], Math.round(g[k] * 100) / 100]; });
  } catch (e) { o.hatalar.push('Gider raporu: ' + e); }

  // 2) Besi-düve yem tüketimi (hayvan bazlı ham kayıt; parça parça okunur)
  try {
    var sb = ss.getSheetByName('Besi-Düve Yem Tüketimi'), son = sb.getLastRow(), hb = sb.getRange(1, 1, 1, sb.getLastColumn()).getValues()[0].map(String);
    function s(ad) { return hb.findIndex(function (x) { return x.trim() === ad; }); }
    var cb = { yil: s('Yıl'), ay: s('Ay'), uy: s('Üretim yeri'), mal: s('Malzeme kısa metni'), mik: s('Toplam tüketim'), tut: s('Tutar'), cins: s('Canlı hayvan Cins') };
    var son_sut = Math.max(cb.yil, cb.ay, cb.uy, cb.mal, cb.mik, cb.tut, cb.cins) + 1, y = {};
    for (var bas = 2; bas <= son; bas += 40000) {
      var n = Math.min(40000, son - bas + 1), v = sb.getRange(bas, 1, n, son_sut).getValues();
      for (var j = 0; j < v.length; j++) {
        var r2 = v[j], yil2 = Number(r2[cb.yil]), ay2 = crAy_(r2[cb.ay]);
        if (!yil2 || !ay2) continue;
        var k = [yil2, ay2, String(r2[cb.uy]).trim(), String(r2[cb.mal]).trim(), String(r2[cb.cins] || '').trim()].join('|');
        var x = y[k] || (y[k] = [0, 0]);
        x[0] += crSayi_(r2[cb.mik]); x[1] += crSayi_(r2[cb.tut]);
      }
    }
    o.yem = Object.keys(y).map(function (k) { var a = k.split('|'); return [+a[0], +a[1], a[2], a[3], a[4], Math.round(y[k][0] * 100) / 100, Math.round(y[k][1] * 100) / 100]; });
  } catch (e) { o.hatalar.push('Besi-düve yem tüketimi: ' + e); }

  // 3) Duran varlık (sağmal) yem tüketimi ve 4) tarımsal alan tüketimi
  function tuketim(ad, uyVar) {
    var sh2 = ss.getSheetByName(ad);
    if (!sh2) return [];
    var d2 = sh2.getDataRange().getValues(), h2 = d2[0].map(function (x) { return String(x).trim(); }), m = {};
    var c2 = { yil: h2.indexOf('Yıl'), ay: h2.indexOf('Aylar'), uy: h2.indexOf('Üretim yeri'), mal: h2.indexOf('Malzeme kısa metni'),
      mik: h2.indexOf('Miktar'), bir: h2.indexOf('Giriş ölçü birimi'), tut: h2.indexOf('Tutar') };
    for (var i2 = 1; i2 < d2.length; i2++) {
      var r3 = d2[i2], yil3 = Number(r3[c2.yil]), ay3 = crAy_(r3[c2.ay]);
      if (!yil3 || !ay3) continue;
      var k3 = [yil3, ay3, uyVar ? String(r3[c2.uy]).trim() : '1611', String(r3[c2.mal]).trim(), String(r3[c2.bir]).trim()].join('|');
      var x3 = m[k3] || (m[k3] = [0, 0]);
      x3[0] += crSayi_(r3[c2.mik]); x3[1] += crSayi_(r3[c2.tut]);
    }
    return Object.keys(m).map(function (k) { var a = k.split('|'); return [+a[0], +a[1], a[2], a[3], a[4], Math.round(m[k][0] * 100) / 100, Math.round(m[k][1] * 100) / 100]; });
  }
  try { o.duranVarlik = tuketim('Duran Varlık Yem Tüketimi', true); } catch (e) { o.hatalar.push('Duran varlık yem: ' + e); }
  try { o.tarim = tuketim('Tarımsal Alan Tüketim Raporu', false); } catch (e) { o.hatalar.push('Tarımsal alan tüketimi: ' + e); }
  try { o.mutabakat = crOzetMutabakat_(ss, o); } catch (e) { o.hatalar.push('Özet sayfa mutabakatı: ' + e); }
  return o;
}

/** Özet ve çiftlik bazlı detay sayfaları (pivot) ana detay sayfalarıyla karşılaştırılır; böylece bu sayfalar da
 *  tamamen okunur ve muhasebe dosyasındaki iç tutarsızlıklar görünür. [{sayfa, karsi, ozet, detay2026, detayTum, durum, aciklama}] */
function crOzetMutabakat_(ss, o) {
  var l = [];
  function topla(a, f) { return a.reduce(function (t, r) { return f(r) ? t + r[r.length - 1] : t; }, 0); }
  function sutunlar(h, desen) { var m = []; h.forEach(function (x, j) { if (desen.test(String(x).trim())) m.push(j); }); return m; }
  function ekle(sayfa, karsi, oz, d26, dTum, not) {
    var uy = Math.abs(oz - d26) <= Math.max(1, Math.abs(d26) * 0.001) || Math.abs(oz - dTum) <= Math.max(1, Math.abs(dTum) * 0.001);
    l.push({ sayfa: sayfa, karsi: karsi, ozet: Math.round(oz), detay2026: Math.round(d26), detayTum: Math.round(dTum), durum: uy ? 'uyumlu' : 'farkli', aciklama: not || '' });
  }
  // 1) Çiftlik bazlı gider detay sayfaları (Ay/Yıl sütunlu) ↔ Çiftlikler Gider Raporu Detay
  [['Taşağıl Gider Raporu Detay', '1604'], ['Aslım Gider Raporu Detay', '1605'], ['Tarımsal Gider Raporu Detay', '1611'],
   ['Şekersüt Detay Gider Raporu', '1613'], ['Pan-Gev Detay Gider Raporu', '1614']].forEach(function (x) {
    var sh = ss.getSheetByName(x[0]);
    if (!sh) return;
    var d = sh.getDataRange().getValues(), h = d[0].map(String), kod = h.findIndex(function (t) { return t.trim() === 'Hesap Kodu'; });
    var ay = []; h.forEach(function (t, j) { var m = /^\s*([A-Za-zÇĞİÖŞÜçğıöşü]+)\/(\d{4})\s*$/.exec(t); if (m && crAy_(m[1])) ay.push([j, +m[2]]); });
    var yil = {};
    for (var i = 1; i < d.length; i++) {
      if (!/^\d{6,}$/.test(String(d[i][kod]).trim())) continue;
      ay.forEach(function (a) { yil[a[1]] = (yil[a[1]] || 0) + crSayi_(d[i][a[0]]); });
    }
    Object.keys(yil).sort().forEach(function (y) {
      var dt = topla(o.gider, function (r) { return r[0] === +y && r[2] === x[1]; });
      ekle(x[0] + ' · ' + y, 'Çiftlikler Gider Raporu Detay (' + x[1] + ', ' + y + ')', yil[y], dt, dt);
    });
  });
  // 2) Çiftlikler Gider Raporu Özet (aylık) ↔ detay
  var go = ss.getSheetByName('Çiftlikler Gider Raporu Özet');
  if (go) {
    var d2 = go.getDataRange().getValues(), bs = -1;
    for (var r = 0; r < Math.min(20, d2.length) && bs < 0; r++) if (d2[r].map(String).some(function (t) { return t.trim() === 'Hesap Kodu'; })) bs = r;
    if (bs >= 0) {
      var h2 = d2[bs].map(String), k2 = h2.findIndex(function (t) { return t.trim() === 'Hesap Kodu'; }), oz = 0;
      var ayS = []; h2.forEach(function (t, j) { if (crAy_(t.trim()) && !/TOPLAM/i.test(t)) ayS.push(j); });
      for (var i2 = bs + 1; i2 < d2.length; i2++) if (/^\d{6,}$/.test(String(d2[i2][k2]).trim())) ayS.forEach(function (j) { oz += crSayi_(d2[i2][j]); });
      ekle('Çiftlikler Gider Raporu Özet', 'Çiftlikler Gider Raporu Detay', oz, topla(o.gider, function (rr) { return rr[0] === 2026; }), topla(o.gider, function () { return true; }),
        'Özet sayfası bir pivot tablodur; seçili filtreye göre tek yıl/çiftlik gösterebilir.');
    }
  }
  // 3) Tüketim özetleri ↔ detay
  [['Besi-Düve Yem Tüketimi Özet', o.yem, 'Besi-Düve Yem Tüketimi'], ['Duran Varlık Yem Tüketimi Özet', o.duranVarlik, 'Duran Varlık Yem Tüketimi'],
   ['Tarımsal Alan Tüketim Özet', o.tarim, 'Tarımsal Alan Tüketim Raporu']].forEach(function (x) {
    var sh = ss.getSheetByName(x[0]);
    if (!sh || !x[1]) return;
    var d = sh.getDataRange().getValues(), bs = -1, c = -1;
    for (var r = 0; r < Math.min(20, d.length) && bs < 0; r++) { c = d[r].map(String).findIndex(function (t) { return t.trim() === 'Toplam Tutar'; }); if (c >= 0) bs = r; }
    if (bs < 0) return;
    var oz = 0;
    for (var i = bs + 1; i < d.length; i++) if (String(d[i][0]).trim() && !/toplam/i.test(String(d[i][0]))) oz += crSayi_(d[i][c]);
    var tut = function (r) { return r[6]; };
    var d26 = x[1].reduce(function (t, r) { return r[0] === 2026 ? t + tut(r) : t; }, 0), dt = x[1].reduce(function (t, r) { return t + tut(r); }, 0);
    ekle(x[0], x[2], oz, d26, dt, 'Özet sayfası pivot tablodur; seçili filtreye göre dönem farklı olabilir.');
  });
  // 4) Satılan Mamül Maliyeti Özet ↔ SMM Detay
  var so = ss.getSheetByName('Satılan Mamül Maliyeti Özet'), sd = ss.getSheetByName('SMM Detay');
  if (so && sd) {
    var d4 = so.getDataRange().getValues(), bs4 = -1, c4 = -1;
    for (var r4 = 0; r4 < Math.min(20, d4.length) && bs4 < 0; r4++) { c4 = d4[r4].map(String).findIndex(function (t) { return /Fiili Top\.Değer/.test(t); }); if (c4 >= 0) bs4 = r4; }
    var dd = sd.getDataRange().getValues(), hc = dd[0].map(String).findIndex(function (t) { return /Fiili Top\.Değer/.test(t); }), d26 = 0, dt = 0;
    for (var i5 = 1; i5 < dd.length; i5++) { var v = crSayi_(dd[i5][hc]); dt += v; if (String(dd[i5][1]).trim() === '2026') d26 += v; }
    if (bs4 >= 0) {
      var oz4 = 0;
      for (var i4 = bs4 + 1; i4 < d4.length; i4++) if (String(d4[i4][0]).trim() && !/toplam/i.test(String(d4[i4][0]))) oz4 += crSayi_(d4[i4][c4]);
      ekle('Satılan Mamül Maliyeti Özet', 'SMM Detay', oz4, d26, dt, 'Özet sayfası pivot tablodur; seçili filtreye göre dönem farklı olabilir.');
    }
  }
  return l;
}

/** Kaynak değişmedikçe kayıtlı sonucu döndürür; değiştiyse yeniden hesaplar ve kaydeder. */
function ciftlikRaporTam_(zorla) {
  var donusum = null;
  try { donusum = ciftlikRaporDonustur_(); } catch (e) { donusum = { durum: 'dönüştürme hatası: ' + e }; }
  var kaynak = ciftlikRaporTabloBul_();
  if (!kaynak) return null;
  var imza = kaynak.getId() + '@' + kaynak.getLastUpdated().getTime(), ad = 'ciftlik_rapor_tam.json', cache = CacheService.getScriptCache();
  var k = 'crTam_' + imza, m = zorla ? null : parcaliOku_(cache, k);
  if (m) { try { var o0 = JSON.parse(m); o0.donusum = donusum; return o0; } catch (e) {} }
  var klasor = DriveApp.getFolderById(UYGULAMA_VERI_KLASOR_), it = klasor.getFilesByName(ad), f = it.hasNext() ? it.next() : null;
  if (f && !zorla) {
    try {
      var kayit = JSON.parse(f.getBlob().getDataAsString('UTF-8'));
      if (kayit.imza === imza) { parcaliYaz_(cache, k, JSON.stringify(kayit)); kayit.donusum = donusum; return kayit; }
    } catch (e) {}
  }
  var o = ciftlikRaporTamHesapla_(kaynak);
  // Yeni muhasebe dosyası: gelir tabloları, satış ve SMM (ciftlik_rapor_2026.json) da yeniden üretilir.
  if (!zorla) { try { ciftlikRaporUret_(kaynak); } catch (e) { o.hatalar.push('Gelir tabloları üretilemedi: ' + e); } }
  o.imza = imza;
  o.guncelleme = Utilities.formatDate(kaynak.getLastUpdated(), 'Europe/Istanbul', "yyyy-MM-dd'T'HH:mm:ss");
  var metin = JSON.stringify(o);
  if (f) f.setContent(metin); else klasor.createFile(ad, metin, 'application/json');
  parcaliYaz_(cache, k, metin);
  o.donusum = donusum;
  return o;
}

/** Düzenleyiciden bir kez çalıştırın: Çiftlik Raporları E-Tablosunun tamamını okuyup kaydeder. */
function ciftlikRaporHazirla() {
  try { Logger.log('Gelir tabloları / satış / SMM: ' + JSON.stringify(ciftlikRaporUret_())); } catch (e) { Logger.log('Gelir tabloları üretilemedi: ' + e); }
  var o = ciftlikRaporTam_(true);
  Logger.log('Dönüştürme: ' + JSON.stringify(o && o.donusum));
  Logger.log(o ? (o.dosya + ': ' + o.sayfalar.length + ' sayfa, gider ' + o.gider.length + ', besi-düve yem ' + o.yem.length +
    ', duran varlık ' + o.duranVarlik.length + ', tarım ' + o.tarim.length + ' satır; hata: ' + (o.hatalar.join(' | ') || 'yok'))
    : 'Çiftlik Raporları E-Tablosu bulunamadı.');
}


// ---------------------------------------------------------------------------
// MALİYET TAKİP – İLAÇ AŞI ve DİĞER MALZEMELER: malzeme bazında ayrıntı (canlı okunur, sınırsız).
// Sayfa düzeni: çiftlik blokları yan yana (1. satırda çiftlik adı); her blokta ay başlığı ("OCAK : belge",
// "OCAK AYI"), "MALZEME KODU" başlık satırı, kalemler ve "TOPLAM:". Bloklardaki açıklama yazıları not olarak alınır.
// KVKK: belge numaraları alınmaz; sayfalarda kişi bilgisi yoktur.
var MALIYET_TAKIP_ID_ = '1Yj2GfYBZBK7HqDqb-iGG2dlsBnWFUcMWHWyLwF4pEaM';

function mtAyBul_(s) {
  var t = String(s || '').trim().toLocaleUpperCase('tr');
  for (var i = 0; i < CR_AYLAR_.length; i++) if (t.indexOf(CR_AYLAR_[i]) === 0) return i + 1;
  return 0;
}

function mtSayi_(v) {
  // "5.160,00-" (SAP tüketim çıkışı) ve "3-" gibi sondaki eksi işareti: tutar mutlak değer olarak alınır.
  var t = String(v == null ? '' : v).replace(/[₺\s]/g, '').replace(/-$/, '');
  return eskTrSayi_(t);
}

function mtSayfaOku_(sh, tur) {
  var d = sh.getDataRange().getDisplayValues(), out = [], notlar = [];
  if (!d.length) return { kalemler: out, notlar: notlar };
  var w = 0;
  d.forEach(function (r) { if (r.length > w) w = r.length; });
  function h(r, c) { return String((d[r] || [])[c] == null ? '' : d[r][c]).trim(); }
  function H(r, c) { return h(r, c).toLocaleUpperCase('tr'); }
  // Blok başlangıç sütunları: herhangi bir satırında "MALZEME KODU" geçen sütunlar.
  var bloklar = [];
  for (var c0 = 0; c0 < w; c0++) for (var r0 = 0; r0 < d.length; r0++) if (H(r0, c0) === 'MALZEME KODU') { bloklar.push(c0); break; }
  function ciftlik(c) {
    var en = '', enC = -1;
    for (var rr = 0; rr < Math.min(d.length, 3); rr++) for (var j = 0; j <= Math.min(c + 1, w - 1); j++) {
      var t = h(rr, j);
      if (t && !mtAyBul_(t) && j > enC && !/MALZEME/i.test(t)) { en = t; enC = j; }
    }
    return en;
  }
  bloklar.forEach(function (c) {
    var cf = ciftlik(c), ay = 0, yil = 0, sonAy = 0, col = null, sap = false;
    for (var r = 0; r < d.length; r++) {
      var x = h(r, c), X = H(r, c), a = mtAyBul_(x);
      if (a && !h(r, c + 1)) {
        // Ay başlığı ya da "Şubat ayında ilaç aşı düşülmemiştir." gibi ay ile başlayan açıklama
        if (!yil) yil = a >= 8 ? 2025 : 2026; else if (a < sonAy) yil++;
        ay = a; sonAy = a; sap = true; // başlıksız ay: SAP dökümü düzeni beklenir, başlık gelirse değişir
        if (x.length > 25 && /\s/.test(x) && !/:\s*\d/.test(x)) notlar.push({ tur: tur, ciftlik: cf, yil: yil, ay: a, not: x });
        continue;
      }
      if (X === 'MALZEME KODU') {
        col = { ad: -1, mik: -1, bir: -1, fiy: -1, top: -1 }; sap = false;
        for (var j = c + 1; j < Math.min(w, c + 8); j++) {
          var t = H(r, j);
          if (!t) { if (col.top >= 0) break; continue; }
          if (t === 'MALZEME') col.ad = j; else if (t === 'TÜKETİM') col.mik = j;
          else if (t === 'BİRİM' || t === 'BİRİMİ') col.bir = j; else if (t === 'BİRİM FİYAT') col.fiy = j;
          else if (/^TOPLAM/.test(t)) col.top = j;
        }
        continue;
      }
      var ad = h(r, c + 1);
      if (!x && !ad) continue;
      if (/^TOPLAM/i.test(ad) || /^TOPLAM/i.test(x)) continue;
      if (!ay) continue;
      if (sap && /^16\d\d$/.test(h(r, c + 2))) {
        // SAP dökümü: kod, malzeme, üretim yeri, miktar-, birim, tutar-, TRY
        var mk = mtSayi_(h(r, c + 3)) || 0, tt = mtSayi_(h(r, c + 5)) || 0;
        out.push([tur, cf, yil, ay, x, ad, mk, h(r, c + 4), mk ? Math.round(tt / mk * 100) / 100 : 0, tt]);
        continue;
      }
      if (col && col.ad >= 0 && x && ad) {
        out.push([tur, cf, yil, ay, x, ad, mtSayi_(h(r, col.mik)) || 0, col.bir >= 0 ? h(r, col.bir) : '',
          col.fiy >= 0 ? mtSayi_(h(r, col.fiy)) || 0 : 0, col.top >= 0 ? mtSayi_(h(r, col.top)) || 0 : 0]);
        continue;
      }
      if (x.length > 15 && /\s/.test(x) && mtSayi_(x) === null) notlar.push({ tur: tur, ciftlik: cf, yil: yil, ay: ay, not: x });
    }
  });
  return { kalemler: out, notlar: notlar };
}

/** {kalemler: [[tür, çiftlik, yıl, ay, kod, malzeme, miktar, birim, birim fiyat, tutar]], notlar: [...]} */
function maliyetTakipDetay_() {
  return onbellekli_('mtDetay_v2', 1800, function () {
    var ss = SpreadsheetApp.openById(MALIYET_TAKIP_ID_), o = { kalemler: [], notlar: [], hatalar: [] };
    [['İLAÇ AŞI', 'İlaç ve aşı'], ['DİĞER MALZEMELER', 'Diğer malzemeler']].forEach(function (s) {
      try {
        var sh = ss.getSheetByName(s[0]);
        if (!sh) { o.hatalar.push(s[0] + ' sayfası yok'); return; }
        var x = mtSayfaOku_(sh, s[1]);
        o.kalemler = o.kalemler.concat(x.kalemler); o.notlar = o.notlar.concat(x.notlar);
      } catch (e) { o.hatalar.push(s[0] + ': ' + e); }
    });
    return o;
  });
}


// ---------------------------------------------------------------------------
// ÇİFTLİK RAPORLARI (muhasebe) – gelir tabloları, satış ve satılan mamul maliyeti: canlı ve tam okuma.
// Daha önce dosyanın ~1 MB ile sınırlı metin dökümünden çevrimdışı üretiliyordu (araclar/ciftlik_rapor/uret.py);
// artık E-Tablo kopyasının bütün satır ve sütunları okunur ve ciftlik_rapor_2026.json sunucuda üretilir.
// Dönem sabit değildir: muhasebenin kapattığı son ay otomatik bulunur.
// KVKK: fatura alıcısı (müşteri) adı ve kodu okunmaz; yalnızca üretim yeri, ay, ürün, miktar ve tutar.
var CR_AY_ADLARI_ = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
var CR_CIFTLIKLER_ = [['Çiftlikler Konsolide', 'Konsolide (tüm çiftlikler)', 'Toplam'], ['1613 - Şekersüt', 'Şekersüt', 'Süt'],
  ['1614 - Pan-Gev', 'Pan-Gev', 'Süt'], ['1611 - Tarımsal Alan', 'Tarımsal Alan', 'Tarım'], ['1605 - Aslım', 'Aslım', 'Et / Besi'],
  ['1604 - Taşağıl', 'ESK-Taşağıl (Besi hizmeti)', 'ESK (ayrı)']];
var CR_KALEMLER_ = [['Brüt satışlar', 'A- 60-BRÜT SATIŞLAR'], ['Net satışlar', 'NET SATIŞLAR'],
  ['Satışların maliyeti', 'C- 62-SATIŞLARIN MALİYETİ (-)'], ['Brüt satış kârı/zararı', 'BRÜT SATIŞ KÂRI VEYA ZARARI'],
  ['Faaliyet giderleri', 'D- 63-FAALİYET GİDERLERİ (-)'], ['Diğer olağan gelirler (649)', 'E- 64-DİĞER FAALİYETLERDEN OLAĞAN GELİR VE KÂRLAR'],
  ['Diğer olağan giderler', 'F- 65-DİĞ.FAALİYETLERDEN OL.GİDER VE ZARARLAR (-)'], ['Finansman giderleri', 'G- 66-FİNANSMAN GİDERLERİ (-)'],
  ['Olağandışı gelirler (679)', 'H- 67-OLAĞANDIŞI GELİR VE KÂRLAR'], ['Olağandışı giderler', 'I- 68-OLAĞANDIŞI GİDER VE ZARARLAR (-)'],
  ['Amortisman', 'AMORTİSMAN'], ['FAVÖK (EBITDA)', 'EBITDA'], ['Dönem net kârı/zararı', 'DÖNEM NET KÂRI VEYA ZARARI ( DÖNEM KARI VEYA ZARARI-J)']];
var CR_BIRIM_URUN_ = { '1613': 'Süt – Şekersüt', '1614': 'Süt – Pan-Gev', '1604': 'ESK besi hizmeti' };
// SMM bileşenleri: [ad, başlık deseni]
var CR_BILESEN_ = [['Hammadde (yem)', /Hammadde/], ['Yardımcı malzeme', /Yardımcı/], ['Ambalaj malzemesi', /Ambalaj/],
  ['Direkt işçilik', /Direkt İşçilik/], ['Enerji', /Enerji/], ['Bakım onarım', /Bakım Onarım/], ['Endirekt işçilik', /Endirekt/],
  ['Genel üretim', /Genel Üretim/], ['Amortisman', /Amortisman/]];
var CR_TARIM_AD_ = { 'BUĞDAY': 'Buğday', 'PANCAR(TARLA)': 'Şeker pancarı', 'YONCA BALYASI': 'Yonca balyası', 'TRİTİKALE(TARLA)': 'Tritikale',
  'PATATES': 'Patates', 'MISIR SILAJI': 'Mısır silajı', 'SAP BALYASI': 'Sap balyası', 'ESK SAP BALYASI': 'Sap balyası (ESK’ya)',
  'AİDA TEMİZ ARPA TOHUMU KG': 'Arpa tohumu (Aida)', 'TOHUM ARPA CERVOİSE': 'Arpa tohumu (Cervoise)', 'TOHUM BUĞDAY': 'Buğday tohumu' };
var CR_TARIM_CIFTLIK_ = { '1604': 'ESK-Taşağıl', '1605': 'Aslım', '1611': 'Tarımsal Alan' };
var CR_NET_ = 'DÖNEM NET KÂRI VEYA ZARARI ( DÖNEM KARI VEYA ZARARI-J)';
var CR_DONEM_KARI_ = 'DÖNEM KÂRI VEYA ZARARI (OLAĞAN KAR VEYA ZARAR+H-I)';

function crSayiH_(v) {
  if (typeof v === 'number') return v;
  var t = String(v == null ? '' : v).trim();
  if (!t || t === '-' || /%$/.test(t)) return 0;
  var x = eskTrSayi_(t);
  return x === null || isNaN(x) ? 0 : x;
}

/** Gelir tablosu sayfası → { satırEtiketi: {'26': [12], '25': [12], '24': [12]} }; bütün satırlar. */
function crGelirTablosu_(d) {
  var bs = -1, sut = {};
  for (var r = 0; r < Math.min(10, d.length) && bs < 0; r++) {
    d[r].forEach(function (x, j) {
      // Başlık hücresi metin ("Ocak 26") ya da xlsx dönüşümünde tarih değeri olabilir.
      if (Object.prototype.toString.call(x) === '[object Date]' && !isNaN(x.getTime())) {
        var yy = ('0' + (x.getFullYear() % 100)).slice(-2);
        if (/^(2[4-9])$/.test(yy)) { sut[yy + '|' + x.getMonth()] = j; bs = r; }
        return;
      }
      var m = /^\s*(Ocak|Şubat|Mart|Nisan|Mayıs|Haziran|Temmuz|Ağustos|Eylül|Ekim|Kasım|Aralık)\s+(\d\d)\s*$/.exec(String(x));
      if (m) { sut[m[2] + '|' + CR_AY_ADLARI_.indexOf(m[1])] = j; bs = r; }
    });
  }
  var o = {}, sira = [];
  if (bs < 0) return { satirlar: o, sira: sira };
  for (var i = bs + 1; i < d.length; i++) {
    var ad = String(d[i][0] || '').trim();
    if (!ad) continue;
    var y = {};
    ['26', '25', '24'].forEach(function (yy) {
      var l = [];
      for (var a = 0; a < 12; a++) { var j = sut[yy + '|' + a]; l.push(j == null ? 0 : crSayiH_(d[i][j])); }
      y[yy] = l;
    });
    if (!o[ad]) sira.push(ad);
    o[ad] = y;
  }
  return { satirlar: o, sira: sira };
}

function crBaslikIndeks_(h, desen) {
  for (var j = 0; j < h.length; j++) if (desen.test(String(h[j]).replace(/\s+/g, ' ').trim())) return j;
  return -1;
}

/** @param oku function(sayfaAdı) → 2B dizi (yoksa null). */
function ciftlikRaporUretCekirdek_(oku, kaynakAdi) {
  var g = {}, tam = {}, hatalar = [];
  ['Çiftlikler Konsolide', 'Çiftlikler Konsolide (2)', '1604 - Taşağıl', '1605 - Aslım', '1605 - Aslım 2', '1611 - Tarımsal Alan',
   '1611 - Tarımsal Alan 2', '1613 - Şekersüt', '1613 - Şekersüt 2', '1614 - Pan-Gev', '1614 - Pan-Gev 2'].forEach(function (s) {
    var d = oku(s);
    if (!d) { hatalar.push(s + ' sayfası yok'); return; }
    var t = crGelirTablosu_(d);
    g[s] = t.satirlar;
    tam[s] = t.sira.map(function (ad) { return [ad, t.satirlar[ad]['26'], t.satirlar[ad]['25'], t.satirlar[ad]['24']]; });
  });
  function seri(s, k, y) { return ((g[s] || {})[k] || {})[y] || [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]; }
  // Kapanan son ay: Konsolide'de satış veya net sonucu sıfırdan farklı olan son 2026 ayı
  var n = 0;
  for (var a = 0; a < 12; a++) if (seri('Çiftlikler Konsolide', 'NET SATIŞLAR', '26')[a] || seri('Çiftlikler Konsolide', CR_NET_, '26')[a]) n = a + 1;
  if (!n) n = 1;
  function top(l, k) { var s = 0; for (var i = 0; i < (k || 12); i++) s += l[i] || 0; return Math.round(s); }

  var gelir = [], aylik = [];
  CR_CIFTLIKLER_.forEach(function (c) {
    CR_KALEMLER_.forEach(function (k) {
      gelir.push({ ciftlik: c[1], bolum: c[2], kalem: k[0], y2026_9ay: top(seri(c[0], k[1], '26'), n), y2025_9ay: top(seri(c[0], k[1], '25'), n),
        y2025_yil: top(seri(c[0], k[1], '25')), y2024_yil: top(seri(c[0], k[1], '24')) });
    });
    [['26', 2026, n], ['25', 2025, 12]].forEach(function (p) {
      for (var i = 0; i < p[2]; i++) aylik.push({ ciftlik: c[1], yil: p[1], ay: CR_AY_ADLARI_[i], ay_no: i + 1,
        net_kar: Math.round(seri(c[0], CR_NET_, p[0])[i]), brut_kar: Math.round(seri(c[0], CR_KALEMLER_[3][1], p[0])[i]) });
    });
  });
  CR_KALEMLER_.forEach(function (k) {
    var f = {};
    ['26', '25', '24'].forEach(function (y) { var a1 = seri('Çiftlikler Konsolide', k[1], y), b1 = seri('1604 - Taşağıl', k[1], y); f[y] = a1.map(function (x, i) { return x - b1[i]; }); });
    gelir.push({ ciftlik: 'Çiftliklerimiz (ESK hariç)', bolum: 'Toplam', kalem: k[0], y2026_9ay: top(f['26'], n), y2025_9ay: top(f['25'], n),
      y2025_yil: top(f['25']), y2024_yil: top(f['24']) });
  });

  // Satış ve SMM detayı (bütün satırlar)
  var satis = oku('Satış') || [], smm = oku('SMM Detay') || [];
  if (!satis.length) hatalar.push('Satış sayfası yok');
  if (!smm.length) hatalar.push('SMM Detay sayfası yok');
  var hs = satis[0] || [], hm = smm[0] || [];
  var S = { uy: 0, yil: 1, ay: 2, mal: crBaslikIndeks_(hs, /^Malzeme$/), ad: crBaslikIndeks_(hs, /^Malzeme Adı$/),
    kg: crBaslikIndeks_(hs, /^NET KG$/), tl: crBaslikIndeks_(hs, /^Net Tutar TL$/), hesap: crBaslikIndeks_(hs, /^Fatura Alıcısı Adı$/) };
  var M = { uy: 0, yil: 1, ay: 2, ad: crBaslikIndeks_(hm, /kısa metni/), mik: crBaslikIndeks_(hm, /Top\.Ürt\.Miktarı/), top: crBaslikIndeks_(hm, /Fiili Top\.Değer/) };
  var bil = CR_BILESEN_.map(function (b) { return [b[0], crBaslikIndeks_(hm, b[1])]; });
  function grup(p) { p = String(p); return p.indexOf('SÜT') >= 0 ? 'SÜT' : p.indexOf('ESK BÜYÜKBAŞ') >= 0 ? 'ESK' : null; }
  var U = {}, F = {}, T = {}, tes = {}, satisSatir = [], smmSatir = [];
  for (var i = 1; i < smm.length; i++) {
    var r = smm[i], uy = String(r[M.uy]).trim(), yil = String(r[M.yil]).trim(), ay = CR_AY_ADLARI_.indexOf(String(r[M.ay]).trim()), urun = String(r[M.ad]).trim();
    if (!uy || ay < 0) continue;
    var mik = crSayiH_(r[M.mik]), tt = crSayiH_(r[M.top]);
    var b = bil.map(function (x) { return x[1] >= 0 ? crSayiH_(r[x[1]]) : 0; });
    smmSatir.push([uy, +yil, ay + 1, urun, mik, Math.round(tt * 100) / 100].concat(b.map(function (x) { return Math.round(x * 100) / 100; })));
    if (grup(urun)) {
      var k = uy + '|' + yil + '|' + ay, u = U[k] || (U[k] = { q: 0, t: 0, b: bil.map(function () { return 0; }) });
      u.q += mik; u.t += tt; b.forEach(function (x, j) { u.b[j] += x; });
    }
    if (CR_TARIM_CIFTLIK_[uy] && CR_TARIM_AD_[urun]) { var kt = uy + '|' + urun + '|' + yil, t0 = T[kt] || (T[kt] = [0, 0, 0, 0]); t0[2] += mik; t0[3] += tt; }
  }
  for (var i2 = 1; i2 < satis.length; i2++) {
    var s = satis[i2], uy2 = String(s[S.uy]).trim(), yil2 = String(s[S.yil]).trim(), ay2 = CR_AY_ADLARI_.indexOf(String(s[S.ay]).trim());
    var mal = String(s[S.mal]).trim(), ad2 = String(s[S.ad]).trim(), kg = crSayiH_(s[S.kg]), tl = crSayiH_(s[S.tl]);
    // Teşvik / prim gelirleri ("diğer"): türü hesap açıklamasından (Fatura Alıcısı Adı sütunu) belirlenir; açıklama çıktıya yazılmaz.
    if (mal === 'diğer') ad2 = String(s[S.hesap] || '').trim();
    if (!uy2 || ay2 < 0) continue;
    satisSatir.push([uy2, +yil2, ay2 + 1, mal === 'diğer' ? 'teşvik / prim' : 'ürün', mal === 'diğer' ? '' : ad2, Math.round(kg * 100) / 100, Math.round(tl * 100) / 100]);
    if (mal === 'diğer') {
      var kk = ad2.indexOf('ÇİĞ SÜT') >= 0 ? 'Süt teşviki' : ad2.indexOf('BUZAĞI') >= 0 ? 'Buzağı teşviki' : ad2.indexOf('TARIMSAL') >= 0 ? 'Tarımsal teşvik' : 'İstihdam (SGK) teşvikleri';
      tes[yil2 + '|' + kk] = (tes[yil2 + '|' + kk] || 0) + tl;
      continue;
    }
    if (grup(ad2)) { var kf = uy2 + '|' + yil2 + '|' + ay2, f0 = F[kf] || (F[kf] = [0, 0]); f0[0] += kg; f0[1] += tl; }
    if (CR_TARIM_CIFTLIK_[uy2] && CR_TARIM_AD_[ad2]) { var kt2 = uy2 + '|' + ad2 + '|' + yil2, t1 = T[kt2] || (T[kt2] = [0, 0, 0, 0]); t1[0] += kg; t1[1] += tl; }
  }
  var birim = Object.keys(U).sort().filter(function (k) { return U[k].q && CR_BIRIM_URUN_[k.split('|')[0]]; }).map(function (k) {
    var p = k.split('|'), u = U[k], f = F[k] || [0, 0], bm = {};
    bil.forEach(function (x, j) { if (x[1] >= 0 && (j < 1 || j > 2 || Math.round(u.b[j]))) bm[x[0]] = Math.round(u.b[j]); });
    return { urun: CR_BIRIM_URUN_[p[0]], yil: +p[1], ay_no: +p[2] + 1, miktar: Math.round(u.q), toplam: Math.round(u.t), bilesen: bm,
      satis_miktar: Math.round(f[0]), satis_tl: Math.round(f[1]), tutarsiz: false };
  });
  // Tutarsız ay: toplam ≤ 0, bileşen toplamı fiili toplamdan %1'den fazla farklı ya da birim maliyet ürünün
  // ortanca birim maliyetinin 1/4'ünden düşük veya 4 katından yüksek (ör. üretim miktarı ile maliyet aynı aya düşmemiş).
  var ort = {};
  birim.forEach(function (x) { (ort[x.urun] = ort[x.urun] || []).push(x.toplam / x.miktar); });
  Object.keys(ort).forEach(function (u) { var l = ort[u].sort(function (a, b) { return a - b; }); ort[u] = l[Math.floor(l.length / 2)]; });
  birim.forEach(function (x) {
    var s0 = 0; for (var kb in x.bilesen) s0 += x.bilesen[kb];
    var bm = x.toplam / x.miktar, o = ort[x.urun];
    if (x.toplam <= 0 || Math.abs(s0 - x.toplam) > Math.max(1000, Math.abs(x.toplam) * 0.01) || (o > 0 && (bm < o / 4 || bm > o * 4))) x.tutarsiz = true;
  });
  var tarim = Object.keys(T).sort().map(function (k) {
    var p = k.split('|'), v = T[k];
    return { ciftlik: CR_TARIM_CIFTLIK_[p[0]], urun: CR_TARIM_AD_[p[1]], yil: +p[2], satis_kg: Math.round(v[0]), satis_tl: Math.round(v[1]),
      smm_kg: Math.round(v[2]), smm_tl: Math.round(v[3]) };
  });
  var tesvik = Object.keys(tes).sort().map(function (k) { var p = k.split('|'); return { yil: +p[0], kalem: p[1], tutar: Math.round(tes[k]) }; });

  return {
    baslik: 'Çiftlikler Rapor 2026', kaynak: kaynakAdi, donem: 'Ocak–' + CR_AY_ADLARI_[n - 1] + ' 2026', ay_sayisi: n,
    uretim: 'sunucu (canlı, tam okuma)', gelir: gelir, aylik: aylik, birim: birim, tarim: tarim, tesvik: tesvik,
    senaryo: crSenaryo_(g, n), gelirTam: tam, satisDetay: satisSatir, smmDetay: smmSatir,
    smmBilesenleri: bil.filter(function (x) { return x[1] >= 0; }).map(function (x) { return x[0]; }), hatalar: hatalar
  };
}

function crSenaryo_(g, n) {
  var K = {}; CR_KALEMLER_.forEach(function (k) { K[k[0]] = k[1]; });
  var KAL = ['Net satışlar', 'Satışların maliyeti', 'Brüt satış kârı/zararı', 'Faaliyet giderleri', 'Faaliyet dışı net', 'Dönem net kârı/zararı'];
  var CF = [['1605 - Aslım', 'Aslım'], ['1611 - Tarımsal Alan', 'Tarımsal Alan'], ['1613 - Şekersüt', 'Şekersüt'], ['1614 - Pan-Gev', 'Pan-Gev']];
  function ham(s, k, y) { return (((g[s] || {})[k] || {})[y]) || [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]; }
  function seri(s, kalem, y) {
    y = y || '26';
    if (kalem === 'Faaliyet dışı net') {
      var a = ['Diğer olağan gelirler (649)', 'Olağandışı gelirler (679)', 'Diğer olağan giderler', 'Olağandışı giderler'].map(function (k) { return ham(s, K[k], y); });
      return a[0].map(function (_, i) { return a[0][i] + a[1][i] - a[2][i] - a[3][i]; });
    }
    return ham(s, K[kalem], y);
  }
  function tl(v) { return Math.round(v).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.'); }
  function mn(v) { return (Math.round(v / 1e5) / 10).toFixed(1).replace('.', ','); }
  function sutunH(i) { return sutunHarf_(i + 1); }
  function konum(sayfa, satir, yil, aylar) {
    function ac(a) { return sutunH((yil === 2026 ? 1 : 28) + 2 * (a - 1)); }
    var s = aylar.length === 1 ? ac(aylar[0]) + ' sütunu (' + CR_AY_ADLARI_[aylar[0] - 1] + ' ' + (yil % 100) + ')'
      : ac(aylar[0]) + '–' + ac(aylar[aylar.length - 1]) + ' sütunları (' + CR_AY_ADLARI_[aylar[0] - 1] + '–' + CR_AY_ADLARI_[aylar[aylar.length - 1] - 1] + ' ' + (yil % 100) + ')';
    return '“' + sayfa + '” sayfası · “' + satir + '” satırı · ' + s;
  }
  function donem(s, y, m) {
    var l = [];
    for (var i = 0; i < m; i++) {
      var o = { ay_no: i + 1 };
      KAL.forEach(function (k) { o[k + '|1'] = Math.round(seri(s, k, y)[i]); o[k + '|2'] = Math.round(seri(s + ' 2', k, y)[i]); });
      l.push(o);
    }
    return { ay_sayisi: m, aylik: l };
  }
  var cl = [], kontrol = [], t1 = {}, t2 = {};
  KAL.forEach(function (k) { t1[k] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]; t2[k] = t1[k].slice(); });
  function sum(l, m) { var s = 0; for (var i = 0; i < m; i++) s += l[i] || 0; return s; }
  CF.forEach(function (c) {
    var s = c[0], s2 = s + ' 2';
    if (!g[s] || !g[s2]) return;
    var kal = KAL.map(function (k) {
      var a = seri(s, k), b = seri(s2, k);
      for (var i = 0; i < 12; i++) { t1[k][i] += a[i]; t2[k][i] += b[i]; }
      return { kalem: k, s1: Math.round(sum(a, n)), s2: Math.round(sum(b, n)) };
    });
    var n1 = seri(s, 'Dönem net kârı/zararı'), n2 = seri(s2, 'Dönem net kârı/zararı'), ns1 = seri(s, 'Net satışlar'), ns2 = seri(s2, 'Net satışlar'), ay = [];
    for (var i = 0; i < n; i++) ay.push({ ay_no: i + 1, s1: Math.round(n1[i]), s2: Math.round(n2[i]), satis1: Math.round(ns1[i]), satis2: Math.round(ns2[i]) });
    cl.push({ ciftlik: c[1], sayfa: s, kalemler: kal, aylik: ay, donemler: { '2026': donem(s, '26', n), '2025': donem(s, '25', 12) } });
    var smm1 = seri(s, 'Satışların maliyeti'), neg = [];
    for (var j = 0; j < n; j++) if (smm1[j] < -1) neg.push(j + 1);
    if (neg.length) {
      kontrol.push({ tur: 'tutarsizlik', baslik: c[1] + ' – negatif satış maliyeti', ciftlik: c[1],
        aciklama: 'Maliyet senaryosunda (“' + s + '”) ' + neg.map(function (a) { return CR_AY_ADLARI_[a - 1]; }).join(', ') +
          ' ayında satışların maliyeti eksi (' + tl(Math.min.apply(null, smm1.slice(0, n))) + ' ₺) görünüyor; iade/düzeltme kaydı muhasebeden teyit edilmeli.',
        kaynak: konum(s, K['Satışların maliyeti'], 2026, neg) });
    }
  });
  if (cl.length) {
    var kal0 = KAL.map(function (k) { return { kalem: k, s1: Math.round(sum(t1[k], n)), s2: Math.round(sum(t2[k], n)) }; });
    var ay0 = [];
    for (var i = 0; i < n; i++) ay0.push({ ay_no: i + 1, s1: Math.round(t1['Dönem net kârı/zararı'][i]), s2: Math.round(t2['Dönem net kârı/zararı'][i]),
      satis1: Math.round(t1['Net satışlar'][i]), satis2: Math.round(t2['Net satışlar'][i]) });
    function topla(y) {
      var l = cl.map(function (c) { return c.donemler[y]; }), m = l[0].ay_sayisi, out = [];
      for (var i = 0; i < m; i++) {
        var o = { ay_no: i + 1 };
        Object.keys(l[0].aylik[i]).forEach(function (k) { if (k !== 'ay_no') o[k] = l.reduce(function (t, x) { return t + x.aylik[i][k]; }, 0); });
        out.push(o);
      }
      return { ay_sayisi: m, aylik: out };
    }
    cl.unshift({ ciftlik: 'Çiftliklerimiz (ESK hariç)', sayfa: '', kalemler: kal0, aylik: ay0, donemler: { '2026': topla('2026'), '2025': topla('2025') } });
    var k2 = g['Çiftlikler Konsolide (2)'];
    if (k2 && k2[CR_NET_] && k2[CR_DONEM_KARI_]) {
      var net2 = sum(k2[CR_NET_]['26'], n), dk2 = sum(k2[CR_DONEM_KARI_]['26'], n), tp = sum(t2['Dönem net kârı/zararı'], n), al = [];
      for (var a2 = 1; a2 <= n; a2++) al.push(a2);
      if (Math.abs(net2 - dk2) > 1000) kontrol.push({ tur: 'tutarsizlik', baslik: 'Konsolide (2) – dönem net kârı satırı hatalı', ciftlik: 'Çiftliklerimiz (ESK hariç)',
        aciklama: '“Çiftlikler Konsolide (2)” sayfasında dönem kârı ' + mn(dk2) + ' mn ₺, vergi karşılığı sıfır olduğu hâlde dönem net kârı ' + mn(net2) +
          ' mn ₺ yazıyor. Çiftlik sayfalarının toplamı ' + mn(tp) + ' mn ₺ olduğundan analizde toplam kullanılmıştır; satırdaki formül düzeltilmeli.',
        kaynak: konum('Çiftlikler Konsolide (2)', CR_NET_, 2026, al) + '; karşılaştırılan satır “' + CR_DONEM_KARI_ + '”' });
      if (k2['NET SATIŞLAR']) {
        var ns = sum(k2['NET SATIŞLAR']['26'], n);
        if (Math.abs(ns - sum(t2['Net satışlar'], n)) > 1000) kontrol.push({ tur: 'tutarsizlik', baslik: 'Konsolide (2) – net satış toplamı çiftliklerle uyuşmuyor',
          aciklama: 'Konsolide (2) net satış ' + mn(ns) + ' mn ₺, çiftlik sayfaları toplamı ' + mn(sum(t2['Net satışlar'], n)) + ' mn ₺.',
          ciftlik: 'Çiftliklerimiz (ESK hariç)', kaynak: konum('Çiftlikler Konsolide (2)', 'NET SATIŞLAR', 2026, al) });
      }
    }
    cl.slice(1).forEach(function (c) {
      var ayni = c.aylik.filter(function (a) { return a.satis1 === a.satis2 && Math.abs(a.s1 - a.s2) < 1; }).map(function (a) { return CR_AY_ADLARI_[a.ay_no - 1]; });
      var farkli = c.aylik.filter(function (a) { return Math.abs(a.s1 - a.s2) >= 1; });
      if (ayni.length && farkli.length) kontrol.push({ tur: 'bilgi', baslik: c.ciftlik + ' – iki senaryonun aynı olduğu aylar', ciftlik: c.ciftlik,
        aciklama: ayni.join(', ') + ' aylarında iki sayfa aynı; bu aylarda grup içi alım-satım olmamış ya da piyasa fiyatıyla yeniden değerleme yapılmamış olabilir.' });
    });
  }
  return { aciklama: 'Birinci senaryoda çiftliklerde üretilip grup içinde kullanılan ürünler maliyet bedeliyle aktarılır. İkinci senaryoda ' +
      '(dosyadaki “2” uzantılı sayfalar) bu ürünler dışarı satılsaydı piyasa satış fiyatıyla, dışarıdan alınsaydı piyasa alış fiyatıyla değerlenir.',
    donem: 'Ocak–' + CR_AY_ADLARI_[n - 1] + ' 2026', ciftlikler: cl, kontrol: kontrol };
}

/** Çiftlik Raporları E-Tablosundan ciftlik_rapor_2026.json'u üretir ve Uygulama Verileri'ndeki dosyaya yazar. */
function ciftlikRaporUret_(tablo) {
  tablo = tablo || ciftlikRaporTabloBul_();
  if (!tablo) return { hata: 'Çiftlik Raporları E-Tablosu yok' };
  var ss = SpreadsheetApp.open(tablo);
  var o = ciftlikRaporUretCekirdek_(function (ad) {
    var s = ss.getSheetByName(ad);
    if (!s) { var l = ss.getSheets().filter(function (x) { return x.getName().trim() === ad; }); s = l[0]; }
    return s ? s.getDataRange().getValues() : null;
  }, tablo.getName());
  o.kaynakGuncelleme = Utilities.formatDate(tablo.getLastUpdated(), 'Europe/Istanbul', 'dd.MM.yyyy HH:mm');
  // Güvenlik: gelir tablolarından hiç tutar okunamadıysa mevcut dosyanın üzerine yazılmaz.
  var dolu = o.gelir.some(function (g) { return g.y2026_9ay || g.y2025_yil; });
  if (!dolu) return { hata: 'Gelir tablolarında tutar okunamadı; mevcut dosya korunuyor.', hatalar: o.hatalar };
  DriveApp.getFileById(UYGULAMA_DOSYALARI_.ciftlik_rapor_2026).setContent(JSON.stringify(o));
  try { CacheService.getScriptCache().remove('dosya_ciftlik_rapor_2026_' + UYGULAMA_DOSYALARI_.ciftlik_rapor_2026 + '_n'); } catch (e) {}
  return { donem: o.donem, gelir: o.gelir.length, birim: o.birim.length, tarim: o.tarim.length, satis: o.satisDetay.length, smm: o.smmDetay.length, hatalar: o.hatalar };
}


// ---------------------------------------------------------------------------
// MALİYET TAKİP – sunucuda canlı ve tam okuma (maliyet_takip_2026.json). Daha önce xlsx dışa aktarımından
// çevrimdışı üretiliyordu (araclar/ciftlik_rapor/maliyet_takip.py). Fark: yem sayfasında yalnızca ana yemler ve
// 9 ay değil, bütün malzemeler ve 12 ay okunur. KVKK: yalnızca çiftlik / kalem toplamları; kişi, belge no yok.
var MT_AYLAR_UST_ = ['OCAK', 'ŞUBAT', 'MART', 'NİSAN', 'MAYIS', 'HAZİRAN', 'TEMMUZ', 'AĞUSTOS', 'EYLÜL', 'EKİM', 'KASIM', 'ARALIK'];
function mtUst_(x) { return String(x == null ? '' : x).toLocaleUpperCase('tr'); }
function mtDeger_(v) {
  if (v === null || v === undefined || v === '') return null;
  if (typeof v === 'number') return v;
  if (Object.prototype.toString.call(v) === '[object Date]') return null;
  var s = String(v).trim();
  if (s.charAt(0) === '#') return 'HATA';
  var x = Number(s.replace(/\./g, '').replace(',', '.'));
  return isNaN(x) || s === '' ? null : x;
}
function mtSayiMi_(v) { return typeof v === 'number' && !isNaN(v); }
function mtHucre_(r, j) { return r && j < r.length ? r[j] : null; }

function maliyetTakipUretCekirdek_(oku) {
  var hatalar = {}, H = function (k) { hatalar[k] = (hatalar[k] || 0) + 1; };
  // 1) Hayvancılık
  var s = oku('MALİYET ÖZET HAYVANCILIK') || [], hay = [];
  var bloklar = [[3, 'Aslım'], [20, 'Taşağıl'], [44, 'Şekersüt'], [61, 'Pan-Gev']], kalemler = [[1, 'yem'], [2, 'iscilik'], [3, 'amortisman'], [4, 'diger'], [5, 'toplam'], [7, 'hayvan']];
  bloklar.forEach(function (b) {
    [[2025, 2], [2026, 17]].forEach(function (yk) {
      for (var ay = 0; ay < 12; ay++) {
        var k = { ciftlik: b[1], yil: yk[0], ay: ay + 1 }, bos = true;
        kalemler.forEach(function (kl) {
          var v = mtDeger_(mtHucre_(s[b[0] - 1 + kl[0]], yk[1] + ay));
          if (v === 'HATA') { H(['MALİYET ÖZET HAYVANCILIK', b[1], yk[0]].join('|')); v = null; }
          if (v !== null && v !== 0) bos = false;
          k[kl[1]] = v;
        });
        if (!bos) hay.push(k);
      }
    });
  });
  var kopya = 0;
  if (s[78] && s[61]) for (var j = 2; j < 14; j++) { var a = mtDeger_(s[78][j]), bb = mtDeger_(s[61][j]); if (mtSayiMi_(a) && a === bb) kopya++; }
  // 2) Tarım
  var t = oku('MALİYET ÖZET TARIM 2026') || [], donem = [], ortak = [], ekilis = [];
  for (var c = 2; c < 19; c++) {
    var h = mtHucre_(t[2], c);
    donem.push(Object.prototype.toString.call(h) === '[object Date]' ? [h.getFullYear(), h.getMonth() + 1] : null);
  }
  donem.forEach(function (ya, i) {
    if (!ya) return;
    var k = { yil: ya[0], ay: ya[1] };
    [[3, 'iscilik'], [4, 'amortisman'], [5, 'diger']].forEach(function (x) { var v = mtDeger_(mtHucre_(t[x[0]], 2 + i)); k[x[1]] = v === 'HATA' ? null : v; });
    if (k.iscilik || k.amortisman || k.diger) ortak.push(k);
  });
  var URUN = { 'YONCA': 'Yonca', 'ARPA': 'Arpa', 'BUĞDAY': 'Buğday', 'TRİTİKALE': 'Tritikale', 'PANCAR': 'Şeker pancarı', 'MISIR SİLAJI': 'Mısır silajı', 'PATATES': 'Patates' };
  var CF = { 'ASLIM': 'Aslım', 'ŞEKERSÜT': 'Şekersüt', 'TAŞAĞIL': 'Taşağıl' }, cf = null;
  for (var r = 9; r < t.length; r++) {
    var row = t[r];
    if (row[0]) { var u0 = mtUst_(row[0]).replace(' EKİLİŞ', '').trim(); cf = CF[u0] || (u0.charAt(0) + u0.slice(1).toLocaleLowerCase('tr')); }
    if (!row[1] || mtUst_(row[1]).trim() === 'TOPLAM' || cf === null) continue;
    var ad = String(row[1]).trim(), p = ad.indexOf('('), urun = (p >= 0 ? ad.slice(0, p) : ad).trim(), alan = p >= 0 ? ad.slice(p + 1) : '';
    var dek = mtDeger_(alan.replace('dekar', '').replace(')', '').trim()), aylik = {}, top = 0;
    donem.forEach(function (ya, i) {
      if (!ya) return;
      var v = mtDeger_(row[2 + i]);
      if (v === 'HATA') { H(['MALİYET ÖZET TARIM 2026', cf, urun].join('|')); return; }
      if (v) { aylik[ya[0] + '-' + ('0' + ya[1]).slice(-2)] = v; top += v; }
    });
    ekilis.push({ ciftlik: cf, urun: URUN[urun] || urun, dekar: mtSayiMi_(dek) ? dek : null, aylik: aylik, toplam: Math.round(top * 100) / 100 });
  }
  var yazili = t[6] ? mtDeger_(t[6][19]) : null;
  // 3) Süt litre maliyeti
  var su = oku('SÜT MALİYETİ') || [], sut = [], disari = [];
  [['Şekersüt', 0], ['Pan-Gev', 7]].forEach(function (x) {
    su.slice(5, 17).forEach(function (row) {
      var ay = MT_AYLAR_UST_.indexOf(mtUst_(row[x[1]]).trim()) + 1;
      if (!ay) return;
      [2024, 2025, 2026].forEach(function (yil, jj) {
        var v = mtDeger_(row[x[1] + 1 + jj]);
        if (mtSayiMi_(v)) { var sa = yil === 2026 ? mtDeger_(row[x[1] + 4]) : null; sut.push({ ciftlik: x[0], yil: yil, ay: ay, maliyet: v, satis: mtSayiMi_(sa) ? sa : null }); }
      });
    });
  });
  su.forEach(function (row, i) { row.forEach(function (v, jj) { if (jj >= 13 && v !== null && v !== '') disari.push(sutunHarf_(jj + 1) + (i + 1)); }); });
  // 4) Karkas
  var ka = oku('KARKAS MALİYETİ') || [], karkas = [];
  var tanim = [['Aslım', 'Besi', 0, 1, 2], ['Şekersüt', 'Dişi', 4, 5, null], ['Şekersüt', 'Besi', 4, 6, 7], ['Pan-Gev', 'Dişi', 8, 9, null]];
  ka.slice(5, 17).forEach(function (row) {
    tanim.forEach(function (x) {
      var ay = MT_AYLAR_UST_.indexOf(mtUst_(row[x[2]]).trim()) + 1;
      if (!ay) return;
      var v = mtHucre_(row, x[3]), not = x[4] !== null && row[x[4]] ? String(row[x[4]]).trim() : '', d = mtDeger_(v);
      if (typeof v === 'string' && d === null) not = v.trim();
      if (d === null && !not) return;
      karkas.push({ ciftlik: x[0], tur: x[1], ay: ay, maliyet: mtSayiMi_(d) ? d : null, not_: not });
    });
  });
  // 5) Canlı hayvan (kayar ortalama)
  var kay = oku('KAYAR ORTALAMA') || [], canli = [];
  var tc = [['Aslım', 0, ['Besi', 'Başlıksız sütun']], ['Şekersüt', 4, ['Erkek buzağı', 'Besi', 'Dişi buzağı', 'Dişi dana', 'Düve', 'İnek']],
    ['Pan-Gev', 12, ['Erkek buzağı', 'Dişi buzağı', 'Dişi dana', 'Düve', 'İnek']]];
  kay.slice(6, 18).forEach(function (row) {
    tc.forEach(function (x) {
      var ay = MT_AYLAR_UST_.indexOf(mtUst_(row[x[1]]).trim()) + 1;
      if (!ay) return;
      x[2].forEach(function (kat, jj) { var d = mtDeger_(mtHucre_(row, x[1] + 1 + jj)); if (mtSayiMi_(d)) canli.push({ ciftlik: x[0], kategori: kat, ay: ay, maliyet: d }); });
    });
  });
  // 6) Yem: bütün malzemeler, 12 ay (ay başına miktar + tutar + birim fiyat sütunu)
  var y = oku('YEM') || [], yem = [], toplamsiz = [], genel = [], grup = null;
  var GR = { 'ASLIM': 'Aslım', 'ŞEKERSÜT BESİ': 'Şekersüt besi', 'ŞEKERSÜT ANAÇ': 'Şekersüt anaç' };
  y.forEach(function (row) {
    if (row[0]) {
      var g0 = String(row[0]).trim();
      grup = GR[g0] || g0;
      if (g0.indexOf('PANGEV') === 0 && g0.indexOf('ANAÇ') >= 0) grup = 'Pan-Gev anaç'; else if (g0 === 'PANGEV') grup = 'Pan-Gev besi';
    }
    var ad = row[2];
    if (grup === null || typeof ad !== 'string' || !ad.trim()) {
      if (String(row[1]).trim() === 'Genel Toplam' && grup) genel.push({ grup: grup, tutar: mtDeger_(row[41]) || 0, miktar: mtDeger_(row[40]) || 0 });
      return;
    }
    ad = ad.trim();
    if (/^malzeme/i.test(ad)) return;
    var aylik = [];
    for (var ay = 0; ay < 12; ay++) {
      if (5 + 3 * ay >= 40) break;  // 40. ve 41. sütunlar dönem toplamlarıdır
      var q = mtDeger_(row[4 + 3 * ay]), tt = mtDeger_(row[5 + 3 * ay]);
      if (mtSayiMi_(q) && q) aylik.push([ay + 1, q, mtSayiMi_(tt) ? tt : null]);
    }
    if (!aylik.length) return;
    var tp = mtDeger_(row[41]);
    if (tp === null || tp === 'HATA') toplamsiz.push({ grup: grup, malzeme: ad, miktar: Math.round(aylik.reduce(function (s0, a) { return s0 + a[1]; }, 0) * 10) / 10 });
    aylik.forEach(function (a) { yem.push({ grup: grup, malzeme: ad, ay: a[0], miktar: Math.round(a[1] * 100) / 100, tutar: a[2] ? Math.round(a[2] * 100) / 100 : null }); });
  });
  // 7) Özet sayfası hata sayısı
  var oz = oku('ÖZET') || [], ozRef = 0;
  oz.forEach(function (row) { row.forEach(function (v) { if (typeof v === 'string' && /^#REF/.test(v.trim())) ozRef++; }); });
  function ayni(c) {
    var a = hay.filter(function (h) { return h.ciftlik === c && h.ay === 1; });
    return a.length === 2 && ['yem', 'iscilik', 'amortisman', 'diger', 'toplam', 'hayvan'].every(function (k) { return a[0][k] === a[1][k]; });
  }
  return {
    kaynak: 'ÇİFTLİKLER : MALİYET TAKİP 2026', uretim: 'sunucu (canlı, tam okuma)',
    hayvancilik: hay, tarim_ortak: ortak, tarim_ekilis: ekilis, sut_litre: sut, karkas: karkas, canli: canli, yem: yem, yem_genel: genel,
    kontrol: {
      ref_hatalari: Object.keys(hatalar).sort().map(function (k) { var p = k.split('|'); return { sayfa: p[0], bolum: p[1], yil: String(p[2]), adet: hatalar[k] }; }),
      ozet_ref: ozRef, toplam_2025_pangev_kopya: kopya, tasagil_2026_ocak_2025_kopya: ayni('Taşağıl'), sut_tablo_disi_hucre: disari,
      yem_toplama_alinmayan: toplamsiz, tarim_ortak_toplam_yazili: mtSayiMi_(yazili) ? yazili : null
    }
  };
}

function maliyetTakipUret_() {
  var ss = SpreadsheetApp.openById(MALIYET_TAKIP_ID_);
  var o = maliyetTakipUretCekirdek_(function (ad) { var sh = ss.getSheetByName(ad); return sh ? sh.getDataRange().getValues() : null; });
  if (!o.hayvancilik.length) return { hata: 'Maliyet Takip hayvancılık tablosu okunamadı; mevcut dosya korunuyor.' };
  o.kaynakGuncelleme = Utilities.formatDate(DriveApp.getFileById(MALIYET_TAKIP_ID_).getLastUpdated(), 'Europe/Istanbul', 'dd.MM.yyyy HH:mm');
  DriveApp.getFileById(UYGULAMA_DOSYALARI_.maliyet_takip_2026).setContent(JSON.stringify(o));
  try { CacheService.getScriptCache().remove('dosya_maliyet_takip_2026_' + UYGULAMA_DOSYALARI_.maliyet_takip_2026 + '_n'); } catch (e) {}
  return { hayvancilik: o.hayvancilik.length, ekilis: o.tarim_ekilis.length, sut: o.sut_litre.length, karkas: o.karkas.length, canli: o.canli.length, yem: o.yem.length };
}

/** Maliyet Takip dosyası değiştiyse yeniden üretir (veri toplanırken ve günlük çalışmada çağrılır). */
function maliyetTakipGuncelle_() {
  var pr = PropertiesService.getScriptProperties(), imza = String(DriveApp.getFileById(MALIYET_TAKIP_ID_).getLastUpdated().getTime());
  if (pr.getProperty('mtUretim') === imza) return { durum: 'güncel' };
  var r = maliyetTakipUret_();
  if (!r.hata) pr.setProperty('mtUretim', imza);
  return r;
}

/** Elle çalıştırma: Maliyet Takip verisini hemen yeniden üretir ve sonucu günlüğe yazar. */
function maliyetTakipHazirla() {
  var r = maliyetTakipUret_();
  if (!r.hata) PropertiesService.getScriptProperties().setProperty('mtUretim', String(DriveApp.getFileById(MALIYET_TAKIP_ID_).getLastUpdated().getTime()));
  Logger.log('Maliyet Takip: ' + JSON.stringify(r));
}
