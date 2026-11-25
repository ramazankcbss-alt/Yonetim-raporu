import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bicim.dart';
import '../tema.dart';
import '../veri/ciftlik_rapor.dart';
import '../veri/ciftlik_soru.dart';
import '../veri/maliyet_analiz.dart';
import '../veri/senaryo.dart';
import 'bilesenler.dart';
import 'gonder.dart';

/// Çiftlikler Rapor: her yıl ayrı bir bölümdür (Tarla Haritası sezonları gibi).
class CiftlikRaporEkran extends StatelessWidget {
  const CiftlikRaporEkran({super.key});

  /// Paketlenmiş veri bir kez okunur.
  static final Future<CiftlikRaporu> _veri = CiftlikRaporu.yukle();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Çiftlikler Rapor')),
      body: FutureBuilder<CiftlikRaporu>(
        future: _veri,
        builder: (context, s) {
          if (s.hasError) {
            return const Padding(padding: EdgeInsets.all(16), child: BilgiKutusu(uyari: true, yazi: 'Rapor verisi okunamadı.'));
          }
          final r = s.data;
          if (r == null) return const Center(child: CircularProgressIndicator());
          const net = 'Dönem net kârı/zararı';
          void ac(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
          return GonderAlani(
            konu: 'Çiftlikler Rapor – Yıllar',
            child: ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 24), children: [
              BilgiKutusu(
                  yazi: 'Her yıl ayrı bir bölümdür; içinde kâr / zarar, süt, maliyet takip ve piyasa senaryosu sekmeleri yer alır. '
                      'Kaynak: “${r.kaynak}” (muhasebe gelir tabloları) ve “ÇİFTLİKLER : MALİYET TAKİP 2026”.'),
              const SizedBox(height: 12),
              _YilKarti(
                baslik: '2025 yılı',
                alt: 'Ocak–Aralık 2025 · Konsolide net sonuç ${kz(r.d25Yil(kKonsolide, net))} · '
                    'Şekersüt ve Pan-Gev verisi Ağustos 2025’ten başlar',
                ikon: Icons.event_available,
                dokun: () => ac(_Yil2025(r: r)),
              ),
              _YilKarti(
                baslik: '2026 yılı',
                alt: '${r.donem} · Konsolide net sonuç ${kz(r.d26(kKonsolide, net))} · Ekim–Aralık henüz işlenmemiş',
                ikon: Icons.insights,
                dokun: () => ac(_Yil2026(r: r)),
              ),
              _YilKarti(
                baslik: '2027 yılı',
                alt: 'Veri yok · 2027 kayıtları kaynak dosyalara girildiğinde bu bölüm doldurulacaktır',
                ikon: Icons.event_note,
                dokun: () => ac(const _Yil2027()),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _YilKarti extends StatelessWidget {
  const _YilKarti({required this.baslik, required this.alt, required this.ikon, required this.dokun});
  final String baslik, alt;
  final IconData ikon;
  final VoidCallback dokun;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(backgroundColor: Renk.anaAcik, child: Icon(ikon, color: Renk.ana)),
          title: Text(baslik, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(alt),
          trailing: const Icon(Icons.chevron_right),
          onTap: dokun,
        ),
      );
}

/// Sekmeli yıl ekranı.
class _SekmeliYil extends StatelessWidget {
  const _SekmeliYil({required this.baslik, required this.sekmeler});
  final String baslik;
  final List<(String, Widget)> sekmeler;
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: sekmeler.length,
        child: Scaffold(
          appBar: AppBar(
            title: Text(baslik),
            bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xCCFFFFFF),
              indicatorColor: Colors.white,
              tabs: [for (final (t, _) in sekmeler) Tab(text: t)],
            ),
          ),
          body: TabBarView(children: [
            for (final (t, w) in sekmeler) t == 'Kapsam' ? w : GonderAlani(konu: '$baslik – $t', child: w),
          ]),
        ),
      );
}

class _Yil2026 extends StatelessWidget {
  const _Yil2026({required this.r});
  final CiftlikRaporu r;
  @override
  Widget build(BuildContext context) => _SekmeliYil(baslik: 'Çiftlikler Rapor 2026', sekmeler: [
        ('Kâr / Zarar', _KarZarar(r: r)),
        ('Soru Sor', _SoruSor(r: r)),
        ('Süt', _Sut(r: r)),
        ('Et / Besi', _Et(r: r)),
        ('Tarım', _Tarim(r: r)),
        ('Maliyet Takip', _MaliyetTakip(r: r)),
        ('Piyasa Senaryosu', _PiyasaSenaryosu(r: r, sabitYil: 2026)),
        ('Kapsam', _Kapsam(r: r)),
      ]);
}

class _Yil2025 extends StatelessWidget {
  const _Yil2025({required this.r});
  final CiftlikRaporu r;
  @override
  Widget build(BuildContext context) => _SekmeliYil(baslik: 'Çiftlikler Rapor 2025', sekmeler: [
        ('Kâr / Zarar', _KarZarar2025(r: r)),
        ('Süt', _Sut2025(r: r)),
        ('Maliyet Takip', _MaliyetTakip(r: r, yil: 2025)),
        ('Piyasa Senaryosu', _PiyasaSenaryosu(r: r, sabitYil: 2025)),
      ]);
}

class _Yil2027 extends StatelessWidget {
  const _Yil2027();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Çiftlikler Rapor 2027')),
        body: ListView(padding: const EdgeInsets.all(16), children: const [
          BilgiKutusu(
              uyari: true,
              yazi: '2027 yılına ait çiftlik raporu verisi henüz bulunmuyor. “2026 Yılı Çiftlik Raporları” ve “ÇİFTLİKLER : MALİYET TAKİP 2026” '
                  'dosyaları 2027 sütunu içermiyor. 2027 dosyaları paylaşıldığında bu bölüm kâr / zarar, süt, maliyet takip ve piyasa '
                  'senaryosu sekmeleriyle doldurulacaktır. Tahmini ya da varsayımsal rakam gösterilmez.'),
        ]),
      );
}

/// 2025 kâr / zarar: yıl toplamları ve aylık sonuç.
class _KarZarar2025 extends StatefulWidget {
  const _KarZarar2025({required this.r});
  final CiftlikRaporu r;
  @override
  State<_KarZarar2025> createState() => _KarZarar2025State();
}

class _KarZarar2025State extends State<_KarZarar2025> {
  String _secili = kKonsolide;

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final c = _secili;
    const net = 'Dönem net kârı/zararı', brut = 'Brüt satış kârı/zararı';
    final aylik = r.aylikSonuc(c, yil: 2025);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text('Kaynak: ${r.kaynak} · Fiili Ocak–Aralık 2025', style: const TextStyle(fontSize: 12, color: Renk.soluk)),
        ),
        BilgiKutusu(
            yazi: '2025 yılında çiftlikler konsolide olarak ${kz(r.d25Yil(kKonsolide, net))} elde etti '
                '(2024: ${kz(r.d24Yil(kKonsolide, net))}). Brüt satış kârı ${mn(r.d25Yil(kKonsolide, brut))}.'),
        Secici<String>(
          secenekler: r.ciftlikler.reversed.toList(),
          secili: c,
          etiket: (s) => s,
          degisti: (s) => setState(() => _secili = s),
        ),
        GostergeIzgarasi(kartlar: [
          for (final (k, f) in [('Net satışlar', mn), (brut, mn), ('FAVÖK (EBITDA)', mn), (net, kz)])
            _DegerKarti(
              baslik: '${k == net ? 'Dönem net sonucu' : k} · 2025',
              deger: f(r.d25Yil(c, k)),
              renk: k == 'Net satışlar' ? Renk.yazi : _isaretRengi(r.d25Yil(c, k)),
              alt: '2024: ${f(r.d24Yil(c, k))}',
            ),
        ]),
        const SizedBox(height: 12),
        Panel(
          baslik: 'Aylık brüt satış kârı ve dönem net sonucu (2025)',
          child: aylik.isEmpty
              ? const Text('Bu görünüm için aylık kırılım dosyada bulunmuyor.', style: TextStyle(color: Renk.soluk))
              : _AylikGrafik(aylar: aylik),
        ),
        Panel(
          baslik: 'Çiftlik bazında kâr / zarar (Ocak–Aralık 2025)',
          child: VeriTablosu(
            ilkSutunGenislik: 150,
            basliklar: const ['Çiftlik', 'Net satış', 'Satış maliyeti', 'Brüt kâr', 'Net 2025', 'Net 2024'],
            satirlar: [
              for (final x in r.ciftlikler)
                [
                  x,
                  mn(r.d25Yil(x, 'Net satışlar')),
                  mn(r.d25Yil(x, 'Satışların maliyeti')),
                  mn(r.d25Yil(x, brut)),
                  mn(r.d25Yil(x, net)),
                  mn(r.d24Yil(x, net)),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 2025 süt: muhasebe (satılan mamul maliyeti) ve maliyet takip litre maliyeti yan yana.
class _Sut2025 extends StatelessWidget {
  const _Sut2025({required this.r});
  final CiftlikRaporu r;
  @override
  Widget build(BuildContext context) {
    String s2(double? v) => v == null ? '—' : sayi(v, ondalik: 2);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const BilgiKutusu(
            yazi: 'Muhasebe: satılan mamul maliyeti ÷ üretilen litre. Takip: “ÇİFTLİKLER : MALİYET TAKİP 2026” SÜT MALİYETİ sayfasındaki 2025 değeri. '
                'Muhasebe verisi Ağustos 2025’ten başlar.'),
        for (final (c, u) in const [('Şekersüt', kSekersut), ('Pan-Gev', kPangev)])
          Panel(
            baslik: '$c – 1 litre süt (2025, ₺)',
            child: VeriTablosu(
              ilkSutunGenislik: 80,
              basliklar: const ['Ay', 'Üretim (lt)', 'Muhasebe maliyet', 'Takip maliyet', 'Satış fiyatı', 'Litre başı sonuç'],
              satirlar: [
                for (var ay = 1; ay <= 12; ay++)
                  if (r.birimAylar(u).where((b) => b.yil == 2025 && b.ayNo == ay && b.miktar > 0).firstOrNull case final b?)
                    [
                      raporAylari[ay - 1],
                      sayi(b.miktar),
                      s2(b.birimMaliyet),
                      s2(r.mt?.sutAylar(c, 2025).where((x) => x.ay == ay).firstOrNull?.maliyet),
                      s2(b.fiyat),
                      b.fiyat == null ? '—' : tl2f(b.fiyat! - b.birimMaliyet),
                    ]
                  else if (r.mt?.sutAylar(c, 2025).where((x) => x.ay == ay).firstOrNull case final t?)
                    [raporAylari[ay - 1], '—', '—', s2(t.maliyet), '—', '—'],
                if (r.donemOrt(u, 2025).aylar.isNotEmpty)
                  () {
                    final d = r.donemOrt(u, 2025);
                    return ['Ort.', sayi(d.aylar.fold<double>(0, (t, a) => t + a.miktar)), s2(d.birimMaliyet), '', s2(d.fiyat),
                      d.fiyat == null ? '—' : tl2f(d.fiyat! - d.birimMaliyet)];
                  }(),
              ],
              vurguluSonSatir: r.donemOrt(u, 2025).aylar.isNotEmpty,
            ),
          ),
      ],
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
    final yillar = {for (final a in l) a.yil}.toList()..sort((x, y) => y.compareTo(x));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final yil in yillar) ...[
        _YilBasligi(yil),
        () {
          final y = [for (final a in l) if (a.yil == yil) a];
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(height: 170, child: CustomPaint(size: Size.infinite, painter: _CizgiCizer(y))),
            const SizedBox(height: 6),
            Wrap(alignment: WrapAlignment.center, spacing: 16, children: [
              const _Lej(renk: Renk.kirmizi, yazi: 'Birim maliyet'),
              _Lej(renk: Renk.ana, yazi: fiyatAdi),
            ]),
            const SizedBox(height: 8),
            VeriTablosu(
              ilkSutunGenislik: 80,
              basliklar: const ['Ay', 'Miktar', 'Maliyet', 'Fiyat', 'Fark'],
              satirlar: [
                for (final a in y)
                  [raporAylari[a.ayNo - 1], sayi(a.miktar), tl2(a.birimMaliyet), tl2(a.fiyat), tl2f(a.fiyat == null ? null : a.fiyat! - a.birimMaliyet)],
              ],
            ),
          ]);
        }(),
        const SizedBox(height: 14),
      ],
    ]);
  }
}

/// Yıl ayırıcı başlığı.
class _YilBasligi extends StatelessWidget {
  const _YilBasligi(this.yil);
  final int yil;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 4, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Renk.anaAcik, borderRadius: BorderRadius.circular(8)),
        child: Text('$yil', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Renk.anaKoyu)),
      );
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final yil in {for (final t in urunler) t.yil}.toList()..sort((a, b) => b.compareTo(a))) ...[
              _YilBasligi(yil),
              VeriTablosu(
                ilkSutunGenislik: 150,
                metinSutunlari: const {0, 1},
                basliklar: const ['Ürün', 'Çiftlik', 'Satış (kg)', 'Satış', 'Birim maliyet', 'Satış fiyatı', 'Kg başı sonuç'],
                satirlar: [
                  for (final t in urunler.where((t) => t.yil == yil))
                    [t.urun, t.ciftlik, sayi(t.satisKg), mn(t.satisTl), tl2(t.birimMaliyet), tl2(t.fiyat), tl2f(t.birimKar)],
                ],
              ),
              const SizedBox(height: 12),
            ],
          ]),
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
            ('Süt', 'Şekersüt ve Pan-Gev gelir tablosu dosyasında Ağustos 2025’ten itibaren yer aldığından süt birim maliyeti 2025 Ağustos–Aralık ortalamasıyla karşılaştırılmıştır. Daha eski aylar için Maliyet Takip sekmesine bakılabilir.'),
            ('Maliyet Takip', '“ÇİFTLİKLER : MALİYET TAKİP 2026” dosyasındaki özet, süt, karkas, canlı maliyet, tarım ve yem sayfaları; İLAÇ AŞI ve DİĞER MALZEMELER sayfaları malzeme ayrıntısı olduğundan özet tablolar üzerinden kullanılmıştır. Formül hatalı hücreler hesaba katılmamıştır.'),
            ('İki senaryo', 'Çiftlik sayfaları (ör. “1605 - Aslım”) grup içi ürünlerin maliyet bedeliyle aktarıldığı fiili durumu; “2” uzantılı sayfalar (ör. “1605 - Aslım 2”) aynı ürünler dışarı satılsaydı piyasa satış fiyatıyla, dışarıdan alınsaydı piyasa alış fiyatıyla hesaplanan durumu gösterir. Kâr / Zarar, Süt, Et ve Tarım sekmeleri birinci senaryoya; Piyasa Senaryosu sekmesi ikisinin karşılaştırmasına dayanır. “Çiftlikler Konsolide (2)” sayfası Taşağıl’ı (ESK) içermez.'),
            ('Çiftliklerimiz (ESK hariç)', 'Konsolide toplamdan 1604 Taşağıl (ESK besi hizmeti) çıkarılarak hesaplanmıştır.'),
            ('KVKK', 'Rapor yalnızca çiftlik bazında toplam tutar ve birim maliyet içerir; kişi adı, personel, ücret ayrıntısı, alıcı adı ve küpe numarası yoktur.'),
            ('Güncelleme', 'Dosyanın yeni sürümü geldiğinde veri araclar/ciftlik_rapor/uret.py ile yeniden üretilir.'),
          ], baslik: 'Kapsam ve notlar'),
        ],
      );
}

// ----------------------------------------------------------------- Soru Sor

const _ornekSorular = [
  'Şekersüt süt maliyeti neden arttı?',
  'Mayıs ayında Pan-Gev yem maliyeti ne kadar?',
  'En çok zarar eden çiftlik hangisi?',
  'Buğday fiyatı 2025’e göre ne kadar değişti?',
  'ESK besi hizmeti neden zarar ediyor?',
  'Konsolide net kâr neden arttı?',
  'Teşvikler ne kadar?',
  'Aslım piyasa senaryosunda neden zarar ediyor?',
  'Tutarsızlıklar neler?',
];

/// Rapor verisi üzerinde soru-cevap. Sorular yalnızca bu cihazda saklanır.
class _SoruSor extends StatefulWidget {
  const _SoruSor({required this.r});
  final CiftlikRaporu r;
  @override
  State<_SoruSor> createState() => _SoruSorState();
}

class _SoruSorState extends State<_SoruSor> {
  static const _anahtar = 'ciftlik_rapor_sorular';
  final _kutu = TextEditingController();
  final _sorular = <String>[];

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() => _sorular.addAll(p.getStringList(_anahtar) ?? const []));
    });
  }

  @override
  void dispose() {
    _kutu.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_anahtar, _sorular);
  }

  void _sor([String? hazir]) {
    final q = (hazir ?? _kutu.text).trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sorular
        ..remove(q)
        ..insert(0, q);
      if (_sorular.length > 20) _sorular.removeRange(20, _sorular.length);
      _kutu.clear();
    });
    _kaydet();
  }

  void _sil(String q) {
    setState(() => _sorular.remove(q));
    _kaydet();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
              'Sorunuzu yazın; yanıt rapor dosyasındaki gelir tabloları, satış ve maliyet kayıtlarından hesaplanır. '
              'İlgili olumsuz sonuçlar ve veri tutarsızlıkları yanıtın altında kırmızı olarak işaretlenir. '
              'Sorular yalnızca bu cihazda saklanır.',
              style: TextStyle(fontSize: 12.5, color: Renk.soluk, height: 1.4)),
        ),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _kutu,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sor(),
              decoration: const InputDecoration(hintText: 'Örn. Şekersüt süt maliyeti neden arttı?'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(tooltip: 'Sor', onPressed: _sor, icon: const Icon(Icons.send)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final o in _ornekSorular) ActionChip(label: Text(o, style: const TextStyle(fontSize: 12)), onPressed: () => _sor(o)),
        ]),
        const SizedBox(height: 12),
        if (_sorular.isEmpty)
          const BilgiKutusu(yazi: 'Henüz soru sorulmadı. Yukarıdaki örneklerden birine dokunabilir ya da kendi sorunuzu yazabilirsiniz.'),
        for (final q in _sorular) _YanitKarti(y: cevapla(r, q), sil: () => _sil(q)),
      ],
    );
  }
}

class _YanitKarti extends StatelessWidget {
  const _YanitKarti({required this.y, required this.sil});
  final Yanit y;
  final VoidCallback sil;

  @override
  Widget build(BuildContext context) {
    final olumsuz = y.bulgular.where((b) => b.tur == BulguTuru.olumsuz).toList();
    final tutarsiz = y.bulgular.where((b) => b.tur == BulguTuru.tutarsizlik).toList();
    return Panel(
      baslik: y.soru,
        eylem: IconButton(tooltip: 'Soruyu kaldır', icon: const Icon(Icons.close, size: 18), onPressed: sil),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!y.anlasildi)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: BilgiKutusu(uyari: true, yazi: 'Soru tam anlaşılamadı; çiftlik, ürün veya kalem adı ekleyerek yeniden sorun.'),
            ),
          for (final p in y.paragraflar)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(p, style: const TextStyle(fontSize: 13.5, color: Renk.yazi, height: 1.45)),
            ),
          if (olumsuz.isNotEmpty) _BulguListesi(baslik: 'Olumsuz sonuçlar', bulgular: olumsuz),
          if (tutarsiz.isNotEmpty) _BulguListesi(baslik: 'Veri tutarsızlıkları', bulgular: tutarsiz),
        ]),
    );
  }
}

class _BulguListesi extends StatelessWidget {
  const _BulguListesi({required this.baslik, required this.bulgular});
  final String baslik;
  final List<Bulgu> bulgular;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Renk.kirmiziAcik,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Renk.kirmizi.withValues(alpha: 0.35)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(bulgular.first.tur == BulguTuru.olumsuz ? Icons.trending_down : Icons.report_problem_outlined, size: 18, color: Renk.kirmizi),
            const SizedBox(width: 6),
            Text('$baslik (${bulgular.length})', style: const TextStyle(fontWeight: FontWeight.w700, color: Renk.kirmizi)),
          ]),
          for (final b in bulgular)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '${b.baslik}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: b.aciklama),
                  if (b.kaynak.isNotEmpty)
                    TextSpan(text: '\nKaynak: ${b.kaynak}', style: const TextStyle(fontSize: 12, color: Renk.soluk, fontStyle: FontStyle.italic)),
                ]),
                style: const TextStyle(fontSize: 13, color: Renk.yazi, height: 1.4),
              ),
            ),
        ]),
      );
}

// ----------------------------------------------------------------- Maliyet Takip

/// "ÇİFTLİKLER : MALİYET TAKİP 2026" dosyasının analizi.
class _MaliyetTakip extends StatelessWidget {
  const _MaliyetTakip({required this.r, this.yil = 2026});
  final CiftlikRaporu r;
  final int yil;

  @override
  Widget build(BuildContext context) {
    final m = r.mt;
    if (m == null) {
      return const Padding(padding: EdgeInsets.all(16), child: BilgiKutusu(uyari: true, yazi: 'Maliyet takip verisi bulunamadı.'));
    }
    final bulgular = [for (final b in maliyetTakipBulgulari(r)) if (yil == 2026 || b.baslik.contains('$yil')) b];
    final olumsuz = [for (final b in bulgular) if (b.tur == BulguTuru.olumsuz) b];
    final tutarsiz = [for (final b in bulgular) if (b.tur == BulguTuru.tutarsizlik) b];
    String s2(double? v) => v == null ? '—' : sayi(v, ondalik: 2);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BilgiKutusu(
            yazi: 'Kaynak: “${m.kaynak}”; süt litre maliyeti “2026 Yılı Çiftlik Raporları” muhasebe verisiyle eşleştirilmiştir. Hayvancılık, süt ve karkas maliyetleri, canlı hayvan maliyeti, tarım ekiliş maliyetleri ve yem tüketimi '
                'aylık olarak incelenmiştir. Formül hatası (#REF!) içeren hücreler hesaba katılmamış, aşağıda tutarsızlık olarak listelenmiştir.'),
        if (olumsuz.isNotEmpty || tutarsiz.isNotEmpty)
          Panel(
            baslik: 'Olumsuz sonuçlar ve tutarsızlıklar',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (olumsuz.isNotEmpty) _BulguListesi(baslik: 'Olumsuz sonuçlar', bulgular: olumsuz),
              if (tutarsiz.isNotEmpty) _BulguListesi(baslik: 'Veri tutarsızlıkları', bulgular: tutarsiz),
            ]),
          ),
        // Hayvancılık
        for (final c in m.hayvanCiftlikleri)
          if (m.hayvanAylar(c, yil).isNotEmpty)
            Panel(
              baslik: '$c – hayvan başı aylık maliyet ($yil)',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                VeriTablosu(
                  ilkSutunGenislik: 80,
                  basliklar: const ['Ay', 'Hayvan', 'Toplam', 'Baş/ay', 'Baş/gün', 'Yem', 'İşçilik', 'Amortisman', 'Diğer'],
                  satirlar: [
                    for (final a in m.hayvanAylar(c, yil))
                      [
                        raporAylari[a.ay - 1],
                        sayi(a.hayvan),
                        mn(a.toplam!),
                        sayi(a.basinaAylik),
                        sayi(a.basinaGunluk),
                        sayi(a.basina(a.yem)),
                        sayi(a.basina(a.iscilik)),
                        sayi(a.basina(a.amortisman)),
                        sayi(a.basina(a.diger)),
                      ],
                    ['Ort.', '', '', sayi(m.donemBasina(c, yil, 'Toplam')), '', sayi(m.donemBasina(c, yil, 'Yem')), sayi(m.donemBasina(c, yil, 'İşçilik')),
                      sayi(m.donemBasina(c, yil, 'Amortisman')), sayi(m.donemBasina(c, yil, 'Diğer'))],
                  ],
                  vurguluSonSatir: true,
                ),
                if (yil == 2026)
                  for (final (b, a) in hayvanNedenleri(m, c))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: '$b: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: a),
                    ]), style: const TextStyle(fontSize: 13, height: 1.4)),
                  ),
              ]),
            ),
        // Süt litre maliyeti
        Panel(
          baslik: '1 litre süt maliyeti (₺)',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final yil in this.yil == 2026 ? const [2026, 2025, 2024] : const [2025, 2024])
              if (m.sut.any((x) => x.yil == yil)) ...[
                _YilBasligi(yil),
                VeriTablosu(
                  ilkSutunGenislik: 80,
                  basliklar: [
                    'Ay',
                    for (final c in const ['Şekersüt', 'Pan-Gev']) ...[
                      yil == 2026 ? '$c takip' : c,
                      if (yil == 2026) ...['$c muhasebe', '$c satış'],
                    ],
                  ],
                  satirlar: [
                    for (var ay = 1; ay <= 12; ay++)
                      if (m.sut.any((x) => x.ay == ay && x.yil == yil) ||
                          (yil == 2026 && sutEslesme(r, 'Şekersüt', ay).muhasebe != null))
                        [
                          raporAylari[ay - 1],
                          for (final c in const ['Şekersüt', 'Pan-Gev'])
                            if (yil == 2026)
                              ...() {
                                final e = sutEslesme(r, c, ay);
                                return [s2(e.takip), s2(e.muhasebe), e.satis == null ? '—' : '${s2(e.satis)}${e.satisMuhasebeden ? '*' : ''}'];
                              }()
                            else
                              s2(m.sutAylar(c, yil).where((x) => x.ay == ay).firstOrNull?.maliyet),
                        ],
                  ],
                ),
                if (yil == 2026)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                        'Takip: “ÇİFTLİKLER : MALİYET TAKİP 2026” SÜT MALİYETİ sayfası. Muhasebe: “2026 Yılı Çiftlik Raporları” satılan mamul '
                        'maliyeti ÷ üretilen litre. Satış: takip dosyasındaki fiyat; * işaretli aylarda takipte fiyat girilmediği için '
                        'muhasebedeki faturalanan ortalama fiyat kullanılmıştır. Aynı ay iki kez girilmez, iki kaynak yan yana gösterilir.',
                        style: TextStyle(fontSize: 12, height: 1.35)),
                  ),
                const SizedBox(height: 12),
              ],
            if (yil == 2026)
              for (final c in const ['Şekersüt', 'Pan-Gev'])
                for (final (b, a) in sutTakipNedenleri(m, c))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '$b: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: a),
                  ]), style: const TextStyle(fontSize: 13, height: 1.4)),
                ),
          ]),
        ),
        if (yil != 2026)
          const BilgiKutusu(
              yazi: 'Karkas, canlı hayvan, tarım ekiliş ve yem sayfaları yalnızca 2026 verisi içerdiğinden bu bölümler 2026 yılında yer alır.'),
        // Karkas
        if (yil == 2026)
        Panel(
          baslik: '1 kg karkas maliyeti (₺)',
          child: VeriTablosu(
            ilkSutunGenislik: 80,
            basliklar: const ['Ay', 'Aslım besi', 'Şekersüt dişi', 'Şekersüt besi', 'Pan-Gev dişi'],
            satirlar: [
              for (var ay = 1; ay <= 12; ay++)
                if (m.karkas.any((x) => x.ay == ay))
                  [
                    raporAylari[ay - 1],
                    for (final (c, t) in const [('Aslım', 'Besi'), ('Şekersüt', 'Dişi'), ('Şekersüt', 'Besi'), ('Pan-Gev', 'Dişi')])
                      () {
                        final x = m.karkas.where((k) => k.ciftlik == c && k.tur == t && k.ay == ay).firstOrNull;
                        if (x == null) return '';
                        if (x.maliyet == null || x.maliyet == 0) return x.not.isEmpty ? '—' : x.not;
                        return s2(x.maliyet);
                      }(),
                  ],
            ],
          ),
        ),
        // Canlı maliyet
        if (yil == 2026 && m.canli.isNotEmpty)
          Panel(
            baslik: 'Canlı hayvan maliyeti – kayar ortalama (₺/baş)',
            child: () {
              final aylar = {for (final x in m.canli) x.ay}.toList()..sort();
              final gruplar = <String>[];
              for (final x in m.canli) {
                final g = '${x.ciftlik} · ${x.kategori.toLowerCase()}';
                if (!gruplar.contains(g)) gruplar.add(g);
              }
              return VeriTablosu(
                ilkSutunGenislik: 170,
                basliklar: ['Grup', for (final a in aylar) raporAylari[a - 1].substring(0, 3), 'Değişim'],
                satirlar: [
                  for (final g in gruplar)
                    () {
                      final l = [for (final x in m.canli) if ('${x.ciftlik} · ${x.kategori.toLowerCase()}' == g) x];
                      return [
                        g,
                        for (final a in aylar) sayi(l.where((x) => x.ay == a).firstOrNull?.maliyet),
                        l.length >= 2 && l.first.maliyet > 0 ? yuzde((l.last.maliyet / l.first.maliyet - 1) * 100) : '—',
                      ];
                    }(),
                ],
              );
            }(),
          ),
        // Tarım
        if (yil == 2026)
        Panel(
          baslik: 'Tarım – ekiliş bazında maliyet (Ağustos 2025 – Eylül 2026)',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            VeriTablosu(
              ilkSutunGenislik: 150,
              metinSutunlari: const {0, 1},
              basliklar: const ['Ürün', 'Çiftlik', 'Dekar', 'Maliyet', '₺/da', 'Ortak paylı ₺/da'],
              satirlar: [
                for (final d in dekarSatirlari(m))
                  [d.e.urun, d.e.ciftlik, sayi(d.e.dekar), mn(d.e.toplam), sayi(d.dekarBasi), sayi(d.payliDekarBasi)],
                ['Ortak giderler', '', sayi(m.toplamDekar), mn(m.ortakToplam), sayi(m.ortakDekarBasi), ''],
              ],
              vurguluSonSatir: true,
            ),
            for (final (b, a) in tarimTakipNedenleri(r))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '$b: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: a),
                ]), style: const TextStyle(fontSize: 13, height: 1.4)),
              ),
          ]),
        ),
        // Yem
        if (yil == 2026)
        Panel(
          baslik: 'Yem – ana kalemlerde birim fiyat değişimi (Ocak → Eylül 2026)',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final g in m.yemGruplari)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '$g (9 ay ${mn(m.yemGenel[g] ?? 0)}): ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: yemFiyatDegisimleri(m, g).join('; ')),
                ]), style: const TextStyle(fontSize: 13, height: 1.4)),
              ),
          ]),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- Piyasa Senaryosu

/// Maliyet bedeliyle aktarım (çiftlik sayfası) ile piyasa fiyatıyla değerleme
/// ("2" uzantılı sayfa) karşılaştırması.
class _PiyasaSenaryosu extends StatefulWidget {
  const _PiyasaSenaryosu({required this.r, this.sabitYil});
  final CiftlikRaporu r;

  /// Yıl bölümünden açıldığında aylık görünüm bu yıla sabitlenir.
  final int? sabitYil;
  @override
  State<_PiyasaSenaryosu> createState() => _PiyasaSenaryosuState();
}

class _PiyasaSenaryosuState extends State<_PiyasaSenaryosu> {
  String? _secili;
  String _gorunum = 'Aylık';
  int? _yil;

  @override
  Widget build(BuildContext context) {
    final s = widget.r.senaryo;
    if (s == null || s.ciftlikler.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16), child: BilgiKutusu(uyari: true, yazi: 'Dosyada piyasa fiyatlı senaryo sayfası bulunamadı.'));
    }
    final c = s.ciftlik(_secili ?? '') ?? s.ciftlikler.first;
    final yillar = s.yillar.isEmpty ? const [2026] : s.yillar;
    final sabit = widget.sabitYil;
    final yil = sabit != null && yillar.contains(sabit) ? sabit : (yillar.contains(_yil) ? _yil! : yillar.first);
    final aylik = _gorunum == 'Aylık';
    final bulgular = senaryoBulgulari(widget.r, yil: aylik ? yil : null);
    final olumsuz = [for (final b in bulgular) if (b.tur == BulguTuru.olumsuz) b];
    final tutarsiz = [for (final b in bulgular) if (b.tur == BulguTuru.tutarsizlik) b];
    final bilgi = [for (final k in s.kontrol) if (k.tur == 'bilgi' && (c.ciftlik == kSenaryoToplam || k.ciftlik == c.ciftlik)) k];
    String m1(double v) => sayi(v / 1e6, ondalik: 1);
    String f1(double v) => '${v > 0 ? '+' : v < 0 ? '−' : ''}${sayi(v.abs() / 1e6, ondalik: 1)}';
    const net = 'Dönem net kârı/zararı';
    SenaryoDonem? dn(SenaryoCiftlik x, int y) => x.donemler[y];
    final sirali = [...s.ciftlikler.skip(1), s.ciftlikler.first];
    final toplamSon = s.ciftlikler.first.ciftlik == kSenaryoToplam;
    String etiket(int y) => dn(s.ciftlikler.first, y)?.etiket ?? '$y';
    const kaynakStil = TextStyle(fontSize: 12, color: Renk.soluk, fontStyle: FontStyle.italic);

    Widget ciftlikSecici() => Wrap(spacing: 8, runSpacing: 4, children: [
          for (final x in s.ciftlikler)
            ChoiceChip(label: Text(x.ciftlik), selected: x.ciftlik == c.ciftlik, onSelected: (_) => setState(() => _secili = x.ciftlik)),
        ]);
    Widget bulguPaneli() => Panel(
          baslik: 'Olumsuz sonuçlar ve tutarsızlıklar',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (olumsuz.isNotEmpty) _BulguListesi(baslik: 'Olumsuz sonuçlar', bulgular: olumsuz),
            if (tutarsiz.isNotEmpty) _BulguListesi(baslik: 'Veri tutarsızlıkları', bulgular: tutarsiz),
          ]),
        );

    final govde = <Widget>[];
    if (aylik) {
      final d = dn(c, yil);
      govde.addAll([
        const SizedBox(height: 8),
        if (sabit == null)
          Wrap(spacing: 8, children: [
            for (final y in yillar) ChoiceChip(label: Text('$y'), selected: y == yil, onSelected: (_) => setState(() => _yil = y)),
          ]),
        Panel(
          baslik: 'Dönem net sonucu – ${etiket(yil)} (mn ₺)',
          child: VeriTablosu(
            ilkSutunGenislik: 150,
            basliklar: const ['Çiftlik', 'Maliyet bedeliyle', 'Piyasa fiyatıyla', 'Fark'],
            satirlar: [
              for (final x in sirali)
                if (dn(x, yil) case final e?) [x.ciftlik, m1(e.toplam(net, 1)), m1(e.toplam(net, 2)), f1(e.toplam(net, 2) - e.toplam(net, 1))],
            ],
            vurguluSonSatir: toplamSon,
          ),
        ),
        if (olumsuz.isNotEmpty || tutarsiz.isNotEmpty) bulguPaneli(),
        const SizedBox(height: 4),
        ciftlikSecici(),
        if (d != null) ...[
          Panel(
            baslik: '${c.ciftlik} – kalem karşılaştırması, ${d.etiket} (mn ₺)',
            child: VeriTablosu(
              ilkSutunGenislik: 150,
              basliklar: const ['Kalem', 'Maliyet bedeliyle', 'Piyasa fiyatıyla', 'Fark'],
              satirlar: [
                for (final k in senaryoKalemleri) [k, m1(d.toplam(k, 1)), m1(d.toplam(k, 2)), f1(d.toplam(k, 2) - d.toplam(k, 1))],
              ],
              vurguluSonSatir: true,
            ),
          ),
          Panel(
            baslik: '${c.ciftlik} – aylık net sonuç, $yil (mn ₺)',
            child: VeriTablosu(
              ilkSutunGenislik: 80,
              basliklar: const ['Ay', 'Maliyet bedeliyle', 'Piyasa fiyatıyla', 'Fark'],
              satirlar: [
                for (var i = 1; i <= d.aySayisi; i++)
                  [raporAylari[i - 1], m1(d.ay(i, net, 1)), m1(d.ay(i, net, 2)), f1(d.ay(i, net, 2) - d.ay(i, net, 1))],
                ['Toplam', m1(d.toplam(net, 1)), m1(d.toplam(net, 2)), f1(d.toplam(net, 2) - d.toplam(net, 1))],
              ],
              vurguluSonSatir: true,
            ),
          ),
          if (c.sayfa.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  'Kaynak: “${c.sayfa}” (maliyet bedeliyle) ve “${c.sayfa} 2” (piyasa fiyatıyla) sayfaları · '
                  '“$kSatirNet” satırı · ${aySutunu(yil, 1)}–${aySutunu(yil, d.aySayisi)} sütunları.',
                  style: kaynakStil),
            ),
        ],
        if (yil == 2026) _Nedenler(senaryoNedenleri(s, c), baslik: 'Farkın nedenleri'),
        if (yil == 2026 && bilgi.isNotEmpty) _Nedenler([for (final k in bilgi) (k.baslik, k.aciklama)], baslik: 'Notlar'),
      ]);
    } else {
      final ys = yillar.reversed.toList();
      govde.addAll([
        Panel(
          baslik: 'Yıllara göre dönem net sonucu (mn ₺)',
          child: VeriTablosu(
            ilkSutunGenislik: 150,
            basliklar: ['Çiftlik', for (final y in ys) ...['$y maliyet', '$y piyasa']],
            satirlar: [
              for (final x in sirali)
                [
                  x.ciftlik,
                  for (final y in ys) ...[
                    dn(x, y) == null ? '—' : m1(dn(x, y)!.toplam(net, 1)),
                    dn(x, y) == null ? '—' : m1(dn(x, y)!.toplam(net, 2)),
                  ],
                ],
            ],
            vurguluSonSatir: toplamSon,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
              'Dönemler: ${[for (final y in ys) etiket(y)].join(', ')}. Şekersüt ve Pan-Gev 2025 verisi Ağustos 2025’ten başlar. '
              'Kaynak: çiftlik sayfaları ve “2” uzantılı sayfalar · “$kSatirNet” satırı · '
              '${[for (final y in ys) '$y: ${aySutunu(y, 1)}–${aySutunu(y, dn(s.ciftlikler.first, y)?.aySayisi ?? 12)}'].join(', ')} sütunları.',
              style: kaynakStil),
        ),
        if (olumsuz.isNotEmpty || tutarsiz.isNotEmpty) bulguPaneli(),
        const SizedBox(height: 4),
        ciftlikSecici(),
        Panel(
          baslik: '${c.ciftlik} – yıllara göre kalemler (mn ₺)',
          child: VeriTablosu(
            ilkSutunGenislik: 150,
            basliklar: ['Kalem', for (final y in ys) ...['$y maliyet', '$y piyasa']],
            satirlar: [
              for (final k in senaryoKalemleri)
                [
                  k,
                  for (final y in ys) ...[
                    dn(c, y) == null ? '—' : m1(dn(c, y)!.toplam(k, 1)),
                    dn(c, y) == null ? '—' : m1(dn(c, y)!.toplam(k, 2)),
                  ],
                ],
            ],
            vurguluSonSatir: true,
          ),
        ),
      ]);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BilgiKutusu(yazi: '${s.aciklama} Tutarlar mn ₺. Gelir tabloları aylık tutulduğundan günlük ve haftalık kırılım bulunmaz.'),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'Aylık', label: Text('Aylık')), ButtonSegment(value: 'Yıllık', label: Text('Yıllar karşılaştırması'))],
          selected: {_gorunum},
          onSelectionChanged: (x) => setState(() => _gorunum = x.first),
        ),
        ...govde,
      ],
    );
  }
}
