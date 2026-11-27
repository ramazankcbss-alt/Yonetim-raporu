import 'package:flutter/material.dart';

import '../servis/bildirim_servisi.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/bildirim.dart';
import '../veri/model.dart';
import 'stok_suru.dart';
import 'veri_kalitesi.dart';
import 'yonetim_ozeti.dart';

/// Asistan › Bildirimler: karar gerektiren durumlar (kritik, günlük özet, bilgi).
class BildirimlerEkran extends StatelessWidget {
  const BildirimlerEkran({super.key, required this.veri});
  final RaporVerisi veri;

  void _ac(BuildContext context, UygulamaBildirimi b) {
    final v = VeriDeposu.ben.veri ?? veri;
    BildirimServisi.ben.okundu([b.anahtar]);
    final Widget e = switch (b.hedef) {
      BildirimHedefi.veriKalitesi => VeriKalitesiEkran(veri: v),
      BildirimHedefi.stokSuru => StokSuruEkran(veri: v),
      BildirimHedefi.yonetimOzeti || BildirimHedefi.aylikRapor => YonetimOzetiEkran(veri: v),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => e));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: BildirimServisi.ben,
        builder: (context, _) {
          final s = BildirimServisi.ben;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Bildirimler'),
              actions: [
                if (s.okunmamis > 0)
                  TextButton(
                    onPressed: () => s.okundu(s.liste.map((b) => b.anahtar)),
                    child: const Text('Tümünü okundu say', style: TextStyle(color: Colors.white)),
                  ),
              ],
            ),
            body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
              Panel(
                baslik: 'Telefon bildirimi',
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Kritik durumlarda telefona bildirim gönder'),
                    subtitle: const Text('Birim maliyetin satış fiyatını geçmesi, sürü kaybının artması'),
                    value: s.sistemAcik,
                    onChanged: (x) async {
                      final ok = await s.sistemBildirimiAyarla(x);
                      if (x && !ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bildirim izni verilmedi; telefon ayarlarından açılabilir.')));
                      }
                    },
                  ),
                  const Text(
                    'Bildirimler uygulama yeni veri aldığında değerlendirilir; aynı durum için bir kez gönderilir. '
                    'Kilit ekranında içerik gizlenir. Bildirimlerde kişi adı ve kişi bazında tutar yer almaz.',
                    style: TextStyle(fontSize: 12, color: Renk.soluk, height: 1.4),
                  ),
                ]),
              ),
              if (s.liste.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Şu an bildirim yok.', style: TextStyle(fontSize: 14)),
                ),
              for (final o in BildirimOnceligi.values)
                if (s.liste.any((b) => b.oncelik == o))
                  Panel(
                    baslik: oncelikAdi(o),
                    child: Column(children: [
                      for (final b in s.liste)
                        if (b.oncelik == o)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              o == BildirimOnceligi.kritik
                                  ? Icons.warning_amber_rounded
                                  : (o == BildirimOnceligi.ozet ? Icons.notifications_none : Icons.info_outline),
                              color: o == BildirimOnceligi.kritik ? Renk.kirmizi : (o == BildirimOnceligi.ozet ? Renk.amber : Renk.mavi),
                            ),
                            title: Text(b.baslik,
                                style: TextStyle(fontWeight: s.okunan.contains(b.anahtar) ? FontWeight.w400 : FontWeight.w700, fontSize: 14)),
                            subtitle: Text(b.metin, style: const TextStyle(fontSize: 12.5, height: 1.35)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _ac(context, b),
                          ),
                    ]),
                  ),
            ]),
          );
        },
      );
}
