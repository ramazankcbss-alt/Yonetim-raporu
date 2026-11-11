import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yonetim_raporu/ekranlar/ana.dart';
import 'package:yonetim_raporu/ekranlar/kurulum.dart';
import 'package:yonetim_raporu/pdf/rapor_pdf.dart';
import 'package:yonetim_raporu/servis/veri_servisi.dart';
import 'package:yonetim_raporu/tema.dart';
import 'package:yonetim_raporu/veri/model.dart';

import 'ornek_veri.dart';

const _link =
    'https://script.google.com/macros/s/AKfyTEST/exec?anahtar=1234567890abcdef1234';

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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final d = VeriDeposu.ben;
    d.sahteIstek = (_) async => jsonEncode(ornekJson);
    await d.baslat();
  });

  testWidgets('Kurulum ekranı: hatalı link uyarı verir, doğru link bağlanır',
      (t) async {
    _telefon(t);
    await t.pumpWidget(_uygulama(const KurulumEkrani(ilk: true)));
    expect(find.text('Bağlan'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'https://example.com');
    await t.tap(find.text('Bağlan'));
    await t.pumpAndSettle();
    expect(find.textContaining('script.google.com'), findsWidgets);
    expect(VeriDeposu.ben.link, isNull);

    await t.enterText(find.byType(TextField), _link);
    await t.tap(find.text('Bağlan'));
    await t.pumpAndSettle();
    expect(VeriDeposu.ben.link, _link);
    expect(VeriDeposu.ben.veri, isNotNull);
  });

  testWidgets('Ana ekran: tüm sekmeler hatasız açılır', (t) async {
    _telefon(t);
    await VeriDeposu.ben.linkKaydet(_link);
    await t.pumpWidget(_uygulama(const AnaEkran(guncellemeKontrolu: false)));
    await t.pumpAndSettle();

    // Günlük
    expect(find.text('Günlük Pano'), findsOneWidget);
    expect(find.text('2.079'), findsWidgets);
    expect(find.text('12.648 kg'), findsOneWidget);

    // Haftalık
    await t.tap(find.text('Haftalık'));
    await t.pumpAndSettle();
    expect(find.text('53.187 kg'), findsOneWidget);
    await t.drag(find.byType(ListView).last, const Offset(0, -1500));
    await t.pumpAndSettle();

    // Tarım
    await t.tap(find.text('Tarım'));
    await t.pumpAndSettle();
    expect(find.text('6.684 da'), findsOneWidget);
    await t.drag(find.byType(ListView).last, const Offset(0, -2000));
    await t.pumpAndSettle();

    // Rapor
    await t.tap(find.text('Rapor'));
    await t.pumpAndSettle();
    final liste = find
        .descendant(
            of: find.byKey(const Key('rapor-liste')),
            matching: find.byType(Scrollable))
        .first;
    final paylas = find.text('Paylaş (e-posta, WhatsApp…)');
    await t.scrollUntilVisible(paylas, 300, scrollable: liste);
    expect(paylas, findsOneWidget);
    await t.drag(liste, const Offset(0, 3000));
    await t.pumpAndSettle();
    await t.tap(find.descendant(
        of: find.byKey(const Key('rapor-liste')),
        matching: find.text('Haftalık')));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(paylas, 300, scrollable: liste);
    expect(paylas, findsOneWidget);

    // Asistan → Sekreterlik (İşler)
    await t.tap(find.text('Asistan'));
    await t.pumpAndSettle();
    expect(find.text('Sekreterlik'), findsOneWidget);
    await t.tap(find.text('Sekreterlik'));
    await t.pumpAndSettle();
    expect(find.text('Sekreterlik — İşler'), findsOneWidget);
    expect(find.textContaining('Vetkim ödemesi'), findsOneWidget);
    expect(find.text('Bekleyen işler (1)'), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
  });

  test('PDF raporları oluşur', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final v = RaporVerisi.json(ornekJson);
    const a = RaporAyari(
        hazirlayan: 'Test Kişi', unvan: 'Grup Müdürü', alici: 'Sayın Müdürüm');
    final g = await gunlukRaporPdf(v, DateTime(2026, 11, 5), a);
    final h = await haftalikRaporPdf(v, DateTime(2026, 11, 2), a);
    final bos = await gunlukRaporPdf(v, DateTime(2026, 11, 1), const RaporAyari());
    for (final b in [g, h, bos]) {
      expect(String.fromCharCodes(b.sublist(0, 5)), '%PDF-');
      expect(b.length, greaterThan(5000));
    }
    expect(gunlukDosyaAdi(DateTime(2026, 11, 5)), 'Gunluk_Rapor_05.11.2026.pdf');
    expect(haftalikDosyaAdi(DateTime(2026, 11, 2)), 'Haftalik_Rapor_45_Hafta_2026.pdf');
  });
}
