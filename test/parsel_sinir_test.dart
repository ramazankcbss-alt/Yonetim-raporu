import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/model.dart';
import 'package:yonetim_raporu/veri/tarla.dart';

void main() {
  test('sınır koordinatları yazılır ve okunur', () {
    final k = [(10.5, 20.25), (10.6, 20.25), (10.6, 20.3)];
    final t = ParselSinir.koordYaz(k);
    expect(t, '10.500000,20.250000 10.600000,20.250000 10.600000,20.300000');
    expect(ParselSinir.koordOku(t), k);
    final r = ParselSinir.oku(['Örnek çiftlik', 'A', t, '01.01.2026', 'Aktif'])!;
    expect(r.aktif, isTrue);
    expect(r.koord.length, 3);
  });

  test('son aktif sınır geçerli; geri alınınca KMZ sınırına dönülür; yeni parsel eklenir', () {
    const kare = [(1.0, 1.0), (2.0, 1.0), (2.0, 2.0), (1.0, 2.0)];
    const ucgen = [(1.0, 1.0), (3.0, 1.0), (2.0, 3.0)];
    final kmz = TarlaSezonu(sezon: '2025-2026', kaynak: 'KMZ', tarih: '', ciftlikler: [
      TarlaCiftlik(ad: 'Örnek', parseller: [
        TarlaParsel(ad: 'A', tip: 'ekili', urunler: const [('Arpa', 10)], koord: kare),
      ]),
    ]);
    final l = [
      const ParselSinir(ciftlik: 'Örnek', parsel: 'A', koord: kare, durum: 'Güncellendi'),
      const ParselSinir(ciftlik: 'Örnek', parsel: 'A', koord: ucgen, durum: 'Aktif'),
      const ParselSinir(ciftlik: 'Örnek', parsel: 'B', koord: kare, durum: 'Aktif'),
    ];
    final s = sinirUygula(kmz, l);
    final p = s.ciftlikler.single.parseller;
    expect(p.length, 2);
    expect(p.first.koord, ucgen);
    expect(p.first.urunler, [('Arpa', 10.0)]);
    expect(p.last.ad, 'B');
    expect(p.last.girilmedi, isTrue);

    final geri = sinirUygula(kmz, [...l, const ParselSinir(ciftlik: 'Örnek', parsel: 'A', durum: 'Geri alındı')]);
    expect(geri.ciftlikler.single.parseller.first.koord, kare);
  });
}
