import 'package:flutter/material.dart';

import '../bicim.dart';
import '../tema.dart';
import '../veri/hastalik.dart' show aylar;
import '../veri/sureme.dart';
import 'gonder.dart';

/// Sürü Sağlığı ve Üreme: doğum, tohumlama, gebelik muayenesi, senkronizasyon, sürü durumu,
/// aşı, gelen hayvan, hayvan satışı, süt analizi ve diğer veteriner uygulamaları.
/// Kaynak: Drive › SAĞLIK RAPORLARI veteriner uygulama dosyaları (yalnızca sayılar).
class SuremeEkran extends StatefulWidget {
  const SuremeEkran({super.key});

  @override
  State<SuremeEkran> createState() => _SuremeEkranState();
}

double _top(Iterable<SuremeSatir> l, String k) => l.fold(0.0, (s, x) => s + x.v(k));
String _s(double v) => sayi(v);
String _yuzde(double a, double b) => b <= 0 ? '—' : '%${sayi(a / b * 100, ondalik: 1)}';

Map<String, double> _grupla(Iterable<SuremeSatir> l, String Function(SuremeSatir) a, String k) {
  final m = <String, double>{};
  for (final x in l) {
    m.update(a(x), (n) => n + x.v(k), ifAbsent: () => x.v(k));
  }
  return m;
}

String _liste(Map<String, double> m, {String son = ''}) {
  final e = m.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
  return e.map((x) => '${x.key} ${_s(x.value)}$son').join(' · ');
}

class _SuremeEkranState extends State<SuremeEkran> {
  late final SuremeArsiv _a = SuremeArsiv.yukle();
  int? _yil;
  String? _ciftlik;

  List<SuremeSatir> _suz(List<SuremeSatir> l) =>
      [for (final x in l) if ((_yil == null || x.t.year == _yil) && (_ciftlik == null || x.ciftlik == _ciftlik)) x];

  @override
  Widget build(BuildContext context) {
    final a = _a;
    const sekmeler = [
      'Doğum', 'Tohumlama', 'Gebelik Muayenesi', 'Senkronizasyon', 'Sürü Durumu',
      'Aşı', 'Gelen Hayvan', 'Hayvan Satışı', 'Süt Analizi', 'Diğer Uygulamalar',
    ];
    return DefaultTabController(
      length: sekmeler.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sürü Sağlığı ve Üreme'),
          bottom: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [for (final s in sekmeler) Tab(text: s)]),
        ),
        body: a.bosMu
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: Text('Sürü sağlığı ve üreme arşivi henüz yüklenmedi. Verileri yenileyip tekrar deneyin.',
                        textAlign: TextAlign.center)))
            : Column(children: [
                _filtreler(a),
                Expanded(
                  child: TabBarView(children: [
                    for (final (i, s) in sekmeler.indexed) GonderAlani(konu: 'Sürü Sağlığı ve Üreme – $s', child: _sekme(i, a)),
                  ]),
                ),
              ]),
      ),
    );
  }

  Widget _sekme(int i, SuremeArsiv a) => switch (i) {
        0 => _Dogum(l: _suz(a.dogum)),
        1 => _Tohumlama(l: _suz(a.tohumlama), boga: _suz(a.boga)),
        2 => _Gebelik(l: _suz(a.gebelik)),
        3 => _Senk(l: _suz(a.senk)),
        4 => _Suru(l: _ciftlik == null || _ciftlik == 'Şekersüt' ? _suz(a.suru) : const []),
        5 => _Asi(l: _suz(a.asi)),
        6 => _Gelen(l: _suz(a.gelen)),
        7 => _Satis(l: _suz(a.satis)),
        8 => _Sut(l: _suz(a.sut)),
        _ => _Diger(l: _suz(a.diger)),
      };

  Widget _filtreler(SuremeArsiv a) {
    final tum = [...a.dogum, ...a.tohumlama, ...a.gebelik, ...a.senk, ...a.asi, ...a.gelen, ...a.satis, ...a.sut, ...a.diger, ...a.suru];
    final yillar = tum.map((x) => x.t.year).toSet().toList()..sort((x, y) => y.compareTo(x));
    final cf = tum.map((x) => x.ciftlik).toSet().toList()..sort();
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
        const SizedBox(height: 4),
        const Divider(height: 1),
      ]),
    );
  }
}

/// Kayıtları yıl → ay gruplar; her ay bir kart (başlık + alt satır), açılınca ayrıntı.
class _AyListe extends StatelessWidget {
  const _AyListe({
    required this.l,
    required this.ozet,
    required this.detay,
    this.not,
    this.yilOzet,
  });
  final List<SuremeSatir> l;
  final String Function(List<SuremeSatir>) ozet;
  final List<Widget> Function(List<SuremeSatir>) detay;
  final String? Function(List<SuremeSatir>)? yilOzet;
  final String? not;

  @override
  Widget build(BuildContext context) {
    final ust = <Widget>[
      if (not != null) Text(not!, style: const TextStyle(fontSize: 12, color: Renk.soluk)),
      if (not != null) const SizedBox(height: 8),
    ];
    if (l.isEmpty) {
      return ListView(padding: const EdgeInsets.all(12), children: [
        ...ust,
        const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Bu seçimde kayıt yok'))),
      ]);
    }
    final ay = <int, List<SuremeSatir>>{};
    for (final x in l) {
      ay.putIfAbsent(x.t.year * 100 + x.t.month, () => []).add(x);
    }
    final anahtar = ay.keys.toList()..sort((a, b) => b.compareTo(a));
    final ogeler = <Object>[];
    int? onceki;
    for (final k in anahtar) {
      if (k ~/ 100 != onceki) {
        onceki = k ~/ 100;
        ogeler.add(onceki);
      }
      ogeler.add(k);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: ust.length + ogeler.length,
      itemBuilder: (context, i) {
        if (i < ust.length) return ust[i];
        final o = ogeler[i - ust.length] as int;
        if (o < 10000) {
          final yl = l.where((x) => x.t.year == o).toList();
          final yo = (yilOzet ?? ozet)(yl);
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$o', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              if (yo != null) Expanded(child: Text(yo, style: const TextStyle(color: Renk.soluk, fontSize: 12.5))),
            ]),
          );
        }
        final kl = ay[o]!..sort((a, b) => b.t.compareTo(a.t));
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Text('${aylar[o % 100 - 1]} ${o ~/ 100}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(ozet(kl), style: const TextStyle(fontSize: 12.5)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: detay(kl),
          ),
        );
      },
    );
  }
}

/// Gün bazında ayrıntı satırları: tarih · çiftlik · metin.
List<Widget> _gunluk(List<SuremeSatir> l, String Function(List<SuremeSatir>) metin, {bool ciftlikGoster = true}) {
  final g = <String, List<SuremeSatir>>{};
  for (final x in l) {
    g.putIfAbsent('${x.t.toIso8601String()}|${x.ciftlik}', () => []).add(x);
  }
  final k = g.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final a in k)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 46, child: Text(gunAy(g[a]!.first.t), style: const TextStyle(fontWeight: FontWeight.w600))),
          if (ciftlikGoster) SizedBox(width: 74, child: Text(g[a]!.first.ciftlik, style: const TextStyle(color: Renk.soluk))),
          Expanded(child: Text(metin(g[a]!))),
        ]),
      ),
  ];
}

Widget _baslik(String s) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(s, style: const TextStyle(fontWeight: FontWeight.w700, color: Renk.anaKoyu)),
    );

class _Dogum extends StatelessWidget {
  const _Dogum({required this.l});
  final List<SuremeSatir> l;

  static String _ozet(List<SuremeSatir> l) {
    final t = _top(l, 'dogum');
    final s = _grupla(l, (x) => x.tur, 'dogum');
    final sorunlu = (s['Müdahale/güç doğum'] ?? 0) + (s['Abort'] ?? 0) + (s['Ölü doğum'] ?? 0);
    return [
      '${_s(t)} kayıt',
      _liste(s),
      if (_top(l, 'ikiz') > 0) 'İkiz ${_s(_top(l, 'ikiz'))}',
      'Buzağı: dişi ${_s(_top(l, 'disi'))}, erkek ${_s(_top(l, 'erkek'))}${_top(l, 'olu') > 0 ? ', ölü ${_s(_top(l, 'olu'))}' : ''}',
      'Sorunlu doğum oranı ${_yuzde(sorunlu, t)}',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) => _AyListe(
        l: l,
        not: 'Doğum şekli: normal, müdahale/güç doğum, günsüz, ölü doğum, abort. Şekersüt 2022–2024 kayıtları doğan buzağı '
            'listesinden alındığı için her buzağı bir kayıttır; diğer kayıtlarda her satır bir doğumdur. Sorunlu doğum oranı = '
            '(müdahale + ölü doğum + abort) / toplam.',
        ozet: _ozet,
        detay: (k) => [
          if (_grupla(k, (x) => x.alt, 'dogum').length > 1) Text('Anne: ${_liste(_grupla(k, (x) => x.alt, 'dogum'))}'),
          _baslik('Günlük'),
          ..._gunluk(k, (g) => _liste(_grupla(g, (x) => x.tur, 'dogum'))),
        ],
      );
}

class _Tohumlama extends StatelessWidget {
  const _Tohumlama({required this.l, required this.boga});
  final List<SuremeSatir> l, boga;

  static String _ozet(List<SuremeSatir> l) {
    final t = _top(l, 'adet');
    final grup = _grupla(l, (x) => x.alt.split('|').first, 'adet');
    final sira = _grupla(l, (x) => x.alt.split('|').last, 'adet')..remove('Bilinmiyor');
    final yontem = _grupla(l, (x) => x.tur, 'adet')..remove('Belirtilmemiş');
    return [
      '${_s(t)} tohumlama',
      _liste(grup..remove('Belirtilmemiş')),
      if (sira.isNotEmpty) _liste(sira),
      if (yontem.isNotEmpty) _liste(yontem),
    ].where((s) => s.isNotEmpty).join(' · ');
  }

  @override
  Widget build(BuildContext context) => _AyListe(
        l: l,
        not: 'Tohumlama sırası hayvanın kaçıncı tohumlaması olduğunu gösterir; yöntem kızgınlık gözlemi veya senkronizasyon '
            'programıdır. Aynı hayvanın aynı gün iki kez yazılan kaydı bir kez sayılır.',
        ozet: _ozet,
        detay: (k) {
          final y = k.first.t.year, a = k.first.t.month;
          final b = boga.where((x) => x.t.year == y && x.t.month == a && k.any((z) => z.ciftlik == x.ciftlik));
          return [
            if (b.isNotEmpty) ...[_baslik('Kullanılan boğa'), Text(_liste(_grupla(b, (x) => x.tur, 'adet')))],
            _baslik('Günlük'),
            ..._gunluk(k, (g) => '${_s(_top(g, 'adet'))} tohumlama · ${_liste(_grupla(g, (x) => x.alt.split('|').first, 'adet'))}'),
          ];
        },
      );
}

class _Gebelik extends StatelessWidget {
  const _Gebelik({required this.l});
  final List<SuremeSatir> l;

  static String _ozet(List<SuremeSatir> l) {
    final t = _top(l, 'adet');
    final s = _grupla(l, (x) => x.tur, 'adet');
    return ['${_s(t)} muayene', _liste(s), 'Gebelik oranı ${_yuzde(s['Gebe'] ?? 0, t)}'].join(' · ');
  }

  @override
  Widget build(BuildContext context) => _AyListe(
        l: l,
        not: 'Gebelik oranı = gebe çıkan / muayene edilen. "Boş (kist)" foliküler veya luteal kist tespit edilen boş hayvanlardır.',
        ozet: _ozet,
        detay: (k) => [
          if (_grupla(k, (x) => x.alt, 'adet').length > 1) Text('Grup: ${_liste(_grupla(k, (x) => x.alt, 'adet'))}'),
          _baslik('Günlük'),
          ..._gunluk(k, (g) => _liste(_grupla(g, (x) => x.tur, 'adet'))),
        ],
      );
}

class _Senk extends StatelessWidget {
  const _Senk({required this.l});
  final List<SuremeSatir> l;

  @override
  Widget build(BuildContext context) => _AyListe(
        l: l,
        not: 'Senkronizasyon (kızgınlık eşitleme) programları; tarih programın ilk uygulama günüdür, sayı programa alınan hayvan sayısıdır.',
        ozet: (k) => '${_s(_top(k, 'program'))} program · ${_s(_top(k, 'hayvan'))} hayvan',
        detay: (k) => _gunluk(k, (g) => '${_s(_top(g, 'hayvan'))} hayvan programa alındı'),
      );
}

class _Suru extends StatelessWidget {
  const _Suru({required this.l});
  final List<SuremeSatir> l;

  static const _alan = [
    ('sagmal', 'Sağmal'), ('bos_inek', 'Boş inek'), ('tohumlu_inek', 'Tohumlu inek'), ('gebe_inek', 'Gebe inek'),
    ('kuru_gebe', 'Kuru gebe'), ('genc_duve', 'Genç düve'), ('bos_duve', 'Boş düve'), ('uygun_duve', 'Tohuma uygun boş düve'),
    ('tohumlu_duve', 'Tohumlu düve'), ('gebe_duve', 'Gebe düve'),
  ];

  static String _durum(SuremeSatir x) =>
      [for (final (k, ad) in _alan) if (x.d.containsKey(k)) '$ad ${_s(x.v(k))}'].join(' · ');

  @override
  Widget build(BuildContext context) => _AyListe(
        l: l,
        not: 'Şekersüt İşletmesi günlük tohumlama bilgisi. Ay kartında ayın son kayıtlı günündeki sürü durumu ve ay içinde '
            'tohumlanan inek/düve toplamı yer alır.',
        ozet: (k) {
          final son = k.first;
          return '${gunAy(son.t)} itibarıyla: ${_durum(son)} · Ay içinde tohumlanan inek ${_s(_top(k, 'toh_inek'))}, düve ${_s(_top(k, 'toh_duve'))}';
        },
        yilOzet: (k) => 'Yıl içinde tohumlanan inek ${_s(_top(k, 'toh_inek'))}, düve ${_s(_top(k, 'toh_duve'))}',
        detay: (k) => [
          for (final x in k)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 46, child: Text(gunAy(x.t), style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(
                    child: Text('${_durum(x)} · Tohumlanan inek ${_s(x.v('toh_inek'))}, düve ${_s(x.v('toh_duve'))}'
                        '${x.v('kizginlik') > 0 ? ' · Kızgınlık ${_s(x.v('kizginlik'))}' : ''}')),
              ]),
            ),
        ],
      );
}

class _Asi extends StatelessWidget {
  const _Asi({required this.l});
  final List<SuremeSatir> l;

  @override
  Widget build(BuildContext context) => _AyListe(
        l: l,
        not: 'Aşı uygulamaları: aşı adı ve uygulanan grup/bölüm. Hayvan bazında tutulan listelerde kayıt sayısı ayrıca belirtilir.',
        ozet: (k) => '${k.length} uygulama · ${k.map((x) => x.tur).toSet().take(4).join(', ')}',
        detay: (k) => _gunluk(
            k,
            (g) => g
                .map((x) => '${x.tur}${x.alt.isNotEmpty ? ' (${x.alt})' : ''}${x.v('kayit') > 1 ? ' – ${_s(x.v('kayit'))} kayıt' : ''}')
                .join('; ')),
      );
}

class _Gelen extends StatelessWidget {
  const _Gelen({required this.l});
  final List<SuremeSatir> l;

  static String _ozet(List<SuremeSatir> k) {
    final a = _top(k, 'adet'), kg = _top(k, 'kg');
    return '${_s(a)} baş · ${_liste(_grupla(k, (x) => x.tur, 'adet'))}${kg > 0 && a > 0 ? ' · ortalama ${_s(kg / a)} kg' : ''}';
  }

  @override
  Widget build(BuildContext context) => _AyListe(
        l: l,
        not: 'Çiftliğe gelen hayvanlar (adet, cins, ortalama canlı ağırlık). Geldiği yer ve araç plakası alınmaz.',
        ozet: _ozet,
        detay: (k) => _gunluk(k, _ozet),
      );
}

class _Satis extends StatelessWidget {
  const _Satis({required this.l});
  final List<SuremeSatir> l;

  static String _ozet(List<SuremeSatir> k) {
    final a = _top(k, 'adet'), kg = _top(k, 'kg'), t = _top(k, 'tutar');
    return [
      '${_s(a)} baş',
      _liste(_grupla(k, (x) => x.tur, 'adet')),
      if (t > 0) '${_s(t)} TL',
      if (kg > 0 && a > 0) 'ortalama ${_s(kg / a)} kg',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) => _AyListe(
        l: l,
        not: 'Hayvan satışları (adet, tutar, ortalama canlı ağırlık). Alıcı bilgisi alınmaz.',
        ozet: _ozet,
        detay: (k) => _gunluk(k, _ozet),
      );
}

class _Sut extends StatelessWidget {
  const _Sut({required this.l});
  final List<SuremeSatir> l;

  static const _alan = [
    ('yag', 'Yağ %', 2), ('protein', 'Protein %', 2), ('tkm', 'Kuru madde %', 2), ('ykm', 'YKM %', 2),
    ('ph', 'pH', 2), ('laktik', 'Laktik asit', 2), ('shs', 'Somatik hücre', 0), ('bakteri', 'Bakteri', 0), ('miktar', 'Süt (lt)', 0),
  ];

  static String _ort(List<SuremeSatir> k) => [
        for (final (a, ad, o) in _alan)
          if (k.any((x) => x.d.containsKey(a)))
            '$ad ${sayi(k.where((x) => x.d.containsKey(a)).fold(0.0, (s, x) => s + x.v(a)) / k.where((x) => x.d.containsKey(a)).length, ondalik: o)}',
      ].join(' · ');

  @override
  Widget build(BuildContext context) => _AyListe(
        l: l,
        not: 'Süt analiz sonuçları; ay kartında ayın ortalaması, ayrıntıda analiz günleri yer alır.',
        ozet: (k) => '${k.length} analiz · ortalama: ${_ort(k)}',
        detay: (k) => _gunluk(k, _ort),
      );
}

class _Diger extends StatelessWidget {
  const _Diger({required this.l});
  final List<SuremeSatir> l;

  @override
  Widget build(BuildContext context) => _AyListe(
        l: l,
        not: 'Tırnak bakımı, mıknatıs uygulaması ve boynuz köreltme gibi rutin veteriner uygulamaları (hayvan sayısı).',
        ozet: (k) => _liste(_grupla(k, (x) => x.tur, 'adet')),
        detay: (k) => _gunluk(k, (g) => _liste(_grupla(g, (x) => x.tur, 'adet'))),
      );
}
