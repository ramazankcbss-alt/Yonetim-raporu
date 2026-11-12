import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
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
    // Her dönem içinde en yeni tarih en üstte.
    for (final l in gruplar.values) {
      l.sort((a, b) => (b.tarih ?? DateTime(2000))
          .compareTo(a.tarih ?? DateTime(2000)));
    }
    // Dönemleri kronolojik: en yeni ay-yıl üstte, "Diğer" en sonda.
    final donemler = gruplar.keys.toList()
      ..sort((a, b) {
        if (a == 'Diğer') return 1;
        if (b == 'Diğer') return -1;
        return _donemSira(b).compareTo(_donemSira(a));
      });

    final belgeler = kayitlar.isEmpty
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
          );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Personel / Puantaj'),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Personel (${veri.personelListesi.length})'),
              Tab(text: 'Puantaj / İK (${kayitlar.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            PersonelListesi(veri: veri),
            belgeler,
          ],
        ),
      ),
    );
  }
}

const _aylar = [
  'ocak', 'şubat', 'mart', 'nisan', 'mayıs', 'haziran',
  'temmuz', 'ağustos', 'eylül', 'ekim', 'kasım', 'aralık'
];

/// "Ekim 2026" gibi bir dönemi sıralanabilir sayıya çevirir (yıl*100 + ay).
/// Çözülemezse 0.
int _donemSira(String donem) {
  final s = donem.toLowerCase();
  var ay = 0;
  for (var i = 0; i < _aylar.length; i++) {
    if (s.contains(_aylar[i])) {
      ay = i + 1;
      break;
    }
  }
  final yil = int.tryParse(RegExp(r'(19|20)\d{2}').firstMatch(s)?.group(0) ?? '') ?? 0;
  return yil * 100 + ay;
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


/// Tüm çiftlik personeli (ad, görev, birim); seçilenler Kişiler'e eklenir.
class PersonelListesi extends StatefulWidget {
  const PersonelListesi({super.key, required this.veri});

  final RaporVerisi veri;

  @override
  State<PersonelListesi> createState() => _PersonelListesiState();
}

class _PersonelListesiState extends State<PersonelListesi> {
  String _ara = '';
  final _secili = <String>{};
  bool _ekleniyor = false;

  Future<void> _ekle(List<PersonelKisi> secilenler) async {
    setState(() => _ekleniyor = true);
    var n = 0;
    try {
      for (final p in secilenler) {
        await VeriDeposu.ben.kisiKaydet(
          p.ad,
          telefon: p.telefon,
          eposta: '',
          birim: [p.gorev, p.birim].where((e) => e.isNotEmpty).join(' – '),
          yenilensin: false,
        );
        n++;
      }
      await VeriDeposu.ben.yenile();
      if (mounted) {
        setState(_secili.clear);
        bildir(context, "$n kişi Kişiler'e eklendi.");
      }
    } on VeriHatasi catch (e) {
      if (mounted) bildir(context, '$n kişi eklendi; sonra hata: ${e.mesaj}');
    } catch (_) {
      if (mounted) bildir(context, '$n kişi eklendi; kalanlar eklenemedi.');
    } finally {
      if (mounted) setState(() => _ekleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final veri = VeriDeposu.ben.veri ?? widget.veri;
    final mevcut = {for (final k in veri.kisiler) trKucuk(k.ad)};
    final q = trKucuk(_ara);
    final liste = [
      for (final p in veri.personelListesi)
        if (q.isEmpty || p.aranabilir.contains(q)) p
    ];
    final gruplar = <String, List<PersonelKisi>>{};
    for (final p in liste) {
      (gruplar[p.birim.isEmpty ? 'Diğer' : p.birim] ??= []).add(p);
    }
    final secilenler = [
      for (final p in veri.personelListesi)
        if (_secili.contains(p.ad)) p
    ];
    if (veri.personelListesi.isEmpty) {
      return const BosDurum(
          ikon: Icons.people_outline,
          yazi: "Personel listesi boş. Rapor tablosundaki 'Personel_Listesi' "
              'sayfası doldurulunca burada görünür.');
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() => _ara = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Ara: ad, görev ya da birim',
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            children: [
              for (final b in (gruplar.keys.toList()..sort())) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                  child: Text('$b (${gruplar[b]!.length})',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: Renk.ana)),
                ),
                for (final p in gruplar[b]!)
                  mevcut.contains(trKucuk(p.ad))
                      ? ListTile(
                          dense: true,
                          leading: const Icon(Icons.check_circle,
                              color: Renk.yesil),
                          title: Text(p.ad),
                          subtitle: Text('${p.gorev} · Kişiler\'de'),
                        )
                      : CheckboxListTile(
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _secili.contains(p.ad),
                          onChanged: (v) => setState(() => v == true
                              ? _secili.add(p.ad)
                              : _secili.remove(p.ad)),
                          title: Text(p.ad),
                          subtitle: Text(p.gorev),
                        ),
              ],
            ],
          ),
        ),
        if (secilenler.isNotEmpty)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Buton(
                yazi: "Seçilen ${secilenler.length} kişiyi Kişiler'e ekle",
                ikon: Icons.person_add_alt_1,
                mesgul: _ekleniyor,
                onTap: () => _ekle(secilenler),
              ),
            ),
          ),
      ],
    );
  }
}
