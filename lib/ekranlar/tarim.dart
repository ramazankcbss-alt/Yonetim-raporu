import 'package:flutter/material.dart';

import '../bicim.dart';
import '../tema.dart';
import '../veri/model.dart';
import '../veri/tablolar.dart';
import 'bilesenler.dart';

/// Tarım panosu: ekim alanları, hasat/verim, besi planı ve faaliyet akışı.
class TarimEkran extends StatefulWidget {
  const TarimEkran({super.key, required this.veri});

  final RaporVerisi veri;

  @override
  State<TarimEkran> createState() => _TarimEkranState();
}

class _TarimEkranState extends State<TarimEkran> {
  String? _ciftlik; // null: tümü
  bool _hayvancilik = false; // false: Ziraat, true: Hayvancılık

  @override
  Widget build(BuildContext context) {
    final v = widget.veri;
    final (plan, ekilen) = ekimToplami(v.ekim);
    final sonTarih = v.tarim.isEmpty ? null : v.tarim.last.tarih;
    final akis = sonTarih == null
        ? const <TarimKaydi>[]
        : v
            .tarimDonem(sonTarih.subtract(const Duration(days: 30)), sonTarih)
            .where((t) => t.hayvancilik == _hayvancilik)
            .where((t) => _ciftlik == null || t.ciftlik == _ciftlik)
            .toList()
            .reversed
            .toList();
    // Çiftlik çipleri yalnızca seçili türde kaydı olan çiftlikleri göstersin.
    final turCiftlikleri = {
      for (final t in v.tarim)
        if (t.hayvancilik == _hayvancilik) t.ciftlik
    };
    final ciftlikler = [
      ...ciftlikSirasi.where(turCiftlikleri.contains),
      ...turCiftlikleri.where((c) => !ciftlikSirasi.contains(c)),
    ];

    // Hayvancılık için son haftanın hayvan verileri.
    final haftalar = v.haftalar;
    final sonHafta = haftalar.isEmpty ? null : haftalar.first;
    final hg = sonHafta == null ? null : haftalikGostergeler(v, sonHafta);
    final hayvanOzeti = sonHafta == null
        ? null
        : canliHayvanOzeti(v, sonHafta, sonHafta.add(const Duration(days: 6)));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _TurGecis(
          hayvancilik: _hayvancilik,
          sec: (h) => setState(() {
            _hayvancilik = h;
            _ciftlik = null;
          }),
        ),
        const SizedBox(height: 12),
        if (!_hayvancilik) ...[
          GostergeIzgarasi(kartlar: [
            GostergeKarti(
              baslik: 'Planlanan Alan',
              deger: '${sayi(plan)} da',
              ikon: Icons.map_outlined,
            ),
            GostergeKarti(
              baslik: 'Ekilen Alan',
              deger: '${sayi(ekilen)} da',
              ikon: Icons.grass,
              renk: Renk.yesil,
              alt: plan > 0 ? 'Planın %${sayi(ekilen / plan * 100)}\'i' : null,
            ),
          ]),
          const SizedBox(height: 12),
          Panel(
            baslik: 'Ekim Alanları (dekar)',
            child: v.ekim.isEmpty
                ? const BosDurum(
                    ikon: Icons.grass, yazi: 'Ekim alanı verisi yok.')
                : Column(
                    children: [for (final e in v.ekim) _EkimSatiri(e: e)],
                  ),
          ),
          Panel(
            baslik: 'Hasat / Verim Özeti',
            child: v.hasat.isEmpty
                ? const BosDurum(
                    ikon: Icons.inventory_2_outlined, yazi: 'Hasat kaydı yok.')
                : VeriTablosu(
                    basliklar: hasatBasliklari,
                    satirlar: hasatSatirlari(v.hasat),
                    metinSutunlari: const {0, 1},
                    ilkSutunGenislik: 170,
                  ),
          ),
        ] else ...[
          if (hg != null) ...[
            if (sonHafta != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 2),
                child: Text('Son hafta: ${haftaEtiketi(sonHafta)}',
                    style:
                        const TextStyle(fontSize: 12.5, color: Renk.soluk)),
              ),
            GostergeIzgarasi(kartlar: [
              GostergeKarti(
                baslik: 'Toplam Hayvan',
                deger: sayi(hg.toplamHayvan),
                ikon: Icons.pets,
              ),
              GostergeKarti(
                baslik: 'Sağılan Hayvan',
                deger: sayi(hg.sagilan),
                ikon: Icons.water_drop_outlined,
                renk: Renk.mavi,
              ),
              GostergeKarti(
                baslik: 'Haftalık Süt',
                deger: kg(hg.sut),
                ikon: Icons.local_drink_outlined,
                renk: Renk.mavi,
                alt: hg.ortVerim == null
                    ? null
                    : 'Ort. ${sayi(hg.ortVerim, ondalik: 1)} kg/baş/gün',
              ),
              GostergeKarti(
                baslik: 'Doğan Buzağı',
                deger: sayi(hg.dogan),
                ikon: Icons.cruelty_free_outlined,
                renk: Renk.yesil,
                alt: hg.olenBuzagi == null
                    ? null
                    : 'Ölen buzağı: ${sayi(hg.olenBuzagi)}',
              ),
              GostergeKarti(
                baslik: 'Kesilen Dana',
                deger: sayi(hg.kesilenDana),
                ikon: Icons.content_cut,
                renk: Renk.turuncu,
                alt: hg.eskKesilen == null
                    ? null
                    : 'ESK-Taşağıl: ${sayi(hg.eskKesilen)}',
              ),
              GostergeKarti(
                baslik: 'İnek/Düve Kesim-Satış',
                deger: sayi(hg.kesimSatis),
                ikon: Icons.sell_outlined,
                renk: Renk.turuncu,
              ),
            ]),
            const SizedBox(height: 12),
          ],
          Panel(
            baslik: 'İşletme Bazlı Canlı Hayvan',
            child: (hayvanOzeti == null || hayvanOzeti.ozetGunu == null)
                ? const BosDurum(
                    ikon: Icons.table_chart_outlined,
                    yazi: 'İşletme özeti verisi yok.')
                : VeriTablosu(
                    basliklar: isletmeBasliklari,
                    satirlar: isletmeSatirlari(hayvanOzeti),
                    vurguluSonSatir: true,
                    ilkSutunGenislik: 190,
                  ),
          ),
          Panel(
            baslik: 'Besi Planı ve Kesim',
            child: v.besi.isEmpty
                ? const BosDurum(
                    ikon: Icons.pets, yazi: 'Besi planı verisi yok.')
                : VeriTablosu(
                    basliklar: besiBasliklari,
                    satirlar: besiSatirlari(v.besi),
                    vurguluSonSatir: true,
                    ilkSutunGenislik: 110,
                  ),
          ),
        ],
        Panel(
          baslik: _hayvancilik
              ? 'Hayvancılık Faaliyetleri (son 30 gün)'
              : 'Ziraat Faaliyetleri (son 30 gün)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Tümü'),
                    selected: _ciftlik == null,
                    onSelected: (_) => setState(() => _ciftlik = null),
                  ),
                  for (final c in ciftlikler)
                    ChoiceChip(
                      label: Text(c),
                      selected: _ciftlik == c,
                      onSelected: (_) => setState(() => _ciftlik = c),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (akis.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Kayıt yok.', style: TextStyle(color: Renk.soluk)),
                ),
              for (final f in akis) FaaliyetSatiri(kayit: f),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ziraat / Hayvancılık ikili geçişi.
class _TurGecis extends StatelessWidget {
  const _TurGecis({required this.hayvancilik, required this.sec});

  final bool hayvancilik;
  final ValueChanged<bool> sec;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Renk.zemin,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Renk.cizgi),
      ),
      child: Row(
        children: [
          _TurDugme(
              yazi: 'Ziraat',
              ikon: Icons.agriculture_outlined,
              secili: !hayvancilik,
              onTap: () => sec(false)),
          _TurDugme(
              yazi: 'Hayvancılık',
              ikon: Icons.pets_outlined,
              secili: hayvancilik,
              onTap: () => sec(true)),
        ],
      ),
    );
  }
}

class _TurDugme extends StatelessWidget {
  const _TurDugme({
    required this.yazi,
    required this.ikon,
    required this.secili,
    required this.onTap,
  });

  final String yazi;
  final IconData ikon;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: secili ? Renk.kart : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: secili
                  ? [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1))
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(ikon,
                    size: 18, color: secili ? Renk.ana : Renk.soluk),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(yazi,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              secili ? FontWeight.w700 : FontWeight.w500,
                          color: secili ? Renk.ana : Renk.soluk)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EkimSatiri extends StatelessWidget {
  const _EkimSatiri({required this.e});

  final EkimSatir e;

  @override
  Widget build(BuildContext context) {
    final oran = e.oran;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '${e.ciftlik}  ',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: ciftlikRengi(e.ciftlik))),
                    TextSpan(text: e.urun),
                  ]),
                  style: const TextStyle(fontSize: 14, color: Renk.yazi),
                ),
              ),
              Text(
                '${e.ekilen == null ? '—' : sayi(e.ekilen)} / ${sayi(e.plan)} da',
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Renk.yazi),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: oran == null ? 0 : oran.clamp(0, 1).toDouble(),
              minHeight: 7,
              backgroundColor: Renk.cizgi,
              color: oran == null
                  ? Renk.cizgi
                  : oran >= 1
                      ? Renk.yesil
                      : Renk.ana,
            ),
          ),
        ],
      ),
    );
  }
}
