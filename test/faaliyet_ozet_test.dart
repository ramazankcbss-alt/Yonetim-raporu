import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/faaliyet_ozet.dart';
import 'package:yonetim_raporu/veri/model.dart';

void main() {
  test('Formen notu ve işçi bilgisi çıkarılır', () {
    expect(
        faaliyetMaddeleri("Formen bildirimi (icmalde henüz yok): Fidanlık "
            "bölümünde yağmurlama serme işlemi yapılıyor, serilen alan 65 dekar "
            "(Örnekköy'den 11 işçi)"),
        ['Fidanlık bölümünde yağmurlama serme işlemi yapılıyor, serilen alan 65 dekar']);
  });

  test('Operatör adları çıkarılır, pivot korunur', () {
    final m = faaliyetMaddeleri(
        'Arpa ekimine başlandı, dekara 25 kg tohum (7. pivot, Operatör: Ali Veli); '
        'kantar yanı çekimine başlandı (Operatör: Can Tan); şeker pancarı sökümüne başlandı');
    expect(m, [
      'Arpa ekimine başlandı, dekara 25 kg tohum (7. pivot)',
      'Kantar yanı çekimine başlandı',
      'Şeker pancarı sökümüne başlandı',
    ]);
    expect(m.join(' '), isNot(contains('Ali')));
  });

  test('Tire ile yazılan pivot ve kişi adı', () {
    expect(
        faaliyetMaddeleri('Yonca – tırmık çekimine başlandı. – 6.pivot – ali veli; '
            'Kürüm merdane çekimine başlandı. – 7.pivot – can tan'),
        [
          'Yonca – tırmık çekimine başlandı (6. pivot)',
          'Kürüm merdane çekimine başlandı (7. pivot)',
        ]);
  });

  test('Çiftlik bazında gruplanır, tekrarlar ayıklanır', () {
    final o = faaliyetOzeti([
      TarimKaydi(tarih: DateTime(2026, 11, 15), ciftlik: 'Şekersüt', faaliyet: 'Formen bildirimi: tarla sürümü bitti'),
      TarimKaydi(tarih: DateTime(2026, 11, 14), ciftlik: 'Şekersüt', faaliyet: 'Tarla sürümü bitti.'),
      TarimKaydi(tarih: DateTime(2026, 11, 14), ciftlik: 'Aslım', faaliyet: 'Arpa ekimi'),
    ]);
    expect(o.map((e) => e.ciftlik), ['Aslım', 'Şekersüt']);
    expect(o[1].maddeler, ['Tarla sürümü bitti']);
  });
}
