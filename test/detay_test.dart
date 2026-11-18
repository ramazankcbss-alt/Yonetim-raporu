import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/detay.dart';
import 'package:yonetim_raporu/veri/model.dart';

void main() {
  final v = RaporVerisi(ozet: const [], gunluk: const [], tarim: const [], detay: [
    DetaySatir(DateTime(2026, 11, 16), 'Erentepe Şube', 'hayvan sayisi', 'toplam hayv.say.', 287),
    DetaySatir(DateTime(2026, 11, 16), 'Erentepe Şube', 'suruden cikanlar', 'ölen inek', 1),
    DetaySatir(DateTime(2026, 11, 16), 'Erentepe Şube', 'sut (kg)', 'sagilan', 3200),
    DetaySatir(DateTime(2026, 11, 16), 'Erentepe Şube', 'performans gostert', 'calisan pers.says.', 6),
    DetaySatir(DateTime(2026, 11, 17), 'Erentepe Şube', 'hayvan sayisi', 'toplam hayv.say.', 286),
    DetaySatir(DateTime(2026, 11, 17), 'Erentepe Şube', 'suruden cikanlar', 'olu dogum', 1),
    DetaySatir(DateTime(2026, 11, 17), 'Erentepe Şube', 'sut (kg)', 'sagilan', 3400),
    DetaySatir(DateTime(2026, 11, 17), 'Erentepe Şube', 'disiler', 'bugun dogan buzagi', 2),
    DetaySatir(DateTime(2026, 11, 17), 'Erentepe Şube', 'performans gostert', 'calisan pers.says.', 6),
    DetaySatir(DateTime(2026, 11, 17), 'ESK-Taşağıl Çiftliği', 'SÜRÜDEN ÇIKANLAR', 'Ölen ithal Besi Danası', 3),
  ]);
  final bas = DateTime(2026, 11, 16), son = DateTime(2026, 11, 22);

  test('Dönem özeti: akış toplanır, hayvan sayısı son günden', () {
    final b = isletmeDetayi(v, 'Erentepe Şube', bas, son);
    final hayvan = b.firstWhere((x) => x.ad == 'Hayvan Sayıları');
    expect(hayvan.satirlar.single.etiket, 'Toplam hayvan');
    expect(hayvan.satirlar.single.deger, 286);
    final sut = b.firstWhere((x) => x.ad == 'Süt Üretimi (kg)');
    expect(sut.satirlar.single.deger, 6600);
    final cikan = b.firstWhere((x) => x.ad == 'Sürüden Çıkanlar');
    expect(cikan.satirlar.map((s) => s.etiket), ['Ölen inek', 'Ölü doğum']);
    expect(b.last.ad, 'Personel Sayıları');
  });

  test('Oran satırları alınmaz', () {
    expect(DetaySatir.oku(['2026-11-06', 'Aslım Çiftliği', 'ASLIM ÇİFTLİĞİ', 'Ölüm/Hayvan Sayısı', '0,02']), isNull);
    expect(DetaySatir.oku(['2026-11-06', 'Erentepe Şube', 'hayvan sayisi', 'sag.hay/ topl.hay.', 0.42]), isNull);
    expect(DetaySatir.oku(['2026-11-06', 'Aslım Çiftliği', 'SÜRÜDEN ÇIKANLAR', 'Satılan Erkek /DİŞİ dana', 3]), isNotNull);
  });

  test('Kayıplar: çiftliklerimiz ve ESK ayrı', () {
    final k = kayipOzeti(v, bas, son)!;
    expect(k.toplam, 2);
    expect(k.aciklama, 'Erentepe: ölen inek 1, ölü doğum 1');
    expect(kayipOzeti(v, bas, son, eskDahil: true)!.toplam, 3);
    expect(kayipOzeti(v, DateTime(2026, 10, 1), DateTime(2026, 10, 2)), isNull);
  });

  test('Hareket tabloları', () {
    final c = hareketTablosu(v, bas, son, cikis: true);
    expect(c['Ölen inek']!['Erentepe Şube'], 1);
    final g = hareketTablosu(v, bas, son, cikis: false);
    expect(g.keys, ['Bugün doğan buzağı']);
  });
}
