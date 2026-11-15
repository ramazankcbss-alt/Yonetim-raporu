import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../tema.dart';
import '../veri/model.dart';

/// Araç Takip uygulamasından gelen kayıtların yönetim görünümü.
class AraclarEkran extends StatelessWidget {
  const AraclarEkran({super.key, required this.veri});
  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) {
    final a = veri.arac;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Araçlar'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Genel Durum'),
              Tab(text: 'İş Emirleri'),
              Tab(text: 'Araçlar'),
              Tab(text: 'Personel'),
              Tab(text: 'Mutabakat Kontrolü'),
            ],
          ),
        ),
        body: a.bos
            ? const _Bilgi(
                'Araç Takip uygulamasından henüz kayıt gelmedi. Uygulama kurulup araçlar '
                'eklendikçe kullanım, bakım ve arıza kayıtları burada görünür.')
            : TabBarView(
                children: [
                  _Genel(a: a),
                  _IsEmirleri(a: a),
                  _AracListesi(a: a),
                  _PersonelListesi(a: a),
                  _Mutabakat(a: a),
                ],
              ),
      ),
    );
  }
}

String _sayi(double? d) {
  if (d == null) return '–';
  return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toStringAsFixed(1).replaceAll('.', ',');
}

class _Bilgi extends StatelessWidget {
  const _Bilgi(this.metin);
  final String metin;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(metin, textAlign: TextAlign.center, style: const TextStyle(color: Renk.soluk)),
        ),
      );
}

class _Etiket extends StatelessWidget {
  const _Etiket(this.metin);
  final String metin;

  static (Color, Color) renk(String s) {
    switch (s) {
      case 'Aktif':
      case 'Onaylandı':
      case 'Onarıldı':
      case 'Mutabık':
        return (Renk.yesil, Renk.yesilAcik);
      case 'Devam ediyor':
      case 'Atölyede':
      case 'Verildi':
      case 'Başladı':
        return (Renk.mavi, Renk.maviAcik);
      case 'Tamamlandı':
      case 'Parça bekleniyor':
      case 'Yaklaşıyor':
      case 'Belge Eksikliği':
        return (Renk.amber, Renk.amberAcik);
      case 'Mutabakat Farkı':
        return (Renk.turuncu, Renk.turuncuAcik);
      case 'Arızalı':
      case 'Bildirildi':
      case 'Gecikti':
      case 'Kritik Bulgu':
        return (Renk.kirmizi, Renk.kirmiziAcik);
      default:
        return (Renk.soluk, Renk.cizgi);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (y, z) = renk(metin);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: z, borderRadius: BorderRadius.circular(6)),
      child: Text(metin, style: TextStyle(color: y, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _KullanimSatiri extends StatelessWidget {
  const _KullanimSatiri(this.x, {this.personelGoster = true, this.aracGoster = true});
  final AracKullanim x;
  final bool personelGoster, aracGoster;

  @override
  Widget build(BuildContext context) {
    final baslik = [
      if (aracGoster) x.birlesik else if (x.ekipman.isNotEmpty) '+ ${x.ekipman.join(', ')}',
      if (personelGoster) x.personel,
    ].join(' · ');
    final alt = [
      '${x.baslangic}${x.bitis.isEmpty ? '' : ' → ${x.bitis.split(' ').last}'}',
      if (x.saat != null) '${_sayi(x.saat)} saat',
      if (x.is_.isNotEmpty) x.is_,
      if (x.sekil == 'Formen girişi') 'Formen girişi',
    ].join(' · ');
    final eksik = x.eksikKontroller;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(baslik.isEmpty ? x.tarih : baslik),
      subtitle: Text(eksik.isEmpty ? alt : '$alt\nBakım Uygunsuzluğu: ${eksik.join(', ')}'),
      isThreeLine: eksik.isNotEmpty,
      trailing: _Etiket(x.durum),
    );
  }
}

// ---------------------------------------------------------------------------

class _Genel extends StatelessWidget {
  const _Genel({required this.a});
  final AracVerisi a;

  @override
  Widget build(BuildContext context) {
    final aktif = a.aktif;
    final uyari = a.bakimUyarilari();
    final acikAriza = a.ariza.where((x) => !x.kapali).toList();
    final son7 = DateTime.now().subtract(const Duration(days: 7));
    final uygunsuz = a.kullanim
        .where((x) => (x.bas?.isAfter(son7) ?? false) && x.eksikKontroller.isNotEmpty)
        .toList();
    final arizali = a.araclar.where((x) => x.durum == 'Arızalı').length;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            _Sayac('Araç', '${a.araclar.where((x) => !x.ekipman).length}', Renk.ana),
            _Sayac('Aktif kullanım', '${aktif.length}', Renk.mavi),
            _Sayac('Arızalı', '$arizali', Renk.kirmizi),
            _Sayac('Bakım uyarısı', '${uyari.length}', Renk.amber),
          ],
        ),
        const SizedBox(height: 12),
        Panel(
          baslik: 'Aktif Kullanım',
          child: aktif.isEmpty
              ? const Text('Şu an kullanımda araç yok.', style: TextStyle(color: Renk.soluk))
              : Column(children: [for (final x in aktif) _KullanimSatiri(x)]),
        ),
        Panel(
          baslik: 'Periyodik Bakım Durumu',
          child: uyari.isEmpty
              ? const Text('Geciken ya da yaklaşan bakım yok.', style: TextStyle(color: Renk.soluk))
              : Column(
                  children: [
                    for (final b in uyari)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${b.arac.no} · ${b.plan.bakim}'),
                        subtitle: Text(b.gecikti
                            ? '${_sayi(-b.kalan)} saat gecikti · sayaç ${_sayi(b.arac.sayac)}'
                            : '${_sayi(b.kalan)} saat kaldı · sayaç ${_sayi(b.arac.sayac)}'),
                        trailing: _Etiket(b.gecikti ? 'Gecikti' : 'Yaklaşıyor'),
                      ),
                  ],
                ),
        ),
        Panel(
          baslik: 'Açık Arızalar',
          child: acikAriza.isEmpty
              ? const Text('Açık arıza yok.', style: TextStyle(color: Renk.soluk))
              : Column(children: [for (final x in acikAriza) _ArizaSatiri(x)]),
        ),
        Panel(
          baslik: 'Bakım Uygunsuzlukları (son 7 gün)',
          child: uygunsuz.isEmpty
              ? const Text('Kayıt yok.', style: TextStyle(color: Renk.soluk))
              : Column(children: [for (final x in uygunsuz.reversed) _KullanimSatiri(x)]),
        ),
      ],
    );
  }
}

class _Sayac extends StatelessWidget {
  const _Sayac(this.ad, this.deger, this.renk);
  final String ad, deger;
  final Color renk;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Renk.cizgi)),
          child: Column(
            children: [
              Text(deger, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: renk)),
              Text(ad, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Renk.soluk)),
            ],
          ),
        ),
      );
}

class _ArizaSatiri extends StatelessWidget {
  const _ArizaSatiri(this.x);
  final AracAriza x;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('${x.yer == 'Makine-Ekipman' ? 'Makine-ekipman' : 'Araç'} ${x.arac} · ${x.aciklama}',
            maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text([
          '${x.zaman} · ${x.bildiren}',
          if (x.gun != null) '${x.gun} gün',
          if (x.birlikte.isNotEmpty) 'Birlikte: ${x.birlikte}',
          if (x.not.isNotEmpty) x.not,
        ].join(' · ')),
        trailing: _Etiket(x.durum),
        onTap: x.foto.isEmpty
            ? null
            : () => launchUrl(Uri.parse(x.foto), mode: LaunchMode.externalApplication),
      );
}

// ---------------------------------------------------------------------------

class _AracListesi extends StatelessWidget {
  const _AracListesi({required this.a});
  final AracVerisi a;

  Widget _kart(BuildContext context, AracKaydi x) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Renk.cizgi)),
        child: ListTile(
          leading: Icon(x.ekipman ? Icons.construction_outlined : Icons.agriculture_outlined,
              color: x.durum == 'Arızalı' ? Renk.kirmizi : Renk.ana),
          title: Text(x.baslik, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${x.alt}\n${x.ekipman ? 'Çalışma saati' : 'Motor saati'}: ${_sayi(x.sayac)}'),
          isThreeLine: true,
          trailing: _Etiket(x.durum),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _AracDetay(a: a, arac: x))),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = [...a.araclar]..sort((x, y) => x.no.compareTo(y.no));
    if (l.isEmpty) return const _Bilgi('Kayıtlı araç yok.');
    final araclar = l.where((x) => !x.ekipman).toList();
    final ekipman = l.where((x) => x.ekipman).toList();
    Widget baslik(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, color: Renk.soluk)),
        );
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        baslik('Araçlar (${araclar.length})'),
        for (final x in araclar) _kart(context, x),
        if (ekipman.isNotEmpty) baslik('Makine-Ekipman (${ekipman.length})'),
        for (final x in ekipman) _kart(context, x),
      ],
    );
  }
}

class _AracDetay extends StatelessWidget {
  const _AracDetay({required this.a, required this.arac});
  final AracVerisi a;
  final AracKaydi arac;

  @override
  Widget build(BuildContext context) {
    final gecmis = a.aracGecmisi(arac.no);
    final bakim = a.bakim.where((b) => b.arac == arac.no).toList().reversed.toList();
    final ariza = a.ariza.where((b) => b.arac == arac.no).toList().reversed.toList();
    final plan = a.plan.where((p) => p.arac == arac.no).toList();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(arac.no),
          actions: [
            IconButton(
              tooltip: 'Olay Sorgulama',
              icon: const Icon(Icons.manage_search),
              onPressed: () => _olaySorgula(context),
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Kullanım Geçmişi'),
            Tab(text: 'Bakım'),
            Tab(text: 'Arıza'),
          ]),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(arac.baslik, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      Text(arac.alt, style: const TextStyle(color: Renk.soluk)),
                      const SizedBox(height: 4),
                      Text('${arac.ekipman ? 'Çalışma saati' : 'Motor saati'}: ${_sayi(arac.sayac)} · Durum: ${arac.durum}'),
                    ],
                  ),
                ),
                if (gecmis.isEmpty)
                  const _Bilgi('Kullanım kaydı yok.')
                else
                  for (final x in gecmis) _KullanimSatiri(x, aracGoster: false),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Panel(
                  baslik: 'Periyodik bakım planı',
                  child: plan.isEmpty
                      ? const Text('Plan yok.', style: TextStyle(color: Renk.soluk))
                      : Column(
                          children: [
                            for (final p in plan)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(p.bakim),
                                subtitle: Text('Her ${_sayi(p.periyot)} saat · son ${_sayi(p.son)} saat'
                                    '${p.sonTarih.isEmpty ? '' : ' (${p.sonTarih})'}'),
                              ),
                          ],
                        ),
                ),
                Panel(
                  baslik: 'Bakım ve onarım kayıtları',
                  child: bakim.isEmpty
                      ? const Text('Kayıt yok.', style: TextStyle(color: Renk.soluk))
                      : Column(
                          children: [
                            for (final b in bakim)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text([b.kayitTuru, b.bakim].where((s) => s.isNotEmpty).join(' · ')),
                                subtitle: Text([
                                  b.tarih,
                                  if (b.sayac != null) '${_sayi(b.sayac)} saat',
                                  if (b.is_.isNotEmpty) b.is_,
                                  if (b.parca.isNotEmpty) 'Parça: ${b.parca}',
                                  if (b.firma.isNotEmpty) b.firma,
                                  if (b.tutar.isNotEmpty) '${b.tutar} TL',
                                  if (b.belge.isNotEmpty) 'Belge: ${b.belge}',
                                  if (b.giren.isNotEmpty) 'Giren: ${b.giren}',
                                ].join(' · ')),
                              ),
                          ],
                        ),
                ),
              ],
            ),
            ariza.isEmpty
                ? const _Bilgi('Arıza kaydı yok.')
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [for (final x in ariza) _ArizaSatiri(x)],
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _olaySorgula(BuildContext context) async {
    final gun = await showDatePicker(
      context: context,
      firstDate: DateTime(2026),
      lastDate: DateTime.now(),
      initialDate: DateTime.now(),
      helpText: 'Olay tarihi',
    );
    if (gun == null || !context.mounted) return;
    final saat = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Olay saati',
    );
    if (saat == null || !context.mounted) return;
    final an = DateTime(gun.year, gun.month, gun.day, saat.hour, saat.minute);
    final s = a.olaySorgula(arac.no, an);
    String yaz(AracKullanim? x) => x == null
        ? 'Kayıt yok'
        : '${x.personel}\n${x.baslangic}${x.bitis.isEmpty ? ' (devam ediyor)' : ' → ${x.bitis}'}'
            '${x.eksikKontroller.isEmpty ? '' : '\nBakım Uygunsuzluğu: ${x.eksikKontroller.join(', ')}'}';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Olay Sorgulama · ${arac.no}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${gun.day.toString().padLeft(2, '0')}.${gun.month.toString().padLeft(2, '0')}.${gun.year} '
                  '${saat.hour.toString().padLeft(2, '0')}:${saat.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Renk.soluk)),
              const SizedBox(height: 12),
              const Text('O anda kullanan', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(yaz(s.sirada)),
              const SizedBox(height: 10),
              const Text('Önceki kullanıcı', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(yaz(s.once)),
              const SizedBox(height: 10),
              const Text('Sonraki kullanıcı', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(yaz(s.sonra)),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat'))],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Personel Kullanım Geçmişi. Kişi bazlı toplam çalışma saati gösterilmez
/// (puantaj verisi değildir); yalnız araç sorumluluğu ve kayıt düzeni.
class _PersonelListesi extends StatelessWidget {
  const _PersonelListesi({required this.a});
  final AracVerisi a;

  @override
  Widget build(BuildContext context) {
    final l = a.personeller;
    if (l.isEmpty) return const _Bilgi('Kayıt yok.');
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: l.length,
      itemBuilder: (_, i) {
        final ad = l[i];
        final g = a.personelGecmisi(ad);
        final uygunsuz = g.where((x) => x.eksikKontroller.isNotEmpty).length;
        final formen = g.where((x) => x.sekil == 'Formen girişi').length;
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Renk.cizgi)),
          child: ListTile(
            title: Text(ad, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text([
              '${g.length} kayıt',
              '${{for (final x in g) x.arac}.length} araç',
              if (uygunsuz > 0) '$uygunsuz bakım uygunsuzluğu',
              if (formen > 0) '$formen kayıt eksikliği (formen girişi)',
            ].join(' · ')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: Text(ad)),
                  body: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [for (final x in g) _KullanimSatiri(x, personelGoster: false)],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _Mutabakat extends StatefulWidget {
  const _Mutabakat({required this.a});
  final AracVerisi a;

  @override
  State<_Mutabakat> createState() => _MutabakatState();
}

class _MutabakatState extends State<_Mutabakat> {
  static const _sonuclar = ['Kritik Bulgu', 'Mutabakat Farkı', 'Belge Eksikliği', 'Mutabık'];
  String? _filtre;

  @override
  Widget build(BuildContext context) {
    final tum = widget.a.mutabakat.reversed.toList();
    final l = _filtre == null ? tum : tum.where((x) => x.sonuc == _filtre).toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text(
          'Bakım, onarım ve araç kullanım kayıtları; satınalma talepleri, faturalar, ödemeler, '
          'tarım faaliyetleri ve mesajlarla her gün karşılaştırılır.',
          style: TextStyle(color: Renk.soluk),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: Text('Tümü (${tum.length})'),
              selected: _filtre == null,
              onSelected: (_) => setState(() => _filtre = null),
            ),
            for (final s in _sonuclar)
              ChoiceChip(
                label: Text('$s (${tum.where((x) => x.sonuc == s).length})'),
                selected: _filtre == s,
                onSelected: (_) => setState(() => _filtre = _filtre == s ? null : s),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (l.isEmpty)
          const _Bilgi('Mutabakat kaydı yok.')
        else
          for (final x in l)
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Etiket(x.sonuc),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text([x.arac, x.konu].where((s) => s.isNotEmpty).join(' · '),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(x.aciklama),
                  const SizedBox(height: 4),
                  Text(
                    [x.tarih, if (x.personel.isNotEmpty) x.personel, if (x.kaynaklar.isNotEmpty) x.kaynaklar]
                        .join(' · '),
                    style: const TextStyle(color: Renk.soluk, fontSize: 12),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// Bir personelin araç kullanım geçmişi (Kişiler ekranından açılır).
/// Kişi bazlı toplam çalışma saati gösterilmez.
class AracPersonelGecmisiEkran extends StatelessWidget {
  const AracPersonelGecmisiEkran({super.key, required this.veri, required this.ad});
  final RaporVerisi veri;
  final String ad;

  @override
  Widget build(BuildContext context) {
    final g = veri.arac.personelGecmisi(ad);
    final uygunsuz = g.where((x) => x.eksikKontroller.isNotEmpty).length;
    return Scaffold(
      appBar: AppBar(title: Text('Araç Kullanımı · $ad')),
      body: g.isEmpty
          ? const _Bilgi('Bu personele ait araç kullanım kaydı yok.')
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text(
                  [
                    '${g.length} kayıt',
                    '${{for (final x in g) x.arac}.length} araç',
                    if (uygunsuz > 0) '$uygunsuz bakım uygunsuzluğu',
                  ].join(' · '),
                  style: const TextStyle(color: Renk.soluk),
                ),
                const SizedBox(height: 6),
                for (final x in g) _KullanimSatiri(x, personelGoster: false),
              ],
            ),
    );
  }
}

/// Formenlerin personele verdiği iş emirleri: kim, nerede, hangi işi, hangi araç ve makine-ekipmanla.
class _IsEmirleri extends StatefulWidget {
  const _IsEmirleri({required this.a});
  final AracVerisi a;

  @override
  State<_IsEmirleri> createState() => _IsEmirleriState();
}

class _IsEmirleriState extends State<_IsEmirleri> {
  int _gun = 0; // 0 bugün, -1 dün, 1 yarın, 99 tümü

  @override
  Widget build(BuildContext context) {
    final bugun = DateTime.now();
    final hedef = DateTime(bugun.year, bugun.month, bugun.day).add(Duration(days: _gun == 99 ? 0 : _gun));
    final l = widget.a.isEmri.where((e) {
      if (_gun == 99) return true;
      final g = e.gun;
      return g != null && g.year == hedef.year && g.month == hedef.month && g.day == hedef.day;
    }).toList()
      ..sort((x, y) {
        final f = x.formen.compareTo(y.formen);
        return f != 0 ? f : x.personel.compareTo(y.personel);
      });
    final sayim = <String, int>{};
    for (final e in l) {
      sayim[e.durum] = (sayim[e.durum] ?? 0) + 1;
    }
    final formenler = <String, List<AracIsEmri>>{};
    for (final e in l) {
      (formenler[e.formen.isEmpty ? 'Formen belirtilmemiş' : e.formen] ??= []).add(e);
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Wrap(
          spacing: 6,
          children: [
            for (final (d, ad) in const [(-1, 'Dün'), (0, 'Bugün'), (1, 'Yarın'), (99, 'Tümü')])
              ChoiceChip(label: Text(ad), selected: _gun == d, onSelected: (_) => setState(() => _gun = d)),
          ],
        ),
        const SizedBox(height: 8),
        if (l.isEmpty)
          const _Bilgi('Bu gün için iş emri yok.')
        else ...[
          Text(
            ['${l.length} iş emri', for (final e in sayim.entries) '${e.value} ${e.key.toLowerCase()}'].join(' · '),
            style: const TextStyle(color: Renk.soluk),
          ),
          const SizedBox(height: 8),
          for (final f in formenler.entries)
            Panel(
              baslik: '${f.key} (${f.value.length})',
              child: Column(
                children: [
                  for (final e in f.value)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${e.personel} · ${e.is_}'),
                      subtitle: Text([
                        if (_gun == 99) e.tarih,
                        [e.yerTuru, e.yer].where((x) => x.isNotEmpty).join(': '),
                        e.aracMetni.isEmpty ? 'Araçsız iş' : e.aracMetni,
                        if (e.aciklama.isNotEmpty) e.aciklama,
                      ].where((x) => x.isNotEmpty).join(' · ')),
                      trailing: _Etiket(e.durum),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
