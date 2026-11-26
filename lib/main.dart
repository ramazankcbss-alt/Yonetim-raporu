import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'ekranlar/ana.dart';
import 'servis/rapor_arsivi.dart';
import 'servis/veri_servisi.dart';
import 'servis/web_kopru.dart';
import 'tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');
  await VeriDeposu.ben.baslat();
  if (kIsWeb) {
    // Web sürümü yalnızca şirket paneli içinde (şirket hesabıyla girişten sonra) çalışır.
    if (webKopruVar) {
      VeriDeposu.ben.webKopruKur();
    } else {
      VeriDeposu.ben.hata = 'Bu sayfa yalnızca size gönderilen paylaşım linkiyle, şirket hesabınızla açılır.';
    }
  } else {
    VeriDeposu.ben.veriGeldi = RaporArsivi.guncelle;
  }
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const YonetimRaporuApp());
}

class YonetimRaporuApp extends StatelessWidget {
  const YonetimRaporuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yönetim Raporu',
      debugShowCheckedModeBanner: false,
      theme: temaOlustur(),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Kapi(),
    );
  }
}
