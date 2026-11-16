// Bakım Onarım Kayıtları (Günlük Tarım Bildirimi formundan ayrı tabloya
// aktarılır; bakım onarım formeni onaylar). Kod.gs salt okunur aktarır.
// KVKK: kişi adı yoktur, "Bildiren" görevdir (formen, bakım onarım personeli…).

import 'arac.dart' show zamanOku;

String _m(Object? v) => (v ?? '').toString().trim();
Object? _h(List<Object?> r, int i) => i < r.length ? r[i] : null;

class BakimOnarimKaydi {
  const BakimOnarimKaydi({
    required this.no,
    required this.zaman,
    required this.ciftlik,
    required this.bildiren,
    required this.makine,
    required this.islem,
    required this.sayac,
    required this.yapilanIs,
    required this.malzeme,
    required this.tedarik,
    required this.servis,
    required this.durum,
    required this.onayli,
    required this.onayZamani,
  });

  final String no, zaman, ciftlik, bildiren, makine, islem, sayac, yapilanIs,
      malzeme, tedarik, servis, durum, onayZamani;

  /// Bakım onarım formeni onayladı mı?
  final bool onayli;

  static BakimOnarimKaydi? oku(Object? v) {
    if (v is! List) return null;
    final r = v.cast<Object?>();
    final makine = _m(_h(r, 4)), is_ = _m(_h(r, 7));
    if (makine.isEmpty && is_.isEmpty) return null;
    return BakimOnarimKaydi(
      no: _m(_h(r, 0)),
      zaman: _m(_h(r, 1)),
      ciftlik: _m(_h(r, 2)),
      bildiren: _m(_h(r, 3)),
      makine: makine,
      islem: _m(_h(r, 5)),
      sayac: _m(_h(r, 6)),
      yapilanIs: is_,
      malzeme: _m(_h(r, 8)),
      tedarik: _m(_h(r, 9)),
      servis: _m(_h(r, 10)),
      durum: _m(_h(r, 11)),
      onayli: _m(_h(r, 12)) == 'Evet',
      onayZamani: _m(_h(r, 13)),
    );
  }

  DateTime? get tarih => zamanOku(zaman);

  /// İş henüz tamamlanmadı (devam ediyor / parça bekleniyor).
  bool get acik => durum.isNotEmpty && durum != 'Tamamlandı';

  /// Malzeme/parça tedariki bekleniyor.
  bool get tedarikBekliyor =>
      tedarik == 'Tedarik bekleniyor' || durum == 'Parça bekleniyor';

  bool get disServis => servis == 'Dış servis';

  /// Ekranda gösterilecek çiftlik adı.
  String get ciftlikAdi => ciftlik.isEmpty ? 'Çiftlik belirtilmedi' : ciftlik;
}

/// Kayıtlar üzerinde özetler. Liste yeniden eskiye sıralıdır.
class BakimOnarimOzeti {
  BakimOnarimOzeti(Iterable<BakimOnarimKaydi> l)
      : kayitlar = List.unmodifiable([...l]
          ..sort((a, b) => (b.tarih ?? DateTime(0)).compareTo(a.tarih ?? DateTime(0))));

  final List<BakimOnarimKaydi> kayitlar;

  bool get bos => kayitlar.isEmpty;
  List<BakimOnarimKaydi> get onayli => kayitlar.where((x) => x.onayli).toList();
  List<BakimOnarimKaydi> get onayBekleyen => kayitlar.where((x) => !x.onayli).toList();

  /// Açık işler (yalnızca onaylı kayıtlar).
  List<BakimOnarimKaydi> get acik => onayli.where((x) => x.acik).toList();

  /// Tedarik bekleyen malzeme/parça (yalnızca onaylı kayıtlar).
  List<BakimOnarimKaydi> get tedarikBekleyen => onayli.where((x) => x.tedarikBekliyor).toList();

  List<String> get ciftlikler =>
      {for (final x in kayitlar) x.ciftlikAdi}.toList()..sort();

  /// Onaylı kayıtların işlem türüne göre sayısı, çoktan aza.
  List<MapEntry<String, int>> get islemDagilimi {
    final m = <String, int>{};
    for (final x in onayli) {
      final k = x.islem.isEmpty ? 'Belirtilmedi' : x.islem;
      m[k] = (m[k] ?? 0) + 1;
    }
    return m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  /// Onaylı kayıtların makineye göre sayısı, çoktan aza.
  List<MapEntry<String, int>> get makineDagilimi {
    final m = <String, int>{};
    for (final x in onayli) {
      m[x.makine] = (m[x.makine] ?? 0) + 1;
    }
    return m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }
}
