import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yonetim_raporu/ekranlar/esk.dart';
import 'package:yonetim_raporu/tema.dart';
import 'package:yonetim_raporu/veri/model.dart';

import 'ornek_veri.dart';

Widget _uygulama(Widget ev) => MaterialApp(
      theme: temaOlustur(),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ev,
    );

final _eskJson = <String, dynamic>{
  ...ornekJson,
  'eskAylik': [
    ['Mayıs 2026', 2499, 127645, 4255, 1814, 520, 13, 5775505, 0, 1433120,
      1067176, 4576491, 1564958, 'Gerçek', 'Resmi gelir tablosu'],
    ['Ekim 2026', 4778, 94209, 3039, 1404, 0, 3, 4710450, 900000, 0, 0,
      6289392, -678942, 'Tahmini', 'Gider son 3 ay ortalaması'],
  ],
  'eskBilgi': [
    ['Başabaş', 'MİNİMUM GÜNLÜK ORTALAMA BAŞ', 3546, 'Altına düşerse zarar'],
    ['Özet', '2026 Ocak–Ağustos toplam (resmi)', -7648002, ''],
    ['Fiyat', 'Bakım besleme ücreti', '50 TL/baş/gün', 'Ekim faturası'],
    ['Öneri', '1. Asgari hacim maddesi', '3.600 baş/gün', 'Al ya da öde'],
    ['Eksik', 'ESK sözleşmesi', 'Ümit Buldu / Osman Konuk', 'Süre, fiyat'],
  ],
};

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  test('ESK satırları okunur', () {
    final v = RaporVerisi.json(_eskJson);
    expect(v.eskAylik.length, 2);
    final ekim = v.eskAylik.last;
    expect(ekim.yil, 2026);
    expect(ekim.tahmini, isTrue);
    expect(ekim.karZarar, -678942);
    expect(ekim.gelir, 4710450 + 900000);
    expect(eskBasabas(v.eskBilgi), 3546);
    expect(v.eskBilgi[2].sayi, isNull);
    expect(v.eskBilgi[2].deger, '50 TL/baş/gün');
    expect(EskAy.oku(['', 1]), isNull);
    expect(EskBilgi.oku(['Özet']), isNull);
  });

  testWidgets('ESK ekranı: başabaş, aylık ve eksik belgeler', (t) async {
    t.view.physicalSize = const Size(1080, 5400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
        _uygulama(EskEkran(veri: RaporVerisi.json(_eskJson))));
    await t.pumpAndSettle();
    expect(find.text('3.546 baş / gün ortalama'), findsOneWidget);
    expect(find.textContaining('başabaşın 507 baş altında'), findsOneWidget);

    await t.tap(find.text('Aylık'));
    await t.pumpAndSettle();
    expect(find.text('Ekim 2026'), findsOneWidget);
    expect(find.text('Tahmini'), findsOneWidget);

    await t.tap(find.text('Eksik belgeler'));
    await t.pumpAndSettle();
    expect(find.text('ESK sözleşmesi'), findsOneWidget);
    expect(find.text('Kimden: Ümit Buldu / Osman Konuk'), findsOneWidget);
  });
}
