#!/usr/bin/env python3
"""Çiftlikler Rapor 2026 verisini üretir.

Kaynak: Drive'daki "2026 Yılı Çiftlik Raporları (7).xlsx" dosyasının Drive
connector'ından alınan metin çıktısı (read_file_content → fileContent). Dosya
22 MB olduğundan metin çıktısı ~1 MB ile sınırlıdır; gelir tabloları, satış
özeti ve satılan mamul maliyeti (SMM) detayı bu kısımda tam olarak yer alır.

Kullanım:
    python3 araclar/ciftlik_rapor/uret.py <metin_ciktisi.txt|.json> assets/veri/ciftlik_rapor_2026.json

KVKK: Çıktıda yalnızca çiftlik bazında toplam tutarlar, miktarlar ve birim
maliyetler yer alır. Alıcı adları, kişi adları ve hayvan küpe numaraları
aktarılmaz.
"""
import csv
import io
import json
import re
import sys
from collections import defaultdict

M = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık']
HARF = r'[A-Za-zÇĞİÖŞÜçğıöşü]'


def sayi(x):
    x = (x or '').strip().replace(',', '')
    if x in ('', '-'):
        return 0.0
    try:
        return float(x)
    except ValueError:
        return None


def oku(yol):
    s = open(yol, encoding='utf-8').read()
    if s.lstrip().startswith('{'):
        s = json.loads(s)['fileContent']
    return s


# ---------------------------------------------------------------- gelir tabloları
def gelir_tablolari(s):
    bas = [m.start() for m in re.finditer(r' ?(Çiftlikler Konsolide|16\d\d - [^,]+?) ,2026 FİİLİ', s)]
    son = bas[1:] + [s.find('Satış Özet')]
    sayfalar = {}
    for a, b in zip(bas, son):
        seg = s[a:b].strip()
        ad = seg.split(',')[0].strip()
        hucreler = next(csv.reader(io.StringIO(seg)))
        satirlar = [[]]
        for t in hucreler:
            m = re.match(r'^\s*(-?[\d.,]*%?)\s+(.*' + HARF + '.*)$', t)
            if m and satirlar[-1] and not re.match(r'^\s*-?[\d.,]+%?\s*$', t):
                satirlar[-1].append(m.group(1))
                satirlar.append([m.group(2).strip()])
            else:
                satirlar[-1].append(t)
        res = {}
        genis = any(len(r) >= 81 for r in satirlar)
        for r in satirlar:
            if 'BRÜT SATIŞLAR' in ' '.join(r[:3]):
                i = [k for k, c in enumerate(r) if 'BRÜT SATIŞLAR' in c][0]
                r = ['A- 60-BRÜT SATIŞLAR'] + r[i + 1:]
            if genis and len(r) >= 81:
                y = {'26': [sayi(r[1 + 2 * i]) for i in range(12)], '25': [sayi(r[28 + 2 * i]) for i in range(12)],
                     '24': [sayi(r[55 + 2 * i]) for i in range(12)]}
            elif not genis and len(r) >= 30:
                y = {'26': [sayi(r[1 + i]) for i in range(12)], '25': [sayi(r[16 + i]) for i in range(12)], '24': [0] * 12}
            else:
                continue
            res[r[0]] = y
        sayfalar[ad] = res
    return sayfalar


# ---------------------------------------------------------------- satış ve SMM tabloları
def satir_tablosu(seg):
    parcalar = re.split(r'(?:(?<=,)|(?<=^)) (?=16\d\d,20\d\d,)', seg)
    out = []
    for p in parcalar[1:]:
        r = next(csv.reader(io.StringIO(p.strip())))
        out.append(r)
    return out


CIFTLIKLER = [('Çiftlikler Konsolide', 'Konsolide (tüm çiftlikler)', 'Toplam'), ('1613 - Şekersüt', 'Şekersüt', 'Süt'),
              ('1614 - Pan-Gev', 'Pan-Gev', 'Süt'), ('1611 - Tarımsal Alan', 'Tarımsal Alan', 'Tarım'),
              ('1605 - Aslım', 'Aslım', 'Et / Besi'), ('1604 - Taşağıl', 'ESK-Taşağıl (Besi hizmeti)', 'ESK (ayrı)')]
KALEMLER = [('Brüt satışlar', 'A- 60-BRÜT SATIŞLAR'), ('Net satışlar', 'NET SATIŞLAR'),
            ('Satışların maliyeti', 'C- 62-SATIŞLARIN MALİYETİ (-)'), ('Brüt satış kârı/zararı', 'BRÜT SATIŞ KÂRI VEYA ZARARI'),
            ('Faaliyet giderleri', 'D- 63-FAALİYET GİDERLERİ (-)'),
            ('Diğer olağan gelirler (649)', 'E- 64-DİĞER FAALİYETLERDEN OLAĞAN GELİR VE KÂRLAR'),
            ('Diğer olağan giderler', 'F- 65-DİĞ.FAALİYETLERDEN OL.GİDER VE ZARARLAR (-)'),
            ('Finansman giderleri', 'G- 66-FİNANSMAN GİDERLERİ (-)'), ('Olağandışı gelirler (679)', 'H- 67-OLAĞANDIŞI GELİR VE KÂRLAR'),
            ('Olağandışı giderler', 'I- 68-OLAĞANDIŞI GİDER VE ZARARLAR (-)'), ('Amortisman', 'AMORTİSMAN'),
            ('FAVÖK (EBITDA)', 'EBITDA'), ('Dönem net kârı/zararı', 'DÖNEM NET KÂRI VEYA ZARARI ( DÖNEM KARI VEYA ZARARI-J)')]
BIRIM_URUN = {'1613': 'Süt – Şekersüt', '1614': 'Süt – Pan-Gev', '1604': 'ESK besi hizmeti'}
BILESEN = ['Hammadde (yem)', 'Direkt işçilik', 'Enerji', 'Bakım onarım', 'Endirekt işçilik', 'Genel üretim', 'Amortisman']
TARIM_AD = {'BUĞDAY': 'Buğday', 'PANCAR(TARLA)': 'Şeker pancarı', 'YONCA BALYASI': 'Yonca balyası', 'TRİTİKALE(TARLA)': 'Tritikale',
            'PATATES': 'Patates', 'MISIR SILAJI': 'Mısır silajı', 'SAP BALYASI': 'Sap balyası', 'ESK SAP BALYASI': 'Sap balyası (ESK’ya)',
            'AİDA TEMİZ ARPA TOHUMU KG': 'Arpa tohumu (Aida)', 'TOHUM ARPA CERVOİSE': 'Arpa tohumu (Cervoise)', 'TOHUM BUĞDAY': 'Buğday tohumu'}
TARIM_CIFTLIK = {'1604': 'ESK-Taşağıl', '1605': 'Aslım', '1611': 'Tarımsal Alan'}


def uret(s):
    g = gelir_tablolari(s)
    top = lambda a, n=12: round(sum((x or 0) for x in a[:n]))

    gelir, aylik = [], []
    for sayfa, ad, bolum in CIFTLIKLER:
        for lab, key in KALEMLER:
            v = g[sayfa][key]
            gelir.append(dict(ciftlik=ad, bolum=bolum, kalem=lab, y2026_9ay=top(v['26'], 9), y2025_9ay=top(v['25'], 9),
                              y2025_yil=top(v['25']), y2024_yil=top(v['24'])))
        for i in range(9):
            aylik.append(dict(ciftlik=ad, ay=M[i], ay_no=i + 1, net_kar=round(g[sayfa][KALEMLER[-1][1]]['26'][i] or 0),
                              brut_kar=round(g[sayfa][KALEMLER[3][1]]['26'][i] or 0)))
    for lab, key in KALEMLER:  # Çiftliklerimiz = Konsolide – Taşağıl (ESK)
        a, b = g['Çiftlikler Konsolide'][key], g['1604 - Taşağıl'][key]
        d = {y: [(x or 0) - (z or 0) for x, z in zip(a[y], b[y])] for y in a}
        gelir.append(dict(ciftlik='Çiftliklerimiz (ESK hariç)', bolum='Toplam', kalem=lab, y2026_9ay=top(d['26'], 9),
                          y2025_9ay=top(d['25'], 9), y2025_yil=top(d['25']), y2024_yil=top(d['24'])))

    satis = satir_tablosu(s[s.find('Satış Üretim yeri'):s.find('Top.Ürt.Miktarı')])
    smm = satir_tablosu(s[s.find('Top.Ürt.Miktarı'):s.find('Besi-Düve Yem Tüketimi Özet')])

    # süt ve ESK hizmeti: aylık birim maliyet
    U = defaultdict(lambda: [0.0] * 9)
    F = defaultdict(lambda: [0.0, 0.0])
    grup = lambda p: 'SÜT' if 'SÜT' in p else ('ESK' if 'ESK BÜYÜKBAŞ' in p else None)
    for r in smm[:]:
        r = r[:21]
        if len(r) < 19 or r[2] not in M or grup(r[4]) is None:
            continue
        k = (r[0], r[1], M.index(r[2]))
        U[k][0] += sayi(r[8]) or 0
        for i, c in enumerate([9, 12, 13, 14, 15, 16, 17]):
            U[k][1 + i] += sayi(r[c]) or 0
        U[k][8] += sayi(r[18]) or 0
    for r in satis:
        if len(r) < 17 or r[5] == 'diğer' or r[2] not in M or grup(r[6]) is None:
            continue
        k = (r[0], r[1], M.index(r[2]))
        F[k][0] += sayi(r[12]) or 0
        F[k][1] += sayi(r[16]) or 0
    birim = []
    for k in sorted(U):
        v = U[k]
        q = v[0]
        if not q:
            continue
        f = F.get(k, [0, 0])
        tutarsiz = k[0] == '1604' and k[1] == '2026' and k[2] in (0, 2)
        birim.append(dict(urun=BIRIM_URUN[k[0]], yil=int(k[1]), ay_no=k[2] + 1, miktar=round(q), toplam=round(v[8]),
                          bilesen={b: round(v[1 + i]) for i, b in enumerate(BILESEN)},
                          satis_miktar=round(f[0]), satis_tl=round(f[1]), tutarsiz=tutarsiz))

    # tarım ürünleri
    T = defaultdict(lambda: [0.0, 0.0, 0.0, 0.0])
    for r in satis:
        if len(r) >= 17 and r[0] in TARIM_CIFTLIK and r[5] != 'diğer' and r[6] in TARIM_AD:
            k = (r[0], r[6], r[1])
            T[k][0] += sayi(r[12]) or 0
            T[k][1] += sayi(r[16]) or 0
    for r in smm:
        r = r[:21]
        if len(r) >= 19 and r[0] in TARIM_CIFTLIK and r[4] in TARIM_AD:
            k = (r[0], r[4], r[1])
            T[k][2] += sayi(r[8]) or 0
            T[k][3] += sayi(r[18]) or 0
    tarim = [dict(ciftlik=TARIM_CIFTLIK[f], urun=TARIM_AD[p], yil=int(y), satis_kg=round(v[0]), satis_tl=round(v[1]),
                  smm_kg=round(v[2]), smm_tl=round(v[3])) for (f, p, y), v in sorted(T.items())]

    # teşvikler
    tes = defaultdict(float)
    for r in satis:
        if len(r) >= 17 and r[5] == 'diğer':
            ad = r[4]
            k = 'Süt teşviki' if 'ÇİĞ SÜT' in ad else 'Buzağı teşviki' if 'BUZAĞI' in ad else \
                'Tarımsal teşvik' if 'TARIMSAL' in ad else 'İstihdam (SGK) teşvikleri'
            tes[(r[1], k)] += sayi(r[16]) or 0
    tesvik = [dict(yil=int(y), kalem=k, tutar=round(v)) for (y, k), v in sorted(tes.items())]

    return dict(
        baslik='Çiftlikler Rapor 2026',
        kaynak='2026 Yılı Çiftlik Raporları (7).xlsx',
        donem='Ocak–Eylül 2026',
        gelir=gelir, aylik=aylik, birim=birim, tarim=tarim, tesvik=tesvik)


if __name__ == '__main__':
    veri = uret(oku(sys.argv[1]))
    with open(sys.argv[2], 'w', encoding='utf-8') as f:
        json.dump(veri, f, ensure_ascii=False, separators=(',', ':'))
    print({k: len(v) for k, v in veri.items() if isinstance(v, list)})
