import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yonetim_raporu/bicim.dart';
import 'package:yonetim_raporu/servis/veri_servisi.dart';
import 'package:yonetim_raporu/veri/model.dart';
import 'package:yonetim_raporu/veri/tablolar.dart';

import 'ornek_veri.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  final v = RaporVerisi.json(ornekJson);
  final pzt = DateTime(2026, 11, 2);

  test('Sayı okuma (Türkçe yazım)', () {
    expect(sayiOku('12.648'), 12648);
    expect(sayiOku('22,4'), 22.4);
    expect(sayiOku('1.234,5'), 1234.5);
    expect(sayiOku(9382), 9382);
    expect(sayiOku(''), isNull);
    expect(sayiOku('—'), isNull);
  });

  test('Tarih, hafta', () {
    expect(tarihOku('2026-11-05'), DateTime(2026, 11, 5));
    expect(haftaBasi(DateTime(2026, 11, 8)), pzt);
    expect(isoHafta(pzt), 45);
    expect(isoHafta(DateTime(2026, 10, 26)), 44);
  });

  test('Veri okunur ve sıralanır', () {
    expect(v.ozet.length, 48);
    expect(v.gunluk.length, 5);
    expect(v.sonGun, DateTime(2026, 11, 5));
    expect(v.gunler.first, DateTime(2026, 11, 5));
    expect(v.haftalar, [pzt, DateTime(2026, 10, 26)]);
  });

  test('Haftalık işletme tablosu E-Tablodaki haftalık sayfayla aynı', () {
    final o = canliHayvanOzeti(v, pzt, DateTime(2026, 11, 8));
    expect(o.ozetGunu, DateTime(2026, 11, 5));

    final f = o.bul('Fethiye Şube')!;
    expect([f.personel, f.taseron, f.hayvan, f.sagilan], [41, 2, 982, 418]);
    expect(f.sut, 40417);
    expect(sayi(f.ortVerim, ondalik: 1), '24,2');
    expect([f.kesimSatis, f.buzagiOlum, f.kesilenDana], [3, 1, 2]);

    final e = o.bul('Erentepe Şube')!;
    expect(e.sut, 12770);
    expect(sayi(e.ortVerim, ondalik: 1), '27,1');

    expect(o.bul('Fethiye Şube Holstein Besi')!.hayvan, 810);
    expect(o.bul(eskBesi)!.kesilenDana, 422);
    expect(o.bul(digerAdi)!.personel, 18);

    final t = o.toplam;
    expect([t.personel, t.taseron, t.hayvan, t.sagilan], [91, 10, 2079, 537]);
    expect(t.sut, 53187);
    expect(sayi(t.ortVerim, ondalik: 1), '24,8');
    expect([t.kesimSatis, t.buzagiOlum, t.kesilenDana, t.dogan], [3, 1, 2, 5]);
  });

  test('Haftalık göstergeler (45. hafta)', () {
    final g = haftalikGostergeler(v, pzt);
    expect(g.toplamHayvan, 2079);
    expect(g.sagilan, 537);
    expect(g.sut, 53187);
    expect(sayi(g.ortVerim, ondalik: 1), '24,8');
    expect(g.satilan, 47886);
    expect(g.personel, 91);
    expect(g.dogan, 5);
    expect(g.kesilenDana, 2);
    expect(g.olenBuzagi, 1);
    expect(g.eskKesilen, 422);
  });

  test('Özetsiz hafta (44. hafta): yalnızca günlük süt verisi', () {
    final g = haftalikGostergeler(v, DateTime(2026, 10, 26));
    expect(g.toplamHayvan, 2080);
    expect(g.sagilan, 540);
    expect(g.sut, 13470);
    expect(sayi(g.ortVerim, ondalik: 1), '24,9');
    expect(g.satilan, 12130);
    expect(g.personel, isNull);
  });

  test('Günlük göstergeler (05.11.2026) kaynak özet tablosuyla aynı', () {
    final g = gunlukGostergeler(v, DateTime(2026, 11, 5));
    expect(g.toplamHayvan, 2079);
    expect(g.sagilan, 537);
    expect(g.sut, 12648);
    expect(sayi(g.ortVerim, ondalik: 1), '23,6');
    expect(g.satilan, 11474);
    expect(g.personel, 91);
    expect(g.taseron, 10);
    expect(g.dogan, 3);
    expect(g.kesilenDana, 0);
    expect(g.eskBesiHayvan, 3686);
  });

  test('Tablolar', () {
    final o = canliHayvanOzeti(v, pzt, DateTime(2026, 11, 8));
    final s = isletmeSatirlari(o);
    expect(s.length, 8);
    expect(s.last, [
      'ÇİFTLİKLER TOPLAM', '91', '10', '2.079', '537', '53.187', '24,8', '3',
      '1', '2'
    ]);

    final suru = suruSatirlari(v.gunlukBul(pzt), v.gunlukBul(DateTime(2026, 11, 5)));
    expect(suru[0], ['Toplam hayvan', '1.792', '1.792', '—', '283', '287', '+4']);
    expect(suru[4], ['Sağılan süt (kg)', '10.471', '9.382', '-1.089', '3.170', '3.266', '+96']);

    final sut = gunlukSutSatirlari(v.gunlukDonem(pzt, DateTime(2026, 11, 8)));
    expect(sut.last[0], 'Hafta Toplamı');
    expect(sut.last[3], '53.187');
    expect(sut.last[6], '47.886');

    final ekim = ekimSatirlari(v.ekim);
    expect(ekim.last.sublist(0, 4), ['GENEL TOPLAM', '', '8.905', '6.684']);
  });

  test('Tarım: son faaliyetler ve dönem', () {
    final son = v.sonFaaliyetler(DateTime(2026, 11, 5));
    expect(son.map((t) => t.ciftlik).toList(),
        ['Şekersüt', 'Aslım', 'Taşağıl', 'Fidanlık']);
    expect(son.last.tarih, DateTime(2026, 11, 5));
    expect(v.tarimDonem(pzt, DateTime(2026, 11, 8)).length, 5);
  });

  test('Bağlantı linki kontrolü', () {
    expect(linkKontrol(''), isNotNull);
    expect(linkKontrol('https://example.com/exec?anahtar=1234567890abcdef'),
        isNotNull);
    expect(linkKontrol('https://script.google.com/macros/s/AKfy/exec'),
        isNotNull);
    expect(
        linkKontrol(
            'https://script.google.com/macros/s/AKfy/exec?anahtar=1234567890abcdef1234'),
        isNull);
  });
}
