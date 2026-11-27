import '../veri/esk_plan.dart';
import '../veri/kaynak_envanteri.dart';
import 'kaynak_kapsami.dart';
import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/ciftlik_rapor.dart';
import '../veri/gecmis_ozet.dart' show gecmisCiftlikAdi;
import '../veri/havuz.dart';
import '../veri/model.dart';
import '../veri/urun_karlilik.dart';
import 'bilesenler.dart';
import 'gonder.dart';
import 'net_sonuc.dart' show mtKgMaliyetleri;
import 'urun_karlilik.dart' show maliyetTakipVerisi;

String _tarih(DateTime? d) => d == null ? '—' : zamanBicim(d);
String _mn(double v) => '${v < 0 ? '−' : ''}${sayi(v.abs() / 1e6, ondalik: 2)} mn ₺';

/// Açık konu: dosyalar arası tutarsızlık ya da eksik veri, sorumlusuyla.
class AcikKonu {
  const AcikKonu(this.baslik, this.aciklama, this.sorumlu);
  final String baslik, aciklama, sorumlu;
}

/// Veri kalitesi denetimi: kaynak tarihleri, eksik aylar ve açık konular (veriden üretilir).
class VeriKalitesi {
  VeriKalitesi._(this.kaynaklar, this.eksikAylar, this.konular);
  final List<(KaynakTarihi?, String, String)> kaynaklar;
  final List<String> eksikAylar;
  final List<AcikKonu> konular;

  int get eskiSayisi => kaynaklar.where((k) => k.$1?.eski ?? false).length;
  int get uyariSayisi => eskiSayisi + eksikAylar.length + konular.length;

  static VeriKalitesi hesapla(RaporVerisi v, CiftlikRaporu? muhasebe, {DateTime? bugun}) {
    final simdi = bugun ?? DateTime.now();
    final mt = maliyetTakipVerisi();
    final gg = v.mali.gelirGider;
    final h = GelirGiderHavuzu.hesapla(faturalar: gg, muhasebe: muhasebe, mtKgMaliyet: mtKgMaliyetleri(v));
    KaynakTarihi? t(String ad) => v.kaynakTarihleri.where((k) => k.ad == ad).firstOrNull;

    String mtKapsam() {
      if (mt == null) return 'Veri yok';
      final aylar = <String>{for (final e in mt.ekilis) ...e.aylik.keys}.toList()..sort();
      if (aylar.isEmpty) return '';
      String ay(String a) {
        final p = a.split('-');
        return '${raporAylari[int.parse(p[1]) - 1]} ${p[0]}';
      }

      return '${ay(aylar.first)} – ${ay(aylar.last)}';
    }

    String suruKapsam() {
      final sh = v.suruHareketleri;
      if (sh.bos) return 'Veri yok';
      var son = 0;
      for (final c in sh.ciftlikler) {
        final a = sh.sonAy(c, simdi.year);
        if (a > son) son = a;
      }
      return son == 0 ? '' : 'Ocak–${raporAylari[son - 1]} ${simdi.year}';
    }

    String pancarKapsam() {
      final g = [for (final x in v.urunTeslimat.gunler) if (x.kaynak == 'TarKop') x.tarih]..sort();
      String f(String x) => x.length == 10 ? '${x.substring(8)}.${x.substring(5, 7)}.${x.substring(0, 4)}' : x;
      return g.isEmpty ? 'Veri yok' : '${f(g.first)} – ${f(g.last)}';
    }

    String yemKapsam() {
      final y = v.eskKaynak.yemAylik().keys.toList()..sort();
      return y.isEmpty ? 'Veri yok' : '${y.first} – ${y.last}';
    }

    final kaynaklar = <(KaynakTarihi?, String, String)>[
      (t('Çiftlik Raporları (muhasebe)'), 'Çiftlik Raporları (muhasebe)', muhasebe?.donem ?? 'Veri yok'),
      (t('Maliyet Takip'), 'Maliyet Takip', mtKapsam()),
      (t('Aylık gelir satış ve gider tabloları'), 'Aylık gelir satış ve gider tabloları', gg.bos ? 'Veri yok' : gg.donem),
      (t('Stok sayımları'), 'Stok sayımları', v.stokSayimi.bos ? 'Veri yok' : '${v.stokSayimi.donem} sayımı'.trim()),
      (t('Sürü hareketleri'), 'Sürü hareketleri', suruKapsam()),
      (t('Tarımsal Faaliyet'), 'Tarımsal Faaliyet',
          v.tarimsalUretim.bos ? 'Veri yok' : '${v.tarimsalUretim.yilBasligi} hasadı'.trim()),
      (t('Araç masrafları (muhasebe)'), 'Araç masrafları (muhasebe)', v.aracMasraf.bos ? 'Veri yok' : v.aracMasraf.donem),
      (t('Pancar teslimatı (TarKop)'), 'Pancar teslimatı (TarKop)', pancarKapsam()),
      (t('ESK bakım hizmet tablosu'), 'ESK bakım hizmet tablosu',
          v.eskKaynak.aylar.isEmpty ? 'Veri yok' : '${v.eskKaynak.aylar.first.ad} – ${v.eskKaynak.aylar.last.ad}'),
      (t('ESK ithal dana partileri'), 'ESK ithal dana partileri',
          v.eskKaynak.partiler.isEmpty ? 'Veri yok' : '${v.eskKaynak.partiler.length} parti'),
      (t('ESK gelen yemler'), 'ESK gelen yemler', yemKapsam()),
      (t('ESK kesim / ölüm listeleri'), 'ESK kesim / ölüm listeleri',
          v.eskEk.kesim.isEmpty ? 'Veri yok' : '${v.eskEk.kesim.first.ad} – ${v.eskEk.kesim.last.ad}'),
      (t('ESK kasaplık listesi'), 'ESK kasaplık listesi',
          v.eskEk.kasaplik.isEmpty ? 'Veri yok' : '${v.eskEk.kasaplik.first.parti}.–${v.eskEk.kasaplik.last.parti}. parti'),
      (t('ESK balya ve gübre'), 'ESK balya ve gübre', v.eskEk.balya.isEmpty && v.eskEk.gubre.isEmpty ? 'Veri yok' : 'Aylık tonaj'),
      (t('ESK gelir tablosu çalışması'), 'ESK gelir tablosu çalışması',
          v.eskEk.gelir.isEmpty ? 'Veri yok' : '${v.eskEk.gelir.first.ad} – ${v.eskEk.gelir.last.ad}'),
    ];

    // Eksik aylar: bu yıl için tamamlanmış son ay.
    final sonTam = simdi.month - 1;
    final eksik = <String>[];
    if (h.yil == simdi.year && sonTam >= 1) {
      if (h.sonMuhasebeAyi < sonTam) {
        final bas = h.sonMuhasebeAyi + 1;
        eksik.add('Muhasebe (Çiftlik Raporları): ${bas == sonTam ? raporAylari[sonTam - 1] : '${raporAylari[bas - 1]}–${raporAylari[sonTam - 1]}'} '
            'kapanışı bekleniyor; bu aylar Net Sonuç\'ta tahmin olarak gösteriliyor.');
      }
      if (h.sonFaturaAyi < sonTam) {
        final bas = h.sonFaturaAyi + 1;
        eksik.add('Gelir satış ve gider tabloları: ${bas == sonTam ? raporAylari[sonTam - 1] : '${raporAylari[bas - 1]}–${raporAylari[sonTam - 1]}'} '
            'faturaları henüz yok.');
      }
    }

    final konular = <AcikKonu>[];
    if (h.konsolideFark != null && h.konsolideFark!.abs() >= 1000) {
      konular.add(AcikKonu('Havuz ile muhasebe konsolide net kârı farklı',
          'Fark ${_mn(h.konsolideFark!)}. Çiftlik gelir tabloları ile konsolide sayfası birbirini tutmuyor.', 'Muhasebe'));
    }
    if (mt != null) {
      final ref = <String, int>{};
      for (final r in mt.refHatalari) {
        ref['${r.sayfa} · ${r.bolum}'] = (ref['${r.sayfa} · ${r.bolum}'] ?? 0) + r.adet;
      }
      for (final e in ref.entries) {
        konular.add(AcikKonu('Maliyet Takip: #REF! hatası', '${e.key}: ${e.value} hücre kayıp sayfaya başvuruyor.', 'Maliyet Takip sorumlusu'));
      }
      if (mt.ortakYazili != null && (mt.ortakToplam - mt.ortakYazili!).abs() >= 1) {
        konular.add(AcikKonu(
            'Maliyet Takip: tarım ortak gider TOPLAM hücresi',
            'Dosyada ${_mn(mt.ortakYazili!)}, kalemlerin toplamı ${_mn(mt.ortakToplam)} (fark ${_mn(mt.ortakToplam - mt.ortakYazili!)}).',
            'Maliyet Takip sorumlusu'));
      }
      if (!v.tarimsalUretim.bos) {
        final k = UrunKarlilik.hesapla(plan: v.tarimsalUretim, mt: mt);
        for (final (u, c, tf, m) in k.alanFarklari) {
          konular.add(AcikKonu('Ekiliş alanı iki dosyada farklı', '$u – $c: Tarımsal Faaliyet ${sayi(tf)} da, Maliyet Takip ${sayi(m)} da.',
              'Maliyet Takip sorumlusu'));
        }
        for (final u in k.urunler) {
          final yok = [for (final c in u.ciftlikler.values) if (!c.mtVar) c.ciftlik];
          if (yok.isNotEmpty) {
            konular.add(AcikKonu('Maliyet Takip\'te olmayan ekiliş', '${u.urun}: ${yok.join(', ')} (tahmini maliyet kullanılıyor).',
                'Maliyet Takip sorumlusu'));
          }
        }
      }
    }
    // Süt: fatura litresi ile muhasebe üretim kaydı (%10'dan büyük fark)
    if (muhasebe != null) {
      for (final (c, urun) in const [('Şekersüt', kSekersut), ('Pan-Gev', kPangev)]) {
        for (final b in muhasebe.birimAylar(urun)) {
          if (b.yil != h.yil || b.miktar <= 0) continue;
          final l = gg.gelir
              .where((g) => g.ciftlik == c && g.yil == b.yil && g.ay == b.ayNo && g.urun == 'Çiğ süt' && g.birim.toUpperCase() == 'L')
              .fold(0.0, (s, g) => s + g.miktar);
          if (l > 0 && ((l - b.miktar) / b.miktar).abs() > 0.10) {
            konular.add(AcikKonu('$c süt litresi: fatura ile muhasebe farklı (${raporAylari[b.ayNo - 1]})',
                'Gelir tablosundaki süt faturası ${sayi(l)} L, muhasebe üretim kaydı ${sayi(b.miktar)} L. '
                    'Fatura başka bir ayın teslimini içeriyor olabilir; aylık litre için muhasebe kaydı kullanılır.',
                'Muhasebe'));
          }
        }
      }
    }
    // Hayvan sayısı: Maliyet Takip ile Sürü Hareketleri (%5'ten büyük fark)
    if (mt != null && !v.suruHareketleri.bos) {
      for (final x in mt.hayvan) {
        if (x.yil != h.yil || x.hayvan == null || x.hayvan == 0) continue;
        final s = v.suruHareketleri.deger(x.ciftlik, x.yil, x.ay, 'TÜM SÜRÜ');
        if (s == null || s == 0) continue;
        if (((x.hayvan! - s) / s).abs() > 0.05) {
          konular.add(AcikKonu('${x.ciftlik} hayvan sayısı: Maliyet Takip ile Sürü Hareketleri farklı (${raporAylari[x.ay - 1]})',
              'Maliyet Takip ${sayi(x.hayvan)}, Sürü Hareketleri ${sayi(s)} baş. Hayvan sayısının asıl kaynağı Sürü Hareketleri\'dir.',
              'Maliyet Takip sorumlusu'));
        }
      }
    }
    // Çiftlik Raporları otomatik dönüştürme
    final dn = v.ciftlikRaporTam.donusum;
    if (dn.contains('Drive API') || dn.contains('hata')) {
      konular.add(AcikKonu('Çiftlik Raporları otomatik dönüştürülemiyor',
          '$dn. Apps Script › Hizmetler › Drive API eklenmeli; o zamana kadar yeni xlsx elle E-Tabloya çevrilmeli.', 'Uygulama sahibi'));
    }
    for (final m in v.ciftlikRaporTam.mutabakat.where((m) => !m.uyumlu)) {
      konular.add(AcikKonu('Çiftlik Raporları: ${m.sayfa} ile ${m.karsi} farklı',
          'Özet ${_mn(m.ozet)}, detay 2026 ${_mn(m.detay2026)}, detay tüm yıllar ${_mn(m.detayTum)}.${m.aciklama.isEmpty ? '' : ' ${m.aciklama}'}',
          'Muhasebe'));
    }
    for (final h in v.ciftlikRaporTam.hatalar) {
      konular.add(AcikKonu('Çiftlik Raporları sayfası okunamadı', h, 'Uygulama sahibi'));
    }
    // Kaynak envanteri: okunamayan dosya / sayfa
    for (final r in v.kaynakEnvanteri.liste) {
      if (r.length >= 5 && r[3] == 'hata') {
        konular.add(AcikKonu('Kaynak okunamadı: ${r[1]}${r[2].isEmpty ? '' : ' › ${r[2]}'}', r[4], 'Uygulama sahibi'));
      }
    }
    // ESK çalışma › ÖZET sayfası ile ESK_Aylık
    for (final f in eskOzetMutabakat(EskPlan.coz(v.kaynakTablolari), v.eskAylik)) {
      konular.add(AcikKonu('ESK çalışma › ÖZET ile ESK_Aylık farklı (${raporAylari[f.ay - 1]} ${f.yil})',
          '${f.kalem}: ÖZET sayfasında ${sayi(f.ozet)}, ESK_Aylık\'ta ${sayi(f.aylik)}.', 'ESK sorumlusu'));
    }
    // Değerlendirme raporu: oranlar sayılarla tutarlı mı
    for (final k in v.gecmisOzet.kontroller) {
      konular.add(AcikKonu('Değerlendirme Raporu › ${k.tablo.trim()} · ${gecmisCiftlikAdi(k.ciftlik)} ${k.yil}',
          '${k.olcu} %${sayi(k.yazilan, ondalik: 1)} yazılmış; ${k.pay} / ${k.payda} ile hesaplanan oran %${sayi(k.hesaplanan, ondalik: 1)}.'
              '${k.hesaplanan > 100 ? ' Oran %100\'ü aşıyor; sayılar kontrol edilmeli.' : ''}',
          'Değerlendirme raporunu hazırlayan birim'));
    }
    // Maliyet Takip › İlaç aşı ve diğer malzemeler
    final mtd = v.maliyetTakipDetay;
    for (final h in mtd.hatalar) {
      konular.add(AcikKonu('Maliyet Takip ayrıntı sayfası okunamadı', h, 'Uygulama sahibi'));
    }
    for (final n in mtd.notlar) {
      konular.add(AcikKonu('Maliyet Takip › ${n.tur} · ${n.ciftlik}', n.not, 'Maliyet Takip sorumlusu'));
    }
    final mtFiyatsiz = mtd.kalemler.where((k) => k.tutar == 0 && k.miktar > 0).length;
    if (mtFiyatsiz > 0) {
      konular.add(AcikKonu('Maliyet Takip: tutarı girilmemiş malzeme kalemleri',
          '$mtFiyatsiz kalemde tüketim miktarı var, birim fiyat / tutar boş veya 0.', 'Maliyet Takip sorumlusu'));
    }
    // Araç masrafları
    final am = v.aracMasraf;
    if (!am.bos) {
      if (am.genelToplam != null && (am.araclarToplami - am.genelToplam!).abs() >= 1) {
        konular.add(AcikKonu('Araç masrafları: GENEL TOPLAM hücresi',
            'Dosyada ${_mn(am.genelToplam!)}, araç satırlarının toplamı ${_mn(am.araclarToplami)} '
                '(fark ${_mn(am.araclarToplami - am.genelToplam!)}); toplam formülüne dahil edilmeyen satır var.',
            'Muhasebe'));
      }
      final adsiz = am.araclar.where((a) => a.arac == 'Adı yazılmamış araç').length;
      if (adsiz > 0) {
        konular.add(AcikKonu('Araç masrafları: araç adı boş', '$adsiz satırda araç adı yazılmamış.', 'Muhasebe'));
      }
      final uysuz = [for (final a in am.araclar) if (a.uretimYeri.isEmpty) a];
      if (uysuz.isNotEmpty) {
        konular.add(AcikKonu('Araç masrafları: iş alanı belirlenemeyen araçlar',
            '${uysuz.length} araç (${_mn(uysuz.fold(0.0, (t, a) => t + a.toplam))}) detay sayfasında iş alanıyla eşleşmiyor; '
                'gider kollara dağıtılamıyor.',
            'Muhasebe'));
      }
    }
    // ESK: kaynak tablo ile ESK aylık rapor
    final em = [...v.eskKaynak.mutabakat(v.eskAylik), ...v.eskEk.mutabakat(v.eskKaynak, v.eskAylik)];
    final supheli = v.eskEk.kesim.fold(0, (t, x) => t + x.supheli);
    if (supheli > 0) {
      konular.add(AcikKonu('ESK kesim listesi: şüpheli canlı ağırlık',
          '$supheli satırda baş başına canlı ağırlık 150–900 kg dışında (ör. fazladan sıfır yazılmış olabilir).', 'ESK sorumlusu'));
    }
    if (em.isNotEmpty) {
      konular.add(AcikKonu('ESK: kaynak tablo ile aylık rapor farklı',
          em.take(4).map((m) => '${m.ay} ${m.kalem}: tablo ${sayi(m.kaynak)}, rapor ${sayi(m.rapor)}').join('; ') +
              (em.length > 4 ? ' (+${em.length - 4} fark)' : ''),
          'ESK sorumlusu'));
    }
    for (final a in v.eskKaynak.aylar) {
      final h2 = a.hesaplananGider, b = a.bakimGideri;
      if (h2 != null && b != null && (h2 - b).abs() > 1) {
        konular.add(AcikKonu('ESK bakım tablosu: bedel baş-gün × birim fiyattan farklı (${a.ad})',
            'Tabloda ${_mn(b)}, hesaplanan ${_mn(h2)}.', 'ESK sorumlusu'));
      }
    }
    for (final s in muhasebe?.senaryo?.kontrol ?? const []) {
      if (s.tur == 'tutarsizlik') konular.add(AcikKonu(s.baslik, s.aciklama, 'Muhasebe'));
    }
    return VeriKalitesi._(kaynaklar, eksik, konular);
  }
}

/// Asistan › Veri Kalitesi.
class VeriKalitesiEkran extends StatefulWidget {
  const VeriKalitesiEkran({super.key, required this.veri});
  final RaporVerisi veri;

  @override
  State<VeriKalitesiEkran> createState() => _VeriKalitesiEkranState();
}

class _VeriKalitesiEkranState extends State<VeriKalitesiEkran> {
  late final Future<CiftlikRaporu?> _muhasebe =
      CiftlikRaporu.yukle().then<CiftlikRaporu?>((r) => r).catchError((Object _) => null);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Veri Kalitesi'), actions: const [TabloGuncelleButonu()]),
        body: ListenableBuilder(
          listenable: VeriDeposu.ben,
          builder: (context, _) => FutureBuilder<CiftlikRaporu?>(
            future: _muhasebe,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              final v = VeriDeposu.ben.veri ?? widget.veri;
              final q = VeriKalitesi.hesapla(v, snap.data);
              return GonderAlani(konu: 'Veri Kalitesi', child: _Icerik(q: q, tarihVar: v.kaynakTarihleri.isNotEmpty, gelen: v.gelenDosyalar));
            },
          ),
        ),
      );
}

class _Icerik extends StatelessWidget {
  const _Icerik({required this.q, required this.tarihVar, this.gelen = const []});
  final VeriKalitesi q;
  final bool tarihVar;
  final List<GelenDosya> gelen;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Panel(
            baslik: 'Özet',
            child: Text(
              q.uyariSayisi == 0
                  ? 'Bütün kaynaklar güncel; açık konu yok.'
                  : '${q.eskiSayisi} kaynakta veri eski · ${q.eksikAylar.length} eksik dönem · ${q.konular.length} açık konu',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: q.uyariSayisi == 0 ? Renk.yesil : Renk.amber),
            ),
          ),
          if (!tarihVar)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: BilgiKutusu(yazi: 'Kaynak dosyaların değişiklik tarihleri, Apps Script güncellendiğinde görünür.'),
            ),
          Builder(builder: (context) {
            final ke = VeriDeposu.ben.veri?.kaynakEnvanteri ?? const KaynakEnvanterOzet();
            return Panel(
              baslik: 'Kaynak Kapsamı',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(
                    ke.yok
                        ? 'Kaynak envanteri henüz hazırlanmadı (Apps Script › kaynakEnvanteriHazirla).'
                        : '${ke.dosya} dosya · ${ke.sayfa} sayfa: ${ke.kullanilan} piramitte kullanılıyor, '
                            '${ke.kullanilmayan} henüz kullanılmıyor, ${ke.kvkk} KVKK nedeniyle hariç, ${ke.hata} okunamadı. '
                            '${ke.not} not / açıklama, ${ke.formulHatasi} formül hatası.${ke.tamam ? '' : ' İnceleme sürüyor.'}',
                    style: const TextStyle(fontSize: 13, height: 1.4)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.travel_explore, size: 18),
                    label: const Text('Sayfa sayfa incele'),
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => const KaynakKapsamiEkran())),
                  ),
                ),
              ]),
            );
          }),
          Panel(
            baslik: 'Kaynaklar',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final (t, ad, kapsam) in q.kaynaklar) _KaynakSatiri(t: t, ad: ad, kapsam: kapsam),
            ]),
          ),
          Panel(
            baslik: 'Gelen Dosyalar (${gelen.length} işlenmeyi bekliyor)',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (gelen.isEmpty)
                const Text('Bekleyen dosya yok.', style: TextStyle(fontSize: 13))
              else
                for (final d in gelen)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text('• ${d.ad} (${d.tur}${d.eklenme == null ? '' : ', eklendi ${tarihKisa(d.eklenme!)}'})',
                        style: const TextStyle(fontSize: 13, height: 1.4)),
                  ),
              const SizedBox(height: 4),
              const Text(
                  "Uygulamaya bağlanacak yeni dosyayı Drive'daki \"Yönetim Raporu – Gelen Dosyalar\" klasörüne (dosya ya da kısayol olarak) "
                  "koyun. Dosya incelenip uygulamaya bağlandığında klasördeki \"İşlenenler\" alt klasörüne taşınır. Yalnızca dosya adı ve tarihi okunur.",
                  style: TextStyle(fontSize: 12, color: Renk.soluk, height: 1.4)),
            ]),
          ),
          if (q.eksikAylar.isNotEmpty)
            Panel(
              baslik: 'Eksik dönemler',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final x in q.eksikAylar)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text('• $x', style: const TextStyle(fontSize: 13, height: 1.4))),
              ]),
            ),
          Panel(
            baslik: 'Açık konular (${q.konular.length})',
            child: q.konular.isEmpty
                ? const Text('Dosyalar arası tutarsızlık bulunmadı.', style: TextStyle(fontSize: 13))
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    for (final k in q.konular)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(k.baslik, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          const SizedBox(height: 2),
                          Text(k.aciklama, style: const TextStyle(fontSize: 13, height: 1.4)),
                          Text('Sorumlu: ${k.sorumlu}', style: const TextStyle(fontSize: 12, color: Renk.soluk)),
                        ]),
                      ),
                  ]),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Açık konular dosyalar okunduğunda yeniden hesaplanır; personel düzeltme yaptığında kendiliğinden kapanır. '
              'Yalnızca dosya tarihleri ve toplam tutarlar kullanılır; kişisel veri okunmaz.',
              style: TextStyle(fontSize: 12, color: Renk.soluk, height: 1.4),
            ),
          ),
        ],
      );
}

class _KaynakSatiri extends StatelessWidget {
  const _KaynakSatiri({required this.t, required this.ad, required this.kapsam});
  final KaynakTarihi? t;
  final String ad, kapsam;

  @override
  Widget build(BuildContext context) {
    final (durum, renk) = t == null
        ? ('Tarih bilinmiyor', Renk.soluk)
        : t!.canli
            ? ('Doğrudan okunuyor', Renk.yesil)
            : t!.eski
                ? ('Veri eski – kopya yenilenmeli', Renk.kirmizi)
                : ('Güncel', Renk.yesil);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(ad, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
          Text(durum, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: renk)),
        ]),
        if (kapsam.isNotEmpty) Text('Kapsanan dönem: $kapsam', style: const TextStyle(fontSize: 12.5)),
        if (t != null)
          Text(
              t!.canli
                  ? 'Kaynak son değişiklik: ${_tarih(t!.kaynak)}'
                  : 'Kaynak son değişiklik: ${_tarih(t!.kaynak)} · Uygulamadaki kopya: ${_tarih(t!.kopya)}',
              style: const TextStyle(fontSize: 12, color: Renk.soluk)),
      ]),
    );
  }
}
