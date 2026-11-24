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

  test('KMZ sezon katmanı: girilmeyen parsele KMZ ürünü gelir, uygulama girişi önce gelir', () {
    const kare = [(1.0, 1.0), (2.0, 1.0), (2.0, 2.0), (1.0, 2.0)];
    final kmz = TarlaSezonu(sezon: '2025-2026', kaynak: 'KMZ', tarih: '', ciftlikler: [
      TarlaCiftlik(ad: 'Örnek', parseller: [
        TarlaParsel(ad: 'A', tip: 'parsel', urunler: const [('Arpa', 0)], koord: kare),
        TarlaParsel(ad: 'B', tip: 'parsel', urunler: const [('Arpa', 0)], koord: kare),
      ]),
    ]);
    final katman = TarlaSezonu.json({
      'sezon': '2026-2027', 'kaynak': 'örnek.kmz', 'tarih': '', 'tur': 'katman',
      'ciftlikler': [
        {'ad': 'Örnek', 'parseller': [
          {'ad': 'A', 'tip': 'parsel', 'urunler': [['Buğday', 10], ['Arpa', 20]], 'cesitler': ['Halis', null],
           'bolgeler': [['P', [0, 0, 50, 0, 50, 50]]], 'not_': 'KMZ: örnek'},
          {'ad': 'B', 'tip': 'parsel', 'urunler': [['Buğday', 30]], 'not_': 'KMZ: örnek B'},
        ]},
      ],
    });
    final l = [const SezonParsel(sezon: '2026-2027', ciftlik: 'Örnek', parsel: 'B', urun: 'Arpa', alan: 30, durum: 'Aktif')];
    final ss = tarlaSezonlari([kmz, katman], l);
    expect([for (final x in ss) x.sezon], ['2024-2025', '2025-2026', '2026-2027']);
    final p = ss.last.ciftlikler.single.parseller;
    expect(p.first.urunler, [('Buğday', 10.0), ('Arpa', 20.0)]);
    expect(p.first.cesit(0), 'Halis');
    expect(p.first.bolgeler.single.$1, 'P');
    expect(p.last.urunler, [('Arpa', 30.0)]);
    expect(p.last.not, contains('KMZ\'de farklı'));
  });
}
