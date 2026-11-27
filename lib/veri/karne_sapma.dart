// Piramit 7. ve 9. adım: verimlilik karnesi ve sapma açıklama katmanı.
//
// Karne: her kolun teknik ve birim göstergeleri, geçen yılın aynı ayıyla.
//  • Hayvancılık: süt verimi (L/sağmal/gün), süt maliyeti ve satış fiyatı (₺/L, muhasebe üretim kaydı),
//    çiftlik gideri (₺/baş/ay), yıl başından kayıp ve abort / doğum oranı (Sürü Hareketleri).
//  • Ziraat (hasat sezonu): plan ve gerçekleşen verim (kg/da), doğrudan maliyet (₺/da), kg maliyeti (ortak dahil)
//    ve satış fiyatı.
// Sapma: son kesin aylarda normal seviyenin (önceki 12 ayın ortalaması) belirgin üstüne çıkan kalemler,
// kalemlere ayrılarak ve nedenleriyle (verim, kayıp, yıl sonu kaydı, fatura türü) yazılır.
// KVKK: yalnızca çiftlik, ay, kalem ve tutar / sayı; kişi bilgisi yoktur.

import 'ciftlik_rapor.dart';
import 'esk_kaynak.dart';
import 'esk_plan.dart';
import 'gecmis_ozet.dart';
import 'model.dart' show EskAy;
import 'hasat_durumu.dart';
import 'gelir_gider.dart';
import 'havuz.dart';
import 'maliyet_takip.dart';
import 'stok_suru.dart';
import 'urun_karlilik.dart';

class KarneGostergesi {
  const KarneGostergesi(this.ad, this.birim, this.deger, {this.gecenYil, this.yuksekIyi = true, this.ondalik = 1, this.gecmis});
  final String ad, birim;

  /// Kıyas notu: geçmiş yıllar (Değerlendirme Raporu 31.12.2025) ya da plan değeri (ESK çalışma dosyası).
  final String? gecmis;
  final double? deger, gecenYil;

  /// Değerin yüksek olması iyi mi (verim) yoksa kötü mü (maliyet, kayıp).
  final bool yuksekIyi;
  final int ondalik;

  double? get degisim => deger == null || gecenYil == null || gecenYil == 0 ? null : (deger! - gecenYil!) / gecenYil!.abs() * 100;

  /// Geçen yıla göre iyileşme mi (null: karşılaştırma yok).
  bool? get iyi => degisim == null ? null : (yuksekIyi ? degisim! >= 0 : degisim! <= 0);
}

class KarneBolumu {
  const KarneBolumu(this.kol, this.baslik, this.donem, this.gostergeler);
  final Kol kol;
  final String baslik, donem;
  final List<KarneGostergesi> gostergeler;
}

class Sapma {
  Sapma({
    required this.ciftlik,
    required this.yil,
    required this.ay,
    required this.baslik,
    required this.nedenler,
    this.alarm = false,
    this.tekSeferlik = false,
  });
  final String ciftlik, baslik;
  final int yil, ay;
  final List<String> nedenler;

  /// Birim maliyet satış fiyatının üstünde.
  final bool alarm;

  /// Yıl sonu kaydı gibi tek seferlik kalem; eğilimi bozmaz.
  final bool tekSeferlik;
  String get donem => '${raporAylari[ay - 1]} $yil';
}

String _tl(double v, {int o = 2}) => '${v < 0 ? '−' : ''}${_s(v.abs(), o)} ₺';
String _s(double v, int o) {
  final t = v.toStringAsFixed(o).split('.');
  final b = t[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
  return o == 0 ? b : '$b,${t[1]}';
}

String _yuzde(double v) => '${v >= 0 ? '+' : '−'}%${_s(v.abs(), 0)}';
String _mn(double v) => '${v < 0 ? '−' : ''}${_s(v.abs() / 1e6, 2)} mn ₺';

const kSutCiftlikleri = [('Şekersüt', kSekersut), ('Pan-Gev', kPangev)];

BirimAy? _birim(CiftlikRaporu r, String urun, int yil, int ay) =>
    r.birimAylar(urun).where((b) => b.yil == yil && b.ayNo == ay && !b.tutarsiz).firstOrNull;

/// Muhasebe aylık çiftlik gideri (satışların maliyeti + faaliyet giderleri), 1. senaryo.
double? muhasebeGideri(CiftlikRaporu r, String ciftlik, int yil, int ay) {
  final d = r.senaryo?.ciftlik(ciftlik)?.donemler[yil];
  if (d == null || ay > d.aySayisi) return null;
  final g = d.ay(ay, 'Satışların maliyeti', 1) + d.ay(ay, 'Faaliyet giderleri', 1);
  return g == 0 && d.ay(ay, 'Net satışlar', 1) == 0 ? null : g;
}

double? _sutVerimi(CiftlikRaporu r, SuruHareketleri s, String c, String urun, int yil, int ay) {
  final b = _birim(r, urun, yil, ay), sag = s.deger(c, yil, ay, 'SAĞMAL');
  if (b == null || sag == null || sag == 0) return null;
  return b.miktar / sag / DateTime(yil, ay + 1, 0).day;
}

double _ytd(SuruHareketleri s, String c, int yil, int ay, double Function(int) f) {
  var t = 0.0;
  for (var m = 1; m <= ay; m++) {
    t += f(m);
  }
  return t;
}

/// Verimlilik karnesi: hayvancılık için [ay] (son kesin ay), ziraat için hasat sezonu.
/// Değerlendirme raporundaki bir göstergenin yıllar boyunca değerleri: "2021 74,7 · 2022 71,3 …".
String? gecmisSeri(GecmisOzet? g, String ciftlik, RegExp tablo, RegExp olcu, {int ondalik = 1, String birim = ''}) {
  if (g == null) return null;
  final m = <int, double>{};
  for (final x in g.gostergeler) {
    if (tablo.hasMatch(x.tablo) && olcu.hasMatch(x.olcu) && gecmisCiftlikAdi(x.ciftlik) == ciftlik) m[x.yil] = x.deger;
  }
  if (m.values.every((v) => v == 0)) return null;
  final y = m.keys.toList()..sort();
  String f(double v) => v.toStringAsFixed(ondalik).replaceAll('.', ',');
  return 'Geçmiş yıllar: ${[for (final k in y) '$k ${f(m[k]!)}'].join(' · ')}$birim';
}

List<KarneBolumu> verimlilikKarnesi({
  required CiftlikRaporu muhasebe,
  required SuruHareketleri suru,
  required int yil,
  required int ay,
  UrunKarlilik? tarim,
  List<HasatKaydi> hasat = const [],
  GecmisOzet? gecmis,
  List<EskAy> eskAylik = const [],
  EskKaynak? eskKaynak,
  EskPlan? eskPlan,
}) {
  final out = <KarneBolumu>[];
  final donem = '${raporAylari[ay - 1]} $yil · geçen yılın aynı ayıyla';
  for (final (c, urun) in kSutCiftlikleri) {
    final b = _birim(muhasebe, urun, yil, ay), b0 = _birim(muhasebe, urun, yil - 1, ay);
    double? lm(BirimAy? x) => x == null || x.miktar == 0 ? null : x.toplam / x.miktar;
    double? fiyat(BirimAy? x) => x == null || x.satisMiktar == 0 ? null : x.satisTl / x.satisMiktar;
    double? basa(int y) {
      final g = muhasebeGideri(muhasebe, c, y, ay), t = suru.deger(c, y, ay, 'TÜM SÜRÜ');
      return g == null || t == null || t == 0 ? null : g / t;
    }

    double? kayip(int y) => suru.sonAy(c, y) < ay ? null : _ytd(suru, c, y, ay, (m) => suru.kayip(c, y, m));
    double? abort(int y) {
      if (suru.sonAy(c, y) < ay) return null;
      final d = _ytd(suru, c, y, ay, (m) => suru.deger(c, y, m, 'DOĞUM') ?? 0);
      final a = _ytd(suru, c, y, ay, (m) => suru.deger(c, y, m, 'ABORT') ?? 0);
      return d == 0 ? null : a / d * 100;
    }

    final marj = lm(b) == null || fiyat(b) == null ? null : fiyat(b)! - lm(b)!;
    final marj0 = lm(b0) == null || fiyat(b0) == null ? null : fiyat(b0)! - lm(b0)!;
    out.add(KarneBolumu(Kol.hayvancilik, c, donem, [
      KarneGostergesi('Süt verimi', 'L/sağmal/gün', _sutVerimi(muhasebe, suru, c, urun, yil, ay),
          gecenYil: _sutVerimi(muhasebe, suru, c, urun, yil - 1, ay)),
      KarneGostergesi('Süt maliyeti', '₺/L', lm(b), gecenYil: lm(b0), yuksekIyi: false, ondalik: 2),
      KarneGostergesi('Süt satış fiyatı', '₺/L', fiyat(b), gecenYil: fiyat(b0), ondalik: 2),
      KarneGostergesi('Satış fiyatı − maliyet', '₺/L', marj, gecenYil: marj0, ondalik: 2),
      KarneGostergesi('Çiftlik gideri', '₺/baş/ay', basa(yil), gecenYil: basa(yil - 1), yuksekIyi: false, ondalik: 0),
      KarneGostergesi('Kayıp (yıl başından)', 'baş', kayip(yil), gecenYil: kayip(yil - 1), yuksekIyi: false, ondalik: 0),
      KarneGostergesi('Abort / doğum (yıl başından)', '%', abort(yil), gecenYil: abort(yil - 1), yuksekIyi: false,
          gecmis: gecmisSeri(gecmis, c, RegExp('abort', caseSensitive: false), RegExp('abort.*oran|oran.*abort', caseSensitive: false), birim: ' %')),
      if (gecmisSeri(gecmis, c, RegExp('^Doğum oranları', caseSensitive: false), RegExp('Doğum Oranı', caseSensitive: false)) != null)
        KarneGostergesi('Doğum oranı (inek + düve)', '%', null, ondalik: 1,
            gecmis: gecmisSeri(gecmis, c, RegExp('^Doğum oranları', caseSensitive: false), RegExp('Doğum Oranı', caseSensitive: false), birim: ' %')),
      if (gecmisSeri(gecmis, c, RegExp('^Ölüm oranları', caseSensitive: false), RegExp('oran', caseSensitive: false)) != null)
        KarneGostergesi('Ölüm oranı', '%', null,
            gecmis: gecmisSeri(gecmis, c, RegExp('^Ölüm oranları', caseSensitive: false), RegExp('oran', caseSensitive: false), birim: ' %')),
    ]));
  }
  // Aslım (besi): gider ve kayıp
  {
    const c = 'Aslım';
    double? basa(int y) {
      final g = muhasebeGideri(muhasebe, c, y, ay), t = suru.deger(c, y, ay, 'TÜM SÜRÜ');
      return g == null || t == null || t == 0 ? null : g / t;
    }

    if (basa(yil) != null) {
      out.add(KarneBolumu(Kol.hayvancilik, '$c (besi)', donem, [
        KarneGostergesi('Hayvan sayısı', 'baş', suru.deger(c, yil, ay, 'TÜM SÜRÜ'), gecenYil: suru.deger(c, yil - 1, ay, 'TÜM SÜRÜ'), ondalik: 0),
        KarneGostergesi('Çiftlik gideri', '₺/baş/ay', basa(yil), gecenYil: basa(yil - 1), yuksekIyi: false, ondalik: 0),
        KarneGostergesi('Kayıp (yıl başından)', 'baş', _ytd(suru, c, yil, ay, (m) => suru.kayip(c, yil, m)),
            gecenYil: suru.sonAy(c, yil - 1) < ay ? null : _ytd(suru, c, yil - 1, ay, (m) => suru.kayip(c, yil - 1, m)),
            yuksekIyi: false, ondalik: 0),
        if (gecmisSeri(gecmis, c, RegExp('Karkas Verimliliği', caseSensitive: false), RegExp('^Ortalama Karkas', caseSensitive: false)) != null)
          KarneGostergesi('Ortalama karkas', 'kg', null,
              gecmis: gecmisSeri(gecmis, c, RegExp('Karkas Verimliliği', caseSensitive: false), RegExp('^Ortalama Karkas', caseSensitive: false), birim: ' kg')),
        if (gecmisSeri(gecmis, c, RegExp('Karkas Verimliliği', caseSensitive: false), RegExp('^Randıman', caseSensitive: false)) != null)
          KarneGostergesi('Karkas randımanı', '%', null,
              gecmis: gecmisSeri(gecmis, c, RegExp('Karkas Verimliliği', caseSensitive: false), RegExp('^Randıman', caseSensitive: false), ondalik: 0, birim: ' %')),
      ]));
    }
  }
  // ESK-Taşağıl (bakım hizmeti): son kesin ESK ayı; plan değerleri ESK çalışma dosyasından.
  {
    final kesin = [for (final a in eskAylik) if (!a.tahmini && eskAyCoz(a.ay) != null && (a.hayvanGun ?? 0) > 0) a];
    if (kesin.isNotEmpty) {
      final a = kesin.last, c = eskAyCoz(a.ay)!;
      final yem = eskKaynak == null ? null : eskGunlukYem(eskKaynak.yem, eskAylik, c.$1, c.$2);
      final plan = eskPlan?.sabitGider == null ? null : eskPlan!.sabitGider! + (eskPlan.kesimBirim ?? 0) * ((a.kesim ?? 0) + (a.disKesim ?? 0));
      String f(double v) => v.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
      out.add(KarneBolumu(Kol.esk, 'ESK-Taşağıl (bakım hizmeti)', '${a.ay} · son kesin ay', [
        KarneGostergesi('Ortalama hayvan', 'baş', a.ortBas, ondalik: 0),
        KarneGostergesi('Gelen yem', 'kg/baş/gün', yem, yuksekIyi: false,
            gecmis: eskPlan?.rasyonKg == null
                ? null
                : 'Rasyon planı: ${eskPlan!.rasyonKg!.toStringAsFixed(2).replaceAll('.', ',')} kg/baş/gün'
                    '${eskPlan.rasyonTl == null ? '' : ', ${eskPlan.rasyonTl!.toStringAsFixed(2).replaceAll('.', ',')} ₺/baş/gün (güncel fiyat)'}'),
        KarneGostergesi('İşletme gideri', '₺/ay', a.gider, yuksekIyi: false, ondalik: 0,
            gecmis: plan == null ? null : 'Maliyet planı: ${f(plan)} ₺ (sabit ${f(eskPlan!.sabitGider!)} ₺ + kesim ${f(eskPlan.kesimBirim ?? 0)} ₺/baş)'),
        KarneGostergesi('Ölüm (ay)', 'baş', a.olen, yuksekIyi: false, ondalik: 0),
      ]));
    }
  }
  if (tarim != null && !tarim.bos) {
    for (final u in tarim.urunler) {
      if (u.dekar <= 0) continue;
      final gercekKg = u.teslimKg > 0 ? u.teslimKg : u.faturaKg;
      final bitti = hasatTamam(hasat, tarim.hasatYili, u.urun);
      out.add(KarneBolumu(Kol.ziraat, u.urun,
          '${tarim.hasatYili} hasat sezonu · ${bitti ? 'hasat tamamlandı, kesin sonuç' : 'hasat / teslimat sürüyor'} · plana göre', [
        KarneGostergesi('Verim', 'kg/da', gercekKg > 0 ? gercekKg / u.dekar : null, gecenYil: u.planKg / u.dekar, ondalik: 0),
        KarneGostergesi('Doğrudan maliyet', '₺/da', u.maliyet / u.dekar, ondalik: 0, yuksekIyi: false),
        KarneGostergesi('Kg maliyeti (ortak dahil)', '₺/kg', u.kgMaliyet, yuksekIyi: false, ondalik: 2),
        KarneGostergesi('Satış fiyatı', '₺/kg', u.faturaFiyat > 0 ? u.faturaFiyat : u.planFiyat, gecenYil: u.planFiyat, ondalik: 2),
      ]));
    }
  }
  return out;
}

/// Sapmalar: son [aySayisi] kesin ayda normal seviyenin üstüne çıkan kalemler, nedenleriyle.
List<Sapma> sapmalar({
  required CiftlikRaporu muhasebe,
  required SuruHareketleri suru,
  required GelirGider faturalar,
  required int yil,
  required int sonAy,
  MaliyetTakip? mt,
  int aySayisi = 3,
}) {
  final out = <Sapma>[];
  final ilk = sonAy - aySayisi + 1;

  // A. Süt maliyeti: önceki 12 ayın ortalamasına göre (+%10) ve satış fiyatı karşılaştırması
  for (final (c, urun) in kSutCiftlikleri) {
    final l = [for (final b in muhasebe.birimAylar(urun)) if (!b.tutarsiz && b.miktar > 0) b]
      ..sort((a, b) => (a.yil * 12 + a.ayNo).compareTo(b.yil * 12 + b.ayNo));
    for (var i = 0; i < l.length; i++) {
      final b = l[i];
      if (b.yil != yil || b.ayNo < ilk || b.ayNo > sonAy) continue;
      final once = l.sublist(i - 12 < 0 ? 0 : i - 12, i);
      final lm = b.toplam / b.miktar, fiyat = b.satisMiktar > 0 ? b.satisTl / b.satisMiktar : null;
      if (fiyat != null && lm > fiyat) {
        out.add(Sapma(
          ciftlik: c,
          yil: b.yil,
          ay: b.ayNo,
          alarm: true,
          baslik: 'Süt maliyeti satış fiyatının üstünde: ${_tl(lm)}/L, satış ${_tl(fiyat)}/L',
          nedenler: ['Litre başına ${_tl(lm - fiyat)} zarar; ${_s(b.miktar, 0)} L için yaklaşık ${_mn((lm - fiyat) * b.miktar)}.'],
        ));
      }
      if (once.length < 3) continue;
      final ort = once.fold(0.0, (s, x) => s + x.toplam / x.miktar) / once.length;
      if (lm <= ort * 1.10) continue;
      final nedenler = <String>[];
      final farklar = <(String, double)>[
        for (final k in b.bilesen.keys)
          (k, b.bilesen[k]! / b.miktar - once.fold(0.0, (s, x) => s + (x.bilesen[k] ?? 0) / x.miktar) / once.length),
      ]..sort((a, b) => b.$2.compareTo(a.$2));
      for (final (k, f) in farklar.take(3)) {
        if (f > 0.3) nedenler.add('$k ${_tl(f)}/L arttı');
      }
      final v = _sutVerimi(muhasebe, suru, c, urun, b.yil, b.ayNo);
      final vOnce = [
        for (final x in once) _sutVerimi(muhasebe, suru, c, urun, x.yil, x.ayNo),
      ].whereType<double>().toList();
      if (v != null && vOnce.isNotEmpty) {
        final vo = vOnce.reduce((a, b) => a + b) / vOnce.length;
        if (v < vo * 0.95) nedenler.add('Süt verimi düştü: ${_s(vo, 1)} → ${_s(v, 1)} L/sağmal/gün');
      }
      final kayip = suru.kayip(c, b.yil, b.ayNo);
      final kOnce = [for (final x in once) suru.kayip(c, x.yil, x.ayNo)];
      if (kOnce.isNotEmpty) {
        final ko = kOnce.reduce((a, b) => a + b) / kOnce.length;
        if (kayip > ko * 1.5 && kayip >= 3) nedenler.add('Hayvan kaybı arttı: ${_s(kayip, 0)} baş (ortalama ${_s(ko, 1)})');
      }
      out.add(Sapma(
        ciftlik: c,
        yil: b.yil,
        ay: b.ayNo,
        baslik: 'Süt maliyeti ${_tl(lm)}/L; önceki 12 ay ortalaması ${_tl(ort)}/L (${_yuzde((lm / ort - 1) * 100)})',
        nedenler: nedenler.isEmpty ? ['Artış bileşenlere dağılmış; tek bir kalem öne çıkmıyor.'] : nedenler,
      ));
    }
  }

  // B. Çiftlik gideri (muhasebe) önceki 12 ayın ortalamasının %15 üstünde
  for (final c in kHavuzCiftlikleri) {
    for (var m = ilk < 1 ? 1 : ilk; m <= sonAy; m++) {
      final g = muhasebeGideri(muhasebe, c, yil, m);
      if (g == null) continue;
      final once = <double>[];
      for (var k = 1; k <= 12; k++) {
        final t = DateTime(yil, m - k);
        final x = muhasebeGideri(muhasebe, c, t.year, t.month);
        if (x != null) once.add(x);
      }
      if (once.length < 3) continue;
      final ort = once.reduce((a, b) => a + b) / once.length;
      if (ort <= 0 || g <= ort * 1.15 || g - ort < 100000) continue;
      final nedenler = <String>[];
      // Fatura türleri: bu ay ile önceki ayların ortalaması
      final buAy = <String, double>{}, onceki = <String, List<double>>{};
      for (final x in faturalar.gider) {
        if (x.ciftlik != c || kYatirimKategorileri.contains(x.kategori)) continue;
        final fark = (yil - x.yil) * 12 + (m - x.ay);
        if (fark == 0) buAy[x.kategori] = (buAy[x.kategori] ?? 0) + x.net;
      }
      for (var k = 1; k <= 12; k++) {
        final t = DateTime(yil, m - k);
        final ayT = <String, double>{};
        for (final x in faturalar.gider) {
          if (x.ciftlik == c && x.yil == t.year && x.ay == t.month && !kYatirimKategorileri.contains(x.kategori)) {
            ayT[x.kategori] = (ayT[x.kategori] ?? 0) + x.net;
          }
        }
        if (ayT.isEmpty) continue;
        for (final k2 in {...ayT.keys, ...buAy.keys}) {
          onceki.putIfAbsent(k2, () => []).add(ayT[k2] ?? 0);
        }
      }
      final ff = <(String, double)>[
        for (final e in buAy.entries)
          (e.key, e.value - ((onceki[e.key]?.isEmpty ?? true) ? 0 : onceki[e.key]!.reduce((a, b) => a + b) / onceki[e.key]!.length)),
      ]..sort((a, b) => b.$2.compareTo(a.$2));
      for (final (k, f) in ff.take(3)) {
        if (f > 100000) nedenler.add('Faturalarda $k ortalamanın ${_mn(f)} üstünde');
      }
      final t0 = suru.deger(c, yil, m, 'TÜM SÜRÜ'), t1 = suru.deger(c, yil, m - 1 < 1 ? 1 : m - 1, 'TÜM SÜRÜ');
      if (t0 != null && t1 != null && t1 > 0 && (t0 / t1 - 1).abs() > 0.1) {
        nedenler.add('Hayvan sayısı değişti: ${_s(t1, 0)} → ${_s(t0, 0)} baş');
      }
      out.add(Sapma(
        ciftlik: c,
        yil: yil,
        ay: m,
        baslik: 'Gider ${_mn(g)}; önceki 12 ay ortalaması ${_mn(ort)} (${_yuzde((g / ort - 1) * 100)})',
        nedenler: nedenler.isEmpty
            ? ['Faturalarda öne çıkan bir kalem yok; artış faturasız giderlerde (personel, amortisman, stoktan kullanım) olabilir.']
            : nedenler,
      ));
    }
  }

  // C. Tarım ortak giderleri (Maliyet Takip): ayın toplamı ortalamanın %30 üstünde
  if (mt != null && mt.ortak.length >= 4) {
    final ort = mt.ortakToplam / mt.ortak.length;
    double ortK(double? Function(MtOrtak) f) => mt.ortak.fold(0.0, (s, o) => s + (f(o) ?? 0)) / mt.ortak.length;
    for (final o in mt.ortak) {
      if (o.toplam <= ort * 1.3) continue;
      final k = <(String, double)>[
        ('İşçilik', (o.iscilik ?? 0) - ortK((x) => x.iscilik)),
        ('Amortisman', (o.amortisman ?? 0) - ortK((x) => x.amortisman)),
        ('Diğer', (o.diger ?? 0) - ortK((x) => x.diger)),
      ]..sort((a, b) => b.$2.compareTo(a.$2));
      final yilSonu = o.ay == 12 && k.first.$1 == 'Amortisman';
      out.add(Sapma(
        ciftlik: 'Tarım ortak giderleri',
        yil: o.yil,
        ay: o.ay,
        tekSeferlik: yilSonu,
        baslik: 'Ortak gider ${_mn(o.toplam)}; dönem ortalaması ${_mn(ort)} (${_yuzde((o.toplam / ort - 1) * 100)})',
        nedenler: [
          for (final (ad, f) in k)
            if (f > 100000) '$ad ortalamanın ${_mn(f)} üstünde',
          if (yilSonu) 'Yıl sonu amortisman kaydı; tek seferlik, aylara yayılınca eğilimi bozmaz.',
        ],
      ));
    }
  }
  out.sort((a, b) {
    final t = (b.yil * 12 + b.ay).compareTo(a.yil * 12 + a.ay);
    return t != 0 ? t : (b.alarm ? 1 : 0) - (a.alarm ? 1 : 0);
  });
  return out;
}
