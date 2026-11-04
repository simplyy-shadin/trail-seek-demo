#!/usr/bin/env python3
"""Copies the chosen photos into assets/images/thrissur/ (resized, ~150 KB each)
and writes tools/thrissur/images.json (asset lists per destination/programme +
credits) which build_data.py merges into assets/data/thrissur.json.

Sources (SRC env var or the default scrape folder):
  kfd/      photos from the Kerala Forest Department ecotourism portal
  vzcl/     photos from the Vazhachal Forest Division website
  commons/  Wikimedia Commons files (free licences; credits required)
Usage: SRC=/path/to/scrape/imgs python3 tools/thrissur/images.py
"""
import json, os, sys
from PIL import Image, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.environ.get('SRC', '/tmp/claude-1000/-home-robert-Projects-trailseek/71b6d62d-00b9-408a-a039-faf5736cd0d4/scratchpad/scrape/imgs')
OUT = os.path.join(ROOT, 'assets', 'images', 'thrissur')
MAX_W, QUALITY = 1080, 72

KFD = {'author': 'Kerala Forest Department', 'license': 'Kerala Forest Department ecotourism portal (used with the department for the Thrissur programme)', 'sourceUrl': 'https://ecotourism.forest.kerala.gov.in/'}
VZCL = {'author': 'Vazhachal Forest Division', 'license': 'Vazhachal Forest Division website', 'sourceUrl': 'https://athirappillyvazhachal.in/gallery'}

# asset name -> (source file, credit, title)
MAP = {
    # Athirappilly – Vazhachal
    'athirappilly-falls': ('kfd/slot261_0.jpeg', KFD, 'Athirappilly Falls'),
    'athirappilly-top': ('kfd/slot259_0.jpg', KFD, 'Top of Athirappilly Falls'),
    'vazhachal-rapids': ('kfd/centre81.jpeg', KFD, 'Vazhachal rapids'),
    'vazhachal-group': ('kfd/slot255_0.jpg', KFD, 'Trekking group, Vazhachal division'),
    'athirappilly-wide': ('vzcl/GALMAIN_121743588065.jpeg', VZCL, 'Athirappilly Falls in flow'),
    'athirappilly-trail': ('vzcl/trekking.jpg', VZCL, 'Trekkers above the falls'),
    'hornbill': ('vzcl/GALSUB_161743588218_1743588218.jpeg', VZCL, 'Great hornbill in flight'),
    'vazhachal-bamboo': ('vzcl/GALSUB_131713170376_1713170376.jpeg', VZCL, 'Bamboo arch at Vazhachal'),
    'vazhachal-forest-road': ('vzcl/GALSUB_121713170158_1713170158.jpeg', VZCL, 'Forest road near Vazhachal'),
    # Peechi – Vazhani
    'peechi-sunset': ('kfd/centre54.jpg', KFD, 'Peechi reservoir at dusk'),
    'peechi-coracle-blue': ('kfd/slot140_3.jpg', KFD, 'Coracle on Peechi reservoir'),
    'peechi-coracle-jackets': ('kfd/slot138_1.jpg', KFD, 'Coracle ride with life jackets, Peechi'),
    'peechi-coracle-pair': ('kfd/slot138_2.jpg', KFD, 'Coracles on the reservoir'),
    'peechi-coracle-far': ('kfd/slot141_1.jpg', KFD, 'Coracle under the hills, Peechi'),
    'peechi-boat-shore': ('kfd/slot132_1.jpg', KFD, 'Boat landing, Peechi reservoir'),
    'peechi-dam-aerial': ('kfd/slot135_2.jpg', KFD, 'Peechi dam garden and reservoir'),
    'peechi-stream': ('kfd/slot132_0.jpeg', KFD, 'Forest stream, Peechi'),
    'peechi-stream-2': ('kfd/slot135_1.jpg', KFD, 'Stream crossing on the Moodal trail'),
    'peechi-gaur': ('kfd/slot132_2.jpg', KFD, 'Gaur, Peechi-Vazhani Wildlife Sanctuary'),
    'peechi-dhole': ('kfd/slot134_2.jpg', KFD, 'Dholes (wild dogs), Peechi'),
    'peechi-trail': ('kfd/slot133_0.jpg', KFD, 'Guided walk on the Nasika trail'),
    'peechi-trail-2': ('kfd/slot133_2.jpg', KFD, 'Forest walk, Peechi'),
    # Chimmony
    'chimmony-reservoir': ('kfd/centre55.jpg', KFD, 'Chimmony dam reservoir'),
    'chimmony-elephant': ('kfd/slot230_0.jpg', KFD, 'Elephant, Chimmony Wildlife Sanctuary'),
    'chimmony-elephant-2': ('kfd/slot46_1.jpg', KFD, 'Tusker at Chimmony'),
    'chimmony-elephants-bush': ('kfd/slot145_3.jpg', KFD, 'Elephants in the undergrowth, Chimmony'),
    'chimmony-waterfall': ('kfd/slot145_0.jpeg', KFD, 'Choorathala waterfall'),
    'chimmony-waterfall-2': ('kfd/slot145_1.jpeg', KFD, 'Choorathala waterfall, lower cascade'),
    'chimmony-waterfall-3': ('kfd/slot230_2.jpeg', KFD, 'Waterfall on the Amphi-Trekking route'),
    'chimmony-coracle': ('kfd/slot143_0.jpeg', KFD, 'Bamboo coracles, Chimmony reservoir'),
    'chimmony-coracle-2': ('kfd/slot143_3.jpeg', KFD, 'Coracle ride, Chimmony'),
    'chimmony-coracles-lake': ('kfd/slot143_1.jpeg', KFD, 'Coracles crossing the reservoir'),
    'chimmony-coracle-forest': ('kfd/slot143_2.jpeg', KFD, 'Coracle along the forested shore'),
    'chimmony-trail': ('kfd/slot230_3.jpeg', KFD, 'Trekkers on the Chimmony trail'),
    # Chulannur
    'chulannur-peacocks': ('kfd/slot146_0.jpg', KFD, 'Peacocks at Chulannur'),
    'chulannur-rock': ('kfd/slot147_0.jpg', KFD, 'Laterite outcrop, Chulannur'),
    'chulannur-trekkers': ('kfd/slot147_1.jpg', KFD, 'Trek through the dry forest'),
    'chulannur-plateau': ('kfd/slot147_2.jpg', KFD, 'Rock plateau at dusk, Chulannur'),
    'chulannur-walk': ('kfd/slot149_0.jpg', KFD, 'Guided walk, Chulannur'),
    'chulannur-view': ('kfd/slot149_1.jpg', KFD, 'View from the outcrop'),
    'chulannur-rest': ('kfd/slot149_2.jpg', KFD, 'Rest on the rock, Ayakurisi trek'),
}

# Wikimedia Commons picks, matched by file title in commons_downloaded.json.
COMMONS = {
    'commons-athirappilly': 'File:Athirappilly Falls 2024.jpg',
    'commons-athirappilly-rainbow': 'File:Rainbow at Athirappilly Falls 2025 June.jpg',
    'commons-vazhachal': 'File:The full flowing Vazhachal Falls on the upper reaches of Chalakudy River.jpg',
    'commons-charpa': 'File:The Milky Charpa Falls, Chalakudy.jpg',
    'commons-thumboormuzhi-bridge': 'File:Ezhattumugham-Thumboormuzhi Cable Suspension Bridge IMG20231023143823.jpg',
    'commons-peechi-dam': 'File:Peechi Dam, January 2020 01.jpg',
    'commons-chimmini-dam': 'File:Chimmini Dam, Pariyaram, India (Unsplash).jpg',
    'commons-chimmini-forest': 'File:Chimmini Forest (24191464894).jpg',
    'commons-chulannur-gate': 'File:Choolannur Peafowl Sanctuary gate.jpg',
    'commons-chulannur-1': 'File:Choolannur Peacock Sanctuary 001.jpeg',
    'commons-malakkappara': 'File:Tea Plantation at Malakkappara DSC 9982.jpg',
    'commons-ezhattumugham': 'File:The Ezhattumugham Rapids on the Chalakudy River.jpg',
}

DESTINATIONS = {
    'athirappilly-vazhachal': ['athirappilly-falls', 'commons-athirappilly', 'commons-vazhachal', 'commons-charpa', 'commons-thumboormuzhi-bridge', 'hornbill', 'commons-malakkappara'],
    'peechi-vazhani': ['peechi-coracle-blue', 'peechi-sunset', 'peechi-dam-aerial', 'commons-peechi-dam', 'peechi-dhole', 'peechi-gaur'],
    'chimmony': ['chimmony-reservoir', 'chimmony-elephant', 'chimmony-waterfall', 'chimmony-coracle', 'commons-chimmini-dam', 'commons-chimmini-forest'],
    'chulannur': ['chulannur-peacocks', 'chulannur-rock', 'chulannur-trekkers', 'commons-chulannur-1', 'commons-chulannur-gate'],
}

PROGRAMS = {
    'athirappilly-trekking': ['athirappilly-top', 'athirappilly-trail', 'hornbill', 'vazhachal-forest-road'],
    'vazhachal-trekking': ['vazhachal-rapids', 'vazhachal-group', 'vazhachal-bamboo', 'commons-vazhachal'],
    'athirappilly-vazhachal-falls': ['athirappilly-falls', 'commons-athirappilly-rainbow', 'athirappilly-wide', 'commons-vazhachal', 'commons-charpa'],
    'peechi-elephant-saga': ['peechi-stream', 'peechi-gaur', 'peechi-boat-shore'],
    'peechi-nasika': ['peechi-trail', 'peechi-trail-2', 'peechi-boat-shore'],
    'peechi-dam-valley': ['peechi-dhole', 'peechi-sunset', 'peechi-stream'],
    'peechi-moodal-hill': ['peechi-stream-2', 'peechi-gaur', 'peechi-dam-aerial'],
    'peechi-coracle-20': ['peechi-coracle-jackets', 'peechi-coracle-pair', 'peechi-sunset'],
    'peechi-coracle-40': ['peechi-coracle-far', 'peechi-coracle-pair', 'peechi-coracle-jackets'],
    'peechi-coracle-elephant-saga': ['peechi-coracle-blue', 'peechi-stream', 'peechi-dhole'],
    'peechi-coracle-nasika': ['peechi-coracle-far', 'peechi-trail', 'peechi-coracle-jackets'],
    'peechi-stay-nature-centre': ['peechi-dam-aerial', 'peechi-sunset', 'peechi-coracle-blue'],
    'chimmony-choorathala': ['chimmony-waterfall', 'chimmony-waterfall-2', 'chimmony-elephants-bush', 'chimmony-trail'],
    'chimmony-amphi-trekking': ['chimmony-elephant', 'chimmony-coracle-2', 'chimmony-waterfall-3', 'chimmony-trail'],
    'chimmony-climate-walk': ['chimmony-elephant-2', 'chimmony-trail', 'chimmony-elephants-bush', 'commons-chimmini-forest'],
    'chimmony-coracle-20': ['chimmony-coracle', 'chimmony-coracle-2', 'chimmony-coracle-forest'],
    'chimmony-panther-ride': ['commons-chimmini-dam', 'chimmony-reservoir'],
    'chimmony-anaporu-camp': ['chimmony-coracles-lake', 'commons-chimmini-forest', 'chimmony-elephant'],
    'chulannur-chilambathodi': ['chulannur-peacocks', 'chulannur-walk', 'commons-chulannur-1'],
    'chulannur-anadiyanpara': ['chulannur-rock', 'chulannur-trekkers', 'chulannur-plateau'],
    'chulannur-watch-tower': ['chulannur-view', 'chulannur-peacocks', 'commons-chulannur-gate'],
    'chulannur-ayakurisi': ['chulannur-walk', 'chulannur-rest', 'chulannur-view'],
}


def convert(src, dst):
    im = Image.open(src)
    im = ImageOps.exif_transpose(im).convert('RGB')
    if im.width > MAX_W:
        im = im.resize((MAX_W, round(im.height * MAX_W / im.width)), Image.LANCZOS)
    im.save(dst, 'JPEG', quality=QUALITY, optimize=True, progressive=True)
    return os.path.getsize(dst)


def main():
    os.makedirs(OUT, exist_ok=True)
    commons = {}
    cj = os.path.join(SRC, '..', 'commons_downloaded.json')
    if os.path.exists(cj):
        for it in json.load(open(cj)):
            commons[it['title']] = it
    credits, available = [], set()
    total = 0
    for name, (rel, credit, title) in MAP.items():
        src = os.path.join(SRC, rel)
        if not os.path.exists(src):
            print('missing', rel)
            continue
        dst = os.path.join(OUT, name + '.jpg')
        total += convert(src, dst)
        available.add(name)
        credits.append({'asset': f'assets/images/thrissur/{name}.jpg', 'title': title, **credit})
    for name, title in COMMONS.items():
        it = commons.get(title)
        if not it or not os.path.exists(os.path.join(SRC, '..', it['file'])):
            print('commons not downloaded yet:', title)
            continue
        dst = os.path.join(OUT, name + '.jpg')
        total += convert(os.path.join(SRC, '..', it['file']), dst)
        available.add(name)
        credits.append({'asset': f'assets/images/thrissur/{name}.jpg', 'title': title[5:].rsplit('.', 1)[0], 'author': it.get('artist') or 'Wikimedia Commons contributor', 'license': it.get('license') or '', 'sourceUrl': 'https://commons.wikimedia.org/wiki/' + title.replace(' ', '_')})
    def paths(names):
        return [f'assets/images/thrissur/{n}.jpg' for n in names if n in available]
    out = {'destinations': {k: paths(v) for k, v in DESTINATIONS.items()}, 'programs': {k: paths(v) for k, v in PROGRAMS.items()}, 'credits': credits}
    json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'images.json'), 'w'), indent=1, ensure_ascii=False)
    print(f'{len(available)} images, {total // 1024} KB total -> {OUT}')


if __name__ == '__main__':
    main()
