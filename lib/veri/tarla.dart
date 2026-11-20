// Tarla haritası (KMZ) ekiliş verisi ve tarım icmaliyle karşılaştırma.
// Kaynak: Google Earth "Yerlerim" KMZ dosyasından üretilen assets/veri/tarla_*.json
// (araclar/tarla). KVKK: kişi adı içermez.
import 'dart:convert';

import 'package:flutter/services.dart';

import 'kategori.dart';
import 'model.dart';

class TarlaParsel {
  const TarlaParsel({required this.ad, required this.tip, required this.urunler, this.beyan, this.olculen,
      this.etiket = '', this.not = '', this.koord = const []});
  final String ad, tip, etiket, not;
  final List<(String, double)> urunler;
  final double? beyan, olculen;
  final List<(double, double)> koord;

  String get urunYazi => urunler.isEmpty
      ? (tip == 'bos' ? 'Boş alan' : 'Ürün belirtilmemiş')
      : urunler.map((u) => '${u.$1} ${_s(u.$2)} da').join(' + ');

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
  const TarlaSezonu({required this.sezon, required this.kaynak, required this.tarih, required this.ciftlikler});
  final String sezon, kaynak, tarih;
  final List<TarlaCiftlik> ciftlikler;

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
  for (final a in ['şekersüt', 'aslım', 'taşağıl', 'fidanlık', 'pangev', 'pankent']) {
    if (k.contains(a)) return a;
  }
  return k;
}

class EkimKarsilastirma {
  const EkimKarsilastirma({required this.ciftlik, required this.urun, required this.harita, this.plan, this.ekilen});
  final String ciftlik, urun;
  final double harita;
  final double? plan, ekilen;
  double? get fark => plan == null ? null : harita - plan!;

  /// 'Uyumlu', 'Fark', 'Planda yok', 'Haritada yok'.
  String get durum {
    if (plan == null) return 'Planda yok';
    if (harita == 0) return 'Haritada yok';
    final f = fark!.abs();
    return f <= 10 || f <= plan! * 0.03 ? 'Uyumlu' : 'Fark';
  }
}

/// Haritadaki ekilişi tarım icmalinin ekim alanlarıyla (Ekim_Alanları) karşılaştırır.
List<EkimKarsilastirma> ekimKarsilastir(TarlaSezonu s, List<EkimSatir> ekim) {
  final out = <EkimKarsilastirma>[];
  final plan = <String, (String, String, double?, double?)>{};
  for (final e in ekim) {
    final k = '${ciftlikAnahtari(e.ciftlik)}|${urunAnahtari(e.urun)}';
    final o = plan[k];
    plan[k] = (e.ciftlik, urunAnahtari(e.urun), (o?.$3 ?? 0) + (e.plan ?? 0), e.ekilen == null && o?.$4 == null ? null : (o?.$4 ?? 0) + (e.ekilen ?? 0));
  }
  final gorulen = <String>{};
  for (final c in s.ciftlikler) {
    final t = c.urunToplami;
    if (t.isEmpty) continue;
    for (final u in t.keys) {
      final k = '${ciftlikAnahtari(c.ad)}|$u';
      gorulen.add(k);
      final p = plan[k];
      out.add(EkimKarsilastirma(ciftlik: c.ad, urun: u, harita: t[u]!, plan: p?.$3, ekilen: p?.$4));
    }
  }
  for (final e in plan.entries) {
    if (gorulen.contains(e.key)) continue;
    if (!s.ciftlikler.any((c) => ciftlikAnahtari(c.ad) == e.key.split('|')[0])) continue;
    out.add(EkimKarsilastirma(ciftlik: e.value.$1, urun: e.value.$2, harita: 0, plan: e.value.$3, ekilen: e.value.$4));
  }
  return out;
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
