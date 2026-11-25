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
    this.sapYer = '',
    this.gelenYer = '',
  });

  final DateTime tarih;
  final String birim, hesap, kategori, tedarikci, paraBirimi, durum, kontrol;

  /// Kaynak dosyalardaki yeri: SAP listesi (satır, belge no) ve ayrıntılı
  /// fatura raporu (sayfa, satır).
  final String sapYer, gelenYer;

  /// Fatura tutarı, [paraBirimi] cinsinden.
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
      sapYer: v.length > 10 ? m(10) : '',
      gelenYer: v.length > 11 ? m(11) : '',
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
    this.yer = '',
  });

  /// Açık bakiye dosyasındaki yeri (satır, belge no).
  final String yer;

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
      yer: v.length > 7 ? m(7) : '',
    );
  }
}

/// Bir bulgunun tek kaydı: iki kaynaktaki yeri, tutarı ve yapılacak düzeltme.
class MaliDetay {
  const MaliDetay({this.tarih, this.birim = '', this.tutarA, this.tutarB, this.yerA = '', this.yerB = '', this.yapilacak = ''});
  final DateTime? tarih;
  final String birim, yerA, yerB, yapilacak;
  final double? tutarA, tutarB;

  static MaliDetay? oku(Object? v) {
    if (v is! List || v.length < 7) return null;
    String m(int i) => (v[i] ?? '').toString().trim();
    return MaliDetay(
      tarih: tarihOku(v[0]),
      birim: m(1),
      tutarA: v[2] == null ? null : sayiOku(v[2]),
      tutarB: v[3] == null ? null : sayiOku(v[3]),
      yerA: m(4),
      yerB: m(5),
      yapilacak: m(6),
    );
  }
}

class MaliKontrol {
  const MaliKontrol({
    required this.bolum,
    required this.baslik,
    this.deger = '',
    this.aciklama = '',
    this.kaynakA = '',
    this.linkA = '',
    this.kaynakB = '',
    this.linkB = '',
    this.duzeltme = '',
    this.detay = const [],
  });
  final String bolum, baslik, deger, aciklama;

  /// Karşılaştırılan iki kaynak dosya ve Drive bağlantıları.
  final String kaynakA, linkA, kaynakB, linkB;

  /// Genel olarak ne yapılmalı.
  final String duzeltme;
  final List<MaliDetay> detay;

  static MaliKontrol? oku(Object? v) {
    if (v is! List || v.length < 2) return null;
    String m(int i) => i < v.length ? (v[i] ?? '').toString().trim() : '';
    if (m(1).isEmpty) return null;
    return MaliKontrol(
      bolum: m(0),
      baslik: m(1),
      deger: m(2),
      aciklama: m(3),
      kaynakA: m(4),
      linkA: m(5),
      kaynakB: m(6),
      linkB: m(7),
      duzeltme: m(8),
      detay: v.length > 9 && v[9] is List
          ? (v[9] as List).map(MaliDetay.oku).whereType<MaliDetay>().toList()
          : const [],
    );
  }
}

class MaliVeri {
  const MaliVeri({
    this.faturalar = const [],
    this.acik = const [],
    this.kontrol = const [],
    this.olusturma,
    this.kaynak = '',
    this.kdv = 'dahil',
    this.muhasebe = const [],
    this.muhasebeKaynak = '',
    this.muhasebeDonem = '',
    this.muhasebeLink = '',
  });

  /// Muhasebenin gönderdiği 2026 fatura listesi (SAP), fatura bazında; tutarlar KDV dahil.
  /// Her faturanın kontrol alanı birim fatura raporuyla karşılaştırma sonucudur.
  final List<MaliFatura> muhasebe;
  final String muhasebeKaynak, muhasebeDonem, muhasebeLink;

  final List<MaliFatura> faturalar;
  final List<MaliAcik> acik;
  final List<MaliKontrol> kontrol;
  final DateTime? olusturma;
  final String kaynak;

  /// Tutarların KDV durumu: 'hariç' ya da 'dahil'.
  final String kdv;

  /// Ödeme durumu (ödendi/açık) veride var mı.
  bool get odemeVar => faturalar.any((f) => f.durum.isNotEmpty);

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
      kdv: (j['kdv'] ?? 'dahil').toString(),
      muhasebe: l('muhasebe', MaliFatura.oku)..sort((a, b) => a.tarih.compareTo(b.tarih)),
      muhasebeKaynak: _bilgi(j, 'kaynak'),
      muhasebeDonem: _bilgi(j, 'donem'),
      muhasebeLink: _bilgi(j, 'link'),
    );
  }

  static String _bilgi(Map j, String k) {
    final b = j['muhasebeBilgi'];
    return b is Map ? (b[k] ?? '').toString() : '';
  }
}

/// Bir döneme ait fatura özeti.
class MaliOzet {
  MaliOzet(this.faturalar);
  final List<MaliFatura> faturalar;

  Iterable<MaliFatura> get _tl => faturalar.where((f) => f.paraBirimi == 'TRY');

  /// TL faturaların toplamı (döviz faturaları hariç).
  double get toplam => _tl.fold(0.0, (t, f) => t + f.tutar);
  double get acik => _tl.where((f) => f.acik).fold(0.0, (t, f) => t + f.tutar);

  /// Döviz faturalarının para birimine göre toplamı.
  Map<String, double> get doviz {
    final m = <String, double>{};
    for (final f in faturalar.where((f) => f.paraBirimi != 'TRY')) {
      m.update(f.paraBirimi, (v) => v + f.tutar, ifAbsent: () => f.tutar);
    }
    return m;
  }
  double get odenen => toplam - acik;

  /// Anahtara göre toplam, büyükten küçüğe.
  List<MapEntry<String, double>> grupla(String Function(MaliFatura) anahtar) {
    final m = <String, double>{};
    for (final f in _tl) {
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

/// Tutarsızlıkların düzeltilmesi için ilgili birime gönderilecek talep metni.
/// KVKK: yalnızca sayfa/satır, hücre değeri ve tüzel kişi fatura numarası içerir
/// (şahıs tedarikçilerin fatura numaraları veride zaten yoktur).
String duzeltmeTalebi(List<MaliKontrol> bulgular, {String imza = 'Ramazan Kocabaş\nTarım ve Hayvancılık Grup Müdürü'}) {
  final b = StringBuffer()
    ..writeln('Konu: 2026 fatura kayıtları – düzeltme talebi')
    ..writeln()
    ..writeln('Merhaba,')
    ..writeln('2026 Çiftlikler İş Birimi Gelen Fatura Raporları ve muhasebe 2026 fatura listesinde aşağıdaki kayıtlarda '
        'tutarsızlık tespit edilmiştir. Bu hususların incelenerek düzeltilmesini rica ederim.');
  var no = 0;
  final linkler = <String>{};
  for (final k in bulgular) {
    no++;
    b
      ..writeln()
      ..writeln('$no. ${k.baslik} (${k.deger})');
    if (k.duzeltme.isNotEmpty) b.writeln('Yapılacak: ${k.duzeltme}');
    for (final d in k.detay) {
      b.writeln('• ${d.yerA}${d.yapilacak.isEmpty ? '' : ' – ${d.yapilacak}'}');
    }
    if (k.linkA.isNotEmpty) linkler.add(k.linkA);
  }
  b.writeln();
  for (final l in linkler) {
    b.writeln('Dosya: $l');
  }
  b
    ..writeln('Düzeltmeler tamamlandığında bilgi verilmesini rica ederim.')
    ..writeln()
    ..writeln('Saygılarımla,')
    ..write(imza);
  return b.toString();
}
