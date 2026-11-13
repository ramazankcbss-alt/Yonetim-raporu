import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/model.dart';
import 'package:yonetim_raporu/veri/ozel.dart';

void main() {
  test('Kisi.oku alanları ve anahtarları okur', () {
    final k = Kisi.oku([
      'Selin Ak',
      'Çiftlikler',
      '0532 111 22 33',
      'ornek1@ornek.com',
      'Özge, Ak',
      '',
    ])!;
    expect(k.ad, 'Selin Ak');
    expect(k.anahtarlar, ['özge', 'demirel']);
    expect(k.whatsappNumarasi, '905321112233');
    expect(k.epostaVar, isTrue);
  });

  test('Ad yoksa null; telefon/e-posta boşsa yok sayılır', () {
    expect(Kisi.oku(['', 'x']), isNull);
    final k = Kisi.oku(['Levent Su'])!;
    expect(k.telefonVar, isFalse);
    expect(k.epostaVar, isFalse);
    expect(k.anahtarlar, isEmpty);
  });

  test('Telefon biçimleri', () {
    expect(const Kisi(ad: 'a', telefon: '+90 532 111 22 33').whatsappNumarasi,
        '905321112233');
    expect(const Kisi(ad: 'a', telefon: '5321112233').whatsappNumarasi,
        '905321112233');
    expect(const Kisi(ad: 'a', telefon: '123').whatsappNumarasi, isNull);
  });

  test('İş eşleşmesi Türkçe büyük/küçük harften etkilenmez', () {
    final k = Kisi.oku(['Kemal Tan', '', '', '', 'Kemal Tan, Tan'])!;
    const i = Is(no: 1, konu: 'ESK kesim', sorumlu: 'ÜMİT BULDU');
    const j = Is(no: 2, konu: 'Başka iş', sorumlu: 'Selin Ak');
    expect(k.isEslesir(i), isTrue);
    expect(k.isEslesir(j), isFalse);
    const a = AkisKaydi(no: 3, baslik: 'Arpa', firma: 'Şekersüt – Kemal Tan');
    expect(k.akisEslesir(a), isTrue);
  });

  test('Anahtar yoksa ad ile eşleşir', () {
    final k = Kisi.oku(['Cem Uçar'])!;
    expect(k.isEslesir(const Is(no: 1, konu: 'x', sorumlu: 'Cem Uçar')),
        isTrue);
  });

  test('RaporVerisi.json kisiler alanını okur', () {
    final v = RaporVerisi.json({
      'ok': true,
      'kisiler': [
        ['Ayla Deniz', '', '', 'ornek2@ornek.com', 'Ayla', '']
      ],
    });
    expect(v.kisiler.single.ad, 'Ayla Deniz');
  });

  test('PersonelKisi ve KisiOlayi okunur', () {
    final v = RaporVerisi.json({
      'personelListesi': [
        ['Eren Kılıç', 'Çiftlik İşletme Operatörü', 'Şekersüt Çiftlik', '05000000011', '99999']
      ],
    });
    expect(v.personelListesi.single.gorev, 'Çiftlik İşletme Operatörü');
    final o = OzelVeri.json({
      'kisiOlaylari': [
        ['2026-11-12', 'Selin Ak', 'Gecikme', 'Vetkim ödemesi', 'Cevap yok',
          'Olumsuz', '', 'Chat', 'O-1'],
        ['2026-11-10', 'Selin Ak', 'Eksik bilgi', 'Soya', '', 'Olumlu',
          '2026-11-12', 'Chat', 'O-2'],
      ],
    });
    expect(o.kisiOlaylari.length, 2);
    expect(o.kisiOlaylari.first.olumlu, isFalse);
    expect(o.kisiOlaylari.last.olumlu, isTrue);
  });

  test('Makam sırası: yönetim üstte, güvenlik altta', () {
    expect(makamSirasi('Tarım Ve Hayvancılık Grup Müdürü'), 0);
    expect(makamSirasi('Çiftlikler İşletme Müdürü'), 1);
    expect(makamSirasi('Şekersüt Çiftlik İşletme Yön. Yrd.'), 2);
    expect(makamSirasi('Raporlama Uzmanı – Panagro Aslım'), 3);
    expect(makamSirasi('Veteriner Sağlık Teknikeri'), 4);
    expect(makamSirasi('Çiftlik İşletme Operatörü'), 5);
    expect(makamSirasi('Güvenlik Personeli'), 7);
  });
}
