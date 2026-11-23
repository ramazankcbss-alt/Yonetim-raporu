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

  test('Ayırma çizgileri okunur ve yazılır', () {
    final m = ParselIcerik.bolunmusMetin([('Arpa', 100), ('Buğday', 50)], [(37.4, 52.2)]);
    expect(m, 'Arpa:100+Buğday:50/37,52');
    final ic = ParselIcerik.oku(m);
    expect(ic.parcalar, [('Arpa', 100.0), ('Buğday', 50.0)]);
    expect(ic.cizgiler, [(37.0, 52.0)]);
    expect(ParselIcerik.oku('Arpa:1+Buğday:2+Yonca:3/10,30;10,70').cizgiler.length, 2);
  });
}
