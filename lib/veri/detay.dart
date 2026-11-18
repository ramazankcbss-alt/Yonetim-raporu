// İşletme günlük raporlarının (Fethiye, Erentepe, Aslım, ESK-Taşağıl)
// göstergelerini dönem için özetler: akış göstergeleri (süt, doğum, kesim,
// ölüm, giriş) toplanır, mevcut göstergeleri (hayvan sayıları, personel)
// dönemin son veri gününden, ortalamalar gün ortalaması olarak verilir.

import 'model.dart';

const detayIsletmeleri = [
  'Fethiye Şube',
  'Erentepe Şube',
  'Aslım Çiftliği',
  'ESK-Taşağıl Çiftliği',
];

const eskDetay = 'ESK-Taşağıl Çiftliği';

enum DetayTur { toplam, sonGun, ortalama }

class DetayGosterge {
  const DetayGosterge(this.etiket, this.deger);
  final String etiket;
  final double deger;
}

class DetayBolum {
  DetayBolum(this.ad, this.tur);
  final String ad;
  final DetayTur tur;
  final List<DetayGosterge> satirlar = [];

  String get turAciklama => switch (tur) {
        DetayTur.toplam => 'dönem toplamı',
        DetayTur.sonGun => 'son veri günü',
        DetayTur.ortalama => 'günlük ortalama',
      };
}

/// Türkçe küçük harf ve tek boşluk.
String kucuk(String s) => s
    .replaceAll('İ', 'i')
    .replaceAll('I', 'ı')
    .toLowerCase()
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool _icerir(String n, List<String> parcalar) => parcalar.any(n.contains);

bool personelMi(String gosterge) => _icerir(kucuk(gosterge),
    ['personel', 'pers.', 'işçi', 'isci', 'taşeron', 'taseron', 'güvenlik']);

bool cikisMi(String bolum) => _icerir(kucuk(bolum), ['cikan', 'çıkan']);

bool kayipMi(String gosterge) =>
    _icerir(kucuk(gosterge), ['ölen', 'olen', 'ölü', 'olu dog', 'atık', 'atik']);

bool girisMi(String gosterge) => _icerir(kucuk(gosterge),
    ['doğan', 'dogan', 'alınan', 'alinan', 'satın al', 'satin al']);

DetayTur detayTuru(String bolum, String gosterge) {
  final b = kucuk(bolum), g = kucuk(gosterge);
  if (personelMi(gosterge)) return DetayTur.sonGun;
  if (b.contains('ort') || g.contains('ort.') || g.startsWith('süt ort')) {
    return DetayTur.ortalama;
  }
  if (cikisMi(bolum) ||
      b.startsWith('sut (') ||
      b.startsWith('süt (') ||
      b == 'lt' ||
      b == 'kg' ||
      girisMi(gosterge) ||
      _icerir(g, ['kesilen', 'ölen', 'olen', 'giden', 'satılan', 'satilan'])) {
    return DetayTur.toplam;
  }
  return DetayTur.sonGun;
}

const _bolumAdlari = {
  'hayvan sayisi': 'Hayvan Sayıları',
  'hayvan sayısı': 'Hayvan Sayıları',
  'sut (lt)': 'Süt Üretimi (lt)',
  'sut (kg)': 'Süt Üretimi (kg)',
  'ort.sut verimi': 'Ortalama Süt Verimi',
  'lt': 'Süt Dağılımı (lt)',
  'kg': 'Süt Dağılımı (kg)',
  'suruden cikanlar': 'Sürüden Çıkanlar',
  'sürüden çıkanlar': 'Sürüden Çıkanlar',
  'disiler': 'Dişi Hayvanlar',
  'dişiler': 'Dişi Hayvanlar',
  'erkekler': 'Erkek Hayvanlar',
  'aslım çiftliği': 'Sürü Yapısı',
  'taşağıl çiftliği': 'Sürü Yapısı',
};

String bolumAdi(String bolum, String gosterge) {
  if (personelMi(gosterge)) return 'Personel Sayıları';
  final n = kucuk(bolum);
  return _bolumAdlari[n] ?? _buyukIlk(_kelimeDuzelt(n));
}

const _etiketler = {
  'toplam hayv.say.': 'Toplam hayvan',
  'sagılan hay.say.': 'Sağılan hayvan',
  'sagilan hay.say.': 'Sağılan hayvan',
  'sagilan hayvan sayisi': 'Sağılan hayvan',
  'buzag.ver.mama': 'Buzağıya verilen mama',
  'buzag.ver.süt': 'Buzağıya verilen süt',
  'buzag.ver.sut': 'Buzağıya verilen süt',
  'buzag.ver.kolostrum': 'Buzağıya verilen kolostrum',
  'dokulen kolostrum': 'Dökülen kolostrum',
  'antibiyot.sut': 'Antibiyotikli süt',
  'ant tank': 'Antibiyotik tankı',
  'calisan pers.says.': 'Çalışan personel',
  'teknik pers.': 'Teknik personel',
  'isci-hayvancılık': 'İşçi (hayvancılık)',
  'satilan sut': 'Satılan süt',
  'satilan sut (kg)': 'Satılan süt (kg)',
  'sagilan sut': 'Sağılan süt',
  'olu dogum': 'Ölü doğum',
  'ölü dogum': 'Ölü doğum',
  'atık buzagı': 'Atık buzağı',
  'atık buzagi': 'Atık buzağı',
  'sagilan': 'Sağılan',
};

const _kelimeler = {
  'sut': 'süt',
  'sagilan': 'sağılan',
  'yuksek': 'yüksek',
  'dusuk': 'düşük',
  'buzagi': 'buzağı',
  'buzagı': 'buzağı',
  'dogan': 'doğan',
  'dogum': 'doğum',
  'bugun': 'bugün',
  'disi': 'dişi',
  'duve': 'düve',
  'boga': 'boğa',
  'gebe': 'gebe',
  'bos': 'boş',
  'olen': 'ölen',
  'dısardan': 'dışarıdan',
  'dışardan': 'dışarıdan',
  'sutten': 'sütten',
  'cikan': 'çıkan',
  'satilan': 'satılan',
};

String _kelimeDuzelt(String n) =>
    n.split(' ').map((w) => _kelimeler[w] ?? w).join(' ');

String _buyukIlk(String s) {
  if (s.isEmpty) return s;
  final ilk = s[0] == 'i' ? 'İ' : s[0].toUpperCase();
  return '$ilk${s.substring(1)}';
}

/// Kaynak etiketini kurumsal yazıma çevirir.
String gostergeAdi(String gosterge) {
  final n = kucuk(gosterge);
  return _etiketler[n] ?? _buyukIlk(_kelimeDuzelt(n));
}

bool _arada(DateTime t, DateTime bas, DateTime son) =>
    !t.isBefore(gunu(bas)) && !t.isAfter(gunu(son));

/// Dönemde işletmenin verisi olan günler.
List<DateTime> detayGunleri(RaporVerisi v, String isletme, DateTime bas, DateTime son) {
  final s = <DateTime>{
    for (final d in v.detay)
      if (d.isletme == isletme && _arada(d.tarih, bas, son)) gunu(d.tarih)
  };
  return s.toList()..sort();
}

/// İşletmenin dönem özeti, bölümlere ayrılmış (kaynak sırasıyla).
List<DetayBolum> isletmeDetayi(
    RaporVerisi v, String isletme, DateTime bas, DateTime son) {
  final gunler = detayGunleri(v, isletme, bas, son);
  if (gunler.isEmpty) return const [];
  final sonGun = gunler.last;
  final sira = <String, (String, String)>{}; // anahtar → (bölüm, gösterge)
  final toplam = <String, double>{}, sonDeger = <String, double>{};
  final adet = <String, int>{};
  for (final d in v.detay) {
    if (d.isletme != isletme || !_arada(d.tarih, bas, son)) continue;
    final k = '${kucuk(d.bolum)}|${kucuk(d.gosterge)}';
    sira.putIfAbsent(k, () => (d.bolum, d.gosterge));
    toplam[k] = (toplam[k] ?? 0) + d.deger;
    adet[k] = (adet[k] ?? 0) + 1;
    if (gunu(d.tarih) == sonGun) sonDeger[k] = d.deger;
  }
  final bolumler = <String, DetayBolum>{};
  final personel = DetayBolum('Personel Sayıları', DetayTur.sonGun);
  for (final e in sira.entries) {
    final (b, g) = e.value;
    final tur = detayTuru(b, g);
    final deger = switch (tur) {
      DetayTur.toplam => toplam[e.key]!,
      DetayTur.sonGun => sonDeger[e.key] ?? 0,
      DetayTur.ortalama => toplam[e.key]! / adet[e.key]!,
    };
    if (deger == 0) continue;
    final hedef = personelMi(g)
        ? personel
        : bolumler.putIfAbsent('${bolumAdi(b, g)}|${tur.name}',
            () => DetayBolum(bolumAdi(b, g), tur));
    hedef.satirlar.add(DetayGosterge(gostergeAdi(g), deger));
  }
  return [
    ...bolumler.values.where((b) => b.satirlar.isNotEmpty),
    if (personel.satirlar.isNotEmpty) personel,
  ];
}

/// Dönemde işletme bazında sürüden çıkışlar ya da giriş/doğumlar
/// (gösterge → işletme → toplam). Yalnızca sıfırdan farklı satırlar.
Map<String, Map<String, double>> hareketTablosu(
    RaporVerisi v, DateTime bas, DateTime son, {required bool cikis}) {
  final t = <String, Map<String, double>>{};
  for (final d in v.detay) {
    if (!_arada(d.tarih, bas, son)) continue;
    final uygun = cikis
        ? cikisMi(d.bolum) && !kucuk(d.gosterge).startsWith('toplam')
        : !cikisMi(d.bolum) && girisMi(d.gosterge);
    if (!uygun) continue;
    final ad = gostergeAdi(d.gosterge);
    final s = t.putIfAbsent(ad, () => {});
    s[d.isletme] = (s[d.isletme] ?? 0) + d.deger;
  }
  return t;
}

/// Kayıplar (ölüm, ölü doğum, atık): toplam ve "Erentepe: ölen inek 1, ..."
/// açıklaması. ESK-Taşağıl [eskDahil] değilse hariç tutulur.
/// Dönemde işletme raporu verisi yoksa null döner.
({double toplam, String aciklama})? kayipOzeti(
    RaporVerisi v, DateTime bas, DateTime son, {bool eskDahil = false}) {
  final gunVar = v.detay.any((d) =>
      _arada(d.tarih, bas, son) && (eskDahil || d.isletme != eskDetay));
  if (!gunVar) return null;
  final ip = <String, Map<String, double>>{};
  for (final d in v.detay) {
    if (!_arada(d.tarih, bas, son)) continue;
    if (!eskDahil && d.isletme == eskDetay) continue;
    if (eskDahil && d.isletme != eskDetay) continue;
    if (!cikisMi(d.bolum) || !kayipMi(d.gosterge)) continue;
    final g = ip.putIfAbsent(d.isletme, () => {});
    final ad = gostergeAdi(d.gosterge).toLowerCase();
    g[ad] = (g[ad] ?? 0) + d.deger;
  }
  var toplam = 0.0;
  final parcalar = <String>[];
  for (final i in detayIsletmeleri) {
    final g = ip[i];
    if (g == null || g.isEmpty) continue;
    toplam += g.values.fold(0.0, (a, b) => a + b);
    final kisa = i.split(' ').first;
    parcalar.add('$kisa: ${g.entries.map((e) => '${e.key} ${e.value.round()}').join(', ')}');
  }
  return (toplam: toplam, aciklama: parcalar.isEmpty ? 'Kayıp yok' : parcalar.join(' · '));
}
