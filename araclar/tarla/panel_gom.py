#!/usr/bin/env python3
"""apps_script/tarla_panel.html → TarlaPaneli.gs içindeki TARLA_PANEL_HTML_ (Apps Script'e .gs dosyası olarak yapıştırılsın diye)."""
import json, re, sys, os
kok = os.path.join(os.path.dirname(__file__), '..', '..')
html = open(os.path.join(kok, 'apps_script', 'tarla_panel.html'), encoding='utf8').read()
p = os.path.join(kok, 'apps_script', 'TarlaPaneli.gs')
s = open(p, encoding='utf8').read()
yeni = 'var TARLA_PANEL_HTML_ = ' + json.dumps(html, ensure_ascii=False) + ';'
s2, n = re.subn(r'var TARLA_PANEL_HTML_ = .*?;\n(?=// <</TARLA_PANEL_HTML>>)', lambda m: yeni + '\n', s, flags=re.S)
assert n == 1, 'işaret bulunamadı'
open(p, 'w', encoding='utf8').write(s2)
print('gömüldü', len(html))
