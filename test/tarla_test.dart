import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/ekranlar/tarla.dart';
import 'package:yonetim_raporu/veri/model.dart';
import 'package:yonetim_raporu/veri/tarla.dart';

void main() {
  final s = TarlaSezonu.json(jsonDecode(File('assets/veri/tarla_2025_2026.json').readAsStringSync()));
  final v = RaporVerisi.json({
    'hayvanOzet': [], 'hayvanGunluk': [],
    'tarim': [
      ['2026-11-14', 'Şekersüt', 'Şeker pancarı sökümü devam ediyor: 425 dekar (4. pivot)'],
    ],
    'ekim': [
      ['Şekersüt', 'Buğday (dane)', '1700', '1700'],
      ['Şekersüt', 'Silajlık mısır', '670', '670'],
      ['Aslım', 'Arpa', '1340', '1340'],
      ['Taşağıl', 'Patates', '400', '400'],
    ],
    'ekimDuzeltme': [
      ['2025-2026', 'Aslım', 'Arpa', 'Harita doğru', '1105', 'Test', '20.11.2026', 'Aktif'],
    ],
    'ekimPlani': [
      ['2026', 'Şekersüt', 'Buğday', '1700'],
      ['2027', 'Şekersüt', 'Buğday', '900'],
    ],
    'resmiParsel': [
      ['Şekersüt', 'ÇUMRA', 'FETHİYE', '143', '7', '721', 'BUĞDAY'],
    ],
    'cks': [
      ['2025-2026', 'Şekersüt', 'Çumra / Örnek', '101', '5', 'Buğday', '800', '1. pivot', 'CKS_x.pdf', '20.11.2026'],
    ],
    'sezonParsel': [
      ['2026-2027', 'Şekersüt', '1. pivot', 'Buğday', '450', '20.11.2026', 'Aktif'],
      ['2026-2027', 'Şekersüt', '4. pivot', 'Arpa', '', '20.11.2026', 'Güncellendi'],
      ['2026-2027', 'Şekersüt', '4. pivot', 'Buğday', '300', '20.11.2026', 'Aktif'],
    ],
    'hasat': [
      ['Patates', 'Taşağıl', '400', '1954747', '4887', '22.10.2026'],
    ],
  });

  test('KMZ sezonu okunur ve icmalle karşılaştırılır', () {
    expect(s.sezon, '2025-2026');
    final sk = s.ciftlikler.firstWhere((c) => c.ad == 'Şekersüt');
    expect(sk.urunToplami['Buğday'], 1700);
    final t = excelKarsilastir(s, v.ekim, v.resmiParsel, v.cks);
    final b = t.firstWhere((x) => x.ciftlik == 'Şekersüt' && x.urun == 'Buğday');
    expect(b.esas, 1700);
    expect(b.haritada, isTrue);
    expect(b.resmiFarkli, isTrue); // PARSEL 721 / plan 1700
    expect(b.cksFarkli, isTrue); // ÇKS 800 / plan 1700
    // Haritadaki dekar (730) dikkate alınmaz: Excel 670, haritada ekili → uyumlu.
    expect(t.firstWhere((x) => x.ciftlik == 'Şekersüt' && x.urun == 'Silajlık mısır').uyumlu, isTrue);
    expect(t.firstWhere((x) => x.ciftlik == 'Aslım' && x.urun == 'Arpa').uyumlu, isTrue);
    expect(t.firstWhere((x) => x.ciftlik == 'Aslım' && x.urun == 'Yonca').excelYok, isTrue);
    expect(excelAlanlari(v.ekim, 'Taşağıl')['Patates'], 400);
    expect(sk.parseller.first.urunCinsi.contains(' da'), isFalse);
    final p4 = sk.parseller.firstWhere((p) => p.ad == '4. pivot');
    expect(parselKayitlari(sk, p4, v.tarim).length, 1);
    expect(urunAnahtari('MISIR SİLAJI'), 'Silajlık mısır');
    expect(parselCks(sk, sk.parseller.first, v.cks, s.sezon).length, 1);
    expect(s.ciftlikler.any((c) => c.ad.startsWith('Pangev')), isFalse);
    expect(planYillari(v.ekimPlani), ['2026', '2027']);
    expect(aktifDuzeltme(v.ekimDuzeltme, s.sezon, 'Aslım', 'Arpa')?.deger, 1105);
    expect(aktifDuzeltme(v.ekimDuzeltme, s.sezon, 'Aslım', 'Buğday'), isNull);
  });

  test('Haritadan yeni sezon girişi', () {
    expect(sonrakiSezon('2025-2026'), '2026-2027');
    final y = girisSezonu(s, v.sezonParsel);
    expect(y.sezon, '2026-2027');
    expect(y.giris, isTrue);
    expect(y.uretimYili, '2027');
    final sk = y.ciftlikler.firstWhere((c) => c.ad == 'Şekersüt');
    expect(sk.urunToplami['Buğday'], 750);
    expect(sk.parseller.firstWhere((p) => p.ad == '4. pivot').urunYazi, 'Buğday 300 da');
    expect(sk.parseller.firstWhere((p) => p.ad == '2. pivot').girilmedi, isTrue);
    expect(oncekiUrunler(y, 'Şekersüt', '1. pivot'), ['Buğday']);
    expect(yilPlani(v.ekimPlani, '2027', 'Şekersüt')['Buğday'], 900);
    expect(parselGirisi(v.sezonParsel, '2026-2027', 'Şekersüt', '4. pivot')?.alan, 300);
  });

  testWidgets('Tarla Haritası ekranı', (t) async {
    t.view.physicalSize = const Size(1600, 3200);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: TarlaEkran(veri: v, sezonlar: [s])));
    await t.pumpAndSettle();
    expect(find.text('Tarla Haritası 2025-2026'), findsOneWidget);
    expect(find.text('Ekiliş özeti'), findsOneWidget);
    expect(find.text('1.700 da'), findsWidgets); // Excel alanı
    expect(find.textContaining('Parsele dokunarak 2026-2027'), findsOneWidget);
    await t.tap(find.text('Karşılaştırma'));
    await t.pumpAndSettle();
    expect(find.text('Tutarsızlıklar: Excel esas alınarak'), findsOneWidget);
    expect(find.textContaining('Şekersüt · Buğday'), findsWidgets);
    await t.tap(find.text('Uyumlu'));
    await t.pumpAndSettle();
    expect(find.text('Olumlu: uyumlu olanlar'), findsOneWidget);
        expect(find.text('Excel esaslı ekim alanları (da)'), findsOneWidget);
    expect(find.text('Düzelt'), findsWidgets);
    await t.tap(find.text('Parseller'));
    await t.pumpAndSettle();
    expect(find.text('Çiftlikler'), findsOneWidget);
    await t.tap(find.text('Şekersüt'));
    await t.pumpAndSettle();
    expect(find.textContaining("ÇKS'de bildirildi"), findsWidgets);
    expect(find.textContaining('Resmî parsel kayıtları'), findsOneWidget);
    expect(find.text('Bu bulguyu gönder'), findsOneWidget);
    await t.tap(find.text('4. pivot'));
    await t.pumpAndSettle();
    expect(find.textContaining('Tarım icmali kayıtları'), findsOneWidget);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    await t.tap(find.text('ÇKS'));
    await t.pumpAndSettle();
    expect(find.text('Fotoğraf çek'), findsOneWidget);
    await t.tap(find.text('2025-2026 sezonu'));
    await t.pumpAndSettle();
    await t.tap(find.text('Şekersüt'));
    await t.pumpAndSettle();
    expect(find.textContaining('Ada 101 / Parsel 5'), findsOneWidget);
  });

  testWidgets('Yeni sezon haritası', (t) async {
    t.view.physicalSize = const Size(1600, 3200);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: TarlaEkran(veri: v, sezonlar: [s])));
    await t.pumpAndSettle();
    await t.tap(find.text('2026-2027 sezonu haritasını aç'));
    await t.pumpAndSettle();
    expect(find.text('Tarla Haritası 2026-2027'), findsOneWidget);
    expect(find.textContaining('Ürün girilmemiş parsel'), findsOneWidget);
    await t.tap(find.text('Karşılaştırma'));
    await t.pumpAndSettle();
    expect(find.text('Girilen alanlar ve Excel planı (da)'), findsOneWidget);
    expect(find.textContaining('Aynı ürün üst üste'), findsWidgets);
  });
}
