import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/ciftlik_rapor.dart' show raporAylari;
import '../veri/model.dart';
import '../veri/stok_suru.dart';
import 'kaynak_kapsami.dart';
import 'bilesenler.dart';
import 'gonder.dart';

/// Kaba yem türleri (sayım ton olarak özetlenir).
const _kabaYem = [('Silaj', ['SILAJ', 'SİLAJ']), ('Yonca balyası', ['YONCA']), ('Sap balyası', ['SAP BALYA'])];

/// Asistan › Stok ve Sürü: sürü hareketleri (çiftlik × ay) ve en yeni stok sayımı.
class StokSuruEkran extends StatelessWidget {
  const StokSuruEkran({super.key, required this.veri});
  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: VeriDeposu.ben,
        builder: (context, _) {
          final v = VeriDeposu.ben.veri ?? veri;
          return DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Stok ve Sürü'),
                actions: const [KaynakTablolariButonu(menuler: ['stokSuru'], baslik: 'Stok ve Sürü – kaynak tabloları'), TabloGuncelleButonu()],
                bottom: const TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Color(0xCCFFFFFF),
                  indicatorColor: Colors.white,
                  tabs: [Tab(text: 'Sürü Hareketleri'), Tab(text: 'Stok Sayımı')],
                ),
              ),
              body: TabBarView(children: [
                GonderAlani(konu: 'Sürü Hareketleri', child: _Suru(s: v.suruHareketleri)),
                GonderAlani(konu: 'Stok Sayımı', child: _Stok(s: v.stokSayimi)),
              ]),
            ),
          );
        },
      );
}

class _Suru extends StatefulWidget {
  const _Suru({required this.s});
  final SuruHareketleri s;

  @override
  State<_Suru> createState() => _SuruState();
}

class _SuruState extends State<_Suru> {
  int? _yil;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    if (s.bos) {
      return const Padding(
          padding: EdgeInsets.all(16),
          child: BilgiKutusu(yazi: "Sürü hareketleri henüz gelmedi; Apps Script güncellendiğinde 'SÜRÜ HAREKETLERİ' dosyası okunur."));
    }
    final yillar = <int>{for (final c in s.veri.values) ...c.keys}.toList()..sort((a, b) => b.compareTo(a));
    final yil = _yil ?? yillar.first;
    const st = TextStyle(fontSize: 12);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Wrap(spacing: 8, children: [
          for (final y in yillar) ChoiceChip(label: Text('$y'), selected: y == yil, onSelected: (_) => setState(() => _yil = y)),
        ]),
        const SizedBox(height: 8),
        for (final c in s.ciftlikler)
          if (s.sonAy(c, yil) > 0 && s.seri(c, yil, 'TÜM SÜRÜ').any((x) => (x ?? 0) > 0))
            Panel(
              baslik: '$c – $yil',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 12,
                    headingRowHeight: 40,
                    dataRowMinHeight: 28,
                    dataRowMaxHeight: 32,
                    headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Renk.anaKoyu),
                    columns: const [
                      DataColumn(label: Text('Ay')),
                      DataColumn(label: Text('Tüm\nsürü'), numeric: true),
                      DataColumn(label: Text('Sağmal'), numeric: true),
                      DataColumn(label: Text('Kuru'), numeric: true),
                      DataColumn(label: Text('Doğum'), numeric: true),
                      DataColumn(label: Text('Kesim'), numeric: true),
                      DataColumn(label: Text('Kayıp'), numeric: true),
                    ],
                    rows: [
                      for (var m = 1; m <= s.sonAy(c, yil); m++)
                        DataRow(cells: [
                          DataCell(Text(raporAylari[m - 1], style: st)),
                          DataCell(Text(sayi(s.deger(c, yil, m, 'TÜM SÜRÜ')), style: st)),
                          DataCell(Text(sayi(s.deger(c, yil, m, 'SAĞMAL')), style: st)),
                          DataCell(Text(sayi(s.deger(c, yil, m, 'KURU')), style: st)),
                          DataCell(Text(sayi(s.deger(c, yil, m, 'DOĞUM')), style: st)),
                          DataCell(Text(sayi(s.kesim(c, yil, m)), style: st)),
                          DataCell(Text(sayi(s.kayip(c, yil, m)),
                              style: st.copyWith(color: s.kayip(c, yil, m) > 0 ? Renk.kirmizi : null))),
                        ]),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(_hareketOzeti(s, c, yil), style: const TextStyle(fontSize: 12, color: Renk.soluk, height: 1.4)),
              ]),
            ),
        Text(
          'Kaynak: ${s.dosya.trim()}${s.guncelleme == null ? '' : ' (son değişiklik ${zamanBicim(s.guncelleme!)})'}. '
          'Sayılar aylık ortalamadır. Kayıp: ölü doğum, abort ve ölen hayvanlar. Yalnızca sayılar kullanılır.',
          style: const TextStyle(fontSize: 12, color: Renk.soluk, height: 1.4),
        ),
      ],
    );
  }
}

String _hareketOzeti(SuruHareketleri s, String c, int yil) {
  double top(bool Function(String) f) {
    var t = 0.0;
    for (final k in s.kalemler(c, yil)) {
      if (!f(k)) continue;
      for (final x in s.seri(c, yil, k)) {
        t += x ?? 0;
      }
    }
    return t;
  }

  final alim = top((k) => k.contains('ALINAN') || k.contains('GELEN'));
  final giden = top((k) => k.contains('GİDEN') || k.contains('SATILAN'));
  return 'Yıl içinde gelen / alınan ${sayi(alim)} baş, giden / satılan ${sayi(giden)} baş.';
}

class _Stok extends StatelessWidget {
  const _Stok({required this.s});
  final StokSayimi s;

  @override
  Widget build(BuildContext context) {
    if (s.bos) {
      return const Padding(
          padding: EdgeInsets.all(16),
          child: BilgiKutusu(yazi: "Stok sayımı henüz gelmedi; Apps Script güncellendiğinde en yeni 'Stok Sayımları' dosyası okunur."));
    }
    final kodlar = s.sayfalar.keys.toList()..sort();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Panel(
          baslik: 'Kaba yem stoku – ${s.donem.isEmpty ? 'son sayım' : '${s.donem} sayımı'} (ton)',
          child: Column(children: [
            for (final k in kodlar)
              if (_kabaYem.any((y) => s.toplam(k, (x) => x.birim == 'KG' && y.$2.any((a) => x.ad.toUpperCase().contains(a))) > 0))
                _Satir(
                  uretimYeriAdi(k),
                  [
                    for (final y in _kabaYem)
                      if (s.toplam(k, (x) => x.birim == 'KG' && y.$2.any((a) => x.ad.toUpperCase().contains(a))) > 0)
                        '${y.$1} ${sayi(s.toplam(k, (x) => x.birim == 'KG' && y.$2.any((a) => x.ad.toUpperCase().contains(a))) / 1000)}',
                  ].join(' · '),
                ),
          ]),
        ),
        for (final k in kodlar)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ExpansionTile(
              title: Text('${uretimYeriAdi(k)} ($k)', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${s.sayfalar[k]!.length} kalem', style: const TextStyle(fontSize: 12)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                for (final x in s.sayfalar[k]!)
                  _Satir(
                    '${x.ad}${x.grup.isEmpty ? '' : ' · ${_basHarf(x.grup)}'}',
                    '${x.sayim == null ? '—' : sayi(x.sayim, ondalik: (x.sayim! % 1) == 0 ? 0 : 2)} ${x.birim}'
                        '${(x.anacTuketim ?? 0) + (x.gencTuketim ?? 0) > 0 ? ' (tüketim ${sayi((x.anacTuketim ?? 0) + (x.gencTuketim ?? 0))})' : ''}',
                  ),
              ],
            ),
          ),
        Text(
          'Kaynak: ${s.dosya}${s.guncelleme == null ? '' : ' (son değişiklik ${zamanBicim(s.guncelleme!)})'}. '
          'Açıklama sütunları okunmaz; yalnızca malzeme, birim, sayım ve tüketim miktarları kullanılır.',
          style: const TextStyle(fontSize: 12, color: Renk.soluk, height: 1.4),
        ),
      ],
    );
  }
}

String _basHarf(String s) {
  final k = s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase().trim();
  return k.isEmpty ? k : '${k[0].toUpperCase()}${k.substring(1)}';
}

class _Satir extends StatelessWidget {
  const _Satir(this.etiket, this.deger);
  final String etiket, deger;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(etiket, style: const TextStyle(color: Renk.soluk, fontSize: 13.5))),
          const SizedBox(width: 8),
          Flexible(child: Text(deger, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500))),
        ]),
      );
}
