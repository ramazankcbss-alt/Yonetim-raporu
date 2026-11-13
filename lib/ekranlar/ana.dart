import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/guncelleme.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import 'asistan.dart';
import 'ayarlar.dart';
import 'bilesenler.dart';
import 'gunluk.dart';
import 'haftalik.dart';
import 'kurulum.dart';
import 'rapor.dart';
import 'tarim.dart';

/// Bağlantı yoksa kurulum, varsa ana ekran.
class Kapi extends StatelessWidget {
  const Kapi({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VeriDeposu.ben,
      builder: (context, _) => VeriDeposu.ben.link == null
          ? const KurulumEkrani(ilk: true)
          : const AnaEkran(),
    );
  }
}

class AnaEkran extends StatefulWidget {
  const AnaEkran({super.key, this.guncellemeKontrolu = true});

  /// Testlerde kapatılır.
  final bool guncellemeKontrolu;

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> with WidgetsBindingObserver {
  int _sekme = 0;
  final d = VeriDeposu.ben;

  static const _basliklar = [
    'Günlük Pano',
    'Haftalık Pano',
    'Tarım',
    'Rapor Gönder',
    'Asistan',
  ];

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama tekrar öne gelince veri 5 dakikadan eskiyse kendiliğinden yenile.
    if (state != AppLifecycleState.resumed || d.yukleniyor) return;
    final son = d.sonAlinma;
    if (son == null || DateTime.now().difference(son).inMinutes >= 5) d.yenile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      d.yenile();
      if (widget.guncellemeKontrolu) Guncelleme.kontrolEt(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: d,
      builder: (context, _) {
        final veri = d.veri;
        Widget govde;
        if (veri == null) {
          govde = d.yukleniyor
              ? const Center(child: CircularProgressIndicator())
              : _HataGovde(
                  mesaj: d.hata ?? 'Veri henüz alınmadı.',
                  yenile: d.yenile,
                );
        } else {
          final sayfalar = [
            GunlukEkran(veri: veri),
            HaftalikEkran(veri: veri),
            TarimEkran(veri: veri),
            RaporEkran(veri: veri),
            AsistanEkran(veri: veri),
          ];
          govde = Column(
            children: [
              if (d.hata != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: BilgiKutusu(
                    uyari: true,
                    yazi: '${d.hata}'
                        '${d.sonAlinma == null ? '' : '\nGösterilen veri: ${zamanBicim(d.sonAlinma!)}'}',
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: d.yenile,
                  child: IndexedStack(index: _sekme, children: sayfalar),
                ),
              ),
            ],
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_basliklar[_sekme]),
                if (d.sonAlinma != null)
                  Text(
                    'Güncelleme: ${zamanBicim(d.sonAlinma!)}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white70),
                  ),
              ],
            ),
            actions: [
              d.yukleniyor
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white)),
                    )
                  : IconButton(
                      tooltip: 'Yenile',
                      icon: const Icon(Icons.refresh),
                      onPressed: d.yenile,
                    ),
              IconButton(
                tooltip: 'Ayarlar',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AyarlarEkran())),
              ),
            ],
          ),
          body: govde,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _sekme,
            onDestinationSelected: (i) => setState(() => _sekme = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.today_outlined),
                  selectedIcon: Icon(Icons.today),
                  label: 'Günlük'),
              NavigationDestination(
                  icon: Icon(Icons.date_range_outlined),
                  selectedIcon: Icon(Icons.date_range),
                  label: 'Haftalık'),
              NavigationDestination(
                  icon: Icon(Icons.agriculture_outlined),
                  selectedIcon: Icon(Icons.agriculture),
                  label: 'Tarım'),
              NavigationDestination(
                  icon: Icon(Icons.picture_as_pdf_outlined),
                  selectedIcon: Icon(Icons.picture_as_pdf),
                  label: 'Rapor'),
              NavigationDestination(
                  icon: Icon(Icons.support_agent_outlined),
                  selectedIcon: Icon(Icons.support_agent),
                  label: 'Asistan'),
            ],
          ),
        );
      },
    );
  }
}

class _HataGovde extends StatelessWidget {
  const _HataGovde({required this.mesaj, required this.yenile});

  final String mesaj;
  final Future<void> Function() yenile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.cloud_off_outlined, size: 52, color: Renk.soluk),
        const SizedBox(height: 12),
        Text(mesaj,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Renk.yazi)),
        const SizedBox(height: 20),
        Buton(yazi: 'Tekrar dene', ikon: Icons.refresh, onTap: yenile),
        const SizedBox(height: 10),
        Buton(
          yazi: 'Bağlantı linkini değiştir',
          ikon: Icons.link,
          renk: ButonRenk.ikincil,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const KurulumEkrani(ilk: false))),
        ),
      ],
    );
  }
}
