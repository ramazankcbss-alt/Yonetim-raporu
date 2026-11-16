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
final _bosParantez = RegExp(r'\(\s*[,;]?\s*\)');

/// Tek bir faaliyet metnini sadeleştirir: iç notları ve kişi adlarını çıkarır,
/// yazımı düzeltir. Dönen metin noktalı virgülle ayrılmış maddeler içerebilir.
String kurumsalFaaliyet(String ham) {
  var s = ham.replaceAll(_formenOnEki, '');
  s = s.replaceAllMapped(_pivotAdi, (m) => ' (${m[1]}. pivot)');
  s = s.replaceAll(_gorevliAdi, '');
  s = s.replaceAll(_isciParantez, '');
  s = s.replaceAllMapped(_pivotYazim, (m) => '${m[1]}. ${m[2]!.toLowerCase()}');
  s = s.replaceAll(RegExp(r'\(\s*,\s*'), '(').replaceAll(RegExp(r'\s*,\s*\)'), ')');
  s = s.replaceAll(_bosParantez, '');
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  s = s.replaceAll(RegExp(r'\s+([.,;:)])'), r'$1');
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
