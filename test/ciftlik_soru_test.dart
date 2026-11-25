import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/ciftlik_rapor.dart';
import 'package:yonetim_raporu/veri/ciftlik_soru.dart';

void main() {
  final r = CiftlikRaporu.coz(File('assets/veri/ciftlik_rapor_2026.json').readAsStringSync());

  test('bulgular: olumsuz sonuç ve tutarsızlık tespit edilir', () {
    final b = tumBulgular(r);
    expect(b.any((x) => x.tur == BulguTuru.olumsuz && x.baslik.contains('Şekersüt')), isTrue);
    expect(b.any((x) => x.tur == BulguTuru.tutarsizlik && x.baslik.contains('negatif maliyet')), isTrue);
    expect(b.any((x) => x.tur == BulguTuru.tutarsizlik && x.baslik.contains('miktarsız gelir')), isTrue);
  });

  test('süt maliyeti sorusu Şekersüt analizini ve olumsuzlukları verir', () {
    final y = cevapla(r, 'Şekersüt süt maliyeti neden arttı?');
    expect(y.anlasildi, isTrue);
    expect(y.paragraflar.join(' '), contains('31,36'));
    expect(y.bulgular.any((b) => b.tur == BulguTuru.olumsuz), isTrue);
  });

  test('aylık bileşen sorusu', () {
    final y = cevapla(r, 'Mayıs ayında Pan-Gev yem maliyeti ne kadar?');
    expect(y.paragraflar.first, contains('Mayıs 2026'));
    expect(y.paragraflar.first, contains('hammadde (yem)'));
  });

  test('en çok zarar eden çiftlik', () {
    final y = cevapla(r, 'En çok zarar eden çiftlik hangisi?');
    expect(y.paragraflar.join(' '), contains('ESK-Taşağıl'));
  });

  test('tarım ürün sorusu', () {
    final y = cevapla(r, 'Buğday fiyatı 2025’e göre ne kadar değişti?');
    expect(y.paragraflar.join(' '), contains('Buğday 2025→2026'));
  });

  test('tutarsızlık sorusu tüm bulguları döner', () {
    final y = cevapla(r, 'Tutarsızlıklar neler?');
    expect(y.bulgular.length, tumBulgular(r).length);
  });

  test('anlaşılmayan soru yönlendirme verir', () {
    final y = cevapla(r, 'merhaba');
    expect(y.anlasildi, isFalse);
  });

  test('piyasa senaryosu sorusu iki senaryoyu karşılaştırır', () {
    final y = cevapla(r, 'Aslım piyasa senaryosunda neden zarar ediyor?');
    expect(y.anlasildi, isTrue);
    expect(y.paragraflar.join(' '), contains('Aslım'));
    expect(y.paragraflar.join(' '), contains('piyasa'));
    expect(y.bulgular.any((b) => b.baslik.contains('Aslım – piyasa')), isTrue);
  });
}
