import 'package:shared_preferences/shared_preferences.dart';

import '../pdf/rapor_pdf.dart';
import '../veri/model.dart';
import 'veri_servisi.dart';

/// Haftalık raporu Drive'daki "Haftalık Faaliyet Raporları" klasöründe güncel
/// tutar: yeni veri geldiğinde içinde bulunulan haftanın PDF'i oluşturulur ve
/// aynı dosyanın üzerine kaydedilir. Haftanın ilk iki gününde bir önceki
/// haftanın raporu da (geç gelen veriler için) güncellenir.
/// Veri değişmediyse tekrar gönderilmez. KVKK: PDF kişi bilgisi içermez.
class RaporArsivi {
  RaporArsivi._();

  static bool _calisiyor = false;
  static const _onEk = 'arsiv_parmak_';

  /// Son otomatik kaydın sonucu (Rapor ekranında bilgi olarak gösterilir).
  static String? sonDurum;

  static Future<void> guncelle(RaporVerisi v, String ham) async {
    final d = VeriDeposu.ben;
    if (_calisiyor || d.link == null) return;
    final son = v.sonGun;
    if (son == null) return;
    _calisiyor = true;
    try {
      final p = await SharedPreferences.getInstance();
      final buHafta = haftaBasi(son);
      final haftalar = [
        buHafta,
        if (son.difference(buHafta).inDays <= 1)
          buHafta.subtract(const Duration(days: 7)),
      ];
      for (final h in haftalar) {
        final ad = haftalikDosyaAdi(h);
        final parmak = parmakIzi('$ad|${d.ayar.baslik}|${d.ayar.alici}|$ham');
        if (p.getString('$_onEk$ad') == parmak) continue;
        final pdf = await haftalikRaporPdf(v, h, d.ayar);
        sonDurum = await d.raporuDriveKaydet(ad, pdf);
        await p.setString('$_onEk$ad', parmak);
      }
    } catch (e) {
      sonDurum = 'Otomatik Drive kaydı yapılamadı: $e';
    } finally {
      _calisiyor = false;
    }
  }
}

/// Basit ve kararlı 32 bit FNV-1a özeti (değişiklik tespiti için).
String parmakIzi(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return '${s.length}-${h.toRadixString(16)}';
}
