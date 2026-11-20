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
    'hasat': [
      ['Patates', 'Taşağıl', '400', '1954747', '4887', '22.10.2026'],
    ],
  });

  test('KMZ sezonu okunur ve icmalle karşılaştırılır', () {
    expect(s.sezon, '2025-2026');
    final sk = s.ciftlikler.firstWhere((c) => c.ad == 'Şekersüt');
    expect(sk.urunToplami['Buğday'], 1700);
    final k = ekimKarsilastir(s, v.ekim);
    expect(k.firstWhere((x) => x.ciftlik == 'Şekersüt' && x.urun == 'Buğday').durum, 'Uyumlu');
    final m = k.firstWhere((x) => x.ciftlik == 'Şekersüt' && x.urun == 'Silajlık mısır');
    expect(m.durum, 'Fark');
    expect(m.fark, 60);
    expect(k.firstWhere((x) => x.ciftlik == 'Aslım' && x.urun == 'Arpa').fark, -235);
    final p4 = sk.parseller.firstWhere((p) => p.ad == '4. pivot');
    expect(parselKayitlari(sk, p4, v.tarim).length, 1);
    expect(urunAnahtari('MISIR SİLAJI'), 'Silajlık mısır');
    expect(parselCks(sk, sk.parseller.first, v.cks, s.sezon).length, 1);
    expect(s.ciftlikler.any((c) => c.ad.startsWith('Pangev')), isFalse);
    expect(planYillari(v.ekimPlani), ['2026', '2027']);
    expect(resmiKarsilastir(s, v.resmiParsel).any((e) => e.$2 == 'Buğday' && e.$3 == 721), isTrue);
  });

  testWidgets('Tarla Haritası ekranı', (t) async {
    t.view.physicalSize = const Size(1600, 3200);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: TarlaEkran(veri: v, sezonlar: [s])));
    await t.pumpAndSettle();
    expect(find.text('Tarla Haritası 2025-2026'), findsOneWidget);
    expect(find.text('Ekiliş özeti'), findsOneWidget);
    await t.tap(find.text('Karşılaştırma'));
    await t.pumpAndSettle();
    expect(find.text('Tutarsızlıklar: harita ve tarım icmali'), findsOneWidget);
    expect(find.textContaining('Şekersüt · Silajlık mısır'), findsWidgets);
    await t.tap(find.text('Uyumlu'));
    await t.pumpAndSettle();
    expect(find.text('Olumlu: uyumlu olanlar'), findsOneWidget);
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
  });
}
