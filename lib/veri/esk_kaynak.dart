// ESK (Taşağıl) kaynak tabloları: bakım hizmet alım tablosu (aylık toplamlar), ithal dana parti listesi
// ve aylık yem girişi. Sunucu yalnızca toplamları gönderir; plaka, şoför, kartela ve irsaliye no gelmez.
import 'model.dart' show EskAy;

const _ayAdlari = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
String eskAyAdi(int yil, int ay) => '${_ayAdlari[ay - 1]} $yil';

double? _n(Object? v) => v is num ? v.toDouble() : null;
int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

class EskBakimAyi {
  const EskBakimAyi({required this.yil, required this.ay, this.gelen, this.birimFiyat, this.kesilen = 0,
      this.sehirKesim = 0, this.olen = 0, this.basGun, this.bakimGideri});
  final int yil, ay;
  final double? gelen, birimFiyat, basGun, bakimGideri;
  final double kesilen, sehirKesim, olen;

  String get ad => eskAyAdi(yil, ay);

  /// Baş-gün × birim fiyat (tablodaki toplamın kontrolü).
  double? get hesaplananGider => basGun == null || birimFiyat == null ? null : basGun! * birimFiyat!;

  /// Ölüm oranı: ölen / (kesilen + ölen); ay içinde çıkan hayvanlara göre.
  double? get olumOrani {
    final c = kesilen + sehirKesim + olen;
    return c <= 0 ? null : olen / c;
  }
}

class EskParti {
  const EskParti({required this.parti, this.gelis = '', this.ciftlik, this.liman, this.nakliyeOlen});
  final String parti, gelis;
  final double? ciftlik, liman, nakliyeOlen;
  double? get fark => ciftlik == null || liman == null ? null : ciftlik! - liman!;
}

class EskYem {
  const EskYem({required this.yil, required this.ay, required this.urun, required this.kg});
  final int yil, ay;
  final String urun;
  final double kg;
}

/// Kaynak tablo ile ESK_Aylık sayfası arasındaki fark.
class EskMutabakat {
  const EskMutabakat({required this.ay, required this.kalem, required this.kaynak, required this.rapor});
  final String ay, kalem;
  final double kaynak, rapor;
  double get fark => kaynak - rapor;
}

class EskKaynak {
  const EskKaynak({this.aylar = const [], this.partiler = const [], this.yem = const [], this.hatalar = const []});
  final List<EskBakimAyi> aylar;
  final List<EskParti> partiler;
  final List<EskYem> yem;
  final List<String> hatalar;

  bool get bos => aylar.isEmpty && partiler.isEmpty && yem.isEmpty;

  static EskKaynak json(Object? j) {
    if (j is! Map) return const EskKaynak();
    List l(String k) => j[k] is List ? j[k] as List : const [];
    return EskKaynak(
      aylar: [
        for (final a in l('aylar'))
          if (a is Map && _i(a['ay']) >= 1 && _i(a['ay']) <= 12)
            EskBakimAyi(
              yil: _i(a['yil']), ay: _i(a['ay']), gelen: _n(a['gelen']), birimFiyat: _n(a['birimFiyat']),
              kesilen: _n(a['kesilen']) ?? 0, sehirKesim: _n(a['sehirKesim']) ?? 0, olen: _n(a['olen']) ?? 0,
              basGun: _n(a['basGun']), bakimGideri: _n(a['bakimGideri'])),
      ]..sort((a, b) => (a.yil * 12 + a.ay).compareTo(b.yil * 12 + b.ay)),
      partiler: [
        for (final p in l('partiler'))
          if (p is Map)
            EskParti(parti: '${p['parti'] ?? ''}', gelis: '${p['gelis'] ?? ''}', ciftlik: _n(p['ciftlik']),
                liman: _n(p['liman']), nakliyeOlen: _n(p['nakliyeOlen'])),
      ],
      yem: [
        for (final y in l('yem'))
          if (y is Map && _n(y['kg']) != null)
            EskYem(yil: _i(y['yil']), ay: _i(y['ay']), urun: '${y['urun'] ?? ''}', kg: _n(y['kg'])!),
      ],
      hatalar: [for (final k in ['maliyetHata', 'partiHata', 'yemHata']) if (j[k] != null) '${j[k]}'],
    );
  }

  /// Ay → ürün → kg.
  Map<String, Map<String, double>> yemAylik() {
    final m = <String, Map<String, double>>{};
    for (final y in yem) {
      final k = '${y.yil}-${y.ay.toString().padLeft(2, '0')}';
      (m[k] ??= {})[y.urun] = (m[k]![y.urun] ?? 0) + y.kg;
    }
    return m;
  }

  /// ESK_Aylık sayfasındaki hayvan-gün, kesim, ölen ve bakım geliriyle karşılaştırır (yalnızca farklar).
  List<EskMutabakat> mutabakat(List<EskAy> rapor, {double tolerans = 0.5}) {
    final out = <EskMutabakat>[];
    for (final a in aylar) {
      EskAy? r;
      for (final x in rapor) {
        if (x.ay.trim().toLowerCase() == a.ad.toLowerCase()) r = x;
      }
      if (r == null) continue;
      void k(String kalem, double? kaynak, double? rap) {
        if (kaynak == null || rap == null) return;
        if ((kaynak - rap).abs() > tolerans) out.add(EskMutabakat(ay: a.ad, kalem: kalem, kaynak: kaynak, rapor: rap));
      }

      k('Hayvan-gün', a.basGun, r.hayvanGun);
      k('Panagro kesim', a.kesilen, r.kesim);
      k('Dış kesim', a.sehirKesim, r.disKesim);
      k('Ölen', a.olen, r.olen);
      k('Bakım geliri', a.bakimGideri, r.bakim);
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// ESK ek kaynaklar (Apps Script › eskEk_): yalnızca toplamlar.

Map<String, double> _harita(Object? v) => {
      if (v is Map)
        for (final e in v.entries)
          if (e.value is num) '${e.key}': (e.value as num).toDouble(),
    };

class EskKesimAyi {
  const EskKesimAyi({required this.yil, required this.ay, this.adet = 0, this.kg = 0, this.kgAdet = 0, this.supheli = 0,
      this.neden = const {}, this.yer = const {}});
  final int yil, ay, supheli;
  final double adet, kg, kgAdet;
  final Map<String, double> neden, yer;
  String get ad => eskAyAdi(yil, ay);
  double? get ortKg => kgAdet <= 0 ? null : kg / kgAdet;
}

class EskOlumAyi {
  const EskOlumAyi({required this.yil, required this.ay, this.adet = 0, this.maliyete = 0, this.neden = const {}});
  final int yil, ay;
  final double adet, maliyete;
  final Map<String, double> neden;
  String get ad => eskAyAdi(yil, ay);
}

class EskKasaplikParti {
  const EskKasaplikParti({required this.parti, this.tarih = '', this.adet = 0, this.netKg = 0, this.limanAdet = 0,
      this.limanKg = 0, this.arac = 0});
  final int parti, arac;
  final String tarih;
  final double adet, netKg, limanAdet, limanKg;
  double? get ortKg => adet <= 0 ? null : netKg / adet;

  /// Liman ile çiftlik kantarı arasındaki ağırlık kaybı (%), liman ağırlığı girilmişse.
  double? get fireYuzde => limanKg <= 0 ? null : 100 * (limanKg - netKg) / limanKg;
}

class EskMiktar {
  const EskMiktar({required this.yil, required this.ay, required this.ad, this.yer = '', required this.kg});
  final int yil, ay;
  final String ad, yer;
  final double kg;
  String get anahtar => '$yil-${ay.toString().padLeft(2, '0')}';
}

class EskNakliyeAyi {
  const EskNakliyeAyi({required this.yil, required this.ay, this.sefer = 0, this.hayvan = 0});
  final int yil, ay;
  final double sefer, hayvan;
  String get ad => eskAyAdi(yil, ay);
}

class EskGelirAyi {
  const EskGelirAyi({required this.yil, required this.ay, this.sap, this.bakim, this.kira, this.satis, this.smm,
      this.digerMaliyet, this.faaliyet, this.gider, this.kazanc});
  final int yil, ay;
  final double? sap, bakim, kira, satis, smm, digerMaliyet, faaliyet, gider, kazanc;
  String get ad => eskAyAdi(yil, ay);
}

class EskEk {
  const EskEk({this.kesim = const [], this.olum = const [], this.kasaplik = const [], this.balya = const [],
      this.gubre = const [], this.nakliye = const [], this.gelir = const [], this.hatalar = const []});
  final List<EskKesimAyi> kesim;
  final List<EskOlumAyi> olum;
  final List<EskKasaplikParti> kasaplik;
  final List<EskMiktar> balya, gubre;
  final List<EskNakliyeAyi> nakliye;
  final List<EskGelirAyi> gelir;
  final List<String> hatalar;

  bool get bos =>
      kesim.isEmpty && olum.isEmpty && kasaplik.isEmpty && balya.isEmpty && gubre.isEmpty && nakliye.isEmpty && gelir.isEmpty;

  static int _sira(int y, int a) => y * 12 + a;

  static EskEk json(Object? j) {
    if (j is! Map) return const EskEk();
    List l(String k) => j[k] is List ? j[k] as List : const [];
    double? n(Object? v) => v is num ? v.toDouble() : null;
    return EskEk(
      kesim: [
        for (final x in l('kesim'))
          if (x is Map)
            EskKesimAyi(yil: _i(x['yil']), ay: _i(x['ay']), adet: n(x['adet']) ?? 0, kg: n(x['kg']) ?? 0,
                kgAdet: n(x['kgAdet']) ?? 0, supheli: _i(x['supheli']), neden: _harita(x['neden']), yer: _harita(x['yer'])),
      ]..sort((a, b) => _sira(a.yil, a.ay).compareTo(_sira(b.yil, b.ay))),
      olum: [
        for (final x in l('olum'))
          if (x is Map)
            EskOlumAyi(yil: _i(x['yil']), ay: _i(x['ay']), adet: n(x['adet']) ?? 0, maliyete: n(x['maliyete']) ?? 0,
                neden: _harita(x['neden'])),
      ]..sort((a, b) => _sira(a.yil, a.ay).compareTo(_sira(b.yil, b.ay))),
      kasaplik: [
        for (final x in l('kasaplik'))
          if (x is Map)
            EskKasaplikParti(parti: _i(x['parti']), tarih: '${x['tarih'] ?? ''}', adet: n(x['adet']) ?? 0,
                netKg: n(x['netKg']) ?? 0, limanAdet: n(x['limanAdet']) ?? 0, limanKg: n(x['limanKg']) ?? 0, arac: _i(x['arac'])),
      ]..sort((a, b) => a.parti.compareTo(b.parti)),
      balya: [
        for (final x in l('balya'))
          if (x is Map && n(x['kg']) != null)
            EskMiktar(yil: _i(x['yil']), ay: _i(x['ay']), ad: '${x['urun'] ?? ''}', yer: '${x['yer'] ?? ''}', kg: n(x['kg'])!),
      ],
      gubre: [
        for (final x in l('gubre'))
          if (x is Map && n(x['kg']) != null)
            EskMiktar(yil: _i(x['yil']), ay: _i(x['ay']), ad: '${x['urun'] ?? ''}', yer: '${x['yer'] ?? ''}', kg: n(x['kg'])!),
      ],
      nakliye: [
        for (final x in l('nakliye'))
          if (x is Map) EskNakliyeAyi(yil: _i(x['yil']), ay: _i(x['ay']), sefer: n(x['sefer']) ?? 0, hayvan: n(x['hayvan']) ?? 0),
      ]..sort((a, b) => _sira(a.yil, a.ay).compareTo(_sira(b.yil, b.ay))),
      gelir: [
        for (final x in l('gelir'))
          if (x is Map && _i(x['ay']) >= 1 && _i(x['ay']) <= 12)
            EskGelirAyi(yil: _i(x['yil']), ay: _i(x['ay']), sap: n(x['sap']), bakim: n(x['bakim']), kira: n(x['kira']),
                satis: n(x['satis']), smm: n(x['smm']), digerMaliyet: n(x['digerMaliyet']), faaliyet: n(x['faaliyet']),
                gider: n(x['gider']), kazanc: n(x['kazanc'])),
      ],
      hatalar: [for (final h in l('hatalar')) '$h'],
    );
  }

  /// Ay ("2026-01") → ad → kg.
  static Map<String, Map<String, double>> aylik(List<EskMiktar> l, {bool yereGore = false}) {
    final m = <String, Map<String, double>>{};
    for (final x in l) {
      final k = yereGore ? x.yer : x.ad;
      (m[x.anahtar] ??= {})[k] = (m[x.anahtar]![k] ?? 0) + x.kg;
    }
    return m;
  }

  /// Bakım hizmet tablosu (kaynak) ile aylık kesim/ölüm listeleri ve ESK aylık raporu ile gelir tablosu çalışması
  /// arasındaki farklar.
  List<EskMutabakat> mutabakat(EskKaynak k, List<EskAy> rapor, {double tolerans = 0.5}) {
    final out = <EskMutabakat>[];
    for (final a in k.aylar) {
      for (final x in kesim) {
        if (x.yil == a.yil && x.ay == a.ay && (x.adet - (a.kesilen + a.sehirKesim)).abs() > tolerans) {
          out.add(EskMutabakat(ay: a.ad, kalem: 'Kesim (liste – bakım tablosu)', kaynak: x.adet, rapor: a.kesilen + a.sehirKesim));
        }
      }
      for (final x in olum) {
        if (x.yil == a.yil && x.ay == a.ay && (x.adet - a.olen).abs() > tolerans) {
          out.add(EskMutabakat(ay: a.ad, kalem: 'Ölüm (liste – bakım tablosu)', kaynak: x.adet, rapor: a.olen));
        }
      }
    }
    for (final g in gelir) {
      for (final r in rapor) {
        if (r.ay.trim().toLowerCase() == g.ad.toLowerCase() && g.kazanc != null && r.karZarar != null &&
            (g.kazanc! - r.karZarar!).abs() > 1000) {
          out.add(EskMutabakat(ay: g.ad, kalem: 'Kâr/zarar (gelir tablosu – aylık rapor)', kaynak: g.kazanc!, rapor: r.karZarar!));
        }
      }
    }
    return out;
  }
}
