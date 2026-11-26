// Mali Raporlar › Gider, Gelir, Kâr / Zarar.
// Kaynak: Drive › Mali Raporlar › "aylık gider tablosu" (SAP gelen fatura kalemleri) ve
// "aylık gelir satış tablosu" (SAP satış faturaları); araclar/mali/gelir_gider.py ile
// mali_veri.json içindeki "gelirGider" anahtarına aylık toplamlar olarak yazılır.
// KVKK: satıcı/müşteri adı, kullanıcı adı ve belge numarası veride yoktur.

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

class GiderSatiri {
  const GiderSatiri(this.yil, this.ay, this.ciftlik, this.kategori, this.hesap, this.net, this.brut, {this.gun = 0});
  final int yil, ay;

  /// Belge tarihinin günü (0: eski veri, yalnızca ay bilinir).
  final int gun;
  DateTime get tarih => DateTime(yil, ay, gun == 0 ? 1 : gun);
  final String ciftlik, kategori, hesap;

  /// KDV hariç / KDV dahil (₺).
  final double net, brut;

  static GiderSatiri? oku(Object? r) {
    if (r is! List || r.length < 7) return null;
    return GiderSatiri(_i(r[0]), _i(r[1]), '${r[2]}', '${r[3]}', '${r[4]}', _d(r[5]), _d(r[6]), gun: r.length > 7 ? _i(r[7]) : 0);
  }
}

class GelirSatiri {
  const GelirSatiri(this.yil, this.ay, this.ciftlik, this.urun, this.hesap, this.birim, this.miktar, this.net, this.brut,
      {this.gun = 0});
  final int yil, ay;

  /// Fatura tarihinin günü (0: eski veri, yalnızca ay bilinir).
  final int gun;
  DateTime get tarih => DateTime(yil, ay, gun == 0 ? 1 : gun);
  final String ciftlik, urun, hesap, birim;
  final double miktar, net, brut;

  static GelirSatiri? oku(Object? r) {
    if (r is! List || r.length < 9) return null;
    return GelirSatiri(_i(r[0]), _i(r[1]), '${r[2]}', '${r[3]}', '${r[4]}', '${r[5]}', _d(r[6]), _d(r[7]), _d(r[8]),
        gun: r.length > 9 ? _i(r[9]) : 0);
  }
}

/// Seçili çiftlik ve tarih aralığı için süzme ölçütü (null: tümü). [bas] dahil, [bit] hariç.
typedef GgSuzgec = ({String? ciftlik, DateTime? bas, DateTime? bit});

/// Dönem türü: günlük, haftalık (pazartesi–pazar), aylık, yıllık.
enum GgDonem { gun, hafta, ay, yil }

/// Tarihin içinde bulunduğu dönemin başlangıcı.
DateTime ggDonemBasi(DateTime t, GgDonem d) => switch (d) {
      GgDonem.gun => DateTime(t.year, t.month, t.day),
      GgDonem.hafta => DateTime(t.year, t.month, t.day - (t.weekday - 1)),
      GgDonem.ay => DateTime(t.year, t.month),
      GgDonem.yil => DateTime(t.year),
    };

/// Dönemin bitişi (hariç).
DateTime ggDonemSonu(DateTime b, GgDonem d) => switch (d) {
      GgDonem.gun => DateTime(b.year, b.month, b.day + 1),
      GgDonem.hafta => DateTime(b.year, b.month, b.day + 7),
      GgDonem.ay => DateTime(b.year, b.month + 1),
      GgDonem.yil => DateTime(b.year + 1),
    };

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

  /// Satırlarda gün bilgisi var mı (günlük / haftalık görünüm için).
  bool get gunVar => gider.any((x) => x.gun > 0) || gelir.any((x) => x.gun > 0);

  /// Verideki dönem başlangıçları, yeniden eskiye.
  List<DateTime> donemler(GgDonem d, {bool giderli = true, bool gelirli = true}) {
    final s = {
      if (giderli) for (final x in gider) ggDonemBasi(x.tarih, d),
      if (gelirli) for (final x in gelir) ggDonemBasi(x.tarih, d),
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    return s;
  }

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

  static bool _uyar(GgSuzgec s, String c, DateTime t) =>
      (s.ciftlik == null || s.ciftlik == c) && (s.bas == null || !t.isBefore(s.bas!)) && (s.bit == null || t.isBefore(s.bit!));

  List<GiderSatiri> giderler(GgSuzgec s) => [for (final x in gider) if (_uyar(s, x.ciftlik, x.tarih)) x];
  List<GelirSatiri> gelirler(GgSuzgec s) => [for (final x in gelir) if (_uyar(s, x.ciftlik, x.tarih)) x];

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
