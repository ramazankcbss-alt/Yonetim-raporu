import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/ekranlar/paylasim.dart';

void main() {
  test('paylaşım menü grupları tüm menüleri bir kez içerir', () {
    final g = [for (final x in paylasimMenuGruplari) ...x.$2];
    expect(g.toSet().length, g.length);
    expect(g.toSet(), paylasimMenuAdlari.keys.toSet());
  });
}
