// Tarımsal faaliyet kayıtlarını rapor için kurumsal üsluba getirir.
//
// KVKK: Rapor dışarıya (Genel Müdürlük) gönderildiği için faaliyet
// metinlerindeki kişi adları (operatör, formen, sürücü, taşeron / işçi
// bilgisi) çıkarılır. İşlem tamamen cihazda yapılır; veri hiçbir servise
// gönderilmez.

import 'model.dart';

/// Bir çiftliğin dönem içindeki faaliyetlerinin madde madde özeti.
class FaaliyetOzeti {
  const FaaliyetOzeti(this.ciftlik, this.maddeler);
  final String ciftlik;
  final List<String> maddeler;
}

final _formenOnEki =
    RegExp(r'formen\s+bildirimi\s*(\([^)]*\))?\s*:\s*', caseSensitive: false);
final _gorevliAdi = RegExp(
    r',?\s*\b(operatör|operator|sürücü|şoför|formen|sorumlu|personel)\s*:\s*[^,;()]*',
    caseSensitive: false);
final _isciParantez = RegExp(r"\s*\([^()]*\bişçi[^()]*\)", caseSensitive: false);
final _pivotAdi = RegExp(r'\.?\s*[–-]\s*(\d+)\s*\.\s*pivot\s*[–-]\s*[^.;–()]+',
    caseSensitive: false);
final _pivotYazim = RegExp(r'(\d+)\s*\.\s*(pivot|parsel)', caseSensitive: false);
// Yalnızca ad-soyad içeren parantez: "(Ali Veli)", "(Ali Veli, Can Tan)"
final _adParantez = RegExp(
    r'\s*\((?:\s*[A-ZÇĞİÖŞÜ][a-zçğıöşü]+(?:\s+[A-ZÇĞİÖŞÜ][a-zçğıöşü]+)+\s*,?)+\s*\)');
final _bosParantez = RegExp(r'\(\s*[,;]?\s*\)');

/// Tek bir faaliyet metnini sadeleştirir: iç notları ve kişi adlarını çıkarır,
/// yazımı düzeltir. Dönen metin noktalı virgülle ayrılmış maddeler içerebilir.
String kurumsalFaaliyet(String ham) {
  var s = ham.replaceAll(_formenOnEki, '');
  s = s.replaceAllMapped(_pivotAdi, (m) => ' (${m[1]}. pivot)');
  s = s.replaceAll(_gorevliAdi, '');
  s = s.replaceAll(_isciParantez, '');
  s = s.replaceAll(_adParantez, '');
  s = s.replaceAllMapped(_pivotYazim, (m) => '${m[1]}. ${m[2]!.toLowerCase()}');
  s = s.replaceAll(RegExp(r'\(\s*,\s*'), '(').replaceAll(RegExp(r'\s*,\s*\)'), ')');
  s = s.replaceAll(_bosParantez, '');
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  s = s.replaceAllMapped(RegExp(r'\s+([.,;:)])'), (m) => m[1]!);
  // Cümle sonlarını maddeye çevir ("7. pivot" gibi sıra sayılarına dokunma).
  s = s.replaceAll(RegExp(r'(?<!\d)\.\s*[–-]\s*'), '; ');
  s = s.replaceAll(RegExp(r'(?<!\d)\.\s+'), '; ');
  return s.trim().replaceAll(RegExp(r'[.;,\s]+$'), '');
}

/// Metni maddelere böler, her maddeyi büyük harfle başlatır.
List<String> faaliyetMaddeleri(String ham) => [
      for (final p in kurumsalFaaliyet(ham).split(';'))
        if (p.trim().length > 2) _buyukBasla(p.trim())
    ];

/// Kayıtları çiftlik bazında gruplar; tekrar eden maddeleri ayıklar.
/// Çiftlikler alfabetik, maddeler tarih sırasıyla verilir.
List<FaaliyetOzeti> faaliyetOzeti(List<TarimKaydi> kayitlar) {
  final sirali = [...kayitlar]..sort((a, b) => a.tarih.compareTo(b.tarih));
  final m = <String, List<String>>{};
  final gorulen = <String, Set<String>>{};
  for (final k in sirali) {
    final liste = m.putIfAbsent(k.ciftlik, () => []);
    final g = gorulen.putIfAbsent(k.ciftlik, () => {});
    for (final madde in faaliyetMaddeleri(k.faaliyet)) {
      final m = k.kontrolBekliyor ? '$madde (kontrol bekliyor)' : madde;
      if (g.add(_anahtar(m))) liste.add(m);
    }
  }
  final ciftlikler = m.keys.toList()..sort();
  return [
    for (final c in ciftlikler)
      if (m[c]!.isNotEmpty) FaaliyetOzeti(c, m[c]!)
  ];
}

String _buyukBasla(String s) {
  if (s.isEmpty) return s;
  final ilk = s[0];
  final b = ilk == 'i' ? 'İ' : (ilk == 'ı' ? 'I' : ilk.toUpperCase());
  return b + s.substring(1);
}

String _anahtar(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-zçğıöşü0-9]'), '');

// ---------------------------------------------------------------------------
// Yönetici özeti: Genel Müdürlüğe giden raporda yalnızca yapılan işin boyutu.
// Aynı işin hafta içindeki günlük kayıtları toplanır; "başlandı", "makine
// gönderildi", "arıza giderildi" gibi ara bilgiler gösterilmez.

class _Is {
  const _Is(this.etiket, this.desen);
  final String etiket;
  final String desen;
}

// Sıra raporda görünme sırasıdır.
const _isler = [
  _Is('Hasat (biçerdöver)', r'hasat|biçerdöver|biçer\b'),
  _Is('Şeker pancarı sökümü', r'söküm|sökül'),
  _Is('Pancar yükleme ve sevkiyat', r'yükleme|sevkiyat'),
  _Is('Biçim', r'biçim|biçil'),
  _Is('Balya yapımı', r'balya'),
  _Is('Tarla sürümü', r'sürüm|sürül'),
  _Is('Patlatan çekimi', r'patlatan|dipkazan'),
  _Is('Kombine (kürüm) çekimi', r'kombine|kombi\b'),
  _Is('Merdane çekimi', r'merdane'),
  _Is('Kobra çekimi', r'kobra'),
  _Is('Alabora çekimi', r'alabora'),
  _Is('Tırmık çekimi', r'tırmık'),
  _Is('Toprak tesviyesi', r'tesviye'),
  _Is('Sulama borularının toplanması', r'(boru|hat|damlama)\w*\s+(\w+\s+)?(toplan|çıkar)'),
  _Is('Yağmurlama sistemi serimi', r'yağmurlama|boru serme|seril'),
  _Is('Sulama', r'sulama|sulan'),
  _Is('Gübreleme', r'gübreleme|gübre atı|gübre dağıt'),
  _Is('İlaçlama', r'ilaçlama'),
];
// Ürüne göre ayrıştırılan işler: "Sulama (arpa)", "Biçim (yonca)".
const _urunluIsler = {'Hasat (biçerdöver)', 'Biçim', 'Balya yapımı', 'Sulama'};
const _urunler = [
  'buğday', 'arpa', 'yonca', 'mısır', 'ayçiçeği', 'tritikale', 'çavdar',
  'fiğ', 'yulaf', 'nohut', 'fasulye', 'patates', 'silajlık',
];
const _teslimUrunleri = [
  'şeker pancarı', 'pancar', 'yonca', 'buğday', 'arpa', 'patates', 'mısır', 'silaj', 'tritikale', 'saman', 'sap',
];
final _ekim = RegExp(r'(^|[^a-zçğıöşü])ek(im|il|iyor|me)');
// "30 dekar", "30 dekarın", "30 da" — "dekara 25 kg" (dekar başına) alan değildir.
final _dekar = RegExp(r'(\d[\d.,]*)\s*(?:dekar(?!a(?![a-zçğıöşü]))|da(?![a-zçğıöşü]))');
final _tamam = RegExp(r'bitti|bitmiş|tamamland|tamamlan');
final _basla = RegExp(r'başla');
// Form kaydı: "Malzeme girişi: 15 ton Halis buğday tohumu (dış tedarik)"
final _malzeme = RegExp(r'^Malzeme (girişi|çıkışı): ([\d.,]+) (\S+) (.+?) \((.+)\)$');
// Gelen malzeme: "15 ton Halis buğday tohumu teslim alındı", "21250 kg amonyum sülfat geldi"
final _tedarik = RegExp(r'\b(ton|kg)\b.*(teslim al|tedarik|alındı|alınmış|geldi|gelmiş)');
// Giden ürün: "39900 kg yonca alıcıya teslim edildi", "10 ton … mağazasına teslim edildi"
final _sevk = RegExp(r'(\d[\d.,]*)\s*(kg|ton)\b[^;]*?(teslim edil|sevk edil|satıl|verildi|gönderil)');

String _kucuk(String s) =>
    s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

double _sayi(String s) =>
    double.tryParse(s.replaceAll('.', '').replaceAll(',', '.')) ?? 0;

String _dk(double d) {
  final t = d.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < t.length; i++) {
    if (i > 0 && (t.length - i) % 3 == 0) b.write('.');
    b.write(t[i]);
  }
  return '$b dekar';
}

class _Toplam {
  double toplam = 0;
  double? kumulatif; // "toplam X dekar" ifadesi: hafta sonu durumu
  bool tamam = false;
  bool basladi = false;
  final baslangic = <double>{}; // "… dekara başlandı" — aynı alan "bitti" ile tekrar sayılmaz
  double get deger =>
      kumulatif != null && kumulatif! > toplam ? kumulatif! : toplam;

  /// Alan yazılmamış işler için durum.
  String get durum => tamam ? 'tamamlandı' : (basladi ? 'başlandı' : 'devam ediyor');
}

class _Toplanan {
  final ciftlikler = <String, Map<String, _Toplam>>{};
  final malzemeler = <String, Map<String, double>>{};
  final tedarikler = <String, List<String>>{};
  final sevkler = <String, Map<String, double>>{}; // çiftlik → "Yonca teslimatı" → kg
}

String? _urunBul(String s, List<String> l) {
  for (final u in l) {
    if (s.contains(u)) return u;
  }
  return null;
}

/// Kayıtları çiftlik ve iş türü bazında toplar (tek kaynak için).
/// Metin cümleciklere bölünür; her cümlecikteki alan o cümleciğin işine yazılır
/// ("serilen alan 100 dekar, bağlanan alan 60 dekar ve 30 dekarın sulaması yapıldı"
/// → serim 100, sulama 30). "Kalan" ve "bağlanan" alanlar sayılmaz.
_Toplanan _topla(List<TarimKaydi> kayitlar) {
  final t = _Toplanan();
  final sirali = [...kayitlar]..sort((a, b) => a.tarih.compareTo(b.tarih));
  final gorulen = <String, Set<String>>{};

  for (final k in sirali) {
    final m = t.ciftlikler.putIfAbsent(k.ciftlik, () => {});
    final kayitUrunleri = {for (final u in _urunler) if (_kucuk(k.faaliyet).contains(u)) u};
    for (final madde in faaliyetMaddeleri(k.faaliyet)) {
      var s = _kucuk(madde);
      if (s.startsWith('belge no')) continue;
      s = s
          .replaceAll(RegExp(r'\(\s*kalan[^)]*\)'), '')
          .replaceAll(RegExp(r'kalan(\s+\S+){0,2}?\s*:?\s*\d[\d.,]*\s*(dekar|da)(?![a-zçğıöşü])'), '')
          .trim();
      if (s.isEmpty || s.startsWith('kalan')) continue;
      final mz = _malzeme.firstMatch(madde);
      if (mz != null) {
        final anahtar = '${mz[1]}|${mz[3]}|${mz[4]}|${mz[5]}';
        final mm = t.malzemeler.putIfAbsent(k.ciftlik, () => {});
        mm[anahtar] = (mm[anahtar] ?? 0) + _sayi(mz[2]!);
        continue;
      }
      final sv = _sevk.firstMatch(s);
      if (sv != null && !s.contains('teslim al')) {
        final u = _urunBul(s, _teslimUrunleri);
        final etiket = s.contains('tohum')
            ? 'Tohum teslimatı${u == null ? '' : ' (${u == 'pancar' ? 'şeker pancarı' : u})'}'
            : '${_buyuk(u == null ? 'ürün' : (u == 'pancar' ? 'şeker pancarı' : u))} teslimatı';
        final kg = _sayi(sv[1]!) * (sv[2] == 'ton' ? 1000 : 1);
        final sm = t.sevkler.putIfAbsent(k.ciftlik, () => {});
        sm[etiket] = (sm[etiket] ?? 0) + kg;
        continue;
      }
      if (_tedarik.hasMatch(s)) {
        final g = gorulen.putIfAbsent(k.ciftlik, () => {});
        if (g.add(_anahtar(madde))) {
          t.tedarikler.putIfAbsent(k.ciftlik, () => []).add(
              madde.replaceAll(RegExp(r'\s*\(kantar fişleri?\)', caseSensitive: false), ''));
        }
        continue;
      }

      String? onceki;
      for (final c in s.split(RegExp(r',(?!\d)|(?<!\d)\.(?=[a-zçğıöşü])'))) {
        final cc = c.trim();
        if (cc.isEmpty) continue;
        final tamam = _tamam.hasMatch(cc);
        final basla = _basla.hasMatch(cc);
        final kumulatif = cc.contains('toplam');
        final alanlar = [
          for (final e in _dekar.allMatches(cc))
            if (!RegExp(r'(bağlanan|kalan)\s*(alan)?\s*:?\s*$').hasMatch(cc.substring(0, e.start))) _sayi(e[1]!)
        ];

        // Hangi iş?
        String? etiket;
        for (final i in _isler) {
          if (RegExp(i.desen).hasMatch(cc)) {
            etiket = i.etiket;
            break;
          }
        }
        if (etiket == null && _ekim.hasMatch(cc)) {
          // Ürün–miktar eşleşmesi: "669 dekar arpa ve 150 dekar buğday"
          final ciftler = RegExp(
                  r'(\d[\d.]*)\s*dekar\b\s+(?:[a-zçğıöşü]+\s+){0,2}?(' +
                      _urunler.join('|') + r')')
              .allMatches(cc)
              .toList();
          if (ciftler.isNotEmpty) {
            for (final e in ciftler) {
              _ekle(m, '${_buyuk(e[2]!)} ekimi', _sayi(e[1]!), kumulatif, tamam, basla);
            }
            onceki = null;
            continue;
          }
          final urun = _urunBul(cc, _urunler) ?? _urunBul(s, _urunler) ??
              (kayitUrunleri.length == 1 ? kayitUrunleri.first : null);
          etiket = urun == null ? 'Ekim' : '${_buyuk(urun)} ekimi';
        }
        if (etiket == null) {
          // "serilen alan 100 dekar", "toplam 700 dekar": bir önceki cümleciğin işi.
          if (onceki != null && alanlar.isNotEmpty) {
            _ekle(m, onceki, alanlar.fold<double>(0, (a, b) => a + b), kumulatif, tamam, basla);
          } else if (onceki != null && tamam) {
            m[onceki]?.tamam = true;
          }
          continue;
        }
        if (_urunluIsler.contains(etiket)) {
          final u = _urunBul(cc, _urunler) ?? _urunBul(s, _urunler) ??
              (kayitUrunleri.length == 1 ? kayitUrunleri.first : null);
          if (u != null) etiket = '$etiket ($u)';
        }
        onceki = etiket;
        _ekle(m, etiket, alanlar.fold<double>(0, (a, b) => a + b), kumulatif, tamam, basla);
      }
    }
  }

  return t;
}

/// İcmal ile formen formunun karşılaştırma sonucu (bir çiftlik, bir iş türü).
class TeyitSatiri {
  const TeyitSatiri(this.ciftlik, this.is_, this.icmal, this.form, this.durum);
  final String ciftlik;
  final String is_;
  final double? icmal;
  final double? form;
  final String durum; // Teyitli, Fark var, İcmalde yok, Formda yok

  String get icmalMetin => icmal == null ? '–' : _dk(icmal!);
  String get formMetin => form == null ? '–' : _dk(form!);
}

const teyitTolerans = 0.05; // %5'e kadar fark teyitli sayılır

/// Formen bildirimi olan çiftliklerde iş türü bazında haftalık karşılaştırma.
List<TeyitSatiri> teyitDurumu(List<TarimKaydi> tumKayitlar) {
  // Kontrol bekleyen formen kayıtları rapora girmez.
  final kayitlar = [for (final k in tumKayitlar) if (!k.kontrolBekliyor) k];
  final ic = _topla([for (final k in kayitlar) if (!k.formdan) k]);
  final fo = _topla([for (final k in kayitlar) if (k.formdan) k]);
  final sonuc = <TeyitSatiri>[];
  final ciftlikler = fo.ciftlikler.keys.toList()..sort();
  for (final c in ciftlikler) {
    final a = ic.ciftlikler[c] ?? {};
    final b = fo.ciftlikler[c] ?? {};
    final etiketler = {...a.keys, ...b.keys}.toList()
      ..sort((x, y) {
        final f = _sira(x).compareTo(_sira(y));
        return f != 0 ? f : x.compareTo(y);
      });
    for (final e in etiketler) {
      final i = (a[e]?.deger ?? 0) > 0 ? a[e]!.deger : null;
      final f = (b[e]?.deger ?? 0) > 0 ? b[e]!.deger : null;
      if (i == null && f == null) continue;
      final String durum;
      if (i != null && f != null) {
        final fark = (i - f).abs();
        durum = fark <= 1 || fark <= teyitTolerans * (i > f ? i : f)
            ? 'Teyitli'
            : 'Fark var';
      } else {
        durum = i == null ? 'İcmalde yok' : 'Formda yok';
      }
      sonuc.add(TeyitSatiri(c, e, i, f, durum));
    }
  }
  return sonuc;
}

/// Genel Müdürlük raporu için çiftlik bazında kısa özet.
/// İcmal ve formen formu karşılaştırılır: ikisi de varsa icmal esas alınır,
/// yalnızca formda olan iş de rapora girer (uygulamada "icmalde yok" işaretli).
/// [teslimatlar]: dönemdeki ürün teslimat satırları (örn. TarKop pancar sevkiyatı),
/// çiftlik bazında "Şeker pancarı teslimatı (Konya Şeker): … ton net" olarak eklenir.
List<FaaliyetOzeti> yoneticiOzeti(List<TarimKaydi> tumKayitlar,
    {List<DonemTeslimati> teslimatlar = const []}) {
  // Kontrol bekleyen formen kayıtları rapora girmez.
  final kayitlar = [for (final k in tumKayitlar) if (!k.kontrolBekliyor) k];
  final ic = _topla([for (final k in kayitlar) if (!k.formdan) k]);
  final fo = _topla([for (final k in kayitlar) if (k.formdan) k]);

  final sonuc = <FaaliyetOzeti>[];
  final adlar = {
    ...ic.ciftlikler.keys, ...ic.tedarikler.keys, ...ic.malzemeler.keys,
    ...fo.ciftlikler.keys, ...fo.tedarikler.keys, ...fo.malzemeler.keys,
    ...ic.sevkler.keys, ...fo.sevkler.keys, for (final t in teslimatlar) t.ciftlik,
  }.toList()
    ..sort();
  for (final c in adlar) {
    final a = ic.ciftlikler[c] ?? {};
    final b = fo.ciftlikler[c] ?? {};
    final etiketler = {...a.keys, ...b.keys}.toList()
      ..sort((x, y) {
        final f = _sira(x).compareTo(_sira(y));
        return f != 0 ? f : x.compareTo(y);
      });
    final formMalzeme = fo.malzemeler[c] ?? const <String, double>{};
    final icMalzeme = ic.malzemeler[c] ?? const <String, double>{};
    final maddeler = <String>[
      for (final e in etiketler)
        if ((a[e]?.deger ?? 0) > 0 || (b[e]?.deger ?? 0) > 0)
          '$e: ${_dk((a[e]?.deger ?? 0) > 0 ? a[e]!.deger : b[e]!.deger)}'
              '${(a[e]?.tamam ?? false) || (b[e]?.tamam ?? false) ? ' (tamamlandı)' : ''}'
        else
          // Alan yazılmamış iş: durumuyla (başlandı / devam ediyor / tamamlandı).
          '$e: ${(a[e]?.tamam ?? false) || (b[e]?.tamam ?? false) ? 'tamamlandı' : (a[e] ?? b[e])!.durum}',
      for (final e in {...?ic.sevkler[c], ...?fo.sevkler[c]}.entries) '${e.key}: ${_kg(e.value)}',
      for (final t in teslimatlar)
        if (t.ciftlik == c) t.metin,
      // Formda malzeme hareketi varsa icmaldeki serbest tedarik notu tekrar yazılmaz.
      if (formMalzeme.isEmpty)
        for (final t in ic.tedarikler[c] ?? const <String>[]) t,
      for (final t in fo.tedarikler[c] ?? const <String>[]) t,
      for (final e in {...icMalzeme, ...formMalzeme}.entries)
        _malzemeSatiri(e.key, e.value),
    ];
    if (maddeler.isNotEmpty) sonuc.add(FaaliyetOzeti(c, maddeler));
  }
  return sonuc;
}

void _ekle(Map<String, _Toplam> m, String etiket, double miktar,
    bool kumulatif, bool tamam, [bool basla = false]) {
  final t = m.putIfAbsent(etiket, () => _Toplam());
  if (basla) t.basladi = true;
  if (kumulatif && miktar > 0) {
    t.kumulatif = (t.kumulatif ?? 0) < miktar ? miktar : t.kumulatif;
  } else if (miktar > 0) {
    if (basla && !tamam) {
      // "100 dekar ekime başlandı" … "100 dekar ekim bitti": alan bir kez sayılır.
      t.baslangic.add(miktar);
      t.toplam += miktar;
    } else if (tamam && t.baslangic.remove(miktar)) {
      // aynı alan zaten sayıldı
    } else {
      t.toplam += miktar;
    }
  }
  if (tamam) t.tamam = true;
}

int _sira(String etiket) {
  final i = _isler.indexWhere((e) => e.etiket == etiket || etiket.startsWith('${e.etiket} ('));
  if (i >= 0) return i;
  return etiket.endsWith(' ekimi') || etiket == 'Ekim' ? -1 : 99;
}

String _buyuk(String s) => _buyukBasla(s);

String _malzemeSatiri(String anahtar, double miktar) {
  final p = anahtar.split('|');
  final m = miktar == miktar.roundToDouble()
      ? _binlik(miktar.round())
      : miktar.toStringAsFixed(2).replaceAll('.', ',');
  return 'Malzeme ${p[0]}: $m ${p[1]} ${p[2]} (${p[3]})';
}

String _binlik(int n) {
  final t = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < t.length; i++) {
    if (i > 0 && (t.length - i) % 3 == 0) b.write('.');
    b.write(t[i]);
  }
  return b.toString();
}

/// Kontrol bekleyen formen kaydı sayısı.
int kontrolBekleyen(List<TarimKaydi> kayitlar) =>
    kayitlar.where((k) => k.kontrolBekliyor).length;


String _kg(double kg) {
  if (kg < 100000) return '${_binlik(kg.round())} kg';
  final t = (kg / 100).round(); // 0,1 ton hassasiyet
  return '${_binlik(t ~/ 10)},${t % 10} ton';
}

/// Bir ürünün dönem içindeki teslimat toplamı (Ürün Takibi kayıtlarından).
class DonemTeslimati {
  const DonemTeslimati({required this.ciftlik, required this.urun, this.alici = '',
      required this.net, this.teslim = 0, this.sefer = 0});
  final String ciftlik, urun, alici;
  final double net, teslim;
  final int sefer;

  String get metin {
    final kesinti = teslim > net ? (teslim - net) / teslim * 100 : 0;
    final u = urun.isEmpty ? urun : '${urun[0]}${_kucuk(urun.substring(1))}';
    return '$u teslimatı${alici.isEmpty ? '' : ' ($alici)'}: ${_kg(net)} net'
        '${sefer > 0 ? ', $sefer sefer' : ''}'
        '${kesinti > 0 ? ', fire %${kesinti.toStringAsFixed(1).replaceAll('.', ',')}' : ''}';
  }
}
