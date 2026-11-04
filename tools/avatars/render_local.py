#!/usr/bin/env python3
"""Renders the avatar character library on the local GPU (6 GB is enough) with
RealVisXL V5.0 (SDXL, CreativeML Open RAIL++-M: commercial use allowed).
Same seed per character across outfit tiers keeps the face consistent.
Usage: ~/.cache/trailseek-render/bin/python tools/avatars/render_local.py OUT [char ...]"""
import os, sys, time
import torch
from diffusers import StableDiffusionXLPipeline, DPMSolverMultistepScheduler

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from render import CHARS, TIERS  # same characters, seeds and outfits as the online renderer

OUT = sys.argv[1]
only = set(sys.argv[2:])
os.makedirs(OUT, exist_ok=True)

SCENE = ('full body shot of a trekker standing on a rocky mountain summit, entire body visible from head to boots, facing the camera, looking at the viewer, '
         'confident heroic stance, misty green Western Ghats mountains and dramatic cloudy sky behind, '
         'Unreal Engine 5 game character select screen, 3D render, cinematic lighting, sharp focus, highly detailed face, realistic skin')
NEG = ('cropped, out of frame, cut off feet, back view, from behind, multiple people, extra limbs, extra fingers, deformed hands, blurry face, '
       'cartoon, anime, illustration, text, watermark, logo, lowres, jpeg artifacts')

pipe = StableDiffusionXLPipeline.from_pretrained('SG161222/RealVisXL_V5.0', torch_dtype=torch.float16, variant='fp16', use_safetensors=True)
pipe.scheduler = DPMSolverMultistepScheduler.from_config(pipe.scheduler.config, use_karras_sigmas=True, algorithm_type='dpmsolver++')
pipe.enable_model_cpu_offload()
pipe.vae.enable_tiling()

for c, (seed, look) in CHARS.items():
    if only and c not in only:
        continue
    for t, gear in TIERS.items():
        out = os.path.join(OUT, f'{c}_{t}.webp')
        if os.path.exists(out) and os.path.getsize(out) > 10000:
            continue
        t0 = time.time()
        img = pipe(
            prompt=f'{look}, wearing {gear}, {SCENE}',
            negative_prompt=NEG,
            width=832, height=1216, num_inference_steps=28, guidance_scale=5.5,
            generator=torch.Generator('cuda').manual_seed(seed),
        ).images[0]
        img.save(out, 'WEBP', quality=92)
        print('ok', c, t, f'{time.time() - t0:.0f}s', flush=True)
print('done', flush=True)
