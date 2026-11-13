import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/kategori.dart';
import '../veri/model.dart';
import 'bilesenler.dart';
import 'esk.dart' show tl;

/// Geçmiş Yıllar – Bilgi Bankası: çiftlik × gösterge bazında yıl yıl
/// değerler ve geçmişten çıkarılan dersler.
class GecmisEkran extends StatelessWidget {
  const GecmisEkran({super.key, required this.veri});

  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VeriDeposu.ben,
      builder: (context, _) {
        final v = VeriDeposu.ben.veri ?? veri;
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Geçmiş Yıllar'),
              actions: const [TabloGuncelleButonu()],
              bottom: const TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                  tabs: [
                Tab(text: 'Göstergeler'),
                Tab(text: 'Dersler'),
              ]),
            ),
            body: v.gecmis.isEmpty && v.dersler.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: BilgiKutusu(
                        yazi: 'Geçmiş yıllar verisi henüz gelmedi. Bilgi '
                            'Bankası tablosunu okuyabilmek için Apps Script '
                            'güncel olmalı.'),
                  )
                : TabBarView(children: [
                    _Gostergeler(kayitlar: v.gecmis),
                    _Dersler(dersler: v.dersler),
                  ]),
          ),
        );
      },
    );
  }
}

String gecmisDeger(GecmisVeri x) {
  final s = x.sayi;
  if (s == null) return x.deger;
  if (x.birim == 'TL' && s.abs() >= 10000) return tl(s);
  final o = s == s.roundToDouble() ? 0 : 1;
  final b = x.birim.isEmpty ? '' : ' ${x.birim}';
  return x.birim == '%' ? '%${sayi(s, ondalik: o)}' : '${sayi(s, ondalik: o)}$b';
}

class _Gostergeler extends StatefulWidget {
  const _Gostergeler({required this.kayitlar});
  final List<GecmisVeri> kayitlar;

  @override
  State<_Gostergeler> createState() => _GostergelerState();
}

class _GostergelerState extends State<_Gostergeler> {
  static const _tumu = 'Tümü';
  Birim? _birim;
  String _alan = _tumu; // '@Kök' = işletmenin tamamı, aksi hâlde tam çiftlik adı
  String _konu = _tumu;
  String _ara = '';

  bool _alanUyar(GecmisVeri x, String alan) =>
      alan == _tumu || (alan.startsWith('@') ? alanKoku(x.alan) == alan.substring(1) : x.alan == alan);

  @override
  Widget build(BuildContext context) {
    final k = widget.kayitlar;
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
    if (_birim == null) {
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
      if (_birim == null && b != onceki) satirlar.add(b);
      onceki = b;
      satirlar.add(a);
    }

    return Column(children: [
      SizedBox(
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

class _Dersler extends StatelessWidget {
  const _Dersler({required this.dersler});
  final List<Ders> dersler;

  @override
  Widget build(BuildContext context) {
    if (dersler.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16), child: BilgiKutusu(yazi: 'Henüz ders kaydı yok.'));
    }
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
