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
      if (g.add(_anahtar(madde))) liste.add(madde);
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
  _Is('Hasat (kombine)', r'kombine|hasat|biçer'),
  _Is('Şeker pancarı sökümü', r'söküm|sökül'),
  _Is('Tarla sürümü', r'sürüm|sürül'),
  _Is('Merdane çekimi', r'merdane'),
  _Is('Tırmık çekimi', r'tırmık'),
  _Is('Toprak tesviyesi', r'tesviye'),
  _Is('Yağmurlama sistemi serimi', r'yağmurlama'),
  _Is('Gübreleme', r'gübreleme|gübre atı'),
  _Is('İlaçlama', r'ilaçlama'),
];
const _urunler = [
  'buğday', 'arpa', 'yonca', 'mısır', 'ayçiçeği', 'tritikale', 'çavdar',
  'fiğ', 'yulaf', 'nohut', 'fasulye', 'patates', 'silajlık',
];
final _ekim = RegExp(r'(^|[^a-zçğıöşü])ek(im|il|iyor|me)');
final _dekar = RegExp(r'(\d[\d.,]*)\s*dekar\b');
final _tamam = RegExp(r'bitti|tamamland');
// Form kaydı: "Malzeme girişi: 15 ton Halis buğday tohumu (dış tedarik)"
final _malzeme = RegExp(r'^Malzeme (girişi|çıkışı): ([\d.,]+) (\S+) (.+?) \((.+)\)$');
final _tedarik = RegExp(r'\bton\b.*(teslim|tedarik|alındı|geldi)');

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
  double get deger =>
      kumulatif != null && kumulatif! > toplam ? kumulatif! : toplam;
}

/// Genel Müdürlük raporu için çiftlik bazında kısa özet.
List<FaaliyetOzeti> yoneticiOzeti(List<TarimKaydi> kayitlar) {
  // Aynı çiftlik ve gün için formen formu varsa icmal kaydı ikinci kez sayılmaz.
  final formGunleri = {
    for (final k in kayitlar)
      if (k.formdan) '${k.ciftlik}|${k.tarih.year}-${k.tarih.month}-${k.tarih.day}'
  };
  final sirali = [
    for (final k in kayitlar)
      if (k.formdan ||
          !formGunleri.contains(
              '${k.ciftlik}|${k.tarih.year}-${k.tarih.month}-${k.tarih.day}'))
        k
  ]..sort((a, b) => a.tarih.compareTo(b.tarih));
  final ciftlikler = <String, Map<String, _Toplam>>{};
  final malzemeler = <String, Map<String, double>>{};
  final tedarikler = <String, List<String>>{};
  final gorulen = <String, Set<String>>{};

  for (final k in sirali) {
    final m = ciftlikler.putIfAbsent(k.ciftlik, () => {});
    for (final madde in faaliyetMaddeleri(k.faaliyet)) {
      final s = _kucuk(madde);
      if (s.contains('kalan') || s.startsWith('belge no')) continue;
      final mz = _malzeme.firstMatch(madde);
      if (mz != null) {
        final anahtar = '${mz[1]}|${mz[3]}|${mz[4]}|${mz[5]}';
        final mm = malzemeler.putIfAbsent(k.ciftlik, () => {});
        mm[anahtar] = (mm[anahtar] ?? 0) + _sayi(mz[2]!);
        continue;
      }
      if (_tedarik.hasMatch(s)) {
        final g = gorulen.putIfAbsent(k.ciftlik, () => {});
        if (g.add(_anahtar(madde))) {
          tedarikler.putIfAbsent(k.ciftlik, () => []).add(
              madde.replaceAll(RegExp(r'\s*\(kantar fişleri?\)', caseSensitive: false), ''));
        }
        continue;
      }
      final tamam = _tamam.hasMatch(s);
      final kumulatif = s.contains('toplam');

      // Hangi iş?
      String? etiket;
      for (final i in _isler) {
        if (RegExp(i.desen).hasMatch(s)) {
          etiket = i.etiket;
          break;
        }
      }
      if (etiket == null && _ekim.hasMatch(s)) {
        // Ürün–miktar eşleşmesi: "669 dekar arpa ve 150 dekar buğday"
        final ciftler = RegExp(
                r'(\d[\d.]*)\s*dekar\b\s+(?:[a-zçğıöşü]+\s+){0,2}?(' +
                    _urunler.join('|') + r')')
            .allMatches(s)
            .toList();
        if (ciftler.isNotEmpty) {
          for (final c in ciftler) {
            _ekle(m, '${_buyuk(c[2]!)} ekimi', _sayi(c[1]!), kumulatif, tamam);
          }
          continue;
        }
        final urun = _urunler.firstWhere(s.contains, orElse: () => '');
        etiket = urun.isEmpty ? 'Ekim' : '${_buyuk(urun)} ekimi';
      }
      if (etiket == null) continue;
      final miktar =
          _dekar.allMatches(s).fold<double>(0, (t, e) => t + _sayi(e[1]!));
      _ekle(m, etiket, miktar, kumulatif, tamam);
    }
  }

  final sonuc = <FaaliyetOzeti>[];
  final adlar = {...ciftlikler.keys, ...tedarikler.keys, ...malzemeler.keys}
      .toList()
    ..sort();
  for (final c in adlar) {
    final m = ciftlikler[c] ?? {};
    final etiketler = m.keys.toList()
      ..sort((a, b) {
        final f = _sira(a).compareTo(_sira(b));
        return f != 0 ? f : a.compareTo(b);
      });
    final maddeler = <String>[
      for (final e in etiketler)
        if (m[e]!.deger > 0)
          '$e: ${_dk(m[e]!.deger)}${m[e]!.tamam ? ' (tamamlandı)' : ''}',
      for (final t in tedarikler[c] ?? const <String>[]) t,
      for (final e in (malzemeler[c] ?? const <String, double>{}).entries)
        _malzemeSatiri(e.key, e.value),
    ];
    if (maddeler.isNotEmpty) sonuc.add(FaaliyetOzeti(c, maddeler));
  }
  return sonuc;
}

void _ekle(Map<String, _Toplam> m, String etiket, double miktar,
    bool kumulatif, bool tamam) {
  final t = m.putIfAbsent(etiket, () => _Toplam());
  if (kumulatif && miktar > 0) {
    t.kumulatif = (t.kumulatif ?? 0) < miktar ? miktar : t.kumulatif;
  } else {
    t.toplam += miktar;
  }
  if (tamam) t.tamam = true;
}

int _sira(String etiket) {
  if (etiket.endsWith('ekimi') || etiket == 'Ekim') return -1;
  final i = _isler.indexWhere((e) => e.etiket == etiket);
  return i < 0 ? 99 : i;
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
