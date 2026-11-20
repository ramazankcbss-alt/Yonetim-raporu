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
    await t.tap(find.text('Parseller'));
    await t.pumpAndSettle();
    expect(find.text('Tarım icmali (son kayıtlar):'), findsWidgets);
  });
}
