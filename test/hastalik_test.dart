import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/hastalik.dart';
import 'package:yonetim_raporu/veri/model.dart';

void main() {
  test('Bilgi Bankası satırı hastalık kaydına çevrilir', () {
    const g = GecmisVeri(yil: '2026', ay: 'Kasım', alan: 'Şekersüt', konu: 'Hastalık kaydı', gosterge: 'İnek · Mastit · Kuru', sayi: 3);
    final k = gecmistenHastalik(g)!;
    expect([k.yil, k.ay, k.cins, k.hastalik, k.sonuc, k.adet], [2026, 11, 'İnek', 'Mastit', 'Kuru', 3]);
    expect(tedbirBul('Mastit').tedbirler, isNotEmpty);
    expect(tedbirBul('Bilinmeyen').etken, contains('teşhis'));
  });
  test('Bilgi Bankası dilimi arşivdeki ayın yerine geçer', () {
    const arsiv = [
      HastalikKaydi(2026, 11, 'Şekersüt', 'İnek', 'Mastit', 'Kuru', 5),
      HastalikKaydi(2026, 11, 'Aslım', 'Besi danası', 'Solunum/pnömoni', 'Ölüm', 1),
      HastalikKaydi(2026, 10, 'Şekersüt', 'İnek', 'Mastit', 'Kuru', 4),
    ];
    const g = [
      GecmisVeri(yil: '2026', ay: 'Kasım', alan: 'Şekersüt', konu: 'Hastalık kaydı', gosterge: 'İnek · Mastit · Kuru', sayi: 7),
      GecmisVeri(yil: '2026', ay: 'Kasım', alan: 'Şekersüt', konu: 'Hastalık kaydı', gosterge: 'Buzağı · İshal · Ölüm', sayi: 0),
    ];
    final l = hastalikBirlestir(arsiv, g);
    expect(l.length, 3);
    expect(l.where((k) => k.ciftlik == 'Şekersüt' && k.ay == 11).single.adet, 7);
    expect(l.any((k) => k.ciftlik == 'Aslım'), isTrue);
    expect(l.any((k) => k.ay == 10), isTrue);
  });
  test('Günlük kırılımlı arşiv çözülür, gün toplamı aylık sayıya eşittir', () {
    const j = '{"ciftlik":["A"],"cins":["İnek"],"hastalik":["Mastit"],"sonuc":["Kuru"],'
        '"kayit":[[2026,3,0,0,0,0,5]],"gunluk":[[2026,3,0,0,0,0,0,1],[2026,3,4,0,0,0,0,4]]}';
    final l = hastalikJsonCoz(j);
    expect(l.fold(0, (s, k) => s + k.adet), 5);
    expect(l.where((k) => k.tarih == null).single.adet, 1);
    expect(l.where((k) => k.tarih != null).single.tarih, DateTime(2026, 3, 4));
  });
}
