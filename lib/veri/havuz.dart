// Piramit veri yapısı › 1. adım: gelir ve gider havuzu.
//
// Kaynak önceliği:
//  1. Muhasebe (Çiftlik Raporları › çiftlik gelir tabloları, aylık; ESK için aylık net sonuç).
//     Muhasebenin kapsadığı aylar "kesin"dir ve havuzun net sonucu muhasebe net kârına eşittir.
//  2. Aylık gelir satış ve gider tabloları (faturalar): muhasebenin henüz kapanmadığı aylar ve
//     muhasebe ile mutabakat kontrolü.
// Muhasebe kapanmayan aylar "tahmin"dir:
//  • Hayvancılık çiftlikleri: fatura geliri / gideri + son 3 muhasebe ayındaki (muhasebe − fatura)
//    farkının ortalaması (faturasız gelir, personel, amortisman, stok kullanımı).
//  • Tarımsal Alan: muhasebe girdileri ürün satılana kadar stokta tutar; bu yüzden gider =
//    satılan miktar × ürünün birim maliyeti (muhasebe satılan mamul maliyeti, yoksa Maliyet Takip).
//  • Faaliyet dışı gelir ve giderler (teşvik, finansman) tahmine katılmaz; muhasebe kapanışında girer.
// Canlı hayvan, makine ve yapı alımları gider değil, yatırım olarak ayrı listelenir.
// ESK (Taşağıl) ayrı izlenir; konsolide sonuca (ESK hariç) girmez.
// KVKK: yalnızca çiftlik, ay, kalem ve tutar; kişi, müşteri, tedarikçi bilgisi yoktur.

import 'ciftlik_rapor.dart';
import 'gelir_gider.dart';
import 'uretim_karlilik.dart';

enum Kol { ziraat, hayvancilik, esk }

String kolAdi(Kol k) => switch (k) { Kol.ziraat => 'Ziraat', Kol.hayvancilik => 'Hayvancılık', Kol.esk => 'ESK' };

/// Muhasebe ve fatura tablolarında kullanılan çiftlik adları.
const kHavuzCiftlikleri = ['Tarımsal Alan', 'Şekersüt', 'Pan-Gev', 'Aslım'];
const kEskFatura = 'Taşağıl (ESK)';
const kEskMuhasebe = 'ESK-Taşağıl (Besi hizmeti)';
const kKonsolideMuhasebe = 'Çiftliklerimiz (ESK hariç)';

/// Tarım ürünleri (birim maliyeti aranan).
const kTarimUrunleri = {'Şeker Pancarı', 'Silajlık Mısır', 'Buğday', 'Arpa', 'Tritikale', 'Yonca', 'Patates'};

Kol ciftlikKolu(String c) => c == 'Tarımsal Alan' ? Kol.ziraat : (c == kEskFatura || c == kEskMuhasebe) ? Kol.esk : Kol.hayvancilik;

/// Yatırım niteliğindeki alımlar (kâr/zarara girmez).
const kYatirimKategorileri = {'Canlı hayvan alımı', 'Makine ve ekipman alımı', 'Yapı, tesisat ve inşaat'};

/// Gider türünün ait olduğu kol (kodu belirsiz kayıtlar için kontrol).
const kZiraatKategorileri = {'Gübre ve zirai ilaç', 'Tohum', 'Tarımsal hizmet (hasat, ilaçlama, nakliye)', 'Arazi kirası'};
const kHayvancilikKategorileri = {'Yem ve kaba yem', 'Veteriner, ilaç, aşı, tohumlama', 'Sağım ve süt ekipmanı'};

class HavuzAy {
  HavuzAy(this.ciftlik, this.yil, this.ay);
  final String ciftlik;
  final int yil, ay;
  Kol get kol => ciftlikKolu(ciftlik);

  /// Muhasebe kalemi (kesin) ya da tahmin.
  bool kesin = false;
  double gelir = 0, gider = 0, faaliyetDisi = 0;

  /// Faturalar (mutabakat ve tahmin için).
  double faturaGelir = 0, faturaGider = 0, yatirim = 0;

  /// Muhasebe kalemleri (kesin aylarda).
  double muhSatis = 0, muhGider = 0, muhNet = 0;

  /// Tahminin nasıl yapıldığı.
  String yontem = '';

  /// Tahmine katılmayan olağandışı fatura geliri (maliyeti muhasebe kapanışında belli olur).
  double olagandisiGelir = 0;
  bool get veriVar => kesin || faturaGelir != 0 || faturaGider != 0;
  double get net => kesin ? muhNet : gelir - gider + faaliyetDisi;
}

class HavuzToplam {
  double gelir = 0, gider = 0, faaliyetDisi = 0, net = 0, kesinNet = 0, tahminNet = 0;
  void ekle(HavuzAy a) {
    gelir += a.gelir;
    gider += a.gider;
    faaliyetDisi += a.faaliyetDisi;
    net += a.net;
    if (a.kesin) {
      kesinNet += a.net;
    } else {
      tahminNet += a.net;
    }
  }
}

/// Bir çiftlikte muhasebe ile faturalar arasındaki fark (kesin aylar toplamı).
class Mutabakat {
  Mutabakat(this.ciftlik);
  final String ciftlik;
  double muhSatis = 0, faturaGelir = 0, muhGider = 0, faturaGider = 0;
  final List<int> faturasizGelirAylari = [];
  double get gelirFarki => muhSatis - faturaGelir;
  double get giderFarki => muhGider - faturaGider;
}

class GelirGiderHavuzu {
  GelirGiderHavuzu._(this.yil, this.aylar, this.esk, this.sonMuhasebeAyi, this.sonFaturaAyi, this.yatirimlar, this.kolUyusmazliklari,
      this.muhasebeKonsolide, this.tarimBirimMaliyet, this.muhasebeVar);

  final int yil;

  /// Çiftlik → 1..12 ay.
  final Map<String, List<HavuzAy>> aylar;

  /// ESK: yalnızca aylık net (muhasebe) ve fatura bazlı tahmin.
  final List<HavuzAy> esk;
  final int sonMuhasebeAyi, sonFaturaAyi;

  /// (çiftlik, kategori) → yatırım tutarı.
  final Map<(String, String), double> yatirimlar;

  /// (çiftlik, kategori) → tutar: gider türü çiftliğin kolundan farklı olan faturalar.
  final Map<(String, String), double> kolUyusmazliklari;

  /// Muhasebedeki "Çiftliklerimiz (ESK hariç)" dönem net kârı (kesin aylar toplamı).
  final double? muhasebeKonsolide;

  /// Tarım tahmininde kullanılan ürün birim maliyetleri (₺/kg) ve kaynağı.
  final Map<String, (double, String)> tarimBirimMaliyet;
  final bool muhasebeVar;

  int get sonAy => sonMuhasebeAyi > sonFaturaAyi ? sonMuhasebeAyi : sonFaturaAyi;

  List<HavuzAy> ciftlikAylari(String c) => [for (final a in aylar[c] ?? const <HavuzAy>[]) if (a.ay <= sonAy) a];

  HavuzToplam toplam({String? ciftlik, Kol? kol, int? ay}) {
    final t = HavuzToplam();
    for (final e in aylar.entries) {
      if (ciftlik != null && e.key != ciftlik) continue;
      for (final a in e.value) {
        if (a.ay > sonAy || (ay != null && a.ay != ay) || (kol != null && a.kol != kol)) continue;
        t.ekle(a);
      }
    }
    return t;
  }

  HavuzToplam get eskToplam {
    final t = HavuzToplam();
    for (final a in esk) {
      if (a.ay <= sonAy) t.ekle(a);
    }
    return t;
  }

  /// Havuzun kesin ayları toplamı ile muhasebe konsolide net kârı arasındaki fark.
  double? get konsolideFark => muhasebeKonsolide == null ? null : toplam().kesinNet - muhasebeKonsolide!;

  List<Mutabakat> get mutabakat => [
        for (final c in kHavuzCiftlikleri)
          () {
            final m = Mutabakat(c);
            for (final a in aylar[c] ?? const <HavuzAy>[]) {
              if (!a.kesin) continue;
              m
                ..muhSatis += a.muhSatis
                ..faturaGelir += a.faturaGelir
                ..muhGider += a.muhGider
                ..faturaGider += a.faturaGider;
              if (a.muhSatis.abs() >= 1000 && a.faturaGelir.abs() < 1) m.faturasizGelirAylari.add(a.ay);
            }
            return m;
          }(),
      ];

  double get yatirimToplami => yatirimlar.values.fold(0.0, (s, v) => s + v);

  static GelirGiderHavuzu hesapla({
    required GelirGider faturalar,
    CiftlikRaporu? muhasebe,
    Map<String, double> mtKgMaliyet = const {},
    int? yil,
  }) {
    final y = yil ?? _yil(faturalar, muhasebe);
    final aylar = {for (final c in kHavuzCiftlikleri) c: [for (var m = 1; m <= 12; m++) HavuzAy(c, y, m)]};
    final esk = [for (var m = 1; m <= 12; m++) HavuzAy(kEskFatura, y, m)];
    HavuzAy? ayOf(String c, int m) => c == kEskFatura ? esk[m - 1] : aylar[c]?[m - 1];

    // Faturalar
    var sonFatura = 0;
    final yatirim = <(String, String), double>{};
    final uyusmaz = <(String, String), double>{};
    final tarimSatisKg = <int, Map<String, double>>{};
    for (final g in faturalar.gider) {
      if (g.yil != y) continue;
      final a = ayOf(g.ciftlik, g.ay);
      if (a == null) continue;
      if (g.ay > sonFatura) sonFatura = g.ay;
      if (kYatirimKategorileri.contains(g.kategori)) {
        a.yatirim += g.net;
        yatirim[(g.ciftlik, g.kategori)] = (yatirim[(g.ciftlik, g.kategori)] ?? 0) + g.net;
        continue;
      }
      a.faturaGider += g.net;
      final kol = ciftlikKolu(g.ciftlik);
      if ((kol == Kol.hayvancilik && kZiraatKategorileri.contains(g.kategori)) ||
          (kol == Kol.ziraat && kHayvancilikKategorileri.contains(g.kategori))) {
        uyusmaz[(g.ciftlik, g.kategori)] = (uyusmaz[(g.ciftlik, g.kategori)] ?? 0) + g.net;
      }
    }
    for (final g in faturalar.gelir) {
      if (g.yil != y) continue;
      final a = ayOf(g.ciftlik, g.ay);
      if (a == null) continue;
      if (g.ay > sonFatura) sonFatura = g.ay;
      a.faturaGelir += g.net;
      if (g.ciftlik == 'Tarımsal Alan' && g.birim.toUpperCase() == 'KG') {
        final u = TarimsalUretim.urunAdi(g.urun);
        final m = tarimSatisKg.putIfAbsent(g.ay, () => {});
        m[u] = (m[u] ?? 0) + g.miktar;
      }
    }

    // Muhasebe (kesin aylar)
    var sonMuh = 0;
    double? konsolide;
    final sc = muhasebe?.senaryo;
    if (sc != null) {
      for (final c in kHavuzCiftlikleri) {
        final d = sc.ciftlik(c)?.donemler[y];
        if (d == null) continue;
        for (var m = 1; m <= d.aySayisi && m <= 12; m++) {
          final a = aylar[c]![m - 1];
          final ns = d.ay(m, 'Net satışlar', 1), smm = d.ay(m, 'Satışların maliyeti', 1), fg = d.ay(m, 'Faaliyet giderleri', 1);
          final net = d.ay(m, 'Dönem net kârı/zararı', 1);
          if (ns == 0 && smm == 0 && fg == 0 && net == 0) continue;
          a
            ..kesin = true
            ..muhSatis = ns
            ..muhGider = smm + fg
            ..muhNet = net
            ..gelir = ns
            ..gider = smm + fg
            ..faaliyetDisi = net - (ns - smm - fg)
            ..yontem = 'Muhasebe';
          if (m > sonMuh) sonMuh = m;
        }
      }
      final k = sc.ciftlik(kKonsolideMuhasebe)?.donemler[y];
      if (k != null && sonMuh > 0) konsolide = k.toplam('Dönem net kârı/zararı', 1, ayaKadar: sonMuh);
    }
    if (muhasebe != null) {
      for (final s in muhasebe.aylik) {
        if (s.ciftlik != kEskMuhasebe || s.yil != y || s.ayNo < 1 || s.ayNo > 12) continue;
        final a = esk[s.ayNo - 1]
          ..kesin = true
          ..muhNet = s.netKar
          ..yontem = 'Muhasebe';
        a.gelir = 0;
      }
    }

    // Tarım birim maliyetleri: muhasebe satılan mamul maliyeti (aynı yıl), yoksa Maliyet Takip.
    final birim = <String, (double, String)>{};
    for (final e in mtKgMaliyet.entries) {
      if (e.value > 0) birim[e.key] = (e.value, 'Maliyet Takip');
    }
    for (final t in muhasebe?.tarim ?? const <TarimUrun>[]) {
      if (t.ciftlik != 'Tarımsal Alan' || t.yil != y || t.urun.toLowerCase().contains('tohum') || t.smmKg <= 0) continue;
      birim[TarimsalUretim.urunAdi(t.urun)] = (t.smmTl / t.smmKg, 'Muhasebe');
    }

    // Tahmin ayları
    for (final c in kHavuzCiftlikleri) {
      final l = aylar[c]!;
      final kesinler = [for (final a in l) if (a.kesin) a];
      final son3 = kesinler.length <= 3 ? kesinler : kesinler.sublist(kesinler.length - 3);
      double ort(double Function(HavuzAy) f) => son3.isEmpty ? 0 : son3.fold(0.0, (s, a) => s + f(a)) / son3.length;
      final gelirFarki = ort((a) => a.muhSatis - a.faturaGelir);
      for (final a in l) {
        if (a.kesin || a.ay > sonFatura || (a.faturaGelir == 0 && a.faturaGider == 0)) continue;
        if (c == 'Tarımsal Alan') {
          var smm = 0.0;
          final eksik = <String>[];
          for (final e in (tarimSatisKg[a.ay] ?? const <String, double>{}).entries) {
            final b = birim[e.key];
            if (b == null) {
              if (kTarimUrunleri.contains(e.key)) eksik.add(e.key);
            } else {
              smm += e.value * b.$1;
            }
          }
          a
            ..gelir = a.faturaGelir
            ..gider = smm
            ..yontem = 'Fatura geliri; gider = satılan miktar × ürün birim maliyeti'
                '${eksik.isEmpty ? '' : ' (birim maliyeti olmayan: ${eksik.join(', ')})'}';
        } else if (son3.isEmpty) {
          a
            ..gelir = a.faturaGelir
            ..gider = a.faturaGider
            ..yontem = 'Yalnızca faturalar (muhasebe verisi yok)';
        } else {
          // Gider: muhasebe gideri faturaların (toplu alım) zamanlamasından etkilenmediği için son ayların ortalaması.
          final ortSatis = ort((x) => x.muhSatis);
          var gel = a.faturaGelir + gelirFarki;
          if (ortSatis > 0 && a.faturaGelir > 2 * ortSatis) {
            a.olagandisiGelir = a.faturaGelir;
            gel = ortSatis;
          }
          a
            ..gelir = gel
            ..gider = ort((x) => x.muhGider)
            ..yontem = 'Gelir: faturalar + son ${son3.length} muhasebe ayının ortalama farkı; gider: son ${son3.length} muhasebe ayının ortalaması'
                '${a.olagandisiGelir > 0 ? '. Olağandışı fatura geliri tahmine katılmadı; maliyeti muhasebe kapanışında belli olur' : ''}';
        }
      }
    }
    // ESK tahmini: fatura farkı + son 3 ayın ortalama düzeltmesi
    {
      final kesinler = [for (final a in esk) if (a.kesin) a];
      final son3 = kesinler.length <= 3 ? kesinler : kesinler.sublist(kesinler.length - 3);
      final ortNet = son3.isEmpty ? null : son3.fold(0.0, (s, a) => s + a.muhNet) / son3.length;
      for (final a in esk) {
        if (a.kesin || a.ay > sonFatura || (a.faturaGelir == 0 && a.faturaGider == 0)) continue;
        a
          ..gelir = a.faturaGelir
          ..gider = ortNet == null ? a.faturaGider : a.faturaGelir - ortNet
          ..yontem = ortNet == null ? 'Yalnızca faturalar' : 'Son ${son3.length} muhasebe ayının ortalama net sonucu';
      }
    }

    return GelirGiderHavuzu._(y, aylar, esk, sonMuh, sonFatura, yatirim, uyusmaz, konsolide, birim, muhasebe != null);
  }

  static int _yil(GelirGider f, CiftlikRaporu? m) {
    var y = 0;
    for (final g in f.gelir) {
      if (g.yil > y) y = g.yil;
    }
    for (final g in f.gider) {
      if (g.yil > y) y = g.yil;
    }
    return y == 0 ? DateTime.now().year : y;
  }
}
