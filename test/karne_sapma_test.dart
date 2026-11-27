import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/ciftlik_rapor.dart';
import 'package:yonetim_raporu/veri/gelir_gider.dart';
import 'package:yonetim_raporu/veri/karne_sapma.dart';
import 'package:yonetim_raporu/veri/stok_suru.dart';

// Yalnızca test için yapay örnek veri; gerçek şirket rakamı içermez.
Map<String, dynamic> _b(int yil, int ay, double yem, double amort, {double fiyat = 25}) => {
      'urun': kSekersut,
      'yil': yil,
      'ay_no': ay,
      'miktar': 1000,
      'toplam': yem + amort,
      'bilesen': {'Hammadde (yem)': yem, 'Amortisman': amort},
      'satis_miktar': 1000,
      'satis_tl': fiyat * 1000,
      'tutarsiz': false,
    };

void main() {
  final r = CiftlikRaporu.coz(jsonEncode({
    'baslik': 'Örnek',
    'kaynak': 'örnek',
    'donem': '',
    'gelir': [],
    'aylik': [],
    'birim': [
      for (var m = 1; m <= 12; m++) _b(2039, m, 10000, 10000),
      _b(2040, 1, 10000, 20000),
    ],
    'tarim': [],
    'tesvik': [],
    'senaryo': null,
  }));
  final suru = SuruHareketleri.json({
    'sayfalar': {
      '2040': [
        ['ŞEKERSÜT'],
        ['TÜM SÜRÜ', '100'],
        ['SAĞMAL', '40'],
      ],
      '2039': [
        ['ŞEKERSÜT'],
        ['TÜM SÜRÜ', '100'],
        ['SAĞMAL', '50'],
      ],
    },
  });

  test('süt maliyeti satış fiyatını geçince alarm; artış bileşene göre açıklanır', () {
    final l = sapmalar(muhasebe: r, suru: suru, faturalar: const GelirGider(), yil: 2040, sonAy: 1);
    expect(l.any((s) => s.alarm && s.baslik.contains('30,00')), isTrue);
    final s = l.firstWhere((s) => !s.alarm);
    expect(s.baslik, contains('20,00'));
    expect(s.nedenler.any((n) => n.startsWith('Amortisman 10,00')), isTrue);
  });

  test('karne geçen yılın aynı ayıyla karşılaştırır', () {
    final k = verimlilikKarnesi(muhasebe: r, suru: suru, yil: 2040, ay: 1).first;
    final maliyet = k.gostergeler.firstWhere((g) => g.ad == 'Süt maliyeti');
    expect(maliyet.deger, 30);
    expect(maliyet.gecenYil, 20);
    expect(maliyet.iyi, isFalse);
    final verim = k.gostergeler.firstWhere((g) => g.ad == 'Süt verimi');
    expect(verim.deger, closeTo(1000 / 40 / 31, 1e-9));
  });
}
