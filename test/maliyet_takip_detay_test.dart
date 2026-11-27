import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/ciftlik_rapor_tam.dart';

void main() {
  test('maliyet takip ayrıntısı: çiftlik × ay toplamı ve notlar', () {
    final d = MaliyetTakipDetay.json({
      'kalemler': [
        ['İlaç ve aşı', 'A', 2030, 1, 'K1', 'Aşı X', 10, 'ADT', 5, 50],
        ['İlaç ve aşı', 'A', 2030, 1, 'K2', 'İlaç Y', 2, 'ADT', 10, 20],
        ['İlaç ve aşı', 'A', 2030, 2, 'K1', 'Aşı X', 4, 'ADT', 0, 0],
        ['Diğer malzemeler', 'B', 2030, 1, 'K3', 'Eldiven', 1, 'PAK', 3, 3],
      ],
      'notlar': [
        {'tur': 'İlaç ve aşı', 'ciftlik': 'A', 'yil': 2030, 'ay': 2, 'not': 'Deneme notu'}
      ],
    });
    expect(d.turler, ['İlaç ve aşı', 'Diğer malzemeler']);
    expect(d.aylik('İlaç ve aşı', 'A'), {203001: 70.0, 203002: 0.0});
    expect(d.ciftlikler('Diğer malzemeler'), ['B']);
    expect(d.notlar.single.not, 'Deneme notu');
  });
}
