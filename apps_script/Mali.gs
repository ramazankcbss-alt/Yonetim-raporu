// Mali.gs — Mali Raporlar: muhasebenin "2026 Fatura" listesi (aylık gider tablosu) ve aylık gelir satış tablosu
// sunucuda, dosya değiştikçe otomatik ve tam okunur; mali_veri.json üretilir (Mali Raporlar klasörü).
// Daha önce çevrimdışı üretiliyordu (araclar/mali/mali_muhasebe.py + gelir_gider.py); kurallar aynen taşındı.
// Karar (26.11.2026): Mali Raporlar yalnızca muhasebe listesinden beslenir; birim gelen fatura raporu okunmaz.
// KVKK: "Kullanıcı adı" sütunu okunmaz; şahıs / teyitsiz tedarikçi adları ve onların fatura numaraları
// çıktıya yazılmaz; kalem açıklaması aktarılmaz (yalnızca kategori). Müşteri adı yalnızca grup içi / kamu /
// grup dışı ayrımı için okunur, çıktıya yazılmaz.
var MALI_GIDER_ID_ = '1SZdjPUrz3_1aHcWn5xBQJSpMeqBntKMw';   // aylık gider tablosu.xlsx (= 2026 Fatura, muhasebe)
var MALI_GELIR_ID_ = '1_68Qn8esEbBH2LnTAfUCtP_V1OsXe1Ci';   // aylık gelir satış tablosu.xlsx
var MALI_F5_ = '2026 Fatura (muhasebe)';
var MALI_BIRIM_ = 'Tarım ve Hayvancılık';
var MALI_URETIM_YERI_ = { '1604': 'Taşağıl (ESK)', '1605': 'Aslım', '1611': 'Tarımsal Alan', '1613': 'Şekersüt', '1614': 'Pan-Gev' };

// Python'un Unicode \b davranışı: Türkçe harfler kelime karakteri sayılır.
var MALI_W_ = 'A-Za-z0-9_ÇĞİÖŞÜçğıöşüÂâÎîÛû';
function maliRe_(desen, bayrak) {
  var b = '(?:(?<=[' + MALI_W_ + '])(?![' + MALI_W_ + '])|(?<![' + MALI_W_ + '])(?=[' + MALI_W_ + ']))';
  return new RegExp(desen.split('\\b').join(b), bayrak || '');
}
function maliS_(v) { return v === null || v === undefined ? '' : String(v).trim(); }
function maliUst_(v) { return maliS_(v).toUpperCase(); }   // Python str.upper() gibi (i → I)
function maliSayi_(v) {
  if (typeof v === 'number') return v;
  var t = maliS_(v).replace(/ /g, '');
  if (!t) return null;
  if (/^-?\d{1,3}(\.\d{3})*,\d+$/.test(t) || /^-?\d+,\d+$/.test(t)) return parseFloat(t.replace(/\./g, '').replace(',', '.'));
  var x = Number(t);
  return isNaN(x) ? null : x;
}
function maliTarihMi_(v) { return Object.prototype.toString.call(v) === '[object Date]' && !isNaN(v.getTime()); }
function maliTarih_(v) {
  if (maliTarihMi_(v)) return v;
  var t = maliS_(v).slice(0, 10), m;
  if ((m = /^(\d{2})\.(\d{2})\.(\d{4})$/.exec(t))) return new Date(+m[3], +m[2] - 1, +m[1]);
  if ((m = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(t))) return new Date(+m[3], +m[1] - 1, +m[2]);
  if ((m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(t))) return new Date(+m[1], +m[2] - 1, +m[3]);
  return null;
}
function maliT_(d) { return d ? d.getFullYear() + '-' + ('0' + (d.getMonth() + 1)).slice(-2) + '-' + ('0' + d.getDate()).slice(-2) : ''; }
function maliTrn_(x) {
  var t = String(x).replace(/İ/g, 'I').replace(/ı/g, 'i').toUpperCase();
  return t.replace(/Ş/g, 'S').replace(/Ğ/g, 'G').replace(/Ü/g, 'U').replace(/Ö/g, 'O').replace(/Ç/g, 'C');
}
function maliNrm_(x) { return maliTrn_(x).replace(/[^A-Z0-9]/g, ''); }
function maliFk_(f) { return maliTrn_(f).replace(/[^A-Z0-9]/g, '').slice(0, 5); }
function maliMn_(v) {
  var s = (v / 1e6).toFixed(2).split('.');
  return s[0].replace(/\B(?=(\d{3})+(?!\d))/g, '.') + ',' + s[1] + ' milyon TL';
}

var MALI_TUZEL_ = maliRe_('(ENERJİ\\.TOP|A\\.?\\s?Ş\\.?|\\bAŞ\\b|LTD|ŞTİ|ŞİRKETİ|KOOP|LİMİTED|ANONİM|BİRLİĞİ|MÜDÜRLÜĞÜ|BAŞKANLIĞI|BELEDİYE|KURUMU|KOMBİNASI|ODASI|BORSASI|BANKASI|SİGORTA|ÜNİVERSİTE|HOLDİNG|NOTERLİĞİ|VAKFI|DERNEĞİ|OFİSİ|\\(TMO\\)|DAĞITIM|PERAKENDE|TURKCELL|VODAFONE|TÜRK TELEKOM|SANAYİ VE TİCARET|SAN\\.\\s?VE\\s?TİC)', 'i');
var MALI_KURUMSAL_ = /A\.?Ş|LTD|ŞTİ|KOOP|SAN|TİC|KURUM|KOMBİNA|MÜDÜR|BAŞKAN|BELEDİYE|ODASI|BORSA|BANKA|SİGORTA|ÜNİVERSİTE|HOLDİNG|NOTER|VAKF|DERNEK|OFİSİ|TMO|DAĞITIM|ENERJİ|GIDA|TARIM|VETERİNER|ECZA|MAKİNA|OTO|DSYB|İL[İI] /i;
function maliTedarikci_(ad) {
  ad = maliS_(ad);
  if (!(MALI_TUZEL_.test(ad) || /ENERJİ\.?TOP|SAN\. A$|SAN\.?$/.test(ad))) return 'Şahıs / teyitsiz tedarikçi';
  var p = ad.split(/\s*-\s*/);
  for (var i = 0; i < p.length; i++) {
    if (/^[A-ZÇĞİÖŞÜ]+( [A-ZÇĞİÖŞÜ]+){0,2}\.?$/.test(p[i].trim()) && !MALI_KURUMSAL_.test(p[i])) return 'Şahıs / teyitsiz tedarikçi';
  }
  return ad;
}
function maliTuzel_(ad) { return maliTedarikci_(ad).indexOf('Şahıs') !== 0; }
function maliFnoY_(no, firma) { return maliTuzel_(firma) && no ? ' · fatura no ' + no : ''; }
function maliHesapM_(firma) {   // mali_muhasebe.hesap
  var f = maliUst_(firma);
  if (/KONYA ŞEKER|PANAGRO|ÇUMRA ŞEKER|KONYA ŞEKER/.test(f)) return 'Grup içi';
  if (/MÜDÜRLÜĞÜ|BELEDİYE|VERGİ DAİRESİ|TOPRAK MAHSULLERİ|TMO|BAŞKANLIĞI|KURUMU|NOTER/.test(f)) return 'Kamu';
  return 'Grup dışı';
}
function maliHesapG_(firma) {   // gelir_gider.hesap
  var f = maliUst_(firma);
  if (/KONYA ŞEKER|PANAGRO|ÇUMRA ŞEKER|PANKOBİRLİK/.test(f)) return 'Grup içi';
  if (/MÜDÜRLÜĞÜ|BELEDİYE|VERGİ DAİRESİ|TOPRAK MAHSULLERİ|TMO|BAŞKANLIĞI|KURUMU|NOTER|ET VE SÜT/.test(f)) return 'Kamu';
  return 'Grup dışı';
}

var MALI_KAT_ = [['Canlı hayvan alımı', 'BESİLİK SIĞIR|İTHAL ERKEK DANA|DÜVE ALIMI|CANLI HAYVAN'],
  ['Taşeron işçilik hizmeti', 'YEVMİYE|PERSONEL ÜCRET|^ÇİFTL+İKLER|^ÇİFTLİK YEVM|İŞÇİLİK HİZMET'],
  ['Enerji ve su', 'AKTİF ENERJİ|DAĞITIM BEDELİ|ELEKTRİK +YANSITMA|^BTV$|ELEKTRİK ENERJİ|ELEKTRİK TÜKETİM|DOĞALGAZ|DOGALGAZ|İÇME SUYU|SU BEDELİ|SULAMA SUYU|ŞAFAK SU|DAMACANA'],
  ['Tohum', 'PAN\\.\\s?TOH|CONVİSO|SANDPİPER|TOHUM'],
  ['Yem ve kaba yem', '^ARPA|BUĞDAY(?! HASAT)|TOKSİN BAĞLAYICI|YEM|KÜSPE|SAMAN|SİLAJ|SILAJ|KEPEK|SOYA|PELET|MELAS|BALYA|FLAKE|RASYON|PREMİKS|MİNERAL|TUZ BLOK|BUZAĞI MAMASI|SÜT TOZU'],
  ['Gübre ve zirai ilaç', 'GÜBRE|HERBİSİT|FUNGİSİT|İNSEKTİSİT|ÜRE |AMONYUM|DAP|NPK|BİOVİN|BIOVIN|ASVİN|ASVIN|CERAMINO|SULFO|ZİRAİ|YAPRAK|TARIM İLACI|POLYSULPHATE|GOGGLES|POLKA|COPPER WAY|GALLANT|NATUREX|MAHLAS TARIM|SAFA TARIM|CORTEVA|\\d+ ?(SC|EW|EC|WG|SL)\\b'],
  ['Tarımsal hizmet (hasat, ilaçlama, nakliye)', 'HASATI|HASAT HİZMET|İLAÇLAMA HİZMET|BİÇİM|BALYALAMA|SÜRÜM HİZMET'],
  ['Makine ve ekipman alımı', 'MAKİNASI|MAKİNESİ|TIRMIĞI|DRONE|PULVERİZATÖR|RÖMORK ALIM|TRAKTÖR ALIM|BALYA MAKİNE'],
  ['Arazi kirası', 'TARLA|ADA \\d|PARSEL KİRA|ARAZİ KİRA'],
  ['Akaryakıt', 'MOTORİN|MOTORIN|BENZİN|AKARYAKIT|ADBLUE|EURODİES|DİZEL'],
  ['Veteriner, ilaç, aşı, tohumlama', 'AŞI|VETERİNER|ANTİBİYOT|ENJEK|SPERMA|SEMEN|PAYET|TOHUMLAMA|SERUM|İLAÇ.*(HAYVAN|BUZAĞI|İNEK)|KALSİYUM|BOLUS|OKSİTETRA|PENİSİLİN|DEZENFEKT|İYOT|KOLOSTRUM'],
  ['Sağım ve süt ekipmanı', 'SAĞIM|SAGIM|MEME|PULSATÖR|SÜT TANKI|SÜT HORTUM'],
  ['Nakliye ve taşıma', 'NAKLİYE|NAKLIYE|TAŞIMA|TAŞINMASI|HAMMALİYE|KANTAR'],
  ['İş güvenliği ve giyim', 'İŞ GÜVENLİĞİ|SWEAT|ELDİVEN|BOT |ÇİZME|YELEK|MONT|KASK|TULUM|PANTOLON|TİŞÖRT|GÖMLEK|MASKE'],
  ['Yapı, tesisat ve inşaat', 'ÇİMENTO|DEMİR|BOYA|BETON|TUĞLA|PROFİL|SAC |BORU|VANA|KABLO|ELEKTRİK MALZ|SİGORTA KUTU|İNŞAAT|KAYNAK ELEKTROD|CIVATA|CİVATA|SOMUN'],
  ['Bakım, onarım, yedek parça', 'YAĞ|FİLTRE|RULMAN|TAMİR|BAKIM|ONARIM|LASTİK|AKÜ|PARÇA|KEÇE|HORTUM|KAYIŞ|RADYATÖR|BOBİNAJ|TORNA|KAPORTA|ROT|BALANS|EGZOZ|MOTOR|ŞANZIMAN|DİŞLİ|PİSTON|CONTA|POMPA|AMORTİSÖR|FREN|DEBRİYAJ|SERVİS|HİZMET ALIMI|MANİTOU|TRAKTÖR|JCB|PULLUK|MİBZER|RÖMORK'],
  ['Temizlik, kırtasiye, mutfak', 'TEMİZLİK|DETERJAN|KAĞIT|KIRTASİYE|TONER|ÇAY|ŞEKER |YEMEK|GIDA|EKMEK|SU \\d'],
  ['Resmi giderler, vergi, harç', 'DAMGA|VERGİ|HARÇ|NOTER|ÜCRETİ.*MÜDÜRLÜ|AİDAT|SİGORTA PRİM|KASKO|TRAFİK SİGORTA|MUAYENE']
].map(function (k) { return [k[0], maliRe_(k[1])]; });
function maliKategori_(t) {
  t = maliUst_(t);
  for (var i = 0; i < MALI_KAT_.length; i++) if (MALI_KAT_[i][1].test(t)) return MALI_KAT_[i][0];
  return 'Diğer';
}
var MALI_EK_KAT_ = [
  ['Gübre ve zirai ilaç', 'OT İLACI|İLAÇ OT|FUNGUSİT|FUNGİSİT|VARİANO|SİGNUM|SIVANTO|TİVMETİX|CAPRENO|INTEGRITY|KÜKÜRT|AZOTE|CUTTENG'],
  ['Canlı hayvan alımı', 'CANLI (DANA|HAYVAN|SIĞIR)|DANA ALIM|HAYVAN ALIM'],
  ['Veteriner, ilaç, aşı, tohumlama', 'MASTİT|VAKSİN|BOVIS|GESTAVET|KOLİBİN|CEFTISIN|PENISILIN|DALMAZİN|GENTAPAN|METECAM|CEPHANOM|PRIMAMYCINE|DOLLİSERA|HALOCUR|' +
    'THERENEKRON|ELİSA|SANİTİME|VİRKON|SİNEK|SOYKÜTÜĞÜ|ISLAH BEDELİ|\\b\\d+ ?ML\\b'],
  ['Yem ve kaba yem', 'POSASI|POSA '],
  ['Makine ve ekipman alımı', 'DÜMENLEME|NOVATEL|\\bUPS\\b'],
  ['Bakım, onarım, yedek parça', 'KEPÇE ÇALIŞMA|KAYNAK İŞÇ|KAYNAK İŞC|LASTİĞİ']
].map(function (k) { return [k[0], maliRe_(k[1])]; });
function maliGiderKategori_(m) {
  var t = maliUst_(m);
  for (var i = 0; i < MALI_EK_KAT_.length; i++) if (MALI_EK_KAT_[i][1].test(t)) return MALI_EK_KAT_[i][0];
  return maliKategori_(m);
}
function maliGelirUrun_(m) {
  var t = maliUst_(m), l = [['Çiğ süt', /SÜT/], ['ESK hayvan bakım hizmeti', /BAKIM HİZMET/], ['Sap balyası', /SAP BALYA/], ['Yonca balyası', /YONCA/],
    ['Buğday', /BUĞDAY/], ['Arpa', /ARPA/], ['Patates', /PATATES/], ['Şeker pancarı', /PANCAR/], ['Mısır ve silaj', /MISIR|SİLAJ/],
    ['Canlı hayvan', /DANA|DÜVE|İNEK|BUZAĞI|TOSUN|HAYVAN/], ['Hurda ve atık', /DEMİR|ATIK|HURDA|YAĞLAR|PLASTİK/]];
  for (var i = 0; i < l.length; i++) if (l[i][1].test(t)) return l[i][0];
  return 'Diğer';
}
function maliEnCok_(sayac) {   // Python Counter.most_common(1): eşitlikte ilk eklenen
  var en = null, ev = -Infinity;
  Object.keys(sayac).forEach(function (k) { if (sayac[k] > ev) { ev = sayac[k]; en = k; } });
  return en;
}
function maliKarsilastir_(a, b) {
  for (var i = 0; i < Math.min(a.length, b.length); i++) { if (a[i] < b[i]) return -1; if (a[i] > b[i]) return 1; }
  return a.length - b.length;
}
var MALI_AY_ = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

/** @param gider 2B dizi (ilk satır başlık), @param gelir 2B dizi; @param bugun 'yyyy-MM-dd' */
function maliUretCekirdek_(gider, gelir, linkGider, linkGelir, bugun) {
  var bas = gider[0].map(maliS_);
  function kol(b, ad) { var i = b.indexOf(ad); return i < 0 ? null : i; }
  var c = { firma: kol(bas, 'Satıcı adı'), ref: kol(bas, 'Referans'), tarih: kol(bas, 'Belge tarihi'), brut: kol(bas, 'Fatura brüt tutarı'),
    net: kol(bas, 'Tutar'), metin: kol(bas, 'Kısa metin'), uy: kol(bas, 'Üretim yeri') };   // "Kullanıcı adı" okunmaz (KVKK)
  var MF = {}, sira = [];
  for (var i = 1; i < gider.length; i++) {
    var r = gider[i];
    if (!maliTarihMi_(r[c.tarih])) continue;
    var ham = maliS_(r[c.ref]), k = maliNrm_(ham) + '|' + maliFk_(r[c.firma]);
    var f = MF[k];
    if (!f) { f = MF[k] = { ham: ham, satir: [], tarih: r[c.tarih], firma: maliS_(r[c.firma]), brut: 0, net: 0, kat: {} }; sira.push(k); }
    var b = maliSayi_(r[c.brut]) || 0, n = maliSayi_(r[c.net]) || 0, kt = maliKategori_(r[c.metin]);
    f.satir.push(i + 1); f.brut += b; f.net += n; f.kat[kt] = (f.kat[kt] || 0) + (Math.abs(n) || 1);
    if (r[c.tarih] < f.tarih) f.tarih = r[c.tarih];
  }
  function yer(f) {
    var s = f.satir, rng = s.length === 1 ? 'satır ' + s[0] : 'satır ' + s[0] + '–' + s[s.length - 1];
    return MALI_F5_ + ' › ' + rng + maliFnoY_(f.ham, f.firma);
  }
  var liste = sira.map(function (k) { return MF[k]; });
  var sirali = liste.map(function (f, j) { return [f, j]; }).sort(function (a, b) { return (a[0].tarih - b[0].tarih) || (a[1] - b[1]); }).map(function (x) { return x[0]; });
  var fat = sirali.map(function (f) {
    return [maliT_(f.tarih), MALI_BIRIM_, maliHesapM_(f.firma), maliEnCok_(f.kat), maliTedarikci_(f.firma).replace(/\.+$/, ''),
      Math.round(f.brut * 100) / 100, 'TRY', '', '', '', yer(f), '', Math.round(f.net * 100) / 100];
  });
  var son = liste.reduce(function (m, f) { return !m || f.tarih > m ? f.tarih : m; }, null);
  var ilk = liste.reduce(function (m, f) { return !m || f.tarih < m ? f.tarih : m; }, null);
  var donem = ilk ? MALI_AY_[ilk.getMonth()] + '–' + MALI_AY_[son.getMonth()] + ' ' + son.getFullYear() : '';
  var K = [];
  function kontrol(bolum, baslik, deger, aciklama, kA, lA, kB, lB, duz, detay) { K.push([bolum, baslik, deger, aciklama, kA || '', lA || '', kB || '', lB || '', duz || '', detay || []]); }
  var gecersiz = liste.filter(function (f) { return !/\d{6}/.test(maliNrm_(f.ham)); });
  if (gecersiz.length) {
    kontrol('Tutarsızlık', 'Fatura numarası geçersiz kayıtlar', gecersiz.length + ' kayıt',
      'Muhasebe listesinde "Referans" (fatura no) alanı fatura numarası biçiminde değil.', MALI_F5_, linkGider, '', '', 'Muhasebeden doğru fatura numarası istenmeli.',
      gecersiz.map(function (f) {
        return [maliT_(f.tarih), MALI_BIRIM_, null, Math.round(f.brut * 100) / 100, yer(f) + ' · ' + maliTedarikci_(f.firma).replace(/\.+$/, ''), '',
          'Referans: "' + (maliTuzel_(f.firma) ? f.ham : '—') + '".'];
      }));
  }
  var tb = liste.reduce(function (s, f) { return s + f.brut; }, 0), tn = liste.reduce(function (s, f) { return s + f.net; }, 0);
  kontrol('Bilgi', 'Kaynak dosya', '1 dosya',
    MALI_F5_ + ': ' + (gider.length - 1) + ' kalem, ' + liste.length + ' fatura, ' + donem + '. KDV dahil toplam ' + maliMn_(tb) + ', KDV hariç ' + maliMn_(tn) + '. ' +
    '26.11.2026 kararıyla Mali Raporlar yalnızca bu dosyadan beslenir; birim fatura raporu okunmaz.', MALI_F5_, linkGider);
  kontrol('Bilgi', 'KVKK', '—', 'Kullanıcı adı sütunu okunmaz. Şahıs işletmeleri ve gerçek kişi tedarikçilerin adları ve fatura numaraları gösterilmez ("Şahıs / teyitsiz tedarikçi"); kalem açıklaması aktarılmaz.');

  // ---- gelir / gider (KDV hariç karşılaştırma)
  var cg = { firma: kol(bas, 'Satıcı adı'), tarih: kol(bas, 'Belge tarihi'), brut: kol(bas, 'Fatura brüt tutarı'), net: kol(bas, 'Tutar'), metin: kol(bas, 'Kısa metin'), uy: kol(bas, 'Üretim yeri') };
  var G = {}, ng = 0;
  for (var g = 1; g < gider.length; g++) {
    var rg = gider[g];
    if (!rg || !maliS_(rg[cg.firma])) continue;
    var t = maliTarih_(rg[cg.tarih]);
    if (!t) continue;
    ng++;
    var key = [t.getFullYear(), t.getMonth() + 1, MALI_URETIM_YERI_[maliS_(rg[cg.uy])] || 'Diğer birim', maliGiderKategori_(rg[cg.metin]), maliHesapG_(rg[cg.firma]), t.getDate()];
    var ks = JSON.stringify(key), v = G[ks] || (G[ks] = { k: key, v: [0, 0] });
    v.v[0] += maliSayi_(rg[cg.net]) || 0; v.v[1] += maliSayi_(rg[cg.brut]) || 0;
  }
  var bg = gelir[0].map(maliS_);
  function kol2() { for (var a = 0; a < arguments.length; a++) { var i = bg.indexOf(arguments[a]); if (i >= 0) return i; } throw new Error('Sütun bulunamadı: ' + Array.prototype.join.call(arguments, ', ')); }
  var cl = { org: kol2('Satış organizasyonu'), tarih: kol2('Faturalama tarihi'), musteri: kol2('Ad 1'), ia: kol2('İş alanı'), mlz: kol2('Malzeme  tnm', 'Malzeme tnm'),
    mkt: kol2('Faturalanan miktar'), brm: kol2('Satış ölçü birimi'), net: kol2('Matrah'), brut: kol2('KDV dahil tutar(TRY)') };
  var L = {}, nl = 0, iade = [0, 0];
  for (var h = 1; h < gelir.length; h++) {
    var rl = gelir[h];
    if (!rl || !maliS_(rl[cl.org])) continue;
    var tl = maliTarih_(rl[cl.tarih]);
    if (!tl) continue;
    nl++;
    var net = maliSayi_(rl[cl.net]) || 0;
    if (net < 0) { iade[0]++; iade[1] += net; }
    var kl = [tl.getFullYear(), tl.getMonth() + 1, MALI_URETIM_YERI_[maliS_(rl[cl.ia])] || 'Diğer birim', maliGelirUrun_(rl[cl.mlz]), maliHesapG_(rl[cl.musteri]),
      maliUst_(rl[cl.brm]), tl.getDate()];
    var kls = JSON.stringify(kl), w = L[kls] || (L[kls] = { k: kl, v: [0, 0, 0] });
    w.v[0] += maliSayi_(rl[cl.mkt]) || 0; w.v[1] += net; w.v[2] += maliSayi_(rl[cl.brut]) || 0;
  }
  function r2(x, d) { var p = Math.pow(10, d); return Math.round(x * p) / p; }
  var gList = Object.keys(G).map(function (k) { return G[k]; }).sort(function (a, b) { return maliKarsilastir_(a.k, b.k); });
  var lList = Object.keys(L).map(function (k) { return L[k]; }).sort(function (a, b) { return maliKarsilastir_(a.k, b.k); });
  var aylar = {};
  gList.concat(lList).forEach(function (x) { aylar[x.k[0] * 100 + x.k[1]] = true; });
  var ak = Object.keys(aylar).map(Number).sort(function (a, b) { return a - b; });
  var gg = {
    surum: 2, donem: ak.length ? MALI_AY_[ak[0] % 100 - 1] + '–' + MALI_AY_[ak[ak.length - 1] % 100 - 1] + ' ' + Math.floor(ak[ak.length - 1] / 100) : '',
    kdv: 'hariç', kaynakGider: 'aylık gider tablosu', kaynakGelir: 'aylık gelir satış tablosu', linkGider: linkGider, linkGelir: linkGelir,
    satirGider: ng, satirGelir: nl, iadeAdet: iade[0], iadeTutar: r2(iade[1], 2),
    gider: gList.map(function (x) { return [x.k[0], x.k[1], x.k[2], x.k[3], x.k[4], r2(x.v[0], 2), r2(x.v[1], 2), x.k[5]]; }),
    gelir: lList.map(function (x) { return [x.k[0], x.k[1], x.k[2], x.k[3], x.k[4], x.k[5], r2(x.v[0], 3), r2(x.v[1], 2), r2(x.v[2], 2), x.k[6]]; })
  };
  return { surum: 5, olusturma: bugun, uretim: 'sunucu (otomatik, tam okuma)', kaynak: MALI_F5_, kdv: 'dahil', dosyalar: [['muhasebe', MALI_F5_, linkGider]],
    fatura: fat, acik: [], kontrol: K, muhasebe: [], muhasebeBilgi: { kaynak: MALI_F5_, link: linkGider, donem: donem, kdv: 'dahil' }, gelirGider: gg };
}

function maliKaynakDegerleri_(id) {
  var dn = kaynakDonustur_(DriveApp.getFileById(id));
  if (!dn || dn.hata) throw new Error('Dönüştürülemedi: ' + (dn && dn.hata));
  return SpreadsheetApp.openById(dn.id).getSheets()[0].getDataRange().getValues();
}

/** mali_veri.json'u üretir ve Mali Raporlar klasöründeki dosyanın üzerine yazar. */
function maliUret_() {
  var gider = maliKaynakDegerleri_(MALI_GIDER_ID_), gelir = maliKaynakDegerleri_(MALI_GELIR_ID_);
  var o = maliUretCekirdek_(gider, gelir, 'https://drive.google.com/file/d/' + MALI_GIDER_ID_ + '/view',
    'https://drive.google.com/file/d/' + MALI_GELIR_ID_ + '/view', Utilities.formatDate(new Date(), 'Europe/Istanbul', 'yyyy-MM-dd'));
  if (!o.fatura.length || !o.gelirGider.gider.length) return { hata: 'Fatura listesi okunamadı; mevcut dosya korunuyor.' };
  var f = maliDosyasi_(), metin = JSON.stringify(o);
  if (f) f.setContent(metin); else DriveApp.getFolderById(MALI_KLASOR_ID).createFile('mali_veri.json', metin, 'application/json');
  return { fatura: o.fatura.length, gider: o.gelirGider.gider.length, gelir: o.gelirGider.gelir.length, donem: o.muhasebeBilgi.donem };
}

/** Kaynak dosyalardan biri değiştiyse yeniden üretir (veri toplanırken ve günlük çalışmada). */
function maliGuncelle_() {
  var pr = PropertiesService.getScriptProperties();
  var imza = [MALI_GIDER_ID_, MALI_GELIR_ID_].map(function (id) { return DriveApp.getFileById(id).getLastUpdated().getTime(); }).join('|');
  if (pr.getProperty('maliUretim') === imza) return { durum: 'güncel' };
  var r = maliUret_();
  if (!r.hata) pr.setProperty('maliUretim', imza);
  return r;
}

/** Elle çalıştırma: Mali Raporlar verisini hemen yeniden üretir ve sonucu günlüğe yazar. */
function maliHazirla() {
  var r = maliUret_();
  if (!r.hata) PropertiesService.getScriptProperties().setProperty('maliUretim',
    [MALI_GIDER_ID_, MALI_GELIR_ID_].map(function (id) { return DriveApp.getFileById(id).getLastUpdated().getTime(); }).join('|'));
  Logger.log('Mali Raporlar: ' + JSON.stringify(r));
}
