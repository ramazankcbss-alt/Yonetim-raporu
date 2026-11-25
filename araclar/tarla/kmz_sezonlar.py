#!/usr/bin/env python3
"""Sezonlara ayrılmış "Yerlerim … GÜNCEL.kmz" → sezon katmanları.

Kullanım:
  python3 -I kmz_oku.py doc.kml pm.json
  python3 -I kmz_sezonlar.py pm.json assets/veri/tarla_2025_2026.json assets/veri

KMZ'de her sezon (2023-2024 … 2026-2027) ayrı klasördedir. Çizimler esas haritadaki (tarla_2025_2026.json)
parsellerle örtüşmeye göre eşleştirilir (shapely gerekir):
- tarla_2024_2025.json, tarla_2026_2027.json: "katman" — esas parsellerin üzerine o sezonun ürünü, dekarı,
  tohumu ve (parselin bir kısmını kaplayan çizimlerden) bölgeleri.
- 2023-2024 sezonu kaldırıldı (25.11.2026).
Ürün ve dekar KMZ'deki çizim adından okunur (ör. "3. Parsel 190da. Buğday Halis"). Uygulamadan girilen
kayıtlar bu bilgilerin önüne geçer. 2025-2026 sezonu ayrıca düzenlenmiş olduğundan bu betikle değişmez.
KVKK: çizim adlarında kişi adı yoktur; kişi adı içeren çizim çıkarsa alınmaz (KISI listesi).
"""
import json, math, re, sys
from shapely.geometry import Polygon
from shapely.validation import make_valid

L = json.load(open(sys.argv[1]))
esas = json.load(open(sys.argv[2]))
cikti = sys.argv[3]
KX = math.cos(math.radians(37.9))
CF = {'ŞEKERSÜT': 'Şekersüt', 'ASLIM': 'Aslım', 'TAŞAĞIL': 'Taşağıl', 'FİDANLIK': 'Fidanlık'}
KISI = []  # kişi adı geçen çizim adları buraya; alınmaz


def P(k):
    p = Polygon([(a * KX, b) for a, b in k])
    return p if p.is_valid else make_valid(p)


def kucuk(t):
    return t.replace('I', 'ı').replace('İ', 'i').lower()


URUN = [  # (aranan, ürün) — sıra önemli
    ('ıslah', 'Islah edilen alan'), ('deneme', 'Deneme alanı'), ('arge', 'Deneme alanı'),
    ('toprak dökme', 'Boş alan'), ('boş alan', 'Boş alan'), ('boş toprak', 'Boş alan'),
    ('yağlık', 'Yağlık ayçiçeği'), ('ayçiçe', 'Yağlık ayçiçeği'), ('soğan', 'Soğan'), ('patates', 'Patates'),
    ('yonca', 'Yonca'), ('trıtıcale', 'Tritikale'), ('tırıtıcale', 'Tritikale'), ('tritikale', 'Tritikale'),
    ('silaj', 'Silajlık mısır'), ('mısır', 'Silajlık mısır'), ('pancar', 'Şeker pancarı'),
    ('buğday', 'Buğday'), ('arpa', 'Arpa'),
]
TOHUM = ['halis', 'touareg', 'altındane', 'campanie']


def oku(ad):
    """Çizim adından (ürün, dekar, tohum); ürün yoksa None."""
    k = kucuk(ad)
    yer = [(k.find(a), u) for a, u in URUN if a in k]
    if not yer:
        return None
    u = min(yer)[1]
    m = re.search(r'(\d+(?:[.,]\d+)?)\s*\.?\s*(?:da\b|da\.|dekar|d\.a)', k)
    if not m:  # birimsiz sayı ("7.pivot 240 Arpa"); baştaki sıra numarası sayılmaz
        m = re.search(r'(?<![\d.])(\d{2,4})(?![\d.])', re.sub(r'^\s*\d+\s*\.', '', k))
    da = float(m.group(1).replace(',', '.')) if m else None
    t = next((x.capitalize() for x in TOHUM if x in k), None)
    return u, da, t


def sade(c, n):
    if len(c) <= n:
        return c
    s = len(c) / n
    return [c[int(i * s)] for i in range(n)]


esas_p = {}
for c in esas['ciftlikler']:
    for p in c['parseller']:
        if len(p['koord']) > 2:
            esas_p[(c['ad'], p['ad'])] = (p, P(p['koord']))


def sezon_cizimleri(sezon):
    for x in L:
        y = x['yol'].split(' / ')[2:]
        if x['tur'] != 'alan' or not y or y[0] != sezon or x['ad'] in KISI:
            continue
        cf = 'Taşağıl' if 'TAŞAĞIL' in y else CF.get(y[1] if len(y) > 1 else '')
        if cf:
            yield cf, y, x


def eslestir(cf, q):
    en, ei = None, 0
    for (c, a), (_, b) in esas_p.items():
        if c != cf:
            continue
        i = q.intersection(b).area
        if i > ei:
            en, ei = a, i
    if not en:
        return None, 0, 0
    return en, ei / q.area, ei / esas_p[(cf, en)][1].area


def katman(sezon):
    """Esas parsellere düşen o sezonun çizimleri → parsel başına ürün/dekar/tohum/bölge."""
    gruplar = {}
    for cf, y, x in sezon_cizimleri(sezon):
        q = P(x['koord'])
        ad, kap, pay = eslestir(cf, q)
        if not ad or kap < 0.8:
            continue
        gruplar.setdefault((cf, ad), []).append((x, q, pay))
    sonuc = {}
    for (cf, ad), l in gruplar.items():
        esasp, b = esas_p[(cf, ad)]
        if esasp['tip'] == 'diger':
            continue
        tam = [(x, q, pay) for x, q, pay in l if pay >= 0.85 and oku(x['ad'])]
        kismi = [(x, q, pay) for x, q, pay in l if pay < 0.85 and oku(x['ad'])]
        etiket = ' / '.join(sorted({x['ad'].strip() for x, _, _ in l}))
        if not tam and not kismi:
            continue
        if tam:
            kalan = oku(tam[0][0]['ad'])
            cel = len({oku(x['ad'])[0] for x, _, _ in tam}) > 1
        else:
            # Parsel parçalara ayrılmış: en büyük parça kalan olur.
            kismi.sort(key=lambda t: -t[1].area)
            kalan = oku(kismi[0][0]['ad'])
            kismi = kismi[1:]
            cel = False
        x0, y0, x1, y1 = b.bounds
        bolgeler, urunler, cesitler = [], [], []
        for x, q, _ in kismi:
            u, da, t = oku(x['ad'])
            k = [(a * KX, bb) for a, bb in x['koord']]
            if k[0] == k[-1]:
                k = k[:-1]
            k = sade(k, 16)
            bolgeler.append(['P', [round(v) for a, bb in k for v in ((a - x0) / (x1 - x0) * 100, (bb - y0) / (y1 - y0) * 100)]])
            urunler.append([u, da or round(q.area / b.area * (esasp.get('beyan') or 0)) or 0])
            cesitler.append(t)
        u, da, t = kalan
        urunler.append([u, da or 0])
        cesitler.append(t)
        sonuc.setdefault(cf, []).append(dict(
            ad=ad, tip=esasp['tip'] if esasp['tip'] != 'bos' else 'parsel',
            urunler=urunler, cesitler=cesitler if any(cesitler) else [], bolgeler=bolgeler,
            not_=f'KMZ: {etiket}' + (' (üst üste farklı ürünlü çizimler var)' if cel else '')))
    return sonuc


def yaz(ad, d):
    with open(f'{cikti}/{ad}', 'w') as f:
        json.dump(d, f, ensure_ascii=False, separators=(',', ':'))


KAYNAK = sys.argv[4] if len(sys.argv) > 4 else 'Yerlerim 24.11.2026 GÜNCEL.kmz'
for sezon in ['2024-2025', '2026-2027']:
    k = katman(sezon)
    yaz(f'tarla_{sezon.replace("-", "_")}.json', dict(sezon=sezon, kaynak=KAYNAK, tarih='2026-11-24', tur='katman',
        ciftlikler=[dict(ad=c, parseller=p) for c, p in k.items()]))
    print(sezon, {c: len(p) for c, p in k.items()})

# 2023-2024 sezonu kullanıcı kararıyla kaldırıldı (25.11.2026); dosyası üretilmez.
