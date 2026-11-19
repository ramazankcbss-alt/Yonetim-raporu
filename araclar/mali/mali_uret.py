#!/usr/bin/env python3
"""Mali Raporlar veri dosyası üretici.

Kaynak: "2026 Çiftlikler İş Birimi Gelen Fatura Raporları" (xlsx).
Çıktı: uygulamanın okuduğu mali_veri.json (Drive › Mali Raporlar).

Kurallar (Tarım ve Hayvancılık Direktörlüğü kararları, Kasım 2026):
- Tutar: L sütunu (TOPLAM TUTAR) olduğu gibi; KDV ayrımı yok. 0 ve "BEDELSİZ" = 0 TL.
- Para birimiyle yazılmış tutarlar (EUR/USD) döviz olarak işlenir.
- Tek birim: Tarım ve Hayvancılık; ayrım kategoriye göre.
- Fatura no + SAT + SAS + tedarikçi + kalem + miktar + tutar aynı satırlar bir kez sayılır.
- Fatura aynı/SAT-SAS farklı ve SAT aynı/fatura farklı kayıtlar olağandır.
KVKK: şahıs tedarikçi adı ve fatura numarası, kalem açıklaması, plaka ve personel
bilgisi çıktıya yazılmaz.

Kullanım: python3 -I mali_uret.py KAYNAK.xlsx CIKTI.json
"""
import openpyxl, datetime, collections, re, json, sys
KAYNAK, CIKTI = sys.argv[1], sys.argv[2]
def s(v): return '' if v is None else str(v).strip()
def sayi(v):
    if isinstance(v,(int,float)): return float(v)
    t=s(v).replace(' ','')
    if not t: return None
    if re.fullmatch(r'-?\d{1,3}(\.\d{3})*,\d+',t) or re.fullmatch(r'-?\d+,\d+',t):
        return float(t.replace('.','').replace(',','.'))
    try: return float(t)
    except: return None

CIFTLIK_={'1613':'Şekersüt (Fethiye)','1605':'Aslım','1611':'Tarımsal Faaliyet (Aslım + Şekersüt tarım)','1604':'Taşağıl','1614':'Pangev (Erentepe)'}
SAYFA={'ASLIM-2026':('Aslım','1605'),'ASLIM TARIM-2026':('Aslım tarım','1611'),'TAŞAĞIL-2026':('Taşağıl','1604'),
 'FETHİYE (ŞEKERSÜT) 2026':('Şekersüt (Fethiye)','1613'),'FETHİYE (ŞEKERSÜT)TARIM-2026':('Şekersüt tarım','1611'),'ERENTEPE(PANGEV)2026':('Pangev (Erentepe)','1614')}

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
PLAKA=re.compile(r'\b\d{2}\s?[A-ZÇĞİÖŞÜ]{1,3}\s?\d{2,4}\b')

g=openpyxl.load_workbook(KAYNAK,read_only=True,data_only=True)
gel=[]; metinTutar=[]
for ws in g.worksheets:
    ad,kod=SAYFA.get(ws.title,(ws.title,''))
    for i,x in enumerate(ws.iter_rows(values_only=True)):
        if i==0 or len(x)<12 or not isinstance(x[1],datetime.datetime): continue
        v=sayi(x[11])
        if not isinstance(x[11],(int,float)): metinTutar.append(dict(sayfa=ws.title,satir=i+1,tarih=x[1],ham=s(x[11]),okunan=v))
        gel.append(dict(satir=i+1,sayfa=ws.title,ciftlik=ad,kod=kod,tarih=x[1],fno=s(x[5]).upper(),firma=s(x[6]),icerik=s(x[7]),miktar=x[8] if isinstance(x[8],(int,float)) else None,
            bf=x[9] if isinstance(x[9],(int,float)) else None,kdv=x[10] if isinstance(x[10],(int,float)) else None,tutar=v or 0.0,kat=kategori(x[7]),uyKod=s(x[13]).split('.')[0]))

F3='2026 Çiftlikler İş Birimi Gelen Fatura Raporları'; L3='https://drive.google.com/file/d/1zKkRZrpBFhCrZxRlBvrWdx58DcQX-M2j/view'
F4='Uygulama tablosu: ESK_Aylık sayfası'; L4='https://docs.google.com/spreadsheets/d/1GkKhf3j-VK8tomjeIqLDMKs-mlq7CYJOfQMyokMGh3Y/edit'
BIRIM={'ASLIM-2026':'Aslım','ASLIM TARIM-2026':'Tarım – Aslım','TAŞAĞIL-2026':'Taşağıl','FETHİYE (ŞEKERSÜT) 2026':'Şekersüt (Fethiye)','FETHİYE (ŞEKERSÜT)TARIM-2026':'Tarım – Şekersüt','ERENTEPE(PANGEV)2026':'Pangev (Erentepe)'}
KOD={'ASLIM-2026':'1605','ASLIM TARIM-2026':'1611','TAŞAĞIL-2026':'1604','FETHİYE (ŞEKERSÜT) 2026':'1613','FETHİYE (ŞEKERSÜT)TARIM-2026':'1611','ERENTEPE(PANGEV)2026':'1614'}
KODAD={'1605':'Aslım','1611':'Tarımsal faaliyet','1604':'Taşağıl','1613':'Şekersüt','1614':'Pangev'}
T=lambda dt: dt.strftime('%Y-%m-%d') if dt else ''
def tl(v): return f"{v:,.2f}".replace(',','X').replace('.',',').replace('X','.')+' TL'
m=lambda v: f"{v/1e6:,.2f}".replace(',','X').replace('.',',').replace('X','.')+' milyon TL'
def tuzel(ad): return not tedarikci(ad).startswith('Şahıs')
def fnoY(no,firma): return f' · fatura no {no}' if tuzel(firma) and no else ''
def hesap(firma):
    f=firma.upper()
    if re.search(r'KONYA ŞEKER|PANAGRO|ÇUMRA ŞEKER|KONYA ŞEKER',f): return 'Grup içi'
    if re.search(r'MÜDÜRLÜĞÜ|BELEDİYE|VERGİ DAİRESİ|TOPRAK MAHSULLERİ|TMO|BAŞKANLIĞI|KURUMU|NOTER',f): return 'Kamu'
    return 'Grup dışı'
import openpyxl
_wb=openpyxl.load_workbook(KAYNAK,read_only=True,data_only=True)
SATSAS={}
for _sh in _wb.sheetnames:
    for _i,_r in enumerate(_wb[_sh].iter_rows(min_row=1,values_only=True),start=1):
        SATSAS[(_sh,_i)]=(str(_r[3] or '').strip(),str(_r[4] or '').strip())
for x in gel: x['sat'],x['sas']=SATSAS.get((x['sayfa'],x['satir']),('',''))
BIRIM_TEK='Tarım ve Hayvancılık'
# döviz ya da birimli yazılmış tutarlar: "5.739,49EUR", "26.304,30usd", "120.649,50TL."
mtk={(m['sayfa'],m['satir']):m for m in metinTutar}
def birimli(ham):
    h=str(ham or '').strip()
    r=re.fullmatch(r'(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d{1,2}))?\s*(EUR|USD|TL)\.?',h,re.I)
    if not r: return None
    v=float(r.group(1).replace('.','')+'.'+(r.group(2) or '0'))
    pb=r.group(3).upper(); return v,('TRY' if pb=='TL' else pb)
DOVIZ=set()
for x in gel:
    x['pb']='TRY'
    mm=mtk.get((x['sayfa'],x['satir']))
    if mm:
        b=birimli(mm['ham'])
        if b:
            x['tutar'],x['pb']=b; DOVIZ.add((x['sayfa'],x['satir']))
# satır bazında KDV durumu ve net tutar
for x in gel:
    x['kdvDurum']='?'; x['net']=x['tutar']
    k=x['kdv'] or 0
    if x['miktar'] and x['bf'] and x['tutar'] and x['pb']=='TRY' and (x['sayfa'],x['satir']) not in mtk:
        net=x['miktar']*x['bf']
        if abs(x['tutar']-net)<=max(1,abs(net)*0.01): x['kdvDurum']='haric'
        elif k and 0<k<1 and abs(x['tutar']-net*(1+k))<=max(1,abs(net)*0.01): x['kdvDurum']='dahil'; x['net']=x['tutar']/(1+k)
        else: x['kdvDurum']='tutmuyor'
    x['kdvDurum']='?'; x['net']=x['tutar']; x['brut']=x['tutar']  # L sütunu olduğu gibi
# fatura grupla
G=collections.OrderedDict()
for x in gel:
    key=(x['sayfa'],x['pb'],re.sub(r'[^A-Z0-9]','',x['fno'].upper()),re.sub(r'[^A-ZÇĞİÖŞÜ]','',x['firma'].upper())[:12])
    G.setdefault(key,[]).append(x)
def yer(l):
    sat=sorted(x['satir'] for x in l); s=l[0]['sayfa']
    rng=f"satır {sat[0]}" if len(sat)==1 else f"satır {sat[0]}–{sat[-1]}" if sat[-1]-sat[0]==len(sat)-1 else 'satır '+', '.join(map(str,sat[:6]))+('…' if len(sat)>6 else '')
    return f"{s} › {rng}{fnoY(l[0]['fno'],l[0]['firma'])}"
# kontroller (satır bazında)
metin={(x['sayfa'],x['satir']):x for x in metinTutar}
sorun=collections.defaultdict(list)
for x in gel:
    k=(x['sayfa'],x['satir'])
    if k in metin and k not in DOVIZ:
        ham=str(metin[k]['ham'] or '').strip()
        if not ham: sorun[k].append('bos')
        elif 'BEDEL' not in ham.upper(): sorun[k].append('metin')
    # tutar 0 girilmiş satırlar geçerli kabul edilir (0 TL)
# ---- ortak ve dağıtılmış faturalar (satır bazında) ----
# Aynı fatura no + tedarikçi + kalem + miktar + tutar birden fazla sayfada → aynı kalemin kopyası; bir kez sayılır.
# Bir sayfaya özgü satırlar o çiftliğin payıdır. Kopya kalemde açıklama çiftlik adı/payı veriyorsa ona göre dağıtılır,
# vermiyorsa "Ortak (çiftliklere ayrılmamış)" olarak izlenir.
SIRA=['ASLIM-2026','ASLIM TARIM-2026','TAŞAĞIL-2026','FETHİYE (ŞEKERSÜT) 2026','FETHİYE (ŞEKERSÜT)TARIM-2026','ERENTEPE(PANGEV)2026']
ORTAK='Ortak (çiftliklere ayrılmamış)'
nrm=lambda s: re.sub(r'[^A-Z0-9]','',str(s).upper())
def trn(s): return str(s).replace('İ','I').replace('ı','i').upper().translate(str.maketrans('ŞĞÜÖÇ','SGUOC'))
CIFT={'ASLIM':['ASLIM-2026','ASLIM TARIM-2026'],'TASAGIL':['TAŞAĞIL-2026'],'FETHIYE':['FETHİYE (ŞEKERSÜT) 2026','FETHİYE (ŞEKERSÜT)TARIM-2026'],
      'SEKERSUT':['FETHİYE (ŞEKERSÜT) 2026','FETHİYE (ŞEKERSÜT)TARIM-2026'],'ERENTEPE':['ERENTEPE(PANGEV)2026'],'PANGEV':['ERENTEPE(PANGEV)2026']}
FR=r'(ASLIM|TASAGIL|FETHIYE|SEKERSUT|ERENTEPE|PANGEV)'
def sayiTR(t):
    t=t.strip('.,')
    if not t: return None
    t=t.replace('.','').replace(',','.')
    try: return float(t)
    except: return None
def sayfaSec(ad,sheets,tarim=False):
    c=CIFT[ad]
    if tarim and len(c)>1: return c[1]
    for k in c:
        if k in sheets: return k
    return c[0]
U=r'(?:KG|TON|ADET|ADT|AD|KISI)?'
def bolus(icerik,sheets):
    u=trn(icerik); par={}
    B=[(f,t,n) for n,f,t in re.findall(r'(\d[\d.,]*)\s*'+U+r'\.?\s*'+FR+r'(\s*TARIM)?',u)]
    A=[(f,t,n) for f,t,n in re.findall(FR+r'(\s*TARIM)?\w*\s*[-:]\s*(\d[\d.,]*)',u)]
    for bul in (B,A):
        par={}
        for f,t,n in bul:
            v=sayiTR(n); k=sayfaSec(f,sheets,bool(t.strip()))
            if v and v>0 and k not in par: par[k]=v
        if len(par)>=2: break
    if len(par)>=2:
        t=sum(par.values()); return [(BIRIM[k],v/t) for k,v in par.items()],'açıklamadaki paylara göre'
    adS={sayfaSec(f,sheets,bool(t.strip())) for f,t in re.findall(FR+r'(\s*TARIM)?',u)}
    if len(adS)==1:
        k=adS.pop(); return [(BIRIM[k],1.0)],'açıklamadaki çiftlik adına göre'
    return None,''
byk=collections.defaultdict(lambda: collections.defaultdict(list))
for x in gel:
    if x['fno'] and not re.fullmatch(r'GIB20260+1',nrm(x['fno'])):
        byk[(nrm(x['fno']),nrm(x['sat']),nrm(x['sas']),re.sub(r'[^A-ZÇĞİÖŞÜ]','',x['firma'].upper())[:12],nrm(x['icerik'])[:80],round(x['miktar'] or 0,3),round(x['tutar'] or 0,2),x['pb'])][x['sayfa']].append(x)
pay={}; kopya=[]; atlaX=set()
for k,ss in byk.items():
    if len(ss)<2: continue
    mn=min(len(v) for v in ss.values()); sheets=sorted(ss,key=SIRA.index)
    for x in ss[sheets[0]][:mn]:
        dag,neden=None,''
        pay[id(x)]=[(BIRIM_TEK,1.0)]
        kopya.append((x,sheets,neden))
    for s_ in sheets[1:]:
        for x in ss[s_][:mn]: atlaX.add(id(x))
# fatura bazında dağıtılmış (sayfaya özgü satırları olan) faturalar
inv=collections.defaultdict(lambda: collections.defaultdict(float))
for x in gel:
    if x['fno'] and not re.fullmatch(r'GIB20260+1',nrm(x['fno'])) and id(x) not in atlaX and id(x) not in pay:
        inv[(nrm(x['fno']),re.sub(r'[^A-ZÇĞİÖŞÜ]','',x['firma'].upper())[:12])][x['sayfa']]+=x['net'] if x['pb']=='TRY' else 0
dagitik=[(k,v) for k,v in inv.items() if len(v)>1]
# faturalar
G=collections.OrderedDict()
for x in gel:
    if id(x) in atlaX: continue
    for birim,oran in pay.get(id(x),[(BIRIM_TEK,1.0)]):
        key=(birim,x['pb'],nrm(x['fno']),re.sub(r'[^A-ZÇĞİÖŞÜ]','',x['firma'].upper())[:12])
        G.setdefault(key,[]).append((x,oran))
def yer(l):
    l=[x for x,_ in l] if l and isinstance(l[0],tuple) else l
    by=collections.OrderedDict()
    for x in l: by.setdefault(x['sayfa'],[]).append(x['satir'])
    out=[]
    for s_,sat in by.items():
        sat=sorted(set(sat))
        rng=f"satır {sat[0]}" if len(sat)==1 else f"satır {sat[0]}–{sat[-1]}" if sat[-1]-sat[0]==len(sat)-1 else 'satır '+', '.join(map(str,sat[:6]))+('…' if len(sat)>6 else '')
        out.append(f"{s_} › {rng}")
    return ' | '.join(out)+fnoY(l[0]['fno'],l[0]['firma'])
fat=[]
ETK={'metin':'Tutar metin','bos':'Tutar boş'}
for key,l in G.items():
    f0=l[0][0]; kat=collections.Counter()
    for x,o in l: kat[x['kat']]+=abs(x['net']*o) or 1
    ss=sorted({ETK[s_] for x,_ in l for s_ in sorun.get((x['sayfa'],x['satir']),[])})
    nt=round(sum(x['net']*o for x,o in l),2)
    fat.append([T(min(x['tarih'] for x,_ in l)),key[0],hesap(f0['firma']),kat.most_common(1)[0][0],tedarikci(f0['firma']).rstrip('.'),
        nt,f0['pb'],'','', 'Uyumlu' if not ss else ', '.join(ss),'',yer(l),nt])
K=[]
def kontrol(bolum,baslik,deger,aciklama,kA='',lA='',kB='',lB='',duz='',detay=None): K.append([bolum,baslik,deger,aciklama,kA,lA,kB,lB,duz,detay or []])
def satirlar(tur):
    return [x for x in gel if tur in sorun.get((x['sayfa'],x['satir']),[])]
def det(x,yap,tutarA=None,yerB=''):
    return [T(x['tarih']),BIRIM[x['sayfa']],tutarA,None,f"{x['sayfa']} › satır {x['satir']}{fnoY(x['fno'],x['firma'])}",yerB,yap]
l=satirlar('metin')
kontrol('Tutarsızlık','Tutar hücresine metin yazılmış satırlar',f'{len(l)} satır',
 'L sütunundaki (TOPLAM TUTAR) değer sayı değil; bu satırlar toplamlara yanlış ya da hiç girmez.',F3,L3,'','','Her satırın sayfa ve satır numarası aşağıda; L sütunundaki değeri sayı olarak yeniden yazın, döviz ise TL karşılığını yazın.',
 [det(x,f"Hücrede \"{metin[(x['sayfa'],x['satir'])]['ham']}\" yazıyor.") for x in l])
l=satirlar('bos')
kontrol('Tutarsızlık','Tutar hücresi boş bırakılmış satırlar',f'{len(l)} satır',
 'Kalem yazılmış ama L sütunu (TOPLAM TUTAR) boş. En önemlisi: 25 Haziran 2026 tarihli ESK\'dan Şekersüt için ithal erkek dana alımı (satır 916); bu faturanın tutarı rapor toplamlarına girmemiştir. Tutarı 0 girilmiş satırlar ve "BEDELSİZ" yazılanlar 0 TL olarak geçerli kabul edildi, bu listede yer almaz.',F3,L3,'','','Fatura aslından tutarı L sütununa yazın.',
 [det(x,f"Kalem: {x['kat']}. Tutar hücresi boş.") for x in l])

kt=[x for x,_,_ in kopya if x['pb']=='TRY']
ayr=sum(x['net'] for x,_,n in kopya if n and x['pb']=='TRY'); ort=sum(x['net'] for x,_,n in kopya if not n and x['pb']=='TRY')
fazla=sum(x['net'] for x in gel if id(x) in atlaX and x['pb']=='TRY')
kf=collections.OrderedDict()
for x,sh,n in kopya: kf.setdefault((nrm(x['fno']),x['firma'][:12]),[]).append((x,sh,n))
# fatura no / SAT / SAS eşleşmesi (sayfalar arası)
FK=collections.defaultdict(lambda: collections.defaultdict(list))
for x in gel:
    if x['fno'] and not re.fullmatch(r'GIB20260+1',nrm(x['fno'])):
        FK[(nrm(x['fno']),re.sub(r'[^A-ZÇĞİÖŞÜ]','',x['firma'].upper())[:12])][x['sayfa']].append(x)
def ss_(xs): return frozenset((nrm(x['sat']),nrm(x['sas'])) for x in xs)
def ssYaz(xs):
    sat=sorted({x['sat'] for x in xs if x['sat']}); sas=sorted({x['sas'] for x in xs if x['sas']})
    return f"SAT {', '.join(sat) or '—'} / SAS {', '.join(sas) or '—'}"
esl=[]; uy=[]
for k,sh in FK.items():
    if len(sh)<2: continue
    (esl if len({ss_(v) for v in sh.values()})==1 else uy).append(sh)
def satirS(sh,yap):
    ks=sorted(sh,key=SIRA.index); xs=[x for s_ in ks for x in sh[s_]]
    t=[sum(x['net'] for x in sh[s_] if x['pb']=='TRY') for s_ in ks]
    return [T(min(x['tarih'] for x in xs)),BIRIM_TEK,round(t[0],2),round(t[1],2),yer(sh[ks[0]]),' | '.join(yer(sh[s_]) for s_ in ks[1:]),yap]
kontrol('Eşleşen kayıtlar','Fatura, SAT ve SAS numarası aynı kayıtlar',f'{len(esl)} fatura · tekrar eden {m(fazla)} toplama eklenmedi',
 f'Aynı fatura numarası birden fazla çiftlik sayfasında ve her sayfada SAT ve SAS numaraları da aynı. Tarım ve Hayvancılık tek birim olarak ele alındığından kalem, miktar ve tutarı aynı satırlar bir kez sayıldı; diğer sayfalardaki {m(fazla)} toplama eklenmedi. Sayfaya özgü farklı kalemler ayrıca sayıldı.',F3,L3,F3,L3,'',
 [satirS(sh,'Fatura, SAT ve SAS aynı: '+ssYaz([x for v in sh.values() for x in v])+'.') for sh in esl])
# SAT aynı, fatura no farklı (sayfalar arası)
SK=collections.defaultdict(lambda: collections.defaultdict(list))
for x in gel:
    if nrm(x['sat']): SK[nrm(x['sat'])][x['sayfa']].append(x)
satF=[sh for sh in SK.values() if len(sh)>1 and len({frozenset(nrm(x['fno']) for x in v) for v in sh.values()})>1]
kontrol('Eşleşen kayıtlar','Fatura numarası aynı, SAT ve SAS çiftliğe göre farklı',f'{len(uy)} fatura',
 'Çiftlikler ihtiyaçlarına göre ayrı SAT ve SAS açmış, malzeme tek yerden alındığı için fatura tek. Bu durum olağandır. Her çiftliğin SAT/SAS satırları kendi kaydı olarak sayıldı.',F3,L3,F3,L3,'',
 [satirS(sh,'Olağan: '+' · '.join(f"{s_}: {ssYaz(sh[s_])}" for s_ in sorted(sh,key=SIRA.index))) for sh in uy])
det=[satirS(sh,'Olağan: '+' · '.join(f"{s_}: fatura {', '.join(sorted({x['fno'] if tuzel(x['firma']) else 'şahıs' for x in sh[s_]}))}" for s_ in sorted(sh,key=SIRA.index))) for sh in satF]
kontrol('Eşleşen kayıtlar','SAT numarası aynı, fatura numarası farklı',f'{len(satF)} kayıt',
 'Tek talep (SAT) birden fazla faturayla, parça parça teslimatla karşılanmış. Bu durum olağandır. Her fatura kendi kaydı olarak sayıldı.',F3,L3,F3,L3,'',det)
# karşılaştırmalar
sapG=[x for x in gel if x['sayfa']=='TAŞAĞIL-2026' and abs(x['tutar']-6766470)<1]
kontrol('Karşılaştırma','ESK: Ağustos 2026 sap balyası maliyeti faturayla doğrulandı','6,77 milyon TL',
 'Taşağıl sayfasındaki "buğday sap balyası (ESK kodu)" alım faturası ESK_Aylık Ağustos sap maliyetiyle aynı. ESK\'ya Ağustos\'ta kesilen 7,52 milyon TL sap faturasının karşılığı bu toplu alım.',F3,L3,F4,L4,'',
 [[T(x['tarih']),'Taşağıl',x['tutar'],6766470.0,f"TAŞAĞIL-2026 › satır {x['satir']}",'ESK_Aylık › satır 21 (Ağustos 2026) › K sütunu (Sap maliyeti)','Tutarlar aynı; düzeltme gerekmez.'] for x in sapG])
esk=[x for x in gel if 'ET VE SÜT' in x['firma'].upper()]
kontrol('Karşılaştırma','ESK\'dan canlı hayvan alımı (Şekersüt)','tutar girilmemiş',
 '25 Haziran 2026 tarihli satır: Et ve Süt Kurumu Sincan Kombinasından Şekersüt için ithal erkek dana alımı. Satırda tutar boş; hayvan adedi ve tutar faturadan girilmeli, adet Fethiye işletme raporunda Temmuz başı "dışarıdan alınan" kaydıyla karşılaştırılmalı.',F3,L3,'','','',
 [det(x,'Tutar ve adet faturadan girilmeli.',x['tutar']) for x in esk])
ESKG={'2026-01':(14,4296418),'2026-02':(15,3767288),'2026-03':(16,3911820),'2026-04':(17,3713289),'2026-05':(18,4576491),'2026-06':(19,5648755),'2026-07':(20,6457056),'2026-08':(21,6762366),'2026-09':(22,6051219),'2026-10':(23,6289392)}
st=collections.Counter(); tas=collections.Counter()
for x in gel:
    if x['sayfa']=='TAŞAĞIL-2026' and x['pb']=='TRY':
        st[x['tarih'].strftime('%Y-%m')]+=x['net']
        if x['kat']=='Taşeron işçilik hizmeti': tas[x['tarih'].strftime('%Y-%m')]+=x['net']
kontrol('Karşılaştırma','Taşağıl sayfasındaki kalemler ve ESK işletme gideri',m(sum(st.values()))+' (Oca–Kas)',
 'Taşağıl sayfasındaki faturalar ile ESK_Aylık işletme gideri ay ay. İşletme gideri personel, amortisman ve enerji gibi fatura dışı giderleri de içerir; sap balyası alımı (Ağustos) ESK\'ya yeniden satıldığı için ayrıca izlenir.',F3,L3,F4,L4,'',
 [[k+'-01','Taşağıl',round(st[k],2),float(v),f"TAŞAĞIL-2026 › {k[5:]}/{k[:4]} faturaları"+(f" (taşeron işçilik {tl(tas[k])})" if tas[k] else ''),f"ESK_Aylık › satır {s} › L sütunu (İşletme gideri)",'Kapsam farkı; düzeltme gerekmez.'+(' Ekim gideri tahmini.' if k=='2026-10' else '')] for k,(s,v) in ESKG.items()])
kontrol('Karşılaştırma','Bakım onarım kayıtları ile yedek parça faturaları','karşılaştırılamadı',
 'Bakım Onarım Kayıtları tablosunda şu an yalnızca 1 deneme kaydı var; yedek parça ve bakım faturaları ile eşleştirme kayıtlar biriktikçe yapılacak.')
dl=[x for x in gel if (x['sayfa'],x['satir']) in DOVIZ and x['pb']!='TRY']
dt=collections.Counter()
for x in dl: dt[x['pb']]+=x['tutar']
fmt=lambda v,pb: f"{v:,.2f}".replace(',','X').replace('.',',').replace('X','.')+' '+pb
kontrol('Bilgi','Döviz olarak işlenen satırlar',f'{len(dl)} satır · '+' · '.join(fmt(v,k) for k,v in sorted(dt.items())),
 'L sütununa para birimiyle (EUR, USD) yazılmış tutarlar döviz faturası olarak işlendi; TL toplamlarına katılmaz, döviz toplamı ayrıca gösterilir. Dosyada kur bilgisi olmadığından TL karşılığı hesaplanmadı. Satır sayısı kopya satırları da içerir; rapordaki döviz toplamı kopyalar bir kez sayılarak hesaplanır. "TL" ekiyle yazılmış tutarlar TL olarak okundu.',F3,L3,'','','TL karşılığı gerekiyorsa fatura tarihindeki kurla ayrı bir sütuna yazın.',
 [[T(x['tarih']),BIRIM[x['sayfa']],None,None,f"{x['sayfa']} › satır {x['satir']}{fnoY(x['fno'],x['firma'])}",'',f"Hücrede \"{mtk[(x['sayfa'],x['satir'])]['ham']}\" yazıyor; {fmt(x['tutar'],x['pb'])} olarak işlendi."] for x in dl])
kontrol('Bilgi','Kaynak dosya','1 dosya',
 f'{F3}: 6 sayfa, {len(gel)} kalem, {len(G)} fatura. Tutarlar dosyanın L sütunundaki TOPLAM TUTAR olduğu gibi alındı; KDV ayrımı yapılmadı (KDV bilgisi M sütununda açıklama olarak yer alır). TL faturalar TL, döviz faturalar kendi para biriminde. Ödeme durumu bu dosyada olmadığı için ödenen/ödenmemiş ayrımı yapılmaz. Satır numaraları Excel satırlarıdır (başlık satırı 1).',F3,L3)
kontrol('Bilgi','KVKK','—','Şahıs işletmeleri ve gerçek kişi tedarikçilerin adları ve fatura numaraları gösterilmez ("Şahıs / teyitsiz tedarikçi"); yerlerini sayfa ve satır numarasıyla bulabilirsiniz. Plaka, kalem açıklaması ve personel ücret ayrıntısı aktarılmaz.')
out=dict(surum=3,olusturma=datetime.date.today().isoformat(),kaynak=F3,kdv='',dosyalar=[['gelen',F3,L3]],fatura=fat,acik=[],kontrol=K)
json.dump(out,open(CIKTI,'w'),ensure_ascii=False,separators=(',',':'))
import os; print(os.path.getsize(CIKTI),len(fat),collections.Counter(f[6] for f in fat),round(sum(f[5] for f in fat if f[6]=='TRY')),round(sum(f[12] for f in fat)),[(k[1][:35],k[2]) for k in K])
