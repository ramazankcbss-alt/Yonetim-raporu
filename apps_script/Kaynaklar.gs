// Kaynaklar.gs — Mali raporlar, veri kalitesi, sürü, stok, gelen dosyalar, ESK kaynakları, araç masrafları, ESK ek kaynaklar, geçmiş yıllar, hasat durumu
// Bu proje birden çok .gs dosyasından oluşur; hepsi birlikte çalışır (Kod.gs, Kayitlar.gs, Paylasim.gs,
// Isletme.gs, Kaynaklar.gs, Muhasebe.gs, Envanter.gs, TarlaPaneli.gs).

// ---------------------------------------------------------------------------
// MALİ RAPORLAR: "Mali Raporlar" klasöründeki fatura dosyalarından hazırlanan
// özet (mali_veri.json). Fatura, açık bakiye ve kontrol satırları; şahıs
// tedarikçi adları, fatura numaraları, plaka ve personel ücret ayrıntısı yoktur.
var MALI_KLASOR_ID = '1vd-AFH6KXpqdFKMDCk9Of1PcrUIgpA6b';  // 05 – Mali Raporlar

/** En yeni mali_veri.json: önce Mali Raporlar klasörü, klasör taşınmış/silinmişse Drive genelinde ada göre. */
function maliDosyasi_() {
  var en = null;
  function bak(it) {
    while (it.hasNext()) {
      var f = it.next();
      if (f.getName().indexOf('mali_veri.json') !== 0 || f.isTrashed()) continue;
      if (!en || f.getLastUpdated() > en.getLastUpdated()) en = f;
    }
  }
  try { bak(DriveApp.getFolderById(MALI_KLASOR_ID).getFiles()); } catch (e) {}
  if (!en) { try { bak(DriveApp.getFilesByName('mali_veri.json')); } catch (e) {} }
  return en;
}

function maliVeri_() {
  try {
    var en = maliDosyasi_();
    return en ? JSON.parse(en.getBlob().getDataAsString('UTF-8')) : null;
  } catch (err) {
    return null;
  }
}



// ---------------------------------------------------------------------------
// VERİ KALİTESİ: kaynak dosyaların ve uygulamadaki kopyaların son değişiklik tarihleri.
// Yalnızca dosya tarihi okunur; içerik okunmaz, kişisel veri yoktur.
var VERI_KAYNAKLARI_ = [
  { ad: 'Çiftlik Raporları (muhasebe)', kaynak: ['1FniioMusJmKiQIjnt-JZjUtrLisNyGiN'], kopya: 'ciftlik_rapor_2026' },
  { ad: 'Maliyet Takip', kaynak: ['1Yj2GfYBZBK7HqDqb-iGG2dlsBnWFUcMWHWyLwF4pEaM'], kopya: 'maliyet_takip_2026' },
  { ad: 'Aylık gelir satış ve gider tabloları', kaynak: ['1SZdjPUrz3_1aHcWn5xBQJSpMeqBntKMw', '1_68Qn8esEbBH2LnTAfUCtP_V1OsXe1Ci'], kopya: 'mali' },
  { ad: 'Stok sayımları', kaynak: [], ara: "title contains 'Stok Sayımları' and trashed = false" },
  { ad: 'Sürü hareketleri', kaynak: ['1yp23PwaA_kFXMapnLQGZfcVhjzcTTbujSUJS3m77y48'] },
  { ad: 'Tarımsal Faaliyet', kaynak: ['1jeeLe8VF06l_a_JdcS1eF8n8yDGsgEPlIcjO4Y5T7u8'] },
  { ad: 'Araç masrafları (muhasebe)', kaynak: [], ara: "title contains 'ARAÇ MASRAFLARI' and trashed = false" },
  { ad: 'Pancar teslimatı (TarKop)', kaynak: [], ara: "title contains 'TarKop' and trashed = false" },
  { ad: 'ESK bakım hizmet tablosu', kaynak: ['1Es9f4xiwQaarxb7Rkup2gkbBszrAO4RLMFGWCG4pNOA'] },
  { ad: 'ESK ithal dana partileri', kaynak: ['1atuPz1wqi42bUzeCzcgZanEtxmRQYdmrIFC9HLsfTOU'] },
  { ad: 'ESK gelen yemler', kaynak: ['1d7Zvj6SoRKXN71q_bDqF6zVqBG2ehsvSL9yAf8f10WA'] },
  { ad: 'ESK kesim / ölüm listeleri', kaynak: [], ara: "title contains 'İTHAL ÖLÜM' and trashed = false" },
  { ad: 'ESK kasaplık listesi', kaynak: [], ara: "title contains 'KASAPLIK HAYVAN' and trashed = false" },
  { ad: 'ESK balya ve gübre', kaynak: ['1y_ya5m5KwXYAHbXSQQDAiRCQ5OMPYGrXSEV2Ezxhsu0', '1_wwlYHdnP3MywO-0bj_TX-lf7C3QIAyuo41B-DUNANg'] },
  { ad: 'ESK gelir tablosu çalışması', kaynak: ['142BCrHnPYp-eKP49dDaWAjnzN6J3n5TIBsQJZCNTCe0'] },
  { ad: 'Çiftlik Raporları (E-Tablo kopyası)', kaynak: [], ara: "title contains 'Çiftlik Raporları' and mimeType = 'application/vnd.google-apps.spreadsheet' and trashed = false" },
  { ad: 'Kesim özeti 2021–2026', kaynak: ['14rJ4Lr5SGqlY7yqJNfX0ckQinI1sPfi46Uc5uU9pHns'] },
  { ad: 'Değerlendirme raporu 31.12.2025', kaynak: ['1sFGE9-t-rf-uu2RuEdPfP2flA-yJDyBtSDJjG3KSI_s'] }
];

function veriKalitesi_() {
  return onbellekli_('veriKalitesi_v2', 600, function () {
    function tarih(d) { return d ? Utilities.formatDate(d, 'Europe/Istanbul', "yyyy-MM-dd'T'HH:mm:ss") : ''; }
    function dosya(id) { try { return DriveApp.getFileById(id).getLastUpdated(); } catch (e) { return null; } }
    function maliKopya() { var f = maliDosyasi_(); return f ? f.getLastUpdated() : null; }
    return VERI_KAYNAKLARI_.map(function (k) {
      var son = null;
      k.kaynak.forEach(function (id) { var d = dosya(id); if (d && (!son || d > son)) son = d; });
      if (k.ara) {
        try {
          var it = DriveApp.searchFiles(k.ara);
          while (it.hasNext()) { var d2 = it.next().getLastUpdated(); if (!son || d2 > son) son = d2; }
        } catch (e) {}
      }
      var kopya = !k.kopya ? null : k.kopya === 'mali' ? maliKopya() : dosya(UYGULAMA_DOSYALARI_[k.kopya]);
      return { ad: k.ad, kaynak: tarih(son), kopya: tarih(kopya), canli: !k.kopya };
    });
  });
}


// ---------------------------------------------------------------------------
// SÜRÜ HAREKETLERİ: "SÜRÜ HAREKETLERİ" dosyasının bütün yıl sayfaları.
// Çiftlik başlığı + kalem satırları (tüm sürü, sağmal, doğum, kesim, ölüm, nakil…) × 12 ay. Yalnızca sayı.
var SURU_HAREKETLERI_ID = '1yp23PwaA_kFXMapnLQGZfcVhjzcTTbujSUJS3m77y48';

function suruHareketleriOku_() {
  return onbellekli_('suruHareketleri_v2', 1800, function () {
    // Bütün yıl sayfaları (2020–…) okunur.
    var ss = SpreadsheetApp.openById(SURU_HAREKETLERI_ID), sayfalar = {};
    ss.getSheets().forEach(function (sh) {
      var y = sh.getName().trim();
      if (!/^20\d\d$/.test(y)) return;
      var n = sh.getLastRow();
      if (n < 3) return;
      sayfalar[y] = sh.getRange(1, 1, n, Math.max(sh.getLastColumn(), 14)).getValues().map(function (r) {
        return r.map(function (x) { return x instanceof Date ? '' : x; });
      });
    });
    return { dosya: ss.getName(), guncelleme: Utilities.formatDate(DriveApp.getFileById(SURU_HAREKETLERI_ID).getLastUpdated(), 'Europe/Istanbul', "yyyy-MM-dd'T'HH:mm:ss"), sayfalar: sayfalar };
  });
}

// ---------------------------------------------------------------------------
// STOK SAYIMI: adında "Stok Sayımları" geçen en yeni tablo; üretim yeri sayfaları (1604, 1605, …).
// KVKK: yalnızca başlıklı sütunlar okunur (ÜY, DY, malzeme kodu ve adı, birim, stok, sayım, tüketim);
// başlıklardan sonra gelen açıklama sütunları (kişi adı içerebilir) okunmaz.
var STOK_BASLIKLARI_ = ['ÜY', 'DY', 'MALZ KOD', 'MALZ', 'ÖB', 'STOK', 'SAYIM', 'ANAÇ TÜKETİM', 'GENÇ TÜKETİM'];

function stokSayimiOku_() {
  return onbellekli_('stokSayimi_v1', 1800, function () {
    var it = DriveApp.searchFiles("title contains 'Stok Sayımları' and mimeType = 'application/vnd.google-apps.spreadsheet' and trashed = false");
    var en = null;
    while (it.hasNext()) {
      var f = it.next();
      if (!en || f.getLastUpdated() > en.getLastUpdated()) en = f;
    }
    if (!en) return null;
    var ss = SpreadsheetApp.openById(en.getId()), sayfalar = {};
    ss.getSheets().forEach(function (sh) {
      var ad = sh.getName();
      if (!/^16\d\d$/.test(ad) || sh.getLastRow() < 2) return;
      var lc = sh.getLastColumn();
      var baslik = sh.getRange(1, 1, 1, lc).getValues()[0].map(function (x) { return String(x).trim().toLocaleUpperCase('tr'); });
      var son = -1;
      baslik.forEach(function (b, i) { if (STOK_BASLIKLARI_.indexOf(b) >= 0) son = i; });
      if (son < 0) return;
      var n = sh.getLastRow();
      sayfalar[ad] = sh.getRange(1, 1, n, son + 1).getValues().map(function (r) {
        return r.map(function (x) { return x instanceof Date ? '' : x; });
      });
    });
    return { dosya: en.getName(), guncelleme: Utilities.formatDate(en.getLastUpdated(), 'Europe/Istanbul', "yyyy-MM-dd'T'HH:mm:ss"), sayfalar: sayfalar };
  });
}


// ---------------------------------------------------------------------------
// GELEN DOSYALAR: uygulamaya bağlanacak yeni dosyalar bu klasöre (dosya ya da kısayol olarak) konur.
// Klasörün doğrudan içindekiler "işlenmeyi bekleyen" sayılır; işlenen dosyalar "İşlenenler" alt klasörüne taşınır.
// Yalnızca ad, tür ve tarih okunur; içerik okunmaz.
var GELEN_DOSYALAR_KLASOR_ID = '1hiu45DOKB8rvzAWmqeWWyJ0DVGTwtrqH';

function gelenDosyalar_() {
  return onbellekli_('gelenDosyalar_v1', 600, function () {
    var it = DriveApp.getFolderById(GELEN_DOSYALAR_KLASOR_ID).getFiles(), out = [];
    function t(d) { return d ? Utilities.formatDate(d, 'Europe/Istanbul', "yyyy-MM-dd'T'HH:mm:ss") : ''; }
    while (it.hasNext()) {
      var f = it.next(), ad = f.getName(), tur = f.getMimeType(), guncelleme = f.getLastUpdated();
      if (tur === 'application/vnd.google-apps.shortcut') {
        try {
          var h = DriveApp.getFileById(f.getTargetId());
          ad = h.getName(); tur = h.getMimeType(); guncelleme = h.getLastUpdated();
        } catch (e) { tur = 'kısayol (erişim yok)'; }
      }
      out.push({ ad: ad, tur: String(tur).split('.').pop().split('/').pop(), eklenme: t(f.getDateCreated()), guncelleme: t(guncelleme) });
    }
    return out.sort(function (a, b) { return a.eklenme < b.eklenme ? 1 : -1; });
  });
}


// ---------------------------------------------------------------------------
// ESK KAYNAK DOSYALARI (Taşağıl): bakım hizmet alım tablosu (aylık), ithal dana parti listesi, gelen yemler.
// KVKK: yem dosyasından yalnızca tarih, ürün ve Taşağıl tonajı okunur; plaka, şoför, kartela ve irsaliye no okunmaz.
var ESK_KAYNAK_ = {
  maliyet: '1Es9f4xiwQaarxb7Rkup2gkbBszrAO4RLMFGWCG4pNOA',
  parti: '1atuPz1wqi42bUzeCzcgZanEtxmRQYdmrIFC9HLsfTOU',
  yem: '1d7Zvj6SoRKXN71q_bDqF6zVqBG2ehsvSL9yAf8f10WA'
};
var ESK_AYLAR_ = ['OCAK', 'ŞUBAT', 'MART', 'NİSAN', 'MAYIS', 'HAZİRAN', 'TEMMUZ', 'AĞUSTOS', 'EYLÜL', 'EKİM', 'KASIM', 'ARALIK'];

function eskTrSayi_(v) {
  if (typeof v === 'number') return v;
  var s = String(v == null ? '' : v).replace(/[₺\s]/g, '');
  if (!s) return null;
  s = s.replace(/\./g, '').replace(',', '.');
  var n = Number(s);
  return isNaN(n) ? null : n;
}

/** {aylar:[{yil, ay, gelen, birimFiyat, kesilen, sehirKesim, olen, basGun, bakimGideri}], partiler:[...], yem:[{yil, ay, urun, kg}]} */
function eskKaynak_() {
  return onbellekli_('eskKaynak_v1', 1800, function () {
    var o = { aylar: [], partiler: [], yem: [] };
    try {
      SpreadsheetApp.openById(ESK_KAYNAK_.maliyet).getSheets().forEach(function (sh) {
        var m = sh.getName().trim().match(/^(\S+)\s+(\d{4})$/);
        if (!m) return;
        var ay = ESK_AYLAR_.indexOf(m[1].toLocaleUpperCase('tr')) + 1;
        if (!ay) return;
        var d = sh.getDataRange().getDisplayValues();
        var bas = -1;
        for (var i = 0; i < Math.min(d.length, 40); i++) if (String(d[i][0]).trim() === 'GÜN') { bas = i; break; }
        if (bas < 0) return;
        var h = d[bas].map(function (x) { return String(x).toLocaleUpperCase('tr'); });
        var top = null;
        for (var j = bas + 1; j < d.length; j++) if (/GENEL TOPLAM/.test(String(d[j][0]))) { top = d[j]; break; }
        if (!top) return;
        var r = { yil: Number(m[2]), ay: ay, gelen: eskTrSayi_(d[1] && d[1][1]), birimFiyat: null,
          kesilen: 0, sehirKesim: 0, olen: 0, basGun: null, bakimGideri: null };
        (d[1] || []).forEach(function (x) { var n = eskTrSayi_(x); if (/₺/.test(String(x)) && n) r.birimFiyat = n; });
        h.forEach(function (b, k) {
          var n = eskTrSayi_(top[k]) || 0;
          if (/ÖLEN/.test(b)) r.olen += n;
          else if (/KESİLEN/.test(b) && /PANAGRO/.test(b)) r.kesilen += n;
          else if (/KESİLEN/.test(b)) r.sehirKesim += n;
          else if (/AHIRDA KALAN/.test(b)) r.basGun = n;
          else if (/BAKIM GİDERİ/.test(b)) r.bakimGideri = n;
        });
        o.aylar.push(r);
      });
      o.aylar.sort(function (a, b) { return a.yil * 12 + a.ay - (b.yil * 12 + b.ay); });
    } catch (e) { o.maliyetHata = String(e); }
    try {
      var p = SpreadsheetApp.openById(ESK_KAYNAK_.parti).getSheets()[0].getDataRange().getDisplayValues();
      var ph = (p[1] || []).map(function (x) { return String(x).toLocaleUpperCase('tr'); });
      function s(ad) { for (var k = 0; k < ph.length; k++) if (ph[k].indexOf(ad) >= 0) return k; return -1; }
      var cT = s('TARİH'), cC = s('TAŞAĞIL'), cL = s('ESK LİMAN'), cO = s('ÖLEN');
      for (var i = 2; i < p.length; i++) {
        if (!/PART/i.test(String(p[i][0]))) continue;
        o.partiler.push({ parti: String(p[i][0]).trim(), gelis: cT >= 0 ? String(p[i][cT]).trim() : '',
          ciftlik: eskTrSayi_(p[i][cC]), liman: cL >= 0 ? eskTrSayi_(p[i][cL]) : null, nakliyeOlen: cO >= 0 ? eskTrSayi_(p[i][cO]) : null });
      }
    } catch (e) { o.partiHata = String(e); }
    try {
      var top2 = {};
      SpreadsheetApp.openById(ESK_KAYNAK_.yem).getSheets().forEach(function (sh) {
        var y = sh.getDataRange().getDisplayValues();
        if (!y.length) return;
        var yh = y[0].map(function (x) { return String(x).toLocaleUpperCase('tr').trim(); });
        var cT = yh.indexOf('TARİH'), cU = yh.indexOf('ÜRÜN'), cK = -1;
        yh.forEach(function (b, k) { if (cK < 0 && /TAŞAĞIL\s+TONAJ/.test(b)) cK = k; });
        if (cT < 0 || cU < 0 || cK < 0) return;
        for (var i = 1; i < y.length; i++) {
          var t = String(y[i][cT]).match(/(\d{1,2})\.(\d{1,2})\.(\d{4})/), kg = eskTrSayi_(y[i][cK]), u = String(y[i][cU]).trim();
          if (!t || !kg || !u) continue;
          var k2 = t[3] + '|' + Number(t[2]) + '|' + u;
          top2[k2] = (top2[k2] || 0) + kg;
        }
      });
      Object.keys(top2).sort().forEach(function (k) {
        var a = k.split('|');
        o.yem.push({ yil: Number(a[0]), ay: Number(a[1]), urun: a[2], kg: top2[k] });
      });
    } catch (e) { o.yemHata = String(e); }
    return o;
  });
}

// ---------------------------------------------------------------------------
// ARAÇ MASRAFLARI: muhasebenin "ÇİFTLİKLER ARAÇ MASRAFLARI <yıl>.xlsx" dosyası doğrudan okunur (en yeni dosya).
// KVKK: plaka/araç kodu yalnızca aracı iş alanıyla eşleştirmek için bellekte kullanılır, çıktıya yazılmaz;
// satıcı adı ve numarası, belge numarası ve açıklama metni okunmaz.
function excelTarih_(n) { return new Date(Date.UTC(1899, 11, 30) + Math.round(n) * 864e5); }

/** sayfalar: xlsxSatirlari_ çıktısı. */
function aracMasrafCoz_(sayfalar) {
  var genel = null, detay = null;
  sayfalar.forEach(function (s) {
    for (var i = 0; i < Math.min(s.length, 40); i++) {
      var a = String(s[i].A || '').trim().toLocaleUpperCase('tr');
      if (!genel && a === 'PLAKA') genel = { s: s, h: i };
      if (!detay && a === 'ANA HESAP') detay = { s: s, h: i };
    }
  });
  if (!genel) return null;
  var ustSatir = genel.s[genel.h - 1] || {}, aylar = [], topSut = null;
  Object.keys(ustSatir).forEach(function (k) {
    var v = ustSatir[k];
    if (typeof v === 'number' && v > 40000) {
      var d = excelTarih_(v);
      aylar.push({ k: k, ay: d.getUTCFullYear() + '-' + ('0' + (d.getUTCMonth() + 1)).slice(-2) });
    } else if (String(v).trim().toLocaleUpperCase('tr') === 'TOPLAM') topSut = k;
  });
  var araclar = [], genelToplam = null;
  for (var i = genel.h + 1; i < genel.s.length; i++) {
    var r = genel.s[i], kod = String(r.A || '').trim(), ad = String(r.B || '').trim();
    if (/GENEL TOPLAM/i.test(kod + ' ' + ad)) { if (topSut && typeof r[topSut] === 'number') genelToplam = r[topSut]; continue; }
    if (!kod && !ad) continue;
    var aylik = {}, top = 0;
    aylar.forEach(function (a) { var v = r[a.k]; if (typeof v === 'number' && v) { aylik[a.ay] = Math.round(v * 100) / 100; top += v; } });
    var t = topSut && typeof r[topSut] === 'number' ? r[topSut] : top;
    if (!t) continue;
    araclar.push({ kod: kod, arac: ad || 'Adı yazılmamış araç', aylik: aylik, toplam: Math.round(t * 100) / 100 });
  }
  // Aracın iş alanı: detay satırlarında araç koduyla geçen iş alanlarının çoğunluğu.
  var oy = {};
  if (detay) {
    // Detay sayfası ay ay bloklar hâlinde; her blokta başlık yeniden yazılır (sütun yerleri değişebilir).
    var cK = null, cU = null, cM = null;
    for (var j = detay.h; j < detay.s.length; j++) {
      var r2 = detay.s[j];
      if (String(r2.A || '').trim().toLocaleUpperCase('tr') === 'ANA HESAP') {
        cK = null; cU = null; cM = null;
        Object.keys(r2).forEach(function (k) {
          var b = String(r2[k]).trim().toLocaleUpperCase('tr');
          if (b === 'SİPARİŞ') cK = k; else if (b === 'İŞ ALANI') cU = k; else if (b === 'MASRAF YERİ' && !cM) cM = k;
        });
        continue;
      }
      if (!cK || (!cU && !cM)) continue;
      var kd = String(r2[cK] || '').trim(), u = cU ? String(r2[cU] || '').trim() : '';
      if (!/^16\d\d$/.test(u) && cM) u = String(r2[cM] || '').trim().slice(0, 4);  // masraf yeri 1613010001 → 1613
      if (!kd || !/^16\d\d$/.test(u)) continue;
      var o = oy[kd] || (oy[kd] = {}); o[u] = (o[u] || 0) + 1;
    }
  }
  var uy = {};
  araclar.forEach(function (a) {
    var o = oy[a.kod] || {}, en = '';
    Object.keys(o).forEach(function (x) { if (!en || o[x] > o[en]) en = x; });
    a.uy = en;
    delete a.kod; // plaka içerir; çıktıya yazılmaz
  });
  aylar.sort(function (a, b) { return a.ay < b.ay ? -1 : 1; });
  var ilk = aylar.length ? aylar[0].ay.split('-') : null, son = aylar.length ? aylar[aylar.length - 1].ay.split('-') : null;
  var dolu = aylar.filter(function (a) { return araclar.some(function (x) { return x.aylik[a.ay]; }); });
  var sonDolu = dolu.length ? dolu[dolu.length - 1].ay.split('-') : son;
  return {
    kaynak: 'ÇİFTLİKLER ARAÇ MASRAFLARI',
    donem: ilk ? ilk[1] + '.' + ilk[0] + '–' + sonDolu[1] + '.' + sonDolu[0] : '',
    araclar: araclar,
    kontrol: { genel_toplam: genelToplam, araclar_toplami: Math.round(araclar.reduce(function (t, a) { return t + a.toplam; }, 0) * 100) / 100 }
  };
}

function aracMasrafOku_() {
  return onbellekli_('aracMasraf_v1', 1800, function () {
    var it = DriveApp.searchFiles("title contains 'ARAÇ MASRAFLARI' and trashed = false"), en = null;
    while (it.hasNext()) {
      var f = it.next();
      if (!/\.xlsx$/i.test(f.getName())) continue;
      if (!en || f.getLastUpdated() > en.getLastUpdated()) en = f;
    }
    if (!en) return null;
    var o = aracMasrafCoz_(xlsxSatirlari_(en.getBlob()));
    if (o) { o.dosya = en.getName(); o.guncelleme = Utilities.formatDate(en.getLastUpdated(), 'Europe/Istanbul', "yyyy-MM-dd'T'HH:mm:ss"); }
    return o;
  });
}


// ---------------------------------------------------------------------------
// ESK EK KAYNAKLAR (Taşağıl): aylık ithal kesim/ölüm listeleri, kasaplık (geliş tartım) partileri, gelen balya,
// gübre çıkışı, kesim nakliyesi ve ESK gelir tablosu çalışması. Yalnızca toplamlar döner.
// KVKK: plaka, şoför, kartela/bilet no, kulak küpesi ve açıklama sütunları okunmaz.
var ESK_EK_ = {
  balya: '1y_ya5m5KwXYAHbXSQQDAiRCQ5OMPYGrXSEV2Ezxhsu0',
  gubre: '1_wwlYHdnP3MywO-0bj_TX-lf7C3QIAyuo41B-DUNANg',
  calisma: '142BCrHnPYp-eKP49dDaWAjnzN6J3n5TIBsQJZCNTCe0'
};

function eskTarih_(v) {
  var m = String(v || '').match(/(\d{1,2})[.\/](\d{1,2})[.\/](\d{4})/);
  return m ? { yil: Number(m[3]), ay: Number(m[2]), gun: Number(m[1]) } : null;
}

/** Başlık satırında (ilk 5 satır) verilen ifadelere uyan sütunlar: {ad: index}. */
function eskSutunlar_(d, kurallar) {
  for (var i = 0; i < Math.min(d.length, 40); i++) {
    var h = d[i].map(function (x) { return String(x).toLocaleUpperCase('tr').replace(/\s+/g, ' ').trim(); }), o = { _bas: i }, n = 0;
    Object.keys(kurallar).forEach(function (k) {
      for (var j = 0; j < h.length; j++) if (kurallar[k].test(h[j])) { o[k] = j; n++; break; }
    });
    if (n >= 2 && o.tarih !== undefined) return o;
  }
  return null;
}


/** Ada göre e-tablolar: Drive araması + ortak sürücüdeki bilinen klasörler (arama ortak sürücüyü kapsamayabilir). */
function eskTablolar_(sorgu, klasorler, desen) {
  var gor = {}, out = [];
  function ekle(f) {
    if (gor[f.getId()] || f.getMimeType() !== MimeType.GOOGLE_SHEETS || !desen.test(f.getName())) return;
    gor[f.getId()] = 1; out.push(f);
  }
  try { var it = DriveApp.searchFiles(sorgu); while (it.hasNext()) ekle(it.next()); } catch (e) {}
  (klasorler || []).forEach(function (id) {
    try { var it2 = DriveApp.getFolderById(id).getFiles(); while (it2.hasNext()) ekle(it2.next()); } catch (e) {}
  });
  return out;
}

function eskEk_() {
  return onbellekli_('eskEk_v1', 1800, function () {
    var o = { kesim: [], olum: [], kasaplik: [], balya: [], gubre: [], nakliye: [], gelir: [], hatalar: [] };
    function hata(ad, e) { o.hatalar.push(ad + ': ' + String(e)); }
    function topla(m, k, v) { m[k] = (m[k] || 0) + v; }

    // 1) Aylık ithal kesim / ölüm listeleri ("TAŞAĞIL-ESK İTHAL ÖLÜM / KESİM <AY> <YIL>")
    try {
      var kes = {}, olu = {};
      eskTablolar_("title contains 'İTHAL ÖLÜM' and trashed = false",
          ['1yCcs1qxL2IpueOvtAAo-DNrDAnt3nPzg', '1XlmipOR_EVEUSFM5iRjLm5MyqUK5rN9u', '0AP3nZiFWLpVHUk9PVA'], /İTHAL ÖLÜM/i).forEach(function (dosya) {
        var ss = SpreadsheetApp.open(dosya);
        var sk = ss.getSheetByName('KESİM'), so = ss.getSheetByName('ÖLÜM');
        if (sk) {
          var d = sk.getDataRange().getDisplayValues();
          var c = eskSutunlar_(d, { tarih: /^TARİH$/, adet: /KESİLEN HAYVAN/, neden: /KESİM NEDENİ/, kg: /^CANLI AĞIRLIK$/, yer: /KESİM YERİ/ });
          if (c) for (var i = c._bas + 1; i < d.length; i++) {
            var t = eskTarih_(d[i][c.tarih]), a = eskTrSayi_(d[i][c.adet]);
            if (!t || !a) continue;
            var k = t.yil + '-' + t.ay, x = kes[k] || (kes[k] = { yil: t.yil, ay: t.ay, adet: 0, kg: 0, kgAdet: 0, supheli: 0, neden: {}, yer: {} });
            x.adet += a;
            var kg = c.kg !== undefined ? eskTrSayi_(d[i][c.kg]) : null;
            if (kg && kg / a >= 150 && kg / a <= 900) { x.kg += kg; x.kgAdet += a; } else if (kg) x.supheli++;
            topla(x.neden, String(d[i][c.neden] || 'Belirtilmemiş').trim() || 'Belirtilmemiş', a);
            if (c.yer !== undefined) topla(x.yer, String(d[i][c.yer] || 'Belirtilmemiş').trim() || 'Belirtilmemiş', a);
          }
        }
        if (so) {
          var d2 = so.getDataRange().getDisplayValues();
          var c2 = eskSutunlar_(d2, { tarih: /^TARİH$/, neden: /ÖLÜM NEDENİ/, maliyet: /MALİYET/ });
          if (c2) for (var j = c2._bas + 1; j < d2.length; j++) {
            var t2 = eskTarih_(d2[j][c2.tarih]);
            if (!t2) continue;
            var k2 = t2.yil + '-' + t2.ay, y = olu[k2] || (olu[k2] = { yil: t2.yil, ay: t2.ay, adet: 0, maliyete: 0, neden: {} });
            y.adet++;
            if (c2.maliyet !== undefined && /YANSIT/i.test(d2[j][c2.maliyet])) y.maliyete++;
            topla(y.neden, String(d2[j][c2.neden] || 'Belirtilmemiş').trim() || 'Belirtilmemiş', 1);
          }
        }
      });
      o.kesim = Object.keys(kes).map(function (k) { return kes[k]; });
      o.olum = Object.keys(olu).map(function (k) { return olu[k]; });
    } catch (e) { hata('İthal kesim/ölüm', e); }

    // 2) Kasaplık hayvan listeleri: parti başına çiftlik kantarı net, adet, liman adet ve ağırlık
    try {
      eskTablolar_("title contains 'KASAPLIK HAYVAN' and trashed = false", ['12iVwe-Ic5bzU9ha87AkgZgkUej71VgvC'], /KASAPLIK/i)
        .forEach(function (dosya) { SpreadsheetApp.open(dosya).getSheets().forEach(function (sh) {
          var pm = sh.getName().match(/(\d+)\s*\.?\s*PART/i);
          if (!pm) return;
          var d = sh.getDataRange().getDisplayValues();
          var c = eskSutunlar_(d, { tarih: /^TARİH$/, net: /KANTAR NET/, adet: /TAŞAĞIL ADET/, ladet: /LİMAN ADET/, lkg: /LİMAN CANLI/ });
          if (!c) return;
          var p = { parti: Number(pm[1]), tarih: '', adet: 0, netKg: 0, limanAdet: 0, limanKg: 0, arac: 0 };
          for (var i = c._bas + 1; i < d.length; i++) {
            var t = eskTarih_(d[i][c.tarih]);
            if (!t) continue;  // toplam / ortalama satırları tarihsizdir
            if (!p.tarih) p.tarih = ('0' + t.gun).slice(-2) + '.' + ('0' + t.ay).slice(-2) + '.' + t.yil;
            p.arac++;
            p.adet += eskTrSayi_(d[i][c.adet]) || 0;
            p.netKg += eskTrSayi_(d[i][c.net]) || 0;
            if (c.ladet !== undefined) p.limanAdet += eskTrSayi_(d[i][c.ladet]) || 0;
            if (c.lkg !== undefined) p.limanKg += eskTrSayi_(d[i][c.lkg]) || 0;
          }
          if (p.adet) o.kasaplik.push(p);
        }); });
      o.kasaplik.sort(function (a, b) { return a.parti - b.parti; });
    } catch (e) { hata('Kasaplık listesi', e); }

    // 3) Gelen balya (mısır, yonca, sap): ay × ürün × geldiği yer, kg
    try {
      var b = {};
      SpreadsheetApp.openById(ESK_EK_.balya).getSheets().forEach(function (sh) {
        var d = sh.getDataRange().getDisplayValues();
        var c = eskSutunlar_(d, { tarih: /TARİH/, kg: /TAŞAĞIL TONAJ/, yer: /GELDİĞİ YER/, urun: /ÜRÜN ADI/ });
        if (!c) return;
        for (var i = c._bas + 1; i < d.length; i++) {
          var t = eskTarih_(d[i][c.tarih]), kg = eskTrSayi_(d[i][c.kg]);
          if (!t || !kg) continue;
          var u = String(d[i][c.urun] || '').trim() || 'Belirtilmemiş', yer = String(d[i][c.yer] || '').trim() || 'Belirtilmemiş';
          topla(b, [t.yil, t.ay, u, yer].join('|'), kg);
        }
      });
      o.balya = Object.keys(b).sort().map(function (k) { var a = k.split('|'); return { yil: +a[0], ay: +a[1], urun: a[2], yer: a[3], kg: b[k] }; });
    } catch (e) { hata('Balya', e); }

    // 4) Gübre çıkışı: ay × gittiği yer, kg (sayfalar: ahır temizliği, cüruf, biyogaz)
    try {
      var g = {};
      SpreadsheetApp.openById(ESK_EK_.gubre).getSheets().forEach(function (sh) {
        var d = sh.getDataRange().getDisplayValues();
        var c = eskSutunlar_(d, { tarih: /TARİH/, kg: /TONAJ/, gittigi: /GİTTİĞİ YER/, urun: /ÜRÜN ADI/ });
        if (!c) return;
        for (var i = c._bas + 1; i < d.length; i++) {
          var t = eskTarih_(d[i][c.tarih]), kg = eskTrSayi_(d[i][c.kg]);
          if (!t || !kg) continue;
          var yer = c.gittigi !== undefined ? String(d[i][c.gittigi] || '').trim() : '';
          topla(g, [t.yil, t.ay, yer || sh.getName(), String(d[i][c.urun] || '').trim()].join('|'), kg);
        }
      });
      o.gubre = Object.keys(g).sort().map(function (k) { var a = k.split('|'); return { yil: +a[0], ay: +a[1], yer: a[2], urun: a[3], kg: g[k] }; });
    } catch (e) { hata('Gübre', e); }

    // 5) Kesim nakliyesi ("ESK NAKLİYE <AY> <YIL>"): ay başına sefer ve taşınan hayvan
    try {
      var n = {};
      eskTablolar_("title contains 'ESK NAKLİYE' and trashed = false", [], /NAKLİYE/i).forEach(function (dosya) {
        SpreadsheetApp.open(dosya).getSheets().forEach(function (sh) {
          var d = sh.getDataRange().getDisplayValues();
          var c = eskSutunlar_(d, { tarih: /^TARİH$/, adet: /HAYVAN SAYISI/ });
          if (!c) return;
          for (var i = c._bas + 1; i < d.length; i++) {
            var t = eskTarih_(d[i][c.tarih]), a = eskTrSayi_(d[i][c.adet]);
            if (!t || !a) continue;
            var k = t.yil + '-' + t.ay, x = n[k] || (n[k] = { yil: t.yil, ay: t.ay, sefer: 0, hayvan: 0 });
            x.sefer++; x.hayvan += a;
          }
        });
      });
      o.nakliye = Object.keys(n).map(function (k) { return n[k]; });
    } catch (e) { hata('Nakliye', e); }

    // 6) ESK gelir tablosu çalışması ("Esk çalışma" › "Gelir Tablosuna Göre."): ay blokları
    try {
      var sh = SpreadsheetApp.openById(ESK_EK_.calisma).getSheetByName('Gelir Tablosuna Göre.');
      // Sayfada yıl yazmıyor: dosyanın son değişiklik tarihine göre (o aydan sonraki aylar önceki yıla aittir).
      var son = DriveApp.getFileById(ESK_EK_.calisma).getLastUpdated(), sYil = son.getFullYear(), sAy = son.getMonth() + 1;
      if (sh) {
        var d = sh.getDataRange().getDisplayValues(), AY = ESK_AYLAR_;
        for (var r = 0; r < Math.min(d.length, 40); r++) {
          d[r].forEach(function (h, col) {
            var m = String(h).toLocaleUpperCase('tr').match(/ESK\s+(\S+)\s+BAKIM/);
            if (!m) return;
            var ay = AY.indexOf(m[1]) + 1;
            if (!ay) return;
            var x = { ay: ay, yil: ay > sAy ? sYil - 1 : sYil };
            for (var j = r + 1; j < Math.min(d.length, r + 40); j++) {
              var et = String(d[j][col] || '').toLocaleUpperCase('tr'), v = eskTrSayi_(d[j][col + 1]);
              if (v === null) continue;
              if (/SAP BALYASI/.test(et)) x.sap = v;
              else if (/BAKIM BESLEME/.test(et)) x.bakim = v;
              else if (/KİRA/.test(et)) x.kira = v;
              else if (/TOPLAM SATIŞ/.test(et)) x.satis = v;
              else if (/^SMM/.test(et)) x.smm = v;
              else if (/DİĞER SATIŞLARIN/.test(et)) x.digerMaliyet = v;
              else if (/FAALİYET/.test(et)) x.faaliyet = v;
              else if (/TOPLAM GİDER/.test(et)) x.gider = v;
              else if (/KAZANÇ/.test(et)) x.kazanc = v;
            }
            if (x.satis !== undefined || x.kazanc !== undefined) o.gelir.push(x);
          });
        }
        o.gelir.sort(function (a, b) { return a.yil * 12 + a.ay - (b.yil * 12 + b.ay); });
        o.gelirDosya = 'Esk çalışma › Gelir Tablosuna Göre';
      }
    } catch (e) { hata('ESK gelir tablosu', e); }
    return o;
  });
}


// ---------------------------------------------------------------------------
// GEÇMİŞ YIL ÖZETLERİ: "2021-2026 Yılları Çiftlikler Kesim Özet" (kesim ve canlı hayvan alımı) ile
// "Çiftlikler Değerlendirme Raporu 31.12.2025" sayfalarından yıl × çiftlik göstergeleri.
// KVKK: personel dağılımı ve organizasyon şeması sayfaları okunmaz; yalnızca sayısal göstergeler.
var GECMIS_OZET_ = {
  kesim: '14rJ4Lr5SGqlY7yqJNfX0ckQinI1sPfi46Uc5uU9pHns',
  degerlendirme: '1sFGE9-t-rf-uu2RuEdPfP2flA-yJDyBtSDJjG3KSI_s',
  sayfalar: ['tarım 5yıllık kazanç', 'süt verimliliği ', 'Ölüm oranları ']
};

/** Kesim Özet › KESİMLER: yıl blokları (yıl başlığı, sütun başlıkları, çiftlik satırları, TOPLAM). */
function gecmisKesimOku_(d) {
  var kesim = [], alim = [];
  for (var i = 0; i < d.length; i++) {
    var y = String(d[i][0]).trim();
    if (!/^20\d\d$/.test(y)) continue;
    var not = String(d[i][9] || '').trim();
    for (var j = i + 2; j < d.length; j++) {
      var c = String(d[j][0]).trim();
      if (!c || /^TOPLAM/i.test(c) || /^20\d\d$/.test(c)) break;
      kesim.push({ yil: +y, ciftlik: c, erkek: eskTrSayi_(d[j][1]) || 0, erkekKarkas: eskTrSayi_(d[j][2]) || 0,
        inek: eskTrSayi_(d[j][3]) || 0, inekKarkas: eskTrSayi_(d[j][4]) || 0, duve: eskTrSayi_(d[j][5]) || 0,
        duveKarkas: eskTrSayi_(d[j][6]) || 0, adet: eskTrSayi_(d[j][7]) || 0, karkas: eskTrSayi_(d[j][8]) || 0,
        satis: eskTrSayi_(d[j][10]), donem: not });
    }
    for (var k = i + 2; k < d.length; k++) {
      var a = String(d[k][12] || '').trim();
      if (!a || /^TOPLAM/i.test(a)) { if (/^TOPLAM/i.test(a) || !String(d[k][0]).trim()) break; continue; }
      if (!String(d[k][13] || '').trim() && !String(d[k][14] || '').trim() && !String(d[k][15] || '').trim()) continue;
      alim.push({ yil: +y, ciftlik: a, ic: eskTrSayi_(d[k][13]) || 0, dis: eskTrSayi_(d[k][14]) || 0, toplam: eskTrSayi_(d[k][15]) || 0 });
    }
  }
  return { kesim: kesim, alim: alim };
}

/** Yıl × çiftlik tablosu: başlık hücrelerindeki yıla göre (yılsız sütun önceki sütunun yılını alır). */
function gecmisMatrisOku_(d, baslik) {
  var hb = -1;
  for (var i = 0; i < Math.min(d.length, 40); i++) {
    var n = d[i].filter(function (x) { return /20\d\d/.test(String(x)); }).length;
    if (n >= 2 && String(d[i][0] || '').trim() !== '' || n >= 3) { hb = i; }
    if (hb >= 0 && n >= 2 && d[i].some(function (x) { return /[A-Za-zÇĞİÖŞÜçğıöşü]{4}/.test(String(x).replace(/20\d\d/g, '')); })) { hb = i; break; }
  }
  if (hb < 0) return [];
  var h = d[hb], ust = hb > 0 ? d[hb - 1] : [], out = [], yil = null, yillar = [], olcu = [];
  for (var j = 1; j < h.length; j++) {
    var t = String(h[j] || '').replace(/\n/g, ' ').trim(), m = t.match(/20\d\d/) || String(ust[j] || '').match(/20\d\d/);
    if (m) yil = +m[0];
    yillar[j] = t ? yil : null;
    olcu[j] = t.replace(/20\d\d/g, '').replace(/%/g, '').replace(/\s+/g, ' ').trim() || null;
  }
  for (var r = hb + 1; r < d.length; r++) {
    var c = String(d[r][0] || '').trim();
    if (!c) {
      // Tablo bitti: sayfanın kalanında başka yıl tablosu varsa o da okunur (sınır yok).
      if (out.length) return out.concat(r + 1 < d.length ? gecmisMatrisOku_(d.slice(r + 1), baslik) : []);
      continue;
    }
    for (var j2 = 1; j2 < h.length; j2++) {
      if (!yillar[j2] || !olcu[j2] || /TOPLAM/i.test(olcu[j2])) continue;
      var v = eskTrSayi_(String(d[r][j2]).replace('%', ''));
      if (v === null) continue;
      var alan = /ALAN/i.test(c);  // "EKİM ALANI" satırı ayrı bir göstergedir
      out.push({ tablo: baslik, ciftlik: alan || /TOPLAM/i.test(c) ? 'Toplam' : c, yil: yillar[j2],
        olcu: alan ? 'Ekim alanı (da)' : olcu[j2], deger: v, yuzde: /%/.test(String(d[r][j2])) });
    }
  }
  return out;
}

/** Oran tutarlılığı: "<X> Oranı" yüzdesi, aynı satırdaki "<X> sayısı" ile hayvan sayısından yeniden hesaplanır.
 *  [{tablo, ciftlik, yil, olcu, yazilan, hesaplanan}] — fark 0,5 puandan büyükse ya da oran %100'ü aşıyorsa. */
function gecmisKontrol_(gl) {
  var g = {}, out = [];
  gl.forEach(function (x) { var k = x.tablo + '|' + x.ciftlik + '|' + x.yil; (g[k] = g[k] || []).push(x); });
  Object.keys(g).forEach(function (k) {
    var l = g[k];
    l.filter(function (x) { return x.yuzde && /Oran/i.test(x.olcu); }).forEach(function (o) {
      var kok = o.olcu.replace(/\s*Oran[ıi]?.*$/i, '').trim().toLocaleLowerCase('tr');
      if (!kok) return;
      var pay = l.find(function (x) { return !x.yuzde && x.olcu.toLocaleLowerCase('tr').indexOf(kok) === 0 && /say/i.test(x.olcu); });
      var payda = l.find(function (x) { return !x.yuzde && x !== pay && /say/i.test(x.olcu) && x.olcu.toLocaleLowerCase('tr').indexOf(kok) !== 0; });
      if (!pay || !payda || !payda.deger) return;
      var h = Math.round(pay.deger / payda.deger * 1000) / 10;
      if (Math.abs(h - o.deger) > 0.5 || o.deger > 100) out.push({ tablo: o.tablo, ciftlik: o.ciftlik, yil: o.yil, olcu: o.olcu, yazilan: o.deger, hesaplanan: h,
        pay: pay.olcu + ' ' + pay.deger, payda: payda.olcu + ' ' + payda.deger });
    });
  });
  return out;
}

function gecmisOzet_() {
  return onbellekli_('gecmisOzet_v2', 21600, function () {
    var o = { kesim: [], alim: [], gostergeler: [], hatalar: [] };
    try {
      var sh = SpreadsheetApp.openById(GECMIS_OZET_.kesim).getSheetByName('KESİMLER');
      var k = gecmisKesimOku_(sh.getDataRange().getDisplayValues());
      o.kesim = k.kesim; o.alim = k.alim;
    } catch (e) { o.hatalar.push('Kesim özet: ' + e); }
    try {
      var ss = SpreadsheetApp.openById(GECMIS_OZET_.degerlendirme);
      // Değerlendirme raporunun bütün sayfaları (KVKK sayfaları hariç); yıl sütunlu tablolar gösterge olarak okunur.
      ss.getSheets().forEach(function (s) {
        var ad = s.getName();
        if (KVKK_SAYFA_.test(ad) || !s.getLastRow()) return;
        o.gostergeler = o.gostergeler.concat(gecmisMatrisOku_(s.getDataRange().getDisplayValues(), ad.trim()));
      });
      o.kontroller = gecmisKontrol_(o.gostergeler);
    } catch (e) { o.hatalar.push('Değerlendirme raporu: ' + e); }
    return o;
  });
}


// ---------------------------------------------------------------------------
// HASAT DURUMU: hasadı / teslimatı tamamlanan ürünler. Sayfa: "Hasat Durumu" (Sezon, Ürün, Durum, Tarih).
// Ürün "Tümü" ise o sezonun bütün ürünleri tamamlanmış sayılır. Kişisel veri içermez.
var HASAT_SAYFASI_ = 'Hasat Durumu';

function hasatSayfasi_() {
  var ss = SpreadsheetApp.getActiveSpreadsheet(), sh = ss.getSheetByName(HASAT_SAYFASI_);
  if (!sh) { sh = ss.insertSheet(HASAT_SAYFASI_); sh.getRange(1, 1, 1, 4).setValues([['Sezon', 'Ürün', 'Durum', 'Tarih']]); }
  return sh;
}

function hasatDurumuOku_() {
  var sh = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(HASAT_SAYFASI_);
  if (!sh || sh.getLastRow() < 2) return [];
  return sh.getRange(2, 1, sh.getLastRow() - 1, 4).getDisplayValues()
    .filter(function (r) { return r[0] && r[1]; })
    .map(function (r) { return { sezon: Number(r[0]), urun: String(r[1]).trim(), tamam: /tamam/i.test(r[2]), tarih: String(r[3] || '') }; });
}

function hasatDurumuKaydet_(g) {
  var sezon = Number(g.sezon), urun = String(g.urun || '').trim(), tamam = String(g.tamam) === 'true';
  if (!sezon || !urun) return { ok: false, hata: 'Sezon ve ürün gerekli.' };
  var sh = hasatSayfasi_(), son = sh.getLastRow();
  var v = son > 1 ? sh.getRange(2, 1, son - 1, 2).getDisplayValues() : [], satir = -1;
  for (var i = 0; i < v.length; i++) if (Number(v[i][0]) === sezon && String(v[i][1]).trim() === urun) { satir = i + 2; break; }
  var deger = [[sezon, urun, tamam ? 'Tamamlandı' : 'Devam ediyor', Utilities.formatDate(new Date(), 'Europe/Istanbul', 'dd.MM.yyyy')]];
  if (satir > 0) sh.getRange(satir, 1, 1, 4).setValues(deger); else sh.appendRow(deger[0]);
  return { ok: true, mesaj: urun + (tamam ? ': hasat tamamlandı olarak işaretlendi.' : ': hasat devam ediyor olarak işaretlendi.') };
}
