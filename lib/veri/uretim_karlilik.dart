// Tarımsal Faaliyet dosyası › "ÇİFTLİK BAZINDA" sayfasından üretim ve kârlılık:
// ekim alanı, dekara verim, toplam verim, satış tutarı, toplam maliyet, net kazanç.
// Ürün bazında değerler çiftlik satırlarının toplamıdır (dekara verim: toplam verim / alan).
// Kişi bilgisi içermez.

import 'model.dart';

class UretimKalemi {
  UretimKalemi({
    required this.ad,
    this.cesit = '',
    this.alt = '',
    this.dekar = 0,
    this.toplamVerim = 0,
    this.birimFiyat = 0,
    this.satis = 0,
    this.maliyet = 0,
  });

  /// Çiftlik ya da ürün adı.
  final String ad;

  /// Ürün ticari ismi (çeşit) — yalnızca çiftlik satırında.
  final String cesit;

  /// Ek açıklama (ör. "Ormanlık").
  final String alt;
  double dekar, toplamVerim, birimFiyat, satis, maliyet;

  double get dekaraVerim => dekar > 0 ? toplamVerim / dekar : 0;
  double get netKazanc => satis - maliyet;
  double get dekarKazanc => dekar > 0 ? netKazanc / dekar : 0;

  void ekle(UretimKalemi k) {
    dekar += k.dekar;
    toplamVerim += k.toplamVerim;
    satis += k.satis;
    maliyet += k.maliyet;
  }
}

class CiftlikUretimi {
  CiftlikUretimi(this.ciftlik);
  final String ciftlik;
  final List<UretimKalemi> urunler = [];

  UretimKalemi get toplam {
    final t = UretimKalemi(ad: ciftlik);
    for (final u in urunler) {
      t.ekle(u);
    }
    return t;
  }
}

class TarimsalUretim {
  const TarimsalUretim({
    this.dosya = '',
    this.yilBasligi = '',
    this.ciftlikler = const [],
    this.ekGelirler = const [],
    this.excelToplamKazanc,
  });

  final String dosya, yilBasligi;
  final List<CiftlikUretimi> ciftlikler;

  /// Sayfanın altındaki ek kalemler (sap balyaları, küspe, kota tamamlama, destekler).
  final List<(String, double)> ekGelirler;

  /// Excel'deki "TOPLAM KAZANÇ" (net kazanç + ek gelirler).
  final double? excelToplamKazanc;

  bool get bos => ciftlikler.isEmpty;

  /// Ürün bazında: çiftlik satırlarının ürüne göre toplamı (satışa göre büyükten küçüğe).
  List<UretimKalemi> get urunler {
    final m = <String, UretimKalemi>{};
    for (final c in ciftlikler) {
      for (final u in c.urunler) {
        m.putIfAbsent(u.ad, () => UretimKalemi(ad: u.ad)).ekle(u);
      }
    }
    return m.values.toList()..sort((a, b) => b.satis.compareTo(a.satis));
  }

  UretimKalemi get genelToplam {
    final t = UretimKalemi(ad: 'Toplam');
    for (final c in ciftlikler) {
      t.ekle(c.toplam);
    }
    return t;
  }

  double get ekGelirToplami => ekGelirler.fold(0.0, (a, e) => a + e.$2);

  static String _kucuk(String s) => s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

  static String ciftlikAdi(String c) {
    final k = _kucuk(c);
    if (k.contains('şeker')) return 'Şekersüt';
    if (k.contains('aslım')) return 'Aslım';
    // Ormanlık, Taşağıl çiftliğine ait alandır.
    if (k.contains('taşağıl') || k.contains('ormanlık')) return 'Taşağıl';
    if (k.contains('fidanl')) return 'Fidanlık';
    final t = c.trim();
    return t.isEmpty ? t : '${t[0]}${_kucuk(t.substring(1))}';
  }

  static String urunAdi(String u) {
    final k = _kucuk(u.trim());
    if (k.contains('pancar')) return 'Şeker Pancarı';
    if (k.contains('mısır')) return 'Silajlık Mısır';
    if (k.contains('buğday')) return 'Buğday';
    if (k.contains('arpa')) return 'Arpa';
    if (k.contains('tritikale')) return 'Tritikale';
    if (k.contains('yonca')) return 'Yonca';
    if (k.contains('patates')) return 'Patates';
    final t = u.trim();
    return t.isEmpty ? t : '${t[0]}${_kucuk(t.substring(1))}';
  }

  /// Sunucudan gelen { dosya, urunBasligi, satirlar } verisini okur.
  factory TarimsalUretim.json(Object? v) {
    if (v is! Map) return const TarimsalUretim();
    final satirlar = v['satirlar'];
    if (satirlar is! List) return const TarimsalUretim();
    String m(List r, int i) => i < r.length ? '${r[i] ?? ''}'.trim() : '';
    double n(List r, int i) => i < r.length ? (sayiOku(r[i]) ?? 0) : 0;

    final ciftlikler = <String, CiftlikUretimi>{};
    final ek = <(String, double)>[];
    double? toplamKazanc;
    var baslik = false;
    var ciftlik = '';
    var hamCiftlik = '';
    for (final r in satirlar) {
      if (r is! List || r.isEmpty) continue;
      final a = m(r, 0), b = m(r, 1);
      final ak = _kucuk(a), bk = _kucuk(b);
      if (!baslik) {
        if (ak.startsWith('işletme')) baslik = true;
        continue;
      }
      if (a.isNotEmpty && !ak.startsWith('toplam')) {
        hamCiftlik = a;
        ciftlik = ciftlikAdi(a);
      }
      // Alt bölüm: "NET KAZANÇ / SAP BALYALARI / … / TOPLAM KAZANÇ" (B sütunu etiket, C değer)
      if (a.isEmpty && b.isNotEmpty && m(r, 2).isNotEmpty && sayiOku(r[2]) != null && m(r, 3).isEmpty) {
        final deger = n(r, 2);
        if (bk.contains('toplam kazanç')) {
          toplamKazanc = deger;
        } else if (!bk.contains('net kazanç') && deger != 0) {
          ek.add((b, deger));
        }
        continue;
      }
      if (ak.startsWith('toplam') || bk.startsWith('toplam') || b.isEmpty || ciftlik.isEmpty) continue;
      final dekar = n(r, 3);
      if (dekar <= 0) continue;
      final ormanlik = _kucuk(hamCiftlik).contains('ormanlık');
      ciftlikler.putIfAbsent(ciftlik, () => CiftlikUretimi(ciftlik)).urunler.add(UretimKalemi(
            ad: urunAdi(b),
            cesit: m(r, 2),
            alt: ormanlik ? 'Ormanlık' : '',
            dekar: dekar,
            toplamVerim: n(r, 5),
            birimFiyat: n(r, 6),
            satis: n(r, 7),
            maliyet: n(r, 10),
          ));
    }
    final yil = RegExp(r'(20\d\d)').firstMatch('${v['urunBasligi'] ?? ''}')?[1] ?? '';
    return TarimsalUretim(
      dosya: '${v['dosya'] ?? ''}',
      yilBasligi: yil,
      ciftlikler: ciftlikler.values.toList(),
      ekGelirler: ek,
      excelToplamKazanc: toplamKazanc,
    );
  }
}
