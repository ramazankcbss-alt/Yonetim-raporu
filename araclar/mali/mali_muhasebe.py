#!/usr/bin/env python3
"""Mali Raporlar veri dosyası üretici – yalnızca muhasebe "2026 Fatura" (SAP fatura listesi).

Karar (26.11.2026): Mali Raporlar yalnızca muhasebenin gönderdiği "2026 Fatura" dosyasından beslenir.
"2026 Çiftlikler İş Birimi Gelen Fatura Raporları" artık okunmaz; ondan alınan veriler kaldırıldı.

Kullanım: python3 -I mali_muhasebe.py 2026_Fatura.xlsx CIKTI.json [DRIVE_LINK]
KVKK: "Kullanıcı adı" sütunu okunmaz; şahıs / teyitsiz tedarikçi adları ve onların fatura numaraları
çıktıya yazılmaz; kalem açıklaması aktarılmaz (yalnızca kategori).
"""
import openpyxl, datetime, collections, re, json, sys
KAYNAK, CIKTI = sys.argv[1], sys.argv[2]
L5 = sys.argv[3] if len(sys.argv) > 3 else 'https://drive.google.com/file/d/1SZdjPUrz3_1aHcWn5xBQJSpMeqBntKMw/view'
F5 = '2026 Fatura (muhasebe)'
BIRIM_TEK = 'Tarım ve Hayvancılık'
def s(v): return '' if v is None else str(v).strip()
def sayi(v):
    if isinstance(v,(int,float)): return float(v)
    t=s(v).replace(' ','')
    if not t: return None
    if re.fullmatch(r'-?\d{1,3}(\.\d{3})*,\d+',t) or re.fullmatch(r'-?\d+,\d+',t):
        return float(t.replace('.','').replace(',','.'))
    try: return float(t)
    except: return None
def trn(x): return str(x).replace('İ','I').replace('ı','i').upper().translate(str.maketrans('ŞĞÜÖÇ','SGUOC'))
def nrm(x): return re.sub(r'[^A-Z0-9]','',trn(x))
def fk(firma): return re.sub(r'[^A-Z0-9]','',trn(firma))[:5]
T=lambda dt: dt.strftime('%Y-%m-%d') if dt else ''
m=lambda v: f"{v/1e6:,.2f}".replace(',','X').replace('.',',').replace('X','.')+' milyon TL'
TUZEL=re.compile(r'(ENERJİ\.TOP|A\.?\s?Ş\.?|\bAŞ\b|LTD|ŞTİ|ŞİRKETİ|KOOP|LİMİTED|ANONİM|BİRLİĞİ|MÜDÜRLÜĞÜ|BAŞKANLIĞI|BELEDİYE|KURUMU|KOMBİNASI|ODASI|BORSASI|BANKASI|SİGORTA|ÜNİVERSİTE|HOLDİNG|NOTERLİĞİ|VAKFI|DERNEĞİ|OFİSİ|\(TMO\)|DAĞITIM|PERAKENDE|TURKCELL|VODAFONE|TÜRK TELEKOM|SANAYİ VE TİCARET|SAN\.\s?VE\s?TİC)',re.I)
KURUMSAL=re.compile(r'A\.?Ş|LTD|ŞTİ|KOOP|SAN|TİC|KURUM|KOMBİNA|MÜDÜR|BAŞKAN|BELEDİYE|ODASI|BORSA|BANKA|SİGORTA|ÜNİVERSİTE|HOLDİNG|NOTER|VAKF|DERNEK|OFİSİ|TMO|DAĞITIM|ENERJİ|GIDA|TARIM|VETERİNER|ECZA|MAKİNA|OTO|DSYB|İL[İI] ',re.I)
def tedarikci(ad):
    ad=s(ad)
    if not (TUZEL.search(ad) or re.search(r'ENERJİ\.?TOP|SAN\. A$|SAN\.?$',ad)): return 'Şahıs / teyitsiz tedarikçi'
    for p in re.split(r'\s*-\s*',ad):
        if re.fullmatch(r'[A-ZÇĞİÖŞÜ]+( [A-ZÇĞİÖŞÜ]+){0,2}\.?',p.strip()) and not KURUMSAL.search(p): return 'Şahıs / teyitsiz tedarikçi'
    return ad

KAT=[('Canlı hayvan alımı',r'BESİLİK SIĞIR|İTHAL ERKEK DANA|DÜVE ALIMI|CANLI HAYVAN'),
 ('Taşeron işçilik hizmeti',r'YEVMİYE|PERSONEL ÜCRET|^ÇİFTL+İKLER|^ÇİFTLİK YEVM|İŞÇİLİK HİZMET'),
 ('Enerji ve su',r'AKTİF ENERJİ|DAĞITIM BEDELİ|ELEKTRİK +YANSITMA|^BTV$|ELEKTRİK ENERJİ|ELEKTRİK TÜKETİM|DOĞALGAZ|DOGALGAZ|İÇME SUYU|SU BEDELİ|SULAMA SUYU|ŞAFAK SU|DAMACANA'),
 ('Tohum',r'PAN\.\s?TOH|CONVİSO|SANDPİPER|TOHUM'),
 ('Yem ve kaba yem',r'^ARPA|BUĞDAY(?! HASAT)|TOKSİN BAĞLAYICI|YEM|KÜSPE|SAMAN|SİLAJ|SILAJ|KEPEK|SOYA|PELET|MELAS|BALYA|FLAKE|RASYON|PREMİKS|MİNERAL|TUZ BLOK|BUZAĞI MAMASI|SÜT TOZU'),
 ('Gübre ve zirai ilaç',r'GÜBRE|HERBİSİT|FUNGİSİT|İNSEKTİSİT|ÜRE |AMONYUM|DAP|NPK|BİOVİN|BIOVIN|ASVİN|ASVIN|CERAMINO|SULFO|ZİRAİ|YAPRAK|TARIM İLACI|POLYSULPHATE|GOGGLES|POLKA|COPPER WAY|GALLANT|NATUREX|MAHLAS TARIM|SAFA TARIM|CORTEVA|\d+ ?(SC|EW|EC|WG|SL)\b'),
 ('Tarımsal hizmet (hasat, ilaçlama, nakliye)',r'HASATI|HASAT HİZMET|İLAÇLAMA HİZMET|BİÇİM|BALYALAMA|SÜRÜM HİZMET'),
 ('Makine ve ekipman alımı',r'MAKİNASI|MAKİNESİ|TIRMIĞI|DRONE|PULVERİZATÖR|RÖMORK ALIM|TRAKTÖR ALIM|BALYA MAKİNE'),
 ('Arazi kirası',r'TARLA|ADA \d|PARSEL KİRA|ARAZİ KİRA'),
 ('Akaryakıt',r'MOTORİN|MOTORIN|BENZİN|AKARYAKIT|ADBLUE|EURODİES|DİZEL'),
 ('Veteriner, ilaç, aşı, tohumlama',r'AŞI|VETERİNER|ANTİBİYOT|ENJEK|SPERMA|SEMEN|PAYET|TOHUMLAMA|SERUM|İLAÇ.*(HAYVAN|BUZAĞI|İNEK)|KALSİYUM|BOLUS|OKSİTETRA|PENİSİLİN|DEZENFEKT|İYOT|KOLOSTRUM'),
 ('Sağım ve süt ekipmanı',r'SAĞIM|SAGIM|MEME|PULSATÖR|SÜT TANKI|SÜT HORTUM'),
 ('Nakliye ve taşıma',r'NAKLİYE|NAKLIYE|TAŞIMA|TAŞINMASI|HAMMALİYE|KANTAR'),
 ('İş güvenliği ve giyim',r'İŞ GÜVENLİĞİ|SWEAT|ELDİVEN|BOT |ÇİZME|YELEK|MONT|KASK|TULUM|PANTOLON|TİŞÖRT|GÖMLEK|MASKE'),
 ('Yapı, tesisat ve inşaat',r'ÇİMENTO|DEMİR|BOYA|BETON|TUĞLA|PROFİL|SAC |BORU|VANA|KABLO|ELEKTRİK MALZ|SİGORTA KUTU|İNŞAAT|KAYNAK ELEKTROD|CIVATA|CİVATA|SOMUN'),
 ('Bakım, onarım, yedek parça',r'YAĞ|FİLTRE|RULMAN|TAMİR|BAKIM|ONARIM|LASTİK|AKÜ|PARÇA|KEÇE|HORTUM|KAYIŞ|RADYATÖR|BOBİNAJ|TORNA|KAPORTA|ROT|BALANS|EGZOZ|MOTOR|ŞANZIMAN|DİŞLİ|PİSTON|CONTA|POMPA|AMORTİSÖR|FREN|DEBRİYAJ|SERVİS|HİZMET ALIMI|MANİTOU|TRAKTÖR|JCB|PULLUK|MİBZER|RÖMORK'),
 ('Temizlik, kırtasiye, mutfak',r'TEMİZLİK|DETERJAN|KAĞIT|KIRTASİYE|TONER|ÇAY|ŞEKER |YEMEK|GIDA|EKMEK|SU \d'),
 ('Resmi giderler, vergi, harç',r'DAMGA|VERGİ|HARÇ|NOTER|ÜCRETİ.*MÜDÜRLÜ|AİDAT|SİGORTA PRİM|KASKO|TRAFİK SİGORTA|MUAYENE'),
]
def kategori(t):
    t=s(t).upper()
    for k,p in KAT:
        if re.search(p,t): return k
    return 'Diğer'
def tuzel(ad): return not tedarikci(ad).startswith('Şahıs')
def fnoY(no,firma): return f' · fatura no {no}' if tuzel(firma) and no else ''
def hesap(firma):
    f=firma.upper()
    if re.search(r'KONYA ŞEKER|PANAGRO|ÇUMRA ŞEKER|KONYA ŞEKER',f): return 'Grup içi'
    if re.search(r'MÜDÜRLÜĞÜ|BELEDİYE|VERGİ DAİRESİ|TOPRAK MAHSULLERİ|TMO|BAŞKANLIĞI|KURUMU|NOTER',f): return 'Kamu'
    return 'Grup dışı'

mw=openpyxl.load_workbook(KAYNAK,read_only=True,data_only=True).worksheets[0]
rows=list(mw.iter_rows(values_only=True))
bas=[s(x) for x in rows[0]]
def kol(ad): return bas.index(ad) if ad in bas else None
c=dict(firma=kol('Satıcı adı'),ref=kol('Referans'),tarih=kol('Belge tarihi'),brut=kol('Fatura brüt tutarı'),net=kol('Tutar'),
       metin=kol('Kısa metin'),uy=kol('Üretim yeri'))   # "Kullanıcı adı" okunmaz (KVKK)
MF=collections.OrderedDict()
for i,r in enumerate(rows[1:],start=2):
    if not isinstance(r[c['tarih']],datetime.datetime): continue
    ham=s(r[c['ref']]); k=(nrm(ham),fk(r[c['firma']]))
    f=MF.setdefault(k,dict(ham=ham,satir=[],tarih=r[c['tarih']],firma=s(r[c['firma']]),brut=0.0,net=0.0,kat=collections.Counter()))
    b=sayi(r[c['brut']]) or 0.0; n=sayi(r[c['net']]) or 0.0
    f['satir'].append(i); f['brut']+=b; f['net']+=n; f['kat'][kategori(r[c['metin']])]+=abs(n) or 1
    f['tarih']=min(f['tarih'],r[c['tarih']])
def yer(f):
    sat=f['satir']; rng=f"satır {sat[0]}" if len(sat)==1 else f"satır {sat[0]}–{sat[-1]}"
    return f"{F5} › {rng}"+fnoY(f['ham'],f['firma'])
fat=[[T(f['tarih']),BIRIM_TEK,hesap(f['firma']),f['kat'].most_common(1)[0][0],tedarikci(f['firma']).rstrip('.'),round(f['brut'],2),'TRY','','','',yer(f),'',round(f['net'],2)]
     for f in sorted(MF.values(),key=lambda x:x['tarih'])]
AY=['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran','Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık']
son=max(f['tarih'] for f in MF.values()); ilk=min(f['tarih'] for f in MF.values())
donem=f"{AY[ilk.month-1]}–{AY[son.month-1]} {son.year}"
K=[]
def kontrol(bolum,baslik,deger,aciklama,kA='',lA='',kB='',lB='',duz='',detay=None): K.append([bolum,baslik,deger,aciklama,kA,lA,kB,lB,duz,detay or []])
gecersiz=[f for f in MF.values() if not re.search(r'\d{6}',nrm(f['ham']))]
if gecersiz:
    kontrol('Tutarsızlık','Fatura numarası geçersiz kayıtlar',f'{len(gecersiz)} kayıt',
     'Muhasebe listesinde "Referans" (fatura no) alanı fatura numarası biçiminde değil.',F5,L5,'','','Muhasebeden doğru fatura numarası istenmeli.',
     [[T(f['tarih']),BIRIM_TEK,None,round(f['brut'],2),yer(f)+' · '+tedarikci(f['firma']).rstrip('.'),'','Referans: "'+(f['ham'] if tuzel(f['firma']) else '—')+'".'] for f in gecersiz])
kontrol('Bilgi','Kaynak dosya','1 dosya',
 f'{F5}: {len(rows)-1} kalem, {len(MF)} fatura, {donem}. KDV dahil toplam {m(sum(f["brut"] for f in MF.values()))}, KDV hariç {m(sum(f["net"] for f in MF.values()))}. '
 '26.11.2026 kararıyla Mali Raporlar yalnızca bu dosyadan beslenir; birim fatura raporu okunmaz.',F5,L5)
kontrol('Bilgi','KVKK','—','Kullanıcı adı sütunu okunmaz. Şahıs işletmeleri ve gerçek kişi tedarikçilerin adları ve fatura numaraları gösterilmez ("Şahıs / teyitsiz tedarikçi"); kalem açıklaması aktarılmaz.')
out=dict(surum=5,olusturma=datetime.date.today().isoformat(),kaynak=F5,kdv='dahil',dosyalar=[['muhasebe',F5,L5]],
         fatura=fat,acik=[],kontrol=K,muhasebe=[],muhasebeBilgi=dict(kaynak=F5,link=L5,donem=donem,kdv='dahil'))
json.dump(out,open(CIKTI,'w'),ensure_ascii=False,separators=(',',':'))
print(len(fat),round(sum(f[5] for f in fat)),donem,[k[1] for k in K])
