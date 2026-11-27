import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/kaynak_envanteri.dart';

void main() {
  test('kaynak tabloları: menü, sayfa ve bloklar', () {
    final k = KaynakTablolari.json({
      'menuler': {
        'gecmis': [
          {
            'grup': 'Deneme raporu',
            'dosya': 'D',
            'sayfa': 'S1',
            'bloklar': [
              {
                'satirlar': [
                  ['Başlık', '2030'],
                  ['A', '10']
                ]
              },
              {
                'satirlar': [
                  ['Not']
                ]
              }
            ]
          }
        ]
      }
    });
    expect(k.menu('gecmis').single.bloklar.length, 2);
    expect(k.menu('gecmis').single.bloklar.first[1], ['A', '10']);
    expect(k.menu('esk'), isEmpty);
  });
}
