import 'package:flutter_test/flutter_test.dart';
import 'package:yonetim_raporu/servis/rapor_arsivi.dart';

void main() {
  test('Parmak izi aynı veride aynı, farklı veride farklı', () {
    expect(parmakIzi('abc'), parmakIzi('abc'));
    expect(parmakIzi('abc'), isNot(parmakIzi('abd')));
    expect(parmakIzi(''), '0-811c9dc5');
  });
}
