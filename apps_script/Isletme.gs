// Isletme.gs — İşletme günlük raporları ve haftalık rapor
// Bu proje birden çok .gs dosyasından oluşur; hepsi birlikte çalışır (Kod.gs, Kayitlar.gs, Paylasim.gs,
// Isletme.gs, Kaynaklar.gs, Muhasebe.gs, Envanter.gs, TarlaPaneli.gs).

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
  var v = sh.getRange(1, 1, bitis, Math.max(sh.getLastColumn(), 33)).getValues();
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
