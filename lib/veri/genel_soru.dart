// Asistan › Soru Sor: uygulamadaki tüm bölümlerin verisini tarayıp soruya
// veriye dayalı cevap üretir. Hesaplar cihazda yapılır; dışarıya veri
// gönderilmez.
//
// KVKK: personel, kişi, paylaşım ve veteriner erişim kodu verileri
// kullanılmaz; arıza ve bakım kayıtlarında bildiren kişi, mali kayıtlarda
// tedarikçi adı cevaba yazılmaz.
import '../bicim.dart';
import 'ciftlik_rapor.dart';
import 'ciftlik_soru.dart';
import 'hastalik.dart';
import 'model.dart';
import 'tarla.dart' show ParselIcerik;

/// Cevabın bir bölümü: başlık, paragraflar ve verinin alındığı kaynak.
class CevapBolumu {
  const CevapBolumu(this.baslik, this.paragraflar, this.kaynak);
  final String baslik;
  final List<String> paragraflar;
  final String kaynak;
}

class GenelYanit {
  const GenelYanit({required this.soru, required this.bolumler, this.anlasildi = true, this.bulgular = const []});
  final String soru;
  final List<CevapBolumu> bolumler;
  final bool anlasildi;

  /// Çiftlikler Rapor'dan gelen olumsuz sonuç ve tutarsızlıklar.
  final List<Bulgu> bulgular;
}

/// Dönem: [bas]–[son] (dahil) ve okunur adı.
class Donem {
  const Donem(this.bas, this.son, this.ad, {this.acik = false});
  final DateTime bas, son;
  final String ad;

  /// Soruda dönem açıkça belirtildi mi?
  final bool acik;
  bool icinde(DateTime t) => !gunu(t).isBefore(gunu(bas)) && !gunu(t).isAfter(gunu(son));
}

const _aylar = ['ocak', 'şubat', 'mart', 'nisan', 'mayıs', 'haziran', 'temmuz', 'ağustos', 'eylül', 'ekim', 'kasım', 'aralık'];
const _ayAdlari = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

/// Çiftlik adı → sorudaki karşılıkları ve kayıtlardaki karşılıkları.
const _ciftlikler = <String, List<String>>{
  'Şekersüt': ['şekersüt', 'şeker süt', 'sekersut', 'fethiye'],
  'Pan-Gev': ['pangev', 'pan-gev', 'pan gev', 'erentepe'],
  'Aslım': ['aslım', 'aslim'],
  'Taşağıl': ['taşağıl', 'tasagil', ' esk ', " esk'", ' esk’', ' esk-'],
  'Fidanlık': ['fidanlık', 'fidanlik'],
  'Ormanlık': ['ormanlık'],
  'Pankent': ['pankent'],
  'Tarımsal Alan': ['tarımsal alan'],
};

const _urunler = [
  'buğday', 'arpa', 'tritikale', 'çavdar', 'yulaf', 'pancar', 'patates', 'soğan', 'mısır', 'silaj', 'yonca', 'ayçiçeği',
  'kanola', 'nohut', 'fasulye', 'mercimek', 'korunga', 'fiğ', 'sorgum', 'nadas', 'saman', 'sap',
];

const _konular = <String, List<String>>{
  'sut': ['süt', 'sağmal', 'sağılan', 'sağım', 'litre', 'inek', 'sürü', 'hayvan sayı', 'kaç hayvan', 'kuru', 'gebe'],
  'dogum': ['doğum', 'doğan', 'buzağı', 'ölüm', 'öldü', 'ölen', 'kesim', 'yavru atma', 'ölü doğum'],
  'faaliyet': ['faaliyet', 'neler yapıldı', 'ne yapıldı', 'yapılan iş', 'sulama', 'ilaçlama', 'gübre', 'sürüm', 'tırmık', 'çapa', 'işler'],
  'ekim': ['ekim', 'ekil', 'ekiliş', 'dekar', 'sezon', 'parsel', 'plan'],
  'hasat': ['hasat', 'verim', 'rekolte', 'kaç ton', 'ton'],
  'urun': ['teslimat', 'teslim', 'satış', 'sattık', 'satılan', 'kantar', 'sefer', 'net kazanç', 'kazanç', 'gelir', 'fiyat', 'ürün takibi'],
  'esk': [' esk ', " esk'", ' esk’', ' esk-', 'et ve süt', 'besi hizmeti', 'bakım geliri', 'taşağıl'],
  'hastalik': ['hastalık', 'hasta', 'mastitis', 'ishal', 'pnömoni', 'tedavi', 'şap', 'topallık'],
  'arac': ['araç', 'traktör', 'kamyon', 'manitou', 'arıza', 'makine'],
  'bakim': ['bakım', 'onarım', 'tamir', 'servis', 'yedek parça'],
  'mali': ['fatura', 'ödeme', 'bakiye', 'borç', 'alacak', 'harcama', 'gider', 'vade'],
  'gecmis': ['geçmiş', 'önceki yıl', 'geçen yıl', 'bilgi bankası', 'ders', 'tecrübe'],
  'vet': ['veteriner'],
  'bulgu': ['bulgu', 'uyarı', 'sorun', 'tutarsız', 'eksik', 'hata'],
  'besi': ['besi', 'dana', 'düve', 'erkek hayvan'],
  'finans': ['kâr', 'kar ', 'zarar', 'maliyet', 'birim', 'ebitda', 'favök', 'teşvik', 'senaryo', 'piyasa', 'gelir tablosu', 'konsolide'],
};

const _durakKelimeler = {
  'nedir', 'neler', 'nasıl', 'kadar', 'hangi', 'hangisi', 'için', 'olan', 'oldu', 'mıydı', 'midir', 'mıdır', 'bana', 'göre', 'bilgi',
  'ver', 'veri', 'göster', 'söyle', 'kaç', 'mi', 'mı', 'mu', 'mü', 'var', 'yok', 'ile', 've', 'veya', 'daha', 'en', 'çok', 'az',
  'bu', 'şu', 'bir', 'ne', 'neden', 'niye', 'durum', 'durumu', 'toplam', 'ortalama', 'ayında', 'yılında', 'haftası', 'günü',
};

class _Soru {
  _Soru(String ham, DateTime bugun) : s = ' ${trKucuk(ham)} ' {
    for (final e in _ciftlikler.entries) {
      if (e.value.any(s.contains)) ciftlikler.add(e.key);
    }
    for (final u in _urunler) {
      if (s.contains(u)) urunler.add(u);
    }
    for (final e in _konular.entries) {
      if (e.value.any(s.contains)) konular.add(e.key);
    }
    // "Ekim ayı" ay adıdır, ekim (tohum) değil.
    if (RegExp(r'ekim ay|ekim 20\d\d').hasMatch(s) && !RegExp(r'ekim alan|ekili|ekiliş|ekim plan').hasMatch(s)) konular.remove('ekim');
    donem = _donem(bugun);
    kelimeler = [
      for (final k in s.split(RegExp(r"[^a-zçğıöşü0-9]+")))
        if (k.length >= 4 && !_durakKelimeler.contains(k) && !_aylar.contains(k)) k,
    ];
  }

  final String s;
  final ciftlikler = <String>{};
  final urunler = <String>{};
  final konular = <String>{};
  late final Donem donem;
  late final List<String> kelimeler;

  bool var_(String k) => konular.contains(k);

  Donem _donem(DateTime b) {
    final bugun = gunu(b);
    final yilM = RegExp(r'\b(20\d\d)\b').firstMatch(s);
    final yil = yilM == null ? null : int.parse(yilM[1]!);
    final sonN = RegExp(r'son (\d+) gün').firstMatch(s);
    if (sonN != null) {
      final n = int.parse(sonN[1]!);
      return Donem(bugun.subtract(Duration(days: n - 1)), bugun, 'son $n gün', acik: true);
    }
    if (s.contains('bugün')) return Donem(bugun, bugun, 'bugün', acik: true);
    if (s.contains(' dün')) {
      final d = bugun.subtract(const Duration(days: 1));
      return Donem(d, d, 'dün', acik: true);
    }
    final pzt = bugun.subtract(Duration(days: bugun.weekday - 1));
    if (s.contains('geçen hafta')) {
      return Donem(pzt.subtract(const Duration(days: 7)), pzt.subtract(const Duration(days: 1)), 'geçen hafta', acik: true);
    }
    if (s.contains('bu hafta') || s.contains('haftalık')) return Donem(pzt, bugun, 'bu hafta', acik: true);
    if (s.contains('geçen ay')) {
      final a = DateTime(bugun.year, bugun.month - 1, 1);
      return Donem(a, DateTime(a.year, a.month + 1, 0), '${_ayAdlari[a.month - 1]} ${a.year}', acik: true);
    }
    if (s.contains('bu ay')) {
      return Donem(DateTime(bugun.year, bugun.month, 1), bugun, '${_ayAdlari[bugun.month - 1]} ${bugun.year}', acik: true);
    }
    for (var i = 0; i < 12; i++) {
      if (RegExp('(^|[^a-zçğıöşü])${_aylar[i]}').hasMatch(s)) {
        var y = yil ?? bugun.year;
        if (yil == null && i + 1 > bugun.month) y--;
        return Donem(DateTime(y, i + 1, 1), DateTime(y, i + 2, 0), '${_ayAdlari[i]} $y', acik: true);
      }
    }
    if (yil != null) return Donem(DateTime(yil, 1, 1), DateTime(yil, 12, 31), '$yil yılı', acik: true);
    if (s.contains('bu yıl') || s.contains('yıllık')) return Donem(DateTime(bugun.year, 1, 1), bugun, '${bugun.year} yılı', acik: true);
    return Donem(bugun.subtract(const Duration(days: 6)), bugun, 'son 7 gün');
  }
}

String _yuzde(double a, double b) => b == 0 ? '' : ' (${a >= b ? '+' : '−'}%${sayi(((a - b) / b * 100).abs(), ondalik: 1)})';

bool _ciftlikEslesir(Set<String> secili, String kayit) {
  if (secili.isEmpty) return true;
  final k = trKucuk(kayit);
  return secili.any((c) => _ciftlikler[c]!.any(k.contains) || k.contains(trKucuk(c)));
}

/// Soruyu uygulamadaki verilerle cevaplar.
GenelYanit genelCevapla(RaporVerisi v, String soru, {CiftlikRaporu? rapor, List<HastalikKaydi> hastalik = const [], DateTime? bugun}) {
  final q = _Soru(soru, bugun ?? DateTime.now());
  final b = <CevapBolumu>[];
  var bulgular = <Bulgu>[];
  final konuYok = q.konular.isEmpty;

  // Yalnızca ürün adı geçiyorsa (ör. "buğday") ekim, hasat ve ürün takibi aranır.
  final urunSorusu = konuYok && q.urunler.isNotEmpty;
  // Yalnızca çiftlik adı geçiyorsa o çiftliğin özeti verilir.
  final ciftlikOzeti = konuYok && q.urunler.isEmpty && q.ciftlikler.isNotEmpty;

  if (q.var_('sut') || ciftlikOzeti && q.ciftlikler.any((c) => c == 'Şekersüt' || c == 'Pan-Gev')) _sut(v, q, b);
  if (q.var_('dogum')) _dogum(v, q, b);
  if (q.var_('faaliyet') || ciftlikOzeti) _faaliyet(v, q, b);
  if (q.var_('ekim') || urunSorusu) _ekim(v, q, b);
  if (q.var_('hasat') || urunSorusu) _hasat(v, q, b);
  if (q.var_('urun') || urunSorusu) _urunTakibi(v, q, b);
  if (q.var_('esk') || ciftlikOzeti && q.ciftlikler.contains('Taşağıl')) _esk(v, q, b);
  if (q.var_('besi')) _besi(v, q, b);
  if (q.var_('hastalik')) _hastalik(hastalik, q, b);
  if (q.var_('arac')) _arac(v, q, b);
  if (q.var_('bakim')) _bakim(v, q, b);
  if (q.var_('mali')) _mali(v, q, b);
  if (q.var_('vet')) _vet(v, q, b);
  if (q.var_('gecmis')) _gecmis(v, q, b);
  if (q.var_('bulgu') || ciftlikOzeti) _bulgu(v, q, b);
  if (rapor != null && (q.var_('finans') || q.var_('bulgu') && b.isEmpty)) {
    final y = cevapla(rapor, soru);
    if (y.anlasildi) {
      b.add(CevapBolumu('Kâr / zarar ve maliyet', y.paragraflar, 'Çiftlikler Rapor (${rapor.kaynak}; Maliyet Takip)'));
      bulgular = y.bulgular;
    }
  }
  if (b.isEmpty) _metinArama(v, q, b);
  if (b.isEmpty) {
    return GenelYanit(soru: soru, anlasildi: false, bolumler: [
      CevapBolumu(
          'Veri bulunamadı',
          [
            'Bu soruyla ilgili uygulamadaki verilerde kayıt bulunamadı; tahmini bir cevap verilmez.',
            'Soruyu süt, hayvan sayısı, doğum/ölüm, tarım faaliyeti, ekim, hasat, ürün teslimatı, ESK, hastalık, araç, bakım onarım, '
                'fatura, veteriner, geçmiş yıllar veya kâr/zarar konularından biriyle, gerekirse çiftlik ve dönem belirterek sorabilirsiniz. '
                'Örn. “Geçen hafta Şekersüt’te günlük süt ne kadar?”',
          ],
          ''),
    ]);
  }
  return GenelYanit(soru: soru, bolumler: b, bulgular: bulgular);
}

// ----------------------------------------------------------------- süt ve sürü

void _sut(RaporVerisi v, _Soru q, List<CevapBolumu> b) {
  if (v.gunluk.isEmpty) return;
  final l = [...v.gunluk]..sort((a, b) => a.tarih.compareTo(b.tarih));
  final son = l.last.tarih;
  // Dönem verilmediyse son veri günü esas alınır.
  final d = q.donem.acik ? q.donem : Donem(son.subtract(const Duration(days: 6)), son, 'son 7 gün (${tarihKisa(son)} itibarıyla)');
  final p = [for (final x in l) if (d.icinde(x.tarih)) x];
  final ciftlikler = [
    if (q.ciftlikler.isEmpty || q.ciftlikler.contains('Şekersüt')) ('Şekersüt', (GunlukSatir x) => x.fethiye),
    if (q.ciftlikler.isEmpty || q.ciftlikler.contains('Pan-Gev')) ('Pan-Gev', (GunlukSatir x) => x.erentepe),
  ];
  if (ciftlikler.isEmpty) return;
  final par = <String>[];
  if (p.isEmpty) {
    par.add('${d.ad} için günlük süt kaydı yok. Kayıtlar ${tarihKisa(l.first.tarih)} – ${tarihKisa(son)} arasını kapsıyor.');
  } else {
    final gun = p.length;
    par.add('${d.ad}: ${tarihKisa(p.first.tarih)} – ${tarihKisa(p.last.tarih)}, $gun günlük kayıt.');
    // Önceki eşit dönem
    final uz = d.son.difference(d.bas).inDays + 1;
    final onceki = Donem(d.bas.subtract(Duration(days: uz)), d.bas.subtract(const Duration(days: 1)), 'önceki dönem');
    final o = [for (final x in l) if (onceki.icinde(x.tarih)) x];
    for (final (ad, f) in ciftlikler) {
      final sut = p.fold<double>(0, (t, x) => t + f(x).sut);
      final sat = p.fold<double>(0, (t, x) => t + f(x).satilan);
      final sagmal = p.fold<double>(0, (t, x) => t + f(x).sagmal) / gun;
      final top = f(p.last).toplam;
      final ort = sagmal > 0 ? sut / gun / sagmal : 0.0;
      final oSut = o.isEmpty ? 0.0 : o.fold<double>(0, (t, x) => t + f(x).sut) / o.length;
      par.add('$ad: toplam ${sayi(sut)} kg süt (günlük ortalama ${sayi(sut / gun)} kg${o.isEmpty ? '' : _yuzde(sut / gun, oSut)}), '
          'satılan ${sayi(sat)} kg; ortalama ${sayi(sagmal)} sağmal, inek başı ${sayi(ort, ondalik: 1)} kg/gün. '
          'Son gün (${tarihKisa(p.last.tarih)}) sürü ${sayi(top)} baş, sağmal ${sayi(f(p.last).sagmal)}, kuru/gebe ${sayi(f(p.last).kuruGebe)}.');
    }
    if (o.isNotEmpty) par.add('Parantezdeki değişim, bir önceki eşit uzunluktaki dönemin (${tarihKisa(o.first.tarih)} – ${tarihKisa(o.last.tarih)}) günlük ortalamasına göredir.');
  }
  b.add(CevapBolumu('Süt ve sürü', par, 'Hayvan_Günlük sayfası (işletme günlük raporları)'));
}

void _dogum(RaporVerisi v, _Soru q, List<CevapBolumu> b) {
  if (v.ozet.isEmpty) return;
  final son = v.ozet.map((x) => x.tarih).reduce((a, b) => a.isAfter(b) ? a : b);
  final d = q.donem.acik ? q.donem : Donem(son.subtract(const Duration(days: 29)), son, 'son 30 gün (${tarihKisa(son)} itibarıyla)');
  final l = [for (final x in v.ozet) if (d.icinde(x.tarih) && _ciftlikEslesir(q.ciftlikler, x.isletme)) x];
  if (l.isEmpty) {
    b.add(CevapBolumu('Doğum, ölüm ve kesim', ['${d.ad} için kayıt yok.'], 'Hayvan_Özet sayfası'));
    return;
  }
  final m = <String, List<double>>{};
  for (final x in l) {
    final a = m.putIfAbsent(x.isletme, () => List.filled(8, 0));
    final de = [x.dogan, x.buzagiOlum, x.inekOlum, x.gencOlum, x.olenDana, x.yavruAtma, x.kesimSatis + x.gencKesim + x.kesilenDana, x.satilanDana];
    for (var i = 0; i < 8; i++) {
      a[i] += de[i];
    }
  }
  final par = <String>['${d.ad} (${tarihKisa(l.map((x) => x.tarih).reduce((a, b) => a.isBefore(b) ? a : b))} – ${tarihKisa(l.map((x) => x.tarih).reduce((a, b) => a.isAfter(b) ? a : b))}):'];
  for (final e in m.entries) {
    final a = e.value;
    if (a.every((x) => x == 0)) continue;
    par.add('${e.key}: doğan buzağı ${sayi(a[0])}, buzağı ölümü ${sayi(a[1])}, inek ölümü ${sayi(a[2])}, genç ölümü ${sayi(a[3])}, '
        'ölen dana ${sayi(a[4])}, yavru atma/ölü doğum ${sayi(a[5])}, kesim/satış ${sayi(a[6])}, satılan/transfer dana ${sayi(a[7])}.');
  }
  if (par.length == 1) par.add('Bu dönemde doğum, ölüm veya kesim kaydı yok.');
  b.add(CevapBolumu('Doğum, ölüm ve kesim', par, 'Hayvan_Özet sayfası'));
}

// ----------------------------------------------------------------- tarım

void _faaliyet(RaporVerisi v, _Soru q, List<CevapBolumu> b) {
  if (v.tarim.isEmpty) return;
  final son = v.tarim.map((x) => x.tarih).reduce((a, b) => a.isAfter(b) ? a : b);
  final ilk = v.tarim.map((x) => x.tarih).reduce((a, b) => a.isBefore(b) ? a : b);
  // Belirli bir iş (sulama, gübre…) ya da ürün sorulduysa ve dönem verilmediyse tüm kayıtlar aranır.
  final isler = [for (final k in const ['sulama', 'ilaçlama', 'gübre', 'sürüm', 'tırmık', 'çapa', 'hasat', 'ekim', 'biçim', 'balya']) if (q.s.contains(k)) k];
  final suz = isler.isNotEmpty || q.urunler.isNotEmpty;
  final d = q.donem.acik
      ? q.donem
      : suz
          ? Donem(ilk, son, 'tüm kayıtlar')
          : Donem(son.subtract(const Duration(days: 6)), son, 'son 7 gün (${tarihKisa(son)} itibarıyla)');
  final l = [
    for (final x in v.tarim)
      if (d.icinde(x.tarih) &&
          _ciftlikEslesir(q.ciftlikler, x.ciftlik) &&
          (q.urunler.isEmpty || q.urunler.any(trKucuk(x.faaliyet).contains)) &&
          (isler.isEmpty || isler.any(trKucuk(x.faaliyet).contains)))
        x,
  ]..sort((a, b) => b.tarih.compareTo(a.tarih));
  final par = <String>[];
  if (l.isEmpty) {
    par.add('${d.ad} için ${q.ciftlikler.isEmpty ? '' : '${q.ciftlikler.join(', ')} '}tarım faaliyeti kaydı yok.');
  } else {
    final say = <String, int>{};
    for (final x in l) {
      say[x.ciftlik] = (say[x.ciftlik] ?? 0) + 1;
    }
    par.add('${d.ad}: ${l.length} faaliyet kaydı (${say.entries.map((e) => '${e.key} ${e.value}').join(', ')}).');
    for (final x in l.take(15)) {
      par.add('${tarihKisa(x.tarih)} · ${x.ciftlik}: ${x.faaliyet}');
    }
    if (l.length > 15) par.add('… ve ${l.length - 15} kayıt daha (tamamı Tarım ekranında).');
  }
  b.add(CevapBolumu('Tarım faaliyetleri', par, 'Tarım_Veri sayfası (günlük tarım bildirimleri)'));
}

void _ekim(RaporVerisi v, _Soru q, List<CevapBolumu> b) {
  final par = <String>[];
  // Tarla Haritası girişleri: her (sezon, çiftlik, parsel) için son kayıt.
  final sonKayit = <String, SezonParsel>{};
  for (final x in v.sezonParsel) {
    sonKayit['${x.sezon}|${x.ciftlik}|${x.parsel}'] = x;
  }
  final sezonlar = <String, Map<String, double>>{};
  for (final x in sonKayit.values) {
    if (x.durum != 'Aktif' || !_ciftlikEslesir(q.ciftlikler, x.ciftlik)) continue;
    final ic = ParselIcerik.oku(x.urun);
    if (ic.birlesik != null) continue;
    final m = sezonlar.putIfAbsent(x.sezon, () => {});
    if (ic.parcalar.length > 1) {
      for (final (u, da) in ic.parcalar) {
        m[u] = (m[u] ?? 0) + (da ?? 0);
      }
    } else if (ic.parcalar.isNotEmpty) {
      m[ic.parcalar.first.$1] = (m[ic.parcalar.first.$1] ?? 0) + (x.alan ?? 0);
    }
  }
  for (final s in (sezonlar.keys.toList()..sort()).reversed) {
    final m = sezonlar[s]!;
    final l = [
      for (final e in m.entries)
        if (q.urunler.isEmpty || q.urunler.any(trKucuk(e.key).contains)) e,
    ]..sort((a, b) => b.value.compareTo(a.value));
    if (l.isEmpty) continue;
    final top = l.fold<double>(0, (t, e) => t + e.value);
    par.add('$s sezonu (Tarla Haritası girişleri${q.ciftlikler.isEmpty ? '' : ', ${q.ciftlikler.join(', ')}'}): '
        '${l.map((e) => '${e.key} ${sayi(e.value)} da').join(', ')}; toplam ${sayi(top)} da.');
  }
  final plan = [
    for (final x in v.ekimPlani)
      if (_ciftlikEslesir(q.ciftlikler, x.ciftlik) && (q.urunler.isEmpty || q.urunler.any(trKucuk(x.urun).contains))) x,
  ];
  if (plan.isNotEmpty) {
    final m = <String, double>{};
    for (final x in plan) {
      m['${x.yil}|${x.urun}'] = (m['${x.yil}|${x.urun}'] ?? 0) + x.plan;
    }
    final yillar = {for (final x in plan) x.yil}.toList()..sort();
    for (final y in yillar.reversed.take(2)) {
      final l = [for (final e in m.entries) if (e.key.startsWith('$y|')) (e.key.substring(y.length + 1), e.value)]
        ..sort((a, b) => b.$2.compareTo(a.$2));
      par.add('$y ekim planı (Excel): ${l.map((e) => '${e.$1} ${sayi(e.$2)} da').join(', ')}.');
    }
  }
  final ekim = [
    for (final x in v.ekim)
      if (_ciftlikEslesir(q.ciftlikler, x.ciftlik) && (q.urunler.isEmpty || q.urunler.any(trKucuk(x.urun).contains))) x,
  ];
  if (ekim.isNotEmpty) {
    par.add('Ekim takibi (plan / ekilen): ${ekim.map((x) => '${x.ciftlik} ${x.urun} ${sayi(x.plan)} / ${sayi(x.ekilen)} da').join('; ')}.');
  }
  if (par.isNotEmpty) b.add(CevapBolumu('Ekim alanları', par, 'Sezon_Parselleri (Tarla Haritası), Ekim Planı ve Ekim_Alanları sayfaları'));
}

void _hasat(RaporVerisi v, _Soru q, List<CevapBolumu> b) {
  final l = [
    for (final x in v.hasat)
      if (_ciftlikEslesir(q.ciftlikler, x.ciftlik) &&
          (q.urunler.isEmpty || q.urunler.any(trKucuk(x.urun).contains)) &&
          (!q.donem.acik || x.tarih == null || q.donem.icinde(x.tarih!)))
        x,
  ];
  if (l.isEmpty) return;
  b.add(CevapBolumu(
    'Hasat ve verim',
    [
      for (final x in l.take(15))
        '${x.tarih == null ? '' : '${tarihKisa(x.tarih!)} · '}${x.ciftlik} ${x.urun}: ${sayi(x.alan)} da, toplam ${sayi(x.toplam)} kg'
            '${x.verim == null ? '' : ', dekara ${sayi(x.verim)} kg'}.',
    ],
    'Hasat_Verim sayfası',
  ));
}

void _urunTakibi(RaporVerisi v, _Soru q, List<CevapBolumu> b) {
  final par = <String>[];
  final t = v.tarimsalUretim;
  if (!t.bos) {
    for (final c in t.ciftlikler) {
      if (!_ciftlikEslesir(q.ciftlikler, c.ciftlik)) continue;
      for (final u in c.urunler) {
        if (q.urunler.isNotEmpty && !q.urunler.any(trKucuk(u.ad).contains)) continue;
        if (u.dekar == 0 && u.satis == 0) continue;
        par.add('${c.ciftlik} ${u.ad}: ${sayi(u.dekar)} da, verim ${sayi(u.dekaraVerim)} kg/da, satış ${sayi(u.satis)} ₺, '
            'maliyet ${sayi(u.maliyet)} ₺, net kazanç ${sayi(u.netKazanc)} ₺ (dekara ${sayi(u.dekarKazanc)} ₺).');
      }
    }
    if (par.isNotEmpty) par.insert(0, '${t.yilBasligi.isEmpty ? '' : '${t.yilBasligi} · '}Tarımsal Faaliyet › Çiftlik Bazında:');
  }
  final g = [
    for (final x in v.urunTeslimat.gunler)
      if (_ciftlikEslesir(q.ciftlikler, x.ciftlik) &&
          (q.urunler.isEmpty || q.urunler.any(trKucuk(x.urun).contains)) &&
          (!q.donem.acik || _donemde(q.donem, x.tarih)))
        x,
  ];
  if (g.isNotEmpty) {
    final m = <String, List<double>>{};
    for (final x in g) {
      final a = m.putIfAbsent('${x.ciftlik} ${x.urun}', () => [0, 0, 0, 0]);
      a[0] += x.sefer;
      a[1] += x.net;
      a[2] += x.tutar;
      a[3] += x.ekGelir;
    }
    final tarihler = [for (final x in g) x.tarih]..sort();
    par.add('Teslimat (${q.donem.acik ? q.donem.ad : 'tüm kayıtlar'}, ${tarihler.first} – ${tarihler.last}):');
    for (final e in m.entries) {
      par.add('${e.key}: ${sayi(e.value[0])} sefer, net ${sayi(e.value[1] / 1000, ondalik: 1)} ton'
          '${e.value[2] > 0 ? ', tutar ${sayi(e.value[2])} ₺' : ''}${e.value[3] > 0 ? ', ek gelir ${sayi(e.value[3])} ₺' : ''}.');
    }
  }
  if (par.isNotEmpty) b.add(CevapBolumu('Ürün takibi', par, 'Ürün Takibi (Tarımsal Faaliyet dosyası, teslimat ve kantar kayıtları)'));
}

bool _donemde(Donem d, String tarih) {
  final t = DateTime.tryParse(tarih);
  return t != null && d.icinde(t);
}

// ----------------------------------------------------------------- hayvancılık diğer

void _esk(RaporVerisi v, _Soru q, List<CevapBolumu> b) {
  if (v.eskAylik.isEmpty) return;
  final l = [
    for (final x in v.eskAylik)
      if (!q.donem.acik || (x.yil >= q.donem.bas.year && x.yil <= q.donem.son.year)) x,
  ];
  if (l.isEmpty) return;
  final par = <String>[];
  final gercek = [for (final x in l) if (!x.tahmini) x];
  final kz = gercek.fold<double>(0, (t, x) => t + (x.karZarar ?? 0));
  par.add('${l.first.ay} – ${l.last.ay}: gerçekleşen ${gercek.length} ayın toplam sonucu ${sayi(kz)} ₺ '
      '(${kz >= 0 ? 'kâr' : 'zarar'}).');
  for (final x in l.reversed.take(6)) {
    par.add('${x.ay}${x.tahmini ? ' (tahmini)' : ''}: gelen ${sayi(x.gelen)} baş, Panagro kesim ${sayi(x.kesim)}, ölen ${sayi(x.olen)}, '
        'gelir ${sayi(x.gelir)} ₺, gider ${sayi(x.gider)} ₺, sonuç ${sayi(x.karZarar)} ₺.${x.not.isEmpty ? '' : ' ${x.not}'}');
  }
  b.add(CevapBolumu('ESK – Taşağıl', par, 'ESK_Aylık sayfası'));
}

void _besi(RaporVerisi v, _Soru q, List<CevapBolumu> b) {
  final l = [for (final x in v.besi) if (_ciftlikEslesir(q.ciftlikler, x.isletme)) x];
  if (l.isEmpty) return;
  b.add(CevapBolumu(
    'Besi planı',
    [for (final x in l) '${x.isletme}: yerli ${sayi(x.yerli)}, erkek ${sayi(x.erkek)}, inek ${sayi(x.inek)} baş.'],
    'Besi_Plan sayfası',
  ));
}

void _hastalik(List<HastalikKaydi> h, _Soru q, List<CevapBolumu> b) {
  if (h.isEmpty) return;
  final l = [
    for (final x in h)
      if (_ciftlikEslesir(q.ciftlikler, x.ciftlik) &&
          (!q.donem.acik || (!DateTime(x.yil, x.ay, 1).isAfter(q.donem.son) && !DateTime(x.yil, x.ay + 1, 0).isBefore(q.donem.bas))) &&
          (q.kelimeler.every((k) => !_hastalikAdiMi(h, k)) || q.kelimeler.any(trKucuk(x.hastalik).contains)))
        x,
  ];
  if (l.isEmpty) {
    b.add(CevapBolumu('Hastalıklar', ['${q.donem.acik ? q.donem.ad : 'Kayıtlarda'} bu ölçütle hastalık kaydı yok.'], 'Hastalık Dağılımı'));
    return;
  }
  final hm = <String, int>{}, sm = <String, int>{};
  for (final x in l) {
    hm[x.hastalik] = (hm[x.hastalik] ?? 0) + x.adet;
    sm[x.sonuc] = (sm[x.sonuc] ?? 0) + x.adet;
  }
  final hs = hm.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final ilk = l.map((x) => x.yil * 100 + x.ay).reduce((a, b) => a < b ? a : b);
  final son = l.map((x) => x.yil * 100 + x.ay).reduce((a, b) => a > b ? a : b);
  b.add(CevapBolumu(
    'Hastalıklar',
    [
      '${_ayAdlari[ilk % 100 - 1]} ${ilk ~/ 100} – ${_ayAdlari[son % 100 - 1]} ${son ~/ 100}: ${hm.values.fold(0, (a, b) => a + b)} vaka.',
      'En sık: ${hs.take(6).map((e) => '${e.key} ${e.value}').join(', ')}.',
      'Sonuçlar: ${sm.entries.map((e) => '${e.key} ${e.value}').join(', ')}.',
    ],
    'Hastalık Dağılımı (veteriner kayıtları ve Bilgi Bankası)',
  ));
}

bool _hastalikAdiMi(List<HastalikKaydi> h, String k) => h.any((x) => trKucuk(x.hastalik).contains(k));

// ----------------------------------------------------------------- araç, bakım, mali, veteriner

void _arac(RaporVerisi v, _Soru q, List<CevapBolumu> b) {
  final a = v.arac;
  if (a.bos) return;
  final acik = [for (final x in a.ariza) if (!x.kapali && _ciftlikEslesir(q.ciftlikler, x.ciftlik)) x];
  final par = <String>[
    '${a.araclar.length} kayıtlı araç/makine, ${a.aktif.length} devam eden kullanım, ${acik.length} açık arıza.',
    for (final x in acik.take(10))
      '${x.arac} (${x.ciftlik}): ${x.aciklama}${x.gun == null ? '' : ' — ${x.gun} gündür açık'}; durum: ${x.durum}.',
  ];
  b.add(CevapBolumu('Araç ve makineler', par, 'Araç Takip tablosu'));
}

void _bakim(RaporVerisi v, _Soru q, List<CevapBolumu> b) {
  final o = v.bakimOnarim;
  if (o.bos) return;
  final acik = [for (final x in o.acik) if (_ciftlikEslesir(q.ciftlikler, x.ciftlik)) x];
  b.add(CevapBolumu(
    'Bakım onarım',
    [
      '${o.onayli.length} onaylı, ${o.onayBekleyen.length} onay bekleyen, ${o.acik.length} açık iş, ${o.tedarikBekleyen.length} tedarik bekleyen kayıt.',
      for (final x in acik.take(10)) '${x.zaman} · ${x.ciftlik} · ${x.makine}: ${x.islem}${x.yapilanIs.isEmpty ? '' : ' — ${x.yapilanIs}'} (${x.durum}).',
    ],
    'Günlük Tarım Bildirimi – bakım onarım kayıtları',
  ));
}

void _mali(RaporVerisi v, _Soru q, List<CevapBolumu> b) {
  final m = v.mali;
  if (m.bos) return;
  final f = [for (final x in m.faturalar) if ((!q.donem.acik || q.donem.icinde(x.tarih)) && _ciftlikEslesir(q.ciftlikler, x.birim)) x];
  final kat = <String, double>{};
  for (final x in f) {
    if (x.paraBirimi != 'TRY') continue;
    kat[x.kategori.isEmpty ? 'Diğer' : x.kategori] = (kat[x.kategori.isEmpty ? 'Diğer' : x.kategori] ?? 0) + x.tutar;
  }
  final ks = kat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final acik = m.acik.fold<double>(0, (t, x) => t + x.tutar);
  b.add(CevapBolumu(
    'Faturalar ve bakiyeler',
    [
      '${q.donem.acik ? q.donem.ad : 'Tüm kayıtlar'}: ${f.length} fatura, toplam ${sayi(kat.values.fold<double>(0, (a, b) => a + b))} ₺'
          '${ks.isEmpty ? '' : ' — ${ks.take(6).map((e) => '${e.key} ${sayi(e.value)} ₺').join(', ')}'}.',
      'Açık bakiye: ${m.acik.length} kalem, ${sayi(acik)} ₺. Kontrol bulgusu: ${m.kontrol.length}.',
      'Tedarikçi bazında ayrıntı Mali Raporlar ekranındadır.',
    ],
    'Mali Raporlar (${m.kaynak.isEmpty ? 'gelen faturalar ve açık bakiyeler' : m.kaynak})',
  ));
}

void _vet(RaporVerisi v, _Soru q, List<CevapBolumu> b) {
  final l = v.vetBildirimleri;
  if (l.isEmpty) return;
  final yeni = l.where((x) => x.yeni).length;
  b.add(CevapBolumu(
    'Veteriner değerlendirmeleri',
    [
      '${l.length} değerlendirme, $yeni yeni.',
      for (final x in l.take(8)) '${x.tarih} · ${x.bolum}: ${x.konu}${x.degerlendirme.isEmpty ? '' : ' — ${x.degerlendirme}'} (${x.durum}).',
    ],
    'Veteriner Kontrol Paneli',
  ));
}

void _gecmis(RaporVerisi v, _Soru q, List<CevapBolumu> b) {
  bool uyar(String t) {
    final k = trKucuk(t);
    return (q.urunler.isEmpty || q.urunler.any(k.contains)) &&
        (q.kelimeler.isEmpty || q.kelimeler.any(k.contains) || q.urunler.isNotEmpty);
  }

  final g = [
    for (final x in v.gecmis)
      if ((!q.donem.acik || x.yilNo >= q.donem.bas.year && x.yilNo <= q.donem.son.year) &&
          _ciftlikEslesir(q.ciftlikler, '${x.alan} ${x.konu}') &&
          uyar('${x.alan} ${x.konu} ${x.gosterge}'))
        x,
  ];
  final d = [for (final x in v.dersler) if (uyar('${x.alan} ${x.konu} ${x.neOldu} ${x.sonuc}')) x];
  if (g.isEmpty && d.isEmpty) return;
  b.add(CevapBolumu(
    'Geçmiş yıllar',
    [
      for (final x in g.take(12)) '${x.yil}${x.ay.isEmpty ? '' : ' ${x.ay}'} · ${x.konu} · ${x.gosterge}: ${x.deger} ${x.birim}'.trim(),
      if (g.length > 12) '… ve ${g.length - 12} kayıt daha (Geçmiş Yıllar ekranında).',
      for (final x in d.take(5)) 'Ders (${x.yil}, ${x.konu}): ${x.neOldu} → ${x.sonuc}',
    ],
    'Bilgi Bankası (Geçmiş Yıllar)',
  ));
}

void _bulgu(RaporVerisi v, _Soru q, List<CevapBolumu> b) {
  final l = [
    for (final x in v.bulgular)
      if (_ciftlikEslesir(q.ciftlikler, x.ciftlik) && (!q.donem.acik || q.donem.icinde(x.gun))) x,
  ]..sort((a, b) => b.gun.compareTo(a.gun));
  if (l.isEmpty) return;
  b.add(CevapBolumu(
    'Drive incelemesi bulguları',
    [for (final x in l.take(8)) '${tarihKisa(x.gun)} · ${x.ciftlik.isEmpty ? x.konu : '${x.ciftlik} · ${x.konu}'}: ${x.bulgu}'],
    'Günlük Drive incelemesi (Drive_Bulgular)',
  ));
}

// ----------------------------------------------------------------- serbest metin araması

void _metinArama(RaporVerisi v, _Soru q, List<CevapBolumu> b) {
  final k = [...q.kelimeler, ...q.urunler];
  if (k.isEmpty) return;
  bool es(String t) {
    final s = trKucuk(t);
    return k.any(s.contains);
  }

  final l = <(DateTime?, String, String)>[
    for (final x in v.tarim)
      if (es(x.faaliyet) && _ciftlikEslesir(q.ciftlikler, x.ciftlik)) (x.tarih, 'Tarım', '${x.ciftlik}: ${x.faaliyet}'),
    for (final x in v.bulgular)
      if (es('${x.konu} ${x.bulgu}') && _ciftlikEslesir(q.ciftlikler, x.ciftlik)) (x.gun, 'Drive bulgusu', '${x.konu}: ${x.bulgu}'),
    for (final x in v.gecmis)
      if (es('${x.konu} ${x.gosterge}')) (null, 'Geçmiş ${x.yil}', '${x.konu} · ${x.gosterge}: ${x.deger} ${x.birim}'),
    for (final x in v.dersler)
      if (es('${x.konu} ${x.neOldu} ${x.sonuc}')) (null, 'Ders ${x.yil}', '${x.konu}: ${x.neOldu} → ${x.sonuc}'),
    for (final x in v.bakimOnarim.kayitlar)
      if (es('${x.makine} ${x.islem} ${x.yapilanIs}')) (null, 'Bakım ${x.zaman}', '${x.ciftlik} · ${x.makine}: ${x.islem}'),
  ];
  if (l.isEmpty) return;
  l.sort((a, b) => (b.$1 ?? DateTime(2000)).compareTo(a.$1 ?? DateTime(2000)));
  b.add(CevapBolumu(
    'Kayıtlarda geçen ifadeler',
    [
      '“${k.join('”, “')}” ifadesi ${l.length} kayıtta geçiyor:',
      for (final x in l.take(12)) '${x.$1 == null ? '' : '${tarihKisa(x.$1!)} · '}${x.$2} · ${x.$3}',
    ],
    'Tarım_Veri, Drive_Bulgular, Bilgi Bankası, bakım onarım kayıtları',
  ));
}

/// Ekranda gösterilen örnek sorular.
const genelOrnekSorular = [
  'Geçen hafta Şekersüt’te günlük süt ne kadar?',
  'Bu ay doğum ve ölümler',
  'Son 7 gün Aslım’da neler yapıldı?',
  'Buğday',
  '2026-2027 sezonu ekim alanları',
  'Pancar teslimatı ne durumda?',
  'ESK 2026 kâr zarar',
  'Açık arızalar',
  'Kasım ayı faturaları',
  'Şekersüt süt maliyeti neden arttı?',
];
