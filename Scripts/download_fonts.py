#!/usr/bin/env python3
"""Vendor the exact open-source Google Fonts families used by the HTML, with licenses."""
from pathlib import Path
import urllib.request, json, hashlib
root=Path(__file__).resolve().parent.parent/'Sources/CoverCore/Resources/Fonts'
root.mkdir(parents=True,exist_ok=True)
families=['notosanskr','blackhansans','nanummyeongjo','nanumgothic','dohyeon','jua','gowundodum','gowunbatang','gothica1','ibmplexsanskr','sunflower','dongle','songmyung','nanumpenscript','nanumbrushscript','gaegu','greatvibes']
manifest=[]
for family in families:
 url=f'https://api.github.com/repos/google/fonts/contents/ofl/{family}'
 items=json.load(urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'SeolinCoverMigration'})))
 for item in items:
  name=item['name']
  if name.endswith('.ttf') or name in ['OFL.txt','LICENSE.txt']:
   target=root/(family+'-'+name)
   if not target.exists(): target.write_bytes(urllib.request.urlopen(item['download_url']).read())
   manifest.append({'file':target.name,'source':item['download_url'],'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
 print(family,flush=True)
(root/'font-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
