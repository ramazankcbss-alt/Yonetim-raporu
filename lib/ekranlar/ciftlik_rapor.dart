import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../bicim.dart';
import '../tema.dart';
import '../veri/ciftlik_rapor.dart';
import 'bilesenler.dart';
import 'gonder.dart';

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

/// Çiftlikler Rapor 2026: kâr/zarar ve süt, et, tarım birim maliyetleri,
/// artış ve azalışların nedenleriyle birlikte.
class CiftlikRaporEkran extends StatelessWidget {
  const CiftlikRaporEkran({super.key});

  /// Paketlenmiş veri bir kez okunur.
  static final Future<CiftlikRaporu> _veri = CiftlikRaporu.yukle();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CiftlikRaporu>(
      future: _veri,
      builder: (context, s) {
        final r = s.data;
        return DefaultTabController(
          length: 5,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Çiftlikler Rapor 2026'),
              bottom: const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Colors.white,
                unselectedLabelColor: Color(0xCCFFFFFF),
                indicatorColor: Colors.white,
                tabs: [
                  Tab(text: 'Kâr / Zarar'),
                  Tab(text: 'Süt'),
                  Tab(text: 'Et / Besi'),
                  Tab(text: 'Tarım'),
                  Tab(text: 'Kapsam'),
                ],
              ),
            ),
            body: s.hasError
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: BilgiKutusu(uyari: true, yazi: 'Rapor verisi okunamadı.'),
                  )
                : r == null
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(children: [
                        GonderAlani(konu: 'Çiftlikler Rapor 2026 – Kâr / Zarar', child: _KarZarar(r: r)),
                        GonderAlani(konu: 'Çiftlikler Rapor 2026 – Süt', child: _Sut(r: r)),
                        GonderAlani(konu: 'Çiftlikler Rapor 2026 – Et / Besi', child: _Et(r: r)),
                        GonderAlani(konu: 'Çiftlikler Rapor 2026 – Tarım', child: _Tarim(r: r)),
                        _Kapsam(r: r),
                      ]),
          ),
        );
      },
    );
  }
}

// ----------------------------------------------------------------- ortak

class _Ust extends StatelessWidget {
  const _Ust(this.r);
  final CiftlikRaporu r;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 8),
        child: Text('Kaynak: ${r.kaynak} · Fiili ${r.donem} (Ekim–Aralık henüz işlenmemiş)',
            style: const TextStyle(fontSize: 12, color: Renk.soluk)),
      );
}

/// Neden maddeleri: kalın başlık + açıklama.
class _Nedenler extends StatelessWidget {
  const _Nedenler(this.maddeler, {this.baslik = 'Yükselme ve düşüşün nedenleri'});
  final String baslik;
  final List<(String, String)> maddeler;

  @override
  Widget build(BuildContext context) => Panel(
        baslik: baslik,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (b, a) in maddeler)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '$b: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: a),
                ]),
                style: const TextStyle(fontSize: 13.5, color: Renk.yazi, height: 1.45),
              ),
            ),
        ]),
      );
}

Color _isaretRengi(double v, {bool tersi = false}) {
  if (v == 0) return Renk.yazi;
  final iyi = tersi ? v < 0 : v > 0;
  return iyi ? Renk.yesil : Renk.kirmizi;
}

class _DegerKarti extends StatelessWidget {
  const _DegerKarti({required this.baslik, required this.deger, this.alt, this.renk = Renk.yazi});
  final String baslik, deger;
  final String? alt;
  final Color renk;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Renk.kart,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Renk.cizgi),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(baslik, maxLines: 2, style: const TextStyle(fontSize: 12.5, color: Renk.soluk, height: 1.2)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(deger, maxLines: 1, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: renk)),
          ),
          if (alt != null) ...[
            const SizedBox(height: 2),
            Text(alt!, style: const TextStyle(fontSize: 12, color: Renk.soluk)),
          ],
        ]),
      );
}

// ----------------------------------------------------------------- Kâr / Zarar

class _KarZarar extends StatefulWidget {
  const _KarZarar({required this.r});
  final CiftlikRaporu r;
  @override
  State<_KarZarar> createState() => _KarZararState();
}

class _KarZararState extends State<_KarZarar> {
  String _secili = kKonsolide;

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final c = _secili;
    const net = 'Dönem net kârı/zararı', brut = 'Brüt satış kârı/zararı';
    final aylik = r.aylikSonuc(c);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Ust(r),
        _Ozet(r: r),
        Secici<String>(
          secenekler: r.ciftlikler.reversed.toList(),
          secili: c,
          etiket: (s) => s,
          degisti: (s) => setState(() => _secili = s),
        ),
        GostergeIzgarasi(kartlar: [
          for (final (k, f) in [('Net satışlar', mn), (brut, mn), ('FAVÖK (EBITDA)', mn), (net, kz)])
            _DegerKarti(
              baslik: '${k == net ? 'Dönem net sonucu' : k} · ${r.donem}',
              deger: f(r.d26(c, k)),
              renk: k == 'Net satışlar' ? Renk.yazi : _isaretRengi(r.d26(c, k)),
              alt: '2025 aynı dönem: ${f(r.d25(c, k))}',
            ),
        ]),
        const SizedBox(height: 12),
        Panel(
          baslik: 'Aylık brüt satış kârı ve dönem net sonucu (2026)',
          child: aylik.isEmpty
              ? const Text('Bu görünüm için aylık kırılım dosyada bulunmuyor.', style: TextStyle(color: Renk.soluk))
              : _AylikGrafik(aylar: aylik),
        ),
        Panel(
          baslik: 'Çiftlik bazında kâr / zarar (${r.donem})',
          child: VeriTablosu(
            ilkSutunGenislik: 150,
            basliklar: const ['Çiftlik', 'Net satış', 'Satış maliyeti', 'Brüt kâr', 'Faaliyet dışı (net)', 'Net 2026', 'Net 2025 (aynı dönem)', 'Net 2025 (yıl)'],
            satirlar: [
              for (final x in r.ciftlikler)
                [
                  x,
                  mn(r.d26(x, 'Net satışlar')),
                  mn(r.d26(x, 'Satışların maliyeti')),
                  mn(r.d26(x, brut)),
                  mn(r.faaliyetDisi(x)),
                  mn(r.d26(x, net)),
                  mn(r.d25(x, net)),
                  mn(r.kalem(x, net)?.y2025Yil ?? 0),
                ],
            ],
          ),
        ),
        _Nedenler(karZararNedenleri(r), baslik: 'Kâr / zarardaki değişimin nedenleri'),
      ],
    );
  }
}

/// Üstteki tek cümlelik değerlendirme.
class _Ozet extends StatelessWidget {
  const _Ozet({required this.r});
  final CiftlikRaporu r;
  @override
  Widget build(BuildContext context) {
    const k = kKonsolide;
    final net = r.d26(k, 'Dönem net kârı/zararı');
    final brut = r.d26(k, 'Brüt satış kârı/zararı');
    final fd = r.faaliyetDisi(k);
    final yazi = '${r.donem} döneminde çiftlikler konsolide olarak ${kz(net)} elde etti '
        '(2025 aynı dönem: ${kz(r.d25(k, 'Dönem net kârı/zararı'))}). '
        '${fd > brut ? 'Esas faaliyetten gelen brüt satış kârı ${mn(brut)} düzeyinde kalmış; sonucun büyük bölümü ${mn(fd)} net faaliyet dışı gelirden kaynaklanmaktadır.' : 'Sonucun ana kaynağı ${mn(brut)} brüt satış kârıdır.'}';
    return BilgiKutusu(yazi: yazi);
  }
}

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

class _AylikGrafik extends StatelessWidget {
  const _AylikGrafik({required this.aylar});
  final List<AylikSonuc> aylar;
  static const brutRenk = Color(0xFF9BB8AA);

  @override
  Widget build(BuildContext context) {
    final enB = aylar.expand((a) => [a.brutKar.abs(), a.netKar.abs()]).fold<double>(1, math.max);
    final pozitifMax = aylar.expand((a) => [a.brutKar, a.netKar, 0.0]).fold<double>(0, math.max);
    final negatifMax = -aylar.expand((a) => [a.brutKar, a.netKar, 0.0]).fold<double>(0, math.min);
    const h = 160.0;
    final toplam = math.max(pozitifMax + negatifMax, enB);
    final ust = h * pozitifMax / toplam, alt = h * negatifMax / toplam;
    Widget cubuk(double v, Color renk) => Expanded(
          child: Tooltip(
            message: mn(v),
            child: Column(children: [
              SizedBox(
                height: ust,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(height: v > 0 ? h * v / toplam : 0, color: renk),
                ),
              ),
              SizedBox(
                height: alt,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(height: v < 0 ? h * -v / toplam : 0, color: renk.withValues(alpha: 0.75)),
                ),
              ),
            ]),
          ),
        );
    return Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final a in aylar)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(children: [
                Row(children: [cubuk(a.brutKar, brutRenk), const SizedBox(width: 2), cubuk(a.netKar, Renk.ana)]),
                const SizedBox(height: 4),
                Text(a.ay.substring(0, 3), style: const TextStyle(fontSize: 11, color: Renk.soluk)),
                FittedBox(
                  child: Text(sayi(a.netKar / 1e6, ondalik: 1),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _isaretRengi(a.netKar))),
                ),
              ]),
            ),
          ),
      ]),
      const SizedBox(height: 8),
      const Wrap(spacing: 16, children: [
        _Lej(renk: brutRenk, yazi: 'Brüt satış kârı'),
        _Lej(renk: Renk.ana, yazi: 'Dönem net sonucu (rakam: mn ₺)'),
      ]),
    ]);
  }
}

class _Lej extends StatelessWidget {
  const _Lej({required this.renk, required this.yazi});
  final Color renk;
  final String yazi;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(yazi, style: const TextStyle(fontSize: 12, color: Renk.soluk)),
      ]);
}

// ----------------------------------------------------------------- birim maliyet bileşenleri

/// Aylık birim maliyet (kırmızı) ve satış fiyatı (yeşil) çizgi grafiği.
class _BirimGrafik extends StatelessWidget {
  const _BirimGrafik({required this.aylar, this.fiyatAdi = 'Satış fiyatı'});
  final List<BirimAy> aylar;
  final String fiyatAdi;

  @override
  Widget build(BuildContext context) {
    final l = [for (final a in aylar) if (!a.tutarsiz) a];
    return Column(children: [
      SizedBox(height: 180, child: CustomPaint(size: Size.infinite, painter: _CizgiCizer(l))),
      const SizedBox(height: 6),
      Wrap(spacing: 16, children: [
        const _Lej(renk: Renk.kirmizi, yazi: 'Birim maliyet'),
        _Lej(renk: Renk.ana, yazi: fiyatAdi),
      ]),
      const SizedBox(height: 8),
      VeriTablosu(
        ilkSutunGenislik: 92,
        basliklar: const ['Ay', 'Miktar', 'Maliyet', 'Fiyat', 'Fark'],
        satirlar: [
          for (final a in l)
            [a.donem, sayi(a.miktar), tl2(a.birimMaliyet), tl2(a.fiyat), tl2f(a.fiyat == null ? null : a.fiyat! - a.birimMaliyet)],
        ],
      ),
    ]);
  }
}

class _CizgiCizer extends CustomPainter {
  _CizgiCizer(this.aylar);
  final List<BirimAy> aylar;

  @override
  void paint(Canvas canvas, Size size) {
    if (aylar.isEmpty) return;
    const sol = 34.0, alt = 18.0, ust = 6.0;
    final vals = [for (final a in aylar) ...[a.birimMaliyet, if (a.fiyat != null) a.fiyat!]];
    final enY = vals.fold<double>(0, math.max) * 1.1;
    final w = size.width - sol - 6, h = size.height - alt - ust;
    double x(int i) => sol + (aylar.length == 1 ? w / 2 : w * i / (aylar.length - 1));
    double y(double v) => ust + h - h * v / enY;
    final izgara = Paint()..color = Renk.cizgi;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i <= 4; i++) {
      final v = enY * i / 4;
      canvas.drawLine(Offset(sol, y(v)), Offset(size.width, y(v)), izgara);
      tp.text = TextSpan(text: sayi(v), style: const TextStyle(fontSize: 10, color: Renk.soluk));
      tp.layout();
      tp.paint(canvas, Offset(0, y(v) - 6));
    }
    final adim = (aylar.length / 6).ceil();
    for (var i = 0; i < aylar.length; i += adim) {
      tp.text = TextSpan(text: aylar[i].etiket, style: const TextStyle(fontSize: 10, color: Renk.soluk));
      tp.layout();
      tp.paint(canvas, Offset(x(i) - tp.width / 2, size.height - alt + 4));
    }
    void cizgi(double? Function(BirimAy) f, Color c) {
      final p = Paint()
        ..color = c
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final yol = Path();
      var basladi = false;
      for (var i = 0; i < aylar.length; i++) {
        final v = f(aylar[i]);
        if (v == null) continue;
        final o = Offset(x(i), y(v));
        if (basladi) {
          yol.lineTo(o.dx, o.dy);
        } else {
          yol.moveTo(o.dx, o.dy);
        }
        basladi = true;
        canvas.drawCircle(o, 3, Paint()..color = c);
      }
      canvas.drawPath(yol, p);
    }

    cizgi((a) => a.birimMaliyet, Renk.kirmizi);
    cizgi((a) => a.fiyat, Renk.ana);
  }

  @override
  bool shouldRepaint(covariant _CizgiCizer old) => old.aylar != aylar;
}

class _FarkTablosu extends StatelessWidget {
  const _FarkTablosu({required this.r, required this.urun, required this.birim});
  final CiftlikRaporu r;
  final String urun, birim;
  @override
  Widget build(BuildContext context) {
    final a = r.donemOrt(urun, 2025), b = r.donemOrt(urun, 2026);
    return VeriTablosu(
      ilkSutunGenislik: 140,
      basliklar: ['Kalem ($birim)', a.donem, b.donem, 'Değişim'],
      satirlar: [
        for (final k in maliyetBilesenleri) [k, tl2(a.bilesen(k)), tl2(b.bilesen(k)), tl2f(b.bilesen(k) - a.bilesen(k))],
        ['Birim maliyet', tl2(a.birimMaliyet), tl2(b.birimMaliyet), tl2f(b.birimMaliyet - a.birimMaliyet)],
        ['Satış fiyatı', tl2(a.fiyat), tl2(b.fiyat), tl2f(a.fiyat == null || b.fiyat == null ? null : b.fiyat! - a.fiyat!)],
        ['Birim kâr / zarar', tl2f(a.birimKar), tl2f(b.birimKar), tl2f(a.birimKar == null || b.birimKar == null ? null : b.birimKar! - a.birimKar!)],
      ],
      vurguluSonSatir: true,
    );
  }
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

// ----------------------------------------------------------------- Süt

class _Sut extends StatelessWidget {
  const _Sut({required this.r});
  final CiftlikRaporu r;

  @override
  Widget build(BuildContext context) {
    final s = r.donemOrt(kSekersut, 2026), p = r.donemOrt(kPangev, 2026);
    final s25 = r.donemOrt(kSekersut, 2025), p25 = r.donemOrt(kPangev, 2025);
    String sb(String k) => tl2(s.bilesen(k));
    String pb(String k) => tl2(p.bilesen(k));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Ust(r),
        GostergeIzgarasi(kartlar: [
          _DegerKarti(baslik: 'Şekersüt litre maliyeti · ${s.donem}', deger: tl2(s.birimMaliyet), alt: '2025 (${s25.donem}): ${tl2(s25.birimMaliyet)}'),
          _DegerKarti(baslik: 'Şekersüt litre başı sonuç', deger: tl2f(s.birimKar), renk: _isaretRengi(s.birimKar ?? 0), alt: 'Satış fiyatı ${tl2(s.fiyat)}'),
          _DegerKarti(baslik: 'Pan-Gev litre maliyeti · ${p.donem}', deger: tl2(p.birimMaliyet), alt: '2025 (${p25.donem}): ${tl2(p25.birimMaliyet)}'),
          _DegerKarti(baslik: 'Pan-Gev litre başı sonuç', deger: tl2f(p.birimKar), renk: _isaretRengi(p.birimKar ?? 0), alt: 'Satış fiyatı ${tl2(p.fiyat)}'),
        ]),
        const SizedBox(height: 12),
        Panel(baslik: 'Şekersüt – aylık litre maliyeti ve satış fiyatı', child: _BirimGrafik(aylar: r.birimAylar(kSekersut))),
        Panel(baslik: 'Pan-Gev – aylık litre maliyeti ve satış fiyatı', child: _BirimGrafik(aylar: r.birimAylar(kPangev))),
        Panel(baslik: 'Şekersüt – litre maliyeti kalem bazında', child: _FarkTablosu(r: r, urun: kSekersut, birim: '₺/L')),
        Panel(baslik: 'Pan-Gev – litre maliyeti kalem bazında', child: _FarkTablosu(r: r, urun: kPangev, birim: '₺/L')),
        _Nedenler([
          ...birimNedenleri(r, kSekersut, 'Şekersüt', 'L'),
          ...birimNedenleri(r, kPangev, 'Pan-Gev', 'L'),
          (
            'İki çiftlik arasındaki fark',
            'Şekersüt’te direkt işçilik (${sb('Direkt işçilik')}/L), amortisman (${sb('Amortisman')}/L) ve genel üretim '
                '(${sb('Genel üretim')}/L) Pan-Gev’e göre (${pb('Direkt işçilik')}, ${pb('Amortisman')}, ${pb('Genel üretim')}) yüksektir. '
                'Şekersüt’te kârlılık için yem verimliliği ve litre başına düşen sabit gider (amortisman, genel üretim) önceliklidir.'
          ),
        ]),
      ],
    );
  }
}

// ----------------------------------------------------------------- Et / Besi

class _Et extends StatelessWidget {
  const _Et({required this.r});
  final CiftlikRaporu r;

  @override
  Widget build(BuildContext context) {
    final e = r.donemOrt(kEskHizmet, 2026), e25 = r.donemOrt(kEskHizmet, 2025);
    final tutarsiz = [for (final a in r.birimAylar(kEskHizmet)) if (a.tutarsiz) a.donem];
    final aylar = [for (final a in r.birimAylar(kEskHizmet)) if (!a.tutarsiz && a.yil == 2026) a];
    final enAz = aylar.isEmpty ? null : aylar.reduce((a, b) => a.birimMaliyet < b.birimMaliyet ? a : b);
    final enCok = aylar.isEmpty ? null : aylar.reduce((a, b) => a.birimMaliyet > b.birimMaliyet ? a : b);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Ust(r),
        const BilgiKutusu(
            yazi: '2026’da çiftliklerimizde canlı hayvan (et) satışı yoktur. Et/besi faaliyeti, ESK’ya ait hayvanlar için '
                'Taşağıl’da verilen bakım hizmetinden oluşur ve “Çiftliklerimiz” toplamından ayrı gösterilir. Hizmet birimi '
                'dosyada ADT olarak kayıtlıdır (hayvan başı günlük bakım).'),
        GostergeIzgarasi(kartlar: [
          _DegerKarti(baslik: 'ESK hizmeti birim maliyet · ${e.donem}', deger: tl2(e.birimMaliyet), alt: '2025 (${e25.donem}): ${tl2(e25.birimMaliyet)}'),
          _DegerKarti(baslik: 'Birim başı sonuç', deger: tl2f(e.birimKar), renk: _isaretRengi(e.birimKar ?? 0), alt: 'Hizmet bedeli ${tl2(e.fiyat)}'),
          _DegerKarti(
              baslik: 'ESK-Taşağıl dönem net sonucu',
              deger: kz(r.d26(kEsk, 'Dönem net kârı/zararı')),
              renk: _isaretRengi(r.d26(kEsk, 'Dönem net kârı/zararı')),
              alt: '2025 aynı dönem: ${kz(r.d25(kEsk, 'Dönem net kârı/zararı'))}'),
          _DegerKarti(
              baslik: 'Aslım dönem net sonucu',
              deger: kz(r.d26('Aslım', 'Dönem net kârı/zararı')),
              renk: _isaretRengi(r.d26('Aslım', 'Dönem net kârı/zararı')),
              alt: 'Üretim yok; gelir yalnız teşvik/diğer gelir'),
        ]),
        const SizedBox(height: 12),
        Panel(
          baslik: 'ESK besi hizmeti – aylık birim maliyet ve hizmet bedeli',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _BirimGrafik(aylar: r.birimAylar(kEskHizmet), fiyatAdi: 'Hizmet bedeli'),
            if (tutarsiz.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    '${tutarsiz.join(' ve ')} kayıtlarında hizmet maliyetine yalnızca hammadde yazılmıştır; kayıt tutarsızlığı olarak ortalamaya ve grafiğe alınmamıştır.',
                    style: const TextStyle(fontSize: 12, color: Renk.soluk)),
              ),
          ]),
        ),
        Panel(baslik: 'ESK hizmeti – birim maliyet kalem bazında', child: _FarkTablosu(r: r, urun: kEskHizmet, birim: '₺/birim')),
        _Nedenler([
          ...birimNedenleri(r, kEskHizmet, 'ESK hizmeti', 'birim'),
          if (enAz != null && enCok != null)
            (
              'Doluluk etkisi',
              'Sabit giderler (amortisman, endirekt işçilik, genel üretim) hizmet verilen hayvan sayısına bölündüğü için birim maliyet dolulukla değişiyor: '
                  '${enAz.donem}’da ${sayi(enAz.miktar)} birimle ${tl2(enAz.birimMaliyet)}, ${enCok.donem}’de ${sayi(enCok.miktar)} birimle ${tl2(enCok.birimMaliyet)}. '
                  'Hizmet bedelinin, doluluğa bağlı sabit gider payını karşılayacak şekilde yeniden değerlendirilmesi önerilir.'
            ),
          (
            'Aslım',
            '2025’te hayvanların transferiyle çiftlik boşaldı; 2026’da satış maliyeti oluşmuyor. Genel yönetim gideri '
                '(${mn(r.d26('Aslım', 'Faaliyet giderleri'))}) ve amortisman (${mn(r.d26('Aslım', 'Amortisman'))}) sürdüğü için dönem zararı devam ediyor.'
          ),
        ]),
      ],
    );
  }
}

// ----------------------------------------------------------------- Tarım

class _Tarim extends StatelessWidget {
  const _Tarim({required this.r});
  final CiftlikRaporu r;

  @override
  Widget build(BuildContext context) {
    final b26 = r.tarimUrun('Tarımsal Alan', 'Buğday', 2026), b25 = r.tarimUrun('Tarımsal Alan', 'Buğday', 2025);
    final urunler = [...r.tarim]..sort((a, b) => a.yil != b.yil ? b.yil.compareTo(a.yil) : b.satisTl.compareTo(a.satisTl));
    final nedenler = <(String, String)>[];
    // 2025 ve 2026'da birlikte bulunan ürünlerin değişimi
    for (final t in urunler.where((t) => t.yil == 2026 && t.birimMaliyet != null)) {
      final o = r.tarimUrun(t.ciftlik, t.urun, 2025);
      if (o?.birimMaliyet == null || o?.fiyat == null || t.fiyat == null) {
        nedenler.add((t.urun, 'kg maliyeti ${tl2(t.birimMaliyet)}, satış fiyatı ${tl2(t.fiyat)}; kg başı ${tl2f(t.birimKar)} (${sayi(t.satisKg)} kg satış).'));
        continue;
      }
      final mf = (t.birimMaliyet! / o!.birimMaliyet! - 1) * 100, ff = (t.fiyat! / o.fiyat! - 1) * 100;
      nedenler.add((
        t.urun,
        'kg maliyeti ${tl2(o.birimMaliyet)}’den ${tl2(t.birimMaliyet)}’ye (${yuzde(mf)}), satış fiyatı ${tl2(o.fiyat)}’den ${tl2(t.fiyat)}’ye (${yuzde(ff)}). '
            'Kg başı sonuç ${tl2f(o.birimKar)} → ${tl2f(t.birimKar)}. '
            '${t.birimKar! < 0 ? 'Satış fiyatının maliyete göre yeniden belirlenmesi önerilir.' : ''}'
      ));
    }
    final pancar26 = r.tarimUrun('Tarımsal Alan', 'Şeker pancarı', 2026);
    if (pancar26 != null && pancar26.satisKg == 0) {
      final p25 = r.tarimUrun('Tarımsal Alan', 'Şeker pancarı', 2025);
      nedenler.add((
        'Şeker pancarı',
        '2026 hasadı (Ekim–Kasım) dosyada henüz yer almıyor. 2026’da kayıtlı ${mn(pancar26.satisTl)} pancar geliri miktarsızdır; '
            'önceki sezona ait fiyat farkı/prim olduğu değerlendirilmektedir.'
            '${p25 == null ? '' : ' 2025’te kg maliyeti ${tl2(p25.birimMaliyet)}, satış fiyatı ${tl2(p25.fiyat)} idi.'}'
      ));
    }
    final zararli = [for (final t in urunler) if (t.yil < 2026 && (t.birimKar ?? 0) < 0) '${t.yil} ${t.urun.toLowerCase()} (${tl2f(t.birimKar)}/kg)'];
    if (zararli.isNotEmpty) {
      nedenler.add(('Geçmiş yıllarda zararlı ürünler', '${zararli.join(', ')} maliyetin altında satılmıştır; ekim planında dikkate alınması önerilir.'));
    }
    nedenler.add((
      'Not',
      'Tarım ürünlerinde birim maliyet, stok çıkış (satılan mamul) maliyetidir; dosyada tohum, gübre, işçilik gibi kalem ayrımı '
          'bulunmadığından kalem bazında neden analizi yapılamamıştır.'
    ));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Ust(r),
        GostergeIzgarasi(kartlar: [
          _DegerKarti(
              baslik: 'Tarımsal Alan brüt kâr · ${r.donem}',
              deger: mn(r.d26('Tarımsal Alan', 'Brüt satış kârı/zararı')),
              renk: _isaretRengi(r.d26('Tarımsal Alan', 'Brüt satış kârı/zararı')),
              alt: '2025 aynı dönem: ${mn(r.d25('Tarımsal Alan', 'Brüt satış kârı/zararı'))}'),
          _DegerKarti(
              baslik: 'Tarımsal Alan dönem net sonucu',
              deger: kz(r.d26('Tarımsal Alan', 'Dönem net kârı/zararı')),
              renk: _isaretRengi(r.d26('Tarımsal Alan', 'Dönem net kârı/zararı')),
              alt: '2025 yıl: ${kz(r.kalem('Tarımsal Alan', 'Dönem net kârı/zararı')?.y2025Yil ?? 0)}'),
          if (b26 != null)
            _DegerKarti(baslik: 'Buğday kg maliyeti · 2026', deger: tl2(b26.birimMaliyet), alt: '2025: ${tl2(b25?.birimMaliyet)}'),
          if (b26 != null)
            _DegerKarti(baslik: 'Buğday kg başı sonuç', deger: tl2f(b26.birimKar), renk: _isaretRengi(b26.birimKar ?? 0), alt: 'Satış fiyatı ${tl2(b26.fiyat)}'),
        ]),
        const SizedBox(height: 12),
        Panel(
          baslik: 'Ürün bazında birim maliyet ve satış fiyatı (₺/kg)',
          child: VeriTablosu(
            ilkSutunGenislik: 150,
            metinSutunlari: const {0, 1},
            basliklar: const ['Ürün', 'Çiftlik', 'Yıl', 'Satış (kg)', 'Satış', 'Birim maliyet', 'Satış fiyatı', 'Kg başı sonuç'],
            satirlar: [
              for (final t in urunler)
                [t.urun, t.ciftlik, '${t.yil}', sayi(t.satisKg), mn(t.satisTl), tl2(t.birimMaliyet), tl2(t.fiyat), tl2f(t.birimKar)],
            ],
          ),
        ),
        _Nedenler(nedenler),
      ],
    );
  }
}

// ----------------------------------------------------------------- Kapsam

class _Kapsam extends StatelessWidget {
  const _Kapsam({required this.r});
  final CiftlikRaporu r;
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _Nedenler([
            (
              'Kaynak',
              '“2026 Yılı Çiftlik Raporları (7)” dosyası (yaklaşık 22 MB). Dosyanın metin çıktısının ilk bölümü okunmuştur: Çiftlikler Konsolide, '
                  '1604 Taşağıl, 1605 Aslım, 1611 Tarımsal Alan, 1613 Şekersüt, 1614 Pan-Gev gelir tabloları; satış özeti; satılan mamul maliyeti '
                  'detayı. Besi-düve yem tüketimi sayfasından sonraki sayfalar okunamamıştır.'
            ),
            ('Dönem', '2026 verileri Ocak–Eylül dönemini kapsar; karşılaştırmalar 2025’in aynı dokuz ayıyla yapılmıştır.'),
            ('Süt', 'Şekersüt ve Pan-Gev’de süt üretimi Ağustos 2025’te başladığından süt birim maliyeti 2025 Ağustos–Aralık ortalamasıyla karşılaştırılmıştır.'),
            ('Alternatif sayfalar', 'Dosyadaki “2” uzantılı çiftlik sayfaları konsolide toplamla örtüşmediğinden kullanılmamıştır.'),
            ('Çiftliklerimiz (ESK hariç)', 'Konsolide toplamdan 1604 Taşağıl (ESK besi hizmeti) çıkarılarak hesaplanmıştır.'),
            ('KVKK', 'Rapor yalnızca çiftlik bazında toplam tutar ve birim maliyet içerir; kişi adı, personel, ücret ayrıntısı, alıcı adı ve küpe numarası yoktur.'),
            ('Güncelleme', 'Dosyanın yeni sürümü geldiğinde veri araclar/ciftlik_rapor/uret.py ile yeniden üretilir.'),
          ], baslik: 'Kapsam ve notlar'),
        ],
      );
}
