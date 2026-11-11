import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yonetim_raporu/ekranlar/danismanlik.dart';
import 'package:yonetim_raporu/ekranlar/gunce.dart';
import 'package:yonetim_raporu/ekranlar/kilit.dart';
import 'package:yonetim_raporu/ekranlar/ozel_notlar.dart';
import 'package:yonetim_raporu/ekranlar/toplanti.dart';
import 'package:yonetim_raporu/servis/veri_servisi.dart';
import 'package:yonetim_raporu/tema.dart';

const _link =
    'https://script.google.com/macros/s/AKfyTEST/exec?anahtar=1234567890abcdef1234';

final Map<String, dynamic> _ozelJson = {
  'ok': true,
  'ozelNotlar': [
    ['11.11.2026', 'Uyuşmazlık', 'ESK Ekim kesim farkı', '21 baş fark', 'Gmail'],
  ],
  'danismanlik': [
    ['11.11.2026', 'Vade kararı', 'Ne yapmalıyım?', 'Yeni', '', ''],
  ],
  'toplanti': [
    ['11.11.2026', 'Koordinasyon', 'Ekip', 'Bütçe', 'Şunlar konuşuldu', '', ''],
  ],
  'gunluk': [
    ['11.11.2026', 'Not', 'Bugün şunu düşündüm', ''],
  ],
};

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
    await d.baslat();
    d.link = _link;
    d.sahteGonder = null;
    d.sahteIstek = (u) async => u.queryParameters['bolum'] == 'ozel'
        ? jsonEncode(_ozelJson)
        : '{"ok":true}';
  });

  testWidgets('Danışmanlık kayıtları gösterir', (t) async {
    _telefon(t);
    await t.pumpWidget(_uygulama(const DanismanlikEkran()));
    await t.pumpAndSettle();
    expect(find.text('Vade kararı'), findsOneWidget);
    expect(find.textContaining('Ne yapmalıyım?'), findsOneWidget);
  });

  testWidgets('Danışmanlık: soru gönderilir', (t) async {
    _telefon(t);
    String? gonderilen;
    VeriDeposu.ben.sahteGonder = (u, g) async {
      gonderilen = g;
      return '{"ok":true}';
    };
    await t.pumpWidget(_uygulama(const DanismanlikEkran()));
    await t.pumpAndSettle();
    await t.tap(find.text('Soru sor'));
    await t.pumpAndSettle();
    final alanlar = find.byType(TextField);
    await t.enterText(alanlar.at(0), 'Test konu');
    await t.enterText(alanlar.at(1), 'Test soru');
    await t.tap(find.text('Gönder'));
    await t.pumpAndSettle();
    expect(gonderilen, isNotNull);
    expect(gonderilen, contains('Test soru'));
    expect(gonderilen, contains('danismanlik'));
  });

  testWidgets('Toplantı notları gösterir', (t) async {
    _telefon(t);
    await t.pumpWidget(_uygulama(const ToplantiEkran()));
    await t.pumpAndSettle();
    expect(find.textContaining('Şunlar konuşuldu'), findsOneWidget);
  });

  testWidgets('Özel Notlar kilit atlanınca gösterir', (t) async {
    _telefon(t);
    KilitKapisi.testAcik = true;
    addTearDown(() => KilitKapisi.testAcik = false);
    await t.pumpWidget(_uygulama(
        const KilitKapisi(baslik: 'Özel Notlar', child: OzelNotlarEkran())));
    await t.pumpAndSettle();
    expect(find.textContaining('ESK Ekim kesim farkı'), findsOneWidget);
    expect(find.text('Uyuşmazlık'), findsOneWidget);
  });

  testWidgets('Günlük yazısı gösterir', (t) async {
    _telefon(t);
    KilitKapisi.testAcik = true;
    addTearDown(() => KilitKapisi.testAcik = false);
    await t.pumpWidget(_uygulama(
        const KilitKapisi(baslik: 'Günlük', child: GunceEkran())));
    await t.pumpAndSettle();
    expect(find.textContaining('Bugün şunu düşündüm'), findsOneWidget);
  });

  testWidgets('Kilit PIN ister (ilk açılış)', (t) async {
    _telefon(t);
    KilitKapisi.testAcik = false;
    await t.pumpWidget(_uygulama(
        const KilitKapisi(baslik: 'Özel Notlar', child: OzelNotlarEkran())));
    await t.pumpAndSettle();
    expect(find.text('PIN oluştur'), findsOneWidget);
  });
}
