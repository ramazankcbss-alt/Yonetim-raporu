import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Şirket panelinin sayfası `yrSunucu(islem, govde)` işlevini tanımlar (google.script.run).
bool get webKopruVar => globalContext.has('yrSunucu');

@JS('yrSunucu')
external JSPromise<JSString> _yrSunucu(JSString islem, JSString govde);

Future<String> webKopru(String islem, String govde) async => (await _yrSunucu(islem.toJS, govde.toJS).toDart).toDart;
