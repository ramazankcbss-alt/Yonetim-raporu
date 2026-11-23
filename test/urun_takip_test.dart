// Örnek (uydurma değil, test amaçlı küçük) değerlerle birleştirme mantığı sınanır;
// uygulama gerçek verileri Drive dosyalarından okur.
import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/uretim_karlilik.dart';
import 'package:yonetim_raporu/veri/urun_takip.dart';

void main() {
  test('plan ve teslimat ürün/çiftlik bazında birleşir', () {
    final plan = TarimsalUretim.json({
      'dosya': 'Örnek',
      'urunBasligi': '2025',
      'satirlar': [
        ['İŞLETMELER', 'ÜRÜN ADI'],
        ['ASLIM ', 'PANCAR', ' X', '100', '1000', '100000', '2', '200000', '', '', '120000', '80000'],
        ['', 'BUĞDAY', ' Y', '50', '500', '25000', '10', '250000', '', '', '100000', '150000'],
      ],
    });
    final ts = UrunTeslimat.json({
      'satirlar': [
        ['Şeker Pancarı', 'Aslım', 'TarKop', 'Konya Şeker', '2026-11-20', 2, 60000, 55000, '', 0, 0, 17.2, 0],
        ['Şeker Pancarı', 'Aslım', 'TarKop', 'Konya Şeker', '2026-11-21', 1, 30000, 27000, 3, 81000, 0, '', 0],
      ],
      'elle': [],
      'kaynaklar': [],
    });
    final t = UrunTakibi(plan, ts);
    final pancar = t.urunler.firstWhere((e) => e.$1.urun == 'Şeker Pancarı').$1;
    expect(pancar.dekar, 100);
    expect(pancar.teslim, 90000);
    expect(pancar.net, 82000);
    expect(pancar.kesinti, 8000);
    expect(pancar.sefer, 3);
    // 55.000 kg plan fiyatıyla (2) + 27.000 kg kaynaktaki fiyatla (3)
    expect(pancar.gelir, 110000 + 81000);
    expect(pancar.ilerleme, closeTo(82, 0.001));
    expect(pancar.kalan, 18000);
    expect(pancar.fiyatTahmini, isTrue);
    final bugday = t.urunler.firstWhere((e) => e.$1.urun == 'Buğday').$1;
    expect(bugday.teslimatVar, isFalse);
    expect(t.urunler.first.$1.urun, 'Şeker Pancarı');
  });
}
