#!/usr/bin/env python3
"""Build fictional demo documents using the production catalog; never bundle them in the app."""
import base64
import copy
import json
import uuid
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = root / 'Marketing/AppStore/Source'
catalog = json.loads((root / 'Sources/CoverCore/Resources/catalog.json').read_text())
photo = base64.b64encode((source / 'taekwondo-lesson.png').read_bytes()).decode()
words = dict(line1='한 걸음씩 배우는', line2='자신감과 바른 자세', hl='자신감', tag='오늘의 태권도 수업',
             sub='아이의 작은 성장을 함께 응원합니다', en='GROW TOGETHER', handle='@seolin5_tkd', brand='SEOLIN TAEKWONDO')
for order, template_id, title_font in [(1, 'full', 'gothic'), (2, 'card', 'gothic'), (3, 'polaroid', 'gowunb')]:
    template = next(t for t in catalog['templates'] if t['id'] == template_id)
    elements = []
    for index, raw in enumerate(template['elements']):
        values = copy.deepcopy(raw)
        if values['type'] == 'text':
            values['baseSize'] = values.get('size', 60)
        elements.append(dict(id=str(uuid.uuid5(uuid.NAMESPACE_URL, f'seolin.store/{template_id}/{index}')).upper(), values=values))
    project = dict(version=1, themeID='blue', titleFontID=title_font, dim=20, templateID=template_id,
                   words=words, elements=elements, fonts=[], frameHistory={},
                   images={'demo-lesson': photo}, mainPhoto={'items':['demo-lesson'], 'index':0})
    destination = source / 'Documents' / f'{order:02}-{template_id}.seolincover'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(project, ensure_ascii=False, separators=(',', ':')))
    print(destination.relative_to(root))
