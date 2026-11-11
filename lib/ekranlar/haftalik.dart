import 'package:flutter/material.dart';

import '../bicim.dart';
import '../tema.dart';
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
    final tarim = v.tarimDonem(hafta, son).reversed.toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Secici<DateTime>(
          secenekler: haftalar,
          secili: hafta,
          etiket: haftaEtiketi,
          degisti: (d) => setState(() => _hafta = d),
        ),
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
            deger: '${sayi(g.personel)} / ${sayi(g.taseron)}',
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
            baslik: 'Kesilen Dana',
            deger: sayi(g.kesilenDana),
            ikon: Icons.content_cut,
            renk: Renk.turuncu,
            alt: g.eskKesilen == null
                ? null
                : 'ESK-Taşağıl: ${sayi(g.eskKesilen)}',
          ),
          GostergeKarti(
            baslik: 'İnek/Düve Kesim-Satış',
            deger: sayi(g.kesimSatis),
            ikon: Icons.sell_outlined,
            renk: Renk.turuncu,
          ),
        ]),
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
        Panel(
          baslik: 'Haftanın Tarımsal Faaliyetleri',
          child: tarim.isEmpty
              ? const Text('Bu hafta için tarım kaydı yok.',
                  style: TextStyle(color: Renk.soluk))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final f in tarim) FaaliyetSatiri(kayit: f)],
                ),
        ),
      ],
    );
  }
}
