import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yonetim_raporu/ekranlar/arsiv.dart';
import 'package:yonetim_raporu/ekranlar/personel.dart';
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

  group('model okuma', () {
    test('ArsivKaydi.oku', () {
      final a = ArsivKaydi.oku([
        '02.11.2026', 'Puantaj / İK', 'Puantaj Ekim', 'Osman',
        'özet', 'dosya.xlsx', 'Ekim 2026'
      ]);
      expect(a, isNotNull);
      expect(a!.konu, 'Puantaj Ekim');
      expect(a.kategori, 'Puantaj / İK');
      expect(a.ekliMi, isTrue);
      expect(a.aylikMi, isTrue);
      expect(a.tarih, DateTime(2026, 11, 2));
      expect(a.aranabilir.contains('osman'), isTrue);
    });

    test('PersonelKaydi.oku', () {
      final p = PersonelKaydi.oku([
        'Ekim 2026', 'Puantaj', 'Puantaj ve mesai', 'İK', 'özet', '', '02.11.2026'
      ]);
      expect(p, isNotNull);
      expect(p!.donem, 'Ekim 2026');
      expect(p.tur, 'Puantaj');
      expect(p.belgeliMi, isFalse);
    });

    test('konu yoksa null', () {
      expect(ArsivKaydi.oku(['02.11.2026', 'Kat', '']), isNull);
      expect(PersonelKaydi.oku(['Ekim', 'Puantaj', '']), isNull);
    });

    test('RaporVerisi.json arsiv ve personel', () {
      final v = RaporVerisi.json(ornekJson);
      expect(v.arsiv.length, 2);
      expect(v.personel.length, 2);
      final bos = RaporVerisi.json({});
      expect(bos.arsiv, isEmpty);
      expect(bos.personel, isEmpty);
    });
  });

  group('ArsivEkran', () {
    testWidgets('liste ve arama', (t) async {
      _telefon(t);
      final veri = RaporVerisi.json(ornekJson);
      await t.pumpWidget(_uygulama(ArsivEkran(veri: veri)));
      await t.pumpAndSettle();

      expect(find.text('Belge Havuzu'), findsOneWidget);
      expect(find.text('Sağımhane dezenfektan talebi'), findsOneWidget);

      await t.enterText(find.byType(TextField), 'dezenfektan');
      await t.pumpAndSettle();
      expect(find.text('Sağımhane dezenfektan talebi'), findsOneWidget);
      expect(find.text('Çiftlikler Puantaj ve Fazla Mesailer (Ekim2026)'),
          findsNothing);
    });
  });

  group('PersonelEkran', () {
    testWidgets('dönem grubu ve özet uyarısı', (t) async {
      _telefon(t);
      final veri = RaporVerisi.json(ornekJson);
      await t.pumpWidget(_uygulama(PersonelEkran(veri: veri)));
      await t.pumpAndSettle();

      expect(find.text('Personel / Puantaj'), findsOneWidget);
      // İlk sekme personel listesi; belgeler ikinci sekmede.
      await t.tap(find.textContaining('Puantaj / İK'));
      await t.pumpAndSettle();
      expect(find.textContaining('kişi bazlı maaş'), findsOneWidget);
      expect(find.textContaining('Ekim 2026'), findsWidgets);
      expect(find.text('Çiftlikler Taşeron Personel Puantajı'), findsOneWidget);
    });
  });
}
