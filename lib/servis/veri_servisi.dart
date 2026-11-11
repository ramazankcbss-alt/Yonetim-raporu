import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../veri/model.dart';

/// Rapor PDF'inde görünen bilgiler (Ayarlar ekranından).
class RaporAyari {
  const RaporAyari({
    this.baslik = 'Çiftlikler Yönetim Raporu',
    this.hazirlayan = '',
    this.unvan = '',
    this.alici = '',
  });

  final String baslik;
  final String hazirlayan;
  final String unvan;

  /// Örn. "Sayın Genel Müdürüm" — PDF'in başında hitap olarak yazılır.
  final String alici;
}

class VeriHatasi implements Exception {
  VeriHatasi(this.mesaj);
  final String mesaj;
  @override
  String toString() => mesaj;
}

/// Bağlantı linki biçim kontrolü: Apps Script web uygulaması + anahtar.
String? linkKontrol(String link) {
  final s = link.trim();
  if (s.isEmpty) return 'Bağlantı linkini yapıştırın.';
  final u = Uri.tryParse(s);
  if (u == null || u.scheme != 'https' || u.host != 'script.google.com') {
    return 'Link "https://script.google.com/..." ile başlamalı.';
  }
  if (!u.path.endsWith('/exec')) {
    return 'Link "…/exec?anahtar=…" biçiminde olmalı. Kurulum e-postasındaki linkin tamamını kopyalayın.';
  }
  if ((u.queryParameters['anahtar'] ?? '').length < 16) {
    return 'Linkte anahtar eksik. Kurulum e-postasındaki linkin tamamını kopyalayın.';
  }
  return null;
}

/// Uygulamanın tek veri kaynağı: rapor verisini çeker, saklar, dağıtır.
class VeriDeposu extends ChangeNotifier {
  VeriDeposu._();
  static final VeriDeposu ben = VeriDeposu._();

  static const _kLink = 'baglanti_linki';
  static const _kOnbellek = 'veri_onbellek';
  static const _kOnbellekZaman = 'veri_onbellek_zaman';
  static const _kBaslik = 'rapor_baslik';
  static const _kHazirlayan = 'rapor_hazirlayan';
  static const _kUnvan = 'rapor_unvan';
  static const _kAlici = 'rapor_alici';

  String? link;
  RaporVerisi? veri;
  DateTime? sonAlinma;
  bool yukleniyor = false;
  String? hata;
  RaporAyari ayar = const RaporAyari();

  /// Testlerde ağ yerine kullanılır.
  @visibleForTesting
  Future<String> Function(Uri adres)? sahteIstek;

  Future<void> baslat() async {
    final p = await SharedPreferences.getInstance();
    link = p.getString(_kLink);
    ayar = RaporAyari(
      baslik: p.getString(_kBaslik) ?? const RaporAyari().baslik,
      hazirlayan: p.getString(_kHazirlayan) ?? '',
      unvan: p.getString(_kUnvan) ?? '',
      alici: p.getString(_kAlici) ?? '',
    );
    final ham = p.getString(_kOnbellek);
    if (ham != null) {
      try {
        veri = RaporVerisi.json(jsonDecode(ham) as Map<String, dynamic>);
        final z = p.getInt(_kOnbellekZaman);
        sonAlinma = z == null ? null : DateTime.fromMillisecondsSinceEpoch(z);
      } catch (_) {
        veri = null;
      }
    }
    notifyListeners();
  }

  Future<void> ayarKaydet(RaporAyari a) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kBaslik, a.baslik);
    await p.setString(_kHazirlayan, a.hazirlayan);
    await p.setString(_kUnvan, a.unvan);
    await p.setString(_kAlici, a.alici);
    ayar = a;
    notifyListeners();
  }

  /// Linki dener; çalışırsa kaydeder ve veriyi yükler.
  Future<void> linkKaydet(String yeniLink) async {
    final temiz = yeniLink.trim();
    final h = linkKontrol(temiz);
    if (h != null) throw VeriHatasi(h);
    await _getir(temiz);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLink, temiz);
    link = temiz;
    notifyListeners();
  }

  Future<void> linkSil() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kLink);
    await p.remove(_kOnbellek);
    await p.remove(_kOnbellekZaman);
    link = null;
    veri = null;
    sonAlinma = null;
    hata = null;
    notifyListeners();
  }

  /// Güncel veriyi çeker. Hata olursa eldeki (önbellek) veri korunur.
  Future<void> yenile() async {
    final l = link;
    if (l == null || yukleniyor) return;
    yukleniyor = true;
    hata = null;
    notifyListeners();
    try {
      await _getir(l);
    } catch (e) {
      hata = e is VeriHatasi
          ? e.mesaj
          : e is TimeoutException
              ? 'Bağlantı zaman aşımına uğradı. İnternet bağlantınızı kontrol edin.'
              : 'Veri alınamadı. İnternet bağlantınızı kontrol edin.';
    } finally {
      yukleniyor = false;
      notifyListeners();
    }
  }

  Future<void> _getir(String l) async {
    final u = Uri.parse(l);
    final adres = u.replace(queryParameters: {
      ...u.queryParameters,
      'gun': '400',
    });
    final govde = sahteIstek != null
        ? await sahteIstek!(adres)
        : await _istek(adres);
    final ham = govde.trimLeft();
    if (ham.startsWith('<')) {
      throw VeriHatasi(
          'Bağlantı Google girişi istiyor. Apps Script\'te dağıtım ayarı '
          '"Erişimi olanlar: Herkes" olmalı (Dağıt → Dağıtımları yönet).');
    }
    final Object? j;
    try {
      j = jsonDecode(ham);
    } catch (_) {
      throw VeriHatasi('Bağlantıdan anlaşılmayan bir cevap geldi.');
    }
    if (j is! Map<String, dynamic>) {
      throw VeriHatasi('Bağlantıdan anlaşılmayan bir cevap geldi.');
    }
    if (j['ok'] != true) {
      throw VeriHatasi((j['hata'] ?? 'Veri alınamadı.').toString());
    }
    final v = RaporVerisi.json(j);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kOnbellek, ham);
    final simdi = DateTime.now();
    await p.setInt(_kOnbellekZaman, simdi.millisecondsSinceEpoch);
    veri = v;
    sonAlinma = simdi;
    hata = null;
  }

  static Future<String> _istek(Uri adres) async {
    final r = await http.get(adres).timeout(const Duration(seconds: 45));
    if (r.statusCode == 404) {
      throw VeriHatasi(
          'Bağlantı adresi bulunamadı. Apps Script dağıtımı silinmiş olabilir.');
    }
    if (r.statusCode == 401 || r.statusCode == 403) {
      throw VeriHatasi(
          'Bağlantıya izin verilmedi. Apps Script dağıtımında "Erişimi olanlar: Herkes" seçili olmalı.');
    }
    if (r.statusCode != 200) {
      throw VeriHatasi('Sunucu hatası (${r.statusCode}). Biraz sonra tekrar deneyin.');
    }
    return utf8.decode(r.bodyBytes);
  }
}
