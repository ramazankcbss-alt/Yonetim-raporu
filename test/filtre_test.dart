import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yonetim_raporu/ekranlar/isler.dart';
import 'package:yonetim_raporu/ekranlar/tarim.dart';
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

void _telefon(WidgetTester t) {
  t.view.physicalSize = const Size(1080, 5400);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('faaliyetHayvancilik', () {
    test('hayvancılık faaliyetleri', () {
      expect(faaliyetHayvancilik('Sağım yapıldı'), isTrue);
      expect(faaliyetHayvancilik('Buzağı aşılaması tamamlandı'), isTrue);
      expect(faaliyetHayvancilik('İnek kesimi'), isTrue);
      expect(faaliyetHayvancilik('Suni tohumlama'), isTrue);
      expect(faaliyetHayvancilik('Besi danası yem takibi'), isTrue);
    });

    test('ziraat faaliyetleri', () {
      expect(faaliyetHayvancilik('Arpa ekimi yapıldı: 82 dekar'), isFalse);
      expect(faaliyetHayvancilik('Pancar hasadı'), isFalse);
      expect(faaliyetHayvancilik('Yonca biçimi 150 da'), isFalse);
      // "Şekersüt" içindeki "süt" tetiklememeli.
      expect(faaliyetHayvancilik('Şekersüt yağmurlama boruları toplandı'),
          isFalse);
    });

    test('TarimKaydi.hayvancilik getter', () {
      final k = TarimKaydi(
          tarih: DateTime(2026, 11, 5),
          ciftlik: 'Aslım',
          faaliyet: 'Sağım ve buzağı bakımı');
      expect(k.hayvancilik, isTrue);
    });
  });

  group('TarimEkran Ziraat/Hayvancılık geçişi', () {
    testWidgets('varsayılan ziraat; hayvancılığa geçince besi gelir',
        (t) async {
      _telefon(t);
      final veri = RaporVerisi.json(ornekJson);
      await t.pumpWidget(_uygulama(Scaffold(body: TarimEkran(veri: veri))));
      await t.pumpAndSettle();

      // Ziraat varsayılan: Ekim var, Besi yok.
      expect(find.text('Ekim Alanları (dekar)'), findsOneWidget);
      expect(find.text('Besi Planı ve Kesim'), findsNothing);

      await t.tap(find.text('Hayvancılık'));
      await t.pumpAndSettle();

      expect(find.text('Besi Planı ve Kesim'), findsOneWidget);
      expect(find.text('Ekim Alanları (dekar)'), findsNothing);
    });
  });

  group('IslerEkran sayaç filtresi', () {
    testWidgets('Bekliyor sayacına dokununca sadece bekleyenler', (t) async {
      _telefon(t);
      final veri = RaporVerisi.json(ornekJson);
      await t.pumpWidget(_uygulama(IslerEkran(veri: veri)));
      await t.pumpAndSettle();

      expect(find.text('Bekleyen işler (1)'), findsOneWidget);
      expect(find.text('Devam eden işler (1)'), findsOneWidget);

      await t.tap(find.text('Bekliyor'));
      await t.pumpAndSettle();

      expect(find.text('Bekleyen işler (1)'), findsOneWidget);
      expect(find.text('Devam eden işler (1)'), findsNothing);

      // Tekrar dokun → tümü döner.
      await t.tap(find.text('Bekliyor'));
      await t.pumpAndSettle();
      expect(find.text('Devam eden işler (1)'), findsOneWidget);
    });
  });
}
