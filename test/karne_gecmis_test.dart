import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/gecmis_ozet.dart';
import 'package:yonetim_raporu/veri/karne_sapma.dart';

void main() {
  test('karne: geçmiş yıllar serisi', () {
    final g = GecmisOzet.json({
      'gostergeler': [
        {'tablo': 'Doğum oranları', 'ciftlik': 'Deneme Çiftliği ŞEKERSÜT', 'yil': 2031, 'olcu': 'Doğum Oranı', 'deger': 70.5, 'yuzde': true},
        {'tablo': 'Doğum oranları', 'ciftlik': 'Deneme Çiftliği ŞEKERSÜT', 'yil': 2030, 'olcu': 'Doğum Oranı', 'deger': 60, 'yuzde': true},
      ]
    });
    expect(gecmisSeri(g, 'Şekersüt', RegExp('Doğum'), RegExp('Doğum Oranı'), birim: ' %'), '2030 60,0 · 2031 70,5 %');
    expect(gecmisSeri(g, 'Pan-Gev', RegExp('Doğum'), RegExp('Doğum Oranı')), isNull);
  });
}
