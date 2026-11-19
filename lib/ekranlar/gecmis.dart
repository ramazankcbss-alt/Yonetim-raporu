import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/kategori.dart';
import '../veri/model.dart';
import 'bilesenler.dart';
import 'esk.dart' show tl;

/// Geçmiş Yıllar – Bilgi Bankası. Ana ekran iki alana ayrılır (Tarım,
/// Hayvancılık); her alan yıl → ay → konu (birim başlıkları altında) →
/// çiftlik sırasıyla açılır. Dersler ve tüm kayıtlarda arama ayrıca durur.
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

/// Ana alan: Tarım, Hayvancılık ya da (ikisine de girmeyenler) Genel.
const gecmisAnaAlanlar = ['Tarım', 'Hayvancılık', 'Genel'];
const _tarimK = ['tarım', 'tarim', 'ziraat', 'fidan', 'pancar', 'ekim', 'hasat', 'arazi', 'tarla', 'gübre',
  'sulama', 'tohum', 'toprak', 'mısır', 'buğday', 'arpa', 'yonca', 'zirai', 'dekar', 'ilaçlama', 'nadas',
  'kök/da', 'verim kg/da', 'patates', 'ayçiçe', 'nohut', 'pivot'];
const _hayvanK = ['hayvan', 'besi', 'buzağı', 'kesim', 'süt', 'doğum', 'sağmal', 'sağım', 'inek', 'düve',
  'dana', 'tosun', 'yem', 'rasyon', 'aşı', 'ölüm', 'ölen', 'gebe', 'tohumlama', 'sürü', 'koyun', 'mastit',
  'karkas', 'canlı ağırlık', 'baş', 'esk', 'veteriner'];

String gecmisAnaAlan(GecmisVeri x) {
  final b = gecmisBirimi(x);
  if (b == Birim.ziraat) return 'Tarım';
  if (b == Birim.hayvancilik) return 'Hayvancılık';
  final a = kucuk(x.alan);
  if (_tarimK.any(a.contains)) return 'Tarım';
  final t = kucuk('${x.konu} ${x.gosterge} ${x.birim}');
  final h = _hayvanK.any(t.contains), z = _tarimK.any(t.contains);
  if (h && !z) return 'Hayvancılık';
  if (z && !h) return 'Tarım';
  if (RegExp(r'hayvancılık|besi').hasMatch(a)) return 'Hayvancılık';
  return 'Genel';
}

const _aylar = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
String _ayAdi(GecmisVeri x) => x.ay.isEmpty || kucuk(x.ay) == 'yıllık' ? 'Yıl geneli' : x.ay;
int _aySira(String ay) {
  if (ay == 'Yıl geneli') return 0;
  final i = _aylar.indexWhere((a) => kucuk(a) == kucuk(ay));
  return i < 0 ? 99 : i + 1;
}
String _konuAdi(GecmisVeri x) => x.konu.isEmpty ? 'Genel' : x.konu;

IconData _anaIkon(String a) => switch (a) {
      'Tarım' => Icons.agriculture,
      'Hayvancılık' => Icons.pets,
      _ => Icons.more_horiz,
    };

/// Bir alt sayfayı açar; veri yenilendiğinde süzgeç yeniden uygulanır.
void _gecmisAc(BuildContext context, RaporVerisi ilk, String baslik, String yol,
    bool Function(GecmisVeri) suz, Widget Function(List<GecmisVeri>) govde) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ListenableBuilder(
      listenable: VeriDeposu.ben,
      builder: (context, _) {
        final k = _gostergeKayitlari(VeriDeposu.ben.veri ?? ilk).where(suz).toList();
        return Scaffold(
          appBar: AppBar(title: Text(baslik), actions: const [TabloGuncelleButonu()]),
          body: Column(children: [
            if (yol.isNotEmpty)
              Container(
                width: double.infinity,
                color: Renk.anaAcik,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(yol, style: const TextStyle(fontSize: 12.5, color: Renk.anaKoyu, fontWeight: FontWeight.w600)),
              ),
            Expanded(child: govde(k)),
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
            const Text('Alan → yıl → ay → konu → çiftlik sırasıyla ilerleyin.', style: TextStyle(fontSize: 12.5)),
          ]),
        ),
        const _GMenuBaslik('Alanlar'),
        for (final a in gecmisAnaAlanlar)
          if ((anaSay[a] ?? 0) > 0)
            _GMenuSatiri(
              ikon: _anaIkon(a),
              baslik: a == 'Genel' ? 'Genel (iki alana da girmeyen)' : a,
              alt: '${anaSay[a]} kayıt',
              ac: () => _gecmisAc(context, ilk, a, a, (x) => gecmisAnaAlan(x) == a,
                  (k) => _YilListesi(kayitlar: k, ana: a, ilk: ilk)),
            ),
        const _GMenuBaslik('Değerlendirme'),
        _GMenuSatiri(
          ikon: Icons.school_outlined,
          baslik: 'Dersler',
          alt: '${veri.dersler.length} ders: geçmişte ne oldu, ne öğrenildi',
          ac: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Dersler')),
                  body: _Dersler(dersler: (VeriDeposu.ben.veri ?? ilk).dersler)))),
        ),
        _GMenuSatiri(
          ikon: Icons.search,
          baslik: 'Tüm kayıtlarda ara',
          alt: 'Aradığınızı bulamazsanız kelimeyle arayın',
          ac: () => _gecmisAc(context, ilk, 'Tüm kayıtlar', '', (_) => true, (k) => _Gostergeler(kayitlar: k)),
        ),
      ],
    );
  }
}

/// 1) Alan içindeki yıllar.
class _YilListesi extends StatelessWidget {
  const _YilListesi({required this.kayitlar, required this.ana, required this.ilk});
  final List<GecmisVeri> kayitlar;
  final String ana;
  final RaporVerisi ilk;

  @override
  Widget build(BuildContext context) {
    final say = _say(kayitlar, (x) => x.yil);
    final no = {for (final x in kayitlar) x.yil: x.yilNo};
    final yillar = say.keys.toList()..sort((a, b) => no[b]!.compareTo(no[a]!) != 0 ? no[b]!.compareTo(no[a]!) : a.compareTo(b));
    return ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 24), children: [
      const _GMenuBaslik('Yıllar'),
      for (final y in yillar)
        _GMenuSatiri(
          ikon: Icons.event_outlined,
          baslik: y,
          alt: '${say[y]} kayıt',
          ac: () => _gecmisAc(context, ilk, y, '$ana › $y', (x) => gecmisAnaAlan(x) == ana && x.yil == y,
              (k) => _AyListesi(kayitlar: k, ana: ana, yil: y, ilk: ilk)),
        ),
    ]);
  }
}

/// 2) Yıl içindeki aylar.
class _AyListesi extends StatelessWidget {
  const _AyListesi({required this.kayitlar, required this.ana, required this.yil, required this.ilk});
  final List<GecmisVeri> kayitlar;
  final String ana, yil;
  final RaporVerisi ilk;

  @override
  Widget build(BuildContext context) {
    final say = _say(kayitlar, _ayAdi);
    final aylar = say.keys.toList()..sort((a, b) => _aySira(a).compareTo(_aySira(b)));
    return ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 24), children: [
      const _GMenuBaslik('Aylar'),
      for (final a in aylar)
        _GMenuSatiri(
          ikon: a == 'Yıl geneli' ? Icons.calendar_today_outlined : Icons.calendar_month_outlined,
          baslik: a,
          alt: '${say[a]} kayıt',
          ac: () => _gecmisAc(context, ilk, '$yil $a', '$ana › $yil › $a',
              (x) => gecmisAnaAlan(x) == ana && x.yil == yil && _ayAdi(x) == a,
              (k) => _KonuListesi(
                  kayitlar: k,
                  yol: '$ana › $yil › $a',
                  ilk: ilk,
                  suz: (x) => gecmisAnaAlan(x) == ana && x.yil == yil && _ayAdi(x) == a)),
        ),
    ]);
  }
}

/// 3) Ay içindeki konular, birimlerine göre başlıklar altında.
class _KonuListesi extends StatelessWidget {
  const _KonuListesi({required this.kayitlar, required this.yol, required this.ilk, required this.suz});
  final List<GecmisVeri> kayitlar;
  final String yol;
  final RaporVerisi ilk;
  final bool Function(GecmisVeri) suz;

  @override
  Widget build(BuildContext context) {
    final grup = <Birim, Map<String, List<GecmisVeri>>>{};
    for (final x in kayitlar) {
      grup.putIfAbsent(gecmisBirimi(x), () => {}).putIfAbsent(_konuAdi(x), () => []).add(x);
    }
    final birimler = grup.keys.toList()..sort((a, b) => a.index.compareTo(b.index));
    return ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 24), children: [
      for (final b in birimler) ...[
        _GMenuBaslik(birimAdlari[b]!),
        for (final e in (grup[b]!.entries.toList()..sort((p, q) => p.key.compareTo(q.key))))
          _GMenuSatiri(
            ikon: _birimIkon(b),
            baslik: e.key,
            alt: '${e.value.length} kayıt · ${{for (final x in e.value) alanKoku(x.alan)}.join(', ')}',
            ac: () => _gecmisAc(context, ilk, e.key, '$yol › ${e.key}',
                (x) => suz(x) && gecmisBirimi(x) == b && _konuAdi(x) == e.key, (k) => _CiftlikListesi(kayitlar: k)),
          ),
      ],
    ]);
  }
}

/// 4) Konunun çiftliklere göre değerleri.
class _CiftlikListesi extends StatelessWidget {
  const _CiftlikListesi({required this.kayitlar});
  final List<GecmisVeri> kayitlar;

  @override
  Widget build(BuildContext context) {
    final grup = <String, List<GecmisVeri>>{};
    for (final x in kayitlar) {
      grup.putIfAbsent(alanKoku(x.alan), () => []).add(x);
    }
    final ciftlikler = grup.keys.toList()..sort();
    return ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 24), children: [
      for (final c in ciftlikler) ...[
        BolumBasligi(c),
        Card(
          child: Column(children: [
            for (final x in (grup[c]!..sort((a, b) => a.gosterge.compareTo(b.gosterge))))
              ListTile(
                dense: true,
                title: Text(x.gosterge, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text([
                  if (x.alan != c) x.alan,
                  if (x.not.isNotEmpty) x.not,
                  if (x.kaynak.isNotEmpty) 'Kaynak: ${x.kaynak}',
                ].join(' · ')),
                trailing: Text(gecmisDeger(x),
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: x.birim == 'TL' && (x.sayi ?? 0) < 0 ? Renk.kirmizi : Renk.yazi)),
              ),
          ]),
        ),
      ],
    ]);
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

const _aylar = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
int _ayNo(String ay) {
  final i = _aylar.indexWhere((a) => ay.startsWith(a));
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
