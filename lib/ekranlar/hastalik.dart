import 'package:flutter/material.dart';

import '../tema.dart';
import '../veri/hastalik.dart';
import '../veri/model.dart';
import 'gonder.dart';

const _sonucRenk = {
  'Ölüm': Renk.kirmizi,
  'Tedavi (kalım)': Renk.yesil,
  'Kuru': Renk.mavi,
  'Kesim': Renk.turuncu,
  'İmha': Color(0xFF7C3AED),
};
String _kisa(String s) => s == 'Tedavi (kalım)' ? 'Kalım' : s;

/// Hastalık dağılımı: aylara göre, çiftlik ve cins bazında; sonuç
/// (ölüm / kalım / kuru / kesim / imha) ve önleme tedbirleri.
class HastalikEkran extends StatefulWidget {
  const HastalikEkran({super.key, required this.veri});
  final RaporVerisi veri;

  @override
  State<HastalikEkran> createState() => _HastalikEkranState();
}

class _HastalikEkranState extends State<HastalikEkran> {
  List<HastalikKaydi>? _hepsi;
  int? _yil;
  String? _ciftlik, _cins, _sonuc;

  @override
  void initState() {
    super.initState();
    hastalikYukle(widget.veri.gecmis).then((l) {
      if (!mounted) return;
      // Varsayılan: tüm yıllar; liste yıl → ay olarak gruplanır.
      setState(() => _hepsi = l);
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = _hepsi;
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hastalık Dağılımı'),
          bottom: const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
            Tab(text: 'Günlük'),
            Tab(text: 'Haftalık'),
            Tab(text: 'Aylık'),
            Tab(text: 'Yıllık'),
            Tab(text: 'Hastalıklar'),
            Tab(text: 'Tedbirler'),
          ]),
        ),
        body: h == null
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                _filtreler(h),
                Expanded(
                  child: TabBarView(children: [
                    GonderAlani(konu: 'Hastalık Dağılımı – Günlük', child: _Donemsel(k: _suz(h), haftalik: false)),
                    GonderAlani(konu: 'Hastalık Dağılımı – Haftalık', child: _Donemsel(k: _suz(h), haftalik: true)),
                    GonderAlani(konu: 'Hastalık Dağılımı – Aylık', child: _Aylik(k: _suz(h))),
                    GonderAlani(konu: 'Hastalık Dağılımı – Yıllık', child: _Yillik(k: _suz(h))),
                    GonderAlani(konu: 'Hastalık Dağılımı – Hastalıklar', child: _Hastaliklar(k: _suz(h))),
                    GonderAlani(konu: 'Hastalık Dağılımı – Tedbirler', child: _Tedbirler(k: _suz(h))),
                  ]),
                ),
              ]),
      ),
    );
  }

  List<HastalikKaydi> _suz(List<HastalikKaydi> h, {bool sonucDahil = true}) => [
        for (final k in h)
          if ((_yil == null || k.yil == _yil) &&
              (_ciftlik == null || k.ciftlik == _ciftlik) &&
              (_cins == null || k.cins == _cins) &&
              (!sonucDahil || _sonuc == null || k.sonuc == _sonuc))
            k
      ];

  Widget _filtreler(List<HastalikKaydi> h) {
    final yillar = (h.map((k) => k.yil).toSet().toList()..sort((a, b) => b.compareTo(a)));
    final cf = h.map((k) => k.ciftlik).toSet().toList()..sort();
    final cins = h.map((k) => k.cins).toSet().toList()..sort();
    final ozet = <String, int>{};
    for (final k in _suz(h, sonucDahil: false)) {
      ozet.update(k.sonuc, (n) => n + k.adet, ifAbsent: () => k.adet);
    }
    Widget satir<T>(List<T?> l, T? sec, String Function(T?) ad, ValueChanged<T?> deg) => SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              for (final x in l)
                Padding(
                  padding: const EdgeInsets.only(right: 6, top: 4),
                  child: ChoiceChip(
                    label: Text(ad(x)),
                    selected: sec == x,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => deg(x)),
                  ),
                ),
            ],
          ),
        );
    return Material(
      color: Renk.kart,
      child: Column(children: [
        satir<int>([null, ...yillar], _yil, (y) => y?.toString() ?? 'Tüm yıllar', (y) => _yil = y),
        satir<String>([null, ...cf], _ciftlik, (c) => c ?? 'Tüm çiftlikler', (c) => _ciftlik = c),
        satir<String>([null, ...cins], _cins, (c) => c ?? 'Tüm cinsler', (c) => _cins = c),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: Row(children: [
            for (final s in sonuclar)
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _sonuc = _sonuc == s ? null : s),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _sonuc == s ? _sonucRenk[s] : _sonucRenk[s]!.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(children: [
                      Text('${ozet[s] ?? 0}',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16, color: _sonuc == s ? Colors.white : _sonucRenk[s])),
                      Text(_kisa(s), style: TextStyle(fontSize: 11, color: _sonuc == s ? Colors.white : Renk.yazi)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
        const Divider(height: 1),
      ]),
    );
  }
}

Map<String, int> _topla(Iterable<HastalikKaydi> k, String Function(HastalikKaydi) anahtar) {
  final m = <String, int>{};
  for (final x in k) {
    m.update(anahtar(x), (n) => n + x.adet, ifAbsent: () => x.adet);
  }
  return m;
}

class _YiginCubuk extends StatelessWidget {
  const _YiginCubuk({required this.dagilim, required this.enCok});
  final Map<String, int> dagilim;
  final int enCok;

  @override
  Widget build(BuildContext context) {
    final top = dagilim.values.fold(0, (a, b) => a + b);
    return LayoutBuilder(builder: (context, c) {
      final w = enCok == 0 ? 0.0 : c.maxWidth * top / enCok;
      return Row(children: [
        for (final s in sonuclar)
          if ((dagilim[s] ?? 0) > 0)
            Container(width: w * dagilim[s]! / top, height: 14, color: _sonucRenk[s]),
      ]);
    });
  }
}

/// Kayıtları yıl → ay olarak gruplar: her yılın başlığı (toplam vaka),
/// altında yeniden eskiye aylar. [ay] her ayın kartını üretir.
class _YilAy extends StatelessWidget {
  const _YilAy({required this.k, required this.ay, this.ust = const []});
  final List<HastalikKaydi> k;
  final Widget Function(int yil, int ay, List<HastalikKaydi> l, int enCok) ay;
  final List<Widget> ust;

  @override
  Widget build(BuildContext context) {
    if (k.isEmpty) return const Center(child: Text('Bu seçimde kayıt yok'));
    final donem = <int, List<HastalikKaydi>>{};
    for (final x in k) {
      donem.putIfAbsent(x.yil * 100 + x.ay, () => []).add(x);
    }
    final anahtar = donem.keys.toList()..sort((a, b) => b.compareTo(a));
    final toplam = {for (final a in anahtar) a: donem[a]!.fold(0, (s, x) => s + x.adet)};
    final enCok = toplam.values.reduce((a, b) => a > b ? a : b);
    final satirlar = <Widget>[...ust];
    int? oncekiYil;
    for (final a in anahtar) {
      final y = a ~/ 100;
      if (y != oncekiYil) {
        final yk = k.where((x) => x.yil == y);
        final yt = yk.fold(0, (s, x) => s + x.adet);
        final ol = yk.where((x) => x.sonuc == 'Ölüm').fold(0, (s, x) => s + x.adet);
        satirlar.add(Padding(
          padding: EdgeInsets.fromLTRB(4, oncekiYil == null ? 4 : 18, 4, 8),
          child: Row(children: [
            Text('$y', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(width: 10),
            Expanded(
              child: Text('$yt vaka · $ol ölüm',
                  style: const TextStyle(color: Renk.soluk, fontSize: 13)),
            ),
          ]),
        ));
        oncekiYil = y;
      }
      satirlar.add(ay(y, a % 100, donem[a]!, enCok));
    }
    return ListView(padding: const EdgeInsets.all(12), children: satirlar);
  }
}

/// Günlük / haftalık dağılım. Tarih, vakanın kaynak listede ilk görüldüğü gündür.
/// Kaynağında gün bulunmayan vakalar ("tarihi belirsiz") ve yalnızca aylık sayısı
/// girilmiş dönemler bu görünümde yer almaz; sayıları üstte ayrıca belirtilir.
class _Donemsel extends StatelessWidget {
  const _Donemsel({required this.k, required this.haftalik});
  final List<HastalikKaydi> k;
  final bool haftalik;

  static DateTime _haftaBasi(DateTime t) => t.subtract(Duration(days: t.weekday - 1));

  String _etiket(DateTime t) {
    if (!haftalik) {
      const gunler = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
      return '${t.day} ${aylar[t.month - 1]} ${t.year}, ${gunler[t.weekday - 1]}';
    }
    final b = t.add(const Duration(days: 6));
    final bas = b.month == t.month ? '${t.day}' : b.year == t.year ? '${t.day} ${aylar[t.month - 1]}' : '${t.day} ${aylar[t.month - 1]} ${t.year}';
    return '$bas – ${b.day} ${aylar[b.month - 1]} ${b.year}';
  }

  @override
  Widget build(BuildContext context) {
    final donem = <DateTime, List<HastalikKaydi>>{};
    var belirsiz = 0, aylik = 0;
    final aylikDonem = <String>{};
    for (final x in k) {
      final t = x.tarih;
      if (t == null) {
        if (x.gun == 0) {
          belirsiz += x.adet;
        } else {
          aylik += x.adet;
          aylikDonem.add('${aylar[x.ay - 1]} ${x.yil}');
        }
        continue;
      }
      donem.putIfAbsent(haftalik ? _haftaBasi(t) : t, () => []).add(x);
    }
    final anahtar = donem.keys.toList()..sort((a, b) => b.compareTo(a));
    int top(Iterable<HastalikKaydi> l) => l.fold(0, (s, x) => s + x.adet);
    final toplam = {for (final a in anahtar) a: top(donem[a]!)};
    final enCok = toplam.isEmpty ? 0 : toplam.values.reduce((a, b) => a > b ? a : b);

    final ust = <Widget>[
      const _Lejant(),
      const SizedBox(height: 4),
      Text(
          haftalik
              ? 'Haftalar pazartesi–pazar olarak gruplanır. Tarih, vakanın kaynak listede ilk görüldüğü gündür; '
                  'aynı hayvanın aynı ay içindeki aynı hastalığı tek vaka sayılır.'
              : 'Tarih, vakanın kaynak listede ilk görüldüğü gündür; aynı hayvanın aynı ay içindeki aynı hastalığı tek vaka sayılır.',
          style: const TextStyle(fontSize: 12, color: Renk.soluk)),
      if (belirsiz > 0 || aylik > 0)
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Renk.amberAcik, borderRadius: BorderRadius.circular(8)),
          child: Text(
              [
                if (belirsiz > 0) 'Tarihi belirsiz: $belirsiz vaka (kaynakta gün bilgisi yok; aylık ve yıllık toplamlarda yer alır).',
                if (aylik > 0)
                  'Yalnızca aylık veri: $aylik vaka (${aylikDonem.take(4).join(', ')}${aylikDonem.length > 4 ? ' …' : ''}; Bilgi Bankası girişi).',
              ].join('\n'),
              style: const TextStyle(fontSize: 12)),
        ),
      const SizedBox(height: 8),
    ];
    if (anahtar.isEmpty) {
      return ListView(padding: const EdgeInsets.all(12), children: [
        ...ust,
        const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Bu seçimde tarihli kayıt yok'))),
      ]);
    }
    // Başlık: günlükte ay, haftalıkta yıl.
    final ogeler = <Object>[];
    int? onceki;
    for (final a in anahtar) {
      final g = haftalik ? a.year : a.year * 100 + a.month;
      if (g != onceki) {
        ogeler.add(g);
        onceki = g;
      }
      ogeler.add(a);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: ust.length + ogeler.length,
      itemBuilder: (context, i) {
        if (i < ust.length) return ust[i];
        final o = ogeler[i - ust.length];
        if (o is int) {
          final grup = anahtar.where((a) => haftalik ? a.year == o : a.year * 100 + a.month == o);
          final t = grup.fold(0, (s, a) => s + toplam[a]!);
          final ol = grup.fold(0, (s, a) => s + top(donem[a]!.where((x) => x.sonuc == 'Ölüm')));
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Row(children: [
              Text(haftalik ? '$o' : '${aylar[o % 100 - 1]} ${o ~/ 100}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              Expanded(
                child: Text('$t tarihli vaka · $ol ölüm · ${grup.length} ${haftalik ? 'hafta' : 'gün'}',
                    style: const TextStyle(color: Renk.soluk, fontSize: 13)),
              ),
            ]),
          );
        }
        final a = o as DateTime;
        final l = donem[a]!;
        final t = toplam[a]!;
        final cf = _topla(l, (x) => x.ciftlik).entries.toList()..sort((x, y) => y.value.compareTo(x.value));
        final hs = _topla(l, (x) => x.hastalik).entries.toList()..sort((x, y) => y.value.compareTo(x.value));
        String? degisim;
        if (haftalik) {
          final onc = toplam[a.subtract(const Duration(days: 7))] ?? 0;
          if (onc > 0) {
            final f = (t - onc) / onc * 100;
            degisim = 'Önceki hafta $onc (${f >= 0 ? '+' : ''}${f.toStringAsFixed(0)}%)';
          }
        }
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Row(children: [
              Expanded(flex: 5, child: Text(_etiket(a), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
              Expanded(flex: 3, child: _YiginCubuk(dagilim: _topla(l, (x) => x.sonuc), enCok: enCok)),
              SizedBox(width: 40, child: Text('$t', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
            subtitle: Text(
                [
                  cf.map((e) => '${e.key} ${e.value}').join(', '),
                  if (degisim != null) degisim,
                  'En sık: ${hs.take(3).map((e) => '${e.key} ${e.value}').join(', ')}',
                ].join(' · '),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: [_HastalikListesi(k: l)],
          ),
        );
      },
    );
  }
}

class _Aylik extends StatelessWidget {
  const _Aylik({required this.k});
  final List<HastalikKaydi> k;

  @override
  Widget build(BuildContext context) => _YilAy(
        k: k,
        ust: const [_Lejant(), SizedBox(height: 8)],
        ay: (y, ay, l, enCok) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Row(children: [
              SizedBox(width: 78, child: Text(aylar[ay - 1], style: const TextStyle(fontWeight: FontWeight.w600))),
              Expanded(child: _YiginCubuk(dagilim: _topla(l, (x) => x.sonuc), enCok: enCok)),
              SizedBox(width: 48, child: Text('${l.fold(0, (s, x) => s + x.adet)}', textAlign: TextAlign.right)),
            ]),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: [_HastalikListesi(k: l, sinir: 8)],
          ),
        ),
      );
}

/// Yıllık özet: her yılın vaka sayısı, sonuç dağılımı, önceki yıla göre değişim ve en sık hastalıklar.
/// İçinde bulunulan yıl ve eksik aylı yıllar kapsadığı aylarla gösterilir; karşılaştırma aynı aylar üzerinden yapılır.
class _Yillik extends StatelessWidget {
  const _Yillik({required this.k});
  final List<HastalikKaydi> k;

  @override
  Widget build(BuildContext context) {
    if (k.isEmpty) return const Center(child: Text('Bu seçimde kayıt yok'));
    final yil = <int, List<HastalikKaydi>>{};
    for (final x in k) {
      yil.putIfAbsent(x.yil, () => []).add(x);
    }
    final yillar = yil.keys.toList()..sort((a, b) => b.compareTo(a));
    int top(Iterable<HastalikKaydi> l) => l.fold(0, (s, x) => s + x.adet);
    final enCok = yillar.map((y) => top(yil[y]!)).reduce((a, b) => a > b ? a : b);
    String aralik(Set<int> ay) {
      if (ay.isEmpty) return '';
      final l = ay.toList()..sort();
      if (l.length == 12) return 'Ocak–Aralık';
      return l.length == 1 ? aylar[l.first - 1] : '${aylar[l.first - 1]}–${aylar[l.last - 1]} (${l.length} ay)';
    }

    return ListView(padding: const EdgeInsets.all(12), children: [
      const _Lejant(),
      const SizedBox(height: 4),
      const Text('Yıl içinde kaydı olan aylar başlıkta yazılıdır. Önceki yılla karşılaştırma yalnızca iki yılda da kaydı olan aylar üzerinden yapılır.',
          style: TextStyle(fontSize: 12, color: Renk.soluk)),
      const SizedBox(height: 8),
      for (final y in yillar)
        Builder(builder: (_) {
          final l = yil[y]!;
          final aylarY = l.map((x) => x.ay).toSet();
          final t = top(l);
          final olum = top(l.where((x) => x.sonuc == 'Ölüm'));
          String? degisim;
          final onceki = yil[y - 1];
          if (onceki != null) {
            final ortak = aylarY.intersection(onceki.map((x) => x.ay).toSet());
            final a = top(l.where((x) => ortak.contains(x.ay)));
            final b = top(onceki.where((x) => ortak.contains(x.ay)));
            if (ortak.isNotEmpty && b > 0) {
              final f = (a - b) / b * 100;
              degisim = '${y - 1} aynı aylara göre ${f >= 0 ? '+' : ''}${f.toStringAsFixed(0)}% ($a / $b vaka)';
            }
          }
          final enSik = _topla(l, (x) => x.hastalik).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              title: Row(children: [
                SizedBox(width: 56, child: Text('$y', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                Expanded(child: _YiginCubuk(dagilim: _topla(l, (x) => x.sonuc), enCok: enCok)),
                SizedBox(width: 56, child: Text('$t', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
              ]),
              subtitle: Text(
                  [
                    aralik(aylarY),
                    '$olum ölüm (%${t == 0 ? 0 : (olum / t * 100).toStringAsFixed(1)})',
                    if (degisim != null) degisim,
                    if (enSik.isNotEmpty) 'En sık: ${enSik.take(3).map((e) => '${e.key} ${e.value}').join(', ')}',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12.5)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [_HastalikListesi(k: l, sinir: 12)],
            ),
          );
        }),
    ]);
  }
}

class _Lejant extends StatelessWidget {
  const _Lejant();
  @override
  Widget build(BuildContext context) => Wrap(spacing: 12, runSpacing: 4, children: [
        for (final s in sonuclar)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 12, height: 12, color: _sonucRenk[s]),
            const SizedBox(width: 4),
            Text(_kisa(s), style: const TextStyle(fontSize: 12)),
          ]),
      ]);
}

/// Hastalık başına sonuç dağılımı (ölüm / kalım / kuru / kesim / imha).
class _HastalikListesi extends StatelessWidget {
  const _HastalikListesi({required this.k, this.sinir});
  final List<HastalikKaydi> k;
  final int? sinir;

  @override
  Widget build(BuildContext context) {
    final top = _topla(k, (x) => x.hastalik);
    final l = top.keys.toList()..sort((a, b) => top[b]!.compareTo(top[a]!));
    final goster = sinir == null ? l : l.take(sinir!).toList();
    return Column(children: [
      for (final h in goster)
        InkWell(
          onTap: () => _detay(context, h, k.where((x) => x.hastalik == h).toList()),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(child: Text(h)),
              for (final s in sonuclar)
                if (_topla(k.where((x) => x.hastalik == h), (x) => x.sonuc)[s] case final n? when n > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: _sonucRenk[s]!.withValues(alpha: .12), borderRadius: BorderRadius.circular(6)),
                    child: Text('${_kisa(s)} $n', style: TextStyle(fontSize: 11, color: _sonucRenk[s], fontWeight: FontWeight.w600)),
                  ),
            ]),
          ),
        ),
      if (goster.length < l.length)
        Align(alignment: Alignment.centerLeft, child: Text('+ ${l.length - goster.length} hastalık daha', style: const TextStyle(color: Renk.soluk, fontSize: 12))),
    ]);
  }
}

void _detay(BuildContext context, String h, List<HastalikKaydi> k) {
  final t = tedbirBul(h);
  final cf = _topla(k, (x) => x.ciftlik), cins = _topla(k, (x) => x.cins), son = _topla(k, (x) => x.sonuc);
  String yaz(Map<String, int> m) => (m.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).map((e) => '${e.key} ${e.value}').join(' · ');
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .7,
      builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.all(16), children: [
        Text(h, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Sonuç: ${yaz(son)}'),
        Text('Çiftlik: ${yaz(cf)}'),
        Text('Cins: ${yaz(cins)}'),
        const Divider(height: 24),
        _TedbirKutusu(h: h, t: t),
      ]),
    ),
  );
}

class _TedbirKutusu extends StatelessWidget {
  const _TedbirKutusu({required this.h, required this.t, this.baslik = false});
  final String h;
  final Tedbir t;
  final bool baslik;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (baslik) Text(h, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.coronavirus_outlined, size: 18, color: Renk.amber),
          const SizedBox(width: 6),
          Expanded(child: Text('Etken / neden: ${t.etken}', style: const TextStyle(color: Renk.amber, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 6),
        const Text('Önleme tedbirleri', style: TextStyle(fontWeight: FontWeight.w700)),
        for (final s in t.tedbirler)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('•  '),
              Expanded(child: Text(s)),
            ]),
          ),
      ]);
}

class _Hastaliklar extends StatelessWidget {
  const _Hastaliklar({required this.k});
  final List<HastalikKaydi> k;
  @override
  Widget build(BuildContext context) => _YilAy(
        k: k,
        ust: const [
          Text('Aya dokun: o ayın hastalıkları. Hastalığa dokun: etken ve önleme tedbirleri.',
              style: TextStyle(color: Renk.soluk, fontSize: 12)),
          SizedBox(height: 6),
        ],
        ay: (y, ay, l, _) {
          final top = _topla(l, (x) => x.hastalik);
          final ilk = (top.keys.toList()..sort((a, b) => top[b]!.compareTo(top[a]!))).take(3);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              title: Text('${aylar[ay - 1]} $y · ${l.fold(0, (s, x) => s + x.adet)} vaka',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(ilk.map((h) => '$h ${top[h]}').join(' · '),
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [_HastalikListesi(k: l)],
            ),
          );
        },
      );
}

class _Tedbirler extends StatelessWidget {
  const _Tedbirler({required this.k});
  final List<HastalikKaydi> k;
  @override
  Widget build(BuildContext context) => _YilAy(
        k: k,
        ust: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Renk.amberAcik, borderRadius: BorderRadius.circular(8)),
            child: const Text(
                'Her ayda görülen hastalıklar ve önleme tedbirleri. Aya dokununca hastalıklar, '
                'hastalığa dokununca etken ve tedbirler açılır. Tedbirler genel bilgidir; aşı '
                'programı ve ilaçlar çiftlik veterineri ile teyit edilir.',
                style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 8),
        ],
        ay: (y, ay, l, _) {
          final top = _topla(l, (x) => x.hastalik);
          final hl = top.keys.toList()..sort((a, b) => top[b]!.compareTo(top[a]!));
          final teshissiz = (top['Belirtilmemiş'] ?? 0) + (top['Diğer'] ?? 0);
          final teshisli = hl.where((h) => h != 'Belirtilmemiş' && h != 'Diğer').toList();
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              title: Text('${aylar[ay - 1]} $y · ${l.fold(0, (s, x) => s + x.adet)} vaka',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(teshisli.take(3).map((h) => '$h ${top[h]}').join(' · '),
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              children: [
                for (final h in teshisli)
                  ExpansionTile(
                    dense: true,
                    title: Text('$h — ${top[h]} vaka', style: const TextStyle(fontWeight: FontWeight.w700)),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: [_TedbirKutusu(h: h, t: tedbirBul(h))],
                  ),
                if (teshissiz > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Text('Teşhisi yazılmamış: $teshissiz vaka (etken izlenemiyor; otopsi ve teşhis kaydı önerilir)',
                        style: const TextStyle(fontSize: 12, color: Renk.soluk)),
                  ),
              ],
            ),
          );
        },
      );
}
