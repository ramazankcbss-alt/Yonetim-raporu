import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/ciftlik_rapor.dart';
import 'package:yonetim_raporu/veri/senaryo.dart';

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

  test('piyasa senaryosu: "2" sayfaları ayrı okunur, toplam çiftliklerin toplamıdır', () {
    final s = r.senaryo!;
    expect(s.ciftlikler.first.ciftlik, kSenaryoToplam);
    final a = s.ciftlik('Aslım')!;
    expect(a.net1, closeTo(-709021, 1));
    expect(a.net2, closeTo(-7537646, 1));
    final t = s.ciftlikler.first;
    final top = s.ciftlikler.skip(1).fold<double>(0, (x, c) => x + c.net2);
    expect(t.net2, closeTo(top, 4));
    // Birinci senaryo toplamı = Çiftliklerimiz (ESK hariç) gelir tablosu
    expect(t.net1, closeTo(r.d26(kCiftliklerimiz, 'Dönem net kârı/zararı'), 4));
    expect(s.kontrol.any((k) => k.baslik.contains('Konsolide (2)')), isTrue);
  });

  test('senaryo nedenleri veriden üretilir', () {
    final s = r.senaryo!;
    final n = senaryoNedenleri(s, s.ciftlik('Aslım')!);
    expect(n.first.$2, contains('7,5 mn ₺ zarar'));
    expect(n.any((x) => x.$1 == 'Yorum'), isTrue);
    expect(senaryoNedenleri(s, s.ciftlikler.first).any((x) => x.$1 == 'Grup toplamındaki fark'), isTrue);
  });

  test('senaryo: sütun harfleri ve yıllık dönemler', () {
    expect(aySutunu(2026, 1), 'B');
    expect(aySutunu(2026, 9), 'R');
    expect(aySutunu(2025, 1), 'AC');
    final s = r.senaryo!;
    expect(s.yillar, containsAll([2025, 2026]));
    for (final c in s.ciftlikler) {
      final d = c.donemler[2026]!;
      for (final k in senaryoKalemleri) {
        expect(d.toplam(k, 1), closeTo(c.s1(k), 2));
        expect(d.toplam(k, 2), closeTo(c.s2(k), 2));
      }
      expect(c.donemler[2025]!.aySayisi, 12);
    }
  });

  test('2025 aylık sonuçların toplamı yıl toplamına eşittir', () {
    for (final c in [kKonsolide, 'Şekersüt', 'Tarımsal Alan', kEsk]) {
      final l = r.aylikSonuc(c, yil: 2025);
      expect(l.length, 12);
      expect(l.fold(0.0, (t, a) => t + a.netKar), closeTo(r.d25Yil(c, 'Dönem net kârı/zararı'), 12));
    }
    expect(r.aylikSonuc(kKonsolide).every((a) => a.yil == 2026), isTrue);
  });
}
