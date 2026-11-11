import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/ozel.dart';
import 'bilesenler.dart';
import 'form.dart';

/// Danışmanlık: bir konuyu sor, hazırlanan değerlendirmeyi gör.
class DanismanlikEkran extends StatefulWidget {
  const DanismanlikEkran({super.key});

  @override
  State<DanismanlikEkran> createState() => _DanismanlikEkranState();
}

class _DanismanlikEkranState extends State<DanismanlikEkran> {
  late Future<OzelVeri> _f;

  @override
  void initState() {
    super.initState();
    _f = VeriDeposu.ben.ozelGetir();
  }

  void _yenile() => setState(() {
        _f = VeriDeposu.ben.ozelGetir();
      });

  Future<void> _soruSor() async {
    final sonuc = await formGoster(
      context,
      baslik: 'Yeni danışma',
      gonderYazi: 'Gönder',
      alanlar: const [
        AlanTanim('konu', 'Konu', zorunlu: true),
        AlanTanim('soru', 'Sormak istediğin', cokSatir: true, zorunlu: true),
      ],
      gonder: (d) => VeriDeposu.ben.ozelGonder('danismanlik', d),
    );
    if (sonuc == true && mounted) {
      bildir(context, 'Soru kaydedildi. Değerlendirme hazırlanınca burada görünür.');
      _yenile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danışmanlık'),
        actions: [
          IconButton(
              tooltip: 'Yenile',
              onPressed: _yenile,
              icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _soruSor,
          icon: const Icon(Icons.add),
          label: const Text('Soru sor')),
      body: FutureBuilder<OzelVeri>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return HataGovde(mesaj: '${snap.error}', yenile: _yenile);
          }
          final liste = snap.data!.danismanlik.reversed.toList();
          if (liste.isEmpty) {
            return const BosDurum(
                ikon: Icons.forum_outlined,
                yazi:
                    'Henüz danışılan bir konu yok.\nSağ alttan soru sorabilirsin.');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [for (final k in liste) _Kart(k: k)],
          );
        },
      ),
    );
  }
}

class _Kart extends StatelessWidget {
  const _Kart({required this.k});

  final DanismanlikKaydi k;

  @override
  Widget build(BuildContext context) {
    final renk = k.yanitlandi ? Renk.yesil : Renk.amber;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(k.konu.isEmpty ? 'Danışma' : k.konu,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Renk.yazi)),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: renk.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(k.yanitlandi ? 'Yanıtlandı' : 'Bekliyor',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: renk)),
              ),
            ],
          ),
          if (k.tarih != null) ...[
            const SizedBox(height: 2),
            Text(tarihKisa(k.tarih!),
                style: const TextStyle(fontSize: 12, color: Renk.soluk)),
          ],
          if (k.soru.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(k.soru,
                style: const TextStyle(
                    fontSize: 14, color: Renk.yazi, height: 1.4)),
          ],
          if (k.yanit.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Renk.anaAcik,
                  borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Değerlendirme${k.yanitTarihi != null ? ' · ${tarihKisa(k.yanitTarihi!)}' : ''}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Renk.anaKoyu)),
                  const SizedBox(height: 4),
                  Text(k.yanit,
                      style: const TextStyle(
                          fontSize: 14, color: Renk.yazi, height: 1.4)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
