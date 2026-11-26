import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/model.dart';

// Yalnızca test için yapay örnek veri; gerçek şirket rakamı içermez.
void main() {
  final m = MaliVeri.json({
    'gelirGider': {
      'donem': 'Ocak–Şubat 2030',
      'kaynakGider': 'aylık gider tablosu',
      'kaynakGelir': 'aylık gelir satış tablosu',
      'iadeAdet': 1,
      'iadeTutar': -10,
      'gider': [
        [2030, 1, 'Şekersüt', 'Yem ve kaba yem', 'Grup dışı', 100, 110],
        [2030, 2, 'Şekersüt', 'Canlı hayvan alımı', 'Grup dışı', 50, 55],
        [2030, 2, 'Aslım', 'Akaryakıt', 'Grup dışı', 20, 24],
      ],
      'gelir': [
        [2030, 1, 'Şekersüt', 'Çiğ süt', 'Grup içi', 'L', 10, 200, 220],
        [2030, 2, 'Aslım', 'Buğday', 'Grup dışı', 'KG', 5, 30, 33],
      ],
    },
  });

  test('gider, gelir ve kâr/zarar toplamları çiftlik ve aya göre süzülür', () {
    final g = m.gelirGider;
    expect(g.bos, isFalse);
    expect(m.bos, isFalse);
    expect(g.ciftlikler, ['Aslım', 'Şekersüt']);
    expect(g.aylar, [(2030, 1), (2030, 2)]);
    const hepsi = (ciftlik: null, yil: null, ay: null);
    expect(g.giderToplam(hepsi), 170);
    expect(g.giderToplam(hepsi, canliHaric: true), 120);
    expect(g.gelirToplam(hepsi), 230);
    expect(g.gelirToplam(hepsi) - g.giderToplam(hepsi), 60);
    expect(g.giderToplam((ciftlik: 'Şekersüt', yil: 2030, ay: 2)), 50);
    expect(g.gelirToplam((ciftlik: 'Aslım', yil: null, ay: null)), 30);
    final k = GelirGider.grupla(g.giderler(hepsi), (x) => x.kategori, (x) => x.net);
    expect(k.first.key, 'Yem ve kaba yem');
  });

  test('veri yoksa boş', () {
    expect(MaliVeri.json({}).gelirGider.bos, isTrue);
  });
}
