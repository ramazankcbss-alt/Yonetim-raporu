import 'package:flutter/material.dart';

import '../bicim.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'bilesenler.dart';

/// Belge Havuzu — gelen tüm iş maillerinin/belgelerinin aranabilir kataloğu.
/// Veri rapor E-Tablosundaki "Arşiv" sayfasından gelir; otomatik görev
/// mailleri kategorize edip buraya işler, her ay düzenli gelenleri gruplar.
class ArsivEkran extends StatefulWidget {
  const ArsivEkran({super.key, required this.veri});

  final RaporVerisi veri;

  @override
  State<ArsivEkran> createState() => _ArsivEkranState();
}

class _ArsivEkranState extends State<ArsivEkran> {
  final _denetleyici = TextEditingController();
  String _arama = '';
  String? _kategori;

  @override
  void dispose() {
    _denetleyici.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arsiv = widget.veri.arsiv;

    final kategoriler = <String>{
      for (final a in arsiv)
        if (a.kategori.trim().isNotEmpty) a.kategori.trim()
    }.toList()
      ..sort();

    final q = _arama.trim().toLowerCase();
    final liste = arsiv
        .where((a) => _kategori == null || a.kategori.trim() == _kategori)
        .where((a) => q.isEmpty || a.aranabilir.contains(q))
        .toList()
      ..sort((a, b) => (b.tarih ?? DateTime(2000))
          .compareTo(a.tarih ?? DateTime(2000)));

    return Scaffold(
      appBar: AppBar(title: const Text('Belge Havuzu')),
      body: arsiv.isEmpty
          ? const BosDurum(
              ikon: Icons.inbox_outlined,
              yazi:
                  'Henüz arşivlenen belge yok.\nGelen mailler kategorize edilip buraya işlenir.')
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _denetleyici,
                    onChanged: (d) => setState(() => _arama = d),
                    decoration: InputDecoration(
                      hintText: 'Ara: konu, firma, belge, özet…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _arama.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _denetleyici.clear();
                                setState(() => _arama = '');
                              },
                            ),
                      isDense: true,
                      filled: true,
                      fillColor: Renk.kart,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Renk.cizgi),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Renk.cizgi),
                      ),
                    ),
                  ),
                ),
                if (kategoriler.isNotEmpty)
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _KatCip(
                          yazi: 'Tümü',
                          renk: Renk.soluk,
                          secili: _kategori == null,
                          onTap: () => setState(() => _kategori = null),
                        ),
                        for (final k in kategoriler)
                          _KatCip(
                            yazi: k,
                            renk: katRenk(k),
                            secili: _kategori == k,
                            onTap: () => setState(
                                () => _kategori = _kategori == k ? null : k),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: liste.isEmpty
                      ? const BosDurum(
                          ikon: Icons.search_off, yazi: 'Eşleşen kayıt yok.')
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: liste.length,
                          itemBuilder: (_, i) => _ArsivKart(kayit: liste[i]),
                        ),
                ),
              ],
            ),
    );
  }
}

Color katRenk(String k) {
  final s = k.toLowerCase();
  if (s.contains('puantaj') || s.contains('insan') || s.contains('ik')) {
    return Renk.mavi;
  }
  if (s.contains('fatura') || s.contains('muhasebe')) return Renk.ana;
  if (s.contains('ödeme') || s.contains('odeme') || s.contains('finans')) {
    return const Color(0xFF7C3AED);
  }
  if (s.contains('sipariş') || s.contains('siparis') || s.contains('satın')) {
    return Renk.amber;
  }
  if (s.contains('tarım') || s.contains('tarim') || s.contains('ziraat')) {
    return Renk.yesil;
  }
  if (s.contains('rapor')) return Renk.turuncu;
  return Renk.soluk;
}

class _KatCip extends StatelessWidget {
  const _KatCip(
      {required this.yazi,
      required this.renk,
      required this.secili,
      required this.onTap});

  final String yazi;
  final Color renk;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: secili ? renk.withValues(alpha: 0.16) : Renk.kart,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: secili ? renk : Renk.cizgi, width: secili ? 1.5 : 1),
            ),
            child: Text(yazi,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: secili ? FontWeight.w700 : FontWeight.w500,
                    color: secili ? renk : Renk.yazi)),
          ),
        ),
      ),
    );
  }
}

class _ArsivKart extends StatelessWidget {
  const _ArsivKart({required this.kayit});

  final ArsivKaydi kayit;

  @override
  Widget build(BuildContext context) {
    final renk = katRenk(kayit.kategori);
    final alt = [
      if (kayit.gonderen.isNotEmpty) kayit.gonderen,
      if (kayit.tarih != null) tarihKisa(kayit.tarih!),
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Renk.kart,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Renk.cizgi),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (kayit.kategori.isNotEmpty) ...[
                _Rozet(yazi: kayit.kategori, renk: renk),
                const SizedBox(width: 6),
              ],
              if (kayit.aylikMi)
                _Rozet(
                    yazi: kayit.periyot.isEmpty ? 'Aylık' : kayit.periyot,
                    renk: Renk.soluk),
              const Spacer(),
              if (kayit.ekliMi)
                const Icon(Icons.attach_file, size: 16, color: Renk.soluk),
            ],
          ),
          const SizedBox(height: 8),
          Text(kayit.konu,
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Renk.yazi,
                  height: 1.3)),
          if (alt.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(alt,
                style: const TextStyle(fontSize: 12.5, color: Renk.soluk)),
          ],
          if (kayit.ozet.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(kayit.ozet,
                style: const TextStyle(
                    fontSize: 13.5, color: Renk.yazi, height: 1.35)),
          ],
          if (kayit.ekliMi) ...[
            const SizedBox(height: 6),
            Text('Ekler: ${kayit.ekler}',
                style: const TextStyle(
                    fontSize: 12, color: Renk.soluk, height: 1.3)),
          ],
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
