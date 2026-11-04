#!/usr/bin/env python3
"""Renders the avatar character library with FLUX.1-schnell (Apache-2.0) via the
public Hugging Face demo (no key). Output: OUT/<char>_<tier>.png, 768x1152.
Re-runnable: skips files that already exist."""
import json, os, sys, time, urllib.request

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
BASE = 'https://black-forest-labs-flux-1-schnell.hf.space/gradio_api'

CHARS = {
    'arav':   (101, 'young Indian man, short dark hair swept up, light stubble'),
    'kiran':  (202, 'Indian man in his late twenties, short curly black hair, trimmed full beard'),
    'rohan':  (303, 'young Indian man, buzz cut black hair, clean shaven, athletic build'),
    'faisal': (404, 'Malayali man in his thirties, thick black wavy hair, moustache'),
    'joseph': (505, 'Indian man in his forties, salt and pepper short hair, neat beard, glasses'),
    'dev':    (606, 'young South Indian man, medium length black hair tied back, dark skin'),
    'ananya': (707, 'young Indian woman, long black hair in a high ponytail'),
    'meera':  (808, 'young Malayali woman, shoulder length wavy black hair'),
    'sara':   (909, 'Indian woman in her late twenties, short pixie cut black hair'),
    'ayesha': (111, 'young Indian Muslim woman wearing a dark green sports hijab'),
    'lakshmi':(222, 'Indian woman in her thirties, long braided black hair'),
    'nila':   (333, 'young South Indian woman, curly black hair in a bun, dark skin'),
}
TIERS = {
    'rookie': 'grey t-shirt, black trekking shorts over leggings, trail running shoes, small daypack',
    'pathfinder': 'dark grey technical hiking jacket with neon green accents, cargo trekking pants, brown hiking boots, yellow-green backpack, utility belt',
    'summit': 'insulated orange and black mountaineering jacket, harness, helmet clipped to a large expedition backpack, headlamp, trekking poles, gaiters, mountaineering boots',
}
SCENE = ('full body 3D render, standing on a rocky mountain top, facing the camera, looking at the viewer, confident heroic pose, '
         'misty green Western Ghats mountains and dramatic sky behind, Unreal Engine 5 game character select screen, cinematic lighting, highly detailed, realistic')


def call(prompt, seed):
    body = json.dumps({'data': [prompt, seed, False, 768, 1152, 4]}).encode()
    req = urllib.request.Request(f'{BASE}/call/infer', data=body, headers={'Content-Type': 'application/json'})
    eid = json.load(urllib.request.urlopen(req, timeout=60))['event_id']
    stream = urllib.request.urlopen(f'{BASE}/call/infer/{eid}', timeout=300).read().decode()
    if 'event: error' in stream:
        raise RuntimeError(stream[-300:])
    data = json.loads(stream.split('data: ')[-1].strip())
    return urllib.request.urlopen(data[0]['url'], timeout=60).read()


def main():
    jobs = [(c, t) for c in CHARS for t in TIERS]
    for c, t in jobs:
        out = os.path.join(OUT, f'{c}_{t}.webp')
        if os.path.exists(out) and os.path.getsize(out) > 10000:
            continue
        seed, look = CHARS[c]
        prompt = f'{SCENE}, {look}, wearing {TIERS[t]}'
        for attempt in range(6):
            try:
                data = call(prompt, seed)
                open(out, 'wb').write(data)
                print('ok', c, t, flush=True)
                break
            except Exception as e:
                wait = 60 * (attempt + 1)
                print('retry', c, t, str(e)[:160], f'wait {wait}s', flush=True)
                time.sleep(wait)
        time.sleep(4)
    print('done', flush=True)


if __name__ == '__main__':
    main()
