import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Android sistem bildirimi (kritik durumlar). Yalnızca başlık ve kısa metin; kişisel veri yok.
final _eklenti = FlutterLocalNotificationsPlugin();
bool _hazir = false;

Future<bool> _baslat() async {
  if (!Platform.isAndroid) return false;
  if (_hazir) return true;
  try {
    await _eklenti.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    _hazir = true;
  } catch (_) {
    return false;
  }
  return true;
}

Future<bool> sistemBildirimiIzni() async {
  if (!await _baslat()) return false;
  try {
    final a = _eklenti.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await a?.requestNotificationsPermission() ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> sistemBildirimiGoster(int id, String baslik, String metin) async {
  if (!await _baslat()) return;
  try {
    await _eklenti.show(
      id,
      baslik,
      metin,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'kritik',
          'Kritik uyarılar',
          channelDescription: 'Birim maliyet, sürü kaybı gibi karar gerektiren durumlar',
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.private,
        ),
      ),
    );
  } catch (_) {}
}
