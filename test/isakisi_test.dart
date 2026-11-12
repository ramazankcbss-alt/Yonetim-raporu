import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yonetim_raporu/ekranlar/isakisi.dart';
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
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('AkisKaydi.oku', () {
    test('12 sütunu ve dd.MM.yyyy tarihlerini okur', () {
      final k = AkisKaydi.oku([
        '1', 'Soya küspesi siparişi', 'Satınalma', 'SAT açıldı',
        'Çukurova Yem', '', '2-412888', '08.11.2026', '10.11.2026',
        'Chat – Satınalma', 'Malzeme teslim bekleniyor', 'detay',
      ]);
      expect(k, isNotNull);
      expect(k!.no, 1);
      expect(k.baslik, 'Soya küspesi siparişi');
      expect(k.bolum, 'Satınalma');
      expect(k.anahtar, '2-412888');
      expect(k.acilis, DateTime(2026, 11, 8));
      expect(k.sonGuncelleme, DateTime(2026, 11, 10));
      expect(k.sonrakiAdim, 'Malzeme teslim bekleniyor');
    });

    test('aşama ve hat bayrakları', () {
      final siparis = AkisKaydi.oku(['1', 'x', 'Sipariş']);
      final finans = AkisKaydi.oku(['2', 'y', 'Finans']);
      final bakim = AkisKaydi.oku(['3', 'z', 'Arıza-Bakım']);
      final bitti = AkisKaydi.oku(['4', 'w', 'Tamamlandı']);
      expect(siparis!.asama, 0);
      expect(siparis.hatta, isTrue);
      expect(finans!.finansta, isTrue);
      expect(finans.asama, 4);
      expect(bakim!.hatta, isFalse);
      expect(bakim.asama, -1);
      expect(bitti!.tamam, isTrue);
    });

    test('no ya da başlık yoksa null', () {
      expect(AkisKaydi.oku(['', 'x']), isNull);
      expect(AkisKaydi.oku(['1', '']), isNull);
      expect(AkisKaydi.oku(['x', 'x']), isNull);
    });

    test('RaporVerisi.json isakisi listesini okur', () {
      final v = RaporVerisi.json(ornekJson);
      expect(v.akis.length, 5);
      expect(v.akis.where((k) => k.finansta).length, 1);
      expect(v.akis.where((k) => k.tamam).length, 1);

      final bos = RaporVerisi.json({});
      expect(bos.akis, isEmpty);
    });
  });

  group('IsAkisiEkran', () {
    testWidgets('hat şeridi, bölümler ve kalemler görünür', (t) async {
      _telefon(t);
      final veri = RaporVerisi.json(ornekJson);
      await t.pumpWidget(_uygulama(IsAkisiEkran(veri: veri)));
      await t.pumpAndSettle();

      expect(find.text('İş Akışı'), findsOneWidget);
      expect(find.text('Satınalma hattı'), findsOneWidget);
      // Bir kalem başlığı ve bölüm başlığı.
      expect(find.text('1. Soya küspesi siparişi'), findsOneWidget);
      expect(find.text('Finans'), findsWidgets);
      // 7 günden eski Finans ödemesi uyarısı.
      expect(find.textContaining('Finans aşamasında 7 günden uzun'),
          findsOneWidget);
    });

    testWidgets('hat kutusuna dokununca liste süzülür', (t) async {
      _telefon(t);
      final veri = RaporVerisi.json(ornekJson);
      await t.pumpWidget(_uygulama(IsAkisiEkran(veri: veri)));
      await t.pumpAndSettle();

      // Başlangıçta her iki kalem de görünür.
      expect(find.text('1. Soya küspesi siparişi'), findsOneWidget);
      expect(find.text('2. Vetkim ilaç ödemesi'), findsOneWidget);

      // Satınalma hat kutusuna dokun (ilki = üstteki şerit kutusu; ekranda).
      await t.tap(find.text('Satınalma').first);
      await t.pumpAndSettle();

      // Yalnızca Satınalma kalemi kalır.
      expect(find.text('1. Soya küspesi siparişi'), findsOneWidget);
      expect(find.text('2. Vetkim ilaç ödemesi'), findsNothing);

      // Tümü ile geri dön.
      await t.tap(find.text('Tümü'));
      await t.pumpAndSettle();
      expect(find.text('2. Vetkim ilaç ödemesi'), findsOneWidget);
    });

    testWidgets('veri yoksa boş durum', (t) async {
      _telefon(t);
      await t.pumpWidget(_uygulama(IsAkisiEkran(veri: RaporVerisi.json({}))));
      await t.pumpAndSettle();
      expect(find.textContaining('Henüz iş akışı kaydı yok'), findsOneWidget);
    });
  });
}
