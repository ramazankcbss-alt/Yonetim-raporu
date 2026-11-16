import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/ekranlar/bakim_onarim.dart';
import 'package:yonetim_raporu/veri/model.dart';

void main() {
  final j = <String, dynamic>{
    'hayvanOzet': [],
    'hayvanGunluk': [],
    'tarim': [],
    'bakimOnarim': [
      ['1', '16.11.2026 18:25', 'Aslım', 'Bakım onarım personeli', 'Traktör', 'Arıza onarımı', '',
        'Motor rektefiye', 'Motor iç parçaları', 'Tedarik bekleniyor', 'İç ekip', 'Parça bekleniyor',
        'Evet', '16.11.2026'],
      ['2', '17.11.2026 09:10', 'Pankent', 'Formen', 'Manitou', 'Periyodik bakım', '1250',
        'Yağ ve filtre değişimi', 'Motor yağı 15 lt', 'Tedarik edildi', 'İç ekip', 'Tamamlandı', '', ''],
      ['', '', '', '', '', '', '', '', '', '', '', '', '', ''],
    ],
  };

  test('bakım onarım kayıtları okunur; onay bekleyen özetlere girmez', () {
    final v = RaporVerisi.json(j);
    final o = v.bakimOnarim;
    expect(o.kayitlar.length, 2);
    expect(o.kayitlar.first.makine, 'Manitou'); // yeniden eskiye
    expect(o.onayli.single.makine, 'Traktör');
    expect(o.onayBekleyen.single.makine, 'Manitou');
    expect(o.acik.single.no, '1');
    expect(o.tedarikBekleyen.single.no, '1');
    expect(o.islemDagilimi.single.key, 'Arıza onarımı');
    expect(o.ciftlikler, ['Aslım', 'Pankent']);
  });

  testWidgets('bakım onarım ekranı açılır', (t) async {
    await t.pumpWidget(MaterialApp(home: BakimOnarimEkran(veri: RaporVerisi.json(j))));
    expect(find.text('Onaylı kayıt'), findsOneWidget);
    expect(find.text('Onay bekliyor'), findsOneWidget);
    await t.tap(find.text('Onay bekleyen').last);
    await t.pump();
    expect(find.text('Traktör – Arıza onarımı'), findsNothing);
    expect(find.text('Manitou – Periyodik bakım'), findsOneWidget);
  });
}
