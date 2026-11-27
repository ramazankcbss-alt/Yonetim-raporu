import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/ciftlik_rapor_tam.dart';

void main() {
  test('çiftlik raporu tam: gider grup × ay ve malzeme toplamı', () {
    final d = CiftlikRaporTam.json({
      'dosya': 'X',
      'sayfalar': [
        {'ad': 'A', 'satir': 10, 'sutun': 3}
      ],
      'gider': [
        [2030, 1, '1613', '2.İşçi', '', 100],
        [2030, 1, '1614', '2.İşçi', '', 50],
        [2030, 2, '1613', '41.Amortisman', '7 X', 20],
      ],
      'yem': [
        [2030, 1, '1605', 'SAP', 'DANA', 10, 5],
        [2030, 2, '1605', 'SAP', 'DANA', 30, 15],
      ],
    });
    expect(d.giderYillari, [2030]);
    expect(d.giderGrupAy(2030)['2.İşçi']![1], 150);
    expect(d.giderGrupAy(2030, uy: '1613')['2.İşçi']![1], 100);
    expect(CiftlikRaporTam.malzemeToplam(d.yem)['SAP'], (40.0, 20.0));
  });
}
