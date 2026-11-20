import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/ekranlar/gonder.dart';

void main() {
  testWidgets('Bu bulguyu gönder: uzun listenin tamamı toplanır, adlar gizlenir', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GonderAlani(
          konu: 'Deneme – Liste',
          gizle: const ['Ali Veli'],
          child: ListView(children: [
            SizedBox(
              height: 40,
              child: ListView(scrollDirection: Axis.horizontal, children: const [Text('çip yazısı')]),
            ),
            for (var i = 0; i < 80; i++)
              Card(child: ListTile(title: Text('Kalem $i'), subtitle: Text(i == 79 ? 'Ali Veli kullandı' : 'açıklama'))),
          ]),
        ),
      ),
    ));
    await t.tap(find.byKey(const Key('buBulguyuGonder')));
    await t.pumpAndSettle();
    final metin = (t.widget(find.byKey(const Key('talepMetni'))) as TextField).controller!.text;
    expect(metin, contains('Konu: Deneme – Liste – inceleme talebi'));
    expect(metin, contains('incelenerek gerekli düzeltme'));
    expect(metin, contains('Kalem 0'));
    expect(metin, contains('Kalem 79'));
    expect(metin, contains('personel kullandı'));
    expect(metin, isNot(contains('Ali Veli')));
    expect(metin, isNot(contains('çip yazısı')));
    expect('Kalem 40'.allMatches(metin).length, 1);
    expect(metin, contains('Tarım ve Hayvancılık Grup Müdürü'));
  });
}
