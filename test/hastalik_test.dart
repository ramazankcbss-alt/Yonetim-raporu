import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/hastalik.dart';
import 'package:yonetim_raporu/veri/model.dart';

void main() {
  test('arşiv JSON çözülür', () {
    final l = hastalikJsonCoz(File('assets/veri/hastalik.json').readAsStringSync());
    expect(l.length, greaterThan(1000));
    expect(l.every((k) => k.ay >= 1 && k.ay <= 12), isTrue);
    expect(l.every((k) => sonuclar.contains(k.sonuc)), isTrue);
  });
  test('Bilgi Bankası satırı hastalık kaydına çevrilir', () {
    const g = GecmisVeri(yil: '2026', ay: 'Kasım', alan: 'Şekersüt', konu: 'Hastalık kaydı', gosterge: 'İnek · Mastit · Kuru', sayi: 3);
    final k = gecmistenHastalik(g)!;
    expect([k.yil, k.ay, k.cins, k.hastalik, k.sonuc, k.adet], [2026, 11, 'İnek', 'Mastit', 'Kuru', 3]);
    expect(tedbirBul('Mastit').tedbirler, isNotEmpty);
    expect(tedbirBul('Bilinmeyen').etken, contains('teşhis'));
  });
}
