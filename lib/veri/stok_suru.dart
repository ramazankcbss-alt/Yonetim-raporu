// Piramit 4. adım: stok sayımları ve sürü hareketleri.
//  • SÜRÜ HAREKETLERİ: çiftlik × ay sayılar (tüm sürü, sağmal, kuru, doğum, abort, kesim, ölüm, alım, nakil).
//    Hayvan sayısının asıl kaynağıdır.
//  • Çiftlikler : Stok Sayımları ve Tüketimleri: üretim yeri × malzeme sayım miktarı (en yeni dosya).
// KVKK: yalnızca sayı ve malzeme bilgisi; stok dosyasının açıklama sütunları (kişi adı içerebilir) okunmaz.

import 'model.dart';

String _kucuk(String s) => s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase().trim();

/// Muhasebe üretim yeri kodları.
const kUretimYerleri = {
  '1604': 'Taşağıl (ESK)',
  '1605': 'Aslım',
  '1611': 'Tarımsal Alan',
  '1613': 'Şekersüt',
  '1614': 'Pan-Gev',
};

String uretimYeriAdi(String kod) => kUretimYerleri[kod] ?? 'Üretim yeri $kod';

class SuruHareketleri {
  const SuruHareketleri({this.dosya = '', this.guncelleme, this.veri = const {}});
  final String dosya;
  final DateTime? guncelleme;

  /// Çiftlik → yıl → kalem (büyük harf, sade) → 12 ay.
  final Map<String, Map<int, Map<String, List<double?>>>> veri;

  bool get bos => veri.isEmpty;
  List<String> get ciftlikler => veri.keys.toList();

  static String ciftlikAdi(String s) {
    final k = _kucuk(s);
    if (k.contains('şeker')) return 'Şekersüt';
    if (k.contains('pangev') || k.contains('pan-gev') || k.contains('erentepe')) return 'Pan-Gev';
    if (k.contains('aslım')) return 'Aslım';
    if (k.contains('taşağıl')) return 'Taşağıl';
    return s.trim();
  }

  static String kalemAdi(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

  List<double?> seri(String ciftlik, int yil, String kalem) => veri[ciftlik]?[yil]?[kalem] ?? List.filled(12, null);
  double? deger(String ciftlik, int yil, int ay, String kalem) => seri(ciftlik, yil, kalem)[ay - 1];

  /// Verisi olan son ay (tüm sürü dolu).
  int sonAy(String ciftlik, int yil) {
    final s = seri(ciftlik, yil, 'TÜM SÜRÜ');
    for (var i = 11; i >= 0; i--) {
      if (s[i] != null) return i + 1;
    }
    return 0;
  }

  List<String> kalemler(String ciftlik, int yil) => veri[ciftlik]?[yil]?.keys.toList() ?? const [];

  /// Kayıplar: ölü doğum, abort ve ölen hayvanlar toplamı.
  double kayip(String ciftlik, int yil, int ay) {
    var t = 0.0;
    for (final k in kalemler(ciftlik, yil)) {
      if (k.startsWith('ÖLEN') || k == 'ÖLÜ DOĞUM' || k == 'ABORT') t += deger(ciftlik, yil, ay, k) ?? 0;
    }
    return t;
  }

  /// Kesim: inek, düve ve dana kesimleri toplamı.
  double kesim(String ciftlik, int yil, int ay) {
    var t = 0.0;
    for (final k in kalemler(ciftlik, yil)) {
      if (k.contains('KESİM') || k == 'KESİLEN DÜVE') t += deger(ciftlik, yil, ay, k) ?? 0;
    }
    return t;
  }

  factory SuruHareketleri.json(Object? v) {
    if (v is! Map || v['sayfalar'] is! Map) return const SuruHareketleri();
    final out = <String, Map<int, Map<String, List<double?>>>>{};
    for (final e in (v['sayfalar'] as Map).entries) {
      final yil = int.tryParse('${e.key}');
      if (yil == null || e.value is! List) continue;
      String? ciftlik;
      for (final r in e.value as List) {
        if (r is! List || r.isEmpty) continue;
        final a = '${r[0] ?? ''}'.trim();
        if (a.isEmpty) continue;
        final sayilar = [for (var i = 1; i <= 12; i++) i < r.length ? sayiOku(r[i]) : null];
        final dolu = sayilar.any((x) => x != null);
        // Çiftlik başlığı: kalem olmayan satır (Taşağıl başlığının yanında 0'lar bulunabilir).
        if (!_kalemMi(a)) {
          if (!dolu || const {'Şekersüt', 'Pan-Gev', 'Aslım', 'Taşağıl'}.contains(ciftlikAdi(a))) ciftlik = ciftlikAdi(a);
          continue;
        }
        if (ciftlik == null) continue;
        out.putIfAbsent(ciftlik, () => {}).putIfAbsent(yil, () => {})[kalemAdi(a)] = sayilar;
      }
    }
    return SuruHareketleri(dosya: '${v['dosya'] ?? ''}', guncelleme: DateTime.tryParse('${v['guncelleme'] ?? ''}'), veri: out);
  }

  static bool _kalemMi(String a) {
    final k = _kucuk(a);
    return k.contains('sürü') ||
        k.contains('sağmal') ||
        k == 'kuru' ||
        k == 'dişi' ||
        k == 'erkek' ||
        k.contains('doğum') ||
        k.contains('abort') ||
        k.contains('kesim') ||
        k.contains('kesilen') ||
        k.contains('ölen') ||
        k.contains('alınan') ||
        k.contains('gelen') ||
        k.contains('giden') ||
        k.contains('satılan');
  }
}

class StokKalemi {
  const StokKalemi({
    required this.kod,
    required this.ad,
    this.grup = '',
    this.birim = '',
    this.stok,
    this.sayim,
    this.anacTuketim,
    this.gencTuketim,
  });
  final String kod, ad, grup, birim;
  final double? stok, sayim, anacTuketim, gencTuketim;
}

class StokSayimi {
  const StokSayimi({this.dosya = '', this.guncelleme, this.sayfalar = const {}});
  final String dosya;
  final DateTime? guncelleme;

  /// Üretim yeri kodu → kalemler.
  final Map<String, List<StokKalemi>> sayfalar;

  bool get bos => sayfalar.isEmpty;

  /// Dosya adındaki dönem ("2026 Ekim").
  String get donem => RegExp(r'(20\d\d)\s+(\S+)').firstMatch(dosya)?.group(0) ?? '';

  /// Bir üretim yerinde adı verilen ifadeyi içeren malzemelerin sayım toplamı (aynı birim).
  double toplam(String uretimYeri, bool Function(StokKalemi) f) =>
      (sayfalar[uretimYeri] ?? const <StokKalemi>[]).where(f).fold(0.0, (s, k) => s + (k.sayim ?? 0));

  factory StokSayimi.json(Object? v) {
    if (v is! Map || v['sayfalar'] is! Map) return const StokSayimi();
    final out = <String, List<StokKalemi>>{};
    for (final e in (v['sayfalar'] as Map).entries) {
      if (e.value is! List || (e.value as List).isEmpty) continue;
      final rows = e.value as List;
      final b = [for (final x in rows.first as List) '${x ?? ''}'.trim().toUpperCase()];
      int i(String ad) => b.indexOf(ad);
      final iKod = i('MALZ KOD'), iAd = i('MALZ'), iStok = i('STOK'), iSayim = i('SAYIM');
      final iAnac = i('ANAÇ TÜKETİM'), iGenc = i('GENÇ TÜKETİM');
      if (iAd < 0 || iSayim < 0) continue;
      final birimRe = RegExp(r'^(KG|ADT|L|LT|TON|M3|PKT)$', caseSensitive: false);
      final l = <StokKalemi>[];
      for (final r in rows.skip(1)) {
        if (r is! List) continue;
        String m(int k) => k >= 0 && k < r.length ? '${r[k] ?? ''}'.trim() : '';
        double? n(int k) => k >= 0 && k < r.length ? sayiOku(r[k]) : null;
        final ad = m(iAd);
        if (ad.isEmpty) continue;
        var birim = '';
        for (final x in r) {
          if (birimRe.hasMatch('${x ?? ''}'.trim())) {
            birim = '${x ?? ''}'.trim().toUpperCase();
            break;
          }
        }
        // Grup: malzeme kodu ile malzeme adı arasındaki başlıksız sütun (ör. YEMLER, İLAÇ AŞI).
        var grup = '';
        if (iKod >= 0 && iAd - iKod == 2 && b[iKod + 1].isEmpty) grup = m(iKod + 1);
        l.add(StokKalemi(
          kod: m(iKod),
          ad: ad,
          grup: grup,
          birim: birim,
          stok: n(iStok),
          sayim: n(iSayim),
          anacTuketim: n(iAnac),
          gencTuketim: n(iGenc),
        ));
      }
      if (l.isNotEmpty) out['${e.key}'] = l;
    }
    return StokSayimi(dosya: '${v['dosya'] ?? ''}', guncelleme: DateTime.tryParse('${v['guncelleme'] ?? ''}'), sayfalar: out);
  }
}
