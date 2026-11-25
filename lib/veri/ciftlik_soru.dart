// Çiftlikler Rapor 2026 – soru-cevap: soruyu çözümleyip paketli rapor
// verisinden (ciftlik_rapor_2026.json) yanıt üretir; ilgili olumsuz sonuçları
// ve veri tutarsızlıklarını ayrıca işaretler. Çevrimdışı çalışır; soru ve
// veri cihaz dışına gönderilmez.
import '../bicim.dart';
import 'ciftlik_rapor.dart';
import 'maliyet_analiz.dart';
import 'maliyet_takip.dart';
import 'senaryo.dart';

enum BulguTuru { olumsuz, tutarsizlik }

/// Olumsuz sonuç (zarar, maliyetin fiyatı aşması) ya da veri tutarsızlığı.
class Bulgu {
  const Bulgu(this.tur, this.baslik, this.aciklama, this.konular, {this.kaynak = ''});
  final BulguTuru tur;
  final String baslik, aciklama;

  /// Dosyadaki yeri (sayfa · satır · sütun); boşsa gösterilmez.
  final String kaynak;

  /// Eşleştirme etiketleri: çiftlik adları, 'süt', 'et', 'tarım', ürün adları, 'finans'.
  final Set<String> konular;
}

class Yanit {
  const Yanit({required this.soru, required this.paragraflar, required this.bulgular, this.anlasildi = true});
  final String soru;
  final List<String> paragraflar;
  final List<Bulgu> bulgular;

  /// Soruda tanınan bir konu bulunamadıysa false.
  final bool anlasildi;
}

// ------------------------------------------------------------------ bulgular

const _sutCiftlik = {kSekersut: 'Şekersüt', kPangev: 'Pan-Gev', kEskHizmet: kEsk};

/// Dosyadaki tüm olumsuz sonuçlar ve tutarsızlıklar.
List<Bulgu> tumBulgular(CiftlikRaporu r) {
  final l = <Bulgu>[];
  const net = 'Dönem net kârı/zararı', brut = 'Brüt satış kârı/zararı';

  // Zarar eden çiftlikler
  for (final c in r.ciftlikler) {
    final n = r.d26(c, net), b = r.d26(c, brut);
    if (n < 0) {
      l.add(Bulgu(BulguTuru.olumsuz, '$c dönem zararı', '${r.donem} dönem net sonucu ${kz(n)} (2025 aynı dönem ${kz(r.d25(c, net))}).',
          {c, 'finans', if (c == kEsk) 'et', if (c == 'Aslım') 'et'}));
    }
    if (b < 0 && n >= 0) {
      l.add(Bulgu(
          BulguTuru.olumsuz,
          '$c brüt zararda',
          'Esas faaliyette brüt satış sonucu ${mn(b)}; dönem net sonucu yalnızca faaliyet dışı gelirlerle (${mn(r.faaliyetDisi(c))}) pozitife dönüyor.',
          {c, 'finans', if (c == 'Şekersüt' || c == 'Pan-Gev') 'süt'}));
    }
  }
  // Faaliyet dışı gelirin brüt kârı aşması
  for (final c in [kKonsolide, ...r.ciftlikler.where((x) => x != kKonsolide && x != kCiftliklerimiz)]) {
    final fd = r.faaliyetDisi(c), b = r.d26(c, brut);
    if (fd > 1e6 && fd > b.abs()) {
      l.add(Bulgu(
          BulguTuru.tutarsizlik,
          '$c – faaliyet dışı gelir ağırlığı',
          'Net faaliyet dışı gelir (${mn(fd)}) brüt satış sonucundan (${mn(b)}) büyük. 649/679 hesaplarının içeriği dosyada ayrıştırılmamıştır; '
              'muhasebeden teyit edilmelidir.',
          {c, 'finans'}));
    }
  }
  // Aylık: brüt zarar varken net kâr çok yüksek olan aylar
  for (final c in r.ciftlikler) {
    for (final a in r.aylikSonuc(c)) {
      if (a.brutKar < 0 && a.netKar > 3e6) {
        l.add(Bulgu(BulguTuru.tutarsizlik, '$c – ${a.ay} 2026',
            'Brüt sonuç ${mn(a.brutKar)} iken net sonuç ${mn(a.netKar)}: ayın sonucunu faaliyet dışı bir kayıt belirliyor.', {c, 'finans', a.ay}));
      }
    }
  }
  // Birim maliyet: maliyetin fiyatı aşması, negatif kalem, miktar farkı, kayıt tutarsızlığı
  for (final u in [kSekersut, kPangev, kEskHizmet]) {
    final etiket = {_sutCiftlik[u]!, if (u == kEskHizmet) 'et' else 'süt'};
    final d = r.donemOrt(u, 2026);
    if (d.birimKar != null && d.birimKar! < 0) {
      l.add(Bulgu(BulguTuru.olumsuz, '${_sutCiftlik[u]} – birim maliyet fiyatın üstünde',
          '${d.donem}: maliyet ${tl2(d.birimMaliyet)}, fiyat ${tl2(d.fiyat)}; birim başına ${tl2(-d.birimKar!)} zarar.', etiket));
    }
    final zararAylar = [for (final a in d.aylar) if (a.fiyat != null && a.fiyat! < a.birimMaliyet) a.donem];
    if (zararAylar.isNotEmpty && zararAylar.length < d.aylar.length) {
      l.add(Bulgu(BulguTuru.olumsuz, '${_sutCiftlik[u]} – maliyetin fiyatı aştığı aylar', zararAylar.join(', '), etiket));
    }
    for (final a in r.birimAylar(u)) {
      if (a.tutarsiz) {
        l.add(Bulgu(BulguTuru.tutarsizlik, '${_sutCiftlik[u]} – ${a.donem} maliyet kaydı',
            'Maliyete yalnızca hammadde yazılmış (${tl2(a.birimMaliyet)}/birim); işçilik, enerji, amortisman yok. Ortalamaya alınmadı.', {...etiket, raporAylari[a.ayNo - 1]}));
        continue;
      }
      for (final e in a.bilesen.entries) {
        if (e.value < 0) {
          l.add(Bulgu(BulguTuru.tutarsizlik, '${_sutCiftlik[u]} – ${a.donem} negatif maliyet kalemi',
              '${e.key} ${mn(e.value)} olarak eksi kaydedilmiş (düzeltme kaydı); o ayın birim maliyeti olduğundan düşük görünür.', {...etiket, raporAylari[a.ayNo - 1]}));
        }
      }
      if (a.satisMiktar > 0 && (a.satisMiktar - a.miktar).abs() / a.miktar > 0.02) {
        l.add(Bulgu(BulguTuru.tutarsizlik, '${_sutCiftlik[u]} – ${a.donem} miktar farkı',
            'Satış miktarı ${sayi(a.satisMiktar)}, maliyet miktarı ${sayi(a.miktar)} (fark ${yuzde((a.satisMiktar / a.miktar - 1) * 100)}).', {...etiket, raporAylari[a.ayNo - 1]}));
      }
    }
  }
  // Pan-Gev'de direkt işçilik yüklenmemesi
  final pDi = r.donemOrt(kPangev, 2026).bilesen('Direkt işçilik');
  final sDi = r.donemOrt(kSekersut, 2026).bilesen('Direkt işçilik');
  if (pDi < 0.05 && sDi > 0.5) {
    l.add(Bulgu(BulguTuru.tutarsizlik, 'Pan-Gev – direkt işçilik maliyete yüklenmemiş',
        'Pan-Gev’de litre başı direkt işçilik ${tl2(pDi)}, Şekersüt’te ${tl2(sDi)}. İki çiftliğin litre maliyetleri aynı esasla karşılaştırılamaz.', {'Pan-Gev', 'Şekersüt', 'süt'}));
  }
  // Tarım
  for (final t in r.tarim) {
    final etiket = {'tarım', t.urun, t.ciftlik, if (t.ciftlik == 'ESK-Taşağıl') kEsk};
    if (t.birimKar != null && t.birimKar! < 0) {
      l.add(Bulgu(BulguTuru.olumsuz, '${t.urun} ${t.yil} – maliyetin altında satış',
          'Kg maliyeti ${tl2(t.birimMaliyet)}, satış fiyatı ${tl2(t.fiyat)}: kg başı ${tl2(-t.birimKar!)} zarar (${mn(t.satisTl - t.smmTl)}).', etiket));
    }
    if (t.satisKg == 0 && t.satisTl != 0) {
      l.add(Bulgu(BulguTuru.tutarsizlik, '${t.urun} ${t.yil} – miktarsız gelir',
          '${mn(t.satisTl)} gelir miktar olmadan kaydedilmiş (fiyat farkı/prim olabilir); birim fiyat hesaplanamaz.', etiket));
    }
    if (t.satisKg > 0 && t.smmKg > 0 && (t.satisKg - t.smmKg).abs() / t.satisKg > 0.02) {
      l.add(Bulgu(BulguTuru.tutarsizlik, '${t.urun} ${t.yil} – satış ve maliyet miktarı farklı',
          'Satış ${sayi(t.satisKg)} kg, maliyete alınan ${sayi(t.smmKg)} kg. Birim maliyet ve kâr bu farktan etkilenir.', etiket));
    }
  }
  if (r.mt != null) l.addAll(maliyetTakipBulgulari(r));
  l.addAll(senaryoBulgulari(r));
  return l;
}

/// Piyasa senaryosu ("2" uzantılı sayfalar) olumsuz sonuçları ve tutarsızlıkları.
List<Bulgu> senaryoBulgulari(CiftlikRaporu r, {int? yil}) {
  final s = r.senaryo;
  if (s == null) return const [];
  final l = <Bulgu>[];
  for (final y in s.yillar) {
    if (yil != null && y != yil) continue;
    for (final c in s.ciftlikler) {
      if (c.ciftlik == kSenaryoToplam || c.sayfa.isEmpty) continue;
      final d = c.donemler[y];
      if (d == null) continue;
      final aylar = d.doluAylar;
      if (aylar.isEmpty) continue;
      final s2 = '${c.sayfa} 2';
      final n1 = d.toplam('Dönem net kârı/zararı', 1), n2 = d.toplam('Dönem net kârı/zararı', 2);
      final b2 = d.toplam('Brüt satış kârı/zararı', 2);
      final donem = '${raporAylari[aylar.first - 1]}–${raporAylari[aylar.last - 1]} $y';
      if (n2 < 0) {
        l.add(Bulgu(BulguTuru.olumsuz, '${c.ciftlik} – piyasa fiyatlarıyla zarar ($y)',
            'Grup içi ürünler piyasa fiyatıyla değerlendiğinde $donem sonucu ${kz(n2)} (maliyet bedeliyle ${kz(n1)}; fark ${mnFark(n2 - n1)}).',
            {c.ciftlik, 'senaryo', 'finans', '$y', if (c.ciftlik == 'Aslım') 'et'},
            kaynak: senaryoKonum(s2, kSatirNet, y, aylar)));
      } else if (n2 - n1 < -1e6) {
        l.add(Bulgu(BulguTuru.olumsuz, '${c.ciftlik} – piyasa fiyatlarıyla kâr düşüyor ($y)',
            '$donem piyasa senaryosunda sonuç ${kz(n2)}, maliyet senaryosunda ${kz(n1)}.', {c.ciftlik, 'senaryo', 'finans', '$y'},
            kaynak: senaryoKonum(s2, kSatirNet, y, aylar)));
      }
      if (b2 < 0) {
        l.add(Bulgu(BulguTuru.olumsuz, '${c.ciftlik} – piyasa senaryosunda brüt zarar ($y)',
            '$donem piyasa fiyatlarıyla brüt satış sonucu ${mn(b2)}.', {c.ciftlik, 'senaryo', 'finans', '$y'},
            kaynak: senaryoKonum(s2, kSatirBrut, y, aylar)));
      }
    }
  }
  if (yil == null || yil == 2026) {
    for (final k in s.kontrol) {
      if (k.tur != 'tutarsizlik') continue;
      l.add(Bulgu(BulguTuru.tutarsizlik, k.baslik, k.aciklama, {k.ciftlik, 'senaryo', 'finans', '2026'}, kaynak: k.kaynak));
    }
  }
  return l;
}

List<String> _senaryo(CiftlikRaporu r, _Soru q) {
  final s = r.senaryo;
  if (s == null) return ['Dosyada piyasa fiyatlı senaryo sayfası bulunamadı.'];
  final hedef = [
    for (final c in s.ciftlikler)
      if (q.ciftlikler.contains(c.ciftlik) ||
          ((q.ciftlikler.contains(kCiftliklerimiz) || q.ciftlikler.contains(kKonsolide)) && c.ciftlik == kSenaryoToplam))
        c,
  ];
  final l = <String>[];
  if (hedef.isEmpty) {
    l.add('${s.aciklama} ${s.donem} dönem sonuçları: '
        '${s.ciftlikler.map((c) => '${c.ciftlik} ${kz(c.net1)} → ${kz(c.net2)} (${mnFark(c.netFark)})').join('; ')}.');
    hedef.add(s.ciftlikler.first);
  }
  for (final c in hedef) {
    l.add('${c.ciftlik}: ${senaryoNedenleri(s, c).map((x) => '${x.$1}: ${x.$2}').join(' ')}');
  }
  return l;
}

/// "ÇİFTLİKLER : MALİYET TAKİP 2026" dosyasındaki olumsuz sonuçlar ve tutarsızlıklar.
List<Bulgu> maliyetTakipBulgulari(CiftlikRaporu r) {
  final m = r.mt!;
  const k = 'Maliyet takip';
  final l = <Bulgu>[];
  String cTag(String c) => c == 'Taşağıl' ? kEsk : c;

  // --- formül / kopya hataları
  for (final h in m.refHatalari) {
    l.add(Bulgu(BulguTuru.tutarsizlik, '$k – ${h.bolum} ${h.yil} formül hatası',
        '“${h.sayfa}” sayfasında ${h.bolum} ${h.yil} bölümünde ${h.adet} hücre #REF! hatası veriyor; bu aylar hesaplanamıyor.',
        {cTag(h.bolum), 'hayvan', 'finans'}));
  }
  if (m.ozetRef > 0) {
    l.add(Bulgu(BulguTuru.tutarsizlik, '$k – ÖZET sayfası kullanılamıyor',
        'ÖZET sayfasında ${m.ozetRef} hücre #REF! hatası veriyor; sayfa kopuk bağlantılar nedeniyle güncel değil.', {'hayvan', 'finans', 'Aslım', kEsk}));
  }
  if (m.toplamPangevKopya >= 3) {
    l.add(Bulgu(BulguTuru.tutarsizlik, '$k – 2025 TOPLAM bloğu hatalı',
        'Hayvancılık TOPLAM bloğunun 2025 sütunları Pan-Gev değerleriyle birebir aynı (${m.toplamPangevKopya} ay); diğer çiftlikler toplama girmiyor.',
        {'hayvan', 'finans', 'Pan-Gev'}));
  }
  if (m.tasagilKopya) {
    l.add(Bulgu(BulguTuru.tutarsizlik, '$k – Taşağıl verisi güncel değil',
        'Taşağıl 2026 Ocak değerleri 2025 Ocak ile aynı (kopya); Şubat–Eylül 2026 maliyet ve hayvan sayısı girilmemiş.', {kEsk, 'et', 'hayvan'}));
  }
  if (m.sutTabloDisi.isNotEmpty) {
    l.add(Bulgu(BulguTuru.tutarsizlik, '$k – süt maliyeti sayfasında başıboş hücreler',
        '${m.sutTabloDisi.join(', ')} hücrelerinde tabloyla ilişkisiz değerler var.', {'süt'}));
  }
  for (final (g, mz, q) in m.yemToplamsiz) {
    l.add(Bulgu(BulguTuru.tutarsizlik, '$k – $g yem toplamı eksik',
        '$mz için 9 ayda ${sayi(q)} kg tüketim girilmiş ancak tutarı TOPLAM sütununa alınmamış; yem gideri olduğundan düşük görünür.',
        {g.split(' ').first, 'yem', 'süt'}));
  }

  // --- iki dosya arası karşılaştırma: süt litre maliyeti ve fiyat
  for (final (c, u) in const [('Şekersüt', kSekersut), ('Pan-Gev', kPangev)]) {
    final farkli = <String>[], fiyatFarkli = <String>[];
    for (final s in m.sutAylar(c, 2026)) {
      final b = r.birimAylar(u).where((x) => x.yil == 2026 && x.ayNo == s.ay).firstOrNull;
      if (b == null) continue;
      if ((b.birimMaliyet - s.maliyet).abs() > 0.5) {
        farkli.add('${raporAylari[s.ay - 1]} (takip ${tl2(s.maliyet)}, muhasebe ${tl2(b.birimMaliyet)})');
      }
      if (s.satis != null && b.fiyat != null && (b.fiyat! - s.satis!).abs() > 1) {
        fiyatFarkli.add('${raporAylari[s.ay - 1]} (takip ${tl2(s.satis)}, faturalanan ort. ${tl2(b.fiyat)})');
      }
    }
    if (farkli.isNotEmpty) {
      l.add(Bulgu(BulguTuru.tutarsizlik, '$c – litre maliyeti iki dosyada farklı', '${farkli.join('; ')}.', {c, 'süt', for (final a in raporAylari) if (farkli.any((x) => x.startsWith(a))) a}));
    }
    if (fiyatFarkli.isNotEmpty) {
      l.add(Bulgu(BulguTuru.tutarsizlik, '$c – süt satış fiyatı ile faturalanan fiyat farklı',
          '${fiyatFarkli.join('; ')}. Fark iskonto, iade veya fiyat farkı faturasından kaynaklanıyor olabilir.', {c, 'süt'}));
    }
    // olumsuz: maliyet > satış (takip)
    final zarar = [for (final s in m.sutAylar(c, 2026)) if (s.satis != null && s.maliyet > s.satis!) s];
    if (zarar.isNotEmpty) {
      l.add(Bulgu(BulguTuru.olumsuz, '$c – litre maliyeti satış fiyatının üstünde',
          zarar.map((s) => '${raporAylari[s.ay - 1]} ${tl2(s.maliyet)} / ${tl2(s.satis)}').join('; '),
          {c, 'süt', for (final s in zarar) raporAylari[s.ay - 1]}));
    }
  }

  // --- Aslım: maliyet takipte maliyet var, gelir tablosunda satış maliyeti yok
  final aslim = m.hayvanAylar('Aslım', 2026);
  if (aslim.isNotEmpty) {
    final t = aslim.fold(0.0, (s, h) => s + h.toplam!);
    final smm = r.d26('Aslım', 'Satışların maliyeti');
    if (t > 1e6 && smm.abs() < t * 0.1) {
      l.add(Bulgu(BulguTuru.tutarsizlik, 'Aslım – iki dosya uyumsuz',
          'Maliyet takipte Aslım için 2026’da ${mn(t)} hayvancılık maliyeti ve ${sayi(aslim.first.hayvan)}–${sayi(aslim.last.hayvan)} baş hayvan görünüyor; '
              'gelir tablosunda Aslım satış maliyeti ${mn(smm)}. Bu maliyetin hangi işletmeye (ör. ESK hizmeti) yazıldığı teyit edilmeli.',
          {'Aslım', kEsk, 'et', 'hayvan', 'finans'}));
    }
  }

  // --- hayvan sayısı ani değişimleri ve hayvan başı maliyet artışı
  for (final c in m.hayvanCiftlikleri) {
    for (final yil in [2025, 2026]) {
      final a = m.hayvanAylar(c, yil);
      for (var i = 1; i < a.length; i++) {
        final d = a[i].hayvan! / a[i - 1].hayvan! - 1;
        if (d.abs() > 0.25 && (a[i].hayvan! - a[i - 1].hayvan!).abs() > 30) {
          l.add(Bulgu(BulguTuru.tutarsizlik, '$c – ${raporAylari[a[i].ay - 1]} $yil hayvan sayısı değişimi',
              '${sayi(a[i - 1].hayvan)} → ${sayi(a[i].hayvan)} baş (${yuzde(d * 100)}). Giriş/çıkış kaydıyla teyit edilmeli; hayvan başı maliyet bu aydan etkilenir.',
              {c, 'hayvan', raporAylari[a[i].ay - 1]}));
        }
      }
    }
    final a = m.hayvanAylar(c, 2026);
    if (a.length >= 2) {
      final f = a.last.basinaAylik! / a.first.basinaAylik! - 1;
      if (f > 0.2) {
        l.add(Bulgu(BulguTuru.olumsuz, '$c – hayvan başı maliyet arttı',
            '${raporAylari[a.first.ay - 1]} ${tl0(a.first.basinaAylik)} → ${raporAylari[a.last.ay - 1]} ${tl0(a.last.basinaAylik)} (${yuzde(f * 100)}).',
            {c, 'hayvan', if (c != 'Aslım') 'süt' else 'et'}));
      }
    }
  }

  // --- tarım
  for (final e in m.ekilis) {
    final ay = e.aylik.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    for (var i = 1; i < ay.length; i++) {
      if (ay[i].value > 100000 && ay[i].value == ay[i - 1].value) {
        l.add(Bulgu(BulguTuru.tutarsizlik, '${e.ciftlik} ${e.urun} – tekrarlanan tutar',
            '${ay[i - 1].key} ve ${ay[i].key} aylarında aynı tutar (${tl0(ay[i].value)}) girilmiş; kopyalama hatası olabilir.', {'tarım', e.urun, cTag(e.ciftlik)}));
      }
    }
  }
  if (m.ortakYazili != null && (m.ortakYazili! - m.ortakToplam).abs() > m.ortakToplam * 0.01) {
    l.add(Bulgu(BulguTuru.tutarsizlik, 'Tarım ortak giderleri – toplam hücresi hatalı',
        'Aylık işçilik, amortisman ve diğer giderlerin toplamı ${mn(m.ortakToplam)}; dosyadaki TOPLAM hücresinde ${mn(m.ortakYazili!)} yazıyor '
            '(fark ${mn(m.ortakToplam - m.ortakYazili!)}). Raporda aylık kalemlerin toplamı esas alınmıştır.',
        {'tarım', 'Tarımsal Alan'}));
  }
  if (m.ortakToplam > 0) {
    l.add(Bulgu(BulguTuru.tutarsizlik, 'Tarım ortak giderleri dağıtılmamış',
        '${mn(m.ortakToplam)} ortak gider ürün maliyetlerine yansıtılmamış; ürün bazında dekar maliyetleri olduğundan düşük görünür.', {'tarım', 'Tarımsal Alan'}));
  }
  final bugday = r.tarimUrun('Tarımsal Alan', 'Buğday', 2026);
  final bm = [for (final e in m.ekilis) if (e.urun == 'Buğday') e];
  if (bugday != null && bugday.satisKg > 0 && bugday.fiyat != null && bm.isNotEmpty) {
    final maliyet = bm.fold(0.0, (s, e) => s + e.toplam);
    final dekar = bm.fold(0.0, (s, e) => s + (e.dekar ?? 0));
    final kg = maliyet / bugday.satisKg, kgPayli = (maliyet + dekar * m.ortakDekarBasi) / bugday.satisKg;
    if (kgPayli > bugday.fiyat!) {
      l.add(Bulgu(BulguTuru.olumsuz, 'Buğday – ortak gider payıyla maliyet satış fiyatını aşıyor',
          'Maliyet takibine göre kg maliyeti ${tl2(kg)}, tarım ortak gider payı eklendiğinde ${tl2(kgPayli)}; satış fiyatı ${tl2(bugday.fiyat)}. '
              'Gelir tablosundaki ${tl2(bugday.birimMaliyet)}/kg maliyet ortak giderleri içermediği için kârlılık olduğundan yüksek görünüyor.',
          {'tarım', 'Buğday', 'Tarımsal Alan'}));
    }
  }
  final urunler = <String, List<MtEkilis>>{};
  for (final e in m.ekilis) {
    (urunler[e.urun] ??= []).add(e);
  }
  for (final e in urunler.entries) {
    final l2 = [for (final x in e.value) if (x.dekarBasi != null) x]..sort((a, b) => b.dekarBasi!.compareTo(a.dekarBasi!));
    if (l2.length >= 2 && l2.first.dekarBasi! > l2.last.dekarBasi! * 1.15) {
      l.add(Bulgu(BulguTuru.olumsuz, '${e.key} – ${l2.first.ciftlik} dekar maliyeti yüksek',
          '${l2.first.ciftlik} ${tl0(l2.first.dekarBasi)}/da, ${l2.last.ciftlik} ${tl0(l2.last.dekarBasi)}/da (${yuzde((l2.first.dekarBasi! / l2.last.dekarBasi! - 1) * 100)}).',
          {'tarım', e.key, cTag(l2.first.ciftlik)}));
    }
  }

  // --- karkas ve canlı maliyet
  for (final x in m.karkas) {
    if (x.maliyet != null && x.maliyet! > 0 && x.maliyet! < 50) {
      l.add(Bulgu(BulguTuru.tutarsizlik, '${x.ciftlik} ${x.tur.toLowerCase()} karkas – ${raporAylari[x.ay - 1]}',
          'Kg karkas maliyeti ${tl2(x.maliyet)}; olağan aralığın çok altında, hesaplama veya giriş hatası olabilir.', {cTag(x.ciftlik), 'et', 'karkas'}));
    }
    if (x.not.length == 1) {
      l.add(Bulgu(BulguTuru.tutarsizlik, '${x.ciftlik} karkas – ${raporAylari[x.ay - 1]} açıklama',
          'Açıklama hücresinde anlamsız tek karakter (“${x.not}”) var.', {cTag(x.ciftlik), 'karkas'}));
    }
  }
  final sonCanli = m.canli.fold(0, (s, x) => x.ay > s ? x.ay : s);
  if (sonCanli > 0 && sonCanli < 9) {
    l.add(Bulgu(BulguTuru.tutarsizlik, 'Canlı hayvan maliyeti güncellenmemiş',
        'Kayar ortalama (canlı maliyet) tablosu ${raporAylari[sonCanli - 1]} ayından sonra doldurulmamış.', {'et', 'hayvan', 'canlı'}));
  }
  if (m.canli.any((x) => x.kategori == 'Başlıksız sütun')) {
    l.add(Bulgu(BulguTuru.tutarsizlik, 'Aslım canlı maliyet – başlıksız sütun',
        'Kayar ortalama tablosunda Aslım besi sütununun yanında başlığı olmayan bir değer sütunu var; neyi ifade ettiği belirtilmeli.', {'Aslım', 'canlı'}));
  }
  for (final x in m.canli) {
    if (x.maliyet == 0) {
      l.add(Bulgu(BulguTuru.tutarsizlik, '${x.ciftlik} ${x.kategori.toLowerCase()} – ${raporAylari[x.ay - 1]} canlı maliyet sıfır',
          'Değer 0 girilmiş.', {x.ciftlik, 'canlı'}));
    }
  }
  return l;
}

// ------------------------------------------------------------------ soru çözümleme

String _kucuk(String s) => s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase().replaceAll(RegExp(r'[^\wçğıöşüâ\s-]'), ' ');

bool _var(String s, List<String> l) => l.any(s.contains);

class _Soru {
  _Soru(String ham) : s = _kucuk(ham) {
    if (_var(s, ['şekersüt', 'şeker süt', 'sekersut'])) ciftlikler.add('Şekersüt');
    if (_var(s, ['pangev', 'pan-gev', 'pan gev'])) ciftlikler.add('Pan-Gev');
    if (_var(s, ['aslım', 'aslim'])) ciftlikler.add('Aslım');
    if (_var(s, ['taşağıl', 'tasagil', 'esk'])) ciftlikler.add(kEsk);
    if (_var(s, ['tarımsal alan'])) ciftlikler.add('Tarımsal Alan');
    if (_var(s, ['çiftliklerimiz', 'esk hariç'])) ciftlikler.add(kCiftliklerimiz);
    if (_var(s, ['konsolide', 'toplam', 'tüm çiftlik', 'bütün çiftlik', 'genel'])) ciftlikler.add(kKonsolide);
    final s2 = s.replaceAll('şekersüt', '').replaceAll('şeker süt', '').replaceAll('sekersut', '');
    sut = _var(s2, ['süt', 'sut', 'litre', 'inek']);
    et = _var(' $s ', [' et ', ' eti ', 'besi', 'hayvan', 'bakım hizmet', 'esk']);
    for (final e in const {
      'buğday': 'Buğday', 'bugday': 'Buğday', 'pancar': 'Şeker pancarı', 'yonca': 'Yonca balyası', 'sap': 'Sap balyası (ESK’ya)',
      'tritikale': 'Tritikale', 'patates': 'Patates', 'silaj': 'Mısır silajı', 'arpa': 'Arpa', 'tohum': 'tohum',
    }.entries) {
      if (s.contains(e.key)) urunler.add(e.value);
    }
    tarim = urunler.isNotEmpty || _var(s, ['tarım', 'tarim', 'ürün', 'hasat', 'tarla']);
    for (var i = 0; i < raporAylari.length; i++) {
      if (s.contains(_kucuk(raporAylari[i]))) ay = i + 1;
    }
    for (final y in [2024, 2025, 2026]) {
      if (s.contains('$y')) yil = y;
    }
    neden = _var(s, ['neden', 'niye', 'niçin', 'sebep', 'nereden', 'kaynak', 'niye']);
    enCok = _var(s, ['en yüksek', 'en fazla', 'en çok', 'en pahalı', 'en kötü', 'en büyük']);
    enAz = _var(s, ['en düşük', 'en az', 'en ucuz', 'en iyi', 'en küçük']);
    for (final e in const {
      'yem': 'Hammadde (yem)', 'hammadde': 'Hammadde (yem)', 'direkt işçilik': 'Direkt işçilik', 'endirekt': 'Endirekt işçilik',
      'enerji': 'Enerji', 'elektrik': 'Enerji', 'bakım onarım': 'Bakım onarım', 'genel üretim': 'Genel üretim', 'amortisman': 'Amortisman',
    }.entries) {
      if (s.contains(e.key)) bilesen ??= e.value;
    }
    if (bilesen == null && s.contains('işçilik')) bilesen = 'Direkt işçilik';
    maliyet = _var(s, ['maliyet', 'pahalı', 'gider']) || bilesen != null;
    fiyat = _var(s, ['fiyat', 'bedel']);
    tesvik = _var(s, ['teşvik', 'tesvik', 'destek', 'prim ']);
    hayvanBasi = _var(s, ['hayvan başı', 'baş başı', 'hayvan sayısı', 'baş maliyet', 'hayvan maliyet', 'günlük maliyet']);
    karkas = s.contains('karkas');
    canli = _var(s, ['canlı', 'kayar']);
    dekar = _var(s, ['dekar', 'ekiliş', 'ekilis', 'ortak gider']);
    yemFiyat = s.contains('yem') && _var(s, ['fiyat', 'pahal', 'ucuz', 'kg']);
    senaryo = _var(s, ['senaryo', 'piyasa', 'aslım 2', 'aslim 2', 'pan-gev 2', 'pangev 2', 'şekersüt 2', 'alan 2', 'iç transfer',
      'grup içi', 'dışarı sat', 'dışarıdan al', 'ikinci sayfa', '2. sayfa', 'maliyet bedel']);
    tutarsiz = _var(s, ['tutarsız', 'tutarsiz', 'hata', 'yanlış', 'sorun', 'olumsuz', 'risk', 'uyarı']);
    for (final e in const {
      'favök': 'FAVÖK (EBITDA)', 'ebitda': 'FAVÖK (EBITDA)', 'brüt': 'Brüt satış kârı/zararı', 'finansman': 'Finansman giderleri',
      'faiz': 'Finansman giderleri', 'genel yönetim': 'Faaliyet giderleri', 'faaliyet gider': 'Faaliyet giderleri',
      'olağandışı': 'Olağandışı gelirler (679)', 'satış maliyeti': 'Satışların maliyeti', 'smm': 'Satışların maliyeti',
      'ciro': 'Net satışlar', 'satış': 'Net satışlar', 'hasılat': 'Net satışlar', 'gelir': 'Net satışlar',
      'kâr': 'Dönem net kârı/zararı', 'kar ': 'Dönem net kârı/zararı', 'zarar': 'Dönem net kârı/zararı', 'net': 'Dönem net kârı/zararı',
    }.entries) {
      if (s.contains(e.key)) {
        kalem ??= e.value;
      }
    }
    if (s.endsWith('kar') || s.contains('karı') || s.contains('kârı')) kalem ??= 'Dönem net kârı/zararı';
  }

  final String s;
  final ciftlikler = <String>{};
  final urunler = <String>{};
  bool sut = false, et = false, tarim = false, neden = false, enCok = false, enAz = false;
  bool maliyet = false, fiyat = false, tesvik = false, tutarsiz = false;
  bool hayvanBasi = false, karkas = false, canli = false, dekar = false, yemFiyat = false, senaryo = false;
  int? ay, yil;
  String? bilesen, kalem;

  bool get takip => hayvanBasi || karkas || canli || dekar || yemFiyat;
  bool get bos => ciftlikler.isEmpty && !sut && !et && !tarim && kalem == null && !tesvik && !tutarsiz && !maliyet && !fiyat && !takip && !senaryo;

  Set<String> get etiketler => {
        ...ciftlikler,
        ...urunler,
        if (sut) 'süt',
        if (et) 'et',
        if (tarim) 'tarım',
        if (kalem != null || tesvik) 'finans',
        if (ay != null) raporAylari[ay! - 1],
        if (hayvanBasi) 'hayvan',
        if (karkas) 'karkas',
        if (canli) 'canlı',
        if (yemFiyat) 'yem',
        if (dekar) 'tarım',
        if (senaryo) 'senaryo',
      };
}

// ------------------------------------------------------------------ yanıt

Yanit cevapla(CiftlikRaporu r, String soru) {
  final q = _Soru(soru);
  final p = <String>[];
  final tum = tumBulgular(r);

  if (q.tutarsiz && q.bos == false && q.etiketler.isEmpty) {
    return Yanit(soru: soru, paragraflar: ['Dosyada ${tum.length} bulgu tespit edildi.'], bulgular: tum);
  }
  if (q.bos) {
    return Yanit(
      soru: soru,
      anlasildi: false,
      paragraflar: [
        'Soruda çiftlik, ürün veya kalem tanınamadı. Örneğin: “Şekersüt süt maliyeti neden arttı?”, “Mayıs ayında Pan-Gev yem maliyeti ne kadar?”, '
            '“En çok zarar eden çiftlik hangisi?”, “Buğday fiyatı 2025’e göre ne kadar değişti?”, “Teşvikler ne kadar?”, “Tutarsızlıklar neler?”',
        _genelOzet(r),
      ],
      bulgular: tum.where((b) => b.tur == BulguTuru.olumsuz).take(3).toList(),
    );
  }

  if (q.senaryo && q.urunler.isEmpty) {
    final et = q.etiketler;
    return Yanit(
      soru: soru,
      paragraflar: _senaryo(r, q),
      bulgular: [for (final b in tum) if (b.konular.contains('senaryo') && (q.ciftlikler.isEmpty || b.konular.any(et.contains))) b],
    );
  }

  final mt = r.mt;
  if (mt != null) {
    if (q.hayvanBasi) p.addAll(_mtHayvan(mt, q));
    if (q.karkas) p.addAll(_mtKarkas(mt, q));
    if (q.canli) p.addAll(_mtCanli(mt, q));
    if (q.yemFiyat) p.addAll(_mtYem(mt, q));
    if (q.dekar || (q.tarim && !q.fiyat)) p.addAll(_mtTarim(r, mt, q));
  }
  final takipYanitladi = p.isNotEmpty;
  final suttan = !q.hayvanBasi && !q.yemFiyat && (q.sut || ((q.ciftlikler.contains('Şekersüt') || q.ciftlikler.contains('Pan-Gev')) && (q.maliyet || q.fiyat) && q.kalem == null));
  final etten = q.et && !q.tarim && !q.karkas && !q.canli && !q.hayvanBasi && (q.maliyet || q.fiyat || q.kalem == null);

  if (q.tesvik) p.addAll(_tesvik(r, q));
  if (suttan) {
    final urunler = [
      if (q.ciftlikler.contains('Şekersüt') || !q.ciftlikler.contains('Pan-Gev')) kSekersut,
      if (q.ciftlikler.contains('Pan-Gev') || !q.ciftlikler.contains('Şekersüt')) kPangev,
    ];
    for (final u in urunler) {
      p.addAll(_birim(r, q, u, _sutCiftlik[u]!, 'L'));
    }
  }
  if (etten) {
    p.addAll(_birim(r, q, kEskHizmet, 'ESK besi hizmeti', 'birim'));
    if (q.ciftlikler.contains('Aslım') || q.ciftlikler.isEmpty) p.add(_ciftlikOzet(r, 'Aslım'));
  }
  if (q.tarim && !(q.dekar && !q.fiyat)) p.addAll(_tarim(r, q));
  final finans = (!suttan && !etten && !q.tarim && !q.tesvik && !takipYanitladi) || (q.kalem != null && !q.maliyet && !q.fiyat && !q.takip);
  if (finans && !(q.tutarsiz && q.kalem == null && q.ciftlikler.isEmpty)) p.addAll(_finans(r, q));
  if (p.isEmpty) p.add(_genelOzet(r));

  final et = q.etiketler;
  var ilgili = q.tutarsiz && et.isEmpty ? tum : [for (final b in tum) if (b.konular.any(et.contains)) b];
  // Ay sorulduysa o aya ait bulgular öne alınır.
  if (q.ay != null) {
    final a = raporAylari[q.ay! - 1];
    ilgili = [...ilgili.where((b) => b.konular.contains(a)), ...ilgili.where((b) => !b.konular.contains(a))];
  }
  return Yanit(soru: soru, paragraflar: p, bulgular: ilgili);
}

String _genelOzet(CiftlikRaporu r) {
  const n = 'Dönem net kârı/zararı';
  final l = [for (final c in r.ciftlikler) if (c != kKonsolide && c != kCiftliklerimiz) c]
    ..sort((a, b) => r.d26(a, n).compareTo(r.d26(b, n)));
  return '${r.donem} konsolide sonuç ${kz(r.d26(kKonsolide, n))}. Çiftlik bazında: '
      '${l.reversed.map((c) => '$c ${kz(r.d26(c, n))}').join('; ')}.';
}

String _ciftlikOzet(CiftlikRaporu r, String c) {
  const n = 'Dönem net kârı/zararı';
  return '$c: net satış ${mn(r.d26(c, 'Net satışlar'))}, brüt sonuç ${mn(r.d26(c, 'Brüt satış kârı/zararı'))}, '
      'faaliyet gideri ${mn(r.d26(c, 'Faaliyet giderleri'))}, amortisman ${mn(r.d26(c, 'Amortisman'))}, '
      'dönem net sonucu ${kz(r.d26(c, n))} (2025 aynı dönem ${kz(r.d25(c, n))}).';
}

List<String> _tesvik(CiftlikRaporu r, _Soru q) {
  final yillar = q.yil != null ? [q.yil!] : [2025, 2026];
  return [
    for (final y in yillar)
      '$y teşvik gelirleri: ${[
        for (final k in ['Tarımsal teşvik', 'Buzağı teşviki', 'Süt teşviki', 'İstihdam (SGK) teşvikleri'])
          if (r.tesvikTutar(y, k) != 0) '${k.toLowerCase()} ${mn(r.tesvikTutar(y, k))}',
      ].join(', ')}${y == 2026 ? ' (Ocak–Eylül)' : ''}.',
  ];
}

List<String> _birim(CiftlikRaporu r, _Soru q, String urun, String ad, String birim) {
  final p = <String>[];
  final yil = q.yil ?? 2026;
  final aylar = [for (final a in r.birimAylar(urun)) if (a.yil == yil && !a.tutarsiz) a];
  if (aylar.isEmpty) return ['$ad için $yil yılında maliyet kaydı yok.'];
  final d = r.donemOrt(urun, yil);
  final k = q.bilesen;

  if (q.ay != null) {
    final a = aylar.where((x) => x.ayNo == q.ay).firstOrNull;
    final mts = r.mt?.sutAylar(ad, yil).where((x) => x.ay == q.ay).firstOrNull;
    if (a == null && mts != null) {
      return ['$ad ${raporAylari[q.ay! - 1]} $yil litre maliyeti (maliyet takip): ${tl2(mts.maliyet)}'
          '${mts.satis == null ? '' : ', satış fiyatı ${tl2(mts.satis)} (litre başı ${tl2f(mts.satis! - mts.maliyet)})'}. Muhasebe verisinde bu ay henüz yok.'];
    }
    if (a == null) return ['$ad için ${raporAylari[q.ay! - 1]} $yil kaydı yok veya kayıt tutarsız olduğu için kullanılmadı.'];
    final farklar = [for (final b in maliyetBilesenleri) (b, a.bilesenBirim(b) - d.bilesen(b))]..sort((x, y) => y.$2.compareTo(x.$2));
    p.add('$ad ${a.donem}: birim maliyet ${tl2(a.birimMaliyet)}/$birim (dönem ortalaması ${tl2(d.birimMaliyet)}), '
        '${a.fiyat == null ? 'satış kaydı yok' : 'satış fiyatı ${tl2(a.fiyat)}, birim başı ${tl2f(a.fiyat! - a.birimMaliyet)}'}; miktar ${sayi(a.miktar)}.'
        '${k != null ? ' ${k.toLowerCase()} ${tl2(a.bilesenBirim(k))}/$birim (ortalama ${tl2(d.bilesen(k))}).' : ''}');
    if (q.neden || (a.birimMaliyet - d.birimMaliyet).abs() > 0.5) {
      final art = farklar.where((x) => x.$2 > 0.1).take(3).map((x) => '${x.$1.toLowerCase()} ${tl2f(x.$2)}');
      final az = farklar.reversed.where((x) => x.$2 < -0.1).take(2).map((x) => '${x.$1.toLowerCase()} ${tl2f(x.$2)}');
      p.add('Ortalamaya göre fark: ${art.isEmpty ? '' : 'yükselen ${art.join(', ')}'}${art.isNotEmpty && az.isNotEmpty ? '; ' : ''}'
          '${az.isEmpty ? '' : 'düşen ${az.join(', ')}'}.');
    }
    return p;
  }

  if (q.enCok || q.enAz) {
    double v(BirimAy a) => k != null ? a.bilesenBirim(k) : (q.fiyat && !q.maliyet ? (a.fiyat ?? 0) : a.birimMaliyet);
    final s = [...aylar]..sort((x, y) => v(y).compareTo(v(x)));
    final sec = q.enCok ? s.first : s.last;
    final ne = k?.toLowerCase() ?? (q.fiyat && !q.maliyet ? 'satış fiyatı' : 'birim maliyet');
    p.add('$ad $yil içinde $ne en ${q.enCok ? 'yüksek' : 'düşük'} ay ${sec.donem}: ${tl2(v(sec))}/$birim '
        '(en ${q.enCok ? 'düşük' : 'yüksek'}: ${(q.enCok ? s.last : s.first).donem} ${tl2(v(q.enCok ? s.last : s.first))}).');
    return p;
  }

  if (k != null) {
    final once = r.donemOrt(urun, yil - 1);
    p.add('$ad ${k.toLowerCase()} ${d.donem}: ${tl2(d.bilesen(k))}/$birim'
        '${once.bos ? '' : ' (${once.donem}: ${tl2(once.bilesen(k))}, ${tl2f(d.bilesen(k) - once.bilesen(k))})'}. '
        'Aylık: ${aylar.map((a) => '${raporAylari[a.ayNo - 1].substring(0, 3)} ${sayi(a.bilesenBirim(k), ondalik: 2)}').join(', ')}.');
    return p;
  }

  // genel / neden
  final n = birimNedenleri(r, urun, ad, birim);
  if (r.mt != null && birim == 'L') p.addAll(sutTakipNedenleri(r.mt!, ad).map((x) => x.$2));
  if (n.isEmpty) {
    p.add('$ad ${d.donem}: birim maliyet ${tl2(d.birimMaliyet)}/$birim, fiyat ${tl2(d.fiyat)}, birim başı ${tl2f(d.birimKar)}.');
  } else {
    p.addAll(q.neden || q.maliyet ? n.map((x) => x.$2) : n.take(2).map((x) => x.$2));
  }
  return p;
}

List<String> _tarim(CiftlikRaporu r, _Soru q) {
  final p = <String>[];
  var urunler = q.urunler.toList();
  if (urunler.isEmpty) {
    const c = 'Tarımsal Alan';
    p.add(_ciftlikOzet(r, c));
    urunler = {for (final t in r.tarim) if (t.yil == (q.yil ?? 2026) && t.satisTl > 0) t.urun}.toList();
  }
  for (final u in urunler) {
    final kayit = [for (final t in r.tarim) if (t.urun == u || (u == 'Arpa' && t.urun.startsWith('Arpa')) || (u == 'tohum' && t.urun.contains('tohum'))) t]
      ..sort((a, b) => a.yil.compareTo(b.yil));
    if (kayit.isEmpty) {
      p.add('$u için dosyada satış veya maliyet kaydı yok.');
      continue;
    }
    for (final t in kayit.where((t) => q.yil == null || t.yil == q.yil)) {
      p.add('${t.urun} ${t.yil} (${t.ciftlik}): satış ${sayi(t.satisKg)} kg / ${mn(t.satisTl)}, kg fiyatı ${tl2(t.fiyat)}, '
          'kg maliyeti ${tl2(t.birimMaliyet)}, kg başı ${tl2f(t.birimKar)}.');
    }
    final a = kayit.where((t) => t.yil == 2025 && t.birimMaliyet != null && t.fiyat != null).firstOrNull;
    final b = kayit.where((t) => t.yil == 2026 && t.birimMaliyet != null && t.fiyat != null).firstOrNull;
    if (a != null && b != null) {
      p.add('${b.urun} 2025→2026: maliyet ${yuzde((b.birimMaliyet! / a.birimMaliyet! - 1) * 100)}, fiyat ${yuzde((b.fiyat! / a.fiyat! - 1) * 100)}, '
          'kg başı sonuç ${tl2f(a.birimKar)} → ${tl2f(b.birimKar)}.'
          '${b.urun.startsWith('Sap') ? ' 2025’te maliyete yalnızca hammadde yazılırken 2026’da işçilik, genel üretim ve amortisman payları da yüklenmiştir.' : ''}');
    }
  }
  if (q.neden || q.maliyet) {
    p.add('Not: tarım ürünlerinde dosyada maliyet kalemi (tohum, gübre, işçilik) ayrımı yoktur; birim maliyet stok çıkış maliyetidir.');
  }
  return p;
}

const _gelirKalemleri = ['Net satışlar', 'Diğer olağan gelirler (649)', 'Olağandışı gelirler (679)'];
const _giderKalemleri = ['Satışların maliyeti', 'Faaliyet giderleri', 'Diğer olağan giderler', 'Finansman giderleri', 'Olağandışı giderler'];

List<String> _finans(CiftlikRaporu r, _Soru q) {
  final p = <String>[];
  final kalem = q.kalem ?? 'Dönem net kârı/zararı';
  final tumC = [for (final c in r.ciftlikler) if (c != kKonsolide && c != kCiftliklerimiz) c];

  if ((q.enCok || q.enAz) && q.ciftlikler.isEmpty) {
    final s = [...tumC]..sort((a, b) => r.d26(b, kalem).compareTo(r.d26(a, kalem)));
    final zararSor = q.s.contains('zarar');
    final sec = zararSor ? (q.enCok ? s.last : s.first) : (q.enCok ? s.first : s.last);
    p.add('${r.donem} ${kalem.toLowerCase()} sıralaması: ${s.map((c) => '$c ${mn(r.d26(c, kalem))}').join('; ')}. '
        'Sorunuza göre öne çıkan: $sec (${mn(r.d26(sec, kalem))}).');
    return p;
  }

  final cs = q.ciftlikler.isEmpty ? [kKonsolide] : q.ciftlikler.toList();
  for (final c in cs) {
    final k = r.kalem(c, kalem);
    if (k == null) continue;
    if (q.ay != null) {
      final a = r.aylikSonuc(c).where((x) => x.ayNo == q.ay).firstOrNull;
      p.add(a == null
          ? '$c için ${raporAylari[q.ay! - 1]} 2026 aylık kaydı yok (aylık kırılımda yalnız brüt ve net sonuç bulunur).'
          : '$c ${a.ay} 2026: brüt satış sonucu ${mn(a.brutKar)}, dönem net sonucu ${mn(a.netKar)}.'
              '${a.brutKar < 0 && a.netKar > 0 ? ' Net sonucu faaliyet dışı kayıtlar pozitife çeviriyor.' : ''}');
      continue;
    }
    final yil = q.yil;
    if (yil == 2024 || yil == 2025) {
      p.add('$c ${kalem.toLowerCase()} $yil yıl toplamı: ${mn(yil == 2024 ? k.y2024Yil : k.y2025Yil)}.');
    } else {
      p.add('$c ${kalem.toLowerCase()}: ${r.donem} ${mn(k.y2026)}, 2025 aynı dönem ${mn(k.y2025Donem)} '
          '(${mn(k.y2026 - k.y2025Donem)} fark); 2025 yıl toplamı ${mn(k.y2025Yil)}.');
    }
    if (q.neden || kalem == 'Dönem net kârı/zararı') {
      // net değişime katkı veren kalemler
      final katki = <(String, double)>[
        for (final g in _gelirKalemleri) (g, r.d26(c, g) - r.d25(c, g)),
        for (final g in _giderKalemleri) (g, -(r.d26(c, g) - r.d25(c, g))),
      ]..sort((a, b) => b.$2.abs().compareTo(a.$2.abs()));
      final onemli = katki.where((x) => x.$2.abs() > 250000).take(4);
      if (onemli.isNotEmpty) {
        p.add('2025 aynı döneme göre net sonuca etkisi en büyük kalemler: '
            '${onemli.map((x) => '${x.$1.toLowerCase()} ${x.$2 >= 0 ? 'olumlu' : 'olumsuz'} ${mn(x.$2.abs())}').join('; ')}.');
      }
      if (c == kKonsolide) p.addAll(karZararNedenleri(r).take(3).map((x) => '${x.$1}: ${x.$2}'));
    }
  }
  return p;
}


// ------------------------------------------------------------------ maliyet takip yanıtları

List<String> _mtHayvan(MaliyetTakip m, _Soru q) {
  final cs = q.ciftlikler.where(m.hayvanCiftlikleri.contains).toList();
  final l = <String>[];
  for (final c in cs.isEmpty ? m.hayvanCiftlikleri : cs) {
    final aylar = m.hayvanAylar(c, q.yil ?? 2026);
    if (aylar.isEmpty) continue;
    if (q.ay != null) {
      final a = aylar.where((x) => x.ay == q.ay).firstOrNull;
      if (a == null) continue;
      l.add('$c ${raporAylari[a.ay - 1]} ${a.yil}: ${sayi(a.hayvan)} baş, toplam ${mn(a.toplam!)}, hayvan başı aylık ${tl0(a.basinaAylik)} '
          '(günlük ${tl0(a.basinaGunluk)}); yem ${tl0(a.basina(a.yem))}, işçilik ${tl0(a.basina(a.iscilik))}, amortisman ${tl0(a.basina(a.amortisman))}, diğer ${tl0(a.basina(a.diger))}.');
      continue;
    }
    if (q.enCok || q.enAz) {
      final s = [...aylar]..sort((x, y) => y.basinaAylik!.compareTo(x.basinaAylik!));
      final sec = q.enCok ? s.first : s.last;
      l.add('$c hayvan başı maliyet en ${q.enCok ? 'yüksek' : 'düşük'}: ${raporAylari[sec.ay - 1]} ${tl0(sec.basinaAylik)} (${sayi(sec.hayvan)} baş).');
      continue;
    }
    l.add('$c ${raporAylari[aylar.first.ay - 1]}–${raporAylari[aylar.last.ay - 1]} ${aylar.first.yil}: ortalama hayvan başı aylık ${tl0(m.donemBasina(c, aylar.first.yil, 'Toplam'))}. '
        'Aylık: ${aylar.map((a) => '${raporAylari[a.ay - 1].substring(0, 3)} ${sayi(a.basinaAylik)}').join(', ')}.');
    l.addAll(hayvanNedenleri(m, c).map((x) => '${x.$1}: ${x.$2}'));
  }
  return l;
}

List<String> _mtKarkas(MaliyetTakip m, _Soru q) {
  final l = <String>[];
  final gruplar = <String, List<MtKarkas>>{};
  for (final x in m.karkas) {
    if (q.ciftlikler.isNotEmpty && !q.ciftlikler.contains(x.ciftlik)) continue;
    (gruplar['${x.ciftlik} ${x.tur.toLowerCase()}'] ??= []).add(x);
  }
  for (final e in gruplar.entries) {
    final v = [for (final x in e.value) if (x.maliyet != null && x.maliyet! > 0) x];
    if (q.ay != null) {
      final a = e.value.where((x) => x.ay == q.ay).firstOrNull;
      if (a != null) l.add('${e.key} ${raporAylari[a.ay - 1]}: ${a.maliyet == null || a.maliyet == 0 ? a.not : '${tl2(a.maliyet)}/kg${a.not.length > 1 ? ' (${a.not})' : ''}'}.');
      continue;
    }
    if (v.isEmpty) continue;
    final ort = v.fold(0.0, (s, x) => s + x.maliyet!) / v.length;
    final s = [...v]..sort((a, b) => b.maliyet!.compareTo(a.maliyet!));
    l.add('${e.key} kg karkas maliyeti: ${v.map((x) => '${raporAylari[x.ay - 1].substring(0, 3)} ${sayi(x.maliyet)}').join(', ')}. '
        'Ortalama ${tl2(ort)}; en yüksek ${raporAylari[s.first.ay - 1]} (${tl2(s.first.maliyet)}), en düşük ${raporAylari[s.last.ay - 1]} (${tl2(s.last.maliyet)}).');
  }
  return l.isEmpty ? ['Karkas maliyeti kaydı bulunamadı.'] : l;
}

List<String> _mtCanli(MaliyetTakip m, _Soru q) {
  final g = <String, List<MtCanli>>{};
  for (final x in m.canli) {
    if (q.ciftlikler.isNotEmpty && !q.ciftlikler.contains(x.ciftlik)) continue;
    (g['${x.ciftlik} ${x.kategori.toLowerCase()}'] ??= []).add(x);
  }
  return [
    for (final e in g.entries)
      if (e.value.length >= 2)
        '${e.key} canlı maliyet: ${tl0(e.value.first.maliyet)} (${raporAylari[e.value.first.ay - 1]}) → ${tl0(e.value.last.maliyet)} (${raporAylari[e.value.last.ay - 1]})'
            '${e.value.first.maliyet > 0 ? ', ${yuzde((e.value.last.maliyet / e.value.first.maliyet - 1) * 100)}' : ''}.',
  ];
}

List<String> _mtYem(MaliyetTakip m, _Soru q) {
  final l = <String>[];
  for (final g in m.yemGruplari) {
    if (q.ciftlikler.isNotEmpty && !q.ciftlikler.any((c) => g.startsWith(c))) continue;
    final y = yemFiyatDegisimleri(m, g);
    if (y.isNotEmpty) l.add('$g (9 ay yem ${mn(m.yemGenel[g] ?? 0)}): ${y.join('; ')}.');
  }
  return l;
}


List<String> _mtTarim(CiftlikRaporu r, MaliyetTakip m, _Soru q) {
  final l = <String>[];
  for (final d in dekarSatirlari(m)) {
    if (q.urunler.isNotEmpty && !q.urunler.any((u) => d.e.urun.startsWith(u.split(' ').first))) continue;
    if (q.ciftlikler.isNotEmpty && !q.ciftlikler.any((c) => c == d.e.ciftlik || (c == kEsk && d.e.ciftlik == 'Taşağıl'))) continue;
    l.add('${d.e.ciftlik} ${d.e.urun} (${sayi(d.e.dekar)} da): maliyet ${mn(d.e.toplam)}, dekar başı ${tl0(d.dekarBasi)}; ortak gider payıyla ${tl0(d.payliDekarBasi)}.');
  }
  if (q.neden || q.dekar || l.isNotEmpty) l.addAll(tarimTakipNedenleri(r).map((x) => '${x.$1}: ${x.$2}'));
  return l;
}
