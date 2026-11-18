import 'package:flutter/material.dart';

import '../bicim.dart';
import '../tema.dart';
import '../veri/faaliyet_ozet.dart';
import '../veri/model.dart';
import '../veri/tablolar.dart';
import 'bilesenler.dart';

/// Haftalık pano: E-Tablodaki haftalık rapor sayfasının telefondaki hali.
class HaftalikEkran extends StatefulWidget {
  const HaftalikEkran({super.key, required this.veri});

  final RaporVerisi veri;

  @override
  State<HaftalikEkran> createState() => _HaftalikEkranState();
}

class _HaftalikEkranState extends State<HaftalikEkran> {
  DateTime? _hafta;

  @override
  Widget build(BuildContext context) {
    final v = widget.veri;
    final haftalar = v.haftalar;
    if (haftalar.isEmpty) {
      return const BosDurum(
          ikon: Icons.event_busy, yazi: 'Raporda henüz veri yok.');
    }
    final hafta = (_hafta != null && haftalar.contains(_hafta))
        ? _hafta!
        : haftalar.first;
    final son = hafta.add(const Duration(days: 6));

    final g = haftalikGostergeler(v, hafta);
    final oz = canliHayvanOzeti(v, hafta, son);
    final gunler = v.gunlukDonem(hafta, son);
    final tarim = v.tarimDonem(hafta, son).toList()
      ..sort((a, b) => b.tarih.compareTo(a.tarih)); // en yeni üstte

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Secici<DateTime>(
          secenekler: haftalar,
          secili: hafta,
          etiket: haftaEtiketi,
          degisti: (d) => setState(() => _hafta = d),
        ),
        const EsitleButonu(),
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 2),
          child: Text(
            [
              'Özet günü: ${oz.ozetGunu == null ? 'yok' : tarihKisa(oz.ozetGunu!)}',
              if (gunler.isNotEmpty)
                'Süt verisi: ${gunAy(gunler.first.tarih)} – ${gunAy(gunler.last.tarih)} (${gunler.length} gün)',
            ].join('  ·  '),
            style: const TextStyle(fontSize: 12.5, color: Renk.soluk),
          ),
        ),
        const BolumBasligi('Çiftliklerimiz', ikon: Icons.home_work_outlined),
        GostergeIzgarasi(kartlar: [
          GostergeKarti(
            baslik: 'Toplam Hayvan',
            deger: sayi(g.toplamHayvan),
            ikon: Icons.pets,
            alt: 'Haftanın son günü',
          ),
          GostergeKarti(
            baslik: 'Sağılan Hayvan',
            deger: sayi(g.sagilan),
            ikon: Icons.water_drop_outlined,
            renk: Renk.mavi,
            alt: 'Haftanın son günü',
          ),
          GostergeKarti(
            baslik: 'Haftalık Süt',
            deger: kg(g.sut),
            ikon: Icons.local_drink_outlined,
            renk: Renk.mavi,
            alt: g.ortVerim == null
                ? null
                : 'Ort. ${sayi(g.ortVerim, ondalik: 1)} kg/baş/gün',
          ),
          GostergeKarti(
            baslik: 'Satılan Süt',
            deger: kg(g.satilan),
            ikon: Icons.local_shipping_outlined,
            renk: Renk.mavi,
            alt: 'Fethiye + Erentepe',
          ),
          GostergeKarti(
            baslik: 'Personel / Taşeron',
            deger: '${sayi(g.ciftlikPersonel)} / ${sayi(g.ciftlikTaseron)}',
            ikon: Icons.groups_outlined,
            renk: Renk.amber,
          ),
          GostergeKarti(
            baslik: 'Doğan Buzağı',
            deger: sayi(g.dogan),
            ikon: Icons.cruelty_free_outlined,
            renk: Renk.yesil,
            alt: g.olenBuzagi == null
                ? null
                : 'Ölen buzağı: ${sayi(g.olenBuzagi)}',
          ),
          GostergeKarti(
            baslik: 'Hayvan Kayıpları',
            deger: sayi(g.kayip),
            ikon: Icons.heart_broken_outlined,
            renk: Renk.turuncu,
            alt: g.kayipAyrinti,
          ),
          GostergeKarti(
            baslik: 'Kesilen Dana',
            deger: sayi(g.kesilenDana),
            ikon: Icons.content_cut,
            renk: Renk.turuncu,
          ),
          GostergeKarti(
            baslik: 'İnek/Düve Kesim-Satış',
            deger: sayi(g.kesimSatis),
            ikon: Icons.sell_outlined,
            renk: Renk.turuncu,
          ),
        ]),
        EskBolumu(g: g, kesilenAlt: 'Hafta toplamı'),
        const SizedBox(height: 12),
        Panel(
          baslik: 'Günlük Süt Üretimi (kg)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SutGrafigi(gunler: gunler),
              if (gunler.isNotEmpty) ...[
                const SizedBox(height: 12),
                VeriTablosu(
                  basliklar: gunlukSutBasliklari,
                  satirlar: gunlukSutSatirlari(gunler),
                  vurguluSonSatir: true,
                  ilkSutunGenislik: 130,
                ),
              ],
            ],
          ),
        ),
        Panel(
          baslik: 'İşletme Bazlı Canlı Hayvan',
          child: oz.ozetGunu == null
              ? const BosDurum(
                  ikon: Icons.table_chart_outlined,
                  yazi: 'Bu hafta için işletme özeti yok.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Personel, hayvan, sağılan: ${tarihKisa(oz.ozetGunu!)}. '
                      'Süt ve olaylar: hafta toplamı.',
                      style:
                          const TextStyle(fontSize: 12.5, color: Renk.soluk),
                    ),
                    const SizedBox(height: 8),
                    VeriTablosu(
                      basliklar: isletmeBasliklari,
                      satirlar: isletmeSatirlari(oz),
                      vurguluSonSatir: true,
                      ilkSutunGenislik: 190,
                    ),
                  ],
                ),
        ),
        Panel(
          baslik: 'Sürü Değişimi — Fethiye / Erentepe',
          child: gunler.isEmpty
              ? const BosDurum(
                  ikon: Icons.local_drink_outlined,
                  yazi: 'Bu hafta için günlük veri yok.')
              : VeriTablosu(
                  basliklar: suruBasliklari(
                      gunAy(gunler.first.tarih), gunAy(gunler.last.tarih)),
                  satirlar: suruSatirlari(gunler.first, gunler.last),
                  ilkSutunGenislik: 150,
                ),
        ),
        if (teyitDurumu(tarim).isNotEmpty || kontrolBekleyen(tarim) > 0)
          Panel(
            baslik: 'İcmal – Formen Bildirimi Karşılaştırması',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                    'Fark olan kalemlerde raporda icmal esas alınır; '
                    'icmalde olmayan iş formdan rapora girer.',
                    style: TextStyle(fontSize: 12.5, color: Renk.soluk)),
                const SizedBox(height: 6),
                if (kontrolBekleyen(tarim) > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                        'Sedef Hanım kontrolü bekleyen formen kaydı: '
                        '${kontrolBekleyen(tarim)} (rapora girmez)',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF854F0B))),
                  ),
                for (final t in teyitDurumu(tarim)) _TeyitSatiriWidget(t),
              ],
            ),
          ),
        Panel(
          baslik: 'Haftanın Tarımsal Faaliyetleri',
          child: tarim.isEmpty
              ? const Text('Bu hafta için tarım kaydı yok.',
                  style: TextStyle(color: Renk.soluk))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final o in faaliyetOzeti(tarim)) _CiftlikOzeti(o)
                  ],
                ),
        ),
      ],
    );
  }
}

/// Bir çiftliğin haftalık faaliyet özeti (raporda gönderilen biçimle aynı).
class _CiftlikOzeti extends StatelessWidget {
  const _CiftlikOzeti(this.ozet);

  final FaaliyetOzeti ozet;

  @override
  Widget build(BuildContext context) {
    final r = ciftlikRengi(ozet.ciftlik);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
            border: Border(left: BorderSide(color: r, width: 4))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ozet.ciftlik,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: r)),
            const SizedBox(height: 4),
            for (final m in ozet.maddeler)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('• $m',
                    style: const TextStyle(
                        fontSize: 14, color: Renk.yazi, height: 1.35)),
              ),
          ],
        ),
      ),
    );
  }
}

class _TeyitSatiriWidget extends StatelessWidget {
  const _TeyitSatiriWidget(this.t);

  final TeyitSatiri t;

  @override
  Widget build(BuildContext context) {
    final renk = switch (t.durum) {
      'Teyitli' => const Color(0xFF3B6D11),
      'Fark var' => const Color(0xFFA32D2D),
      _ => const Color(0xFF854F0B),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${t.ciftlik} · ${t.is_}',
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                Text('İcmal: ${t.icmalMetin}   Form: ${t.formMetin}',
                    style: const TextStyle(fontSize: 12.5, color: Renk.soluk)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: renk.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6)),
            child: Text(t.durum,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: renk)),
          ),
        ],
      ),
    );
  }
}
