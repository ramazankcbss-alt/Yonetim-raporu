import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/ekranlar/veri_kalitesi.dart';
import 'package:yonetim_raporu/veri/model.dart';

// Yalnızca test için yapay örnek veri; gerçek şirket rakamı içermez.
void main() {
  test('kaynak kopyadan sonra değiştiyse veri eski sayılır; canlı kaynak eski sayılmaz', () {
    final a = KaynakTarihi.oku({'ad': 'X', 'kaynak': '2040-03-10T10:00:00', 'kopya': '2040-03-01T10:00:00'})!;
    final b = KaynakTarihi.oku({'ad': 'Y', 'kaynak': '2040-03-01T10:00:00', 'kopya': '2040-03-10T10:00:00'})!;
    final c = KaynakTarihi.oku({'ad': 'Z', 'kaynak': '2040-03-10T10:00:00', 'canli': true})!;
    expect(a.eski, isTrue);
    expect(b.eski, isFalse);
    expect(c.eski, isFalse);
  });

  test('fatura tabloları kapanmış aylara göre eksik dönemi bildirir', () {
    final v = RaporVerisi.json({
      'mali': {
        'gelirGider': {
          'donem': 'Ocak–Şubat 2040',
          'gelir': [
            [2040, 2, 'Şekersüt', 'Çiğ süt', 'Grup dışı', 'L', 10, 100, 110],
          ],
          'gider': [],
        },
      },
    });
    final q = VeriKalitesi.hesapla(v, null, bugun: DateTime(2040, 5, 15));
    expect(q.eksikAylar.any((x) => x.contains('Mart–Nisan')), isTrue);
  });
}
