import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/gecmis_sinif.dart';
import '../veri/kategori.dart';
import '../veri/model.dart';
import 'bilesenler.dart';
import 'gonder.dart';
import 'esk.dart' show tl;

export '../veri/gecmis_sinif.dart' show gecmisAnaAlan, gecmisAnaAlanlar;

/// Geçmiş Yıllar – Bilgi Bankası. Kayıtlar yıl, alan (Tarım / Hayvancılık),
/// ürün ve çiftlik bazında kademeli açılır; son kademede göstergeler ekim
/// alanı, verim, maliyet, gelir ve kâr/zarar gibi sınıflara ayrılır.
/// Dersler ve tüm kayıtlarda arama ayrıca durur.
class GecmisEkran extends StatelessWidget {
  const GecmisEkran({super.key, required this.veri});

  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VeriDeposu.ben,
      builder: (context, _) {
        final v = VeriDeposu.ben.veri ?? veri;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Geçmiş Yıllar'),
            actions: const [TabloGuncelleButonu()],
          ),
          body: v.gecmis.isEmpty && v.dersler.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: BilgiKutusu(
                      yazi: 'Geçmiş yıllar verisi henüz gelmedi. Bilgi '
                          'Bankası tablosunu okuyabilmek için Apps Script '
                          'güncel olmalı.'),
                )
              : _GecmisMenu(veri: v, ilk: veri),
        );
      },
    );
  }
}

List<GecmisVeri> _gostergeKayitlari(RaporVerisi v) =>
    v.gecmis.where((x) => x.konu != 'Hastalık kaydı').toList();

String _ayAdi(GecmisVeri x) => x.ay.isEmpty || kucuk(x.ay) == 'yıllık' ? 'Yıl geneli' : x.ay;

IconData _anaIkon(String a) => switch (a) {
      'Tarım' => Icons.agriculture,
      'Hayvancılık' => Icons.pets,
      _ => Icons.more_horiz,
    };

IconData _urunIkon(String u) => switch (u) {
      'Süt' => Icons.water_drop_outlined,
      'Besi, kesim ve et' => Icons.set_meal_outlined,
      'Damızlık, üreme ve buzağı' => Icons.child_friendly_outlined,
      'Yem ve girdiler' => Icons.inventory_2_outlined,
      'Sürü geneli' => Icons.pets,
      'Girdiler (gübre, yakıt)' => Icons.science_outlined,
      'Tüm ürünler (genel)' => Icons.agriculture,
      'Sap / saman' => Icons.grass,
      genelUrun => Icons.more_horiz,
      _ => Icons.eco_outlined,
    };

IconData _sinifIkon(String s) => switch (s) {
      'Ekim alanı ve arazi' => Icons.landscape_outlined,
      'Verim ve üretim' => Icons.trending_up,
      'Maliyet' => Icons.payments_outlined,
      'Gelir ve kâr/zarar' => Icons.account_balance_wallet_outlined,
      'Satış ve fiyat' => Icons.sell_outlined,
      'Hayvan varlığı' => Icons.pets,
      'Sürü hareketi ve kesim' => Icons.swap_horiz,
      'Üreme' => Icons.child_friendly_outlined,
      'Süt kalitesi' => Icons.science_outlined,
      'Sağlık' => Icons.medical_services_outlined,
      'Stok' => Icons.inventory_2_outlined,
      'Saha faaliyetleri' => Icons.engineering_outlined,
      'Altyapı, yatırım ve kapasite' => Icons.construction_outlined,
      'İşletme ve personel' => Icons.groups_outlined,
      _ => Icons.more_horiz,
    };

IconData _boyutIkon(GBoyut b, String deger) => switch (b) {
      GBoyut.yil => Icons.event_outlined,
      GBoyut.alan => _anaIkon(deger),
      GBoyut.urun => _urunIkon(deger),
      GBoyut.ciftlik => deger == ortakCiftlik ? Icons.hub_outlined : Icons.home_work_outlined,
    };

/// Kırılım sıraları.
const _yillaraGore = [GBoyut.yil, GBoyut.alan, GBoyut.urun, GBoyut.ciftlik];
const _urunlereGore = [GBoyut.alan, GBoyut.urun, GBoyut.yil, GBoyut.ciftlik];
const _ciftliklereGore = [GBoyut.ciftlik, GBoyut.yil, GBoyut.alan, GBoyut.urun];

/// Seçilmiş bir kademe: boyut ve değeri.
class _Secim1 {
  const _Secim1(this.boyut, this.deger);
  final GBoyut boyut;
  final String deger;
}

bool _uyar(GecmisVeri x, List<_Secim1> s) => s.every((e) => gBoyutDegeri(e.boyut, x) == e.deger);

/// Tek seçeneği kalan kademeleri kendiliğinden geçer (ör. tek yıl, tek çiftlik).
List<_Secim1> _coz(List<GecmisVeri> k, List<GBoyut> sira, List<_Secim1> secim) {
  final s = [...secim];
  while (true) {
    final sonraki = sira.where((b) => !s.any((e) => e.boyut == b)).toList();
    if (sonraki.isEmpty || k.isEmpty) return s;
    final b = sonraki.first;
    final degerler = {for (final x in k.where((x) => _uyar(x, s))) gBoyutDegeri(b, x)};
    if (degerler.length != 1) return s;
    s.add(_Secim1(b, degerler.single));
  }
}

String _yolYazi(String bas, List<_Secim1> s) => [bas, for (final e in s) e.deger].join(' › ');

/// Kayıtların sınıf özetini verir: "Ekim alanı ve arazi, Verim ve üretim, …".
String _sinifOzeti(Iterable<GecmisVeri> k) {
  final s = {for (final x in k) gecmisSinif(x)}.toList()..sort((a, b) => sinifSirasi(a).compareTo(sinifSirasi(b)));
  if (s.length <= 3) return s.join(', ');
  return '${s.take(3).join(', ')} +${s.length - 3}';
}

/// Bir kırılım sayfası açar; veri yenilendiğinde süzgeç yeniden uygulanır.
void _kirilimAc(BuildContext context, RaporVerisi ilk, String bas, List<GBoyut> sira, List<_Secim1> secim,
    {bool hepsi = false}) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ListenableBuilder(
      listenable: VeriDeposu.ben,
      builder: (context, _) {
        final tum = _gostergeKayitlari(VeriDeposu.ben.veri ?? ilk);
        final s = hepsi ? secim : _coz(tum, sira, secim);
        final k = tum.where((x) => _uyar(x, s)).toList();
        final yol = _yolYazi(bas, s);
        final sonraki = sira.where((b) => !s.any((e) => e.boyut == b)).toList();
        final sinifSayfasi = hepsi || sonraki.isEmpty;
        final baslik = s.isEmpty ? bas : s.last.deger;
        return Scaffold(
          appBar: AppBar(
              title: Text(sinifSayfasi && hepsi ? '$baslik – sınıflar' : baslik),
              actions: const [TabloGuncelleButonu()]),
          body: Column(children: [
            Container(
              width: double.infinity,
              color: Renk.anaAcik,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(yol, style: const TextStyle(fontSize: 12.5, color: Renk.anaKoyu, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: GonderAlani(
                konu: 'Geçmiş Yıllar – $yol',
                child: sinifSayfasi
                    ? _SinifListesi(kayitlar: k, sabit: {for (final e in s) e.boyut})
                    : _KirilimListesi(
                        kayitlar: k,
                        boyut: sonraki.first,
                        tumunuAc: () => _kirilimAc(context, ilk, bas, sira, s, hepsi: true),
                        ac: (d) => _kirilimAc(context, ilk, bas, sira, [...s, _Secim1(sonraki.first, d)]),
                      ),
              ),
            ),
          ]),
        );
      },
    ),
  ));
}

Map<String, int> _say(Iterable<GecmisVeri> k, String Function(GecmisVeri) f) {
  final m = <String, int>{};
  for (final x in k) {
    m.update(f(x), (n) => n + 1, ifAbsent: () => 1);
  }
  return m;
}

class _GecmisMenu extends StatelessWidget {
  const _GecmisMenu({required this.veri, required this.ilk});
  final RaporVerisi veri, ilk;

  @override
  Widget build(BuildContext context) {
    final k = _gostergeKayitlari(veri);
    final anaSay = _say(k, gecmisAnaAlan);
    final yillar = <int>{for (final x in k) ...kapsananYillar(x.yil)};
    final yilYazi = yillar.isEmpty
        ? ''
        : ' · ${yillar.reduce((a, b) => a < b ? a : b)}–${yillar.reduce((a, b) => a > b ? a : b)}';
    final urunSay = {for (final x in k) gecmisUrun(x)}.length;
    final ciftlikSay = {for (final x in k) gecmisCiftlik(x)}.length;
    final yilSay = {for (final x in k) gecmisYil(x)}.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Renk.anaAcik, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Bilgi Bankası', style: TextStyle(fontSize: 13, color: Renk.soluk)),
            Text('${k.length} kayıt$yilYazi', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text(
                'Yıl, ürün veya çiftlik bazında ilerleyin. Son kademede kayıtlar ekim alanı, '
                'verim, maliyet, gelir ve kâr/zarar gibi sınıflara ayrılır.',
                style: TextStyle(fontSize: 12.5)),
          ]),
        ),
        const _GMenuBaslik('Sınıflandırma'),
        _GMenuSatiri(
          ikon: Icons.event_note_outlined,
          baslik: 'Yıllara göre',
          alt: '$yilSay dönem · yıl → alan → ürün → çiftlik',
          ac: () => _kirilimAc(context, ilk, 'Yıllar', _yillaraGore, const []),
        ),
        _GMenuSatiri(
          ikon: Icons.eco_outlined,
          baslik: 'Ürünlere göre',
          alt: '$urunSay ürün · alan → ürün → yıl → çiftlik',
          ac: () => _kirilimAc(context, ilk, 'Ürünler', _urunlereGore, const []),
        ),
        _GMenuSatiri(
          ikon: Icons.home_work_outlined,
          baslik: 'Çiftliklere göre',
          alt: '$ciftlikSay çiftlik · çiftlik → yıl → alan → ürün',
          ac: () => _kirilimAc(context, ilk, 'Çiftlikler', _ciftliklereGore, const []),
        ),
        const _GMenuBaslik('Alanlar'),
        for (final a in gecmisAnaAlanlar)
          if ((anaSay[a] ?? 0) > 0)
            _GMenuSatiri(
              ikon: _anaIkon(a),
              baslik: a == 'Genel' ? 'Genel (iki alana da girmeyen)' : a,
              alt: '${anaSay[a]} kayıt · ürün → yıl → çiftlik',
              ac: () => _kirilimAc(context, ilk, 'Alanlar', _urunlereGore, [_Secim1(GBoyut.alan, a)]),
            ),
        const _GMenuBaslik('Değerlendirme'),
        _GMenuSatiri(
          ikon: Icons.school_outlined,
          baslik: 'Dersler',
          alt: '${veri.dersler.length} ders: geçmişte ne oldu, ne öğrenildi',
          ac: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Dersler')),
                  body: GonderAlani(
                      konu: 'Geçmiş Yıllar – Dersler', child: _Dersler(dersler: (VeriDeposu.ben.veri ?? ilk).dersler))))),
        ),
        _GMenuSatiri(
          ikon: Icons.search,
          baslik: 'Tüm kayıtlarda ara',
          alt: 'Aradığınızı bulamazsanız kelimeyle arayın',
          ac: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ListenableBuilder(
              listenable: VeriDeposu.ben,
              builder: (context, _) => Scaffold(
                appBar: AppBar(title: const Text('Tüm kayıtlar'), actions: const [TabloGuncelleButonu()]),
                body: GonderAlani(
                    konu: 'Geçmiş Yıllar – Tüm kayıtlar',
                    child: _Gostergeler(kayitlar: _gostergeKayitlari(VeriDeposu.ben.veri ?? ilk))),
              ),
            ),
          )),
        ),
      ],
    );
  }
}

/// Bir kademedeki seçenekler (yıllar, ürünler, çiftlikler…).
class _KirilimListesi extends StatelessWidget {
  const _KirilimListesi({required this.kayitlar, required this.boyut, required this.ac, required this.tumunuAc});
  final List<GecmisVeri> kayitlar;
  final GBoyut boyut;
  final ValueChanged<String> ac;
  final VoidCallback tumunuAc;

  @override
  Widget build(BuildContext context) {
    final grup = <String, List<GecmisVeri>>{};
    for (final x in kayitlar) {
      grup.putIfAbsent(gBoyutDegeri(boyut, x), () => []).add(x);
    }
    final anahtarlar = grup.keys.toList()..sort((a, b) => gBoyutKarsilastir(boyut, a, b));

    // Ürün kademesinde alan karışıksa Tarım / Hayvancılık başlıkları
    final alanli = boyut == GBoyut.urun && {for (final x in kayitlar) gecmisAnaAlan(x)}.length > 1;
    final satirlar = <Widget>[
      _GMenuSatiri(
        ikon: Icons.view_list_outlined,
        baslik: 'Tümünü sınıflara göre gör',
        alt: '${kayitlar.length} kayıt · ${_sinifOzeti(kayitlar)}',
        ac: tumunuAc,
      ),
      if (!alanli) _GMenuBaslik(gBoyutAdlari[boyut]!),
    ];
    String? oncekiAlan;
    for (final d in anahtarlar) {
      if (alanli) {
        final a = gecmisAnaAlan(grup[d]!.first);
        if (a != oncekiAlan) satirlar.add(_GMenuBaslik('$a ürünleri'));
        oncekiAlan = a;
      }
      satirlar.add(_GMenuSatiri(
        ikon: _boyutIkon(boyut, d),
        baslik: d,
        alt: '${grup[d]!.length} kayıt · ${_sinifOzeti(grup[d]!)}',
        ac: () => ac(d),
      ));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 24), children: satirlar);
  }
}

/// Son kademe: kayıtlar sınıflara (ekim alanı, verim, maliyet…) ayrılır.
class _SinifListesi extends StatefulWidget {
  const _SinifListesi({required this.kayitlar, required this.sabit});
  final List<GecmisVeri> kayitlar;

  /// Yolda zaten seçilmiş boyutlar; satırlarda tekrar yazılmaz.
  final Set<GBoyut> sabit;

  @override
  State<_SinifListesi> createState() => _SinifListesiState();
}

class _SinifListesiState extends State<_SinifListesi> {
  String? _sinif;

  @override
  Widget build(BuildContext context) {
    final sinifSay = _say(widget.kayitlar, gecmisSinif);
    final siniflar = sinifSay.keys.toList()..sort((a, b) => sinifSirasi(a).compareTo(sinifSirasi(b)));
    final secili = sinifSay.containsKey(_sinif) ? _sinif : null;
    final k = secili == null ? widget.kayitlar : widget.kayitlar.where((x) => gecmisSinif(x) == secili).toList();

    // Sınıf → gösterge (+ çiftlik / ürün / yıl ayrımı) grupları
    final grup = <String, Map<String, List<GecmisVeri>>>{};
    for (final x in k) {
      final ek = [
        if (!widget.sabit.contains(GBoyut.ciftlik)) x.alan,
        if (!widget.sabit.contains(GBoyut.urun)) gecmisUrun(x),
      ].join('|');
      grup.putIfAbsent(gecmisSinif(x), () => {}).putIfAbsent('${x.gosterge}|$ek', () => []).add(x);
    }
    final satirlar = <Widget>[];
    for (final s in siniflar.where(grup.containsKey)) {
      satirlar.add(Padding(
        padding: EdgeInsets.fromLTRB(4, satirlar.isEmpty ? 4 : 16, 4, 6),
        child: Row(children: [
          Icon(_sinifIkon(s), size: 18, color: Renk.anaKoyu),
          const SizedBox(width: 6),
          Expanded(
            child: Text(s.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w700, color: Renk.anaKoyu, letterSpacing: .5)),
          ),
          Text('${sinifSay[s]} kayıt', style: const TextStyle(fontSize: 12, color: Renk.soluk)),
        ]),
      ));
      final g = grup[s]!;
      final anahtarlar = g.keys.toList()..sort();
      for (final a in anahtarlar) {
        final l = g[a]!
          ..sort((p, q) {
            final c = q.yilNo.compareTo(p.yilNo);
            return c != 0 ? c : _ayNo(q.ay).compareTo(_ayNo(p.ay));
          });
        satirlar.add(_GostergeKarti(kayitlar: l, sabit: widget.sabit));
      }
    }

    return Column(children: [
      if (siniflar.length > 1)
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            children: [
              _BirimCip(
                  etiket: 'Tüm sınıflar (${widget.kayitlar.length})',
                  ikon: Icons.apps,
                  secili: secili == null,
                  sec: () => setState(() => _sinif = null)),
              for (final s in siniflar)
                _BirimCip(
                  etiket: '$s (${sinifSay[s]})',
                  ikon: _sinifIkon(s),
                  secili: secili == s,
                  sec: () => setState(() => _sinif = secili == s ? null : s),
                ),
            ],
          ),
        ),
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(12, 6, 12, 24), children: satirlar),
      ),
    ]);
  }
}

/// Bir göstergenin kayıtları: tek kayıtsa düz satır, birden çoksa açılır kart.
class _GostergeKarti extends StatelessWidget {
  const _GostergeKarti({required this.kayitlar, required this.sabit});
  final List<GecmisVeri> kayitlar;
  final Set<GBoyut> sabit;

  /// Yolda seçilmemiş bilgiler: yıl, ay, çiftlik, ürün.
  String _baglam(GecmisVeri x, {bool ciftlikUrun = true}) => [
        if (!sabit.contains(GBoyut.yil)) gecmisYil(x),
        if (_ayAdi(x) != 'Yıl geneli') _ayAdi(x),
        if (ciftlikUrun && !sabit.contains(GBoyut.ciftlik)) x.alan,
        if (ciftlikUrun && !sabit.contains(GBoyut.urun) && gecmisUrun(x) != genelUrun) gecmisUrun(x),
      ].join(' · ');

  static bool _metinDeger(GecmisVeri x) => x.sayi == null && x.deger.length > 14;

  Widget _deger(GecmisVeri x, {FontWeight w = FontWeight.w800}) => Text(gecmisDeger(x),
      style: TextStyle(fontWeight: w, color: x.birim == 'TL' && (x.sayi ?? 0) < 0 ? Renk.kirmizi : Renk.yazi));

  @override
  Widget build(BuildContext context) {
    final ilk = kayitlar.first;
    final altBilgi = [ilk.not, if (ilk.kaynak.isNotEmpty) 'Kaynak: ${ilk.kaynak}'].where((e) => e.isNotEmpty);
    if (kayitlar.length == 1) {
      final b = _baglam(ilk);
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(_metinDeger(ilk) ? ilk.deger : ilk.gosterge, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text([if (b.isNotEmpty) b, ...altBilgi].join('\n'), style: const TextStyle(fontSize: 12)),
          trailing: _metinDeger(ilk) ? null : _deger(ilk),
        ),
      );
    }
    final b = _baglam(ilk);
    final ozet = _metinDeger(ilk) ? '' : 'Son: ${b.isEmpty ? '' : '$b · '}${gecmisDeger(ilk)} · ';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(ilk.gosterge, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text([
          '$ozet${kayitlar.length} kayıt',
          if (!sabit.contains(GBoyut.ciftlik)) ilk.alan,
        ].join(' · ')),
        children: [
          for (final x in kayitlar)
            ListTile(
              dense: true,
              title: Text(_metinDeger(x)
                  ? x.deger
                  : (_baglam(x, ciftlikUrun: false).isEmpty ? 'Yıl geneli' : _baglam(x, ciftlikUrun: false))),
              trailing: _metinDeger(x) ? null : _deger(x, w: FontWeight.w600),
              subtitle: Text(
                  [
                    if (_metinDeger(x)) _baglam(x, ciftlikUrun: false),
                    x.not,
                    if (x.kaynak.isNotEmpty) 'Kaynak: ${x.kaynak}',
                  ].where((e) => e.isNotEmpty).join('\n'),
                  style: const TextStyle(fontSize: 11)),
            ),
        ],
      ),
    );
  }
}

class _GMenuBaslik extends StatelessWidget {
  const _GMenuBaslik(this.yazi);
  final String yazi;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Text(yazi.toUpperCase(),
            style: const TextStyle(
                fontSize: 12.5,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
                color: Renk.soluk)),
      );
}

class _GMenuSatiri extends StatelessWidget {
  const _GMenuSatiri(
      {required this.ikon, required this.baslik, required this.alt, required this.ac});
  final IconData ikon;
  final String baslik, alt;
  final VoidCallback ac;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
              backgroundColor: Renk.anaAcik,
              child: Icon(ikon, color: Renk.ana)),
          title: Text(baslik, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(alt, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right),
          onTap: ac,
        ),
      );
}

String gecmisDeger(GecmisVeri x) {
  final s = x.sayi;
  if (s == null) return x.deger;
  if (x.birim == 'TL' && s.abs() >= 10000) return tl(s);
  final o = s == s.roundToDouble() ? 0 : 1;
  final b = x.birim.isEmpty ? '' : ' ${x.birim}';
  return x.birim == '%' ? '%${sayi(s, ondalik: o)}' : '${sayi(s, ondalik: o)}$b';
}

/// Bir yıl alanının kapsadığı yıllar: "2025" → {2025}, "2021-2025" → 2021…2025,
/// "2023-2024" → {2023, 2024}.
Set<int> kapsananYillar(String yil) {
  final y = RegExp(r'20\d\d').allMatches(yil).map((m) => int.parse(m.group(0)!)).toList();
  if (y.isEmpty) return {};
  final a = y.reduce((p, q) => p < q ? p : q), b = y.reduce((p, q) => p > q ? p : q);
  return {for (var i = a; i <= b; i++) i};
}

/// Yıl seçimi: "Tüm yıllar" + yeniden eskiye yıllar, her birinde kayıt sayısı.
class _YilSatiri extends StatelessWidget {
  const _YilSatiri({required this.yillar, required this.secili, required this.sec});
  final Map<int, int> yillar;
  final int? secili;
  final ValueChanged<int?> sec;

  @override
  Widget build(BuildContext context) {
    final l = yillar.keys.toList()..sort((a, b) => b.compareTo(a));
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        children: [
          _BirimCip(etiket: 'Tüm yıllar', ikon: Icons.calendar_month_outlined, secili: secili == null, sec: () => sec(null)),
          for (final y in l)
            _BirimCip(
                etiket: '$y (${yillar[y]})',
                ikon: Icons.event_outlined,
                secili: secili == y,
                sec: () => sec(secili == y ? null : y)),
        ],
      ),
    );
  }
}

class _Gostergeler extends StatefulWidget {
  const _Gostergeler({required this.kayitlar, this.birimCipleri = true});
  final List<GecmisVeri> kayitlar;

  /// Birim sayfasında birim seçimi gizlenir (kayıtlar zaten tek birim).
  final bool birimCipleri;

  @override
  State<_Gostergeler> createState() => _GostergelerState();
}

class _GostergelerState extends State<_Gostergeler> {
  static const _tumu = 'Tümü';
  Birim? _birim;
  int? _yil;
  String _alan = _tumu; // '@Kök' = işletmenin tamamı, aksi hâlde tam çiftlik adı
  String _konu = _tumu;
  String _ara = '';

  bool _alanUyar(GecmisVeri x, String alan) =>
      alan == _tumu || (alan.startsWith('@') ? alanKoku(x.alan) == alan.substring(1) : x.alan == alan);

  @override
  Widget build(BuildContext context) {
    final yilSay = <int, int>{};
    for (final x in widget.kayitlar) {
      for (final y in kapsananYillar(x.yil)) {
        yilSay.update(y, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final yil = yilSay.containsKey(_yil) ? _yil : null;
    final k = yil == null
        ? widget.kayitlar
        : widget.kayitlar.where((x) => kapsananYillar(x.yil).contains(yil)).toList();
    final birimSay = <Birim, int>{};
    for (final x in k) {
      birimSay.update(gecmisBirimi(x), (n) => n + 1, ifAbsent: () => 1);
    }
    final birimler = birimSay.keys.toList()..sort((a, b) => a.index.compareTo(b.index));

    // 1) Birim
    final b1 = k.where((x) => _birim == null || gecmisBirimi(x) == _birim).toList();

    // 2) Çiftlik: ana işletme altında alt bölümler
    final kokler = <String, Set<String>>{};
    for (final x in b1) {
      kokler.putIfAbsent(alanKoku(x.alan), () => {}).add(x.alan);
    }
    final ciftlikler = <_Oge>[const _Oge(_tumu, _tumu)];
    for (final kok in kokler.keys.toList()..sort()) {
      ciftlikler.add(_Oge('@$kok', kok));
      final alt = kokler[kok]!.toList()..sort();
      if (alt.length > 1) {
        for (final a in alt) {
          ciftlikler.add(_Oge(a, a, girinti: true));
        }
      }
    }
    final alan = ciftlikler.any((o) => o.deger == _alan) ? _alan : _tumu;
    final b2 = b1.where((x) => _alanUyar(x, alan)).toList();

    // 3) Konu: birim seçilmemişse birim başlıkları altında
    final konuSet = {for (final x in b2) x.konu}.where((e) => e.isNotEmpty).toList()..sort();
    final konular = <_Oge>[const _Oge(_tumu, _tumu)];
    if (_birim == null && widget.birimCipleri) {
      for (final b in Birim.values) {
        final grup = konuSet.where((c) => konuBirimi(c) == b).toList();
        if (grup.isEmpty) continue;
        konular.add(_Oge('#${b.name}', birimAdlari[b]!, baslik: true));
        for (final c in grup) {
          konular.add(_Oge(c, c, girinti: true));
        }
      }
    } else {
      konular.addAll([for (final c in konuSet) _Oge(c, c)]);
    }
    final konu = konular.any((o) => o.deger == _konu && !o.baslik) ? _konu : _tumu;

    final ara = kucuk(_ara);
    final suz = b2.where((x) =>
        (konu == _tumu || x.konu == konu) &&
        (ara.isEmpty || kucuk('${x.gosterge} ${x.alan} ${x.konu} ${x.not} ${x.yil}').contains(ara)));
    final gruplar = <String, List<GecmisVeri>>{};
    final grupBirim = <String, Birim>{};
    for (final x in suz) {
      final b = gecmisBirimi(x);
      final anahtar = '${b.index}|${x.alan}|${x.gosterge}';
      grupBirim[anahtar] = b;
      gruplar.putIfAbsent(anahtar, () => []).add(x);
    }
    final anahtarlar = gruplar.keys.toList()..sort();

    // Liste: birim seçilmemişse her birimin önüne başlık
    final satirlar = <Object>[];
    Birim? onceki;
    for (final a in anahtarlar) {
      final b = grupBirim[a]!;
      if (_birim == null && widget.birimCipleri && b != onceki) satirlar.add(b);
      onceki = b;
      satirlar.add(a);
    }

    return Column(children: [
      _YilSatiri(yillar: yilSay, secili: yil, sec: (y) => setState(() => _yil = y)),
      if (widget.birimCipleri) SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          children: [
            _BirimCip(etiket: 'Tümü (${k.length})', ikon: Icons.apps, secili: _birim == null,
                sec: () => setState(() => _birim = null)),
            for (final b in birimler)
              _BirimCip(
                etiket: '${birimAdlari[b]} (${birimSay[b]})',
                ikon: _birimIkon(b),
                secili: _birim == b,
                sec: () => setState(() => _birim = _birim == b ? null : b),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Row(children: [
          Expanded(child: _Secim(deger: alan, liste: ciftlikler, etiket: 'Çiftlik', sec: (s) => setState(() => _alan = s))),
          const SizedBox(width: 8),
          Expanded(child: _Secim(deger: konu, liste: konular, etiket: 'Konu', sec: (s) => setState(() => _konu = s))),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          decoration: const InputDecoration(
              isDense: true, prefixIcon: Icon(Icons.search), hintText: 'Ara: süt verimi, pancar, ölüm…'),
          onChanged: (s) => setState(() => _ara = s.trim()),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('${anahtarlar.length} gösterge · ${suz.length} kayıt',
              style: const TextStyle(color: Renk.soluk, fontSize: 12)),
        ),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          itemCount: satirlar.length,
          itemBuilder: (_, i) {
            final s = satirlar[i];
            if (s is Birim) {
              return Padding(
                padding: EdgeInsets.fromLTRB(4, i == 0 ? 4 : 14, 4, 6),
                child: Row(children: [
                  Icon(_birimIkon(s), size: 18, color: Renk.anaKoyu),
                  const SizedBox(width: 6),
                  Text(birimAdlari[s]!.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Renk.anaKoyu, letterSpacing: .5)),
                ]),
              );
            }
            final l = gruplar[s as String]!
              ..sort((a, b) {
                final c = b.yilNo.compareTo(a.yilNo);
                return c != 0 ? c : _ayNo(b.ay).compareTo(_ayNo(a.ay));
              });
            final ilk = l.first;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                title: Text(ilk.gosterge, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${ilk.alan} · ${ilk.yil}${ilk.ay.isEmpty || ilk.ay == 'Yıllık' ? '' : ' ${ilk.ay}'}: ${gecmisDeger(ilk)}'
                    '${l.length > 1 ? ' · ${l.length} kayıt' : ''}'),
                children: [
                  for (final x in l)
                    ListTile(
                      dense: true,
                      title: Text('${x.yil}${x.ay.isEmpty || x.ay == 'Yıllık' ? '' : ' · ${x.ay}'}'),
                      trailing: Text(gecmisDeger(x),
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: x.birim == 'TL' && (x.sayi ?? 0) < 0 ? Renk.kirmizi : Renk.yazi)),
                      subtitle: Text([x.not, x.kaynak].where((e) => e.isNotEmpty).join('\n'),
                          style: const TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ]);
  }
}

IconData _birimIkon(Birim b) => switch (b) {
      Birim.ziraat => Icons.agriculture,
      Birim.hayvancilik => Icons.pets,
      Birim.mali => Icons.payments_outlined,
      Birim.isletme => Icons.build_outlined,
      Birim.diger => Icons.more_horiz,
    };

class _BirimCip extends StatelessWidget {
  const _BirimCip({required this.etiket, required this.ikon, required this.secili, required this.sec});
  final String etiket;
  final IconData ikon;
  final bool secili;
  final VoidCallback sec;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          avatar: Icon(ikon, size: 16),
          label: Text(etiket),
          selected: secili,
          showCheckmark: false,
          onSelected: (_) => sec(),
        ),
      );
}

const _ayAdlari = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
int _ayNo(String ay) {
  final i = _ayAdlari.indexWhere((a) => ay.startsWith(a));
  return i < 0 ? 13 : i;
}

/// Açılır listedeki bir satır: değer, görünen ad, başlık mı, girintili mi.
class _Oge {
  const _Oge(this.deger, this.ad, {this.baslik = false, this.girinti = false});
  final String deger, ad;
  final bool baslik, girinti;
}

class _Secim extends StatelessWidget {
  const _Secim({required this.deger, required this.liste, required this.etiket, required this.sec});
  final String deger, etiket;
  final List<_Oge> liste;
  final ValueChanged<String> sec;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        key: ValueKey('$etiket|$deger|${liste.length}'),
        initialValue: deger,
        isExpanded: true,
        menuMaxHeight: 520,
        decoration: InputDecoration(labelText: etiket, isDense: true),
        selectedItemBuilder: (_) => [
          for (final o in liste) Text(o.ad, overflow: TextOverflow.ellipsis),
        ],
        items: [
          for (final o in liste)
            DropdownMenuItem(
              value: o.deger,
              enabled: !o.baslik,
              child: o.baslik
                  ? Text(o.ad.toUpperCase(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Renk.anaKoyu))
                  : Padding(
                      padding: EdgeInsets.only(left: o.girinti ? 16 : 0),
                      child: Text(o.ad,
                          overflow: TextOverflow.ellipsis,
                          style: o.girinti ? const TextStyle(fontSize: 14) : const TextStyle(fontWeight: FontWeight.w600)),
                    ),
            ),
        ],
        onChanged: (s) => sec(s ?? 'Tümü'),
      );
}

class _Dersler extends StatefulWidget {
  const _Dersler({required this.dersler});
  final List<Ders> dersler;

  @override
  State<_Dersler> createState() => _DerslerState();
}

class _DerslerState extends State<_Dersler> {
  int? _yil;

  @override
  Widget build(BuildContext context) {
    final tum = widget.dersler;
    if (tum.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16), child: BilgiKutusu(yazi: 'Henüz ders kaydı yok.'));
    }
    final yilSay = <int, int>{};
    for (final d in tum) {
      for (final y in kapsananYillar(d.yil)) {
        yilSay.update(y, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final yil = yilSay.containsKey(_yil) ? _yil : null;
    final dersler = yil == null ? tum : tum.where((d) => kapsananYillar(d.yil).contains(yil)).toList();
    return Column(children: [
      _YilSatiri(yillar: yilSay, secili: yil, sec: (y) => setState(() => _yil = y)),
      Expanded(child: _liste(dersler)),
    ]);
  }

  Widget _liste(List<Ders> dersler) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        for (final d in dersler)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${d.yil} · ${d.alan}${d.konu.isEmpty ? '' : ' · ${d.konu}'}',
                    style: const TextStyle(color: Renk.soluk, fontSize: 12)),
                const SizedBox(height: 4),
                Text(d.neOldu),
                if (d.sonuc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('→ ${d.sonuc}', style: const TextStyle(fontWeight: FontWeight.w600, color: Renk.anaKoyu)),
                ],
                if (d.kaynak.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Kaynak: ${d.kaynak}', style: const TextStyle(fontSize: 11, color: Renk.soluk)),
                  ),
              ]),
            ),
          ),
      ],
    );
  }
}
