import 'dart:convert';

import 'dosyalar.dart';

/// Sürü Sağlığı ve Üreme arşivinin bir satırı: tarih, çiftlik, tür (doğum şekli,
/// muayene sonucu, aşı adı vb.), alt grup (inek/düve, kapsam) ve sayısal değerler.
/// Kaynak: Drive'daki arşiv JSON'u (araclar/hastalik/uygulamalar.py); kişi adı ve küpe no içermez.
class SuremeSatir {
  const SuremeSatir(this.t, this.ciftlik, this.tur, this.d, {this.alt = ''});
  final DateTime t;
  final String ciftlik, tur, alt;
  final Map<String, double> d;
  double v(String k) => d[k] ?? 0;
}

class SuremeArsiv {
  SuremeArsiv({
    required this.dogum,
    required this.tohumlama,
    required this.boga,
    required this.senk,
    required this.gebelik,
    required this.asi,
    required this.gelen,
    required this.satis,
    required this.sut,
    required this.diger,
    required this.suru,
    required this.olusturma,
  });
  final List<SuremeSatir> dogum, tohumlama, boga, senk, gebelik, asi, gelen, satis, sut, diger, suru;
  final String olusturma;

  static SuremeArsiv bos() => SuremeArsiv(
      dogum: [], tohumlama: [], boga: [], senk: [], gebelik: [], asi: [], gelen: [], satis: [], sut: [], diger: [], suru: [], olusturma: '');

  bool get bosMu => [dogum, tohumlama, senk, gebelik, asi, gelen, satis, sut, diger, suru].every((l) => l.isEmpty);

  static SuremeArsiv? _onbellek;
  static String? _onbellekMetin;

  /// Sunucudan gelen dosyadan (uygulamalar) okunur; dosya yoksa boş arşiv.
  static SuremeArsiv yukle() {
    final m = UygulamaDosyalari.metin('uygulamalar');
    if (m == null) return bos();
    if (_onbellek != null && _onbellekMetin == m) return _onbellek!;
    try {
      _onbellek = coz(m);
      _onbellekMetin = m;
      return _onbellek!;
    } catch (_) {
      return bos();
    }
  }

  static SuremeArsiv coz(String metin) {
    final j = jsonDecode(metin) as Map<String, dynamic>;
    List<String> l(String k) => ((j[k] as List?) ?? const []).map((e) => '$e').toList();
    final cf = l('ciftlik'), sekil = l('sekil'), grup = l('grup'), geb = l('gebelik'), yontem = l('yontem');
    final bogalar = l('bogalar'), asilar = l('asilar'), suruAlan = l('suruAlan');
    List<List> r(String k) => ((j[k] as List?) ?? const []).cast<List>();
    DateTime g(List x) => DateTime(x[0] as int, x[1] as int, x[2] as int);
    double n(Object? x) => (x as num?)?.toDouble() ?? 0;
    String ad(List<String> l, Object? i) => (i is int && i >= 0 && i < l.length) ? l[i] : 'Belirtilmemiş';
    const sira = ['Bilinmiyor', '1. tohumlama', '2. tohumlama', '3. ve üzeri'];
    return SuremeArsiv(
      dogum: [
        for (final x in r('dogum'))
          SuremeSatir(g(x), ad(cf, x[3]), ad(sekil, x[5]),
              {'dogum': n(x[6]), 'ikiz': n(x[7]), 'disi': n(x[8]), 'erkek': n(x[9]), 'olu': n(x[10])},
              alt: ad(grup, x[4])),
      ],
      tohumlama: [
        for (final x in r('tohumlama'))
          SuremeSatir(g(x), ad(cf, x[3]), ad(yontem, x[6]), {'adet': n(x[7])},
              alt: '${ad(grup, x[4])}|${(x[5] as int) < sira.length ? sira[x[5] as int] : sira[0]}'),
      ],
      boga: [
        for (final x in r('boga')) SuremeSatir(DateTime(x[0] as int, x[1] as int), ad(cf, x[2]), ad(bogalar, x[3]), {'adet': n(x[4])}),
      ],
      senk: [for (final x in r('senk')) SuremeSatir(g(x), ad(cf, x[3]), 'Program', {'hayvan': n(x[4]), 'program': 1})],
      gebelik: [
        for (final x in r('gebelikMuayene')) SuremeSatir(g(x), ad(cf, x[3]), ad(geb, x[5]), {'adet': n(x[6])}, alt: ad(grup, x[4])),
      ],
      asi: [for (final x in r('asi')) SuremeSatir(g(x), ad(cf, x[3]), ad(asilar, x[4]), {'kayit': n(x[6])}, alt: '${x[5]}')],
      gelen: [for (final x in r('gelen')) SuremeSatir(g(x), ad(cf, x[3]), '${x[4]}', {'adet': n(x[5]), 'kg': n(x[6])})],
      satis: [
        for (final x in r('satis')) SuremeSatir(g(x), ad(cf, x[3]), '${x[4]}', {'adet': n(x[5]), 'tutar': n(x[6]), 'kg': n(x[7])}),
      ],
      sut: [
        for (final x in r('sut'))
          SuremeSatir(g(x), ad(cf, x[3]), 'Süt analizi', {for (final e in (x[4] as Map).entries) '${e.key}': n(e.value)}),
      ],
      diger: [for (final x in r('diger')) SuremeSatir(g(x), ad(cf, x[3]), '${x[4]}', {'adet': n(x[5])})],
      suru: [
        for (final x in r('suru'))
          SuremeSatir(g(x), 'Şekersüt', 'Sürü durumu', {
            for (var i = 0; i < suruAlan.length && i + 3 < x.length; i++)
              if (x[i + 3] != null) suruAlan[i]: n(x[i + 3]),
          }),
      ],
      olusturma: '${j['olusturma'] ?? ''}',
    );
  }
}
