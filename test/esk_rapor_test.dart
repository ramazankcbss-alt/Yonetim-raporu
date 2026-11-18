import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/esk_rapor.dart';
import 'package:yonetim_raporu/veri/model.dart';

void main() {
  test('ilkSayi metinden sayıyı okur', () {
    expect(ilkSayi('50 TL/baş/gün'), 50);
    expect(ilkSayi('900.000 TL/ay'), 900000);
    expect(ilkSayi('837,5 TL/baş'), 837.5);
    expect(ilkSayi('yok'), isNull);
  });

  test('haftalık ESK raporu günlük özetten hesaplanır', () {
    final v = RaporVerisi(
      ozet: [
        OzetSatir(tarih: DateTime(2026, 11, 16), isletme: eskBesi, hayvan: 4000, kesilenDana: 100, alinan: 0),
        OzetSatir(tarih: DateTime(2026, 11, 17), isletme: eskBesi, hayvan: 3900, kesilenDana: 100, olenDana: 1),
        OzetSatir(tarih: DateTime(2026, 11, 17), isletme: 'Erentepe Şube', hayvan: 300),
      ],
      gunluk: const [],
      tarim: const [],
      eskBilgi: const [
        EskBilgi(bolum: 'Fiyat', baslik: 'Bakım besleme ücreti', deger: '50 TL/baş/gün'),
        EskBilgi(bolum: 'Fiyat', baslik: 'İşletme kira bedeli', deger: '900.000 TL/ay'),
        EskBilgi(bolum: 'Başabaş', baslik: 'Aylık sabit işletme gideri', deger: '6000000', sayi: 6000000),
      ],
    );
    final h = eskHaftalari(v);
    expect(h, hasLength(1));
    final w = h.first;
    expect(w.bas, DateTime(2026, 11, 16));
    expect(w.gun, 2);
    expect(w.hayvanGun, 7900);
    expect(w.ortBas, 3950);
    expect(w.kesilen, 200);
    expect(w.olen, 1);
    expect(w.sonMevcut, 3900);
    expect(w.bakim, 395000);
    expect(w.kira, closeTo(60000, 0.01));
    expect(w.gider, closeTo(400000, 0.01));
    expect(w.karZarar, closeTo(55000, 0.01));
    expect(w.eksik, isTrue);
  });

  test('yıllık ESK toplamları', () {
    final y = eskYillari(const [
      EskAy(ay: 'Ekim 2026', gelen: 100, hayvanGun: 3100, ortBas: 100, kesim: 10, karZarar: -5, durum: 'Tahmini'),
      EskAy(ay: 'Eylül 2026', gelen: 50, hayvanGun: 6000, ortBas: 200, kesim: 20, karZarar: 3, durum: 'Gerçek'),
      EskAy(ay: 'Ocak 2025', karZarar: -1, durum: 'Gerçek'),
    ]);
    expect(y.map((e) => e.yil), [2026, 2025]);
    expect(y.first.karZarar, -2);
    expect(y.first.gelen, 150);
    expect(y.first.ortBas, closeTo(9100 / 61, 0.001));
    expect(y.first.tahminiAy, 1);
    expect(y.last.eskAy, 0);
  });
}
