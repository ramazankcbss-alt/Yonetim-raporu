import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/ciftlik_rapor_tam.dart';
import '../veri/stok_suru.dart' show kUretimYerleri;
import 'bilesenler.dart';
import 'esk.dart' show tl;

const _ay = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
String _uyAdi(String k) => k.isEmpty ? 'Tüm çiftlikler' : (kUretimYerleri[k] ?? k);

CiftlikRaporTam _veri() => VeriDeposu.ben.veri?.ciftlikRaporTam ?? const CiftlikRaporTam();

Widget _yok() => const Padding(
    padding: EdgeInsets.all(16),
    child: BilgiKutusu(
        yazi: 'Çiftlik Raporları E-Tablo kopyası henüz okunmadı. "06 – Çiftlikler Rapor 2026" klasöründe dosyanın '
            'Google E-Tablolar kopyası olmalı ve Apps Script güncel olmalı.'));

/// Çiftlik Sonuçları › Gider Raporu: muhasebe gider raporu, grup × ay (yıl ve çiftlik seçilir).
class CrGiderSekmesi extends StatefulWidget {
  const CrGiderSekmesi({super.key});
  @override
  State<CrGiderSekmesi> createState() => _CrGiderSekmesiState();
}

class _CrGiderSekmesiState extends State<CrGiderSekmesi> {
  int? _yil;
  String _uy = '';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: VeriDeposu.ben,
        builder: (context, _) {
          final d = _veri();
          if (d.gider.isEmpty) return _yok();
          final yillar = d.giderYillari;
          final yil = _yil ?? yillar.last;
          final uylar = ({for (final g in d.gider) g.uy}.toList()..sort());
          final m = d.giderGrupAy(yil, uy: _uy);
          final aylar = ({for (final x in m.values) ...x.keys}.toList()..sort());
          double top(Map<int, double> x) => x.values.fold(0.0, (t, v) => t + v);
          final gruplar = m.entries.toList()..sort((a, b) => top(b.value).compareTo(top(a.value)));
          final genel = gruplar.fold(0.0, (t, e) => t + top(e.value));
          return ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 24), children: [
            BilgiKutusu(
                yazi: 'Kaynak: ${d.dosya} › Çiftlikler Gider Raporu Detay (muhasebe). Personel giderleri (işçi ve memur) '
                    'KVKK gereği yalnızca grup toplamı olarak gösterilir.'),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (final y in yillar)
                ChoiceChip(label: Text('$y'), selected: y == yil, onSelected: (_) => setState(() => _yil = y)),
            ]),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (final u in ['', ...uylar])
                ChoiceChip(label: Text(_uyAdi(u)), selected: u == _uy, onSelected: (_) => setState(() => _uy = u)),
            ]),
            BolumBasligi('$yil · ${_uyAdi(_uy)} · toplam ${tl(genel)}', ikon: Icons.receipt_long_outlined),
            VeriTablosu(
              basliklar: ['Gider grubu', for (final a in aylar) _ay[a - 1], 'Toplam'],
              metinSutunlari: const {0},
              ilkSutunGenislik: 200,
              vurguluSonSatir: true,
              satirlar: [
                for (final e in gruplar)
                  [e.key.replaceFirst(RegExp(r'^\d+\.\s*'), ''), for (final a in aylar) _mn(e.value[a] ?? 0), _mn(top(e.value))],
                [
                  'Genel toplam',
                  for (final a in aylar) _mn(gruplar.fold(0.0, (t, e) => t + (e.value[a] ?? 0))),
                  _mn(genel),
                ],
              ],
            ),
            const SizedBox(height: 4),
            const Text('Tutarlar bin ₺.', style: TextStyle(fontSize: 12, color: Renk.soluk)),
          ]);
        },
      );
}

String _mn(double v) => sayi(v / 1000);

/// Çiftlik Sonuçları › Yem ve Tüketim: besi-düve ve sağmal yem tüketimi, tarımsal alan girdi tüketimi.
class CrTuketimSekmesi extends StatelessWidget {
  const CrTuketimSekmesi({super.key});

  Widget _tablo(String baslik, IconData ikon, List<CrTuketim> l, {String? aciklama}) {
    final m = CiftlikRaporTam.malzemeToplam(l).entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2));
    final top = m.fold(0.0, (t, e) => t + e.value.$2);
    final yillar = ({for (final x in l) x.yil}.toList()..sort());
    final aylar = ({for (final x in l) x.yil * 100 + x.ay}.toList()..sort());
    final donem = aylar.isEmpty
        ? ''
        : '${_ay[aylar.first % 100 - 1]} ${aylar.first ~/ 100} – ${_ay[aylar.last % 100 - 1]} ${aylar.last ~/ 100}';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BolumBasligi('$baslik · ${tl(top)}', ikon: ikon, aciklama: [donem, if (aciklama != null) aciklama].join(' · ')),
      if (yillar.isNotEmpty)
        VeriTablosu(
          basliklar: const ['Malzeme', 'Miktar', 'Tutar', 'Ort. fiyat'],
          metinSutunlari: const {0},
          ilkSutunGenislik: 200,
          satirlar: [
            for (final e in m)
              [e.key, sayi(e.value.$1), tl(e.value.$2), e.value.$1 > 0 ? sayi(e.value.$2 / e.value.$1, ondalik: 2) : '—'],
          ],
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: VeriDeposu.ben,
        builder: (context, _) {
          final d = _veri();
          if (d.bos) return _yok();
          final besiCf = <String, double>{};
          for (final x in d.yem) {
            besiCf[_uyAdi(x.uy)] = (besiCf[_uyAdi(x.uy)] ?? 0) + x.tutar;
          }
          return ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 24), children: [
            BilgiKutusu(
                yazi: 'Kaynak: ${d.dosya} (${d.sayfalar.length} sayfanın tamamı okundu). Besi-düve tüketimi hayvan bazındaki '
                    'kayıtlardan toplanmıştır; kulak küpe numarası uygulamaya alınmaz.'),
            for (final h in d.hatalar)
              Padding(padding: const EdgeInsets.only(top: 6), child: BilgiKutusu(uyari: true, yazi: 'Okunamadı: $h')),
            _tablo('Besi ve düve yem tüketimi', Icons.grass_outlined, d.yem,
                aciklama: besiCf.entries.map((e) => '${e.key} ${tl(e.value)}').join(', ')),
            _tablo('Sağmal (duran varlık) yem tüketimi', Icons.water_drop_outlined, d.duranVarlik),
            _tablo('Tarımsal alan girdi tüketimi', Icons.agriculture_outlined, d.tarim),
            const BolumBasligi('Dosyadaki sayfalar', ikon: Icons.table_rows_outlined),
            VeriTablosu(
              basliklar: const ['Sayfa', 'Satır', 'Sütun'],
              metinSutunlari: const {0},
              ilkSutunGenislik: 220,
              satirlar: [for (final s in d.sayfalar) [s.ad, sayi(s.satir.toDouble()), '${s.sutun}']],
            ),
          ]);
        },
      );
}
