import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/ciftlik_rapor.dart';
import 'package:yonetim_raporu/veri/ciftlik_soru.dart';
import 'package:yonetim_raporu/veri/maliyet_analiz.dart';

void main() {
  final r = CiftlikRaporu.coz(File('assets/veri/ciftlik_rapor_2026.json').readAsStringSync(),
      maliyetTakip: File('assets/veri/maliyet_takip_2026.json').readAsStringSync());
  final m = r.mt!;

  test('hayvancılık özeti okunur', () {
    final s = m.hayvanAylar('Şekersüt', 2026);
    expect(s.length, 9);
    expect(s.first.hayvan, 1381);
    expect(s.first.basinaAylik, closeTo(11286, 1));
  });

  test('ekiliş ve ortak giderler', () {
    expect(m.ekilis.length, 11);
    expect(m.ortakToplam, closeTo(59791200, 5));
    expect(maliyetTakipBulgulari(r).any((x) => x.baslik.contains('toplam hücresi hatalı')), isTrue);
    expect(dekarSatirlari(m).every((d) => d.payliDekarBasi! > d.dekarBasi!), isTrue);
  });

  test('tutarsızlıklar tespit edilir', () {
    final b = maliyetTakipBulgulari(r);
    expect(b.any((x) => x.baslik.contains('formül hatası')), isTrue);
    expect(b.any((x) => x.baslik.contains('Taşağıl verisi güncel değil')), isTrue);
    expect(b.any((x) => x.baslik.contains('yem toplamı eksik')), isTrue);
    expect(b.any((x) => x.tur == BulguTuru.olumsuz && x.baslik.contains('satış fiyatının üstünde')), isTrue);
  });

  test('maliyet takip soruları', () {
    expect(cevapla(r, 'Şekersüt hayvan başı maliyet ne kadar?').paragraflar.join(' '), contains('hayvan başı'));
    expect(cevapla(r, 'Pancar dekar maliyeti').paragraflar.join(' '), contains('₺'));
    expect(cevapla(r, 'Ekim ayında Pan-Gev süt maliyeti').paragraflar.join(' '), contains('32,30'));
    expect(cevapla(r, 'Karkas maliyeti').paragraflar, isNotEmpty);
    expect(cevapla(r, 'Yem fiyatları arttı mı?').paragraflar.join(' '), contains('₺/kg'));
  });
}
