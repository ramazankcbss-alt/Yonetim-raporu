import 'package:flutter/material.dart';

import '../bicim.dart';
import '../tema.dart';
import '../veri/ciftlik_rapor.dart';
import '../veri/havuz.dart';
import '../veri/model.dart';
import '../veri/urun_karlilik.dart';
import 'bilesenler.dart';
import 'urun_karlilik.dart' show maliyetTakipVerisi;

String _mn(double v) => '${v < 0 ? '−' : ''}${sayi(v.abs() / 1e6, ondalik: 2)} mn ₺';
String _m(double v) => '${v < 0 ? '−' : ''}${sayi(v.abs() / 1e6, ondalik: 2)}';
Color _renk(double v) => v >= 0 ? Renk.yesil : Renk.kirmizi;
String _ay(int a) => raporAylari[a - 1];

/// Muhasebedeki Tarımsal Alan dışındaki ürünler için Maliyet Takip birim maliyeti (₺/kg, doğrudan maliyet / plan tonaj).
Map<String, double> mtKgMaliyetleri(RaporVerisi v) {
  final mt = maliyetTakipVerisi();
  if (mt == null || v.tarimsalUretim.bos) return const {};
  final k = UrunKarlilik.hesapla(plan: v.tarimsalUretim, mt: mt);
  return {for (final u in k.urunler) if (u.planKg > 0 && !u.tahminiMaliyetVar) u.urun: u.maliyet / u.planKg};
}

/// Mali Raporlar › Net Sonuç: gelir ve gider havuzu (piramidin 1. katmanı).
class NetSonucSekmesi extends StatefulWidget {
  const NetSonucSekmesi({super.key, required this.v});
  final RaporVerisi v;

  @override
  State<NetSonucSekmesi> createState() => _NetSonucSekmesiState();
}

class _NetSonucSekmesiState extends State<NetSonucSekmesi> {
  late final Future<CiftlikRaporu?> _muhasebe =
      CiftlikRaporu.yukle().then<CiftlikRaporu?>((r) => r).catchError((Object _) => null);
  int _senaryo = 1;

  @override
  Widget build(BuildContext context) => FutureBuilder<CiftlikRaporu?>(
        future: _muhasebe,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final kg = mtKgMaliyetleri(widget.v);
          final h = GelirGiderHavuzu.hesapla(faturalar: widget.v.mali.gelirGider, muhasebe: snap.data, mtKgMaliyet: kg, senaryo: _senaryo);
          final diger = GelirGiderHavuzu.hesapla(
              faturalar: widget.v.mali.gelirGider, muhasebe: snap.data, mtKgMaliyet: kg, senaryo: _senaryo == 1 ? 2 : 1);
          final senaryoVar = snap.data?.senaryo?.ciftlik(kKonsolideMuhasebe) != null;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (senaryoVar)
                Panel(
                  baslik: 'Grup içi aktarımların değerlemesi',
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 1, label: Text('Maliyet bedeli')),
                        ButtonSegment(value: 2, label: Text('Piyasa fiyatı')),
                      ],
                      selected: {_senaryo},
                      onSelectionChanged: (x) => setState(() => _senaryo = x.first),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Maliyet bedeliyle: ${_mn((_senaryo == 1 ? h : diger).toplam().net)} · '
                      'Piyasa fiyatıyla: ${_mn((_senaryo == 2 ? h : diger).toplam().net)} (konsolide, ESK hariç). '
                      'Piyasa fiyatı: çiftlikte üretilip grup içinde kullanılan ürünler dışarı satılsaydı satış fiyatıyla, '
                      'dışarıdan alınsaydı alış fiyatıyla (muhasebe 2. senaryo).',
                      style: const TextStyle(fontSize: 12, color: Renk.soluk, height: 1.4),
                    ),
                  ]),
                ),
              if (!h.muhasebeVar)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: BilgiKutusu(
                      uyari: true,
                      yazi: 'Muhasebe verisi (Çiftlik Raporları) gelmedi; bütün aylar faturalardan tahmin edildi ve '
                          'personel, amortisman gibi faturasız giderler eksik.'),
                ),
              _Ozet(h: h),
              _Kollar(h: h),
              _AyTablosu(h: h),
              if (snap.data != null && !widget.v.suruHareketleri.bos) _Birim(h: h, v: widget.v, r: snap.data!),
              _Tahmin(h: h),
              _Mutabakat(h: h),
              if (h.yatirimlar.isNotEmpty) _Yatirim(h: h),
              if (h.kolUyusmazliklari.isNotEmpty) _KolKontrol(h: h),
              const _Kaynak(),
            ],
          );
        },
      );
}

class _Ozet extends StatelessWidget {
  const _Ozet({required this.h});
  final GelirGiderHavuzu h;

  @override
  Widget build(BuildContext context) {
    final t = h.toplam();
    final kesinAy = h.sonMuhasebeAyi, sonAy = h.sonAy;
    final fark = h.konsolideFark;
    return Panel(
      baslik: 'Konsolide net sonuç (ESK hariç) – Ocak–${_ay(sonAy)} ${h.yil}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (kesinAy > 0) _Satir('Kesin (Ocak–${_ay(kesinAy)}, muhasebe)', _mn(t.kesinNet), renk: _renk(t.kesinNet)),
        if (sonAy > kesinAy)
          _Satir('Tahmin (${kesinAy + 1 == sonAy ? _ay(sonAy) : '${_ay(kesinAy + 1)}–${_ay(sonAy)}'})', _mn(t.tahminNet),
              renk: Renk.amber),
        _Satir('Toplam net sonuç', _mn(t.net), renk: _renk(t.net), kalin: true),
        const Divider(),
        if (fark != null)
          Row(children: [
            Icon(fark.abs() < 1000 ? Icons.check_circle_outline : Icons.error_outline,
                size: 18, color: fark.abs() < 1000 ? Renk.yesil : Renk.kirmizi),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                fark.abs() < 1000
                    ? 'Muhasebe mutabakatı: Ocak–${_ay(kesinAy)} havuz sonucu, muhasebedeki "Çiftliklerimiz (ESK hariç)" '
                        'net kârıyla aynı (${_mn(h.muhasebeKonsolide!)}).'
                    : 'Muhasebe mutabakatı: havuz ile muhasebe konsolide net kârı arasında ${_mn(fark)} fark var.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ]),
        if (h.yatirimToplami > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Yatırım niteliğindeki alımlar (${_mn(h.yatirimToplami)}) net sonuca dahil değildir.',
                style: const TextStyle(fontSize: 12, color: Renk.soluk)),
          ),
      ]),
    );
  }
}

class _Kollar extends StatelessWidget {
  const _Kollar({required this.h});
  final GelirGiderHavuzu h;

  @override
  Widget build(BuildContext context) {
    final z = h.toplam(kol: Kol.ziraat), hv = h.toplam(kol: Kol.hayvancilik), t = h.toplam(), e = h.eskToplam;
    DataRow satir(String ad, HavuzToplam x, {bool kalin = false, bool yalnizNet = false}) {
      final st = TextStyle(fontSize: 12, fontWeight: kalin ? FontWeight.w700 : FontWeight.w400);
      return DataRow(cells: [
        DataCell(Text(ad, style: st)),
        DataCell(Text(yalnizNet ? '—' : _m(x.gelir), style: st)),
        DataCell(Text(yalnizNet ? '—' : _m(x.gider), style: st)),
        DataCell(Text(yalnizNet ? '—' : _m(x.faaliyetDisi), style: st)),
        DataCell(Text(_m(x.net), style: st.copyWith(color: _renk(x.net), fontWeight: FontWeight.w700))),
      ]);
    }

    return Panel(
      baslik: 'Kollara göre (mn ₺)',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 14,
            headingRowHeight: 40,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 36,
            headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Renk.anaKoyu),
            columns: const [
              DataColumn(label: Text('Kol')),
              DataColumn(label: Text('Gelir'), numeric: true),
              DataColumn(label: Text('Gider'), numeric: true),
              DataColumn(label: Text('Faaliyet\ndışı'), numeric: true),
              DataColumn(label: Text('Net'), numeric: true),
            ],
            rows: [
              satir('Ziraat (Tarımsal Alan)', z),
              satir('Hayvancılık', hv),
              satir('Toplam (ESK hariç)', t, kalin: true),
              satir('ESK (ayrı izlenir)', e, yalnizNet: true),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text('Faaliyet dışı: teşvik, finansman ve olağandışı gelir/giderler (yalnızca muhasebe aylarında).',
            style: TextStyle(fontSize: 11, color: Renk.soluk)),
      ]),
    );
  }
}

class _AyTablosu extends StatelessWidget {
  const _AyTablosu({required this.h});
  final GelirGiderHavuzu h;

  @override
  Widget build(BuildContext context) {
    const st = TextStyle(fontSize: 12);
    DataCell hucre(HavuzAy a) {
      if (!a.veriVar) return const DataCell(Text('—', style: st));
      return DataCell(Text('${_m(a.net)}${a.kesin ? '' : ' *'}',
          style: st.copyWith(color: a.kesin ? _renk(a.net) : Renk.amber, fontStyle: a.kesin ? FontStyle.normal : FontStyle.italic)));
    }

    return Panel(
      baslik: 'Çiftlik × ay net sonuç (mn ₺)',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 14,
            headingRowHeight: 40,
            dataRowMinHeight: 30,
            dataRowMaxHeight: 34,
            headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Renk.anaKoyu),
            columns: [
              const DataColumn(label: Text('Ay')),
              for (final c in kHavuzCiftlikleri) DataColumn(label: Text(c), numeric: true),
              const DataColumn(label: Text('Toplam'), numeric: true),
              const DataColumn(label: Text('ESK'), numeric: true),
            ],
            rows: [
              for (var m = 1; m <= h.sonAy; m++)
                DataRow(cells: [
                  DataCell(Text(_ay(m), style: st)),
                  for (final c in kHavuzCiftlikleri) hucre(h.aylar[c]![m - 1]),
                  () {
                    final t = h.toplam(ay: m);
                    final kesin = kHavuzCiftlikleri.every((c) => h.aylar[c]![m - 1].kesin || !h.aylar[c]![m - 1].veriVar);
                    return DataCell(Text('${_m(t.net)}${kesin ? '' : ' *'}',
                        style: st.copyWith(fontWeight: FontWeight.w700, color: kesin ? _renk(t.net) : Renk.amber)));
                  }(),
                  hucre(h.esk[m - 1]),
                ]),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text('* Tahmin: muhasebe bu ayı henüz kapatmadı. Yöntem aşağıda.', style: TextStyle(fontSize: 11, color: Renk.soluk)),
      ]),
    );
  }
}

/// Hayvancılık birim göstergeleri (kesin aylar): sürü, sağmal başına süt, baş başına gider, litre maliyeti.
class _Birim extends StatelessWidget {
  const _Birim({required this.h, required this.v, required this.r});
  final GelirGiderHavuzu h;
  final RaporVerisi v;
  final CiftlikRaporu r;

  @override
  Widget build(BuildContext context) {
    final s = v.suruHareketleri;
    const st = TextStyle(fontSize: 12);
    final satirlar = <DataRow>[];
    for (final (c, sut) in const [('Şekersüt', kSekersut), ('Pan-Gev', kPangev), ('Aslım', null)]) {
      for (final a in h.ciftlikAylari(c)) {
        if (!a.kesin || a.ay < h.sonMuhasebeAyi - 2) continue;
        final tum = s.deger(c, h.yil, a.ay, 'TÜM SÜRÜ'), sagmal = s.deger(c, h.yil, a.ay, 'SAĞMAL');
        final b = sut == null ? null : r.birimAylar(sut).where((x) => x.yil == h.yil && x.ayNo == a.ay).firstOrNull;
        final gun = DateTime(h.yil, a.ay + 1, 0).day;
        String f(double? x, {int o = 0}) => x == null || !x.isFinite ? '—' : sayi(x, ondalik: o);
        satirlar.add(DataRow(cells: [
          DataCell(Text('$c · ${_ay(a.ay)}', style: st)),
          DataCell(Text(f(tum), style: st)),
          DataCell(Text(f(sagmal), style: st)),
          DataCell(Text(b == null || sagmal == null || sagmal == 0 ? '—' : f(b.miktar / sagmal / gun, o: 1), style: st)),
          DataCell(Text(tum == null || tum == 0 ? '—' : f(a.muhGider / tum), style: st)),
          DataCell(Text(b == null || b.miktar == 0 ? '—' : f(b.toplam / b.miktar, o: 2), style: st)),
        ]));
      }
    }
    if (satirlar.isEmpty) return const SizedBox.shrink();
    return Panel(
      baslik: 'Hayvancılık birim göstergeleri (son 3 kesin ay)',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 14,
            headingRowHeight: 44,
            dataRowMinHeight: 30,
            dataRowMaxHeight: 34,
            headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Renk.anaKoyu),
            columns: const [
              DataColumn(label: Text('Çiftlik · ay')),
              DataColumn(label: Text('Tüm\nsürü'), numeric: true),
              DataColumn(label: Text('Sağmal'), numeric: true),
              DataColumn(label: Text('Süt\nL/sağmal/gün'), numeric: true),
              DataColumn(label: Text('Gider\n₺/baş/ay'), numeric: true),
              DataColumn(label: Text('Süt maliyeti\n₺/L'), numeric: true),
            ],
            rows: satirlar,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
            'Hayvan sayıları: Sürü Hareketleri (aylık ortalama). Süt litresi ve süt maliyeti: muhasebe üretim kaydı. '
            'Gider ₺/baş/ay: çiftliğin muhasebe gideri ÷ tüm sürü.',
            style: TextStyle(fontSize: 11, color: Renk.soluk, height: 1.4)),
      ]),
    );
  }
}

class _Tahmin extends StatelessWidget {
  const _Tahmin({required this.h});
  final GelirGiderHavuzu h;

  @override
  Widget build(BuildContext context) {
    final l = <String>[];
    for (final c in [...kHavuzCiftlikleri, kEskFatura]) {
      final aylar = c == kEskFatura ? h.esk : h.aylar[c]!;
      for (final a in aylar) {
        if (a.kesin || !a.veriVar || a.ay > h.sonAy) continue;
        l.add('$c, ${_ay(a.ay)}: ${a.yontem}.'
            '${a.olagandisiGelir > 0 ? ' Tahmine katılmayan fatura geliri: ${_mn(a.olagandisiGelir)}.' : ''}');
      }
    }
    if (l.isEmpty) return const SizedBox.shrink();
    final b = h.tarimBirimMaliyet.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return Panel(
      baslik: 'Tahmin yöntemi',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final x in l) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text('• $x', style: const TextStyle(fontSize: 13, height: 1.4))),
        if (b.isNotEmpty) ...[
          const SizedBox(height: 6),
          const Text('Tarım ürün birim maliyetleri', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          for (final e in b) _Satir(e.key, '${sayi(e.value.$1, ondalik: 2)} ₺/kg (${e.value.$2})'),
        ],
        const SizedBox(height: 4),
        const Text('Faaliyet dışı gelir ve giderler (teşvik, finansman) tahmine katılmaz; muhasebe kapanışında eklenir.',
            style: TextStyle(fontSize: 11, color: Renk.soluk)),
      ]),
    );
  }
}

class _Mutabakat extends StatelessWidget {
  const _Mutabakat({required this.h});
  final GelirGiderHavuzu h;

  @override
  Widget build(BuildContext context) {
    if (h.sonMuhasebeAyi == 0) return const SizedBox.shrink();
    return Panel(
      baslik: 'Muhasebe ile faturaların mutabakatı (Ocak–${_ay(h.sonMuhasebeAyi)})',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final m in h.mutabakat) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Text(m.ciftlik, style: const TextStyle(fontWeight: FontWeight.w700, color: Renk.anaKoyu, fontSize: 13)),
          ),
          _Satir('Gelir: muhasebe / fatura', '${_mn(m.muhSatis)} / ${_mn(m.faturaGelir)}'),
          _Satir('Gider: muhasebe / fatura', '${_mn(m.muhGider)} / ${_mn(m.faturaGider)}'),
          if (m.gelirFarki.abs() >= 1000)
            _Not(m.gelirFarki > 0
                ? 'Muhasebede olup faturası gelir tablosunda bulunmayan gelir ${_mn(m.gelirFarki)} (teşvik, grup içi aktarım ya da düzeltme kaydı)'
                    '${m.faturasizGelirAylari.isEmpty ? '' : '; faturasız gelir olan aylar: ${m.faturasizGelirAylari.map(_ay).join(', ')}'}.'
                : 'Gelir tablosundaki faturaların ${_mn(-m.gelirFarki)} kadarı muhasebede bu dönemde gelir yazılmamış.'),
          if (m.giderFarki.abs() >= 1000)
            _Not(m.giderFarki < 0
                ? 'Faturalanan giderin ${_mn(-m.giderFarki)} kadarı muhasebede henüz gider yazılmadı: stoka, ürün ya da hayvan maliyetine alındı; satış gerçekleştiğinde gider olur.'
                : 'Muhasebe giderinin ${_mn(m.giderFarki)} kadarı faturasız: personel, amortisman ve stoktan kullanım.'),
        ],
      ]),
    );
  }
}

class _Yatirim extends StatelessWidget {
  const _Yatirim({required this.h});
  final GelirGiderHavuzu h;

  @override
  Widget build(BuildContext context) {
    final l = h.yatirimlar.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Panel(
      baslik: 'Yatırımlar – net sonuca dahil değil (${_mn(h.yatirimToplami)})',
      child: Column(children: [for (final e in l) _Satir('${e.key.$1} · ${e.key.$2}', _mn(e.value))]),
    );
  }
}

class _KolKontrol extends StatelessWidget {
  const _KolKontrol({required this.h});
  final GelirGiderHavuzu h;

  @override
  Widget build(BuildContext context) {
    final l = h.kolUyusmazliklari.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Panel(
      baslik: 'Kol kontrolü',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text(
            'Gider türü çiftliğin kolundan farklı olan faturalar. Muhasebe kaydı esas alınır; '
            'tutarın doğru çiftliğe yazıldığı muhasebeyle teyit edilmelidir.',
            style: TextStyle(fontSize: 12, color: Renk.soluk, height: 1.4)),
        const SizedBox(height: 4),
        for (final e in l)
          _Satir('${e.key.$1} (${kolAdi(ciftlikKolu(e.key.$1))}) · ${e.key.$2}', _mn(e.value)),
      ]),
    );
  }
}

class _Kaynak extends StatelessWidget {
  const _Kaynak();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: 4, bottom: 24),
        child: Text(
          'Kesin aylar: 2026 Yılı Çiftlik Raporları › çiftlik gelir tabloları (muhasebe; grup içi aktarımlar maliyet bedeliyle). '
          'Tahmin ayları: aylık gelir satış ve gider tabloları; tarım ürün birim maliyeti muhasebe satılan mamul maliyetinden, '
          'yoksa Maliyet Takip ve Tarımsal Faaliyet\'ten. Yalnızca çiftlik, ay, kalem ve tutar kullanılır; kişi, müşteri ve '
          'tedarikçi bilgisi alınmaz.',
          style: TextStyle(fontSize: 12, color: Renk.soluk, height: 1.4),
        ),
      );
}

class _Not extends StatelessWidget {
  const _Not(this.yazi);
  final String yazi;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(top: 2, bottom: 2), child: Text('• $yazi', style: const TextStyle(fontSize: 12.5, height: 1.4)));
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
