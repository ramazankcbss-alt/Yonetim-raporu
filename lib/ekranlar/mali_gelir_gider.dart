import 'package:flutter/material.dart';

import '../bicim.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'bilesenler.dart';
import 'esk.dart' show tl, kzRenk;

const _ayAdi = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
String _ayYaz((int, int) a) => '${_ayAdi[a.$2 - 1]} ${a.$1}';
String _pay(double v, double t) => t == 0 ? '—' : '%${sayi(v / t * 100, ondalik: 1)}';
String _mn(double v) => sayi(v / 1e6, ondalik: 2);

enum GgSekme { gider, gelir, karZarar }

/// Mali Raporlar › Gider / Gelir / Kâr-Zarar sekmesi (çiftlik ve ay seçimiyle).
class GelirGiderSekmesi extends StatefulWidget {
  const GelirGiderSekmesi({super.key, required this.veri, required this.sekme});
  final GelirGider veri;
  final GgSekme sekme;
  @override
  State<GelirGiderSekmesi> createState() => _GelirGiderSekmesiState();
}

class _GelirGiderSekmesiState extends State<GelirGiderSekmesi> {
  String? _ciftlik;
  (int, int)? _ay;

  @override
  Widget build(BuildContext context) {
    final g = widget.veri;
    if (g.bos) {
      return const Padding(
          padding: EdgeInsets.all(16),
          child: BilgiKutusu(yazi: 'Gider ve gelir tablosu verisi henüz yok. Mali Raporlar klasöründeki mali_veri.json güncellenmeli.'));
    }
    final s = (ciftlik: _ciftlik, yil: _ay?.$1, ay: _ay?.$2);
    final govde = switch (widget.sekme) {
      GgSekme.gider => _gider(g, s),
      GgSekme.gelir => _gelir(g, s),
      GgSekme.karZarar => _karZarar(g, s),
    };
    return ListView(padding: const EdgeInsets.all(16), children: [
      Wrap(spacing: 6, runSpacing: 4, children: [
        ChoiceChip(label: const Text('Tüm çiftlikler'), selected: _ciftlik == null, onSelected: (_) => setState(() => _ciftlik = null)),
        for (final c in g.ciftlikler)
          ChoiceChip(label: Text(c), selected: _ciftlik == c, onSelected: (_) => setState(() => _ciftlik = c)),
      ]),
      const SizedBox(height: 6),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(label: Text(g.donem), selected: _ay == null, onSelected: (_) => setState(() => _ay = null)),
          ),
          for (final a in g.aylar.reversed)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(label: Text(_ayYaz(a)), selected: _ay == a, onSelected: (_) => setState(() => _ay = a)),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      ...govde,
      const SizedBox(height: 8),
      Text(
          'Kaynak: “${widget.sekme == GgSekme.gelir ? g.kaynakGelir : widget.sekme == GgSekme.gider ? g.kaynakGider : '${g.kaynakGelir}” ve “${g.kaynakGider}'}” '
          '(Drive › Mali Raporlar). Tutarlar KDV hariçtir. KVKK: satıcı ve müşteri adları, belge numaraları aktarılmaz.',
          style: const TextStyle(fontSize: 12, color: Renk.soluk, fontStyle: FontStyle.italic)),
    ]);
  }

  String get _baslik => '${_ciftlik ?? 'Tüm çiftlikler'} · ${_ay == null ? widget.veri.donem : _ayYaz(_ay!)}';

  List<Widget> _gider(GelirGider g, GgSuzgec s) {
    final l = g.giderler(s);
    final top = l.fold(0.0, (t, x) => t + x.net);
    final brut = l.fold(0.0, (t, x) => t + x.brut);
    final canli = l.where((x) => x.kategori == kCanliHayvanAlimi).fold(0.0, (t, x) => t + x.net);
    final kat = GelirGider.grupla(l, (x) => x.kategori, (x) => x.net);
    return [
      GostergeIzgarasi(kartlar: [
        GostergeKarti(baslik: 'Toplam gider (KDV hariç)', deger: tl(top), ikon: Icons.receipt_long, renk: Renk.kirmizi, alt: _baslik),
        GostergeKarti(baslik: 'KDV dahil', deger: tl(brut), ikon: Icons.request_quote_outlined, renk: Renk.soluk),
        GostergeKarti(
            baslik: 'Canlı hayvan alımı hariç', deger: tl(top - canli), ikon: Icons.filter_alt_outlined, alt: 'Canlı hayvan alımı ${tl(canli)}'),
        if (kat.isNotEmpty)
          GostergeKarti(baslik: 'En büyük kalem', deger: kat.first.key, ikon: Icons.leaderboard_outlined, alt: '${tl(kat.first.value)} · ${_pay(kat.first.value, top)}'),
      ]),
      const SizedBox(height: 12),
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
      if (_ay == null) _aylik(g, s, gider: true),
      Panel(
        baslik: 'Tedarikçi grubuna göre',
        child: VeriTablosu(
          basliklar: const ['Grup', 'Tutar (mn ₺)', 'Pay'],
          satirlar: [for (final e in GelirGider.grupla(l, (x) => x.hesap, (x) => x.net)) [e.key, _mn(e.value), _pay(e.value, top)]],
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
    // Ürün + birim bazında miktar ve tutar
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
        GostergeKarti(baslik: 'Toplam gelir (KDV hariç)', deger: tl(top), ikon: Icons.payments_outlined, renk: Renk.yesil, alt: _baslik),
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
      if (_ay == null) _aylik(g, s, gider: false),
      Panel(
        baslik: 'Müşteri grubuna göre',
        child: VeriTablosu(
          basliklar: const ['Grup', 'Tutar (mn ₺)', 'Pay'],
          satirlar: [for (final e in GelirGider.grupla(l, (x) => x.hesap, (x) => x.net)) [e.key, _mn(e.value), _pay(e.value, top)]],
        ),
      ),
      if (g.iadeAdet > 0)
        Text('İade / düzeltme faturaları (${g.iadeAdet} kalem, ${tl(g.iadeTutar)}) gelirden düşülmüştür.',
            style: const TextStyle(fontSize: 12, color: Renk.soluk)),
    ];
  }

  Widget _aylik(GelirGider g, GgSuzgec s, {required bool gider}) {
    final aylar = g.aylar;
    double t((int, int) a) {
      final x = (ciftlik: s.ciftlik, yil: a.$1, ay: a.$2);
      return gider ? g.giderToplam(x) : g.gelirToplam(x);
    }

    final top = aylar.fold(0.0, (a, b) => a + t(b));
    return Panel(
      baslik: 'Aylara göre',
      child: VeriTablosu(
        ilkSutunGenislik: 120,
        basliklar: const ['Ay', 'Tutar (mn ₺)', 'Pay'],
        satirlar: [
          for (final a in aylar) [_ayYaz(a), _mn(t(a)), _pay(t(a), top)],
          ['Toplam', _mn(top), '%100'],
        ],
        vurguluSonSatir: true,
      ),
    );
  }

  List<Widget> _karZarar(GelirGider g, GgSuzgec s) {
    final gelir = g.gelirToplam(s), gider = g.giderToplam(s), canliHaric = g.giderToplam(s, canliHaric: true);
    final fark = gelir - gider, fark2 = gelir - canliHaric;
    String f(double v) => '${v >= 0 ? '' : '−'}${_mn(v.abs())}';
    return [
      const BilgiKutusu(
          uyari: true,
          yazi: 'Bu sonuç fatura bazlıdır: satış faturaları (gelir) ile gelen faturalar (gider) arasındaki farktır. Personel ücretleri, '
              'amortisman, faturasız giderler ve stok değişimi dahil değildir; muhasebe gelir tablosundaki dönem kârının yerine geçmez. '
              'Canlı hayvan alımı yatırım niteliğinde olduğundan ayrıca hariç tutularak da gösterilir.'),
      const SizedBox(height: 10),
      GostergeIzgarasi(kartlar: [
        GostergeKarti(baslik: 'Gelir', deger: tl(gelir), ikon: Icons.payments_outlined, renk: Renk.yesil, alt: _baslik),
        GostergeKarti(baslik: 'Gider', deger: tl(gider), ikon: Icons.receipt_long, renk: Renk.kirmizi),
        GostergeKarti(baslik: fark >= 0 ? 'Kâr (fatura bazlı)' : 'Zarar (fatura bazlı)', deger: tl(fark), ikon: Icons.balance, renk: kzRenk(fark)),
        GostergeKarti(
            baslik: 'Canlı hayvan alımı hariç', deger: tl(fark2), ikon: Icons.filter_alt_outlined, renk: kzRenk(fark2), alt: 'Gider ${tl(canliHaric)}'),
      ]),
      const SizedBox(height: 12),
      if (_ay == null)
        Panel(
          baslik: 'Aylara göre (mn ₺)',
          child: VeriTablosu(
            ilkSutunGenislik: 120,
            basliklar: const ['Ay', 'Gelir', 'Gider', 'Kâr / zarar', 'Canlı hayvan hariç'],
            satirlar: [
              for (final a in g.aylar)
                () {
                  final x = (ciftlik: s.ciftlik, yil: a.$1, ay: a.$2);
                  final ge = g.gelirToplam(x), gi = g.giderToplam(x), gc = g.giderToplam(x, canliHaric: true);
                  return [_ayYaz(a), _mn(ge), _mn(gi), f(ge - gi), f(ge - gc)];
                }(),
              ['Toplam', _mn(gelir), _mn(gider), f(fark), f(fark2)],
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
                  final x = (ciftlik: c, yil: s.yil, ay: s.ay);
                  final ge = g.gelirToplam(x), gi = g.giderToplam(x), gc = g.giderToplam(x, canliHaric: true);
                  return [c, _mn(ge), _mn(gi), f(ge - gi), f(ge - gc)];
                }(),
              ['Toplam', _mn(gelir), _mn(gider), f(fark), f(fark2)],
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
