// Özel dosyadaki ("Özel Notlar – Sadece Ramazan Kocabaş") bölümlerin modeli:
// Danışmanlık, Toplantı Notları, Özel Notlar ve Günlük. Veri Apps Script'in
// ?bolum=ozel ucundan gelir; cihazda diske yazılmaz, bellekte tutulur.

import 'model.dart' show tarihEsnek;

String _m(Object? v) => (v ?? '').toString().trim();
List<Object?> _l(Object? v) => v is List ? v : const [];
String _al(List<Object?> r, int i) => i < r.length ? _m(r[i]) : '';

/// Özel Notlar sayfası: Tarih, Tür, Konu, Not/öneri, Kaynak.
class OzelNot {
  const OzelNot({
    this.tarih,
    this.tur = '',
    this.konu = '',
    this.not = '',
    this.kaynak = '',
  });

  final DateTime? tarih;
  final String tur, konu, not, kaynak;

  static OzelNot? oku(Object? v) {
    final r = _l(v);
    final tur = _al(r, 1);
    final konu = _al(r, 2);
    if (tur.isEmpty && konu.isEmpty) return null;
    return OzelNot(
      tarih: r.isNotEmpty ? tarihEsnek(r[0]) : null,
      tur: tur,
      konu: konu,
      not: _al(r, 3),
      kaynak: _al(r, 4),
    );
  }
}

/// Danışmanlık: Tarih, Konu, Sorum, Durum, Yanıt tarihi, Değerlendirme.
class DanismanlikKaydi {
  const DanismanlikKaydi({
    this.tarih,
    this.konu = '',
    this.soru = '',
    this.durum = '',
    this.yanitTarihi,
    this.yanit = '',
  });

  final DateTime? tarih, yanitTarihi;
  final String konu, soru, durum, yanit;

  bool get yanitlandi => yanit.trim().isNotEmpty || durum == 'Yanıtlandı';

  static DanismanlikKaydi? oku(Object? v) {
    final r = _l(v);
    final konu = _al(r, 1);
    final soru = _al(r, 2);
    if (konu.isEmpty && soru.isEmpty) return null;
    return DanismanlikKaydi(
      tarih: r.isNotEmpty ? tarihEsnek(r[0]) : null,
      konu: konu,
      soru: soru,
      durum: _al(r, 3),
      yanitTarihi: r.length > 4 ? tarihEsnek(r[4]) : null,
      yanit: _al(r, 5),
    );
  }
}

/// Toplantı Notları: Tarih, Yer, Katılımcılar, Konular, Konuşulanlar,
/// Analiz, Takip.
class ToplantiNotu {
  const ToplantiNotu({
    this.tarih,
    this.yer = '',
    this.katilimcilar = '',
    this.konular = '',
    this.notlar = '',
    this.analiz = '',
    this.takip = '',
  });

  final DateTime? tarih;
  final String yer, katilimcilar, konular, notlar, analiz, takip;

  static ToplantiNotu? oku(Object? v) {
    final r = _l(v);
    final yer = _al(r, 1);
    final konular = _al(r, 3);
    final notlar = _al(r, 4);
    if (yer.isEmpty && konular.isEmpty && notlar.isEmpty) return null;
    return ToplantiNotu(
      tarih: r.isNotEmpty ? tarihEsnek(r[0]) : null,
      yer: yer,
      katilimcilar: _al(r, 2),
      konular: konular,
      notlar: notlar,
      analiz: _al(r, 5),
      takip: _al(r, 6),
    );
  }
}

/// Günlük: Tarih, Başlık, İçerik, Not.
class GunceGiris {
  const GunceGiris({this.tarih, this.baslik = '', this.icerik = '', this.not = ''});

  final DateTime? tarih;
  final String baslik, icerik, not;

  static GunceGiris? oku(Object? v) {
    final r = _l(v);
    final baslik = _al(r, 1);
    final icerik = _al(r, 2);
    if (baslik.isEmpty && icerik.isEmpty) return null;
    return GunceGiris(
      tarih: r.isNotEmpty ? tarihEsnek(r[0]) : null,
      baslik: baslik,
      icerik: icerik,
      not: _al(r, 3),
    );
  }
}

/// Kişi bazlı olay: Tarih, Kişi, Tür, Konu, Açıklama, Durum (Olumsuz /
/// Olumlu), Düzeltilme tarihi, Kaynak, Kimlik. Olumsuz olay düzeltildiğinde
/// Olumlu'ya çevrilir.
class KisiOlayi {
  const KisiOlayi({
    this.tarih,
    this.kisi = '',
    this.tur = '',
    this.konu = '',
    this.aciklama = '',
    this.durum = '',
    this.duzeltilme,
    this.kaynak = '',
    this.kimlik = '',
  });

  final DateTime? tarih, duzeltilme;
  final String kisi, tur, konu, aciklama, durum, kaynak, kimlik;

  bool get olumlu => durum.trim().toLowerCase() == 'olumlu';

  static KisiOlayi? oku(Object? v) {
    final r = _l(v);
    final kisi = _al(r, 1);
    final konu = _al(r, 3);
    if (kisi.isEmpty || (konu.isEmpty && _al(r, 4).isEmpty)) return null;
    return KisiOlayi(
      tarih: r.isNotEmpty ? tarihEsnek(r[0]) : null,
      kisi: kisi,
      tur: _al(r, 2),
      konu: konu,
      aciklama: _al(r, 4),
      durum: _al(r, 5),
      duzeltilme: r.length > 6 ? tarihEsnek(r[6]) : null,
      kaynak: _al(r, 7),
      kimlik: _al(r, 8),
    );
  }
}

/// ?bolum=ozel cevabının tamamı.
class OzelVeri {
  const OzelVeri({
    this.ozelNotlar = const [],
    this.danismanlik = const [],
    this.toplanti = const [],
    this.gunce = const [],
    this.kisiOlaylari = const [],
  });

  final List<OzelNot> ozelNotlar;
  final List<DanismanlikKaydi> danismanlik;
  final List<ToplantiNotu> toplanti;
  final List<GunceGiris> gunce;
  final List<KisiOlayi> kisiOlaylari;

  factory OzelVeri.json(Map<String, dynamic> j) {
    List<T> oku<T extends Object>(String alan, T? Function(Object?) f) =>
        _l(j[alan]).map(f).whereType<T>().toList();
    return OzelVeri(
      ozelNotlar: oku('ozelNotlar', OzelNot.oku),
      danismanlik: oku('danismanlik', DanismanlikKaydi.oku),
      toplanti: oku('toplanti', ToplantiNotu.oku),
      gunce: oku('gunluk', GunceGiris.oku),
      kisiOlaylari: oku('kisiOlaylari', KisiOlayi.oku),
    );
  }
}
