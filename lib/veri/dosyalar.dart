// Uygulama veri dosyaları (çiftlik raporu, maliyet takip, hastalık arşivi, tarla haritası).
// KVKK / ticari gizlilik: bu dosyalar depoda ve uygulama paketinde bulunmaz; Drive'daki kapalı
// "Yönetim Raporu – Uygulama Verileri" klasöründen sunucu üzerinden, anahtarla gelir.

class UygulamaDosyalari {
  UygulamaDosyalari._();

  static Map<String, String> _m = const {};

  /// Sunucu cevabındaki "dosyalar" alanı ({ad: JSON metni}).
  static void guncelle(Object? j) {
    if (j is! Map) return;
    _m = {for (final e in j.entries) if (e.value is String && (e.value as String).isNotEmpty) '${e.key}': e.value as String};
  }

  static String? metin(String ad) => _m[ad];

  static void temizle() => _m = const {};
}
