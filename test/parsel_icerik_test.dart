// Örnek (test amaçlı) değerler.
import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/tarla.dart';

void main() {
  test('Parsel içeriği: tek ürün, bölünmüş, birleşik', () {
    expect(ParselIcerik.oku('Arpa').parcalar, [('Arpa', null)]);
    final b = ParselIcerik.oku('Arpa:120+Buğday:80,5');
    expect(b.bolunmus, isTrue);
    expect(b.parcalar, [('Arpa', 120.0), ('Buğday', 80.5)]);
    final m = ParselIcerik.oku('Yonca@7. pivot');
    expect(m.birlesik, '7. pivot');
    expect(m.urun, 'Yonca');
    expect(ParselIcerik.bolunmusMetin([('Arpa', 120), ('Buğday', 80.5)]), 'Arpa:120+Buğday:80.5');
    expect(ParselIcerik.oku(ParselIcerik.bolunmusMetin([('Arpa', 120), ('Buğday', 80.5)])).parcalar.last, ('Buğday', 80.5));
  });
}
