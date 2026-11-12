import 'package:flutter/material.dart';

import '../tema.dart';
import '../veri/model.dart';
import 'danismanlik.dart';
import 'gunce.dart';
import 'isakisi.dart';
import 'isler.dart';
import 'kilit.dart';
import 'ozel_notlar.dart';
import 'toplanti.dart';

/// Asistan sekmesi: sekreterlik, danışmanlık, toplantı notları, özel notlar
/// ve günlük bölümlerine açılan hub. Hazır olmayan bölümler "Yakında".
class AsistanEkran extends StatelessWidget {
  const AsistanEkran({super.key, required this.veri});

  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            'Sekreterin ve danışmanın. İşleri takip eder, toplantılarını '
            'kaydeder, sana özel notlarını tutar.',
            style: TextStyle(fontSize: 13.5, color: Renk.soluk, height: 1.4),
          ),
        ),
        _Bolum(
          ikon: Icons.event_note_outlined,
          baslik: 'Sekreterlik',
          aciklama: '${veri.isler.length} iş · bekleyen, devam eden, tamamlanan',
          renk: Renk.ana,
          ac: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => IslerEkran(veri: veri))),
        ),
        _Bolum(
          ikon: Icons.account_tree_outlined,
          baslik: 'İş Akışı',
          aciklama: _akisOzet(veri),
          renk: _morAsistan,
          ac: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => IsAkisiEkran(veri: veri))),
        ),
        _Bolum(
          ikon: Icons.forum_outlined,
          baslik: 'Danışmanlık',
          aciklama: 'Bir konuyu sor, görüş ve yol önerisi al',
          renk: Renk.mavi,
          ac: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const DanismanlikEkran())),
        ),
        _Bolum(
          ikon: Icons.groups_outlined,
          baslik: 'Toplantı Notları',
          aciklama: 'Toplantıları kaydet; zamanla birleştirip analiz et',
          renk: Renk.yesil,
          ac: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ToplantiEkran())),
        ),
        _Bolum(
          ikon: Icons.lock_outline,
          baslik: 'Özel Notlar',
          aciklama: 'Olumsuzluk, uyuşmazlık ve öneriler — yalnızca sana özel',
          renk: Renk.turuncu,
          ac: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const KilitKapisi(
                  baslik: 'Özel Notlar', child: OzelNotlarEkran()))),
        ),
        _Bolum(
          ikon: Icons.menu_book_outlined,
          baslik: 'Günlük',
          aciklama: 'Aklından geçenler; kimseyle paylaşılmaz',
          renk: Renk.amber,
          ac: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  const KilitKapisi(baslik: 'Günlük', child: GunceEkran()))),
        ),
      ],
    );
  }
}

const _morAsistan = Color(0xFF7C3AED);

String _akisOzet(RaporVerisi veri) {
  final acik = veri.akis.where((k) => !k.tamam).length;
  final finans = veri.akis.where((k) => k.finansta).length;
  if (veri.akis.isEmpty) {
    return 'Sipariş → satınalma → fatura → ödeme akışı';
  }
  return finans > 0
      ? '$acik açık iş · $finans ödeme aşamasında'
      : '$acik açık iş · sipariştan finansa';
}

class _Bolum extends StatelessWidget {
  const _Bolum({
    required this.ikon,
    required this.baslik,
    required this.aciklama,
    required this.renk,
    this.ac,
    this.yakinda = false,
  });

  final IconData ikon;
  final String baslik;
  final String aciklama;
  final Color renk;
  final VoidCallback? ac;
  final bool yakinda;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Renk.kart,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Renk.cizgi),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: yakinda
              ? () => bildir(context, '$baslik bölümü yakında eklenecek.')
              : ac,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: renk.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(ikon, color: renk, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(baslik,
                                style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: Renk.yazi)),
                          ),
                          if (yakinda) ...[
                            const SizedBox(width: 8),
                            const _Yakinda(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(aciklama,
                          style: const TextStyle(
                              fontSize: 13, color: Renk.soluk, height: 1.3)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(yakinda ? Icons.hourglass_empty : Icons.chevron_right,
                    color: Renk.soluk, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Yakinda extends StatelessWidget {
  const _Yakinda();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: Renk.amberAcik, borderRadius: BorderRadius.circular(6)),
        child: const Text('Yakında',
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: Renk.amber)),
      );
}
