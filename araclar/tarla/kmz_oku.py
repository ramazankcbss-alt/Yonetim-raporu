import xml.etree.ElementTree as ET, math, json, sys
NS={'k':'http://www.opengis.net/kml/2.2'}
t=ET.parse(sys.argv[1]); r=t.getroot()
def alan(coords):
    # coords list of (lon,lat); equal-area approx (local projection)
    if len(coords)<3: return 0
    lat0=sum(c[1] for c in coords)/len(coords)
    R=6371008.8
    xs=[math.radians(c[0])*R*math.cos(math.radians(lat0)) for c in coords]; ys=[math.radians(c[1])*R for c in coords]
    a=0
    for i in range(len(xs)): a+=xs[i]*ys[(i+1)%len(xs)]-xs[(i+1)%len(xs)]*ys[i]
    return abs(a)/2
def uzun(coords):
    R=6371008.8; d=0
    for a,b in zip(coords,coords[1:]):
        p1,p2=math.radians(a[1]),math.radians(b[1]); dl=math.radians(b[0]-a[0]); dp=p2-p1
        h=math.sin(dp/2)**2+math.cos(p1)*math.cos(p2)*math.sin(dl/2)**2; d+=2*R*math.asin(math.sqrt(h))
    return d
def crd(el):
    c=el.find('.//k:coordinates',NS)
    if c is None: return []
    return [tuple(map(float,p.split(',')[:2])) for p in c.text.split()]
out=[]
def gez(el,yol):
    for ch in el:
        tag=ch.tag.split('}')[1]
        if tag in('Folder','Document'):
            n=ch.find('k:name',NS); gez(ch,yol+[n.text.strip() if n is not None and n.text else ''])
        elif tag=='Placemark':
            n=ch.find('k:name',NS); d=ch.find('k:description',NS)
            ed={e.get('name'):(e.find('k:value',NS).text if e.find('k:value',NS) is not None else '') for e in ch.findall('.//k:Data',NS)}
            sd={e.get('name'):e.text for e in ch.findall('.//k:SimpleData',NS)}
            if ch.find('.//k:Polygon',NS) is not None:
                o=ch.find('.//k:Polygon/k:outerBoundaryIs',NS); c=crd(o); tur='alan'; a=alan(c)
                for ib in ch.findall('.//k:Polygon/k:innerBoundaryIs',NS): a-=alan(crd(ib))
                if len(ch.findall('.//k:Polygon',NS))>1:
                    a=sum(alan(crd(p.find('k:outerBoundaryIs',NS))) for p in ch.findall('.//k:Polygon',NS))
            elif ch.find('.//k:LineString',NS) is not None: c=crd(ch.find('.//k:LineString',NS)); tur='çizgi'; a=uzun(c)
            elif ch.find('.//k:Point',NS) is not None: c=crd(ch.find('.//k:Point',NS)); tur='nokta'; a=0
            else: c=[]; tur='?'; a=0
            out.append(dict(yol=' / '.join(yol[1:]),ad=(n.text or '').strip() if n is not None else '',acik=(d.text or '').strip() if d is not None else '',veri={**ed,**sd},tur=tur,olcu=a,mrk=(sum(x for x,_ in c)/len(c),sum(y for _,y in c)/len(c)) if c else None,koord=c))
gez(r,[])
json.dump(out,open(sys.argv[2],'w'),ensure_ascii=False)
