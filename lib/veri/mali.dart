// Mali Raporlar: çiftliklerin gelen faturaları (SAP satıcı listesi), açık
// bakiyeler ve dosyalar arası kontrol bulguları. Veri "Mali Raporlar"
// klasöründeki mali_veri.json'dan gelir.
//
// KVKK: şahıs işletmesi / gerçek kişi tedarikçi adı, fatura numarası, plaka
// ve personel ücret ayrıntısı veride yoktur ("Şahıs / teyitsiz tedarikçi").

import 'model.dart';

class MaliFatura {
  const MaliFatura({
    required this.tarih,
    required this.birim,
    required this.hesap,
    required this.kategori,
    required this.tedarikci,
    required this.tutar,
    this.paraBirimi = 'TRY',
    this.vade,
    required this.durum,
    required this.kontrol,
  });

  final DateTime tarih;
  final String birim, hesap, kategori, tedarikci, paraBirimi, durum, kontrol;

  /// KDV dahil, TL.
  final double tutar;
  final DateTime? vade;

  bool get acik => durum == 'Açık';

  static MaliFatura? oku(Object? v) {
    if (v is! List || v.length < 10) return null;
    final t = tarihOku(v[0]);
    final tutar = sayiOku(v[5]);
    if (t == null || tutar == null) return null;
    String m(int i) => (v[i] ?? '').toString().trim();
    return MaliFatura(
      tarih: t,
      birim: m(1),
      hesap: m(2),
      kategori: m(3),
      tedarikci: m(4),
      tutar: tutar,
      paraBirimi: m(6).isEmpty ? 'TRY' : m(6),
      vade: tarihOku(v[7]),
      durum: m(8),
      kontrol: m(9),
    );
  }
}

class MaliAcik {
  const MaliAcik({
    required this.tarih,
    required this.birim,
    required this.kategori,
    required this.tedarikci,
    required this.tutar,
    this.odeme,
    this.gecikme,
  });

  final DateTime tarih;
  final String birim, kategori, tedarikci;
  final double tutar;
  final DateTime? odeme;

  /// Veri tarihine göre ödeme tarihinden bu yana geçen gün (eksi: vadesine var).
  final int? gecikme;

  /// [bugun]'e göre vadesi geçmiş mi.
  bool gecmis(DateTime bugun) => odeme != null && odeme!.isBefore(gunu(bugun));

  static MaliAcik? oku(Object? v) {
    if (v is! List || v.length < 7) return null;
    final t = tarihOku(v[0]);
    final tutar = sayiOku(v[4]);
    if (t == null || tutar == null) return null;
    String m(int i) => (v[i] ?? '').toString().trim();
    return MaliAcik(
      tarih: t,
      birim: m(1),
      kategori: m(2),
      tedarikci: m(3),
      tutar: tutar,
      odeme: tarihOku(v[5]),
      gecikme: sayiOku(v[6])?.round(),
    );
  }
}

class MaliKontrol {
  const MaliKontrol({required this.bolum, required this.baslik, this.deger = '', this.aciklama = ''});
  final String bolum, baslik, deger, aciklama;

  static MaliKontrol? oku(Object? v) {
    if (v is! List || v.length < 2) return null;
    String m(int i) => i < v.length ? (v[i] ?? '').toString().trim() : '';
    if (m(1).isEmpty) return null;
    return MaliKontrol(bolum: m(0), baslik: m(1), deger: m(2), aciklama: m(3));
  }
}

class MaliVeri {
  const MaliVeri({this.faturalar = const [], this.acik = const [], this.kontrol = const [], this.olusturma, this.kaynak = ''});

  final List<MaliFatura> faturalar;
  final List<MaliAcik> acik;
  final List<MaliKontrol> kontrol;
  final DateTime? olusturma;
  final String kaynak;

  bool get bos => faturalar.isEmpty && acik.isEmpty && kontrol.isEmpty;

  factory MaliVeri.json(Object? j) {
    if (j is! Map) return const MaliVeri();
    List<T> l<T>(String k, T? Function(Object?) f) =>
        (j[k] is List ? j[k] as List : const []).map(f).whereType<T>().toList();
    return MaliVeri(
      faturalar: l('fatura', MaliFatura.oku)..sort((a, b) => a.tarih.compareTo(b.tarih)),
      acik: l('acik', MaliAcik.oku),
      kontrol: l('kontrol', MaliKontrol.oku),
      olusturma: tarihOku(j['olusturma']),
      kaynak: (j['kaynak'] ?? '').toString(),
    );
  }
}

/// Bir döneme ait fatura özeti.
class MaliOzet {
  MaliOzet(this.faturalar);
  final List<MaliFatura> faturalar;

  double get toplam => faturalar.fold(0.0, (t, f) => t + f.tutar);
  double get acik => faturalar.where((f) => f.acik).fold(0.0, (t, f) => t + f.tutar);
  double get odenen => toplam - acik;

  /// Anahtara göre toplam, büyükten küçüğe.
  List<MapEntry<String, double>> grupla(String Function(MaliFatura) anahtar) {
    final m = <String, double>{};
    for (final f in faturalar) {
      m.update(anahtar(f), (v) => v + f.tutar, ifAbsent: () => f.tutar);
    }
    return m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  Map<String, int> kontrolSayilari() {
    final m = <String, int>{};
    for (final f in faturalar) {
      m.update(f.kontrol, (n) => n + 1, ifAbsent: () => 1);
    }
    return m;
  }
}

enum MaliDonem { gun, hafta, ay, yil }

/// Faturanın dönem başlangıcı.
DateTime maliDonemBasi(DateTime t, MaliDonem d) => switch (d) {
      MaliDonem.gun => gunu(t),
      MaliDonem.hafta => haftaBasi(t),
      MaliDonem.ay => DateTime(t.year, t.month),
      MaliDonem.yil => DateTime(t.year),
    };

/// Dönem başlangıcı → o dönemin faturaları (yeniden eskiye).
List<MapEntry<DateTime, List<MaliFatura>>> maliDonemler(List<MaliFatura> l, MaliDonem d) {
  final m = <DateTime, List<MaliFatura>>{};
  for (final f in l) {
    m.putIfAbsent(maliDonemBasi(f.tarih, d), () => []).add(f);
  }
  return m.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
}
