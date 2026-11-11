import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/ozel.dart';
import 'bilesenler.dart';
import 'form.dart';

/// Günlük (sırdaş defteri): aklından geçenler; kimseyle paylaşılmaz. PIN
/// arkasındadır, rapora ve toplantı mailine girmez.
class GunceEkran extends StatefulWidget {
  const GunceEkran({super.key});

  @override
  State<GunceEkran> createState() => _GunceEkranState();
}

class _GunceEkranState extends State<GunceEkran> {
  late Future<OzelVeri> _f;

  @override
  void initState() {
    super.initState();
    _f = VeriDeposu.ben.ozelGetir();
  }

  void _yenile() => setState(() {
        _f = VeriDeposu.ben.ozelGetir();
      });

  Future<void> _yaz() async {
    final sonuc = await formGoster(
      context,
      baslik: 'Günlük',
      gonderYazi: 'Kaydet',
      alanlar: const [
        AlanTanim('baslik', 'Başlık'),
        AlanTanim('icerik', 'Yaz...', cokSatir: true, zorunlu: true),
      ],
      gonder: (d) => VeriDeposu.ben.ozelGonder('gunluk', d),
    );
    if (sonuc == true && mounted) {
      bildir(context, 'Kaydedildi.');
      _yenile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Günlük'),
        actions: [
          IconButton(
              tooltip: 'Yenile',
              onPressed: _yenile,
              icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _yaz,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Yaz')),
      body: FutureBuilder<OzelVeri>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return HataGovde(mesaj: '${snap.error}', yenile: _yenile);
          }
          final liste = snap.data!.gunce.reversed.toList();
          if (liste.isEmpty) {
            return const BosDurum(
                ikon: Icons.menu_book_outlined,
                yazi: 'Defter boş.\nSağ alttan yazmaya başlayabilirsin.');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [for (final g in liste) _Kart(g: g)],
          );
        },
      ),
    );
  }
}

class _Kart extends StatelessWidget {
  const _Kart({required this.g});

  final GunceGiris g;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (g.baslik.isNotEmpty)
                Expanded(
                  child: Text(g.baslik,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Renk.yazi)),
                )
              else
                const Spacer(),
              if (g.tarih != null)
                Text(tarihKisa(g.tarih!),
                    style: const TextStyle(fontSize: 12, color: Renk.soluk)),
            ],
          ),
          if (g.icerik.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(g.icerik,
                style: const TextStyle(
                    fontSize: 14, color: Renk.yazi, height: 1.45)),
          ],
        ],
      ),
    );
  }
}
