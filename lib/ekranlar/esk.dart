import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/esk_rapor.dart';
import '../veri/model.dart';
import 'bilesenler.dart';

/// ESK (Et ve Süt Kurumu) – Taşağıl bakım besleme. Ana ekran bir menüdür:
/// üstte güncel durum, altında raporlar (haftalık, aylık, yıllık), finans,
/// operasyon ve yapılacaklar başlıkları; her başlık kendi sayfasında açılır.
class EskEkran extends StatelessWidget {
  const EskEkran({super.key, required this.veri});

  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VeriDeposu.ben,
      builder: (context, _) {
        final v = VeriDeposu.ben.veri ?? veri;
        return Scaffold(
          appBar: AppBar(
            title: const Text('ESK – Et ve Süt Kurumu'),
            actions: const [TabloGuncelleButonu()],
          ),
          body: v.eskAylik.isEmpty && v.eskBilgi.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: BilgiKutusu(
                      yazi: "ESK verisi henüz gelmedi. Tablodaki 'ESK_Aylık' "
                          "ve 'ESK_Bilgi' sayfalarını okuyabilmek için "
                          'Apps Script güncel olmalı.'),
                )
              : _Menu(veri: v, ilk: veri),
        );
      },
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.veri, required this.ilk});
  final RaporVerisi veri, ilk;

  @override
  Widget build(BuildContext context) {
    final b = veri.eskBilgi;
    int say(String bolum) => b.where((x) => x.bolum == bolum).length;
    EskBilgi? bul(String bolum, String parca) {
      for (final x in b) {
        if (x.bolum == bolum && trKucuk(x.baslik).contains(parca)) return x;
      }
      return null;
    }

    final haftalar = eskHaftalari(veri);
    final yillar = eskYillari(veri.eskAylik);
    final aylar = veri.eskAylik.where((a) => a.ortBas != null).toList();
    final sonAy = aylar.isEmpty ? null : aylar.last;
    final esk = bul('Özet', 'esk dönemi');
    final genel = bul('Özet', 'panagro geneli');

    void ac(String baslik, Widget Function(RaporVerisi) govde) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ListenableBuilder(
          listenable: VeriDeposu.ben,
          builder: (context, _) => Scaffold(
            appBar: AppBar(
                title: Text(baslik), actions: const [TabloGuncelleButonu()]),
            body: govde(VeriDeposu.ben.veri ?? ilk),
          ),
        ),
      ));
    }

    Widget grup(RaporVerisi v, String bolum, String baslik) => ListView(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
          children: [
            _Grup(
                baslik: baslik,
                satirlar: v.eskBilgi.where((x) => x.bolum == bolum)),
          ],
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        _DurumKarti(veri: veri),
        const SizedBox(height: 4),
        const _MenuBaslik('Raporlar'),
        _MenuSatiri(
          ikon: Icons.date_range,
          baslik: 'Haftalık rapor',
          alt: haftalar.isEmpty
              ? 'Günlük veri yok'
              : 'Son hafta ort. ${sayi(haftalar.first.ortBas)} baş · '
                  'kesilen ${sayi(haftalar.first.kesilen)}',
          ac: () => ac('ESK haftalık rapor', (v) => _Haftalik(veri: v)),
        ),
        _MenuSatiri(
          ikon: Icons.calendar_month,
          baslik: 'Aylık rapor',
          alt: sonAy == null
              ? '${veri.eskAylik.length} ay'
              : '${sonAy.ay}: ort. ${sayi(sonAy.ortBas)} baş'
                  '${sonAy.karZarar != null ? ' · ${tl(sonAy.karZarar)}' : ''}',
          ac: () => ac('ESK aylık rapor', (v) => _Aylik(veri: v)),
        ),
        _MenuSatiri(
          ikon: Icons.insert_chart_outlined,
          baslik: 'Yıllık rapor',
          alt: yillar.isEmpty
              ? 'Veri yok'
              : yillar.map((y) => '${y.yil}: ${tl(y.karZarar)}').join(' · '),
          ac: () => ac('ESK yıllık rapor', (v) => _Yillik(veri: v)),
        ),
        const _MenuBaslik('Finans'),
        _MenuSatiri(
          ikon: Icons.account_balance_wallet_outlined,
          baslik: 'Kâr / zarar',
          alt: [
            if (esk?.sayi != null) 'Taşağıl ${tl(esk!.sayi)}',
            if (genel?.sayi != null) 'Panagro geneli ${tl(genel!.sayi)}',
          ].join(' · '),
          ac: () => ac('Kâr / zarar', (v) => grup(v, 'Özet', 'Kâr / zarar')),
        ),
        _MenuSatiri(
          ikon: Icons.balance,
          baslik: 'Başabaş ve senaryolar',
          alt: 'Minimum hayvan, gider kırılımı, doluluk senaryoları',
          ac: () => ac(
              'Başabaş ve senaryolar',
              (v) => ListView(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                    children: [
                      _Grup(
                          baslik: 'Başabaş',
                          satirlar:
                              v.eskBilgi.where((x) => x.bolum == 'Başabaş')),
                      _Grup(
                          baslik:
                              'Senaryo: günlük ortalama hayvan → aylık sonuç',
                          satirlar:
                              v.eskBilgi.where((x) => x.bolum == 'Senaryo')),
                    ],
                  )),
        ),
        _MenuSatiri(
          ikon: Icons.sell_outlined,
          baslik: 'Fiyatlar ve sözleşmeler',
          alt: '${say('Fiyat')} kalem: bakım, kira, kesim, yağ, sakatat, deri, nakliye',
          ac: () => ac('Fiyatlar ve sözleşmeler',
              (v) => grup(v, 'Fiyat', 'Fiyatlar ve sözleşmeler')),
        ),
        _MenuSatiri(
          ikon: Icons.receipt_long_outlined,
          baslik: 'Faturalar',
          alt: '${say('Fatura')} kayıt',
          ac: () => ac('Faturalar', (v) => grup(v, 'Fatura', 'Faturalar')),
        ),
        const _MenuBaslik('Operasyon'),
        _MenuSatiri(
          ikon: Icons.agriculture_outlined,
          baslik: 'Yem, sap ve alımlar',
          alt: '${say('Alım')} kayıt',
          ac: () => ac('Yem, sap ve alımlar',
              (v) => grup(v, 'Alım', 'ESK adına alımlar')),
        ),
        _MenuSatiri(
          ikon: Icons.history,
          baslik: 'Geçmiş yıllar',
          alt: 'ESK öncesi Taşağıl',
          ac: () => ac('Geçmiş yıllar',
              (v) => grup(v, 'Geçmiş', 'Geçmiş yıllar (ESK öncesi Taşağıl)')),
        ),
        const _MenuBaslik('Yapılacaklar'),
        _MenuSatiri(
          ikon: Icons.lightbulb_outline,
          baslik: 'Öneriler',
          alt: '${say('Öneri')} öneri',
          ac: () => ac('Öneriler',
              (v) => _Liste(bilgi: v.eskBilgi, bolum: 'Öneri')),
        ),
        _MenuSatiri(
          ikon: Icons.assignment_late_outlined,
          baslik: 'Eksik belgeler ve kontroller',
          alt: '${say('Eksik')} madde',
          renk: say('Eksik') > 0 ? Renk.amber : null,
          ac: () => ac('Eksik belgeler ve kontroller',
              (v) => _Liste(bilgi: v.eskBilgi, bolum: 'Eksik')),
        ),
      ],
    );
  }
}

class _MenuBaslik extends StatelessWidget {
  const _MenuBaslik(this.yazi);
  final String yazi;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Text(yazi.toUpperCase(),
            style: const TextStyle(
                fontSize: 12.5,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
                color: Renk.soluk)),
      );
}

class _MenuSatiri extends StatelessWidget {
  const _MenuSatiri({
    required this.ikon,
    required this.baslik,
    required this.alt,
    required this.ac,
    this.renk,
  });
  final IconData ikon;
  final String baslik, alt;
  final VoidCallback ac;
  final Color? renk;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Renk.anaAcik,
            child: Icon(ikon, color: renk ?? Renk.ana),
          ),
          title: Text(baslik,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: alt.isEmpty
              ? null
              : Text(alt, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right),
          onTap: ac,
        ),
      );
}

/// Başabaş ve son ayın durumu.
class _DurumKarti extends StatelessWidget {
  const _DurumKarti({required this.veri});
  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) {
    final min = eskBasabas(veri.eskBilgi);
    final aylar = veri.eskAylik.where((a) => a.ortBas != null).toList();
    final son = aylar.isEmpty ? null : aylar.last;
    if (min == null && son == null) return const SizedBox.shrink();
    final altta = son != null && min != null && (son.ortBas ?? 0) < min;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: altta ? Renk.kirmiziAcik : Renk.yesilAcik,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (son != null) ...[
            Text('Güncel durum · ${son.ay}',
                style: const TextStyle(fontSize: 13, color: Renk.soluk)),
            Text('Ortalama ${sayi(son.ortBas)} baş / gün',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ],
          if (min != null) ...[
            const SizedBox(height: 4),
            Text(
              'Başabaş ${sayi(min)} baş. '
              '${son == null ? '' : altta ? 'Başabaşın ${sayi(min - (son.ortBas ?? 0))} baş altında: ay zarar yazar.' : 'Başabaşın üstünde: ay kâr yazar.'}',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: altta ? Renk.kirmizi : Renk.yesil),
            ),
          ],
        ],
      ),
    );
  }
}

class _Haftalik extends StatelessWidget {
  const _Haftalik({required this.veri});
  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) {
    final h = eskHaftalari(veri);
    final min = eskBasabas(veri.eskBilgi);
    final b = EskBirimler.oku(veri.eskBilgi);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        BilgiKutusu(
            yazi: 'Günlük canlı hayvan özetinden hesaplanır. Bakım geliri = '
                'hayvan-gün × ${sayi(b.bakimUcreti)} TL; kira ve işletme gideri '
                'aylık tutarın günlere bölünmesiyle bulunur. Kâr/zarar tahminidir.'),
        const SizedBox(height: 8),
        if (h.isEmpty) const BilgiKutusu(yazi: 'Günlük veri yok.'),
        for (final w in h)
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(haftaEtiketi(w.bas),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                    Text(tl(w.karZarar),
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: kzRenk(w.karZarar))),
                  ]),
                  if (w.eksik)
                    Text('${w.gun} günlük veri',
                        style: const TextStyle(
                            fontSize: 11.5, color: Renk.amber)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 14, runSpacing: 4, children: [
                    _Kucuk('Ort. baş', sayi(w.ortBas)),
                    _Kucuk('Hafta sonu ahırda', sayi(w.sonMevcut)),
                    _Kucuk('Giren', sayi(w.giren)),
                    _Kucuk('Kesilen', sayi(w.kesilen)),
                    _Kucuk('Ölen', sayi(w.olen)),
                    _Kucuk('Hayvan-gün', sayi(w.hayvanGun)),
                  ]),
                  if (min != null) _Doluluk(ortBas: w.ortBas, basabas: min),
                  const SizedBox(height: 6),
                  Wrap(spacing: 14, runSpacing: 4, children: [
                    _Kucuk('Bakım geliri', tl(w.bakim)),
                    if (w.kira > 0) _Kucuk('Kira payı', tl(w.kira)),
                    if (w.gider > 0) _Kucuk('Gider payı', tl(w.gider)),
                  ]),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Yillik extends StatelessWidget {
  const _Yillik({required this.veri});
  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) {
    final yillar = eskYillari(veri.eskAylik);
    final min = eskBasabas(veri.eskBilgi);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        for (final y in yillar)
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text('${y.yil}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    Text(tl(y.karZarar),
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: kzRenk(y.karZarar))),
                  ]),
                  Text(
                      '${y.ay} ay kayıtlı'
                      '${y.eskAy > 0 ? ' · ${y.eskAy} ay ESK bakımı' : ' · ESK öncesi'}'
                      '${y.tahminiAy > 0 ? ' · ${y.tahminiAy} ay tahmini/devam ediyor' : ''}',
                      style:
                          const TextStyle(fontSize: 12, color: Renk.soluk)),
                  if (y.eskAy > 0) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 14, runSpacing: 4, children: [
                      _Kucuk('Ort. baş', sayi(y.ortBas)),
                      _Kucuk('Giren', sayi(y.gelen)),
                      _Kucuk('Panagro kesim', sayi(y.kesim)),
                      _Kucuk('Dış kesim', sayi(y.disKesim)),
                      _Kucuk('Ölen', sayi(y.olen)),
                      _Kucuk('Hayvan-gün', sayi(y.hayvanGun)),
                    ]),
                    if (min != null) _Doluluk(ortBas: y.ortBas, basabas: min),
                    const SizedBox(height: 6),
                    Wrap(spacing: 14, runSpacing: 4, children: [
                      _Kucuk('Bakım geliri', tl(y.bakim)),
                      if (y.kira > 0) _Kucuk('Kira', tl(y.kira)),
                      if (y.sap > 0) _Kucuk('Sap balyası', tl(y.sap)),
                      if (y.gider > 0) _Kucuk('İşletme gideri', tl(y.gider)),
                    ]),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Doluluk extends StatelessWidget {
  const _Doluluk({required this.ortBas, required this.basabas});
  final double ortBas, basabas;

  @override
  Widget build(BuildContext context) {
    if (basabas <= 0) return const SizedBox.shrink();
    final oran = (ortBas / basabas).clamp(0.0, 1.6);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (oran / 1.6).toDouble(),
              minHeight: 6,
              backgroundColor: Renk.cizgi,
              color: oran >= 1 ? Renk.yesil : Renk.kirmizi,
            ),
          ),
          Text('Başabaşın %${sayi(oran * 100)}\'i (${sayi(basabas)} baş)',
              style: const TextStyle(fontSize: 11.5, color: Renk.soluk)),
        ],
      ),
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
