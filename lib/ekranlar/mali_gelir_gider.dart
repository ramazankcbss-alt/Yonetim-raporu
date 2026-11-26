import 'package:flutter/material.dart';

import '../bicim.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'bilesenler.dart';
import 'esk.dart' show tl, kzRenk;
import 'gonder.dart';

const _ayAdi = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
const _ayKisa = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
String _pay(double v, double t) => t == 0 ? '—' : '%${sayi(v / t * 100, ondalik: 1)}';
String _mn(double v) => sayi(v / 1e6, ondalik: 2);
String _isaretli(double v) => '${v >= 0 ? '' : '−'}${_mn(v.abs())}';
String _degisim(double yeni, double eski) {
  if (eski == 0) return '—';
  final f = (yeni - eski) / eski.abs() * 100;
  return '${f >= 0 ? '+' : '−'}%${sayi(f.abs(), ondalik: 1)}';
}

enum GgSekme { gider, gelir, karZarar }

String ggDonemAdi(DateTime b, GgDonem d) => switch (d) {
      GgDonem.gun => tarihUzun(b),
      GgDonem.hafta => haftaEtiketi(b),
      GgDonem.ay => '${_ayAdi[b.month - 1]} ${b.year}',
      GgDonem.yil => '${b.year}',
    };

String _kisa(DateTime b, GgDonem d) => switch (d) {
      GgDonem.gun => gunAy(b),
      GgDonem.hafta => '${isoHafta(b)}. hf',
      GgDonem.ay => '${_ayKisa[b.month - 1]} ${b.year % 100}',
      GgDonem.yil => '${b.year}',
    };

/// Mali Raporlar › Gider / Gelir / Kâr-Zarar: her biri kendi içinde Günlük, Haftalık,
/// Aylık, Yıllık ve Karşılaştırma sekmeleriyle.
/// [faturalar]: gider dönemindeki faturaların fatura bazında listesi (2026 Fatura);
/// [kontrol]: fatura kayıt kontrolü (tutarsızlıklar) sayfası.
class GelirGiderBolumu extends StatelessWidget {
  const GelirGiderBolumu({super.key, required this.veri, required this.sekme, this.faturalar, this.kontrol});
  final GelirGider veri;
  final GgSekme sekme;
  final Widget Function(DateTime bas, DateTime bit, String baslik)? faturalar;
  final WidgetBuilder? kontrol;

  String get _ad => switch (sekme) { GgSekme.gider => 'Gider', GgSekme.gelir => 'Gelir', GgSekme.karZarar => 'Kâr / Zarar' };

  @override
  Widget build(BuildContext context) {
    const alt = ['Günlük', 'Haftalık', 'Aylık', 'Yıllık', 'Karşılaştırma'];
    return DefaultTabController(
      length: alt.length,
      child: Column(children: [
        Material(
          color: Renk.anaAcik,
          child: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Renk.anaKoyu,
            unselectedLabelColor: Renk.soluk,
            indicatorColor: Renk.ana,
            tabs: [for (final a in alt) Tab(text: a)],
          ),
        ),
        Expanded(
          child: TabBarView(children: [
            for (final (i, d) in GgDonem.values.indexed)
              GonderAlani(
                konu: 'Mali Raporlar – $_ad – ${alt[i]}',
                child: GelirGiderSekmesi(veri: veri, sekme: sekme, donem: d, faturalar: faturalar),
              ),
            GonderAlani(
              konu: 'Mali Raporlar – $_ad – Karşılaştırma',
              child: _Karsilastirma(veri: veri, sekme: sekme, kontrol: kontrol),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Seçilen dönem (gün / hafta / ay / yıl) için Gider, Gelir ya da Kâr-Zarar ayrıntısı.
class GelirGiderSekmesi extends StatefulWidget {
  const GelirGiderSekmesi({super.key, required this.veri, required this.sekme, required this.donem, this.faturalar});
  final GelirGider veri;
  final GgSekme sekme;
  final GgDonem donem;
  final Widget Function(DateTime bas, DateTime bit, String baslik)? faturalar;
  @override
  State<GelirGiderSekmesi> createState() => _GelirGiderSekmesiState();
}

class _GelirGiderSekmesiState extends State<GelirGiderSekmesi> {
  String? _ciftlik;
  DateTime? _secili;

  @override
  Widget build(BuildContext context) {
    final g = widget.veri, d = widget.donem;
    if (g.bos) {
      return const Padding(
          padding: EdgeInsets.all(16),
          child: BilgiKutusu(yazi: 'Gider ve gelir tablosu verisi henüz yok. Mali Raporlar klasöründeki mali_veri.json güncellenmeli.'));
    }
    if ((d == GgDonem.gun || d == GgDonem.hafta) && !g.gunVar) {
      return const Padding(
          padding: EdgeInsets.all(16),
          child: BilgiKutusu(
              yazi: 'Günlük ve haftalık görünüm için fatura tarihleri gerekir; mali veri bir sonraki güncellemede yenilenince açılır.'));
    }
    final donemler = g.donemler(d,
        giderli: widget.sekme != GgSekme.gelir, gelirli: widget.sekme != GgSekme.gider);
    if (donemler.isEmpty) return const Center(child: Text('Bu sekmede kayıt yok'));
    final bas = donemler.contains(_secili) ? _secili! : donemler.first;
    final bit = ggDonemSonu(bas, d);
    final s = (ciftlik: _ciftlik, bas: bas, bit: bit);
    final govde = switch (widget.sekme) {
      GgSekme.gider => _gider(g, s, bas, bit),
      GgSekme.gelir => _gelir(g, s),
      GgSekme.karZarar => _karZarar(g, s),
    };
    return ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 24), children: [
      SizedBox(
        height: 44,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final b in donemler.take(d == GgDonem.gun ? 90 : 60))
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(label: Text(_kisa(b, d)), selected: b == bas, onSelected: (_) => setState(() => _secili = b)),
            ),
        ]),
      ),
      Wrap(spacing: 6, runSpacing: 4, children: [
        ChoiceChip(label: const Text('Tüm çiftlikler'), selected: _ciftlik == null, onSelected: (_) => setState(() => _ciftlik = null)),
        for (final c in g.ciftlikler)
          ChoiceChip(label: Text(c), selected: _ciftlik == c, onSelected: (_) => setState(() => _ciftlik = c)),
      ]),
      const SizedBox(height: 8),
      Text(ggDonemAdi(bas, d), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      ...govde,
      const SizedBox(height: 8),
      Text(
          'Kaynak: “${widget.sekme == GgSekme.gelir ? g.kaynakGelir : widget.sekme == GgSekme.gider ? g.kaynakGider : '${g.kaynakGelir}” ve “${g.kaynakGider}'}” '
          '(Drive › Mali Raporlar). Tutarlar KDV hariçtir; tarih fatura (belge) tarihidir. KVKK: satıcı ve müşteri adları, belge numaraları aktarılmaz.',
          style: const TextStyle(fontSize: 12, color: Renk.soluk, fontStyle: FontStyle.italic)),
    ]);
  }

  String _baslik(DateTime bas) => '${_ciftlik ?? 'Tüm çiftlikler'} · ${ggDonemAdi(bas, widget.donem)}';

  /// Yıllık görünümde ay ay dağılım (dönem içindeki aylar).
  List<(int, int)> _aylar(GgSuzgec s) => [
        for (final a in widget.veri.aylar)
          if (!DateTime(a.$1, a.$2).isBefore(s.bas!) && DateTime(a.$1, a.$2).isBefore(s.bit!)) a
      ];
  GgSuzgec _ay((int, int) a) => (ciftlik: _ciftlik, bas: DateTime(a.$1, a.$2), bit: DateTime(a.$1, a.$2 + 1));

  List<Widget> _gider(GelirGider g, GgSuzgec s, DateTime bas, DateTime bit) {
    final l = g.giderler(s);
    final top = l.fold(0.0, (t, x) => t + x.net);
    final brut = l.fold(0.0, (t, x) => t + x.brut);
    final canli = l.where((x) => x.kategori == kCanliHayvanAlimi).fold(0.0, (t, x) => t + x.net);
    final kat = GelirGider.grupla(l, (x) => x.kategori, (x) => x.net);
    return [
      GostergeIzgarasi(kartlar: [
        GostergeKarti(baslik: 'Toplam gider (KDV hariç)', deger: tl(top), ikon: Icons.receipt_long, renk: Renk.kirmizi, alt: _baslik(bas)),
        GostergeKarti(baslik: 'KDV dahil', deger: tl(brut), ikon: Icons.request_quote_outlined, renk: Renk.soluk),
        GostergeKarti(
            baslik: 'Canlı hayvan alımı hariç', deger: tl(top - canli), ikon: Icons.filter_alt_outlined, alt: 'Canlı hayvan alımı ${tl(canli)}'),
        if (kat.isNotEmpty)
          GostergeKarti(baslik: 'En büyük kalem', deger: kat.first.key, ikon: Icons.leaderboard_outlined, alt: '${tl(kat.first.value)} · ${_pay(kat.first.value, top)}'),
      ]),
      const SizedBox(height: 12),
      if (l.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Bu dönemde gider kaydı yok.')),
      if (l.isNotEmpty) ...[
        Panel(
          baslik: 'Gider türüne göre',
          child: VeriTablosu(
            ilkSutunGenislik: 190,
            basliklar: const ['Gider türü', 'Tutar (mn ₺)', 'Pay'],
            satirlar: [
              for (final e in kat) [e.key, _mn(e.value), _pay(e.value, top)],
              ['Toplam', _mn(top), '%100'],
            ],
            vurguluSonSatir: true,
          ),
        ),
        if (_ciftlik == null)
          Panel(
            baslik: 'Çiftliklere göre',
            child: VeriTablosu(
              basliklar: const ['Çiftlik', 'Tutar (mn ₺)', 'Pay'],
              satirlar: [for (final e in GelirGider.grupla(l, (x) => x.ciftlik, (x) => x.net)) [e.key, _mn(e.value), _pay(e.value, top)]],
            ),
          ),
        if (widget.donem == GgDonem.yil) _aylik(g, s, gider: true),
        Panel(
          baslik: 'Tedarikçi grubuna göre',
          child: VeriTablosu(
            basliklar: const ['Grup', 'Tutar (mn ₺)', 'Pay'],
            satirlar: [for (final e in GelirGider.grupla(l, (x) => x.hesap, (x) => x.net)) [e.key, _mn(e.value), _pay(e.value, top)]],
          ),
        ),
      ],
      if (widget.faturalar != null)
        Card(
          child: ListTile(
            leading: const Icon(Icons.receipt_outlined),
            title: const Text('Bu dönemin faturaları'),
            subtitle: const Text('2026 Fatura listesi, fatura bazında (KDV dahil) ve kayıt kontrolü'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => widget.faturalar!(bas, bit, ggDonemAdi(bas, widget.donem)))),
          ),
        ),
      const Text('Gider türü, fatura kaleminin açıklamasına göre belirlenir; tanımlanamayan kalemler “Diğer” altında toplanır.',
          style: TextStyle(fontSize: 12, color: Renk.soluk)),
    ];
  }

  List<Widget> _gelir(GelirGider g, GgSuzgec s) {
    final l = g.gelirler(s);
    final top = l.fold(0.0, (t, x) => t + x.net);
    final brut = l.fold(0.0, (t, x) => t + x.brut);
    final m = <String, (double, double, String)>{};
    for (final x in l) {
      final k = '${x.urun}|${x.birim}';
      final o = m[k] ?? (0.0, 0.0, x.birim);
      m[k] = (o.$1 + x.miktar, o.$2 + x.net, x.birim);
    }
    final urunler = m.entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2));
    final grupIci = l.where((x) => x.hesap == 'Grup içi').fold(0.0, (t, x) => t + x.net);
    return [
      GostergeIzgarasi(kartlar: [
        GostergeKarti(baslik: 'Toplam gelir (KDV hariç)', deger: tl(top), ikon: Icons.payments_outlined, renk: Renk.yesil, alt: _baslik(s.bas!)),
        GostergeKarti(baslik: 'KDV dahil', deger: tl(brut), ikon: Icons.request_quote_outlined, renk: Renk.soluk),
        GostergeKarti(baslik: 'Grup içi satışlar', deger: tl(grupIci), ikon: Icons.swap_horiz, alt: _pay(grupIci, top)),
        if (urunler.isNotEmpty)
          GostergeKarti(
              baslik: 'En büyük gelir',
              deger: urunler.first.key.split('|').first,
              ikon: Icons.leaderboard_outlined,
              alt: '${tl(urunler.first.value.$2)} · ${_pay(urunler.first.value.$2, top)}'),
      ]),
      const SizedBox(height: 12),
      if (l.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Bu dönemde satış faturası yok.')),
      if (l.isNotEmpty) ...[
        Panel(
          baslik: 'Ürün ve hizmete göre',
          child: VeriTablosu(
            ilkSutunGenislik: 170,
            basliklar: const ['Ürün / hizmet', 'Miktar', 'Tutar (mn ₺)', 'Ort. fiyat (₺)', 'Pay'],
            satirlar: [
              for (final e in urunler)
                [
                  e.key.split('|').first,
                  '${sayi(e.value.$1)} ${e.value.$3}',
                  _mn(e.value.$2),
                  e.value.$1 == 0 ? '—' : sayi(e.value.$2 / e.value.$1, ondalik: 2),
                  _pay(e.value.$2, top),
                ],
              ['Toplam', '', _mn(top), '', '%100'],
            ],
            vurguluSonSatir: true,
          ),
        ),
        if (_ciftlik == null)
          Panel(
            baslik: 'Çiftliklere göre',
            child: VeriTablosu(
              basliklar: const ['Çiftlik', 'Tutar (mn ₺)', 'Pay'],
              satirlar: [for (final e in GelirGider.grupla(l, (x) => x.ciftlik, (x) => x.net)) [e.key, _mn(e.value), _pay(e.value, top)]],
            ),
          ),
        if (widget.donem == GgDonem.yil) _aylik(g, s, gider: false),
        Panel(
          baslik: 'Müşteri grubuna göre',
          child: VeriTablosu(
            basliklar: const ['Grup', 'Tutar (mn ₺)', 'Pay'],
            satirlar: [for (final e in GelirGider.grupla(l, (x) => x.hesap, (x) => x.net)) [e.key, _mn(e.value), _pay(e.value, top)]],
          ),
        ),
      ],
      if (g.iadeAdet > 0)
        Text('İade / düzeltme faturaları gelirden düşülmüştür (tüm dönem: ${g.iadeAdet} kalem, ${tl(g.iadeTutar)}).',
            style: const TextStyle(fontSize: 12, color: Renk.soluk)),
    ];
  }

  Widget _aylik(GelirGider g, GgSuzgec s, {required bool gider}) {
    final aylar = _aylar(s);
    double t((int, int) a) => gider ? g.giderToplam(_ay(a)) : g.gelirToplam(_ay(a));
    final top = aylar.fold(0.0, (a, b) => a + t(b));
    return Panel(
      baslik: 'Aylara göre',
      child: VeriTablosu(
        ilkSutunGenislik: 120,
        basliklar: const ['Ay', 'Tutar (mn ₺)', 'Pay'],
        satirlar: [
          for (final a in aylar) ['${_ayAdi[a.$2 - 1]} ${a.$1}', _mn(t(a)), _pay(t(a), top)],
          ['Toplam', _mn(top), '%100'],
        ],
        vurguluSonSatir: true,
      ),
    );
  }

  List<Widget> _karZarar(GelirGider g, GgSuzgec s) {
    final gelir = g.gelirToplam(s), gider = g.giderToplam(s), canliHaric = g.giderToplam(s, canliHaric: true);
    final fark = gelir - gider, fark2 = gelir - canliHaric;
    return [
      const BilgiKutusu(
          uyari: true,
          yazi: 'Bu sonuç fatura bazlıdır: satış faturaları (gelir) ile gelen faturalar (gider) arasındaki farktır. Personel ücretleri, '
              'amortisman, faturasız giderler ve stok değişimi dahil değildir; muhasebe gelir tablosundaki dönem kârının yerine geçmez. '
              'Canlı hayvan alımı yatırım niteliğinde olduğundan ayrıca hariç tutularak da gösterilir.'),
      const SizedBox(height: 10),
      GostergeIzgarasi(kartlar: [
        GostergeKarti(baslik: 'Gelir', deger: tl(gelir), ikon: Icons.payments_outlined, renk: Renk.yesil, alt: _baslik(s.bas!)),
        GostergeKarti(baslik: 'Gider', deger: tl(gider), ikon: Icons.receipt_long, renk: Renk.kirmizi),
        GostergeKarti(baslik: fark >= 0 ? 'Kâr (fatura bazlı)' : 'Zarar (fatura bazlı)', deger: tl(fark), ikon: Icons.balance, renk: kzRenk(fark)),
        GostergeKarti(
            baslik: 'Canlı hayvan alımı hariç', deger: tl(fark2), ikon: Icons.filter_alt_outlined, renk: kzRenk(fark2), alt: 'Gider ${tl(canliHaric)}'),
      ]),
      const SizedBox(height: 12),
      if (widget.donem == GgDonem.yil)
        Panel(
          baslik: 'Aylara göre (mn ₺)',
          child: VeriTablosu(
            ilkSutunGenislik: 120,
            basliklar: const ['Ay', 'Gelir', 'Gider', 'Kâr / zarar', 'Canlı hayvan hariç'],
            satirlar: [
              for (final a in _aylar(s))
                () {
                  final x = _ay(a);
                  final ge = g.gelirToplam(x), gi = g.giderToplam(x), gc = g.giderToplam(x, canliHaric: true);
                  return ['${_ayAdi[a.$2 - 1]} ${a.$1}', _mn(ge), _mn(gi), _isaretli(ge - gi), _isaretli(ge - gc)];
                }(),
              ['Toplam', _mn(gelir), _mn(gider), _isaretli(fark), _isaretli(fark2)],
            ],
            vurguluSonSatir: true,
          ),
        ),
      if (_ciftlik == null)
        Panel(
          baslik: 'Çiftliklere göre (mn ₺)',
          child: VeriTablosu(
            basliklar: const ['Çiftlik', 'Gelir', 'Gider', 'Kâr / zarar', 'Canlı hayvan hariç'],
            satirlar: [
              for (final c in g.ciftlikler)
                () {
                  final x = (ciftlik: c, bas: s.bas, bit: s.bit);
                  final ge = g.gelirToplam(x), gi = g.giderToplam(x), gc = g.giderToplam(x, canliHaric: true);
                  return [c, _mn(ge), _mn(gi), _isaretli(ge - gi), _isaretli(ge - gc)];
                }(),
              ['Toplam', _mn(gelir), _mn(gider), _isaretli(fark), _isaretli(fark2)],
            ],
            vurguluSonSatir: true,
          ),
        ),
      const Text(
          'Taşağıl (ESK) geliri, ESK’ya verilen hayvan bakım hizmeti ve sap balyası satışıdır. Çiftlikler arası (grup içi) satışlar '
          'bir çiftlikte gelir, diğerinde gider olabileceğinden çiftlik toplamları birlikte değerlendirilmelidir.',
          style: TextStyle(fontSize: 12, color: Renk.soluk)),
    ];
  }
}

/// Karşılaştırma: aylar arası değişim, son ay – önceki ay kalem farkları ve çiftlik dağılımı.
class _Karsilastirma extends StatefulWidget {
  const _Karsilastirma({required this.veri, required this.sekme, this.kontrol});
  final GelirGider veri;
  final GgSekme sekme;
  final WidgetBuilder? kontrol;
  @override
  State<_Karsilastirma> createState() => _KarsilastirmaState();
}

class _KarsilastirmaState extends State<_Karsilastirma> {
  String? _ciftlik;

  GgSuzgec _ay((int, int) a, [String? c]) => (ciftlik: c ?? _ciftlik, bas: DateTime(a.$1, a.$2), bit: DateTime(a.$1, a.$2 + 1));

  @override
  Widget build(BuildContext context) {
    final g = widget.veri, sk = widget.sekme;
    if (g.bos) return const Center(child: Text('Kayıt yok'));
    final aylar = g.aylar;
    double tutar(GgSuzgec s) => switch (sk) {
          GgSekme.gider => g.giderToplam(s),
          GgSekme.gelir => g.gelirToplam(s),
          GgSekme.karZarar => g.gelirToplam(s) - g.giderToplam(s),
        };
    final ad = switch (sk) { GgSekme.gider => 'Gider', GgSekme.gelir => 'Gelir', GgSekme.karZarar => 'Kâr / zarar' };
    final son = aylar.isNotEmpty ? aylar.last : null;
    final onceki = aylar.length > 1 ? aylar[aylar.length - 2] : null;
    final gecenYil = son == null ? null : (son.$1 - 1, son.$2);
    final gecenYilVar = gecenYil != null && aylar.contains(gecenYil);

    // Son ay – önceki ay kalem karşılaştırması (gider: tür, gelir: ürün, kâr/zarar: çiftlik)
    List<List<String>> kalemler() {
      if (son == null || onceki == null) return const [];
      Map<String, double> m((int, int) a) {
        final s = _ay(a);
        return switch (sk) {
          GgSekme.gider => Map.fromEntries(GelirGider.grupla(g.giderler(s), (x) => x.kategori, (x) => x.net)),
          GgSekme.gelir => Map.fromEntries(GelirGider.grupla(g.gelirler(s), (x) => x.urun, (x) => x.net)),
          GgSekme.karZarar => {for (final c in g.ciftlikler) c: tutar(_ay(a, c))},
        };
      }

      final a = m(son), b = m(onceki);
      final k = {...a.keys, ...b.keys}.toList()..sort((x, y) => ((a[y] ?? 0) - (b[y] ?? 0)).abs().compareTo(((a[x] ?? 0) - (b[x] ?? 0)).abs()));
      return [
        for (final x in k)
          [x, _isaretli(b[x] ?? 0), _isaretli(a[x] ?? 0), _isaretli((a[x] ?? 0) - (b[x] ?? 0)), _degisim(a[x] ?? 0, b[x] ?? 0)],
      ];
    }

    final yilTop = <int, double>{};
    for (final a in aylar) {
      yilTop.update(a.$1, (v) => v + tutar(_ay(a)), ifAbsent: () => tutar(_ay(a)));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 24), children: [
      Wrap(spacing: 6, runSpacing: 4, children: [
        ChoiceChip(label: const Text('Tüm çiftlikler'), selected: _ciftlik == null, onSelected: (_) => setState(() => _ciftlik = null)),
        for (final c in g.ciftlikler)
          ChoiceChip(label: Text(c), selected: _ciftlik == c, onSelected: (_) => setState(() => _ciftlik = c)),
      ]),
      const SizedBox(height: 10),
      if (son != null && onceki != null)
        GostergeIzgarasi(kartlar: [
          GostergeKarti(
              baslik: '${_ayAdi[son.$2 - 1]} ${son.$1}',
              deger: tl(tutar(_ay(son))),
              ikon: Icons.calendar_month,
              renk: sk == GgSekme.karZarar ? kzRenk(tutar(_ay(son))) : (sk == GgSekme.gider ? Renk.kirmizi : Renk.yesil),
              alt: '$ad, son ay'),
          GostergeKarti(
              baslik: 'Önceki aya göre',
              deger: _degisim(tutar(_ay(son)), tutar(_ay(onceki))),
              ikon: Icons.compare_arrows,
              alt: '${_ayAdi[onceki.$2 - 1]}: ${tl(tutar(_ay(onceki)))}'),
          GostergeKarti(
              baslik: 'Geçen yıl aynı ay',
              deger: gecenYilVar ? _degisim(tutar(_ay(son)), tutar(_ay(gecenYil))) : 'Veri yok',
              ikon: Icons.history,
              alt: gecenYilVar ? tl(tutar(_ay(gecenYil))) : 'Kaynak dosya ${aylar.first.$1} yılından başlıyor'),
          GostergeKarti(
              baslik: 'Aylık ortalama',
              deger: tl(aylar.isEmpty ? 0 : aylar.fold(0.0, (t, a) => t + tutar(_ay(a))) / aylar.length),
              ikon: Icons.functions,
              alt: '${aylar.length} ay'),
        ]),
      const SizedBox(height: 12),
      Panel(
        baslik: 'Aylara göre $ad (mn ₺)',
        child: VeriTablosu(
          ilkSutunGenislik: 120,
          basliklar: sk == GgSekme.karZarar
              ? const ['Ay', 'Gelir', 'Gider', 'Kâr / zarar', 'Önceki aya göre']
              : const ['Ay', 'Tutar', 'Önceki aya göre', 'Ortalamaya göre'],
          satirlar: [
            for (final (i, a) in aylar.indexed.toList().reversed)
              () {
                final v = tutar(_ay(a));
                final o = i > 0 ? tutar(_ay(aylar[i - 1])) : 0.0;
                final ort = aylar.fold(0.0, (t, x) => t + tutar(_ay(x))) / aylar.length;
                return sk == GgSekme.karZarar
                    ? ['${_ayAdi[a.$2 - 1]} ${a.$1}', _mn(g.gelirToplam(_ay(a))), _mn(g.giderToplam(_ay(a))), _isaretli(v), i > 0 ? _isaretli(v - o) : '—']
                    : ['${_ayAdi[a.$2 - 1]} ${a.$1}', _mn(v), i > 0 ? _degisim(v, o) : '—', _degisim(v, ort)];
              }(),
          ],
        ),
      ),
      if (son != null && onceki != null)
        Panel(
          baslik: '${_ayAdi[son.$2 - 1]} – ${_ayAdi[onceki.$2 - 1]} karşılaştırması (${sk == GgSekme.gider ? 'gider türü' : sk == GgSekme.gelir ? 'ürün' : 'çiftlik'}, mn ₺)',
          child: VeriTablosu(
            ilkSutunGenislik: 170,
            basliklar: [sk == GgSekme.gider ? 'Gider türü' : sk == GgSekme.gelir ? 'Ürün / hizmet' : 'Çiftlik', _ayKisa[onceki.$2 - 1], _ayKisa[son.$2 - 1], 'Fark', 'Değişim'],
            satirlar: kalemler(),
          ),
        ),
      if (_ciftlik == null && sk != GgSekme.karZarar)
        Panel(
          baslik: 'Çiftliklere göre (tüm dönem, mn ₺)',
          child: VeriTablosu(
            basliklar: const ['Çiftlik', 'Tutar', 'Pay'],
            satirlar: () {
              final m = {for (final c in g.ciftlikler) c: tutar((ciftlik: c, bas: null, bit: null))};
              final t = m.values.fold(0.0, (a, b) => a + b);
              final l = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              return [for (final e in l) [e.key, _mn(e.value), _pay(e.value, t)]];
            }(),
          ),
        ),
      if (yilTop.length > 1)
        Panel(
          baslik: 'Yıllara göre (mn ₺)',
          child: VeriTablosu(
            basliklar: const ['Yıl', 'Tutar', 'Ay sayısı'],
            satirlar: [for (final e in yilTop.entries) ['${e.key}', _isaretli(e.value), '${aylar.where((a) => a.$1 == e.key).length}']],
          ),
        ),
      if (widget.kontrol != null)
        Card(
          child: ListTile(
            leading: const Icon(Icons.fact_check_outlined, color: Renk.amber),
            title: const Text('Fatura kayıt kontrolü'),
            subtitle: const Text('2026 Fatura listesindeki hatalı / eksik kayıtlar ve düzeltme talebi'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: widget.kontrol!)),
          ),
        ),
      const Text('Değişim oranları KDV hariç tutarlar üzerinden hesaplanır. Geçen yıl karşılaştırması, kaynak dosyada önceki yılın verisi olduğunda gösterilir.',
          style: TextStyle(fontSize: 12, color: Renk.soluk)),
    ]);
  }
}
