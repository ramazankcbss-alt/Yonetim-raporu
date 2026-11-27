import 'package:flutter/material.dart';

import '../bicim.dart';
import '../tema.dart';
import '../veri/gecmis_ozet.dart';
import '../veri/model.dart';
import 'bilesenler.dart';
import 'esk.dart' show tl;

const _tabloAdi = {
  'tarım 5yıllık kazanç': 'Tarım net geliri',
  'süt verimliliği': 'Süt verimliliği',
  'Ölüm oranları': 'Ölüm sayıları ve oranları',
};

/// Geçmiş Yıllar › Yıllık göstergeler: kesim ve canlı hayvan alımı (2021–2026) ile değerlendirme raporu tabloları.
class GecmisOzetGovde extends StatelessWidget {
  const GecmisOzetGovde({super.key, required this.veri});
  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) {
    final o = veri.gecmisOzet;
    if (o.bos) {
      return const Padding(
          padding: EdgeInsets.all(16),
          child: BilgiKutusu(yazi: 'Yıllık göstergeler henüz gelmedi. Apps Script güncel olmalı.'));
    }
    final yillar = o.kesimYillari;
    final ciftlikler = {for (final k in o.kesim) k.ciftlik}.toList();
    GecmisKesim? bul(String c, int y) {
      for (final k in o.kesim) {
        if (k.ciftlik == c && k.yil == y) return k;
      }
      return null;
    }

    double yilTop(int y, double Function(GecmisKesim) f) =>
        o.kesim.where((k) => k.yil == y).fold(0.0, (t, k) => t + f(k));
    final alimYil = ({for (final a in o.alim) a.yil}.toList()..sort());
    final alimCiftlik = {for (final a in o.alim) a.ciftlik}.toList();
    final notlar = {for (final k in o.kesim) if (k.donem.isNotEmpty) k.yil: k.donem};

    return ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 24), children: [
      const BilgiKutusu(
          yazi: 'Kaynak: "2021–2026 Yılları Çiftlikler Kesim Özet" ve "Çiftlikler Değerlendirme Raporu 31.12.2025". '
              'Personel ve organizasyon sayfaları alınmaz.'),
      for (final h in o.hatalar)
        Padding(padding: const EdgeInsets.only(top: 6), child: BilgiKutusu(uyari: true, yazi: 'Okunamadı: $h')),
      if (o.kesim.isNotEmpty) ...[
        const BolumBasligi('Kesim – yıllara göre', ikon: Icons.set_meal_outlined,
            aciklama: 'Erkek dana, inek ve düve toplamı; karkas kg ve kesim satışı.'),
        VeriTablosu(
          basliklar: const ['Yıl', 'Adet', 'Karkas (ton)', 'Ort. karkas kg', 'Kesim satışı'],
          ilkSutunGenislik: 110,
          satirlar: [
            for (final y in yillar)
              [
                '$y${notlar[y] == null ? '' : ' (${notlar[y]})'}',
                sayi(yilTop(y, (k) => k.adet)),
                sayi(yilTop(y, (k) => k.karkas) / 1000, ondalik: 1),
                sayi(yilTop(y, (k) => k.adet) > 0 ? yilTop(y, (k) => k.karkas) / yilTop(y, (k) => k.adet) : null),
                tl(yilTop(y, (k) => k.satis ?? 0)),
              ],
          ],
        ),
        const BolumBasligi('Kesim adedi – çiftlik × yıl', ikon: Icons.grid_on),
        VeriTablosu(
          basliklar: ['Çiftlik', for (final y in yillar) '$y'],
          ilkSutunGenislik: 90,
          satirlar: [
            for (final c in ciftlikler) [c, for (final y in yillar) sayi(bul(c, y)?.adet, bos: '—')],
          ],
        ),
      ],
      if (o.alim.isNotEmpty) ...[
        const BolumBasligi('Canlı hayvan alımı (iç + dış)', ikon: Icons.local_shipping_outlined),
        VeriTablosu(
          basliklar: ['Çiftlik', for (final y in alimYil) '$y'],
          ilkSutunGenislik: 90,
          satirlar: [
            for (final c in alimCiftlik)
              [
                c,
                for (final y in alimYil)
                  () {
                    final a = o.alim.where((x) => x.ciftlik == c && x.yil == y);
                    if (a.isEmpty) return '—';
                    final x = a.first;
                    return '${sayi(x.toplam)} (${sayi(x.ic)}+${sayi(x.dis)})';
                  }(),
              ],
          ],
        ),
        const SizedBox(height: 4),
        const Text('Parantez içi: iç alım + dış alım.', style: TextStyle(fontSize: 12, color: Renk.soluk)),
      ],
      for (final t in o.tablolar) ..._matris(o, t),
    ]);
  }

  List<Widget> _matris(GecmisOzet o, String tablo) {
    final m = o.matris(tablo);
    final out = <Widget>[BolumBasligi(_tabloAdi[tablo] ?? tablo, ikon: Icons.table_chart_outlined)];
    final paraMi = tablo.contains('kazanç');
    for (final olcu in m.entries) {
      final yillar = ({for (final c in olcu.value.values) ...c.keys}.toList()..sort());
      final yuzde = olcu.key.toLowerCase().contains('oran');
      out
        ..add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Text(olcu.key, style: const TextStyle(fontWeight: FontWeight.w700, color: Renk.anaKoyu)),
        ))
        ..add(VeriTablosu(
          basliklar: ['Çiftlik', for (final y in yillar) '$y'],
          ilkSutunGenislik: 90,
          satirlar: [
            for (final c in olcu.value.entries)
              [
                c.key,
                for (final y in yillar)
                  c.value[y] == null
                      ? '—'
                      : paraMi && !olcu.key.contains('alan')
                          ? tl(c.value[y])
                          : yuzde
                              ? '%${sayi(c.value[y], ondalik: 1)}'
                              : sayi(c.value[y], ondalik: c.value[y]! % 1 == 0 ? 0 : 1),
              ],
          ],
        ));
    }
    return out;
  }
}
