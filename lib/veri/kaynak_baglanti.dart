// Kaynak tablolarının piramide bağlanması: ayrı okuyucusu olmayan sayfalardaki bilgiler (Apps Script ›
// kaynakTablolari_) burada çözülür ve Yönetim Özeti, karne ve Veri Kalitesi'nde kullanılır.
//  • Değerlendirme Raporu: karar bekleyen konular, tasarruf çalışmaları, yatırımlar, öneriler, gündem.
//  • Sürü hareketleri › ÖZET: yıllık aylık toplam sürü ↔ çiftlik sayfalarının toplamı.
//  • Patates › fatura edilecek miktar ↔ muhasebe satış faturaları.
//  • Ekim planı aylık raporları: aydan aya plan değişiklikleri.
//  • ESK çalışma › kesim-sakatat-bakım-nakliye: sözleşme fiyatları (bakım ₺/baş/gün).
// KVKK: yalnızca konu, çiftlik, ürün ve tutar; kişi bilgisi yoktur (kaynak tabloları sunucuda maskelenir).

import 'gelir_gider.dart';
import 'kaynak_envanteri.dart';
import 'model.dart' show sayiOku;
import 'stok_suru.dart';

String _ust(String s) => s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase().trim();
const _aylar = ['OCAK', 'ŞUBAT', 'MART', 'NİSAN', 'MAYIS', 'HAZİRAN', 'TEMMUZ', 'AĞUSTOS', 'EYLÜL', 'EKİM', 'KASIM', 'ARALIK'];

Iterable<KaynakTablo> _sayfa(KaynakTablolari kt, String menu, bool Function(String) f) =>
    kt.menu(menu).where((t) => f(_ust(t.sayfa)));

/// Değerlendirme Raporu'ndaki metin bölümleri: (başlık, maddeler).
List<(String, List<String>)> yonetimGundemi(KaynakTablolari kt) {
  final out = <(String, List<String>)>[];
  void ekle(String baslik, List<String> l) {
    final t = [for (final x in l) if (x.trim().length > 3) x.trim()];
    if (t.isNotEmpty) out.add((baslik, t));
  }

  for (final t in kt.menu('gecmis')) {
    if (!t.grup.startsWith('Değerlendirme')) continue;
    final s = _ust(t.sayfa);
    final satirlar = [for (final b in t.bloklar) ...b];
    if (s.startsWith('ÇÖZÜM BEKLEYEN')) {
      ekle('Acil çözüm ve karar bekleyen konular',
          [for (final r in satirlar) if (r.length > 1 && RegExp(r'^\d+$').hasMatch(r.first.trim())) r.sublist(1).join(' ')]);
    } else if (s.startsWith('TASARRUF')) {
      var baslik = 'Tasarruf çalışmaları';
      var l = <String>[];
      for (final r in satirlar) {
        final m = r.join(' ').trim();
        if (m.isEmpty) continue;
        if (m == _ust(m) && m.contains('TASARRUF')) {
          ekle(baslik, l);
          baslik = m.contains('TARIM') ? 'Tasarruf çalışmaları – tarım' : 'Tasarruf çalışmaları – hayvancılık';
          l = [];
        } else {
          l.add(m.replaceFirst(RegExp(r'^\d+\s*[.)]?\s*'), ''));
        }
      }
      ekle(baslik, l);
    } else if (s.startsWith('YATIRIM')) {
      final devam = <String>[], plan = <String>[];
      var cf = '';
      for (final r in satirlar) {
        if (r.isNotEmpty && _ust(r.first) == 'ÇİFTLİK') continue;
        if (r.isNotEmpty && r.first.trim().isNotEmpty) cf = r.first.trim();
        final ek = cf.isEmpty ? '' : '$cf: ';
        if (r.length > 1 && r[1].trim().isNotEmpty) devam.add('$ek${r[1].trim()}');
        if (r.length > 2 && r[2].trim().isNotEmpty) plan.add('$ek${r[2].trim()}');
      }
      ekle('Devam eden ve tamamlanan yatırımlar', devam);
      ekle('Planlanan yatırımlar', plan);
    } else if (s.startsWith('ÖNERİLER') || s.startsWith('GÜNDEM')) {
      ekle(s.startsWith('ÖNERİLER') ? 'Öneriler' : 'Değerlendirme toplantısı gündemi',
          [for (final r in satirlar) r.where((x) => x.trim().isNotEmpty && !RegExp(r'^\d+$').hasMatch(x.trim())).join(' – ')]
              .where((x) => _ust(x) != 'ÖNERİLER' && _ust(x) != 'GÜNDEM')
              .toList());
    }
  }
  return out;
}

class KaynakFarki {
  const KaynakFarki(this.baslik, this.aciklama, this.sorumlu);
  final String baslik, aciklama, sorumlu;
}

String _s(double v, [int o = 0]) {
  final t = v.abs().toStringAsFixed(o).split('.');
  final g = t[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return '${v < 0 ? '−' : ''}$g${t.length > 1 ? ',${t[1]}' : ''}';
}

/// Sürü hareketleri › ÖZET: "20xx TÜM SÜRÜ" ay değerleri ↔ çiftlik sayfalarının toplamı.
List<KaynakFarki> suruOzetMutabakat(KaynakTablolari kt, SuruHareketleri suru) {
  final out = <KaynakFarki>[];
  for (final t in _sayfa(kt, 'stokSuru', (s) => s == 'ÖZET')) {
    for (final b in t.bloklar) {
      if (b.isEmpty) continue;
      final h = b.first.map(_ust).toList();
      for (final r in b.skip(1)) {
        final m = RegExp(r'^(20\d\d)\s*TÜM SÜRÜ').firstMatch(_ust(r.first));
        if (m == null) continue;
        final y = int.parse(m[1]!);
        final fark = <String>[];
        for (var a = 0; a < 12; a++) {
          final j = h.indexOf(_aylar[a]);
          if (j < 0 || j >= r.length) continue;
          final oz = sayiOku(r[j]);
          if (oz == null) continue;
          double? top;
          for (final c in suru.ciftlikler) {
            final v = suru.deger(c, y, a + 1, 'TÜM SÜRÜ');
            if (v != null) top = (top ?? 0) + v;
          }
          if (top != null && (top - oz).abs() > 0.5) fark.add('${_aylar[a][0]}${_aylar[a].substring(1).toLowerCase()}: özet ${_s(oz)}, çiftlik sayfaları ${_s(top)}');
        }
        if (fark.isNotEmpty) {
          out.add(KaynakFarki('Sürü hareketleri › ÖZET $y toplamı çiftlik sayfalarıyla farklı', '${fark.join('; ')}.', 'Sürü kayıt sorumlusu'));
        }
      }
    }
  }
  return out;
}

/// Patates › "fatura edilecek miktar" ↔ muhasebe satış faturaları (Patates, KG).
List<KaynakFarki> patatesFaturaMutabakat(KaynakTablolari kt, GelirGider gg, int yil) {
  final out = <KaynakFarki>[];
  for (final t in _sayfa(kt, 'urun', (s) => s.startsWith('FATURA EDİLECEK'))) {
    for (final b in t.bloklar) {
      for (final r in b) {
        if (r.isEmpty || !_ust(r.first).contains('PATATES') || _ust(r.first).contains('NAKLİYE')) continue;
        final kg = r.length > 1 ? sayiOku(r[1]) : null, tl = r.length > 3 ? sayiOku(r[3]) : null;
        if (kg == null) continue;
        final f = gg.gelir.where((x) => x.yil == yil && x.urun == 'Patates' && _ust(x.birim) == 'KG');
        final fkg = f.fold(0.0, (a, x) => a + x.miktar), ftl = f.fold(0.0, (a, x) => a + x.net);
        if ((fkg - kg).abs() > 1) {
          out.add(KaynakFarki(
              'Patates: fatura edilecek miktar ile kesilen faturalar farklı ($yil)',
              'Patates fire listesinde fatura edilecek ${_s(kg)} kg${tl == null ? '' : ' (${_s(tl)} ₺)'}; muhasebe satış faturalarında '
                  '${_s(fkg)} kg (${_s(ftl)} ₺, KDV hariç). Fark ${_s(kg - fkg)} kg.',
              'Muhasebe / ürün satış sorumlusu'));
        }
      }
    }
  }
  return out;
}

/// Ekim planı aylık raporları: plan tablosunun (çiftlik × ürün dekar) bir önceki aya göre değişen hücreleri.
List<KaynakFarki> ekimPlaniDegisimleri(KaynakTablolari kt) {
  Map<String, double> tablo(KaynakTablo t) {
    final m = <String, double>{};
    for (final b in t.bloklar) {
      var h = <String>[];
      for (final r in b) {
        if (r.any((x) => _ust(x).contains('TOPLAM DEKAR'))) {
          h = r;
          continue;
        }
        if (h.isEmpty || r.isEmpty || _ust(r.first).contains('TOPLAM')) continue;
        for (var j = 1; j < r.length && j < h.length; j++) {
          final v = sayiOku(r[j]);
          if (v != null && h[j].trim().isNotEmpty && !_ust(h[j]).contains('TOPLAM')) m['${r.first.trim()} · ${h[j].trim()}'] = v;
        }
      }
      if (m.isNotEmpty) return m;
    }
    return m;
  }

  final aylar = [
    for (final t in _sayfa(kt, 'ziraat', (s) => _aylar.contains(s)))
      if (t.grup.startsWith('Ekim planı')) (_aylar.indexOf(_ust(t.sayfa)), tablo(t)),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  final out = <KaynakFarki>[];
  for (var i = 1; i < aylar.length; i++) {
    final a = aylar[i - 1], b = aylar[i];
    if (a.$2.isEmpty || b.$2.isEmpty) continue;
    final d = <String>[];
    for (final k in {...a.$2.keys, ...b.$2.keys}) {
      final x = a.$2[k] ?? 0, y = b.$2[k] ?? 0;
      if ((x - y).abs() >= 1) d.add('$k ${_s(x)} → ${_s(y)} da');
    }
    if (d.isNotEmpty) {
      final ad = _aylar[b.$1][0] + _aylar[b.$1].substring(1).toLowerCase();
      out.add(KaynakFarki('Ekim planı $ad raporunda değişti', '${d.join('; ')}.', 'Bilgi (tarım planlama)'));
    }
  }
  return out;
}

/// ESK sözleşme fiyatları (kesim-sakatat-bakım-nakliye): {Kesim, Sakatat, Deri, Bakım, Nakliye} → güncel fiyat.
Map<String, double> eskSozlesmeFiyatlari(KaynakTablolari kt) {
  final m = <String, double>{};
  for (final t in _sayfa(kt, 'esk', (s) => s.startsWith('KESİM-SAKATAT'))) {
    for (final b in t.bloklar) {
      var yeni = -1, eski = -1;
      for (final r in b) {
        final u = r.map(_ust).toList();
        if (u.contains('ESKİ FİYAT')) {
          eski = u.indexOf('ESKİ FİYAT');
          yeni = u.indexWhere((x) => x.startsWith('YENİ FİYAT'));
          continue;
        }
        if (eski < 0 || r.isEmpty) continue;
        final ad = r.first.trim();
        if (!RegExp(r'^(Kesim|Sakatat|Deri|Bakım|Nakliye)', caseSensitive: false).hasMatch(ad)) continue;
        double? sayi(int j) {
          if (j < 0 || j >= r.length) return null;
          final x = RegExp(r'-?\d[\d.,]*').firstMatch(r[j]);
          return x == null ? null : sayiOku(x[0]);
        }

        final v = sayi(yeni) ?? sayi(eski);
        if (v != null) m[ad] = v;
      }
    }
  }
  return m;
}
