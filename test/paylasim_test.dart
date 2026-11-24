import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/model.dart';

void main() {
  test('paylaşım verisi okunur', () {
    final v = RaporVerisi.json({
      'ok': true,
      'paylasim': {'kapsam': 'tarla', 'yetki': 'duzenle', 'etiket': 'Örnek birim'},
      'paylasimlar': [
        {'id': 'a1', 'etiket': 'Örnek birim', 'yetki': 'gor', 'acik': false, 'link': 'https://örnek/exec?anahtar=pX'},
      ],
    });
    expect(v.paylasim?.duzenler, isTrue);
    expect(v.paylasim?.etiket, 'Örnek birim');
    expect(v.paylasimlar.single.acik, isFalse);
    expect(v.paylasimlar.single.duzenler, isFalse);
    expect(RaporVerisi.json({'ok': true}).paylasim, isNull);
  });
}
