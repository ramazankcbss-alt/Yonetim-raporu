import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../bicim.dart';
import '../servis/veri_servisi.dart';
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
  final faaliyetler = v.tarimDonem(gun, gun);
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
      _gostergeler(g, haftalik: false),
      _bolum('Canlı Hayvan — İşletme Bazlı'),
      if (oz.ozetGunu == null)
        _not('Bu gün için işletme özeti bulunmuyor.')
      else
        _tablo(isletmeBasliklari, isletmeSatirlari(oz),
            genislik: _isletmeGenislik, vurguSon: true, kucuk: true),
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
        _tablo(const ['Çiftlik', 'Faaliyet'],
            [for (final f in faaliyetler) [f.ciftlik, f.faaliyet]],
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
            [f.ciftlik, tarihKisa(f.tarih), f.faaliyet]
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
  final tarim = v.tarimDonem(pazartesi, son);

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
      _gostergeler(g, haftalik: true),
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
      _bolum('Sürü Değişimi — Fethiye / Erentepe'),
      if (gunler.isEmpty)
        _not('Bu hafta için günlük veri bulunmuyor.')
      else
        _tablo(
            suruBasliklari(gunAy(gunler.first.tarih), gunAy(gunler.last.tarih)),
            suruSatirlari(gunler.first, gunler.last),
            genislik: _suruGenislik),
      _bolum('Tarımsal Faaliyetler'),
      if (tarim.isEmpty)
        _not('Bu hafta için tarım kaydı bulunmuyor.')
      else
        _tablo(const ['Tarih', 'Çiftlik', 'Faaliyet'], [
          for (final f in tarim) [tarihKisa(f.tarih), f.ciftlik, f.faaliyet]
        ],
            genislik: const {
              0: pw.FlexColumnWidth(1.1),
              1: pw.FlexColumnWidth(1.1),
              2: pw.FlexColumnWidth(5.2),
            },
            metin: const {0, 1, 2}),
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

pw.Widget _gostergeler(Gostergeler g, {required bool haftalik}) {
  final kutular = <(String, String, String?)>[
    ('Toplam Hayvan', sayi(g.toplamHayvan), 'ESK-Taşağıl besi hariç'),
    ('Sağılan Hayvan', sayi(g.sagilan), null),
    (
      haftalik ? 'Haftalık Süt' : 'Süt Üretimi',
      kg(g.sut),
      g.ortVerim == null
          ? null
          : 'Ort. ${sayi(g.ortVerim, ondalik: 1)} kg/baş${haftalik ? '/gün' : ''}'
    ),
    ('Satılan Süt', kg(g.satilan), 'Fethiye + Erentepe'),
    ('Personel / Taşeron', '${sayi(g.personel)} / ${sayi(g.taseron)}', null),
    (
      'Doğan Buzağı',
      sayi(g.dogan),
      g.olenBuzagi == null ? null : 'Ölen buzağı: ${sayi(g.olenBuzagi)}'
    ),
    (
      'Kesilen Dana',
      sayi(g.kesilenDana),
      g.eskKesilen == null ? null : 'ESK-Taşağıl: ${sayi(g.eskKesilen)}'
    ),
    haftalik
        ? ('İnek/Düve Kesim-Satış', sayi(g.kesimSatis), null)
        : ('ESK-Taşağıl Besi', sayi(g.eskBesiHayvan), 'Toplama dahil değil'),
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

  return pw.Table(
    children: [
      for (var i = 0; i < kutular.length; i += 4)
        pw.TableRow(children: [
          for (var j = i; j < i + 4 && j < kutular.length; j++) kutu(kutular[j]),
        ]),
    ],
  );
}

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
        'dahil değildir; personel ve taşeron toplamına dahildir. "Diğer" satırı '
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
