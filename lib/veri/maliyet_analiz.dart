// Maliyet Takip 2026 verisinin yorumları: hayvan başı maliyet, süt litre
// maliyeti, tarım dekar başı maliyet ve yem fiyatı değişimlerinin nedenleri.
import '../bicim.dart';
import 'ciftlik_rapor.dart';
import 'maliyet_takip.dart';

String tl0(double? v) => v == null ? '—' : '${v < 0 ? '−' : ''}${sayi(v.abs())} ₺';

/// Hayvan başı aylık maliyetin Ocak → son ay değişimi ve nedenleri.
List<(String, String)> hayvanNedenleri(MaliyetTakip m, String c) {
  final l = m.hayvanAylar(c, 2026);
  if (l.length < 2) return const [];
  final a = l.first, b = l.last;
  final fark = b.basinaAylik! - a.basinaAylik!;
  final kalemler = [
    for (final k in a.kalemler.keys) (k, (b.basina(b.kalemler[k]) ?? 0) - (a.basina(a.kalemler[k]) ?? 0)),
  ]..sort((x, y) => y.$2.compareTo(x.$2));
  final hayvanDegisim = (b.hayvan! / a.hayvan! - 1) * 100;
  final toplamDegisim = (b.toplam! / a.toplam! - 1) * 100;
  final zirve = [...l]..sort((x, y) => y.basinaAylik!.compareTo(x.basinaAylik!));
  final out = <(String, String)>[
    (
      '$c – hayvan başı aylık maliyet ${fark >= 0 ? 'yükseldi' : 'düştü'}',
      '${raporAylari[a.ay - 1]} ${tl0(a.basinaAylik)} → ${raporAylari[b.ay - 1]} ${tl0(b.basinaAylik)} (${tl0(fark)}). '
          'Toplam maliyet ${yuzde(toplamDegisim)}, hayvan sayısı ${yuzde(hayvanDegisim)} (${sayi(a.hayvan)} → ${sayi(b.hayvan)}). '
          'Hayvan başı en çok artan kalemler: ${kalemler.where((x) => x.$2 > 0).take(3).map((x) => '${x.$1.toLowerCase()} ${tl0(x.$2)}').join(', ')}.'
    ),
  ];
  if (hayvanDegisim < -20) {
    out.add((
      '$c – sabit gider etkisi',
      'Hayvan sayısı azalırken amortisman ve diğer sabit giderler aynı kaldığı için hayvan başına düşen maliyet yükseliyor '
          '(${raporAylari[b.ay - 1]} hayvan başı amortisman ${tl0(b.basina(b.amortisman))}, Ocak ${tl0(a.basina(a.amortisman))}).'
    ));
  }
  out.add(('$c – en yüksek maliyetli ay',
      '${raporAylari[zirve.first.ay - 1]}: hayvan başı ${tl0(zirve.first.basinaAylik)} (günlük ${tl0(zirve.first.basinaGunluk)}), ${sayi(zirve.first.hayvan)} baş.'));
  return out;
}

/// Ana yem kalemlerinde Ocak → son ay birim fiyat değişimi.
List<String> yemFiyatDegisimleri(MaliyetTakip m, String grup, {int adet = 4}) {
  final out = <String>[];
  for (final (malzeme, tutar) in m.anaYemler(grup).take(adet)) {
    final a = m.yemAylar(grup, malzeme);
    if (a.length < 2) continue;
    final f = (a.last.fiyat! / a.first.fiyat! - 1) * 100;
    out.add('${_yemAdi(malzeme)}: ${sayi(a.first.fiyat, ondalik: 2)} → ${sayi(a.last.fiyat, ondalik: 2)} ₺/kg (${yuzde(f)}), dönem ${mn(tutar)}');
  }
  return out;
}

String _yemAdi(String m) {
  final s = m.toLowerCase().replaceAll('(hammadde)', '').replaceAll(' 1.000 kg', '').trim();
  return s.isEmpty ? m : '${s[0].toUpperCase()}${s.substring(1)}';
}

/// Süt litre maliyeti: 2025 → 2026 aynı ay karşılaştırması ve son ay.
List<(String, String)> sutTakipNedenleri(MaliyetTakip m, String c) {
  final a26 = m.sutAylar(c, 2026);
  if (a26.isEmpty) return const [];
  final son = a26.last;
  final once = m.sutAylar(c, 2025).where((x) => x.ay == son.ay).firstOrNull;
  final out = <(String, String)>[
    (
      '$c – ${raporAylari[son.ay - 1]} 2026 litre maliyeti',
      '${tl2(son.maliyet)}${son.satis == null ? '' : ', satış fiyatı ${tl2(son.satis)} (litre başı ${tl2f(son.satis! - son.maliyet)})'}'
          '${once == null ? '' : '; 2025 aynı ay ${tl2(once.maliyet)} (${yuzde((son.maliyet / once.maliyet - 1) * 100)})'}.'
    ),
  ];
  final grup = c == 'Şekersüt' ? 'Şekersüt anaç' : 'Pan-Gev anaç';
  final y = yemFiyatDegisimleri(m, grup, adet: 3);
  if (y.isNotEmpty) out.add(('$c – sağmal yem fiyatları (Ocak → Eylül)', '${y.join('; ')}.'));
  return out;
}

/// Tarım: ürün bazında dekar başı maliyet ve ortak gider payı.
class DekarSatiri {
  const DekarSatiri(this.e, this.ortakPay);
  final MtEkilis e;
  final double ortakPay;
  double? get dekarBasi => e.dekarBasi;
  double? get payliDekarBasi => e.dekarBasi == null ? null : e.dekarBasi! + ortakPay;
}

List<DekarSatiri> dekarSatirlari(MaliyetTakip m) => [for (final e in m.ekilis) DekarSatiri(e, m.ortakDekarBasi)];

List<(String, String)> tarimTakipNedenleri(CiftlikRaporu r) {
  final m = r.mt;
  if (m == null) return const [];
  final out = <(String, String)>[];
  out.add((
    'Ortak giderler ürünlere dağıtılmamış',
    'Tarım ortak giderleri (işçilik, amortisman, diğer) ${mn(m.ortakToplam)}; ürün maliyetlerine yansıtılmamıştır. Ekili alana '
        '(${sayi(m.toplamDekar)} da) göre dağıtıldığında dekar başına yaklaşık ${tl0(m.ortakDekarBasi)} eklenir.'
  ));
  // Aynı ürünün çiftlikler arası farkı
  final urunler = <String, List<MtEkilis>>{};
  for (final e in m.ekilis) {
    (urunler[e.urun] ??= []).add(e);
  }
  for (final e in urunler.entries) {
    final l = [for (final x in e.value) if (x.dekarBasi != null) x]..sort((a, b) => b.dekarBasi!.compareTo(a.dekarBasi!));
    if (l.length < 2) continue;
    final f = (l.first.dekarBasi! / l.last.dekarBasi! - 1) * 100;
    out.add((
      '${e.key} – çiftlikler arası fark',
      '${l.map((x) => '${x.ciftlik} ${tl0(x.dekarBasi)}/da').join(', ')} (en yüksek ile en düşük arası ${yuzde(f)}).'
    ));
  }
  // Buğday: maliyet takip + satış ile kg maliyeti
  final bugday = r.tarimUrun('Tarımsal Alan', 'Buğday', 2026);
  final bm = [for (final e in m.ekilis) if (e.urun == 'Buğday') e];
  if (bugday != null && bugday.satisKg > 0 && bm.isNotEmpty) {
    final maliyet = bm.fold(0.0, (s, e) => s + e.toplam);
    final dekar = bm.fold(0.0, (s, e) => s + (e.dekar ?? 0));
    final kg = maliyet / bugday.satisKg, kgPayli = (maliyet + dekar * m.ortakDekarBasi) / bugday.satisKg;
    out.add((
      'Buğday – iki dosyanın karşılaştırması',
      'Maliyet takibindeki buğday gideri ${mn(maliyet)} (${sayi(dekar)} da), 2026 satışı ${sayi(bugday.satisKg)} kg '
          '(dekar başı ${sayi(bugday.satisKg / dekar)} kg). Buna göre kg maliyeti ${tl2(kg)}, ortak gider payıyla ${tl2(kgPayli)}; '
          'gelir tablosundaki satılan mamul maliyeti ${tl2(bugday.birimMaliyet)}/kg. Satış fiyatı ${tl2(bugday.fiyat)}/kg.'
    ));
  }
  return out;
}


/// Bir ayın süt litre maliyeti: takip dosyası ve muhasebe (Çiftlik Raporları) yan yana.
/// Satış fiyatı takipte yoksa muhasebedeki faturalanan ortalama kullanılır (mükerrer giriş yok).
typedef SutEslesme = ({double? takip, double? muhasebe, double? satis, bool satisMuhasebeden});

SutEslesme sutEslesme(CiftlikRaporu r, String c, int ay, {int yil = 2026}) {
  final t = r.mt?.sutAylar(c, yil).where((x) => x.ay == ay).firstOrNull;
  final u = c == 'Şekersüt' ? kSekersut : kPangev;
  final b = r.birimAylar(u).where((x) => x.yil == yil && x.ayNo == ay && x.miktar > 0).firstOrNull;
  final mf = b?.fiyat;
  return (
    takip: t?.maliyet,
    muhasebe: b?.birimMaliyet,
    satis: t?.satis ?? mf,
    satisMuhasebeden: t?.satis == null && mf != null,
  );
}
