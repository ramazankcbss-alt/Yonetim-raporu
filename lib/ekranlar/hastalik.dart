import 'package:flutter/material.dart';

import '../tema.dart';
import '../veri/hastalik.dart';
import '../veri/model.dart';

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
      final y = l.map((k) => k.yil).toSet();
      setState(() {
        _hepsi = l;
        _yil = y.isEmpty ? null : y.reduce((a, b) => a > b ? a : b);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = _hepsi;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hastalık Dağılımı'),
          bottom: const TabBar(tabs: [Tab(text: 'Aylık'), Tab(text: 'Hastalıklar'), Tab(text: 'Tedbirler')]),
        ),
        body: h == null
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                _filtreler(h),
                Expanded(
                  child: TabBarView(children: [
                    _Aylik(k: _suz(h), yil: _yil),
                    _Hastaliklar(k: _suz(h)),
                    _Tedbirler(k: _suz(h)),
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

class _Aylik extends StatelessWidget {
  const _Aylik({required this.k, required this.yil});
  final List<HastalikKaydi> k;
  final int? yil;

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
    return ListView(padding: const EdgeInsets.all(12), children: [
      const _Lejant(),
      const SizedBox(height: 8),
      for (final a in anahtar)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Row(children: [
              SizedBox(width: 92, child: Text('${aylar[a % 100 - 1]} ${a ~/ 100}', style: const TextStyle(fontWeight: FontWeight.w600))),
              Expanded(child: _YiginCubuk(dagilim: _topla(donem[a]!, (x) => x.sonuc), enCok: enCok)),
              SizedBox(width: 48, child: Text('${toplam[a]}', textAlign: TextAlign.right)),
            ]),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: [_HastalikListesi(k: donem[a]!, sinir: 8)],
          ),
        ),
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
  Widget build(BuildContext context) => k.isEmpty
      ? const Center(child: Text('Bu seçimde kayıt yok'))
      : ListView(padding: const EdgeInsets.all(12), children: [
          const Text('Satıra dokun: etken ve önleme tedbirleri', style: TextStyle(color: Renk.soluk, fontSize: 12)),
          _HastalikListesi(k: k),
        ]);
}

class _Tedbirler extends StatelessWidget {
  const _Tedbirler({required this.k});
  final List<HastalikKaydi> k;
  @override
  Widget build(BuildContext context) {
    final top = _topla(k, (x) => x.hastalik)..remove('Belirtilmemiş')..remove('Diğer');
    final l = top.keys.toList()..sort((a, b) => top[b]!.compareTo(top[a]!));
    return ListView(padding: const EdgeInsets.all(12), children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Renk.amberAcik, borderRadius: BorderRadius.circular(8)),
        child: const Text(
            'Seçili döneme göre en sık görülen hastalıklar ve önleme tedbirleri. Tedbirler genel '
            'bilgidir; aşı programı ve ilaçlar çiftlik veterineri ile teyit edilir.',
            style: TextStyle(fontSize: 12)),
      ),
      const SizedBox(height: 8),
      for (final h in l.take(10))
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$h — ${top[h]} vaka', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              _TedbirKutusu(h: h, t: tedbirBul(h)),
            ]),
          ),
        ),
      const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(
              'Kayıt kalitesi: teşhisi yazılmamış ("Belirtilmemiş/Diğer") vakalarda etken izlenemiyor. '
              'Her ölümde otopsi ve her tedavide sonuç (iyileşti/kuru/kesim/ölüm) yazılması önerilir.'),
        ),
      ),
    ]);
  }
}
