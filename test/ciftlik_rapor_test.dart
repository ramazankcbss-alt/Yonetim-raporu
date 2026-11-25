import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/ekranlar/ciftlik_rapor.dart';
import 'package:yonetim_raporu/veri/ciftlik_rapor.dart';

void main() {
  final r = CiftlikRaporu.coz(File('assets/veri/ciftlik_rapor_2026.json').readAsStringSync());

  test('konsolide, çiftliklerin toplamına eşittir', () {
    const k = 'Brüt satışlar';
    final toplam = ['Şekersüt', 'Pan-Gev', 'Tarımsal Alan', 'Aslım', kEsk].fold<double>(0, (t, c) => t + r.d26(c, k));
    expect((r.d26(kKonsolide, k) - toplam).abs(), lessThan(10));
  });

  test('Çiftliklerimiz = Konsolide − ESK', () {
    const k = 'Dönem net kârı/zararı';
    expect(r.d26(kCiftliklerimiz, k), closeTo(r.d26(kKonsolide, k) - r.d26(kEsk, k), 2));
  });

  test('süt birim maliyeti ağırlıklı ortalamadır', () {
    final s = r.donemOrt(kSekersut, 2026);
    expect(s.aylar.length, 9);
    expect(s.birimMaliyet, closeTo(31.36, 0.01));
    expect(s.fiyat, closeTo(26.45, 0.01));
    final kalemToplam = maliyetBilesenleri.fold<double>(0, (t, k) => t + s.bilesen(k));
    expect(kalemToplam, closeTo(s.birimMaliyet, 0.05));
  });

  test('ESK hizmetinin tutarsız ayları ortalamaya girmez', () {
    final e = r.donemOrt(kEskHizmet, 2026);
    expect(e.aylar.any((a) => a.ayNo == 1 || a.ayNo == 3), isFalse);
    expect(e.birimMaliyet, closeTo(69.31, 0.01));
  });

  test('neden metinleri veriden üretilir', () {
    expect(karZararNedenleri(r), isNotEmpty);
    final n = birimNedenleri(r, kSekersut, 'Şekersüt', 'L');
    expect(n.first.$2, contains('31,36'));
    expect(n.any((x) => x.$2.contains('zarar')), isTrue);
  });
}
