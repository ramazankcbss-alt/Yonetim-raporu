import 'package:flutter/material.dart';

import '../bicim.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'bilesenler.dart';

/// İş Akışı — siparişten finansa kadar ilerleyen işler ve hat dışı
/// (Arıza-Bakım, İnsan Kaynakları, Diğer) kalemler. Veri, rapor
/// E-Tablosundaki "İş Akışı" sayfasından gelir; saatlik otomatik görev
/// mailleri ve mesajları işleyip her kalemi doğru aşamaya taşır.
class IsAkisiEkran extends StatelessWidget {
  const IsAkisiEkran({super.key, required this.veri});

  final RaporVerisi veri;

  // Bölümler görünüm sırası: önce hat, sonra hat dışı.
  static const _sira = [
    'Sipariş',
    'Satınalma',
    'Malzeme Tedarik',
    'Muhasebe',
    'Finans',
    'Arıza-Bakım',
    'İnsan Kaynakları',
    'Diğer',
    'Tamamlandı',
  ];

  @override
  Widget build(BuildContext context) {
    final bugun = DateTime.now();
    final akis = veri.akis;

    int sonGun(AkisKaydi a) =>
        a.sonGuncelleme?.millisecondsSinceEpoch ??
        a.acilis?.millisecondsSinceEpoch ??
        0;

    // Bölüme göre grupla.
    final gruplar = <String, List<AkisKaydi>>{};
    for (final k in akis) {
      (gruplar[k.bolum] ??= []).add(k);
    }
    for (final l in gruplar.values) {
      l.sort((a, b) => sonGun(b).compareTo(sonGun(a)));
    }

    // Finans'ta 7 günden uzun bekleyen ödemeler.
    final bekleyenOdeme = akis
        .where((k) =>
            k.finansta &&
            k.sonGuncelleme != null &&
            gunu(bugun).difference(gunu(k.sonGuncelleme!)).inDays > 7)
        .length;

    final acik = akis.where((k) => !k.tamam).length;

    return Scaffold(
      appBar: AppBar(title: const Text('İş Akışı')),
      body: akis.isEmpty
          ? const BosDurum(
              ikon: Icons.account_tree_outlined,
              yazi:
                  'Henüz iş akışı kaydı yok.\nYeni sipariş, satınalma, fatura ve ödemeler geldikçe buraya işlenir.')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HatSerit(gruplar: gruplar),
                const SizedBox(height: 14),
                if (bekleyenOdeme > 0)
                  BilgiKutusu(
                      uyari: true,
                      yazi:
                          '$bekleyenOdeme ödeme Finans aşamasında 7 günden uzun süredir bekliyor.'),
                for (final bolum in _sira)
                  if ((gruplar[bolum] ?? const []).isNotEmpty)
                    _Grup(
                        bolum: bolum,
                        liste: gruplar[bolum]!,
                        bugun: bugun),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                      '$acik açık iş · Kaynak: İş Akışı · ${tarihKisa(bugun)}',
                      style:
                          const TextStyle(fontSize: 12, color: Renk.soluk)),
                ),
              ],
            ),
    );
  }
}

const _mor = Color(0xFF7C3AED);

Color _bolumRenk(String b) {
  switch (b) {
    case 'Sipariş':
      return Renk.amber;
    case 'Satınalma':
      return Renk.turuncu;
    case 'Malzeme Tedarik':
      return Renk.mavi;
    case 'Muhasebe':
      return Renk.ana;
    case 'Finans':
      return _mor;
    case 'Tamamlandı':
      return Renk.yesil;
    case 'Arıza-Bakım':
      return Renk.kirmizi;
    case 'İnsan Kaynakları':
      return Renk.mavi;
  }
  return Renk.soluk;
}

/// Üstteki yatay hat şeridi: 6 aşama ve her aşamadaki iş sayısı.
class _HatSerit extends StatelessWidget {
  const _HatSerit({required this.gruplar});

  final Map<String, List<AkisKaydi>> gruplar;

  @override
  Widget build(BuildContext context) {
    final asamalar = AkisKaydi.hat;
    return Panel(
      baslik: 'Satınalma hattı',
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < asamalar.length; i++) ...[
              _HatKutu(
                ad: asamalar[i],
                sayi: (gruplar[asamalar[i]] ?? const []).length,
                renk: _bolumRenk(asamalar[i]),
              ),
              if (i < asamalar.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.chevron_right,
                      size: 20, color: Renk.soluk),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HatKutu extends StatelessWidget {
  const _HatKutu({required this.ad, required this.sayi, required this.renk});

  final String ad;
  final int sayi;
  final Color renk;

  @override
  Widget build(BuildContext context) {
    final bos = sayi == 0;
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: bos ? Renk.zemin : renk.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: bos ? Renk.cizgi : renk.withValues(alpha: 0.30)),
      ),
      child: Column(
        children: [
          Text('$sayi',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: bos ? Renk.soluk : renk)),
          const SizedBox(height: 3),
          Text(ad,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11.5, height: 1.2, color: Renk.yazi)),
        ],
      ),
    );
  }
}

class _Grup extends StatelessWidget {
  const _Grup(
      {required this.bolum, required this.liste, required this.bugun});

  final String bolum;
  final List<AkisKaydi> liste;
  final DateTime bugun;

  @override
  Widget build(BuildContext context) {
    final renk = _bolumRenk(bolum);
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: renk, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(bolum,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Renk.yazi)),
              const SizedBox(width: 6),
              Text('(${liste.length})',
                  style: const TextStyle(fontSize: 13, color: Renk.soluk)),
            ],
          ),
          const SizedBox(height: 4),
          for (final k in liste)
            _AkisSatiri(kayit: k, bugun: bugun, renk: renk),
        ],
      ),
    );
  }
}

class _AkisSatiri extends StatelessWidget {
  const _AkisSatiri(
      {required this.kayit, required this.bugun, required this.renk});

  final AkisKaydi kayit;
  final DateTime bugun;
  final Color renk;

  @override
  Widget build(BuildContext context) {
    final meta = [
      kayit.firma,
      if (kayit.tutar.isNotEmpty) kayit.tutar,
      if (kayit.anahtar.isNotEmpty) kayit.anahtar,
    ].where((e) => e.isNotEmpty).join(' · ');

    final tarihler = [
      if (kayit.acilis != null) 'Açılış ${tarihKisa(kayit.acilis!)}',
      if (kayit.sonGuncelleme != null)
        'Son ${tarihKisa(kayit.sonGuncelleme!)}',
      if (kayit.kaynak.isNotEmpty) kayit.kaynak,
    ].join(' · ');

    final bekleyen = kayit.finansta &&
        kayit.sonGuncelleme != null &&
        gunu(bugun).difference(gunu(kayit.sonGuncelleme!)).inDays > 7;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Renk.cizgi)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 42,
            margin: const EdgeInsets.only(right: 10, top: 2),
            decoration: BoxDecoration(
                color: renk, borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text('${kayit.no}. ${kayit.baslik}',
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Renk.yazi,
                              height: 1.3)),
                    ),
                    if (kayit.hatta && !kayit.tamam) ...[
                      const SizedBox(width: 8),
                      _Etiket(
                          yazi: '${kayit.asama + 1}/5',
                          renk: renk),
                    ],
                    if (bekleyen) ...[
                      const SizedBox(width: 6),
                      const _Etiket(yazi: 'Bekliyor', renk: Renk.kirmizi),
                    ],
                  ],
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(meta,
                      style:
                          const TextStyle(fontSize: 12.5, color: Renk.soluk)),
                ],
                if (kayit.durum.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(kayit.durum,
                      style: const TextStyle(
                          fontSize: 13.5, color: Renk.yazi, height: 1.35)),
                ],
                if (kayit.sonrakiAdim.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.arrow_forward,
                          size: 14, color: Renk.soluk),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(kayit.sonrakiAdim,
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: Renk.soluk,
                                height: 1.3,
                                fontStyle: FontStyle.italic)),
                      ),
                    ],
                  ),
                ],
                if (tarihler.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(tarihler,
                      style:
                          const TextStyle(fontSize: 11.5, color: Renk.soluk)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Etiket extends StatelessWidget {
  const _Etiket({required this.yazi, required this.renk});

  final String yazi;
  final Color renk;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: renk.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6)),
        child: Text(yazi,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: renk)),
      );
}
