import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// Günlük Drive incelemesinin bulguları: diğer Drive dosyalarında bulunan,
/// rapor kapsamındaki bilgiler. "Onay bekliyor" olanlar kullanıcı onayıyla
/// rapora alınır; "Rapora eklendi" olanlar PDF'te de yer alır.
class DriveBulgulariPaneli extends StatelessWidget {
  const DriveBulgulariPaneli({super.key, required this.veri, required this.bas, required this.son});

  final RaporVerisi veri;
  final DateTime bas, son;

  @override
  Widget build(BuildContext context) {
    final liste = veri.bulgularDonem(bas, son);
    if (liste.isEmpty) return const SizedBox.shrink();
    (Color, Color) renk(DriveBulgu b) => b.eklendi
        ? (Renk.yesil, Renk.yesilAcik)
        : b.onayBekliyor
            ? (Renk.amber, Renk.amberAcik)
            : (Renk.soluk, Renk.zemin);
    return Panel(
      baslik: 'Diğer Drive Dosyalarından Bilgiler',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final b in liste)
            InkWell(
              onTap: b.baglanti.startsWith('http')
                  ? () => launchUrl(Uri.parse(b.baglanti), mode: LaunchMode.externalApplication)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          [b.konu, if (b.ciftlik.isNotEmpty) b.ciftlik].join(' · '),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: renk(b).$2, borderRadius: BorderRadius.circular(10)),
                        child: Text(b.durum.isEmpty ? 'Bilgi' : b.durum,
                            style: TextStyle(fontSize: 11, color: renk(b).$1)),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    Text(b.bulgu, style: const TextStyle(fontSize: 13)),
                    Text('${b.dosya} · ${tarihKisa(b.gun)}',
                        style: const TextStyle(fontSize: 11.5, color: Renk.soluk)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
