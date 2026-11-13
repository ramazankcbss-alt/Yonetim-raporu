import 'model.dart';

/// Geçmiş Yıllar kayıtlarının toplandığı ana birimler.
enum Birim { ziraat, hayvancilik, mali, isletme, diger }

const birimAdlari = {
  Birim.ziraat: 'Ziraat',
  Birim.hayvancilik: 'Hayvancılık',
  Birim.mali: 'Mali',
  Birim.isletme: 'İşletme',
  Birim.diger: 'Diğer',
};

/// Türkçe harfleri bozmadan küçük harfe çevirir (İ→i, I→ı).
String kucuk(String s) => s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

const _hayvanKelime = [
  'hayvan', 'besi', 'besleme', 'buzağı', 'kesim', 'süt', 'doğum', 'sağmal', 'sağım',
  'inek', 'düve', 'dana', 'tosun', 'yem', 'rasyon', 'aşılama', 'ölüm', 'ölen',
  'gebelik', 'tohumlama', 'sürü', 'kuzu', 'koyun', 'mastit', 'karkas', 'canlı ağırlık',
];
const _ziraatKelime = [
  'pancar', 'ekim', 'hasat', 'arazi', 'tarla', 'gübre', 'sulama', 'tohum', 'toprak',
  'silaj', 'mısır', 'buğday', 'arpa', 'yonca', 'fidan', 'fide', 'zirai', 'ziraat', 'tarım',
  'bitki', 'mahsul', 'ürün', 'dekar', 'ilaçlama', 'çapa', 'balya', 'saman', 'nadas', 'kök/da',
];
const _maliKelime = [
  'fiyat', 'alım', 'satış', 'maliyet', 'kâr', 'kar/zarar', 'zarar', 'gelir', 'gider',
  'hizmet', 'ödeme', 'bütçe', 'finans', 'muhasebe', 'tahsilat', 'fatura', 'borç',
  'alacak', 'ciro', 'nakit', 'kira',
];
const _isletmeKelime = [
  'bakım', 'onarım', 'kapasite', 'makine', 'ekipman', 'enerji', 'elektrik', 'akaryakıt',
  'mazot', 'personel', 'işçi', 'genel durum', 'karar', 'bina', 'tesis', 'araç', 'güvenlik',
];

bool _icerir(String metin, List<String> kelimeler) => kelimeler.any(metin.contains);

/// Bir metnin (konu, gösterge…) hangi birime ait olduğunu kelimelerden bulur.
Birim metinBirimi(String metin) {
  final m = kucuk(metin);
  if (m.trim().isEmpty) return Birim.diger;
  if (_icerir(m, _hayvanKelime)) return Birim.hayvancilik;
  if (_icerir(m, _ziraatKelime)) return Birim.ziraat;
  if (_icerir(m, _maliKelime)) return Birim.mali;
  if (_icerir(m, _isletmeKelime)) return Birim.isletme;
  return Birim.diger;
}

/// Çiftlik adı birimi açıkça söylüyorsa onu döndürür ("Aslım hayvancılık",
/// "Aslım (numune 1)", "Konsolide (muhasebe)"…), söylemiyorsa null.
Birim? alanBirimi(String alan) {
  final a = kucuk(alan);
  if (a.contains('hayvancılık') || a.contains('besi') || a.contains('süt') || a.startsWith('esk')) {
    return Birim.hayvancilik;
  }
  if (a.contains('tarım') || a.contains('ziraat') || a.contains('numune') ||
      a.contains('fidanlık') || a.contains('deneme')) {
    return Birim.ziraat;
  }
  if (a.contains('muhasebe') || a.contains('konsolide')) return Birim.mali;
  return null;
}

/// Kaydın birimi: önce çiftlik adı, sonra konu, en son gösterge adı.
Birim gecmisBirimi(GecmisVeri x) {
  final a = alanBirimi(x.alan);
  if (a != null) return a;
  final k = metinBirimi(x.konu);
  if (k != Birim.diger) return k;
  return metinBirimi(x.gosterge);
}

/// Konu listesinde başlık altında toplamak için konunun birimi.
Birim konuBirimi(String konu) => metinBirimi(konu);

/// Çiftlik adının ana işletme kökü: "Aslım (numune 1)" → "Aslım",
/// "Aslım hayvancılık" → "Aslım", "Pankent (Gevrekli)" → "Pankent".
String alanKoku(String alan) {
  var s = alan.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
  s = s.replaceAll(RegExp(r'\s+(hayvancılık|hayvancilik|tarım|tarim|ziraat|besi)$', caseSensitive: false), '').trim();
  return s.isEmpty ? alan : s;
}
