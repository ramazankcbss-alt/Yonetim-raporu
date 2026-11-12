import 'package:flutter/material.dart';

import '../bicim.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'bilesenler.dart';

/// Sekreterlik — Kontrol Paneli'ndeki işlerin (bekleyen / devam eden /
/// tamamlanan) salt okunur görünümü. Veri E-Tablodan gelir, uygulamada
/// değiştirilmez; durum değişiklikleri E-Tablo ve otomatik görevlerle yürür.
class IslerEkran extends StatefulWidget {
  const IslerEkran({super.key, required this.veri});

  final RaporVerisi veri;

  @override
  State<IslerEkran> createState() => _IslerEkranState();
}

class _IslerEkranState extends State<IslerEkran> {
  String? _filtre; // null: tümü; 'Bekliyor' / 'Devam ediyor' / 'Tamamlandı'

  void _degistir(String durum) =>
      setState(() => _filtre = (_filtre == durum) ? null : durum);

  @override
  Widget build(BuildContext context) {
    final bugun = DateTime.now();
    final isler = widget.veri.isler;

    int acilis(Is a) => a.acilis?.millisecondsSinceEpoch ?? 0;
    final bekleyen = isler.where((i) => i.bekliyor).toList()
      ..sort((a, b) => acilis(a).compareTo(acilis(b)));
    final devam = isler.where((i) => i.devam).toList()
      ..sort((a, b) => acilis(a).compareTo(acilis(b)));
    final tamam = isler.where((i) => i.tamam).toList()
      ..sort((a, b) => (b.sonDegisiklik ?? DateTime(2000))
          .compareTo(a.sonDegisiklik ?? DateTime(2000)));
    final geciken = bekleyen.where((i) => i.gecikmis(bugun)).length;

    final goster = _filtre == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Sekreterlik — İşler')),
      body: isler.isEmpty
          ? const BosDurum(
              ikon: Icons.inbox_outlined, yazi: 'Takip edilen iş yok.')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    _Sayac(
                        etiket: 'Bekliyor',
                        sayi: bekleyen.length,
                        renk: Renk.turuncu,
                        secili: _filtre == 'Bekliyor',
                        onTap: () => _degistir('Bekliyor')),
                    const SizedBox(width: 10),
                    _Sayac(
                        etiket: 'Devam',
                        sayi: devam.length,
                        renk: Renk.mavi,
                        secili: _filtre == 'Devam ediyor',
                        onTap: () => _degistir('Devam ediyor')),
                    const SizedBox(width: 10),
                    _Sayac(
                        etiket: 'Tamam',
                        sayi: tamam.length,
                        renk: Renk.yesil,
                        secili: _filtre == 'Tamamlandı',
                        onTap: () => _degistir('Tamamlandı')),
                  ],
                ),
                const SizedBox(height: 12),
                if (geciken > 0 && (goster || _filtre == 'Bekliyor'))
                  BilgiKutusu(
                      uyari: true,
                      yazi:
                          '$geciken iş 14 günden uzun süredir bekliyor. Toplantıda sorumlu ve tarih atanabilir.'),
                if ((goster || _filtre == 'Bekliyor') && bekleyen.isNotEmpty)
                  _grup('Bekleyen işler', bekleyen, bugun),
                if ((goster || _filtre == 'Devam ediyor') && devam.isNotEmpty)
                  _grup('Devam eden işler', devam, bugun),
                if ((goster || _filtre == 'Tamamlandı') && tamam.isNotEmpty)
                  _grup('Tamamlanan işler', tamam, bugun),
                const SizedBox(height: 8),
                if (widget.veri.olusturma != null)
                  Center(
                    child: Text('Kaynak: Kontrol Paneli · ${tarihKisa(bugun)}',
                        style:
                            const TextStyle(fontSize: 12, color: Renk.soluk)),
                  ),
              ],
            ),
    );
  }

  Widget _grup(String baslik, List<Is> liste, DateTime bugun) {
    return Panel(
      baslik: '$baslik (${liste.length})',
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(
        children: [for (final i in liste) _IsSatiri(kayit: i, bugun: bugun)],
      ),
    );
  }
}

Color _durumRenk(String d) {
  switch (d) {
    case 'Bekliyor':
      return Renk.turuncu;
    case 'Devam ediyor':
      return Renk.mavi;
    case 'Tamamlandı':
      return Renk.yesil;
  }
  return Renk.soluk;
}

class _Sayac extends StatelessWidget {
  const _Sayac({
    required this.etiket,
    required this.sayi,
    required this.renk,
    required this.secili,
    required this.onTap,
  });

  final String etiket;
  final int sayi;
  final Color renk;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: renk.withValues(alpha: secili ? 0.20 : 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: renk.withValues(alpha: secili ? 0.90 : 0.25),
                  width: secili ? 2 : 1),
            ),
            child: Column(
              children: [
                Text('$sayi',
                    style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w800, color: renk)),
                const SizedBox(height: 2),
                Text(etiket,
                    style: TextStyle(
                        fontSize: 12.5,
                        color: Renk.yazi,
                        fontWeight:
                            secili ? FontWeight.w700 : FontWeight.w400)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IsSatiri extends StatelessWidget {
  const _IsSatiri({required this.kayit, required this.bugun});

  final Is kayit;
  final DateTime bugun;

  @override
  Widget build(BuildContext context) {
    final renk = _durumRenk(kayit.durum);
    final geciken = kayit.gecikmis(bugun);
    final meta = [
      kayit.ciftlik,
      kayit.kaynak,
      if (kayit.sorumlu.isNotEmpty) kayit.sorumlu,
    ].where((e) => e.isNotEmpty).join(' · ');
    final tarihler = [
      if (kayit.acilis != null) 'Açılış ${tarihKisa(kayit.acilis!)}',
      if (kayit.sonDegisiklik != null) 'Son ${tarihKisa(kayit.sonDegisiklik!)}',
    ].join(' · ');

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
            decoration:
                BoxDecoration(color: renk, borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text('${kayit.no}. ${kayit.konu}',
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Renk.yazi,
                              height: 1.3)),
                    ),
                    if (geciken) ...[
                      const SizedBox(width: 8),
                      const _Etiket(yazi: 'Gecikmiş', renk: Renk.kirmizi),
                    ],
                  ],
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(meta,
                      style:
                          const TextStyle(fontSize: 12.5, color: Renk.soluk)),
                ],
                if (kayit.sonDurum.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(kayit.sonDurum,
                      style: const TextStyle(
                          fontSize: 13.5, color: Renk.yazi, height: 1.35)),
                ],
                if (tarihler.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(tarihler,
                      style: TextStyle(
                          fontSize: 11.5,
                          color: geciken ? Renk.kirmizi : Renk.soluk,
                          fontWeight:
                              geciken ? FontWeight.w600 : FontWeight.w400)),
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
