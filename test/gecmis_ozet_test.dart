// Sentetik veriyle geçmiş yıl özeti testleri.
import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/gecmis_ozet.dart';

void main() {
  test('çiftlik adları tek biçime gelir', () {
    expect(gecmisCiftlikAdi('Şekersüt Çiftliği'), 'Şekersüt');
    expect(gecmisCiftlikAdi('ŞEKERSÜT'), 'Şekersüt');
    expect(gecmisCiftlikAdi('Pangev (Erentepe) Çiftliği'), 'Pan-Gev');
    expect(gecmisCiftlikAdi('Panagro Aslım Besi Çiftliği'), 'Aslım');
    expect(gecmisCiftlikAdi('TAŞAĞIL'), 'Taşağıl');
    expect(gecmisCiftlikAdi('Panagro Göçü Çiftliği'), 'Göçü');
    expect(gecmisCiftlikAdi('TOPLAM NET GELİR'), 'Toplam');
  });

  test('özet ayrıştırma ve matris', () {
    final o = GecmisOzet.json({
      'kesim': [
        {'yil': 2030, 'ciftlik': 'ASLIM', 'adet': 10, 'karkas': 3000, 'satis': 100},
        {'yil': 2031, 'ciftlik': 'ASLIM', 'adet': 5, 'karkas': 2000},
      ],
      'alim': [
        {'yil': 2030, 'ciftlik': 'ASLIM', 'ic': 1, 'dis': 2, 'toplam': 3}
      ],
      'gostergeler': [
        {'tablo': 'T', 'ciftlik': 'Şekersüt Çiftliği', 'yil': 2030, 'olcu': 'Ölüm Oranı', 'deger': 6.6, 'yuzde': true},
        {'tablo': 'T', 'ciftlik': 'Şekersüt Çiftliği', 'yil': 2031, 'olcu': 'Ölüm Oranı', 'deger': 2.7, 'yuzde': true},
      ],
    });
    expect(o.kesimYillari, [2030, 2031]);
    expect(o.kesim.first.ortKarkas, 300);
    expect(o.alim.single.ciftlik, 'Aslım');
    expect(o.matris('T')['Ölüm Oranı']!['Şekersüt']![2031], 2.7);
    expect(o.tablolar, ['T']);
  });
}
