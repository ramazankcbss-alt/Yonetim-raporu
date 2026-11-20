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
      this.etiket = '', this.not = '', this.koord = const []});
  final String ad, tip, etiket, not;
  final List<(String, double)> urunler;
  final double? beyan, olculen;
  final List<(double, double)> koord;

  /// Yeni sezonda henüz ürün girilmemiş parsel.
  bool get girilmedi => tip == 'girilmedi';

  String get urunYazi => urunler.isEmpty
      ? (tip == 'bos' ? 'Boş alan' : 'Ürün belirtilmemiş')
      : urunler.map((u) => u.$2 > 0 ? '${u.$1} ${_s(u.$2)} da' : u.$1).join(' + ');

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
        urunler: [for (final u in (j['urunler'] as List? ?? [])) ((u[0] as String), (u[1] as num).toDouble())],
        beyan: (j['beyan'] as num?)?.toDouble(),
        olculen: (j['olculen'] as num?)?.toDouble(),
        etiket: j['etiket'] ?? '',
        not: j['not_'] ?? '',
        koord: [for (final c in (j['koord'] as List? ?? [])) ((c[0] as num).toDouble(), (c[1] as num).toDouble())],
      );
}

class TarlaCiftlik {
  const TarlaCiftlik({required this.ad, required this.parseller, this.tesis = const {}, this.notlar = const []});
  final String ad;
  final List<TarlaParsel> parseller;
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
  const TarlaSezonu({required this.sezon, required this.kaynak, required this.tarih, required this.ciftlikler, this.onceki});
  final String sezon, kaynak, tarih;
  final List<TarlaCiftlik> ciftlikler;

  /// Haritadan girilen yeni sezonda, çizimlerin alındığı önceki sezon.
  final TarlaSezonu? onceki;
  bool get giris => onceki != null;

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
  SezonParsel? d;
  for (final x in l) {
    if (x.aktif && x.sezon == sezon && ciftlikAnahtari(x.ciftlik) == ciftlikAnahtari(ciftlik) &&
        kucuk(x.parsel).trim() == kucuk(parsel).trim()) {
      d = x;
    }
  }
  return d;
}

/// Önceki sezonun çizimleriyle yeni sezon haritası.
TarlaSezonu girisSezonu(TarlaSezonu onceki, List<SezonParsel> l) {
  final sezon = sonrakiSezon(onceki.sezon);
  return TarlaSezonu(
    sezon: sezon,
    kaynak: 'haritadan girilen bilgiler',
    tarih: '',
    onceki: onceki,
    ciftlikler: [
      for (final c in onceki.ciftlikler)
        TarlaCiftlik(ad: c.ad, tesis: c.tesis, parseller: [
          for (final p in c.parseller)
            if (parselGirisi(l, sezon, c.ad, p.ad) case final g?)
              TarlaParsel(ad: p.ad, tip: 'ekili', urunler: [(g.urun, g.alan ?? 0)], beyan: g.alan, koord: p.koord)
            else
              TarlaParsel(
                  ad: p.ad, tip: p.tip == 'diger' || p.tip == 'bos' ? p.tip : 'girilmedi', urunler: const [], koord: p.koord),
        ]),
    ],
  );
}

/// Önceki sezonda aynı parselde ekili ürünler (münavebe için).
List<String> oncekiUrunler(TarlaSezonu s, String ciftlik, String parsel) {
  final o = s.onceki;
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
