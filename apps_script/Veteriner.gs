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
  return HtmlService.createHtmlOutputFromFile('Veteriner')
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
    kayip: kayip,
    hastalik: HASTALIK_ARSIV,
    hastalikEk: ek,
    bildirimler: vetBildirimleri_(k.kod)
  };
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
