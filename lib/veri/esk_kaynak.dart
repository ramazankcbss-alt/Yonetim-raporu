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
