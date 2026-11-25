// Tarla haritası (KMZ) ekiliş verisi ve tarım icmaliyle karşılaştırma.
// Kaynak: Google Earth "Yerlerim" KMZ dosyasından üretilen assets/veri/tarla_*.json
// (araclar/tarla). KVKK: kişi adı içermez.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../bicim.dart';
import 'kategori.dart';
import 'model.dart';

class TarlaParsel {
  const TarlaParsel({required this.ad, required this.tip, required this.urunler, this.beyan, this.olculen,
      this.etiket = '', this.not = '', this.koord = const [], this.bolme = const [], this.baglar = const [],
      this.cesitler = const [], this.bolgeler = const []});
  final String ad, tip, etiket, not;
  final List<(String, double)> urunler;

  /// Parçalara bölünmüş parselde elle çizilen ayırma çizgileri: (açı°, konum %).
  final List<(double, double)> bolme;

  /// Parçalara bölünmüş parselde, başka parsele bağlanan parçaların hedef parseli (parça sırasıyla; null: bağlı değil).
  final List<String?> baglar;

  String? bag(int i) => i < baglar.length ? baglar[i] : null;

  /// Ekilen tohum / çeşit adı (ürün sırasıyla; null: girilmemiş).
  final List<String?> cesitler;
  String? cesit(int i) => i < cesitler.length && (cesitler[i] ?? '').isNotEmpty ? cesitler[i] : null;

  /// Parsel içinde çizilen bölgeler; ürünler: önce her bölge, sonda parselin kalanı.
  final List<ParselBolge> bolgeler;
  final double? beyan, olculen;
  final List<(double, double)> koord;

  /// Yeni sezonda henüz ürün girilmemiş parsel.
  bool get girilmedi => tip == 'girilmedi';

  String get urunYazi => urunler.isEmpty
      ? (tip == 'bos' ? 'Boş alan' : 'Ürün belirtilmemiş')
      : [
          for (final (i, u) in urunler.indexed)
            '${u.$1}${cesit(i) == null ? '' : ' (${cesit(i)})'}${u.$2 > 0 ? ' ${_s(u.$2)} da' : ''}'
                '${bag(i) == null ? '' : ' → ${bag(i)}'}'
        ].join(' + ');

  /// Yalnızca ekili ürün cinsleri (haritadaki dekarlar esas alınmaz).
  String get urunCinsi => urunler.isEmpty
      ? (tip == 'bos' ? 'Boş alan' : (girilmedi ? 'Girilmedi' : 'Ürün belirtilmemiş'))
      : {for (final u in urunler) u.$1}.join(' + ');

  /// Ölçülen alanın beyandan farkı (%), anlamlı değilse null.
  double? get olcumFarki =>
      (beyan ?? 0) > 0 && olculen != null ? (olculen! - beyan!) / beyan! * 100 : null;

  static TarlaParsel oku(Map<String, dynamic> j) => TarlaParsel(
        ad: j['ad'] ?? '',
        tip: j['tip'] ?? '',
        // KMZ'den yalnızca ürün cinsi gelir (dekar yok); eski biçim [ad, da] de okunur.
        urunler: [
          for (final u in (j['urunler'] as List? ?? []))
            u is List ? ((u[0] as String), (u.length > 1 ? (u[1] as num).toDouble() : 0.0)) : ('$u', 0.0)
        ],
        beyan: (j['beyan'] as num?)?.toDouble(),
        olculen: (j['olculen'] as num?)?.toDouble(),
        etiket: j['etiket'] ?? '',
        not: j['not_'] ?? '',
        koord: [for (final c in (j['koord'] as List? ?? [])) ((c[0] as num).toDouble(), (c[1] as num).toDouble())],
        cesitler: [for (final c in (j['cesitler'] as List? ?? [])) c as String?],
        bolgeler: [
          for (final b in (j['bolgeler'] as List? ?? []))
            if (b case [final String t, final List v]) (t, [for (final x in v) (x as num).toDouble()])
        ],
      );
}

/// KMZ'deki görsel öğe: kuyu, direk, enerji hattı (hat/og), pivot merkez çizgisi, nokta.
class TarlaGorsel {
  const TarlaGorsel({required this.tur, this.ad = '', this.koord = const []});
  final String tur, ad;
  final List<(double, double)> koord;
  bool get cizgi => tur == 'hat' || tur == 'og' || tur == 'pivot';

  static TarlaGorsel oku(Map<String, dynamic> j) => TarlaGorsel(
        tur: j['tur'] ?? '',
        ad: j['ad'] ?? '',
        koord: [for (final c in (j['koord'] as List? ?? [])) ((c[0] as num).toDouble(), (c[1] as num).toDouble())],
      );
}

class TarlaCiftlik {
  const TarlaCiftlik(
      {required this.ad, required this.parseller, this.tesis = const {}, this.notlar = const [], this.gorseller = const []});
  final String ad;
  final List<TarlaParsel> parseller;
  final List<TarlaGorsel> gorseller;
  final Map<String, dynamic> tesis;
  final List<String> notlar;

  /// Haritada ekili ürün cinsleri (ortak adlarla).
  Set<String> get urunCinsleri => {for (final p in parseller) for (final u in p.urunler) urunAnahtari(u.$1)};

  Map<String, double> get urunToplami {
    final m = <String, double>{};
    for (final p in parseller) {
      for (final u in p.urunler) {
        m.update(urunAnahtari(u.$1), (v) => v + u.$2, ifAbsent: () => u.$2);
      }
    }
    return m;
  }
}

class TarlaSezonu {
  const TarlaSezonu(
      {required this.sezon, required this.kaynak, required this.tarih, required this.ciftlikler, this.onceki, this.sonraki, this.giris = false,
      this.tur = 'kmz'});

  /// Paket dosyasının türü: 'kmz' (esas harita), 'katman' (esas parsellerin üzerine o sezonun KMZ ürünleri),
  /// 'ayri' (parsel düzeni farklı eski sezon, kendi çizimleriyle).
  final String tur;
  final String sezon, kaynak, tarih;
  final List<TarlaCiftlik> ciftlikler;

  /// Haritadan girilen yeni sezonda, çizimlerin alındığı önceki sezon.
  final TarlaSezonu? onceki;

  /// İlk sezonda münavebe karşılaştırması için bir sonraki sezon.
  final TarlaSezonu? sonraki;

  /// Ürün ve alanları haritadan girilen sezon (2024-2025, 2026-2027).
  final bool giris;

  /// Sezonun üretim yılı ("2026-2027" → "2027").
  String get uretimYili => sezon.contains('-') ? sezon.split('-').last : sezon;

  static TarlaSezonu json(Map<String, dynamic> j) => TarlaSezonu(
        sezon: j['sezon'] ?? '',
        kaynak: j['kaynak'] ?? '',
        tarih: j['tarih'] ?? '',
        tur: j['tur'] ?? 'kmz',
        ciftlikler: [
          for (final c in (j['ciftlikler'] as List? ?? []))
            TarlaCiftlik(
              ad: c['ad'] ?? '',
              parseller: [for (final p in (c['parseller'] as List? ?? [])) TarlaParsel.oku(p)],
              tesis: Map<String, dynamic>.from(c['tesis'] ?? {}),
              notlar: [for (final n in (c['notlar'] as List? ?? [])) '$n'],
              gorseller: [for (final g in (c['gorseller'] as List? ?? [])) TarlaGorsel.oku(Map<String, dynamic>.from(g))],
            ),
        ],
      );

  static Future<List<TarlaSezonu>> yukle() async {
    final l = <TarlaSezonu>[];
    for (final a in tarlaSezonDosyalari) {
      try {
        l.add(TarlaSezonu.json(jsonDecode(await rootBundle.loadString(a))));
      } catch (_) {}
    }
    return l;
  }
}

/// Paketlenmiş sezon dosyaları (yeniden eskiye).
const tarlaSezonDosyalari = [
  'assets/veri/tarla_2025_2026.json',
  // Yerlerim 24.11.2026 GÜNCEL.kmz: sezon katmanları (araclar/tarla/kmz_sezonlar.py)
  'assets/veri/tarla_2023_2024.json',
  'assets/veri/tarla_2024_2025.json',
  'assets/veri/tarla_2026_2027.json',
];

String _s(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1).replaceAll('.', ',');

/// Ürün adlarını karşılaştırma için ortak ada çevirir.
String urunAnahtari(String u) {
  final k = kucuk(u);
  if (k.contains('2. ürün')) return 'Silajlık mısır (2. ürün)';
  if (k.contains('pancar')) return 'Şeker pancarı';
  if (k.contains('dane mısır') || k.contains('danelik mısır')) return 'Dane mısır';
  if (k.contains('mısır')) return 'Silajlık mısır';
  if (k.contains('çerez')) return 'Çerezlik ayçiçeği';
  if (k.contains('ayçiçe')) return 'Yağlık ayçiçeği';
  if (k.contains('kanola') || k.contains('kolza')) return 'Kanola (kolza)';
  if (k.contains('sorgum')) return 'Silajlık sorgum';
  if (k.contains('buğday')) return 'Buğday';
  if (k.contains('arpa')) return 'Arpa';
  if (k.contains('yonca')) return 'Yonca';
  if (k.contains('patates')) return 'Patates';
  if (k.contains('soğan')) return 'Soğan';
  if (k.contains('tritikale')) return 'Tritikale';
  if (k.contains('deneme')) return 'Deneme alanı';
  if (k.contains('ıslah')) return 'Islah edilen alan';
  if (k.contains('ağaç')) return 'Ağaçlık alan';
  if (k.contains('boş alan') || k == 'boş') return 'Boş alan';
  if (k.contains('nadas')) return 'Nadas';
  return u;
}

String ciftlikAnahtari(String c) {
  final k = kucuk(c);
  if (k.contains('ormanlık')) return 'taşağıl'; // Ormanlık, Taşağıl'a ait alan
  for (final a in ['şekersüt', 'aslım', 'taşağıl', 'fidanlık', 'pangev', 'pankent']) {
    if (k.contains(a)) return a;
  }
  return k;
}

/// Bir parseli anan tarım icmali kayıtları ("5. pivot", "5.pivot", "1. parsel").
List<TarimKaydi> parselKayitlari(TarlaCiftlik c, TarlaParsel p, List<TarimKaydi> tarim) {
  final m = RegExp(r'^(\d+)\.\s*(pivot|parsel)').firstMatch(kucuk(p.ad));
  if (m == null) return const [];
  final re = RegExp('(^|[^0-9])${m.group(1)}\\.\\s*${m.group(2)}');
  return [
    for (final t in tarim)
      if (ciftlikAnahtari(t.ciftlik) == ciftlikAnahtari(c.ad) && re.hasMatch(kucuk(t.faaliyet))) t
  ]..sort((a, b) => b.tarih.compareTo(a.tarih));
}

/// ÇKS'de bu tarla parseline eşleştirilmiş kayıtlar.
List<CksParsel> parselCks(TarlaCiftlik c, TarlaParsel p, List<CksParsel> cks, String sezon) => [
      for (final x in cks)
        if ((x.sezon.isEmpty || x.sezon == sezon) &&
            ciftlikAnahtari(x.ciftlik) == ciftlikAnahtari(c.ad) &&
            x.eslesen.split(',').any((e) => kucuk(e).trim() == kucuk(p.ad).trim()))
          x
    ];


/// Ekim planı dosyasında verisi olan yıllar (küçükten büyüğe).
List<String> planYillari(List<EkimPlanSatir> l) => ({for (final x in l) x.yil}.toList()..sort());


/// Karşılaştırma satırı için geçerli (aktif) düzeltme.
EkimDuzeltme? aktifDuzeltme(List<EkimDuzeltme> l, String sezon, String ciftlik, String urun) {
  EkimDuzeltme? d;
  for (final x in l) {
    if (x.aktif &&
        (x.sezon.isEmpty || x.sezon == sezon) &&
        ciftlikAnahtari(x.ciftlik) == ciftlikAnahtari(ciftlik) &&
        (x.urun.contains(':') || urun.contains(':') ? x.urun == urun : urunAnahtari(x.urun) == urunAnahtari(urun))) {
      d = x;
    }
  }
  return d;
}


// ---------------------------------------------------------------------------
// Excel esaslı karşılaştırma. Alanlar Excel dosyalarından alınır:
//  • Ekim planı (2026-2027 Ekim Planı Tarımsal Faaliyetler › Ekim_Alanları plan)
//  • Resmî parsel kayıtları (2026-2027 Tarımsal Faaliyet › PARSEL)
// Haritadan yalnızca ekili ürün cinsi alınır; haritadaki dekarlar kullanılmaz.

bool alanYakin(double a, double b) => (a - b).abs() <= 10 || (a - b).abs() <= math.max(a, b) * 0.03;

/// Excel ekim planına göre bir çiftliğin ürün alanları (ürün → da).
Map<String, double> excelAlanlari(List<EkimSatir> ekim, String ciftlik) {
  final m = <String, double>{};
  for (final e in ekim) {
    if (ciftlikAnahtari(e.ciftlik) != ciftlikAnahtari(ciftlik) || (e.plan ?? 0) <= 0) continue;
    m.update(urunAnahtari(e.urun), (v) => v + e.plan!, ifAbsent: () => e.plan!);
  }
  return m;
}

Map<String, double> _resmiAlanlar(List<ResmiParsel> l, String ciftlik) {
  final m = <String, double>{};
  for (final x in l) {
    if (ciftlikAnahtari(x.ciftlik) != ciftlikAnahtari(ciftlik) || x.alan == null) continue;
    m.update(urunAnahtari(x.urun), (v) => v + x.alan!, ifAbsent: () => x.alan!);
  }
  return m;
}

/// Bir çiftlik/ürün için kaynaklar: Excel planı (esas), Excel PARSEL, ÇKS, haritada var mı.
class UrunSatiri {
  const UrunSatiri(this.ciftlik, this.urun, {this.excel, this.resmi, this.cks, this.haritada = false, this.ekilen});
  final String ciftlik, urun;
  final double? excel, resmi, cks, ekilen;
  final bool haritada;

  /// Esas alınan alan: Excel ekim planı, yoksa Excel PARSEL kaydı.
  double? get esas => (excel ?? 0) > 0 ? excel : ((resmi ?? 0) > 0 ? resmi : null);

  double? farki(double? x) => esas == null || x == null ? null : x - esas!;

  bool get cksFarkli => esas != null && cks != null && !alanYakin(cks!, esas!);
  bool get resmiFarkli => (excel ?? 0) > 0 && resmi != null && !alanYakin(resmi!, excel!);
  bool get excelYok => esas == null;
  bool get haritadaYok => esas != null && !haritada;

  bool get uyumlu => !cksFarkli && !resmiFarkli && !excelYok && !haritadaYok;

  /// Bulguların kısa açıklaması.
  List<String> get bulgular => [
        if (excelYok)
          [if (haritada) 'haritada', if (cks != null) "ÇKS'de"].join(' ve ') + " ekili, Excel dosyalarında kaydı yok",
        if (haritadaYok) "Excel'de ${sayiKisa(esas!)} da, haritada bu ürün yok",
        if (resmiFarkli) 'Excel PARSEL kaydı ekim planından ${_isaretli(resmi! - excel!)} da farklı',
        if (cksFarkli) "ÇKS Excel'den ${_isaretli(cks! - esas!)} da farklı",
      ];
}

String sayiKisa(double v) => sayi(v);
String _isaretli(double v) => '${v >= 0 ? '+' : '−'}${sayi(v.abs())}';

/// Haritadaki çiftlikler için Excel esaslı ürün tablosu.
List<UrunSatiri> excelKarsilastir(TarlaSezonu s, List<EkimSatir> ekim, List<ResmiParsel> resmi, List<CksParsel> cks) {
  final out = <UrunSatiri>[];
  for (final c in s.ciftlikler) {
    final e = excelAlanlari(ekim, c.ad), r = _resmiAlanlar(resmi, c.ad), h = c.urunCinsleri;
    final k = <String, double>{};
    for (final x in cks) {
      if (x.sezon != s.sezon || ciftlikAnahtari(x.ciftlik) != ciftlikAnahtari(c.ad) || x.alan == null) continue;
      k.update(urunAnahtari(x.urun), (v) => v + x.alan!, ifAbsent: () => x.alan!);
    }
    final ekilen = <String, double>{};
    for (final x in ekim) {
      if (ciftlikAnahtari(x.ciftlik) != ciftlikAnahtari(c.ad) || x.ekilen == null) continue;
      ekilen.update(urunAnahtari(x.urun), (v) => v + x.ekilen!, ifAbsent: () => x.ekilen!);
    }
    for (final u in {...e.keys, ...r.keys, ...k.keys, ...h}) {
      out.add(UrunSatiri(c.ad, u, excel: e[u], resmi: r[u], cks: k[u], haritada: h.contains(u), ekilen: ekilen[u]));
    }
  }
  return out;
}


// ---------------------------------------------------------------------------
// Yeni sezon girişi: önceki sezonun parsel çizimleri üzerine, haritadan girilen
// ürün ve alanlar (Sezon_Parselleri). Girilmemiş parseller "Girilmedi" görünür.

/// "2025-2026" → "2026-2027".
String sonrakiSezon(String s) {
  final m = RegExp(r'^(\d{4})-(\d{4})$').firstMatch(s);
  return m == null ? '$s (yeni)' : '${int.parse(m[1]!) + 1}-${int.parse(m[2]!) + 1}';
}

/// Bir parselin bir sezondaki geçerli girişi (yoksa null).
SezonParsel? parselGirisi(List<SezonParsel> l, String sezon, String ciftlik, String parsel) {
  // Sıradaki son kayıt geçerlidir: sonraki "Geri alındı" kaydı önceki girişi iptal eder.
  SezonParsel? d;
  for (final x in l) {
    if (x.sezon == sezon && ciftlikAnahtari(x.ciftlik) == ciftlikAnahtari(ciftlik) &&
        kucuk(x.parsel).trim() == kucuk(parsel).trim()) {
      if (x.aktif) {
        d = x;
      } else if (x.durum == 'Geri alındı') {
        d = null;
      }
    }
  }
  return d;
}

/// Parsel içinde çizilen bölge (yüzdeler parselin çevreleyen kutusuna göre, 0–100):
/// ('D', [x1, y1, x2, y2]) dikdörtgen, ('C', [mx, my, rx, ry]) daire/elips, ('P', [x, y, x, y, …]) çokgen.
typedef ParselBolge = (String, List<double>);

/// Sezon_Parselleri "Ürün" sütununun içeriği.
/// - "Arpa" → tek ürün (alan "Alan (da)" sütununda)
/// - "Arpa:120+Buğday:120" → parsel parçalara bölünmüş
/// - "Arpa@7. pivot" → bu parsel "7. pivot" ile birleştirilmiş (alan ana parselde)
class ParselIcerik {
  const ParselIcerik(this.parcalar,
      {this.birlesik, this.cizgiler = const [], this.baglar = const [], this.cesitler = const [], this.bolgeler = const []});

  /// Parsel içinde çizilen bölgeler ("…/BD10,10,40,40;C60,50,15,20"); parçalar: bölgeler, sonra kalan.
  final List<ParselBolge> bolgeler;

  /// Tohum / çeşit adı ("Buğday#Altındane"); parça sırasıyla, null: girilmemiş.
  final List<String?> cesitler;
  String? cesit(int i) => i < cesitler.length && (cesitler[i] ?? '').isNotEmpty ? cesitler[i] : null;

  /// "Buğday#Altındane" → ("Buğday", "Altındane").
  static (String, String?) _urunCesit(String s) {
    final i = s.indexOf('#');
    return i < 0 ? (s.trim(), null) : (s.substring(0, i).trim(), s.substring(i + 1).trim());
  }

  /// Tek ürün kaydı: "Buğday" ya da "Buğday#Altındane".
  static String urunMetni(String urun, String? cesit) =>
      cesit == null || cesit.trim().isEmpty ? urun : '$urun#${cesit.trim()}';
  final List<(String, double?)> parcalar;

  /// Parçanın bağlandığı başka parsel ("Arpa>1. parsel:12"); parça sırasıyla, null: bağlı değil.
  final List<String?> baglar;
  String? bag(int i) => i < baglar.length ? baglar[i] : null;

  /// Haritada çizilen ayırma çizgileri: (açı°, konum %), "…/37,52;120,70" ekinden.
  final List<(double, double)> cizgiler;

  /// Birleştirildiği ana parsel (bu parsel ona bağlı).
  final String? birlesik;
  bool get bolunmus => parcalar.length > 1;
  String get urun => parcalar.isEmpty ? '' : parcalar.first.$1;

  static ParselIcerik oku(String urun) {
    final t = urun.trim();
    final at = t.indexOf('@');
    if (at > 0) {
      final (u, c) = _urunCesit(t.substring(0, at));
      return ParselIcerik([(u, null)], birlesik: t.substring(at + 1).trim(), cesitler: [c]);
    }
    if (!t.contains(':')) {
      final (u, c) = _urunCesit(t);
      return ParselIcerik([(u, null)], cesitler: [c]);
    }
    final bolu = t.indexOf('/');
    final govde = bolu < 0 ? t : t.substring(0, bolu);
    final ek = bolu < 0 ? '' : t.substring(bolu + 1);
    final bolgeler = <ParselBolge>[
      if (ek.startsWith('B'))
        for (final b in ek.substring(1).split(';'))
          if (b.length > 1 && 'DCP'.contains(b[0]))
            (b[0], [for (final x in b.substring(1).split(',')) if (double.tryParse(x) case final d?) d]),
    ];
    final cizgiler = <(double, double)>[
      if (bolu >= 0 && !ek.startsWith('B'))
        for (final c in ek.split(';'))
          if (c.split(',') case [final a, final k])
            if (double.tryParse(a) case final aa?)
              if (double.tryParse(k) case final kk?) (aa, kk),
    ];
    final parcalar = <(String, double?)>[];
    final baglar = <String?>[];
    final cesitler = <String?>[];
    for (final x in govde.split('+')) {
      if (x.trim().isEmpty) continue;
      final ad = x.split(':').first.trim();
      final ok = ad.indexOf('>');
      final (u, c) = _urunCesit(ok > 0 ? ad.substring(0, ok) : ad);
      parcalar.add((u, x.contains(':') ? double.tryParse(x.split(':').last.trim().replaceAll(',', '.')) : null));
      baglar.add(ok > 0 ? ad.substring(ok + 1).trim() : null);
      cesitler.add(c);
    }
    return ParselIcerik(parcalar,
        cizgiler: cizgiler,
        bolgeler: bolgeler,
        baglar: baglar.any((b) => b != null) ? baglar : const [],
        cesitler: cesitler.any((c) => c != null) ? cesitler : const []);
  }

  /// Bölünmüş parsel için kayıt metni ("Arpa:120+Buğday:120").
  static String bolunmusMetin(List<(String, double)> l,
          [List<(double, double)> cizgiler = const [],
          List<String?> baglar = const [],
          List<String?> cesitler = const [],
          List<ParselBolge> bolgeler = const []]) =>
      [
        for (final (i, x) in l.indexed)
          '${urunMetni(x.$1, i < cesitler.length ? cesitler[i] : null)}'
              '${i < baglar.length && baglar[i] != null ? '>${baglar[i]}' : ''}:${x.$2 % 1 == 0 ? x.$2.toInt() : x.$2}'
      ].join('+') +
      (bolgeler.isNotEmpty
          ? '/B${bolgeler.map((b) => '${b.$1}${b.$2.map((x) => x.round()).join(',')}').join(';')}'
          : cizgiler.isEmpty
              ? ''
              : '/${cizgiler.map((c) => '${c.$1.round()},${c.$2.round()}').join(';')}');
}

/// "2025-2026" → "2024-2025".
String oncekiSezon(String s) {
  final m = RegExp(r'^(\d{4})-(\d{4})$').firstMatch(s);
  return m == null ? '$s (önceki)' : '${int.parse(m[1]!) - 1}-${int.parse(m[2]!) - 1}';
}

/// [taban] sezonunun parsel çizimleriyle, ürün ve alanları haritadan girilen sezon.
/// [sezon] verilmezse bir sonraki sezon olur; [onceki] münavebe karşılaştırması içindir.
TarlaSezonu girisSezonu(TarlaSezonu taban, List<SezonParsel> l,
    {String? sezon, TarlaSezonu? onceki, bool ilkSezon = false, TarlaSezonu? sonraki, TarlaSezonu? katman}) {
  final ad = sezon ?? sonrakiSezon(taban.sezon);
  final once = ilkSezon ? null : (onceki ?? taban);
  TarlaParsel? kmzde(String cf, String p) {
    for (final c in katman?.ciftlikler ?? const <TarlaCiftlik>[]) {
      if (c.ad != cf) continue;
      for (final x in c.parseller) {
        if (x.ad == p) return x;
      }
    }
    return null;
  }

  return TarlaSezonu(
    sezon: ad,
    kaynak: katman == null ? 'haritadan girilen bilgiler' : '${katman.kaynak} + haritadan girilen bilgiler',
    tur: katman?.tur ?? 'giris',
    tarih: '',
    onceki: once,
    sonraki: sonraki,
    giris: true,
    ciftlikler: [
      for (final c in taban.ciftlikler)
        TarlaCiftlik(ad: c.ad, tesis: c.tesis, gorseller: c.gorseller, parseller: [
          for (final p in c.parseller)
            if (parselGirisi(l, ad, c.ad, p.ad) case final g?)
              _kmzNotu(
                  _girisParseli(p, g, [
                    for (final q in c.parseller)
                      if (parselGirisi(l, ad, c.ad, q.ad) case final h?
                          when q.ad != p.ad && ParselIcerik.oku(h.urun).birlesik == p.ad)
                        q.ad
                  ], gelen: gelenParcalar(l, ad, c, p.ad)),
                  kmzde(c.ad, p.ad))
            else if (kmzde(c.ad, p.ad) case final k? when k.urunler.isNotEmpty)
              TarlaParsel(
                  ad: p.ad,
                  tip: k.tip == 'girilmedi' || k.tip.isEmpty ? 'parsel' : k.tip,
                  urunler: k.urunler,
                  beyan: k.urunler.fold<double>(0, (a, x) => a + x.$2),
                  koord: p.koord,
                  not: k.not,
                  cesitler: k.cesitler,
                  bolgeler: k.bolgeler.length == k.urunler.length - 1 ? k.bolgeler : const [])
            else
              TarlaParsel(
                  ad: p.ad, tip: p.tip == 'diger' || p.tip == 'bos' ? p.tip : 'girilmedi', urunler: const [], koord: p.koord),
        ]),
    ],
  );
}

/// Karar (25.11.2026): KMZ ile farklılıkta uygulama kaydı geçerlidir; KMZ'deki hâl nota eklenmez.
TarlaParsel _kmzNotu(TarlaParsel y, TarlaParsel? k) => y;

/// Başka parsellerden bu parsele bağlanan parçalar: (kaynak parsel, ürün, dekar).
List<(String, String, double)> gelenParcalar(List<SezonParsel> l, String sezon, TarlaCiftlik c, String hedef) => [
      for (final q in c.parseller)
        if (q.ad != hedef)
          if (parselGirisi(l, sezon, c.ad, q.ad) case final h?)
            for (final (i, x) in ParselIcerik.oku(h.urun).parcalar.indexed)
              if (ParselIcerik.oku(h.urun).bag(i) == hedef) (q.ad, x.$1, x.$2 ?? 0),
    ];

TarlaParsel _girisParseli(TarlaParsel p, SezonParsel g, List<String> bagli, {List<(String, String, double)> gelen = const []}) {
  final y = _girisParseliTemel(p, g, bagli);
  if (gelen.isEmpty) return y;
  final ek = gelen.fold<double>(0, (a, x) => a + x.$3);
  return TarlaParsel(
      ad: y.ad, tip: y.tip, urunler: y.urunler, beyan: (y.beyan ?? 0) + ek, koord: y.koord, bolme: y.bolme, baglar: y.baglar,
      cesitler: y.cesitler, bolgeler: y.bolgeler,
      not: [
        if (y.not.isNotEmpty) y.not,
        for (final x in gelen) '${x.$1} parselinden bağlı parça: ${x.$2} ${x.$3 % 1 == 0 ? x.$3.toInt() : x.$3} da',
      ].join(' · '));
}

TarlaParsel _girisParseliTemel(TarlaParsel p, SezonParsel g, List<String> bagli) {
  final ic = ParselIcerik.oku(g.urun);
  if (ic.birlesik != null) {
    // Alan ana parselde sayılır; burada yalnızca ürün cinsi görünür.
    return TarlaParsel(ad: p.ad, tip: 'ekili', urunler: [(ic.urun, 0)], koord: p.koord, not: '${ic.birlesik} ile birleştirildi',
        cesitler: ic.cesitler);
  }
  if (ic.bolunmus) {
    final l = [for (final x in ic.parcalar) (x.$1, x.$2 ?? 0.0)];
    // Başka parsele bağlanan parçanın alanı o parselde sayılır.
    var giden = 0.0;
    for (final (i, x) in l.indexed) {
      if (ic.bag(i) != null) giden += x.$2;
    }
    final kendi = l.fold<double>(0, (a, x) => a + x.$2) - giden;
    return TarlaParsel(ad: p.ad, tip: 'ekili', urunler: l, beyan: giden > 0 ? kendi : (g.alan ?? kendi),
        koord: p.koord, not: 'Parçalara bölündü', bolme: ic.cizgiler.length == l.length - 1 ? ic.cizgiler : const [],
        baglar: ic.baglar, cesitler: ic.cesitler,
        bolgeler: ic.bolgeler.length == l.length - 1 ? ic.bolgeler : const []);
  }
  return TarlaParsel(ad: p.ad, tip: 'ekili', urunler: [(ic.urun, g.alan ?? 0)], beyan: g.alan, koord: p.koord,
      cesitler: ic.cesitler,
      not: bagli.isEmpty ? '' : '${bagli.join(', ')} ile birleştirildi (alan toplamdır)');
}

/// Önceki sezonda aynı parselde ekili ürünler (münavebe için).
List<String> oncekiUrunler(TarlaSezonu s, String ciftlik, String parsel) => sezonUrunleri(s.onceki, ciftlik, parsel);

/// Bir sezonda bir parselde ekili ürünler.
List<String> sezonUrunleri(TarlaSezonu? o, String ciftlik, String parsel) {
  if (o == null) return const [];
  for (final c in o.ciftlikler) {
    if (ciftlikAnahtari(c.ad) != ciftlikAnahtari(ciftlik)) continue;
    for (final p in c.parseller) {
      if (p.ad == parsel) return [for (final u in p.urunler) urunAnahtari(u.$1)];
    }
  }
  return const [];
}

/// Excel ekim planında bir yılın çiftlik/ürün alanları.
Map<String, double> yilPlani(List<EkimPlanSatir> l, String yil, String ciftlik) {
  final m = <String, double>{};
  for (final x in l) {
    if (x.yil != yil || ciftlikAnahtari(x.ciftlik) != ciftlikAnahtari(ciftlik) || x.plan <= 0) continue;
    m.update(urunAnahtari(x.urun), (v) => v + x.plan, ifAbsent: () => x.plan);
  }
  return m;
}

/// Haritadan seçilebilen ürünler.
const secilebilirUrunler = [
  // Hububat
  'Buğday', 'Arpa', 'Tritikale', 'Çavdar', 'Yulaf', 'Dane mısır',
  // Endüstri ve yağ bitkileri
  'Şeker pancarı', 'Patates', 'Soğan', 'Yağlık ayçiçeği', 'Çerezlik ayçiçeği', 'Kanola (kolza)', 'Aspir', 'Soya',
  // Baklagiller
  'Nohut', 'Kuru fasulye', 'Mercimek',
  // Yem bitkileri
  'Silajlık mısır', 'Silajlık mısır (2. ürün)', 'Yonca', 'Korunga', 'Fiğ', 'Silajlık sorgum', 'Sudan otu',
  // Baharat
  'Kimyon', 'Kişniş',
  // Ekim dışı alanlar
  'Nadas', 'Deneme alanı', 'Islah edilen alan', 'Ağaçlık alan', 'Boş alan',
];

/// Ekim dışı alan türleri: münavebe uyarısı verilmez.
const ekimDisiAlanlar = {'Nadas', 'Deneme alanı', 'Islah edilen alan', 'Ağaçlık alan', 'Boş alan'};
bool ekimDisi(String urun) => ekimDisiAlanlar.contains(urunAnahtari(urun));


/// Tarla Haritası bölümleri: 2024-2025 (haritadan giriş), KMZ sezonu (2025-2026),
/// 2026-2027 (haritadan giriş). Hepsi KMZ sezonunun parsel çizimlerini kullanır.
List<TarlaSezonu> tarlaSezonlari(List<TarlaSezonu> paket, List<SezonParsel> l, {List<ParselSinir> sinirlar = const []}) {
  final esaslar = paket.where((k) => k.tur == 'kmz').toList();
  if (esaslar.isEmpty) return const [];
  // Yeniden çizilen sınırlar yalnızca esas haritaya uygulanır (katman sezonları esas çizimleri kullanır).
  final kmz = sinirlar.isEmpty ? esaslar.first : sinirUygula(esaslar.first, sinirlar);
  TarlaSezonu? bul(String sezon, String tur) => paket.where((k) => k.sezon == sezon && k.tur == tur).firstOrNull;
  final s1 = oncekiSezon(kmz.sezon), s3 = sonrakiSezon(kmz.sezon);
  final ayri0 = bul(oncekiSezon(s1), 'ayri');
  // Eski sezonun kendi sınır kayıtları ("2023-2024|parsel") yalnızca o sezona uygulanır.
  final ayri = ayri0 == null || sinirlar.isEmpty ? ayri0 : sinirUygula(ayri0, sinirlar, sezon: ayri0.sezon);
  final k1 = bul(s1, 'katman'), k3 = bul(s3, 'katman');
  // Parsel düzeni farklı en eski sezon (2023-2024): kendi çizimleri, uygulamadan girilen kayıtlar üzerine.
  TarlaSezonu? s0;
  if (ayri != null) {
    final taslak = girisSezonu(kmz, l, sezon: s1, ilkSezon: true, katman: k1);
    s0 = girisSezonu(ayri, l, sezon: ayri.sezon, ilkSezon: true, sonraki: taslak, katman: ayri);
  }
  final eski = girisSezonu(kmz, l, sezon: s1, ilkSezon: s0 == null, onceki: s0, sonraki: s0 == null ? kmz : null, katman: k1);
  final orta = [
    for (final (i, k) in esaslar.indexed) kmzUzerine(i == 0 ? kmz : k, l, onceki: i == 0 ? eski : null)
  ];
  return [if (s0 != null) s0, eski, ...orta, girisSezonu(kmz, l, onceki: orta.first, katman: k3)];
}

/// Geçerli parsel sınırları: (çiftlik, parsel) → (boylam, enlem) noktaları. Son "Aktif" kayıt geçerlidir,
/// "Geri alındı" kaydı parseli KMZ sınırına döndürür.
Map<(String, String), List<(double, double)>> gecerliSinirlar(List<ParselSinir> l) {
  final m = <(String, String), List<(double, double)>>{};
  for (final x in l) {
    final k = (x.ciftlik, x.parsel);
    if (x.aktif && x.koord.length > 2) {
      m[k] = _sinirOnbellek.putIfAbsent(
          '${x.ciftlik}|${x.parsel}|${x.koord.length}|${x.koord.first}|${x.koord.last}', () => x.koord);
    } else if (x.durum == 'Geri alındı') {
      m.remove(k);
    }
  }
  return m;
}

// Aynı sınır her yenilemede aynı liste olsun (harita yakınlaştırması sıfırlanmasın).
final _sinirOnbellek = <String, List<(double, double)>>{};

/// Yeniden çizilen sınırları KMZ parsellerine uygular; KMZ'de olmayan parseller haritaya eklenir.
/// [sezon] verilirse yalnızca o sezona ait kayıtlar ("2023-2024|parsel adı") uygulanır (parsel düzeni farklı
/// eski sezon); verilmezse sezonsuz kayıtlar (tüm sezonların esas haritası).
TarlaSezonu sinirUygula(TarlaSezonu kmz, List<ParselSinir> l, {String? sezon}) {
  final m = <(String, String), List<(double, double)>>{
    for (final e in gecerliSinirlar(l).entries)
      if (sezon == null && !e.key.$2.contains('|'))
        e.key: e.value
      else if (sezon != null && e.key.$2.startsWith('$sezon|'))
        (e.key.$1, e.key.$2.substring(sezon.length + 1)): e.value,
  };
  if (m.isEmpty) return kmz;
  TarlaParsel yeni(TarlaParsel p, List<(double, double)> k) => TarlaParsel(
      ad: p.ad, tip: p.tip, urunler: p.urunler, beyan: p.beyan, olculen: p.olculen, etiket: p.etiket, not: p.not,
      koord: k, bolme: p.bolme, baglar: p.baglar, cesitler: p.cesitler, bolgeler: p.bolgeler);
  return TarlaSezonu(
    sezon: kmz.sezon,
    kaynak: kmz.kaynak,
    tarih: kmz.tarih,
    onceki: kmz.onceki,
    sonraki: kmz.sonraki,
    giris: kmz.giris,
    tur: kmz.tur,
    ciftlikler: [
      for (final c in kmz.ciftlikler)
        TarlaCiftlik(ad: c.ad, tesis: c.tesis, notlar: c.notlar, gorseller: c.gorseller, parseller: [
          for (final p in c.parseller)
            if (m[(c.ad, p.ad)] case final k?) yeni(p, k) else p,
          for (final e in m.entries)
            if (e.key.$1 == c.ad && !c.parseller.any((p) => p.ad == e.key.$2))
              TarlaParsel(ad: e.key.$2, tip: 'girilmedi', urunler: const [], koord: e.value, not: 'Haritadan eklendi'),
        ]),
    ],
  );
}

/// Çok yıllık ürünler: üst üste ekim münavebe hatası sayılmaz, kaçıncı yılı gösterilir.
const cokYillikUrunler = {'Yonca', 'Korunga', 'Çayır'};
bool cokYillik(String urun) => cokYillikUrunler.contains(urunAnahtari(urun));

/// Parselde [urun] bu sezonla birlikte üst üste kaç sezondur ekili: (yıl, kayıtların başına ulaşıldı mı).
(int, bool) ardisikYil(TarlaSezonu s, String ciftlik, String parsel, String urun) {
  var n = 0;
  TarlaSezonu? o = s;
  while (o != null && sezonUrunleri(o, ciftlik, parsel).contains(urunAnahtari(urun))) {
    n++;
    o = o.onceki;
  }
  return (n, o == null);
}

/// KMZ sezonunda haritadan yapılan bölme / ayırma çizgisi kayıtları (aynı sezon için)
/// KMZ parselinin üzerine uygulanır; kaydı olmayan parsel KMZ'deki gibi kalır.
TarlaSezonu kmzUzerine(TarlaSezonu kmz, List<SezonParsel> l, {TarlaSezonu? onceki}) {
  return TarlaSezonu(
    sezon: kmz.sezon,
    kaynak: kmz.kaynak,
    tarih: kmz.tarih,
    onceki: onceki ?? kmz.onceki,
    sonraki: kmz.sonraki,
    giris: kmz.giris,
    ciftlikler: [
      for (final c in kmz.ciftlikler)
        TarlaCiftlik(ad: c.ad, tesis: c.tesis, notlar: c.notlar, gorseller: c.gorseller, parseller: [
          for (final p in c.parseller)
            if (parselGirisi(l, kmz.sezon, c.ad, p.ad) case final g? when ParselIcerik.oku(g.urun).bolunmus || p.girilmedi)
              () {
                final y = _girisParseli(p, g, const []);
                return TarlaParsel(ad: p.ad, tip: p.girilmedi ? y.tip : p.tip, urunler: y.urunler, beyan: p.beyan ?? y.beyan, olculen: p.olculen,
                    etiket: p.etiket, not: p.not, koord: p.koord, bolme: y.bolme, baglar: y.baglar, cesitler: y.cesitler,
                    bolgeler: y.bolgeler);
              }()
            else
              p,
        ]),
    ],
  );
}

/// 2025 üretim yılı (2024-2025 sezonu) ekilen alanları. Kaynak: 2026-2027 Tarımsal Faaliyet
/// › ÇİFTLİK BAZINDA ("2025 YILI ÇİFTLİKLER TARIMSAL ÜRETİMİ"), EKİLEN DEKAR sütunu.
const excel2025 = <(String, String, double)>[
  ('Şekersüt', 'Silajlık mısır', 670), ('Şekersüt', 'Buğday', 1700), ('Şekersüt', 'Şeker pancarı', 700),
  ('Aslım', 'Silajlık mısır', 140), ('Aslım', 'Şeker pancarı', 900), ('Aslım', 'Arpa', 1340), ('Aslım', 'Buğday', 520),
  ('Aslım', 'Tritikale', 200), ('Aslım', 'Yonca', 1360),
  ('Taşağıl', 'Patates', 400), ('Ormanlık', 'Şeker pancarı', 230),
  ('Fidanlık', 'Buğday', 130), ('Fidanlık', 'Arpa', 600),
];

/// Bir sezonun Excel'deki çiftlik/ürün alanları (esas alınan değerler).
Map<String, double> sezonExcel(List<EkimSatir> ekim, List<EkimPlanSatir> plan, TarlaSezonu s, String ciftlik) {
  if (!s.giris) return excelAlanlari(ekim, ciftlik);
  final p = yilPlani(plan, s.uretimYili, ciftlik);
  if (p.isNotEmpty || s.uretimYili != '2025') return p;
  final m = <String, double>{};
  for (final (c, u, a) in excel2025) {
    if (ciftlikAnahtari(c) == ciftlikAnahtari(ciftlik)) m.update(urunAnahtari(u), (v) => v + a, ifAbsent: () => a);
  }
  return m;
}

/// Sezonun Excel kaynağının adı.
String sezonExcelKaynak(TarlaSezonu s) => !s.giris
    ? '2026-2027 Ekim Planı (Excel)'
    : s.uretimYili == '2025'
        ? 'Tarımsal Faaliyet › ÇİFTLİK BAZINDA, 2025 yılı (Excel)'
        : '${s.uretimYili} Excel ekim planı';
