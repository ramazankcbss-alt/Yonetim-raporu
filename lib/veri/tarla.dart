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
      this.etiket = '', this.not = '', this.koord = const [], this.bolme = const [], this.baglar = const []});
  final String ad, tip, etiket, not;
  final List<(String, double)> urunler;

  /// Parçalara bölünmüş parselde elle çizilen ayırma çizgileri: (açı°, konum %).
  final List<(double, double)> bolme;

  /// Parçalara bölünmüş parselde, başka parsele bağlanan parçaların hedef parseli (parça sırasıyla; null: bağlı değil).
  final List<String?> baglar;

  String? bag(int i) => i < baglar.length ? baglar[i] : null;
  final double? beyan, olculen;
  final List<(double, double)> koord;

  /// Yeni sezonda henüz ürün girilmemiş parsel.
  bool get girilmedi => tip == 'girilmedi';

  String get urunYazi => urunler.isEmpty
      ? (tip == 'bos' ? 'Boş alan' : 'Ürün belirtilmemiş')
      : [
          for (final (i, u) in urunler.indexed)
            '${u.$2 > 0 ? '${u.$1} ${_s(u.$2)} da' : u.$1}${bag(i) == null ? '' : ' → ${bag(i)}'}'
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
      {required this.sezon, required this.kaynak, required this.tarih, required this.ciftlikler, this.onceki, this.sonraki, this.giris = false});
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
const tarlaSezonDosyalari = ['assets/veri/tarla_2025_2026.json'];

String _s(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1).replaceAll('.', ',');

/// Ürün adlarını karşılaştırma için ortak ada çevirir.
String urunAnahtari(String u) {
  final k = kucuk(u);
  if (k.contains('2. ürün')) return 'Silajlık mısır (2. ürün)';
  if (k.contains('pancar')) return 'Şeker pancarı';
  if (k.contains('mısır')) return 'Silajlık mısır';
  if (k.contains('buğday')) return 'Buğday';
  if (k.contains('arpa')) return 'Arpa';
  if (k.contains('yonca')) return 'Yonca';
  if (k.contains('patates')) return 'Patates';
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

/// Sezon_Parselleri "Ürün" sütununun içeriği.
/// - "Arpa" → tek ürün (alan "Alan (da)" sütununda)
/// - "Arpa:120+Buğday:120" → parsel parçalara bölünmüş
/// - "Arpa@7. pivot" → bu parsel "7. pivot" ile birleştirilmiş (alan ana parselde)
class ParselIcerik {
  const ParselIcerik(this.parcalar, {this.birlesik, this.cizgiler = const [], this.baglar = const []});
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
    if (at > 0) return ParselIcerik([(t.substring(0, at).trim(), null)], birlesik: t.substring(at + 1).trim());
    if (!t.contains(':')) return ParselIcerik([(t, null)]);
    final bolu = t.indexOf('/');
    final govde = bolu < 0 ? t : t.substring(0, bolu);
    final cizgiler = <(double, double)>[
      if (bolu >= 0)
        for (final c in t.substring(bolu + 1).split(';'))
          if (c.split(',') case [final a, final k])
            if (double.tryParse(a) case final aa?)
              if (double.tryParse(k) case final kk?) (aa, kk),
    ];
    final parcalar = <(String, double?)>[];
    final baglar = <String?>[];
    for (final x in govde.split('+')) {
      if (x.trim().isEmpty) continue;
      final ad = x.split(':').first.trim();
      final ok = ad.indexOf('>');
      parcalar.add((ok > 0 ? ad.substring(0, ok).trim() : ad,
          x.contains(':') ? double.tryParse(x.split(':').last.trim().replaceAll(',', '.')) : null));
      baglar.add(ok > 0 ? ad.substring(ok + 1).trim() : null);
    }
    return ParselIcerik(parcalar, cizgiler: cizgiler, baglar: baglar.any((b) => b != null) ? baglar : const []);
  }

  /// Bölünmüş parsel için kayıt metni ("Arpa:120+Buğday:120").
  static String bolunmusMetin(List<(String, double)> l,
          [List<(double, double)> cizgiler = const [], List<String?> baglar = const []]) =>
      [
        for (final (i, x) in l.indexed)
          '${x.$1}${i < baglar.length && baglar[i] != null ? '>${baglar[i]}' : ''}:${x.$2 % 1 == 0 ? x.$2.toInt() : x.$2}'
      ].join('+') +
      (cizgiler.isEmpty ? '' : '/${cizgiler.map((c) => '${c.$1.round()},${c.$2.round()}').join(';')}');
}

/// "2025-2026" → "2024-2025".
String oncekiSezon(String s) {
  final m = RegExp(r'^(\d{4})-(\d{4})$').firstMatch(s);
  return m == null ? '$s (önceki)' : '${int.parse(m[1]!) - 1}-${int.parse(m[2]!) - 1}';
}

/// [taban] sezonunun parsel çizimleriyle, ürün ve alanları haritadan girilen sezon.
/// [sezon] verilmezse bir sonraki sezon olur; [onceki] münavebe karşılaştırması içindir.
TarlaSezonu girisSezonu(TarlaSezonu taban, List<SezonParsel> l, {String? sezon, TarlaSezonu? onceki, bool ilkSezon = false, TarlaSezonu? sonraki}) {
  final ad = sezon ?? sonrakiSezon(taban.sezon);
  final once = ilkSezon ? null : (onceki ?? taban);
  return TarlaSezonu(
    sezon: ad,
    kaynak: 'haritadan girilen bilgiler',
    tarih: '',
    onceki: once,
    sonraki: sonraki,
    giris: true,
    ciftlikler: [
      for (final c in taban.ciftlikler)
        TarlaCiftlik(ad: c.ad, tesis: c.tesis, gorseller: c.gorseller, parseller: [
          for (final p in c.parseller)
            if (parselGirisi(l, ad, c.ad, p.ad) case final g?)
              _girisParseli(p, g, [
                for (final q in c.parseller)
                  if (parselGirisi(l, ad, c.ad, q.ad) case final h?
                      when q.ad != p.ad && ParselIcerik.oku(h.urun).birlesik == p.ad)
                    q.ad
              ], gelen: gelenParcalar(l, ad, c, p.ad))
            else
              TarlaParsel(
                  ad: p.ad, tip: p.tip == 'diger' || p.tip == 'bos' ? p.tip : 'girilmedi', urunler: const [], koord: p.koord),
        ]),
    ],
  );
}

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
      not: [
        if (y.not.isNotEmpty) y.not,
        for (final x in gelen) '${x.$1} parselinden bağlı parça: ${x.$2} ${x.$3 % 1 == 0 ? x.$3.toInt() : x.$3} da',
      ].join(' · '));
}

TarlaParsel _girisParseliTemel(TarlaParsel p, SezonParsel g, List<String> bagli) {
  final ic = ParselIcerik.oku(g.urun);
  if (ic.birlesik != null) {
    // Alan ana parselde sayılır; burada yalnızca ürün cinsi görünür.
    return TarlaParsel(ad: p.ad, tip: 'ekili', urunler: [(ic.urun, 0)], koord: p.koord, not: '${ic.birlesik} ile birleştirildi');
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
        baglar: ic.baglar);
  }
  return TarlaParsel(ad: p.ad, tip: 'ekili', urunler: [(g.urun, g.alan ?? 0)], beyan: g.alan, koord: p.koord,
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
  'Buğday', 'Arpa', 'Şeker pancarı', 'Silajlık mısır', 'Silajlık mısır (2. ürün)', 'Yonca', 'Patates',
  'Tritikale', 'Fiğ', 'Nadas',
];


/// Tarla Haritası bölümleri: 2024-2025 (haritadan giriş), KMZ sezonu (2025-2026),
/// 2026-2027 (haritadan giriş). Hepsi KMZ sezonunun parsel çizimlerini kullanır.
List<TarlaSezonu> tarlaSezonlari(List<TarlaSezonu> paket, List<SezonParsel> l) {
  if (paket.isEmpty) return const [];
  final kmz = paket.first;
  final eski = girisSezonu(kmz, l, sezon: oncekiSezon(kmz.sezon), ilkSezon: true, sonraki: kmz);
  return [eski, for (final k in paket) kmzUzerine(k, l), girisSezonu(kmz, l, onceki: kmz)];
}

/// KMZ sezonunda haritadan yapılan bölme / ayırma çizgisi kayıtları (aynı sezon için)
/// KMZ parselinin üzerine uygulanır; kaydı olmayan parsel KMZ'deki gibi kalır.
TarlaSezonu kmzUzerine(TarlaSezonu kmz, List<SezonParsel> l) {
  if (!l.any((x) => x.sezon == kmz.sezon)) return kmz;
  return TarlaSezonu(
    sezon: kmz.sezon,
    kaynak: kmz.kaynak,
    tarih: kmz.tarih,
    onceki: kmz.onceki,
    sonraki: kmz.sonraki,
    giris: kmz.giris,
    ciftlikler: [
      for (final c in kmz.ciftlikler)
        TarlaCiftlik(ad: c.ad, tesis: c.tesis, notlar: c.notlar, gorseller: c.gorseller, parseller: [
          for (final p in c.parseller)
            if (parselGirisi(l, kmz.sezon, c.ad, p.ad) case final g? when ParselIcerik.oku(g.urun).bolunmus)
              () {
                final y = _girisParseli(p, g, const []);
                return TarlaParsel(ad: p.ad, tip: p.tip, urunler: y.urunler, beyan: p.beyan ?? y.beyan, olculen: p.olculen,
                    etiket: p.etiket, not: p.not, koord: p.koord, bolme: y.bolme, baglar: y.baglar);
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
