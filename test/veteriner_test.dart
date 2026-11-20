import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/ekranlar/veteriner.dart';
import 'package:yonetim_raporu/veri/model.dart';

void main() {
  final j = <String, dynamic>{
    'hayvanOzet': [],
    'hayvanGunluk': [],
    'tarim': [],
    'veteriner': {
      'acik': true,
      'kodlar': [
        ['K7M2PRT4', 'Şekersüt veteriner hekimi', '18.11.2026 17:30', 'Aktif', ''],
        ['ZZ99AA22', 'Aslım veteriner hekimi', '18.11.2026 17:31', 'Kapalı', '18.11.2026 17:40'],
      ],
      'bildirimler': [
        {
          'satir': 3,
          'tarih': '18.11.2026 17:45',
          'etiket': 'Şekersüt veteriner hekimi',
          'bolum': 'Hastalık Dağılımı',
          'konu': 'Solunum/pnömoni · etken ve önleme tedbirleri',
          'degerlendirme': 'Eksik',
          'aciklama': 'Mycoplasma bovis için süt kültürü önerisi eklenmeli.',
          'durum': 'Yeni',
          'kod': 'K7M2PRT4',
          'yanit': ''
        },
      ],
    },
  };

  test('veteriner verisi okunur', () {
    final v = RaporVerisi.json(j);
    expect(v.vetPanelAcik, isTrue);
    expect(v.vetKodlari, hasLength(2));
    expect(v.vetKodlari.first.aktif, isTrue);
    expect(v.vetKodlari.last.sonGiris, '18.11.2026 17:40');
    final b = v.vetBildirimleri.single;
    expect(b.satir, 3);
    expect(b.yeni, isTrue);
    expect(b.degerlendirme, 'Eksik');
    expect(RaporVerisi.json({'hayvanOzet': [], 'hayvanGunluk': [], 'tarim': []}).vetKodlari, isEmpty);
  });

  testWidgets('veteriner ekranı bildirim ve kodları gösterir', (t) async {
    t.view.physicalSize = const Size(1200, 2600);
    t.view.devicePixelRatio = 1.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: VeterinerEkran(veri: RaporVerisi.json(j))));
    await t.pumpAndSettle();
    expect(find.text('Bildirimler (1 yeni)'), findsOneWidget);
    expect(find.text('Solunum/pnömoni · etken ve önleme tedbirleri'), findsOneWidget);
    await t.tap(find.text('Erişim kodları'));
    await t.pumpAndSettle();
    expect(find.text('Şekersüt veteriner hekimi'), findsOneWidget);
    expect(find.text('Yeni erişim kodu oluştur'), findsOneWidget);
  });
}
