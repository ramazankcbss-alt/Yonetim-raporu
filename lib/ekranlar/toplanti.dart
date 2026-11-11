import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/ozel.dart';
import 'bilesenler.dart';
import 'form.dart';

/// Toplantı Notları: toplantıları kaydet; zamanla birleştirilip analiz edilir.
class ToplantiEkran extends StatefulWidget {
  const ToplantiEkran({super.key});

  @override
  State<ToplantiEkran> createState() => _ToplantiEkranState();
}

class _ToplantiEkranState extends State<ToplantiEkran> {
  late Future<OzelVeri> _f;

  @override
  void initState() {
    super.initState();
    _f = VeriDeposu.ben.ozelGetir();
  }

  void _yenile() => setState(() {
        _f = VeriDeposu.ben.ozelGetir();
      });

  Future<void> _ekle() async {
    final sonuc = await formGoster(
      context,
      baslik: 'Toplantı notu',
      gonderYazi: 'Kaydet',
      alanlar: const [
        AlanTanim('yer', 'Yer / ortam'),
        AlanTanim('katilimcilar', 'Katılımcılar'),
        AlanTanim('konular', 'Konu(lar)'),
        AlanTanim('notlar', 'Konuşulanlar', cokSatir: true, zorunlu: true),
      ],
      gonder: (d) => VeriDeposu.ben.ozelGonder('toplanti', d),
    );
    if (sonuc == true && mounted) {
      bildir(context, 'Toplantı notu kaydedildi.');
      _yenile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Toplantı Notları'),
        actions: [
          IconButton(
              tooltip: 'Yenile',
              onPressed: _yenile,
              icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _ekle,
          icon: const Icon(Icons.add),
          label: const Text('Toplantı ekle')),
      body: FutureBuilder<OzelVeri>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return HataGovde(mesaj: '${snap.error}', yenile: _yenile);
          }
          final liste = snap.data!.toplanti.reversed.toList();
          if (liste.isEmpty) {
            return const BosDurum(
                ikon: Icons.groups_outlined,
                yazi:
                    'Henüz toplantı notu yok.\nBir toplantıdan sonra konuşulanları buraya ekle.');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [for (final t in liste) _Kart(t: t)],
          );
        },
      ),
    );
  }
}

class _Kart extends StatelessWidget {
  const _Kart({required this.t});

  final ToplantiNotu t;

  @override
  Widget build(BuildContext context) {
    final baslik = [
      if (t.tarih != null) tarihKisa(t.tarih!),
      if (t.yer.isNotEmpty) t.yer,
    ].join(' · ');
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (baslik.isNotEmpty)
            Text(baslik,
                style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Renk.yazi)),
          if (t.katilimcilar.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('Katılımcılar: ${t.katilimcilar}',
                style: const TextStyle(fontSize: 12.5, color: Renk.soluk)),
          ],
          if (t.konular.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(t.konular,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Renk.yazi)),
          ],
          if (t.notlar.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(t.notlar,
                style: const TextStyle(
                    fontSize: 14, color: Renk.yazi, height: 1.4)),
          ],
          if (t.analiz.isNotEmpty) ...[
            const SizedBox(height: 10),
            _Kutu(baslik: 'Analiz', yazi: t.analiz, renk: Renk.anaAcik),
          ],
          if (t.takip.isNotEmpty) ...[
            const SizedBox(height: 8),
            _Kutu(baslik: 'Takip / aksiyon', yazi: t.takip, renk: Renk.amberAcik),
          ],
        ],
      ),
    );
  }
}

class _Kutu extends StatelessWidget {
  const _Kutu({required this.baslik, required this.yazi, required this.renk});

  final String baslik, yazi;
  final Color renk;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration:
            BoxDecoration(color: renk, borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(baslik,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Renk.yazi)),
            const SizedBox(height: 4),
            Text(yazi,
                style: const TextStyle(
                    fontSize: 14, color: Renk.yazi, height: 1.4)),
          ],
        ),
      );
}
