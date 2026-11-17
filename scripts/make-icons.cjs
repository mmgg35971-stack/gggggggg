// Renders the crest (app/icon.svg) into the Android launcher icons and splash screens.
// Run once after `npx cap add android`, or whenever the crest changes:  node scripts/make-icons.cjs
// Needs Playwright with a Chromium browser.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const res = path.join(root, 'android/app/src/main/res');
const svg = fs.readFileSync(path.join(root, 'app/icon.svg'), 'utf8');
const crest = svg.replace(/<rect width="120" height="120"[^>]*\/>/, ''); // transparent version
const BG = '#0f0b08';
const DENS = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };

async function shot(page, w, h, inner, crestFrac, file, round = false) {
  const c = Math.round(Math.min(w, h) * crestFrac);
  await page.setViewportSize({ width: w, height: h });
  await page.setContent(`<html><body style="margin:0;width:${w}px;height:${h}px;display:flex;align-items:center;justify-content:center;background:${inner ? BG : 'transparent'};${round ? 'border-radius:50%;overflow:hidden;' : ''}">
    <div style="width:${c}px;height:${c}px">${crest.replace('<svg ', `<svg width="${c}" height="${c}" `)}</div></body></html>`);
  await page.screenshot({ path: file, omitBackground: !inner || round });
}

(async () => {
  const b = await chromium.launch();
  const page = await b.newPage();
  for (const [d, s] of Object.entries(DENS)) {
    const dir = path.join(res, `mipmap-${d}`);
    await shot(page, 48 * s, 48 * s, true, 0.86, path.join(dir, 'ic_launcher.png'));
    await shot(page, 48 * s, 48 * s, true, 0.8, path.join(dir, 'ic_launcher_round.png'), true);
    await shot(page, 108 * s, 108 * s, false, 0.55, path.join(dir, 'ic_launcher_foreground.png'));
  }
  for (const dir of fs.readdirSync(res).filter((n) => n.startsWith('drawable'))) {
    const f = path.join(res, dir, 'splash.png');
    if (!fs.existsSync(f)) continue;
    const buf = fs.readFileSync(f); // PNG IHDR holds width/height at bytes 16-23
    await shot(page, buf.readUInt32BE(16), buf.readUInt32BE(20), true, 0.3, f);
  }
  fs.writeFileSync(path.join(res, 'values/ic_launcher_background.xml'),
    `<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">${BG}</color>\n</resources>\n`);
  await b.close();
  console.log('icons and splash screens written');
})();
