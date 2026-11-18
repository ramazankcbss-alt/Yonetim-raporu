import 'package:flutter/material.dart';

import '../bicim.dart';
import '../tema.dart';
import '../veri/detay.dart';
import '../veri/model.dart';
import 'bilesenler.dart';

/// İşletme günlük raporlarının (Fethiye, Erentepe, Aslım, ESK-Taşağıl) tüm
/// göstergeleri: sürü yapısı, süt, sürüden çıkanlar, doğum/giriş, personel
/// sayıları. Günlük ekranda tek gün, haftalık ekranda hafta özeti.
class IsletmeDetayPaneli extends StatefulWidget {
  const IsletmeDetayPaneli({
    super.key,
    required this.veri,
    required this.bas,
    required this.son,
  });

  final RaporVerisi veri;
  final DateTime bas, son;

  @override
  State<IsletmeDetayPaneli> createState() => _IsletmeDetayPaneliState();
}

class _IsletmeDetayPaneliState extends State<IsletmeDetayPaneli> {
  String _isletme = detayIsletmeleri.first;

  @override
  Widget build(BuildContext context) {
    final v = widget.veri;
    final bolumler = isletmeDetayi(v, _isletme, widget.bas, widget.son);
    final gunler = detayGunleri(v, _isletme, widget.bas, widget.son);
    final tekGun = gunu(widget.bas) == gunu(widget.son);
    return Panel(
      baslik: 'İşletme Raporları',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final i in detayIsletmeleri)
                ChoiceChip(
                  label: Text(i.replaceAll(' Çiftliği', '').replaceAll(' Şube', '')),
                  selected: i == _isletme,
                  onSelected: (_) => setState(() => _isletme = i),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (bolumler.isEmpty)
            const BosDurum(
                ikon: Icons.description_outlined,
                yazi: 'Bu dönem için işletme raporu verisi yok.')
          else ...[
            Text(
              tekGun
                  ? 'Kaynak: işletme günlük raporu, ${tarihKisa(gunler.last)}'
                  : 'Kaynak: işletme günlük raporları, ${gunler.length} gün '
                      '(${gunAy(gunler.first)} – ${gunAy(gunler.last)}). '
                      'Hareketler dönem toplamı, hayvan sayıları ${gunAy(gunler.last)} itibarıyla.',
              style: const TextStyle(fontSize: 12, color: Renk.soluk),
            ),
            for (final b in bolumler) ...[
              const SizedBox(height: 12),
              Text(
                tekGun || b.tur == DetayTur.sonGun
                    ? b.ad
                    : '${b.ad} (${b.turAciklama})',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: cikisMi(b.ad) || b.ad == 'Sürüden Çıkanlar'
                        ? Renk.turuncu
                        : Renk.yazi),
              ),
              const SizedBox(height: 4),
              VeriTablosu(
                basliklar: const ['Gösterge', 'Değer'],
                satirlar: [
                  for (final s in b.satirlar)
                    [
                      s.etiket,
                      sayi(s.deger,
                          ondalik: s.deger == s.deger.roundToDouble() ? 0 : 1)
                    ],
                ],
                ilkSutunGenislik: 220,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
