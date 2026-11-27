// Araç masrafları (Makine ve Bakım › Araç Masrafları).
// Kaynak: "ÇİFTLİKLER ARAÇ MASRAFLARI" muhasebe listesi → arac_masraf_<yıl>.json
// (araclar/arac/arac_masraf.py; Drive "Uygulama Verileri" klasöründe, sunucudan gelir).
// KVKK: dosyada plaka, araç kodu, satıcı, belge numarası ve açıklama metni bulunmaz.
import 'dart:convert';

import 'stok_suru.dart' show kUretimYerleri;

class AracMasrafi {
  const AracMasrafi({required this.arac, required this.uretimYeri, required this.aylik, required this.toplam});
  final String arac, uretimYeri;
  final Map<String, double> aylik; // "2026-01" → matrah (KDV hariç)
  final double toplam;

  bool get kiralik => arac.toUpperCase().contains('KİRALIK');

  /// Araç türü: ad içindeki ilk anahtar kelimeden.
  String get tur {
    final a = arac.toUpperCase();
    if (a.contains('TRAKTÖR')) return 'Traktör';
    if (a.contains('MANITOU') || a.contains('TELESKOBİK') || a.contains('YÜKLEYİCİ') || a.contains('KAZICI')) {
      return 'Yükleyici / iş makinesi';
    }
    if (a.contains('KAMYON') || a.contains('TANKER')) return 'Kamyon / tanker';
    return 'Binek / hafif ticari';
  }
}

class AracMasraflari {
  const AracMasraflari({this.donem = '', this.araclar = const [], this.genelToplam, this.araclarToplami = 0});
  final String donem;
  final List<AracMasrafi> araclar;

  /// Dosyadaki GENEL TOPLAM hücresi ve araç satırlarının toplamı (fark varsa kaynakta düzeltme gerekir).
  final double? genelToplam;
  final double araclarToplami;

  bool get bos => araclar.isEmpty;

  List<String> get aylar => ({for (final a in araclar) ...a.aylik.keys}.toList()..sort());

  double ayToplami(String ay) => araclar.fold(0.0, (t, a) => t + (a.aylik[ay] ?? 0));

  /// Üretim yeri adı → toplam.
  Map<String, double> uretimYeriToplami() {
    final m = <String, double>{};
    for (final a in araclar) {
      m[uretimYeriAdi(a.uretimYeri)] = (m[uretimYeriAdi(a.uretimYeri)] ?? 0) + a.toplam;
    }
    return m;
  }

  Map<String, double> turToplami() {
    final m = <String, double>{};
    for (final a in araclar) {
      m[a.tur] = (m[a.tur] ?? 0) + a.toplam;
    }
    return m;
  }

  static String uretimYeriAdi(String kod) {
    if (kod.isEmpty) return 'Üretim yeri belirtilmemiş';
    if (kod == '1611') return 'Ortak giderler (Tarımsal Alan)';
    return kUretimYerleri[kod] ?? kod;
  }

  static AracMasraflari coz(String metin) {
    final j = jsonDecode(metin);
    if (j is! Map) return const AracMasraflari();
    double? n(Object? v) => v is num ? v.toDouble() : null;
    final l = <AracMasrafi>[
      for (final a in (j['araclar'] is List ? j['araclar'] as List : const []))
        if (a is Map)
          AracMasrafi(
            arac: '${a['arac'] ?? ''}'.trim(),
            uretimYeri: '${a['uy'] ?? ''}',
            aylik: {
              if (a['aylik'] is Map)
                for (final e in (a['aylik'] as Map).entries)
                  if (n(e.value) != null) '${e.key}': n(e.value)!,
            },
            toplam: n(a['toplam']) ?? 0,
          ),
    ]..sort((a, b) => b.toplam.compareTo(a.toplam));
    final k = j['kontrol'] is Map ? j['kontrol'] as Map : const {};
    return AracMasraflari(
      donem: '${j['donem'] ?? ''}',
      araclar: l,
      genelToplam: n(k['genel_toplam']),
      araclarToplami: n(k['araclar_toplami']) ?? l.fold(0.0, (t, a) => t + a.toplam),
    );
  }
}
