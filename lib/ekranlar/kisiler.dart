import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/model.dart';
import '../veri/ozel.dart';
import 'bilesenler.dart';

/// Bir kişinin takip ettiği / sorumlu olduğu açık işler ve olayları.
class KisiIsleri {
  KisiIsleri(this.kisi, RaporVerisi veri, {List<KisiOlayi> olaylar = const []})
      : isler = [
          for (final i in veri.isler)
            if (!i.tamam && kisi.isEslesir(i)) i
        ]..sort((a, b) => _tarihSirala(a.sonDegisiklik ?? a.acilis,
            b.sonDegisiklik ?? b.acilis)),
        akis = [
          for (final k in veri.akis)
            if (!k.tamam && kisi.akisEslesir(k)) k
        ]..sort((a, b) => _tarihSirala(
            a.sonGuncelleme ?? a.acilis, b.sonGuncelleme ?? b.acilis)),
        olaylar = [
          for (final o in olaylar)
            if (kisi.eslesir([o.kisi])) o
        ]..sort((a, b) => _tarihSirala(a.tarih, b.tarih));

  final Kisi kisi;
  final List<Is> isler;
  final List<AkisKaydi> akis;
  final List<KisiOlayi> olaylar;

  int get toplam => isler.length + akis.length;

  /// Hiç açık işi ve olayı yok.
  bool get kayitsiz => toplam == 0 && olaylar.isEmpty;
  int get olumsuz => olaylar.where((o) => !o.olumlu).length;
  int get olumlu => olaylar.where((o) => o.olumlu).length;

  /// Bekleyen, gecikmiş, cevapsız talimat içeren kalemler + olumsuz olaylar.
  int eksik(DateTime bugun) =>
      isler.where((i) => i.bekliyor || i.gecikmis(bugun)).length +
      akis.where((k) => talimatBekliyor(k.sonrakiAdim)).length +
      olumsuz;

  static int _tarihSirala(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return b.compareTo(a); // en yeni üstte
  }
}

bool talimatBekliyor(String s) => trKucuk(s).contains('yanıt bekleniyor');

/// Özel veriyi (kişi olayları) bir kez çeker; hata olursa boş geçer.
Future<void> _ozelYukle() async {
  final d = VeriDeposu.ben;
  if (d.ozelBellek != null) return;
  try {
    await d.ozelGetir();
  } catch (_) {
    // Olaylar gelmezse işler yine gösterilir.
  }
}

/// Asistan → Kişiler: kim hangi işi takip ediyor, eksikleri neler.
class KisilerEkran extends StatefulWidget {
  const KisilerEkran({super.key, required this.veri});

  final RaporVerisi veri;

  @override
  State<KisilerEkran> createState() => _KisilerEkranState();
}

class _KisilerEkranState extends State<KisilerEkran> {
  @override
  void initState() {
    super.initState();
    _ozelYukle().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VeriDeposu.ben,
      builder: (context, _) {
        final veri = VeriDeposu.ben.veri ?? widget.veri;
        final olaylar = VeriDeposu.ben.ozelBellek?.kisiOlaylari ?? const [];
        final bugun = DateTime.now();
        // Görev makamına göre (yönetim üstte), sonra eksik sayısına göre.
        final tumu = [
          for (final k in veri.kisiler) KisiIsleri(k, veri, olaylar: olaylar)
        ]..sort((a, b) {
            final m = a.kisi.makam.compareTo(b.kisi.makam);
            if (m != 0) return m;
            final e = b.eksik(bugun).compareTo(a.eksik(bugun));
            return e != 0 ? e : a.kisi.ad.compareTo(b.kisi.ad);
          });
        // Hiç kaydı olmayanlar takipte kalır ama kalabalık yapmasın diye
        // altta kapalı bir grupta durur.
        final liste = [for (final k in tumu) if (!k.kayitsiz) k];
        final kayitsizlar = [for (final k in tumu) if (k.kayitsiz) k];
        return Scaffold(
          appBar: AppBar(title: const Text('Kişiler')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => kisiEkle(context, veri),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Kişi ekle'),
          ),
          body: liste.isEmpty
              ? const BosDurum(
                  ikon: Icons.people_outline,
                  yazi: 'Kişi listesi boş. Sağ alttaki "Kişi ekle" ile '
                      'personel listesinden seçin.')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 2, bottom: 10),
                      child: Text(
                        'Kişiye dokun: takip ettiği işleri, olumsuz/olumlu '
                        'olayları gör, WhatsApp ya da e-posta ile hatırlat. '
                        'Mesaj gönderilmeden önce her zaman onay sorulur.',
                        style: TextStyle(
                            fontSize: 13.5, color: Renk.soluk, height: 1.4),
                      ),
                    ),
                    for (final k in liste) _KisiKarti(ki: k, bugun: bugun),
                    if (kayitsizlar.isNotEmpty)
                      Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                          leading: const Icon(Icons.visibility_off_outlined,
                              color: Renk.soluk),
                          title: Text(
                              'Kaydı olmayan ${kayitsizlar.length} kişi',
                              style: const TextStyle(
                                  fontSize: 14, color: Renk.soluk)),
                          subtitle: const Text(
                              'Takipte; iş ya da olay çıkınca yukarı taşınır',
                              style:
                                  TextStyle(fontSize: 12, color: Renk.soluk)),
                          children: [
                            for (final k in kayitsizlar)
                              _KisiKarti(ki: k, bugun: bugun),
                          ],
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

/// Kişi ekleme: personel listesinden seç ya da elle yaz.
Future<void> kisiEkle(BuildContext context, RaporVerisi veri) async {
  final secilen = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    builder: (c) => _PersonelSecici(veri: veri),
  );
  if (!context.mounted || secilen == null) return;
  String ad = '', birim = '', telefon = '', eposta = '';
  if (secilen is PersonelKisi) {
    ad = secilen.ad;
    birim = [secilen.gorev, secilen.birim].where((e) => e.isNotEmpty).join(' – ');
    telefon = secilen.telefon;
  } else {
    final sonuc = await _elleKisiFormu(context);
    if (sonuc == null) return;
    ad = sonuc[0];
    birim = sonuc[1];
    telefon = sonuc[2];
    eposta = sonuc[3];
  }
  if (ad.trim().isEmpty) return;
  try {
    await VeriDeposu.ben
        .kisiKaydet(ad.trim(), telefon: telefon, eposta: eposta, birim: birim);
    if (context.mounted) bildir(context, '$ad Kişiler\'e eklendi.');
  } on VeriHatasi catch (e) {
    if (context.mounted) bildir(context, e.mesaj);
  } catch (_) {
    if (context.mounted) bildir(context, 'Eklenemedi.');
  }
}

Future<List<String>?> _elleKisiFormu(BuildContext context) async {
  final ad = TextEditingController();
  final birim = TextEditingController();
  final tel = TextEditingController();
  final ep = TextEditingController();
  final tamam = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Yeni kişi'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: ad,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Ad Soyad')),
            TextField(
                controller: birim,
                decoration:
                    const InputDecoration(labelText: 'Görev / Birim')),
            TextField(
                controller: tel,
                keyboardType: TextInputType.phone,
                decoration:
                    const InputDecoration(labelText: 'Telefon (WhatsApp)')),
            TextField(
                controller: ep,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-posta')),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç')),
        FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Ekle')),
      ],
    ),
  );
  if (tamam != true) return null;
  return [ad.text, birim.text, tel.text, ep.text];
}

/// Personel listesinden seçim; listede olmayan için "elle ekle".
class _PersonelSecici extends StatefulWidget {
  const _PersonelSecici({required this.veri});

  final RaporVerisi veri;

  @override
  State<_PersonelSecici> createState() => _PersonelSeciciState();
}

class _PersonelSeciciState extends State<_PersonelSecici> {
  String _ara = '';

  @override
  Widget build(BuildContext context) {
    final mevcut = {for (final k in widget.veri.kisiler) trKucuk(k.ad)};
    final q = trKucuk(_ara);
    final liste = [
      for (final p in widget.veri.personelListesi)
        if (q.isEmpty || p.aranabilir.contains(q)) p
    ];
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _ara = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Personel ara (ad, görev, birim)',
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Listede yok — elle ekle'),
              onTap: () => Navigator.pop(context, 'elle'),
            ),
            const Divider(height: 1),
            Expanded(
              child: liste.isEmpty
                  ? const Center(
                      child: Text('Personel listesi boş ya da eşleşen yok.',
                          style: TextStyle(color: Renk.soluk)))
                  : ListView.builder(
                      itemCount: liste.length,
                      itemBuilder: (c, i) {
                        final p = liste[i];
                        final var_ = mevcut.contains(trKucuk(p.ad));
                        return ListTile(
                          title: Text(p.ad),
                          subtitle: Text(
                              [p.gorev, p.birim]
                                  .where((e) => e.isNotEmpty)
                                  .join(' · '),
                              style: const TextStyle(fontSize: 12.5)),
                          trailing: var_
                              ? const Icon(Icons.check_circle,
                                  color: Renk.yesil)
                              : const Icon(Icons.add_circle_outline),
                          enabled: !var_,
                          onTap: () => Navigator.pop(context, p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KisiKarti extends StatelessWidget {
  const _KisiKarti({required this.ki, required this.bugun});

  final KisiIsleri ki;
  final DateTime bugun;

  @override
  Widget build(BuildContext context) {
    final k = ki.kisi;
    final eksik = ki.eksik(bugun);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Renk.kart,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Renk.cizgi),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: Renk.ana.withValues(alpha: 0.12),
          child: Text(_basHarfler(k.ad),
              style: const TextStyle(
                  color: Renk.ana, fontWeight: FontWeight.w700)),
        ),
        title: Text(k.ad,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          [
            if (k.birim.isNotEmpty) k.birim,
            ki.toplam == 0 ? 'Açık iş yok' : '${ki.toplam} açık iş',
            if (ki.olumsuz > 0) '${ki.olumsuz} olumsuz',
            if (ki.olumlu > 0) '${ki.olumlu} olumlu',
          ].join(' · '),
        ),
        trailing: eksik > 0
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Renk.amberAcik,
                    borderRadius: BorderRadius.circular(8)),
                child: Text('$eksik',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: Renk.amber)),
              )
            : const Icon(Icons.chevron_right, color: Renk.soluk),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => KisiDetayEkran(kisiAdi: k.ad))),
      ),
    );
  }
}

String _basHarfler(String ad) {
  final p = ad.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
  return p.take(2).map((e) => e.characters.first.toUpperCase()).join();
}

/// Kişinin açık işleri ve olayları; seçilenler için hazır mesaj.
class KisiDetayEkran extends StatefulWidget {
  const KisiDetayEkran({super.key, required this.kisiAdi});

  final String kisiAdi;

  @override
  State<KisiDetayEkran> createState() => _KisiDetayEkranState();
}

class _KisiDetayEkranState extends State<KisiDetayEkran> {
  final _secili = <String>{};
  final _ilkSecilenler = <String>{};
  bool _olumsuzGoster = true;
  final _isleniyor = <String>{};

  @override
  void initState() {
    super.initState();
    _ozelYukle().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _durumDegistir(KisiOlayi o, bool olumlu) async {
    if (o.kimlik.isEmpty) {
      bildir(context, 'Bu olayın kimliği yok; tablodan değiştirin.');
      return;
    }
    setState(() => _isleniyor.add(o.kimlik));
    try {
      await VeriDeposu.ben.olayDurumu(o.kimlik, olumlu: olumlu);
      if (mounted) {
        bildir(context,
            olumlu ? 'Düzeltildi olarak işaretlendi (olumlu).' : 'Olumsuza alındı.');
      }
    } on VeriHatasi catch (e) {
      if (mounted) bildir(context, e.mesaj);
    } catch (_) {
      if (mounted) bildir(context, 'Değiştirilemedi.');
    } finally {
      if (mounted) setState(() => _isleniyor.remove(o.kimlik));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VeriDeposu.ben,
      builder: (context, _) {
        final veri = VeriDeposu.ben.veri;
        Kisi? kisi;
        for (final k in veri?.kisiler ?? const <Kisi>[]) {
          if (k.ad == widget.kisiAdi) kisi = k;
        }
        if (veri == null || kisi == null) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.kisiAdi)),
            body: const BosDurum(
                ikon: Icons.person_off_outlined, yazi: 'Kişi bulunamadı.'),
          );
        }
        final ki = KisiIsleri(kisi, veri,
            olaylar: VeriDeposu.ben.ozelBellek?.kisiOlaylari ?? const []);
        final bugun = DateTime.now();
        final kalemler = <_Kalem>[
          for (final i in ki.isler)
            _Kalem(
              anahtar: 'is-${i.no}',
              baslik: i.konu,
              alt: [
                i.durum,
                if (i.ciftlik.isNotEmpty) i.ciftlik,
                if (i.sonDegisiklik != null) gunAy(i.sonDegisiklik!),
              ].join(' · '),
              aciklama: i.sonDurum,
              uyari: i.bekliyor || i.gecikmis(bugun) || talimatBekliyor(i.sonDurum),
              mesajSatiri: '${i.konu}'
                  '${i.sonDurum.isNotEmpty ? ' (son durum: ${i.sonDurum})' : ''}',
            ),
          for (final k in ki.akis)
            _Kalem(
              anahtar: 'akis-${k.no}',
              baslik: k.baslik,
              alt: [
                k.bolum,
                if (k.sonGuncelleme != null) gunAy(k.sonGuncelleme!),
              ].join(' · '),
              aciklama: [
                if (k.durum.isNotEmpty) k.durum,
                if (k.sonrakiAdim.isNotEmpty) 'Sonraki adım: ${k.sonrakiAdim}',
              ].join('\n'),
              uyari: talimatBekliyor(k.sonrakiAdim) ||
                  trKucuk(k.sonrakiAdim).contains('gecikmiş'),
              mesajSatiri: '${k.baslik}'
                  '${k.sonrakiAdim.isNotEmpty ? ' – ${k.sonrakiAdim}' : ''}',
            ),
        ];
        final olaylarGorunen = [
          for (final o in ki.olaylar)
            if (o.olumlu != _olumsuzGoster) o
        ];
        // Eksik/bekleyen işler ve olumsuz olaylar ilk açılışta seçili gelir.
        for (final k in kalemler) {
          if (k.uyari && _ilkSecilenler.add(k.anahtar)) _secili.add(k.anahtar);
        }
        for (final o in ki.olaylar) {
          final a = 'olay-${o.kimlik}-${o.konu}';
          if (!o.olumlu && _ilkSecilenler.add(a)) _secili.add(a);
        }
        final secilenler = <_Kalem>[
          for (final k in kalemler)
            if (_secili.contains(k.anahtar)) k,
          for (final o in ki.olaylar)
            if (!o.olumlu && _secili.contains('olay-${o.kimlik}-${o.konu}'))
              _Kalem(
                anahtar: 'olay-${o.kimlik}-${o.konu}',
                baslik: o.konu,
                alt: '',
                aciklama: '',
                uyari: true,
                mesajSatiri: '${o.konu}'
                    '${o.aciklama.isNotEmpty ? ' – ${o.aciklama}' : ''}',
              ),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(kisi.ad),
            actions: [
              IconButton(
                tooltip: 'Telefon / e-posta',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _iletisimDuzenle(context, kisi!),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _IletisimSatiri(kisi: kisi),
              const SizedBox(height: 14),
              // --- Olaylar: olumsuz / olumlu ---
              Row(
                children: [
                  const Expanded(
                    child: Text('Olaylar',
                        style: TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w700)),
                  ),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                          value: true,
                          icon: const Icon(Icons.thumb_down_alt_outlined,
                              size: 16),
                          label: Text('Olumsuz ${ki.olumsuz}')),
                      ButtonSegment(
                          value: false,
                          icon: const Icon(Icons.thumb_up_alt_outlined,
                              size: 16),
                          label: Text('Olumlu ${ki.olumlu}')),
                    ],
                    selected: {_olumsuzGoster},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        setState(() => _olumsuzGoster = s.first),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (VeriDeposu.ben.ozelBellek == null)
                const BilgiKutusu(yazi: 'Olaylar yükleniyor…')
              else if (olaylarGorunen.isEmpty)
                BilgiKutusu(
                    yazi: _olumsuzGoster
                        ? 'Açık olumsuz olay yok.'
                        : 'Henüz olumluya çevrilmiş olay yok.')
              else
                for (final o in olaylarGorunen)
                  _OlayKarti(
                    olay: o,
                    secili: _secili.contains('olay-${o.kimlik}-${o.konu}'),
                    secimDegisti: o.olumlu
                        ? null
                        : (v) => setState(() => v
                            ? _secili.add('olay-${o.kimlik}-${o.konu}')
                            : _secili.remove('olay-${o.kimlik}-${o.konu}')),
                    isleniyor: _isleniyor.contains(o.kimlik),
                    degistir: () => _durumDegistir(o, !o.olumlu),
                  ),
              const SizedBox(height: 14),
              // --- Açık işler ---
              const Text('Açık işler',
                  style:
                      TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              if (kalemler.isEmpty)
                const BilgiKutusu(
                    yazi: 'Bu kişiyle eşleşen açık iş yok. Eşleşme, Kontrol '
                        "Paneli'ndeki sorumlu sütunu ve İş Akışı'ndaki ilgili "
                        "kişi alanından yapılır ('Kişiler' sayfası, E sütunu).")
              else ...[
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 6),
                  child: Text(
                    '${kalemler.length} açık iş · mesaja eklenecekleri seç '
                    '(eksik/bekleyenler seçili gelir)',
                    style: const TextStyle(fontSize: 12.5, color: Renk.soluk),
                  ),
                ),
                for (final k in kalemler)
                  _KalemKarti(
                    kalem: k,
                    secili: _secili.contains(k.anahtar),
                    degisti: (v) => setState(() => v
                        ? _secili.add(k.anahtar)
                        : _secili.remove(k.anahtar)),
                  ),
              ],
              const SizedBox(height: 14),
              Buton(
                yazi: 'Mesaj hazırla ve gönder (${secilenler.length})',
                ikon: Icons.send_outlined,
                onTap: () => _mesajYaz(context, kisi!, secilenler),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _iletisimDuzenle(BuildContext context, Kisi kisi) async {
    final tel = TextEditingController(text: kisi.telefon);
    final ep = TextEditingController(text: kisi.eposta);
    final kaydet = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(kisi.ad),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tel,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Telefon (WhatsApp)', hintText: '05xx xxx xx xx'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ep,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-posta'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Kaydet')),
        ],
      ),
    );
    if (kaydet != true) return;
    try {
      await VeriDeposu.ben
          .kisiKaydet(kisi.ad, telefon: tel.text, eposta: ep.text);
      if (context.mounted) bildir(context, 'Kaydedildi.');
    } on VeriHatasi catch (e) {
      if (context.mounted) bildir(context, e.mesaj);
    } catch (_) {
      if (context.mounted) bildir(context, 'Kaydedilemedi.');
    }
  }

  Future<void> _mesajYaz(
      BuildContext context, Kisi kisi, List<_Kalem> secilenler) async {
    final sonuc = await Navigator.of(context).push<String>(MaterialPageRoute(
        builder: (_) => MesajEkran(kisi: kisi, kalemler: secilenler)));
    if (sonuc != null && context.mounted) bildir(context, sonuc);
  }
}

/// Olay kartı: tür, konu, açıklama; olumsuzsa "Düzeltildi" ile olumluya,
/// olumluysa "Olumsuza al" ile geri çevrilir.
class _OlayKarti extends StatelessWidget {
  const _OlayKarti({
    required this.olay,
    required this.secili,
    required this.secimDegisti,
    required this.isleniyor,
    required this.degistir,
  });

  final KisiOlayi olay;
  final bool secili;
  final ValueChanged<bool>? secimDegisti;
  final bool isleniyor;
  final VoidCallback degistir;

  @override
  Widget build(BuildContext context) {
    final o = olay;
    final renk = o.olumlu ? Renk.yesil : Renk.kirmizi;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Renk.kart,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: o.olumlu ? const Color(0xFFBBF7D0) : const Color(0xFFFCA5A5)),
      ),
      padding: const EdgeInsets.fromLTRB(4, 6, 10, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (secimDegisti != null)
            Checkbox(value: secili, onChanged: (v) => secimDegisti!(v ?? false))
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(Icons.check_circle, color: renk, size: 22),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(o.konu.isEmpty ? o.tur : o.konu,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(
                  [
                    if (o.tur.isNotEmpty) o.tur,
                    if (o.tarih != null) gunAy(o.tarih!),
                    if (o.kaynak.isNotEmpty) o.kaynak,
                    if (o.olumlu && o.duzeltilme != null)
                      'düzeltildi ${gunAy(o.duzeltilme!)}',
                  ].join(' · '),
                  style: TextStyle(
                      fontSize: 12.5, color: renk, fontWeight: FontWeight.w600),
                ),
                if (o.aciklama.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(o.aciklama,
                        style:
                            const TextStyle(fontSize: 13, color: Renk.yazi)),
                  ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: isleniyor
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : TextButton.icon(
                          onPressed: degistir,
                          icon: Icon(
                              o.olumlu ? Icons.undo : Icons.check,
                              size: 18),
                          label: Text(o.olumlu
                              ? 'Olumsuza al'
                              : 'Düzeltildi → olumlu'),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Kalem {
  const _Kalem({
    required this.anahtar,
    required this.baslik,
    required this.alt,
    required this.aciklama,
    required this.uyari,
    required this.mesajSatiri,
  });

  final String anahtar, baslik, alt, aciklama, mesajSatiri;
  final bool uyari;
}

class _KalemKarti extends StatelessWidget {
  const _KalemKarti(
      {required this.kalem, required this.secili, required this.degisti});

  final _Kalem kalem;
  final bool secili;
  final ValueChanged<bool> degisti;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Renk.kart,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: kalem.uyari ? const Color(0xFFFCD34D) : Renk.cizgi),
      ),
      child: CheckboxListTile(
        value: secili,
        onChanged: (v) => degisti(v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(kalem.baslik,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kalem.alt,
                style: TextStyle(
                    fontSize: 12.5,
                    color: kalem.uyari ? Renk.amber : Renk.soluk,
                    fontWeight:
                        kalem.uyari ? FontWeight.w600 : FontWeight.w400)),
            if (kalem.aciklama.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(kalem.aciklama,
                    style: const TextStyle(fontSize: 13, color: Renk.yazi)),
              ),
          ],
        ),
      ),
    );
  }
}

class _IletisimSatiri extends StatelessWidget {
  const _IletisimSatiri({required this.kisi});

  final Kisi kisi;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (kisi.birim.isNotEmpty)
            Text(kisi.birim,
                style: const TextStyle(fontSize: 13, color: Renk.soluk)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.phone_outlined, size: 18, color: Renk.soluk),
            const SizedBox(width: 6),
            Text(kisi.telefon.isEmpty ? 'Telefon yok' : kisi.telefon),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.mail_outline, size: 18, color: Renk.soluk),
            const SizedBox(width: 6),
            Flexible(
                child: Text(kisi.eposta.isEmpty ? 'E-posta yok' : kisi.eposta)),
          ]),
        ],
      ),
    );
  }
}

/// Mesaj metni ve gönderim. Her gönderimden önce onay sorulur.
class MesajEkran extends StatefulWidget {
  const MesajEkran({super.key, required this.kisi, required this.kalemler});

  final Kisi kisi;
  final List<Object> kalemler;

  @override
  State<MesajEkran> createState() => _MesajEkranState();
}

class _MesajEkranState extends State<MesajEkran> {
  late final TextEditingController _konu;
  late final TextEditingController _metin;
  bool _gonderiliyor = false;

  @override
  void initState() {
    super.initState();
    final ilkAd = widget.kisi.ad.split(' ').first;
    final satirlar = [
      for (final k in widget.kalemler)
        if (k is _Kalem) '• ${k.mesajSatiri}'
    ];
    _konu = TextEditingController(text: 'Takip edilen işler – ${tarihKisa(DateTime.now())}');
    _metin = TextEditingController(
      text: satirlar.isEmpty
          ? 'Merhaba $ilkAd Bey/Hanım,\n\n\n\nRamazan Kocabaş'
          : 'Merhaba $ilkAd Bey/Hanım,\n\nAşağıdaki konularda son durumu ve '
              'eksikleri iletebilir misiniz?\n\n${satirlar.join('\n')}\n\n'
              'Teşekkürler,\nRamazan Kocabaş',
    );
  }

  @override
  void dispose() {
    _konu.dispose();
    _metin.dispose();
    super.dispose();
  }

  Future<bool> _onay(String kanal, String hedef) async {
    final c = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Gönderilsin mi?'),
        content: SingleChildScrollView(
          child: Text(
            '${widget.kisi.ad} kişisine $kanal ile gönderilecek'
            '${hedef.isEmpty ? '' : ' ($hedef)'}:\n\n${_metin.text.trim()}',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Hayır')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Evet, gönder')),
        ],
      ),
    );
    return c == true;
  }

  Future<void> _whatsapp() async {
    final metin = _metin.text.trim();
    if (metin.isEmpty) {
      bildir(context, 'Mesaj boş.');
      return;
    }
    final no = widget.kisi.whatsappNumarasi;
    if (!await _onay('WhatsApp', no == null ? 'kişiyi WhatsApp\'ta seçeceksiniz' : widget.kisi.telefon)) {
      return;
    }
    final adres = Uri.parse(
        'https://wa.me/${no ?? ''}?text=${Uri.encodeComponent(metin)}');
    final acildi =
        await launchUrl(adres, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!acildi) {
      bildir(context, 'WhatsApp açılamadı.');
    } else {
      Navigator.pop(context, 'WhatsApp açıldı; mesaj hazır, gönder\'e basın.');
    }
  }

  Future<void> _eposta() async {
    final metin = _metin.text.trim();
    final konu = _konu.text.trim();
    if (metin.isEmpty || konu.isEmpty) {
      bildir(context, 'Konu ve mesaj boş olamaz.');
      return;
    }
    if (!widget.kisi.epostaVar) {
      bildir(context,
          'Bu kişinin e-posta adresi yok. Sağ üstteki kalemden ekleyin.');
      return;
    }
    if (!await _onay('e-posta', widget.kisi.eposta)) return;
    setState(() => _gonderiliyor = true);
    try {
      await VeriDeposu.ben.epostaGonder(widget.kisi.ad, konu, metin);
      if (mounted) Navigator.pop(context, 'E-posta gönderildi.');
    } on VeriHatasi catch (e) {
      if (mounted) bildir(context, e.mesaj);
    } catch (_) {
      if (mounted) bildir(context, 'E-posta gönderilemedi.');
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kisi;
    return Scaffold(
      appBar: AppBar(title: Text('Mesaj: ${k.ad}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _konu,
            decoration: const InputDecoration(labelText: 'Konu (e-posta için)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _metin,
            minLines: 8,
            maxLines: 20,
            decoration: const InputDecoration(
                labelText: 'Mesaj', alignLabelWithHint: true),
          ),
          const SizedBox(height: 16),
          Buton(
            yazi: k.telefonVar ? 'WhatsApp ile gönder' : 'WhatsApp ile gönder (kişi seç)',
            ikon: Icons.chat_outlined,
            onTap: _gonderiliyor ? null : _whatsapp,
          ),
          const SizedBox(height: 10),
          Buton(
            yazi: k.epostaVar ? 'E-posta ile gönder' : 'E-posta adresi yok',
            ikon: Icons.mail_outline,
            renk: ButonRenk.ikincil,
            mesgul: _gonderiliyor,
            onTap: k.epostaVar ? _eposta : null,
          ),
          const SizedBox(height: 12),
          const Text(
            'E-posta, sizin Google hesabınızdan (Apps Script) gönderilir ve '
            "rapor tablosundaki 'Mesaj_Kaydı' sayfasına not edilir. WhatsApp'ta "
            'mesaj hazır açılır; son gönder düğmesine siz basarsınız.',
            style: TextStyle(fontSize: 12.5, color: Renk.soluk, height: 1.4),
          ),
        ],
      ),
    );
  }
}
