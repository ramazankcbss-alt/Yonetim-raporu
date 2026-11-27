import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../bicim.dart';
import '../pdf/rapor_pdf.dart';
import '../servis/bildirim_servisi.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/esk_plan.dart';
import '../veri/ciftlik_rapor.dart';
import '../veri/duyarlilik.dart';
import '../veri/havuz.dart';
import '../veri/karne_sapma.dart';
import '../veri/model.dart';
import '../veri/urun_karlilik.dart';
import '../veri/urun_takip.dart';
import 'bilesenler.dart';
import 'bildirimler.dart';
import 'duyarlilik.dart';
import 'gonder.dart';
import 'mali.dart';
import 'net_sonuc.dart' show mtKgMaliyetleri;
import 'urun_karlilik.dart' show maliyetTakipVerisi;
import 'uretim_karlilik.dart';
import 'veri_kalitesi.dart';

String _mn(double v) => '${v < 0 ? '−' : ''}${sayi(v.abs() / 1e6, ondalik: 2)} mn ₺';
Color _renk(double v) => v >= 0 ? Renk.yesil : Renk.kirmizi;

/// Asistan › Yönetim Özeti: piramidin tepesi. Konsolide net sonuç (iki değerleme), kollar,
/// alarmlar, verimlilik karnesi, sapmalar ve veri kalitesi tek ekranda.
class YonetimOzetiEkran extends StatefulWidget {
  const YonetimOzetiEkran({super.key, required this.veri});
  final RaporVerisi veri;

  @override
  State<YonetimOzetiEkran> createState() => _YonetimOzetiEkranState();
}

class _YonetimOzetiEkranState extends State<YonetimOzetiEkran> {
  late final Future<CiftlikRaporu?> _muhasebe =
      CiftlikRaporu.yukle().then<CiftlikRaporu?>((r) => r).catchError((Object _) => null);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Yönetim Özeti'), actions: const [TabloGuncelleButonu()]),
        body: ListenableBuilder(
          listenable: Listenable.merge([VeriDeposu.ben, BildirimServisi.ben]),
          builder: (context, _) => FutureBuilder<CiftlikRaporu?>(
            future: _muhasebe,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              final v = VeriDeposu.ben.veri ?? widget.veri;
              return GonderAlani(konu: 'Yönetim Özeti', child: _Icerik(v: v, r: snap.data));
            },
          ),
        ),
      );
}

class _Icerik extends StatelessWidget {
  const _Icerik({required this.v, required this.r});
  final RaporVerisi v;
  final CiftlikRaporu? r;

  @override
  Widget build(BuildContext context) {
    final kg = mtKgMaliyetleri(v);
    final h1 = GelirGiderHavuzu.hesapla(faturalar: v.mali.gelirGider, muhasebe: r, mtKgMaliyet: kg);
    final h2 = GelirGiderHavuzu.hesapla(faturalar: v.mali.gelirGider, muhasebe: r, mtKgMaliyet: kg, senaryo: 2);
    final mt = maliyetTakipVerisi();
    final tarim = v.tarimsalUretim.bos
        ? null
        : UrunKarlilik.hesapla(
            plan: v.tarimsalUretim,
            mt: mt,
            gelir: v.mali.gelirGider,
            muhasebe: r,
            teslimat: UrunTakibi(v.tarimsalUretim, v.urunTeslimat));
    final karne = r == null || h1.sonMuhasebeAyi == 0
        ? const <KarneBolumu>[]
        : verimlilikKarnesi(
            muhasebe: r!, suru: v.suruHareketleri, yil: h1.yil, ay: h1.sonMuhasebeAyi, tarim: tarim, hasat: v.hasatDurumu, gecmis: v.gecmisOzet,
            eskAylik: v.eskAylik, eskKaynak: v.eskKaynak, eskPlan: EskPlan.coz(v.kaynakTablolari));
    final sap = r == null || h1.sonMuhasebeAyi == 0
        ? const <Sapma>[]
        : sapmalar(muhasebe: r!, suru: v.suruHareketleri, faturalar: v.mali.gelirGider, yil: h1.yil, sonAy: h1.sonMuhasebeAyi, mt: mt);
    final kalite = VeriKalitesi.hesapla(v, r);
    final alarmlar = [for (final s in sap) if (s.alarm && s.ay == h1.sonMuhasebeAyi && s.yil == h1.yil) s];
    final digerSap = [for (final s in sap) if (!s.alarm) s];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _Tepe(h1: h1, h2: h2, tarim: tarim),
        if (alarmlar.isNotEmpty)
          Panel(
            baslik: 'Alarmlar (${raporAylari[h1.sonMuhasebeAyi - 1]} ${h1.yil})',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final s in alarmlar) _SapmaKarti(s: s),
            ]),
          ),
        for (final kol in const [Kol.hayvancilik, Kol.ziraat])
          if (karne.any((k) => k.kol == kol))
            Panel(
              baslik: 'Verimlilik karnesi – ${kolAdi(kol)}',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final k in karne)
                  if (k.kol == kol) _KarneKarti(k: k),
              ]),
            ),
        Panel(
          baslik: 'Sapmalar ve nedenleri (son 3 kesin ay)',
          child: digerSap.isEmpty
              ? const Text('Normal seviyenin belirgin üstüne çıkan kalem yok.', style: TextStyle(fontSize: 13))
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final s in digerSap) _SapmaKarti(s: s)]),
        ),
        const Panel(
          baslik: 'Bütçe ve hedef',
          child: Text('Bütçe dosyası eklendiğinde gerçekleşen ile bütçe burada karşılaştırılır.',
              style: TextStyle(fontSize: 13, color: Renk.soluk)),
        ),
        Panel(
          baslik: 'Veri kalitesi',
          eylem: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => VeriKalitesiEkran(veri: v))),
            child: const Text('Ayrıntı'),
          ),
          child: Text(
            kalite.uyariSayisi == 0
                ? 'Bütün kaynaklar güncel; açık konu yok.'
                : '${kalite.eskiSayisi} kaynakta veri eski · ${kalite.eksikAylar.length} eksik dönem · ${kalite.konular.length} açık konu',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: kalite.uyariSayisi == 0 ? Renk.yesil : Renk.amber),
          ),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (r != null && h1.sonMuhasebeAyi > 0)
            FilledButton.icon(
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: Text('${raporAylari[h1.sonMuhasebeAyi - 1]} aylık raporu'),
              onPressed: () => _aylikRapor(context, h1, h2, tarim, karne, sap, kalite),
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('Duyarlılık analizi'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DuyarlilikEkran(veri: v))),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.notifications_none, size: 18),
            label: Text(BildirimServisi.ben.okunmamis > 0 ? 'Bildirimler (${BildirimServisi.ben.okunmamis})' : 'Bildirimler'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => BildirimlerEkran(veri: v))),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.account_balance_outlined, size: 18),
            label: const Text('Net Sonuç'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MaliEkran(veri: v))),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.insights_outlined, size: 18),
            label: const Text('Ürün Kârlılığı'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => UretimKarlilikEkran(veri: v))),
          ),
        ]),
        const SizedBox(height: 12),
        const Text(
          'Kesin aylar muhasebeye (Çiftlik Raporları), sonrası faturalara dayanır. Göstergelerde yalnızca çiftlik, ürün, ay, '
          'sayı ve tutar toplamları kullanılır; kişisel veri yoktur.',
          style: TextStyle(fontSize: 12, color: Renk.soluk, height: 1.4),
        ),
      ],
    );
  }
}

Future<void> _aylikRapor(BuildContext context, GelirGiderHavuzu h1, GelirGiderHavuzu h2, UrunKarlilik? tarim,
    List<KarneBolumu> karne, List<Sapma> sap, VeriKalitesi kalite) async {
  final mesaj = ScaffoldMessenger.of(context);
  final v = VeriDeposu.ben.veri;
  try {
    var kayitli = await kayitliSenaryolar();
    if (kayitli.isEmpty) kayitli = const [kOrnekSenaryo];
    final d = v == null ? const <DuyarlilikDegiskeni>[] : veridenDegiskenler(v);
    final pdf = await aylikYonetimRaporuPdf(
      a: VeriDeposu.ben.ayar,
      h1: h1,
      h2: h2,
      tarim: tarim,
      karne: karne,
      sapmalar: sap,
      senaryolar: [for (final s in kayitli) (s.ad, s.etki(d))],
      kalite: kalite,
    );
    final ad = aylikDosyaAdi(h1.yil, h1.sonMuhasebeAyi);
    if (!context.mounted) return;
    final secim = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.cloud_upload_outlined), title: const Text('Drive\'a kaydet (paylaşılmayan rapor klasörü)'),
              onTap: () => Navigator.pop(c, 'drive')),
          ListTile(leading: const Icon(Icons.share_outlined), title: const Text('Paylaş / yazdır'), onTap: () => Navigator.pop(c, 'paylas')),
        ]),
      ),
    );
    if (secim == 'drive') {
      final m = await VeriDeposu.ben.raporuDriveKaydet(ad, pdf);
      mesaj.showSnackBar(SnackBar(content: Text(m)));
    } else if (secim == 'paylas') {
      await Printing.sharePdf(bytes: pdf, filename: ad);
    } else {
      return;
    }
    await BildirimServisi.ben.aylikRaporYapildi(h1.yil, h1.sonMuhasebeAyi);
  } catch (e) {
    mesaj.showSnackBar(SnackBar(content: Text('Rapor hazırlanamadı: $e')));
  }
}

class _Tepe extends StatelessWidget {
  const _Tepe({required this.h1, required this.h2, this.tarim});
  final GelirGiderHavuzu h1, h2;
  final UrunKarlilik? tarim;

  @override
  Widget build(BuildContext context) {
    final t1 = h1.toplam(), t2 = h2.toplam();
    final kesinAy = h1.sonMuhasebeAyi;
    Widget kol(String ad, HavuzToplam a, HavuzToplam b) => _Satir(ad, '${_mn(a.net)} / ${_mn(b.net)}', renk: _renk(a.net));
    return Panel(
      baslik: 'Net sonuç – Ocak–${raporAylari[(h1.sonAy < 1 ? 1 : h1.sonAy) - 1]} ${h1.yil}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Maliyet bedeli / piyasa fiyatı (grup içi aktarımlar)', style: TextStyle(fontSize: 12, color: Renk.soluk)),
        const SizedBox(height: 4),
        _Satir('Konsolide (ESK hariç)', '${_mn(t1.net)} / ${_mn(t2.net)}', renk: _renk(t1.net), kalin: true),
        if (kesinAy > 0 && h1.sonAy > kesinAy)
          _Satir('  Kesin (Ocak–${raporAylari[kesinAy - 1]}) / tahmin',
              '${_mn(t1.kesinNet)} / ${_mn(t1.tahminNet)}'),
        kol('Ziraat', h1.toplam(kol: Kol.ziraat), h2.toplam(kol: Kol.ziraat)),
        kol('Hayvancılık', h1.toplam(kol: Kol.hayvancilik), h2.toplam(kol: Kol.hayvancilik)),
        _Satir('ESK (ayrı izlenir)', _mn(h1.eskToplam.net), renk: _renk(h1.eskToplam.net)),
        if (tarim != null && !tarim!.bos) ...[
          const Divider(),
          _Satir('${tarim!.hasatYili} hasat sezonu ürün sonucu', '${_mn(tarim!.netKarMaliyetBedeli)} / ${_mn(tarim!.netKar)}',
              renk: _renk(tarim!.netKarMaliyetBedeli)),
        ],
        if (h1.konsolideFark != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              h1.konsolideFark!.abs() < 1000
                  ? 'Muhasebe mutabakatı sağlandı (Ocak–${raporAylari[kesinAy - 1]}).'
                  : 'Muhasebe ile ${_mn(h1.konsolideFark!)} fark var; Veri Kalitesi\'ne bakın.',
              style: TextStyle(fontSize: 12, color: h1.konsolideFark!.abs() < 1000 ? Renk.yesil : Renk.kirmizi),
            ),
          ),
      ]),
    );
  }
}

class _KarneKarti extends StatelessWidget {
  const _KarneKarti({required this.k});
  final KarneBolumu k;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(k.baslik, style: const TextStyle(fontWeight: FontWeight.w700, color: Renk.anaKoyu, fontSize: 13.5)),
          Text(k.donem, style: const TextStyle(fontSize: 11.5, color: Renk.soluk)),
          for (final g in k.gostergeler)
            if (g.deger != null || g.gecenYil != null || g.gecmis != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text('${g.ad} (${g.birim})', style: const TextStyle(fontSize: 13, color: Renk.soluk))),
                  Text(g.deger == null ? '—' : sayi(g.deger, ondalik: g.ondalik),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  SizedBox(
                    width: 112,
                    child: Text(
                      g.gecenYil == null
                          ? ''
                          : ' ${sayi(g.gecenYil, ondalik: g.ondalik)}${g.degisim == null ? '' : ' (${g.degisim! >= 0 ? '+' : '−'}%${sayi(g.degisim!.abs())})'}',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12, color: g.iyi == null ? Renk.soluk : (g.iyi! ? Renk.yesil : Renk.kirmizi)),
                    ),
                  ),
                ]),
                if (g.gecmis != null)
                  Text(g.gecmis!, style: const TextStyle(fontSize: 11, color: Renk.soluk)),
                ]),
              ),
        ]),
      );
}

class _SapmaKarti extends StatelessWidget {
  const _SapmaKarti({required this.s});
  final Sapma s;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(s.alarm ? Icons.warning_amber_rounded : (s.tekSeferlik ? Icons.event_note_outlined : Icons.trending_up),
              size: 18, color: s.alarm ? Renk.kirmizi : (s.tekSeferlik ? Renk.mavi : Renk.amber)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s.ciftlik} · ${s.donem}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text(s.baslik, style: const TextStyle(fontSize: 13, height: 1.35)),
              for (final n in s.nedenler) Text('• $n', style: const TextStyle(fontSize: 12.5, color: Renk.soluk, height: 1.35)),
            ]),
          ),
        ]),
      );
}

class _Satir extends StatelessWidget {
  const _Satir(this.etiket, this.deger, {this.renk, this.kalin = false});
  final String etiket, deger;
  final Color? renk;
  final bool kalin;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(etiket, style: const TextStyle(color: Renk.soluk, fontSize: 14))),
          const SizedBox(width: 8),
          Flexible(
            child: Text(deger,
                textAlign: TextAlign.right,
                style: TextStyle(color: renk ?? Renk.yazi, fontSize: 14, fontWeight: kalin ? FontWeight.w700 : FontWeight.w500)),
          ),
        ]),
      );
}
