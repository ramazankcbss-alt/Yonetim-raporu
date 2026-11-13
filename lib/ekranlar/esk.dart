import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'bilesenler.dart';

/// ESK (Et ve Süt Kurumu) – Taşağıl bakım besleme: aylık kâr/zarar,
/// başabaş (minimum hayvan), fiyatlar, alımlar, öneriler ve eksik belgeler.
class EskEkran extends StatelessWidget {
  const EskEkran({super.key, required this.veri});

  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VeriDeposu.ben,
      builder: (context, _) {
        final v = VeriDeposu.ben.veri ?? veri;
        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('ESK – Et ve Süt Kurumu'),
              actions: const [TabloGuncelleButonu()],
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Özet'),
                  Tab(text: 'Aylık'),
                  Tab(text: 'Öneriler'),
                  Tab(text: 'Eksikler'),
                ],
              ),
            ),
            body: v.eskAylik.isEmpty && v.eskBilgi.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: BilgiKutusu(
                        yazi: "ESK verisi henüz gelmedi. Tablodaki 'ESK_Aylık' "
                            "ve 'ESK_Bilgi' sayfalarını okuyabilmek için "
                            'Apps Script güncel olmalı.'),
                  )
                : TabBarView(children: [
                    _Ozet(veri: v),
                    _Aylik(veri: v),
                    _Liste(bilgi: v.eskBilgi, bolum: 'Öneri'),
                    _Liste(bilgi: v.eskBilgi, bolum: 'Eksik'),
                  ]),
          ),
        );
      },
    );
  }
}

String tl(double? v) {
  if (v == null) return '—';
  final m = v.abs() >= 1000000;
  final s = m ? '${sayi(v / 1000000, ondalik: 2)} milyon' : sayi(v);
  return '$s TL';
}

Color kzRenk(double? v) =>
    v == null ? Renk.soluk : (v >= 0 ? Renk.yesil : Renk.kirmizi);

/// Başabaş (minimum günlük ortalama baş) değeri, yoksa null.
double? eskBasabas(List<EskBilgi> b) {
  for (final x in b) {
    if (x.bolum == 'Başabaş' && trKucuk(x.baslik).contains('minimum')) {
      return x.sayi ?? sayiOku(x.deger);
    }
  }
  return null;
}

class _Ozet extends StatelessWidget {
  const _Ozet({required this.veri});
  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) {
    final b = veri.eskBilgi;
    final min = eskBasabas(b);
    final aylar = veri.eskAylik.where((a) => a.ortBas != null).toList();
    final son = aylar.isEmpty ? null : aylar.last;
    final altta = son != null && min != null && (son.ortBas ?? 0) < min;
    Iterable<EskBilgi> bol(String ad) => b.where((x) => x.bolum == ad);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        if (min != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: altta ? Renk.kirmiziAcik : Renk.yesilAcik,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Minimum hayvan (başabaş)',
                    style: TextStyle(fontSize: 13, color: Renk.soluk)),
                Text('${sayi(min)} baş / gün ortalama',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Aylık ortalama bunun altına düşerse ay zarar yazar.',
                    style: TextStyle(fontSize: 12.5)),
                if (son != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${son.ay}: ort. ${sayi(son.ortBas)} baş — '
                    '${altta ? 'başabaşın ${sayi(min - (son.ortBas ?? 0))} baş altında' : 'başabaşın üstünde'}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: altta ? Renk.kirmizi : Renk.yesil),
                  ),
                ],
              ],
            ),
          ),
        _Grup(baslik: 'Kâr / zarar', satirlar: bol('Özet')),
        _Grup(baslik: 'Başabaş', satirlar: bol('Başabaş')),
        _Grup(
            baslik: 'Senaryo: günlük ortalama hayvan → aylık sonuç',
            satirlar: bol('Senaryo')),
        _Grup(baslik: 'Fiyatlar', satirlar: bol('Fiyat')),
        _Grup(baslik: 'Faturalar', satirlar: bol('Fatura')),
        _Grup(baslik: 'ESK adına alımlar', satirlar: bol('Alım')),
        _Grup(
            baslik: 'Geçmiş yıllar (ESK öncesi Taşağıl)',
            satirlar: bol('Geçmiş')),
      ],
    );
  }
}

class _Grup extends StatelessWidget {
  const _Grup({required this.baslik, required this.satirlar});
  final String baslik;
  final Iterable<EskBilgi> satirlar;

  @override
  Widget build(BuildContext context) {
    final l = satirlar.toList();
    if (l.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(baslik,
              style:
                  const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Card(
            margin: EdgeInsets.zero,
            child: Column(children: [
              for (final x in l)
                ListTile(
                  dense: true,
                  title: Text(x.baslik,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: x.aciklama.isEmpty ? null : Text(x.aciklama),
                  trailing: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      x.sayi != null
                          ? (x.sayi!.abs() >= 10000 ? tl(x.sayi) : sayi(x.sayi))
                          : x.deger,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: x.sayi != null && x.sayi!.abs() >= 10000
                              ? kzRenk(x.sayi)
                              : Renk.yazi),
                    ),
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Aylik extends StatelessWidget {
  const _Aylik({required this.veri});
  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) {
    final min = eskBasabas(veri.eskBilgi);
    final yillar = <int, List<EskAy>>{};
    for (final a in veri.eskAylik) {
      yillar.putIfAbsent(a.yil, () => []).add(a);
    }
    final sirali = yillar.keys.toList()..sort((a, b) => b.compareTo(a));
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        for (final y in sirali) ...[
          _YilBasligi(yil: y, aylar: yillar[y]!),
          for (final a in yillar[y]!.reversed) _AyKarti(ay: a, basabas: min),
        ],
      ],
    );
  }
}

class _YilBasligi extends StatelessWidget {
  const _YilBasligi({required this.yil, required this.aylar});
  final int yil;
  final List<EskAy> aylar;

  @override
  Widget build(BuildContext context) {
    final kz = aylar.fold<double>(0, (t, a) => t + (a.karZarar ?? 0));
    final gelen = aylar.fold<double>(0, (t, a) => t + (a.gelen ?? 0));
    final kesim = aylar.fold<double>(0, (t, a) => t + (a.kesim ?? 0));
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Text('$yil',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                'Giren ${sayi(gelen)} · Panagro kesim ${sayi(kesim)}',
                style: const TextStyle(color: Renk.soluk, fontSize: 12.5)),
          ),
          Text(tl(kz),
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: kzRenk(kz))),
        ],
      ),
    );
  }
}

class _AyKarti extends StatelessWidget {
  const _AyKarti({required this.ay, this.basabas});
  final EskAy ay;
  final double? basabas;

  @override
  Widget build(BuildContext context) {
    final a = ay;
    final oran = (basabas != null && a.ortBas != null && basabas! > 0)
        ? (a.ortBas! / basabas!).clamp(0.0, 1.6)
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(a.ay,
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w700)),
              ),
              if (a.tahmini || a.devamEdiyor)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: Renk.amberAcik,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(a.durum,
                      style: const TextStyle(
                          fontSize: 11.5,
                          color: Renk.amber,
                          fontWeight: FontWeight.w600)),
                ),
              Text(tl(a.karZarar),
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: kzRenk(a.karZarar))),
            ]),
            if (a.ortBas != null) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 14, runSpacing: 4, children: [
                _Kucuk('Ort. baş', sayi(a.ortBas)),
                _Kucuk('Giren', sayiTire(a.gelen)),
                _Kucuk('Panagro kesim', sayiTire(a.kesim)),
                _Kucuk('Dış kesim', sayiTire(a.disKesim)),
                _Kucuk('Ölen', sayiTire(a.olen)),
                _Kucuk('Hayvan-gün', sayiTire(a.hayvanGun)),
              ]),
            ],
            if (oran != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (oran / 1.6).toDouble(),
                  minHeight: 6,
                  backgroundColor: Renk.cizgi,
                  color: oran >= 1 ? Renk.yesil : Renk.kirmizi,
                ),
              ),
              Text(
                  'Başabaşın %${sayi(oran * 100)}\'i (${sayi(basabas)} baş)',
                  style: const TextStyle(fontSize: 11.5, color: Renk.soluk)),
            ],
            if (a.bakim != null || a.gider != null) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 14, runSpacing: 4, children: [
                if (a.bakim != null) _Kucuk('Bakım geliri', tl(a.bakim)),
                if ((a.kira ?? 0) > 0) _Kucuk('Kira', tl(a.kira)),
                if ((a.sap ?? 0) > 0) _Kucuk('Sap balyası', tl(a.sap)),
                if (a.gider != null) _Kucuk('İşletme gideri', tl(a.gider)),
              ]),
            ],
            if (a.not.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(a.not,
                  style: const TextStyle(fontSize: 11.5, color: Renk.soluk)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Kucuk extends StatelessWidget {
  const _Kucuk(this.etiket, this.deger);
  final String etiket, deger;

  @override
  Widget build(BuildContext context) {
    return Text.rich(TextSpan(children: [
      TextSpan(
          text: '$etiket ',
          style: const TextStyle(fontSize: 12, color: Renk.soluk)),
      TextSpan(
          text: deger,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
    ]));
  }
}

class _Liste extends StatelessWidget {
  const _Liste({required this.bilgi, required this.bolum});
  final List<EskBilgi> bilgi;
  final String bolum;

  @override
  Widget build(BuildContext context) {
    final l = bilgi.where((x) => x.bolum == bolum).toList();
    final eksik = bolum == 'Eksik';
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        if (eksik)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: BilgiKutusu(
                yazi: 'Hesabı kesinleştirmek için bu belgeler gerekiyor. '
                    'İlgili kişilerden mail ile istenip Excel varsa '
                    'paylaşılması rica edilebilir.'),
          ),
        if (l.isEmpty)
          const BilgiKutusu(yazi: 'Kayıt yok.')
        else
          for (final x in l)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(x.baslik,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    if (x.deger.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(eksik ? 'Kimden: ${x.deger}' : x.deger,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: eksik ? Renk.mavi : Renk.ana)),
                    ],
                    if (x.aciklama.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(x.aciklama),
                    ],
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
