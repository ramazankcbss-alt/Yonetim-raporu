// Mali Raporlar › Gider, Gelir, Kâr / Zarar.
// Kaynak: Drive › Mali Raporlar › "aylık gider tablosu" (SAP gelen fatura kalemleri) ve
// "aylık gelir satış tablosu" (SAP satış faturaları); araclar/mali/gelir_gider.py ile
// mali_veri.json içindeki "gelirGider" anahtarına aylık toplamlar olarak yazılır.
// KVKK: satıcı/müşteri adı, kullanıcı adı ve belge numarası veride yoktur.

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

class GiderSatiri {
  const GiderSatiri(this.yil, this.ay, this.ciftlik, this.kategori, this.hesap, this.net, this.brut);
  final int yil, ay;
  final String ciftlik, kategori, hesap;

  /// KDV hariç / KDV dahil (₺).
  final double net, brut;

  static GiderSatiri? oku(Object? r) {
    if (r is! List || r.length < 7) return null;
    return GiderSatiri(_i(r[0]), _i(r[1]), '${r[2]}', '${r[3]}', '${r[4]}', _d(r[5]), _d(r[6]));
  }
}

class GelirSatiri {
  const GelirSatiri(this.yil, this.ay, this.ciftlik, this.urun, this.hesap, this.birim, this.miktar, this.net, this.brut);
  final int yil, ay;
  final String ciftlik, urun, hesap, birim;
  final double miktar, net, brut;

  static GelirSatiri? oku(Object? r) {
    if (r is! List || r.length < 9) return null;
    return GelirSatiri(_i(r[0]), _i(r[1]), '${r[2]}', '${r[3]}', '${r[4]}', '${r[5]}', _d(r[6]), _d(r[7]), _d(r[8]));
  }
}

/// Seçili çiftlik ve ay için süzme ölçütü (null: tümü).
typedef GgSuzgec = ({String? ciftlik, int? yil, int? ay});

class GelirGider {
  const GelirGider({
    this.donem = '',
    this.kaynakGider = '',
    this.kaynakGelir = '',
    this.linkGider = '',
    this.linkGelir = '',
    this.satirGider = 0,
    this.satirGelir = 0,
    this.iadeAdet = 0,
    this.iadeTutar = 0,
    this.gider = const [],
    this.gelir = const [],
  });

  final String donem, kaynakGider, kaynakGelir, linkGider, linkGelir;
  final int satirGider, satirGelir, iadeAdet;
  final double iadeTutar;
  final List<GiderSatiri> gider;
  final List<GelirSatiri> gelir;

  bool get bos => gider.isEmpty && gelir.isEmpty;

  factory GelirGider.json(Object? j) {
    if (j is! Map) return const GelirGider();
    List<T> l<T>(String k, T? Function(Object?) f) => (j[k] is List ? j[k] as List : const []).map(f).whereType<T>().toList();
    return GelirGider(
      donem: '${j['donem'] ?? ''}',
      kaynakGider: '${j['kaynakGider'] ?? ''}',
      kaynakGelir: '${j['kaynakGelir'] ?? ''}',
      linkGider: '${j['linkGider'] ?? ''}',
      linkGelir: '${j['linkGelir'] ?? ''}',
      satirGider: _i(j['satirGider']),
      satirGelir: _i(j['satirGelir']),
      iadeAdet: _i(j['iadeAdet']),
      iadeTutar: _d(j['iadeTutar']),
      gider: l('gider', GiderSatiri.oku),
      gelir: l('gelir', GelirSatiri.oku),
    );
  }

  /// Verideki çiftlikler (gelir ya da gideri olan).
  List<String> get ciftlikler => ({for (final x in gider) x.ciftlik, for (final x in gelir) x.ciftlik}.toList()..sort());

  /// Verideki aylar (yıl, ay), eskiden yeniye.
  List<(int, int)> get aylar {
    final s = {for (final x in gider) (x.yil, x.ay), for (final x in gelir) (x.yil, x.ay)}.toList()
      ..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
    return s;
  }

  static bool _uyar(GgSuzgec s, String c, int y, int a) =>
      (s.ciftlik == null || s.ciftlik == c) && (s.yil == null || s.yil == y) && (s.ay == null || s.ay == a);

  List<GiderSatiri> giderler(GgSuzgec s) => [for (final x in gider) if (_uyar(s, x.ciftlik, x.yil, x.ay)) x];
  List<GelirSatiri> gelirler(GgSuzgec s) => [for (final x in gelir) if (_uyar(s, x.ciftlik, x.yil, x.ay)) x];

  double giderToplam(GgSuzgec s, {bool canliHaric = false}) => giderler(s)
      .where((x) => !canliHaric || x.kategori != kCanliHayvanAlimi)
      .fold(0.0, (t, x) => t + x.net);
  double gelirToplam(GgSuzgec s) => gelirler(s).fold(0.0, (t, x) => t + x.net);

  /// Anahtara göre KDV hariç toplamlar, büyükten küçüğe.
  static List<MapEntry<String, double>> grupla<T>(Iterable<T> l, String Function(T) k, double Function(T) v) {
    final m = <String, double>{};
    for (final x in l) {
      m.update(k(x), (t) => t + v(x), ifAbsent: () => v(x));
    }
    return m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }
}

const kCanliHayvanAlimi = 'Canlı hayvan alımı';
