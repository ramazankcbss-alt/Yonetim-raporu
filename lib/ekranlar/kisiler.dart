import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/model.dart';
import 'bilesenler.dart';

/// Bir kişinin takip ettiği / sorumlu olduğu açık işler.
class KisiIsleri {
  KisiIsleri(this.kisi, RaporVerisi veri)
      : isler = [
          for (final i in veri.isler)
            if (!i.tamam && kisi.isEslesir(i)) i
        ]..sort((a, b) => _tarihSirala(a.sonDegisiklik ?? a.acilis,
            b.sonDegisiklik ?? b.acilis)),
        akis = [
          for (final k in veri.akis)
            if (!k.tamam && kisi.akisEslesir(k)) k
        ]..sort((a, b) => _tarihSirala(
            a.sonGuncelleme ?? a.acilis, b.sonGuncelleme ?? b.acilis));

  final Kisi kisi;
  final List<Is> isler;
  final List<AkisKaydi> akis;

  int get toplam => isler.length + akis.length;

  /// Bekleyen, gecikmiş ya da cevapsız talimat içeren kalemler.
  int eksik(DateTime bugun) =>
      isler.where((i) => i.bekliyor || i.gecikmis(bugun)).length +
      akis.where((k) => talimatBekliyor(k.sonrakiAdim)).length;

  static int _tarihSirala(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return b.compareTo(a); // en yeni üstte
  }
}

bool talimatBekliyor(String s) => trKucuk(s).contains('yanıt bekleniyor');

/// Asistan → Kişiler: kim hangi işi takip ediyor, eksikleri neler.
class KisilerEkran extends StatelessWidget {
  const KisilerEkran({super.key, required this.veri});

  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) {
    final bugun = DateTime.now();
    final liste = [for (final k in veri.kisiler) KisiIsleri(k, veri)]
      ..sort((a, b) => b.eksik(bugun).compareTo(a.eksik(bugun)));
    return Scaffold(
      appBar: AppBar(title: const Text('Kişiler')),
      body: liste.isEmpty
          ? const BosDurum(
              ikon: Icons.people_outline,
              yazi: "Kişi listesi boş. Rapor tablosundaki 'Kişiler' "
                  'sayfasına ad, telefon ve e-posta ekleyin.')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 2, bottom: 10),
                  child: Text(
                    'Kişiye dokun: takip ettiği işleri ve eksikleri gör, '
                    'WhatsApp ya da e-posta ile hatırlat. Mesaj gönderilmeden '
                    'önce her zaman onay sorulur.',
                    style: TextStyle(
                        fontSize: 13.5, color: Renk.soluk, height: 1.4),
                  ),
                ),
                for (final k in liste) _KisiKarti(ki: k, bugun: bugun),
              ],
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
            ki.toplam == 0
                ? 'Açık iş yok'
                : '${ki.toplam} açık iş${eksik > 0 ? ' · $eksik eksik/bekleyen' : ''}',
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

/// Kişinin açık işleri; seçilenler için hazır mesaj, WhatsApp / e-posta.
class KisiDetayEkran extends StatefulWidget {
  const KisiDetayEkran({super.key, required this.kisiAdi});

  final String kisiAdi;

  @override
  State<KisiDetayEkran> createState() => _KisiDetayEkranState();
}

class _KisiDetayEkranState extends State<KisiDetayEkran> {
  final _secili = <String>{};
  bool _ilk = true;

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
        final ki = KisiIsleri(kisi, veri);
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
        if (_ilk) {
          _ilk = false;
          _secili.addAll([for (final k in kalemler) if (k.uyari) k.anahtar]);
        }
        final secilenler = [
          for (final k in kalemler) if (_secili.contains(k.anahtar)) k
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
              const SizedBox(height: 8),
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
                yazi: 'Mesaj hazırla ve gönder',
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
