import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ekranlar/net_sonuc.dart' show mtKgMaliyetleri;
import '../ekranlar/urun_karlilik.dart' show maliyetTakipVerisi;
import '../ekranlar/veri_kalitesi.dart';
import '../veri/bildirim.dart';
import '../veri/ciftlik_rapor.dart';
import '../veri/havuz.dart';
import '../veri/karne_sapma.dart';
import '../veri/model.dart';
import 'sistem_bildirimi_stub.dart' if (dart.library.io) 'sistem_bildirimi_io.dart' as sistem;

/// Bildirim merkezi: veri her geldiğinde kuralları yeniden değerlendirir; yeni kritik durumlar için
/// (açıksa) telefona sistem bildirimi gönderir. Okundu bilgisi yalnızca bu cihazda tutulur.
class BildirimServisi extends ChangeNotifier {
  BildirimServisi._();
  static final ben = BildirimServisi._();

  static const _kOkunan = 'bildirim_okunan', _kGonderilen = 'bildirim_gonderilen', _kSistem = 'bildirim_sistem';
  static const kAylikRaporSon = 'aylik_rapor_son';

  List<UygulamaBildirimi> liste = const [];
  Set<String> okunan = {};
  Set<String> _gonderilen = {};
  bool sistemAcik = false;
  int? sonRaporlananAy;
  bool _yuklendi = false;

  int get okunmamis => liste.where((b) => !okunan.contains(b.anahtar)).length;
  int get kritikOkunmamis => liste.where((b) => b.oncelik == BildirimOnceligi.kritik && !okunan.contains(b.anahtar)).length;

  Future<void> _yukle() async {
    if (_yuklendi) return;
    final p = await SharedPreferences.getInstance();
    okunan = (p.getStringList(_kOkunan) ?? const []).toSet();
    _gonderilen = (p.getStringList(_kGonderilen) ?? const []).toSet();
    sistemAcik = p.getBool(_kSistem) ?? false;
    sonRaporlananAy = p.getInt(kAylikRaporSon);
    _yuklendi = true;
  }

  Future<void> kontrolEt(RaporVerisi v) async {
    try {
      await _yukle();
      final r = await CiftlikRaporu.yukle().then<CiftlikRaporu?>((x) => x).catchError((Object _) => null);
      final h = GelirGiderHavuzu.hesapla(faturalar: v.mali.gelirGider, muhasebe: r, mtKgMaliyet: mtKgMaliyetleri(v));
      final sap = r == null || h.sonMuhasebeAyi == 0
          ? const <Sapma>[]
          : sapmalar(
              muhasebe: r, suru: v.suruHareketleri, faturalar: v.mali.gelirGider, yil: h.yil, sonAy: h.sonMuhasebeAyi, mt: maliyetTakipVerisi());
      final q = VeriKalitesi.hesapla(v, r);
      liste = bildirimleriUret(
        sapmalar: sap,
        yil: h.yil,
        sonMuhasebeAyi: h.sonMuhasebeAyi,
        suru: v.suruHareketleri,
        eskiKaynaklar: [for (final k in q.kaynaklar) if (k.$1?.eski ?? false) k.$2],
        eksikDonemler: q.eksikAylar,
        acikKonu: q.konular.length,
        sonRaporlananAy: sonRaporlananAy,
      );
      final yeni = [for (final b in liste) if (b.oncelik == BildirimOnceligi.kritik && !_gonderilen.contains(b.anahtar)) b];
      if (yeni.isNotEmpty) {
        if (sistemAcik) {
          for (final b in yeni) {
            await sistem.sistemBildirimiGoster(b.anahtar.hashCode & 0x7fffffff, b.baslik, b.metin);
          }
        }
        _gonderilen.addAll(yeni.map((b) => b.anahtar));
        await (await SharedPreferences.getInstance()).setStringList(_kGonderilen, _gonderilen.toList());
      }
      notifyListeners();
    } catch (_) {
      // Bildirim hesabı veri akışını hiçbir zaman durdurmaz.
    }
  }

  Future<bool> sistemBildirimiAyarla(bool acik) async {
    await _yukle();
    sistemAcik = acik ? await sistem.sistemBildirimiIzni() : false;
    await (await SharedPreferences.getInstance()).setBool(_kSistem, sistemAcik);
    notifyListeners();
    return sistemAcik;
  }

  Future<void> okundu(Iterable<String> anahtarlar) async {
    await _yukle();
    okunan.addAll(anahtarlar);
    // Artık listede olmayan eski anahtarlar temizlenir.
    final gecerli = liste.map((b) => b.anahtar).toSet();
    okunan.removeWhere((k) => !gecerli.contains(k));
    await (await SharedPreferences.getInstance()).setStringList(_kOkunan, okunan.toList());
    notifyListeners();
  }

  Future<void> aylikRaporYapildi(int yil, int ay) async {
    await _yukle();
    sonRaporlananAy = yil * 12 + ay;
    await (await SharedPreferences.getInstance()).setInt(kAylikRaporSon, sonRaporlananAy!);
    liste = [for (final b in liste) if (b.hedef != BildirimHedefi.aylikRapor) b];
    notifyListeners();
  }
}
