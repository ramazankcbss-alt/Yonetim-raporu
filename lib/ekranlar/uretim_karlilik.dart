import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/veri_servisi.dart';
import '../tema.dart';
import '../veri/model.dart';
import '../veri/urun_takip.dart';
import 'bilesenler.dart';
import 'gonder.dart';

String _tl(double v) => '${v < 0 ? '−' : ''}${sayi(v.abs())} ₺';

/// kg → "7.632,9 ton" (1 tonun altı kg).
String _ton(double kg) => kg.abs() >= 1000 ? '${sayi(kg / 1000, ondalik: 1)} ton' : '${sayi(kg)} kg';

String _gun(String t) {
  final p = t.split('-');
  return p.length == 3 ? '${p[2]}.${p[1]}.${p[0]}' : t;
}

/// Ürün Takibi: her ürün için ekim alanı ve plan (Tarımsal Faaliyet dosyası) ile
/// teslimat / satış hareketleri (TarKop, patates fire listesi, uygulamadan girilen
/// kayıtlar) tek ekranda: ne kadar teslim edildi, ne kadar kesinti düşüldü, nereye
/// satıldı, ne kadar gelir oluştu, maliyete göre net kazanç.
class UretimKarlilikEkran extends StatelessWidget {
  const UretimKarlilikEkran({super.key, required this.veri});

  final RaporVerisi veri;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VeriDeposu.ben,
      builder: (context, _) {
        final v = VeriDeposu.ben.veri ?? veri;
        final t = UrunTakibi(v.tarimsalUretim, v.urunTeslimat);
        final yil = v.tarimsalUretim.yilBasligi;
        final baslik = yil.isEmpty ? 'Ürün Takibi' : '$yil Ürün Takibi';
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(baslik),
              actions: const [TabloGuncelleButonu()],
              bottom: const TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Color(0xCCFFFFFF),
                indicatorColor: Colors.white,
                tabs: [Tab(text: 'Ürünler'), Tab(text: 'Çiftlikler'), Tab(text: 'Teslimatlar')],
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => teslimatFormu(context, t),
              icon: const Icon(Icons.add),
              label: const Text('Teslimat / satış'),
            ),
            body: v.tarimsalUretim.bos && v.urunTeslimat.gunler.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: BilgiKutusu(
                        yazi: "Veri henüz gelmedi. Drive'daki Tarımsal Faaliyet dosyasında 'ÇİFTLİK BAZINDA' "
                            'sayfası olmalı ve Apps Script güncel olmalı.'),
                  )
                : TabBarView(children: [
                    GonderAlani(konu: '$baslik – Ürünler', child: _Urunler(t: t, v: v)),
                    GonderAlani(konu: '$baslik – Çiftlikler', child: _Ciftlikler(t: t, v: v)),
                    GonderAlani(konu: '$baslik – Teslimatlar', child: _Teslimatlar(t: t, v: v)),
                  ]),
          ),
        );
      },
    );
  }
}

class _Urunler extends StatelessWidget {
  const _Urunler({required this.t, required this.v});
  final UrunTakibi t;
  final RaporVerisi v;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          _GenelToplam(t: t, v: v),
          for (final (u, parcalar) in t.urunler) _UrunKarti(d: u, parcalar: parcalar),
          _Kaynak(v: v),
        ],
      );
}

class _Ciftlikler extends StatelessWidget {
  const _Ciftlikler({required this.t, required this.v});
  final UrunTakibi t;
  final RaporVerisi v;

  @override
  Widget build(BuildContext context) {
    final m = <String, List<UrunDurumu>>{};
    for (final d in t.ciftlikSatirlari) {
      m.putIfAbsent(d.ciftlik, () => []).add(d);
    }
    final l = m.entries.toList()
      ..sort((a, b) => b.value.fold<double>(0, (x, d) => x + d.planSatis).compareTo(a.value.fold<double>(0, (x, d) => x + d.planSatis)));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        for (final e in l)
          Panel(
            baslik: e.key,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _Satir('Ekim alanı', '${sayi(e.value.fold<double>(0, (a, d) => a + d.dekar))} da'),
              _Satir('Planlanan satış', _tl(e.value.fold<double>(0, (a, d) => a + d.planSatis))),
              _Satir('Gerçekleşen gelir (teslim edilen)', _tl(e.value.fold<double>(0, (a, d) => a + d.gelir))),
              _Satir('Toplam maliyet', _tl(e.value.fold<double>(0, (a, d) => a + d.maliyet))),
              const Divider(height: 20),
              VeriTablosu(
                ilkSutunGenislik: 120,
                basliklar: const ['Ürün', 'Alan (da)', 'Plan tonaj', 'Teslim (net)', '%', 'Gelir', 'Maliyet', 'Plan net'],
                satirlar: [
                  for (final d in e.value..sort((a, b) => b.planSatis.compareTo(a.planSatis)))
                    [
                      d.urun,
                      sayi(d.dekar),
                      _ton(d.planVerim),
                      d.teslimatVar ? _ton(d.net) : '—',
                      d.ilerleme == null || !d.teslimatVar ? '—' : '%${sayi(d.ilerleme, ondalik: 1)}',
                      d.teslimatVar ? _tl(d.gelir) : '—',
                      _tl(d.maliyet),
                      _tl(d.planNet),
                    ],
                ],
              ),
            ]),
          ),
        _Kaynak(v: v),
      ],
    );
  }
}

class _GenelToplam extends StatelessWidget {
  const _GenelToplam({required this.t, required this.v});
  final UrunTakibi t;
  final RaporVerisi v;

  @override
  Widget build(BuildContext context) {
    final g = t.genelToplam();
    final u = v.tarimsalUretim;
    return Panel(
      baslik: 'Genel toplam',
      child: Column(children: [
        _Satir('Ekim alanı', '${sayi(g.dekar)} da'),
        _Satir('Planlanan satış', _tl(g.planSatis)),
        _Satir('Toplam maliyet', _tl(g.maliyet)),
        _Satir('Planlanan net kazanç', _tl(g.planNet), renk: g.planNet >= 0 ? Renk.yesil : Renk.kirmizi, kalin: true),
        if (u.ekGelirler.isNotEmpty) ...[
          for (final e in u.ekGelirler) _Satir('+ ${_basHarf(e.$1)}', _tl(e.$2)),
          _Satir('Planlanan toplam kazanç', _tl(g.planNet + u.ekGelirToplami), renk: Renk.yesil, kalin: true),
        ],
        const Divider(),
        _Satir('Teslim edilen (net)', g.teslimatVar ? _ton(g.net) : '—'),
        _Satir('Şu ana kadarki satış geliri', g.teslimatVar ? _tl(g.gelir) : '—', kalin: true),
        _Satir('Kalan beklenen gelir', _tl(g.beklenenGelir - g.gelir)),
      ]),
    );
  }
}

String _basHarf(String s) {
  final k = s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  return k.isEmpty ? k : '${k[0].toUpperCase()}${k.substring(1)}';
}

class _UrunKarti extends StatelessWidget {
  const _UrunKarti({required this.d, required this.parcalar});
  final UrunDurumu d;
  final List<UrunDurumu> parcalar;

  @override
  Widget build(BuildContext context) {
    final durum = !d.teslimatVar
        ? ('Teslimat yok', Renk.soluk, Renk.zemin)
        : (d.kalan <= 0 || (d.ilerleme ?? 0) >= 98)
            ? ('Tamamlandı', Renk.yesil, Renk.yesilAcik)
            : ('Devam ediyor', Renk.mavi, Renk.maviAcik);
    final planKar = d.planNet >= 0;
    return Panel(
      baslik: d.urun,
      eylem: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: durum.$3, borderRadius: BorderRadius.circular(20)),
        child: Text(durum.$1, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: durum.$2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _Baslik('Ekim ve plan'),
        _Satir('Ekim alanı', '${sayi(d.dekar)} da'
            '${parcalar.length > 1 ? ' (${parcalar.map((p) => '${p.ciftlik} ${sayi(p.dekar)}').join(', ')})' : parcalar.isNotEmpty ? ' · ${parcalar.first.ciftlik}' : ''}'),
        if (d.cesitler.isNotEmpty) _Satir('Çeşit', d.cesitler.join(', ')),
        _Satir('Beklenen verim', d.dekar > 0 ? '${sayi(d.planVerim / d.dekar)} kg/da · ${_ton(d.planVerim)}' : _ton(d.planVerim)),
        _Satir('Planlanan satış', '${_tl(d.planSatis)}${d.planFiyat > 0 ? ' (${sayi(d.planFiyat, ondalik: 2)} ₺/kg)' : ''}'),
        _Satir('Toplam maliyet', '${_tl(d.maliyet)}${d.dekar > 0 ? ' (${sayi(d.maliyet / d.dekar)} ₺/da)' : ''}'),
        _Satir('Planlanan net kazanç', _tl(d.planNet), renk: planKar ? Renk.yesil : Renk.kirmizi),
        const SizedBox(height: 8),
        const _Baslik('Teslimat ve satış'),
        if (!d.teslimatVar)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
                'Henüz teslimat / satış kaydı yok. Sağ alttaki "Teslimat / satış" düğmesiyle girin '
                'ya da kaynak dosya Drive\'a eklendiğinde otomatik gelir.',
                style: TextStyle(fontSize: 13, color: Renk.soluk, height: 1.4)),
          )
        else ...[
          if (d.alicilar.isNotEmpty) _Satir('Satıldığı yer', d.alicilar.join(', ')),
          _Satir('Dönem', '${_gun(d.ilkTarih!)} – ${_gun(d.sonTarih!)} · ${sayi(d.sefer.toDouble())} sefer'),
          _Satir('Teslim edilen (kesinti öncesi)', _ton(d.teslim)),
          if (d.kesinti > 0)
            _Satir('Düşülen fire / kesinti', '${_ton(d.kesinti)} (%${sayi(d.kesintiOrani, ondalik: 1)})', renk: Renk.turuncu),
          _Satir('Bedele esas (net)', _ton(d.net), kalin: true),
          if (d.kantar > 0) _Satir('Çiftlik kantarı', '${_ton(d.kantar)} (fark ${_ton(d.teslim - d.kantar)})'),
          if (d.polar != null) _Satir('Ortalama polar', '%${sayi(d.polar, ondalik: 2)}'),
          if (d.ilerleme != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                LinearProgressIndicator(
                  value: (d.ilerleme! / 100).clamp(0.0, 1.0),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                  color: Renk.ana,
                  backgroundColor: Renk.anaAcik,
                ),
                const SizedBox(height: 4),
                Text('Planlanan tonajın %${sayi(d.ilerleme, ondalik: 1)}\'i teslim edildi'
                    '${d.kalan > 0 ? ' · kalan ${_ton(d.kalan)}' : ''}',
                    style: const TextStyle(fontSize: 12, color: Renk.soluk)),
              ]),
            ),
          if (d.gercekDekaraVerim != null) _Satir('Gerçekleşen dekara verim', '${sayi(d.gercekDekaraVerim)} kg/da'),
          if (d.ekGelir > 0) _Satir('Nakliye vb. ek gelir', _tl(d.ekGelir)),
          _Satir('Satış geliri${d.fiyatTahmini ? ' (plan fiyatıyla)' : ''}', _tl(d.gelir), kalin: true),
          const Divider(),
          _Satir('Net kazanç (gelir − maliyet)', _tl(d.gerceklesenNet),
              renk: d.gerceklesenNet >= 0 ? Renk.yesil : Renk.kirmizi, kalin: true),
          if (d.kalan > 0)
            _Satir('Kalan teslim edilirse beklenen net', _tl(d.beklenenGelir - d.maliyet),
                renk: d.beklenenGelir - d.maliyet >= 0 ? Renk.yesil : Renk.kirmizi),
          if (d.fiyatTahmini)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                  'Kaynak dosyada birim fiyat olmadığı için gelir, planlanan birim fiyatla hesaplandı. '
                  'Kesin fiyat belli olunca uygulamadan girilebilir.',
                  style: TextStyle(fontSize: 12, color: Renk.soluk, height: 1.4)),
            ),
        ],
      ]),
    );
  }
}

class _Teslimatlar extends StatelessWidget {
  const _Teslimatlar({required this.t, required this.v});
  final UrunTakibi t;
  final RaporVerisi v;

  @override
  Widget build(BuildContext context) {
    final gruplar = t.ciftlikSatirlari.where((d) => d.teslimatVar).toList()
      ..sort((a, b) => b.sonTarih!.compareTo(a.sonTarih!));
    final elle = [...v.urunTeslimat.elle]..sort((a, b) => b.tarih.compareTo(a.tarih));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        if (gruplar.isEmpty)
          const BilgiKutusu(yazi: 'Henüz teslimat kaydı yok.'),
        for (final d in gruplar)
          Panel(
            baslik: '${d.urun} · ${d.ciftlik}',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('${d.alicilar.join(', ')}${d.alicilar.isEmpty ? '' : ' · '}Kaynak: ${d.kaynaklar.join(', ')}',
                  style: const TextStyle(fontSize: 12, color: Renk.soluk)),
              const SizedBox(height: 6),
              VeriTablosu(
                ilkSutunGenislik: 92,
                basliklar: [
                  'Tarih', 'Sefer', 'Teslim', 'Kesinti', 'Net',
                  if (d.polar != null) 'Polar %',
                  'Gelir',
                ],
                satirlar: [
                  for (final g in d.gunler)
                    [
                      _gun(g.tarih),
                      sayi(g.sefer.toDouble()),
                      _ton(g.teslim),
                      g.kesinti > 0 ? '${_ton(g.kesinti)} (%${sayi(g.teslim > 0 ? g.kesinti / g.teslim * 100 : 0, ondalik: 1)})' : '—',
                      _ton(g.net),
                      if (d.polar != null) g.polar == null ? '—' : sayi(g.polar, ondalik: 2),
                      _tl((g.fiyat != null ? g.tutar : g.net * d.planFiyat) + g.ekGelir),
                    ],
                  [
                    'Toplam',
                    sayi(d.sefer.toDouble()),
                    _ton(d.teslim),
                    d.kesinti > 0 ? '${_ton(d.kesinti)} (%${sayi(d.kesintiOrani, ondalik: 1)})' : '—',
                    _ton(d.net),
                    if (d.polar != null) sayi(d.polar, ondalik: 2),
                    _tl(d.gelir),
                  ],
                ],
                vurguluSonSatir: true,
              ),
            ]),
          ),
        if (elle.isNotEmpty)
          Panel(
            baslik: 'Uygulamadan girilen kayıtlar',
            child: Column(children: [
              for (final e in elle)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text('${_gun(e.tarih)} · ${e.urun} · ${e.ciftlik}'),
                  subtitle: Text([
                    'Net ${_ton(e.net)}',
                    if (e.kesinti > 0) 'kesinti ${_ton(e.kesinti)}',
                    if (e.alici.isNotEmpty) e.alici,
                    if (e.fiyat != null) '${sayi(e.fiyat, ondalik: 2)} ₺/kg',
                    if (e.aciklama.isNotEmpty) e.aciklama,
                  ].join(' · ')),
                  trailing: IconButton(
                    tooltip: 'Sil',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _sil(context, e),
                  ),
                ),
            ]),
          ),
        _Kaynak(v: v),
      ],
    );
  }

  Future<void> _sil(BuildContext context, ElleTeslimat e) async {
    final evet = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Kayıt silinsin mi?'),
        content: Text('${_gun(e.tarih)} · ${e.urun} · ${e.ciftlik} · net ${_ton(e.net)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sil')),
        ],
      ),
    );
    if (evet != true || !context.mounted) return;
    final mesaj = ScaffoldMessenger.of(context);
    try {
      mesaj.showSnackBar(SnackBar(content: Text(await VeriDeposu.ben.teslimatSil(e.satir))));
    } catch (h) {
      mesaj.showSnackBar(SnackBar(content: Text('$h')));
    }
  }
}

/// Elle teslimat / satış girişi. Kişi adı yazılmaz; alıcı alanına firma ya da depo adı girilir.
Future<void> teslimatFormu(BuildContext context, UrunTakibi t) async {
  final ciftlikler = t.ciftlikler.isEmpty ? ['Şekersüt', 'Aslım', 'Taşağıl', 'Fidanlık'] : t.ciftlikler;
  final urunler = t.urunAdlari.isEmpty ? ['Şeker Pancarı', 'Buğday', 'Arpa', 'Yonca', 'Patates', 'Silajlık Mısır'] : t.urunAdlari;
  var tarih = DateTime.now();
  var ciftlik = ciftlikler.first, urun = urunler.first;
  final teslim = TextEditingController(), kesinti = TextEditingController(), fiyat = TextEditingController(),
      alici = TextEditingController(), aciklama = TextEditingController();
  double? n(TextEditingController c) => sayiOku(c.text.trim().replaceAll(' ', ''));
  final kaydet = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, yenile) => AlertDialog(
        title: const Text('Teslimat / satış girişi'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text('Tarih: ${tarih.day.toString().padLeft(2, '0')}.${tarih.month.toString().padLeft(2, '0')}.${tarih.year}'),
              onPressed: () async {
                final g = await showDatePicker(
                    context: c, initialDate: tarih, firstDate: DateTime(2024), lastDate: DateTime.now());
                if (g != null) yenile(() => tarih = g);
              },
            ),
            DropdownButtonFormField<String>(
              initialValue: ciftlik,
              decoration: const InputDecoration(labelText: 'Çiftlik'),
              items: [for (final x in ciftlikler) DropdownMenuItem(value: x, child: Text(x))],
              onChanged: (x) => yenile(() => ciftlik = x ?? ciftlik),
            ),
            DropdownButtonFormField<String>(
              initialValue: urun,
              decoration: const InputDecoration(labelText: 'Ürün'),
              items: [for (final x in urunler) DropdownMenuItem(value: x, child: Text(x))],
              onChanged: (x) => yenile(() => urun = x ?? urun),
            ),
            TextField(controller: teslim, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Teslim edilen miktar (kg)')),
            TextField(controller: kesinti, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Fire / kesinti (kg)', hintText: 'yoksa boş bırakın')),
            TextField(controller: fiyat, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Birim fiyat (₺/kg)', hintText: 'belli değilse boş bırakın')),
            TextField(controller: alici,
                decoration: const InputDecoration(labelText: 'Satıldığı yer / depo', hintText: 'firma veya depo adı (kişi adı yazmayın)')),
            TextField(controller: aciklama, decoration: const InputDecoration(labelText: 'Açıklama (isteğe bağlı)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Kaydet')),
        ],
      ),
    ),
  );
  if (kaydet != true || !context.mounted) return;
  final mesaj = ScaffoldMessenger.of(context);
  final m = n(teslim);
  if (m == null || m <= 0) {
    mesaj.showSnackBar(const SnackBar(content: Text('Teslim edilen miktarı kg olarak girin.')));
    return;
  }
  try {
    final s = await VeriDeposu.ben.teslimatKaydet(
      tarih: tarih, ciftlik: ciftlik, urun: urun, teslim: m, kesinti: n(kesinti) ?? 0,
      fiyat: n(fiyat), alici: alici.text.trim(), aciklama: aciklama.text.trim(),
    );
    mesaj.showSnackBar(SnackBar(content: Text(s)));
  } catch (h) {
    mesaj.showSnackBar(SnackBar(content: Text('$h')));
  }
}

class _Baslik extends StatelessWidget {
  const _Baslik(this.yazi);
  final String yazi;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(yazi, style: const TextStyle(fontWeight: FontWeight.w700, color: Renk.anaKoyu, fontSize: 13)),
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
                style: TextStyle(
                    color: renk ?? Renk.yazi, fontSize: 14, fontWeight: kalin ? FontWeight.w700 : FontWeight.w500)),
          ),
        ]),
      );
}

class _Kaynak extends StatelessWidget {
  const _Kaynak({required this.v});
  final RaporVerisi v;

  @override
  Widget build(BuildContext context) {
    final u = v.tarimsalUretim, ts = v.urunTeslimat;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      child: Text(
        [
          'Plan: ${u.dosya.isEmpty ? 'Tarımsal Faaliyet dosyası' : u.dosya} › ÇİFTLİK BAZINDA (ekim alanı, beklenen verim, fiyat, maliyet).',
          if (ts.kaynaklar.isNotEmpty)
            'Teslimatlar: ${ts.kaynaklar.map((k) => '${k.ad}${k.satir > 0 ? ' (${k.satir} kayıt${k.guncelleme.isEmpty ? '' : ', ${k.guncelleme}'})' : ''}').join('; ')}.',
          if (ts.okunma.isNotEmpty) 'Son okuma: ${ts.okunma}.',
          if (ts.hatalar.isNotEmpty) 'Okunamayan kaynak: ${ts.hatalar.join('; ')}',
          'Ormanlık, Taşağıl çiftliğine dahil gösterilir. Plaka, satıcı numarası ve kişi bilgisi uygulamaya alınmaz.',
        ].join('\n'),
        style: const TextStyle(fontSize: 12, color: Renk.soluk, height: 1.4),
      ),
    );
  }
}
