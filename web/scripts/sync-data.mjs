// Copies the app's Thrissur dataset and photos into the web app, so both
// clients always show the same programmes and prices.
import fs from 'node:fs';
import path from 'node:path';
const here = path.dirname(new URL(import.meta.url).pathname);
const root = path.resolve(here, '..', '..');
const web = path.resolve(here, '..');
const src = path.join(root, 'assets', 'data', 'thrissur.json');
if (fs.existsSync(src)) {
  fs.mkdirSync(path.join(web, 'data'), { recursive: true });
  fs.copyFileSync(src, path.join(web, 'data', 'thrissur.json'));
  const imgSrc = path.join(root, 'assets', 'images', 'thrissur');
  const imgDst = path.join(web, 'public', 'images', 'thrissur');
  fs.mkdirSync(imgDst, { recursive: true });
  for (const f of fs.readdirSync(imgSrc)) fs.copyFileSync(path.join(imgSrc, f), path.join(imgDst, f));
  fs.copyFileSync(path.join(root, 'assets', 'images', 'logo.jpeg'), path.join(web, 'public', 'logo.jpeg'));
  console.log('synced data and', fs.readdirSync(imgDst).length, 'photos');
} else {
  console.log('no ../assets (deploying from web/ alone): using committed data');
}
