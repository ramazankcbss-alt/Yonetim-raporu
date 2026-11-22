import 'kategori.dart';
import 'model.dart';

/// Geçmiş Yıllar (Bilgi Bankası) kayıtlarının sınıflandırılması:
/// ana alan (Tarım / Hayvancılık / Genel), ürün, çiftlik, yıl ve gösterge
/// sınıfı (ekim alanı, verim, maliyet…). Ekran bu dört boyutla kırılım yapar.

/// Küçük harf; birleşik nokta (İ → i̇) kaldırılır.
String _k(String s) => kucuk(s).replaceAll('\u0307', '');

/// Ana alan: Tarım, Hayvancılık ya da (ikisine de girmeyenler) Genel.
const gecmisAnaAlanlar = ['Tarım', 'Hayvancılık', 'Genel'];

const _tarimK = ['tarım', 'tarim', 'ziraat', 'fidan', 'pancar', 'ekim', 'hasat', 'arazi', 'tarla', 'gübre',
  'sulama', 'tohum', 'toprak', 'mısır', 'buğday', 'arpa', 'yonca', 'zirai', 'dekar', 'ilaçlama', 'nadas',
  'kök/da', 'verim kg/da', 'patates', 'ayçiçe', 'nohut', 'pivot', 'tritikale'];
const _hayvanK = ['hayvan', 'besi', 'buzağı', 'kesim', 'süt', 'doğum', 'sağmal', 'sağım', 'inek', 'düve',
  'dana', 'tosun', 'yem', 'rasyon', 'aşı', 'ölüm', 'ölen', 'gebe', 'tohumlama', 'sürü', 'koyun', 'mastit',
  'karkas', 'canlı ağırlık', 'baş', 'esk', 'veteriner'];

/// Konusu açıkça tarım olan kayıtlar (ör. Şekersüt'teki tarla işleri)
/// çiftlik adı "süt" içerse de Tarım alanına girer.
const _tarimKonulari = {'tarım', 'arazi'};

String gecmisAnaAlan(GecmisVeri x) {
  if (_tarimKonulari.contains(kucuk(x.konu).trim())) return 'Tarım';
  final b = gecmisBirimi(x);
  if (b == Birim.ziraat) return 'Tarım';
  if (b == Birim.hayvancilik) return 'Hayvancılık';
  final a = kucuk(x.alan);
  if (_tarimK.any(a.contains)) return 'Tarım';
  final t = kucuk('${x.konu} ${x.gosterge} ${x.birim}');
  final h = _hayvanK.any(t.contains), z = _tarimK.any(t.contains);
  if (h && !z) return 'Hayvancılık';
  if (z && !h) return 'Tarım';
  if (RegExp(r'hayvancılık|besi').hasMatch(a)) return 'Hayvancılık';
  return 'Genel';
}

// ---------------------------------------------------------------- Ürün

/// Tarım ürünleri, gösterilme sırasıyla.
const tarimUrunleri = [
  'Buğday', 'Arpa', 'Tritikale', 'Silajlık mısır', "4'lü karışım", 'Yonca', 'Şeker pancarı',
  'Patates', 'Ayçiçeği', 'Nohut', 'Sap / saman', 'Girdiler (gübre, yakıt)', 'Tüm ürünler (genel)',
];

/// Hayvancılık ürün grupları, gösterilme sırasıyla.
const hayvanUrunleri = [
  'Süt', 'Besi, kesim ve et', 'Damızlık, üreme ve buzağı', 'Yem ve girdiler', 'Sürü geneli',
];

const genelUrun = 'Genel';

String _urunMetni(GecmisVeri x) {
  // Saha iş kayıtlarında işin adı Değer sütunundadır.
  final d = x.sayi == null ? x.deger : '';
  return _k('${x.gosterge} ${x.konu} $d')
      .replaceAll('şekersüt', '')
      .replaceAll('ı', 'i'); // "Misir" / "Mısır" yazımları birleşsin
}

String _tarimUrunu(String t) {
  if (t.contains("4'lü") || t.contains("4'lu") || t.contains('4 lü') || t.contains('4 lu') ||
      t.contains('karişim') || t.contains('karisim')) {
    return "4'lü karışım";
  }
  if (t.contains('tritikale')) return 'Tritikale';
  if (t.contains('buğday') || t.contains('bugday')) return 'Buğday';
  if (t.contains('arpa')) return 'Arpa';
  if (t.contains('silaj') || t.contains('misir')) return 'Silajlık mısır';
  if (t.contains('yonca')) return 'Yonca';
  if (t.contains('pancar')) return 'Şeker pancarı';
  if (t.contains('patates')) return 'Patates';
  if (t.contains('ayçiçe') || t.contains('aycice')) return 'Ayçiçeği';
  if (t.contains('nohut')) return 'Nohut';
  if (t.contains('sap balya') || t.contains('saman')) return 'Sap / saman';
  if (t.contains('gübre') || t.contains('motorin') || t.contains('mazot') || t.contains('kükürt')) {
    return 'Girdiler (gübre, yakıt)';
  }
  return 'Tüm ürünler (genel)';
}

String _hayvanUrunu(GecmisVeri x, String t) {
  final konu = _k(x.konu);
  if (konu == 'stok' || konu.contains('satınalma')) return 'Yem ve girdiler';
  if (t.contains('süt') || t.contains('sağmal') || t.contains('sağim') || t.contains('kuru (')) return 'Süt';
  if (t.contains('besi') || t.contains('kesim') || t.contains('karkas') ||
      t.contains('erkek') || t.contains('boğa') || t.contains('tosun')) {
    return 'Besi, kesim ve et';
  }
  if (konu.contains('üreme') || konu.contains('doğum') || t.contains('buzağ') || t.contains('buzaği') ||
      t.contains('doğum') || t.contains('doğan') || t.contains('tohumla') || t.contains('gebe') ||
      t.contains('abort') || t.contains('düve')) {
    return 'Damızlık, üreme ve buzağı';
  }
  if (t.contains('yem') || t.contains('rasyon')) return 'Yem ve girdiler';
  return 'Sürü geneli';
}

/// Kaydın ürünü (tarımda ekilen ürün, hayvancılıkta ürün grubu).
String gecmisUrun(GecmisVeri x) {
  final ana = gecmisAnaAlan(x);
  final t = _urunMetni(x);
  if (ana == 'Tarım') return _tarimUrunu(t);
  if (ana == 'Hayvancılık') return _hayvanUrunu(x, t);
  return genelUrun;
}

int urunSirasi(String u) {
  final i = tarimUrunleri.indexOf(u);
  if (i >= 0) return i;
  final j = hayvanUrunleri.indexOf(u);
  return j >= 0 ? 100 + j : 200;
}

// ---------------------------------------------------------------- Çiftlik

const ortakCiftlik = 'Tüm çiftlikler (ortak)';

/// Kaydın çiftliği: ana işletme adı; ortak/konsolide kayıtlar tek başlıkta.
/// ESK-Taşağıl kendi çiftliklerimizden ayrı tutulur.
String gecmisCiftlik(GecmisVeri x) {
  final a = kucuk(x.alan).trim();
  if (a.startsWith('esk')) return 'ESK-Taşağıl';
  if (a.contains('ormanlık')) return 'Taşağıl';
  if (a.contains('aslım-taşağıl') || a.contains('aslım - taşağıl')) return 'Aslım-Taşağıl (ortak tarım)';
  final k = alanKoku(x.alan);
  final kk = kucuk(k);
  if (kk.isEmpty || kk.startsWith('tarım') || kk.startsWith('tüm') || kk.startsWith('çiftlikler') ||
      kk.startsWith('konsolide')) {
    return ortakCiftlik;
  }
  return k;
}

int ciftlikSirasi(String c) {
  if (c == ortakCiftlik) return 1;
  if (c == 'ESK-Taşağıl') return 2;
  return 0;
}

// ---------------------------------------------------------------- Yıl

const yilsizEtiket = 'Yıl belirtilmemiş';

String gecmisYil(GecmisVeri x) => x.yil.trim().isEmpty ? yilsizEtiket : x.yil.trim();

/// Yıllar yeniden eskiye; çok yıllı dönemler ("2021-2025") tek yılların
/// arkasından, yılı olmayanlar en sonda.
int yilKarsilastir(String a, String b) {
  int no(String y) {
    final m = RegExp(r'(20\d\d)(?!.*20\d\d)').firstMatch(y);
    return m == null ? 0 : int.parse(m.group(1)!);
  }

  // Tek yıl → 0, çok yıllı dönem → 1, yılsız → 2
  int tur(String y) => no(y) == 0 ? 2 : (RegExp(r'20\d\d.*20\d\d').hasMatch(y) ? 1 : 0);
  final t = tur(a).compareTo(tur(b));
  if (t != 0) return t;
  final c = no(b).compareTo(no(a));
  return c != 0 ? c : a.compareTo(b);
}

// ---------------------------------------------------------------- Sınıf

/// Gösterge sınıfları, gösterilme sırasıyla.
const gecmisSiniflari = [
  'Ekim alanı ve arazi',
  'Verim ve üretim',
  'Maliyet',
  'Gelir ve kâr/zarar',
  'Satış ve fiyat',
  'Hayvan varlığı',
  'Sürü hareketi ve kesim',
  'Üreme',
  'Süt kalitesi',
  'Sağlık',
  'Stok',
  'Saha faaliyetleri',
  'Altyapı, yatırım ve kapasite',
  'İşletme ve personel',
  'Diğer',
];

/// Göstergenin sınıfı: ekim alanı, verim, maliyet, kâr/zarar…
String gecmisSinif(GecmisVeri x) {
  final konu = _k(x.konu).trim();
  final g = _k(x.gosterge);
  final t = '$g $konu';
  final b = kucuk(x.birim).trim();

  if (konu.contains('sağlı') || konu.contains('hastalık') || konu.contains('veteriner')) return 'Sağlık';
  if (konu == 'stok' || g.startsWith('stok')) return 'Stok';
  if (konu.contains('kalite')) return 'Süt kalitesi';
  if (t.contains('maliyet') || t.contains('gider') || t.contains('masraf')) return 'Maliyet';
  if (t.contains('kazanç') || t.contains('kâr') || t.contains('zarar') || t.contains('gelir') ||
      t.contains('net satış') || ((t.contains('satış') || t.contains('tutar')) && b == 'tl')) {
    return 'Gelir ve kâr/zarar';
  }
  if (t.contains('fiyat') || t.contains('satış') || t.contains('satilan')) return 'Satış ve fiyat';
  if (b == 'dekar' || b == 'da' || b == 'm²' || b == 'm2' || b == 'hektar' ||
      g.contains('ekim') || g.contains('serim') || konu == 'arazi') {
    return 'Ekim alanı ve arazi';
  }
  if (t.contains('verim') || t.contains('hasat') || t.contains('tonaj') || t.contains('üretim') ||
      t.contains('karkas') || t.contains('fire') || konu == 'süt') {
    return 'Verim ve üretim';
  }
  if (g.contains('iş tamamlandı') || g.contains('iş kaydı')) return 'Saha faaliyetleri';
  if (konu.contains('yatırım') || konu.contains('kapasite') || konu.contains('kuruluş') ||
      konu.contains('varlık') || g.contains('altyapı') || konu == 'sistem') {
    return 'Altyapı, yatırım ve kapasite';
  }
  if (konu.contains('personel') || konu.contains('karar') || konu.contains('satınalma')) {
    return 'İşletme ve personel';
  }
  if (konu == 'sürü' || konu == 'genel durum') return 'Hayvan varlığı';
  if (konu.contains('sürü hareketi') || konu.startsWith('kesim') || konu == 'alım' ||
      konu.contains('besi girişi') || konu.contains('hayvan satışı') || konu.contains('transfer')) {
    return 'Sürü hareketi ve kesim';
  }
  if (konu == 'üreme' || konu == 'doğum') return 'Üreme';
  return 'Diğer';
}

int sinifSirasi(String s) {
  final i = gecmisSiniflari.indexOf(s);
  return i < 0 ? 99 : i;
}

// ---------------------------------------------------------------- Boyutlar

/// Kırılım boyutları.
enum GBoyut { yil, alan, urun, ciftlik }

const gBoyutAdlari = {
  GBoyut.yil: 'Yıllar',
  GBoyut.alan: 'Alanlar',
  GBoyut.urun: 'Ürünler',
  GBoyut.ciftlik: 'Çiftlikler',
};

String gBoyutDegeri(GBoyut b, GecmisVeri x) => switch (b) {
      GBoyut.yil => gecmisYil(x),
      GBoyut.alan => gecmisAnaAlan(x),
      GBoyut.urun => gecmisUrun(x),
      GBoyut.ciftlik => gecmisCiftlik(x),
    };

int gBoyutKarsilastir(GBoyut b, String p, String q) {
  switch (b) {
    case GBoyut.yil:
      return yilKarsilastir(p, q);
    case GBoyut.alan:
      return gecmisAnaAlanlar.indexOf(p).compareTo(gecmisAnaAlanlar.indexOf(q));
    case GBoyut.urun:
      final c = urunSirasi(p).compareTo(urunSirasi(q));
      return c != 0 ? c : p.compareTo(q);
    case GBoyut.ciftlik:
      final c = ciftlikSirasi(p).compareTo(ciftlikSirasi(q));
      return c != 0 ? c : p.compareTo(q);
  }
}
