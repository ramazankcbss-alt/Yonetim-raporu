import 'package:flutter/material.dart';

import '../bicim.dart';
import '../tema.dart';
import '../veri/model.dart';
import '../veri/tablolar.dart';
import 'bilesenler.dart';

/// Günlük pano: seçilen günün göstergeleri, işletme tablosu, Fethiye/Erentepe
/// karşılaştırması ve tarım faaliyetleri.
class GunlukEkran extends StatefulWidget {
  const GunlukEkran({super.key, required this.veri});

  final RaporVerisi veri;

  @override
  State<GunlukEkran> createState() => _GunlukEkranState();
}

class _GunlukEkranState extends State<GunlukEkran> {
  DateTime? _gun;

  @override
  Widget build(BuildContext context) {
    final v = widget.veri;
    final gunler = v.gunler;
    if (gunler.isEmpty) {
      return const BosDurum(
          ikon: Icons.event_busy, yazi: 'Raporda henüz canlı hayvan verisi yok.');
    }
    final gun = (_gun != null && gunler.contains(_gun))
        ? _gun!
        : (v.sonGun != null && gunler.contains(v.sonGun) ? v.sonGun! : gunler.first);

    final g = gunlukGostergeler(v, gun);
    final oz = canliHayvanOzeti(v, gun, gun);
    final bugun = v.gunlukBul(gun);
    final onceki = v.oncekiGunluk(gun);
    final faaliyetler = v.tarimDonem(gun, gun);
    final kayitliCiftlikler = {for (final f in faaliyetler) f.ciftlik};
    final digerSonlar = [
      for (final s in v.sonFaaliyetler(gun))
        if (!kayitliCiftlikler.contains(s.ciftlik)) s
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Secici<DateTime>(
          secenekler: gunler,
          secili: gun,
          etiket: tarihUzun,
          degisti: (d) => setState(() => _gun = d),
        ),
        const EsitleButonu(),
        if (oz.ozetGunu == null)
          const BilgiKutusu(
            uyari: true,
            yazi: 'Bu gün için işletme özeti yok; yalnızca Fethiye ve '
                'Erentepe günlük süt verisi gösteriliyor.',
          ),
        GostergeIzgarasi(kartlar: [
          GostergeKarti(
            baslik: 'Toplam Hayvan',
            deger: sayi(g.toplamHayvan),
            ikon: Icons.pets,
            alt: 'ESK-Taşağıl besi hariç',
          ),
          GostergeKarti(
            baslik: 'Sağılan Hayvan',
            deger: sayi(g.sagilan),
            ikon: Icons.water_drop_outlined,
            renk: Renk.mavi,
          ),
          GostergeKarti(
            baslik: 'Süt Üretimi',
            deger: kg(g.sut),
            ikon: Icons.local_drink_outlined,
            renk: Renk.mavi,
            alt: g.ortVerim == null
                ? null
                : 'Ort. ${sayi(g.ortVerim, ondalik: 1)} kg/baş',
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
            baslik: 'ESK-Taşağıl Besi',
            deger: sayi(g.eskBesiHayvan),
            ikon: Icons.agriculture_outlined,
            renk: Renk.turuncu,
            alt: 'Çiftlikler toplamına dahil değil',
          ),
        ]),
        const SizedBox(height: 12),
        Panel(
          baslik: 'İşletme Bazlı Canlı Hayvan',
          child: oz.ozetGunu == null
              ? const BosDurum(
                  ikon: Icons.table_chart_outlined,
                  yazi: 'Bu gün için işletme özeti yok.')
              : VeriTablosu(
                  basliklar: isletmeBasliklari,
                  satirlar: isletmeSatirlari(oz),
                  vurguluSonSatir: true,
                  ilkSutunGenislik: 190,
                ),
        ),
        Panel(
          baslik: 'Süt Sığırı — Fethiye / Erentepe',
          child: bugun == null
              ? const BosDurum(
                  ikon: Icons.local_drink_outlined,
                  yazi: 'Bu gün için Fethiye / Erentepe günlük verisi yok.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      onceki == null
                          ? 'Önceki gün verisi yok.'
                          : 'Önceki veri günü (${tarihKisa(onceki.tarih)}) ile karşılaştırma',
                      style: const TextStyle(fontSize: 12.5, color: Renk.soluk),
                    ),
                    const SizedBox(height: 8),
                    VeriTablosu(
                      basliklar: suruBasliklari(
                          onceki == null ? 'Önceki' : gunAy(onceki.tarih),
                          gunAy(gun)),
                      satirlar: suruSatirlari(onceki, bugun),
                      ilkSutunGenislik: 150,
                    ),
                  ],
                ),
        ),
        Panel(
          baslik: 'Tarımsal Faaliyetler',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (faaliyetler.isEmpty)
                const Text('Bu gün için tarım kaydı yok.',
                    style: TextStyle(color: Renk.soluk)),
              for (final f in faaliyetler)
                FaaliyetSatiri(kayit: f, tarihGoster: false),
              if (digerSonlar.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Diğer çiftliklerin son kaydı',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Renk.soluk)),
                for (final f in digerSonlar) FaaliyetSatiri(kayit: f),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
