import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/ozel.dart';
import 'bilesenler.dart';

/// Özel Notlar: yalnızca sana özel olumsuzluk / uyuşmazlık / öneri notları.
/// Salt okunur; notlar otomatik günlük takiple hazırlanır. PIN arkasındadır.
class OzelNotlarEkran extends StatefulWidget {
  const OzelNotlarEkran({super.key});

  @override
  State<OzelNotlarEkran> createState() => _OzelNotlarEkranState();
}

class _OzelNotlarEkranState extends State<OzelNotlarEkran> {
  late Future<OzelVeri> _f;

  @override
  void initState() {
    super.initState();
    _f = VeriDeposu.ben.ozelGetir();
  }

  void _yenile() => setState(() {
        _f = VeriDeposu.ben.ozelGetir();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Özel Notlar'),
        actions: [
          IconButton(
              tooltip: 'Yenile',
              onPressed: _yenile,
              icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<OzelVeri>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return HataGovde(mesaj: '${snap.error}', yenile: _yenile);
          }
          final liste = snap.data!.ozelNotlar.reversed.toList();
          if (liste.isEmpty) {
            return const BosDurum(
                ikon: Icons.lock_outline,
                yazi: 'Henüz sana özel bir not yok.');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8, left: 2),
                child: Text(
                    'Bu notlar yalnızca sende görünür; rapora ve yönetime girmez.',
                    style: TextStyle(fontSize: 12.5, color: Renk.soluk)),
              ),
              for (final n in liste) _Kart(n: n),
            ],
          );
        },
      ),
    );
  }
}

Color _turRenk(String t) {
  switch (t) {
    case 'Olumsuzluk':
      return Renk.kirmizi;
    case 'Uyuşmazlık':
      return Renk.turuncu;
    case 'Öneri':
      return Renk.yesil;
    case 'Çözüldü':
      return Renk.soluk;
  }
  return Renk.mavi;
}

class _Kart extends StatelessWidget {
  const _Kart({required this.n});

  final OzelNot n;

  @override
  Widget build(BuildContext context) {
    final renk = _turRenk(n.tur);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: renk.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(n.tur.isEmpty ? 'Not' : n.tur,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: renk)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(n.konu,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Renk.yazi)),
              ),
            ],
          ),
          if (n.not.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(n.not,
                style: const TextStyle(
                    fontSize: 14, color: Renk.yazi, height: 1.4)),
          ],
          const SizedBox(height: 6),
          Text(
            [
              if (n.tarih != null) tarihKisa(n.tarih!),
              if (n.kaynak.isNotEmpty) n.kaynak,
            ].join(' · '),
            style: const TextStyle(fontSize: 11.5, color: Renk.soluk),
          ),
        ],
      ),
    );
  }
}
