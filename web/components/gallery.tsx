'use client';
import { useState } from 'react';
export function Gallery({ images, title, subtitle }: { images: string[]; title: string; subtitle?: string }) {
  const [i, setI] = useState(0);
  return (
    <>
      <div className="hero">
        <img src={images[i] ?? '/logo.jpeg'} alt={title} />
        <div className="over"><h1 style={{ margin: 0 }}>{title}</h1>{subtitle && <span className="muted">{subtitle}</span>}</div>
      </div>
      {images.length > 1 && <div className="gallery">{images.map((s, k) => <img key={s} src={s} alt="" className={k === i ? 'on' : ''} onClick={() => setI(k)} />)}</div>}
    </>
  );
}
