// يبني preview للواجهة (ثيم الهالوين) كـ HTML + صور PNG، بنفس المقاسات والألوان اللي بالكود.
//   node tools/preview.js        -> docs/preview/preview.html + desktop.png + phone.png
// النصوص بتبويب Prince AI حقيقية: يشغّل عقل Prince AI على سيناريو (علكان يروح ويرجع).
// تقريبي: الخطوط مو نفس خطوط Roblox بالضبط (Code ~ Inconsolata، Fantasy ~ Fondamento).
const fs = require('fs');
const path = require('path');
const { lua, lauxlib, lualib, to_luastring } = require('fengari');

const ROOT = path.join(__dirname, '..');
const OUT = path.join(ROOT, 'docs', 'preview');
fs.mkdirSync(OUT, { recursive: true });

// ---------- 1) نصوص حقيقية من عقل Prince AI ----------
function brainTexts() {
  const core = fs.readFileSync(path.join(ROOT, 'src', 'newtabs', '23_ai_core.lua'), 'utf8');
  const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
  const code = core + `
local b = PrinceAICore.newBrain()
for t = 1, 40 do
  b:tick({ t = t, hp = 1000, maxHp = 1000, alive = true, pos = { x = (t % 2) * 30, y = 100, z = 0 }, vy = 0,
    fps = 58, ping = 95, farms = { "ImpelTest" }, progress = { kills = 3 }, serverAge = 1800, placeKind = "dungeon",
    toolEquipped = true, status = "Floor 2 - stage 3" })
end
local function esc(s) return (tostring(s):gsub("\\\\", "\\\\\\\\"):gsub('"', '\\\\"'):gsub("\\n", "\\\\n")) end
local ex = {}
for _, l in ipairs(b:explain(12)) do ex[#ex + 1] = '"' .. esc(l) .. '"' end
return '{"summary":"' .. esc(b:summary()) .. '","plan":"' .. esc(b:planText()) .. '","budget":"' .. b:budgetLeft() .. ' / ' .. b.autoBudget
  .. '","explain":[' .. table.concat(ex, ",") .. '],"answer":"' .. esc(b:answer("why stuck?")) .. '"}'`;
  if (lauxlib.luaL_loadstring(L, to_luastring(code)) !== 0 || lua.lua_pcall(L, 0, 1, 0) !== 0) {
    throw new Error(lua.lua_tojsstring(L, -1));
  }
  return JSON.parse(lua.lua_tojsstring(L, -1));
}
const ai = brainTexts();

// ---------- 2) HTML ----------
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const E = {
  label: (t, wrap) => `<div class="lbl${wrap ? ' wrap' : ''}">${esc(t).replace(/\n/g, '<br>')}</div>`,
  toggle: (t, on) => `<div class="tgl"><span class="box${on ? ' on' : ''}"></span>${esc(t)}</div>`,
  dropdown: (t, v) => `<div class="lbl">${esc(t)}</div><div class="dd"><span>${esc(v)}</span><span class="arrow">▼</span></div>`,
  slider: (t, v, min, max) => `<div class="lbl">${esc(t)}</div><div class="sld"><div class="fill" style="width:${((v - min) / (max - min)) * 100}%"></div><span>${v}/${max}</span></div>`,
  button: (t) => `<div class="btn">${esc(t)}</div>`,
  input: (t, ph) => `<div class="lbl">${esc(t)}</div><div class="inp">${esc(ph)}</div>`,
  divider: () => `<div class="div"></div>`,
};
const box = (title, items) => `<div class="gb"><div class="hl"></div><div class="gbt">${esc(title)}</div><div class="gbc">${items.join('')}</div></div>`;

const left = [
  box('Prince AI', [
    E.label('Logic engine: watches the game,', true), E.label('finds the problem and why, then fixes it.', true),
    E.toggle('AI analysis', true), E.dropdown('Mode', 'Advise'), E.dropdown('Language', 'EN'),
    E.toggle('Notifications', true), E.slider('Sure enough at (%)', 55, 30, 90),
  ]),
  box('Analysis', [
    E.label('State: ' + ai.summary, true), E.label('Plan: ' + ai.plan, true), E.label('Auto fixes left: ' + ai.budget + '  | mode Advise'),
    E.button('Apply suggestion'), E.button('Copy analysis'),
  ]),
];
const right = [
  box('Thinking tree (why)', [E.label(ai.explain.join('\n'), true)]),
  box('Ask the AI', [
    E.label('why / cause / plan / tree / history', true), E.label('advice / errors / progress / fps / learn', true),
    E.input('Question', 'why stuck?'), E.label(ai.answer, true), E.button('Forget what it learned'),
  ]),
];

const TABS = ['Main', 'Fish', 'Misc', 'ESP', 'Dungeon', 'Farm', 'Kaitun', 'Cupid', 'Waves', 'Impel', 'Impel Down Zyph', 'Auto Impel (test)', 'Prince AI', 'Config'];
const particles = [
  ['✦', 8, 70, 18, 0.75], ['🎃', 30, 82, 20, 0.6], ['✦', 52, 40, 14, 0.5], ['👻', 74, 64, 22, 0.45], ['🦇', 88, 22, 18, 0.55],
  ['✦', 18, 30, 12, 0.4], ['🕸', 63, 88, 18, 0.35], ['✦', 92, 76, 14, 0.6], ['🎃', 44, 12, 16, 0.3], ['✦', 80, 48, 12, 0.5],
].map(([s, x, y, sz, op], i) => `<span class="pt" style="left:${x}%;top:${y}%;font-size:${sz}px;opacity:${op};transform:rotate(${(i * 23) % 50 - 25}deg)">${s}</span>`).join('');

const windowHtml = `
<div class="win" id="win">
  <div class="bg">${particles}</div>
  <div class="title">🎃 PRINCE HUB</div>
  <div class="profile">👑 Prince  •  LV. 420</div>
  <div class="moon"></div>
  <div class="close">X</div>
  <div class="msi">
    <div class="arrowbtn" style="left:8px">&lt;</div>
    <div class="tabbar"><div class="tabs" id="tabs">${TABS.map((t) => `<div class="tab${t === 'Prince AI' ? ' sel' : ''}">${esc(t)}</div>`).join('')}</div></div>
    <div class="arrowbtn" style="right:8px">&gt;</div>
    <div class="cont"><div class="side l">${left.join('')}</div><div class="side r">${right.join('')}</div></div>
  </div>
</div>`;

const statsHtml = `
<div class="stats">
  <div class="stop"><span class="stt">🎃 Prince Stats</span><span class="sb">-</span><span class="sb">X</span></div>
  <div class="srow h">Auto Impel (test)</div>
  ${[['State', 'Floor 2 - stage 3'], ['Where', 'Dungeon - 2'], ['Stage', '3'], ['Target', 'Kelvin'], ['Kills', '17'], ['Health', 'OK (0 err/60s)']]
    .map(([k, v]) => `<div class="srow"><b>${k}</b>: ${esc(v)}</div>`).join('')}
</div>`;

const html = `<!doctype html><html><head><meta charset="utf-8"><title>Prince Hub preview</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inconsolata:wght@400;700&family=Fondamento&family=Noto+Color+Emoji&family=Montserrat:wght@700&display=swap">
<style>
:root{--white:#fff0ff;--dark:#10081c;--main:#1a0b2e;--orange:#ff7d14;--purple:#7819be;--pink:#d23cff}
*{box-sizing:border-box;margin:0;padding:0}
body{width:100vw;height:100vh;overflow:hidden;font-family:Inconsolata,'Noto Color Emoji',monospace;color:var(--white);
 background:radial-gradient(ellipse at 70% 20%,#2c3e3a 0,#18222a 45%,#0b0f14 100%)}
.scene{position:absolute;inset:0}
.scene:after{content:'';position:absolute;left:0;right:0;bottom:0;height:28%;background:linear-gradient(#1d2b22,#121a14);opacity:.9}
.hint{position:absolute;left:12px;bottom:10px;z-index:5;font:12px Montserrat,sans-serif;color:#9fb0b8;opacity:.8}
.stage{position:absolute;left:50%;top:50%;width:640px;height:600px;transform-origin:center;z-index:3}
.win{position:absolute;inset:0;border-radius:14px;overflow:hidden;padding:2px;
 background:conic-gradient(from 120deg,var(--purple),var(--orange),var(--pink),var(--purple))}
.bg{position:absolute;inset:2px;border-radius:12px;background:linear-gradient(135deg,#0c0419,#370a50);overflow:hidden}
.pt{position:absolute;font-family:'Noto Color Emoji',sans-serif;color:var(--orange);pointer-events:none}
.title{position:absolute;left:9px;top:0;height:25px;line-height:27px;font:18px Fondamento,'Noto Color Emoji',serif;color:var(--orange);
 -webkit-text-stroke:.6px #460064;text-shadow:0 0 2px #460064,1px 1px 0 #460064,-1px -1px 0 #460064;z-index:2}
.profile{position:absolute;right:54px;top:1px;height:23px;line-height:23px;font:700 12px Montserrat,'Noto Color Emoji',sans-serif;z-index:2}
.moon{position:absolute;right:46px;top:5px;width:16px;height:16px;border-radius:50%;background:#ffb45a;box-shadow:0 0 0 2px var(--orange),0 0 10px #ff7d1488;z-index:2;display:none}
.profile{right:82px}.moon{display:block;right:58px}
.close{position:absolute;right:20px;top:3px;width:20px;height:20px;background:var(--purple);border:1px solid var(--pink);border-radius:4px;
 font:700 13px Montserrat,sans-serif;text-align:center;line-height:18px;z-index:2}
.msi{position:absolute;left:10px;top:27px;right:10px;bottom:10px;border-radius:10px;background:rgba(16,8,28,.55)}
.tabbar{position:absolute;left:24px;right:24px;top:8px;height:22px;overflow:hidden}
.tabs{display:flex;gap:8px;position:absolute;right:0;top:0}
.tab{height:21px;padding:0 6px;line-height:21px;font-size:14px;white-space:nowrap;background:var(--dark);border:1px solid rgba(120,25,190,.8);border-radius:6px}
.tab.sel{background:var(--main);border-color:var(--orange);color:var(--orange)}
.arrowbtn{position:absolute;top:8px;width:14px;height:21px;line-height:20px;text-align:center;font-size:14px;background:var(--dark);border:1px solid rgba(210,60,255,.7);border-radius:5px}
.cont{position:absolute;left:8px;right:8px;top:30px;bottom:8px;border-radius:10px;background:rgba(26,11,46,.7);border:1px solid rgba(120,25,190,.75);overflow:hidden}
.side{position:absolute;top:7px;width:calc(50% - 10px);display:flex;flex-direction:column;gap:8px}
.side.l{left:7px}.side.r{left:calc(50% + 5px)}
.gb{position:relative;background:rgba(16,8,28,.88);border:1px solid rgba(210,60,255,.65);border-radius:8px;padding:0 4px 6px;overflow:hidden}
.hl{position:absolute;left:0;right:0;top:0;height:2px;background:var(--orange)}
.gbt{height:20px;line-height:22px;font-size:14px;padding-left:0}
.gbc{display:flex;flex-direction:column;gap:5px;padding-right:4px}
.lbl{font-size:14px;line-height:15px;white-space:nowrap;overflow:hidden}
.lbl.wrap{white-space:normal;word-break:break-word}
.tgl{display:flex;align-items:center;gap:6px;font-size:14px;height:15px}
.tgl .box{width:13px;height:13px;background:var(--main);border:1px solid var(--purple)}
.tgl .box.on{background:var(--orange);border-color:#b3570e}
.dd,.inp,.btn{height:20px;line-height:18px;font-size:14px;background:var(--main);border:1px solid var(--purple);outline:1px solid #000;padding:0 5px}
.dd{display:flex;justify-content:space-between}.dd .arrow{font-size:9px;opacity:.8}
.inp{color:#b9a5c9}
.btn{text-align:center}
.sld{position:relative;height:13px;background:var(--main);border:1px solid var(--purple);outline:1px solid #000;font-size:13px;line-height:11px;text-align:center}
.sld .fill{position:absolute;left:0;top:0;bottom:0;background:var(--orange)}
.sld span{position:relative;text-shadow:0 0 2px #000,0 0 2px #000}
.stats{position:absolute;left:20px;top:140px;width:230px;border-radius:6px;background:var(--dark);border:2px solid var(--orange);overflow:hidden;z-index:4}
.stop{height:24px;display:flex;align-items:center;gap:4px;padding:0 4px 0 8px;background:linear-gradient(90deg,var(--purple),#370a50)}
.stt{flex:1;font:16px Fondamento,'Noto Color Emoji',serif;color:var(--orange)}
.sb{width:20px;height:18px;line-height:18px;text-align:center;background:var(--dark);border-radius:4px;font-size:14px}
.srow{font-size:13px;height:16px;line-height:16px;padding:0 8px}.srow.h{color:var(--orange);font-weight:700;margin-top:3px}
.stats{padding-bottom:4px}
.mini{position:absolute;width:46px;height:46px;border-radius:50%;border:3px solid var(--orange);font:30px 'Noto Color Emoji';display:flex;align-items:center;justify-content:center;
 background:linear-gradient(var(--dark),#0a0512);z-index:4}
.minicap{position:absolute;font:11px Montserrat,sans-serif;color:#cfd8dc;z-index:4;text-align:center;width:120px}
</style></head><body>
<div class="scene"></div>
<div class="stage" id="stage">${windowHtml}</div>
${statsHtml}
<div class="mini" id="mini">🎃</div><div class="minicap" id="minicap">when the menu is hidden</div>
<div class="hint">Prince Hub v20 preview (approximate: fonts differ a little from Roblox)</div>
<script>
// نفس حساب PN_fitScale: min((W-10)/640, (H-50)/600) بين 0.3 و 1
const W = innerWidth, H = innerHeight;
const s = Math.max(0.3, Math.min(1, Math.min((W - 10) / 640, (H - 50) / 600)));
const st = document.getElementById('stage');
st.style.transform = 'translate(-50%,-50%) scale(' + s + ')';
const stats = document.querySelector('.stats');
const mini = document.getElementById('mini'), cap = document.getElementById('minicap');
if (W < 900) {
  // مثل 22_ui_scale.lua: نافذة الـ stats تصغر بنفس النسبة بس مو أقل من 0.7
  stats.style.transform = 'scale(' + Math.min(1, Math.max(0.7, s)) + ')'; stats.style.transformOrigin = 'top left';
  stats.style.top = '40px'; stats.style.left = '8px';
  mini.style.left = (W - 64) + 'px'; mini.style.top = (H - 92) + 'px'; cap.style.left = (W - 126) + 'px'; cap.style.top = (H - 40) + 'px';
  document.querySelector('.hint').style.fontSize = '9px';
  // مثل 22_ui_scale.lua: زر X يكبر حتى يبقى 80% من حجمه الطبيعي
  const x = document.querySelector('.close'); x.style.transform = 'scale(' + Math.max(1, 0.8 / s) + ')'; x.style.transformOrigin = 'top right';
} else {
  mini.style.left = (W - 120) + 'px'; mini.style.top = (H - 120) + 'px'; cap.style.left = (W - 157) + 'px'; cap.style.top = (H - 68) + 'px';
}
</script></body></html>`;
fs.writeFileSync(path.join(OUT, 'preview.html'), html);

// ---------- 3) صور ----------
(async () => {
  let chromium;
  try { ({ chromium } = require('playwright')); } catch (e) { console.log('playwright not found: only HTML written'); return; }
  const browser = await chromium.launch();
  const shots = [
    { name: 'desktop.png', viewport: { width: 1280, height: 720 } },
    { name: 'phone.png', viewport: { width: 800, height: 360 } }, // هاتف بالعرض (landscape)
  ];
  for (const s of shots) {
    const page = await browser.newPage({ viewport: s.viewport, deviceScaleFactor: 2 });
    await page.goto('file://' + path.join(OUT, 'preview.html'));
    await page.waitForLoadState('networkidle').catch(() => {});
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: path.join(OUT, s.name) });
    await page.close();
    console.log('wrote docs/preview/' + s.name);
  }
  await browser.close();
})();
