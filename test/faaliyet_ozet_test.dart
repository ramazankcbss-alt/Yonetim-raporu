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

  test('Yalnızca ad-soyad içeren parantez çıkarılır', () {
    expect(faaliyetMaddeleri('Buğday ekimi yapıldı: 83 dekar (Ali Veli, İsa Can)'),
        ['Buğday ekimi yapıldı: 83 dekar']);
  });

  TarimKaydi k(int g, String c, String f) =>
      TarimKaydi(tarih: DateTime(2026, 11, g), ciftlik: c, faaliyet: f);

  test('Yönetici özeti: günlük kayıtlar toplanır, ara bilgiler atılır', () {
    final o = yoneticiOzeti([
      k(10, 'Taşağıl', '15 ton Halis buğday tohumu teslim alındı'),
      k(10, 'Taşağıl', 'Buğday ekimi yapılıyor, 120 dekar, dekara 25 kg Halis tohum'),
      k(11, 'Taşağıl', 'Şeker pancarı: söküm makinesi geldi, sökümüne başlandı'),
      k(11, 'Taşağıl', 'Buğday: ekime başlandı, 50 dekar, dekara 15 kg DAP (Ali Veli)'),
      k(12, 'Taşağıl', '50 dekar merdane çekimi'),
      k(13, 'Taşağıl', 'Şeker pancarı sökümü bitti; Söküm makinesi Şekersüt çiftliğine gönderildi'),
      k(14, 'Taşağıl', '220 dekar merdane çekimi; Buğday: toplam 420 dekar ekim yapıldı'),
      k(12, 'Fidanlık', 'Buğday ekimi yapıldı: 83 dekar (Ali Veli)'),
      k(14, 'Fidanlık', 'Ekim bitti: toplam 669 dekar Touareg arpa ve 150 dekar buğday ekildi'),
      k(13, 'Aslım', 'Pancar söküm makinesi arızalandı; Kalan sökülecek alan 150 dekar'),
      k(14, 'Aslım', '6. pivot etrafı 110 dekar ve 7. pivot 240 dekar alanda kombine çekimi tamamlandı'),
      k(14, 'Aslım', 'Arpa ekimine başlandı, dekara 25 kg tohum (7. pivot, Operatör: Ali Veli)'),
      k(15, 'Şekersüt', 'Deneme pancarlarının sökümü bitti (85 dekar); sökümü devam ediyor: 425 dekar'),
      k(16, 'Şekersüt', 'Formen bildirimi (icmalde henüz yok): şeker pancarı sökümü bitti, toplam 700 dekar; söküm makinesi Aslım\'a gönderildi'),
    ]);
    final m = {for (final x in o) x.ciftlik: x.maddeler};
    expect(m['Taşağıl'], [
      'Buğday ekimi: 420 dekar',
      'Merdane çekimi: 270 dekar',
      '15 ton Halis buğday tohumu teslim alındı',
    ]);
    expect(m['Fidanlık'], ['Arpa ekimi: 669 dekar (tamamlandı)', 'Buğday ekimi: 150 dekar (tamamlandı)']);
    expect(m['Aslım'], ['Hasat (kombine): 350 dekar (tamamlandı)']);
    expect(m['Şekersüt'], ['Şeker pancarı sökümü: 700 dekar (tamamlandı)']);
  });

  test('Form kayıtları: malzeme toplanır, aynı gün icmal ikinci kez sayılmaz', () {
    final o = yoneticiOzeti([
      TarimKaydi(tarih: DateTime(2026, 11, 16), ciftlik: 'Taşağıl',
          faaliyet: 'Buğday ekimi: 120 dekar (7. pivot), tamamlandı; dekara 25 kg tohum', kaynak: 'Form'),
      TarimKaydi(tarih: DateTime(2026, 11, 16), ciftlik: 'Taşağıl',
          faaliyet: 'Buğday ekimi yapılıyor, 120 dekar'),
      TarimKaydi(tarih: DateTime(2026, 11, 16), ciftlik: 'Taşağıl',
          faaliyet: 'Malzeme girişi: 15 ton Halis buğday tohumu (dış tedarik); Belge no: 123', kaynak: 'Form'),
      TarimKaydi(tarih: DateTime(2026, 11, 17), ciftlik: 'Taşağıl',
          faaliyet: 'Malzeme girişi: 10 ton Halis buğday tohumu (dış tedarik)', kaynak: 'Form'),
      TarimKaydi(tarih: DateTime(2026, 11, 17), ciftlik: 'Taşağıl',
          faaliyet: 'Merdane çekimi – Buğday: 45,5 dekar', kaynak: 'Form'),
    ]);
    expect(o.single.maddeler, [
      'Buğday ekimi: 120 dekar (tamamlandı)',
      'Merdane çekimi: 46 dekar',
      'Malzeme girişi: 25 ton Halis buğday tohumu (dış tedarik)',
    ]);
  });

  test('İcmal–form karşılaştırması: fark varsa icmal esas, yalnızca formdaki iş işaretli', () {
    final kayitlar = [
      TarimKaydi(tarih: DateTime(2026, 11, 16), ciftlik: 'Aslım', faaliyet: 'Buğday ekimi yapıldı, 100 dekar'),
      TarimKaydi(tarih: DateTime(2026, 11, 16), ciftlik: 'Aslım', faaliyet: 'Buğday ekimi: 120 dekar', kaynak: 'Form'),
      TarimKaydi(tarih: DateTime(2026, 11, 16), ciftlik: 'Aslım', faaliyet: 'Tarla sürümü: 300 dekar', kaynak: 'Form'),
      TarimKaydi(tarih: DateTime(2026, 11, 17), ciftlik: 'Aslım', faaliyet: '200 dekar merdane çekimi'),
      TarimKaydi(tarih: DateTime(2026, 11, 17), ciftlik: 'Aslım', faaliyet: 'Merdane çekimi: 198 dekar', kaynak: 'Form'),
    ];
    final t = {for (final x in teyitDurumu(kayitlar)) x.is_: x.durum};
    expect(t, {
      'Buğday ekimi': 'Fark var',
      'Tarla sürümü': 'İcmalde yok',
      'Merdane çekimi': 'Teyitli',
    });
    expect(yoneticiOzeti(kayitlar).single.maddeler, [
      'Buğday ekimi: 100 dekar',
      'Tarla sürümü: 300 dekar',
      'Merdane çekimi: 200 dekar',
    ]);
  });

  test('Kontrol bekleyen formen kaydı rapora girmez, ekranda işaretli görünür', () {
    final kayitlar = [
      TarimKaydi(tarih: DateTime(2026, 11, 16), ciftlik: 'Aslım', faaliyet: 'Arpa ekimi: 200 dekar', kaynak: 'Form-Bekliyor'),
      TarimKaydi(tarih: DateTime(2026, 11, 16), ciftlik: 'Aslım', faaliyet: 'Tarla sürümü: 150 dekar', kaynak: 'Form'),
    ];
    expect(yoneticiOzeti(kayitlar).single.maddeler, ['Tarla sürümü: 150 dekar']);
    expect(faaliyetOzeti(kayitlar).single.maddeler.first, 'Arpa ekimi: 200 dekar (kontrol bekliyor)');
    expect(kontrolBekleyen(kayitlar), 1);
  });
}
