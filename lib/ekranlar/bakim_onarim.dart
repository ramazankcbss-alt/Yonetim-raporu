import 'package:flutter/material.dart';

import '../tema.dart';
import '../veri/model.dart';
import 'bilesenler.dart';

/// Günlük Tarım Bildirimi formundan gelen bakım onarım kayıtlarının yönetim
/// görünümü. Bakım onarım formeninin onayladığı kayıtlar özetlere girer;
/// onay bekleyenler listede işaretli görünür, özetlere dahil edilmez.
class BakimOnarimEkran extends StatefulWidget {
  const BakimOnarimEkran({super.key, required this.veri});
  final RaporVerisi veri;

  @override
  State<BakimOnarimEkran> createState() => _BakimOnarimEkranState();
}

enum _Suzgec { tumu, acik, tedarik, onayBekleyen }

const _suzgecAdlari = {
  _Suzgec.tumu: 'Tümü',
  _Suzgec.acik: 'Açık işler',
  _Suzgec.tedarik: 'Tedarik bekleyen',
  _Suzgec.onayBekleyen: 'Onay bekleyen',
};

const _tumCiftlikler = 'Tüm çiftlikler';

class _BakimOnarimEkranState extends State<BakimOnarimEkran> {
  _Suzgec _suzgec = _Suzgec.tumu;
  String _ciftlik = _tumCiftlikler;

  List<BakimOnarimKaydi> _liste(BakimOnarimOzeti o) {
    Iterable<BakimOnarimKaydi> l = o.kayitlar;
    if (_ciftlik != _tumCiftlikler) l = l.where((x) => x.ciftlikAdi == _ciftlik);
    switch (_suzgec) {
      case _Suzgec.tumu:
        break;
      case _Suzgec.acik:
        l = l.where((x) => x.onayli && x.acik);
      case _Suzgec.tedarik:
        l = l.where((x) => x.onayli && x.tedarikBekliyor);
      case _Suzgec.onayBekleyen:
        l = l.where((x) => !x.onayli);
    }
    return l.toList();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.veri.bakimOnarim;
    return Scaffold(
      appBar: AppBar(title: const Text('Bakım Onarım')),
      body: o.bos
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: BilgiKutusu(
                yazi: 'Henüz bakım onarım kaydı yok. Günlük Tarım Bildirimi formunda '
                    '"Bakım onarım kaydı" seçilerek girilen kayıtlar burada görünür.',
              ),
            )
          : _govde(o),
    );
  }

  Widget _govde(BakimOnarimOzeti o) {
    final ciftlikler = [_tumCiftlikler, ...o.ciftlikler];
    if (!ciftlikler.contains(_ciftlik)) _ciftlik = _tumCiftlikler;
    final liste = _liste(o);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GostergeIzgarasi(kartlar: [
          GostergeKarti(
            baslik: 'Onaylı kayıt',
            deger: '${o.onayli.length}',
            ikon: Icons.verified_outlined,
            renk: Renk.yesil,
          ),
          GostergeKarti(
            baslik: 'Onay bekleyen',
            deger: '${o.onayBekleyen.length}',
            ikon: Icons.hourglass_top,
            renk: Renk.amber,
          ),
          GostergeKarti(
            baslik: 'Açık iş',
            deger: '${o.acik.length}',
            ikon: Icons.build_outlined,
            renk: Renk.mavi,
            alt: 'Devam eden / parça bekleyen',
          ),
          GostergeKarti(
            baslik: 'Tedarik bekleyen',
            deger: '${o.tedarikBekleyen.length}',
            ikon: Icons.inventory_2_outlined,
            renk: Renk.kirmizi,
            alt: 'Malzeme / yedek parça',
          ),
        ]),
        const SizedBox(height: 12),
        const BilgiKutusu(
          yazi: 'Kayıtlar bakım onarım formeninin onayından sonra özetlere dahil edilir. '
              'Onay bekleyen kayıtlar listede işaretli olarak gösterilir.',
        ),
        Secici<String>(
          secenekler: ciftlikler,
          secili: _ciftlik,
          etiket: (s) => s,
          degisti: (s) => setState(() => _ciftlik = s),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final s in _Suzgec.values)
              ChoiceChip(
                label: Text(_suzgecAdlari[s]!),
                selected: _suzgec == s,
                onSelected: (_) => setState(() => _suzgec = s),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (liste.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('Bu seçime uygun kayıt yok.',
                textAlign: TextAlign.center, style: TextStyle(color: Renk.soluk)),
          )
        else
          for (final x in liste) _KayitKarti(x),
        if (o.onayli.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Dagilim(baslik: 'İşlem türüne göre (onaylı)', l: o.islemDagilimi),
          const SizedBox(height: 12),
          _Dagilim(baslik: 'Makine / ekipmana göre (onaylı)', l: o.makineDagilimi),
        ],
      ],
    );
  }
}

class _Etiket extends StatelessWidget {
  const _Etiket(this.metin, this.yazi, this.zemin);
  final String metin;
  final Color yazi, zemin;

  factory _Etiket.durum(String s) {
    switch (s) {
      case 'Tamamlandı':
        return _Etiket(s, Renk.yesil, Renk.yesilAcik);
      case 'Devam ediyor':
        return _Etiket(s, Renk.mavi, Renk.maviAcik);
      case 'Parça bekleniyor':
        return _Etiket(s, Renk.amber, Renk.amberAcik);
      default:
        return _Etiket(s.isEmpty ? 'Durum yok' : s, Renk.soluk, Renk.cizgi);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: zemin, borderRadius: BorderRadius.circular(6)),
        child: Text(metin,
            style: TextStyle(color: yazi, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class _KayitKarti extends StatelessWidget {
  const _KayitKarti(this.x);
  final BakimOnarimKaydi x;

  @override
  Widget build(BuildContext context) {
    Widget satir(String ad, String deger) => deger.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '$ad: ', style: const TextStyle(color: Renk.soluk)),
              TextSpan(text: deger),
            ]), style: const TextStyle(fontSize: 13.5, color: Renk.yazi, height: 1.3)),
          );
    final ust = [
      x.ciftlikAdi,
      x.zaman,
      if (x.no.isNotEmpty) 'Kayıt ${x.no}',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Renk.kart,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: x.onayli ? Renk.cizgi : Renk.amber.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  [x.makine, x.islem].where((s) => s.isNotEmpty).join(' – '),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Renk.yazi),
                ),
              ),
              const SizedBox(width: 8),
              _Etiket.durum(x.durum),
            ],
          ),
          const SizedBox(height: 2),
          Text(ust, style: const TextStyle(fontSize: 12.5, color: Renk.soluk)),
          satir('Yapılan iş', x.yapilanIs),
          satir('Malzeme / yedek parça', x.malzeme),
          satir('Tedarik durumu', x.tedarik),
          satir('Çalışma saati / km', x.sayac),
          satir('Servis', x.servis),
          satir('Bildiren', x.bildiren),
          const SizedBox(height: 6),
          x.onayli
              ? Text(
                  'Onaylandı${x.onayZamani.isEmpty ? '' : ' (${x.onayZamani})'}',
                  style: const TextStyle(fontSize: 12.5, color: Renk.yesil, fontWeight: FontWeight.w600),
                )
              : const _Etiket('Onay bekliyor', Renk.amber, Renk.amberAcik),
        ],
      ),
    );
  }
}

class _Dagilim extends StatelessWidget {
  const _Dagilim({required this.baslik, required this.l});
  final String baslik;
  final List<MapEntry<String, int>> l;

  @override
  Widget build(BuildContext context) {
    if (l.isEmpty) return const SizedBox.shrink();
    final enCok = l.first.value;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Renk.kart,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Renk.cizgi),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(baslik, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Renk.yazi)),
          const SizedBox(height: 8),
          for (final e in l.take(8))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(flex: 4, child: Text(e.key, overflow: TextOverflow.ellipsis)),
                  Expanded(
                    flex: 5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: enCok == 0 ? 0 : e.value / enCok,
                        minHeight: 8,
                        color: Renk.ana,
                        backgroundColor: Renk.anaAcik,
                      ),
                    ),
                  ),
                  SizedBox(
                      width: 32,
                      child: Text('${e.value}', textAlign: TextAlign.right)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
