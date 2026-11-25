// Çiftlikler Rapor 2026: "2026 Yılı Çiftlik Raporları" dosyasının gelir
// tabloları, satış özeti ve satılan mamul maliyeti (SMM) detayından üretilen
// assets/veri/ciftlik_rapor_2026.json (araclar/ciftlik_rapor/uret.py).
//
// KVKK: yalnızca çiftlik bazında toplam tutar, miktar ve birim maliyet içerir;
// alıcı, kişi adı ve küpe numarası yoktur.
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../bicim.dart';

const raporAylari = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

/// Maliyet kalemleri (SMM detayındaki sıra).
const maliyetBilesenleri = ['Hammadde (yem)', 'Direkt işçilik', 'Enerji', 'Bakım onarım', 'Endirekt işçilik', 'Genel üretim', 'Amortisman'];

const kKonsolide = 'Konsolide (tüm çiftlikler)';
const kCiftliklerimiz = 'Çiftliklerimiz (ESK hariç)';
const kEsk = 'ESK-Taşağıl (Besi hizmeti)';

const kSekersut = 'Süt – Şekersüt';
const kPangev = 'Süt – Pan-Gev';
const kEskHizmet = 'ESK besi hizmeti';

/// Gelir tablosu satırı: bir çiftliğin bir kalemi.
class GelirKalemi {
  const GelirKalemi({
    required this.ciftlik,
    required this.bolum,
    required this.kalem,
    required this.y2026,
    required this.y2025Donem,
    required this.y2025Yil,
    required this.y2024Yil,
  });
  final String ciftlik, bolum, kalem;

  /// 2026 Ocak–Eylül, 2025 aynı dönem, 2025 ve 2024 yıl toplamları (TL).
  final double y2026, y2025Donem, y2025Yil, y2024Yil;

  factory GelirKalemi.json(Map<String, dynamic> j) => GelirKalemi(
        ciftlik: j['ciftlik'] as String,
        bolum: j['bolum'] as String,
        kalem: j['kalem'] as String,
        y2026: (j['y2026_9ay'] as num).toDouble(),
        y2025Donem: (j['y2025_9ay'] as num).toDouble(),
        y2025Yil: (j['y2025_yil'] as num).toDouble(),
        y2024Yil: (j['y2024_yil'] as num).toDouble(),
      );
}

class AylikSonuc {
  const AylikSonuc(this.ciftlik, this.ayNo, this.brutKar, this.netKar);
  final String ciftlik;
  final int ayNo;
  final double brutKar, netKar;
  String get ay => raporAylari[ayNo - 1];
}

/// Süt ve ESK hizmeti için aylık üretim maliyeti.
class BirimAy {
  const BirimAy({
    required this.urun,
    required this.yil,
    required this.ayNo,
    required this.miktar,
    required this.toplam,
    required this.bilesen,
    required this.satisMiktar,
    required this.satisTl,
    required this.tutarsiz,
  });
  final String urun;
  final int yil, ayNo;
  final double miktar, toplam, satisMiktar, satisTl;
  final Map<String, double> bilesen;

  /// Kayıt tutarsızlığı (ör. hizmet maliyetine yalnız hammadde yazılmış ay):
  /// ortalamalara ve grafiğe alınmaz.
  final bool tutarsiz;

  double get birimMaliyet => miktar == 0 ? 0 : toplam / miktar;
  double? get fiyat => satisMiktar == 0 ? null : satisTl / satisMiktar;
  double bilesenBirim(String k) => miktar == 0 ? 0 : (bilesen[k] ?? 0) / miktar;
  String get etiket => '${raporAylari[ayNo - 1].substring(0, 3)} ${yil % 100}';
  String get donem => '${raporAylari[ayNo - 1]} $yil';

  factory BirimAy.json(Map<String, dynamic> j) => BirimAy(
        urun: j['urun'] as String,
        yil: j['yil'] as int,
        ayNo: j['ay_no'] as int,
        miktar: (j['miktar'] as num).toDouble(),
        toplam: (j['toplam'] as num).toDouble(),
        bilesen: {for (final e in (j['bilesen'] as Map<String, dynamic>).entries) e.key: (e.value as num).toDouble()},
        satisMiktar: (j['satis_miktar'] as num).toDouble(),
        satisTl: (j['satis_tl'] as num).toDouble(),
        tutarsiz: j['tutarsiz'] as bool? ?? false,
      );
}

/// Bir dönemin miktar ağırlıklı ortalaması.
class BirimDonem {
  BirimDonem(this.urun, this.yil, List<BirimAy> aylar)
      : aylar = [for (final a in aylar) if (!a.tutarsiz) a];
  final String urun;
  final int yil;
  final List<BirimAy> aylar;

  bool get bos => aylar.isEmpty;
  double get miktar => aylar.fold(0.0, (t, a) => t + a.miktar);
  double get birimMaliyet => miktar == 0 ? 0 : aylar.fold(0.0, (t, a) => t + a.toplam) / miktar;
  double? get fiyat {
    final m = aylar.fold(0.0, (t, a) => t + a.satisMiktar);
    return m == 0 ? null : aylar.fold(0.0, (t, a) => t + a.satisTl) / m;
  }

  double? get birimKar => fiyat == null ? null : fiyat! - birimMaliyet;
  double bilesen(String k) => miktar == 0 ? 0 : aylar.fold(0.0, (t, a) => t + (a.bilesen[k] ?? 0)) / miktar;
  String get donem => bos
      ? '—'
      : '${raporAylari[aylar.first.ayNo - 1].substring(0, 3)}–${raporAylari[aylar.last.ayNo - 1].substring(0, 3)} $yil';
}

class TarimUrun {
  const TarimUrun({
    required this.ciftlik,
    required this.urun,
    required this.yil,
    required this.satisKg,
    required this.satisTl,
    required this.smmKg,
    required this.smmTl,
  });
  final String ciftlik, urun;
  final int yil;
  final double satisKg, satisTl, smmKg, smmTl;
  double? get fiyat => satisKg == 0 ? null : satisTl / satisKg;
  double? get birimMaliyet => smmKg == 0 ? null : smmTl / smmKg;
  double? get birimKar => fiyat == null || birimMaliyet == null ? null : fiyat! - birimMaliyet!;

  factory TarimUrun.json(Map<String, dynamic> j) => TarimUrun(
        ciftlik: j['ciftlik'] as String,
        urun: j['urun'] as String,
        yil: j['yil'] as int,
        satisKg: (j['satis_kg'] as num).toDouble(),
        satisTl: (j['satis_tl'] as num).toDouble(),
        smmKg: (j['smm_kg'] as num).toDouble(),
        smmTl: (j['smm_tl'] as num).toDouble(),
      );
}

/// Bir maliyet kaleminin iki dönem arasındaki farkı (TL/birim).
class KalemFarki {
  const KalemFarki(this.kalem, this.once, this.sonra);
  final String kalem;
  final double once, sonra;
  double get fark => sonra - once;
}

class CiftlikRaporu {
  CiftlikRaporu({
    required this.baslik,
    required this.kaynak,
    required this.donem,
    required this.gelir,
    required this.aylik,
    required this.birim,
    required this.tarim,
    required this.tesvik,
  });

  final String baslik, kaynak, donem;
  final List<GelirKalemi> gelir;
  final List<AylikSonuc> aylik;
  final List<BirimAy> birim;
  final List<TarimUrun> tarim;

  /// (yıl, kalem) → tutar
  final Map<(int, String), double> tesvik;

  static CiftlikRaporu coz(String metin) {
    final j = jsonDecode(metin) as Map<String, dynamic>;
    List<Map<String, dynamic>> l(String k) => (j[k] as List).cast<Map<String, dynamic>>();
    return CiftlikRaporu(
      baslik: j['baslik'] as String,
      kaynak: j['kaynak'] as String,
      donem: j['donem'] as String,
      gelir: [for (final x in l('gelir')) GelirKalemi.json(x)],
      aylik: [
        for (final x in l('aylik'))
          AylikSonuc(x['ciftlik'] as String, x['ay_no'] as int, (x['brut_kar'] as num).toDouble(), (x['net_kar'] as num).toDouble()),
      ],
      birim: [for (final x in l('birim')) BirimAy.json(x)],
      tarim: [for (final x in l('tarim')) TarimUrun.json(x)],
      tesvik: {for (final x in l('tesvik')) (x['yil'] as int, x['kalem'] as String): (x['tutar'] as num).toDouble()},
    );
  }

  static Future<CiftlikRaporu> yukle() async =>
      coz(await rootBundle.loadString('assets/veri/ciftlik_rapor_2026.json'));

  /// Seçicide gösterilen çiftlikler (dosyadaki sırayla, toplamlar başta).
  List<String> get ciftlikler {
    final l = <String>[];
    for (final g in gelir) {
      if (!l.contains(g.ciftlik)) l.add(g.ciftlik);
    }
    l.sort((a, b) => _sira(a).compareTo(_sira(b)));
    return l;
  }

  static int _sira(String c) => switch (c) { kKonsolide => 0, kCiftliklerimiz => 1, kEsk => 9, _ => 5 };

  GelirKalemi? kalem(String ciftlik, String kalem) {
    for (final g in gelir) {
      if (g.ciftlik == ciftlik && g.kalem == kalem) return g;
    }
    return null;
  }

  double d26(String c, String k) => kalem(c, k)?.y2026 ?? 0;
  double d25(String c, String k) => kalem(c, k)?.y2025Donem ?? 0;

  /// Faaliyet dışı net: (649 + 679 gelirleri) − (65 + 68 giderleri).
  double faaliyetDisi(String c, {bool y2025 = false}) {
    double f(String k) => y2025 ? d25(c, k) : d26(c, k);
    return f('Diğer olağan gelirler (649)') + f('Olağandışı gelirler (679)') - f('Diğer olağan giderler') - f('Olağandışı giderler');
  }

  List<AylikSonuc> aylikSonuc(String ciftlik) => [for (final a in aylik) if (a.ciftlik == ciftlik) a]
    ..sort((a, b) => a.ayNo.compareTo(b.ayNo));

  List<BirimAy> birimAylar(String urun) => [for (final b in birim) if (b.urun == urun) b]
    ..sort((a, b) => a.yil != b.yil ? a.yil.compareTo(b.yil) : a.ayNo.compareTo(b.ayNo));

  BirimDonem donemOrt(String urun, int yil) => BirimDonem(urun, yil, [for (final b in birimAylar(urun)) if (b.yil == yil) b]);

  /// 2025 → 2026 kalem farkları, artışı en büyükten küçüğe.
  List<KalemFarki> kalemFarklari(String urun) {
    final a = donemOrt(urun, 2025), b = donemOrt(urun, 2026);
    return [for (final k in maliyetBilesenleri) KalemFarki(k, a.bilesen(k), b.bilesen(k))]
      ..sort((x, y) => y.fark.compareTo(x.fark));
  }

  /// Ayın en yüksek maliyetli (tutarsız olmayan) ayı ve o ayda en çok artan kalem.
  (BirimAy, String)? zirveAy(String urun, int yil) {
    final l = [for (final b in birimAylar(urun)) if (b.yil == yil && !b.tutarsiz) b];
    if (l.isEmpty) return null;
    l.sort((a, b) => b.birimMaliyet.compareTo(a.birimMaliyet));
    final z = l.first;
    final ort = donemOrt(urun, yil);
    var enK = maliyetBilesenleri.first;
    var enF = double.negativeInfinity;
    for (final k in maliyetBilesenleri) {
      final f = z.bilesenBirim(k) - ort.bilesen(k);
      if (f > enF) {
        enF = f;
        enK = k;
      }
    }
    return (z, enK);
  }

  TarimUrun? tarimUrun(String ciftlik, String urun, int yil) {
    for (final t in tarim) {
      if (t.ciftlik == ciftlik && t.urun == urun && t.yil == yil) return t;
    }
    return null;
  }

  double tesvikTutar(int yil, String kalem) => tesvik[(yil, kalem)] ?? 0;
}

// ------------------------------------------------------------------ biçim ve neden metinleri

/// 12.345.678 → "12,3 mn ₺"; işaret korunur.
String mn(double v) => '${v < 0 ? '−' : ''}${sayi(v.abs() / 1e6, ondalik: 1)} mn ₺';

/// Kâr ise "12,3 mn ₺ kâr", zarar ise "4,1 mn ₺ zarar".
String kz(double v) => '${sayi(v.abs() / 1e6, ondalik: 1)} mn ₺ ${v >= 0 ? 'kâr' : 'zarar'}';

/// 31,36 ₺
String tl2(double? v) => v == null ? '—' : '${v < 0 ? '−' : ''}${sayi(v.abs(), ondalik: 2)} ₺';

/// +2,70 ₺ / −1,10 ₺
String tl2f(double? v) => v == null ? '—' : '${v > 0 ? '+' : v < 0 ? '−' : ''}${sayi(v.abs(), ondalik: 2)} ₺';

/// +%34
String yuzde(double v) => '${v >= 0 ? '+' : '−'}%${sayi(v.abs())}';

List<(String, String)> karZararNedenleri(CiftlikRaporu r) {
  const k = kKonsolide;
  final l = <(String, String)>[];
  final fin25 = r.d25(k, 'Finansman giderleri'), fin26 = r.d26(k, 'Finansman giderleri');
  if (fin25 - fin26 > 500000) {
    l.add(('Finansman yükü azaldı', 'Kısa vadeli borçlanma gideri 2025 aynı dönemde ${mn(fin25)} iken 2026’da ${mn(fin26)}.'));
  }
  final od25 = r.d25(k, 'Olağandışı giderler'), od26 = r.d26(k, 'Olağandışı giderler');
  if (od25 - od26 > 500000) {
    l.add(('Olağandışı giderler düştü',
        '2025 aynı dönemde ${mn(od25)} (ağırlıklı olarak Taşağıl’ın çalışmayan kısım amortismanı) iken 2026’da ${mn(od26)}.'));
  }
  // faaliyet dışı gelirin en çok olduğu çiftlik
  final cs = [for (final c in r.ciftlikler) if (c != kKonsolide && c != kCiftliklerimiz) c]
    ..sort((a, b) => r.faaliyetDisi(b).compareTo(r.faaliyetDisi(a)));
  if (cs.isNotEmpty) {
    final c = cs.first;
    final b = r.d26(c, 'Brüt satış kârı/zararı');
    l.add(('Faaliyet dışı gelirler sonucu belirliyor',
        '$c’te ${mn(r.d26(c, 'Diğer olağan gelirler (649)'))} diğer olağan gelir ve ${mn(r.d26(c, 'Olağandışı gelirler (679)'))} olağandışı gelir yer alıyor'
        '${b < 0 ? '; bu nedenle brüt zarara (${mn(b)}) rağmen net sonuç ${kz(r.d26(c, 'Dönem net kârı/zararı'))}' : ''}. '
        'Bu gelirlerin içeriği dosyada ayrıştırılmamıştır; muhasebeden teyit edilmesi önerilir.'));
  }
  final tb26 = r.d26('Tarımsal Alan', 'Brüt satış kârı/zararı'), tb25 = r.d25('Tarımsal Alan', 'Brüt satış kârı/zararı');
  l.add(('Tarım', 'Tarımsal Alan brüt kârı ${mn(tb26)} (2025 aynı dönem ${mn(tb25)}); ayrıntı Tarım sekmesinde.'));
  final t = [
    for (final x in ['Tarımsal teşvik', 'Buzağı teşviki', 'Süt teşviki'])
      if (r.tesvikTutar(2026, x) > 0) '${x.toLowerCase()} ${mn(r.tesvikTutar(2026, x))}',
  ];
  if (t.isNotEmpty) l.add(('Teşvik gelirleri', '2026’da ${t.join(', ')} gelir kaydedilmiştir.'));
  l.add(('ESK-Taşağıl', 'ESK’ya verilen besi hizmeti ve sap satışında brüt sonuç ${mn(r.d26(kEsk, 'Brüt satış kârı/zararı'))}, '
      'dönem net sonucu ${kz(r.d26(kEsk, 'Dönem net kârı/zararı'))} (Et / Besi sekmesi).'));
  final ag = r.d26('Aslım', 'Faaliyet giderleri'), aa = r.d26('Aslım', 'Amortisman');
  if (ag + aa > 0) {
    l.add(('Aslım', 'Üretim yokken genel yönetim gideri ${mn(ag)} ve amortisman ${mn(aa)} taşınmaktadır.'));
  }
  return l;
}

/// Bir ürünün maliyet değişim nedenleri (artan ilk 3 kalem, fiyat etkisi, zirve ay).
List<(String, String)> birimNedenleri(CiftlikRaporu r, String urun, String ad, String birim) {
  final a = r.donemOrt(urun, 2025), b = r.donemOrt(urun, 2026);
  if (a.bos || b.bos) return const [];
  final fark = b.birimMaliyet - a.birimMaliyet;
  final kalemler = r.kalemFarklari(urun);
  final artan = [for (final k in kalemler) if (k.fark > 0.05) k].take(3).toList();
  final azalan = [for (final k in kalemler.reversed) if (k.fark < -0.05) k].take(2).toList();
  final l = <(String, String)>[];
  l.add((
    '$ad – birim maliyet ${fark >= 0 ? 'yükseldi' : 'düştü'}',
    '${a.donem} ortalaması ${tl2(a.birimMaliyet)}/$birim iken ${b.donem} ortalaması ${tl2(b.birimMaliyet)}/$birim (${tl2f(fark)}). '
        '${artan.isEmpty ? '' : 'Artışa en çok katkı veren kalemler: ${artan.map((k) => '${k.kalem.toLowerCase()} ${tl2f(k.fark)}').join(', ')}. '}'
        '${azalan.isEmpty ? '' : 'Azalan kalemler: ${azalan.map((k) => '${k.kalem.toLowerCase()} ${tl2f(k.fark)}').join(', ')}.'}'
  ));
  if (a.fiyat != null && b.fiyat != null) {
    final bk = b.birimKar!;
    l.add((
      '$ad – fiyat ve kârlılık',
      'Satış fiyatı ${tl2(a.fiyat)}’den ${tl2(b.fiyat)}’ye (${tl2f(b.fiyat! - a.fiyat!)}) çıktı. '
          '${bk >= 0 ? '$birim başına ${tl2(bk)} kâr elde ediliyor' : 'Fiyat maliyetin altında kaldığı için $birim başına ${tl2(-bk)} zarar ediliyor'} '
          '(2025: ${tl2f(a.birimKar)}).'
    ));
  }
  final z = r.zirveAy(urun, 2026);
  if (z != null) {
    final (ay, k) = z;
    l.add((
      '$ad – en yüksek maliyetli ay',
      '${ay.donem}: ${tl2(ay.birimMaliyet)}/$birim. Bu ayda dönem ortalamasına göre en çok artan kalem ${k.toLowerCase()} '
          '(${tl2(ay.bilesenBirim(k))}/$birim, ortalama ${tl2(b.bilesen(k))}/$birim).'
    ));
  }
  return l;
}

