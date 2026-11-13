import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/kategori.dart';
import 'package:yonetim_raporu/veri/model.dart';

void main() {
  GecmisVeri v(String alan, String konu, String gosterge) =>
      GecmisVeri(yil: '2026', alan: alan, konu: konu, gosterge: gosterge);

  test('çiftlik adları ana işletme altında toplanır', () {
    expect(alanKoku('Aslım (numune 1)'), 'Aslım');
    expect(alanKoku('Aslım (2)'), 'Aslım');
    expect(alanKoku('Aslım hayvancılık'), 'Aslım');
    expect(alanKoku('Pankent (Gevrekli)'), 'Pankent');
    expect(alanKoku('Konsolide (muhasebe)'), 'Konsolide');
    expect(alanKoku('ESK-Taşağıl'), 'ESK-Taşağıl');
  });

  test('kayıtlar birimlere ayrılır', () {
    expect(gecmisBirimi(v('Aslım (1)', '', 'Pancar deneme verimi')), Birim.ziraat);
    expect(gecmisBirimi(v('Aslım hayvancılık', 'Kâr/zarar', 'Dönem kâr/zarar')), Birim.hayvancilik);
    expect(gecmisBirimi(v('Aslım', 'Besi sağlığı', 'x')), Birim.hayvancilik);
    expect(gecmisBirimi(v('Göçü', 'Arazi', 'x')), Birim.ziraat);
    expect(gecmisBirimi(v('Göçü', 'Fiyat', 'x')), Birim.mali);
    expect(gecmisBirimi(v('Göçü', 'Bakım-Onarım', 'x')), Birim.isletme);
    expect(gecmisBirimi(v('Konsolide (muhasebe)', 'Genel durum', 'x')), Birim.mali);
    expect(konuBirimi('Hayvan satışı'), Birim.hayvancilik);
    expect(konuBirimi('Karar bekleyen'), Birim.isletme);
    expect(kucuk('İŞLETME'), 'işletme');
  });
}
