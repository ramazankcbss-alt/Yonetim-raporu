// "ÇİFTLİKLER : MALİYET TAKİP 2026" dosyasından üretilen
// assets/veri/maliyet_takip_2026.json (araclar/ciftlik_rapor/maliyet_takip.py).
//
// KVKK: çiftlik ve kalem bazında toplam tutar, hayvan sayısı ve birim maliyet;
// işçilik yalnızca çiftlik toplamı. Kişi, ücret ayrıntısı, belge no yoktur.
import 'dart:convert';

double? _d(Object? v) => v == null ? null : (v as num).toDouble();

/// Hayvancılık aylık maliyeti (₺) ve hayvan sayısı.
class MtHayvan {
  const MtHayvan(this.ciftlik, this.yil, this.ay, this.yem, this.iscilik, this.amortisman, this.diger, this.toplam, this.hayvan);
  final String ciftlik;
  final int yil, ay;
  final double? yem, iscilik, amortisman, diger, toplam, hayvan;

  bool get tam => toplam != null && hayvan != null && hayvan! > 0;
  double? basina(double? v) => v == null || hayvan == null || hayvan == 0 ? null : v / hayvan!;
  double? get basinaAylik => basina(toplam);
  double? get basinaGunluk {
    final a = basinaAylik;
    if (a == null) return null;
    final gun = DateTime(yil, ay + 1, 0).day;
    return a / gun;
  }

  /// Kalem adı → tutar.
  Map<String, double?> get kalemler => {'Yem': yem, 'İşçilik': iscilik, 'Amortisman': amortisman, 'Diğer': diger};
}

class MtEkilis {
  const MtEkilis(this.ciftlik, this.urun, this.dekar, this.aylik, this.toplam);
  final String ciftlik, urun;
  final double? dekar;
  final Map<String, double> aylik;
  final double toplam;
  double? get dekarBasi => dekar == null || dekar == 0 ? null : toplam / dekar!;
}

class MtOrtak {
  const MtOrtak(this.yil, this.ay, this.iscilik, this.amortisman, this.diger);
  final int yil, ay;
  final double? iscilik, amortisman, diger;
  double get toplam => (iscilik ?? 0) + (amortisman ?? 0) + (diger ?? 0);
}

class MtSut {
  const MtSut(this.ciftlik, this.yil, this.ay, this.maliyet, this.satis);
  final String ciftlik;
  final int yil, ay;
  final double maliyet;
  final double? satis;
}

class MtKarkas {
  const MtKarkas(this.ciftlik, this.tur, this.ay, this.maliyet, this.not);
  final String ciftlik, tur, not;
  final int ay;
  final double? maliyet;
}

class MtCanli {
  const MtCanli(this.ciftlik, this.kategori, this.ay, this.maliyet);
  final String ciftlik, kategori;
  final int ay;
  final double maliyet;
}

class MtYem {
  const MtYem(this.grup, this.malzeme, this.ay, this.miktar, this.tutar);
  final String grup, malzeme;
  final int ay;
  final double miktar;
  final double? tutar;
  double? get fiyat => tutar == null || miktar == 0 ? null : tutar! / miktar;
}

class MtRefHatasi {
  const MtRefHatasi(this.sayfa, this.bolum, this.yil, this.adet);
  final String sayfa, bolum, yil;
  final int adet;
}

class MaliyetTakip {
  MaliyetTakip({
    required this.kaynak,
    required this.hayvan,
    required this.ortak,
    required this.ekilis,
    required this.sut,
    required this.karkas,
    required this.canli,
    required this.yem,
    required this.yemGenel,
    required this.refHatalari,
    required this.ozetRef,
    required this.toplamPangevKopya,
    required this.tasagilKopya,
    required this.sutTabloDisi,
    required this.yemToplamsiz,
    this.ortakYazili,
  });

  final String kaynak;
  final List<MtHayvan> hayvan;
  final List<MtOrtak> ortak;
  final List<MtEkilis> ekilis;
  final List<MtSut> sut;
  final List<MtKarkas> karkas;
  final List<MtCanli> canli;
  final List<MtYem> yem;

  /// Yem grubu → dosyadaki genel toplam tutar.
  final Map<String, double> yemGenel;
  final List<MtRefHatasi> refHatalari;
  final int ozetRef, toplamPangevKopya;
  final bool tasagilKopya;
  final List<String> sutTabloDisi;

  /// (grup, malzeme, miktar): aylık tüketimi olduğu hâlde toplam sütununa alınmamış satırlar.
  final List<(String, String, double)> yemToplamsiz;

  /// Tarım ortak giderleri için dosyadaki TOPLAM hücresinde yazan tutar.
  final double? ortakYazili;

  static MaliyetTakip coz(String metin) {
    final j = jsonDecode(metin) as Map<String, dynamic>;
    List<Map<String, dynamic>> l(String k, [Map<String, dynamic>? m]) => ((m ?? j)[k] as List).cast<Map<String, dynamic>>();
    final k = j['kontrol'] as Map<String, dynamic>;
    return MaliyetTakip(
      kaynak: j['kaynak'] as String,
      hayvan: [
        for (final x in l('hayvancilik'))
          MtHayvan(x['ciftlik'] as String, x['yil'] as int, x['ay'] as int, _d(x['yem']), _d(x['iscilik']), _d(x['amortisman']),
              _d(x['diger']), _d(x['toplam']), _d(x['hayvan'])),
      ],
      ortak: [for (final x in l('tarim_ortak')) MtOrtak(x['yil'] as int, x['ay'] as int, _d(x['iscilik']), _d(x['amortisman']), _d(x['diger']))],
      ekilis: [
        for (final x in l('tarim_ekilis'))
          MtEkilis(x['ciftlik'] as String, x['urun'] as String, _d(x['dekar']),
              {for (final e in (x['aylik'] as Map<String, dynamic>).entries) e.key: (e.value as num).toDouble()}, (x['toplam'] as num).toDouble()),
      ],
      sut: [for (final x in l('sut_litre')) MtSut(x['ciftlik'] as String, x['yil'] as int, x['ay'] as int, (x['maliyet'] as num).toDouble(), _d(x['satis']))],
      karkas: [for (final x in l('karkas')) MtKarkas(x['ciftlik'] as String, x['tur'] as String, x['ay'] as int, _d(x['maliyet']), x['not_'] as String? ?? '')],
      canli: [for (final x in l('canli')) MtCanli(x['ciftlik'] as String, x['kategori'] as String, x['ay'] as int, (x['maliyet'] as num).toDouble())],
      yem: [for (final x in l('yem')) MtYem(x['grup'] as String, x['malzeme'] as String, x['ay'] as int, (x['miktar'] as num).toDouble(), _d(x['tutar']))],
      yemGenel: {for (final x in l('yem_genel')) x['grup'] as String: (x['tutar'] as num).toDouble()},
      refHatalari: [for (final x in l('ref_hatalari', k)) MtRefHatasi(x['sayfa'] as String, x['bolum'] as String, x['yil'] as String, x['adet'] as int)],
      ozetRef: k['ozet_ref'] as int,
      toplamPangevKopya: k['toplam_2025_pangev_kopya'] as int,
      tasagilKopya: k['tasagil_2026_ocak_2025_kopya'] as bool? ?? false,
      sutTabloDisi: (k['sut_tablo_disi_hucre'] as List).cast<String>(),
      ortakYazili: _d(k['tarim_ortak_toplam_yazili']),
      yemToplamsiz: [
        for (final x in l('yem_toplama_alinmayan', k)) (x['grup'] as String, x['malzeme'] as String, (x['miktar'] as num).toDouble()),
      ],
    );
  }

  /// Hayvancılık tablosundaki çiftlikler (Taşağıl yalnız kopya Ocak verisi içerdiğinden hariç).
  List<String> get hayvanCiftlikleri => const ['Şekersüt', 'Pan-Gev', 'Aslım'];

  List<MtHayvan> hayvanAylar(String c, int yil) => [for (final h in hayvan) if (h.ciftlik == c && h.yil == yil && h.tam) h]
    ..sort((a, b) => a.ay.compareTo(b.ay));

  /// Dönem toplamı / ortalama hayvan sayısı → hayvan başı aylık ortalama.
  double? donemBasina(String c, int yil, String kalem) {
    final l = hayvanAylar(c, yil);
    if (l.isEmpty) return null;
    final t = l.fold(0.0, (s, h) => s + (kalem == 'Toplam' ? h.toplam! : (h.kalemler[kalem] ?? 0)));
    final hs = l.fold(0.0, (s, h) => s + h.hayvan!);
    return hs == 0 ? null : t / hs;
  }

  List<MtSut> sutAylar(String c, int yil) => [for (final s in sut) if (s.ciftlik == c && s.yil == yil) s]..sort((a, b) => a.ay.compareTo(b.ay));

  double get ortakToplam => ortak.fold(0.0, (s, o) => s + o.toplam);
  double get toplamDekar => ekilis.fold(0.0, (s, e) => s + (e.dekar ?? 0));

  /// Ortak giderlerin ekili alana göre dekar başı payı (dağıtım varsayımı).
  double get ortakDekarBasi => toplamDekar == 0 ? 0 : ortakToplam / toplamDekar;

  /// Bir yem grubunda ana yem kaleminin aylık birim fiyatları.
  List<MtYem> yemAylar(String grup, String malzeme) => [for (final y in yem) if (y.grup == grup && y.malzeme == malzeme && y.fiyat != null) y]
    ..sort((a, b) => a.ay.compareTo(b.ay));

  List<String> get yemGruplari => [for (final g in yemGenel.keys) g];

  /// Grupta tutarı en yüksek ana yem kalemleri (9 ay).
  List<(String, double)> anaYemler(String grup) {
    final m = <String, double>{};
    for (final y in yem) {
      if (y.grup == grup) m[y.malzeme] = (m[y.malzeme] ?? 0) + (y.tutar ?? 0);
    }
    final l = [for (final e in m.entries) (e.key, e.value)]..sort((a, b) => b.$2.compareTo(a.$2));
    return l;
  }
}
