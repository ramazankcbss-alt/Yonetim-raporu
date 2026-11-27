#!/usr/bin/env python3
"""Araç masrafları verisini üretir (Makine ve Bakım › Araç Masrafları).

Kaynak: Drive'daki "ÇİFTLİKLER ARAÇ MASRAFLARI <yıl>.xlsx" dosyasının Drive connector metin çıktısı
(read_file_content → fileContent): "GENEL LİSTE" (araç × ay matrah) ve "DETAY" (fatura kalemleri).

Kullanım:
    python3 -I araclar/arac/arac_masraf.py <metin_ciktisi.txt|.json> <cikti.json>

Çıktı:
    araclar: [{arac, aylik: {"2026-01": matrah, ...}, toplam}]  (araç adı; plaka ve araç kodu yok)
    uretim_yeri: [{uy, yil, ay, matrah}]                        (aracın iş alanına göre; iş alanı detay satırlarından)
    kontrol: {genel_toplam, detay_toplam}

KVKK: plaka, araç kodu, satıcı adı ve numarası, belge numarası ve açıklama metni (plaka ve kişi adı
içerebilir) okunmaz; yalnızca araç adı, iş alanı, ay, gider hesabı ve tutar yazılır.
"""
import csv
import io
import json
import re
import sys
from collections import defaultdict

AYLAR = {'January': 1, 'February': 2, 'March': 3, 'April': 4, 'May': 5, 'June': 6, 'July': 7, 'August': 8,
         'September': 9, 'October': 10, 'November': 11, 'December': 12}
HESAP = {'7303032030': 'Tamir, bakım ve onarım', '7303030050': 'Akaryakıt', '7304042040': 'Araç kirası',
         '7305051110': 'Zorunlu muayene'}


def sayi(x):
    x = (x or '').strip().replace(',', '')
    try:
        return float(x)
    except ValueError:
        return None


def oku(yol):
    s = open(yol, encoding='utf-8').read()
    if s.lstrip().startswith('{'):
        s = json.loads(s)['fileContent']
    return s


def uret(s):
    detay_bas = s.find(' DETAY ')
    genel = s[:detay_bas if detay_bas > 0 else len(s)]
    hucre = next(csv.reader(io.StringIO(genel.replace('\n', ' '))))
    # Başlıktaki ay sırası: "January 2026", "February 2026", ...
    aylar = []
    for h in hucre:
        m = re.match(r'\s*([A-Z][a-z]+) (\d{4})\s*$', h)
        if m and m.group(1) in AYLAR:
            aylar.append((int(m.group(2)), AYLAR[m.group(1)]))
    # Araç satırları: hücre "<kod> ,<ARAÇ ADI>,<matrah>,TRY,<kdvli>,..." biçimindedir; satır başı araç kodu
    # ile başlayan hücreye yapışık gelir ("... 5P4200130148"). Kod yalnızca satırı bulmak için kullanılır.
    araclar, genel_toplam = [], None
    i = 0
    while i < len(hucre):
        h = hucre[i]
        m = re.search(r'(?:^|\s)(5P[0-9A-Z\-]+)\s*$', h)
        if m and i + 1 < len(hucre):
            ad = hucre[i + 1].strip()
            degerler = hucre[i + 2:i + 2 + 3 * (len(aylar) + 1)]
            aylik = {}
            for k, (y, a) in enumerate(aylar):
                v = sayi(degerler[3 * k]) if 3 * k < len(degerler) else None
                if v:
                    aylik[f'{y}-{a:02d}'] = round(v, 2)
            toplam = sayi(degerler[3 * len(aylar)]) if 3 * len(aylar) < len(degerler) else None
            araclar.append(dict(kod=m.group(1), arac=ad or 'Adı yazılmamış araç', aylik=aylik,
                                toplam=round(toplam or sum(aylik.values()), 2)))
            i += 2
            continue
        if 'GENEL TOPLAM' in h:
            d = [x for x in hucre[i + 1:i + 2 + 3 * (len(aylar) + 1)] if x.strip()]
            # matrah, TRY, kdvli tekrarları; son üçlünün ilki dönem toplamı
            genel_toplam = sayi(d[-3]) if len(d) >= 3 else None
        i += 1

    # Aracın iş alanı (üretim yeri): detay satırlarında araç kodunun yanında geçen 16xx kodlarının çoğunluğu.
    det = s[detay_bas:] if detay_bas > 0 else ''
    oy = defaultdict(lambda: defaultdict(int))
    for m in re.finditer(r'(5P[0-9A-Z\-]+)', det):
        u = re.search(r',(16\d\d),', det[m.end():m.end() + 400])
        if u:
            oy[m.group(1)][u.group(1)] += 1
    uy = defaultdict(float)
    for a in araclar:
        o = oy.get(a['kod'])
        a['uy'] = max(o, key=o.get) if o else ''
        for k, v in a['aylik'].items():
            y, ay = k.split('-')
            uy[(a['uy'], int(y), int(ay))] += v
        del a['kod']  # araç kodu plaka içerir; çıktıya yazılmaz
    uretim_yeri = [dict(uy=k[0], yil=k[1], ay=k[2], matrah=round(v, 2)) for k, v in sorted(uy.items())]
    return dict(
        kaynak='ÇİFTLİKLER ARAÇ MASRAFLARI',
        donem=f'{aylar[0][1]:02d}.{aylar[0][0]}–{aylar[-1][1]:02d}.{aylar[-1][0]}' if aylar else '',
        araclar=araclar,
        uretim_yeri=uretim_yeri,
        kontrol=dict(genel_toplam=genel_toplam, araclar_toplami=round(sum(a['toplam'] for a in araclar), 2)),
    )


if __name__ == '__main__':
    veri = uret(oku(sys.argv[1]))
    with open(sys.argv[2], 'w', encoding='utf-8') as f:
        json.dump(veri, f, ensure_ascii=False, separators=(',', ':'))
    print(len(veri['araclar']), 'araç,', len(veri['uretim_yeri']), 'satır; kontrol', veri['kontrol'], veri['donem'])
