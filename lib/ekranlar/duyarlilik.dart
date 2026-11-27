import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bicim.dart';
import '../tema.dart';
import '../veri/duyarlilik.dart';
import '../veri/model.dart';
import '../veri/urun_karlilik.dart';
import '../veri/urun_takip.dart';
import 'bilesenler.dart';
import 'gonder.dart';
import 'urun_karlilik.dart' show maliyetTakipVerisi;

const kSenaryoAnahtari = 'duyarlilik_senaryolari';
String _mn(double v) => '${v < 0 ? '−' : v > 0 ? '+' : ''}${sayi(v.abs() / 1e6, ondalik: 2)} mn ₺';

List<DuyarlilikDegiskeni> veridenDegiskenler(RaporVerisi v) {
  final mt = maliyetTakipVerisi();
  final tarim = v.tarimsalUretim.bos
      ? null
      : UrunKarlilik.hesapla(plan: v.tarimsalUretim, mt: mt, gelir: v.mali.gelirGider, teslimat: UrunTakibi(v.tarimsalUretim, v.urunTeslimat));
  return duyarlilikDegiskenleri(faturalar: v.mali.gelirGider, tarim: tarim, mt: mt);
}

Future<List<DuyarlilikSenaryosu>> kayitliSenaryolar() async =>
    DuyarlilikSenaryosu.listeOku((await SharedPreferences.getInstance()).getString(kSenaryoAnahtari));

/// Yönetim Özeti › Duyarlılık analizi.
class DuyarlilikEkran extends StatefulWidget {
  const DuyarlilikEkran({super.key, required this.veri});
  final RaporVerisi veri;

  @override
  State<DuyarlilikEkran> createState() => _DuyarlilikEkranState();
}

class _DuyarlilikEkranState extends State<DuyarlilikEkran> {
  final Map<String, double> _y = {};
  List<DuyarlilikSenaryosu> _kayitli = const [];

  @override
  void initState() {
    super.initState();
    kayitliSenaryolar().then((l) => mounted ? setState(() => _kayitli = l) : null);
  }

  Future<void> _kaydet() async {
    final ad = await showDialog<String>(
      context: context,
      builder: (c) {
        final t = TextEditingController();
        return AlertDialog(
          title: const Text('Senaryoyu kaydet'),
          content: TextField(controller: t, autofocus: true, decoration: const InputDecoration(labelText: 'Senaryo adı')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(c, t.text.trim()), child: const Text('Kaydet')),
          ],
        );
      },
    );
    if (ad == null || ad.isEmpty) return;
    final l = [..._kayitli.where((s) => s.ad != ad), DuyarlilikSenaryosu(ad, Map.of(_y))];
    await (await SharedPreferences.getInstance()).setString(kSenaryoAnahtari, DuyarlilikSenaryosu.listeYaz(l));
    setState(() => _kayitli = l);
  }

  Future<void> _sil(DuyarlilikSenaryosu s) async {
    final l = [..._kayitli.where((x) => x.ad != s.ad)];
    await (await SharedPreferences.getInstance()).setString(kSenaryoAnahtari, DuyarlilikSenaryosu.listeYaz(l));
    setState(() => _kayitli = l);
  }

  @override
  Widget build(BuildContext context) {
    final d = veridenDegiskenler(widget.veri);
    final toplam = DuyarlilikSenaryosu('', _y).etki(d);
    return Scaffold(
      appBar: AppBar(title: const Text('Duyarlılık Analizi')),
      body: d.isEmpty
          ? const Padding(padding: EdgeInsets.all(16), child: BilgiKutusu(yazi: 'Gelir ve gider tabloları henüz gelmedi.'))
          : GonderAlani(
              konu: 'Duyarlılık Analizi',
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
                Panel(
                  baslik: 'Net sonuca etkisi',
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(_mn(toplam),
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: toplam >= 0 ? Renk.yesil : Renk.kirmizi)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 4, children: [
                      OutlinedButton(
                          onPressed: () => setState(() => _y
                            ..clear()
                            ..addAll(kOrnekSenaryo.yuzdeler)),
                          child: Text(kOrnekSenaryo.ad)),
                      OutlinedButton(onPressed: () => setState(_y.clear), child: const Text('Sıfırla')),
                      FilledButton.icon(
                          onPressed: _y.values.any((x) => x != 0) ? _kaydet : null,
                          icon: const Icon(Icons.save_outlined, size: 18),
                          label: const Text('Kaydet')),
                    ]),
                  ]),
                ),
                for (final x in d)
                  Panel(
                    baslik: x.ad,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text('Baz: ${sayi(x.baz / 1e6, ondalik: 2)} mn ₺ · ${x.donem}', style: const TextStyle(fontSize: 12, color: Renk.soluk)),
                      Row(children: [
                        Expanded(
                          child: Slider(
                            value: _y[x.anahtar] ?? 0,
                            min: -30,
                            max: 30,
                            divisions: 60,
                            label: '%${sayi(_y[x.anahtar] ?? 0)}',
                            onChanged: (v) => setState(() => _y[x.anahtar] = v),
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: Text(
                            '${(_y[x.anahtar] ?? 0) >= 0 ? '+' : '−'}%${sayi((_y[x.anahtar] ?? 0).abs())} → ${_mn(x.etki(_y[x.anahtar] ?? 0))}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                if (_kayitli.isNotEmpty)
                  Panel(
                    baslik: 'Kayıtlı senaryolar',
                    child: Column(children: [
                      for (final s in _kayitli)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.ad),
                          subtitle: Text([
                            for (final e in s.yuzdeler.entries)
                              if (e.value != 0) '${d.where((x) => x.anahtar == e.key).firstOrNull?.ad ?? e.key} ${e.value >= 0 ? '+' : '−'}%${sayi(e.value.abs())}',
                          ].join(' · ')),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(_mn(s.etki(d)), style: TextStyle(fontWeight: FontWeight.w700, color: s.etki(d) >= 0 ? Renk.yesil : Renk.kirmizi)),
                            IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Sil', onPressed: () => _sil(s)),
                          ]),
                          onTap: () => setState(() => _y
                            ..clear()
                            ..addAll(s.yuzdeler)),
                        ),
                    ]),
                  ),
                const Text(
                  'Etki, baz tutarın seçilen oranda değişmesiyle hesaplanır; diğer kalemler sabit kabul edilir. Gelir ve gider kalemleri '
                  'yıl başından bugüne, ürün fiyatları hasat sezonu planına dayanır; bu yüzden toplam etki farklı dönemleri birleştirir. '
                  'Kayıtlı senaryolar aylık yönetim raporuna eklenir.',
                  style: TextStyle(fontSize: 12, color: Renk.soluk, height: 1.4),
                ),
              ]),
            ),
    );
  }
}
