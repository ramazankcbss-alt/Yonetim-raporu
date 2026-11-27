// Geçmiş yıl özetleri (Apps Script › gecmisOzet_): kesim ve canlı hayvan alımı (Kesim Özet 2021–2026) ile
// Değerlendirme Raporu 31.12.2025'teki yıl × çiftlik göstergeleri (tarım net gelir, süt verimi, ölüm oranı).

double? _n(Object? v) => v is num ? v.toDouble() : null;
int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

/// Çiftlik adlarını tek biçime getirir ("Şekersüt Çiftliği", "ŞEKERSÜT" → "Şekersüt").
String gecmisCiftlikAdi(String c) {
  final k = c.toUpperCase().replaceAll('İ', 'I');
  if (k.contains('TOPLAM')) return 'Toplam';
  if (k.contains('EKERS')) return 'Şekersüt';
  if (k.contains('PANGEV') || k.contains('ERENTEPE')) return 'Pan-Gev';
  if (k.contains('PANKENT') || k.contains('GEVREKL')) return 'Pankent';
  if (k.contains('ASLIM')) return 'Aslım';
  if (k.contains('TAŞA') || k.contains('TASA')) return 'Taşağıl';
  if (k.contains('GÖÇÜ') || k.contains('GOCU')) return 'Göçü';
  return c.trim();
}

class GecmisKesim {
  const GecmisKesim({required this.yil, required this.ciftlik, this.erkek = 0, this.erkekKarkas = 0, this.inek = 0,
      this.inekKarkas = 0, this.duve = 0, this.duveKarkas = 0, this.adet = 0, this.karkas = 0, this.satis, this.donem = ''});
  final int yil;
  final String ciftlik, donem;
  final double erkek, erkekKarkas, inek, inekKarkas, duve, duveKarkas, adet, karkas;
  final double? satis;
  double? get ortKarkas => adet <= 0 ? null : karkas / adet;
}

class GecmisAlim {
  const GecmisAlim({required this.yil, required this.ciftlik, this.ic = 0, this.dis = 0, this.toplam = 0});
  final int yil;
  final String ciftlik;
  final double ic, dis, toplam;
}

class GecmisGosterge {
  const GecmisGosterge(
      {required this.tablo, required this.ciftlik, required this.yil, required this.olcu, required this.deger, this.yuzde = false});
  final String tablo, ciftlik, olcu;
  final int yil;
  final double deger;
  final bool yuzde;
}

class GecmisKontrol {
  const GecmisKontrol(this.tablo, this.ciftlik, this.yil, this.olcu, this.yazilan, this.hesaplanan, this.pay, this.payda);
  final String tablo, ciftlik, olcu, pay, payda;
  final int yil;
  final double yazilan, hesaplanan;
}

class GecmisOzet {
  const GecmisOzet({this.kesim = const [], this.alim = const [], this.gostergeler = const [], this.hatalar = const [], this.kontroller = const []});
  final List<GecmisKesim> kesim;
  final List<GecmisAlim> alim;
  final List<GecmisGosterge> gostergeler;
  final List<String> hatalar;

  /// Değerlendirme raporunda yazılan oranın, aynı satırdaki sayılardan hesaplanan orandan farklı olduğu hücreler.
  final List<GecmisKontrol> kontroller;

  bool get bos => kesim.isEmpty && alim.isEmpty && gostergeler.isEmpty;

  static GecmisOzet json(Object? j) {
    if (j is! Map) return const GecmisOzet();
    List l(String k) => j[k] is List ? j[k] as List : const [];
    return GecmisOzet(
      kesim: [
        for (final x in l('kesim'))
          if (x is Map)
            GecmisKesim(
                yil: _i(x['yil']), ciftlik: gecmisCiftlikAdi('${x['ciftlik'] ?? ''}'), erkek: _n(x['erkek']) ?? 0,
                erkekKarkas: _n(x['erkekKarkas']) ?? 0, inek: _n(x['inek']) ?? 0, inekKarkas: _n(x['inekKarkas']) ?? 0,
                duve: _n(x['duve']) ?? 0, duveKarkas: _n(x['duveKarkas']) ?? 0, adet: _n(x['adet']) ?? 0,
                karkas: _n(x['karkas']) ?? 0, satis: _n(x['satis']), donem: '${x['donem'] ?? ''}'),
      ],
      alim: [
        for (final x in l('alim'))
          if (x is Map)
            GecmisAlim(yil: _i(x['yil']), ciftlik: gecmisCiftlikAdi('${x['ciftlik'] ?? ''}'), ic: _n(x['ic']) ?? 0,
                dis: _n(x['dis']) ?? 0, toplam: _n(x['toplam']) ?? 0),
      ],
      gostergeler: [
        for (final x in l('gostergeler'))
          if (x is Map && _n(x['deger']) != null)
            GecmisGosterge(tablo: '${x['tablo'] ?? ''}', ciftlik: gecmisCiftlikAdi('${x['ciftlik'] ?? ''}'), yil: _i(x['yil']),
                olcu: '${x['olcu'] ?? ''}', deger: _n(x['deger'])!, yuzde: x['yuzde'] == true),
      ],
      hatalar: [for (final h in l('hatalar')) '$h'],
      kontroller: [
        for (final k in l('kontroller'))
          if (k is Map)
            GecmisKontrol('${k['tablo'] ?? ''}', '${k['ciftlik'] ?? ''}', (k['yil'] as num?)?.toInt() ?? 0, '${k['olcu'] ?? ''}',
                (k['yazilan'] as num?)?.toDouble() ?? 0, (k['hesaplanan'] as num?)?.toDouble() ?? 0, '${k['pay'] ?? ''}', '${k['payda'] ?? ''}'),
      ],
    );
  }

  List<int> get kesimYillari => ({for (final k in kesim) k.yil}.toList()..sort());

  /// Ölçü adı → (çiftlik → (yıl → değer)); tablo adına göre.
  Map<String, Map<String, Map<int, double>>> matris(String tablo) {
    final m = <String, Map<String, Map<int, double>>>{};
    for (final g in gostergeler) {
      if (g.tablo != tablo) continue;
      ((m[g.olcu] ??= {})[g.ciftlik] ??= {})[g.yil] = g.deger;
    }
    return m;
  }

  List<String> get tablolar => {for (final g in gostergeler) g.tablo}.toList();
}
