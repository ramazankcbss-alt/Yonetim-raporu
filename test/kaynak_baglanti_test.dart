import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/esk_plan.dart';
import 'package:yonetim_raporu/veri/kaynak_baglanti.dart';
import 'package:yonetim_raporu/veri/kaynak_envanteri.dart';

Map<String, Object> _t(String grup, String sayfa, List<List<String>> satirlar) =>
    {'grup': grup, 'dosya': 'D', 'sayfa': sayfa, 'bloklar': [{'satirlar': satirlar}]};

void main() {
  test('yönetim gündemi, ekim planı değişimi, ESK fiyat ve maliyet blokları', () {
    final kt = KaynakTablolari.json({
      'menuler': {
        'gecmis': [
          _t('Değerlendirme Raporu (deneme)', 'çözüm bekleyen', [['', 'Başlık'], ['1', 'Birinci konu'], ['2']]),
          _t('Değerlendirme Raporu (deneme)', 'Yatırımlar', [['ÇİFTLİK', 'DEVAM', 'PLAN'], ['A ÇİFTLİĞİ', 'Kuyu açıldı', 'Depo yapılacak'], ['', 'Traktör alındı']]),
        ],
        'ziraat': [
          _t('Ekim planı – aylık raporlar', 'OCAK', [['', 'Buğday', 'Toplam Dekar'], ['X Çiftliği', '100', '100']]),
          _t('Ekim planı – aylık raporlar', 'ŞUBAT', [['', 'Buğday', 'Toplam Dekar'], ['X Çiftliği', '120', '120']]),
        ],
        'esk': [
          _t('ESK', 'KESİM-SAKATAT-BAKIM-NAKLİYE', [['01.01.2030', 'Eski Fiyat', 'Yeni Fiyat '], ['Bakım', '40 ₺ günlük', '45 ₺ günlük hayvan başı']]),
          _t('ESK', 'ESK MALİYET', [['ESK EYLÜL BAKIM BESLEME', '', 'ESK EKİM BAKIM BESLEME', ''], ['GELEN HAYVAN SAYISI', '10', 'GELEN HAYVAN SAYISI', '20']]),
        ],
      }
    });
    final g = yonetimGundemi(kt);
    expect(g.first.$2, ['Birinci konu']);
    expect(g.any((x) => x.$1 == 'Planlanan yatırımlar' && x.$2.single == 'A ÇİFTLİĞİ: Depo yapılacak'), isTrue);
    expect(ekimPlaniDegisimleri(kt).single.aciklama, contains('100 → 120'));
    expect(eskSozlesmeFiyatlari(kt)['Bakım'], 45);
    final p = EskPlan.coz(kt);
    expect([for (final m in p.maliyetAylari) (m.yil, m.ay, m.gelen)], [(2025, 9, 10.0), (2025, 10, 20.0)]);
  });
}
