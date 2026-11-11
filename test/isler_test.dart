import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/model.dart';

void main() {
  test('Is.oku temel alanları ve tarihleri okur (dd.MM.yyyy)', () {
    final i = Is.oku([
      '13',
      'ESK Ekim kesim farkı',
      'Taşağıl',
      'Gmail',
      '11.11.2026',
      'Bekliyor',
      '11.11.2026',
      'Fark netleşti',
      'Ümit Buldu',
    ]);
    expect(i, isNotNull);
    expect(i!.no, 13);
    expect(i.konu, 'ESK Ekim kesim farkı');
    expect(i.ciftlik, 'Taşağıl');
    expect(i.bekliyor, isTrue);
    expect(i.acilis, DateTime(2026, 11, 11));
    expect(i.sorumlu, 'Ümit Buldu');
  });

  test('Is.oku ISO tarihi de okur', () {
    final i = Is.oku(['1', 'iş', '', '', '2026-11-05', 'Devam ediyor']);
    expect(i!.acilis, DateTime(2026, 11, 5));
    expect(i.devam, isTrue);
  });

  test('No ya da konu yoksa null döner', () {
    expect(Is.oku(['', 'konu']), isNull);
    expect(Is.oku(['5', '']), isNull);
    expect(Is.oku(['x', 'konu']), isNull);
  });

  test('gecikmis: 14 günü aşan bekleyen iş', () {
    final bugun = DateTime(2026, 11, 30);
    final eski = Is(
        no: 1, konu: 'x', durum: 'Bekliyor', acilis: DateTime(2026, 11, 1));
    final yeni = Is(
        no: 2, konu: 'y', durum: 'Bekliyor', acilis: DateTime(2026, 11, 20));
    final devamEden = Is(
        no: 3, konu: 'z', durum: 'Devam ediyor', acilis: DateTime(2026, 1, 1));
    expect(eski.gecikmis(bugun), isTrue);
    expect(yeni.gecikmis(bugun), isFalse);
    expect(devamEden.gecikmis(bugun), isFalse);
  });

  test('RaporVerisi.json isler listesini okur, yoksa boş', () {
    final v = RaporVerisi.json({
      'isler': [
        ['1', 'iş', 'Aslım', 'Chat', '2026-11-05', 'Devam ediyor', '', '', ''],
        ['2', 'iş2', '', '', '', 'Bekliyor'],
      ],
    });
    expect(v.isler.length, 2);
    expect(v.isler.first.devam, isTrue);

    final bos = RaporVerisi.json({});
    expect(bos.isler, isEmpty);
  });
}
