import 'package:intl/intl.dart';

import 'veri/model.dart';

final _tam = NumberFormat('#,##0', 'tr_TR');
final _bir = NumberFormat('#,##0.0', 'tr_TR');
final _iki = NumberFormat('#,##0.00', 'tr_TR');

/// 12648 → "12.648", 24.8 (ondalik: 1) → "24,8". null → "—".
String sayi(double? v, {int ondalik = 0, String bos = '—'}) {
  if (v == null || v.isNaN || v.isInfinite) return bos;
  switch (ondalik) {
    case 0:
      return _tam.format(v.round());
    case 1:
      return _bir.format(v);
    default:
      return _iki.format(v);
  }
}

/// Sıfırsa "—" gösterir (tablolarda boş hücre görünümü).
String sayiTire(double? v, {int ondalik = 0}) =>
    (v == null || v == 0) ? '—' : sayi(v, ondalik: ondalik);

/// Fark: +4, -1, 0 → "—".
String fark(double v, {int ondalik = 0}) {
  final y = ondalik == 0 ? v.roundToDouble() : v;
  if (y.abs() < (ondalik == 0 ? 0.5 : 0.005)) return '—';
  return '${y > 0 ? '+' : '-'}${sayi(y.abs(), ondalik: ondalik)}';
}

String kg(double? v) => v == null ? '—' : '${sayi(v)} kg';

/// 05.11.2026
String tarihKisa(DateTime d) => DateFormat('dd.MM.yyyy').format(d);

/// 05.11
String gunAy(DateTime d) => DateFormat('dd.MM').format(d);

/// 5 Kasım 2026 Perşembe
String tarihUzun(DateTime d) => DateFormat('d MMMM y EEEE', 'tr_TR').format(d);

/// Per
String gunKisa(DateTime d) => DateFormat('EEE', 'tr_TR').format(d);

/// 45. Hafta · 02.11 – 08.11.2026
String haftaEtiketi(DateTime pazartesi) {
  final pazar = pazartesi.add(const Duration(days: 6));
  return '${isoHafta(pazartesi)}. Hafta · ${gunAy(pazartesi)} – ${tarihKisa(pazar)}';
}

/// 09.11.2026 14:05
String zamanBicim(DateTime d) => DateFormat('dd.MM.yyyy HH:mm').format(d);
