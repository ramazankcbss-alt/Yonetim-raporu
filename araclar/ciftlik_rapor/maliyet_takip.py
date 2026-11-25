#!/usr/bin/env python3
"""Çiftlikler Rapor 2026 – "ÇİFTLİKLER : MALİYET TAKİP 2026" verisini üretir.

Kaynak: Drive'daki "ÇİFTLİKLER : MALİYET TAKİP 2026" Google E-Tablosunun .xlsx
dışa aktarımı (hesaplanmış değerler). Hata hücreleri (#REF! vb.) değer olarak
alınmaz; ayrıca sayılıp tutarsızlık olarak raporlanır.

Kullanım:
    python3 -I araclar/ciftlik_rapor/maliyet_takip.py <maliyet_takip.xlsx> assets/veri/maliyet_takip_2026.json

KVKK: Yalnızca çiftlik ve kalem bazında toplam tutar, hayvan sayısı ve birim
maliyet aktarılır. İşçilik yalnızca çiftlik toplamı olarak yer alır; kişi,
ücret ayrıntısı, belge/sipariş numarası ve küpe numarası aktarılmaz.
"""
import datetime as dt
import json
import sys
from collections import defaultdict

import openpyxl

AYLAR = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık']
def tr_ust(x):
    return str(x).replace('i', 'İ').replace('ı', 'I').upper()


AYLAR_UST = [tr_ust(a) for a in ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık']]
HATA = ('#REF!', '#DIV/0!', '#VALUE!', '#N/A', '#NAME?', '#NUM!', '#ERROR!')


def deger(v):
    """Sayı → float, boş → None, hata → 'HATA'."""
    if v is None or v == '':
        return None
    if isinstance(v, str):
        s = v.strip()
        if s.upper() in HATA or s.startswith('#'):
            return 'HATA'
        try:
            return float(s.replace('.', '').replace(',', '.'))
        except ValueError:
            return None
    if isinstance(v, (int, float)):
        return float(v)
    return None


def hayvancilik(ws, hatalar):
    bloklar = {3: 'Aslım', 20: 'Taşağıl', 44: 'Şekersüt', 61: 'Pan-Gev'}
    kalemler = {1: 'yem', 2: 'iscilik', 3: 'amortisman', 4: 'diger', 5: 'toplam', 7: 'hayvan'}
    satirlar = list(ws.iter_rows(values_only=True))
    out = []
    for bas, ciftlik in bloklar.items():
        for yil, kolon in ((2025, 2), (2026, 17)):
            for ay in range(12):
                kayit = dict(ciftlik=ciftlik, yil=yil, ay=ay + 1)
                bos = True
                for ofs, ad in kalemler.items():
                    r = satirlar[bas - 1 + ofs]
                    v = deger(r[kolon + ay]) if len(r) > kolon + ay else None
                    if v == 'HATA':
                        hatalar[('MALİYET ÖZET HAYVANCILIK', ciftlik, yil)] += 1
                        v = None
                    if v is not None and v != 0:
                        bos = False
                    kayit[ad] = v
                if not bos:
                    out.append(kayit)
    # TOPLAM bloğu: 2025 sütunlarının Pan-Gev ile birebir aynı olması (kopya hatası) kontrolü
    toplam25 = [deger(x) for x in satirlar[78][2:14]]
    pangev25 = [deger(x) for x in satirlar[61][2:14]]
    kopya = sum(1 for a, b in zip(toplam25, pangev25) if isinstance(a, float) and a == b)
    return out, kopya


URUN = {'YONCA': 'Yonca', 'ARPA': 'Arpa', 'BUĞDAY': 'Buğday', 'TRİTİKALE': 'Tritikale', 'PANCAR': 'Şeker pancarı',
        'MISIR SİLAJI': 'Mısır silajı', 'PATATES': 'Patates'}


def tarim(ws, hatalar):
    satirlar = list(ws.iter_rows(values_only=True))
    basliklar = satirlar[2][2:19]
    donemler = []
    for b in basliklar:
        if isinstance(b, dt.datetime):
            donemler.append((b.year, b.month))
        else:
            donemler.append(None)
    ortak = []
    for i, (yil_ay) in enumerate(donemler):
        if yil_ay is None:
            continue
        k = dict(yil=yil_ay[0], ay=yil_ay[1])
        for ofs, ad in ((3, 'iscilik'), (4, 'amortisman'), (5, 'diger')):
            v = deger(satirlar[ofs][2 + i])
            k[ad] = None if v == 'HATA' else v
        if any(k[a] for a in ('iscilik', 'amortisman', 'diger')):
            ortak.append(k)
    ekilis = []
    ciftlik = None
    for r in satirlar[9:]:
        if r[0]:
            ciftlik = str(r[0]).replace(' EKİLİŞ', '').strip().title().replace('Şekersüt', 'Şekersüt')
        if not r[1] or str(r[1]).strip().upper() == 'TOPLAM' or ciftlik is None:
            continue
        ad = str(r[1]).strip()
        urun, _, alan = ad.partition('(')
        dekar = deger(alan.replace('dekar', '').replace(')', '').strip())
        aylik = {}
        for i, yil_ay in enumerate(donemler):
            if yil_ay is None:
                continue
            v = deger(r[2 + i])
            if v == 'HATA':
                hatalar[('MALİYET ÖZET TARIM 2026', ciftlik, urun.strip())] += 1
                continue
            if v:
                aylik[f'{yil_ay[0]}-{yil_ay[1]:02d}'] = v
        ekilis.append(dict(ciftlik={'Aslim': 'Aslım', 'Şekersüt': 'Şekersüt', 'Taşağil': 'Taşağıl'}.get(ciftlik, ciftlik),
                           urun=URUN.get(urun.strip(), urun.strip()), dekar=dekar,
                           aylik=aylik, toplam=round(sum(aylik.values()), 2)))
    yazili = deger(satirlar[6][19])
    return ortak, ekilis, (yazili if isinstance(yazili, float) else None)


def sut_litre(ws):
    out = []
    satirlar = list(ws.iter_rows(values_only=True))
    for ciftlik, kolon in (('Şekersüt', 0), ('Pan-Gev', 7)):
        for r in satirlar[5:17]:
            ay = str(r[kolon] or '').strip()
            if not ay:
                continue
            ayno = AYLAR_UST.index(tr_ust(ay)) + 1 if tr_ust(ay) in AYLAR_UST else None
            if ayno is None:
                continue
            for j, yil in enumerate((2024, 2025, 2026)):
                v = deger(r[kolon + 1 + j])
                if isinstance(v, float):
                    satis = deger(r[kolon + 4]) if yil == 2026 else None
                    out.append(dict(ciftlik=ciftlik, yil=yil, ay=ayno, maliyet=v,
                                    satis=satis if isinstance(satis, float) else None))
    # Tablonun dışında kalan başıboş hücreler
    disari = []
    for i, r in enumerate(satirlar, 1):
        for j, v in enumerate(r):
            if j >= 13 and v not in (None, ''):
                disari.append(f'{openpyxl.utils.get_column_letter(j + 1)}{i}')
    return out, disari


def karkas(ws):
    out = []
    satirlar = list(ws.iter_rows(values_only=True))
    tanim = [('Aslım', 'Besi', 0, 1, 2), ('Şekersüt', 'Dişi', 4, 5, None), ('Şekersüt', 'Besi', 4, 6, 7), ('Pan-Gev', 'Dişi', 8, 9, None)]
    for r in satirlar[5:17]:
        for ciftlik, tur, ak, vk, nk in tanim:
            ay = tr_ust(str(r[ak] or '').strip())
            if ay not in AYLAR_UST:
                continue
            ayno = AYLAR_UST.index(ay) + 1
            v = r[vk] if len(r) > vk else None
            not_ = str(r[nk]).strip() if nk is not None and len(r) > nk and r[nk] else ''
            d = deger(v)
            if isinstance(v, str) and d is None:
                not_ = v.strip()
            if d is None and not not_:
                continue
            out.append(dict(ciftlik=ciftlik, tur=tur, ay=ayno, maliyet=d if isinstance(d, float) else None, not_=not_))
    return out


def canli(ws):
    out = []
    satirlar = list(ws.iter_rows(values_only=True))
    tanim = [('Aslım', 0, ['Besi', 'Başlıksız sütun']),
             ('Şekersüt', 4, ['Erkek buzağı', 'Besi', 'Dişi buzağı', 'Dişi dana', 'Düve', 'İnek']),
             ('Pan-Gev', 12, ['Erkek buzağı', 'Dişi buzağı', 'Dişi dana', 'Düve', 'İnek'])]
    for r in satirlar[6:18]:
        for ciftlik, k, kategoriler in tanim:
            ay = tr_ust(str(r[k] or '').strip())
            if ay not in AYLAR_UST:
                continue
            ayno = AYLAR_UST.index(ay) + 1
            for j, kat in enumerate(kategoriler):
                d = deger(r[k + 1 + j]) if len(r) > k + 1 + j else None
                if isinstance(d, float):
                    out.append(dict(ciftlik=ciftlik, kategori=kat, ay=ayno, maliyet=d))
    return out


ANA_YEMLER = {'SÜT 19 YEMİ PELET', 'YONCA BALYASI', 'MISIR SILAJI', 'SOYA KÜSPESİ %48', 'ARPA(HAMMADDE)', 'YEM PELET ENERJİ',
              'YEM PELET BESİ GELİŞTİRME', 'SAP BALYASI', 'PAKET PANCAR POSASI 1.000 KG', 'SÜT YEMİ PREMİX', 'MAMA BUZAĞI'}


def yem(ws):
    """Grup × malzeme × ay: miktar ve tutar. Toplam sütununa alınmamış satırlar işaretlenir."""
    satirlar = list(ws.iter_rows(values_only=True))
    out, toplamsiz, genel = [], [], []
    grup = None
    for r in satirlar:
        if r[0]:
            grup = {'ASLIM': 'Aslım', 'ŞEKERSÜT BESİ': 'Şekersüt besi', 'ŞEKERSÜT ANAÇ': 'Şekersüt anaç',
                    'PANGEV': 'Pan-Gev besi', 'PANGEV  ANAÇ': 'Pan-Gev anaç'}.get(str(r[0]).strip().replace('  ', '  '), str(r[0]).strip())
            if str(r[0]).strip().startswith('PANGEV') and 'ANAÇ' in str(r[0]):
                grup = 'Pan-Gev anaç'
            elif str(r[0]).strip() == 'PANGEV':
                grup = 'Pan-Gev besi'
        ad = r[2]
        if grup is None or not isinstance(ad, str):
            if r[1] == 'Genel Toplam' and grup:
                genel.append(dict(grup=grup, tutar=deger(r[41]) or 0, miktar=deger(r[40]) or 0))
            continue
        ad = ad.strip()
        if ad.lower().startswith('malzeme'):
            continue
        aylik = []
        for ay in range(9):
            q, t = deger(r[4 + 3 * ay]), deger(r[5 + 3 * ay])
            if isinstance(q, float) and q:
                aylik.append((ay + 1, q, t if isinstance(t, float) else None))
        if not aylik:
            continue
        if deger(r[41]) in (None, 'HATA'):
            toplamsiz.append(dict(grup=grup, malzeme=ad, miktar=round(sum(q for _, q, _ in aylik), 1)))
        if ad in ANA_YEMLER:
            for ay, q, t in aylik:
                out.append(dict(grup=grup, malzeme=ad, ay=ay, miktar=round(q, 2), tutar=round(t, 2) if t else None))
    return out, toplamsiz, genel


def _ayni(hay, c):
    a = [h for h in hay if h['ciftlik'] == c and h['ay'] == 1]
    return len(a) == 2 and all(a[0][k] == a[1][k] for k in ('yem', 'iscilik', 'amortisman', 'diger', 'toplam', 'hayvan'))


def ozet_hata(ws):
    return sum(1 for r in ws.iter_rows(values_only=True) for v in r if isinstance(v, str) and v.strip().startswith('#REF'))


def uret(yol):
    wb = openpyxl.load_workbook(yol, data_only=True)
    hatalar = defaultdict(int)
    hay, kopya = hayvancilik(wb['MALİYET ÖZET HAYVANCILIK'], hatalar)
    ortak, ekilis, ortak_yazili = tarim(wb['MALİYET ÖZET TARIM 2026'], hatalar)
    sut, disari = sut_litre(wb['SÜT MALİYETİ'])
    yemler, toplamsiz, genel = yem(wb['YEM'])
    return dict(
        kaynak='ÇİFTLİKLER : MALİYET TAKİP 2026',
        hayvancilik=hay,
        tarim_ortak=ortak,
        tarim_ekilis=ekilis,
        sut_litre=sut,
        karkas=karkas(wb['KARKAS MALİYETİ']),
        canli=canli(wb['KAYAR ORTALAMA']),
        yem=yemler,
        yem_genel=genel,
        kontrol=dict(
            ref_hatalari=[dict(sayfa=s, bolum=b, yil=str(y), adet=n) for (s, b, y), n in sorted(hatalar.items(), key=lambda x: str(x))],
            ozet_ref=ozet_hata(wb['ÖZET']),
            toplam_2025_pangev_kopya=kopya,
            tasagil_2026_ocak_2025_kopya=_ayni(hay, 'Taşağıl'),
            sut_tablo_disi_hucre=disari,
            yem_toplama_alinmayan=toplamsiz,
            tarim_ortak_toplam_yazili=ortak_yazili,
        ),
    )


if __name__ == '__main__':
    veri = uret(sys.argv[1])
    with open(sys.argv[2], 'w', encoding='utf-8') as f:
        json.dump(veri, f, ensure_ascii=False, separators=(',', ':'))
    print({k: (len(v) if isinstance(v, list) else v) for k, v in veri.items() if k != 'kontrol'})
    print(json.dumps(veri['kontrol'], ensure_ascii=False, indent=1))
