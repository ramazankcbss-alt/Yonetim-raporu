// Ürün Takibi: ekilen her ürün için plan (ekim alanı, beklenen verim, satış, maliyet)
// ile gerçekleşen teslimat / satış hareketlerinin birleşimi.
// Teslimat kaynakları (Apps Script › urunTeslimatlari_): TarKop pancar dosyaları,
// patates fire listesi ve uygulamadan girilen Ürün_Teslimatları kayıtları.
// Sunucudan günlük toplamlar gelir; plaka, satıcı numarası ve kişi adı gelmez.

import 'faaliyet_ozet.dart';
import 'model.dart';
import 'uretim_karlilik.dart';

/// Bir ürünün bir çiftlikten bir gündeki teslimat toplamı.
class TeslimatGunu {
  const TeslimatGunu({
    required this.urun,
    required this.ciftlik,
    required this.kaynak,
    this.alici = '',
    required this.tarih,
    this.sefer = 0,
    this.teslim = 0,
    this.net = 0,
    this.fiyat,
    this.tutar = 0,
    this.ekGelir = 0,
    this.polar,
    this.kantar = 0,
  });

  final String urun, ciftlik, kaynak, alici;

  /// yyyy-MM-dd
  final String tarih;
  final int sefer;

  /// kg: teslim edilen (kesinti öncesi) ve bedele esas (kesinti sonrası) miktar.
  final double teslim, net;

  /// Kaynakta yazan birim fiyat (TL/kg); yoksa null.
  final double? fiyat;
  final double tutar, ekGelir;
  final double? polar;

  /// Çiftliğin kendi kantarındaki tartım (kg), varsa.
  final double kantar;

  double get kesinti => teslim > net ? teslim - net : 0;

  static TeslimatGunu? oku(Object? r) {
    if (r is! List || r.length < 8) return null;
    String m(int i) => i < r.length ? '${r[i] ?? ''}'.trim() : '';
    double n(int i) => i < r.length ? (sayiOku(r[i]) ?? 0) : 0;
    double? o(int i) => i < r.length ? sayiOku(r[i]) : null;
    if (m(0).isEmpty || m(4).isEmpty) return null;
    return TeslimatGunu(
      urun: TarimsalUretim.urunAdi(m(0)),
      ciftlik: TarimsalUretim.ciftlikAdi(m(1)),
      kaynak: m(2),
      alici: m(3),
      tarih: m(4),
      sefer: n(5).round(),
      teslim: n(6),
      net: n(7),
      fiyat: o(8),
      tutar: n(9),
      ekGelir: n(10),
      polar: o(11),
      kantar: n(12),
    );
  }
}

/// Uygulamadan girilmiş tek kayıt (silinebilir).
class ElleTeslimat {
  const ElleTeslimat(this.satir, this.tarih, this.ciftlik, this.urun, this.teslim, this.kesinti, this.net,
      this.alici, this.fiyat, this.aciklama);
  final int satir;
  final String tarih, ciftlik, urun, alici, aciklama;
  final double teslim, kesinti, net;
  final double? fiyat;

  static ElleTeslimat? oku(Object? r) {
    if (r is! List || r.length < 10) return null;
    final no = sayiOku(r[0])?.round();
    if (no == null) return null;
    double n(int i) => sayiOku(r[i]) ?? 0;
    return ElleTeslimat(no, '${r[1]}', TarimsalUretim.ciftlikAdi('${r[2]}'), TarimsalUretim.urunAdi('${r[3]}'),
        n(4), n(5), n(6), '${r[7]}', sayiOku(r[8]), '${r[9]}');
  }
}

class TeslimatKaynagi {
  const TeslimatKaynagi(this.ad, this.urun, this.ciftlik, this.satir, this.guncelleme);
  final String ad, urun, ciftlik, guncelleme;
  final int satir;
}

class UrunTeslimat {
  const UrunTeslimat({this.gunler = const [], this.elle = const [], this.kaynaklar = const [], this.hatalar = const [], this.okunma = ''});
  final List<TeslimatGunu> gunler;
  final List<ElleTeslimat> elle;
  final List<TeslimatKaynagi> kaynaklar;
  final List<String> hatalar;
  final String okunma;

  factory UrunTeslimat.json(Object? v) {
    if (v is! Map) return const UrunTeslimat();
    List l(String k) => v[k] is List ? v[k] as List : const [];
    return UrunTeslimat(
      gunler: l('satirlar').map(TeslimatGunu.oku).whereType<TeslimatGunu>().toList(),
      elle: l('elle').map(ElleTeslimat.oku).whereType<ElleTeslimat>().toList(),
      kaynaklar: [
        for (final k in l('kaynaklar'))
          if (k is Map)
            TeslimatKaynagi('${k['ad'] ?? ''}', '${k['urun'] ?? ''}', '${k['ciftlik'] ?? ''}',
                sayiOku(k['satir'])?.round() ?? 0, '${k['guncelleme'] ?? ''}'),
      ],
      hatalar: [for (final h in l('hatalar')) '$h', if (v['hata'] != null) '${v['hata']}'],
      okunma: '${v['okunma'] ?? ''}',
    );
  }
}

/// Bir ürünün (bir çiftlikte ya da tüm çiftliklerde) plan + gerçekleşen özeti.
class UrunDurumu {
  UrunDurumu(this.urun, this.ciftlik);
  final String urun;

  /// Boş: tüm çiftlikler.
  final String ciftlik;

  /// Plan (Tarımsal Faaliyet dosyası).
  double dekar = 0, planVerim = 0, planSatis = 0, maliyet = 0;
  double planFiyat = 0;
  final Set<String> cesitler = {};

  /// Gerçekleşen (teslimat kayıtları).
  final List<TeslimatGunu> gunler = [];
  int get sefer => gunler.fold(0, (a, g) => a + g.sefer);
  double get teslim => gunler.fold<double>(0, (a, g) => a + g.teslim);
  double get net => gunler.fold<double>(0, (a, g) => a + g.net);
  double get kesinti => teslim > net ? teslim - net : 0;
  double get kesintiOrani => teslim > 0 ? kesinti / teslim * 100 : 0;
  double get kantar => gunler.fold<double>(0, (a, g) => a + g.kantar);

  /// Çiftlik kantarında tartımı olan kayıtların portal (fireli) miktarı: kantar farkı yalnız bunlarla karşılaştırılır.
  double get kantarliTeslim => gunler.fold<double>(0, (a, g) => a + (g.kantar > 0 ? g.teslim : 0));
  double get ekGelir => gunler.fold<double>(0, (a, g) => a + g.ekGelir);
  double? get polar {
    var t = 0.0, n = 0.0;
    for (final g in gunler) {
      if (g.polar != null) {
        t += g.polar! * g.net;
        n += g.net;
      }
    }
    return n > 0 ? t / n : null;
  }

  bool get teslimatVar => gunler.isNotEmpty;

  /// Kaynakta fiyatı olmayan teslimatlar plandaki birim fiyatla değerlenir.
  bool get fiyatTahmini => gunler.any((g) => g.fiyat == null);

  /// Şu ana kadarki satış geliri (ürün bedeli + nakliye gibi ek gelirler).
  double get gelir =>
      gunler.fold<double>(0, (a, g) => a + (g.fiyat != null ? g.tutar : g.net * planFiyat)) + ekGelir;

  /// Plandaki tonaja göre teslim oranı (%).
  double? get ilerleme => planVerim > 0 ? net / planVerim * 100 : null;
  double get kalan => planVerim > net ? planVerim - net : 0;
  double? get gercekDekaraVerim => dekar > 0 && teslimatVar ? net / dekar : null;

  /// Kalan miktar plan fiyatından satılırsa beklenen toplam gelir.
  double get beklenenGelir => gelir + kalan * planFiyat;
  double get gerceklesenNet => gelir - maliyet;
  double get planNet => planSatis - maliyet;

  List<String> get alicilar => {for (final g in gunler) if (g.alici.isNotEmpty) g.alici}.toList();
  List<String> get kaynaklar => {for (final g in gunler) g.kaynak}.toList();
  String? get ilkTarih => gunler.isEmpty ? null : (gunler.map((g) => g.tarih).toList()..sort()).first;
  String? get sonTarih => gunler.isEmpty ? null : (gunler.map((g) => g.tarih).toList()..sort()).last;
}

/// Plan ve teslimatları ürün → çiftlik olarak birleştirir.
class UrunTakibi {
  UrunTakibi(TarimsalUretim plan, UrunTeslimat teslimat) {
    UrunDurumu al(String u, String c) =>
        _urunCiftlik.putIfAbsent('$u|$c', () => UrunDurumu(u, c));
    for (final c in plan.ciftlikler) {
      for (final k in c.urunler) {
        final d = al(k.ad, c.ciftlik)
          ..dekar += k.dekar
          ..planVerim += k.toplamVerim
          ..planSatis += k.satis
          ..maliyet += k.maliyet;
        if (k.birimFiyat > 0) d.planFiyat = k.birimFiyat;
        if (k.cesit.trim().isNotEmpty) d.cesitler.add(k.cesit.trim());
      }
    }
    for (final g in teslimat.gunler) {
      al(g.urun, g.ciftlik).gunler.add(g);
    }
    for (final d in _urunCiftlik.values) {
      d.gunler.sort((a, b) => b.tarih.compareTo(a.tarih));
    }
  }

  final Map<String, UrunDurumu> _urunCiftlik = {};

  List<UrunDurumu> get ciftlikSatirlari => _urunCiftlik.values.toList();

  /// Ürün bazında toplam (çiftlik satırlarının birleşimi); fiyatlar çiftlik satırlarında kalır.
  List<(UrunDurumu, List<UrunDurumu>)> get urunler {
    final m = <String, List<UrunDurumu>>{};
    for (final d in _urunCiftlik.values) {
      m.putIfAbsent(d.urun, () => []).add(d);
    }
    final l = [
      for (final e in m.entries) (_topla(e.key, '', e.value), e.value..sort((a, b) => b.planSatis.compareTo(a.planSatis))),
    ];
    l.sort((a, b) {
      final t = (b.$1.teslimatVar ? 1 : 0) - (a.$1.teslimatVar ? 1 : 0);
      return t != 0 ? t : b.$1.planSatis.compareTo(a.$1.planSatis);
    });
    return l;
  }

  List<String> get ciftlikler => {for (final d in _urunCiftlik.values) d.ciftlik}.toList()..sort();
  List<String> get urunAdlari => {for (final d in _urunCiftlik.values) d.urun}.toList()..sort();

  static UrunDurumu _topla(String urun, String ciftlik, List<UrunDurumu> l) {
    final t = _ToplamDurum(urun, ciftlik, l);
    for (final d in l) {
      t.dekar += d.dekar;
      t.planVerim += d.planVerim;
      t.planSatis += d.planSatis;
      t.maliyet += d.maliyet;
      t.cesitler.addAll(d.cesitler);
      t.gunler.addAll(d.gunler);
    }
    if (l.isNotEmpty) t.planFiyat = l.first.planFiyat;
    t.gunler.sort((a, b) => b.tarih.compareTo(a.tarih));
    return t;
  }

  UrunDurumu genelToplam() => _topla('Toplam', '', _urunCiftlik.values.toList());
}

/// Toplam satırında gelir/kalan çiftlik bazındaki fiyatlarla hesaplanır.
class _ToplamDurum extends UrunDurumu {
  _ToplamDurum(super.urun, super.ciftlik, this.parcalar);
  final List<UrunDurumu> parcalar;

  @override
  double get gelir => parcalar.fold<double>(0, (a, d) => a + d.gelir);
  @override
  double get kalan => parcalar.fold<double>(0, (a, d) => a + d.kalan);
  @override
  double get beklenenGelir => parcalar.fold<double>(0, (a, d) => a + d.beklenenGelir);
  @override
  bool get fiyatTahmini => parcalar.any((d) => d.teslimatVar && d.fiyatTahmini);
}

/// Dönem (ör. rapor haftası) içindeki teslimatlar: çiftlik + ürün + alıcı bazında toplam.
List<DonemTeslimati> donemTeslimatlari(UrunTeslimat t, DateTime bas, DateTime son) {
  String g(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final a = g(bas), b = g(son);
  final m = <String, List<TeslimatGunu>>{};
  for (final x in t.gunler) {
    if (x.tarih.compareTo(a) < 0 || x.tarih.compareTo(b) > 0) continue;
    m.putIfAbsent('${x.ciftlik}|${x.urun}|${x.alici}', () => []).add(x);
  }
  return [
    for (final l in m.values)
      DonemTeslimati(
        ciftlik: l.first.ciftlik,
        urun: l.first.urun,
        alici: l.first.alici,
        net: l.fold<double>(0, (s, x) => s + x.net),
        teslim: l.fold<double>(0, (s, x) => s + x.teslim),
        sefer: l.fold<int>(0, (s, x) => s + x.sefer),
      ),
  ]..sort((x, y) => x.ciftlik.compareTo(y.ciftlik));
}
