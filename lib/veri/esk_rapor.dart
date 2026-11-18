// ESK – Taşağıl bakım besleme: haftalık, aylık ve yıllık rapor hesapları.
//
// Haftalık rapor günlük Hayvan_Özet satırlarından (ESK-Taşağıl Çiftliği Besi
// Danası) hesaplanır: ahırdaki hayvan sayıları toplanarak hayvan-gün bulunur,
// bakım geliri hayvan-gün × bakım ücreti, kira ve işletme gideri ise ayın gün
// sayısına bölünerek günlere dağıtılır. Bu yüzden haftalık kâr/zarar tahminidir.
// Aylık ve yıllık rapor 'ESK_Aylık' sayfasından gelir.

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

/// Günlük verisi olan haftalar, yeniden eskiye.
List<EskHafta> eskHaftalari(RaporVerisi v) {
  final b = EskBirimler.oku(v.eskBilgi);
  final h = <DateTime, EskHafta>{};
  final satirlar = v.ozet.where((o) => o.isletme == eskBesi).toList()
    ..sort((a, b) => a.tarih.compareTo(b.tarih));
  for (final o in satirlar) {
    final w = h.putIfAbsent(haftaBasi(o.tarih), () => EskHafta(haftaBasi(o.tarih)));
    w.gun++;
    w.hayvanGun += o.hayvan;
    w.giren += o.alinan;
    w.kesilen += o.kesilenDana;
    w.olen += o.olenDana;
    w.bakim += o.hayvan * (b.bakimUcreti ?? 0);
    final ay = _ayGunu(o.tarih);
    w.kira += (b.aylikKira ?? 0) / ay;
    w.gider += (b.aylikGider ?? 0) / ay;
    w.sonMevcut = o.hayvan;
    w.sonGun = o.tarih;
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
