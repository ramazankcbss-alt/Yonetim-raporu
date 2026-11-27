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

class CiftlikRaporTam {
  const CiftlikRaporTam({this.dosya = '', this.guncelleme, this.sayfalar = const [], this.gider = const [], this.yem = const [],
      this.duranVarlik = const [], this.tarim = const [], this.hatalar = const [], this.donusum = ''});
  final String dosya;
  final DateTime? guncelleme;
  final List<CrSayfa> sayfalar;
  final List<CrGider> gider;
  final List<CrTuketim> yem, duranVarlik, tarim;
  final List<String> hatalar;

  /// Otomatik xlsx → E-Tablo dönüştürmenin durumu (güncel, dönüştürüldü, Drive API hizmeti ekli değil…).
  final String donusum;

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
