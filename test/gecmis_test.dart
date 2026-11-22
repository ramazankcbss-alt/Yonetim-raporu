import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/ekranlar/gecmis.dart';
import 'package:yonetim_raporu/veri/gecmis_sinif.dart';
import 'package:yonetim_raporu/veri/model.dart';

void main() {
  final j = {
    'hayvanOzet': [],
    'hayvanGunluk': [],
    'tarim': [],
    'gecmis': [
      ['2024', '', 'Şekersüt', 'Süt', 'Ortalama süt verimi', '24.1', 'kg/gün/inek', 'Değ.Raporu', '448 sağılan'],
      ['2025', '', 'Şekersüt', 'Süt', 'Ortalama süt verimi', 25.2, 'kg/gün/inek', 'Değ.Raporu', ''],
      ['2025', 'Yıllık', 'Taşağıl hayvancılık', 'Kâr/zarar', 'Yıllık dönem kâr/zarar', -15752709, 'TL', 'x', ''],
      ['2021-2025', '', 'Aslım', 'Kesim', '5 yıllık kesim', 7806, 'baş', 'x', ''],
      ['2025', '', 'Aslım', 'Tarım', 'Buğday net kazanç', -16364, 'TL', 'x', ''],
      ['2025', '', 'Aslım', 'Tarım', 'Buğday hasat tonajı', 301400, 'kg', 'x', ''],
      ['2025', '', 'Aslım', 'Tarım', 'Ekim alanı', 4911, 'dekar', 'x', ''],
    ],
    'dersler': [
      ['2025', 'Aslım', 'Tarım', 'Buğday zarar etti.', 'Yonca/pancar daha iyi.', 'x'],
    ],
  };

  test('geçmiş kayıtları okunur', () {
    final v = RaporVerisi.json(j);
    expect(v.gecmis.length, 7);
    expect(v.gecmis.first.sayi, 24.1);
    expect(v.gecmis[3].yilNo, 2025);
    expect(gecmisDeger(v.gecmis[1]), contains('25'));
    expect(v.dersler.single.sonuc, 'Yonca/pancar daha iyi.');
    expect(kapsananYillar('2021-2025'), {2021, 2022, 2023, 2024, 2025});
    expect(kapsananYillar('2025'), {2025});
    expect(kapsananYillar(''), isEmpty);
  });

  testWidgets('geçmiş ekranı menü ve alt sayfalar', (t) async {
    final v = RaporVerisi.json(j);
    t.view.physicalSize = const Size(2400, 4800);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: GecmisEkran(veri: v)));
    await t.pumpAndSettle();
    expect(find.text('Bilgi Bankası'), findsOneWidget);
    expect(find.text('Hayvancılık'), findsOneWidget);

    await t.tap(find.text('Tüm kayıtlarda ara'));
    await t.pumpAndSettle();
    expect(find.text('Ortalama süt verimi'), findsOneWidget);
    expect(find.text('Yıllık dönem kâr/zarar'), findsOneWidget);
    await t.tap(find.text('2024 (2)'));
    await t.pumpAndSettle();
    expect(find.text('Ortalama süt verimi'), findsOneWidget);
    expect(find.text('Yıllık dönem kâr/zarar'), findsNothing);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();

    expect(gecmisAnaAlan(v.gecmis[1]), 'Hayvancılık');
    expect(find.text('Yıllara göre'), findsOneWidget);
    expect(find.text('Ürünlere göre'), findsOneWidget);
    expect(find.text('Çiftliklere göre'), findsOneWidget);

    // Yıl → alan → ürün → (tek çiftlik kendiliğinden) → sınıflar
    await t.tap(find.text('Yıllara göre'));
    await t.pumpAndSettle();
    expect(find.text('2025'), findsOneWidget);
    expect(find.text('2021-2025'), findsOneWidget);
    await t.tap(find.text('2025'));
    await t.pumpAndSettle();
    expect(find.text('Hayvancılık'), findsOneWidget);
    await t.tap(find.text('Tarım'));
    await t.pumpAndSettle();
    expect(find.text('Tüm ürünler (genel)'), findsOneWidget);
    await t.tap(find.text('Buğday'));
    await t.pumpAndSettle();
    expect(find.text('Yıllar › 2025 › Tarım › Buğday › Aslım'), findsOneWidget);
    expect(find.text('Buğday hasat tonajı'), findsOneWidget);
    expect(find.text('Buğday net kazanç'), findsOneWidget);
    expect(find.text('Ekim alanı'), findsNothing);
    expect(find.text('Tüm sınıflar (2)'), findsOneWidget);
    await t.tap(find.text('Verim ve üretim (1)'));
    await t.pumpAndSettle();
    expect(find.text('Buğday net kazanç'), findsNothing);
    for (var i = 0; i < 4; i++) {
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
    }

    // Çiftlik → … ; "Tümünü sınıflara göre gör"
    await t.tap(find.text('Çiftliklere göre'));
    await t.pumpAndSettle();
    await t.tap(find.text('Aslım'));
    await t.pumpAndSettle();
    await t.tap(find.text('Tümünü sınıflara göre gör'));
    await t.pumpAndSettle();
    expect(find.text('Ekim alanı'), findsOneWidget);
    expect(find.text('5 yıllık kesim'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
    }

    await t.tap(find.text('Dersler'));
    await t.pumpAndSettle();
    expect(find.text('Buğday zarar etti.'), findsOneWidget);
  });

  test('ürün, çiftlik ve sınıf ayrımı', () {
    GecmisVeri g(String alan, String konu, String gosterge, {String birim = '', String deger = '1'}) =>
        GecmisVeri(yil: '2025', alan: alan, konu: konu, gosterge: gosterge, birim: birim, deger: deger,
            sayi: double.tryParse(deger));

    // Şekersüt'teki tarla işleri tarım sayılır
    final is1 = g('Şekersüt', 'Tarım', 'İş tamamlandı', deger: 'Buğday ekimi bitti');
    expect(gecmisAnaAlan(is1), 'Tarım');
    expect(gecmisUrun(is1), 'Buğday');
    expect(gecmisSinif(is1), 'Saha faaliyetleri');

    expect(gecmisUrun(g('Aslım', 'Tarım', "4'lü karışım net kazanç", birim: 'TL')), "4'lü karışım");
    expect(gecmisUrun(g('Aslım', 'Stok', 'Stok sayımı: Misir Silaji(Tarla)', birim: 'kg')), 'Silajlık mısır');
    expect(gecmisUrun(g('Şekersüt', 'Stok', 'Stok sayımı: Misir Silaji', birim: 'kg')), 'Yem ve girdiler');
    expect(gecmisUrun(g('Şekersüt', 'Süt', 'Ortalama süt verimi')), 'Süt');
    expect(gecmisUrun(g('Şekersüt', 'Sürü hareketi', 'Şekersüte gi̇den')), 'Sürü geneli');
    expect(gecmisUrun(g('Pangev', 'Kesim', 'Ortalama karkas ağırlığı')), 'Besi, kesim ve et');
    expect(gecmisUrun(g('Şekersüt', 'Üreme', 'Doğum')), 'Damızlık, üreme ve buzağı');

    expect(gecmisSinif(g('Aslım', 'Tarım', 'Ekim planı', birim: 'dekar')), 'Ekim alanı ve arazi');
    expect(gecmisSinif(g('Aslım', 'Tarım', 'Arpa hasat tonajı', birim: 'kg')), 'Verim ve üretim');
    expect(gecmisSinif(g('Aslım', 'Tarım', 'Pancar birikmiş maliyeti', birim: 'TL')), 'Maliyet');
    expect(gecmisSinif(g('Şekersüt', 'Maliyet', '1 litre süt maliyeti', birim: 'TL')), 'Maliyet');
    expect(gecmisSinif(g('Aslım', 'Tarım', 'Pancar net kazanç', birim: 'TL')), 'Gelir ve kâr/zarar');
    expect(gecmisSinif(g('Şekersüt', 'Buzağı sağlığı', 'Ölen buzağı')), 'Sağlık');
    expect(gecmisSinif(g('Şekersüt', 'Sürü hareketi', 'Zorunlu dana kesi̇m')), 'Sürü hareketi ve kesim');
    expect(gecmisSinif(g('Şekersüt', 'Fiyat', 'Süt satış fiyatı', birim: 'TL/lt')), 'Satış ve fiyat');

    expect(gecmisCiftlik(g('Taşağıl-Ormanlık', 'Tarım', 'Ekim alanı')), 'Taşağıl');
    expect(gecmisCiftlik(g('ESK-Taşağıl', 'Kesim', 'Kesilen dana')), 'ESK-Taşağıl');
    expect(gecmisCiftlik(g('Aslım hayvancılık', 'Süt', 'x')), 'Aslım');
    expect(gecmisCiftlik(g('Tarım ortak', 'Tarım', 'x')), ortakCiftlik);
    expect(gecmisCiftlik(g('Tüm çiftlikler', 'Personel', 'x')), ortakCiftlik);

    final yillar = ['2021-2025', '', '2024', '2026'].map((y) => y.isEmpty ? yilsizEtiket : y).toList()
      ..sort(yilKarsilastir);
    expect(yillar, ['2026', '2024', '2021-2025', yilsizEtiket]);
  });
}
