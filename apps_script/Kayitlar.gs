// Kayitlar.gs — Kişiler, formen bildirim formu, bakım onarım kayıtları, ürün takibi
// Bu proje birden çok .gs dosyasından oluşur; hepsi birlikte çalışır (Kod.gs, Kayitlar.gs, Paylasim.gs,
// Isletme.gs, Kaynaklar.gs, Muhasebe.gs, Envanter.gs, TarlaPaneli.gs).

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
    var v = sh.getRange(1, 1, sh.getLastRow(), 13).getValues().map(function (r) {
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
  var out = [], CIFT = /(ASLIM|ŞEKER\s*SÜT|ŞEKERSÜT|FETHİYE|TAŞAĞIL|ORMANLIK|FİDANLIK)/;
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

  var adCiftlik = (/(ASLIM|ŞEKER\s*SÜT|ŞEKERSÜT|FETHİYE|TAŞAĞIL|ORMANLIK|FİDANLIK)/i.exec(ana.getName()) || [])[1];
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
  var v = sh.getRange(1, 1, sh.getLastRow(), Math.max(sh.getLastColumn(), 22)).getDisplayValues();
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
  return onbellekli_('teslimat_v3', 600, function () {
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
    var v = sh.getRange(1, 1, sh.getLastRow(), Math.max(sh.getLastColumn(), 27)).getDisplayValues();
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
    var v = sh.getRange(1, 1, sh.getLastRow(), 6).getDisplayValues();
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
