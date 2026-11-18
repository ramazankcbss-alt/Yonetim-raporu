import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../veri/detay.dart';
import '../veri/faaliyet_ozet.dart';
import '../veri/model.dart';
import '../veri/tablolar.dart';

const _ana = PdfColor.fromInt(0xFF1F7A4D);
const _anaKoyu = PdfColor.fromInt(0xFF14593A);
const _anaAcik = PdfColor.fromInt(0xFFE3F2EA);
const _cizgi = PdfColor.fromInt(0xFFD5DEE3);
const _soluk = PdfColor.fromInt(0xFF64748B);
const _yazi = PdfColor.fromInt(0xFF1E293B);
const _vurgu = PdfColor.fromInt(0xFFF1F5F4);

pw.ThemeData? _tema;

Future<pw.ThemeData> _temaYukle() async {
  if (_tema != null) return _tema!;
  final normal = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
  final kalin =
      pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
  _tema = pw.ThemeData.withFont(base: normal, bold: kalin);
  return _tema!;
}

/// Dosya adı: Gunluk_Rapor_05.11.2026.pdf / Haftalik_Rapor_45_Hafta_2026.pdf
String gunlukDosyaAdi(DateTime gun) => 'Gunluk_Rapor_${tarihKisa(gun)}.pdf';

String haftalikDosyaAdi(DateTime pazartesi) =>
    'Haftalik_Rapor_${isoHafta(pazartesi)}_Hafta_${pazartesi.add(const Duration(days: 3)).year}.pdf';

// ---------------------------------------------------------------------------

Future<Uint8List> gunlukRaporPdf(
    RaporVerisi v, DateTime gun, RaporAyari a) async {
  final tema = await _temaYukle();
  final g = gunlukGostergeler(v, gun);
  final oz = canliHayvanOzeti(v, gun, gun);
  final bugun = v.gunlukBul(gun);
  final onceki = v.oncekiGunluk(gun);
  final faaliyetler = [
    for (final f in v.tarimDonem(gun, gun)) if (!f.kontrolBekliyor) f
  ];
  final kayitli = {for (final f in faaliyetler) f.ciftlik};
  final digerSonlar = [
    for (final s in v.sonFaaliyetler(gun))
      if (!kayitli.contains(s.ciftlik)) s
  ];

  final doc = pw.Document(
      title: '${a.baslik} — ${tarihKisa(gun)}', author: a.hazirlayan);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 28),
    theme: tema,
    footer: (c) => _altBilgi(c, a),
    build: (c) => [
      _bant(a, 'Günlük Rapor', tarihUzun(gun)),
      ..._hitap(a, '${tarihKisa(gun)} tarihli çiftlik verileri aşağıda bilgilerinize sunulmuştur.'),
      _bolum('Özet Göstergeler'),
      _gostergeler(g,
          haftalik: false,
          ko: kayipOzeti(v, gun, gun),
          eskOlen: kayipOzeti(v, gun, gun, eskDahil: true)?.toplam),
      _bolum('Canlı Hayvan — İşletme Bazlı'),
      if (oz.ozetGunu == null)
        _not('Bu gün için işletme özeti bulunmuyor.')
      else
        _tablo(isletmeBasliklari, isletmeSatirlari(oz),
            genislik: _isletmeGenislik, vurguSon: true, kucuk: true),
      ..._hareketler(v, gun, gun),
      _bolum('Süt Sığırı — Fethiye / Erentepe'),
      if (bugun == null)
        _not('Bu gün için Fethiye / Erentepe günlük verisi bulunmuyor.')
      else ...[
        _tablo(
            suruBasliklari(onceki == null ? 'Önceki' : gunAy(onceki.tarih),
                gunAy(gun)),
            suruSatirlari(onceki, bugun),
            genislik: _suruGenislik),
        if (onceki != null)
          _not('Karşılaştırma önceki veri günü (${tarihKisa(onceki.tarih)}) ile yapılmıştır.'),
      ],
      _bolum('Tarımsal Faaliyetler'),
      if (faaliyetler.isEmpty)
        _not('Bu gün için tarım kaydı bulunmuyor.')
      else
        _tablo(const ['Çiftlik', 'Faaliyet'], [
          for (final o in faaliyetOzeti(faaliyetler))
            [o.ciftlik, _maddeler(o.maddeler)]
        ],
            genislik: const {0: pw.FlexColumnWidth(1.1), 1: pw.FlexColumnWidth(6)},
            metin: const {0, 1}),
      if (digerSonlar.isNotEmpty) ...[
        pw.SizedBox(height: 6),
        pw.Text('Diğer çiftliklerin son kaydı',
            style: pw.TextStyle(
                fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _soluk)),
        pw.SizedBox(height: 3),
        _tablo(const ['Çiftlik', 'Tarih', 'Faaliyet'], [
          for (final f in digerSonlar)
            [f.ciftlik, tarihKisa(f.tarih), faaliyetMaddeleri(f.faaliyet).join('; ')]
        ],
            genislik: const {
              0: pw.FlexColumnWidth(1.1),
              1: pw.FlexColumnWidth(1.1),
              2: pw.FlexColumnWidth(5),
            },
            metin: const {0, 1, 2}),
      ],
      _dipnot(),
      ..._imza(a),
    ],
  ));
  return doc.save();
}

Future<Uint8List> haftalikRaporPdf(
    RaporVerisi v, DateTime pazartesi, RaporAyari a) async {
  final tema = await _temaYukle();
  final son = pazartesi.add(const Duration(days: 6));
  final g = haftalikGostergeler(v, pazartesi);
  final oz = canliHayvanOzeti(v, pazartesi, son);
  final gunler = v.gunlukDonem(pazartesi, son);
  final tarim = [
    for (final f in v.tarimDonem(pazartesi, son)) if (!f.kontrolBekliyor) f
  ];

  final doc = pw.Document(
      title: '${a.baslik} — ${isoHafta(pazartesi)}. Hafta',
      author: a.hazirlayan);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 28),
    theme: tema,
    footer: (c) => _altBilgi(c, a),
    build: (c) => [
      _bant(a, 'Haftalık Rapor',
          '${isoHafta(pazartesi)}. Hafta  ·  ${tarihKisa(pazartesi)} – ${tarihKisa(son)}'),
      ..._hitap(a,
          '${isoHafta(pazartesi)}. hafta (${tarihKisa(pazartesi)} – ${tarihKisa(son)}) çiftlik verileri aşağıda bilgilerinize sunulmuştur.'),
      _bolum('Özet Göstergeler'),
      _gostergeler(g,
          haftalik: true,
          ko: kayipOzeti(v, pazartesi, son),
          eskOlen: kayipOzeti(v, pazartesi, son, eskDahil: true)?.toplam),
      if (gunler.isNotEmpty)
        _not('Süt verisi: ${tarihKisa(gunler.first.tarih)} – ${tarihKisa(gunler.last.tarih)} (${gunler.length} gün). '
            'Toplam hayvan ve sağılan: haftanın son veri günü.'),
      _bolum('Günlük Süt Üretimi'),
      if (gunler.isEmpty)
        _not('Bu hafta için günlük süt verisi bulunmuyor.')
      else
        _tablo(gunlukSutBasliklari, gunlukSutSatirlari(gunler),
            genislik: const {0: pw.FlexColumnWidth(1.6)}, vurguSon: true),
      _bolum('Canlı Hayvan — İşletme Bazlı'),
      if (oz.ozetGunu == null)
        _not('Bu hafta için işletme özeti bulunmuyor.')
      else ...[
        _tablo(isletmeBasliklari, isletmeSatirlari(oz),
            genislik: _isletmeGenislik, vurguSon: true, kucuk: true),
        _not('Personel, hayvan, sağılan: ${tarihKisa(oz.ozetGunu!)}; süt ve olaylar: hafta toplamı.'),
      ],
      ..._hareketler(v, pazartesi, son),
      _bolum('Sürü Değişimi — Fethiye / Erentepe'),
      if (gunler.isEmpty)
        _not('Bu hafta için günlük veri bulunmuyor.')
      else
        _tablo(
            suruBasliklari(gunAy(gunler.first.tarih), gunAy(gunler.last.tarih)),
            suruSatirlari(gunler.first, gunler.last),
            genislik: _suruGenislik),
      _bolum('Tarımsal Faaliyetler'),
      if (yoneticiOzeti(tarim).isEmpty)
        _not('Bu hafta için raporlanacak tarımsal faaliyet bulunmuyor.')
      else
        _tablo(const ['Çiftlik', 'Haftalık Özet'], [
          for (final o in yoneticiOzeti(tarim))
            [o.ciftlik, _maddeler(o.maddeler)]
        ],
            genislik: const {
              0: pw.FlexColumnWidth(1.1),
              1: pw.FlexColumnWidth(6.3),
            },
            metin: const {0, 1}),
      if (v.ekim.isNotEmpty) ...[
        _bolum('Ekim Alanları (dekar)'),
        _tablo(ekimBasliklari, ekimSatirlari(v.ekim),
            metin: const {0, 1}, vurguSon: true),
      ],
      if (v.hasat.isNotEmpty) ...[
        _bolum('Hasat / Verim Özeti'),
        _tablo(hasatBasliklari, hasatSatirlari(v.hasat),
            genislik: const {0: pw.FlexColumnWidth(2.6)}, metin: const {0, 1}),
      ],
      if (v.besi.isNotEmpty) ...[
        _bolum('Besi Planı ve Kesim'),
        _tablo(besiBasliklari, besiSatirlari(v.besi), vurguSon: true),
      ],
      _dipnot(),
      ..._imza(a),
    ],
  ));
  return doc.save();
}

// ---------------------------------------------------------------------------
// Parçalar
// ---------------------------------------------------------------------------

const _isletmeGenislik = {
  0: pw.FlexColumnWidth(3.2),
  6: pw.FlexColumnWidth(1.1),
  7: pw.FlexColumnWidth(1.5),
  9: pw.FlexColumnWidth(1.4),
};

const _suruGenislik = {0: pw.FlexColumnWidth(2.2)};

pw.Widget _bant(RaporAyari a, String tur, String donem) {
  return pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: const pw.BoxDecoration(
      color: _ana,
      borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(a.baslik,
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              pw.Text('$tur  ·  $donem',
                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Rapor tarihi: ${tarihKisa(DateTime.now())}',
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 8.5)),
            if (a.hazirlayan.trim().isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text('Hazırlayan: ${a.hazirlayan.trim()}',
                  style:
                      const pw.TextStyle(color: PdfColors.white, fontSize: 8.5)),
            ],
          ],
        ),
      ],
    ),
  );
}

List<pw.Widget> _hitap(RaporAyari a, String cumle) {
  if (a.alici.trim().isEmpty) return [pw.SizedBox(height: 4)];
  return [
    pw.SizedBox(height: 10),
    pw.Text('${a.alici.trim()},', style: const pw.TextStyle(fontSize: 10)),
    pw.SizedBox(height: 3),
    pw.Text(cumle, style: const pw.TextStyle(fontSize: 10)),
  ];
}

pw.Widget _bolum(String baslik) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 12, bottom: 5),
      child: pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 3),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _ana, width: 1.2)),
        ),
        child: pw.Text(baslik,
            style: pw.TextStyle(
                fontSize: 11, fontWeight: pw.FontWeight.bold, color: _anaKoyu)),
      ),
    );

pw.Widget _not(String s) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 3),
      child: pw.Text(s, style: const pw.TextStyle(fontSize: 7.5, color: _soluk)),
    );

pw.Widget _gostergeler(Gostergeler g,
    {required bool haftalik,
    ({double toplam, String aciklama})? ko,
    double? eskOlen}) {
  final kutular = <(String, String, String?)>[
    ('Toplam Hayvan', sayi(g.toplamHayvan), null),
    ('Sağılan Hayvan', sayi(g.sagilan), null),
    (
      haftalik ? 'Haftalık Süt' : 'Süt Üretimi',
      kg(g.sut),
      g.ortVerim == null
          ? null
          : 'Ort. ${sayi(g.ortVerim, ondalik: 1)} kg/baş${haftalik ? '/gün' : ''}'
    ),
    ('Satılan Süt', kg(g.satilan), 'Fethiye + Erentepe'),
    (
      'Personel / Taşeron',
      '${sayi(g.ciftlikPersonel)} / ${sayi(g.ciftlikTaseron)}',
      null
    ),
    (
      'Doğan Buzağı',
      sayi(g.dogan),
      g.olenBuzagi == null ? null : 'Ölen buzağı: ${sayi(g.olenBuzagi)}'
    ),
    ('Hayvan Kayıpları', sayi(ko?.toplam ?? g.kayip), ko?.aciklama ?? g.kayipAyrinti),
    ('Kesilen Dana', sayi(g.kesilenDana), null),
    if (haftalik) ('İnek/Düve Kesim-Satış', sayi(g.kesimSatis), null),
  ];

  final eskPers = g.eskPersonel ?? 0, eskTas = g.eskTaseron ?? 0;
  final eskKutular = <(String, String, String?)>[
    ('Besi Hayvanı', sayi(g.eskBesiHayvan), null),
    ('Kesilen Dana', sayi(g.eskKesilen), haftalik ? 'Hafta toplamı' : null),
    if ((eskOlen ?? g.eskOlenDana ?? 0) > 0)
      ('Ölen Dana', sayi(eskOlen ?? g.eskOlenDana), null),
    if (eskPers > 0 || eskTas > 0)
      ('Personel / Taşeron', '${sayi(eskPers)} / ${sayi(eskTas)}', null),
  ];

  pw.Widget kutu((String, String, String?) k) => pw.Container(
        margin: const pw.EdgeInsets.all(2.5),
        padding: const pw.EdgeInsets.fromLTRB(7, 6, 7, 6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _cizgi, width: 0.7),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(k.$1, style: const pw.TextStyle(fontSize: 7.5, color: _soluk)),
            pw.SizedBox(height: 2),
            pw.Text(k.$2,
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold, color: _yazi)),
            pw.Text(k.$3 ?? ' ',
                style: const pw.TextStyle(fontSize: 6.5, color: _soluk)),
          ],
        ),
      );

  pw.Widget izgara(List<(String, String, String?)> liste) => pw.Table(
        children: [
          for (var i = 0; i < liste.length; i += 4)
            pw.TableRow(children: [
              for (var j = i; j < i + 4; j++)
                j < liste.length ? kutu(liste[j]) : pw.SizedBox(),
            ]),
        ],
      );

  pw.Widget altBaslik(String baslik, String? aciklama) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4, bottom: 2, left: 2),
        child: pw.Row(children: [
          pw.Text(baslik,
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold, color: _anaKoyu)),
          if (aciklama != null)
            pw.Text('  ·  $aciklama',
                style: const pw.TextStyle(fontSize: 7.5, color: _soluk)),
        ]),
      );

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      altBaslik('Çiftliklerimiz', null),
      izgara(kutular),
      if (g.eskVar) ...[
        pw.SizedBox(height: 4),
        altBaslik('ESK-Taşağıl Çiftliği (Besi)',
            'Çiftliklerimiz toplamına dahil değildir'),
        izgara(eskKutular),
      ],
    ],
  );
}

/// İşletme raporlarından: sürüden çıkanlar/kayıplar ve doğum/girişler.
List<pw.Widget> _hareketler(RaporVerisi v, DateTime bas, DateTime son) {
  const kisa = ['Fethiye', 'Erentepe', 'Aslım', 'ESK-Taşağıl'];
  List<pw.Widget> tablo(String baslik, Map<String, Map<String, double>> t) {
    if (t.isEmpty) return const [];
    final satirlar = <List<String>>[];
    final top = List<double>.filled(detayIsletmeleri.length, 0);
    for (final e in t.entries) {
      final degerler = [for (final i in detayIsletmeleri) e.value[i] ?? 0];
      for (var k = 0; k < degerler.length; k++) {
        top[k] += degerler[k];
      }
      satirlar.add([
        e.key,
        for (final d in degerler) sayiTire(d),
        sayi(degerler.fold<double>(0, (a, b) => a + b)),
      ]);
    }
    satirlar.add([
      'TOPLAM',
      for (final d in top) sayiTire(d),
      sayi(top.fold<double>(0, (a, b) => a + b)),
    ]);
    return [
      _bolum(baslik),
      _tablo(['Gösterge', ...kisa, 'Toplam'], satirlar,
          genislik: const {0: pw.FlexColumnWidth(2.6)}, vurguSon: true, kucuk: true),
    ];
  }

  final tekGun = gunu(bas) == gunu(son);
  final ek = tekGun ? '' : ' (hafta toplamı)';
  final ekli = [for (final b in v.bulgularDonem(bas, son)) if (b.eklendi) b];
  return [
    if (ekli.isNotEmpty) ...[
      _bolum('Diğer Kaynaklardan Bilgiler$ek'),
      _tablo(const ['Konu', 'Çiftlik', 'Bilgi', 'Tarih'], [
        for (final b in ekli) [b.konu, b.ciftlik, b.bulgu, tarihKisa(b.gun)]
      ], genislik: const {
        0: pw.FlexColumnWidth(1.6),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(4),
        3: pw.FlexColumnWidth(1.1),
      }, metin: const {0, 1, 2}, kucuk: true),
    ],
    ...tablo('Sürüden Çıkanlar ve Kayıplar$ek',
        hareketTablosu(v, bas, son, cikis: true)),
    ...tablo('Doğumlar ve Hayvan Girişleri$ek',
        hareketTablosu(v, bas, son, cikis: false)),
  ];
}

String _maddeler(List<String> m) =>
    m.length == 1 ? m.first : m.map((e) => '• $e').join('\n');

pw.Widget _tablo(
  List<String> basliklar,
  List<List<String>> satirlar, {
  Map<int, pw.TableColumnWidth> genislik = const {},
  Set<int> metin = const {0},
  bool vurguSon = false,
  bool kucuk = false,
}) {
  final boy = kucuk ? 7.0 : 8.0;
  pw.Widget hucre(String s, int i, {bool baslik = false, bool kalin = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(
          s,
          textAlign: metin.contains(i) ? pw.TextAlign.left : pw.TextAlign.right,
          style: pw.TextStyle(
            fontSize: baslik ? boy - 0.5 : boy,
            fontWeight:
                baslik || kalin ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: baslik ? _anaKoyu : _yazi,
          ),
        ),
      );

  return pw.Table(
    columnWidths: {
      for (var i = 0; i < basliklar.length; i++)
        i: genislik[i] ?? const pw.FlexColumnWidth(1),
    },
    border: const pw.TableBorder(
      top: pw.BorderSide(color: _cizgi, width: 0.6),
      bottom: pw.BorderSide(color: _cizgi, width: 0.6),
      horizontalInside: pw.BorderSide(color: _cizgi, width: 0.4),
    ),
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    children: [
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: _anaAcik),
        children: [
          for (var i = 0; i < basliklar.length; i++)
            hucre(basliklar[i], i, baslik: true)
        ],
      ),
      for (var r = 0; r < satirlar.length; r++)
        pw.TableRow(
          decoration: vurguSon && r == satirlar.length - 1
              ? const pw.BoxDecoration(color: _vurgu)
              : null,
          children: [
            for (var i = 0; i < basliklar.length; i++)
              hucre(i < satirlar[r].length ? satirlar[r][i] : '', i,
                  kalin: vurguSon && r == satirlar.length - 1),
          ],
        ),
    ],
  );
}

pw.Widget _dipnot() => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 12),
      child: pw.Text(
        '* ESK-Taşağıl besi hayvanları ve kesilen danaları çiftlikler toplamına '
        'dahil değildir. Özet göstergelerde "Çiftliklerimiz" personel/taşeron '
        'sayısı ESK-Taşağıl hariçtir; işletme tablosundaki ÇİFTLİKLER TOPLAM '
        'satırında ESK-Taşağıl personeli dahildir. "Diğer" satırı '
        'güvenlik, Çumpaş, Konya Merkez ve yönetici personelidir. '
        'Kaynak: CANLI HAYVAN GÜNCEL ÖZET RAPORU ve TARIM GÜNLÜK İCMAL kayıtları.',
        style: const pw.TextStyle(fontSize: 7, color: _soluk),
      ),
    );

List<pw.Widget> _imza(RaporAyari a) {
  final ad = a.hazirlayan.trim();
  if (ad.isEmpty) return const [];
  return [
    pw.SizedBox(height: 18),
    pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(ad,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          if (a.unvan.trim().isNotEmpty)
            pw.Text(a.unvan.trim(), style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    ),
  ];
}

pw.Widget _altBilgi(pw.Context c, RaporAyari a) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _cizgi, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(a.baslik, style: const pw.TextStyle(fontSize: 7, color: _soluk)),
          pw.Text('Sayfa ${c.pageNumber} / ${c.pagesCount}',
              style: const pw.TextStyle(fontSize: 7, color: _soluk)),
        ],
      ),
    );
