import 'package:flutter/material.dart';

import '../bicim.dart';
import '../tema.dart';
import '../veri/detay.dart';
import '../veri/model.dart';
import '../veri/tablolar.dart';
import 'bilesenler.dart';
import 'isletme_detay.dart';
import 'tarla.dart';

/// Tarım panosu: ekim alanları, hasat/verim, besi planı ve faaliyet akışı.
class TarimEkran extends StatefulWidget {
  const TarimEkran({super.key, required this.veri, this.sabitTur, this.tarlaGoster = true});

  final RaporVerisi veri;

  /// Paylaşımda menü ayrı açıldığında: false = yalnızca Ziraat, true = yalnızca Hayvancılık (geçiş gizlenir).
  final bool? sabitTur;

  /// Ziraat bölümündeki Tarla Haritası kartı (paylaşımda menü kapalıysa gizlenir).
  final bool tarlaGoster;

  @override
  State<TarimEkran> createState() => _TarimEkranState();
}

class _TarimEkranState extends State<TarimEkran> {
  String? _ciftlik; // null: tümü
  late bool _hayvancilik = widget.sabitTur ?? false; // false: Ziraat, true: Hayvancılık
  bool _gunluk = false; // false: haftalık, true: günlük
  DateTime? _gun, _hafta;

  @override
  Widget build(BuildContext context) {
    final v = widget.veri;
    final (plan, ekilen) = ekimToplami(v.ekim);
    // Seçilen dönem: gün ya da hafta (varsayılan en son).
    final gunler = <DateTime>{...v.gunler, for (final t in v.tarim) gunu(t.tarih)}.toList()..sort((a, b) => b.compareTo(a));
    final haftalar = v.haftalar;
    final gun = _gun != null && gunler.contains(_gun) ? _gun! : (gunler.isEmpty ? null : gunler.first);
    final hafta = _hafta != null && haftalar.contains(_hafta) ? _hafta! : (haftalar.isEmpty ? null : haftalar.first);
    final DateTime? bas = _gunluk ? gun : hafta;
    final DateTime? son = bas == null ? null : (_gunluk ? bas : bas.add(const Duration(days: 6)));
    final List<TarimKaydi> akis = bas == null
        ? const <TarimKaydi>[]
        : (v
            .tarimDonem(bas, son!)
            .where((t) => t.hayvancilik == _hayvancilik)
            .where((t) => _ciftlik == null || t.ciftlik == _ciftlik)
            .toList()
          // En yeni faaliyet en üstte.
          ..sort((a, b) => b.tarih.compareTo(a.tarih)));
    // Çiftlik çipleri yalnızca seçili türde kaydı olan çiftlikleri göstersin.
    final turCiftlikleri = {
      for (final t in v.tarim)
        if (t.hayvancilik == _hayvancilik) t.ciftlik
    };
    final ciftlikler = [
      ...ciftlikSirasi.where(turCiftlikleri.contains),
      ...turCiftlikleri.where((c) => !ciftlikSirasi.contains(c)),
    ];

    // Hayvancılık: seçilen gün ya da haftanın hayvan verileri.
    final hg = bas == null ? null : (_gunluk ? gunlukGostergeler(v, bas) : haftalikGostergeler(v, bas));
    final ko = bas == null ? null : kayipOzeti(v, bas, son!);
    final hayvanOzeti = bas == null ? null : canliHayvanOzeti(v, bas, son!);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (widget.sabitTur == null) ...[
          _TurGecis(
            hayvancilik: _hayvancilik,
            sec: (h) => setState(() {
              _hayvancilik = h;
              _ciftlik = null;
            }),
          ),
          const SizedBox(height: 12),
        ],
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Günlük'), icon: Icon(Icons.today_outlined)),
            ButtonSegment(value: false, label: Text('Haftalık'), icon: Icon(Icons.date_range_outlined)),
          ],
          selected: {_gunluk},
          onSelectionChanged: (x) => setState(() => _gunluk = x.first),
        ),
        const SizedBox(height: 8),
        if (_gunluk && gun != null)
          Secici<DateTime>(secenekler: gunler, secili: gun, etiket: tarihUzun, degisti: (d) => setState(() => _gun = d))
        else if (!_gunluk && hafta != null)
          Secici<DateTime>(
              secenekler: haftalar, secili: hafta, etiket: haftaEtiketi, degisti: (d) => setState(() => _hafta = d)),
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
          if (widget.tarlaGoster) Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.map_outlined, color: Renk.ana),
              title: const Text('Tarla Haritası', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Parseller, haritadaki ekiliş ve tarım icmaliyle karşılaştırma'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TarlaEkran(veri: v))),
            ),
          ),
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
            if (hayvanOzeti?.ozetGunu == null)
              BilgiKutusu(
                  uyari: true,
                  yazi: 'Bu ${_gunluk ? 'gün' : 'hafta'} için işletme özeti yok; kartlarda yalnızca günlük süt verisi bulunan '
                      'değerler gösterilir.'),
            const BolumBasligi('Çiftliklerimiz', ikon: Icons.home_work_outlined),
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
                baslik: _gunluk ? 'Günlük Süt' : 'Haftalık Süt',
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
                baslik: 'Hayvan Kayıpları',
                deger: sayi(ko?.toplam ?? hg.kayip),
                ikon: Icons.heart_broken_outlined,
                renk: Renk.turuncu,
                alt: ko?.aciklama ?? hg.kayipAyrinti,
              ),
              GostergeKarti(
                baslik: 'Kesilen Dana',
                deger: sayi(hg.kesilenDana),
                ikon: Icons.content_cut,
                renk: Renk.turuncu,
              ),
              GostergeKarti(
                baslik: 'İnek/Düve Kesim-Satış',
                deger: sayi(hg.kesimSatis),
                ikon: Icons.sell_outlined,
                renk: Renk.turuncu,
              ),
            ]),
            EskBolumu(g: hg, kesilenAlt: _gunluk ? 'Gün toplamı' : 'Hafta toplamı'),
            const SizedBox(height: 12),
            IsletmeDetayPaneli(veri: v, bas: bas!, son: son!),
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
          baslik: '${_hayvancilik ? 'Hayvancılık' : 'Ziraat'} Faaliyetleri '
              '(${bas == null ? 'kayıt yok' : _gunluk ? tarihUzun(bas) : haftaEtiketi(bas)})',
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
                  child: Text('Bu dönemde kayıt yok.', style: TextStyle(color: Renk.soluk)),
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
