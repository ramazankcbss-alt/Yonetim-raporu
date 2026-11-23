// ESK – Taşağıl bakım besleme: haftalık, aylık ve yıllık rapor hesapları.
//
// Haftalık rapor ESK günlük raporundan (Hayvan_Detay, ESK-Taşağıl Çiftliği:
// gün sonu toplam, dışarıdan alınan, kesilen, ölen) hesaplanır; bu veri yoksa
// Hayvan_Özet satırları (ESK-Taşağıl Çiftliği Besi Danası) kullanılır: ahırdaki hayvan sayıları toplanarak hayvan-gün bulunur,
// bakım geliri hayvan-gün × bakım ücreti, kira ve işletme gideri ise ayın gün
// sayısına bölünerek günlere dağıtılır. Bu yüzden haftalık kâr/zarar tahminidir.
// Aylık ve yıllık rapor 'ESK_Aylık' sayfasından gelir.

import 'detay.dart';
import 'model.dart';

/// "50 TL/baş/gün", "900.000 TL/ay" → 50, 900000. Sayı yoksa null.
double? ilkSayi(String s) {
  final m = RegExp(r'-?\d{1,3}(?:\.\d{3})+(?:,\d+)?|-?\d+(?:,\d+)?').firstMatch(s);
  return m == null ? null : sayiOku(m[0]);
}

/// ESK_Bilgi'den haftalık hesapta kullanılan birim değerler.
class EskBirimler {
  const EskBirimler({this.bakimUcreti, this.aylikKira, this.aylikGider});

  /// TL / baş / gün.
  final double? bakimUcreti;

  /// TL / ay.
  final double? aylikKira, aylikGider;

  factory EskBirimler.oku(List<EskBilgi> b) {
    double? bul(String bolum, String parca) {
      for (final x in b) {
        if (x.bolum == bolum && trKucuk(x.baslik).contains(parca)) {
          return x.sayi ?? ilkSayi(x.deger);
        }
      }
      return null;
    }

    return EskBirimler(
      bakimUcreti: bul('Fiyat', 'bakım'),
      aylikKira: bul('Fiyat', 'kira'),
      aylikGider: bul('Başabaş', 'sabit işletme gideri'),
    );
  }
}

class EskHafta {
  EskHafta(this.bas);

  /// Haftanın Pazartesi'si.
  final DateTime bas;
  DateTime get son => bas.add(const Duration(days: 6));

  int gun = 0;
  double hayvanGun = 0, giren = 0, kesilen = 0, olen = 0;
  double bakim = 0, kira = 0, gider = 0;

  /// Son veri günündeki ahırdaki hayvan.
  double sonMevcut = 0;
  DateTime? sonGun;

  double get ortBas => gun == 0 ? 0 : hayvanGun / gun;
  double get gelir => bakim + kira;

  /// Gider bilinmiyorsa null.
  double? get karZarar => gider > 0 ? gelir - gider : null;

  /// Hafta 7 günden az veriyle (ör. devam eden hafta) hesaplandıysa.
  bool get eksik => gun < 7;
}

int _ayGunu(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

class _EskGun {
  double mevcut = 0, giren = 0, kesilen = 0, olen = 0;
}

/// ESK günlük raporundan gün bazında hareketler. Gün sonu hayvan sayısı
/// "Toplam" satırından (yoksa "İthal Besi Danası"), henüz girilmemiş
/// (sıfır) günler atlanır.
Map<DateTime, _EskGun> _detayGunleri(RaporVerisi v) {
  final g = <DateTime, _EskGun>{};
  final yedek = <DateTime, double>{};
  for (final d in v.detay) {
    if (d.isletme != eskDetay) continue;
    final n = kucuk(d.gosterge);
    final x = g.putIfAbsent(gunu(d.tarih), () => _EskGun());
    if (cikisMi(d.bolum) && n == 'toplam') {
      x.mevcut = d.deger;
    } else if (n == 'ithal besi danası' || n == 'yerli besi danası') {
      yedek[gunu(d.tarih)] = (yedek[gunu(d.tarih)] ?? 0) + d.deger;
    } else if (girisMi(d.gosterge)) {
      x.giren += d.deger;
    } else if (cikisMi(d.bolum) && kayipMi(d.gosterge)) {
      x.olen += d.deger;
    } else if (cikisMi(d.bolum) && n.contains('kesilen')) {
      x.kesilen += d.deger;
    }
  }
  for (final e in g.entries) {
    if (e.value.mevcut == 0) e.value.mevcut = yedek[e.key] ?? 0;
  }
  g.removeWhere((_, x) => x.mevcut <= 0);
  return g;
}

/// Günlük verisi olan haftalar, yeniden eskiye.
List<EskHafta> eskHaftalari(RaporVerisi v) {
  final b = EskBirimler.oku(v.eskBilgi);
  var gunler = _detayGunleri(v);
  if (gunler.isEmpty) {
    gunler = {
      for (final o in v.ozet.where((o) => o.isletme == eskBesi && o.hayvan > 0))
        gunu(o.tarih): _EskGun()
          ..mevcut = o.hayvan
          ..giren = o.alinan
          ..kesilen = o.kesilenDana
          ..olen = o.olenDana,
    };
  }
  final h = <DateTime, EskHafta>{};
  final sirali = gunler.keys.toList()..sort();
  for (final t in sirali) {
    final o = gunler[t]!;
    final w = h.putIfAbsent(haftaBasi(t), () => EskHafta(haftaBasi(t)));
    w.gun++;
    w.hayvanGun += o.mevcut;
    w.giren += o.giren;
    w.kesilen += o.kesilen;
    w.olen += o.olen;
    w.bakim += o.mevcut * (b.bakimUcreti ?? 0);
    final ay = _ayGunu(t);
    w.kira += (b.aylikKira ?? 0) / ay;
    w.gider += (b.aylikGider ?? 0) / ay;
    w.sonMevcut = o.mevcut;
    w.sonGun = t;
  }
  return h.values.toList()..sort((a, b) => b.bas.compareTo(a.bas));
}

class EskYil {
  EskYil(this.yil);
  final int yil;
  int ay = 0, eskAy = 0;
  double gelen = 0, hayvanGun = 0, kesim = 0, disKesim = 0, olen = 0;
  double bakim = 0, kira = 0, sap = 0, gider = 0, karZarar = 0;
  int tahminiAy = 0;
  double gun = 0;

  double get ortBas => gun == 0 ? 0 : hayvanGun / gun;
}

/// ESK_Aylık'tan yıllık toplamlar, yeniden eskiye. Ay adındaki
/// "(1–17)" gibi kısmi aylar gün sayısına dahil edilmez (ort. baş için
/// ayın kendi ortalaması kullanılır).
List<EskYil> eskYillari(List<EskAy> aylar) {
  final y = <int, EskYil>{};
  for (final a in aylar) {
    final t = y.putIfAbsent(a.yil, () => EskYil(a.yil));
    t.ay++;
    if (a.hayvanGun != null && a.hayvanGun! > 0) {
      t.eskAy++;
      t.hayvanGun += a.hayvanGun!;
      if (a.ortBas != null && a.ortBas! > 0) t.gun += a.hayvanGun! / a.ortBas!;
    }
    t.gelen += a.gelen ?? 0;
    t.kesim += a.kesim ?? 0;
    t.disKesim += a.disKesim ?? 0;
    t.olen += a.olen ?? 0;
    t.bakim += a.bakim ?? 0;
    t.kira += a.kira ?? 0;
    t.sap += a.sap ?? 0;
    t.gider += a.gider ?? 0;
    t.karZarar += a.karZarar ?? 0;
    if (a.tahmini || a.devamEdiyor) t.tahminiAy++;
  }
  return y.values.toList()..sort((a, b) => b.yil.compareTo(a.yil));
}

/// ESK-Taşağıl'da tek bir günün hareketi (kesim veya gelen hayvan).
class EskHareket {
  const EskHareket(this.tarih, this.adet);
  final DateTime tarih;
  final double adet;
}

/// [d] günü dahil, ESK-Taşağıl'daki son kesim ve son gelen hayvan hareketi.
/// Kaynak: işletme günlük raporu (Hayvan_Detay); o gün için yoksa Hayvan_Özet.
({EskHareket? kesim, EskHareket? gelen}) eskSonHareketler(
    RaporVerisi v, DateTime d) {
  final son = gunu(d);
  final kesim = <DateTime, double>{}, gelen = <DateTime, double>{};
  for (final o in v.ozet) {
    if (o.isletme != eskBesi) continue;
    final t = gunu(o.tarih);
    if (t.isAfter(son)) continue;
    if (o.kesilenDana > 0) kesim[t] = o.kesilenDana;
    if (o.alinan > 0) gelen[t] = o.alinan;
  }
  _detayGunleri(v).forEach((t, x) {
    if (t.isAfter(son)) return;
    if (x.kesilen > 0) kesim[t] = x.kesilen;
    if (x.giren > 0) gelen[t] = x.giren;
  });
  EskHareket? enSon(Map<DateTime, double> m) {
    if (m.isEmpty) return null;
    final t = m.keys.reduce((a, b) => a.isAfter(b) ? a : b);
    return EskHareket(t, m[t]!);
  }

  return (kesim: enSon(kesim), gelen: enSon(gelen));
}

/// ESK-Taşağıl'ın [d] günündeki gün sonu hayvan sayısı (işletme günlük
/// raporunun "Toplam" satırı; gelen hayvanlar dahil). Veri yoksa null.
double? eskGunSonuHayvan(RaporVerisi v, DateTime d) {
  final x = _detayGunleri(v)[gunu(d)];
  return x == null || x.mevcut <= 0 ? null : x.mevcut;
}

/// [bas]–[son] arasında ESK-Taşağıl'a gelen hayvan toplamı (günlük rapor,
/// o gün yoksa Hayvan_Özet "Dışarıdan Alınan").
double eskGelenToplam(RaporVerisi v, DateTime bas, DateTime son) {
  final b = gunu(bas), s = gunu(son);
  bool icinde(DateTime t) => !t.isBefore(b) && !t.isAfter(s);
  final m = <DateTime, double>{};
  for (final o in v.ozet) {
    final t = gunu(o.tarih);
    if (o.isletme == eskBesi && icinde(t) && o.alinan > 0) m[t] = o.alinan;
  }
  _detayGunleri(v).forEach((t, x) {
    if (icinde(t) && x.giren > 0) m[t] = x.giren;
  });
  return m.values.fold(0.0, (a, b) => a + b);
}
