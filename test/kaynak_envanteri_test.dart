import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/kaynak_envanteri.dart';

void main() {
  test('kaynak envanteri: dosya, sayfa, sütun ve durum sayaçları', () {
    final e = KaynakEnvanteri.json({
      'olusturma': '2030-01-01T00:00:00Z',
      'tamam': true,
      'kaynaklar': [
        {
          'ad': 'Deneme kaynağı',
          'dosyalar': [
            {
              'id': 'x1',
              'ad': 'Deneme dosyası',
              'sayfalar': [
                {
                  'ad': 'A',
                  'durum': 'kullaniliyor',
                  'kullanim': 'Menü',
                  'satir': 10,
                  'sutun': 2,
                  'sutunlar': [
                    {'no': 1, 'baslik': 'Ürün', 'dolu': 9, 'sayisal': 0},
                    {'no': 2, 'baslik': 'Tutar', 'dolu': 9, 'sayisal': 9, 'toplam': 45.5}
                  ],
                  'notlar': [
                    {'hucre': 'B2', 'not': 'Deneme notu'}
                  ]
                },
                {'ad': 'B', 'durum': 'kullanilmiyor'},
                {'ad': 'C', 'durum': 'kvkk'}
              ]
            }
          ]
        }
      ]
    });
    final k = e.kaynaklar.single;
    expect(KaynakEnvanteri.sayac(k), {'kullaniliyor': 1, 'kullanilmiyor': 1, 'kvkk': 1});
    final s = k.dosyalar.single.sayfalar.first;
    expect(s.sutunlar.last.toplam, 45.5);
    expect(s.notlar.single.hucre, 'B2');
    expect(k.dosyalar.single.sayfalar[2].durumAdi, 'KVKK nedeniyle okunmuyor');
    final o = KaynakEnvanterOzet.json({'dosya': 3, 'sayfa': 7, 'kullanilmayan': 2, 'liste': [['K', 'D', 'S', 'hata', 'x']]});
    expect(o.kullanilmayan, 2);
    expect(o.liste.single[3], 'hata');
  });
}
