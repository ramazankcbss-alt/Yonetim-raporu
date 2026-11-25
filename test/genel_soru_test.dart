import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/veri/genel_soru.dart';
import 'package:yonetim_raporu/veri/model.dart';

// Yalnızca test için yapay örnek veri; gerçek şirket rakamı içermez.
void main() {
  Suru s(double sut) => Suru(toplam: 100, sagmal: 50, kuruGebe: 10, erkek: 5, sut: sut, satilan: sut - 10);
  final v = RaporVerisi(
    ozet: [OzetSatir(tarih: DateTime(2030, 1, 9), isletme: 'Fethiye Şube', dogan: 3, inekOlum: 1)],
    gunluk: [
      for (var g = 1; g <= 14; g++) GunlukSatir(tarih: DateTime(2030, 1, g), fethiye: s(1000), erentepe: s(500)),
    ],
    tarim: [
      TarimKaydi(tarih: DateTime(2030, 1, 10), ciftlik: 'Aslım', faaliyet: 'Buğday parselinde sulama yapıldı', kaynak: 'Form'),
      TarimKaydi(tarih: DateTime(2030, 1, 3), ciftlik: 'Fidanlık', faaliyet: 'Arpa gübreleme', kaynak: 'Form'),
    ],
  );
  final bugun = DateTime(2030, 1, 14);

  test('süt sorusu dönem ve çiftliğe göre hesaplanır, kaynak belirtilir', () {
    final y = genelCevapla(v, 'Bu hafta Şekersüt süt ne kadar?', bugun: bugun);
    final b = y.bolumler.firstWhere((x) => x.baslik == 'Süt ve sürü');
    expect(b.kaynak, contains('Hayvan_Günlük'));
    final metin = b.paragraflar.join(' ');
    expect(metin, contains('Şekersüt'));
    expect(metin, isNot(contains('Pan-Gev')));
  });

  test('faaliyet sorusu çiftliğe göre süzülür', () {
    final y = genelCevapla(v, 'Aslım’da neler yapıldı?', bugun: bugun);
    final m = y.bolumler.expand((x) => x.paragraflar).join(' ');
    expect(m, contains('sulama'));
    expect(m, isNot(contains('Arpa gübreleme')));
  });

  test('veri yoksa tahmin yapılmaz', () {
    final y = genelCevapla(v, 'zxqv', bugun: bugun);
    expect(y.anlasildi, isFalse);
    expect(y.bolumler.single.paragraflar.first, contains('tahmini'));
  });

  test('belirli iş sorulunca dönem verilmese de tüm kayıtlar aranır', () {
    final y = genelCevapla(v, 'gübreleme', bugun: bugun);
    expect(y.bolumler.first.paragraflar.join(' '), contains('Arpa gübreleme'));
  });

  test('serbest metin araması kayıtları bulur', () {
    final y = genelCevapla(v, 'parselinde', bugun: bugun);
    expect(y.bolumler.first.paragraflar.join(' '), contains('sulama'));
  });

  test('takip sorusu önceki sorunun konusunu ve dönemini devralır', () {
    final ilk = genelCevapla(v, 'Bu hafta Şekersüt süt ne kadar?', bugun: bugun);
    final y = genelCevapla(v, 'Peki Pan-Gev’de?', bugun: bugun, onceki: ilk.baglam);
    final m = y.bolumler.firstWhere((x) => x.baslik == 'Süt ve sürü').paragraflar.join(' ');
    expect(m, contains('Pan-Gev'));
    expect(m, isNot(contains('Şekersüt:')));
    expect(y.devralinan, contains('bu hafta'));
    expect(y.ozet.first, startsWith('Süt'));
    expect(y.oneriler, contains('Peki Şekersüt’te?'));
  });

  test('takip sorusu çiftliği devralır, "tüm çiftlikler" kaldırır', () {
    final ilk = genelCevapla(v, 'Şekersüt süt', bugun: bugun);
    final y = genelCevapla(v, 'Geçen hafta', bugun: bugun, onceki: ilk.baglam);
    expect(y.baglam.ciftlikler, {'Şekersüt'});
    final t = genelCevapla(v, 'Tüm çiftlikler', bugun: bugun, onceki: y.baglam);
    expect(t.baglam.ciftlikler, isEmpty);
  });
}
