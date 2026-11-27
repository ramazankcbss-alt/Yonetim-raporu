import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/bildirim.dart';
import 'package:yonetim_raporu/veri/duyarlilik.dart';
import 'package:yonetim_raporu/veri/gelir_gider.dart';
import 'package:yonetim_raporu/veri/karne_sapma.dart';

// Yalnızca test için yapay örnek veri; gerçek şirket rakamı içermez.
void main() {
  test('duyarlılık: baz tutarlar faturalardan, etki yönü gelir / gidere göre', () {
    final g = GelirGider.json({
      'gelir': [
        [2040, 1, 'Şekersüt', 'Çiğ süt', 'Grup dışı', 'L', 10, 1000, 1100],
        [2040, 2, 'Pan-Gev', 'Çiğ süt', 'Grup dışı', 'L', 10, 500, 550],
      ],
      'gider': [
        [2040, 2, 'Şekersüt', 'Yem ve kaba yem', 'Grup dışı', 800, 880],
      ],
    });
    final d = duyarlilikDegiskenleri(faturalar: g);
    final sut = d.firstWhere((x) => x.anahtar == 'sut_fiyat'), yem = d.firstWhere((x) => x.anahtar == 'yem');
    expect(sut.baz, 1500);
    expect(sut.etki(-10), -150);
    expect(yem.etki(15), -120);
    expect(kOrnekSenaryo.etki(d), -150 - 120);
    final metin = DuyarlilikSenaryosu.listeYaz([kOrnekSenaryo]);
    expect(DuyarlilikSenaryosu.listeOku(metin).single.yuzdeler['yem'], 15);
  });

  test('bildirim: alarm kritik, sapma özet, aylık rapor hatırlatması bir kez', () {
    final s = [
      Sapma(ciftlik: 'Şekersüt', yil: 2040, ay: 3, baslik: 'Süt maliyeti satış fiyatının üstünde: 30 ₺/L, satış 25 ₺/L', nedenler: const [], alarm: true),
      Sapma(ciftlik: 'Şekersüt', yil: 2040, ay: 3, baslik: 'Gider 1,00 mn ₺; ortalama 0,80 mn ₺', nedenler: const ['Yem']),
      Sapma(ciftlik: 'Pan-Gev', yil: 2040, ay: 2, baslik: 'Eski ay', nedenler: const []),
    ];
    final l = bildirimleriUret(sapmalar: s, yil: 2040, sonMuhasebeAyi: 3, eksikDonemler: const ['Nisan bekleniyor']);
    expect(l.where((b) => b.oncelik == BildirimOnceligi.kritik).length, 1);
    expect(l.where((b) => b.baslik.contains('sapma')).length, 1);
    expect(l.any((b) => b.hedef == BildirimHedefi.aylikRapor), isTrue);
    final sonra = bildirimleriUret(sapmalar: s, yil: 2040, sonMuhasebeAyi: 3, sonRaporlananAy: 2040 * 12 + 3);
    expect(sonra.any((b) => b.hedef == BildirimHedefi.aylikRapor), isFalse);
    // Aynı durum aynı anahtarı üretir (tekrar gönderilmez).
    expect(l.first.anahtar, bildirimleriUret(sapmalar: s, yil: 2040, sonMuhasebeAyi: 3).first.anahtar);
  });
}
