import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/hasat_durumu.dart';

void main() {
  test('hasat durumu: ürüne özel kayıt "Tümü"den önce gelir', () {
    final l = HasatKaydi.liste([
      {'sezon': 2030, 'urun': 'Tümü', 'tamam': true},
      {'sezon': 2030, 'urun': 'Yonca', 'tamam': false},
      {'sezon': 2029, 'urun': 'Buğday', 'tamam': true},
    ]);
    expect(hasatTamam(l, 2030, 'Şeker Pancarı'), isTrue);
    expect(hasatTamam(l, 2030, 'Yonca'), isFalse);
    expect(hasatTamam(l, 2031, 'Buğday'), isFalse);
    expect(sezonYili('2030-2031'), 2030);
  });
}
