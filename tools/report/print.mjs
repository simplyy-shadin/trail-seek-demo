// Prints tools/report/report.html to docs/Trail-Seek-Project-Report.pdf with headless Chromium.
// Usage: node tools/report/print.mjs   (needs the playwright package; NODE_PATH may point at it)
import { createRequire } from 'module';
import path from 'path';
import { fileURLToPath } from 'url';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const here = path.dirname(fileURLToPath(import.meta.url));
const src = 'file://' + path.join(here, 'report.html');
const out = path.join(here, '..', '..', 'docs', 'Trail-Seek-Project-Report.pdf');

const browser = await chromium.launch();
const page = await browser.newPage();
await page.goto(src, { waitUntil: 'networkidle' });
await page.evaluate(() => document.fonts.ready);
// Footer on every page but the cover; report pages that overflow A4.
const report = await page.evaluate(() => {
  const pages = [...document.querySelectorAll('.page')];
  const a4 = 297 * 96 / 25.4;
  const over = [];
  pages.forEach((p, i) => {
    if (p.scrollHeight > a4 + 2) over.push(`${i + 1}:${Math.round(p.scrollHeight - a4)}px`);
    p.style.height = '297mm';
    p.style.overflow = 'hidden';
    if (i === 0) return;
    const f = document.createElement('div');
    f.style.cssText = 'position:absolute;left:18mm;right:18mm;bottom:9mm;display:flex;justify-content:space-between;font-size:7.6pt;letter-spacing:.4pt;border-top:1px solid rgba(120,140,115,.35);padding-top:5pt;' + (p.classList.contains('end') ? 'color:#8fa08a' : 'color:#7d8a79');
    f.innerHTML = `<span><b style="color:#6fcf00">TRAIL SEEK</b> · Official Project Report · October 2026</span><span>${String(i + 1).padStart(2, '0')} / ${String(pages.length).padStart(2, '0')}</span>`;
    p.appendChild(f);
  });
  return { count: pages.length, over };
});
console.log(JSON.stringify(report));
await page.pdf({ path: out, format: 'A4', printBackground: true, margin: { top: 0, right: 0, bottom: 0, left: 0 }, preferCSSPageSize: true });
await browser.close();
console.log(out);
