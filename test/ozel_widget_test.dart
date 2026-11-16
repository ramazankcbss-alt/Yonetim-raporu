import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yonetim_raporu/ekranlar/gunce.dart';
import 'package:yonetim_raporu/ekranlar/kilit.dart';
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
    ['10.11.2026', 'Mastit oranı', 'Ekim oranı?', 'Yanıtlandı', '11.11.2026', 'Ekimde %10 yeni vaka.', 3],
    ['11.11.2026', 'Vade kararı', 'Ne yapmalıyım?', 'Yeni', '', '', 2],
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





  testWidgets('Toplantı notları gösterir', (t) async {
    _telefon(t);
    await t.pumpWidget(_uygulama(const ToplantiEkran()));
    await t.pumpAndSettle();
    expect(find.textContaining('Şunlar konuşuldu'), findsOneWidget);
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
        const KilitKapisi(baslik: 'Günlük', child: GunceEkran())));
    await t.pumpAndSettle();
    expect(find.text('PIN oluştur'), findsOneWidget);
  });
}
