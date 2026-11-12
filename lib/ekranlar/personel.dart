import 'package:flutter/material.dart';

import '../bicim.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'bilesenler.dart';

/// Personel / Puantaj — İK ve işverenden gelen puantaj, fazla mesai, ek ödeme
/// ve İK duyurularının özet/katalog görünümü. Kişi bazlı maaş/saat rakamı
/// tutulmaz; dönem, tür, önemli notlar ve belge bilgisi gösterilir.
class PersonelEkran extends StatelessWidget {
  const PersonelEkran({super.key, required this.veri});

  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) {
    final kayitlar = veri.personel;

    // Döneme göre grupla; dönemsiz olanlar "Diğer" altında.
    final gruplar = <String, List<PersonelKaydi>>{};
    for (final k in kayitlar) {
      final d = k.donem.trim().isEmpty ? 'Diğer' : k.donem.trim();
      (gruplar[d] ??= []).add(k);
    }
    final donemler = gruplar.keys.toList()
      ..sort((a, b) {
        if (a == 'Diğer') return 1;
        if (b == 'Diğer') return -1;
        return b.compareTo(a); // en yeni dönem üstte (kaba)
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Personel / Puantaj')),
      body: kayitlar.isEmpty
          ? const BosDurum(
              ikon: Icons.badge_outlined,
              yazi:
                  'Henüz personel kaydı yok.\nPuantaj ve İK mailleri geldikçe buraya işlenir.')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const BilgiKutusu(
                    yazi:
                        'Özet/katalog görünümü — kişi bazlı maaş ve puantaj rakamları burada tutulmaz. Ayrıntı için ilgili belgeye bakın.'),
                for (final d in donemler)
                  _DonemGrup(donem: d, liste: gruplar[d]!),
              ],
            ),
    );
  }
}

Color _turRenk(String t) {
  final s = t.toLowerCase();
  if (s.contains('fazla') || s.contains('mesai')) return Renk.amber;
  if (s.contains('ek ödeme') || s.contains('ek odeme')) {
    return const Color(0xFF7C3AED);
  }
  if (s.contains('puantaj')) return Renk.mavi;
  if (s.contains('taşeron') || s.contains('taseron')) return Renk.turuncu;
  if (s.contains('ik') || s.contains('insan') || s.contains('duyuru')) {
    return Renk.ana;
  }
  return Renk.soluk;
}

class _DonemGrup extends StatelessWidget {
  const _DonemGrup({required this.donem, required this.liste});

  final String donem;
  final List<PersonelKaydi> liste;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined,
                  size: 18, color: Renk.soluk),
              const SizedBox(width: 8),
              Text(donem,
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
          for (final k in liste) _PersonelSatiri(kayit: k),
        ],
      ),
    );
  }
}

class _PersonelSatiri extends StatelessWidget {
  const _PersonelSatiri({required this.kayit});

  final PersonelKaydi kayit;

  @override
  Widget build(BuildContext context) {
    final renk = _turRenk(kayit.tur);
    final alt = [
      if (kayit.gonderen.isNotEmpty) kayit.gonderen,
      if (kayit.tarih != null) tarihKisa(kayit.tarih!),
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
                    if (kayit.tur.isNotEmpty) ...[
                      _Rozet(yazi: kayit.tur, renk: renk),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(kayit.konu,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Renk.yazi,
                              height: 1.3)),
                    ),
                    if (kayit.belgeliMi)
                      const Icon(Icons.description_outlined,
                          size: 16, color: Renk.soluk),
                  ],
                ),
                if (alt.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(alt,
                      style:
                          const TextStyle(fontSize: 12.5, color: Renk.soluk)),
                ],
                if (kayit.ozet.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(kayit.ozet,
                      style: const TextStyle(
                          fontSize: 13.5, color: Renk.yazi, height: 1.35)),
                ],
                if (kayit.belgeliMi) ...[
                  const SizedBox(height: 4),
                  Text('Belge: ${kayit.belge}',
                      style: const TextStyle(
                          fontSize: 12, color: Renk.soluk, height: 1.3)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Rozet extends StatelessWidget {
  const _Rozet({required this.yazi, required this.renk});

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
