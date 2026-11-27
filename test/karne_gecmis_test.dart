import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/gecmis_ozet.dart';
import 'package:yonetim_raporu/veri/karne_sapma.dart';
import 'package:yonetim_raporu/veri/esk_plan.dart';
import 'package:yonetim_raporu/veri/kaynak_envanteri.dart';
import 'package:yonetim_raporu/veri/model.dart' show EskAy;

void main() {
  test('karne: geçmiş yıllar serisi', () {
    final g = GecmisOzet.json({
      'gostergeler': [
        {'tablo': 'Doğum oranları', 'ciftlik': 'Deneme Çiftliği ŞEKERSÜT', 'yil': 2031, 'olcu': 'Doğum Oranı', 'deger': 70.5, 'yuzde': true},
        {'tablo': 'Doğum oranları', 'ciftlik': 'Deneme Çiftliği ŞEKERSÜT', 'yil': 2030, 'olcu': 'Doğum Oranı', 'deger': 60, 'yuzde': true},
      ]
    });
    expect(gecmisSeri(g, 'Şekersüt', RegExp('Doğum'), RegExp('Doğum Oranı'), birim: ' %'), 'Geçmiş yıllar: 2030 60,0 · 2031 70,5 %');
    expect(gecmisSeri(g, 'Pan-Gev', RegExp('Doğum'), RegExp('Doğum Oranı')), isNull);
  });
  test('ESK plan: rasyon, sabit gider ve ÖZET mutabakatı', () {
    final kt = KaynakTablolari.json({
      'menuler': {
        'esk': [
          {'grup': 'G', 'dosya': 'D', 'sayfa': 'ESK RASYON ', 'bloklar': [
            {'satirlar': [['', 'birim fiyatları', '1 Günlük Tüketim', 'KG', '1 HAYVAN İÇİN 1 GÜNLÜK MALİYET'], ['TOPLAM', '', '8,10', '', '80,70']]}
          ]},
          {'grup': 'G', 'dosya': 'D', 'sayfa': 'GİDER KALEM HESABI', 'bloklar': [
            {'satirlar': [['', 'SABİT GİDER MALİYETLER', 'Toplam Aylık Maliyet (TL)'], ['', '', '5.024.000']]},
            {'satirlar': [['1 ADET HAYVAN KESİM MALİYETİ', '1', '1.500']]}
          ]},
          {'grup': 'G', 'dosya': 'D', 'sayfa': 'ÖZET', 'bloklar': [
            {'satirlar': [['Tarih', 'GELEN HAYVAN SAYISI', 'BAKIM YAPILAN HAYVAN SAYISI AY SONU', 'BAKIM YAPILAN HAYVAN SAYISI ORTALAMA', 'PANAGRODA KESİLEN HAYVAN SAYISI', 'DIŞ KESİM SAYISI', 'ÖLEN HAYVAN SAYISI'],
              ['OCAK 2030', '10', '300', '10', '5', '0', '1']]}
          ]}
        ]
      }
    });
    final p = EskPlan.coz(kt);
    expect(p.rasyonKg, 8.1);
    expect(p.rasyonTl, 80.7);
    expect(p.sabitGider, 5024000);
    expect(p.kesimBirim, 1500);
    final f = eskOzetMutabakat(p, [const EskAy(ay: 'Ocak 2030', gelen: 12, hayvanGun: 300, kesim: 5, disKesim: 0, olen: 1)]);
    expect(f.single.kalem, 'Gelen hayvan');
  });
}
