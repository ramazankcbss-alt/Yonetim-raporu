import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../veri/model.dart';
import '../veri/dosyalar.dart';
import 'web_kopru.dart';
import '../veri/ozel.dart';

/// Rapor PDF'inde görünen bilgiler (Ayarlar ekranından).
class RaporAyari {
  const RaporAyari({
    this.baslik = 'Çiftlikler Yönetim Raporu',
    this.hazirlayan = '',
    this.unvan = '',
    this.alici = '',
  });

  final String baslik;
  final String hazirlayan;
  final String unvan;

  /// Örn. "Sayın Genel Müdürüm" — PDF'in başında hitap olarak yazılır.
  final String alici;
}

class VeriHatasi implements Exception {
  VeriHatasi(this.mesaj);
  final String mesaj;
  @override
  String toString() => mesaj;
}

/// Bağlantı linki biçim kontrolü: Apps Script web uygulaması + anahtar.
String? linkKontrol(String link) {
  final s = link.trim();
  if (s.isEmpty) return 'Bağlantı linkini yapıştırın.';
  final u = Uri.tryParse(s);
  if (u == null || u.scheme != 'https' || u.host != 'script.google.com') {
    return 'Link "https://script.google.com/..." ile başlamalı.';
  }
  if (!u.path.endsWith('/exec')) {
    return 'Link "…/exec?anahtar=…" biçiminde olmalı. Kurulum e-postasındaki linkin tamamını kopyalayın.';
  }
  if ((u.queryParameters['anahtar'] ?? '').length < 16) {
    return 'Linkte anahtar eksik. Kurulum e-postasındaki linkin tamamını kopyalayın.';
  }
  return null;
}

/// Uygulamanın tek veri kaynağı: rapor verisini çeker, saklar, dağıtır.
class VeriDeposu extends ChangeNotifier {
  VeriDeposu._();
  static final VeriDeposu ben = VeriDeposu._();

  static const _kLink = 'baglanti_linki';
  static const _kOnbellek = 'veri_onbellek';
  static const _kOnbellekZaman = 'veri_onbellek_zaman';
  static const _kBaslik = 'rapor_baslik';
  static const _kHazirlayan = 'rapor_hazirlayan';
  static const _kUnvan = 'rapor_unvan';
  static const _kAlici = 'rapor_alici';

  String? link;
  RaporVerisi? veri;

  /// Haritadan yapılan, sunucudan henüz geri gelmemiş parsel girişleri (anında görünsün diye).
  final List<(DateTime, SezonParsel)> _yerelParsel = [];

  /// Yenileme sürerken gelen ikinci istek: bitince bir kez daha çekilir.
  bool _tekrarYenile = false;

  /// Sezon parsel girişleri: sunucudaki kayıtlar + henüz yansımamış yerel girişler (son giriş geçerlidir).
  final List<(DateTime, ParselSinir)> _yerelSinir = [];

  /// Parsel sınırları: sunucudakiler ve bu oturumda kaydedilip henüz gelmeyenler.
  List<ParselSinir> parselSinirleri(RaporVerisi v) =>
      _yerelSinir.isEmpty ? v.parselSinir : [...v.parselSinir, for (final e in _yerelSinir) e.$2];

  List<SezonParsel> sezonParselleri(RaporVerisi v) =>
      _yerelParsel.isEmpty ? v.sezonParsel : [...v.sezonParsel, for (final e in _yerelParsel) e.$2];
  DateTime? sonAlinma;
  bool yukleniyor = false;
  String? hata;
  RaporAyari ayar = const RaporAyari();

  /// Testlerde ağ yerine kullanılır.
  @visibleForTesting
  Future<String> Function(Uri adres)? sahteIstek;

  /// Testlerde POST yerine kullanılır.
  @visibleForTesting
  Future<String> Function(Uri adres, String govde)? sahteGonder;

  Future<void> baslat() async {
    final p = await SharedPreferences.getInstance();
    link = p.getString(_kLink);
    ayar = RaporAyari(
      baslik: p.getString(_kBaslik) ?? const RaporAyari().baslik,
      hazirlayan: p.getString(_kHazirlayan) ?? '',
      unvan: p.getString(_kUnvan) ?? '',
      alici: p.getString(_kAlici) ?? '',
    );
    final ham = p.getString(_kOnbellek);
    if (ham != null) {
      try {
        final j = jsonDecode(ham) as Map<String, dynamic>;
        veri = RaporVerisi.json(j);
        UygulamaDosyalari.guncelle(j['dosyalar']);
        final z = p.getInt(_kOnbellekZaman);
        sonAlinma = z == null ? null : DateTime.fromMillisecondsSinceEpoch(z);
      } catch (_) {
        veri = null;
      }
    }
    notifyListeners();
  }

  /// Web sürümü (şirket paneli içinde): veri ve işlemler panelin köprüsüyle (google.script.run) yapılır.
  /// KVKK: web sürümünde veri tarayıcıda saklanmaz; her açılışta sunucudan yüklenir.
  bool kopru = false;

  void webKopruKur() {
    kopru = true;
    link = 'kopru://panel?anahtar=pkopru-sirket-paneli';
    veri = null;
    UygulamaDosyalari.temizle();
    notifyListeners();
  }

  Future<void> ayarKaydet(RaporAyari a) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kBaslik, a.baslik);
    await p.setString(_kHazirlayan, a.hazirlayan);
    await p.setString(_kUnvan, a.unvan);
    await p.setString(_kAlici, a.alici);
    ayar = a;
    notifyListeners();
  }

  /// Linki dener; çalışırsa kaydeder ve veriyi yükler.
  Future<void> linkKaydet(String yeniLink) async {
    final temiz = yeniLink.trim();
    final h = linkKontrol(temiz);
    if (h != null) throw VeriHatasi(h);
    await _getir(temiz);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLink, temiz);
    link = temiz;
    notifyListeners();
  }

  Future<void> linkSil() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kLink);
    await p.remove(_kOnbellek);
    await p.remove(_kOnbellekZaman);
    link = null;
    veri = null;
    UygulamaDosyalari.temizle();
    sonAlinma = null;
    hata = null;
    notifyListeners();
  }

  /// Güncel veriyi çeker. Hata olursa eldeki (önbellek) veri korunur.
  Future<void> yenile() async {
    final l = link;
    if (l == null) return;
    if (yukleniyor) {
      _tekrarYenile = true;
      return;
    }
    yukleniyor = true;
    hata = null;
    notifyListeners();
    try {
      await _getir(l);
    } catch (e) {
      hata = e is VeriHatasi
          ? e.mesaj
          : e is TimeoutException
              ? 'Bağlantı zaman aşımına uğradı. İnternet bağlantınızı kontrol edin.'
              : 'Veri alınamadı. İnternet bağlantınızı kontrol edin.';
    } finally {
      yukleniyor = false;
      notifyListeners();
    }
    if (_tekrarYenile) {
      _tekrarYenile = false;
      await yenile();
    }
  }

  Future<void> _getir(String l) async {
    final baslangic = DateTime.now();
    final u = Uri.parse(l);
    // Web paneli linki (panel=tarla) uygulamaya yapıştırılırsa veri adresi olarak kullanılır.
    final adres = u.replace(queryParameters: {
      ...Map.of(u.queryParameters)..remove('panel'),
      'gun': '400',
    });
    final govde = kopru
        ? await webKopru('veri', '')
        : sahteIstek != null
            ? await sahteIstek!(adres)
            : await _istek(adres);
    final ham = govde.trimLeft();
    if (ham.startsWith('<')) {
      throw VeriHatasi(
          'Bağlantı Google girişi istiyor. Apps Script\'te dağıtım ayarı '
          '"Erişimi olanlar: Herkes" olmalı (Dağıt → Dağıtımları yönet).');
    }
    final Object? j;
    try {
      j = jsonDecode(ham);
    } catch (_) {
      throw VeriHatasi('Bağlantıdan anlaşılmayan bir cevap geldi.');
    }
    if (j is! Map<String, dynamic>) {
      throw VeriHatasi('Bağlantıdan anlaşılmayan bir cevap geldi.');
    }
    if (j['ok'] != true) {
      // Paylaşım kapatıldıysa önbellekteki harita verisi de silinir.
      if (j['paylasimKapali'] == true) await _paylasimKapandi();
      throw VeriHatasi((j['hata'] ?? 'Veri alınamadı.').toString());
    }
    final v = RaporVerisi.json(j);
    UygulamaDosyalari.guncelle(j['dosyalar']);
    final simdi = DateTime.now();
    if (!kopru) {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kOnbellek, ham);
      await p.setInt(_kOnbellekZaman, simdi.millisecondsSinceEpoch);
    }
    veri = v;
    sonAlinma = simdi;
    hata = null;
    // Bu çekim başlamadan önce kaydedilen yerel girişler artık sunucu verisinde.
    _yerelParsel.removeWhere((e) => e.$1.isBefore(baslangic));
    _yerelSinir.removeWhere((e) => e.$1.isBefore(baslangic));
    _yerelSezonlar = null;
    final kanca = veriGeldi;
    if (kanca != null && v.paylasim == null) unawaited(kanca(v, ham));
  }

  /// Paylaşım linkiyle açılmış uygulamada mı (yalnızca Tarla Haritası).
  Paylasim? get paylasim => veri?.paylasim;

  /// Kayıtlı link bir paylaşım linki mi (paylaşım anahtarları "p" ile başlar; veri gelmeden de bilinir).
  bool get paylasimLinki => paylasim != null || (link?.contains('anahtar=p') ?? false);

  Future<void> _paylasimKapandi() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kOnbellek);
    await p.remove(_kOnbellekZaman);
    veri = null;
    UygulamaDosyalari.temizle();
    sonAlinma = null;
    paylasimKapali = true;
    notifyListeners();
  }

  /// Paylaşım sahibince kapatıldı (önbellek silindi).
  bool paylasimKapali = false;

  /// Tarla Haritası paylaşımı (yalnızca sahibin uygulamasından): ekle, yetki, kapat, aç, sil.
  Future<String> paylasimYonet(String tur,
      {String id = '', String etiket = '', String yetki = 'gor', List<String>? menuler, bool? maliDetay, int? sure}) async {
    final j = await _islem(tur, {
      'id': id, 'etiket': etiket, 'yetki': yetki,
      if (menuler != null) 'menuler': menuler.join(','),
      if (maliDetay != null) 'maliDetay': '$maliDetay',
      if (sure != null) 'sure': '$sure',
    });
    await yenile();
    return (j['mesaj'] ?? 'Kaydedildi.').toString();
  }

  /// Yeni veri alındığında çağrılır (uygulamada haftalık raporu Drive
  /// arşivine kaydetmek için kullanılır; testlerde boş kalır).
  Future<void> Function(RaporVerisi v, String ham)? veriGeldi;

  static Future<String> _istek(Uri adres) async {
    final r = await http.get(adres).timeout(const Duration(seconds: 45));
    if (r.statusCode == 404) {
      throw VeriHatasi(
          'Bağlantı adresi bulunamadı. Apps Script dağıtımı silinmiş olabilir.');
    }
    if (r.statusCode == 401 || r.statusCode == 403) {
      throw VeriHatasi(
          'Bağlantıya izin verilmedi. Apps Script dağıtımında "Erişimi olanlar: Herkes" seçili olmalı.');
    }
    if (r.statusCode != 200) {
      throw VeriHatasi('Sunucu hatası (${r.statusCode}). Biraz sonra tekrar deneyin.');
    }
    return utf8.decode(r.bodyBytes);
  }

  // --- Özel bölümler (Danışmanlık, Toplantı, Özel Notlar, Günlük) ---
  // Diske yazılmaz; her açılışta çekilir.

  /// Son çekilen özel veri (yalnızca bellekte; diske yazılmaz).
  OzelVeri? ozelBellek;

  Future<OzelVeri> ozelGetir() async {
    final l = link;
    if (l == null) throw VeriHatasi('Bağlantı linki yok.');
    final u = Uri.parse(l);
    final adres = u.replace(queryParameters: {
      ...u.queryParameters,
      'bolum': 'ozel',
    });
    final ham =
        (sahteIstek != null ? await sahteIstek!(adres) : await _istek(adres))
            .trimLeft();
    if (ham.startsWith('<')) {
      throw VeriHatasi(
          'Bağlantı Google girişi istiyor. Apps Script dağıtımı "Herkes" olmalı.');
    }
    final Object? j;
    try {
      j = jsonDecode(ham);
    } catch (_) {
      throw VeriHatasi('Bağlantıdan anlaşılmayan bir cevap geldi.');
    }
    if (j is! Map<String, dynamic> || j['ok'] != true) {
      final h = j is Map ? j['hata'] : null;
      throw VeriHatasi((h ?? 'Özel veri alınamadı.').toString());
    }
    final o = OzelVeri.json(j);
    ozelBellek = o;
    return o;
  }

  Future<void> ozelGonder(String tur, Map<String, String> alan) async {
    await _islem(tur, alan);
  }

  /// Danışmanlık sorusunu değiştirir; soru yeniden "Yeni" olur, eski
  /// değerlendirme silinir. [eskiSoru] yanlış satırı değiştirmemek içindir.
  Future<void> danismaDuzenle(int satir, String eskiSoru, String konu, String soru) =>
      _islem('danismanlikDuzenle', {
        'satir': '$satir',
        'eskiSoru': eskiSoru,
        'konu': konu,
        'soru': soru,
      });

  /// Danışmanlık sorusunu tablodan siler.
  Future<void> danismaSil(int satir, String eskiSoru) =>
      _islem('danismanlikSil', {'satir': '$satir', 'eskiSoru': eskiSoru});

  /// Apps Script'e bir işlem gönderir; cevabı (ok: true) döndürür.
  Future<Map<String, dynamic>> _islem(
      String tur, Map<String, String> alan) async {
    final l = link;
    if (l == null) throw VeriHatasi('Bağlantı linki yok.');
    final govde = jsonEncode({'tur': tur, ...alan});
    final u = Uri.parse(l);
    final ham = (kopru
            ? await webKopru(tur, govde)
            : sahteGonder != null
                ? await sahteGonder!(u, govde)
                : await _gonder(u, govde))
        .trimLeft();
    if (ham.startsWith('<')) {
      throw VeriHatasi('Bağlantıdan anlaşılmayan bir cevap geldi. Apps Script '
          'kodunu güncelleyip yeni sürüm olarak dağıttığınızdan emin olun.');
    }
    final Object? j;
    try {
      j = jsonDecode(ham);
    } catch (_) {
      throw VeriHatasi('İşlem sırasında anlaşılmayan bir cevap geldi.');
    }
    if (j is! Map<String, dynamic> || j['ok'] != true) {
      if (j is Map && j['paylasimKapali'] == true) await _paylasimKapandi();
      final h = j is Map ? j['hata'] : null;
      throw VeriHatasi((h ?? 'İşlem yapılamadı.').toString());
    }
    return j;
  }

  /// "Eşitle": kaynak tablolardaki yeni günleri rapora çeker, sonra veriyi
  /// yeniler. Kullanıcıya gösterilecek özet mesajı döndürür.
  bool esitleniyor = false;

  /// Uygulama açılışında: son eşitlemeden 3 saat geçtiyse kaynak tabloları
  /// (canlı hayvan, işletme raporları, tarım) arka planda rapora çeker.
  Future<void> otomatikEsitle() async {
    if (link == null || esitleniyor || sahteGonder != null || paylasim != null) return;
    final p = await SharedPreferences.getInstance();
    final son = p.getInt('son_otomatik_esitle');
    final simdi = DateTime.now().millisecondsSinceEpoch;
    if (son != null && simdi - son < 3 * 3600 * 1000) return;
    await p.setInt('son_otomatik_esitle', simdi);
    try {
      await esitle();
    } catch (_) {
      // Sessiz: kullanıcı isterse Eşitle düğmesiyle tekrar dener.
    }
  }

  Future<String> esitle() async {
    if (esitleniyor) return 'Eşitleme zaten sürüyor.';
    esitleniyor = true;
    notifyListeners();
    try {
      final c = await _islem('esitle', const {});
      final notlar = (c['notlar'] is List)
          ? (c['notlar'] as List).map((e) => e.toString()).toList()
          : const <String>[];
      await yenile();
      final mesaj = (c['mesaj'] ?? 'Eşitlendi.').toString();
      return notlar.isEmpty ? mesaj : '$mesaj\n${notlar.join('\n')}';
    } finally {
      esitleniyor = false;
      notifyListeners();
    }
  }

  /// Veteriner Kontrol Paneli'ni erişime açar ya da kapatır.
  Future<void> vetPanelDurum({required bool acik}) async {
    await _islem('vetPanelDurum', {'acik': acik ? '1' : '0'});
    await yenile();
  }

  /// Veteriner Kontrol Paneli: yeni erişim kodu üretir (etiket: görev/rol).
  Future<String> vetKodEkle(String etiket) async {
    final j = await _islem('vetKodEkle', {'etiket': etiket});
    await yenile();
    return (j['kod'] ?? '').toString();
  }

  /// Kodu kapatır (panel o kodla açılmaz) ya da yeniden açar.
  Future<void> vetKodDurum(String kod, {required bool acik}) async {
    await _islem(acik ? 'vetKodAc' : 'vetKodKapat', {'kod': kod});
    await yenile();
  }

  /// Veteriner bildiriminin durumunu (Görüldü, Düzeltildi, Katılmıyorum) ve
  /// isteğe bağlı yanıtı kaydeder.
  Future<void> vetBildirimDurum(VetBildirim b, String durum, {String? yanit}) async {
    await _islem('vetBildirimDurum', {
      'satir': '${b.satir}',
      'kod': b.kod,
      'durum': durum,
      if (yanit != null) 'yanit': yanit,
    });
    await yenile();
  }

  /// Panel adresi: bağlantı linkinin anahtarsız hâli + ?panel=veteriner.
  String? get vetPanelAdresi {
    final l = link;
    if (l == null) return null;
    final u = Uri.parse(l);
    return u.replace(queryParameters: {'panel': 'veteriner'}).toString();
  }

  /// Haftalık rapor PDF'ini Drive'daki "Haftalık Faaliyet Raporları"
  /// klasörüne kaydeder; sunucunun bilgi mesajını döner.
  Future<String> raporuDriveKaydet(String ad, List<int> pdf) async {
    final j = await _islem('raporKaydet', {'ad': ad, 'pdf': base64Encode(pdf)});
    return (j['mesaj'] ?? 'Rapor Drive\'a kaydedildi.').toString();
  }

  /// ÇKS belgesini (PDF ya da fotoğraf) Drive'daki "ÇKS Belgeleri" klasörüne
  /// yükler; sunucunun bilgi mesajını döner.
  Future<String> cksYukle(List<int> bayt, String mime, {String sezon = ''}) async {
    final j = await _islem('cksYukle', {'veri': base64Encode(bayt), 'mime': mime, 'sezon': sezon});
    return (j['mesaj'] ?? 'ÇKS belgesi Drive\'a kaydedildi.').toString();
  }

  /// Tarla Haritası karşılaştırmasındaki bir farkı düzeltir (ya da geri alır)
  /// ve veriyi yeniler.
  Future<String> ekimDuzelt({required String sezon, required String ciftlik, required String urun,
      String secim = '', double? deger, String aciklama = '', bool geriAl = false}) async {
    final j = await _islem(geriAl ? 'ekimDuzeltGeriAl' : 'ekimDuzelt', {
      'sezon': sezon, 'ciftlik': ciftlik, 'urun': urun, 'secim': secim,
      'deger': deger == null ? '' : '$deger'.replaceAll('.', ','), 'aciklama': aciklama,
    });
    await yenile();
    return (j['mesaj'] ?? 'Kaydedildi.').toString();
  }

  /// Tarla Haritası'nda bir parselin yeni sezon ürününü ve alanını kaydeder
  /// (ya da girişi geri alır) ve veriyi yeniler.
  Future<String> sezonParselKaydet({required String sezon, required String ciftlik, required String parsel,
      String urun = '', double? alan, bool geriAl = false, bool yenilensin = true}) async {
    final j = await _islem(geriAl ? 'sezonParselGeriAl' : 'sezonParsel', {
      'sezon': sezon, 'ciftlik': ciftlik, 'parsel': parsel, 'urun': urun,
      'alan': alan == null ? '' : '$alan'.replaceAll('.', ','),
    });
    // Harita hemen güncellensin: kayıt yerelde de tutulur; tam yenileme arkada sürer.
    _yerelParsel.add((
      DateTime.now(),
      SezonParsel(sezon: sezon, ciftlik: ciftlik, parsel: parsel, urun: urun, alan: alan, durum: geriAl ? 'Geri alındı' : 'Aktif'),
    ));
    notifyListeners();
    if (yenilensin) unawaited(yenile());
    return (j['mesaj'] ?? 'Kaydedildi.').toString();
  }

  /// Tarla Haritası: parsel sınırını kaydeder (yeni parsel de olabilir) ya da KMZ sınırına döndürür.
  /// Yalnızca çiftlik, parsel adı ve koordinat gönderilir; kişisel veri yoktur.
  Future<String> parselSinirKaydet(
      {required String ciftlik, required String parsel, List<(double, double)> koord = const [], bool geriAl = false}) async {
    final j = await _islem(geriAl ? 'parselSinirGeriAl' : 'parselSinir',
        {'ciftlik': ciftlik, 'parsel': parsel, 'koord': ParselSinir.koordYaz(koord)});
    _yerelSinir.add((
      DateTime.now(),
      ParselSinir(ciftlik: ciftlik, parsel: parsel, koord: koord, durum: geriAl ? 'Geri alındı' : 'Aktif'),
    ));
    notifyListeners();
    unawaited(yenile());
    return (j['mesaj'] ?? 'Kaydedildi.').toString();
  }

  /// Tarla Haritası: yeni sezon açar ya da kaydı olmayan sezonu kaldırır (sunucuda TARLA_SEZONLARI).
  Future<String> tarlaSezon(String sezon, {bool sil = false}) async {
    final j = await _islem(sil ? 'tarlaSezonSil' : 'tarlaSezonEkle', {'sezon': sezon});
    final l = j['tarlaSezonlari'];
    if (l is List) _yerelSezonlar = [for (final x in l) '$x'];
    notifyListeners();
    unawaited(yenile());
    return (j['mesaj'] ?? 'Kaydedildi.').toString();
  }

  List<String>? _yerelSezonlar;

  /// Açılan sezonlar: son işlemin sonucu (yenileme gelene kadar) ya da sunucu verisi.
  List<String> tarlaEkSezonlari(RaporVerisi v) => _yerelSezonlar ?? v.tarlaSezonlari;

  /// Ürün Takibi: elle teslimat / satış kaydı ekler ve veriyi yeniler.
  /// Miktarlar kg, fiyat TL/kg. Kişi adı gönderilmez.
  Future<String> teslimatKaydet({required DateTime tarih, required String ciftlik, required String urun,
      required double teslim, double kesinti = 0, String alici = '', double? fiyat, String aciklama = ''}) async {
    String g(double v) => '$v'.replaceAll('.', ',');
    final j = await _islem('teslimatEkle', {
      'tarih': '${tarih.year}-${tarih.month.toString().padLeft(2, '0')}-${tarih.day.toString().padLeft(2, '0')}',
      'ciftlik': ciftlik, 'urun': urun, 'teslim': g(teslim), 'kesinti': g(kesinti),
      'alici': alici, 'fiyat': fiyat == null ? '' : g(fiyat), 'aciklama': aciklama,
    });
    await yenile();
    return (j['mesaj'] ?? 'Kaydedildi.').toString();
  }

  /// Ürünün (ya da "Tümü") hasat durumunu kaydeder: tamamlandı / devam ediyor.
  Future<String> hasatDurumuKaydet({required int sezon, required String urun, required bool tamam}) async {
    final j = await _islem('hasatDurumu', {'sezon': '$sezon', 'urun': urun, 'tamam': '$tamam'});
    await yenile();
    return (j['mesaj'] ?? 'Kaydedildi.').toString();
  }

  /// Uygulamadan girilmiş teslimat kaydını siler (tabloda "Silindi" olarak işaretlenir).
  Future<String> teslimatSil(int satir) async {
    final j = await _islem('teslimatSil', {'satir': '$satir'});
    await yenile();
    return (j['mesaj'] ?? 'Silindi.').toString();
  }

  /// Kişiler sayfasındaki kişiye uygulamanın sahibi adına e-posta gönderir.
  Future<void> epostaGonder(String ad, String konu, String metin) async {
    await _islem('mesaj', {'ad': ad, 'konu': konu, 'metin': metin});
  }

  /// Kişinin telefonunu / e-postasını kaydeder (yoksa yeni kişi ekler) ve
  /// veriyi yeniler.
  Future<void> kisiKaydet(String ad,
      {required String telefon,
      required String eposta,
      String birim = '',
      bool yenilensin = true}) async {
    await _islem('kisi', {
      'ad': ad,
      'telefon': telefon,
      'eposta': eposta,
      'birim': birim,
      'anahtar': ad,
    });
    if (yenilensin) await yenile();
  }

  /// Kişi olayını Olumlu (düzeltildi) ya da Olumsuz yapar; özel veriyi yeniler.
  Future<void> olayDurumu(String kimlik, {required bool olumlu}) async {
    await _islem('olay', {'kimlik': kimlik, 'durum': olumlu ? 'Olumlu' : 'Olumsuz'});
    await ozelGetir();
    notifyListeners();
  }

  static Future<String> _gonder(Uri adres, String govde) async {
    var r = await http
        .post(adres,
            body: govde,
            headers: {'Content-Type': 'text/plain;charset=utf-8'})
        .timeout(const Duration(seconds: 330)); // eşitleme uzun sürebilir (Apps Script en çok 6 dk)
    // Apps Script, POST cevabını bir yönlendirme (302) ile verir; cevabı
    // yönlendirilen adresten GET ile okuruz.
    final yer = r.headers['location'];
    if ((r.statusCode == 302 || r.statusCode == 303) && yer != null) {
      r = await http
          .get(adres.resolve(yer))
          .timeout(const Duration(seconds: 45));
    }
    if (r.statusCode != 200) {
      throw VeriHatasi('Sunucu hatası (${r.statusCode}). Biraz sonra tekrar deneyin.');
    }
    return utf8.decode(r.bodyBytes);
  }
}
