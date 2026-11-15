import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/model.dart';

void main() {
  final v = AracVerisi.json({
    'aracListe': [
      ['TRK-07', 'Traktör', 'NH', '', 'Panagro - Aslım', '1240', 'Aktif'],
      ['PLK-02', 'Pulluk', '', '', 'Panagro - Aslım', '12', 'Aktif', '', '', '', '', '', 'Makine-Ekipman'],
    ],
    'aracKullanim': [
      ['K00001', '14.11.2026', 'TRK-07', 'Ali Veli', '05000000000', 'Panagro - Aslım', '14.11.2026 08:00',
        '14.11.2026 12:00', '1230', '1234', '4', 'Ekim', 'Yapıldı', 'Yapılmadı', 'Yapıldı', 'Yapıldı', '', 'Onaylandı',
        '', '', 'Personel', '', 'PLK-02'],
      ['K00002', '14.11.2026', 'TRK-07', 'Can Kaya', '05000000001', 'Panagro - Aslım', '14.11.2026 13:00',
        '', '1234', '', '', '', '', '', '', '', '', 'Devam ediyor'],
    ],
    'aracPlan': [
      ['TRK-07', 'Motor yağı ve yağ filtresi', '250', '1000', ''],
    ],
  });

  test('araç verisi okunur, bakım uyarısı ve olay sorgulama çalışır', () {
    expect(v.araclar.first.sayac, 1240);
    expect(v.araclar.last.ekipman, isTrue);
    expect(v.kullanim.first.birlesik, 'TRK-07 + PLK-02');
    expect(v.aracGecmisi('PLK-02').single.personel, 'Ali Veli');
    expect(v.aktif.single.personel, 'Can Kaya');
    expect(v.kullanim.first.eksikKontroller, ['Hava filtresi']);
    final u = v.bakimUyarilari();
    expect(u.single.kalan, 10);
    final s = v.olaySorgula('TRK-07', DateTime(2026, 11, 14, 12, 30));
    expect(s.once?.personel, 'Ali Veli');
    expect(s.sonra?.personel, 'Can Kaya');
    expect(s.sirada, isNull);
  });
}
