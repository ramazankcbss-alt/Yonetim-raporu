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

  test('Parça başka parsele bağlanır', () {
    final m = ParselIcerik.bolunmusMetin([('Arpa', 12), ('Buğday', 90)], [(10, 20)], ['1. parsel', null]);
    expect(m, 'Arpa>1. parsel:12+Buğday:90/10,20');
    final ic = ParselIcerik.oku(m);
    expect(ic.parcalar, [('Arpa', 12.0), ('Buğday', 90.0)]);
    expect(ic.bag(0), '1. parsel');
    expect(ic.bag(1), isNull);
    expect(ic.cizgiler, [(10.0, 20.0)]);
  });

  test('Tohum / çeşit adı okunur ve yazılır', () {
    final tek = ParselIcerik.oku('Buğday#Altındane');
    expect(tek.urun, 'Buğday');
    expect(tek.cesit(0), 'Altındane');
    expect(ParselIcerik.urunMetni('Buğday', 'Halis'), 'Buğday#Halis');
    final b = ParselIcerik.oku(ParselIcerik.bolunmusMetin([('Arpa', 10), ('Buğday', 20)], [], ['1. parsel', null], ['Touareg', 'Halis']));
    expect(b.parcalar, [('Arpa', 10.0), ('Buğday', 20.0)]);
    expect(b.cesit(0), 'Touareg');
    expect(b.cesit(1), 'Halis');
    expect(b.bag(0), '1. parsel');
    final m = ParselIcerik.oku('Yonca#Magnum@7. pivot');
    expect(m.urun, 'Yonca');
    expect(m.cesit(0), 'Magnum');
    expect(m.birlesik, '7. pivot');
  });

  test('çizilen bölgeler (dikdörtgen, daire, noktalar) kaydedilip okunur', () {
    final metin = ParselIcerik.bolunmusMetin([('Deneme alanı', 5), ('Ağaçlık alan', 3), ('Buğday', 40)], [], [], [], [
      ('D', [10, 10, 40, 30]),
      ('C', [60, 50, 15, 20]),
    ]);
    expect(metin, 'Deneme alanı:5+Ağaçlık alan:3+Buğday:40/BD10,10,40,30;C60,50,15,20');
    final ic = ParselIcerik.oku(metin);
    expect(ic.parcalar, [('Deneme alanı', 5.0), ('Ağaçlık alan', 3.0), ('Buğday', 40.0)]);
    expect(ic.cizgiler, isEmpty);
    expect([for (final b in ic.bolgeler) b.$1], ['D', 'C']);
    expect(ic.bolgeler[0].$2, [10.0, 10.0, 40.0, 30.0]);
    expect(ic.bolgeler[1].$2, [60.0, 50.0, 15.0, 20.0]);
    final p = ParselIcerik.oku('Boş alan:2+Arpa:20/BP10,10,30,10,20,40');
    expect(p.bolgeler.single.$1, 'P');
    expect(p.bolgeler.single.$2.length, 6);
    // Eski çizgi kaydı bozulmaz.
    expect(ParselIcerik.oku('Arpa:10+Buğday:20/37,52').cizgiler, [(37.0, 52.0)]);
  });
}
