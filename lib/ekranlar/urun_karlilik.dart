import 'package:flutter/material.dart';

import '../bicim.dart';
import '../tema.dart';
import '../veri/ciftlik_rapor.dart';
import '../veri/dosyalar.dart';
import '../veri/maliyet_takip.dart';
import '../veri/model.dart';
import '../veri/urun_karlilik.dart';
import '../veri/urun_takip.dart';
import 'bilesenler.dart';

String _mn(double v) => '${v < 0 ? '−' : ''}${sayi(v.abs() / 1e6, ondalik: 2)} mn ₺';
String _tl(double v) => '${v < 0 ? '−' : ''}${sayi(v.abs())} ₺';
String _ton(double kg) => '${sayi(kg / 1000)} ton';
Color _renk(double v) => v >= 0 ? Renk.yesil : Renk.kirmizi;

String? _mtMetin;
MaliyetTakip? _mt;

/// Sunucudan gelen maliyet takip dosyası (aynı metin için bir kez çözülür).
MaliyetTakip? maliyetTakipVerisi() {
  final m = UygulamaDosyalari.metin('maliyet_takip_2026');
  if (m == null) return null;
  if (m != _mtMetin) {
    _mtMetin = m;
    try {
      _mt = MaliyetTakip.coz(m);
    } catch (_) {
      _mt = null;
    }
  }
  return _mt;
}

/// Ürün Takibi › Kârlılık sekmesi.
class UrunKarlilikSekmesi extends StatefulWidget {
  const UrunKarlilikSekmesi({super.key, required this.v, required this.t});
  final RaporVerisi v;
  final UrunTakibi t;

  @override
  State<UrunKarlilikSekmesi> createState() => _UrunKarlilikSekmesiState();
}

class _UrunKarlilikSekmesiState extends State<UrunKarlilikSekmesi> {
  OrtakAnahtar _anahtar = OrtakAnahtar.dekar;
  late final Future<CiftlikRaporu?> _muhasebe =
      CiftlikRaporu.yukle().then<CiftlikRaporu?>((r) => r).catchError((Object _) => null);

  @override
  Widget build(BuildContext context) => FutureBuilder<CiftlikRaporu?>(
        future: _muhasebe,
        builder: (context, snap) => _icerik(snap.data),
      );

  Widget _icerik(CiftlikRaporu? muhasebe) {
    final mt = maliyetTakipVerisi();
    final k = UrunKarlilik.hesapla(
        plan: widget.v.tarimsalUretim,
        mt: mt,
        gelir: widget.v.mali.gelirGider,
        teslimat: widget.t,
        muhasebe: muhasebe,
        anahtar: _anahtar);
    if (k.bos) {
      return const Padding(
          padding: EdgeInsets.all(16), child: BilgiKutusu(yazi: 'Tarımsal Faaliyet verisi henüz gelmedi.'));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        if (!k.mtVar)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: BilgiKutusu(
                uyari: true,
                yazi: 'Maliyet Takip verisi gelmedi; maliyetler Tarımsal Faaliyet tahminidir ve ortak giderler dağıtılmadı.'),
          ),
        _Ozet(k: k),
        Panel(
          baslik: 'Ortak gider dağıtım anahtarı',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SegmentedButton<OrtakAnahtar>(
              segments: const [
                ButtonSegment(value: OrtakAnahtar.dekar, label: Text('Ekim alanı')),
                ButtonSegment(value: OrtakAnahtar.maliyet, label: Text('Doğrudan maliyet')),
              ],
              selected: {_anahtar},
              onSelectionChanged: (s) => setState(() => _anahtar = s.first),
            ),
            const SizedBox(height: 6),
            Text(
              _anahtar == OrtakAnahtar.dekar
                  ? 'Ortak giderler (${_mn(k.ortakToplam)}) ekim alanına göre dağıtılır: '
                      '${sayi(k.ortakDekarlari)} da, dekar başına ${_tl(k.ortakDekarlari > 0 ? k.ortakToplam / k.ortakDekarlari : 0)}.'
                  : 'Ortak giderler (${_mn(k.ortakToplam)}) her ürünün doğrudan maliyet payına göre dağıtılır.',
              style: const TextStyle(fontSize: 12, color: Renk.soluk, height: 1.4),
            ),
          ]),
        ),
        _Tablo(k: k),
        if (k.muhasebeVar) _Muhasebe(k: k),
        if (k.senaryo != null) _Senaryo(k: k),
        for (final u in k.urunler) _UrunKarti(u: u),
        _Kontroller(k: k),
        _Kaynak(k: k, v: widget.v),
      ],
    );
  }
}

class _Ozet extends StatelessWidget {
  const _Ozet({required this.k});
  final UrunKarlilik k;

  @override
  Widget build(BuildContext context) => Panel(
        baslik: '${k.hasatYili} hasat sezonu – genel toplam',
        child: Column(children: [
          _Satir('Ekim alanı', '${sayi(k.dekar)} da'),
          _Satir('Beklenen satış (plan tonaj × fiyat)', _mn(k.planSatis)),
          _Satir('Doğrudan maliyet', _mn(k.maliyet)),
          _Satir('Ortak gider öncesi kâr', _mn(k.brutKar), renk: _renk(k.brutKar)),
          _Satir('Tarım ortak giderleri', '−${_mn(k.ortakPay)}'),
          _Satir('Net ürün kârı', _mn(k.netKar), renk: _renk(k.netKar), kalin: true),
          if (k.ekGelirler.isNotEmpty || k.tarimsalTesvik > 0) ...[
            for (final e in k.ekGelirler) _Satir('+ ${_basHarf(e.$1)} (plan)', _mn(e.$2)),
            if (k.tarimsalTesvik > 0) _Satir('+ Tarımsal teşvik (muhasebe, ${k.muhasebeDonem})', _mn(k.tarimsalTesvik)),
            _Satir('Ek gelirlerle toplam', _mn(k.netKar + k.ekGelirToplami + k.tarimsalTesvik),
                renk: _renk(k.netKar + k.ekGelirToplami + k.tarimsalTesvik), kalin: true),
          ],
          const Divider(),
          _Satir('Sezonda faturalanan satış', _mn(k.faturaTutar), kalin: true),
          _Satir('Henüz faturalanmayan beklenen satış', _mn(k.faturalanmamis), renk: Renk.amber),
          _Satir('Faturalanan tutara göre sonuç', _mn(k.faturaKar), renk: _renk(k.faturaKar)),
        ]),
      );
}

class _Tablo extends StatelessWidget {
  const _Tablo({required this.k});
  final UrunKarlilik k;

  @override
  Widget build(BuildContext context) {
    const s = TextStyle(fontSize: 12);
    const b = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);
    DataCell h(String t, {Color? r, bool kalin = false}) =>
        DataCell(Text(t, style: (kalin ? b : s).copyWith(color: r)));
    String m(double v) => sayi(v / 1e6, ondalik: 2);
    return Panel(
      baslik: 'Ürün bazında kârlılık (mn ₺)',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 14,
          headingRowHeight: 40,
          dataRowMinHeight: 32,
          dataRowMaxHeight: 36,
          headingTextStyle: b.copyWith(color: Renk.anaKoyu),
          columns: const [
            DataColumn(label: Text('Ürün')),
            DataColumn(label: Text('Dekar'), numeric: true),
            DataColumn(label: Text('Beklenen\nsatış'), numeric: true),
            DataColumn(label: Text('Doğrudan\nmaliyet'), numeric: true),
            DataColumn(label: Text('Ortak\nöncesi'), numeric: true),
            DataColumn(label: Text('Ortak\npay'), numeric: true),
            DataColumn(label: Text('Net'), numeric: true),
            DataColumn(label: Text('₺/da'), numeric: true),
            DataColumn(label: Text('Faturalanan'), numeric: true),
          ],
          rows: [
            for (final u in k.urunler)
              DataRow(cells: [
                h(u.urun + (u.tahminiMaliyetVar ? ' *' : ''), kalin: true),
                h(sayi(u.dekar)),
                h(m(u.planSatis)),
                h(m(u.maliyet)),
                h(m(u.brutKar), r: _renk(u.brutKar)),
                h(m(u.ortakPay)),
                h(m(u.netKar), r: _renk(u.netKar), kalin: true),
                h(sayi(u.dekarNet), r: _renk(u.dekarNet)),
                h(m(u.faturaTutar)),
              ]),
            DataRow(color: const WidgetStatePropertyAll(Renk.anaAcik), cells: [
              h('Toplam', kalin: true),
              h(sayi(k.dekar), kalin: true),
              h(m(k.planSatis), kalin: true),
              h(m(k.maliyet), kalin: true),
              h(m(k.brutKar), r: _renk(k.brutKar), kalin: true),
              h(m(k.ortakPay), kalin: true),
              h(m(k.netKar), r: _renk(k.netKar), kalin: true),
              h(k.dekar > 0 ? sayi(k.netKar / k.dekar) : '—', kalin: true),
              h(m(k.faturaTutar), kalin: true),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Muhasebe (Çiftlik Raporları › Tarımsal Alan) ile çapraz kontrol.
class _Muhasebe extends StatelessWidget {
  const _Muhasebe({required this.k});
  final UrunKarlilik k;

  @override
  Widget build(BuildContext context) {
    const s = TextStyle(fontSize: 12);
    const b = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);
    DataCell h(String t, {Color? r, bool kalin = false}) => DataCell(Text(t, style: (kalin ? b : s).copyWith(color: r)));
    String m(double v) => sayi(v / 1e6, ondalik: 2);
    final l = [for (final u in k.urunler) if (u.muhVar || u.faturaTutar > 0) u];
    final notlar = <String>[
      for (final u in l)
        if (u.muhVar && u.faturaTutar > 0 && (u.muhSatisTl - u.faturaTutar).abs() >= 1)
          '${u.urun}: muhasebe satışı ${_tl(u.muhSatisTl)}, gelir tablosu ${_tl(u.faturaTutar)} (fark ${_tl(u.muhSatisTl - u.faturaTutar)}).',
      for (final u in l)
        if (u.muhVar && u.muhSatisKg > 0 && u.muhSmm > 0)
          '${u.urun}: muhasebede satılan ${_ton(u.muhSatisKg)} için maliyet ${sayi(u.muhSmm / u.muhSatisKg, ondalik: 2)} ₺/kg; '
              'Maliyet Takip\'e göre ${sayi(u.planKg > 0 ? u.maliyet / u.planKg : 0, ondalik: 2)} ₺/kg (plan tonajıyla, ortak gider hariç).',
      for (final u in l)
        if (!u.muhVar && u.faturaTutar > 0)
          '${u.urun}: ${_tl(u.faturaTutar)} fatura muhasebe döneminden (${k.muhasebeDonem}) sonra kesildi.',
    ];
    return Panel(
      baslik: 'Muhasebe ile çapraz kontrol (${k.muhasebeDonem})',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 14,
            headingRowHeight: 40,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 36,
            headingTextStyle: b.copyWith(color: Renk.anaKoyu),
            columns: const [
              DataColumn(label: Text('Ürün')),
              DataColumn(label: Text('Gelir\ntablosu'), numeric: true),
              DataColumn(label: Text('Muhasebe\nsatış'), numeric: true),
              DataColumn(label: Text('Muhasebe\nmaliyet'), numeric: true),
              DataColumn(label: Text('Maliyet\nTakip'), numeric: true),
            ],
            rows: [
              for (final u in l)
                DataRow(cells: [
                  h(u.urun, kalin: true),
                  h(m(u.faturaTutar)),
                  h(u.muhVar ? m(u.muhSatisTl) : '—'),
                  h(u.muhVar ? m(u.muhSmm) : '—'),
                  h(m(u.maliyet)),
                ]),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text('mn ₺ · Muhasebe maliyeti yalnızca satılan miktarın maliyetidir; Maliyet Takip ekilişin tamamını kapsar.',
            style: TextStyle(fontSize: 11, color: Renk.soluk)),
        for (final x in notlar)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text('• $x', style: const TextStyle(fontSize: 13, height: 1.4))),
      ]),
    );
  }
}

/// İşletme içinde kullanılan ürünler dışarı satılsaydı / dışarıdan alınsaydı (dosyadaki 2. senaryo).
class _Senaryo extends StatelessWidget {
  const _Senaryo({required this.k});
  final UrunKarlilik k;

  @override
  Widget build(BuildContext context) {
    final s = k.senaryo!;
    final ic = [for (final u in k.urunler) if (u.icKg > 0) u];
    return Panel(
      baslik: 'Piyasa fiyatı senaryosu – Tarımsal Alan',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text(
            'Çiftlik Raporları dosyası: 1. senaryoda grup içinde kullanılan ürünler maliyet bedeliyle aktarılır; '
            '2. senaryoda dışarı satılsaydı piyasa satış fiyatıyla, dışarıdan alınsaydı piyasa alış fiyatıyla değerlenir.',
            style: TextStyle(fontSize: 12, color: Renk.soluk, height: 1.4)),
        const SizedBox(height: 6),
        _Satir('Net satışlar', '${_mn(s.satis1)} → ${_mn(s.satis2)}'),
        _Satir('Satışların maliyeti', '${_mn(s.smm1)} → ${_mn(s.smm2)}'),
        _Satir('Brüt kâr', '${_mn(s.brut1)} → ${_mn(s.brut2)}', kalin: true),
        _Satir('Dönem net kârı', '${_mn(s.net1)} → ${_mn(s.net2)}', renk: _renk(s.net2 - s.net1), kalin: true),
        _Satir('Piyasa fiyatıyla değerleme farkı', _mn(s.satis2 - s.satis1)),
        if (ic.isNotEmpty) ...[
          const Divider(),
          const Text('Bu tablodaki karşılığı (faturalanmayan yem bitkileri, plan fiyatıyla):',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          for (final u in ic)
            _Satir('  ${u.urun}', '${_ton(u.icKg)} × ${sayi(u.planFiyat, ondalik: 2)} = ${_mn(u.icPiyasaDegeri)}'),
          _Satir('İç kullanım piyasa değeri', _mn(k.icPiyasaDegeri), kalin: true),
          _Satir('İç kullanıma düşen doğrudan maliyet', _mn(k.icMaliyet)),
          _Satir('Piyasa fiyatıyla brüt katkı', _mn(k.icPiyasaDegeri - k.icMaliyet), renk: _renk(k.icPiyasaDegeri - k.icMaliyet)),
          _Satir('Dosyadaki değerleme farkıyla fark', _mn(k.icPiyasaDegeri - (s.satis2 - s.satis1))),
        ],
      ]),
    );
  }
}

class _UrunKarti extends StatelessWidget {
  const _UrunKarti({required this.u});
  final KarlilikUrun u;

  @override
  Widget build(BuildContext context) => Panel(
        baslik: u.urun,
        eylem: Text(_mn(u.netKar), style: TextStyle(fontWeight: FontWeight.w700, color: _renk(u.netKar))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Satir('Ekim alanı', '${sayi(u.dekar)} da'),
          _Satir('Planlanan tonaj', '${_ton(u.planKg)} (${sayi(u.dekar > 0 ? u.planKg / u.dekar : 0)} kg/da)'),
          _Satir('Birim satış fiyatı (plan)', '${sayi(u.planFiyat, ondalik: 2)} ₺/kg'),
          _Satir('Beklenen satış', _tl(u.planSatis)),
          for (final c in u.ciftlikler.values)
            _Satir('  ${c.ciftlik} maliyeti${c.mtVar ? '' : ' (tahmini)'}', _tl(c.maliyet)),
          _Satir('Doğrudan maliyet', _tl(u.maliyet), kalin: true),
          if (u.tfMaliyet != u.maliyet)
            _Satir('  Tarımsal Faaliyet tahmini', '${_tl(u.tfMaliyet)} (fark ${_tl(u.maliyet - u.tfMaliyet)})'),
          _Satir('Ortak gider payı', _tl(u.ortakPay)),
          _Satir('Net ürün kârı', _tl(u.netKar), renk: _renk(u.netKar), kalin: true),
          _Satir('Dekar başına', _tl(u.dekarNet), renk: _renk(u.dekarNet)),
          _Satir('Kg maliyeti (ortak dahil)', '${sayi(u.kgMaliyet, ondalik: 2)} ₺/kg'),
          const Divider(),
          if (u.teslimKg > 0) _Satir('Teslim edilen (bedele esas net)', _ton(u.teslimKg)),
          _Satir('Sezonda faturalanan',
              u.faturaTutar > 0 ? '${_ton(u.faturaKg)} · ${_tl(u.faturaTutar)} (${sayi(u.faturaFiyat, ondalik: 2)} ₺/kg)' : 'Fatura yok'),
          if (u.faturaOrani != null && u.faturaTutar > 0) _Satir('Plan tonajının faturalanan oranı', '%${sayi(u.faturaOrani, ondalik: 1)}'),
          if (u.faturalanmamis > 0) _Satir('Faturalanmayan beklenen satış', _tl(u.faturalanmamis), renk: Renk.amber),
          if (u.oncekiTutar > 0)
            _Satir('Sezon öncesi fatura (önceki hasat)', '${_ton(u.oncekiKg)} · ${_tl(u.oncekiTutar)}', renk: Renk.soluk),
          _Satir('Faturalanan tutara göre sonuç', _tl(u.faturaKar), renk: _renk(u.faturaKar)),
        ]),
      );
}

class _Kontroller extends StatelessWidget {
  const _Kontroller({required this.k});
  final UrunKarlilik k;

  @override
  Widget build(BuildContext context) {
    final l = <String>[
      if (k.ortakFark != null && k.ortakFark!.abs() >= 1)
        'Maliyet Takip › ortak giderler: dosyadaki TOPLAM hücresi ${_tl(k.ortakYazili!)}, işçilik + amortisman + diğer '
            'kalemlerinin toplamı ${_tl(k.ortakToplam)} (fark ${_tl(k.ortakFark!)}). Hesapta kalemlerin toplamı kullanıldı; '
            'dosyadaki TOPLAM formülünün kontrol edilmesi gerekir.',
      for (final (u, c, tf, mt) in k.alanFarklari)
        '$u – $c: Tarımsal Faaliyet ${sayi(tf)} da, Maliyet Takip ${sayi(mt)} da. Hesapta Tarımsal Faaliyet alanı kullanıldı.',
      for (final u in k.urunler)
        if (u.tahminiMaliyetVar)
          '${u.urun}: ${[for (final c in u.ciftlikler.values) if (!c.mtVar) c.ciftlik].join(', ')} Maliyet Takip dosyasında yok; '
              'Tarımsal Faaliyet tahmini maliyet kullanıldı (*).',
      for (final u in k.urunler)
        if (u.planSatis > 0 && u.faturaTutar == 0 && u.oncekiTutar == 0 && u.teslimKg == 0)
          '${u.urun}: sezonda satış faturası yok. Beklenen satış piyasa fiyatıyla değerlendi; ürün işletme içinde yem olarak '
              'kullanılıyorsa nakit girişi oluşmaz.',
      for (final (u, c, t) in k.digerGelir)
        '$u ($c hesabı) sezonda ${_tl(t)} faturalandı; ürün tablosunda karşılığı olmadığından kârlılığa dahil edilmedi.',
    ];
    if (l.isEmpty) return const SizedBox.shrink();
    return Panel(
      baslik: 'Dosyalar arası kontrol',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final x in l)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('• $x', style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
      ]),
    );
  }
}

class _Kaynak extends StatelessWidget {
  const _Kaynak({required this.k, required this.v});
  final UrunKarlilik k;
  final RaporVerisi v;

  @override
  Widget build(BuildContext context) {
    final g = v.mali.gelirGider;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      child: Text(
        [
          'Alan, tonaj, fiyat ve beklenen satış: ${v.tarimsalUretim.dosya.isEmpty ? 'Tarımsal Faaliyet' : v.tarimsalUretim.dosya} › ÇİFTLİK BAZINDA.',
          'Doğrudan maliyet ve ortak giderler: ÇİFTLİKLER : MALİYET TAKİP 2026 › MALİYET ÖZET TARIM 2026 (gerçekleşen).',
          'Faturalanan satış: ${g.kaynakGelir.isEmpty ? 'aylık gelir satış tablosu' : g.kaynakGelir} — '
              '${tarihKisa(k.sezonBas)} ile ${tarihKisa(k.sezonBit.subtract(const Duration(days: 1)))} arasında kesilen faturalar (KDV hariç).',
          if (k.muhasebeVar)
            'Muhasebe ve senaryo: 2026 Yılı Çiftlik Raporları › Tarımsal Alan gelir tablosu, satış özeti, SMM detayı, "1611 - Tarımsal Alan 2" (${k.muhasebeDonem}).',
          'Teslim edilen: Ürün Takibi teslimat kayıtları (TarKop, patates listesi, uygulamadan giriş).',
          'Yalnızca ürün, çiftlik, alan, miktar ve tutar kullanılır; müşteri, satıcı ve kişi bilgisi alınmaz.',
        ].join('\n'),
        style: const TextStyle(fontSize: 12, color: Renk.soluk, height: 1.4),
      ),
    );
  }
}

String _basHarf(String s) {
  final k = s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase().trim();
  return k.isEmpty ? k : '${k[0].toUpperCase()}${k.substring(1)}';
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
