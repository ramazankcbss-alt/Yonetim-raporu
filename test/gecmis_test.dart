import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/ekranlar/gecmis.dart';
import 'package:yonetim_raporu/veri/model.dart';

void main() {
  final j = {
    'hayvanOzet': [],
    'hayvanGunluk': [],
    'tarim': [],
    'gecmis': [
      ['2024', '', 'Şekersüt', 'Süt', 'Ortalama süt verimi', '24.1', 'kg/gün/inek', 'Değ.Raporu', '448 sağılan'],
      ['2025', '', 'Şekersüt', 'Süt', 'Ortalama süt verimi', 25.2, 'kg/gün/inek', 'Değ.Raporu', ''],
      ['2025', 'Yıllık', 'Taşağıl hayvancılık', 'Kâr/zarar', 'Yıllık dönem kâr/zarar', -15752709, 'TL', 'x', ''],
      ['2021-2025', '', 'Aslım', 'Kesim', '5 yıllık kesim', 7806, 'baş', 'x', ''],
    ],
    'dersler': [
      ['2025', 'Aslım', 'Tarım', 'Buğday zarar etti.', 'Yonca/pancar daha iyi.', 'x'],
    ],
  };

  test('geçmiş kayıtları okunur', () {
    final v = RaporVerisi.json(j);
    expect(v.gecmis.length, 4);
    expect(v.gecmis.first.sayi, 24.1);
    expect(v.gecmis[3].yilNo, 2025);
    expect(gecmisDeger(v.gecmis[1]), contains('25'));
    expect(v.dersler.single.sonuc, 'Yonca/pancar daha iyi.');
    expect(kapsananYillar('2021-2025'), {2021, 2022, 2023, 2024, 2025});
    expect(kapsananYillar('2025'), {2025});
    expect(kapsananYillar(''), isEmpty);
  });

  testWidgets('geçmiş ekranı gösterir', (t) async {
    final v = RaporVerisi.json(j);
    await t.pumpWidget(MaterialApp(home: GecmisEkran(veri: v)));
    await t.pumpAndSettle();
    expect(find.text('Ortalama süt verimi'), findsOneWidget);
    expect(find.text('Yıllık dönem kâr/zarar'), findsOneWidget);
    await t.tap(find.text('2024 (2)'));
    await t.pumpAndSettle();
    expect(find.text('Ortalama süt verimi'), findsOneWidget);
    expect(find.text('Yıllık dönem kâr/zarar'), findsNothing);
    await t.tap(find.text('Dersler'));
    await t.pumpAndSettle();
    expect(find.text('Buğday zarar etti.'), findsOneWidget);
  });
}
