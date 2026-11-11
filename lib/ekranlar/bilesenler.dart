import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../bicim.dart';
import '../tema.dart';
import '../veri/model.dart';

/// Gösterge kartı: başlık, büyük değer, isteğe bağlı alt yazı.
class GostergeKarti extends StatelessWidget {
  const GostergeKarti({
    super.key,
    required this.baslik,
    required this.deger,
    required this.ikon,
    this.renk = Renk.ana,
    this.alt,
  });

  final String baslik;
  final String deger;
  final IconData ikon;
  final Color renk;
  final String? alt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Renk.kart,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Renk.cizgi),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: renk.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(ikon, size: 18, color: renk),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(baslik,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, color: Renk.soluk, height: 1.2)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(deger,
                maxLines: 1,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Renk.yazi)),
          ),
          if (alt != null) ...[
            const SizedBox(height: 2),
            Text(alt!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Renk.soluk)),
          ],
        ],
      ),
    );
  }
}

/// Kartları telefonda 2, tablette 4 sütun dizer.
class GostergeIzgarasi extends StatelessWidget {
  const GostergeIzgarasi({super.key, required this.kartlar});

  final List<Widget> kartlar;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final sutun = c.maxWidth >= 640 ? 4 : 2;
      const bosluk = 10.0;
      final w = (c.maxWidth - bosluk * (sutun - 1)) / sutun;
      return Wrap(
        spacing: bosluk,
        runSpacing: bosluk,
        children: [for (final k in kartlar) SizedBox(width: w, child: k)],
      );
    });
  }
}

/// Yatay kaydırılabilir sade tablo.
class VeriTablosu extends StatelessWidget {
  const VeriTablosu({
    super.key,
    required this.basliklar,
    required this.satirlar,
    this.vurguluSonSatir = false,
    this.ilkSutunGenislik = 150,
    this.metinSutunlari = const {0},
  });

  final List<String> basliklar;
  final List<List<String>> satirlar;
  final bool vurguluSonSatir;
  final double ilkSutunGenislik;

  /// Sola yaslanacak sütunlar (diğerleri sayısal, sağa yaslı).
  final Set<int> metinSutunlari;

  @override
  Widget build(BuildContext context) {
    TableRow satir(List<String> h, {bool baslik = false, bool vurgu = false}) {
      return TableRow(
        decoration: BoxDecoration(
          color: baslik
              ? Renk.anaAcik
              : vurgu
                  ? const Color(0xFFF1F5F4)
                  : null,
          border: const Border(bottom: BorderSide(color: Renk.cizgi)),
        ),
        children: [
          for (var i = 0; i < basliklar.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(
                i < h.length ? h[i] : '',
                textAlign: metinSutunlari.contains(i)
                    ? TextAlign.left
                    : TextAlign.right,
                style: TextStyle(
                  fontSize: baslik ? 12 : 13,
                  fontWeight:
                      baslik || vurgu ? FontWeight.w700 : FontWeight.w400,
                  color: baslik ? Renk.anaKoyu : Renk.yazi,
                ),
              ),
            ),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        columnWidths: {0: FixedColumnWidth(ilkSutunGenislik)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          satir(basliklar, baslik: true),
          for (var i = 0; i < satirlar.length; i++)
            satir(satirlar[i],
                vurgu: vurguluSonSatir && i == satirlar.length - 1),
        ],
      ),
    );
  }
}

/// Günlük süt grafiği: Fethiye + Erentepe yığılmış sütunlar.
class SutGrafigi extends StatelessWidget {
  const SutGrafigi({super.key, required this.gunler});

  final List<GunlukSatir> gunler;

  static const fethiyeRenk = Renk.ana;
  static const erentepeRenk = Color(0xFF7CC4A0);

  @override
  Widget build(BuildContext context) {
    if (gunler.isEmpty) {
      return const BosDurum(
          ikon: Icons.bar_chart, yazi: 'Bu dönemde süt kaydı yok.');
    }
    final enCok = gunler.map((g) => g.sut).fold<double>(0, math.max);
    const yukseklik = 150.0;
    return Column(
      children: [
        SizedBox(
          height: yukseklik + 44,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final g in gunler)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(sayi(g.sut),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Renk.yazi)),
                        ),
                        const SizedBox(height: 4),
                        _cubuk(g.erentepe.sut, enCok, yukseklik, erentepeRenk,
                            ust: true),
                        _cubuk(g.fethiye.sut, enCok, yukseklik, fethiyeRenk),
                        const SizedBox(height: 6),
                        Text(gunKisa(g.tarih),
                            style: const TextStyle(
                                fontSize: 11, color: Renk.soluk)),
                        Text(gunAy(g.tarih),
                            style: const TextStyle(
                                fontSize: 10, color: Renk.soluk)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Lejant(renk: fethiyeRenk, yazi: 'Fethiye'),
            SizedBox(width: 16),
            _Lejant(renk: erentepeRenk, yazi: 'Erentepe'),
          ],
        ),
      ],
    );
  }

  Widget _cubuk(double v, double enCok, double h, Color renk,
      {bool ust = false}) {
    final y = enCok <= 0 ? 0.0 : (v / enCok) * h;
    return Container(
      height: y,
      decoration: BoxDecoration(
        color: renk,
        borderRadius: ust
            ? const BorderRadius.vertical(top: Radius.circular(4))
            : BorderRadius.zero,
      ),
    );
  }
}

class _Lejant extends StatelessWidget {
  const _Lejant({required this.renk, required this.yazi});
  final Color renk;
  final String yazi;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                  color: renk, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(yazi, style: const TextStyle(fontSize: 12, color: Renk.soluk)),
        ],
      );
}

/// Önceki / sonraki okları olan açılır seçici (gün ya da hafta).
class Secici<T> extends StatelessWidget {
  const Secici({
    super.key,
    required this.secenekler,
    required this.secili,
    required this.etiket,
    required this.degisti,
  });

  /// Yeniden eskiye sıralı.
  final List<T> secenekler;
  final T secili;
  final String Function(T) etiket;
  final ValueChanged<T> degisti;

  @override
  Widget build(BuildContext context) {
    final i = secenekler.indexOf(secili);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Renk.kart,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Renk.cizgi),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Önceki',
            icon: const Icon(Icons.chevron_left),
            onPressed: i >= 0 && i < secenekler.length - 1
                ? () => degisti(secenekler[i + 1])
                : null,
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: i >= 0 ? secili : null,
                isExpanded: true,
                alignment: Alignment.center,
                items: [
                  for (final s in secenekler)
                    DropdownMenuItem<T>(
                      value: s,
                      alignment: Alignment.center,
                      child: Text(etiket(s),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) degisti(v);
                },
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sonraki',
            icon: const Icon(Icons.chevron_right),
            onPressed: i > 0 ? () => degisti(secenekler[i - 1]) : null,
          ),
        ],
      ),
    );
  }
}

Color ciftlikRengi(String c) {
  switch (c) {
    case 'Şekersüt':
      return Renk.mavi;
    case 'Aslım':
      return Renk.amber;
    case 'Taşağıl':
      return Renk.turuncu;
    case 'Fidanlık':
      return Renk.yesil;
  }
  return Renk.soluk;
}

/// Bir tarım faaliyeti satırı.
class FaaliyetSatiri extends StatelessWidget {
  const FaaliyetSatiri({super.key, required this.kayit, this.tarihGoster = true});

  final TarimKaydi kayit;
  final bool tarihGoster;

  @override
  Widget build(BuildContext context) {
    final r = ciftlikRengi(kayit.ciftlik);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 38,
            margin: const EdgeInsets.only(right: 10, top: 2),
            decoration: BoxDecoration(
                color: r, borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tarihGoster
                      ? '${kayit.ciftlik} · ${tarihKisa(kayit.tarih)}'
                      : kayit.ciftlik,
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700, color: r),
                ),
                const SizedBox(height: 2),
                Text(kayit.faaliyet,
                    style: const TextStyle(
                        fontSize: 14, color: Renk.yazi, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Veri yokken gösterilen ince uyarı kutusu.
class BilgiKutusu extends StatelessWidget {
  const BilgiKutusu({super.key, required this.yazi, this.uyari = false});

  final String yazi;
  final bool uyari;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: uyari ? Renk.amberAcik : Renk.maviAcik,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(uyari ? Icons.warning_amber_rounded : Icons.info_outline,
                size: 20, color: uyari ? Renk.amber : Renk.mavi),
            const SizedBox(width: 8),
            Expanded(
                child: Text(yazi,
                    style: const TextStyle(fontSize: 13.5, color: Renk.yazi))),
          ],
        ),
      );
}
