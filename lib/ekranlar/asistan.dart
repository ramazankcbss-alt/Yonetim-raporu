import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'araclar.dart';
import 'bakim_onarim.dart';
import 'ciftlik_rapor.dart';
import 'esk.dart';
import 'gecmis.dart';
import 'hastalik.dart';
import 'gunce.dart';
import 'kilit.dart';
import 'mali.dart';
import 'tarla.dart';
import 'toplanti.dart';
import 'uretim_karlilik.dart';
import 'veteriner.dart';

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
            'Toplantılarını kaydeder, ESK, geçmiş yıllar, araç, bakım onarım ve hastalık '
            'verilerini tek yerde toplar.',
            style: TextStyle(fontSize: 13.5, color: Renk.soluk, height: 1.4),
          ),
        ),
        const _AnlikGuncelle(),
        _Bolum(
          ikon: Icons.agriculture_outlined,
          baslik: 'ESK – Et ve Süt Kurumu',
          aciklama: _eskOzet(veri),
          renk: Renk.kirmizi,
          ac: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EskEkran(veri: veri))),
        ),
        _Bolum(
          ikon: Icons.account_balance_outlined,
          baslik: 'Mali Raporlar',
          aciklama: _maliOzet(veri),
          renk: Renk.amber,
          ac: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => MaliEkran(veri: veri))),
        ),
        _Bolum(
          ikon: Icons.query_stats_outlined,
          baslik: 'Çiftlikler Rapor 2026',
          aciklama: 'Kâr/zarar ile süt, et ve tarım birim maliyetleri — artış ve azalış nedenleriyle',
          renk: Renk.mavi,
          ac: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CiftlikRaporEkran())),
        ),
        _Bolum(
          ikon: Icons.insights_outlined,
          baslik: 'Ürün Takibi',
          aciklama: veri.tarimsalUretim.bos
              ? 'Ekim alanı, maliyet, teslimat, satış ve net kazanç — ürün ve çiftlik bazında'
              : '${sayi(veri.tarimsalUretim.genelToplam.dekar)} da · teslimat, satış, maliyet, net kazanç',
          renk: Renk.yesil,
          ac: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => UretimKarlilikEkran(veri: veri))),
        ),
        _Bolum(
          ikon: Icons.history_edu_outlined,
          baslik: 'Geçmiş Yıllar',
          aciklama: veri.gecmis.isEmpty
              ? 'Bilgi Bankası: 2018–2026 sürü, süt, kesim, maliyet, tarım ve kâr/zarar'
              : '${veri.gecmis.length} kayıt · ${veri.dersler.length} ders (2018–2026)',
          renk: Renk.ana,
          ac: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => GecmisEkran(veri: veri))),
        ),
        _Bolum(
          ikon: Icons.map_outlined,
          baslik: 'Tarla Haritası',
          aciklama: '2025-2026 sezonu parseller, ekiliş ve tarım icmaliyle karşılaştırma',
          renk: Renk.yesil,
          ac: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TarlaEkran(veri: veri))),
        ),
        _Bolum(
          ikon: Icons.agriculture_outlined,
          baslik: 'Araçlar',
          aciklama: veri.arac.bos
              ? 'Araç Takip: kullanım, bakım ve arıza'
              : '${veri.arac.araclar.length} araç · ${veri.arac.aktif.length} aktif kullanım · '
                  '${veri.arac.ariza.where((x) => !x.kapali).length} açık arıza',
          renk: Renk.anaKoyu,
          ac: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AraclarEkran(veri: veri))),
        ),
        _Bolum(
          ikon: Icons.build_outlined,
          baslik: 'Bakım Onarım',
          aciklama: veri.bakimOnarim.bos
              ? 'Günlük Tarım Bildirimi formundan gelen bakım onarım kayıtları'
              : '${veri.bakimOnarim.onayli.length} onaylı · '
                  '${veri.bakimOnarim.onayBekleyen.length} onay bekleyen · '
                  '${veri.bakimOnarim.acik.length} açık iş',
          renk: Renk.turuncu,
          ac: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => BakimOnarimEkran(veri: veri))),
        ),
        _Bolum(
          ikon: Icons.vaccines_outlined,
          baslik: 'Hastalık Dağılımı',
          aciklama: 'Aylara göre hastalıklar; çiftlik, cins ve ölüm/kalım/kuru/kesim/imha + önleme tedbirleri',
          renk: Renk.kirmizi,
          ac: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => HastalikEkran(veri: veri))),
        ),
        _Bolum(
          ikon: Icons.medical_services_outlined,
          baslik: 'Veteriner Kontrol Paneli',
          aciklama: _vetOzet(veri),
          renk: Renk.mavi,
          ac: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => VeterinerEkran(veri: veri))),
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


/// Asistan'ın en üstünde: kaynak tablolardaki yeni günleri rapora çeker
/// (Eşitle), ardından rapor ve özel bölümleri (danışmanlık, toplantı…)
/// yeniden okur. Son güncelleme saatini gösterir.
class _AnlikGuncelle extends StatefulWidget {
  const _AnlikGuncelle();

  @override
  State<_AnlikGuncelle> createState() => _AnlikGuncelleState();
}

class _AnlikGuncelleState extends State<_AnlikGuncelle> {
  bool _calisiyor = false;

  Future<void> _guncelle() async {
    final d = VeriDeposu.ben;
    setState(() => _calisiyor = true);
    String mesaj;
    try {
      mesaj = await d.esitle();
      try {
        await d.ozelGetir();
      } catch (_) {/* özel bölümler okunamazsa rapor yine güncel */}
    } catch (e) {
      // Eşitleme yapılamazsa en azından tablodaki son hali al.
      await d.yenile();
      mesaj = d.hata ?? 'Tablodaki son veri alındı (eşitleme yapılamadı: $e).';
    }
    if (!mounted) return;
    setState(() => _calisiyor = false);
    bildir(context, mesaj);
  }

  @override
  Widget build(BuildContext context) {
    final d = VeriDeposu.ben;
    return ListenableBuilder(
      listenable: d,
      builder: (context, _) {
        final mesgul = _calisiyor || d.yukleniyor || d.esitleniyor;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: mesgul ? null : _guncelle,
          child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: BoxDecoration(
            color: Renk.anaAcik,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Icon(Icons.cloud_sync_outlined, color: Renk.anaKoyu),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Anlık güncelleme',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, color: Renk.anaKoyu)),
                Text(
                    mesgul
                        ? 'Yeni veriler çekiliyor…'
                        : d.sonAlinma == null
                            ? 'Henüz güncellenmedi'
                            : 'Son: ${zamanBicim(d.sonAlinma!)} · yeni veri için dokun',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Renk.soluk)),
              ]),
            ),
            mesgul
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)),
                  )
                : IconButton.filled(
                    tooltip: 'Şimdi güncelle',
                    onPressed: _guncelle,
                    icon: const Icon(Icons.sync),
                  ),
          ]),
        ),
        );
      },
    );
  }
}

String _maliOzet(RaporVerisi veri) {
  final m = veri.mali;
  if (m.bos) return 'Gelen faturalar, açık bakiyeler ve dosyalar arası kontrol';
  final top = m.faturalar.fold(0.0, (t, f) => t + f.tutar);
  final acik = m.acik.fold(0.0, (t, a) => t + a.tutar);
  final sorun = m.kontrol.where((k) => k.bolum == 'Tutarsızlık' || k.bolum == 'Uyarı').length;
  return '2026 faturalar ${tl(top)}${m.kdv.isEmpty ? '' : ' (KDV ${m.kdv})'}${m.acik.isNotEmpty ? ' · ödenmemiş ${tl(acik)}' : ''}${sorun > 0 ? ' · $sorun uyarı' : ''}';
}

String _vetOzet(RaporVerisi veri) {
  if (!veri.vetPanelAcik) return 'Panel erişime kapalı · açmak için dokunun';
  final yeni = veri.vetBildirimleri.where((b) => b.yeni).length;
  final aktif = veri.vetKodlari.where((k) => k.aktif).length;
  if (veri.vetKodlari.isEmpty) {
    return 'Veteriner hekimler kodla girip hayvancılık ve hastalık analizini kontrol eder';
  }
  return '${yeni > 0 ? '$yeni yeni bildirim · ' : ''}${veri.vetBildirimleri.length} bildirim · $aktif aktif kod';
}

String _eskOzet(RaporVerisi veri) {
  final min = eskBasabas(veri.eskBilgi);
  final aylar = veri.eskAylik.where((a) => a.ortBas != null).toList();
  if (min == null || aylar.isEmpty) {
    return 'Taşağıl bakım besleme: aylık kâr/zarar, başabaş, öneriler';
  }
  final son = aylar.last;
  return 'Başabaş ${sayi(min)} baş/gün · ${son.ay}: ort. ${sayi(son.ortBas)} baş';
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
