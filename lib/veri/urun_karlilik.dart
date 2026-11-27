// Ürün Kârlılığı: üç kaynağın tek tabloda birleşimi (mükerrer giriş yok).
//  • Tarımsal Faaliyet › ÇİFTLİK BAZINDA: ekim alanı, planlanan tonaj, birim fiyat, beklenen satış.
//  • ÇİFTLİKLER : MALİYET TAKİP 2026 › MALİYET ÖZET TARIM 2026: ürüne yazılan gerçekleşen giderler
//    ve tarım ortak giderleri (işçilik, amortisman, diğer). Maliyet takibinde olmayan ekilişler
//    (ör. Fidanlık) için Tarımsal Faaliyet'teki tahmini maliyet kullanılır ve işaretlenir.
//  • Aylık gelir satış tablosu (gelirGider): sezon içinde faturalanan miktar ve tutar.
//  • Teslimatlar (TarKop / patates listesi / elle giriş): bedele esas net teslim.
// KVKK: yalnızca ürün, çiftlik, alan, miktar ve tutar; müşteri, satıcı ve kişi bilgisi yoktur.

import 'gelir_gider.dart';
import 'maliyet_takip.dart';
import 'urun_takip.dart';
import 'uretim_karlilik.dart';

/// Ortak giderlerin ürünlere dağıtım anahtarı.
enum OrtakAnahtar { dekar, maliyet }

class KarlilikCiftlik {
  KarlilikCiftlik(this.ciftlik);
  final String ciftlik;
  double dekar = 0, planKg = 0, planSatis = 0, tfMaliyet = 0, mtMaliyet = 0, teslimKg = 0;
  bool mtVar = false;

  /// Maliyet takip dosyasında yazan ekiliş alanı (dekar).
  double mtDekar = 0;

  /// Gerçekleşen (maliyet takibi) varsa o, yoksa Tarımsal Faaliyet tahmini.
  double get maliyet => mtVar ? mtMaliyet : tfMaliyet;
}

class KarlilikUrun {
  KarlilikUrun(this.urun);
  final String urun;
  final Map<String, KarlilikCiftlik> ciftlikler = {};
  double ortakPay = 0, faturaKg = 0, faturaTutar = 0;

  /// Sezon dışında (önceki sezona ait) faturalanan miktar/tutar.
  double oncekiKg = 0, oncekiTutar = 0;

  double _t(double Function(KarlilikCiftlik) f) => ciftlikler.values.fold(0.0, (a, c) => a + f(c));
  double get dekar => _t((c) => c.dekar);
  double get planKg => _t((c) => c.planKg);
  double get planSatis => _t((c) => c.planSatis);
  double get maliyet => _t((c) => c.maliyet);
  double get tfMaliyet => _t((c) => c.tfMaliyet);
  double get teslimKg => _t((c) => c.teslimKg);
  bool get tahminiMaliyetVar => ciftlikler.values.any((c) => !c.mtVar);
  double get planFiyat => planKg > 0 ? planSatis / planKg : 0;
  double get faturaFiyat => faturaKg > 0 ? faturaTutar / faturaKg : 0;

  double get brutKar => planSatis - maliyet;
  double get netKar => brutKar - ortakPay;
  double get dekarNet => dekar > 0 ? netKar / dekar : 0;

  /// Toplam maliyetle (doğrudan + ortak pay) kg maliyeti.
  double get kgMaliyet => planKg > 0 ? (maliyet + ortakPay) / planKg : 0;

  /// Beklenen satışın henüz faturalanmamış kısmı.
  double get faturalanmamis => planSatis > faturaTutar ? planSatis - faturaTutar : 0;

  /// Yalnızca faturalanan tutara göre (nakit esası) sonuç.
  double get faturaKar => faturaTutar - maliyet - ortakPay;

  /// Plan tonajının faturalanan oranı (%).
  double? get faturaOrani => planKg > 0 ? faturaKg / planKg * 100 : null;
}

class UrunKarlilik {
  UrunKarlilik._(this.urunler, this.ortakToplam, this.ortakYazili, this.anahtar, this.hasatYili, this.mtVar, this.digerGelir,
      this.ekGelirler, this.ortakDekarlari);

  final List<KarlilikUrun> urunler;

  /// Tarım ortak giderleri: kalemlerin (işçilik + amortisman + diğer) toplamı.
  final double ortakToplam;

  /// Maliyet takip dosyasının TOPLAM hücresinde yazan tutar (kontrol için).
  final double? ortakYazili;
  final OrtakAnahtar anahtar;
  final int hasatYili;
  final bool mtVar;

  /// Gelir tablosunda sezon içinde faturalanan, ürün tablosunda olmayan tarım dışı/ek kalemler.
  final List<(String, String, double)> digerGelir;

  /// Tarımsal Faaliyet sayfasının altındaki ek gelir kalemleri (plan).
  final List<(String, double)> ekGelirler;

  /// Ortak gider payı dağıtılan toplam alan.
  final double ortakDekarlari;

  bool get bos => urunler.isEmpty;

  /// İki dosyada farklı yazılan ekiliş alanları: (ürün, çiftlik, Tarımsal Faaliyet, Maliyet Takip).
  List<(String, String, double, double)> get alanFarklari => [
        for (final u in urunler)
          for (final c in u.ciftlikler.values)
            if (c.mtVar && c.mtDekar > 0 && (c.mtDekar - c.dekar).abs() >= 1) (u.urun, c.ciftlik, c.dekar, c.mtDekar),
      ];

  double _t(double Function(KarlilikUrun) f) => urunler.fold(0.0, (a, u) => a + f(u));
  double get dekar => _t((u) => u.dekar);
  double get planSatis => _t((u) => u.planSatis);
  double get maliyet => _t((u) => u.maliyet);
  double get brutKar => _t((u) => u.brutKar);
  double get ortakPay => _t((u) => u.ortakPay);
  double get netKar => _t((u) => u.netKar);
  double get faturaTutar => _t((u) => u.faturaTutar);
  double get faturalanmamis => _t((u) => u.faturalanmamis);
  double get faturaKar => _t((u) => u.faturaKar);
  double get ekGelirToplami => ekGelirler.fold(0.0, (a, e) => a + e.$2);

  /// Dosyadaki TOPLAM hücresi ile kalemlerin toplamı arasındaki fark.
  double? get ortakFark => ortakYazili == null ? null : ortakToplam - ortakYazili!;

  /// Sezon: hasat yılının 1 Haziranından bir sonraki yılın 31 Mayısına kadar kesilen faturalar.
  DateTime get sezonBas => DateTime(hasatYili, 6, 1);
  DateTime get sezonBit => DateTime(hasatYili + 1, 6, 1);

  static UrunKarlilik hesapla({
    required TarimsalUretim plan,
    MaliyetTakip? mt,
    GelirGider? gelir,
    UrunTakibi? teslimat,
    OrtakAnahtar anahtar = OrtakAnahtar.dekar,
    int? hasatYili,
  }) {
    final m = <String, KarlilikUrun>{};
    KarlilikCiftlik al(String u, String c) =>
        m.putIfAbsent(u, () => KarlilikUrun(u)).ciftlikler.putIfAbsent(c, () => KarlilikCiftlik(c));

    for (final c in plan.ciftlikler) {
      for (final k in c.urunler) {
        al(k.ad, c.ciftlik)
          ..dekar += k.dekar
          ..planKg += k.toplamVerim
          ..planSatis += k.satis
          ..tfMaliyet += k.maliyet;
      }
    }
    var yil = hasatYili ?? 0;
    if (mt != null) {
      for (final e in mt.ekilis) {
        final u = TarimsalUretim.urunAdi(e.urun), c = TarimsalUretim.ciftlikAdi(e.ciftlik);
        final x = al(u, c)
          ..mtMaliyet += e.toplam
          ..mtVar = true
          ..mtDekar += e.dekar ?? 0;
        if (x.dekar == 0) x.dekar = e.dekar ?? 0;
        if (hasatYili == null) {
          for (final a in e.aylik.keys) {
            final y = int.tryParse(a.split('-').first) ?? 0;
            if (y > yil) yil = y;
          }
        }
      }
    }
    if (yil == 0) yil = DateTime.now().year;

    if (teslimat != null) {
      for (final d in teslimat.ciftlikSatirlari) {
        final u = m[d.urun];
        final c = u?.ciftlikler[d.ciftlik];
        if (c != null) c.teslimKg += d.net;
      }
    }

    final bas = DateTime(yil, 6, 1), bit = DateTime(yil + 1, 6, 1);
    final diger = <String, (String, String, double)>{};
    for (final g in gelir?.gelir ?? const <GelirSatiri>[]) {
      final u = m[TarimsalUretim.urunAdi(g.urun)];
      final sezonda = !g.tarih.isBefore(bas) && g.tarih.isBefore(bit);
      if (u == null) {
        if (!sezonda || !_tarimGeliri(g.urun)) continue;
        final k = '${g.urun}|${g.ciftlik}';
        final o = diger[k];
        diger[k] = (g.urun, g.ciftlik, (o?.$3 ?? 0) + g.net);
        continue;
      }
      final kg = g.birim.toUpperCase() == 'KG' ? g.miktar : g.birim.toUpperCase() == 'TON' ? g.miktar * 1000 : 0.0;
      if (sezonda) {
        u
          ..faturaKg += kg
          ..faturaTutar += g.net;
      } else if (g.tarih.isBefore(bas)) {
        u
          ..oncekiKg += kg
          ..oncekiTutar += g.net;
      }
    }

    final urunler = m.values.where((u) => u.dekar > 0 || u.maliyet > 0).toList();
    final ortak = mt?.ortakToplam ?? 0;
    final toplamDekar = urunler.fold(0.0, (a, u) => a + u.dekar);
    final toplamMaliyet = urunler.fold(0.0, (a, u) => a + u.maliyet);
    for (final u in urunler) {
      final pay = anahtar == OrtakAnahtar.dekar
          ? (toplamDekar > 0 ? u.dekar / toplamDekar : 0)
          : (toplamMaliyet > 0 ? u.maliyet / toplamMaliyet : 0);
      u.ortakPay = ortak * pay;
    }
    urunler.sort((a, b) => b.netKar.compareTo(a.netKar));
    return UrunKarlilik._(urunler, ortak, mt?.ortakYazili, anahtar, yil, mt != null,
        diger.values.toList()..sort((a, b) => b.$3.compareTo(a.$3)), plan.ekGelirler, toplamDekar);
  }

  /// Sap, saman, küspe gibi tarım yan ürünleri (süt, hizmet ve hurda hariç).
  static bool _tarimGeliri(String u) {
    final k = u.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
    return k.contains('sap') || k.contains('saman') || k.contains('küspe') || k.contains('balya');
  }
}
