// ESK çalışma dosyası (Taşağıl): rasyon planı, gider kalem hesabı (bakım maliyet planı) ve aylık ÖZET sayfası.
// Kaynak tablolarından (Apps Script › kaynakTablolari_, menü "esk") okunur; plan değerleri karnede gerçekleşenle,
// ÖZET sayfası ESK_Aylık ile karşılaştırılır.
// KVKK: gider kalem hesabındaki pozisyon bazlı ücret satırları sunucuda maskelenir; yalnızca grup ve genel toplamlar kullanılır.

import 'esk_kaynak.dart';
import 'kaynak_envanteri.dart';
import 'model.dart';

const _aylar = ['OCAK', 'ŞUBAT', 'MART', 'NİSAN', 'MAYIS', 'HAZİRAN', 'TEMMUZ', 'AĞUSTOS', 'EYLÜL', 'EKİM', 'KASIM', 'ARALIK'];

String _ust(String s) => s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase().trim();

/// "EYLÜL 2025", "Eylül 2025", "01.09.2025", "2025-09" → (2025, 9).
(int, int)? eskAyCoz(String s) {
  final u = _ust(s);
  final y = RegExp(r'(20\d\d)').firstMatch(u);
  if (y == null) return null;
  for (var i = 0; i < 12; i++) {
    if (u.contains(_aylar[i])) return (int.parse(y[1]!), i + 1);
  }
  final d = RegExp(r'^\d{1,2}[./](\d{1,2})[./](20\d\d)').firstMatch(u) ?? RegExp(r'^(20\d\d)-(\d{1,2})').firstMatch(u);
  if (d == null) return null;
  return u.startsWith('20') ? (int.parse(d[1]!), int.parse(d[2]!)) : (int.parse(d[2]!), int.parse(d[1]!));
}

class EskOzetAyi {
  const EskOzetAyi(this.yil, this.ay, this.gelen, this.hayvanGun, this.ortBas, this.kesim, this.disKesim, this.olen);
  final int yil, ay;
  final double? gelen, hayvanGun, ortBas, kesim, disKesim, olen;
}

class EskPlan {
  const EskPlan({this.rasyonKg, this.rasyonTl, this.sabitGider, this.kesimBirim, this.ozet = const []});

  /// İthal rasyon: baş başına günlük tüketim (kg) ve günlük maliyet (₺), güncel fiyatla.
  final double? rasyonKg, rasyonTl;

  /// Gider kalem hesabı: aylık sabit gider (₺) ve baş başına kesim maliyeti (₺).
  final double? sabitGider, kesimBirim;
  final List<EskOzetAyi> ozet;
  bool get bos => rasyonKg == null && sabitGider == null && ozet.isEmpty;

  static EskPlan coz(KaynakTablolari kt) {
    double? rKg, rTl, sabit, kesim;
    final ozet = <EskOzetAyi>[];
    for (final t in kt.menu('esk')) {
      final sayfa = _ust(t.sayfa);
      for (final b in t.bloklar) {
        if (sayfa.startsWith('ESK RASYON')) {
          var kgSut = -1, tlSut = -1;
          for (final r in b) {
            final u = r.map(_ust).toList();
            final k = u.indexWhere((x) => x.contains('GÜNLÜK TÜKETİM'));
            final m = u.indexWhere((x) => x.contains('GÜNLÜK MALİYET'));
            if (k >= 0) kgSut = k;
            if (m >= 0) tlSut = m;
            if (u.isNotEmpty && u.contains('TOPLAM') && kgSut >= 0 && rKg == null) {
              rKg = kgSut < r.length ? sayiOku(r[kgSut]) : null;
              rTl = tlSut >= 0 && tlSut < r.length ? sayiOku(r[tlSut]) : null;
            }
          }
        }
        if (sayfa.startsWith('GİDER KALEM')) {
          for (var i = 0; i < b.length; i++) {
            final u = b[i].map(_ust).toList();
            final s = u.indexWhere((x) => x.contains('SABİT GİDER'));
            if (s >= 0 && i + 1 < b.length) {
              final v = [for (final x in b[i + 1]) sayiOku(x.replaceAll(RegExp(r'[^0-9.,-]'), ''))].whereType<double>().toList();
              if (v.isNotEmpty) sabit ??= v.last;
            }
            final ks = u.indexWhere((x) => x.contains('KESİM MALİYETİ') && x.contains('HAYVAN'));
            if (ks >= 0) {
              final v = [for (final x in b[i].skip(ks + 1)) sayiOku(x)].whereType<double>().toList();
              if (v.isNotEmpty) kesim ??= v.last;
            }
          }
        }
        if (sayfa == 'ÖZET') {
          var h = <String>[];
          for (final r in b) {
            final u = r.map(_ust).toList();
            if (u.any((x) => x.contains('GELEN HAYVAN'))) {
              h = u;
              continue;
            }
            if (h.isEmpty || r.isEmpty) continue;
            final a = eskAyCoz(r.first);
            if (a == null) continue;
            double? c(bool Function(String) f) {
              final i = h.indexWhere(f);
              return i < 0 || i >= r.length ? null : sayiOku(r[i]);
            }

            ozet.add(EskOzetAyi(
              a.$1,
              a.$2,
              c((x) => x.contains('GELEN')),
              c((x) => x.contains('AY SONU')),
              c((x) => x.contains('ORTALAMA')),
              c((x) => x.contains('PANAGRO') && x.contains('KESİLEN')),
              c((x) => x.contains('DIŞ KESİM')),
              c((x) => x.contains('ÖLEN HAYVAN SAYISI')),
            ));
          }
        }
      }
    }
    return EskPlan(rasyonKg: rKg, rasyonTl: rTl, sabitGider: sabit, kesimBirim: kesim, ozet: ozet);
  }
}

class EskOzetFarki {
  const EskOzetFarki(this.yil, this.ay, this.kalem, this.ozet, this.aylik);
  final int yil, ay;
  final String kalem;
  final double ozet, aylik;
}

/// ESK çalışma › ÖZET sayfası ile ESK_Aylık (uygulama tablosu) arasındaki aylık farklar.
List<EskOzetFarki> eskOzetMutabakat(EskPlan p, List<EskAy> aylik) {
  final out = <EskOzetFarki>[];
  for (final o in p.ozet) {
    final a = aylik.where((x) {
      final c = eskAyCoz(x.ay);
      return c != null && c.$1 == o.yil && c.$2 == o.ay;
    }).firstOrNull;
    if (a == null) continue;
    void k(String ad, double? x, double? y) {
      if (x == null || y == null) return;
      if ((x - y).abs() > 0.5) out.add(EskOzetFarki(o.yil, o.ay, ad, x, y));
    }

    k('Gelen hayvan', o.gelen, a.gelen);
    k('Hayvan-gün', o.hayvanGun, a.hayvanGun);
    k('Panagro kesim', o.kesim, a.kesim);
    k('Dış kesim', o.disKesim, a.disKesim);
    k('Ölen hayvan', o.olen, a.olen);
  }
  return out;
}

/// Bir ayda gelen yem (kg) / hayvan-gün → baş başına günlük yem (kg).
double? eskGunlukYem(List<EskYem> yem, List<EskAy> aylik, int yil, int ay) {
  final a = aylik.where((x) {
    final c = eskAyCoz(x.ay);
    return c != null && c.$1 == yil && c.$2 == ay;
  }).firstOrNull;
  final hg = a?.hayvanGun;
  if (hg == null || hg <= 0) return null;
  final kg = yem.where((y) => y.yil == yil && y.ay == ay).fold(0.0, (t, y) => t + y.kg);
  return kg <= 0 ? null : kg / hg;
}
