#!/usr/bin/env python3
"""Makes avatar variants from tools/avatars/reference.png: same scene, outfit and
render style, only the person's face and body change (img2img on the local GPU).
Each candidate gets a face pass: the head is re-rendered as a 1024 px close-up
and blended back, so faces stay clean at full-body scale.
Usage: ~/.cache/trailseek-render/bin/python tools/avatars/variants.py OUT [key ...]
Writes OUT/<key>-<n>.webp for n in 0..CANDIDATES-1; pick the best and rename to <key>.webp."""
import os, sys
import numpy as np
import torch
from PIL import Image, ImageDraw, ImageFilter
from diffusers import StableDiffusionXLImg2ImgPipeline, DPMSolverMultistepScheduler

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1]
only = set(sys.argv[2:])
os.makedirs(OUT, exist_ok=True)
CANDIDATES = 3
W, H = 768, 1152

MAN = 'handsome'
WOMAN = 'beautiful pretty feminine'
# key: (seed, woman, person)
PEOPLE = {
    'arav':    (11, False, 'young Indian man, short dark wavy hair, light stubble, lean build'),
    'kiran':   (22, False, 'Indian man, short curly black hair, full trimmed beard, broad build'),
    'rohan':   (33, False, 'young South Indian man, short neat black hair, clean shaven, dark brown skin, athletic'),
    'faisal':  (44, False, 'Malayali man in his thirties, thick black hair, thick moustache, medium brown skin'),
    'joseph':  (55, False, 'Indian man in his forties, salt and pepper hair, neat grey beard, glasses'),
    'dev':     (66, False, 'young Indian man, black hair tied in a short man bun, dark skin, slim'),
    'ananya':  (77, True, 'young Indian woman, long black hair in a high ponytail, slim athletic figure'),
    'meera':   (88, True, 'young Malayali woman, shoulder length wavy black hair, medium brown skin, slim figure'),
    'sara':    (99, True, 'young Indian woman, short black pixie cut hair, fair skin, slim figure'),
    'ayesha':  (111, True, 'young Indian woman wearing a dark green sports hijab covering her hair, slim figure'),
    'lakshmi': (122, True, 'Indian woman in her late twenties, long black braided hair, dark brown skin, slim figure'),
    'nila':    (133, True, 'young South Indian woman, curly black hair in a bun, dark skin, slim athletic figure'),
}
STYLE = ('full body 3D game character render of a trekker standing on a mossy rock at a mountain viewpoint, facing the viewer, '
         'dark charcoal hiking jacket with neon lime green zips and pocket trims, teal inner shirt, brown belt, dark cargo trousers, '
         'brown hiking boots, yellow-green backpack, sun glow behind the head, deep blue sky with clouds, green mountain valleys, '
         'stylized realistic CG, unreal engine 5, octane render, highly detailed, sharp focus')
FACE = ('close-up portrait, {beauty} {person}, symmetrical detailed face, clear bright eyes, smooth skin, natural friendly expression, '
        'dark hiking jacket with neon lime green collar, stylized realistic 3D game character, unreal engine 5, soft rim light, sharp focus')
NEG = 'photo, photograph, blurry, cropped, cut off feet, extra limbs, extra fingers, deformed hands, multiple people, text, watermark, logo'
NEG_FACE = 'ugly, deformed face, asymmetric eyes, crossed eyes, bad teeth, wrinkles, blurry, low detail, photo, text, watermark'

ref = Image.open(os.path.join(HERE, 'reference.png')).convert('RGB').resize((W, H))
pipe = StableDiffusionXLImg2ImgPipeline.from_pretrained('SG161222/RealVisXL_V5.0', torch_dtype=torch.float16, variant='fp16', use_safetensors=True)
pipe.scheduler = DPMSolverMultistepScheduler.from_config(pipe.scheduler.config, use_karras_sigmas=True, algorithm_type='dpmsolver++')
pipe.enable_model_cpu_offload()
pipe.vae.enable_tiling()


def skin(p):
    r, g, b = p[:3]
    return r > 60 and g > 30 and b > 15 and r > g > b and (r - b) > 25 and (r - g) < 90


def find_face(im):
    small = im.resize((96, 144))
    px = small.load()
    rows = []
    for y in range(4, 70):
        xs = [x for x in range(20, 76) if skin(px[x, y])]
        if len(xs) >= 4:
            rows.append((y, sum(xs) / len(xs)))
    if not rows:
        return 0.48, 0.19
    top = rows[0][0]
    face = [r for r in rows if r[0] <= top + 22]
    return sum(r[1] for r in face) / len(face) / 96, (top + 11) / 144


def fix_face(img, woman, person, gen):
    cx, cy = find_face(img)
    side = int(0.30 * W)
    x0 = max(0, min(W - side, int(cx * W - side / 2)))
    y0 = max(0, min(H - side, int(cy * H - side * 0.45)))
    crop = img.crop((x0, y0, x0 + side, y0 + side)).resize((1024, 1024), Image.LANCZOS)
    prompt = FACE.format(beauty=WOMAN if woman else MAN, person=person)
    neg = NEG_FACE + (', masculine, beard, moustache' if woman else '')
    out = pipe(prompt=prompt, negative_prompt=neg, image=crop, strength=0.42, num_inference_steps=36,
               guidance_scale=6.0, generator=gen).images[0].resize((side, side), Image.LANCZOS)
    mask = Image.new('L', (side, side), 0)
    m = int(side * 0.12)
    ImageDraw.Draw(mask).ellipse((m, m, side - m, side - m), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(side * 0.07))
    img = img.copy()
    img.paste(out, (x0, y0), mask)
    return img


for key, (seed, woman, person) in PEOPLE.items():
    if only and key not in only:
        continue
    for n in range(CANDIDATES):
        gen = torch.Generator('cuda').manual_seed(seed * 10 + n)
        beauty = WOMAN if woman else MAN
        img = pipe(prompt=f'{beauty} {person}, {STYLE}', negative_prompt=NEG + (', masculine, beard' if woman else ''), image=ref,
                   strength=0.62 if woman else 0.56, num_inference_steps=34, guidance_scale=6.0, generator=gen).images[0]
        img = fix_face(img, woman, person, gen)
        img.save(os.path.join(OUT, f'{key}-{n}.webp'), 'WEBP', quality=93)
        print('ok', key, n, flush=True)
print('done', flush=True)
