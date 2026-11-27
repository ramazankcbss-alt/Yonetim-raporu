// Çiftlik Raporları (muhasebe) E-Tablo kopyasının tamamından gelen ayrıntılar (Apps Script › ciftlikRaporTam_):
// gider raporu (yıl × üretim yeri × grup × hesap × ay), besi-düve ve sağmal yem tüketimi, tarımsal alan tüketimi.
// Personel grupları (2. İşçi, 3. Memur) yalnızca grup toplamıdır.

double _n(Object? v) => v is num ? v.toDouble() : 0;
int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

class CrGider {
  const CrGider(this.yil, this.ay, this.uy, this.grup, this.hesap, this.tutar);
  final int yil, ay;
  final String uy, grup, hesap;
  final double tutar;
}

class CrTuketim {
  const CrTuketim(this.yil, this.ay, this.uy, this.malzeme, this.ek, this.miktar, this.tutar);
  final int yil, ay;
  final String uy, malzeme, ek; // ek: besi-düvede hayvan cinsi, diğerlerinde birim
  final double miktar, tutar;
}

class CrSayfa {
  const CrSayfa(this.ad, this.satir, this.sutun);
  final String ad;
  final int satir, sutun;
}

class CrMutabakat {
  const CrMutabakat(this.sayfa, this.karsi, this.ozet, this.detay2026, this.detayTum, this.uyumlu, this.aciklama);
  final String sayfa, karsi, aciklama;
  final double ozet, detay2026, detayTum;
  final bool uyumlu;
}

class CiftlikRaporTam {
  const CiftlikRaporTam({this.dosya = '', this.guncelleme, this.sayfalar = const [], this.gider = const [], this.yem = const [],
      this.duranVarlik = const [], this.tarim = const [], this.hatalar = const [], this.donusum = '', this.mutabakat = const []});
  final String dosya;
  final DateTime? guncelleme;
  final List<CrSayfa> sayfalar;
  final List<CrGider> gider;
  final List<CrTuketim> yem, duranVarlik, tarim;
  final List<String> hatalar;

  /// Otomatik xlsx → E-Tablo dönüştürmenin durumu (güncel, dönüştürüldü, Drive API hizmeti ekli değil…).
  final String donusum;

  /// Özet / çiftlik bazlı pivot sayfalarının ana detay sayfalarıyla karşılaştırması.
  final List<CrMutabakat> mutabakat;

  bool get bos => sayfalar.isEmpty;

  static CiftlikRaporTam json(Object? j) {
    if (j is! Map) return const CiftlikRaporTam();
    List l(String k) => j[k] is List ? j[k] as List : const [];
    List<CrTuketim> t(String k) => [
          for (final r in l(k))
            if (r is List && r.length >= 7) CrTuketim(_i(r[0]), _i(r[1]), '${r[2]}', '${r[3]}', '${r[4]}', _n(r[5]), _n(r[6])),
        ];
    return CiftlikRaporTam(
      dosya: '${j['dosya'] ?? ''}',
      guncelleme: DateTime.tryParse('${j['guncelleme'] ?? ''}'),
      sayfalar: [
        for (final s in l('sayfalar'))
          if (s is Map) CrSayfa('${s['ad']}', _i(s['satir']), _i(s['sutun'])),
      ],
      gider: [
        for (final r in l('gider'))
          if (r is List && r.length >= 6) CrGider(_i(r[0]), _i(r[1]), '${r[2]}', '${r[3]}', '${r[4]}', _n(r[5])),
      ],
      yem: t('yem'),
      duranVarlik: t('duranVarlik'),
      tarim: t('tarim'),
      hatalar: [for (final h in l('hatalar')) '$h'],
      donusum: j['donusum'] is Map ? '${(j['donusum'] as Map)['durum'] ?? ''}' : '',
      mutabakat: [
        for (final m in l('mutabakat'))
          if (m is Map)
            CrMutabakat('${m['sayfa'] ?? ''}', '${m['karsi'] ?? ''}', _n(m['ozet']), _n(m['detay2026']), _n(m['detayTum']),
                m['durum'] == 'uyumlu', '${m['aciklama'] ?? ''}'),
      ],
    );
  }

  List<int> get giderYillari => ({for (final g in gider) g.yil}.toList()..sort());

  /// Grup → ay → tutar (yıl ve üretim yeri süzgeciyle; uy boşsa hepsi).
  Map<String, Map<int, double>> giderGrupAy(int yil, {String uy = ''}) {
    final m = <String, Map<int, double>>{};
    for (final g in gider) {
      if (g.yil != yil || (uy.isNotEmpty && g.uy != uy)) continue;
      (m[g.grup] ??= {})[g.ay] = (m[g.grup]![g.ay] ?? 0) + g.tutar;
    }
    return m;
  }

  /// Malzeme → (miktar, tutar) toplamı.
  static Map<String, (double, double)> malzemeToplam(Iterable<CrTuketim> l) {
    final m = <String, (double, double)>{};
    for (final x in l) {
      final o = m[x.malzeme] ?? (0.0, 0.0);
      m[x.malzeme] = (o.$1 + x.miktar, o.$2 + x.tutar);
    }
    return m;
  }
}

/// Maliyet Takip › İLAÇ AŞI ve DİĞER MALZEMELER malzeme ayrıntısı (Apps Script › maliyetTakipDetay_).
class MtKalem {
  const MtKalem(this.tur, this.ciftlik, this.yil, this.ay, this.kod, this.malzeme, this.miktar, this.birim, this.fiyat, this.tutar);
  final String tur, ciftlik, kod, malzeme, birim;
  final int yil, ay;
  final double miktar, fiyat, tutar;
}

class MtNot {
  const MtNot(this.tur, this.ciftlik, this.yil, this.ay, this.not);
  final String tur, ciftlik, not;
  final int yil, ay;
}

class MaliyetTakipDetay {
  const MaliyetTakipDetay({this.kalemler = const [], this.notlar = const [], this.hatalar = const []});
  final List<MtKalem> kalemler;
  final List<MtNot> notlar;
  final List<String> hatalar;
  bool get bos => kalemler.isEmpty;

  static MaliyetTakipDetay json(Object? j) {
    if (j is! Map) return const MaliyetTakipDetay();
    List l(String k) => j[k] is List ? j[k] as List : const [];
    return MaliyetTakipDetay(
      kalemler: [
        for (final r in l('kalemler'))
          if (r is List && r.length >= 10)
            MtKalem('${r[0]}', '${r[1]}', _i(r[2]), _i(r[3]), '${r[4]}', '${r[5]}', _n(r[6]), '${r[7]}', _n(r[8]), _n(r[9])),
      ],
      notlar: [
        for (final n in l('notlar'))
          if (n is Map) MtNot('${n['tur']}', '${n['ciftlik']}', _i(n['yil']), _i(n['ay']), '${n['not']}'),
      ],
      hatalar: [for (final h in l('hatalar')) '$h'],
    );
  }

  List<String> get turler => {for (final k in kalemler) k.tur}.toList();
  List<String> ciftlikler(String tur) => {for (final k in kalemler) if (k.tur == tur) k.ciftlik}.toList();

  /// Ay anahtarı (yıl*100+ay) → tutar.
  Map<int, double> aylik(String tur, String ciftlik) {
    final m = <int, double>{};
    for (final k in kalemler) {
      if (k.tur != tur || k.ciftlik != ciftlik) continue;
      m[k.yil * 100 + k.ay] = (m[k.yil * 100 + k.ay] ?? 0) + k.tutar;
    }
    return m;
  }
}
