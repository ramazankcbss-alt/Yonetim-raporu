import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yonetim_raporu/ekranlar/mali.dart';
import 'package:yonetim_raporu/tema.dart';
import 'package:yonetim_raporu/veri/model.dart';

final _j = <String, dynamic>{
  'hayvanOzet': [],
  'hayvanGunluk': [],
  'tarim': [],
  'mali': {
    'olusturma': '2026-11-18',
    'fatura': [
      ['2026-11-16', 'Şekersüt (Fethiye)', 'Grup içi', 'Yem ve kaba yem', 'KONYA ŞEKER SANAYİ VE TİCARET A.Ş.', 100000.0, 'TRY', '2026-12-31', 'Açık', 'Raporla uyumlu'],
      ['2026-11-17', 'Aslım', 'Grup dışı', 'Akaryakıt', 'Şahıs / teyitsiz tedarikçi', 20000.0, 'TRY', '', 'Ödendi', 'Tutar farkı'],
      ['2026-10-05', 'Taşağıl', 'Grup dışı', 'Bakım, onarım, yedek parça', 'Şahıs / teyitsiz tedarikçi', 5000.0, 'TRY', '', 'Ödendi', 'Ayrıntılı raporda yok'],
    ],
    'acik': [
      ['2026-08-01', 'Aslım', 'Gübre ve zirai ilaç', 'S.S.KONYA PANCAR EKİCİLERİ KOOPERAT', 50000.0, '2026-09-01', 78],
      ['2026-11-16', 'Şekersüt (Fethiye)', 'Yem ve kaba yem', 'KONYA ŞEKER SANAYİ VE TİCARET A.Ş.', 100000.0, '2099-12-31', -100],
    ],
    'kontrol': [
      ['Tutarsızlık', 'Tutarı farklı çıkan faturalar', '79 fatura', 'Açıklama'],
      ['Karşılaştırma', 'ESK sap balyası', '6,77 milyon TL', 'Açıklama'],
    ],
  },
};

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  test('mali veri okunur ve döneme ayrılır', () {
    final m = RaporVerisi.json(_j).mali;
    expect(m.faturalar, hasLength(3));
    expect(m.faturalar.first.tarih, DateTime(2026, 10, 5));
    expect(m.acik.first.gecmis(DateTime(2026, 11, 18)), isTrue);
    expect(m.acik.last.gecmis(DateTime(2026, 11, 18)), isFalse);
    final hf = maliDonemler(m.faturalar, MaliDonem.hafta);
    expect(hf.first.key, DateTime(2026, 11, 16));
    expect(MaliOzet(hf.first.value).toplam, 120000);
    expect(MaliOzet(hf.first.value).acik, 100000);
    final ay = maliDonemler(m.faturalar, MaliDonem.ay);
    expect(ay.map((e) => e.key), [DateTime(2026, 11), DateTime(2026, 10)]);
    expect(MaliOzet(m.faturalar).grupla((f) => f.hesap).first.key, 'Grup içi');
    expect(RaporVerisi.json({'hayvanOzet': [], 'hayvanGunluk': [], 'tarim': []}).mali.bos, isTrue);
  });

  testWidgets('mali raporlar ekranı', (t) async {
    t.view.physicalSize = const Size(1200, 5000);
    t.view.devicePixelRatio = 1.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      theme: temaOlustur(),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MaliEkran(veri: RaporVerisi.json(_j)),
    ));
    await t.pumpAndSettle();
    expect(find.text('Toplam fatura'), findsOneWidget);
    await t.tap(find.text('Aylık'));
    await t.pumpAndSettle();
    expect(find.text('Kasım 2026'), findsOneWidget);
    await t.tap(find.text('Karşılaştırma'));
    await t.pumpAndSettle();
    expect(find.text('Tutarı farklı çıkan faturalar'), findsOneWidget);
    await t.tap(find.text('Açık bakiyeler'));
    await t.pumpAndSettle();
    expect(find.text('Vadesi geçmiş'), findsOneWidget);
  });
}
