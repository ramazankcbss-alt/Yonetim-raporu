import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
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
              bottom: const TabBar(tabs: [
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
  String _alan = 'Tümü';
  String _konu = 'Tümü';
  String _ara = '';

  @override
  Widget build(BuildContext context) {
    final k = widget.kayitlar;
    final alanlar = ['Tümü', ...{for (final x in k) x.alan}.toList()..sort()];
    final konular = ['Tümü', ...{for (final x in k) x.konu}.where((e) => e.isNotEmpty).toList()..sort()];
    final ara = _ara.toLowerCase();
    final suz = k.where((x) =>
        (_alan == 'Tümü' || x.alan == _alan) &&
        (_konu == 'Tümü' || x.konu == _konu) &&
        (ara.isEmpty ||
            '${x.gosterge} ${x.alan} ${x.not} ${x.yil}'.toLowerCase().contains(ara)));
    final gruplar = <String, List<GecmisVeri>>{};
    for (final x in suz) {
      gruplar.putIfAbsent('${x.alan}|${x.gosterge}', () => []).add(x);
    }
    final anahtarlar = gruplar.keys.toList()..sort();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Row(children: [
          Expanded(child: _Secim(deger: _alan, liste: alanlar, etiket: 'Çiftlik', sec: (s) => setState(() => _alan = s))),
          const SizedBox(width: 8),
          Expanded(child: _Secim(deger: _konu, liste: konular, etiket: 'Konu', sec: (s) => setState(() => _konu = s))),
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
          itemCount: anahtarlar.length,
          itemBuilder: (_, i) {
            final l = gruplar[anahtarlar[i]]!
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

const _aylar = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
int _ayNo(String ay) {
  final i = _aylar.indexWhere((a) => ay.startsWith(a));
  return i < 0 ? 13 : i;
}

class _Secim extends StatelessWidget {
  const _Secim({required this.deger, required this.liste, required this.etiket, required this.sec});
  final String deger, etiket;
  final List<String> liste;
  final ValueChanged<String> sec;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        initialValue: deger,
        isExpanded: true,
        decoration: InputDecoration(labelText: etiket, isDense: true),
        items: [for (final s in liste) DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))],
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
