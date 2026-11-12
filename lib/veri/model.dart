// Rapor verisi ve hesaplar.
//
// Veri, Apps Script bağlantısından JSON olarak gelir (bkz. apps_script/Kod.gs).
// Hesap kuralları, Google E-Tablosundaki haftalık rapor sayfasıyla aynıdır:
//  - Personel/taşeron/sağılan: dönemin son özet günündeki değer.
//  - Süt, doğan buzağı, kesim-satış, buzağı ölümü, kesilen dana: dönem toplamı.
//  - ESK-Taşağıl besi hayvanları ve kesilen danaları çiftlikler toplamına
//    dahil değildir; personel ve taşeron toplamına dahildir.
//  - Haftalık süt, sağmal ve satılan süt Fethiye + Erentepe günlük
//    kayıtlarından (Hayvan_Günlük) hesaplanır.

/// Türkçe yazılmış ya da sayı olarak gelen değeri okur ("12.648" → 12648,
/// "22,4" → 22.4). Boş veya okunamayan değer için null döner.
double? sayiOku(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  var s = v.toString().trim().replaceAll(' ', '');
  if (s.isEmpty) return null;
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^-?\d{1,3}(\.\d{3})+$').hasMatch(s)) {
    s = s.replaceAll('.', '');
  }
  return double.tryParse(s);
}

/// "2026-11-05" → 5 Kasım 2026 (yerel, saatsiz).
DateTime? tarihOku(Object? v) {
  if (v == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(v.toString().trim());
  if (m == null) return null;
  return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}

/// "2026-11-05" ya da "05.11.2026" → tarih. Kontrol Paneli tarihleri metin
/// olarak gelebildiği için işlerde bu esnek okuyucu kullanılır.
DateTime? tarihEsnek(Object? v) {
  final iso = tarihOku(v);
  if (iso != null) return iso;
  if (v == null) return null;
  final m = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})')
      .firstMatch(v.toString().trim());
  if (m == null) return null;
  return DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
}

DateTime gunu(DateTime d) => DateTime(d.year, d.month, d.day);

bool ayniGun(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Haftanın Pazartesi'si.
DateTime haftaBasi(DateTime d) {
  final g = gunu(d);
  return g.subtract(Duration(days: g.weekday - DateTime.monday));
}

/// ISO 8601 hafta numarası.
int isoHafta(DateTime d) {
  final g = gunu(d);
  final persembe = g.add(Duration(days: DateTime.thursday - g.weekday));
  final yilBasi = DateTime(persembe.year, 1, 1);
  return (persembe.difference(yilBasi).inDays ~/ 7) + 1;
}

bool _arada(DateTime t, DateTime bas, DateTime son) =>
    !t.isBefore(gunu(bas)) && !t.isAfter(gunu(son));

List<Object?> _liste(Object? v) => v is List ? v : const [];

String _metin(Object? v) => (v ?? '').toString().trim();

double _s(List r, int i) => i < r.length ? (sayiOku(r[i]) ?? 0) : 0;

// ---------------------------------------------------------------------------
// Ham satırlar
// ---------------------------------------------------------------------------

/// Hayvan_Özet: bir günün bir işletmesi.
class OzetSatir {
  const OzetSatir({
    required this.tarih,
    required this.isletme,
    this.personel = 0,
    this.taseron = 0,
    this.hayvan = 0,
    this.sagilan = 0,
    this.sut = 0,
    this.dogan = 0,
    this.kesimSatis = 0,
    this.buzagiOlum = 0,
    this.kesilenDana = 0,
  });

  final DateTime tarih;
  final String isletme;
  final double personel, taseron, hayvan, sagilan, sut;
  final double dogan, kesimSatis, buzagiOlum, kesilenDana;

  static OzetSatir? oku(Object? v) {
    final r = _liste(v);
    final t = r.isEmpty ? null : tarihOku(r[0]);
    if (t == null || r.length < 2 || _metin(r[1]).isEmpty) return null;
    return OzetSatir(
      tarih: t,
      isletme: _metin(r[1]),
      personel: _s(r, 2),
      taseron: _s(r, 3),
      hayvan: _s(r, 4),
      sagilan: _s(r, 5),
      sut: _s(r, 6),
      dogan: _s(r, 7),
      kesimSatis: _s(r, 8),
      buzagiOlum: _s(r, 9),
      kesilenDana: _s(r, 10),
    );
  }
}

/// Bir sürünün (Fethiye ya da Erentepe) bir günü.
class Suru {
  const Suru({
    this.toplam = 0,
    this.sagmal = 0,
    this.kuruGebe = 0,
    this.erkek = 0,
    this.sut = 0,
    this.satilan = 0,
  });

  final double toplam, sagmal, kuruGebe, erkek, sut, satilan;

  double get ortalama => sagmal > 0 ? sut / sagmal : 0;

  bool get bos => toplam == 0 && sagmal == 0 && sut == 0;
}

/// Hayvan_Günlük: bir günün Fethiye ve Erentepe değerleri.
class GunlukSatir {
  const GunlukSatir({
    required this.tarih,
    required this.fethiye,
    required this.erentepe,
  });

  final DateTime tarih;
  final Suru fethiye, erentepe;

  double get toplamHayvan => fethiye.toplam + erentepe.toplam;
  double get sagmal => fethiye.sagmal + erentepe.sagmal;
  double get sut => fethiye.sut + erentepe.sut;
  double get satilan => fethiye.satilan + erentepe.satilan;

  static GunlukSatir? oku(Object? v) {
    final r = _liste(v);
    final t = r.isEmpty ? null : tarihOku(r[0]);
    if (t == null) return null;
    Suru suru(int i) => Suru(
          toplam: _s(r, i),
          sagmal: _s(r, i + 1),
          kuruGebe: _s(r, i + 2),
          erkek: _s(r, i + 3),
          sut: _s(r, i + 4),
          satilan: _s(r, i + 5),
        );
    return GunlukSatir(tarih: t, fethiye: suru(1), erentepe: suru(7));
  }
}

class TarimKaydi {
  const TarimKaydi(
      {required this.tarih, required this.ciftlik, required this.faaliyet});

  final DateTime tarih;
  final String ciftlik;
  final String faaliyet;

  static TarimKaydi? oku(Object? v) {
    final r = _liste(v);
    final t = r.isEmpty ? null : tarihOku(r[0]);
    if (t == null || r.length < 3) return null;
    final c = _metin(r[1]);
    final f = _metin(r[2]);
    if (c.isEmpty || f.isEmpty) return null;
    return TarimKaydi(tarih: t, ciftlik: c, faaliyet: f);
  }
}

class EkimSatir {
  const EkimSatir(
      {required this.ciftlik, required this.urun, this.plan, this.ekilen});

  final String ciftlik, urun;
  final double? plan, ekilen;

  double? get oran => (plan ?? 0) > 0 && ekilen != null
      ? (ekilen! / plan!).clamp(0.0, 1.5).toDouble()
      : null;

  static EkimSatir? oku(Object? v) {
    final r = _liste(v);
    if (r.length < 2 || _metin(r[0]).isEmpty) return null;
    return EkimSatir(
      ciftlik: _metin(r[0]),
      urun: _metin(r[1]),
      plan: r.length > 2 ? sayiOku(r[2]) : null,
      ekilen: r.length > 3 ? sayiOku(r[3]) : null,
    );
  }
}

class HasatSatir {
  const HasatSatir({
    required this.urun,
    required this.ciftlik,
    this.alan,
    this.toplam,
    this.verim,
    this.tarih,
  });

  final String urun, ciftlik;
  final double? alan, toplam, verim;
  final DateTime? tarih;

  static HasatSatir? oku(Object? v) {
    final r = _liste(v);
    if (r.length < 2 || _metin(r[0]).isEmpty) return null;
    final alan = r.length > 2 ? sayiOku(r[2]) : null;
    final toplam = r.length > 3 ? sayiOku(r[3]) : null;
    var verim = r.length > 4 ? sayiOku(r[4]) : null;
    if (verim == null && (alan ?? 0) > 0 && toplam != null) {
      verim = toplam / alan!;
    }
    return HasatSatir(
      urun: _metin(r[0]),
      ciftlik: _metin(r[1]),
      alan: alan,
      toplam: toplam,
      verim: verim,
      tarih: r.length > 5 ? tarihOku(r[5]) : null,
    );
  }
}

class BesiSatir {
  const BesiSatir(
      {required this.isletme, this.yerli = 0, this.erkek = 0, this.inek = 0});

  final String isletme;
  final double yerli, erkek, inek;

  static BesiSatir? oku(Object? v) {
    final r = _liste(v);
    if (r.isEmpty || _metin(r[0]).isEmpty) return null;
    return BesiSatir(
        isletme: _metin(r[0]), yerli: _s(r, 1), erkek: _s(r, 2), inek: _s(r, 3));
  }
}

/// Kontrol Paneli'ndeki tek bir iş / takip kalemi.
/// Sütunlar: No, Konu, Çiftlik/Birim, Kaynak, Açılış, Durum,
/// Son değişiklik, Son durum, Sorumlu.
class Is {
  const Is({
    required this.no,
    required this.konu,
    this.ciftlik = '',
    this.kaynak = '',
    this.acilis,
    this.durum = '',
    this.sonDegisiklik,
    this.sonDurum = '',
    this.sorumlu = '',
  });

  final int no;
  final String konu, ciftlik, kaynak, durum, sonDurum, sorumlu;
  final DateTime? acilis, sonDegisiklik;

  bool get bekliyor => durum == 'Bekliyor';
  bool get devam => durum == 'Devam ediyor';
  bool get tamam => durum == 'Tamamlandı';

  /// Bekleyen ve açılışından bu yana 14 günü geçmiş iş.
  bool gecikmis(DateTime bugun) =>
      bekliyor &&
      acilis != null &&
      gunu(bugun).difference(gunu(acilis!)).inDays > 14;

  static Is? oku(Object? v) {
    final r = _liste(v);
    if (r.length < 2) return null;
    final no = sayiOku(r[0]);
    final konu = _metin(r[1]);
    if (no == null || konu.isEmpty) return null;
    return Is(
      no: no.round(),
      konu: konu,
      ciftlik: r.length > 2 ? _metin(r[2]) : '',
      kaynak: r.length > 3 ? _metin(r[3]) : '',
      acilis: r.length > 4 ? tarihEsnek(r[4]) : null,
      durum: r.length > 5 ? _metin(r[5]) : '',
      sonDegisiklik: r.length > 6 ? tarihEsnek(r[6]) : null,
      sonDurum: r.length > 7 ? _metin(r[7]) : '',
      sorumlu: r.length > 8 ? _metin(r[8]) : '',
    );
  }
}

/// İş Akışı tablosundaki bir kalem: siparişten finansa kadar ilerleyen bir iş
/// ya da Arıza-Bakım / İnsan Kaynakları / Diğer bölümünden bir kayıt.
class AkisKaydi {
  const AkisKaydi({
    required this.no,
    required this.baslik,
    this.bolum = '',
    this.durum = '',
    this.firma = '',
    this.tutar = '',
    this.anahtar = '',
    this.acilis,
    this.sonGuncelleme,
    this.kaynak = '',
    this.sonrakiAdim = '',
    this.detay = '',
  });

  final int no;
  final String baslik, bolum, durum, firma, tutar, anahtar, kaynak;
  final String sonrakiAdim, detay;
  final DateTime? acilis, sonGuncelleme;

  /// Satınalma hattındaki aşama sırası; hat dışı bölümler için -1.
  static const List<String> hat = [
    'Sipariş',
    'Satınalma',
    'Malzeme Tedarik',
    'Muhasebe',
    'Finans',
    'Tamamlandı',
  ];

  int get asama => hat.indexOf(bolum);
  bool get hatta => asama >= 0;
  bool get tamam => bolum == 'Tamamlandı';
  bool get finansta => bolum == 'Finans';

  static AkisKaydi? oku(Object? v) {
    final r = _liste(v);
    if (r.length < 2) return null;
    final no = sayiOku(r[0]);
    final baslik = _metin(r[1]);
    if (no == null || baslik.isEmpty) return null;
    return AkisKaydi(
      no: no.round(),
      baslik: baslik,
      bolum: r.length > 2 ? _metin(r[2]) : '',
      durum: r.length > 3 ? _metin(r[3]) : '',
      firma: r.length > 4 ? _metin(r[4]) : '',
      tutar: r.length > 5 ? _metin(r[5]) : '',
      anahtar: r.length > 6 ? _metin(r[6]) : '',
      acilis: r.length > 7 ? tarihEsnek(r[7]) : null,
      sonGuncelleme: r.length > 8 ? tarihEsnek(r[8]) : null,
      kaynak: r.length > 9 ? _metin(r[9]) : '',
      sonrakiAdim: r.length > 10 ? _metin(r[10]) : '',
      detay: r.length > 11 ? _metin(r[11]) : '',
    );
  }
}

// ---------------------------------------------------------------------------
// Tüm veri
// ---------------------------------------------------------------------------

class RaporVerisi {
  RaporVerisi({
    required List<OzetSatir> ozet,
    required List<GunlukSatir> gunluk,
    required List<TarimKaydi> tarim,
    this.ekim = const [],
    this.hasat = const [],
    this.besi = const [],
    this.isler = const [],
    this.akis = const [],
    this.olusturma,
  })  : ozet = List.unmodifiable(
            [...ozet]..sort((a, b) => a.tarih.compareTo(b.tarih))),
        gunluk = List.unmodifiable(
            [...gunluk]..sort((a, b) => a.tarih.compareTo(b.tarih))),
        tarim = List.unmodifiable([...tarim]
          ..sort((a, b) {
            final c = a.tarih.compareTo(b.tarih);
            return c != 0 ? c : a.ciftlik.compareTo(b.ciftlik);
          }));

  final List<OzetSatir> ozet;
  final List<GunlukSatir> gunluk;
  final List<TarimKaydi> tarim;
  final List<EkimSatir> ekim;
  final List<HasatSatir> hasat;
  final List<BesiSatir> besi;
  final List<Is> isler;
  final List<AkisKaydi> akis;
  final DateTime? olusturma;

  factory RaporVerisi.json(Map<String, dynamic> j) {
    List<T> oku<T extends Object>(String alan, T? Function(Object?) f) =>
        _liste(j[alan]).map(f).whereType<T>().toList();
    return RaporVerisi(
      ozet: oku('hayvanOzet', OzetSatir.oku),
      gunluk: oku('hayvanGunluk', GunlukSatir.oku),
      tarim: oku('tarim', TarimKaydi.oku),
      ekim: oku('ekim', EkimSatir.oku),
      hasat: oku('hasat', HasatSatir.oku),
      besi: oku('besi', BesiSatir.oku),
      isler: oku('isler', Is.oku),
      akis: oku('isakisi', AkisKaydi.oku),
      olusturma: DateTime.tryParse(_metin(j['olusturma'])),
    );
  }

  bool get bos => ozet.isEmpty && gunluk.isEmpty && tarim.isEmpty;

  /// Canlı hayvan verisi olan günler (özet veya günlük), yeniden eskiye.
  List<DateTime> get gunler {
    final s = <DateTime>{
      for (final o in ozet) o.tarih,
      for (final g in gunluk) g.tarih,
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    return s;
  }

  /// Varsayılan gün: son özet günü (yoksa son günlük kayıt).
  DateTime? get sonGun {
    if (ozet.isNotEmpty) return ozet.last.tarih;
    if (gunluk.isNotEmpty) return gunluk.last.tarih;
    if (tarim.isNotEmpty) return tarim.last.tarih;
    return null;
  }

  /// Verisi olan haftaların Pazartesi'leri, yeniden eskiye.
  List<DateTime> get haftalar {
    final s = <DateTime>{
      for (final o in ozet) haftaBasi(o.tarih),
      for (final g in gunluk) haftaBasi(g.tarih),
      for (final t in tarim) haftaBasi(t.tarih),
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    return s;
  }

  GunlukSatir? gunlukBul(DateTime d) {
    for (final g in gunluk) {
      if (ayniGun(g.tarih, d)) return g;
    }
    return null;
  }

  /// d gününden önceki son günlük kayıt.
  GunlukSatir? oncekiGunluk(DateTime d) {
    GunlukSatir? s;
    for (final g in gunluk) {
      if (g.tarih.isBefore(gunu(d))) s = g;
    }
    return s;
  }

  List<GunlukSatir> gunlukDonem(DateTime bas, DateTime son) =>
      [for (final g in gunluk) if (_arada(g.tarih, bas, son)) g];

  List<TarimKaydi> tarimDonem(DateTime bas, DateTime son) =>
      [for (final t in tarim) if (_arada(t.tarih, bas, son)) t];

  /// Her çiftliğin [son] gününe kadarki (isteğe bağlı [bas]'tan sonraki)
  /// son kaydı. Sıra: bilinen çiftlikler, sonra diğerleri.
  List<TarimKaydi> sonFaaliyetler(DateTime son, {DateTime? bas}) {
    final m = <String, TarimKaydi>{};
    for (final t in tarim) {
      if (t.tarih.isAfter(gunu(son))) continue;
      if (bas != null && t.tarih.isBefore(gunu(bas))) continue;
      m[t.ciftlik] = t; // tarih sıralı; son yazılan en yenisi
    }
    final sira = [
      for (final c in ciftlikSirasi)
        if (m.containsKey(c)) m[c]!,
      for (final e in m.entries)
        if (!ciftlikSirasi.contains(e.key)) e.value,
    ];
    return sira;
  }
}

const ciftlikSirasi = ['Şekersüt', 'Aslım', 'Taşağıl', 'Fidanlık'];

// ---------------------------------------------------------------------------
// İşletme bazlı canlı hayvan özeti (E-Tablodaki "HAFTALIK CANLI HAYVAN ÖZETİ")
// ---------------------------------------------------------------------------

const eskBesi = 'ESK-Taşağıl Çiftliği Besi Danası';
const digerAdi = 'Diğer (Güvenlik, Çumpaş, Konya Merkez, Yönetici)';
const anaIsletmeler = [
  'Fethiye Şube',
  'Fethiye Şube Holstein Besi',
  'Pankent Çiftliği',
  'Erentepe Şube',
  'Aslım Çiftliği Besi Danası',
  eskBesi,
];

class IsletmeSatiri {
  const IsletmeSatiri({
    required this.ad,
    this.personel = 0,
    this.taseron = 0,
    this.hayvan = 0,
    this.sagilan = 0,
    this.sut = 0,
    this.sagilanGun = 0,
    this.dogan = 0,
    this.kesimSatis = 0,
    this.buzagiOlum = 0,
    this.kesilenDana = 0,
  });

  final String ad;

  /// Dönemin son özet gününden.
  final double personel, taseron, hayvan, sagilan;

  /// Dönem toplamları.
  final double sut, sagilanGun, dogan, kesimSatis, buzagiOlum, kesilenDana;

  /// Süt / (dönemdeki günlerin sağılan hayvan toplamı).
  double get ortVerim => sagilanGun > 0 ? sut / sagilanGun : 0;
}

class CanliHayvanOzeti {
  const CanliHayvanOzeti({
    required this.ozetGunu,
    required this.satirlar,
    required this.toplam,
  });

  /// Dönemdeki son özet günü; dönemde özet yoksa null.
  final DateTime? ozetGunu;

  /// Ana işletmeler + "Diğer".
  final List<IsletmeSatiri> satirlar;

  /// Çiftlikler toplamı (ESK-Taşağıl hayvan ve kesilen dana hariç).
  final IsletmeSatiri toplam;

  IsletmeSatiri? bul(String ad) {
    for (final s in satirlar) {
      if (s.ad == ad) return s;
    }
    return null;
  }
}

CanliHayvanOzeti canliHayvanOzeti(RaporVerisi v, DateTime bas, DateTime son) {
  final donem = [for (final o in v.ozet) if (_arada(o.tarih, bas, son)) o];
  DateTime? gun;
  for (final o in donem) {
    if (gun == null || o.tarih.isAfter(gun)) gun = o.tarih;
  }

  IsletmeSatiri hesapla(String ad, bool Function(String) uyar) {
    double p = 0, t = 0, h = 0, s = 0;
    double sut = 0, sg = 0, d = 0, ks = 0, bo = 0, kd = 0;
    for (final o in donem) {
      if (!uyar(o.isletme)) continue;
      if (gun != null && ayniGun(o.tarih, gun)) {
        p += o.personel;
        t += o.taseron;
        h += o.hayvan;
        s += o.sagilan;
      }
      sut += o.sut;
      sg += o.sagilan;
      d += o.dogan;
      ks += o.kesimSatis;
      bo += o.buzagiOlum;
      kd += o.kesilenDana;
    }
    return IsletmeSatiri(
      ad: ad,
      personel: p,
      taseron: t,
      hayvan: h,
      sagilan: s,
      sut: sut,
      sagilanGun: sg,
      dogan: d,
      kesimSatis: ks,
      buzagiOlum: bo,
      kesilenDana: kd,
    );
  }

  final satirlar = [
    for (final a in anaIsletmeler) hesapla(a, (x) => x == a),
    hesapla(digerAdi, (x) => !anaIsletmeler.contains(x)),
  ];

  double top(double Function(IsletmeSatiri) f, {bool eskHaric = false}) =>
      satirlar
          .where((s) => !(eskHaric && s.ad == eskBesi))
          .fold(0.0, (a, s) => a + f(s));

  final toplam = IsletmeSatiri(
    ad: 'ÇİFTLİKLER TOPLAM',
    personel: top((s) => s.personel),
    taseron: top((s) => s.taseron),
    // E-Tabloda: ana işletmelerden ESK hariç (Diğer'in hayvanı yok).
    hayvan: satirlar
        .where((s) => s.ad != eskBesi && s.ad != digerAdi)
        .fold(0.0, (a, s) => a + s.hayvan),
    sagilan: top((s) => s.sagilan),
    sut: top((s) => s.sut),
    sagilanGun: top((s) => s.sagilanGun),
    dogan: top((s) => s.dogan),
    kesimSatis: top((s) => s.kesimSatis),
    buzagiOlum: top((s) => s.buzagiOlum),
    kesilenDana: top((s) => s.kesilenDana, eskHaric: true),
  );

  return CanliHayvanOzeti(ozetGunu: gun, satirlar: satirlar, toplam: toplam);
}

// ---------------------------------------------------------------------------
// Gösterge kartları
// ---------------------------------------------------------------------------

class Gostergeler {
  const Gostergeler({
    this.toplamHayvan,
    this.sagilan,
    this.sut,
    this.ortVerim,
    this.satilan,
    this.personel,
    this.taseron,
    this.dogan,
    this.kesilenDana,
    this.olenBuzagi,
    this.kesimSatis,
    this.eskBesiHayvan,
    this.eskKesilen,
  });

  final double? toplamHayvan, sagilan, sut, ortVerim, satilan;
  final double? personel, taseron, dogan, kesilenDana, olenBuzagi, kesimSatis;
  final double? eskBesiHayvan, eskKesilen;
}

/// Tek bir günün göstergeleri.
Gostergeler gunlukGostergeler(RaporVerisi v, DateTime d) {
  final oz = canliHayvanOzeti(v, d, d);
  final g = v.gunlukBul(d);
  final esk = oz.bul(eskBesi);
  final ozVar = oz.ozetGunu != null;
  final sut = ozVar ? oz.toplam.sut : g?.sut;
  final sag = ozVar ? oz.toplam.sagilan : g?.sagmal;
  return Gostergeler(
    toplamHayvan: ozVar ? oz.toplam.hayvan : g?.toplamHayvan,
    sagilan: sag,
    sut: sut,
    ortVerim: (sag ?? 0) > 0 && sut != null ? sut / sag! : null,
    satilan: g?.satilan,
    personel: ozVar ? oz.toplam.personel : null,
    taseron: ozVar ? oz.toplam.taseron : null,
    dogan: ozVar ? oz.toplam.dogan : null,
    kesilenDana: ozVar ? oz.toplam.kesilenDana : null,
    olenBuzagi: ozVar ? oz.toplam.buzagiOlum : null,
    kesimSatis: ozVar ? oz.toplam.kesimSatis : null,
    eskBesiHayvan: ozVar ? esk?.hayvan : null,
    eskKesilen: ozVar ? esk?.kesilenDana : null,
  );
}

/// Pazartesi [bas] ile başlayan haftanın göstergeleri (E-Tablodaki üst kartlar).
Gostergeler haftalikGostergeler(RaporVerisi v, DateTime bas) {
  final son = gunu(bas).add(const Duration(days: 6));
  final oz = canliHayvanOzeti(v, bas, son);
  final gunler = v.gunlukDonem(bas, son);
  final esk = oz.bul(eskBesi);
  final ozVar = oz.ozetGunu != null;
  final sonG = gunler.isEmpty ? null : gunler.last;
  final sut =
      gunler.isEmpty ? null : gunler.fold<double>(0, (a, g) => a + g.sut);
  final sagGun = gunler.fold(0.0, (a, g) => a + g.sagmal);
  return Gostergeler(
    toplamHayvan: sonG?.toplamHayvan ?? (ozVar ? oz.toplam.hayvan : null),
    sagilan: sonG?.sagmal ?? (ozVar ? oz.toplam.sagilan : null),
    sut: sut,
    ortVerim: sagGun > 0 && sut != null ? sut / sagGun : null,
    satilan:
        gunler.isEmpty ? null : gunler.fold<double>(0, (a, g) => a + g.satilan),
    personel: ozVar ? oz.toplam.personel : null,
    taseron: ozVar ? oz.toplam.taseron : null,
    dogan: ozVar ? oz.toplam.dogan : null,
    kesilenDana: ozVar ? oz.toplam.kesilenDana : null,
    olenBuzagi: ozVar ? oz.toplam.buzagiOlum : null,
    kesimSatis: ozVar ? oz.toplam.kesimSatis : null,
    eskBesiHayvan: ozVar ? esk?.hayvan : null,
    eskKesilen: ozVar ? esk?.kesilenDana : null,
  );
}

/// Ekim alanları toplamı: (plan, ekilen).
(double, double) ekimToplami(List<EkimSatir> ekim) => (
      ekim.fold(0.0, (a, e) => a + (e.plan ?? 0)),
      ekim.fold(0.0, (a, e) => a + (e.ekilen ?? 0)),
    );
